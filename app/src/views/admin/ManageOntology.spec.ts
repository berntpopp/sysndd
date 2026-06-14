// ManageOntology.spec.ts
/**
 * Spec covering the typed-client migration of
 * `views/admin/ManageOntology.vue` (feat/admin-typed-client-migration).
 *
 *   1. `doLoadData()` fetches `GET /api/ontology/variant/table` via
 *      `listVariantOntology` with the `Authorization: Bearer <token>`
 *      header injected by the apiClient request interceptor.
 *   2. `updateOntologyData()` writes via `PUT /api/ontology/variant/update`
 *      through `updateVariantOntology` and also carries the Bearer header.
 *
 * The pre-F2b implementation hard-coded
 * `Authorization: Bearer ${localStorage.getItem('token')}` on each call;
 * this spec pins the migrated path so any regression trips the lint
 * guardrail AND fails an observable test. Asserting on the msw network
 * boundary keeps the Bearer-header-on-the-wire coverage intact across the
 * raw-axios -> typed-client move (both route through the same axios
 * singleton + request interceptor).
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import { useAuth } from '@/composables/useAuth';
import ManageOntology from './ManageOntology.vue';

const makeToastSpy = vi.fn();
vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: makeToastSpy }),
}));

// The view composes `useTableData`, `useUrlParsing`, and `useExcelExport`
// from the barrel. Stub them to minimal shapes so the spec focuses on
// the two migrated HTTP call sites.
vi.mock('@/composables', () => ({
  useTableData: () => ({
    currentPage: 1,
    perPage: 25,
    totalRows: 0,
    sort: '+vario_id',
    sortBy: [],
    filter_string: '',
    currentItemID: 0,
    prevItemID: 0,
    nextItemID: 0,
    lastItemID: 0,
    executionTime: 0,
    pageOptions: [25],
    isBusy: false,
  }),
  useUrlParsing: () => ({
    filterObjToStr: () => '',
    filterStrToObj: (_s: string, o: unknown) => o,
    sortStringToVariables: () => ({ sortBy: [] }),
  }),
  useExcelExport: () => ({
    isExporting: false,
    exportToExcel: vi.fn(),
  }),
}));

interface OntologyVm {
  doLoadData: () => Promise<void>;
  updateOntologyData: () => Promise<void>;
  ontologyToEdit: Record<string, unknown>;
  ontologies: unknown[];
  filter: Record<string, unknown>;
}

const tableOk = {
  data: [
    {
      vario_id: 'VariO:0001',
      vario_name: 'Example',
      definition: 'Example def',
      obsolete: 0,
      is_active: 1,
      sort: 1,
      update_date: '2025-01-01',
    },
  ],
  meta: [
    {
      totalItems: 1,
      currentPage: 1,
      totalPages: 1,
      prevItemID: 0,
      currentItemID: 0,
      nextItemID: 0,
      lastItemID: 0,
      executionTime: 10,
    },
  ],
};

async function mountView() {
  setActivePinia(createPinia());
  const wrapper = mount(ManageOntology, {
    global: {
      directives: { 'b-tooltip': {}, 'b-toggle': {} },
      stubs: {
        GenericTable: { template: '<div />' },
        TablePaginationControls: { template: '<div />' },
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
        BFormSelect: { template: '<select />' },
        BModal: { template: '<div><slot /></div>' },
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

describe('ManageOntology — v11.0 closeout F2b apiClient migration', () => {
  it('doLoadData() fetches the ontology table with the Bearer header injected by apiClient', async () => {
    primeAuth('ontology-token');

    server.use(
      http.get('/api/ontology/variant/table', ({ request }) => {
        expectBearerHeader(request, 'ontology-token');
        return HttpResponse.json(tableOk);
      })
    );

    const wrapper = await mountView();
    await (wrapper.vm as unknown as OntologyVm).doLoadData();
    await flushPromises();

    // Sanity: the migration did not break the table's consumption of
    // `response.data` — ontologies populated from the fixture.
    const vm = wrapper.vm as unknown as OntologyVm;
    expect(Array.isArray(vm.ontologies)).toBe(true);
    expect(vm.ontologies).toHaveLength(1);
  });

  it('updateOntologyData() writes via PUT with the Bearer header', async () => {
    primeAuth('ontology-write-token');

    server.use(
      http.put('/api/ontology/variant/update', ({ request }) => {
        expectBearerHeader(request, 'ontology-write-token');
        return HttpResponse.json({ message: 'Updated' });
      })
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as OntologyVm;
    vm.ontologyToEdit = {
      vario_id: 'VariO:0001',
      vario_name: 'Renamed',
      definition: 'New def',
    };
    // `ontologies` must exist so the post-update splice has something
    // to find (even if no match, the code path still validates the
    // Bearer-header contract).
    vm.ontologies = [];

    await vm.updateOntologyData();
    await flushPromises();

    // Success toast fired because the PUT resolved 2xx.
    expect(makeToastSpy).toHaveBeenCalled();
  });
});
