import { mount, RouterLinkStub } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: vi.fn() }),
}));

import PhenotypeCorrelations from './PhenotypeCorrelations.vue';
import VariantCorrelations from './VariantCorrelations.vue';
import PublicationsNDD from './PublicationsNDD.vue';
import PubtatorNDD from './PubtatorNDD.vue';

describe('tabbed analysis route shells', () => {
  it.each([
    [
      PhenotypeCorrelations,
      'Phenotype correlations',
      'Phenotype correlation views',
      ['Phenotype correlogram', 'Phenotype counts', 'Phenotype clustering', 'Correlation matrix'],
    ],
    [
      VariantCorrelations,
      'Variant correlations',
      'Variant correlation views',
      ['Variant correlogram', 'Variant counts'],
    ],
    [
      PublicationsNDD,
      'NDD publications',
      'NDD publication views',
      ['SysNDD Curated', 'Time Plot', 'Stats'],
    ],
    [PubtatorNDD, 'PubTator NDD', 'PubTator NDD views', ['Table', 'Genes', 'Stats']],
  ])('renders %s in the unified tabbed analysis shell', (component, title, navLabel, labels) => {
    const wrapper = mount(component, {
      global: {
        stubs: {
          RouterLink: RouterLinkStub,
          RouterView: { template: '<div data-testid="route-child">Child</div>' },
          BBadge: { template: '<span class="badge"><slot /></span>' },
          BPopover: { template: '<div><slot name="title" /><slot /></div>' },
        },
      },
    });

    expect(wrapper.find('.analysis-frame').exists()).toBe(true);
    expect(wrapper.get('.analysis-title').text()).toBe(title);
    expect(wrapper.get(`[aria-label="${navLabel}"]`).text()).toContain(labels[0]);
    for (const label of labels) {
      expect(wrapper.text()).toContain(label);
    }
    expect(wrapper.find('[data-testid="route-child"]').exists()).toBe(true);
    expect(wrapper.findAll('.card')).toHaveLength(0);
  });
});
