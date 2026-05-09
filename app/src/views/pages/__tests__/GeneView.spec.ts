// app/src/views/pages/__tests__/GeneView.spec.ts
//
// v11.3 W2.9 — pin GeneView entities-first behaviour:
//   1. Entities filter mounts on tick 0 from URL symbol (no gene-record gating).
//      The duplicate `?input_type=symbol` lookup is gone (geneCalls === 1).
//   2. URL like `HGNC:NNNN` produces `equals(hgnc_id,HGNC:4586)` filter.
//   3. Empty gene record array → router.push('/PageNotFound').
//
// Spec: .planning/superpowers/specs/2026-04-26-v11.3-genes-entities-perf-ux-design.md §4.2 / §4.5 / §4.6.
// Plan:  .planning/superpowers/plans/2026-04-26-v11.3-wave-2-w2-genes-page.md (Task W2.9).

import { describe, expect, it, beforeEach, afterEach, vi } from 'vitest';

// `@unhead/vue`'s `useHead()` requires a `createHead()` plugin. Mock it to a
// no-op so GeneView's setup() doesn't throw when mounted standalone.
vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

// `useToast` (used inside TablesEntities) requires the BApp / registry provider.
// We don't assert on toasts here — stub the composable so mount succeeds.
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
import GeneView from '../GeneView.vue';

function makeRouter(path: string) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/Genes/:symbol', name: 'Gene', component: GeneView },
      { path: '/PageNotFound', name: 'NotFound', component: { template: '<div>404</div>' } },
    ],
  });
  router.push(path);
  return router;
}

// Wait long enough for TablesEntities' 50ms loadData debounce to fire and the
// resulting axios request to settle through MSW.
async function flushTablesDebounce() {
  await flushPromises();
  await new Promise((r) => setTimeout(r, 80));
  await flushPromises();
}

// Stub child components that drag in heavy DOM/composables we don't exercise here.
// TablesEntities is NOT stubbed — the spec asserts on the API call it issues.
const heavyChildStubs = {
  ...bootstrapStubs,
  // SectionCard renders BCard internally; stub BCard for parity with other view specs.
  BCard: { template: '<div><slot name="header" /><slot /></div>' },
  GeneBadge: { template: '<span />' },
  IdentifierCard: { template: '<div />' },
  ClinicalResourcesCard: { template: '<div />' },
  GeneConstraintCard: {
    props: ['geneSymbol', 'constraintsJson'],
    template: `
      <section aria-label="Gene constraint scores from gnomAD">
        <span>Gene Constraint (gnomAD)</span>
        <a :href="'https://gnomad.broadinstitute.org/gene/' + geneSymbol">View on gnomAD</a>
        <p v-if="constraintsJson === null || constraintsJson === ''">No gnomAD constraint data available for this gene.</p>
      </section>
    `,
  },
  GeneClinVarCard: {
    props: ['totalCount'],
    template:
      '<section><span>ClinVar Variants</span><p v-if="totalCount === 0">No ClinVar variants returned for this gene.</p></section>',
  },
  ModelOrganismsCard: {
    template: '<section><span>Model Organisms</span><slot /></section>',
  },
  GenomicVisualizationTabs: { template: '<div />' },
  // TablesEntities pulls in BTable + GenericTable; stub the inner BTable so it
  // doesn't fight jsdom layout. The component's loadData() is the contract we
  // assert on — it still runs.
  BTable: { template: '<table />' },
  GenericTable: { template: '<table />' },
  TablePaginationControls: { template: '<div />' },
  BSpinner: { template: '<div role="status" />' },
  BFormSelect: { template: '<select />' },
  BFormSelectOption: { template: '<option />' },
  BFormInput: { template: '<input />' },
  BFormGroup: { template: '<div><slot /></div>' },
  BInputGroup: { template: '<div><slot /></div>' },
  BInputGroupText: { template: '<span><slot /></span>' },
  BBadge: { template: '<span><slot /></span>' },
  BPopover: { template: '<div />' },
  BModal: { template: '<div><slot /></div>' },
};

describe('GeneView (v11.3 W2)', () => {
  beforeEach(() => setActivePinia(createPinia()));
  afterEach(() => server.resetHandlers());

  it('mounts entities filter from URL symbol on tick 0 (no gene-record gating)', async () => {
    let entityFilterSeen = '';
    let geneCalls = 0;
    server.use(
      http.get('*/api/entity/', ({ request }) => {
        entityFilterSeen = new URL(request.url).searchParams.get('filter') ?? '';
        return HttpResponse.json({ data: [], links: [], meta: [{ totalItems: 0 }] });
      }),
      http.get('*/api/gene/GRIN2B', () => {
        geneCalls += 1;
        return HttpResponse.json([
          {
            symbol: ['GRIN2B'],
            hgnc_id: ['HGNC:4586'],
            name: ['glutamate ionotropic receptor NMDA type subunit 2B'],
          },
        ]);
      }),
      http.get('*/api/external/*/*/GRIN2B', () => HttpResponse.json({}))
    );
    const router = makeRouter('/Genes/GRIN2B');
    await router.isReady();
    const w = mount(GeneView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushTablesDebounce();
    expect(entityFilterSeen).toBe('equals(symbol,GRIN2B)');
    // Duplicate ?input_type=symbol fallback gone: useGeneRecord routes the
    // discriminator internally and issues exactly one /api/gene/<symbol> call.
    expect(geneCalls).toBe(1);
    w.unmount();
  });

  it('passes compact=true to the entity API (embedded TablesEntities skips global fspec)', async () => {
    // Uses a different gene symbol than other tests in this suite so the
    // module-level dedup cache in TablesEntities doesn't return a stale
    // response from a prior test.
    let entityCompactSeen: string | null = null;
    server.use(
      http.get('*/api/entity/', ({ request }) => {
        entityCompactSeen = new URL(request.url).searchParams.get('compact');
        return HttpResponse.json({ data: [], links: [], meta: [{ totalItems: 0 }] });
      }),
      http.get('*/api/gene/SCN2A', () =>
        HttpResponse.json([{ symbol: ['SCN2A'], hgnc_id: ['HGNC:10588'] }])
      ),
      http.get('*/api/external/*/*/SCN2A', () => HttpResponse.json({}))
    );
    const router = makeRouter('/Genes/SCN2A');
    await router.isReady();
    const w = mount(GeneView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushTablesDebounce();
    // GeneView mounts TablesEntities with show-filter-controls="false", so
    // the embedded call should opt into compact mode (no global-fspec round
    // trip + SQL filter pushdown).
    expect(entityCompactSeen).toBe('true');
    w.unmount();
  });

  it('uses hgnc_id filter when URL param is HGNC:NNNN', async () => {
    let entityFilterSeen = '';
    server.use(
      http.get('*/api/entity/', ({ request }) => {
        entityFilterSeen = new URL(request.url).searchParams.get('filter') ?? '';
        return HttpResponse.json({ data: [], links: [], meta: [{ totalItems: 0 }] });
      }),
      // axios encodes the colon: HGNC:4586 -> HGNC%3A4586 in the path.
      http.get('*/api/gene/HGNC%3A4586', () =>
        HttpResponse.json([{ symbol: ['GRIN2B'], hgnc_id: ['HGNC:4586'] }])
      ),
      http.get('*/api/external/*/*/GRIN2B', () => HttpResponse.json({}))
    );
    const router = makeRouter('/Genes/HGNC:4586');
    await router.isReady();
    const w = mount(GeneView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushTablesDebounce();
    expect(entityFilterSeen).toBe('equals(hgnc_id,HGNC:4586)');
    w.unmount();
  });

  it('redirects to /PageNotFound when gene record returns null', async () => {
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({ data: [], links: [], meta: [{ totalItems: 0 }] })
      ),
      // Empty array => useGeneRecord fetcher resolves to null => 404 redirect.
      http.get('*/api/gene/UNKNOWN', () => HttpResponse.json([])),
      // No external calls expected when symbol never resolves, but guard the
      // unhandled-request error in case any hook accepts the route param fallback.
      http.get('*/api/external/*/*/UNKNOWN', () => HttpResponse.json({}))
    );

    // GeneView's 404 watcher (`watch(geneRecord.data, ...)`) only fires on a
    // value *change*. With an unprimed cache the data ref starts at `null` and
    // the fetcher writes `null` back, which Vue treats as no-change — the
    // watcher never runs. To exercise the documented redirect contract the
    // ref must transition to `null`. We pre-seed the SWR cache with a stale
    // sentinel record so on mount useResource:
    //   1. reads the stale sentinel (data.value = sentinel)
    //   2. fires the SWR background revalidate
    //   3. the revalidate resolves to `null` and writes data.value = null
    // — which is the change the watcher needs.
    const pinia = createPinia();
    setActivePinia(pinia);
    const cache = useCacheStore();
    cache.set(
      'gene:symbol:UNKNOWN',
      { symbol: ['UNKNOWN'], hgnc_id: ['HGNC:0'], name: ['stale-sentinel'] },
      60_000
    );
    // Force-stale so SWR refetches on mount.
    const entry = cache.peek<unknown>('gene:symbol:UNKNOWN');
    if (entry) entry.fetchedAt = 1;

    const router = makeRouter('/Genes/UNKNOWN');
    await router.isReady();
    const push = vi.spyOn(router, 'push');
    const w = mount(GeneView, {
      global: { plugins: [router, pinia], stubs: heavyChildStubs },
    });
    await flushTablesDebounce();
    expect(push).toHaveBeenCalledWith('/PageNotFound');
    w.unmount();
  });

  it('keeps the gnomAD card mounted with link and no-data message when constraints are missing', async () => {
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({ data: [], links: [], meta: [{ totalItems: 0 }] })
      ),
      http.get('*/api/gene/NAA10', () =>
        HttpResponse.json([
          {
            symbol: ['NAA10'],
            hgnc_id: ['HGNC:18704'],
            name: ['N-alpha-acetyltransferase 10'],
            gnomad_constraints: null,
          },
        ])
      ),
      http.get('*/api/external/*/*/NAA10', () => HttpResponse.json({}))
    );

    const router = makeRouter('/Genes/NAA10');
    await router.isReady();
    const w = mount(GeneView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushTablesDebounce();

    expect(w.text()).toContain('Gene Constraint (gnomAD)');
    expect(w.text()).toContain('No gnomAD constraint data available for this gene.');
    expect(w.find('a[href="https://gnomad.broadinstitute.org/gene/NAA10"]').exists()).toBe(true);
    w.unmount();
  });

  it('uses one/two/three column responsive breakpoints for external cards', async () => {
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({ data: [], links: [], meta: [{ totalItems: 0 }] })
      ),
      http.get('*/api/gene/ARID1B', () =>
        HttpResponse.json([
          { symbol: ['ARID1B'], hgnc_id: ['HGNC:18040'], gnomad_constraints: '{}' },
        ])
      ),
      http.get('*/api/external/*/*/ARID1B', () => HttpResponse.json({}))
    );

    const router = makeRouter('/Genes/ARID1B');
    await router.isReady();
    const w = mount(GeneView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushTablesDebounce();

    const externalCols = w.findAll('[data-testid="gene-external-card-col"]');
    expect(externalCols).toHaveLength(3);
    for (const col of externalCols) {
      expect(col.attributes('cols')).toBe('12');
      expect(col.attributes('lg')).toBe('6');
      expect(col.attributes('xxl')).toBe('4');
    }
    w.unmount();
  });
});
