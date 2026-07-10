import { flushPromises, mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { computed, ref } from 'vue';
import NetworkVisualization from './NetworkVisualization.vue';

type ElementLike = { data: Record<string, unknown> };

const mocks = vi.hoisted(() => ({
  push: vi.fn(),
  capturedCytoscapeOptions: null as Record<string, unknown> | null,
  // Cytoscape handle spies (shared across the mock instance so tests can assert
  // on staged-hydration calls).
  initializeCytoscape: vi.fn(),
  updateElements: vi.fn(),
  fitToScreen: vi.fn(),
  exportPNG: vi.fn(() => ''),
  exportSVG: vi.fn(() => ''),
  // Controllable data the composables feed the controller.
  nodeElements: [] as ElementLike[],
  initialElements: [] as ElementLike[],
  fullElements: [] as ElementLike[],
  cyInstance: null as unknown,
  isInitialized: true,
  searchRegex: null as RegExp | null,
  searchMatches: (_symbol: string): boolean => false,
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mocks.push }),
}));

vi.mock('@/utils/clusterColors', () => ({
  getClusterColor: (cluster: number | string) => `cluster-color-${cluster}`,
}));

vi.mock('@/composables/useNetworkTooltip', () => ({
  useNetworkTooltip: () => ({
    tooltipVisible: ref(false),
    tooltipPosition: ref({ x: 0, y: 0 }),
    tooltipData: ref({
      symbol: '',
      hgncId: '',
      cluster: '',
      degree: 0,
      category: '',
      isClusterParent: false,
    }),
    setupTooltipHandlers: vi.fn(),
  }),
}));

vi.mock('@/composables', () => ({
  useNetworkData: () => ({
    isLoading: ref(false),
    error: ref(null),
    isPreparing: ref(false),
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
    cytoscapeElements: computed(() => mocks.fullElements),
    cytoscapeInitialElements: computed(() => mocks.initialElements),
    cytoscapeNodeElements: computed(() => mocks.nodeElements),
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
    regex: computed(() => mocks.searchRegex),
    matches: (symbol: string) => mocks.searchMatches(symbol),
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
      cy: () => mocks.cyInstance,
      isInitialized: computed(() => mocks.isInitialized),
      isLoading: ref(false),
      initializeCytoscape: mocks.initializeCytoscape,
      updateElements: mocks.updateElements,
      fitToScreen: mocks.fitToScreen,
      resetLayout: vi.fn(),
      zoomIn: vi.fn(),
      zoomOut: vi.fn(),
      exportPNG: mocks.exportPNG,
      exportSVG: mocks.exportSVG,
    };
  },
}));

const globalStubs = {
  // A bare button: the component's `@click="handleX"` falls through and attaches
  // as a native listener on this root, so `trigger('click')` fires the handler
  // exactly once. (Re-emitting `click` from the stub would double-fire it,
  // because the fallthrough listener also runs on the native click.)
  BButton: { template: '<button><slot /></button>' },
  BBadge: { template: '<span><slot /></span>' },
  BSpinner: { template: '<span />' },
  BDropdown: { template: '<div><slot /></div>', props: ['text'] },
  BDropdownItemButton: {
    template: '<button @click="$emit(\'click\')"><slot /></button>',
  },
  BDropdownDivider: { template: '<hr />' },
};

/** A single Cytoscape-node-like object for search-highlight characterization. */
function makeSearchNode(symbol: string, isClusterParent = false) {
  return {
    length: 1,
    classes: new Set<string>(),
    data(key: string) {
      if (key === 'symbol') return symbol;
      if (key === 'isClusterParent') return isClusterParent;
      if (key === 'category') return 'Definitive';
      return undefined;
    },
    addClass(cls: string) {
      this.classes.add(cls);
    },
  };
}

/** Minimal fake Cytoscape core covering the search-highlight code path. */
function makeFakeCy(nodes: ReturnType<typeof makeSearchNode>[]) {
  const nodesApi = {
    removeClass: vi.fn(),
    forEach(cb: (n: ReturnType<typeof makeSearchNode>) => void) {
      nodes.forEach(cb);
    },
    first() {
      return nodes[0] ?? { length: 0 };
    },
  };
  return {
    nodes: () => nodesApi,
    collection() {
      const items: unknown[] = [];
      return {
        get length() {
          return items.length;
        },
        merge(n: unknown) {
          items.push(n);
          return this;
        },
        boundingBox() {
          return { x1: 0, y1: 0, x2: 100, y2: 100, w: 100, h: 100 };
        },
      };
    },
    width: () => 800,
    height: () => 600,
    animate: vi.fn(),
  };
}

describe('NetworkVisualization', () => {
  beforeEach(() => {
    mocks.push.mockClear();
    mocks.capturedCytoscapeOptions = null;
    mocks.initializeCytoscape.mockClear();
    mocks.updateElements.mockClear();
    mocks.fitToScreen.mockClear();
    mocks.exportPNG.mockClear();
    mocks.exportSVG.mockClear();
    mocks.exportPNG.mockReturnValue('');
    mocks.exportSVG.mockReturnValue('');
    mocks.nodeElements = [];
    mocks.initialElements = [];
    mocks.fullElements = [];
    mocks.cyInstance = null;
    mocks.isInitialized = true;
    mocks.searchRegex = null;
    mocks.searchMatches = () => false;
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

  describe('Cytoscape lifecycle (characterization)', () => {
    it('mounts nodes only for the initial Cytoscape render', async () => {
      mocks.nodeElements = [{ data: { id: 'A' } }, { data: { id: 'B' } }];
      mocks.initialElements = [
        { data: { id: 'A' } },
        { data: { id: 'B' } },
        { data: { id: 'A_B', source: 'A', target: 'B' } },
      ];

      mount(NetworkVisualization, { global: { stubs: globalStubs } });
      await flushPromises();

      expect(mocks.initializeCytoscape).toHaveBeenCalledTimes(1);
      const passed = mocks.initializeCytoscape.mock.calls[0][0] as ElementLike[];
      expect(passed).toHaveLength(2);
      expect(passed.every((el) => el.data.source === undefined)).toBe(true);
    });

    it('hydrates the initial edge set exactly once after layout readiness', async () => {
      const originalRIC = window.requestIdleCallback;
      // Run the idle callback synchronously so hydration is observable.
      (window as unknown as { requestIdleCallback: unknown }).requestIdleCallback = (
        cb: (deadline: unknown) => void
      ) => {
        cb({ didTimeout: false, timeRemaining: () => 0 });
        return 1;
      };

      mocks.nodeElements = [{ data: { id: 'A' } }, { data: { id: 'B' } }];
      mocks.initialElements = [
        { data: { id: 'A' } },
        { data: { id: 'B' } },
        { data: { id: 'A_B', source: 'A', target: 'B' } },
      ];

      const wrapper = mount(NetworkVisualization, { global: { stubs: globalStubs } });
      await flushPromises();

      const onLayoutReady = mocks.capturedCytoscapeOptions?.onLayoutReady as (() => void) | undefined;
      expect(onLayoutReady).toBeTypeOf('function');

      onLayoutReady?.();
      onLayoutReady?.();
      await wrapper.vm.$nextTick();

      // Edge set hydrated exactly once (subsequent layout-ready callbacks are no-ops).
      const initialEdgeMounts = mocks.updateElements.mock.calls.filter(
        (call) => (call[0] as ElementLike[]).length === 3
      );
      expect(initialEdgeMounts).toHaveLength(1);

      // network-ready fires once, only after the hydration path has completed.
      expect(wrapper.emitted('network-ready')).toHaveLength(1);

      (window as unknown as { requestIdleCallback: unknown }).requestIdleCallback = originalRIC;
    });

    it('emits network-ready immediately when there is no initial edge set to hydrate', async () => {
      mocks.nodeElements = [{ data: { id: 'A' } }, { data: { id: 'B' } }];
      mocks.initialElements = [];

      const wrapper = mount(NetworkVisualization, { global: { stubs: globalStubs } });
      await flushPromises();

      const onLayoutReady = mocks.capturedCytoscapeOptions?.onLayoutReady as (() => void) | undefined;
      onLayoutReady?.();
      await wrapper.vm.$nextTick();

      expect(wrapper.emitted('network-ready')).toHaveLength(1);
      expect(mocks.updateElements).not.toHaveBeenCalled();
    });

    it('mounts the full graph exactly once when the category filter expands past Definitive', async () => {
      mocks.nodeElements = [];
      mocks.fullElements = [
        { data: { id: 'A' } },
        { data: { id: 'B' } },
        { data: { id: 'A_B', source: 'A', target: 'B' } },
      ];

      const wrapper = mount(NetworkVisualization, { global: { stubs: globalStubs } });
      await flushPromises();

      const moderate = wrapper
        .findAll('button')
        .find((btn) => btn.text().includes('+ Moderate'));
      expect(moderate).toBeTruthy();

      await moderate!.trigger('click');
      await moderate!.trigger('click');

      const fullMounts = mocks.updateElements.mock.calls.filter(
        (call) => (call[0] as ElementLike[]).length === 3
      );
      expect(fullMounts).toHaveLength(1);
    });

    it('updates search-highlight classes and emits the match count', async () => {
      const matchNode = makeSearchNode('PKD1');
      const missNode = makeSearchNode('OTHER');
      const parentNode = makeSearchNode('Cluster 1', true);
      mocks.cyInstance = makeFakeCy([matchNode, missNode, parentNode]);
      mocks.searchRegex = /PKD/;
      mocks.searchMatches = (symbol: string) => symbol === 'PKD1';

      const wrapper = mount(NetworkVisualization, { global: { stubs: globalStubs } });
      await flushPromises();
      await wrapper.vm.$nextTick();

      const matchEmits = wrapper.emitted('search-match-count') as Array<[number]> | undefined;
      expect(matchEmits).toBeTruthy();
      expect(matchEmits!.some((call) => call[0] === 1)).toBe(true);

      expect(matchNode.classes.has('search-match')).toBe(true);
      expect(missNode.classes.has('search-no-match')).toBe(true);
      // Cluster-parent nodes are never search-classified.
      expect(parentNode.classes.size).toBe(0);
    });

    it('disconnects the ResizeObserver on unmount', async () => {
      const disconnectSpy = vi.fn();
      global.ResizeObserver = class ResizeObserver {
        observe = vi.fn();
        disconnect = disconnectSpy;
        unobserve = vi.fn();
      };

      const wrapper = mount(NetworkVisualization, { global: { stubs: globalStubs } });
      await flushPromises();

      wrapper.unmount();
      expect(disconnectSpy).toHaveBeenCalledTimes(1);
    });

    it('exports a PNG using the network.png filename', async () => {
      mocks.exportPNG.mockReturnValue('data:image/png;base64,AAAA');

      const wrapper = mount(NetworkVisualization, { global: { stubs: globalStubs } });
      await flushPromises();

      const pngBtn = wrapper.findAll('button').find((btn) => btn.find('i.bi-image').exists());
      expect(pngBtn).toBeTruthy();

      // Install the anchor-capturing spy only around the click so mount-time DOM
      // element creation isn't counted.
      const anchors: HTMLAnchorElement[] = [];
      const origCreate = document.createElement.bind(document);
      const createSpy = vi
        .spyOn(document, 'createElement')
        .mockImplementation((tag: string) => {
          const el = origCreate(tag) as HTMLElement;
          if (tag === 'a') {
            (el as HTMLAnchorElement).click = vi.fn();
            anchors.push(el as HTMLAnchorElement);
          }
          return el;
        });

      await pngBtn!.trigger('click');

      expect(anchors).toHaveLength(1);
      expect(anchors[0].download).toBe('network.png');
      expect(anchors[0].href).toContain('data:image/png');

      createSpy.mockRestore();
    });

    it('exports an SVG using network.svg and revokes the object URL', async () => {
      mocks.exportSVG.mockReturnValue('<svg></svg>');
      const createObjectURL = vi.fn(() => 'blob:mock-url');
      const revokeObjectURL = vi.fn();
      (URL as unknown as { createObjectURL: unknown }).createObjectURL = createObjectURL;
      (URL as unknown as { revokeObjectURL: unknown }).revokeObjectURL = revokeObjectURL;

      const wrapper = mount(NetworkVisualization, { global: { stubs: globalStubs } });
      await flushPromises();

      const svgBtn = wrapper
        .findAll('button')
        .find((btn) => btn.find('i.bi-file-earmark-image').exists());
      expect(svgBtn).toBeTruthy();

      const anchors: HTMLAnchorElement[] = [];
      const origCreate = document.createElement.bind(document);
      const createSpy = vi
        .spyOn(document, 'createElement')
        .mockImplementation((tag: string) => {
          const el = origCreate(tag) as HTMLElement;
          if (tag === 'a') {
            (el as HTMLAnchorElement).click = vi.fn();
            anchors.push(el as HTMLAnchorElement);
          }
          return el;
        });

      await svgBtn!.trigger('click');

      expect(anchors).toHaveLength(1);
      expect(anchors[0].download).toBe('network.svg');
      expect(createObjectURL).toHaveBeenCalledTimes(1);
      expect(revokeObjectURL).toHaveBeenCalledWith('blob:mock-url');

      createSpy.mockRestore();
    });
  });
});
