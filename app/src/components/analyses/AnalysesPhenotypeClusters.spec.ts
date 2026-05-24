import { flushPromises, mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { getPhenotypeClustering } from '@/api/analysis';
import AnalysesPhenotypeClusters from './AnalysesPhenotypeClusters.vue';

const mocks = vi.hoisted(() => ({
  getPhenotypeClusterSummary: vi.fn(),
  makeToast: vi.fn(),
  cytoscapeUpdateElements: vi.fn(),
  cytoscapeSelectCluster: vi.fn(),
}));

vi.mock('@/api/analysis', () => ({
  getPhenotypeClustering: vi.fn(),
  getPhenotypeClusterSummary: mocks.getPhenotypeClusterSummary,
}));

vi.mock('@/api/client', () => ({
  isApiError: vi.fn((error) => Boolean(error?.response)),
}));

vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: mocks.makeToast }),
}));

vi.mock('@/composables', () => ({
  usePhenotypeCytoscape: () => ({
    isInitialized: { value: false },
    destroy: vi.fn(),
    initializeCytoscape: vi.fn(),
    updateElements: mocks.cytoscapeUpdateElements,
    selectCluster: mocks.cytoscapeSelectCluster,
    exportPNG: vi.fn(() => ''),
    exportSVG: vi.fn(() => ''),
  }),
  useExcelExport: () => ({
    isExporting: false,
    exportToExcel: vi.fn(),
  }),
}));

const getPhenotypeClusteringMock = vi.mocked(getPhenotypeClustering);

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
    template: '<button :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
    props: ['disabled'],
  },
  BSpinner: { template: '<span />' },
  BCard: { template: '<div><slot name="header" /><slot name="footer" /><slot /></div>' },
  BCardText: { template: '<div><slot /></div>' },
  BBadge: { template: '<span><slot /></span>' },
  BLink: { template: '<a><slot /></a>' },
  GenericTable: {
    template:
      '<table data-testid="phenotype-cluster-table"><slot name="filter-controls" /></table>',
  },
  TableLoadingState: {
    props: ['label'],
    template: '<div data-testid="phenotype-table-loading">{{ label }}</div>',
  },
  TableSearchInput: { template: '<input />' },
  TablePaginationControls: { template: '<nav />' },
  LlmSummaryCard: { template: '<article>AI Summary</article>' },
};

function mountComponent() {
  return mount(AnalysesPhenotypeClusters, {
    global: {
      stubs: globalStubs,
      directives: {
        bTooltip: {},
      },
    },
  });
}

describe('AnalysesPhenotypeClusters', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    getPhenotypeClusteringMock.mockImplementation(() => new Promise(() => {}));
  });

  it('shows a table loader instead of an empty table while phenotype clusters load', () => {
    const wrapper = mountComponent();

    expect(getPhenotypeClusteringMock).toHaveBeenCalledTimes(1);
    expect(wrapper.get('[data-testid="phenotype-table-loading"]').text()).toContain(
      'Loading phenotype cluster rows'
    );
    expect(wrapper.find('[data-testid="phenotype-cluster-table"]').exists()).toBe(false);
  });

  it('keeps stale AI summary responses from replacing the active phenotype cluster summary', async () => {
    let resolveClusterOne: (value: unknown) => void = () => {};
    let resolveClusterTwo: (value: unknown) => void = () => {};
    const clusterOneSummary = {
      summary_json: { summary: 'Cluster 1 stale summary' },
      model_name: 'gemini-test',
      created_at: '2026-05-24T00:00:00Z',
      validation_status: 'approved',
    };
    const clusterTwoSummary = {
      summary_json: { summary: 'Cluster 2 active summary' },
      model_name: 'gemini-test',
      created_at: '2026-05-24T00:00:00Z',
      validation_status: 'approved',
    };

    mocks.getPhenotypeClusterSummary
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
    const firstRequest = wrapper.vm.fetchClusterSummary('equals(hash,one)', 1);
    const secondRequest = wrapper.vm.fetchClusterSummary('equals(hash,two)', 2);

    resolveClusterTwo(clusterTwoSummary);
    await flushPromises();
    resolveClusterOne(clusterOneSummary);
    await flushPromises();
    await Promise.allSettled([firstRequest, secondRequest]);

    expect(wrapper.vm.currentSummary.summary_json.summary).toBe('Cluster 2 active summary');
    expect(wrapper.vm.summaryLoading).toBe(false);
  });

  it('does not show a transient-error toast when phenotype summaries are unavailable', async () => {
    mocks.getPhenotypeClusterSummary.mockRejectedValue({ response: { status: 503 } });

    const wrapper = mountComponent();
    await wrapper.vm.fetchClusterSummary('equals(hash,missing)', 1);
    await flushPromises();

    expect(mocks.makeToast).not.toHaveBeenCalled();
    expect(wrapper.vm.currentSummary).toBeNull();
    expect(wrapper.vm.summaryLoading).toBe(false);
  });
});
