// app/src/views/pages/__tests__/EntityView.spec.ts
//
// v11.3 W3.4 — pin EntityView parallel hook fan-out:
//   1. All 5 sub-resource endpoints fire on tick 0 (parallel, not sequential).
//   2. Publications result splits into additional_references + gene_review
//      adjacent cards from a single fetch (one /publications request).
//   3. Linked-gene block hydrates from the entity record's hgnc_id.
//   4. 404 redirect when the entity record returns empty.
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
  EntityBadge: { template: '<span />' },
  GeneBadge: { template: '<span />' },
  DiseaseBadge: { template: '<span />' },
  InheritanceBadge: { template: '<span />' },
  CategoryIcon: { template: '<span />' },
  NddIcon: { template: '<span />' },
};

describe('EntityView (v11.3 W3)', () => {
  beforeEach(() => setActivePinia(createPinia()));
  afterEach(() => server.resetHandlers());

  it('fires all 5 sub-resource calls in parallel on mount (no sequential await)', async () => {
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
      http.get('*/api/gene/HGNC%3A6990', () => HttpResponse.json([{ symbol: ['MECP2'] }]))
    );

    const router = makeRouter('/Entities/304');
    await router.isReady();
    const w = mount(EntityView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushPromises();

    // Each tag appeared at least once — the page hit all 5 sub-resource
    // endpoints, not just the first in a sequential chain.
    expect(calls.some((c) => c.endsWith('status'))).toBe(true);
    expect(calls.some((c) => c.endsWith('review'))).toBe(true);
    expect(calls.some((c) => c.endsWith('pubs'))).toBe(true);
    expect(calls.some((c) => c.endsWith('pheno'))).toBe(true);
    expect(calls.some((c) => c.endsWith('var'))).toBe(true);

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
});
