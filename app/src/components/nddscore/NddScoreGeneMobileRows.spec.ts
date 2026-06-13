import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import NddScoreGeneMobileRows from './NddScoreGeneMobileRows.vue';

vi.mock('vue-router', () => ({
  RouterLink: {
    props: ['to'],
    template: '<a :href="to"><slot /></a>',
  },
}));

const bLinkStub = {
  props: ['to', 'href'],
  template: '<a :href="to || href"><slot /></a>',
};

function mountRows(items: Array<Record<string, unknown>>) {
  return mount(NddScoreGeneMobileRows, {
    props: { items },
    global: {
      stubs: {
        BLink: bLinkStub,
      },
    },
  });
}

describe('NddScoreGeneMobileRows', () => {
  it('renders a scannable prediction card with gene, rank, score, tiers, and toggleable details', async () => {
    const wrapper = mountRows([
      {
        gene_symbol: 'CLCN4',
        hgnc_id: 'HGNC:2022',
        ndd_score: 0.994,
        rank: 1,
        percentile: 100,
        risk_tier: 'Very High',
        confidence_tier: 'High',
        known_sysndd_gene: true,
        model_split: 'train',
        top_inheritance_mode: 'XLD',
        n_predicted_hpo: 2,
        top_hpo_predictions_json: [
          { phenotype_name: 'Intellectual disability', probability: 0.998 },
          { phenotype_name: 'Seizure', probability: 0.832 },
        ],
      },
    ]);

    // Collapsed headline metrics are readable, not truncated.
    expect(wrapper.text()).toContain('CLCN4');
    expect(wrapper.text()).toContain('#1');
    expect(wrapper.text()).toContain('0.994');
    expect(wrapper.text()).toContain('Very High');
    expect(wrapper.text()).toContain('High');
    expect(wrapper.text()).toContain('Known');

    // Gene badge links to the NDDScore gene detail page; "Known" links to curated gene page.
    expect(wrapper.get('a[href="/NDDScore/Gene/HGNC%3A2022"]').text()).toContain('CLCN4');
    expect(wrapper.get('a[href="/Genes/HGNC:2022"]').text()).toContain('Known');

    // Secondary detail is hidden until requested.
    const detailsButton = wrapper.get('button');
    expect(detailsButton.attributes('aria-expanded')).toBe('false');
    expect(wrapper.find('dl').exists()).toBe(false);

    await detailsButton.trigger('click');

    expect(detailsButton.attributes('aria-expanded')).toBe('true');
    const details = wrapper.get('dl');
    expect(details.text()).toContain('HGNC:2022');
    expect(details.text()).toContain('100.0%');
    expect(details.text()).toContain('XLD');
    expect(details.text()).toContain('train');
    expect(details.text()).toContain('Intellectual disability');
    expect(details.text()).toContain('Seizure');
  });

  it('marks genes outside curated SysNDD as New and does not link to a curated gene page', () => {
    const wrapper = mountRows([
      {
        gene_symbol: 'NEWGENE',
        hgnc_id: 'HGNC:99999',
        ndd_score: 0.5,
        rank: 42,
        percentile: 50,
        risk_tier: 'Moderate',
        confidence_tier: 'Low',
        known_sysndd_gene: false,
      },
    ]);

    expect(wrapper.text()).toContain('New');
    expect(wrapper.find('a[href="/Genes/HGNC:99999"]').exists()).toBe(false);
    // Detail navigation to the NDDScore gene page is still available.
    expect(wrapper.find('a[href="/NDDScore/Gene/HGNC%3A99999"]').exists()).toBe(true);
  });

  it('shows an empty state when there are no predictions', () => {
    const wrapper = mountRows([]);

    expect(wrapper.text()).toContain('No gene predictions found.');
    expect(wrapper.find('.mobile-record-row').exists()).toBe(false);
  });
});
