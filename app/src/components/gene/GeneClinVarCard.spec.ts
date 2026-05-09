import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import GeneClinVarCard from './GeneClinVarCard.vue';

const richSummary = {
  counts: {
    pathogenic: 2,
    likely_pathogenic: 1,
    vus: 1,
    likely_benign: 0,
    benign: 0,
  },
  class_breakdowns: {
    pathogenic: {
      label: 'Pathogenic',
      short_label: 'P',
      count: 2,
      consequences: [
        { key: 'lof', label: 'LoF', count: 1 },
        { key: 'missense', label: 'Missense', count: 1 },
      ],
    },
    likely_pathogenic: {
      label: 'Likely pathogenic',
      short_label: 'LP',
      count: 1,
      consequences: [{ key: 'splice', label: 'Splice', count: 1 }],
    },
    vus: {
      label: 'VUS',
      short_label: 'VUS',
      count: 1,
      consequences: [{ key: 'missense', label: 'Missense', count: 1 }],
    },
  },
  quality_counts: {
    in_gnomad: 2,
    review_stars: { 0: 0, 1: 3, 2: 1, 3: 0, 4: 0 },
  },
};

function mountCard(props = {}) {
  return mount(GeneClinVarCard, {
    props: {
      geneSymbol: 'NAA10',
      loading: false,
      error: null,
      counts: null,
      totalCount: 0,
      ...props,
    },
    global: {
      stubs: {
        BCard: { template: '<section><slot name="header" /><slot /></section>' },
        BButton: {
          template: '<button v-bind="$attrs"><slot /></button>',
        },
        BSpinner: { template: '<span />' },
        BBadge: { template: '<span v-bind="$attrs"><slot /></span>' },
        BPopover: {
          props: ['modelValue'],
          template: '<aside v-if="modelValue"><slot name="title" /><slot /></aside>',
        },
      },
    },
  });
}

describe('GeneClinVarCard', () => {
  it('renders the design empty copy when no ClinVar variants are returned', () => {
    const wrapper = mountCard();

    expect(wrapper.text()).toContain('No ClinVar variants returned for this gene.');
  });

  it('renders dense short chips from rich ClinVar summary data', () => {
    const wrapper = mountCard({
      counts: richSummary.counts,
      classBreakdowns: richSummary.class_breakdowns,
      qualityCounts: richSummary.quality_counts,
      totalCount: 4,
    });

    expect(wrapper.text()).toContain('P 2');
    expect(wrapper.text()).toContain('LP 1');
    expect(wrapper.text()).toContain('VUS 1');
    expect(wrapper.text()).not.toContain('Pathogenic (2)');
  });

  it('uses accessible chip names that include visible text and full class names', () => {
    const wrapper = mountCard({
      counts: richSummary.counts,
      classBreakdowns: richSummary.class_breakdowns,
      totalCount: 4,
    });

    const pathogenicChip = wrapper.find('[aria-label="P 2 Pathogenic variants"]');
    expect(pathogenicChip.exists()).toBe(true);
  });

  it('opens a consequence breakdown popover from a class chip', async () => {
    const wrapper = mountCard({
      counts: richSummary.counts,
      classBreakdowns: richSummary.class_breakdowns,
      qualityCounts: richSummary.quality_counts,
      totalCount: 4,
    });

    await wrapper.find('[aria-label="P 2 Pathogenic variants"]').trigger('click');

    expect(wrapper.text()).toContain('Pathogenic (2)');
    expect(wrapper.text()).toContain('LoF');
    expect(wrapper.text()).toContain('Missense');
  });

  it('keeps count-only summary props usable in compact chip form', () => {
    const wrapper = mountCard({
      counts: {
        pathogenic: 1,
        likely_pathogenic: 0,
        vus: 2,
        likely_benign: 0,
        benign: 0,
      },
      totalCount: 3,
    });

    expect(wrapper.text()).toContain('P 1');
    expect(wrapper.text()).toContain('VUS 2');
  });
});
