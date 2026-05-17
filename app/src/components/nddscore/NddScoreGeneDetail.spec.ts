import { flushPromises, mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import NddScoreGeneDetail from './NddScoreGeneDetail.vue';

vi.mock('@/api/nddscore', () => ({
  fetchGeneDetail: vi.fn().mockResolvedValue({
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
  }),
}));

describe('NddScoreGeneDetail', () => {
  it('renders prediction details without the old curated-evidence explainer block', async () => {
    const wrapper = mount(NddScoreGeneDetail, {
      props: { hgncIdOrSymbol: 'CLCN4' },
      global: {
        stubs: {
          RouterLink: {
            props: ['to'],
            template: '<a :href="to"><slot /></a>',
          },
        },
      },
    });

    await flushPromises();

    expect(wrapper.text()).toContain('CLCN4');
    expect(wrapper.text()).toContain('Very High');
    expect(wrapper.text()).toContain('Intellectual disability');
    expect(wrapper.text()).toContain('Known SysNDD gene');
    expect(wrapper.find('a[href="/Genes/HGNC:2024"]').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('Curated SysNDD evidence');
    expect(wrapper.text()).not.toContain('read as a distinct evidence source');
  });
});
