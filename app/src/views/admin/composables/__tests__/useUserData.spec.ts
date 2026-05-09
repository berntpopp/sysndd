// app/src/views/admin/composables/__tests__/useUserData.spec.ts
/**
 * Unit tests for `useUserData` — the data-loading composable extracted
 * from `ManageUser.vue` during W1 of v11.2 monolith-cleanup.
 *
 * Mock strategy: stub `axios` at the module level (matching the W6 Review.vue
 * composable precedent in `src/views/review/composables/__tests__/`).
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';

vi.mock('axios', () => {
  const axiosMock = {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
    defaults: { baseURL: '', headers: { common: {} } },
    interceptors: {
      request: {
        use: vi.fn(),
        _cb: null,
      },
      response: {
        use: vi.fn(),
      },
    },
    isAxiosError: (err: unknown): boolean =>
      typeof err === 'object' && err !== null && 'isAxiosError' in err,
  };
  return {
    default: axiosMock,
    ...axiosMock,
    AxiosHeaders: class {
      private store = new Map<string, string>();
      has(key: string): boolean {
        return this.store.has(key.toLowerCase());
      }
      get(key: string): string | null {
        return this.store.get(key.toLowerCase()) ?? null;
      }
      set(key: string, value: string): this {
        this.store.set(key.toLowerCase(), value);
        return this;
      }
    },
    AxiosError: Error,
  };
});

vi.mock('@/router', () => ({
  default: {
    push: vi.fn(),
    currentRoute: { value: { fullPath: '/admin/manage-user' } },
  },
}));

import { __resetUserDataCache, useUserData } from '../useUserData';

interface AxiosMock {
  get: ReturnType<typeof vi.fn>;
}
async function getAxiosMock(): Promise<AxiosMock> {
  const axios = await import('axios');
  return axios.default as unknown as AxiosMock;
}

const userTablePayload = {
  data: [
    {
      user_id: 1,
      user_name: 'alice',
      email: 'alice@example.org',
      user_role: 'Curator',
      approved: 1,
    },
    { user_id: 2, user_name: 'bob', email: 'bob@example.org', user_role: 'Reviewer', approved: 1 },
  ],
  meta: [
    {
      totalItems: 2,
      currentPage: 1,
      totalPages: 1,
      prevItemID: 0,
      currentItemID: 0,
      nextItemID: 0,
      lastItemID: 0,
      executionTime: 5,
      fspec: [],
    },
  ],
};

describe('useUserData', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    __resetUserDataCache();
  });

  it('loadData populates users and meta', async () => {
    const axios = await getAxiosMock();
    axios.get.mockResolvedValueOnce({ status: 200, data: userTablePayload });
    const data = useUserData();
    expect(data.users.value).toEqual([]);
    await data.loadDataNow();
    await flushPromises();
    expect(data.users.value).toHaveLength(2);
    expect(data.totalRows.value).toBe(2);
    expect(data.totalPages.value).toBe(1);
  });

  it('loadData error path surfaces via toast hook and clears isBusy', async () => {
    const axios = await getAxiosMock();
    const err = new Error('boom');
    axios.get.mockRejectedValueOnce(err);
    const toasts: Array<unknown[]> = [];
    const data = useUserData({ onToast: (...args: unknown[]) => toasts.push(args) });
    await data.loadDataNow();
    await flushPromises();
    expect(data.isBusy.value).toBe(false);
    expect(toasts).toHaveLength(1);
  });

  it('loadRoleList populates role_options', async () => {
    const axios = await getAxiosMock();
    axios.get.mockResolvedValueOnce({
      status: 200,
      data: [{ role: 'Administrator' }, { role: 'Curator' }],
    });
    const data = useUserData();
    await data.loadRoleList();
    await flushPromises();
    expect(data.roleOptions.value).toEqual([
      { value: 'Administrator', text: 'Administrator' },
      { value: 'Curator', text: 'Curator' },
    ]);
  });

  it('handlePageChange triggers a second loadData call', async () => {
    const axios = await getAxiosMock();
    axios.get.mockResolvedValue({ status: 200, data: userTablePayload });
    const data = useUserData();
    await data.loadDataNow();
    await flushPromises();
    expect(axios.get).toHaveBeenCalledTimes(1);
    // Reset cache so the second call (with same params) isn't deduped
    __resetUserDataCache();
    data.handlePageChange(2);
    await new Promise((r) => setTimeout(r, 80)); // wait past 50ms debounce
    await flushPromises();
    expect(axios.get).toHaveBeenCalledTimes(2);
  });

  it('removeFilters clears every filter content', async () => {
    const data = useUserData();
    data.filter.value.user_name.content = 'alice';
    data.removeFilters();
    expect(data.filter.value.user_name.content).toBeNull();
  });
});
