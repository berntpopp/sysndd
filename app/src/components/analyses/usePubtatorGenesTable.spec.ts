// src/components/analyses/usePubtatorGenesTable.spec.ts
//
// Unit coverage for the PubTator gene-table controller extracted from
// PubtatorNDDGenes.vue (issue #346). PubtatorNDDGenes.spec.ts already
// exercises the full mounted-component flow (loading, enrichment rendering,
// row expansion, export, freshness notice); this file adds the
// characterization coverage called out for the extraction: a stale load
// response cannot clobber a newer one, unmount cancels in-flight publication
// fetches, the fspec merge appends exactly one `actions` column, and the
// Plumber scalar-array `meta` shape is normalized before any pagination
// field is applied.

import { defineComponent, h } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';
import { afterEach, beforeEach, describe, expect, it, vi, type Mock } from 'vitest';

import {
  usePubtatorGenesTable,
  normalizePubtatorGenesMeta,
  mergePubtatorGeneFields,
  deriveEnrichmentNotice,
  type PubtatorGenesTableProps,
} from './usePubtatorGenesTable';
import { createPubtatorGeneFields } from './pubtatorEnrichmentDisplay';
import { listPubtatorGenes } from '@/api/publication';

const makeToastSpy = vi.fn();
const exportToExcelSpy = vi.fn().mockResolvedValue(undefined);
const cancelAllSpy = vi.fn();
const resetCacheSpy = vi.fn();

vi.mock('@/api/publication', () => ({
  listPubtatorGenes: vi.fn(),
}));

vi.mock('@/composables/useExcelExport', async () => {
  const { ref } = await import('vue');
  return {
    useExcelExport: () => ({
      isExporting: ref(false),
      exportToExcel: exportToExcelSpy,
    }),
  };
});

vi.mock('@/composables/usePubtatorGenePublications', () => ({
  usePubtatorGenePublications: () => ({
    fetchPublications: vi.fn().mockResolvedValue(undefined),
    getPublications: vi.fn().mockReturnValue([]),
    isLoading: vi.fn().mockReturnValue(false),
    isCached: vi.fn().mockReturnValue(false),
    resetCache: resetCacheSpy,
    cancelAll: cancelAllSpy,
  }),
}));

vi.mock('@/composables', async () => {
  const actual = await vi.importActual<typeof import('@/composables')>('@/composables');
  return {
    ...actual,
    useToast: () => ({ makeToast: makeToastSpy }),
  };
});

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/analyses/pubtator-genes', component: { template: '<div />' } }],
  });
}

const defaultProps: PubtatorGenesTableProps = {
  sortInput: '-enrichment_ratio,-npmi,publication_count',
  filterInput: null,
  pageAfterInput: '',
  pageSizeInput: 10,
  fspecInput: 'gene_symbol,gene_name,publication_count',
};

async function mountTable(props: Partial<PubtatorGenesTableProps> = {}) {
  setActivePinia(createPinia());
  const router = makeRouter();
  await router.push('/analyses/pubtator-genes');
  await router.isReady();

  const emit = vi.fn();
  let api!: ReturnType<typeof usePubtatorGenesTable>;
  const Host = defineComponent({
    setup() {
      api = usePubtatorGenesTable({ ...defaultProps, ...props }, emit);
      return () => h('div');
    },
  });
  const wrapper = mount(Host, { global: { plugins: [router] } });
  await flushPromises();
  return { wrapper, api, emit };
}

function genesResponse(data: Array<Record<string, unknown>>) {
  return {
    data,
    meta: [{ totalItems: data.length, totalPages: 1, currentPage: 1, currentItemID: 0, fspec: [] }],
  };
}

beforeEach(() => {
  makeToastSpy.mockClear();
  exportToExcelSpy.mockClear();
  cancelAllSpy.mockClear();
  resetCacheSpy.mockClear();
  (listPubtatorGenes as unknown as Mock).mockReset();
});

afterEach(() => {
  vi.clearAllMocks();
});

describe('usePubtatorGenesTable', () => {
  it('does not let a stale load response replace a newer filter result', async () => {
    const first = deferred<ReturnType<typeof genesResponse>>();
    const second = deferred<ReturnType<typeof genesResponse>>();
    (listPubtatorGenes as unknown as Mock)
      .mockResolvedValueOnce(genesResponse([])) // initial mount load
      .mockReturnValueOnce(first.promise) // first filter change (slow / stale)
      .mockReturnValueOnce(second.promise); // second, newer filter change (fast)

    const { api } = await mountTable();

    // Two overlapping filter changes fired back to back; the second (newer)
    // request must win regardless of resolution order.
    api.filtered();
    api.filtered();

    second.resolve(genesResponse([{ gene_symbol: 'FRESH', gene_name: 'fresh gene' }]));
    await flushPromises();
    expect((api.items.value as Array<{ gene_symbol: string }>).map((g) => g.gene_symbol)).toEqual([
      'FRESH',
    ]);

    // The stale first response now lands late; it must not clobber FRESH.
    first.resolve(genesResponse([{ gene_symbol: 'STALE', gene_name: 'stale gene' }]));
    await flushPromises();
    expect((api.items.value as Array<{ gene_symbol: string }>).map((g) => g.gene_symbol)).toEqual([
      'FRESH',
    ]);
  });

  it('cancels in-flight publication fetches on unmount', async () => {
    (listPubtatorGenes as unknown as Mock).mockResolvedValue(genesResponse([]));
    const { wrapper } = await mountTable();

    expect(cancelAllSpy).not.toHaveBeenCalled();
    wrapper.unmount();
    expect(cancelAllSpy).toHaveBeenCalledTimes(1);
  });

  it('resets the per-gene publication cache on every load', async () => {
    (listPubtatorGenes as unknown as Mock).mockResolvedValue(genesResponse([]));
    const { api } = await mountTable();

    const callsAfterMount = resetCacheSpy.mock.calls.length;
    expect(callsAfterMount).toBeGreaterThan(0);

    api.filtered();
    await flushPromises();
    expect(resetCacheSpy.mock.calls.length).toBeGreaterThan(callsAfterMount);
  });
});

describe('mergePubtatorGeneFields', () => {
  it('appends exactly one trailing actions column', () => {
    const current = createPubtatorGeneFields();
    const inbound = [
      { key: 'gene_symbol', label: 'Gene', sortable: true, count: 10, count_filtered: 4 },
      { key: 'gene_name', label: 'Name', sortable: true },
    ];

    const merged = mergePubtatorGeneFields(inbound, current);

    const actionsEntries = merged.filter((f) => f.key === 'actions');
    expect(actionsEntries).toHaveLength(1);
    expect(merged.at(-1)?.key).toBe('actions');
  });

  it('drops a stray inbound actions column instead of duplicating it', () => {
    const current = createPubtatorGeneFields();
    const inbound = [
      { key: 'gene_symbol', label: 'Gene' },
      { key: 'actions', label: 'unexpected server actions column' },
    ];

    const merged = mergePubtatorGeneFields(inbound, current);

    expect(merged.filter((f) => f.key === 'actions')).toHaveLength(1);
  });

  it('preserves locally-owned filterable/class for a matching inbound key', () => {
    const current = [
      { key: 'gene_symbol', label: 'Gene', filterable: true, class: 'text-start' },
    ];
    const inbound = [{ key: 'gene_symbol', label: 'Gene (server)', sortable: true }];

    const merged = mergePubtatorGeneFields(inbound, current);
    const geneSymbolField = merged.find((f) => f.key === 'gene_symbol');

    expect(geneSymbolField?.filterable).toBe(true);
    expect(geneSymbolField?.class).toBe('text-start');
    expect(geneSymbolField?.label).toBe('Gene (server)');
  });
});

describe('normalizePubtatorGenesMeta', () => {
  it('unwraps a Plumber scalar-array meta payload before pagination fields are read', () => {
    const meta = normalizePubtatorGenesMeta([
      { totalItems: 42, totalPages: 5, currentPage: 2, enrichmentStatus: 'current' },
    ]);
    expect(meta).toEqual({
      totalItems: 42,
      totalPages: 5,
      currentPage: 2,
      enrichmentStatus: 'current',
    });
  });

  it('returns null for an empty meta array so pagination state is left untouched', () => {
    expect(normalizePubtatorGenesMeta([])).toBeNull();
  });

  it('returns null when meta is missing entirely (older API response shape)', () => {
    expect(normalizePubtatorGenesMeta(undefined)).toBeNull();
    expect(normalizePubtatorGenesMeta(null)).toBeNull();
  });
});

describe('deriveEnrichmentNotice', () => {
  it('is silent when the ranking is current or the status is absent', () => {
    expect(deriveEnrichmentNotice(undefined, undefined)).toBeNull();
    expect(deriveEnrichmentNotice('current', undefined)).toBeNull();
  });

  it('surfaces a missing-ranking notice', () => {
    expect(deriveEnrichmentNotice('missing', undefined)).toContain('not yet computed');
  });

  it('surfaces a stale-ranking notice with the refreshed date when present', () => {
    const notice = deriveEnrichmentNotice('stale', '2026-01-01T00:00:00Z');
    expect(notice).toContain('out of date');
    expect(notice).toContain('last refreshed');
  });
});
