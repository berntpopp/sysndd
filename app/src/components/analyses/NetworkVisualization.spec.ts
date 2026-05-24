import { mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { computed, ref } from 'vue';
import NetworkVisualization from './NetworkVisualization.vue';

const mocks = vi.hoisted(() => ({
  push: vi.fn(),
  capturedCytoscapeOptions: null as Record<string, unknown> | null,
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mocks.push }),
}));

vi.mock('@/utils/clusterColors', () => ({
  getClusterColor: (cluster: number | string) => `cluster-color-${cluster}`,
}));

vi.mock('@/composables', () => ({
  useNetworkData: () => ({
    isLoading: ref(false),
    error: ref(null),
    metadata: ref({
      node_count: 2,
      edge_count: 1,
      cluster_count: 2,
      total_edges: 1,
      edges_filtered: false,
      total_ndd_genes: 2,
      genes_with_string: 2,
      elapsed_seconds: 0.1,
      category_counts: { Definitive: 2, Moderate: 0, Limited: 0 },
    }),
    fetchNetworkData: vi.fn().mockResolvedValue(undefined),
    cytoscapeElements: ref([]),
    cytoscapeInitialElements: ref([]),
    cytoscapeNodeElements: ref([]),
  }),
  useNetworkFilters: () => {
    const selectedClusters = ref(new Set<number>());
    const showAllClusters = ref(true);

    return {
      categoryLevel: ref('Definitive'),
      selectedClusters,
      showAllClusters,
      applyFilters: vi.fn(),
      getVisibleNodeCount: vi.fn(() => 2),
      getVisibleEdgeCount: vi.fn(() => 1),
    };
  },
  useFilterSync: () => ({
    filterState: ref({ search: '' }),
  }),
  useWildcardSearch: () => ({
    pattern: ref(''),
    regex: computed(() => null),
    matches: vi.fn(() => false),
  }),
  useNetworkHighlight: () => ({
    highlightState: ref({ hoveredNodeId: null }),
    setupNetworkListeners: vi.fn(),
    highlightNodeFromTable: vi.fn(),
    clearHighlights: vi.fn(),
    isRowHighlighted: vi.fn(() => false),
  }),
  useCytoscape: (options: Record<string, unknown>) => {
    mocks.capturedCytoscapeOptions = options;

    return {
      cy: () => null,
      isInitialized: ref(true),
      isLoading: ref(false),
      initializeCytoscape: vi.fn(),
      updateElements: vi.fn(),
      fitToScreen: vi.fn(),
      resetLayout: vi.fn(),
      zoomIn: vi.fn(),
      zoomOut: vi.fn(),
      exportPNG: vi.fn(() => ''),
      exportSVG: vi.fn(() => ''),
    };
  },
}));

const globalStubs = {
  BButton: { template: '<button><slot /></button>' },
  BBadge: { template: '<span><slot /></span>' },
  BSpinner: { template: '<span />' },
  BDropdown: { template: '<div><slot /></div>', props: ['text'] },
  BDropdownItemButton: {
    template: '<button @click="$emit(\'click\')"><slot /></button>',
  },
  BDropdownDivider: { template: '<hr />' },
};

describe('NetworkVisualization', () => {
  beforeEach(() => {
    mocks.push.mockClear();
    mocks.capturedCytoscapeOptions = null;
    global.ResizeObserver = class ResizeObserver {
      observe = vi.fn();
      disconnect = vi.fn();
      unobserve = vi.fn();
    };
  });

  it('selects a cluster when the Cytoscape cluster parent is clicked', async () => {
    const wrapper = mount(NetworkVisualization, {
      global: { stubs: globalStubs },
    });

    const onClusterClick = mocks.capturedCytoscapeOptions?.onClusterClick as
      | ((clusterId: number) => void)
      | undefined;

    expect(onClusterClick).toBeTypeOf('function');
    onClusterClick?.(1);
    await wrapper.vm.$nextTick();

    expect(wrapper.emitted('clusters-changed')).toEqual([[[1], false]]);
  });

  it('keeps gene node clicks routed to the gene page', () => {
    mount(NetworkVisualization, {
      global: { stubs: globalStubs },
    });

    const onNodeClick = mocks.capturedCytoscapeOptions?.onNodeClick as
      | ((nodeId: string) => void)
      | undefined;

    expect(onNodeClick).toBeTypeOf('function');
    onNodeClick?.('HGNC:1234');

    expect(mocks.push).toHaveBeenCalledWith({
      name: 'Gene',
      params: { id: 'HGNC:1234' },
    });
  });

  it('returns to all clusters when the Cytoscape background is clicked', async () => {
    const wrapper = mount(NetworkVisualization, {
      global: { stubs: globalStubs },
    });

    const onClusterClick = mocks.capturedCytoscapeOptions?.onClusterClick as
      | ((clusterId: number) => void)
      | undefined;
    const onBackgroundClick = mocks.capturedCytoscapeOptions?.onBackgroundClick as
      | (() => void)
      | undefined;

    expect(onClusterClick).toBeTypeOf('function');
    expect(onBackgroundClick).toBeTypeOf('function');

    onClusterClick?.(1);
    await wrapper.vm.$nextTick();

    onBackgroundClick?.();
    await wrapper.vm.$nextTick();

    expect(wrapper.emitted('clusters-changed')).toEqual([
      [[1], false],
      [[], true],
    ]);
  });
});
