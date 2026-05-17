import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import NddScoreGeneDetail from './NddScoreGeneDetail.vue';

const routeState = vi.hoisted(() => ({
  query: {} as Record<string, string>,
}));

const nddScoreApi = vi.hoisted(() => ({
  fetchGeneDetail: vi.fn(),
}));

vi.mock('vue-router', () => ({
  RouterLink: {
    props: ['to'],
    template: '<a :href="to"><slot /></a>',
  },
  useRoute: () => ({ query: routeState.query }),
}));

vi.mock('@/api/nddscore', () => ({
  fetchGeneDetail: nddScoreApi.fetchGeneDetail,
}));

function prediction(overrides: Record<string, unknown> = {}) {
  return {
    hgnc_id: 'HGNC:2024',
    gene_symbol: 'CLCN4',
    ndd_score: 0.982,
    rank: 12,
    risk_tier: 'Very High',
    confidence_tier: 'High',
    known_sysndd_gene: 1,
    inheritance_probabilities_json: JSON.stringify({
      AD: 0.12,
      AR: 0.05,
      XLD: 0.71,
      XLR: 0.12,
    }),
    top_hpo_predictions_json: JSON.stringify([
      {
        phenotype_id: 'HP:0001249',
        phenotype_name: 'Intellectual disability',
        probability: 0.91,
      },
    ]),
    shap_group_contributions_json: JSON.stringify({
      constraint: 0.42,
      network: 0.31,
    }),
    prediction_note:
      'CLCN4 is predicted as a candidate NDD gene (score 0.98). Note: SHAP attributions reflect statistical associations.',
    ...overrides,
  };
}

describe('NddScoreGeneDetail', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    routeState.query = {};
    nddScoreApi.fetchGeneDetail.mockReset();
    nddScoreApi.fetchGeneDetail.mockResolvedValue(prediction());
  });

  it('does not render the predictions back link', async () => {
    routeState.query = {
      returnTo:
        '/NDDScore?sort=%2Brank&filter=equals%28model_split%2Cunseen%29&page=3&page_size=10',
    };

    const wrapper = mount(NddScoreGeneDetail, {
      props: { hgncIdOrSymbol: 'CLCN4' },
    });

    await flushPromises();

    expect(wrapper.find('.ndd-gene-detail__back-link').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Back to predictions');
  });

  it('renders prediction details without the old curated-evidence explainer block', async () => {
    routeState.query = {};
    const wrapper = mount(NddScoreGeneDetail, {
      props: { hgncIdOrSymbol: 'CLCN4' },
    });

    await flushPromises();

    expect(wrapper.get('.ndd-gene-detail__title').text()).toBe('NDDScore gene prediction');
    expect(wrapper.text()).toContain('CLCN4');
    expect(wrapper.text()).toContain('Very High');
    expect(wrapper.text()).toContain('Intellectual disability');
    expect(wrapper.text()).toContain('Known SysNDD gene');
    expect(wrapper.find('a[href="/Genes/HGNC:2024"]').exists()).toBe(true);
    expect(wrapper.find('[title*="Model probability-like score"]').exists()).toBe(true);
    expect(wrapper.find('[title*="Open the curated SysNDD gene page"]').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('Curated SysNDD evidence');
    expect(wrapper.text()).not.toContain('read as a distinct evidence source');
    expect(wrapper.text()).not.toContain('predicted as a candidate NDD gene');
    expect(wrapper.text()).not.toContain('SHAP attributions reflect statistical associations');
  });

  it('restores cached gene detail immediately when browser history remounts the page', async () => {
    nddScoreApi.fetchGeneDetail.mockResolvedValueOnce(
      prediction({
        hgnc_id: 'HGNC:29140',
        gene_symbol: 'MAU2',
        known_sysndd_gene: 0,
      })
    );

    const firstVisit = mount(NddScoreGeneDetail, {
      props: { hgncIdOrSymbol: 'HGNC:29140' },
    });

    await flushPromises();
    expect(firstVisit.text()).toContain('MAU2');
    firstVisit.unmount();

    nddScoreApi.fetchGeneDetail.mockImplementationOnce(() => new Promise(() => {}));

    const restoredVisit = mount(NddScoreGeneDetail, {
      props: { hgncIdOrSymbol: 'HGNC:29140' },
    });

    await flushPromises();

    expect(restoredVisit.text()).toContain('MAU2');
    expect(restoredVisit.text()).not.toContain('Loading gene prediction.');
    expect(nddScoreApi.fetchGeneDetail).toHaveBeenCalledTimes(1);
  });
});
