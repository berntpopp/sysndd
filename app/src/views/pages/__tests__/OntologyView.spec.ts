// app/src/views/pages/__tests__/OntologyView.spec.ts

import { describe, expect, it, beforeEach, afterEach, vi } from 'vitest';

vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: vi.fn() }),
}));

import { setActivePinia, createPinia } from 'pinia';
import { http, HttpResponse } from 'msw';
import { mount, flushPromises } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import { server } from '@/test-utils/mocks/server';
import { bootstrapStubs } from '@/test-utils';
import OntologyView from '../OntologyView.vue';

const mockMondoResponse = [
  {
    disease_ontology_id: ['MONDO:0001071'],
    disease_ontology_id_version: ['MONDO:0001071'],
    disease_ontology_name: ['intellectual disability'],
    disease_ontology_source: ['mondo'],
    disease_ontology_is_specific: ['0'],
    hgnc_id: [null],
    hpo_mode_of_inheritance_term: [null],
    DOID: ['DOID:1059'],
    MONDO: [null],
    Orphanet: ['Orphanet:319658'],
    EFO: [null],
    UMLS: ['UMLS:C3714756'],
    MedGen: ['MedGen:811461'],
    NCIT: ['NCIT:C97250'],
    GARD: [null],
    ontology_mapping_release: ['2026-09-01'],
    hpo_mode_of_inheritance_term_name: [null],
    inheritance_filter: [null],
  },
];

function makeRouter(path: string) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/Ontology/:disease_term', name: 'Ontology', component: OntologyView },
      { path: '/PageNotFound', name: 'NotFound', component: { template: '<div>404</div>' } },
    ],
  });
  router.push(path);
  return router;
}

const componentStubs = {
  ...bootstrapStubs,
  TablesEntities: {
    props: ['filterInput', 'headerLabel'],
    template: '<div data-testid="tables-entities-stub" :data-filter="filterInput">{{ headerLabel }}</div>',
  },
};

describe('OntologyView', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  afterEach(() => {
    server.resetHandlers();
  });

  it('renders clinical hero and cross-ontology mappings when ontology resolves', async () => {
    server.use(
      http.get('*/api/ontology/:term', () => {
        return HttpResponse.json(mockMondoResponse);
      })
    );

    const router = makeRouter('/Ontology/MONDO:0001071');
    await router.isReady();

    const wrapper = mount(OntologyView, {
      global: {
        plugins: [router],
        stubs: componentStubs,
        directives: {
          'b-tooltip': {},
        },
      },
    });

    await flushPromises();

    expect(wrapper.text()).toContain('intellectual disability');
    expect(wrapper.text()).toContain('MONDO:0001071');
    expect(wrapper.text()).toContain('Broad term');
    expect(wrapper.text()).toContain('Cross-Ontology Mappings & External Databases');
    expect(wrapper.text()).toContain('DOID:1059');
    expect(wrapper.text()).toContain('Orphanet:319658');
    expect(wrapper.text()).toContain('UMLS:C3714756');

    const tableStub = wrapper.find('[data-testid="tables-entities-stub"]');
    expect(tableStub.exists()).toBe(true);
    expect(tableStub.attributes('data-filter')).toBe('any(disease_ontology_id_version,MONDO:0001071)');
  });

  it('redirects to /PageNotFound when no ontology record is found', async () => {
    server.use(
      http.get('*/api/ontology/:term', () => {
        return HttpResponse.json([]);
      })
    );

    const router = makeRouter('/Ontology/NONEXISTENT:9999');
    await router.isReady();

    mount(OntologyView, {
      global: {
        plugins: [router],
        stubs: componentStubs,
        directives: {
          'b-tooltip': {},
        },
      },
    });

    await flushPromises();

    expect(router.currentRoute.value.path).toBe('/PageNotFound');
  });
});
