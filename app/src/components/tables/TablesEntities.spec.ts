// TablesEntities.spec.ts
/**
 * WP-F closeout: verifies the row-expansion slot renders LinkedOntologies and
 * triggers a disease-mappings fetch on row expand.
 *
 * #346 Wave 2 Task 2 (entities domain): useEntitiesTable domain-contract
 * coverage — URL-derived initial state, the request-coordinator stale-
 * response guard, cursor-pagination transitions, the fspec -> fields merge,
 * disableUrlSync, return links, and the Excel-export filename. Composable
 * methods are exercised via the mounted SFC's `vm` with a real (unmocked,
 * module-level) request coordinator; tests that fire a request use a
 * distinct `pageSizeInput` so cache keys never collide across `it()` blocks
 * (mirrors usePublicationsTable.spec.ts / TablesLogs.spec.ts).
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { ref, computed } from 'vue';
import { createPinia, setActivePinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';

import '@/plugins/axios';
import axios from '@/plugins/axios';
import type { EntityListResponse } from '@/api/entity';
import type { UseEntitiesTableProps } from './useEntitiesTable';

// Module mocks
const makeToastSpy = vi.fn();

vi.mock('@/composables', async () => {
  return {
    useToast: () => ({ makeToast: makeToastSpy }),
    useUrlParsing: () => ({
      filterObjToStr: () => '',
      filterStrToObj: (_s: string, o: unknown) => o,
      sortStringToVariables: () => ({ sortBy: [] }),
    }),
    useColorAndSymbols: () => ({}),
    useText: () => ({ truncate: (s: string) => s }),
    useColumnTooltip: () => ({ getTooltipText: () => '' }),
    // Respects `pageSizeInput` (unlike the earlier fixed stub) so tests below
    // can drive distinct request-coordinator cache keys via the SFC's
    // `page-size-input` prop; every other field mirrors the real
    // `useTableData()` initial defaults closely enough for this table's
    // needs (the composable's onMounted() re-derives `sort`/`currentItemID`
    // from props directly, so only `perPage` needs to be prop-derived here).
    useTableData: (options: { pageSizeInput?: number } = {}) => ({
      items: ref([]),
      loading: ref(false),
      downloading: ref(false),
      currentPage: ref(1),
      perPage: ref(Number(options.pageSizeInput) || 10),
      totalRows: ref(0),
      sort: ref('+entity_id'),
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
  };
});

const getEntityMappingsSpy = vi.fn();
vi.mock('@/api/disease-mappings', () => ({
  getEntityMappings: (...args: unknown[]) => getEntityMappingsSpy(...args),
}));

const listEntitiesMock = vi.hoisted(() => vi.fn());
const listEntitiesXlsxMock = vi.hoisted(() => vi.fn());

vi.mock('@/api/entity', () => ({
  listEntities: listEntitiesMock,
  listEntitiesXlsx: listEntitiesXlsxMock,
}));

// Helpers
function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/', name: 'Home', component: { template: '<div />' } }],
  });
}

/** Minimal mock disease-mapping response */
const mockMappingResponse = {
  disease_ontology_id: 'OMIM:135900',
  disease_ontology_name: 'Coffin-Siris syndrome 1',
  mondo_id: 'MONDO:0032745',
  release_version: '2024-01-01',
  status: 'current' as const,
  mappings: {
    MONDO: [
      {
        id: 'MONDO:0032745',
        label: 'Coffin-Siris syndrome 1',
        predicate: 'exactMatch',
        source: 'mondo_sssom',
      },
    ],
  },
};

const DEFAULT_FSPEC = [
  { key: 'entity_id', label: 'Entity', sortable: true, class: 'text-start' },
  { key: 'details', label: 'Details' },
];

/** Builds a canonical `/api/entity` list envelope; mirrors the real API shape. */
function makeListResponse(
  data: Array<Record<string, unknown>>,
  metaOverrides: Record<string, unknown> = {},
  fspec: Array<Record<string, unknown>> = DEFAULT_FSPEC
): EntityListResponse {
  return {
    links: [],
    data: data as EntityListResponse['data'],
    meta: [
      {
        totalItems: data.length,
        currentPage: 1,
        totalPages: 1,
        prevItemID: 0,
        currentItemID: 0,
        nextItemID: 0,
        lastItemID: 0,
        executionTime: 1,
        fspec,
        ...metaOverrides,
      },
    ],
  };
}

/** Shared entity-row fixture for the row-expansion tests below. */
function makeEntityRow(overrides: Record<string, unknown> = {}) {
  return {
    entity_id: 57,
    symbol: 'ARID1B',
    hgnc_id: 'HGNC:18040',
    disease_ontology_name: 'Coffin-Siris syndrome 1',
    disease_ontology_id_version: 'OMIM:135900_2024-01-01',
    hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
    hpo_mode_of_inheritance_term: 'HP:0000006',
    category: 'Definitive',
    ndd_phenotype_word: 'Yes',
    ...overrides,
  };
}

async function mountTable(props: UseEntitiesTableProps = {}, settle = true) {
  setActivePinia(createPinia());
  const router = makeRouter();
  await router.push('/');
  await router.isReady();

  const wrapper = mount((await import('./TablesEntities.vue')).default, {
    props,
    global: {
      plugins: [router],
      provide: { axios },
      directives: { 'b-tooltip': {}, 'b-toggle': {} },
      stubs: {
        // Layout shells
        BContainer: { template: '<div><slot /></div>' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        // Table shells
        TableShell: {
          template:
            '<div><slot name="actions" /><slot name="toolbar" /><slot name="loading" /><slot /></div>',
        },
        TableLoadingState: { template: '<div data-testid="entities-skeleton" />' },
        TableSearchInput: { template: '<input />' },
        TablePaginationControls: { template: '<div />' },
        TableDownloadLinkCopyButtons: { template: '<div />' },
        // Badge / icon stubs
        EntityBadge: { template: '<span class="entity-badge"><slot /></span>' },
        GeneBadge: { template: '<span class="gene-badge"><slot /></span>' },
        DiseaseBadge: { template: '<span class="disease-badge"><slot /></span>' },
        InheritanceBadge: { template: '<span class="inheritance-badge"><slot /></span>' },
        CategoryIcon: { template: '<span class="category-icon" />' },
        NddIcon: { template: '<span class="ndd-icon" />' },
        // Bootstrap-Vue-Next
        BCard: { template: '<div class="b-card"><slot /></div>' },
        BButton: { template: '<button><slot /></button>' },
        BBadge: { template: '<span><slot /></span>' },
        BFormInput: { template: '<input />' },
        BFormSelect: { template: '<select><slot /></select>' },
        BFormSelectOption: { template: '<option><slot /></option>' },
        BSpinner: { template: '<div />' },
        // LinkedOntologies — keep as the REAL component so we can assert it renders
        // EntitiesMobileRows — stub for isolation
        EntitiesMobileRows: { template: '<div />' },
        // GenericTable renders the #row-expansion-extra slot; we stub it with a slot-aware stub.
        // The stub also exposes a details-toggle button so tests can assert the details
        // column mechanism is wired up.
        GenericTable: {
          props: ['items', 'fields', 'fieldDetails', 'sortBy', 'stackedMode'],
          emits: ['update-sort'],
          template: `
              <div class="generic-table-stub">
                <button
                  v-for="item in items"
                  :key="item.entity_id"
                  class="details-toggle"
                  @click="$emit('toggle', item)"
                >Show</button>
                <slot
                  v-for="item in items"
                  :key="'exp-' + item.entity_id"
                  name="row-expansion-extra"
                  :row="item"
                />
              </div>
            `,
        },
        // ResourceLink used inside LinkedOntologies
        ResourceLink: {
          props: ['name', 'url', 'available', 'icon', 'compact'],
          template: '<a class="resource-link" :href="url">{{ name }}</a>',
        },
      },
    },
  });

  if (settle) await flushPromises();
  return wrapper;
}

// Tests
beforeEach(() => {
  makeToastSpy.mockClear();
  getEntityMappingsSpy.mockReset();
  getEntityMappingsSpy.mockResolvedValue(mockMappingResponse);
  listEntitiesMock.mockReset();
  listEntitiesMock.mockResolvedValue(makeListResponse([]));
  listEntitiesXlsxMock.mockReset();
  vi.stubEnv('VITE_API_URL', '');
});

afterEach(() => {
  vi.unstubAllEnvs();
});

describe('TablesEntities — WP-F row-expansion ontology outlinks', () => {
  it('does not schedule its initial request after immediate unmount', async () => {
    const wrapper = await mountTable({}, false);
    wrapper.unmount();
    await flushPromises();

    expect(listEntitiesMock).not.toHaveBeenCalled();
  });

  it('renders without errors and contains the GenericTable wrapper', async () => {
    const wrapper = await mountTable();
    expect(wrapper.find('.generic-table-stub').exists()).toBe(true);
  });

  it('renders LinkedOntologies in the row-expansion slot for each item', async () => {
    // Inject a visible item so the slot is rendered
    const wrapper = await mountTable();

    // Set items directly on the component instance (bypassing API loading)
    const vm = wrapper.vm as { items: unknown[] };
    vm.items = [
      makeEntityRow({
        entry_date: '2024-02-10',
        last_update: '2026-02-10',
        synopsis: 'Developmental delay with speech involvement.',
      }),
    ];
    await flushPromises();

    // The slot should be rendered because GenericTable stub always renders it
    const linkedOntologies = wrapper.findComponent({ name: 'LinkedOntologies' });
    expect(linkedOntologies.exists()).toBe(true);
  });

  it('calls getEntityMappings with the entity_id when the row expansion slot renders', async () => {
    const wrapper = await mountTable();

    const vm = wrapper.vm as {
      items: unknown[];
      fetchEntityMappings: (id: unknown) => Promise<void>;
    };
    vm.items = [makeEntityRow()];
    await flushPromises();

    // Directly call the exposed fetchEntityMappings function (as @vue:mounted would)
    await vm.fetchEntityMappings(57);
    await flushPromises();

    expect(getEntityMappingsSpy).toHaveBeenCalledWith('57');
  });

  it('getEntityMappingState returns a safe default for unknown entity ids', async () => {
    const wrapper = await mountTable();
    const vm = wrapper.vm as {
      getEntityMappingState: (id: unknown) => { data: unknown; loading: boolean; error: unknown };
    };

    const state = vm.getEntityMappingState(9999);
    expect(state.data).toBeNull();
    expect(state.loading).toBe(false);
    expect(state.error).toBeNull();
  });

  it('does not call getEntityMappings twice for the same entity', async () => {
    const wrapper = await mountTable();
    const vm = wrapper.vm as { fetchEntityMappings: (id: unknown) => Promise<void> };

    await vm.fetchEntityMappings(57);
    await vm.fetchEntityMappings(57); // second call should be a no-op
    await flushPromises();

    expect(getEntityMappingsSpy).toHaveBeenCalledTimes(1);
  });

  // #3: assert the existing details toggle column is still present
  it('includes the "details" field in the columns definition', async () => {
    const wrapper = await mountTable();
    const vm = wrapper.vm as { fields: Array<{ key: string }> };
    const hasDetailsField = vm.fields.some((f) => f.key === 'details');
    expect(hasDetailsField).toBe(true);
  });

  // #4: verify that the fetch fires when the row-expansion-extra slot renders
  // The GenericTable stub always renders the slot for all items, so setting an item
  // causes the @vue:mounted trigger inside the slot to fire fetchEntityMappings.
  it('calls getEntityMappings via @vue:mounted when the row-expansion-extra slot is rendered', async () => {
    const wrapper = await mountTable();
    const vm = wrapper.vm as { items: unknown[] };

    // Inject an item — the stub renders the slot immediately for each item
    vm.items = [
      makeEntityRow({
        entity_id: 99,
        symbol: 'TEST',
        hgnc_id: 'HGNC:99999',
        disease_ontology_name: 'Test Disease',
        disease_ontology_id_version: 'OMIM:999999_2024-01-01',
      }),
    ];
    await flushPromises();

    // The @vue:mounted div inside #row-expansion-extra mounts when the slot renders,
    // calling fetchEntityMappings(99) which invokes getEntityMappings('99').
    expect(getEntityMappingsSpy).toHaveBeenCalledWith('99');
  });
});

// #346 Wave 2 Task 2 — useEntitiesTable domain contract coverage
interface EntitiesVm {
  sort: string;
  isInitializing: boolean;
  currentItemID: number;
  totalPages: number;
  currentPage: number;
  prevItemID: number;
  nextItemID: number;
  lastItemID: number;
  items: unknown[];
  fields: Array<{ key: string; label: string }>;
  loadDataDebounceTimer: ReturnType<typeof setTimeout> | null;
  doLoadData: () => Promise<void>;
  handlePageChange: (value: number) => void;
  applyApiResponse: (data: EntityListResponse) => void;
  requestExcel: () => Promise<void>;
  withCurrentReturnTo: (path: string) => string;
}

function clearPendingDebounce(vm: EntitiesVm) {
  if (vm.loadDataDebounceTimer) {
    clearTimeout(vm.loadDataDebounceTimer);
    vm.loadDataDebounceTimer = null;
  }
}

describe('initial load — URL-derived state', () => {
  it('applies URL-derived filter, sort, and cursor state before firing the single initial request', async () => {
    const wrapper = await mountTable({
      sortInput: '-symbol',
      filterInput: 'contains(symbol,ARID)',
      pageAfterInput: '42',
      pageSizeInput: 71,
    });

    expect(listEntitiesMock).toHaveBeenCalledTimes(1);
    expect(listEntitiesMock).toHaveBeenCalledWith({
      sort: '-symbol',
      filter: 'contains(symbol,ARID)',
      page_after: 42,
      page_size: '71',
      compact: false,
    });

    const vm = wrapper.vm as unknown as EntitiesVm;
    clearPendingDebounce(vm);
  });
});

describe('request coordinator — stale response guard', () => {
  it('discards an older in-flight response once a newer request has superseded it', async () => {
    const resolvers: Array<(value: EntityListResponse) => void> = [];
    listEntitiesMock.mockImplementation(
      () =>
        new Promise<EntityListResponse>((resolve) => {
          resolvers.push(resolve);
        })
    );

    const wrapper = await mountTable({ pageSizeInput: 72 });
    const vm = wrapper.vm as unknown as EntitiesVm;
    expect(listEntitiesMock).toHaveBeenCalledTimes(1); // request A in flight

    // Move state on to a different query, then fire request B directly while
    // A is still unresolved.
    vm.sort = '-symbol';
    const requestB = vm.doLoadData();
    expect(listEntitiesMock).toHaveBeenCalledTimes(2);

    // Resolve the OLDER request A first: its data must be discarded because
    // isCurrent() now reflects request B's params.
    resolvers[0](makeListResponse([{ entity_id: 'OLD' }]));
    await flushPromises();
    expect(vm.items).toEqual([]);

    // Resolve the newer request B; its data must win.
    resolvers[1](makeListResponse([{ entity_id: 'NEW' }]));
    await requestB;
    expect(vm.items).toEqual([{ entity_id: 'NEW' }]);

    clearPendingDebounce(vm);
  });
});

describe('handlePageChange — cursor transitions', () => {
  it('resolves each pagination branch to the matching cursor id', async () => {
    const wrapper = await mountTable({ pageSizeInput: 73 });
    const vm = wrapper.vm as unknown as EntitiesVm;
    clearPendingDebounce(vm);

    vm.currentItemID = 999;
    vm.handlePageChange(1); // value === 1 -> first page, cursor resets to 0
    expect(vm.currentItemID).toBe(0);

    vm.totalPages = 5;
    vm.currentPage = 2;
    vm.lastItemID = 500;
    vm.handlePageChange(5); // value === totalPages -> jump to lastItemID
    expect(vm.currentItemID).toBe(500);

    vm.currentPage = 2;
    vm.nextItemID = 300;
    vm.handlePageChange(3); // value > currentPage -> advance to nextItemID
    expect(vm.currentItemID).toBe(300);

    vm.currentPage = 3;
    vm.prevItemID = 100;
    vm.handlePageChange(2); // value < currentPage -> go back to prevItemID
    expect(vm.currentItemID).toBe(100);

    clearPendingDebounce(vm);
  });
});

describe('applyApiResponse — fspec merge', () => {
  it('applies short-label overrides for known keys and passes through unmapped keys unchanged', async () => {
    const wrapper = await mountTable({ pageSizeInput: 74 });
    const vm = wrapper.vm as unknown as EntitiesVm;
    clearPendingDebounce(vm);

    vm.applyApiResponse(
      makeListResponse([], {}, [
        { key: 'entity_id', label: 'Entity identifier', sortable: true },
        { key: 'symbol', label: 'Gene symbol', sortable: true },
        { key: 'disease_ontology_name', label: 'Disease name', sortable: true },
        { key: 'hpo_mode_of_inheritance_term_name', label: 'Mode of inheritance', sortable: true },
        { key: 'ndd_phenotype_word', label: 'NDD phenotype', sortable: true },
        { key: 'details', label: 'Details' },
      ])
    );

    const byKey = Object.fromEntries(vm.fields.map((f) => [f.key, f.label]));
    expect(byKey.entity_id).toBe('Entity');
    expect(byKey.disease_ontology_name).toBe('Disease');
    expect(byKey.hpo_mode_of_inheritance_term_name).toBe('Inheritance');
    expect(byKey.ndd_phenotype_word).toBe('NDD');
    // Unmapped keys pass through the server label unchanged.
    expect(byKey.symbol).toBe('Gene symbol');
    expect(byKey.details).toBe('Details');
  });
});

describe('updateBrowserUrl — disableUrlSync (embedded/URL-disabled mode)', () => {
  // A mount-triggered load races isInitializing=false against a
  // synchronously-resolved mock response (unlike a real HTTP round trip).
  // Mirroring TablesLogs.spec.ts, drive a fresh doLoadData() with
  // isInitializing forced false and `sort` changed so the coordinator takes
  // its network path rather than the recent-response cache path (which
  // intentionally skips updateBrowserUrl).
  it.each([
    [true, 75, false],
    [false, 76, true],
  ])(
    'disableUrlSync=%s -> history.replaceState called=%s after a successful load',
    async (disableUrlSync, pageSizeInput, expectCalled) => {
      const wrapper = await mountTable({ disableUrlSync, pageSizeInput });
      const vm = wrapper.vm as unknown as EntitiesVm;
      clearPendingDebounce(vm);
      vm.isInitializing = false;
      vm.sort = '-symbol';

      const replaceStateSpy = vi.spyOn(window.history, 'replaceState');
      await vm.doLoadData();
      await flushPromises();

      expect(replaceStateSpy.mock.calls.length > 0).toBe(expectCalled);
      replaceStateSpy.mockRestore();
    }
  );
});

describe('withCurrentReturnTo — return links', () => {
  it.each([
    ['/Entities?filter=x', '/Entities/57?returnTo=%2FEntities%3Ffilter%3Dx', 77],
    ['/SomeOtherPage', '/Entities/57', 78],
  ])('from location %s -> %s', async (locationPath, expected, pageSizeInput) => {
    window.history.pushState({}, '', locationPath);

    const wrapper = await mountTable({ pageSizeInput: pageSizeInput as number });
    const vm = wrapper.vm as unknown as EntitiesVm;
    clearPendingDebounce(vm);

    expect(vm.withCurrentReturnTo('/Entities/57')).toBe(expected);
  });
});

describe('requestExcel — XLSX filename', () => {
  it('calls listEntitiesXlsx with page_size "all" and downloads sysndd_entity_table.xlsx', async () => {
    const blob = new Blob(['x'], { type: 'application/octet-stream' });
    listEntitiesXlsxMock.mockResolvedValue(blob);
    const createObjectURL = vi.fn().mockReturnValue('blob:mock-entities');
    window.URL.createObjectURL = createObjectURL;
    window.URL.revokeObjectURL = vi.fn();
    const appendChildSpy = vi.spyOn(document.body, 'appendChild');

    const wrapper = await mountTable({
      pageSizeInput: 79,
      sortInput: '-symbol',
      filterInput: 'contains(symbol,ARID)',
    });
    const vm = wrapper.vm as unknown as EntitiesVm;
    clearPendingDebounce(vm);

    await vm.requestExcel();

    expect(listEntitiesXlsxMock).toHaveBeenCalledWith({
      sort: '-symbol',
      filter: 'contains(symbol,ARID)',
      page_after: 0,
      page_size: 'all',
    });
    expect(createObjectURL).toHaveBeenCalled();

    const anchorCall = appendChildSpy.mock.calls.find(
      ([node]) => (node as HTMLElement).tagName === 'A'
    );
    expect(anchorCall).toBeDefined();
    const anchor = anchorCall![0] as HTMLAnchorElement;
    expect(anchor.getAttribute('download')).toBe('sysndd_entity_table.xlsx');

    appendChildSpy.mockRestore();
  });
});
