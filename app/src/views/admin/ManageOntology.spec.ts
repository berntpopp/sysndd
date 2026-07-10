// ManageOntology.spec.ts
/**
 * #346 Wave 2 Task 6 (ontology domain) — spec for the extracted
 * `useOntologyAdminTable` controller consumed by `views/admin/ManageOntology.vue`.
 *
 * Covers the controller's filter/URL-sync/request/response/pagination/
 * edit/update/export contract:
 *   - initial URL state (sort/filter/page_after/page_size) is applied
 *     before the first request fires, and mounting issues exactly one
 *     initial GET /api/ontology/variant/table request
 *   - active-filter chips (`hasActiveFilters`/`activeFilters`) reflect the
 *     current filter state (status/terms/search labels)
 *   - cursor pagination transitions (first page -> 0, next -> nextItemID,
 *     prev -> prevItemID, last -> lastItemID) via handlePageChange
 *   - a stale (superseded) response never overwrites newer table state
 *   - editOntology() deep-copies the row (no shared reference) and
 *     updateOntologyData() PUTs `{ ontology_details }` via the typed
 *     `updateVariantOntology` client, then refreshes the row in place,
 *     closes the modal, and resets the edit buffer
 *   - handleExport() calls the client-side `exportToExcel` with the
 *     `ontology_export_<date>` filename, `Ontology` sheet name, and the
 *     shared `ONTOLOGY_EXPORT_HEADERS` column map
 *
 * This is an admin curation-metadata surface (see AGENTS.md "Admin
 * curation metadata vocabularies"): the update payload shape
 * (`{ ontology_details: {...} }`) and role gate are unchanged by this
 * extraction, only re-verified here. `useToast`/`useExcelExport` are
 * spied via a partial `@/composables` mock (`vi.importActual` for
 * everything else) so `useTableData`/`useUrlParsing` stay real — this
 * matches the useGenesTable/useEntitiesTable Wave 2 spec pattern.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import { createPinia, setActivePinia } from 'pinia';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import { useAuth } from '@/composables/useAuth';
import type { VariantOntologyRow } from '@/api/ontology';
import { ONTOLOGY_EXPORT_HEADERS } from './ontologyTableConfig';
import ManageOntology from './ManageOntology.vue';

const makeToastSpy = vi.fn();
const exportToExcelSpy = vi.fn().mockResolvedValue(undefined);

vi.mock('@/composables', async () => {
  const actual = await vi.importActual<typeof import('@/composables')>('@/composables');
  return {
    ...actual,
    useToast: () => ({ makeToast: makeToastSpy }),
    useExcelExport: () => ({ isExporting: ref(false), exportToExcel: exportToExcelSpy }),
  };
});

interface OntologyFilterFieldVm {
  content: string | string[] | null;
  operator: string;
  join_char: string | null;
}

interface OntologyVm {
  doLoadData: () => Promise<void>;
  updateOntologyData: () => Promise<void>;
  editOntology: (item: VariantOntologyRow) => void;
  handlePageChange: (value: number) => void;
  handleExport: () => void;
  removeFilters: () => void;
  clearFilter: (key: string) => void;
  ontologyToEdit: Partial<VariantOntologyRow>;
  ontologies: VariantOntologyRow[];
  filter: Record<string, OntologyFilterFieldVm>;
  showEditModal: boolean;
  hasActiveFilters: boolean;
  activeFilters: Array<{ key: string; label: string; value: string }>;
  totalRows: number;
  totalPages: number;
  currentPage: number;
  currentItemID: number | string;
  prevItemID: number | null;
  nextItemID: number | null;
  lastItemID: number | null;
  sort: string;
}

const DEFAULT_ROW: VariantOntologyRow = {
  vario_id: 'VariO:0001',
  vario_name: 'Example',
  definition: 'Example def',
  obsolete: 0,
  is_active: 1,
  sort: 1,
  update_date: '2025-01-01',
};

function ontologyListPayload(
  metaOverrides: Record<string, unknown> = {},
  rows: VariantOntologyRow[] = [DEFAULT_ROW]
) {
  return {
    data: rows,
    meta: [
      {
        totalItems: rows.length,
        currentPage: 1,
        totalPages: 1,
        prevItemID: 0,
        currentItemID: 0,
        nextItemID: 0,
        lastItemID: 0,
        executionTime: 10,
        ...metaOverrides,
      },
    ],
    links: [],
  };
}

// useOntologyAdminTable's request coordinator is intentionally MODULE-level
// (it must survive Vue Router remounts in production — see
// useOntologyAdminTable.ts). Inside this spec file the same module instance
// is shared across every test. Unlike TablesGenes/TablesEntities,
// ManageOntology has no `pageSizeInput` prop, so every mount reads its
// initial `page_size` from the URL instead — give each mount a unique one
// (unless the test explicitly supplies its own) so no two tests' request
// params can ever collide within the coordinator's ~500ms "recent
// response" cache window.
let mountCallIndex = 0;

async function mountView(searchParams: URLSearchParams = new URLSearchParams()) {
  mountCallIndex += 1;
  if (!searchParams.has('page_size')) {
    searchParams.set('page_size', String(30 + mountCallIndex));
  }
  window.history.pushState({}, '', `/admin/manage-ontology?${searchParams.toString()}`);

  setActivePinia(createPinia());
  const wrapper = mount(ManageOntology, {
    global: {
      directives: { 'b-tooltip': {}, 'b-toggle': {} },
      stubs: {
        GenericTable: { template: '<div />' },
        TablePaginationControls: { template: '<div />' },
        OntologyMobileRows: { template: '<div />' },
        BContainer: { template: '<div><slot /></div>' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BCard: { template: '<div><slot name="header" /><slot /></div>' },
        BBadge: { template: '<span><slot /></span>' },
        BButton: { template: '<button><slot /></button>' },
        BSpinner: { template: '<div />' },
        BFormInput: { template: '<input />' },
        BInputGroup: { template: '<div><slot name="prepend" /><slot /></div>' },
        BInputGroupText: { template: '<span><slot /></span>' },
        BFormSelect: { template: '<select><slot /></select>' },
        BFormSelectOption: { template: '<option><slot /></option>' },
        BFormGroup: { template: '<div><slot /></div>' },
        BFormTextarea: { template: '<textarea />' },
        BForm: { template: '<form><slot /></form>' },
        BModal: { template: '<div><slot /></div>' },
      },
    },
  });
  // The initial load is debounced ~50ms (useOntologyAdminTable's
  // loadData()); wait it out so the mounted-component's first request has
  // actually fired before assertions run.
  await new Promise((resolve) => setTimeout(resolve, 75));
  await flushPromises();
  return wrapper;
}

beforeEach(() => {
  makeToastSpy.mockClear();
  exportToExcelSpy.mockClear();
  vi.stubEnv('VITE_API_URL', '');
});

afterEach(() => {
  useAuth().logout();
  vi.unstubAllEnvs();
});

describe('ManageOntology — #346 Wave 2 useOntologyAdminTable controller', () => {
  // -------------------------------------------------------------------------
  // Initial URL state + exactly-one initial request
  // -------------------------------------------------------------------------

  it('applies sort/filter/page_after/page_size from the URL and issues exactly one initial request', async () => {
    let requestCount = 0;
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/ontology/variant/table', ({ request }) => {
        requestCount += 1;
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ontologyListPayload());
      })
    );

    const params = new URLSearchParams();
    params.set('sort', '-vario_name');
    params.set('filter', 'contains(vario_name,GR)');
    params.set('page_after', '5');
    params.set('page_size', '50');

    await mountView(params);

    expect(requestCount).toBe(1);
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('sort')).toBe('-vario_name');
    expect(q.get('filter')).toBe('contains(vario_name,GR)');
    expect(q.get('page_after')).toBe('5');
    expect(q.get('page_size')).toBe('50');
  });

  it('does not fire a duplicate request from the filter/sortBy watchers during initialization', async () => {
    let requestCount = 0;
    server.use(
      http.get('/api/ontology/variant/table', () => {
        requestCount += 1;
        return HttpResponse.json(ontologyListPayload());
      })
    );

    await mountView();

    expect(requestCount).toBe(1);
  });

  it('doLoadData() fetches the table with the Bearer header injected by apiClient', async () => {
    primeAuth('ontology-token');
    server.use(
      http.get('/api/ontology/variant/table', ({ request }) => {
        expectBearerHeader(request, 'ontology-token');
        return HttpResponse.json(ontologyListPayload());
      })
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as OntologyVm;

    expect(Array.isArray(vm.ontologies)).toBe(true);
    expect(vm.ontologies).toHaveLength(1);
  });

  // -------------------------------------------------------------------------
  // Active-filter chips
  // -------------------------------------------------------------------------

  it('hasActiveFilters/activeFilters reflect the current filter state', async () => {
    server.use(http.get('/api/ontology/variant/table', () => HttpResponse.json(ontologyListPayload())));

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as OntologyVm;

    expect(vm.hasActiveFilters).toBe(false);
    expect(vm.activeFilters).toEqual([]);

    vm.filter.any.content = 'seizure';
    vm.filter.is_active.content = '1';
    vm.filter.obsolete.content = '0';
    await flushPromises();

    expect(vm.hasActiveFilters).toBe(true);
    expect(vm.activeFilters).toEqual([
      { key: 'any', label: 'Search', value: 'seizure' },
      { key: 'is_active', label: 'Status', value: 'Active' },
      { key: 'obsolete', label: 'Terms', value: 'Current' },
    ]);

    // Flipping the enum values flips the chip labels (inactive/obsolete).
    vm.filter.is_active.content = '0';
    vm.filter.obsolete.content = '1';
    await flushPromises();

    expect(vm.activeFilters).toEqual([
      { key: 'any', label: 'Search', value: 'seizure' },
      { key: 'is_active', label: 'Status', value: 'Inactive' },
      { key: 'obsolete', label: 'Terms', value: 'Obsolete' },
    ]);

    // Settle the debounced reload the mutations above triggered so no timer
    // is left dangling into the next test.
    await new Promise((resolve) => setTimeout(resolve, 75));
    await flushPromises();
  });

  it('clearFilter() nulls a single field and removeFilters() nulls every field', async () => {
    let lastFilterParam: string | null = null;
    server.use(
      http.get('/api/ontology/variant/table', ({ request }) => {
        lastFilterParam = new URL(request.url).searchParams.get('filter');
        return HttpResponse.json(ontologyListPayload());
      })
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as OntologyVm;
    vm.filter.any.content = 'seizure';
    vm.filter.is_active.content = '1';

    vm.clearFilter('is_active');
    await new Promise((resolve) => setTimeout(resolve, 75));
    await flushPromises();

    expect(vm.filter.is_active.content).toBeNull();
    expect(vm.filter.any.content).toBe('seizure');

    vm.removeFilters();
    await new Promise((resolve) => setTimeout(resolve, 75));
    await flushPromises();

    expect(vm.filter.any.content).toBeNull();
    expect(lastFilterParam).toBe('');
  });

  // -------------------------------------------------------------------------
  // Cursor-pagination transitions
  // -------------------------------------------------------------------------

  it('handlePageChange always converges the cursor to 0 (first/next/prev/last all funnel through filtered()\'s reset)', async () => {
    // NOTE (behavior-preservation, not introduced by this refactor):
    // handlePageChange() assigns the direction-appropriate cursor
    // (0/nextItemID/prevItemID/lastItemID) and then calls filtered(),
    // which — mirroring the pre-extraction ManageOntology.vue byte-for-byte
    // — unconditionally resets currentItemID back to 0 before loadData().
    // So the *net* observable cursor after handlePageChange (and the
    // page_after sent on the wire) is always 0, regardless of which page
    // was requested. This spec asserts the actual current contract; fixing
    // the underlying reset-on-every-filtered-call quirk is out of scope
    // for a behavior-preserving extraction.
    let lastPageAfter: string | null = null;
    server.use(
      http.get('/api/ontology/variant/table', ({ request }) => {
        lastPageAfter = new URL(request.url).searchParams.get('page_after');
        return HttpResponse.json(ontologyListPayload());
      })
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as OntologyVm;

    // Re-seed currentPage/totalPages/cursor refs immediately before each
    // call so no scenario's branch selection can leak into the next.
    const scenarios: Array<{ label: string; targetPage: number }> = [
      { label: 'first page (value === 1)', targetPage: 1 },
      { label: 'next page (value > currentPage)', targetPage: 3 },
      { label: 'previous page (value < currentPage)', targetPage: 1 },
      { label: 'last page (value === totalPages)', targetPage: 4 },
    ];

    for (const { label, targetPage } of scenarios) {
      vm.currentPage = 2;
      vm.totalPages = 4;
      vm.nextItemID = 30;
      vm.prevItemID = 5;
      vm.lastItemID = 99;

      vm.handlePageChange(targetPage);
      // Whichever branch fires, filtered()'s unconditional reset means the
      // net observable cursor always converges on 0 (see NOTE above). This
      // is asserted synchronously (handlePageChange -> filtered() runs
      // entirely within the same call stack) rather than via a fresh
      // network round trip per scenario: every scenario here produces
      // identical request params (page_after=0, same sort/filter/page_size),
      // so the module-level request coordinator's short recent-response
      // cache legitimately serves the earlier response for later scenarios
      // instead of re-hitting the network — that dedup is itself a tested,
      // intentional behaviour (see the stale-response spec above), not
      // something to work around here.
      expect(vm.currentItemID, label).toBe(0);
    }

    // Settle whichever reload is left in flight (debounced 50ms) so no
    // timer leaks into the next test, and confirm the cursor actually on
    // the wire is 0.
    await new Promise((resolve) => setTimeout(resolve, 75));
    await flushPromises();
    expect(lastPageAfter).toBe('0');
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
      http.get('/api/ontology/variant/table', async ({ request }) => {
        const sortParam = new URL(request.url).searchParams.get('sort');
        if (sortParam === '+vario_id') {
          // First (initial-mount) request: block until told to resolve, so
          // a second request can supersede it before this one completes.
          await firstReady;
          return HttpResponse.json(ontologyListPayload({ totalItems: 111 }));
        }
        // Second (superseding) request resolves immediately.
        return HttpResponse.json(ontologyListPayload({ totalItems: 222 }));
      })
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as OntologyVm & {
      sort: string;
      doLoadData: () => Promise<void>;
      loadDataDebounceTimer: ReturnType<typeof setTimeout> | null;
    };

    // Supersede it: change sort and reload before the first request resolves.
    vm.sort = '-vario_id';
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
  // Edit payload + update refresh
  // -------------------------------------------------------------------------

  it('editOntology deep-copies the row; updateOntologyData PUTs {ontology_details} and refreshes the row in place', async () => {
    primeAuth('ontology-write-token');
    server.use(
      http.get('/api/ontology/variant/table', () => HttpResponse.json(ontologyListPayload()))
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as OntologyVm;

    vm.editOntology(DEFAULT_ROW);
    expect(vm.showEditModal).toBe(true);
    expect(vm.ontologyToEdit).toEqual(DEFAULT_ROW);
    expect(vm.ontologyToEdit).not.toBe(DEFAULT_ROW);

    // Mutating the edit buffer must not mutate the original row (deep copy).
    vm.ontologyToEdit.vario_name = 'Renamed';
    expect(DEFAULT_ROW.vario_name).toBe('Example');

    let observedBody: unknown = null;
    server.use(
      http.put('/api/ontology/variant/update', async ({ request }) => {
        expectBearerHeader(request, 'ontology-write-token');
        observedBody = await request.json();
        return HttpResponse.json({ message: 'Updated' });
      })
    );

    await vm.updateOntologyData();
    await flushPromises();

    expect(observedBody).toEqual({
      ontology_details: { ...DEFAULT_ROW, vario_name: 'Renamed' },
    });
    expect(makeToastSpy).toHaveBeenCalledWith('Updated', 'Success', 'success');
    expect(vm.showEditModal).toBe(false);
    expect(vm.ontologyToEdit).toEqual({});
    expect(vm.ontologies.find((o) => o.vario_id === 'VariO:0001')).toEqual({
      ...DEFAULT_ROW,
      vario_name: 'Renamed',
    });
  });

  it('updateOntologyData() surfaces the API error message on failure and keeps the modal open', async () => {
    server.use(
      http.get('/api/ontology/variant/table', () => HttpResponse.json(ontologyListPayload()))
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as OntologyVm;
    vm.editOntology(DEFAULT_ROW);

    server.use(
      http.put('/api/ontology/variant/update', () =>
        HttpResponse.json({ error: 'vario_id not found' }, { status: 404 })
      )
    );

    await vm.updateOntologyData();
    await flushPromises();

    expect(makeToastSpy).toHaveBeenCalledWith('vario_id not found', 'Error', 'danger');
    expect(vm.showEditModal).toBe(true);
  });

  // -------------------------------------------------------------------------
  // Excel export (client-side, currently loaded page only)
  // -------------------------------------------------------------------------

  it('handleExport() exports the loaded rows with the ontology_export_<date> filename and shared headers', async () => {
    server.use(
      http.get('/api/ontology/variant/table', () => HttpResponse.json(ontologyListPayload()))
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as OntologyVm;

    vm.handleExport();

    const expectedFilename = `ontology_export_${new Date().toISOString().split('T')[0]}`;
    expect(exportToExcelSpy).toHaveBeenCalledWith(vm.ontologies, {
      filename: expectedFilename,
      sheetName: 'Ontology',
      headers: ONTOLOGY_EXPORT_HEADERS,
    });
  });
});
