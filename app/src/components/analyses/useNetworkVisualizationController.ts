// src/components/analyses/useNetworkVisualizationController.ts
//
// The SINGLE owner of NetworkVisualization's Cytoscape lifecycle (#346). It wires
// the network data / filter / search / highlight / tooltip composables, owns the
// staged-hydration state machine (nodes → initial edges → full graph), the
// cluster-mutation handlers, the fit/reset/zoom/export controls, the URL-search
// and hover watchers, the ResizeObserver, mount, retry, and cleanup. Mutable
// Cytoscape state lives ONLY here; the shell SFC and the two child components
// (Controls, Legend) are stateless with respect to the graph and consume the
// values this composable returns. Do NOT copy or destructure the Cytoscape core
// or its handles into other independently-lived modules.

import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import {
  useCytoscape,
  useNetworkData,
  useNetworkFilters,
  useFilterSync,
  useWildcardSearch,
  useNetworkHighlight,
} from '@/composables';
import type { CategoryFilter } from '@/composables';
import { useNetworkTooltip } from '@/composables/useNetworkTooltip';
import {
  categoryCountsHaveData,
  computeCategoryFilterLabel,
  computeCategoryOptionsWithCounts,
  computeClusterFilterLabel,
  computeEdgesFilteredTooltip,
  computeGeneCountTooltip,
  computeIsNetworkFiltered,
  computeLegendClusters,
  computeNetworkCoverageTooltip,
  firstNodeCategoryIsKnown,
} from './networkVisualizationPresentation';
import {
  addNetworkCluster,
  removeNetworkCluster,
  selectSingleNetworkCluster,
  showAllNetworkClusters,
} from './networkSelection';

/** Typed emit surface the controller drives on the parent's behalf. */
export interface NetworkVisualizationEmit {
  (e: 'cluster-selected', hgncId: string): void;
  (e: 'clusters-changed', clusters: number[], showAll: boolean): void;
  (e: 'node-hover', nodeId: string | null): void;
  (e: 'search-match-count', count: number): void;
  (e: 'network-ready'): void;
}

export function useNetworkVisualizationController(emit: NetworkVisualizationEmit) {
  const router = useRouter();

  // Template ref: bound by the shell SFC, passed straight into useCytoscape.
  const cytoscapeContainer = ref<HTMLElement | null>(null);

  const {
    isLoading,
    error,
    isPreparing,
    metadata,
    fetchNetworkData,
    cytoscapeElements,
    cytoscapeInitialElements,
    cytoscapeNodeElements,
  } = useNetworkData();

  const {
    categoryLevel,
    selectedClusters,
    showAllClusters,
    applyFilters,
    getVisibleNodeCount,
    getVisibleEdgeCount,
  } = useNetworkFilters();

  const { filterState } = useFilterSync();

  const { pattern: searchPattern, regex: searchRegex, matches: searchMatches } = useWildcardSearch();

  const searchMatchCount = ref(0);

  const visibleNodeCount = ref(0);
  const visibleEdgeCount = ref(0);
  const fullGraphMounted = ref(false);
  const initialEdgesMounted = ref(false);
  const initialEdgeHydrationQueued = ref(false);

  const {
    cy,
    isInitialized,
    isLoading: isCytoscapeLoading,
    initializeCytoscape,
    updateElements,
    fitToScreen,
    resetLayout,
    zoomIn,
    zoomOut,
    exportPNG,
    exportSVG,
  } = useCytoscape({
    container: cytoscapeContainer,
    onNodeClick: (nodeId: string) => {
      router.push({ name: 'Gene', params: { id: nodeId } });
      emit('cluster-selected', nodeId);
    },
    onClusterClick: (clusterId: number) => {
      selectSingleCluster(clusterId);
    },
    onBackgroundClick: () => {
      setShowAllClusters(true);
    },
    onLayoutReady: () => {
      if (hydrateInitialEdgesIfNeeded()) return;
      emit('network-ready');
    },
  });

  const { tooltipVisible, tooltipPosition, tooltipData, setupTooltipHandlers } = useNetworkTooltip(
    cy,
    cytoscapeContainer
  );

  const {
    highlightState,
    setupNetworkListeners: setupHighlightListeners,
    highlightNodeFromTable,
    clearHighlights,
    isRowHighlighted,
  } = useNetworkHighlight(cy);

  // Cluster list/legend derived from the REAL distinct cluster ids on the nodes.
  const legendClusters = computed(() => computeLegendClusters(cytoscapeNodeElements.value));

  const categoryFilterLabel = computed(() => computeCategoryFilterLabel(categoryLevel.value));

  const clusterFilterLabel = computed(() =>
    computeClusterFilterLabel(showAllClusters.value, selectedClusters.value.size)
  );

  const networkCoverageTooltip = computed(() => computeNetworkCoverageTooltip(metadata.value));

  const isNetworkFiltered = computed(() =>
    computeIsNetworkFiltered(visibleNodeCount.value, metadata.value?.node_count || 0)
  );

  const geneCountTooltip = computed(() =>
    computeGeneCountTooltip({
      isNetworkFiltered: isNetworkFiltered.value,
      networkCoverageTooltip: networkCoverageTooltip.value,
      visibleNodeCount: visibleNodeCount.value,
      nodeCount: metadata.value?.node_count || 0,
      showAllClusters: showAllClusters.value,
      selectedClusterCount: selectedClusters.value.size,
      categoryFilterLabel: categoryFilterLabel.value,
      clusterFilterLabel: clusterFilterLabel.value,
    })
  );

  const edgesFilteredTooltip = computed(() => computeEdgesFilteredTooltip(metadata.value));

  const hasCategoryData = computed(() => {
    if (metadata.value?.category_counts) {
      return categoryCountsHaveData(metadata.value.category_counts);
    }
    const cyInstance = cy();
    if (cyInstance) {
      const firstNode = cyInstance.nodes().first();
      if (firstNode && firstNode.length > 0) {
        return firstNodeCategoryIsKnown(firstNode.data('category'));
      }
    }
    return false;
  });

  const categoryOptionsWithCounts = computed(() =>
    computeCategoryOptionsWithCounts(metadata.value?.category_counts)
  );

  // ---------------------------------------------------------------------------
  // Filter application + staged hydration
  // ---------------------------------------------------------------------------

  function handleApplyFilters() {
    const cyInstance = cy();
    if (!cyInstance) return;

    // Always apply filters - the applyFilters function handles both category and
    // cluster. Category filtering is skipped internally when nodes don't have
    // category data.
    applyFilters(cyInstance);

    visibleNodeCount.value = getVisibleNodeCount(cyInstance);
    visibleEdgeCount.value = getVisibleEdgeCount(cyInstance);

    // Re-apply search highlighting after filters
    updateSearchHighlighting();
  }

  function mountInitialGraphElements() {
    if (cytoscapeInitialElements.value.length === 0) return;
    updateElements(cytoscapeInitialElements.value);
    initialEdgesMounted.value = true;
    fullGraphMounted.value = false;
    handleApplyFilters();
  }

  function mountNodeGraphElements() {
    if (cytoscapeNodeElements.value.length === 0) return;
    updateElements(cytoscapeNodeElements.value);
    initialEdgesMounted.value = false;
    initialEdgeHydrationQueued.value = false;
    fullGraphMounted.value = false;
    handleApplyFilters();
  }

  function hydrateInitialEdgesIfNeeded(): boolean {
    if (
      initialEdgesMounted.value ||
      initialEdgeHydrationQueued.value ||
      cytoscapeInitialElements.value.length <= cytoscapeNodeElements.value.length
    ) {
      return false;
    }

    initialEdgeHydrationQueued.value = true;
    const hydrate = () => {
      mountInitialGraphElements();
      initialEdgeHydrationQueued.value = false;
    };

    const requestIdle =
      typeof window.requestIdleCallback === 'function'
        ? window.requestIdleCallback.bind(window)
        : null;
    if (requestIdle) {
      requestIdle(hydrate, { timeout: 700 });
    } else {
      globalThis.setTimeout(hydrate, 100);
    }
    return true;
  }

  function mountFullGraphIfNeeded() {
    if (fullGraphMounted.value || cytoscapeElements.value.length === 0) return;
    updateElements(cytoscapeElements.value);
    initialEdgesMounted.value = true;
    initialEdgeHydrationQueued.value = false;
    fullGraphMounted.value = true;
    handleApplyFilters();
    nextTick(() => {
      setupTooltipHandlers();
    });
  }

  /**
   * Update search highlighting on network nodes. Applies search-match and
   * search-no-match classes based on the wildcard pattern, then pans/zooms to
   * focus on the matching nodes and emits the match count for the parent.
   */
  function updateSearchHighlighting() {
    const cyInstance = cy();
    if (!cyInstance) return;

    const hasPattern = searchRegex.value !== null;
    let matchCount = 0;
    const matchingNodes = cyInstance.collection();

    // Remove existing search classes
    cyInstance.nodes().removeClass('search-match search-no-match');

    if (hasPattern) {
      cyInstance.nodes().forEach((node) => {
        // Skip cluster parent nodes
        if (node.data('isClusterParent')) return;

        const symbol = node.data('symbol');
        const isMatch = searchMatches(symbol);

        if (isMatch) {
          node.addClass('search-match');
          matchingNodes.merge(node);
          matchCount += 1;
        } else {
          node.addClass('search-no-match');
        }
      });

      // Focus on matching nodes with a gentle pan+zoom (capped at 1.5x so it
      // never zooms in too hard); 150px padding keeps the framing loose.
      if (matchingNodes.length > 0) {
        const bb = matchingNodes.boundingBox();
        const padding = 150;
        const containerWidth = cyInstance.width();
        const containerHeight = cyInstance.height();

        const zoomX = containerWidth / (bb.w + padding * 2);
        const zoomY = containerHeight / (bb.h + padding * 2);
        const maxZoom = 1.5;
        const targetZoom = Math.min(zoomX, zoomY, maxZoom);

        const centerX = (bb.x1 + bb.x2) / 2;
        const centerY = (bb.y1 + bb.y2) / 2;

        cyInstance.animate({
          pan: {
            x: containerWidth / 2 - centerX * targetZoom,
            y: containerHeight / 2 - centerY * targetZoom,
          },
          zoom: targetZoom,
          duration: 400,
          easing: 'ease-out-cubic',
        });
      }
    }

    // Update match count and emit for parent component
    searchMatchCount.value = matchCount;
    emit('search-match-count', matchCount);
  }

  // ---------------------------------------------------------------------------
  // Category + cluster mutation handlers
  // ---------------------------------------------------------------------------

  function setCategoryLevel(level: CategoryFilter) {
    categoryLevel.value = level;
    if (level !== 'Definitive') {
      mountFullGraphIfNeeded();
    }
    handleApplyFilters();
  }

  function selectSingleCluster(clusterId: number) {
    const nextSelection = selectSingleNetworkCluster(clusterId);
    showAllClusters.value = nextSelection.showAllClusters;
    selectedClusters.value = nextSelection.selectedClusters;
    handleApplyFilters();
    emit('clusters-changed', Array.from(selectedClusters.value), showAllClusters.value);
  }

  function addClusterToSelection(clusterId: number) {
    const nextSelection = addNetworkCluster(selectedClusters.value, clusterId);
    showAllClusters.value = nextSelection.showAllClusters;
    selectedClusters.value = nextSelection.selectedClusters;
    handleApplyFilters();
    emit('clusters-changed', Array.from(selectedClusters.value), showAllClusters.value);
  }

  function removeClusterFromSelection(clusterId: number) {
    const nextSelection = removeNetworkCluster(selectedClusters.value, clusterId);
    showAllClusters.value = nextSelection.showAllClusters;
    selectedClusters.value = nextSelection.selectedClusters;

    handleApplyFilters();
    emit('clusters-changed', Array.from(selectedClusters.value), showAllClusters.value);
  }

  function setShowAllClusters(value: boolean) {
    const nextSelection = showAllNetworkClusters(value, selectedClusters.value);
    showAllClusters.value = nextSelection.showAllClusters;
    selectedClusters.value = nextSelection.selectedClusters;
    handleApplyFilters();

    // Emit cluster selection change for table sync
    emit('clusters-changed', Array.from(selectedClusters.value), showAllClusters.value);
  }

  // ---------------------------------------------------------------------------
  // Control handlers
  // ---------------------------------------------------------------------------

  function handleFitToScreen() {
    fitToScreen();
  }

  function handleResetLayout() {
    resetLayout();
  }

  function handleZoomIn() {
    zoomIn();
  }

  function handleZoomOut() {
    zoomOut();
  }

  function handleExportPNG() {
    const dataUrl = exportPNG();
    if (dataUrl) {
      const link = document.createElement('a');
      link.download = 'network.png';
      link.href = dataUrl;
      link.click();
    }
  }

  function handleExportSVG() {
    const svgString = exportSVG();
    if (svgString) {
      const blob = new Blob([svgString], { type: 'image/svg+xml' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.download = 'network.svg';
      link.href = url;
      link.click();
      URL.revokeObjectURL(url);
    }
  }

  // ---------------------------------------------------------------------------
  // Watchers, lifecycle, retry, and programmatic selection
  // ---------------------------------------------------------------------------

  // Resize observer to refit graph when container resizes
  let resizeObserver: ResizeObserver | null = null;

  // Watch for search pattern changes from URL state (filterState.search)
  watch(
    () => filterState.value.search,
    (newPattern) => {
      searchPattern.value = newPattern;
      if (isInitialized.value) {
        updateSearchHighlighting();
      }
    },
    { immediate: true }
  );

  // Emit node hover events for bidirectional table highlighting
  watch(
    () => highlightState.value.hoveredNodeId,
    (nodeId) => {
      emit('node-hover', nodeId);
    }
  );

  // Initialize on mount
  onMounted(async () => {
    // Fetch network data
    await fetchNetworkData();

    // Wait for DOM update
    await nextTick();

    if (cytoscapeNodeElements.value.length > 0) {
      initializeCytoscape(cytoscapeNodeElements.value);
      initialEdgesMounted.value = false;
      fullGraphMounted.value = false;
      handleApplyFilters();
    } else {
      initializeCytoscape();
    }

    // Setup tooltip handlers after a brief delay to ensure cy is ready
    await nextTick();
    setupTooltipHandlers();

    // Setup network highlight listeners for bidirectional hover
    setupHighlightListeners();

    // Apply initial filters (defaults to Definitive only)
    await nextTick();
    handleApplyFilters();

    // Setup resize observer to refit graph when container is resized
    if (cytoscapeContainer.value) {
      resizeObserver = new ResizeObserver(() => {
        const cyInstance = cy();
        if (cyInstance && isInitialized.value) {
          // Use fitToScreen which handles resize, fit, and manual centering
          fitToScreen();
        }
      });
      resizeObserver.observe(cytoscapeContainer.value);
    }
  });

  // Cleanup resize observer on unmount
  onBeforeUnmount(() => {
    if (resizeObserver) {
      resizeObserver.disconnect();
      resizeObserver = null;
    }
  });

  // Watch for element changes and update the graph
  watch(cytoscapeNodeElements, (newElements) => {
    if (isInitialized.value && newElements.length > 0) {
      updateElements(newElements);
      initialEdgesMounted.value = false;
      initialEdgeHydrationQueued.value = false;
      fullGraphMounted.value = false;
      // Re-setup tooltip handlers and apply filters after elements update
      nextTick(() => {
        setupTooltipHandlers();
        handleApplyFilters();
      });
    }
  });

  /**
   * Retry loading network data after an error.
   */
  const retryLoadNetwork = async () => {
    await fetchNetworkData();
    await nextTick();
    if (!isInitialized.value) {
      initializeCytoscape(cytoscapeNodeElements.value);
      initialEdgesMounted.value = false;
      fullGraphMounted.value = false;
      setupTooltipHandlers();
      handleApplyFilters();
    } else if (cytoscapeNodeElements.value.length > 0) {
      mountNodeGraphElements();
      setupTooltipHandlers();
      handleApplyFilters();
    }
  };

  /**
   * Select a specific cluster programmatically (for parent component sync).
   * Used when the parent auto-selects the first cluster on initial load. Does not
   * emit clusters-changed because the parent already knows the state.
   */
  function selectCluster(clusterId: number) {
    const nextSelection = selectSingleNetworkCluster(clusterId);
    showAllClusters.value = nextSelection.showAllClusters;
    selectedClusters.value = nextSelection.selectedClusters;
    handleApplyFilters();
  }

  // Everything the shell template and the Controls/Legend children consume. The
  // Cytoscape core/handles are deliberately NOT part of this surface.
  return {
    cytoscapeContainer,
    // Network data + status
    isLoading,
    error,
    isPreparing,
    metadata,
    isInitialized,
    isCytoscapeLoading,
    // Tooltip popover state
    tooltipVisible,
    tooltipPosition,
    tooltipData,
    // Derived counts + labels + tooltips
    visibleNodeCount,
    visibleEdgeCount,
    isNetworkFiltered,
    geneCountTooltip,
    networkCoverageTooltip,
    edgesFilteredTooltip,
    hasCategoryData,
    categoryFilterLabel,
    categoryOptionsWithCounts,
    clusterFilterLabel,
    legendClusters,
    // Filter state
    categoryLevel,
    selectedClusters,
    showAllClusters,
    // Category + cluster actions
    setCategoryLevel,
    setShowAllClusters,
    selectSingleCluster,
    addClusterToSelection,
    removeClusterFromSelection,
    // Control actions
    handleFitToScreen,
    handleResetLayout,
    handleZoomIn,
    handleZoomOut,
    handleExportPNG,
    handleExportSVG,
    // Retry + exposed surface for the parent
    retryLoadNetwork,
    highlightNodeFromTable,
    isRowHighlighted,
    clearHighlights,
    searchMatchCount,
    selectCluster,
  };
}

export type NetworkVisualizationController = ReturnType<typeof useNetworkVisualizationController>;
