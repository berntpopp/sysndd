// app/src/views/admin/composables/__tests__/useBulkUserActions.spec.ts
/**
 * Unit tests for `useBulkUserActions` — the bulk-operations composable
 * extracted from `ManageUser.vue` during W1 of v11.2 monolith-cleanup.
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
      request: { use: vi.fn(), _cb: null },
      response: { use: vi.fn() },
    },
    isAxiosError: (err: unknown): boolean =>
      typeof err === 'object' && err !== null && 'isAxiosError' in err,
  };
  return {
    default: axiosMock,
    ...axiosMock,
    AxiosHeaders: class {
      private store = new Map<string, string>();
      has(key: string): boolean { return this.store.has(key.toLowerCase()); }
      get(key: string): string | null { return this.store.get(key.toLowerCase()) ?? null; }
      set(key: string, value: string): this { this.store.set(key.toLowerCase(), value); return this; }
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

import { useBulkUserActions } from '../useBulkUserActions';

interface AxiosMock { post: ReturnType<typeof vi.fn> }
async function getAxiosMock(): Promise<AxiosMock> {
  const axios = await import('axios');
  return axios.default as unknown as AxiosMock;
}

describe('useBulkUserActions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('bulkApprove POSTs user_ids and toggles bulkActing', async () => {
    const axios = await getAxiosMock();
    axios.post.mockResolvedValueOnce({ status: 200, data: { processed: 3 } });
    const a = useBulkUserActions();
    expect(a.bulkActing.value).toBe(false);
    const p = a.bulkApprove([1, 2, 3]);
    expect(a.bulkActing.value).toBe(true);
    await p;
    await flushPromises();
    expect(a.bulkActing.value).toBe(false);
  });

  it('bulkAssignRole POSTs user_ids + role and rejects empty selection or empty role', async () => {
    const axios = await getAxiosMock();
    let received: any = null;
    axios.post.mockImplementationOnce((_url: string, data: any) => {
      received = data;
      return Promise.resolve({ status: 200, data: { processed: 2 } });
    });
    const a = useBulkUserActions();
    await expect(a.bulkAssignRole([], 'Curator')).rejects.toThrow();
    await expect(a.bulkAssignRole([1, 2], '')).rejects.toThrow();
    await a.bulkAssignRole([1, 2], 'Curator');
    await flushPromises();
    expect(received).toEqual({ user_ids: [1, 2], role: 'Curator' });
  });

  it('bulkDelete POSTs user_ids and clears bulkActing on success', async () => {
    const axios = await getAxiosMock();
    axios.post.mockResolvedValueOnce({ status: 200, data: { processed: 2 } });
    const a = useBulkUserActions();
    await a.bulkDelete([1, 2]);
    await flushPromises();
    expect(a.bulkActing.value).toBe(false);
  });
});
