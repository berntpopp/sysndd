// Unit coverage for the NDDScore gene-table controller extracted from
// NddScoreGeneTable.vue (issue #346). NddScoreGeneTable.spec.ts already
// exercises the full mounted-component flow (DOM filter controls, sort,
// pagination, export, warning rendering); this file adds the
// characterization coverage called out for the extraction: URL hydration of
// range/HPO/search/sort/page/page-size, a monotonic request serial that
// rejects both a stale success and a stale error, a full filter reset, and
// graceful degradation when the HPO term lookup fails. NDDScore is a
// model-derived prediction layer, kept separate from curated SysNDD
// evidence; none of the tests below touch its labelling/wording.

import { defineComponent, h } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi, type Mock } from 'vitest';

import { useNddScoreGeneTable } from './useNddScoreGeneTable';
import { fetchGenePredictions, fetchHpoTerms } from '@/api/nddscore';

vi.mock('@/api/nddscore', () => ({
  fetchGenePredictions: vi.fn(),
  fetchHpoTerms: vi.fn(),
}));

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

function genesPage(data: Array<Record<string, unknown>> = [], overrides: Record<string, unknown> = {}) {
  return { data, total: data.length, page: 1, page_size: 10, ...overrides };
}

async function mountTable() {
  let api!: ReturnType<typeof useNddScoreGeneTable>;
  const Host = defineComponent({
    setup() {
      api = useNddScoreGeneTable();
      return () => h('div');
    },
  });
  const wrapper = mount(Host);
  await flushPromises();
  return { wrapper, api };
}

beforeEach(() => {
  window.history.replaceState({}, '', '/NDDScore');
  (fetchGenePredictions as unknown as Mock).mockReset();
  (fetchHpoTerms as unknown as Mock).mockReset();
  (fetchGenePredictions as unknown as Mock).mockResolvedValue(genesPage());
  (fetchHpoTerms as unknown as Mock).mockResolvedValue([]);
});

describe('useNddScoreGeneTable — URL hydration', () => {
  it('hydrates sort, page, page-size, search, range, and HPO state from the URL on mount', async () => {
    const filter =
      'contains(any,BRCA1),equals(risk_tier,High),range(percentile,10,90),' +
      'any(top_hpo_predictions_json,HP:0001249)';
    window.history.replaceState(
      {},
      '',
      `/NDDScore?sort=-ndd_score&filter=${encodeURIComponent(filter)}&page=2&page_size=25`
    );
    (fetchGenePredictions as unknown as Mock).mockResolvedValueOnce(
      genesPage([], { page: 2, page_size: 25 })
    );

    const { api } = await mountTable();

    expect(api.sortBy.value).toEqual([{ key: 'ndd_score', order: 'desc' }]);
    expect(api.page.value).toBe(2);
    expect(api.pageSize.value).toBe(25);
    expect(api.search.value).toBe('BRCA1');
    expect(api.columnFilters.risk_tier).toBe('High');
    expect(api.rangeFilters.percentile).toEqual({
      operator: 'range',
      value: '10',
      valueMax: '90',
    });
    expect(api.hpoTermFilter.value).toEqual(['HP:0001249']);

    expect(fetchGenePredictions).toHaveBeenCalledWith(
      expect.objectContaining({
        sort: '-ndd_score',
        search: 'BRCA1',
        riskTier: 'High',
        percentileMin: 10,
        percentileMax: 90,
        hpoTerms: ['HP:0001249'],
        page: 2,
        pageSize: 25,
      })
    );
  });

  it('hydrates a gte range operator and an ascending sort with no leading sign', async () => {
    window.history.replaceState(
      {},
      '',
      `/NDDScore?sort=rank&filter=${encodeURIComponent('gte(rank,100)')}`
    );

    const { api } = await mountTable();

    expect(api.sortBy.value).toEqual([{ key: 'rank', order: 'asc' }]);
    expect(api.rangeFilters.rank).toEqual({ operator: 'gte', value: '100', valueMax: '' });
    expect(fetchGenePredictions).toHaveBeenCalledWith(
      expect.objectContaining({ rankMin: 100, rankMax: undefined })
    );
  });

  it('falls back to page 1 / page size 10 / sort "rank" when the URL carries none of them', async () => {
    const { api } = await mountTable();

    expect(api.page.value).toBe(1);
    expect(api.pageSize.value).toBe(10);
    expect(api.sortBy.value).toEqual([{ key: 'rank', order: 'asc' }]);
    expect(api.search.value).toBe('');
    expect(api.hpoTermFilter.value).toEqual([]);
  });
});

describe('useNddScoreGeneTable — request-serial stale rejection', () => {
  it('ignores a stale success that lands after a newer request already succeeded', async () => {
    const stale = deferred<ReturnType<typeof genesPage>>();
    const fresh = deferred<ReturnType<typeof genesPage>>();
    (fetchGenePredictions as unknown as Mock)
      .mockResolvedValueOnce(genesPage()) // initial mount load
      .mockReturnValueOnce(stale.promise) // first reload — slow / stale
      .mockReturnValueOnce(fresh.promise); // second reload — newer, resolves first

    const { api } = await mountTable();

    void api.loadRows();
    void api.loadRows();

    fresh.resolve(genesPage([{ gene_symbol: 'FRESH' }], { total: 1 }));
    await flushPromises();
    expect(api.rows.value).toEqual([{ gene_symbol: 'FRESH' }]);
    expect(api.total.value).toBe(1);

    // The stale request now resolves late; it must not clobber FRESH.
    stale.resolve(genesPage([{ gene_symbol: 'STALE' }], { total: 99 }));
    await flushPromises();
    expect(api.rows.value).toEqual([{ gene_symbol: 'FRESH' }]);
    expect(api.total.value).toBe(1);
  });

  it('ignores a stale error that lands after a newer request already succeeded', async () => {
    const stale = deferred<ReturnType<typeof genesPage>>();
    const fresh = deferred<ReturnType<typeof genesPage>>();
    (fetchGenePredictions as unknown as Mock)
      .mockResolvedValueOnce(genesPage()) // initial mount load
      .mockReturnValueOnce(stale.promise) // first reload — slow / eventually rejects
      .mockReturnValueOnce(fresh.promise); // second reload — newer, resolves first

    const { api } = await mountTable();

    void api.loadRows();
    void api.loadRows();

    fresh.resolve(genesPage([{ gene_symbol: 'FRESH' }], { total: 1 }));
    await flushPromises();
    expect(api.rows.value).toEqual([{ gene_symbol: 'FRESH' }]);
    expect(api.loadError.value).toBe('');

    // The stale request now rejects late; it must not clear FRESH's rows or
    // surface a warning for a request that is no longer the latest one.
    stale.reject(new Error('stale upstream failure'));
    await flushPromises();
    expect(api.rows.value).toEqual([{ gene_symbol: 'FRESH' }]);
    expect(api.loadError.value).toBe('');
  });

  it('surfaces the newest request error even while an older request is still pending', async () => {
    const stale = deferred<ReturnType<typeof genesPage>>();
    const fresh = deferred<ReturnType<typeof genesPage>>();
    (fetchGenePredictions as unknown as Mock)
      .mockResolvedValueOnce(genesPage()) // initial mount load
      .mockReturnValueOnce(stale.promise) // first reload — still pending
      .mockReturnValueOnce(fresh.promise); // second reload — newer, rejects first

    const { api } = await mountTable();

    void api.loadRows();
    void api.loadRows();

    fresh.reject(new Error('newest request failed'));
    await flushPromises();
    expect(api.loadError.value).toBe(
      'NDDScore predictions are not available for the active release.'
    );
    expect(api.rows.value).toEqual([]);

    // The older, now-stale request resolves late; it must not resurrect
    // rows or clear the current (newer) error state.
    stale.resolve(genesPage([{ gene_symbol: 'TOO_LATE' }], { total: 1 }));
    await flushPromises();
    expect(api.rows.value).toEqual([]);
    expect(api.loadError.value).toBe(
      'NDDScore predictions are not available for the active release.'
    );
  });
});

describe('useNddScoreGeneTable — full filter reset', () => {
  it('clears search, column, range, and HPO filters and reloads page 1', async () => {
    const { api } = await mountTable();
    (fetchGenePredictions as unknown as Mock).mockClear();
    (fetchGenePredictions as unknown as Mock).mockResolvedValue(genesPage());

    api.search.value = 'BRCA1';
    api.columnFilters.gene_symbol = 'BRCA1';
    api.columnFilters.risk_tier = 'High';
    api.rangeFilters.rank.operator = 'gte';
    api.rangeFilters.rank.value = '10';
    api.hpoTermFilter.value = ['HP:0001249'];
    api.hpoTermSearch.value = 'seizure';
    api.page.value = 5;

    api.removeFilters();
    await flushPromises();

    expect(api.search.value).toBe('');
    expect(Object.values(api.columnFilters).every((value) => value === '')).toBe(true);
    expect(
      Object.values(api.rangeFilters).every(
        (state) => state.operator === 'any' && state.value === '' && state.valueMax === ''
      )
    ).toBe(true);
    expect(api.hpoTermFilter.value).toEqual([]);
    expect(api.hpoTermSearch.value).toBe('');
    expect(api.page.value).toBe(1);

    expect(fetchGenePredictions).toHaveBeenLastCalledWith(
      expect.objectContaining({
        search: undefined,
        geneSymbol: undefined,
        riskTier: undefined,
        rankMin: undefined,
        hpoTerms: undefined,
        page: 1,
      })
    );
  });
});

describe('useNddScoreGeneTable — HPO-load graceful degradation', () => {
  it('degrades to an empty HPO option list instead of failing the table load', async () => {
    (fetchHpoTerms as unknown as Mock).mockRejectedValueOnce(new Error('HPO lookup unavailable'));
    (fetchGenePredictions as unknown as Mock).mockResolvedValueOnce(
      genesPage([{ gene_symbol: 'KMT2A' }], { total: 1 })
    );

    const { api } = await mountTable();

    expect(api.hpoTermOptions.value).toEqual([]);
    expect(api.filteredHpoTermOptions.value).toEqual([]);
    expect(api.hpoFilterLabel.value).toBe('Any HPO');

    // The independent gene-predictions load still succeeds — one lookup
    // provider failing must not block the table itself.
    expect(api.rows.value).toEqual([{ gene_symbol: 'KMT2A' }]);
    expect(api.loadError.value).toBe('');
  });

  it('keeps the HPO filter dropdown usable (empty, not broken) after the lookup fails', async () => {
    (fetchHpoTerms as unknown as Mock).mockRejectedValueOnce(new Error('network error'));

    const { api } = await mountTable();

    api.hpoTermSearch.value = 'seizure';
    expect(api.filteredHpoTermOptions.value).toEqual([]);
  });
});
