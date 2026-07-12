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
    // removeFilters() schedules a 50ms debounced load; dispose so its timer cannot
    // fire inside a later test with a different axios mock / module state.
    data.dispose();
  });

  // --- S5b request ownership -------------------------------------------------

  it('shares one same-param transport with two current instances and applies it to both', async () => {
    const axios = await getAxiosMock();
    let resolve!: (value: unknown) => void;
    axios.get.mockImplementationOnce(() => new Promise((res) => (resolve = res)));

    const first = useUserData();
    const second = useUserData();
    const firstPending = first.loadDataNow();
    const secondPending = second.loadDataNow();

    expect(axios.get).toHaveBeenCalledTimes(1);

    resolve({ status: 200, data: userTablePayload });
    await Promise.all([firstPending, secondPending]);
    await flushPromises();

    expect(first.totalRows.value).toBe(2);
    expect(second.totalRows.value).toBe(2);
    expect(first.isBusy.value).toBe(false);
    expect(second.isBusy.value).toBe(false);
  });

  it('an out-of-order stale response does not apply over the newer request', async () => {
    const axios = await getAxiosMock();
    const resolvers: Array<(v: unknown) => void> = [];
    axios.get.mockImplementation(() => new Promise((res) => resolvers.push(res)));
    const data = useUserData();
    const p1 = data.loadDataNow(); // P1 (default params)
    data.perPage.value = 50; // params change → P2 differs
    const p2 = data.loadDataNow(); // P2 (latest)
    // resolve the newer P2 first, then the stale P1 LAST
    resolvers[1]({
      status: 200,
      data: { ...userTablePayload, meta: [{ ...userTablePayload.meta[0], totalItems: 99 }] },
    });
    await p2;
    await flushPromises();
    resolvers[0]({ status: 200, data: userTablePayload }); // stale P1 (totalItems 2)
    await p1;
    await flushPromises();
    expect(data.totalRows.value).toBe(99); // P2 retained; stale P1 ignored
  });

  it('the 500ms cache never serves a response cached under different params', async () => {
    const axios = await getAxiosMock();
    axios.get.mockResolvedValueOnce({ status: 200, data: userTablePayload }); // P1: totalItems 2
    const data = useUserData();
    await data.loadDataNow();
    await flushPromises();
    expect(data.totalRows.value).toBe(2);

    data.perPage.value = 50; // params → P2
    let resolveB!: (v: unknown) => void;
    axios.get.mockImplementationOnce(() => new Promise((res) => (resolveB = res)));
    const pB = data.loadDataNow(); // P2 in flight
    data.totalRows.value = 999; // sentinel — a wrong cache-serve would overwrite this
    const sharedP2 = data.loadDataNow(); // 2nd identical P2 subscribes while pending
    await Promise.resolve();
    expect(data.totalRows.value).toBe(999); // must NOT serve P1's cached response for P2

    resolveB({
      status: 200,
      data: { ...userTablePayload, meta: [{ ...userTablePayload.meta[0], totalItems: 7 }] },
    });
    await Promise.all([pB, sharedP2]);
    await flushPromises();
    expect(data.totalRows.value).toBe(7); // the real P2 response applies
  });

  it('a response arriving after dispose() does not apply', async () => {
    const axios = await getAxiosMock();
    let resolve!: (v: unknown) => void;
    axios.get.mockImplementation(() => new Promise((res) => (resolve = res)));
    const data = useUserData();
    const p = data.loadDataNow();
    data.totalRows.value = 555; // sentinel
    data.dispose(); // simulate unmount/navigation
    resolve({
      status: 200,
      data: { ...userTablePayload, meta: [{ ...userTablePayload.meta[0], totalItems: 42 }] },
    });
    await p;
    await flushPromises();
    expect(data.totalRows.value).toBe(555); // disposed → late response ignored
  });

  it('A-B-A reuses the original keyed A transport for the current A intent', async () => {
    // A keyed transport is a valid shared result for a later identical intent. The
    // map must subscribe A2 to A1 rather than launching a duplicate A2 request.
    const axios = await getAxiosMock();
    const resolvers: Array<(v: unknown) => void> = [];
    axios.get.mockImplementation(() => new Promise((res) => resolvers.push(res)));
    const data = useUserData();

    const pA1 = data.loadDataNow(); // A1 (default params) — resolvers[0]
    data.perPage.value = 50;
    const pB = data.loadDataNow(); // B (params B) — resolvers[1]
    data.perPage.value = 25; // back to default params A
    const pA2 = data.loadDataNow(); // A2 subscribes to A1 (same params)

    expect(resolvers).toHaveLength(2); // A1 + B only; no duplicate A2 transport
    resolvers[0]({
      status: 200,
      data: { ...userTablePayload, meta: [{ ...userTablePayload.meta[0], totalItems: 77 }] },
    });
    await Promise.all([pA1, pA2]);
    await flushPromises();

    // The current A intent received the shared A transport and recorded it for cache.
    await data.loadDataNow();
    await flushPromises();
    expect(data.totalRows.value).toBe(77);

    // let B settle so no timer/promise leaks into the next test
    resolvers[1]({ status: 200, data: userTablePayload });
    await pB;
    await flushPromises();
    data.dispose();
  });

  it('a stale shared rejection cannot clear a newer keyed slot or busy state', async () => {
    const axios = await getAxiosMock();
    const pending: Array<{ resolve: (v: unknown) => void; reject: (e: unknown) => void }> = [];
    axios.get.mockImplementation(
      () =>
        new Promise((resolve, reject) => {
          pending.push({ resolve, reject });
        })
    );
    const staleToasts: unknown[][] = [];
    const currentToasts: unknown[][] = [];
    const stale = useUserData({ onToast: (...args) => staleToasts.push(args) });
    const current = useUserData({ onToast: (...args) => currentToasts.push(args) });

    const staleA = stale.loadDataNow();
    const currentA = current.loadDataNow(); // shared A transport
    stale.perPage.value = 50;
    const staleB = stale.loadDataNow(); // independent B transport

    pending[0].reject(new Error('obsolete A'));
    await Promise.allSettled([staleA, currentA]);
    await flushPromises();

    expect(staleToasts).toEqual([]); // stale A was superseded by B
    expect(currentToasts).toHaveLength(1); // current shared A receives its failure
    expect(stale.isBusy.value).toBe(true); // stale A finally did not clear B's spinner

    pending[1].resolve({ status: 200, data: userTablePayload });
    await staleB;
    await flushPromises();
    expect(stale.totalRows.value).toBe(2);
    expect(stale.isBusy.value).toBe(false);
    stale.dispose();
    current.dispose();
  });

  it('A→B→cached-A does not leave isBusy stuck true', async () => {
    const axios = await getAxiosMock();
    const resolvers: Array<(v: unknown) => void> = [];
    axios.get.mockImplementation(() => new Promise((res) => resolvers.push(res)));
    const data = useUserData();
    const pA = data.loadDataNow(); // A (default params) in flight
    data.perPage.value = 50;
    const pB = data.loadDataNow(); // B in flight
    // stale A completes while B is pending → caches A's response
    resolvers[0]({ status: 200, data: userTablePayload });
    await pA;
    await flushPromises();
    // switch back to A (served from the <500ms cache)
    data.perPage.value = 25;
    await data.loadDataNow();
    await flushPromises();
    expect(data.isBusy.value).toBe(false); // cache hit cleared busy; not stuck from B
    // let B settle (superseded — must not resurrect busy)
    resolvers[1]({ status: 200, data: userTablePayload });
    await pB;
    await flushPromises();
    expect(data.isBusy.value).toBe(false);
    data.dispose();
  });
});
