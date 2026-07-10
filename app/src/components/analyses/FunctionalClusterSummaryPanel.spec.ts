// src/components/analyses/FunctionalClusterSummaryPanel.spec.ts
//
// Characterizes the summary-state matrix extracted from AnalyseGeneClusters.vue
// (#346 Task 1): validated summary, judge-rejected summary, loading, the
// "select a cluster" show-all cue (with its select-cluster emit), and the
// unavailable single-cluster state that renders none of the above panels.

import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import FunctionalClusterSummaryPanel from './FunctionalClusterSummaryPanel.vue';

const globalStubs = {
  LlmSummaryCard: {
    template: '<article>AI Summary</article>',
    props: ['summary', 'modelName', 'createdAt', 'validationStatus', 'clusterNumber'],
  },
  BCard: { template: '<div><slot /></div>' },
  BSpinner: { template: '<span />' },
  BButton: {
    template: '<button :aria-label="ariaLabel" @click="$emit(\'click\')"><slot /></button>',
    props: ['ariaLabel'],
    emits: ['click'],
  },
};

function mountPanel(props: Record<string, unknown>) {
  return mount(FunctionalClusterSummaryPanel, {
    props: {
      currentSummary: null,
      summaryLoading: false,
      summaryRejected: false,
      summaryRejectionReason: null,
      showAllClustersInTable: false,
      showAllClustersSummaryCue: false,
      firstAvailableCluster: null,
      activeParentCluster: 1,
      ...props,
    },
    global: { stubs: globalStubs },
  });
}

describe('FunctionalClusterSummaryPanel', () => {
  it('renders LlmSummaryCard for a validated single-cluster summary', () => {
    const wrapper = mountPanel({
      currentSummary: {
        summary_json: { summary: 'Cluster summary' },
        model_name: 'gemini-test',
        created_at: '2026-05-15T00:00:00Z',
        validation_status: 'approved',
      },
      firstAvailableCluster: 1,
    });

    expect(wrapper.text()).toContain('AI Summary');
    expect(wrapper.find('[data-testid="ai-summary-unavailable"]').exists()).toBe(false);
  });

  it('renders the "could not be validated" card with the reason when the summary is judge-rejected', () => {
    const wrapper = mountPanel({
      currentSummary: {
        summary_json: {},
        summary_available: false,
        validation_status: 'rejected',
        reason: 'over-broad, low specificity',
      },
      summaryRejected: true,
      summaryRejectionReason: 'over-broad, low specificity',
      firstAvailableCluster: 1,
    });

    const card = wrapper.find('[data-testid="ai-summary-unavailable"]');
    expect(card.exists()).toBe(true);
    expect(card.text()).toContain('could not be validated');
    expect(card.text()).toContain('over-broad, low specificity');
    expect(wrapper.find('article').exists()).toBe(false);
  });

  it('renders the loading indicator while a summary request is in flight', () => {
    const wrapper = mountPanel({
      summaryLoading: true,
    });

    expect(wrapper.text()).toContain('Loading AI summary...');
    expect(wrapper.find('article').exists()).toBe(false);
    expect(wrapper.find('[data-testid="ai-summary-unavailable"]').exists()).toBe(false);
  });

  it('renders the selection cue in show-all mode and emits select-cluster with firstAvailableCluster', async () => {
    const wrapper = mountPanel({
      showAllClustersInTable: true,
      showAllClustersSummaryCue: true,
      firstAvailableCluster: 1,
      activeParentCluster: null,
    });

    expect(wrapper.text()).toContain('Select one cluster to view its AI summary');

    await wrapper.get('button[aria-label="View cluster 1 summary"]').trigger('click');

    expect(wrapper.emitted('select-cluster')).toEqual([[1]]);
  });

  it('treats cluster 0 as a valid available cluster in the cue button label + emit', async () => {
    const wrapper = mountPanel({
      showAllClustersInTable: true,
      showAllClustersSummaryCue: true,
      firstAvailableCluster: 0,
      activeParentCluster: null,
    });

    expect(wrapper.text()).toContain('View cluster 0');

    await wrapper.get('button[aria-label="View cluster 0 summary"]').trigger('click');

    expect(wrapper.emitted('select-cluster')).toEqual([[0]]);
  });

  it('renders none of the summary panels for an unavailable single-cluster state', () => {
    const wrapper = mountPanel({
      currentSummary: null,
      summaryLoading: false,
      summaryRejected: false,
      showAllClustersInTable: false,
      showAllClustersSummaryCue: false,
      firstAvailableCluster: null,
    });

    expect(wrapper.find('article').exists()).toBe(false);
    expect(wrapper.find('[data-testid="ai-summary-unavailable"]').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Loading AI summary');
    expect(wrapper.text()).not.toContain('Select one cluster');
  });
});
