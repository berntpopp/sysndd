// usePubtatorPublicationTable.spec.ts
//
// Composable-level characterization of the request/cache orchestration
// extracted from PubtatorNDDTable.vue: exact query parameters, the
// stale-response guard, all four cursor-pagination transitions, the shared
// bounded annotated-publication parse-cache reuse, stable details-field
// merge, the Excel export filename, and the copy-link URL.

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { defineComponent } from 'vue';
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';

import {
  usePubtatorPublicationTable,
  PUBTATOR_TABLE_XLSX_FILENAME,
  type UsePubtatorPublicationTableProps,
} from './usePubtatorPublicationTable';

const makeToastSpy = vi.fn();

vi.mock('@/composables', async () => {
  const actual = await vi.importActual<typeof import('@/composables')>('@/composables');
  return {
    ...actual,
    // Real bootstrap-vue-next toast requires its plugin; stub it like the
    // sibling table specs (AnalysesCurationComparisonsTable.spec.ts, etc).
    useToast: () => ({ makeToast: makeToastSpy }),
  };
});

const listPubtatorTable = vi.fn();
const listPubtatorTableXlsx = vi.fn();
vi.mock('@/api/publication', () => ({
  listPubtatorTable: (...args: unknown[]) => listPubtatorTable(...args),
  listPubtatorTableXlsx: (...args: unknown[]) => listPubtatorTableXlsx(...args),
}));

type Api = ReturnType<typeof usePubtatorPublicationTable>;

interface PubtatorRow {
  search_id: number;
  pmid: number;
  title: string;
  [key: string]: unknown;
}

function makeResponse(
  pmids: number[],
  metaOverrides: Record<string, unknown> = {}
): { data: PubtatorRow[]; meta: Array<Record<string, unknown>> } {
  return {
    data: pmids.map((pmid, index) => ({ search_id: index + 1, pmid, title: `Title ${pmid}` })),
    meta: [
      {
        totalItems: pmids.length,
        currentPage: 1,
        totalPages: 1,
        prevItemID: 0,
        currentItemID: 0,
        nextItemID: 0,
        lastItemID: 0,
        executionTime: 1,
        fspec: [],
        ...metaOverrides,
      },
    ],
  };
}

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/analyses/pubtator-table', component: { template: '<div />' } }],
  });
}

const mountedWrappers: VueWrapper[] = [];

async function mountComposable(
  props: UsePubtatorPublicationTableProps = {}
): Promise<{ wrapper: VueWrapper; api: Api }> {
  setActivePinia(createPinia());
  const router = makeRouter();
  await router.push('/analyses/pubtator-table');
  await router.isReady();

  let api!: Api;
  const Host = defineComponent({
    setup() {
      api = usePubtatorPublicationTable({
        sortInput: '-search_id',
        filterInput: null,
        pageAfterInput: '0',
        pageSizeInput: 10,
        fspecInput: 'search_id,pmid,doi,title,journal,date,score,gene_symbols,text_hl',
        ...props,
      });
      return api;
    },
    template: '<div />',
  });

  const wrapper = mount(Host, { global: { plugins: [router] } });
  mountedWrappers.push(wrapper);
  await flushPromises();
  return { wrapper, api };
}

beforeEach(() => {
  makeToastSpy.mockClear();
  listPubtatorTable.mockReset();
  listPubtatorTableXlsx.mockReset();
  listPubtatorTable.mockResolvedValue(makeResponse([]));
  vi.stubEnv('VITE_URL', 'https://sysndd.test');
});

afterEach(() => {
  mountedWrappers.splice(0).forEach((wrapper) => wrapper.unmount());
  vi.unstubAllEnvs();
  vi.restoreAllMocks();
});

describe('usePubtatorPublicationTable', () => {
  it('loads initial data with the exact sort/filter/cursor query parameters', async () => {
    const { api } = await mountComposable({ fspecInput: 'search_id,pmid,title' });

    expect(listPubtatorTable).toHaveBeenCalledWith({
      sort: '-search_id',
      filter: '',
      page_after: '0',
      page_size: '10',
      fields: 'search_id,pmid,title',
    });
    expect(api.totalRows.value).toBe(0);
    expect(api.isBusy.value).toBe(false);
  });

  it('discards a stale earlier response so it cannot overwrite the current one', async () => {
    const { api } = await mountComposable();

    let resolvers: Array<(value: unknown) => void> = [];
    listPubtatorTable.mockReset();
    listPubtatorTable.mockImplementation(
      () =>
        new Promise((resolve) => {
          resolvers.push(resolve);
        })
    );

    // Fire an earlier (STALE) load, then a newer (CURRENT) load.
    void api.loadTableData();
    void api.loadTableData();
    expect(resolvers).toHaveLength(2);

    // CURRENT (second/newer) resolves first.
    resolvers[1](makeResponse([111]));
    await flushPromises();
    expect(api.items.value.map((row) => (row as PubtatorRow).pmid)).toEqual([111]);
    expect(api.isBusy.value).toBe(false);

    // STALE (first/older) resolves later — must be dropped, not applied.
    resolvers[0](makeResponse([222, 333]));
    await flushPromises();
    expect(api.items.value.map((row) => (row as PubtatorRow).pmid)).toEqual([111]);
    resolvers = [];
  });

  it('drops a stale error too — a superseded failure must not toast or flip isBusy', async () => {
    const { api } = await mountComposable();

    let resolvers: Array<{ resolve: (v: unknown) => void; reject: (e: unknown) => void }> = [];
    listPubtatorTable.mockReset();
    listPubtatorTable.mockImplementation(
      () =>
        new Promise((resolve, reject) => {
          resolvers.push({ resolve, reject });
        })
    );

    void api.loadTableData(); // STALE
    void api.loadTableData(); // CURRENT
    makeToastSpy.mockClear();

    resolvers[1].resolve(makeResponse([999]));
    await flushPromises();
    expect(api.items.value.map((row) => (row as PubtatorRow).pmid)).toEqual([999]);

    resolvers[0].reject(new Error('stale upstream failure'));
    await flushPromises();
    expect(makeToastSpy).not.toHaveBeenCalled();
    expect(api.items.value.map((row) => (row as PubtatorRow).pmid)).toEqual([999]);
    resolvers = [];
  });

  it('computes all four cursor-pagination transitions', async () => {
    const { api } = await mountComposable();
    await flushPromises();

    // 1) first page -> reset cursor to 0.
    api.currentPage.value = 3;
    api.handlePageChange(1);
    expect(api.currentItemID.value).toBe(0);
    await flushPromises();

    // 2) last page -> lastItemID.
    api.totalPages.value = 5;
    api.currentPage.value = 3;
    api.lastItemID.value = 99;
    api.handlePageChange(5);
    expect(api.currentItemID.value).toBe(99);
    await flushPromises();

    // 3) next page (value > currentPage) -> nextItemID.
    api.currentPage.value = 3;
    api.nextItemID.value = 40;
    api.handlePageChange(4);
    expect(api.currentItemID.value).toBe(40);
    await flushPromises();

    // 4) previous page (value < currentPage) -> prevItemID.
    api.currentPage.value = 3;
    api.prevItemID.value = 20;
    api.handlePageChange(2);
    expect(api.currentItemID.value).toBe(20);
    await flushPromises();
  });

  it('reuses the shared bounded parse cache — repeated calls return the identical array', async () => {
    const { api } = await mountComposable();
    const text = '@GENE_1 @GENE_MECP2 @@@MECP2@@@ causes disease.';

    const first = api.parseAnnotations(text);
    const second = api.parseAnnotations(text);

    expect(second).toBe(first);
  });

  it('shares the parse cache across composable instances (module-level, not per-instance)', async () => {
    const { api: apiA } = await mountComposable();
    const { api: apiB } = await mountComposable();
    const text = 'a distinct shared-cache probe string';

    const a = apiA.parseAnnotations(text);
    const b = apiB.parseAnnotations(text);

    expect(b).toBe(a);
  });

  it('forces filterable on inbound fields and pins a stable details column at the end', async () => {
    const { api } = await mountComposable();
    const inbound = [
      { key: 'search_id', label: 'Search ID', sortable: true, class: 'text-start', filterable: false },
      { key: 'pmid', label: 'PMID', sortable: true, class: 'text-start' },
    ];

    const merged = api.mergeFields(inbound);

    expect(merged.map((f) => f.key)).toEqual(['search_id', 'pmid', 'details']);
    expect(merged.filter((f) => f.key !== 'details').every((f) => f.filterable === true)).toBe(
      true
    );
    const details = merged.find((f) => f.key === 'details');
    expect(details).toMatchObject({
      key: 'details',
      label: 'Details',
      sortable: false,
      filterable: false,
      selectable: false,
      multi_selectable: false,
    });
  });

  it('merges fields stably across repeated calls (no duplication, same shape)', async () => {
    const { api } = await mountComposable();
    const inbound = [{ key: 'search_id', label: 'Search ID', sortable: true, class: 'text-start' }];

    const first = api.mergeFields(inbound);
    const second = api.mergeFields(inbound);

    expect(second).toEqual(first);
    expect(second.filter((f) => f.key === 'details')).toHaveLength(1);
  });

  it('exports via the exact filename and query parameters', async () => {
    const { api } = await mountComposable({ fspecInput: 'search_id,pmid' });
    await flushPromises();
    listPubtatorTableXlsx.mockResolvedValue(new Blob(['xlsx bytes']));

    const createObjectURLSpy = vi.spyOn(URL, 'createObjectURL').mockReturnValue('blob:mock-url');
    const realCreateElement = document.createElement.bind(document);
    let anchor: HTMLAnchorElement | null = null;
    vi.spyOn(document, 'createElement').mockImplementation((tag: string) => {
      const el = realCreateElement(tag);
      if (tag === 'a') anchor = el as HTMLAnchorElement;
      return el;
    });

    api.sort.value = '-search_id';
    api.filter_string.value = 'contains(title,MECP2)';
    await api.requestExcel();

    expect(listPubtatorTableXlsx).toHaveBeenCalledWith({
      sort: '-search_id',
      filter: 'contains(title,MECP2)',
      page_after: '0',
      page_size: 'all',
      fields: 'search_id,pmid',
    });
    expect(anchor?.getAttribute('download')).toBe(PUBTATOR_TABLE_XLSX_FILENAME);
    expect(anchor?.getAttribute('download')).toBe('publications.xlsx');
    expect(api.downloading.value).toBe(false);

    createObjectURLSpy.mockRestore();
  });

  it('toasts and resets downloading when the export request fails', async () => {
    const { api } = await mountComposable();
    await flushPromises();
    listPubtatorTableXlsx.mockRejectedValue(new Error('network down'));

    await api.requestExcel();

    expect(makeToastSpy).toHaveBeenCalledWith(expect.any(Error), 'Error downloading Excel', 'danger');
    expect(api.downloading.value).toBe(false);
  });

  it('copies a URL combining sort, filter, cursor, and page size, and toasts confirmation', async () => {
    const { api } = await mountComposable();
    await flushPromises();
    const writeText = vi.fn();
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText },
    });

    api.sort.value = '-search_id';
    api.filter_string.value = 'contains(title,MECP2)';
    api.currentItemID.value = 40;
    api.perPage.value = 25;

    api.copyLinkToClipboard();

    expect(writeText).toHaveBeenCalledTimes(1);
    const [url] = writeText.mock.calls[0];
    expect(url).toContain('sort=-search_id');
    expect(url).toContain('filter=contains(title,MECP2)');
    expect(url).toContain('page_after=40');
    expect(url).toContain('page_size=25');
    expect(url).toContain('/analyses/pubtator-table');
    expect(makeToastSpy).toHaveBeenCalledWith('Link copied to clipboard', 'Info', 'info');
  });

  it('reloads when the filter changes (deep watch) and resets on removeFilters', async () => {
    const { api } = await mountComposable();
    await flushPromises();
    listPubtatorTable.mockClear();

    api.filter.value.any.content = 'MECP2';
    await flushPromises();
    expect(listPubtatorTable).toHaveBeenCalledWith(
      expect.objectContaining({ filter: 'contains(any,MECP2)' })
    );

    listPubtatorTable.mockClear();
    api.removeFilters();
    await flushPromises();
    expect(api.filter.value.any.content).toBeNull();
    expect(listPubtatorTable).toHaveBeenCalledWith(expect.objectContaining({ filter: '' }));
  });

  it('reloads on a genuine sort change but not on a no-op sortBy update', async () => {
    const { api } = await mountComposable();
    await flushPromises();
    listPubtatorTable.mockClear();

    // No-op: same key/order as the current sort ('-search_id').
    api.sortBy.value = [{ key: 'search_id', order: 'desc' }];
    await flushPromises();
    expect(listPubtatorTable).not.toHaveBeenCalled();

    // Genuine change.
    api.sortBy.value = [{ key: 'pmid', order: 'asc' }];
    await flushPromises();
    expect(api.sort.value).toBe('+pmid');
    expect(listPubtatorTable).toHaveBeenCalledWith(expect.objectContaining({ sort: '+pmid' }));
  });
});
