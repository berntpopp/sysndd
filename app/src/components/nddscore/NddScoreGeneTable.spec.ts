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

    const geneInput = wrapper.find('input[placeholder=".. Gene .."]');
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
});
