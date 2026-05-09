import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import GeneClinVarCard from './GeneClinVarCard.vue';

function mountCard() {
  return mount(GeneClinVarCard, {
    props: {
      geneSymbol: 'NAA10',
      loading: false,
      error: null,
      counts: null,
      totalCount: 0,
    },
    global: {
      stubs: {
        BCard: { template: '<section><slot name="header" /><slot /></section>' },
        BButton: { template: '<a><slot /></a>' },
        BSpinner: { template: '<span />' },
        BBadge: { template: '<span><slot /></span>' },
      },
    },
  });
}

describe('GeneClinVarCard', () => {
  it('renders the design empty copy when no ClinVar variants are returned', () => {
    const wrapper = mountCard();

    expect(wrapper.text()).toContain('No ClinVar variants returned for this gene.');
  });
});
