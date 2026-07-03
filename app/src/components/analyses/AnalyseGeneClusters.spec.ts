import { flushPromises, mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { getFunctionalClustering } from '@/api/analysis';
import { submitClustering } from '@/api/jobs';
import AnalyseGeneClusters from './AnalyseGeneClusters.vue';

const mocks = vi.hoisted(() => ({
  getFunctionalClusterSummary: vi.fn(),
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

vi.mock('@/api/analysis', async () => {
  const actual = await vi.importActual<typeof import('@/api/analysis')>('@/api/analysis');
  return {
    ...actual, // keep the real isSnapshotPreparingError so the preparing-state test is realistic
    getFunctionalClustering: vi.fn(),
    getFunctionalClusterSummary: mocks.getFunctionalClusterSummary,
  };
});

const getFunctionalClusteringMock = vi.mocked(getFunctionalClustering);
const submitClusteringMock = vi.mocked(submitClustering);

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
  TableLoadingState: {
    props: ['label'],
    template: '<div data-testid="cluster-table-loading">{{ label }}</div>',
  },
  TablePaginationControls: { template: '<nav />' },
  TermSearch: { template: '<input />' },
  CategoryFilter: { template: '<select />' },
  ScoreSlider: { template: '<input />' },
  LlmSummaryCard: { template: '<article>AI Summary</article>' },
  Splitpanes: { template: '<div><slot /></div>' },
  Pane: { template: '<div><slot /></div>' },
  NetworkVisualization: {
    template: '<button data-testid="network-viz" @click="$emit(\'network-ready\')" />',
    emits: ['network-ready'],
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
    mocks.getFunctionalClusterSummary.mockReset();
    mocks.networkSelectSingleCluster.mockClear();
    getFunctionalClusteringMock.mockReset();
    getFunctionalClusteringMock.mockImplementation(() => new Promise(() => {}));
    submitClusteringMock.mockClear();
  });

  it('starts loading the cluster table immediately so it can render before the graph finishes', async () => {
    const wrapper = mountComponent();

    expect(getFunctionalClusteringMock).toHaveBeenCalledWith({
      page_size: '50',
    });
    expect(submitClusteringMock).not.toHaveBeenCalled();
    expect(wrapper.get('[data-testid="cluster-table-loading"]').text()).toContain(
      'Loading functional cluster rows'
    );

    await wrapper.get('[data-testid="network-viz"]').trigger('click');
    await flushPromises();

    expect(getFunctionalClusteringMock).toHaveBeenCalledTimes(1);
    expect(submitClusteringMock).not.toHaveBeenCalled();
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
      cluster_hash: 'equals(hash,abc)',
      cluster_number: 1,
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

  it('renders a distinct "could not be validated" card when a functional summary is judge-rejected (#490)', async () => {
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
    // Terminal rejected payload (HTTP 200), not a 404 — mirrors the phenotype view.
    wrapper.vm.currentSummary = {
      cluster_hash: 'equals(hash,abc)',
      cluster_number: 1,
      summary_json: {},
      summary_available: false,
      validation_status: 'rejected',
      reason: 'over-broad, low specificity',
    };
    wrapper.vm.summaryLoading = false;
    wrapper.vm.showAllClustersInTable = false;
    await wrapper.vm.$nextTick();

    const card = wrapper.find('[data-testid="ai-summary-unavailable"]');
    expect(card.exists()).toBe(true);
    expect(card.text()).toContain('could not be validated');
    expect(card.text()).toContain('over-broad, low specificity');
    // The normal AI summary card (LlmSummaryCard stub renders <article>) is hidden.
    expect(wrapper.find('article').exists()).toBe(false);
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

  it('keeps stale AI summary responses from replacing the active cluster summary', async () => {
    let resolveClusterOne: (value: unknown) => void = () => {};
    let resolveClusterTwo: (value: unknown) => void = () => {};
    const clusterOneSummary = {
      summary_json: { summary: 'Cluster 1 stale summary' },
      model_name: 'gemini-test',
      created_at: '2026-05-15T00:00:00Z',
      validation_status: 'approved',
    };
    const clusterTwoSummary = {
      summary_json: { summary: 'Cluster 2 active summary' },
      model_name: 'gemini-test',
      created_at: '2026-05-15T00:00:00Z',
      validation_status: 'approved',
    };

    mocks.getFunctionalClusterSummary
      .mockImplementationOnce(
        () =>
          new Promise((resolve) => {
            resolveClusterOne = resolve;
          })
      )
      .mockImplementationOnce(
        () =>
          new Promise((resolve) => {
            resolveClusterTwo = resolve;
          })
      );

    const wrapper = mountComponent();
    wrapper.vm.loading = false;
    wrapper.vm.itemsCluster = [
      {
        cluster: 1,
        cluster_size: 10,
        hash_filter: 'equals(hash,one)',
        term_enrichment: [],
        identifiers: [],
      },
      {
        cluster: 2,
        cluster_size: 8,
        hash_filter: 'equals(hash,two)',
        term_enrichment: [],
        identifiers: [],
      },
    ];

    wrapper.vm.handleClustersChanged([1], false);
    wrapper.vm.handleClustersChanged([2], false);

    resolveClusterTwo(clusterTwoSummary);
    await flushPromises();

    expect(wrapper.vm.currentSummary).toEqual(clusterTwoSummary);
    expect(wrapper.vm.summaryLoading).toBe(false);

    resolveClusterOne(clusterOneSummary);
    await flushPromises();

    expect(wrapper.vm.currentSummary).toEqual(clusterTwoSummary);
  });

  // Regression (#441): the snapshot-backed functional_clustering endpoint
  // serialises `cluster` as a string ("1"), while NetworkVisualization emits
  // numeric cluster ids ([1]). The selection lookups must coerce both sides,
  // otherwise `"1" === 1` is false -> no summary fetch and an empty table.
  it('shows the "being prepared" state on a snapshot_missing 503 instead of an error toast (#440)', async () => {
    getFunctionalClusteringMock.mockReset();
    // Real API shape: 503 with the problem code as a 1-element array.
    getFunctionalClusteringMock.mockRejectedValue({
      response: { status: 503, data: { code: ['snapshot_missing'] } },
    });

    const wrapper = mountComponent();
    await wrapper.vm.loadClusterData();
    await flushPromises();

    expect(wrapper.vm.isPreparing).toBe(true);
    expect(wrapper.vm.loading).toBe(false);
    expect(wrapper.text()).toContain('This analysis is being prepared');
  });

  it('resolves the summary and table when the API returns cluster as a string and selection is numeric', async () => {
    mocks.getFunctionalClusterSummary.mockResolvedValue({
      summary_json: { summary: 'Cluster 1 summary' },
      model_name: 'gemini-test',
      created_at: '2026-05-15T00:00:00Z',
      validation_status: 'approved',
    });

    const wrapper = mountComponent();
    wrapper.vm.loading = false;
    wrapper.vm.itemsCluster = [
      {
        cluster: '1', // API/snapshot serialises cluster as a STRING
        cluster_size: 10,
        hash_filter: 'equals(hash,one)',
        term_enrichment: [{ term: 'GO:1' }],
        identifiers: [{ symbol: 'AAA' }],
      },
    ];

    wrapper.vm.handleClustersChanged([1], false); // NetworkVisualization emits a NUMBER
    await flushPromises();

    expect(mocks.getFunctionalClusterSummary).toHaveBeenCalledWith({
      cluster_hash: 'equals(hash,one)',
      cluster_number: '1',
    });
    expect(wrapper.vm.currentSummary).not.toBeNull();
    // Focused table resolves to the selected cluster's rows (not empty).
    expect((wrapper.vm.selectedCluster.term_enrichment || []).length).toBeGreaterThan(0);
  });
});
