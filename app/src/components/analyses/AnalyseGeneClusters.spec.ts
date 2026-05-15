import { mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import AnalyseGeneClusters from './AnalyseGeneClusters.vue';

const mocks = vi.hoisted(() => ({
  networkSelectSingleCluster: vi.fn(),
}));

vi.mock('@/composables', () => ({
  useToast: () => ({ makeToast: vi.fn() }),
  useColorAndSymbols: () => ({}),
  useFilterSync: () => ({
    filterState: { search: '' },
    setSearch: vi.fn(),
  }),
  useWildcardSearch: () => ({
    pattern: { value: '' },
    matches: vi.fn(() => true),
  }),
  useExcelExport: () => ({
    isExporting: false,
    exportToExcel: vi.fn(),
  }),
}));

vi.mock('@/api/jobs', () => ({
  submitClustering: vi.fn(() => new Promise(() => {})),
  getJobStatus: vi.fn(),
}));

vi.mock('@/api/analysis', () => ({
  getFunctionalClustering: vi.fn(),
  getFunctionalClusterSummary: vi.fn(),
}));

const globalStubs = {
  AnalysisPanel: {
    template: '<section><slot name="actions" /><slot /></section>',
  },
  InlineHelpBadge: { template: '<button />' },
  BPopover: { template: '<div />' },
  BRow: { template: '<div><slot /></div>' },
  BCol: { template: '<div><slot /></div>' },
  BInputGroup: { template: '<div><slot /></div>' },
  BFormSelect: { template: '<select />' },
  BFormInput: { template: '<input />' },
  BButton: {
    template:
      '<button :aria-label="ariaLabel" :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
    props: ['ariaLabel', 'disabled'],
  },
  BSpinner: { template: '<span />' },
  BCard: { template: '<div><slot name="header" /><slot /></div>' },
  BCardText: { template: '<div><slot /></div>' },
  BBadge: { template: '<span><slot /></span>' },
  BLink: { template: '<a><slot /></a>' },
  GenericTable: { template: '<table><slot name="filter-controls" /></table>' },
  TablePaginationControls: { template: '<nav />' },
  TermSearch: { template: '<input />' },
  CategoryFilter: { template: '<select />' },
  ScoreSlider: { template: '<input />' },
  LlmSummaryCard: { template: '<article>AI Summary</article>' },
  Splitpanes: { template: '<div><slot /></div>' },
  Pane: { template: '<div><slot /></div>' },
  NetworkVisualization: {
    template: '<div data-testid="network-viz" />',
    methods: {
      selectSingleCluster: mocks.networkSelectSingleCluster,
    },
  },
};

function mountComponent() {
  return mount(AnalyseGeneClusters, {
    global: {
      stubs: globalStubs,
      directives: {
        bTooltip: {},
      },
    },
  });
}

describe('AnalyseGeneClusters', () => {
  beforeEach(() => {
    mocks.networkSelectSingleCluster.mockClear();
  });

  it('shows a compact AI summary cue in all-clusters mode', async () => {
    const wrapper = mountComponent();
    wrapper.vm.loading = false;
    wrapper.vm.itemsCluster = [
      {
        cluster: 1,
        cluster_size: 10,
        hash_filter: 'equals(hash,abc)',
        term_enrichment: [],
        identifiers: [],
      },
    ];
    wrapper.vm.showAllClustersInTable = true;
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('Select one cluster to view its AI summary');
    expect(wrapper.text()).toContain('View cluster 1');
  });

  it('selects cluster 1 through the network ref from the cue button', async () => {
    const wrapper = mountComponent();
    wrapper.vm.loading = false;
    wrapper.vm.itemsCluster = [
      {
        cluster: 1,
        cluster_size: 10,
        hash_filter: 'equals(hash,abc)',
        term_enrichment: [],
        identifiers: [],
      },
    ];
    wrapper.vm.showAllClustersInTable = true;
    await wrapper.vm.$nextTick();

    await wrapper.get('button[aria-label="View cluster 1 summary"]').trigger('click');

    expect(mocks.networkSelectSingleCluster).toHaveBeenCalledWith(1);
  });

  it('does not show the cue while cluster data is loading', async () => {
    const wrapper = mountComponent();
    wrapper.vm.loading = true;
    wrapper.vm.itemsCluster = [
      {
        cluster: 1,
        cluster_size: 10,
        hash_filter: 'equals(hash,abc)',
        term_enrichment: [],
        identifiers: [],
      },
    ];
    wrapper.vm.showAllClustersInTable = true;
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).not.toContain('Select one cluster to view its AI summary');
    expect(wrapper.find('button[aria-label="View cluster 1 summary"]').exists()).toBe(false);
  });

  it('shows the summary card and not the cue in selected single-cluster summary mode', async () => {
    const wrapper = mountComponent();
    wrapper.vm.loading = false;
    wrapper.vm.itemsCluster = [
      {
        cluster: 1,
        cluster_size: 10,
        hash_filter: 'equals(hash,abc)',
        term_enrichment: [],
        identifiers: [],
      },
    ];
    wrapper.vm.currentSummary = {
      summary_json: { summary: 'Cluster summary' },
      model_name: 'gemini-test',
      created_at: '2026-05-15T00:00:00Z',
      validation_status: 'approved',
    };
    wrapper.vm.summaryLoading = false;
    wrapper.vm.showAllClustersInTable = false;
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('AI Summary');
    expect(wrapper.text()).not.toContain('Select one cluster to view its AI summary');
    expect(wrapper.find('button[aria-label="View cluster 1 summary"]').exists()).toBe(false);
  });

  it('treats cluster 0 as a valid available cluster', async () => {
    const wrapper = mountComponent();
    wrapper.vm.loading = false;
    wrapper.vm.itemsCluster = [
      {
        cluster: 0,
        cluster_size: 10,
        hash_filter: 'equals(hash,zero)',
        term_enrichment: [],
        identifiers: [],
      },
    ];
    wrapper.vm.showAllClustersInTable = true;
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('View cluster 0');

    await wrapper.get('button[aria-label="View cluster 0 summary"]').trigger('click');

    expect(mocks.networkSelectSingleCluster).toHaveBeenCalledWith(0);
  });
});
