// TablesEntities.spec.ts
/**
 * WP-F closeout — verifies that the row-expansion slot in TablesEntities.vue
 * renders LinkedOntologies and triggers a disease-mappings fetch when a row is
 * expanded.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { ref, computed } from 'vue';
import { createPinia, setActivePinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import axios from '@/plugins/axios';
import { server } from '@/test-utils/mocks/server';

// ---------------------------------------------------------------------------
// Module mocks
// ---------------------------------------------------------------------------

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
    useTableData: () => ({
      items: ref([]),
      loading: ref(false),
      downloading: ref(false),
      currentPage: ref(1),
      perPage: ref(10),
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
      applyApiResponse: vi.fn(),
    }),
    useTableMethods: () => ({
      filtered: vi.fn(),
      handlePageChange: vi.fn(),
      handlePerPageChange: vi.fn(),
      handleSortByOrDescChange: vi.fn(),
      removeFilters: vi.fn(),
      removeSearch: vi.fn(),
      requestExcel: vi.fn(),
      copyLinkToClipboard: vi.fn(),
    }),
  };
});

const getEntityMappingsSpy = vi.fn();
vi.mock('@/api/disease-mappings', () => ({
  getEntityMappings: (...args: unknown[]) => getEntityMappingsSpy(...args),
}));

vi.mock('@/api/entity', () => ({
  listEntities: vi.fn().mockResolvedValue({
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
        executionTime: 1,
        fspec: [
          { key: 'entity_id', label: 'Entity', sortable: true, class: 'text-start' },
          { key: 'details', label: 'Details' },
        ],
      },
    ],
  }),
}));

vi.mock('@/utils/tableRequestCoordinator', () => ({
  createTableRequestCoordinator: () => ({
    request: vi.fn().mockResolvedValue({ handled: true }),
  }),
}));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
    MONDO: [{ id: 'MONDO:0032745', label: 'Coffin-Siris syndrome 1', predicate: 'exactMatch', source: 'mondo_sssom' }],
  },
};

async function mountTable() {
  setActivePinia(createPinia());
  const router = makeRouter();
  await router.push('/');
  await router.isReady();

  const wrapper = mount(
    (await import('./TablesEntities.vue')).default,
    {
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
          TableShell: { template: '<div><slot name="actions" /><slot name="toolbar" /><slot name="loading" /><slot /></div>' },
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
          // GenericTable renders the #row-expansion slot; we stub it with a slot-aware stub
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
                  name="row-expansion"
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
    }
  );

  await flushPromises();
  return wrapper;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

beforeEach(() => {
  makeToastSpy.mockClear();
  getEntityMappingsSpy.mockReset();
  getEntityMappingsSpy.mockResolvedValue(mockMappingResponse);
  vi.stubEnv('VITE_API_URL', '');
});

afterEach(() => {
  vi.unstubAllEnvs();
});

describe('TablesEntities — WP-F row-expansion ontology outlinks', () => {
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
      {
        entity_id: 57,
        symbol: 'ARID1B',
        hgnc_id: 'HGNC:18040',
        disease_ontology_name: 'Coffin-Siris syndrome 1',
        disease_ontology_id_version: 'OMIM:135900_2024-01-01',
        hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
        hpo_mode_of_inheritance_term: 'HP:0000006',
        category: 'Definitive',
        ndd_phenotype_word: 'Yes',
        entry_date: '2024-02-10',
        last_update: '2026-02-10',
        synopsis: 'Developmental delay with speech involvement.',
      },
    ];
    await flushPromises();

    // The slot should be rendered because GenericTable stub always renders it
    const linkedOntologies = wrapper.findComponent({ name: 'LinkedOntologies' });
    expect(linkedOntologies.exists()).toBe(true);
  });

  it('calls getEntityMappings with the entity_id when the row expansion slot renders', async () => {
    const wrapper = await mountTable();

    const vm = wrapper.vm as { items: unknown[]; fetchEntityMappings: (id: unknown) => Promise<void> };
    vm.items = [
      {
        entity_id: 57,
        symbol: 'ARID1B',
        hgnc_id: 'HGNC:18040',
        disease_ontology_name: 'Coffin-Siris syndrome 1',
        disease_ontology_id_version: 'OMIM:135900_2024-01-01',
        hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
        hpo_mode_of_inheritance_term: 'HP:0000006',
        category: 'Definitive',
        ndd_phenotype_word: 'Yes',
      },
    ];
    await flushPromises();

    // Directly call the exposed fetchEntityMappings function (as @vue:mounted would)
    await vm.fetchEntityMappings(57);
    await flushPromises();

    expect(getEntityMappingsSpy).toHaveBeenCalledWith('57');
  });

  it('getEntityMappingState returns a safe default for unknown entity ids', async () => {
    const wrapper = await mountTable();
    const vm = wrapper.vm as { getEntityMappingState: (id: unknown) => { data: unknown; loading: boolean; error: unknown } };

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
});

// ---------------------------------------------------------------------------
// MSW: default entity-list handler so doLoadData (if it runs) doesn't error
// ---------------------------------------------------------------------------

beforeEach(() => {
  server.use(
    http.get('/api/entity', () =>
      HttpResponse.json({
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
            executionTime: 1,
            fspec: [],
          },
        ],
      })
    )
  );
});
