import { mount, RouterLinkStub } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: vi.fn() }),
}));

const childStubs = {
  AnalysesTimePlot: { template: '<div data-testid="entries-child">Entries child</div>' },
  AnalysesPhenotypeFunctionalCorrelation: {
    template: '<div data-testid="pheno-func-child">Pheno func child</div>',
  },
  AnalyseGeneClusters: {
    template: '<div data-testid="gene-networks-child">Gene networks child</div>',
  },
};

import EntriesOverTime from './EntriesOverTime.vue';
import PhenotypeFunctionalCorrelation from './PhenotypeFunctionalCorrelation.vue';
import GeneNetworks from './GeneNetworks.vue';

describe('standalone analysis route shells', () => {
  it.each([
    [EntriesOverTime, 'NDD entities and genes over time', 'entries-child'],
    [
      PhenotypeFunctionalCorrelation,
      'Phenotype & functional clusters correlation',
      'pheno-func-child',
    ],
    [GeneNetworks, 'Functional gene clusters', 'gene-networks-child'],
  ])('renders %s in the unified analysis shell', (component, title, childTestId) => {
    const wrapper = mount(component, {
      global: {
        stubs: {
          ...childStubs,
          RouterLink: RouterLinkStub,
        },
      },
    });

    expect(wrapper.find('.analysis-frame').exists()).toBe(true);
    expect(wrapper.get('.analysis-title').text()).toBe(title);
    expect(wrapper.find(`[data-testid="${childTestId}"]`).exists()).toBe(true);
    expect(wrapper.findAll('.card')).toHaveLength(0);
  });
});
