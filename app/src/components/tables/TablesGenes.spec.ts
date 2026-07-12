// TablesGenes.spec.ts
/**
 * #346 Wave 2 — spec for the extracted `useGenesTable` controller consumed by
 * `components/tables/TablesGenes.vue`.
 *
 * Covers the controller's request/response/pagination/URL-sync contract:
 *   - initial URL state is applied before the first request fires
 *   - mounting issues exactly one initial GET /api/gene request
 *   - a stale (superseded) response never overwrites newer table state
 *   - cursor pagination keeps HGNC symbol cursors as STRINGS end-to-end
 *   - the API's `fspec` response replaces `fields` verbatim (flat array)
 *   - `withCurrentReturnTo` appends a `returnTo` query param on safe list
 *     routes (the /Genes/<symbol> and row-expansion /Entities/<id> links)
 *   - `requestExcel` downloads `sysndd_gene_table.xlsx` via the typed
 *     `listGenesXlsx` client (no injected Axios instance)
 *
 * `useGenesTable` no longer accepts an injected Axios instance — every
 * network call goes through the typed `@/api/genes` client, so this spec
 * exercises `/api/gene` through MSW rather than mocking an Axios instance.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import { server } from '@/test-utils/mocks/server';
import TablesGenes from './TablesGenes.vue';

const makeToastSpy = vi.fn();

vi.mock('@/composables', async () => {
  const actual = await vi.importActual<typeof import('@/composables')>('@/composables');
  return {
    ...actual,
    useToast: () => ({ makeToast: makeToastSpy }),
  };
});

interface GenesVm {
  doLoadData: () => Promise<void>;
  requestExcel: () => Promise<void>;
  copyLinkToClipboard: () => void;
  removeFilters: () => void;
  removeSearch: () => void;
  handlePageChange: (value: number) => void;
  withCurrentReturnTo: (path: string) => string;
  fields: Array<{ key: string; label: string }>;
  totalRows: number;
  totalPages: number;
  currentPage: number;
  currentItemID: number | string;
  nextItemID: number | string | null;
  sort: string;
  filter: Record<string, { content: unknown; operator: string; join_char: string | null }>;
  loadDataDebounceTimer: ReturnType<typeof setTimeout> | null;
  downloading: boolean;
}

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/', name: 'Home', component: { template: '<div />' } }],
  });
}

function geneListPayload(overrides: Record<string, unknown> = {}) {
  return {
    data: [{ symbol: 'ARID1B', hgnc_id: 'HGNC:18040', entities_count: 1, entities: [] }],
    meta: [
      {
        totalItems: 1,
        currentPage: 1,
        totalPages: 1,
        prevItemID: 'null',
        currentItemID: 0,
        nextItemID: 'null',
        lastItemID: 'null',
        executionTime: '0.01 secs',
        fspec: [
          { key: 'symbol', label: 'Gene Symbol', sortable: true, class: 'text-start' },
          { key: 'details', label: 'Details' },
        ],
        ...overrides,
      },
    ],
    links: [],
  };
}

// useGenesTable's request coordinator is intentionally MODULE-level (it must
// survive Vue Router remounts in production — see useGenesTable.ts). Inside
// this spec file the same module instance is shared across every test, so
// two tests mounting with identical sort/filter/page params within its
// ~500ms "recent response" cache window would otherwise silently reuse each
// other's cached response instead of hitting the per-test MSW handler. Give
// every mount a unique `pageSizeInput` (unless the test overrides it) so no
// two tests' request params can ever collide.
let mountCallIndex = 0;

async function mountTable(props: Record<string, unknown> = {}, waitForInitialLoad = true) {
  mountCallIndex += 1;
  setActivePinia(createPinia());
  const router = makeRouter();
  await router.push('/');
  await router.isReady();

  const wrapper = mount(TablesGenes, {
    props: { pageSizeInput: 20 + mountCallIndex, ...props },
    global: {
      plugins: [router],
      directives: { 'b-tooltip': {} },
      stubs: {
        BContainer: { template: '<div><slot /></div>' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        TableShell: {
          template:
            '<div><slot name="actions" /><slot name="toolbar" /><slot name="loading" /><slot /></div>',
        },
        TableLoadingState: { template: '<div data-testid="genes-skeleton" />' },
        TableSearchInput: { template: '<input />' },
        TablePaginationControls: { template: '<div />' },
        TableDownloadLinkCopyButtons: { template: '<div />' },
        GenesMobileRows: { template: '<div />' },
        BTable: { template: '<div class="b-table-stub" />' },
        BCard: { template: '<div><slot /></div>' },
        BButton: { template: '<button><slot /></button>' },
        BBadge: { template: '<span><slot /></span>' },
        BFormInput: { template: '<input />' },
        BFormSelect: { template: '<select><slot /></select>' },
        BFormSelectOption: { template: '<option><slot /></option>' },
        CategoryIcon: { template: '<span />' },
        NddIcon: { template: '<span />' },
        GeneBadge: { template: '<span class="gene-badge" />' },
        InheritanceBadge: { template: '<span class="inheritance-badge" />' },
        EntityBadge: { template: '<span class="entity-badge" />' },
        DiseaseBadge: { template: '<span class="disease-badge" />' },
      },
    },
  });
  if (waitForInitialLoad) {
    await flushPromises();
    // The initial load is debounced ~50ms (useGenesTable's loadData()); wait it
    // out so the mounted-component's first request has actually fired before
    // assertions run.
    await new Promise((resolve) => setTimeout(resolve, 75));
    await flushPromises();
  }
  return wrapper;
}

beforeEach(() => {
  makeToastSpy.mockClear();
  vi.stubEnv('VITE_API_URL', '');
  vi.stubEnv('VITE_URL', 'http://localhost:5173');
});

afterEach(() => {
  vi.unstubAllEnvs();
});

describe('TablesGenes — #346 Wave 2 useGenesTable controller', () => {
  // -------------------------------------------------------------------------
  // Initial URL state + exactly-one initial request
  // -------------------------------------------------------------------------

  it('does not schedule its initial request after immediate unmount', async () => {
    let requestCount = 0;
    server.use(
      http.get('/api/gene', () => {
        requestCount += 1;
        return HttpResponse.json(geneListPayload());
      })
    );

    const wrapper = await mountTable({}, false);
    wrapper.unmount();
    await new Promise((resolve) => setTimeout(resolve, 75));

    expect(requestCount).toBe(0);
  });

  it('applies sortInput/filterInput/pageAfterInput and issues exactly one initial request', async () => {
    let requestCount = 0;
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/gene', ({ request }) => {
        requestCount += 1;
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(geneListPayload());
      })
    );

    await mountTable({
      sortInput: '-symbol',
      filterInput: 'contains(symbol,GR)',
      pageAfterInput: 'HNRNPU',
      pageSizeInput: 25,
    });

    expect(requestCount).toBe(1);
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('sort')).toBe('-symbol');
    expect(q.get('filter')).toBe('contains(symbol,GR)');
    // The initial page_after cursor is the HGNC symbol string, not a number.
    expect(q.get('page_after')).toBe('HNRNPU');
    expect(q.get('page_size')).toBe('25');
  });

  it('does not fire a duplicate request from the filter/sortBy watchers during initialization', async () => {
    let requestCount = 0;
    server.use(
      http.get('/api/gene', () => {
        requestCount += 1;
        return HttpResponse.json(geneListPayload());
      })
    );

    // mountTable() already waits out the debounced initial load.
    await mountTable({ sortInput: '+symbol' });

    expect(requestCount).toBe(1);
  });

  // -------------------------------------------------------------------------
  // API fspec merge
  // -------------------------------------------------------------------------

  it('replaces fields with the API fspec array verbatim', async () => {
    server.use(
      http.get('/api/gene', () =>
        HttpResponse.json(
          geneListPayload({
            fspec: [
              { key: 'symbol', label: 'Gene Symbol', sortable: true, filterable: true },
              { key: 'category', label: 'Category', selectable: true },
            ],
          })
        )
      )
    );

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as GenesVm;

    expect(vm.fields).toEqual([
      { key: 'symbol', label: 'Gene Symbol', sortable: true, filterable: true },
      { key: 'category', label: 'Category', selectable: true },
    ]);
  });

  // -------------------------------------------------------------------------
  // Stale-response rejection
  // -------------------------------------------------------------------------

  it('rejects a stale response that resolves after a newer request has superseded it', async () => {
    let resolveFirst: (() => void) | null = null;
    const firstReady = new Promise<void>((resolve) => {
      resolveFirst = resolve;
    });

    server.use(
      http.get('/api/gene', async ({ request }) => {
        const sortParam = new URL(request.url).searchParams.get('sort');
        if (sortParam === '+symbol') {
          // First (initial-mount) request: block until told to resolve, so a
          // second request can supersede it before this one completes.
          await firstReady;
          return HttpResponse.json(geneListPayload({ totalItems: 111 }));
        }
        // Second (superseding) request resolves immediately.
        return HttpResponse.json(geneListPayload({ totalItems: 222 }));
      })
    );

    const wrapper = await mountTable({ sortInput: '+symbol' });
    const vm = wrapper.vm as unknown as GenesVm;

    // Let the debounced initial load fire and hit the (blocked) handler.
    await new Promise((resolve) => setTimeout(resolve, 75));

    // Supersede it: change sort and reload before the first request resolves.
    vm.sort = '-symbol';
    if (vm.loadDataDebounceTimer) clearTimeout(vm.loadDataDebounceTimer);
    await vm.doLoadData();
    await flushPromises();

    // The second (superseding) request already applied its data.
    expect(vm.totalRows).toBe(222);

    // Now let the first (stale) request resolve. Its data must be discarded
    // because doLoadData()'s isCurrent() check no longer matches (sort
    // changed underneath it).
    resolveFirst!();
    await flushPromises();

    expect(vm.totalRows).toBe(222);
  });

  // -------------------------------------------------------------------------
  // Cursor transitions (string symbol cursors)
  // -------------------------------------------------------------------------

  it('keeps HGNC symbol cursors as strings through handlePageChange', async () => {
    server.use(http.get('/api/gene', () => HttpResponse.json(geneListPayload())));

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as GenesVm;

    vm.currentPage = 1;
    vm.totalPages = 3;
    vm.nextItemID = 'HNRNPU';

    let observedPageAfter: string | null = null;
    server.use(
      http.get('/api/gene', ({ request }) => {
        observedPageAfter = new URL(request.url).searchParams.get('page_after');
        // Mirror the real backend's generate_cursor_pag_inf(), which echoes
        // the requested page_after back as the response's currentItemID.
        return HttpResponse.json(geneListPayload({ currentItemID: observedPageAfter }));
      })
    );

    vm.handlePageChange(2);
    await new Promise((resolve) => setTimeout(resolve, 75));
    await flushPromises();

    expect(vm.currentItemID).toBe('HNRNPU');
    expect(typeof vm.currentItemID).toBe('string');
    expect(observedPageAfter).toBe('HNRNPU');
  });

  it('resets to the numeric 0 cursor when navigating to page 1', async () => {
    server.use(http.get('/api/gene', () => HttpResponse.json(geneListPayload())));

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as GenesVm;
    vm.currentItemID = 'ARID1B';

    vm.handlePageChange(1);
    await new Promise((resolve) => setTimeout(resolve, 75));
    await flushPromises();

    expect(vm.currentItemID).toBe(0);
  });

  // -------------------------------------------------------------------------
  // Filter helpers
  // -------------------------------------------------------------------------

  it('removeFilters clears every field and reloads', async () => {
    let lastFilterParam: string | null = null;
    server.use(
      http.get('/api/gene', ({ request }) => {
        lastFilterParam = new URL(request.url).searchParams.get('filter');
        return HttpResponse.json(geneListPayload());
      })
    );

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as GenesVm;
    vm.filter.symbol.content = 'ARID';
    vm.filter.any.content = 'search text';

    vm.removeFilters();
    await new Promise((resolve) => setTimeout(resolve, 75));
    await flushPromises();

    expect(vm.filter.symbol.content).toBeNull();
    expect(vm.filter.any.content).toBeNull();
    expect(lastFilterParam).toBe('');
  });

  it('removeSearch only clears the "any" field, preserving other active filters', async () => {
    server.use(http.get('/api/gene', () => HttpResponse.json(geneListPayload())));

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as GenesVm;
    vm.filter.symbol.content = 'ARID';
    vm.filter.any.content = 'search text';

    vm.removeSearch();
    // removeSearch() triggers a debounced reload; let it settle so no timer
    // is left dangling into the next test.
    await new Promise((resolve) => setTimeout(resolve, 75));
    await flushPromises();

    expect(vm.filter.any.content).toBeNull();
    expect(vm.filter.symbol.content).toBe('ARID');
  });

  // -------------------------------------------------------------------------
  // Return links (withCurrentReturnTo)
  // -------------------------------------------------------------------------

  it('withCurrentReturnTo appends returnTo when the current location is a safe list route', async () => {
    server.use(http.get('/api/gene', () => HttpResponse.json(geneListPayload())));
    window.history.pushState({}, '', '/Genes?sort=%2Bsymbol&page_size=10');

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as GenesVm;

    // Read the location dynamically rather than hardcoding it: the mounted
    // table's own updateBrowserUrl() may have rewritten the query string
    // (pathname stays /Genes either way, which is what makes it "safe").
    const expectedReturnTo = `${window.location.pathname}${window.location.search}`;
    const link = vm.withCurrentReturnTo('/Genes/HGNC:18040');
    expect(link).toBe(`/Genes/HGNC:18040?returnTo=${encodeURIComponent(expectedReturnTo)}`);
  });

  it('withCurrentReturnTo returns the bare path when the current location is not a known list route', async () => {
    server.use(http.get('/api/gene', () => HttpResponse.json(geneListPayload())));
    window.history.pushState({}, '', '/SomeOtherPage');

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as GenesVm;

    expect(vm.withCurrentReturnTo('/Genes/HGNC:18040')).toBe('/Genes/HGNC:18040');
  });

  // -------------------------------------------------------------------------
  // XLSX export (filename + typed listGenesXlsx, no injected Axios)
  // -------------------------------------------------------------------------

  it('requestExcel downloads sysndd_gene_table.xlsx via the typed listGenesXlsx client', async () => {
    let exportQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/gene', ({ request }) => {
        const query = new URL(request.url).searchParams;
        if (query.get('format') === 'xlsx') {
          exportQuery = query;
          return new HttpResponse(new Uint8Array([0x50, 0x4b, 0x03, 0x04]), {
            status: 200,
            headers: {
              'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            },
          });
        }
        return HttpResponse.json(geneListPayload());
      })
    );

    const createSpy = vi.spyOn(URL, 'createObjectURL').mockReturnValue('blob:mock-genes');
    const revokeSpy = vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {});
    let downloadedFilename: string | null = null;
    const clickSpy = vi.fn();
    const createElementSpy = vi.spyOn(document, 'createElement').mockImplementation(((
      tagName: string
    ) => {
      const element = document.createElementNS(
        'http://www.w3.org/1999/xhtml',
        tagName
      ) as HTMLAnchorElement;
      if (tagName === 'a') {
        element.click = clickSpy;
        const originalSetAttribute = element.setAttribute.bind(element);
        element.setAttribute = (name: string, value: string) => {
          if (name === 'download') downloadedFilename = value;
          return originalSetAttribute(name, value);
        };
      }
      return element;
    }) as typeof document.createElement);

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as GenesVm;

    await vm.requestExcel();
    await flushPromises();

    expect((exportQuery as unknown as URLSearchParams).get('format')).toBe('xlsx');
    expect((exportQuery as unknown as URLSearchParams).get('page_after')).toBe('0');
    expect((exportQuery as unknown as URLSearchParams).get('page_size')).toBe('all');
    expect(downloadedFilename).toBe('sysndd_gene_table.xlsx');
    expect(clickSpy).toHaveBeenCalled();

    createSpy.mockRestore();
    revokeSpy.mockRestore();
    createElementSpy.mockRestore();
  });

  it('toasts an error and resets downloading state when the export request fails', async () => {
    server.use(
      http.get('/api/gene', ({ request }) => {
        const url = new URL(request.url);
        if (url.searchParams.get('format') === 'xlsx') {
          return HttpResponse.json({ error: 'boom' }, { status: 500 });
        }
        return HttpResponse.json(geneListPayload());
      })
    );

    const wrapper = await mountTable();
    const vm = wrapper.vm as unknown as GenesVm;

    await vm.requestExcel();
    await flushPromises();

    expect(makeToastSpy).toHaveBeenCalledWith(expect.anything(), 'Error', 'danger');
    expect(vm.downloading).toBe(false);
  });

  // -------------------------------------------------------------------------
  // copyLinkToClipboard
  // -------------------------------------------------------------------------

  it('copyLinkToClipboard writes the current sort/filter/page state to the clipboard', async () => {
    server.use(http.get('/api/gene', () => HttpResponse.json(geneListPayload())));
    const writeTextSpy = vi.fn().mockResolvedValue(undefined);
    Object.assign(navigator, { clipboard: { writeText: writeTextSpy } });

    // page_size is asserted below, so pin it explicitly rather than taking
    // mountTable()'s auto-assigned unique value.
    const wrapper = await mountTable({ sortInput: '+symbol', pageSizeInput: 10 });
    const vm = wrapper.vm as unknown as GenesVm;

    vm.copyLinkToClipboard();

    expect(writeTextSpy).toHaveBeenCalledWith(
      expect.stringContaining('sort=+symbol&filter=&page_after=0&page_size=10')
    );
  });
});
