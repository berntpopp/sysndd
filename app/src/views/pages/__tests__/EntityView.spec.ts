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
import EntityViewHero, { type EntityHeroModel } from '../components/EntityViewHero.vue';
import ClinicalSynopsisCard, {
  type ClinicalSynopsisModel,
} from '../components/ClinicalSynopsisCard.vue';
import EntityEvidenceGrid, {
  type EntityEvidenceModel,
} from '../components/EntityEvidenceGrid.vue';

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

// -----------------------------------------------------------------------------
// #346 W2 decomposition: child-contract tests for the three presentation
// components extracted from EntityView.vue. Each is mounted in isolation with
// a hand-built display model — no composables, no MSW handlers — pinning the
// prop contract independently of the parent's fetch orchestration.
// -----------------------------------------------------------------------------

const routerLinkStub = {
  props: ['to'],
  template: "<a :href=\"typeof to === 'string' ? to : '#'\"><slot /></a>",
};

function makeHeroModel(overrides: Partial<EntityHeroModel> = {}): EntityHeroModel {
  return {
    entityIdStr: '57',
    backToResults: null,
    loading: false,
    empty: false,
    error: null,
    hasRecord: true,
    geneSymbol: 'ARID1B',
    hgncId: 'HGNC:18040',
    geneLink: '/Genes/HGNC:18040',
    inheritanceName: 'Autosomal dominant inheritance',
    inheritanceTerm: 'HP:0000006',
    diseaseName: 'Coffin-Siris syndrome 1',
    diseaseOntologyId: 'OMIM:135900',
    diseaseLink: '/Ontology/OMIM:135900',
    categoryLabel: 'Definitive',
    diseaseSourceId: 'OMIM:135900',
    diseaseSourceUrl: 'https://www.omim.org/entry/135900',
    nddStatus: 'Yes',
    entryDate: '2014-03-04 00:00:00',
    lastUpdate: '2026-02-10 12:29:49',
    ...overrides,
  };
}

function mountHero(model: EntityHeroModel) {
  return mount(EntityViewHero, {
    props: { model },
    global: { stubs: { ...heavyChildStubs, RouterLink: routerLinkStub } },
  });
}

describe('EntityViewHero (#346 child contract)', () => {
  it('renders the loading skeleton while the hero resource is loading', () => {
    const w = mountHero(makeHeroModel({ loading: true, hasRecord: false }));
    expect(w.find('[data-testid="section-card-skeleton"]').exists()).toBe(true);
    expect(w.find('[data-testid="entity-hero"]').exists()).toBe(false);
    w.unmount();
  });

  it('renders the SectionCard error state with the hero error message', () => {
    const w = mountHero(makeHeroModel({ error: 'Network error', hasRecord: false }));
    const errorBlock = w.get('[data-testid="section-card-error"]');
    expect(errorBlock.text()).toContain('Network error');
    w.unmount();
  });

  it('renders nothing when the hero resource resolves empty', () => {
    const w = mountHero(makeHeroModel({ empty: true, hasRecord: false }));
    expect(w.find('[data-testid="section-card-content"]').exists()).toBe(false);
    expect(w.find('[data-testid="section-card-skeleton"]').exists()).toBe(false);
    expect(w.find('[data-testid="entity-hero"]').exists()).toBe(false);
    w.unmount();
  });

  it('renders the Gene / Inheritance / Disease unit, classification, and freshness pills from the model', () => {
    const w = mountHero(makeHeroModel());
    const unit = w.get('[data-testid="entity-unit"]');
    const labels = unit.findAll('[data-testid="entity-unit-label"]').map((n) => n.text());
    expect(labels).toEqual(['Gene', 'Inheritance', 'Disease']);
    expect(w.text()).toContain('Definitive');
    expect(w.get('[data-testid="entity-entry-date"]').text()).toContain('Entered 2014-03-04');
    expect(w.get('[data-testid="entity-last-update"]').text()).toContain(
      'Last updated 2026-02-10'
    );
    w.unmount();
  });

  it('builds the OMIM source link from an OMIM disease source id', () => {
    const w = mountHero(
      makeHeroModel({
        diseaseSourceId: 'OMIM:135900',
        diseaseSourceUrl: 'https://www.omim.org/entry/135900',
      })
    );
    const link = w.get('.entity-meta-pill a');
    expect(link.attributes('href')).toBe('https://www.omim.org/entry/135900');
    expect(link.text()).toBe('OMIM:135900');
    w.unmount();
  });

  it('builds the MONDO OBO purl source link from a MONDO disease source id', () => {
    const w = mountHero(
      makeHeroModel({
        diseaseSourceId: 'MONDO:0032745',
        diseaseSourceUrl: 'http://purl.obolibrary.org/obo/MONDO_0032745',
      })
    );
    const link = w.get('.entity-meta-pill a');
    expect(link.attributes('href')).toBe('http://purl.obolibrary.org/obo/MONDO_0032745');
    w.unmount();
  });

  it('renders "Back to results" only when backToResults is set', () => {
    const withBack = mountHero(makeHeroModel({ backToResults: '/Entities?page=2' }));
    expect(withBack.find('a.btn-outline-secondary').exists()).toBe(true);
    withBack.unmount();

    const withoutBack = mountHero(makeHeroModel({ backToResults: null }));
    expect(withoutBack.find('a.btn-outline-secondary').exists()).toBe(false);
    withoutBack.unmount();
  });
});

function makeSynopsisModel(overrides: Partial<ClinicalSynopsisModel> = {}): ClinicalSynopsisModel {
  return {
    loading: false,
    error: null,
    reviewDate: '2025-02-12 11:14:21',
    synopsisText: 'De novo truncating variants with developmental delay.',
    copyButtonLabel: 'Copy',
    ...overrides,
  };
}

function mountSynopsis(model: ClinicalSynopsisModel) {
  return mount(ClinicalSynopsisCard, {
    props: { model },
    global: { stubs: heavyChildStubs },
  });
}

describe('ClinicalSynopsisCard (#346 child contract)', () => {
  it('renders the loading skeleton while the review resource is loading', () => {
    const w = mountSynopsis(makeSynopsisModel({ loading: true }));
    expect(w.find('[data-testid="section-card-skeleton"]').exists()).toBe(true);
    expect(w.find('[data-testid="clinical-synopsis-panel"]').exists()).toBe(false);
    w.unmount();
  });

  it('renders the SectionCard error state with the review error message', () => {
    const w = mountSynopsis(makeSynopsisModel({ error: 'Failed to load review' }));
    expect(w.get('[data-testid="section-card-error"]').text()).toContain('Failed to load review');
    w.unmount();
  });

  it('renders the synopsis text and reviewed-date, and emits copy on button click', async () => {
    const w = mountSynopsis(makeSynopsisModel());
    expect(w.get('[data-testid="clinical-synopsis-panel"]').text()).toContain(
      'De novo truncating variants'
    );
    expect(w.get('[data-testid="clinical-synopsis-header"]').text()).toContain(
      'Last reviewed 2025-02-12 11:14:21'
    );
    const button = w.get('[data-testid="copy-synopsis-button"]');
    expect((button.element as HTMLButtonElement).disabled).toBe(false);
    await button.trigger('click');
    expect(w.emitted('copy')).toHaveLength(1);
    w.unmount();
  });

  it('shows the empty-state message and disables copy when synopsis text is empty', () => {
    const w = mountSynopsis(makeSynopsisModel({ synopsisText: '' }));
    expect(w.get('[data-testid="clinical-synopsis-panel"]').text()).toContain(
      'No clinical synopsis available.'
    );
    const button = w.get('[data-testid="copy-synopsis-button"]');
    expect((button.element as HTMLButtonElement).disabled).toBe(true);
    w.unmount();
  });
});

function makeEvidenceModel(overrides: Partial<EntityEvidenceModel> = {}): EntityEvidenceModel {
  return {
    publications: { loading: false, error: null, additionalRefs: [], geneReviews: [] },
    phenotypes: { loading: false, error: null, list: [] },
    variation: { loading: false, error: null, list: [] },
    ...overrides,
  };
}

function mountGrid(model: EntityEvidenceModel) {
  return mount(EntityEvidenceGrid, {
    props: { model },
    global: { stubs: heavyChildStubs },
  });
}

describe('EntityEvidenceGrid (#346 child contract)', () => {
  it('renders loading skeletons for all four evidence cards', () => {
    const w = mountGrid(
      makeEvidenceModel({
        publications: { loading: true, error: null, additionalRefs: [], geneReviews: [] },
        phenotypes: { loading: true, error: null, list: [] },
        variation: { loading: true, error: null, list: [] },
      })
    );
    expect(w.findAll('[data-testid="section-card-skeleton"]')).toHaveLength(4);
    w.unmount();
  });

  it('renders the SectionCard error state for each of the three resources', () => {
    const w = mountGrid(
      makeEvidenceModel({
        publications: { loading: false, error: 'pubs failed', additionalRefs: [], geneReviews: [] },
        phenotypes: { loading: false, error: 'pheno failed', list: [] },
        variation: { loading: false, error: 'vario failed', list: [] },
      })
    );
    // Publications + Gene Reviews share the publications resource state, so
    // the same error message renders on both cards.
    const errors = w.findAll('[data-testid="section-card-error"]').map((n) => n.text());
    expect(errors.filter((t) => t.includes('pubs failed'))).toHaveLength(2);
    expect(errors.some((t) => t.includes('pheno failed'))).toBe(true);
    expect(errors.some((t) => t.includes('vario failed'))).toBe(true);
    w.unmount();
  });

  it('shows the empty-state message for each of the four evidence cards when no items are linked', () => {
    const w = mountGrid(makeEvidenceModel());
    expect(w.text()).toContain('No publications linked.');
    expect(w.text()).toContain('No GeneReviews linked.');
    expect(w.text()).toContain('No phenotype terms linked.');
    expect(w.text()).toContain('No variation ontology terms linked.');
    w.unmount();
  });

  it('renders publication, gene-review, phenotype, and variation chips with correct links, tooltips, and aria-labels', () => {
    const w = mountGrid(
      makeEvidenceModel({
        publications: {
          loading: false,
          error: null,
          additionalRefs: [
            { publication_id: 'PMID:22405089', publication_type: 'additional_references' },
          ],
          geneReviews: [{ publication_id: 'PMID:23556151', publication_type: 'gene_review' }],
        },
        phenotypes: {
          loading: false,
          error: null,
          list: [{ phenotype_id: 'HP:0001250', HPO_term: 'Seizures', modifier_id: 5 }],
        },
        variation: {
          loading: false,
          error: null,
          list: [{ vario_id: 'VariO:0133', vario_name: 'protein truncation', modifier_id: 3 }],
        },
      })
    );

    const pubChip = w.get('[data-testid="publication-chip-PMID:22405089"]');
    expect(pubChip.attributes('href')).toBe('https://pubmed.ncbi.nlm.nih.gov/22405089');
    expect(pubChip.attributes('data-tooltip')).toBe('Original Article');
    expect(pubChip.attributes('aria-label')).toBe('Original Article PMID:22405089');

    const reviewChip = w.get('[data-testid="publication-chip-PMID:23556151"]');
    expect(reviewChip.attributes('data-tooltip')).toBe('GeneReview Article');

    const phenoChip = w.get('[data-testid="phenotype-chip-HP:0001250"]');
    expect(phenoChip.classes()).toContain('entity-chip--absent');
    expect(phenoChip.attributes('href')).toBe('https://hpo.jax.org/browse/term/HP:0001250');
    expect(phenoChip.attributes('data-tooltip')).toBe('absent | HP:0001250');

    const varioChip = w.get('[data-testid="variation-chip-VariO:0133"]');
    expect(varioChip.classes()).toContain('entity-chip--variable');
    expect(varioChip.attributes('href')).toContain('ebi.ac.uk/ols4');

    w.unmount();
  });
});
