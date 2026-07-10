// Mounted-component coverage for the NDDScore gene predictions table: DOM
// filter controls, sort, pagination, gene-detail links, and warning
// rendering. Load/URL/state/action logic lives in useNddScoreGeneTable.ts
// (issue #346); useNddScoreGeneTable.spec.ts adds the characterization
// coverage for that extraction (URL hydration, request-serial stale
// rejection, full filter reset, HPO-load graceful degradation) that does not
// need a full component mount.

import { flushPromises, mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import NddScoreGeneTable from './NddScoreGeneTable.vue';

const mocks = vi.hoisted(() => ({
  push: vi.fn(),
  fetchGenePredictions: vi.fn().mockResolvedValue({
    data: [],
    total: 0,
    page: 1,
    page_size: 10,
  }),
  fetchHpoTerms: vi.fn().mockResolvedValue([
    { phenotype_id: 'HP:0001249', phenotype_name: 'Intellectual disability' },
    { phenotype_id: 'HP:0001250', phenotype_name: 'Seizure' },
  ]),
}));

vi.mock('vue-router', () => ({
  RouterLink: {
    props: ['to'],
    template: '<a :href="to"><slot /></a>',
  },
  useRouter: () => ({ push: mocks.push }),
}));

vi.mock('@/api/nddscore', () => ({
  fetchGenePredictions: mocks.fetchGenePredictions,
  fetchHpoTerms: mocks.fetchHpoTerms,
}));

function selectWithOption(wrapper: ReturnType<typeof mount>, value: string) {
  const select = wrapper
    .findAll('select')
    .find((candidate) =>
      Array.from((candidate.element as HTMLSelectElement).options).some(
        (option) => option.value === value
      )
    );

  if (!select) {
    throw new Error(`No select found with option ${value}`);
  }

  return select;
}

describe('NddScoreGeneTable', () => {
  beforeEach(() => {
    window.history.replaceState({}, '', '/NDDScore');
    mocks.push.mockClear();
    mocks.fetchGenePredictions.mockClear();
    mocks.fetchHpoTerms.mockClear();
  });

  it('marks the table as machine-learning predictions rather than curated evidence', async () => {
    const wrapper = mount(NddScoreGeneTable);
    await flushPromises();

    expect(wrapper.text()).toContain('not manually curated SysNDD classifications');
  });

  it('uses the same filter control treatment for range, text, select, and HPO filters', async () => {
    const wrapper = mount(NddScoreGeneTable);
    await flushPromises();

    expect(wrapper.get('input[placeholder="Filter Gene"]').classes()).toContain(
      'nddscore-gene-table__filter-control'
    );
    const riskTierSelect = selectWithOption(wrapper, 'Very High');
    expect(riskTierSelect.classes()).toContain('nddscore-gene-table__filter-control');
    // aria-label now includes the current value (e.g. "NDD score filter: Any NDD
    // score") so the accessible name contains the visible toggle text — match the prefix.
    expect(wrapper.get('[aria-label^="NDD score filter"]').classes()).toContain(
      'nddscore-gene-table__filter-dropdown--empty'
    );
    expect(wrapper.get('[data-testid="nddscore-hpo-filter"]').classes()).toContain(
      'nddscore-gene-table__filter-dropdown--empty'
    );
  });

  it('offers live NDDScore values as column filters', async () => {
    const wrapper = mount(NddScoreGeneTable);
    await flushPromises();

    expect(wrapper.text()).toContain('Very Low');
    expect(wrapper.text()).toContain('Medium');

    const confidenceSelect = selectWithOption(wrapper, 'Medium');
    expect((confidenceSelect.element as HTMLSelectElement).options[0].value).toBe('');
    await confidenceSelect.setValue('Medium');
    await flushPromises();

    expect(mocks.fetchGenePredictions).toHaveBeenLastCalledWith(
      expect.objectContaining({
        confidenceTier: 'Medium',
        page: 1,
      })
    );

    await selectWithOption(wrapper, 'Medium').setValue('');
    await flushPromises();

    expect(mocks.fetchGenePredictions).toHaveBeenLastCalledWith(
      expect.objectContaining({
        confidenceTier: undefined,
        page: 1,
      })
    );
  });

  it('sends gene text and split column filters to the API', async () => {
    const wrapper = mount(NddScoreGeneTable);
    await flushPromises();

    expect(wrapper.text()).not.toContain('HGNC ID');

    const geneInput = wrapper.find('input[placeholder="Filter Gene"]');
    await geneInput.setValue('KMT2A');
    await flushPromises();

    expect(mocks.fetchGenePredictions).toHaveBeenLastCalledWith(
      expect.objectContaining({
        geneSymbol: 'KMT2A',
        page: 1,
      })
    );
    expect(decodeURIComponent(window.location.search)).toContain(
      'filter=equals(gene_symbol,KMT2A)'
    );

    const splitSelect = selectWithOption(wrapper, 'unseen');
    await splitSelect.setValue('unseen');
    await flushPromises();

    expect(mocks.fetchGenePredictions).toHaveBeenLastCalledWith(
      expect.objectContaining({
        geneSymbol: 'KMT2A',
        modelSplit: 'unseen',
        page: 1,
      })
    );
    expect(decodeURIComponent(window.location.search)).toContain('equals(model_split,unseen)');
  });

  it('carries the current table URL when linking to a gene detail page', async () => {
    window.history.replaceState(
      {},
      '',
      '/NDDScore?sort=%2Brank&filter=equals%28model_split%2Cunseen%29&page=3&page_size=10'
    );
    mocks.fetchGenePredictions.mockResolvedValueOnce({
      data: [
        {
          hgnc_id: 'HGNC:6512',
          gene_symbol: 'KMT2A',
          ndd_score: 0.98,
          rank: 42,
          percentile: 99,
        },
      ],
      total: 50,
      page: 3,
      page_size: 10,
    });

    const wrapper = mount(NddScoreGeneTable);
    await flushPromises();

    const href = wrapper.get('[to^="/NDDScore/Gene/HGNC%3A6512"]').attributes('to');
    expect(decodeURIComponent(href)).toContain(
      'returnTo=/NDDScore?sort=%2Brank&filter=equals%28model_split%2Cunseen%29&page=3&page_size=10'
    );
  });

  it('sends typed numeric, inheritance, and HPO filters to the API', async () => {
    const wrapper = mount(NddScoreGeneTable);
    await flushPromises();

    expect(mocks.fetchHpoTerms).toHaveBeenCalledTimes(1);
    mocks.fetchGenePredictions.mockClear();

    await wrapper.find('select[aria-label="Rank filter operator"]').setValue('lte');
    await flushPromises();
    expect(mocks.fetchGenePredictions).not.toHaveBeenCalled();

    await wrapper.find('input[aria-label="Rank filter value"]').setValue('200');
    await flushPromises();

    expect(mocks.fetchGenePredictions).toHaveBeenLastCalledWith(
      expect.objectContaining({
        nddScoreMax: undefined,
        rankMax: 200,
        percentileMax: undefined,
        pageSize: 10,
      })
    );

    await wrapper.find('select[aria-label="Percentile filter operator"]').setValue('gte');
    await wrapper.find('input[aria-label="Percentile filter value"]').setValue('95');
    await selectWithOption(wrapper, 'AD').setValue('AD');
    await flushPromises();

    expect(mocks.fetchGenePredictions).toHaveBeenLastCalledWith(
      expect.objectContaining({
        rankMax: 200,
        percentileMin: 95,
        topInheritanceMode: 'AD',
      })
    );

    expect(wrapper.find('select[multiple]').exists()).toBe(false);
    const hpoFilter = wrapper.get('[data-testid="nddscore-hpo-filter"]');
    await hpoFilter.get('[data-testid="nddscore-hpo-option-HP:0001249"]').trigger('click');
    await flushPromises();
    await wrapper
      .get('[data-testid="nddscore-hpo-filter"]')
      .get('[data-testid="nddscore-hpo-option-HP:0001250"]')
      .trigger('click');
    await flushPromises();

    expect(mocks.fetchGenePredictions).toHaveBeenLastCalledWith(
      expect.objectContaining({
        hpoTerms: ['HP:0001249', 'HP:0001250'],
      })
    );
  });

  it('renders an inline warning when predictions cannot be loaded', async () => {
    mocks.fetchGenePredictions.mockRejectedValueOnce(new Error('no active release'));

    const wrapper = mount(NddScoreGeneTable);
    await flushPromises();

    expect(wrapper.text()).toContain(
      'NDDScore predictions are not available for the active release.'
    );
  });
});
