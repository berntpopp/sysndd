// app/src/views/pages/__tests__/EntityView.spec.ts
//
// v11.3 W3.4 — pin EntityView parallel hook fan-out:
//   1. All 7 sub-resource endpoints fire on tick 0 (parallel, not sequential).
//   2. Publications result splits into additional_references + gene_review
//      adjacent cards from a single fetch (one /publications request).
//   3. Linked-gene block hydrates from the entity record's hgnc_id.
//   4. 404 redirect when the entity record returns empty.
//
// WP-G additions:
//   5. "Linked disease ontologies" SectionCard renders LinkedOntologies (layout="card").
//   6. Old mondoEquivalent plain-text MONDO pill is gone.
//
// Spec ref: .planning/superpowers/specs/2026-04-26-v11.3-genes-entities-perf-ux-design.md
//           §4.4 (entities page) and §2.3 finding 6 (sequential-await bug).

import { describe, expect, it, beforeEach, afterEach, vi } from 'vitest';

// `@unhead/vue`'s `useHead()` requires a `createHead()` plugin. Mock it to a
// no-op so EntityView's setup() doesn't throw when mounted standalone.
vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

// `useToast` (used by some descendant composables) requires the BApp / registry
// provider. Stub the composable so mount succeeds.
vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: vi.fn() }),
}));

import { setActivePinia, createPinia } from 'pinia';
import { http, HttpResponse } from 'msw';
import { mount, flushPromises } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import { server } from '@/test-utils/mocks/server';
import { bootstrapStubs } from '@/test-utils';
import { useCacheStore } from '@/stores/cacheStore';
import EntityView from '../EntityView.vue';
import LinkedOntologies from '@/components/disease/LinkedOntologies.vue';

function makeRouter(path: string) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/Entities/:entity_id', name: 'Entity', component: EntityView },
      { path: '/PageNotFound', name: 'NotFound', component: { template: '<div>404</div>' } },
      { path: '/Genes/:symbol', name: 'Gene', component: { template: '<div/>' } },
      { path: '/Ontology/:id', name: 'Ontology', component: { template: '<div/>' } },
    ],
  });
  router.push(path);
  return router;
}

// Stub heavy descendants to keep the page mount fast and side-effect free.
// SectionCard renders BCard internally; stub BCard for parity with the W2 spec.
const heavyChildStubs = {
  ...bootstrapStubs,
  BCard: { template: '<div><slot name="header" /><slot /></div>' },
  BCardText: { template: '<div><slot /></div>' },
  BTable: { template: '<table />' },
  BSpinner: { template: '<div role="status" />' },
  BButton: { template: '<button><slot /></button>' },
  EntityBadge: {
    props: ['entityId', 'size'],
    template:
      '<span data-testid="entity-page-badge" :data-size="size">sysndd:{{ entityId }}</span>',
  },
  GeneBadge: { template: '<span />' },
  DiseaseBadge: { template: '<span />' },
  InheritanceBadge: { template: '<span />' },
  CategoryIcon: { template: '<span />' },
  NddIcon: { template: '<span />' },
};

// Default empty-mappings response reused by all tests; individual tests may
// override with server.use(...) to return real mapping data.
const emptyMappingsResponse = {
  disease_ontology_id: 'OMIM:135900',
  disease_ontology_name: 'Coffin-Siris syndrome 1',
  mondo_id: null,
  release_version: null,
  status: 'missing',
  mappings: {},
};

describe('EntityView (v11.3 W3)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    // Register a default mappings handler so existing tests don't get
    // unhandled-request 500s now that useEntityMappings is always mounted.
    server.use(http.get('*/api/disease/mappings', () => HttpResponse.json(emptyMappingsResponse)));
  });
  afterEach(() => server.resetHandlers());

  it('fires all 7 sub-resource calls in parallel on mount (no sequential await)', async () => {
    const calls: string[] = [];
    const start = Date.now();
    const tag = (name: string) => calls.push(`${Date.now() - start}:${name}`);

    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({
          data: [{ entity_id: 304, symbol: 'MECP2', hgnc_id: 'HGNC:6990' }],
          links: [],
          meta: [{}],
        })
      ),
      http.get('*/api/entity/304/status', () => {
        tag('status');
        return HttpResponse.json([{ category: 'Definitive' }]);
      }),
      http.get('*/api/entity/304/review', () => {
        tag('review');
        return HttpResponse.json([{ synopsis: '', comment: '' }]);
      }),
      http.get('*/api/entity/304/publications', () => {
        tag('pubs');
        return HttpResponse.json([]);
      }),
      http.get('*/api/entity/304/phenotypes', () => {
        tag('pheno');
        return HttpResponse.json([]);
      }),
      http.get('*/api/entity/304/variation', () => {
        tag('var');
        return HttpResponse.json([]);
      }),
      http.get('*/api/disease/mappings', () => {
        tag('mappings');
        return HttpResponse.json({
          disease_ontology_id: 'OMIM:300005',
          disease_ontology_name: 'Rett syndrome',
          mondo_id: null,
          release_version: null,
          status: 'missing',
          mappings: {},
        });
      }),
      http.get('*/api/gene/HGNC%3A6990', () => HttpResponse.json([{ symbol: ['MECP2'] }]))
    );

    const router = makeRouter('/Entities/304');
    await router.isReady();
    const w = mount(EntityView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushPromises();

    // Each tag appeared at least once — the page hit all 7 sub-resource
    // endpoints, not just the first in a sequential chain.
    expect(calls.some((c) => c.endsWith('status'))).toBe(true);
    expect(calls.some((c) => c.endsWith('review'))).toBe(true);
    expect(calls.some((c) => c.endsWith('pubs'))).toBe(true);
    expect(calls.some((c) => c.endsWith('pheno'))).toBe(true);
    expect(calls.some((c) => c.endsWith('var'))).toBe(true);
    expect(calls.some((c) => c.endsWith('mappings'))).toBe(true);

    // No tag should be more than 100 ms later than the earliest — they all
    // started within the same tick. Sequential awaits would space the calls
    // by at least one microtask each (typically > 50 ms under MSW + vitest).
    const offsets = calls.map((c) => Number(c.split(':')[0]));
    const spread = Math.max(...offsets) - Math.min(...offsets);
    expect(spread).toBeLessThan(100);
    w.unmount();
  });

  it('splits publications into additional_references and gene_review from one fetch', async () => {
    let pubsCalls = 0;
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({
          data: [{ entity_id: 304, hgnc_id: 'HGNC:6990' }],
          links: [],
          meta: [{}],
        })
      ),
      http.get('*/api/entity/304/status', () => HttpResponse.json([])),
      http.get('*/api/entity/304/review', () => HttpResponse.json([{ synopsis: '' }])),
      http.get('*/api/entity/304/publications', () => {
        pubsCalls += 1;
        return HttpResponse.json([
          { publication_id: 'PMID:1', publication_type: 'additional_references' },
          { publication_id: 'PMID:2', publication_type: 'additional_references' },
          { publication_id: 'PMID:3', publication_type: 'gene_review' },
        ]);
      }),
      http.get('*/api/entity/304/phenotypes', () => HttpResponse.json([])),
      http.get('*/api/entity/304/variation', () => HttpResponse.json([])),
      http.get('*/api/gene/HGNC%3A6990', () => HttpResponse.json([{ symbol: ['MECP2'] }]))
    );

    const router = makeRouter('/Entities/304');
    await router.isReady();
    const w = mount(EntityView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushPromises();

    // One fetch feeds both adjacent cards.
    expect(pubsCalls).toBe(1);
    w.unmount();
  });

  it('redirects to /PageNotFound when the entity record is empty', async () => {
    server.use(
      http.get('*/api/entity/', () => HttpResponse.json({ data: [], links: [], meta: [{}] })),
      // The remaining sub-resource handlers may still be called by the hooks
      // even when the record is empty; return empty payloads to keep MSW happy.
      http.get('*/api/entity/999999/status', () => HttpResponse.json([])),
      http.get('*/api/entity/999999/review', () => HttpResponse.json([])),
      http.get('*/api/entity/999999/publications', () => HttpResponse.json([])),
      http.get('*/api/entity/999999/phenotypes', () => HttpResponse.json([])),
      http.get('*/api/entity/999999/variation', () => HttpResponse.json([]))
    );

    // Pre-seed the SWR cache with a stale sentinel so the watcher fires on the
    // null transition (matches the W2 GeneView 404 spec pattern).
    const pinia = createPinia();
    setActivePinia(pinia);
    const cache = useCacheStore();
    cache.set('entity:999999', { entity_id: 999999, hgnc_id: 'HGNC:0' }, 60_000);
    const entry = cache.peek<unknown>('entity:999999');
    if (entry) entry.fetchedAt = 1;

    const router = makeRouter('/Entities/999999');
    await router.isReady();
    const push = vi.spyOn(router, 'push');
    const w = mount(EntityView, {
      global: { plugins: [router, pinia], stubs: heavyChildStubs },
    });
    await flushPromises();
    expect(push).toHaveBeenCalledWith('/PageNotFound');
    w.unmount();
  });

  it('hydrates the linked-gene hook from entity.hgnc_id', async () => {
    let geneCalls = 0;
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({
          data: [{ entity_id: 304, symbol: 'MECP2', hgnc_id: 'HGNC:6990' }],
          links: [],
          meta: [{}],
        })
      ),
      http.get('*/api/entity/304/status', () => HttpResponse.json([])),
      http.get('*/api/entity/304/review', () => HttpResponse.json([{ synopsis: 'r' }])),
      http.get('*/api/entity/304/publications', () => HttpResponse.json([])),
      http.get('*/api/entity/304/phenotypes', () => HttpResponse.json([])),
      http.get('*/api/entity/304/variation', () => HttpResponse.json([])),
      // axios encodes the colon: HGNC:6990 -> HGNC%3A6990 in the path.
      http.get('*/api/gene/HGNC%3A6990', () => {
        geneCalls += 1;
        return HttpResponse.json([{ symbol: ['MECP2'], name: ['methyl-CpG binding protein 2'] }]);
      })
    );
    const router = makeRouter('/Entities/304');
    await router.isReady();
    const w = mount(EntityView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushPromises();
    // The linked-gene hook fired exactly once with the resolved hgnc_id.
    expect(geneCalls).toBe(1);
    w.unmount();
  });

  it('renders a copyable clinical synopsis panel without the stacked table wrapper', async () => {
    const synopsis =
      'De novo truncating variants with developmental delay, seizures, hypotonia, and multisystem involvement.';
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText },
    });

    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({
          data: [
            {
              entity_id: 57,
              symbol: 'ARID1B',
              hgnc_id: 'HGNC:18040',
              disease_ontology_name: 'Coffin-Siris syndrome 1',
              disease_ontology_id_version: 'OMIM:135900',
              hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
              hpo_mode_of_inheritance_term: 'HP:0000006',
              ndd_phenotype_word: 'Yes',
            },
          ],
          links: [],
          meta: [{}],
        })
      ),
      http.get('*/api/entity/57/status', () => HttpResponse.json([{ category: 'Definitive' }])),
      http.get('*/api/entity/57/review', () =>
        HttpResponse.json([{ synopsis, review_date: '2025-02-12 11:14:21', comment: '' }])
      ),
      http.get('*/api/entity/57/publications', () => HttpResponse.json([])),
      http.get('*/api/entity/57/phenotypes', () => HttpResponse.json([])),
      http.get('*/api/entity/57/variation', () => HttpResponse.json([])),
      http.get('*/api/gene/HGNC%3A18040', () => HttpResponse.json([{ symbol: ['ARID1B'] }]))
    );

    const router = makeRouter('/Entities/57');
    await router.isReady();
    const w = mount(EntityView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushPromises();

    const synopsisPanel = w.get('[data-testid="clinical-synopsis-panel"]');
    expect(synopsisPanel.text()).toContain(synopsis);
    expect(w.get('[data-testid="clinical-synopsis-header"]').text()).toContain(
      'Last reviewed 2025-02-12 11:14:21'
    );
    expect(synopsisPanel.text()).not.toContain('Last reviewed');
    expect(
      w.get('[data-testid="clinical-synopsis-header"]').find('.copy-synopsis-button').exists()
    ).toBe(true);
    expect(synopsisPanel.find('table').exists()).toBe(false);

    await w
      .get('[data-testid="clinical-synopsis-header"] [data-testid="copy-synopsis-button"]')
      .trigger('click');
    expect(writeText).toHaveBeenCalledWith(synopsis);
    w.unmount();
  });

  it('does not report copied when clipboard write fails', async () => {
    const synopsis = 'Refractory seizures and developmental delay';
    const writeText = vi.fn().mockRejectedValue(new Error('no permission'));
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText },
    });

    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({
          data: [
            {
              entity_id: 57,
              symbol: 'ARID1B',
              hgnc_id: 'HGNC:18040',
              disease_ontology_name: 'Coffin-Siris syndrome 1',
              disease_ontology_id_version: 'OMIM:135900',
              hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
              hpo_mode_of_inheritance_term: 'HP:0000006',
              ndd_phenotype_word: 'Yes',
            },
          ],
          links: [],
          meta: [{}],
        })
      ),
      http.get('*/api/entity/57/status', () => HttpResponse.json([{ category: 'Definitive' }])),
      http.get('*/api/entity/57/review', () =>
        HttpResponse.json([{ synopsis, review_date: '2025-02-12 11:14:21', comment: '' }])
      ),
      http.get('*/api/entity/57/publications', () => HttpResponse.json([])),
      http.get('*/api/entity/57/phenotypes', () => HttpResponse.json([])),
      http.get('*/api/entity/57/variation', () => HttpResponse.json([])),
      http.get('*/api/gene/HGNC%3A18040', () => HttpResponse.json([{ symbol: ['ARID1B'] }]))
    );

    const router = makeRouter('/Entities/57');
    await router.isReady();
    const w = mount(EntityView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushPromises();

    const copyButton = w.get(
      '[data-testid="clinical-synopsis-header"] [data-testid="copy-synopsis-button"]'
    );
    await copyButton.trigger('click');
    await flushPromises();

    expect(writeText).toHaveBeenCalledWith(synopsis);
    expect(copyButton.text()).toContain('Copy');
    w.unmount();
  });

  it('renders the entity hero as a Gene / Inheritance / Disease unit', async () => {
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({
          data: [
            {
              entity_id: 57,
              symbol: 'ARID1B',
              hgnc_id: 'HGNC:18040',
              disease_ontology_name: 'Coffin-Siris syndrome 1',
              disease_ontology_id_version: 'OMIM:135900',
              hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
              hpo_mode_of_inheritance_term: 'HP:0000006',
              ndd_phenotype_word: 'Yes',
            },
          ],
          links: [],
          meta: [{}],
        })
      ),
      http.get('*/api/entity/57/status', () => HttpResponse.json([{ category: 'Definitive' }])),
      http.get('*/api/entity/57/review', () =>
        HttpResponse.json([{ synopsis: 'Concise clinical text.', comment: '' }])
      ),
      http.get('*/api/entity/57/publications', () => HttpResponse.json([])),
      http.get('*/api/entity/57/phenotypes', () => HttpResponse.json([])),
      http.get('*/api/entity/57/variation', () => HttpResponse.json([])),
      http.get('*/api/gene/HGNC%3A18040', () => HttpResponse.json([{ symbol: ['ARID1B'] }]))
    );

    const router = makeRouter('/Entities/57');
    await router.isReady();
    const w = mount(EntityView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushPromises();

    const unit = w.get('[data-testid="entity-unit"]');
    const labels = unit.findAll('[data-testid="entity-unit-label"]').map((node) => node.text());
    expect(labels).toEqual(['Gene', 'Inheritance', 'Disease']);
    expect(w.get('[data-testid="entity-page-badge"]').attributes('data-size')).toBe('lg');
    expect(unit.html()).toContain('ARID1B');
    expect(unit.html()).toContain('Autosomal dominant inheritance');
    expect(unit.html()).toContain('Coffin-Siris syndrome 1');
    w.unmount();
  });

  it('does not render an unrelated Results / Handoff table on the focused entity page', async () => {
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({
          data: [
            {
              entity_id: 57,
              symbol: 'ARID1B',
              hgnc_id: 'HGNC:18040',
              disease_ontology_name: 'Coffin-Siris syndrome 1',
              disease_ontology_id_version: 'OMIM:135900',
              hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
              hpo_mode_of_inheritance_term: 'HP:0000006',
              ndd_phenotype_word: 'Yes',
            },
          ],
          links: [],
          meta: [{}],
        })
      ),
      http.get('*/api/entity/57/status', () => HttpResponse.json([{ category: 'Definitive' }])),
      http.get('*/api/entity/57/review', () =>
        HttpResponse.json([
          {
            synopsis: 'Concise clinical text.',
            review_date: '2025-02-12 11:14:21',
            comment: '',
          },
        ])
      ),
      http.get('*/api/entity/57/publications', () =>
        HttpResponse.json([
          { publication_id: 'PMID:22405089', publication_type: 'additional_references' },
          { publication_id: 'PMID:23556151', publication_type: 'gene_review' },
        ])
      ),
      http.get('*/api/entity/57/phenotypes', () =>
        HttpResponse.json([
          { phenotype_id: 'HP:0001249', HPO_term: 'Intellectual disability', modifier_id: 1 },
          { phenotype_id: 'HP:0001250', HPO_term: 'Seizures', modifier_id: 5 },
        ])
      ),
      http.get('*/api/entity/57/variation', () =>
        HttpResponse.json([
          { vario_id: 'VariO:0133', vario_name: 'protein truncation', modifier_id: 3 },
        ])
      ),
      http.get('*/api/gene/HGNC%3A18040', () => HttpResponse.json([{ symbol: ['ARID1B'] }]))
    );

    const router = makeRouter('/Entities/57');
    await router.isReady();
    const w = mount(EntityView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushPromises();

    expect(w.find('[data-testid="entity-handoff-table"]').exists()).toBe(false);
    expect(w.text()).not.toContain('Results / Handoff');
    expect(w.text()).toContain('PMID:22405089');
    expect(w.text()).toContain('PMID:23556151');
    expect(w.text()).toContain('Intellectual disability');
    expect(w.text()).toContain('protein truncation');
    expect(w.get('[data-testid="phenotype-chip-HP:0001250"]').classes()).toContain(
      'entity-chip--absent'
    );
    expect(w.get('[data-testid="variation-chip-VariO:0133"]').classes()).toContain(
      'entity-chip--variable'
    );
    expect(
      w.get('[data-testid="publication-chip-PMID:22405089"]').attributes('title')
    ).toBeUndefined();
    expect(w.get('[data-testid="publication-chip-PMID:22405089"]').attributes('data-tooltip')).toBe(
      'Original Article'
    );
    expect(w.get('[data-testid="phenotype-chip-HP:0001250"]').attributes('title')).toBeUndefined();
    expect(w.get('[data-testid="phenotype-chip-HP:0001250"]').attributes('data-tooltip')).toBe(
      'absent | HP:0001250'
    );
    expect(w.get('[data-testid="variation-chip-VariO:0133"]').attributes('title')).toBeUndefined();
    expect(w.get('[data-testid="variation-chip-VariO:0133"]').attributes('data-tooltip')).toBe(
      'variable | VariO:0133'
    );
    // Issue #98: VariO chip links to the configurable EBI OLS4 term browser
    // (not the dead aber-owl.net fragment URL), with the id encoded as an OBO
    // PURL IRI (VariO:0133 -> VariO_0133).
    const varioHref = w
      .get('[data-testid="variation-chip-VariO:0133"]')
      .attributes('href') as string;
    expect(varioHref.startsWith('https://www.ebi.ac.uk/ols4/ontologies/vario/classes?iri=')).toBe(
      true
    );
    expect(varioHref).toContain(encodeURIComponent('http://purl.obolibrary.org/obo/VariO_0133'));
    expect(varioHref).not.toContain('aber-owl.net');
    w.unmount();
  });

  it('keeps source cards visible with clean empty states when optional data is missing', async () => {
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({
          data: [
            {
              entity_id: 57,
              symbol: 'ARID1B',
              hgnc_id: 'HGNC:18040',
              disease_ontology_name: 'Coffin-Siris syndrome 1',
              disease_ontology_id_version: 'OMIM:135900',
              hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
              hpo_mode_of_inheritance_term: 'HP:0000006',
              ndd_phenotype_word: 'Yes',
            },
          ],
          links: [],
          meta: [{}],
        })
      ),
      http.get('*/api/entity/57/status', () => HttpResponse.json([{ category: 'Definitive' }])),
      http.get('*/api/entity/57/review', () => HttpResponse.json([{ synopsis: '', comment: '' }])),
      http.get('*/api/entity/57/publications', () =>
        HttpResponse.json([
          { publication_id: 'PMID:22405089', publication_type: 'additional_references' },
        ])
      ),
      http.get('*/api/entity/57/phenotypes', () => HttpResponse.json([])),
      http.get('*/api/entity/57/variation', () => HttpResponse.json([])),
      http.get('*/api/gene/HGNC%3A18040', () => HttpResponse.json([{ symbol: ['ARID1B'] }]))
    );

    const router = makeRouter('/Entities/57');
    await router.isReady();
    const w = mount(EntityView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushPromises();

    expect(w.text()).toContain('Clinical Synopsis');
    expect(w.text()).toContain('No clinical synopsis available.');
    expect(w.text()).toContain('Gene Reviews');
    expect(w.text()).toContain('No GeneReviews linked.');
    expect(w.text()).toContain('Phenotypes');
    expect(w.text()).toContain('No phenotype terms linked.');
    expect(w.text()).toContain('Variation Ontology');
    expect(w.text()).toContain('No variation ontology terms linked.');
    w.unmount();
  });

  it('renders entry date and last-updated freshness pills (date-only)', async () => {
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({
          data: [
            {
              entity_id: 57,
              symbol: 'ARID1B',
              hgnc_id: 'HGNC:18040',
              disease_ontology_name: 'Coffin-Siris syndrome 1',
              disease_ontology_id_version: 'OMIM:135900',
              hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
              hpo_mode_of_inheritance_term: 'HP:0000006',
              ndd_phenotype_word: 'Yes',
              entry_date: '2014-03-04 00:00:00',
              last_update: '2026-02-10 12:29:49',
            },
          ],
          links: [],
          meta: [{}],
        })
      ),
      http.get('*/api/entity/57/status', () => HttpResponse.json([{ category: 'Definitive' }])),
      http.get('*/api/entity/57/review', () => HttpResponse.json([{ synopsis: '', comment: '' }])),
      http.get('*/api/entity/57/publications', () => HttpResponse.json([])),
      http.get('*/api/entity/57/phenotypes', () => HttpResponse.json([])),
      http.get('*/api/entity/57/variation', () => HttpResponse.json([])),
      http.get('*/api/gene/HGNC%3A18040', () => HttpResponse.json([{ symbol: ['ARID1B'] }]))
    );

    const router = makeRouter('/Entities/57');
    await router.isReady();
    const w = mount(EntityView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushPromises();

    const entry = w.get('[data-testid="entity-entry-date"]');
    expect(entry.text()).toContain('Entered 2014-03-04');
    expect(entry.text()).not.toContain('00:00:00');

    const updated = w.get('[data-testid="entity-last-update"]');
    expect(updated.text()).toContain('Last updated 2026-02-10');
    // Date-only: the time component is trimmed off.
    expect(updated.text()).not.toContain('12:29:49');
    w.unmount();
  });

  it('omits the freshness pills when the entity record has no dates', async () => {
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({
          data: [
            {
              entity_id: 57,
              symbol: 'ARID1B',
              hgnc_id: 'HGNC:18040',
              disease_ontology_name: 'Coffin-Siris syndrome 1',
              disease_ontology_id_version: 'OMIM:135900',
              hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
              hpo_mode_of_inheritance_term: 'HP:0000006',
              ndd_phenotype_word: 'Yes',
            },
          ],
          links: [],
          meta: [{}],
        })
      ),
      http.get('*/api/entity/57/status', () => HttpResponse.json([{ category: 'Definitive' }])),
      http.get('*/api/entity/57/review', () => HttpResponse.json([{ synopsis: '', comment: '' }])),
      http.get('*/api/entity/57/publications', () => HttpResponse.json([])),
      http.get('*/api/entity/57/phenotypes', () => HttpResponse.json([])),
      http.get('*/api/entity/57/variation', () => HttpResponse.json([])),
      http.get('*/api/gene/HGNC%3A18040', () => HttpResponse.json([{ symbol: ['ARID1B'] }]))
    );

    const router = makeRouter('/Entities/57');
    await router.isReady();
    const w = mount(EntityView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushPromises();

    expect(w.find('[data-testid="entity-entry-date"]').exists()).toBe(false);
    expect(w.find('[data-testid="entity-last-update"]').exists()).toBe(false);
    w.unmount();
  });

  // -------------------------------------------------------------------------
  // WP-G: Linked disease ontologies card
  // -------------------------------------------------------------------------

  it('WP-G: renders "Linked disease ontologies" SectionCard with LinkedOntologies (layout=card)', async () => {
    const mappingsResponse = {
      disease_ontology_id: 'OMIM:135900',
      disease_ontology_name: 'Coffin-Siris syndrome 1',
      mondo_id: 'MONDO:0032745',
      release_version: '2024-01-01',
      status: 'current',
      mappings: {
        MONDO: [
          {
            id: 'MONDO:0032745',
            label: 'Coffin-Siris syndrome 1',
            predicate: 'exactMatch',
            source: 'mondo_sssom',
          },
        ],
        Orphanet: [
          { id: 'Orphanet:1465', label: null, predicate: 'exactMatch', source: 'mondo_sssom' },
        ],
      },
    };

    server.use(
      http.get('*/api/disease/mappings', () => HttpResponse.json(mappingsResponse)),
      http.get('*/api/entity/', () =>
        HttpResponse.json({
          data: [
            {
              entity_id: 57,
              symbol: 'ARID1B',
              hgnc_id: 'HGNC:18040',
              disease_ontology_name: 'Coffin-Siris syndrome 1',
              disease_ontology_id_version: 'OMIM:135900',
              hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
              hpo_mode_of_inheritance_term: 'HP:0000006',
              ndd_phenotype_word: 'Yes',
              MONDO: 'MONDO:0032745',
            },
          ],
          links: [],
          meta: [{}],
        })
      ),
      http.get('*/api/entity/57/status', () => HttpResponse.json([{ category: 'Definitive' }])),
      http.get('*/api/entity/57/review', () => HttpResponse.json([{ synopsis: '', comment: '' }])),
      http.get('*/api/entity/57/publications', () => HttpResponse.json([])),
      http.get('*/api/entity/57/phenotypes', () => HttpResponse.json([])),
      http.get('*/api/entity/57/variation', () => HttpResponse.json([])),
      http.get('*/api/gene/HGNC%3A18040', () => HttpResponse.json([{ symbol: ['ARID1B'] }]))
    );

    const router = makeRouter('/Entities/57');
    await router.isReady();
    const w = mount(EntityView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushPromises();

    // The "Linked disease ontologies" card title should be present.
    expect(w.text()).toContain('Linked disease ontologies');

    // LinkedOntologies must receive layout="card" — locking the contract so a
    // change to "strip" would fail.
    expect(w.findComponent(LinkedOntologies).props('layout')).toBe('card');

    // LinkedOntologies should render mapping badges with MONDO and Orphanet IDs.
    expect(w.text()).toContain('MONDO:0032745');
    expect(w.text()).toContain('Orphanet:1465');

    w.unmount();
  });

  it('WP-G: the old plain-text MONDO pill (mondoEquivalent) is not rendered', async () => {
    // Return an entity with a MONDO field so the old pill would have appeared.
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({
          data: [
            {
              entity_id: 57,
              symbol: 'ARID1B',
              hgnc_id: 'HGNC:18040',
              disease_ontology_name: 'Coffin-Siris syndrome 1',
              disease_ontology_id_version: 'OMIM:135900',
              hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
              hpo_mode_of_inheritance_term: 'HP:0000006',
              ndd_phenotype_word: 'Yes',
              MONDO: 'MONDO:0032745',
            },
          ],
          links: [],
          meta: [{}],
        })
      ),
      http.get('*/api/entity/57/status', () => HttpResponse.json([{ category: 'Definitive' }])),
      http.get('*/api/entity/57/review', () => HttpResponse.json([{ synopsis: '', comment: '' }])),
      http.get('*/api/entity/57/publications', () => HttpResponse.json([])),
      http.get('*/api/entity/57/phenotypes', () => HttpResponse.json([])),
      http.get('*/api/entity/57/variation', () => HttpResponse.json([])),
      http.get('*/api/gene/HGNC%3A18040', () => HttpResponse.json([{ symbol: ['ARID1B'] }]))
    );

    const router = makeRouter('/Entities/57');
    await router.isReady();
    const w = mount(EntityView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushPromises();

    // The hero entity-metadata-row must NOT contain "MONDO MONDO:0032745" (the
    // old plain-text pill format). The full card "MONDO:0032745" in the ontology
    // section is fine, but the pill in the hero row is gone.
    const heroRow = w.find('.entity-metadata-row');
    // Assert the row is present so a missing row doesn't silently pass the check.
    expect(heroRow.exists()).toBe(true);
    // The old pill rendered as literal text "MONDO <id>" in the entity-meta-pill.
    // It must no longer appear in the hero metadata row.
    expect(heroRow.text()).not.toMatch(/\bMONDO MONDO:/);
    // Also assert no element carrying the old pill pattern exists anywhere.
    expect(w.find('.entity-meta-pill').text()).not.toMatch(/\bMONDO MONDO:/);

    w.unmount();
  });
});
