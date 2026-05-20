import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';
import { http, HttpResponse } from 'msw';

import axios from '@/plugins/axios';
import TablesPhenotypes from './TablesPhenotypes.vue';
import { server } from '@/test-utils/mocks/server';

const makeToastSpy = vi.fn();
const clickSpy = vi.fn();
const createObjectUrlSpy = vi.fn(() => 'blob:phenotype-search');
const mountedWrappers: VueWrapper[] = [];

vi.mock('@/composables', async () => {
  const actual = await vi.importActual<typeof import('@/composables')>('@/composables');
  return {
    ...actual,
    useToast: () => ({ makeToast: makeToastSpy }),
    useUrlParsing: () => ({
      filterObjToStr: (filter: Record<string, { content: unknown; operator: string }>) => {
        const selected = filter.modifier_phenotype_id?.content;
        const values = Array.isArray(selected) ? selected.join(',') : '';
        const operator = filter.modifier_phenotype_id?.operator || 'all';
        return `${operator}(modifier_phenotype_id,${values})`;
      },
      filterStrToObj: (
        filterString: string,
        filter: Record<string, { content: unknown; operator: string }>
      ) => {
        const next = { ...filter, modifier_phenotype_id: { ...filter.modifier_phenotype_id } };
        if (filterString.includes('HP:0001250')) {
          next.modifier_phenotype_id.content = ['HP:0001250'];
        }
        return next;
      },
      sortStringToVariables: () => ({ sortBy: [{ key: 'entity_id', order: 'desc' }] }),
    }),
    useColorAndSymbols: () => ({ ndd_icon_text: { Yes: 'NDD phenotype' } }),
    useText: () => ({ truncate: (value: string) => value }),
  };
});

vi.mock('@/utils/tableRequestCoordinator', () => ({
  createTableRequestCoordinator: () => ({
    request: async ({
      fetcher,
      apply,
    }: {
      fetcher: () => Promise<unknown>;
      apply: (data: unknown, source: 'network') => void;
    }) => {
      const data = await fetcher();
      apply(data, 'network');
      return { handled: true, source: 'network' };
    },
  }),
}));

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/Tables/Phenotypes', component: { template: '<div />' } }],
  });
}

async function mountSubject(props = {}) {
  setActivePinia(createPinia());
  const router = makeRouter();
  await router.push('/Tables/Phenotypes');
  await router.isReady();

  const wrapper = mount(TablesPhenotypes, {
    props,
    global: {
      plugins: [router],
      provide: { axios },
      directives: { 'b-tooltip': {} },
      stubs: {
        TableShell: {
          template:
            '<section><slot name="actions" /><slot name="toolbar" /><slot name="loading" /><slot /></section>',
        },
        TableLoadingState: { template: '<div />' },
        TablePaginationControls: { template: '<nav />' },
        PhenotypesMobileRows: { template: '<div />' },
        EntityBadge: { template: '<a>{{ entityId }}</a>', props: ['entityId'] },
        GeneBadge: { template: '<a>{{ symbol }}</a>', props: ['symbol'] },
        DiseaseBadge: { template: '<span>{{ name }}</span>', props: ['name'] },
        InheritanceBadge: { template: '<span>{{ fullName }}</span>', props: ['fullName'] },
        CategoryIcon: { template: '<span />' },
        NddIcon: { template: '<span />' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BButton: { template: '<button @click="$emit(\'click\')"><slot /></button>' },
        BSpinner: { template: '<span />' },
        BDropdown: {
          template: '<div><slot name="button-content" /><slot /></div>',
          methods: { show() {} },
        },
        BDropdownForm: { template: '<form><slot /></form>' },
        BDropdownDivider: { template: '<hr />' },
        BDropdownItemButton: { template: '<button @click="$emit(\'click\')"><slot /></button>' },
        BDropdownText: { template: '<span><slot /></span>' },
        BFormInput: {
          inheritAttrs: false,
          props: ['modelValue'],
          template: '<input />',
        },
        BFormSelect: {
          inheritAttrs: false,
          props: ['options', 'modelValue'],
          template: '<select />',
        },
        BFormSelectOption: { template: '<option><slot /></option>' },
        BCard: { template: '<div><slot /></div>' },
        BTable: {
          props: ['items'],
          template:
            '<table><tbody><tr v-for="item in items" :key="item.entity_id"><td>{{ item.entity_id }}</td><td>{{ item.symbol }}</td><td>{{ item.disease_ontology_name }}</td><td>{{ item.hpo_mode_of_inheritance_term_name }}</td><td>{{ item.category }}</td><td>{{ item.ndd_phenotype_word }}</td></tr></tbody></table>',
        },
      },
    },
  });
  await flushPromises();
  await new Promise((resolve) => setTimeout(resolve, 75));
  await flushPromises();
  mountedWrappers.push(wrapper);
  return wrapper;
}

interface PhenotypesVm {
  clearAllPhenotypes: () => void;
  setLogicMode: (isOr: boolean) => void;
  requestExcel: () => Promise<void>;
  isInitializing: boolean;
  filter: { modifier_phenotype_id: { content: string[]; operator: string } };
  items: unknown[];
  totalRows: number;
}

beforeEach(() => {
  makeToastSpy.mockClear();
  clickSpy.mockClear();
  createObjectUrlSpy.mockClear();
  vi.stubGlobal('URL', window.URL);
  vi.spyOn(window.URL, 'createObjectURL').mockImplementation(createObjectUrlSpy);
});

afterEach(() => {
  mountedWrappers.splice(0).forEach((wrapper) => wrapper.unmount());
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe('TablesPhenotypes', () => {
  it('loads phenotype options and selected phenotype entity rows through typed endpoints', async () => {
    let listQuery: URLSearchParams | null = null;
    let browseQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/list/phenotype', ({ request }) => {
        listQuery = new URL(request.url).searchParams;
        return HttpResponse.json({
          data: [{ HPO_term: 'Intellectual disability', phenotype_id: 'HP:0001249' }],
        });
      }),
      http.get('/api/phenotype/entities/browse', ({ request }) => {
        browseQuery = new URL(request.url).searchParams;
        return HttpResponse.json({
          meta: [
            {
              fspec: [],
              totalItems: 1,
              currentPage: 1,
              totalPages: 1,
              currentItemID: 0,
              executionTime: 3,
            },
          ],
          data: [
            {
              entity_id: 'E1',
              symbol: 'MECP2',
              disease_ontology_name: 'Rett syndrome',
              hpo_mode_of_inheritance_term_name: 'X-linked',
              category: 'Definitive',
              ndd_phenotype_word: 'Yes',
            },
          ],
        });
      })
    );

    const wrapper = await mountSubject();

    expect((listQuery as URLSearchParams).get('tree')).toBe('FALSE');
    expect((browseQuery as URLSearchParams).get('sort')).toBe('entity_id');
    expect((browseQuery as URLSearchParams).get('page_size')).toBe('10');
    expect((browseQuery as URLSearchParams).get('format')).toBe('json');
    expect((browseQuery as URLSearchParams).get('filter')).toContain('HP:0001249');
    expect(wrapper.text()).toContain('MECP2');
  });

  it('does not request entity rows when no phenotype is selected', async () => {
    let browseCalls = 0;
    server.use(
      http.get('/api/list/phenotype', () => HttpResponse.json({ data: [] })),
      http.get('/api/phenotype/entities/browse', () => {
        browseCalls += 1;
        return HttpResponse.json({
          meta: [{ fspec: [], totalItems: 0, currentPage: 1, totalPages: 1 }],
          data: [],
        });
      })
    );

    const wrapper = await mountSubject();
    const vm = wrapper.vm as unknown as PhenotypesVm;
    const callsAfterMount = browseCalls;
    vm.isInitializing = true;
    vm.clearAllPhenotypes();
    await flushPromises();

    expect(vm.items).toEqual([]);
    expect(vm.totalRows).toBe(0);
    expect(browseCalls).toBe(callsAfterMount);
  });

  it('applies URL-derived phenotype state and changes the outgoing logic operator', async () => {
    const observedFilters: string[] = [];
    server.use(
      http.get('/api/list/phenotype', () => HttpResponse.json({ data: [] })),
      http.get('/api/phenotype/entities/browse', ({ request }) => {
        observedFilters.push(new URL(request.url).searchParams.get('filter') || '');
        return HttpResponse.json({
          meta: [{ fspec: [], totalItems: 0, currentPage: 1, totalPages: 1, currentItemID: 0 }],
          data: [],
        });
      })
    );

    const wrapper = await mountSubject({
      filterInput: 'all(modifier_phenotype_id,HP:0001250)',
    });
    const vm = wrapper.vm as unknown as PhenotypesVm;

    expect(observedFilters.at(-1)).toContain('HP:0001250');

    vm.isInitializing = true;
    vm.setLogicMode(true);
    await new Promise((resolve) => setTimeout(resolve, 75));
    await flushPromises();

    expect(observedFilters.at(-1)).toContain('any(modifier_phenotype_id,HP:0001250)');
  });

  it('exports all selected phenotype rows as phenotype_search.xlsx', async () => {
    let exportQuery: URLSearchParams | null = null;
    const createElementSpy = vi
      .spyOn(document, 'createElement')
      .mockImplementation(((tagName: string) => {
        const element = document.createElementNS(
          'http://www.w3.org/1999/xhtml',
          tagName
        ) as HTMLAnchorElement;
        if (tagName === 'a') {
          element.click = clickSpy;
        }
        return element;
      }) as typeof document.createElement);
    server.use(
      http.get('/api/list/phenotype', () => HttpResponse.json({ data: [] })),
      http.get('/api/phenotype/entities/browse', ({ request }) => {
        const query = new URL(request.url).searchParams;
        if (query.get('format') === 'xlsx') {
          exportQuery = query;
          return new HttpResponse(new Uint8Array([0x50, 0x4b]), { status: 200 });
        }
        return HttpResponse.json({
          meta: [{ fspec: [], totalItems: 1, currentPage: 1, totalPages: 1, currentItemID: 0 }],
          data: [],
        });
      })
    );

    const wrapper = await mountSubject();
    await (wrapper.vm as unknown as PhenotypesVm).requestExcel();
    await flushPromises();

    expect((exportQuery as URLSearchParams).get('page_after')).toBe('0');
    expect((exportQuery as URLSearchParams).get('page_size')).toBe('all');
    expect((exportQuery as URLSearchParams).get('format')).toBe('xlsx');
    expect(clickSpy).toHaveBeenCalled();
    createElementSpy.mockRestore();
  });
});
