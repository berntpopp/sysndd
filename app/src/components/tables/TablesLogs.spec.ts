// TablesLogs.spec.ts
/**
 * v11.0 closeout F2b — spec for `components/tables/TablesLogs.vue`.
 *
 * Four authed endpoints now route through `apiClient.raw.*`:
 *
 *   - GET    /api/user/list   (`loadUserList`)
 *   - GET    /api/logs/       (`doLoadData` — main table)
 *   - GET    /api/logs/       (`requestExcel` — blob response)
 *   - DELETE /api/logs/       (`deleteLogs`)
 *
 * Each previously stamped its own
 * `Authorization: Bearer ${localStorage.getItem('token')}` header. This
 * spec pins the apiClient interceptor injection with
 * `primeAuth() + expectBearerHeader()`.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import axios from '@/plugins/axios';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import { useAuth } from '@/composables/useAuth';
import TablesLogs from './TablesLogs.vue';

const makeToastSpy = vi.fn();

vi.mock('@/composables', async () => {
  const { ref, computed } = await import('vue');
  return {
    useToast: () => ({ makeToast: makeToastSpy }),
    useUrlParsing: () => ({
      filterObjToStr: () => '',
      filterStrToObj: (_s: string, o: unknown) => o,
      sortStringToVariables: () => ({ sortBy: [] }),
    }),
    useColorAndSymbols: () => ({}),
    useText: () => ({ truncate: (s: string) => s }),
    useTableData: () => ({
      items: ref([]),
      loading: ref(false),
      downloading: ref(false),
      currentPage: ref(1),
      perPage: ref(10),
      totalRows: ref(0),
      sort: ref('-id'),
      sortBy: ref([]),
      filter_string: ref(''),
      currentItemID: ref(0),
      prevItemID: ref(0),
      nextItemID: ref(0),
      lastItemID: ref(0),
      executionTime: ref(0),
      pageOptions: ref([10]),
      isBusy: ref(false),
      totalPages: computed(() => 0),
    }),
    useTableMethods: () => ({}),
  };
});

interface LogsVm {
  loadUserList: () => Promise<void>;
  doLoadData: () => Promise<void>;
  requestExcel: () => Promise<void>;
  deleteLogs: () => Promise<void>;
  deleteMode: string;
  totalRows: number;
  user_options: unknown[];
  isBusy: boolean;
  isInitializing: boolean;
  sort: string;
  loadDataDebounceTimer: ReturnType<typeof setTimeout> | null;
}

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/', name: 'Home', component: { template: '<div />' } }],
  });
}

async function mountTable() {
  setActivePinia(createPinia());
  const router = makeRouter();
  await router.push('/');
  await router.isReady();

  const wrapper = mount(TablesLogs, {
    global: {
      plugins: [router],
      mocks: { axios },
      provide: { axios },
      directives: { 'b-tooltip': {}, 'b-toggle': {} },
      stubs: {
        TableHeaderLabel: { template: '<div />' },
        TableSearchInput: { template: '<div />' },
        TablePaginationControls: { template: '<div />' },
        TableDownloadLinkCopyButtons: { template: '<div />' },
        GenericTable: { template: '<div />' },
        LogDetailDrawer: { template: '<div />' },
        BContainer: { template: '<div><slot /></div>' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BCard: { template: '<div><slot name="header" /><slot /></div>' },
        BBadge: { template: '<span><slot /></span>' },
        BButton: { template: '<button><slot /></button>' },
        BSpinner: { template: '<div />' },
        BFormInput: { template: '<input />' },
        BFormSelect: { template: '<select />' },
        BInputGroup: { template: '<div><slot /></div>' },
        BInputGroupText: { template: '<span><slot /></span>' },
        BModal: { template: '<div><slot /></div>' },
        BFormGroup: { template: '<div><slot /></div>' },
      },
    },
  });
  await flushPromises();
  return wrapper;
}

beforeEach(() => {
  makeToastSpy.mockClear();
  vi.stubEnv('VITE_API_URL', '');
});

afterEach(() => {
  useAuth().logout();
  vi.unstubAllEnvs();
});

describe('TablesLogs — v11.0 closeout F2b apiClient migration', () => {
  it('loadUserList issues GET /api/user/list with the Bearer header', async () => {
    primeAuth('logs-users-token');

    server.use(
      http.get('/api/user/list', ({ request }) => {
        expectBearerHeader(request, 'logs-users-token');
        return HttpResponse.json([{ user_name: 'alice', user_role: 'Administrator' }]);
      }),
      http.get('/api/logs/', () =>
        HttpResponse.json({ data: [], meta: [{ totalItems: 0, currentPage: 1, totalPages: 1 }] })
      )
    );

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as LogsVm;
    await vm.loadUserList();
    await flushPromises();
    expect(vm.user_options).toEqual([{ value: 'alice', text: 'alice (Administrator)' }]);
  });

  it('doLoadData issues GET /api/logs/ with the Bearer header', async () => {
    primeAuth('logs-data-token');

    server.use(
      http.get('/api/user/list', () => HttpResponse.json([])),
      http.get('/api/logs/', ({ request }) => {
        expectBearerHeader(request, 'logs-data-token');
        return HttpResponse.json({
          data: [],
          meta: [
            {
              totalItems: 0,
              currentPage: 1,
              totalPages: 1,
              prevItemID: 0,
              currentItemID: 0,
              nextItemID: 0,
              lastItemID: 0,
              executionTime: 5,
            },
          ],
        });
      })
    );

    const wrapper = await mountTable();
    await (wrapper.vm as unknown as LogsVm).doLoadData();
    await flushPromises();
  });

  it('shows an inline loading state while logs are loading', async () => {
    primeAuth('logs-loading-token');

    server.use(
      http.get('/api/user/list', () => HttpResponse.json([])),
      http.get('/api/logs/', () =>
        HttpResponse.json({ data: [], meta: [{ totalItems: 0, currentPage: 1, totalPages: 1 }] })
      )
    );

    const wrapper = await mountTable();
    (wrapper.vm as unknown as LogsVm).isBusy = true;
    await flushPromises();

    expect(wrapper.get('[data-testid="logs-loading-state"]').text()).toContain('Loading logs');
  });

  it('requestExcel issues GET /api/logs/?format=xlsx with the Bearer header', async () => {
    primeAuth('logs-excel-token');

    let sawBearer = false;
    server.use(
      http.get('/api/user/list', () => HttpResponse.json([])),
      http.get('/api/logs/', ({ request }) => {
        const url = new URL(request.url);
        // The excel path passes `format=xlsx`; the data path does not.
        if (url.searchParams.get('format') === 'xlsx') {
          expectBearerHeader(request, 'logs-excel-token');
          sawBearer = true;
          return new HttpResponse(new Blob(['xlsx bytes']));
        }
        return HttpResponse.json({ data: [], meta: [{ totalItems: 0 }] });
      })
    );

    // Stub URL.createObjectURL — jsdom does not implement it.
    const createSpy = vi.spyOn(URL, 'createObjectURL').mockReturnValue('blob:mock');
    const revokeSpy = vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {});

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as LogsVm;
    vm.totalRows = 100;
    await vm.requestExcel();
    await flushPromises();

    createSpy.mockRestore();
    revokeSpy.mockRestore();

    expect(sawBearer).toBe(true);
  });

  it('deleteLogs issues DELETE /api/logs/ with the Bearer header', async () => {
    primeAuth('logs-delete-token');

    let sawBearer = false;
    server.use(
      http.get('/api/user/list', () => HttpResponse.json([])),
      http.delete('/api/logs/', ({ request }) => {
        expectBearerHeader(request, 'logs-delete-token');
        sawBearer = true;
        return HttpResponse.json({ deleted_count: 3 });
      }),
      http.get('/api/logs/', () =>
        HttpResponse.json({ data: [], meta: [{ totalItems: 0, currentPage: 1, totalPages: 1 }] })
      )
    );

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as LogsVm;
    vm.deleteMode = 'all';
    await vm.deleteLogs();
    await flushPromises();

    expect(sawBearer).toBe(true);
  });

  it('updates the browser URL only after a successful fresh logs response', async () => {
    primeAuth('logs-url-success-token');
    let resolveLogs: () => void;
    const logsReady = new Promise<void>((resolve) => {
      resolveLogs = resolve;
    });

    server.use(
      http.get('/api/user/list', () => HttpResponse.json([])),
      http.get('/api/logs/', async () => {
        await logsReady;
        return HttpResponse.json({
          data: [],
          meta: [
            {
              totalItems: 0,
              currentPage: 1,
              totalPages: 1,
              prevItemID: 0,
              currentItemID: 0,
              nextItemID: 0,
              lastItemID: 0,
              executionTime: 5,
            },
          ],
        });
      })
    );

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as LogsVm;
    if (vm.loadDataDebounceTimer) {
      clearTimeout(vm.loadDataDebounceTimer);
      vm.loadDataDebounceTimer = null;
    }
    vm.isInitializing = false;
    vm.sort = '-timestamp';
    const replaceStateSpy = vi.spyOn(window.history, 'replaceState').mockImplementation(() => {});

    const loadPromise = vm.doLoadData();
    await Promise.resolve();

    expect(replaceStateSpy).not.toHaveBeenCalled();

    resolveLogs!();
    await loadPromise;
    await flushPromises();

    expect(replaceStateSpy).toHaveBeenCalled();
    replaceStateSpy.mockRestore();
  });

  it('does not update the browser URL after a failed logs response', async () => {
    primeAuth('logs-url-failure-token');

    server.use(
      http.get('/api/user/list', () => HttpResponse.json([])),
      http.get('/api/logs/', () => HttpResponse.json({ error: 'INVALID_FILTER' }, { status: 400 }))
    );

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as LogsVm;
    if (vm.loadDataDebounceTimer) {
      clearTimeout(vm.loadDataDebounceTimer);
      vm.loadDataDebounceTimer = null;
    }
    vm.isInitializing = false;
    vm.sort = '+timestamp';
    const replaceStateSpy = vi.spyOn(window.history, 'replaceState').mockImplementation(() => {});

    await vm.doLoadData();
    await flushPromises();

    expect(replaceStateSpy).not.toHaveBeenCalled();
    replaceStateSpy.mockRestore();
  });
});
