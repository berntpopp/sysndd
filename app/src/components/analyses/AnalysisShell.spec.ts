import { mount, RouterLinkStub } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import AnalysisShell from './AnalysisShell.vue';

describe('AnalysisShell', () => {
  it('renders a unified analysis frame with optional tabs and metadata', () => {
    const wrapper = mount(AnalysisShell, {
      props: {
        title: 'Phenotype correlations',
        subtitle: 'Compare phenotype annotations across entities.',
        navLabel: 'Phenotype correlation views',
        tabs: [
          { label: 'Correlogram', to: '/PhenotypeCorrelations' },
          { label: 'Counts', to: '/PhenotypeCorrelations/PhenotypeCounts' },
        ],
        meta: 'Interactive analysis',
      },
      slots: {
        default: '<div data-testid="analysis-child">Child analysis</div>',
      },
      global: {
        stubs: {
          RouterLink: RouterLinkStub,
        },
      },
    });

    expect(wrapper.find('.analysis-frame').exists()).toBe(true);
    expect(wrapper.get('.analysis-title').text()).toBe('Phenotype correlations');
    expect(wrapper.get('.analysis-subtitle').text()).toContain('Compare phenotype');
    expect(wrapper.get('.analysis-meta-badge').text()).toBe('Interactive analysis');
    expect(wrapper.get('[aria-label="Phenotype correlation views"]').text()).toContain(
      'Correlogram'
    );
    expect(wrapper.findAllComponents(RouterLinkStub)).toHaveLength(2);
    expect(wrapper.get('[data-testid="analysis-child"]').text()).toBe('Child analysis');
    expect(wrapper.findAll('.card')).toHaveLength(0);
  });
});
