import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import AnalysisPanel from './AnalysisPanel.vue';

describe('AnalysisPanel', () => {
  it('renders modern panel chrome without Bootstrap card classes', () => {
    const wrapper = mount(AnalysisPanel, {
      props: {
        title: 'NDD entities and genes over time',
        description: 'Tracks curated entries by year.',
      },
      slots: {
        actions: '<button>PNG</button>',
        default: '<div data-testid="panel-body">Chart</div>',
      },
    });

    expect(wrapper.find('.analysis-panel').exists()).toBe(true);
    expect(wrapper.get('.analysis-panel__title').text()).toBe('NDD entities and genes over time');
    expect(wrapper.get('.analysis-panel__description').text()).toContain('curated entries');
    expect(wrapper.get('.analysis-panel__actions').text()).toBe('PNG');
    expect(wrapper.get('[data-testid="panel-body"]').text()).toBe('Chart');
    expect(wrapper.findAll('.card')).toHaveLength(0);
  });
});
