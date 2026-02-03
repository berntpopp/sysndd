<!-- src/components/analyses/NetworkVisualization.vue -->
<template>
  <div class="network-visualization">
    <!-- Card with header controls -->
    <BCard header-tag="header" body-class="p-0" header-class="p-1" border-variant="dark">
      <template #header>
        <div class="d-flex justify-content-between align-items-center flex-wrap">
          <div class="d-flex align-items-center flex-wrap">
            <h6 class="mb-0 font-weight-bold me-2">Protein-Protein Interaction Network</h6>
            <!-- Visible / Total in network -->
            <BBadge
              v-if="isInitialized && visibleNodeCount > 0"
              v-b-tooltip.hover
              variant="info"
              class="me-1"
              :title="networkCoverageTooltip"
            >
              {{ visibleNodeCount }} / {{ metadata?.node_count || 0 }} genes
            </BBadge>
            <BBadge
              v-else-if="metadata"
              v-b-tooltip.hover
              variant="info"
              class="me-1"
              :title="networkCoverageTooltip"
            >
              {{ metadata.node_count }} genes
            </BBadge>
            <!-- Edges with cap warning -->
            <BBadge
              v-if="isInitialized && visibleEdgeCount > 0"
              v-b-tooltip.hover
              variant="secondary"
              class="me-1"
              :title="edgesFilteredTooltip"
            >
              {{ visibleEdgeCount }} / {{ metadata?.edge_count || 0 }} interactions
            </BBadge>
            <BBadge
              v-else-if="metadata"
              v-b-tooltip.hover
              variant="secondary"
              class="me-1"
              :title="edgesFilteredTooltip"
            >
              {{ metadata.edge_count }} interactions
            </BBadge>
            <!-- Warning if edges capped -->
            <BBadge
              v-if="metadata?.edges_filtered"
              v-b-tooltip.hover
              variant="warning"
              class="me-1"
              title="Edges limited to 10,000 for performance. High confidence edges prioritized."
            >
              <i class="bi bi-exclamation-triangle-fill" />
            </BBadge>

            <!-- Filter controls -->
            <div class="d-flex align-items-center gap-2 ms-3">
              <!-- Category dropdown with counts -->
              <BDropdown
                size="sm"
                :variant="hasCategoryData ? 'outline-secondary' : 'outline-warning'"
                :text="categoryFilterLabel"
                :disabled="!hasCategoryData"
              >
                <template v-if="!hasCategoryData">
                  <BDropdownItemButton disabled>
                    <small class="text-muted">
                      Category data not available.<br />
                      Server cache needs refresh.
                    </small>
                  </BDropdownItemButton>
                </template>
                <template v-else>
                  <BDropdownItemButton
                    v-for="opt in categoryOptionsWithCounts"
                    :key="opt.value"
                    :active="categoryLevel === opt.value"
                    @click="setCategoryLevel(opt.value)"
                  >
                    {{ opt.label }} <small class="text-muted">({{ opt.count }})</small>
                  </BDropdownItemButton>
                </template>
              </BDropdown>

              <!-- Cluster dropdown -->
              <BDropdown size="sm" variant="outline-secondary" :text="clusterFilterLabel">
                <BDropdownItemButton :active="showAllClusters" @click="setShowAllClusters(true)">
                  <i class="bi bi-grid-3x3-gap me-2" />
                  All Clusters
                </BDropdownItemButton>
                <BDropdownDivider />
                <div
                  v-for="cluster in legendClusters"
                  :key="cluster.id"
                  class="cluster-dropdown-item px-3 py-2"
                  :class="{ 'cluster-dropdown-item--selected': selectedClusters.has(cluster.id) }"
                >
                  <!-- Main clickable area - single select -->
                  <button
                    type="button"
                    class="cluster-dropdown-main"
                    :title="`View Cluster ${cluster.id} only`"
                    @click="selectSingleCluster(cluster.id)"
                  >
                    <span class="legend-color me-2" :style="{ backgroundColor: cluster.color }" />
                    <span class="cluster-label">Cluster {{ cluster.id }}</span>
                    <i
                      v-if="selectedClusters.has(cluster.id) && selectedClusters.size === 1"
                      class="bi bi-check-lg text-primary ms-auto"
                    />
                  </button>
                  <!-- Add/Remove button for multi-select -->
                  <button
                    v-if="!selectedClusters.has(cluster.id)"
                    type="button"
                    class="cluster-dropdown-action cluster-dropdown-action--add"
                    title="Add to selection"
                    @click.stop="addClusterToSelection(cluster.id)"
                  >
                    <i class="bi bi-plus-lg" />
                  </button>
                  <button
                    v-else
                    type="button"
                    class="cluster-dropdown-action cluster-dropdown-action--remove"
                    title="Remove from selection"
                    @click.stop="removeClusterFromSelection(cluster.id)"
                  >
                    <i class="bi bi-x-lg" />
                  </button>
                </div>
              </BDropdown>
            </div>
          </div>

          <!-- Control buttons -->
          <div class="btn-group btn-group-sm mt-1 mt-md-0">
            <BButton
              v-b-tooltip.hover
              variant="outline-secondary"
              size="sm"
              title="Fit to screen"
              :disabled="!isInitialized"
              @click="handleFitToScreen"
            >
              <i class="bi bi-arrows-fullscreen" />
            </BButton>
            <BButton
              v-b-tooltip.hover
              variant="outline-secondary"
              size="sm"
              title="Reset layout"
              :disabled="!isInitialized || isCytoscapeLoading"
              @click="handleResetLayout"
            >
              <i class="bi bi-arrow-clockwise" />
            </BButton>
            <BButton
              v-b-tooltip.hover
              variant="outline-secondary"
              size="sm"
              title="Zoom in"
              :disabled="!isInitialized"
              @click="handleZoomIn"
            >
              <i class="bi bi-zoom-in" />
            </BButton>
            <BButton
              v-b-tooltip.hover
              variant="outline-secondary"
              size="sm"
              title="Zoom out"
              :disabled="!isInitialized"
              @click="handleZoomOut"
            >
              <i class="bi bi-zoom-out" />
            </BButton>
            <BButton
              v-b-tooltip.hover
              variant="outline-primary"
              size="sm"
              title="Export as PNG"
              :disabled="!isInitialized"
              @click="handleExportPNG"
            >
              <i class="bi bi-image" />
            </BButton>
            <BButton
              v-b-tooltip.hover
              variant="outline-primary"
              size="sm"
              title="Export as SVG"
              :disabled="!isInitialized"
              @click="handleExportSVG"
            >
              <i class="bi bi-file-earmark-image" />
            </BButton>
          </div>
        </div>
      </template>

      <!-- Network container -->
      <div class="network-container">
        <!-- Loading spinner overlay -->
        <div v-if="isLoading || isCytoscapeLoading" class="loading-overlay">
          <BSpinner label="Loading network..." class="spinner" />
          <div class="loading-text mt-2">
            <small class="text-muted">
              {{ isLoading ? 'Loading network data...' : 'Running layout...' }}
            </small>
          </div>
        </div>

        <!-- Error state with retry -->
        <div v-if="error && !isLoading" class="error-container text-center">
          <i class="bi bi-exclamation-triangle-fill text-danger fs-1 mb-3 d-block" />
          <p class="text-muted mb-3">Failed to load network: {{ error.message }}</p>
          <BButton variant="primary" @click="retryLoadNetwork">
            <i class="bi bi-arrow-clockwise me-1" />
            Retry
          </BButton>
        </div>

        <!-- Cytoscape canvas -->
        <div ref="cytoscapeContainer" class="cytoscape-canvas" />

        <!-- Tooltip popover -->
        <div
          v-if="tooltipVisible"
          ref="tooltipElement"
          class="network-tooltip"
          :style="{ left: tooltipPosition.x + 'px', top: tooltipPosition.y + 'px' }"
        >
          <div class="tooltip-content">
            <strong>{{ tooltipData.symbol }}</strong>
            <div class="tooltip-details">
              <!-- Cluster parent tooltip -->
              <template v-if="tooltipData.isClusterParent">
                <span class="text-muted">Visible genes:</span> {{ tooltipData.degree }}
              </template>
              <!-- Gene node tooltip -->
              <template v-else>
                <span class="text-muted">HGNC:</span> {{ tooltipData.hgncId }}<br />
                <span class="text-muted">Category:</span> {{ tooltipData.category }}<br />
                <span class="text-muted">Cluster:</span> {{ tooltipData.cluster }}<br />
                <span class="text-muted">Connections:</span> {{ tooltipData.degree }}
              </template>
            </div>
          </div>
        </div>
      </div>

      <!-- Network legend - interactive cluster pills -->
      <div v-if="legendClusters.length > 0" class="network-legend p-2 border-top">
        <small class="text-muted me-2">Clusters:</small>
        <div class="legend-pills">
          <div
            v-for="cluster in legendClusters"
            :key="cluster.id"
            class="legend-pill"
            :class="{
              'legend-pill--selected': selectedClusters.has(cluster.id) && !showAllClusters,
              'legend-pill--all': showAllClusters,
            }"
          >
            <!-- Main pill - click to single select -->
            <button
              type="button"
              class="legend-pill-main"
              :title="`View Cluster ${cluster.id}`"
              @click="selectSingleCluster(cluster.id)"
            >
              <span class="legend-color" :style="{ backgroundColor: cluster.color }" />
              {{ cluster.id }}
            </button>
            <!-- Add button - appears on hover when not selected -->
            <button
              v-if="!selectedClusters.has(cluster.id) || showAllClusters"
              type="button"
              class="legend-pill-add"
              title="Add to selection"
              @click.stop="addClusterToSelection(cluster.id)"
            >
              <i class="bi bi-plus" />
            </button>
            <!-- Remove button - shown when selected in multi-select mode -->
            <button
              v-else-if="selectedClusters.size > 1"
              type="button"
              class="legend-pill-remove"
              title="Remove from selection"
              @click.stop="removeClusterFromSelection(cluster.id)"
            >
              <i class="bi bi-x" />
            </button>
          </div>
        </div>
      </div>
    </BCard>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, computed, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import {
  BCard,
  BButton,
  BBadge,
  BSpinner,
  BDropdown,
  BDropdownItemButton,
  BDropdownDivider,
} from 'bootstrap-vue-next';
import {
  useCytoscape,
  useNetworkData,
  useNetworkFilters,
  useFilterSync,
  useWildcardSearch,
  useNetworkHighlight,
} from '@/composables';
import type { CategoryFilter } from '@/composables';
import { getClusterColor } from '@/utils/clusterColors';

// Props
interface Props {
  clusterType?: 'clusters' | 'subclusters';
}

const props = withDefaults(defineProps<Props>(), {
  clusterType: 'clusters',
});

// Emits
const emit = defineEmits<{
  (e: 'cluster-selected', hgncId: string): void;
  (e: 'clusters-changed', clusters: number[], showAll: boolean): void;
  (e: 'node-hover', nodeId: string | null): void;
  (e: 'search-match-count', count: number): void;
}>();

// Router
const router = useRouter();

// Template refs
const cytoscapeContainer = ref<HTMLElement | null>(null);

// Tooltip state
const tooltipVisible = ref(false);
const tooltipPosition = ref({ x: 0, y: 0 });
const tooltipData = ref({
  symbol: '',
  hgncId: '',
  cluster: '',
  degree: 0,
  category: '',
  isClusterParent: false,
});

// Network data composable
const { isLoading, error, metadata, fetchNetworkData, cytoscapeElements } = useNetworkData();

// Network filters composable
const {
  categoryLevel,
  selectedClusters,
  showAllClusters,
  applyFilters,
  getVisibleNodeCount,
  getVisibleEdgeCount,
} = useNetworkFilters();

// Filter sync composable for URL state management
const { filterState } = useFilterSync();

// Wildcard search composable
const { pattern: searchPattern, regex: searchRegex, matches: searchMatches } = useWildcardSearch();

// Track search match count for UI feedback
const searchMatchCount = ref(0);

// Visible counts (updated after filter application)
const visibleNodeCount = ref(0);
const visibleEdgeCount = ref(0);

// Cytoscape composable
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
    // Navigate to entity detail page
    router.push({ name: 'Gene', params: { id: nodeId } });
    // Emit for potential table sync
    emit('cluster-selected', nodeId);
  },
});

// Network highlight composable for bidirectional hover
const {
  highlightState,
  setupNetworkListeners: setupHighlightListeners,
  highlightNodeFromTable,
  clearHighlights,
  isRowHighlighted,
} = useNetworkHighlight(cy);

// Computed legend clusters - uses shared getClusterColor for consistency
const legendClusters = computed(() => {
  if (!metadata.value || !metadata.value.cluster_count) return [];

  const count = Math.min(metadata.value.cluster_count, 10);
  return Array.from({ length: count }, (_, i) => ({
    id: i + 1,
    color: getClusterColor(i + 1), // Use shared utility for consistent colors
  }));
});

// Category filter options
const categoryOptions = [
  { value: 'Definitive' as CategoryFilter, label: 'Definitive only' },
  { value: 'Moderate' as CategoryFilter, label: '+ Moderate' },
  { value: 'Limited' as CategoryFilter, label: '+ Limited' },
];

// Category filter label for dropdown button
const categoryFilterLabel = computed(() => {
  const opt = categoryOptions.find((o) => o.value === categoryLevel.value);
  return `Category: ${opt?.label || categoryLevel.value}`;
});

// Cluster filter label for dropdown button
const clusterFilterLabel = computed(() => {
  if (showAllClusters.value) {
    return 'Clusters: All';
  }
  const count = selectedClusters.value.size;
  return count === 0 ? 'Clusters: None' : `Clusters: ${count} selected`;
});

// Network coverage tooltip explaining why not all genes are shown
const networkCoverageTooltip = computed(() => {
  if (!metadata.value) return '';
  const total = metadata.value.total_ndd_genes || 0;
  const inNetwork = metadata.value.node_count || 0;
  const _withString = metadata.value.genes_with_string || 0;
  if (total && inNetwork < total) {
    return `${inNetwork} of ${total} NDD genes shown. Only genes with STRING protein-protein interaction data are included.`;
  }
  return `${inNetwork} genes with protein-protein interactions`;
});

// Edges tooltip
const edgesFilteredTooltip = computed(() => {
  if (!metadata.value) return '';
  if (metadata.value.edges_filtered && metadata.value.total_edges) {
    return `Showing ${metadata.value.edge_count} of ${metadata.value.total_edges} total edges. Limited to 10,000 for performance (high confidence prioritized).`;
  }
  return `${metadata.value.edge_count} protein-protein interactions`;
});

// Check if category data is available (from metadata or node data)
const hasCategoryData = computed(() => {
  // Check if metadata has category counts
  if (metadata.value?.category_counts) {
    const counts = metadata.value.category_counts;
    return (counts.Definitive || 0) + (counts.Moderate || 0) + (counts.Limited || 0) > 0;
  }
  // Fallback: check if any node has category data
  const cyInstance = cy();
  if (cyInstance) {
    const firstNode = cyInstance.nodes().first();
    if (firstNode && firstNode.length > 0) {
      const cat = firstNode.data('category');
      return cat && cat !== 'Unknown';
    }
  }
  return false;
});

// Category options with counts from metadata
const categoryOptionsWithCounts = computed(() => {
  const counts = metadata.value?.category_counts || {};
  const defCount = counts.Definitive || 0;
  const modCount = counts.Moderate || 0;
  const limCount = counts.Limited || 0;

  return [
    {
      value: 'Definitive' as CategoryFilter,
      label: 'Definitive only',
      count: defCount,
    },
    {
      value: 'Moderate' as CategoryFilter,
      label: '+ Moderate',
      count: defCount + modCount,
    },
    {
      value: 'Limited' as CategoryFilter,
      label: '+ Limited',
      count: defCount + modCount + limCount,
    },
  ];
});

// Setup tooltip event handlers after cytoscape is initialized
function setupTooltipHandlers() {
  const cyInstance = cy();
  if (!cyInstance) return;

  cyInstance.on('mouseover', 'node', (event) => {
    const node = event.target;
    const data = node.data();
    const renderedPosition = node.renderedPosition();
    const containerRect = cytoscapeContainer.value?.getBoundingClientRect();

    if (containerRect) {
      // Check if this is a cluster parent node
      const isClusterParent = data.isClusterParent === true;

      if (isClusterParent) {
        // Cluster parent node - show cluster info
        // Extract cluster number from id like "cluster-1"
        const clusterId = data.id?.replace('cluster-', '') || '?';
        // Count children (genes in this cluster)
        const children = cyInstance.nodes().filter((n) => n.data('parent') === data.id);
        const visibleChildren = children.filter((n) => n.visible());

        tooltipData.value = {
          symbol: `Cluster ${clusterId}`,
          hgncId: '',
          cluster: clusterId,
          degree: visibleChildren.length,
          category: '',
          isClusterParent: true,
        };
      } else {
        // Gene node - show gene info
        tooltipData.value = {
          symbol: data.symbol || 'Unknown',
          hgncId: data.id || '',
          cluster: String(data.cluster || '?'),
          degree: data.degree || 0,
          category: data.category || 'Unknown',
          isClusterParent: false,
        };
      }

      // Position tooltip near the node
      tooltipPosition.value = {
        x: renderedPosition.x + 15,
        y: renderedPosition.y - 10,
      };

      tooltipVisible.value = true;
    }
  });

  cyInstance.on('mouseout', 'node', () => {
    tooltipVisible.value = false;
  });

  // Hide tooltip when dragging
  cyInstance.on('drag', 'node', () => {
    tooltipVisible.value = false;
  });
}

// Apply filters and update visible counts
function handleApplyFilters() {
  const cyInstance = cy();
  if (!cyInstance) return;

  // Always apply filters - the applyFilters function handles both category and cluster
  // Category filtering is skipped internally when nodes don't have category data
  applyFilters(cyInstance);

  visibleNodeCount.value = getVisibleNodeCount(cyInstance);
  visibleEdgeCount.value = getVisibleEdgeCount(cyInstance);

  // Re-apply search highlighting after filters
  updateSearchHighlighting();
}

/**
 * Update search highlighting on network nodes
 * Applies search-match and search-no-match classes based on wildcard pattern
 * Also pans/zooms to focus on matching nodes for better UX
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

    // Focus on matching nodes with gentle animation (don't zoom in too hard)
    if (matchingNodes.length > 0) {
      // Calculate the bounding box of matching nodes
      const bb = matchingNodes.boundingBox();
      const padding = 150; // More padding for gentler zoom

      // Get viewport dimensions
      const containerWidth = cyInstance.width();
      const containerHeight = cyInstance.height();

      // Calculate zoom level that would fit the nodes
      const zoomX = containerWidth / (bb.w + padding * 2);
      const zoomY = containerHeight / (bb.h + padding * 2);
      let targetZoom = Math.min(zoomX, zoomY);

      // Limit max zoom to prevent zooming in too hard (max 1.5x)
      const maxZoom = 1.5;
      targetZoom = Math.min(targetZoom, maxZoom);

      // Calculate center of matching nodes
      const centerX = (bb.x1 + bb.x2) / 2;
      const centerY = (bb.y1 + bb.y2) / 2;

      // First pan to center, then zoom
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

// Category level change handler
function setCategoryLevel(level: CategoryFilter) {
  categoryLevel.value = level;
  handleApplyFilters();
}

/**
 * Select a single cluster (replaces any existing selection)
 * Primary action for cluster pills and dropdown items
 */
function selectSingleCluster(clusterId: number) {
  showAllClusters.value = false;
  selectedClusters.value = new Set([clusterId]);
  handleApplyFilters();
  emit('clusters-changed', Array.from(selectedClusters.value), showAllClusters.value);
}

/**
 * Add a cluster to the current selection (multi-select)
 * Used by "+" button on pills and dropdown items
 */
function addClusterToSelection(clusterId: number) {
  showAllClusters.value = false;
  const newSet = new Set(selectedClusters.value);
  newSet.add(clusterId);
  selectedClusters.value = newSet;
  handleApplyFilters();
  emit('clusters-changed', Array.from(selectedClusters.value), showAllClusters.value);
}

/**
 * Remove a cluster from the current selection
 * Used by "x" button on selected pills and dropdown items
 */
function removeClusterFromSelection(clusterId: number) {
  const newSet = new Set(selectedClusters.value);
  newSet.delete(clusterId);
  selectedClusters.value = newSet;

  // If no clusters left, show all
  if (newSet.size === 0) {
    showAllClusters.value = true;
  }

  handleApplyFilters();
  emit('clusters-changed', Array.from(selectedClusters.value), showAllClusters.value);
}

// Show all clusters handler
function setShowAllClusters(value: boolean) {
  showAllClusters.value = value;
  if (value) {
    selectedClusters.value = new Set();
  }
  handleApplyFilters();

  // Emit cluster selection change for table sync
  emit('clusters-changed', Array.from(selectedClusters.value), showAllClusters.value);
}

// Control handlers
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
  await fetchNetworkData(props.clusterType);

  // Wait for DOM update
  await nextTick();

  // Initialize cytoscape
  initializeCytoscape();

  // CRITICAL: Update elements after initialization
  // The watch may have fired before isInitialized was true
  if (cytoscapeElements.value.length > 0) {
    updateElements(cytoscapeElements.value);
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
import { onBeforeUnmount } from 'vue';
onBeforeUnmount(() => {
  if (resizeObserver) {
    resizeObserver.disconnect();
    resizeObserver = null;
  }
});

// Watch for element changes and update the graph
watch(cytoscapeElements, (newElements) => {
  if (isInitialized.value && newElements.length > 0) {
    updateElements(newElements);
    // Re-setup tooltip handlers and apply filters after elements update
    nextTick(() => {
      setupTooltipHandlers();
      handleApplyFilters();
    });
  }
});

// Watch for clusterType prop changes
watch(
  () => props.clusterType,
  async (newType) => {
    await fetchNetworkData(newType);
  }
);

/**
 * Retry loading network data after an error
 */
const retryLoadNetwork = async () => {
  await fetchNetworkData(props.clusterType);
  await nextTick();
  if (!isInitialized.value) {
    initializeCytoscape();
  }
  if (cytoscapeElements.value.length > 0) {
    updateElements(cytoscapeElements.value);
    setupTooltipHandlers();
    handleApplyFilters();
  }
};

/**
 * Select a specific cluster programmatically (for parent component sync)
 * Used when parent auto-selects first cluster on initial load
 */
function selectCluster(clusterId: number) {
  showAllClusters.value = false;
  selectedClusters.value = new Set([clusterId]);
  handleApplyFilters();
  // Don't emit clusters-changed here - parent already knows the state
}

// Expose methods for parent component (bidirectional highlighting)
defineExpose({
  highlightNodeFromTable,
  isRowHighlighted,
  clearHighlights,
  searchMatchCount,
  selectCluster,
});
</script>

<style scoped>
.network-visualization {
  width: 100%;
}

.network-container {
  position: relative;
  width: 100%;
  height: 600px;
  min-height: 400px;
  /* CSS resize doesn't work with flexbox siblings - removed */
  overflow: hidden;
}

.cytoscape-canvas {
  width: 100%;
  height: 100%;
  background-color: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 4px;
  display: block;
  /* CRITICAL: Position relative for canvas child positioning */
  position: relative;
}

/* Fix Cytoscape.js canvas positioning issue (GitHub issue #14, #2401) */
/* The canvas element created by Cytoscape needs explicit positioning */
.cytoscape-canvas :deep(canvas) {
  position: absolute !important;
  top: 0 !important;
  left: 0 !important;
  width: 100% !important;
  height: 100% !important;
}

.loading-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background-color: rgba(255, 255, 255, 0.85);
  z-index: 10;
}

.spinner {
  width: 3rem;
  height: 3rem;
}

.loading-text {
  text-align: center;
}

.error-container {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: 5;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 200px;
  padding: 1rem;
}

.network-tooltip {
  position: absolute;
  z-index: 100;
  background-color: white;
  border: 1px solid #333;
  border-radius: 4px;
  padding: 8px 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
  pointer-events: none;
  max-width: 200px;
}

.tooltip-content strong {
  font-size: 14px;
  display: block;
  margin-bottom: 4px;
}

.tooltip-details {
  font-size: 12px;
  line-height: 1.4;
}

.network-legend {
  background-color: #f8f9fa;
  font-size: 12px;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
}

/* ============================================
   Cluster Selection UI - Polished Design
   ============================================ */

/* Legend pills container */
.legend-pills {
  display: inline-flex;
  flex-wrap: wrap;
  gap: 0.375rem;
  align-items: center;
}

/* Individual cluster pill */
.legend-pill {
  display: inline-flex;
  align-items: center;
  position: relative;
  border-radius: 20px;
  background-color: #f8f9fa;
  border: 1px solid #e9ecef;
  transition: all 0.2s ease;
  overflow: hidden;
}

.legend-pill:hover {
  border-color: #adb5bd;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.08);
}

/* Main clickable area of pill */
.legend-pill-main {
  display: inline-flex;
  align-items: center;
  padding: 0.25rem 0.625rem;
  font-size: 12px;
  font-weight: 600;
  color: #495057;
  background: transparent;
  border: none;
  cursor: pointer;
  transition: all 0.15s ease;
}

.legend-pill-main:hover {
  background-color: rgba(0, 0, 0, 0.04);
}

.legend-pill-main:focus {
  outline: none;
}

/* Add button (+ icon) - appears on hover */
.legend-pill-add {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 0;
  padding: 0;
  font-size: 11px;
  color: #198754;
  background: transparent;
  border: none;
  border-left: 1px solid transparent;
  cursor: pointer;
  overflow: hidden;
  transition: all 0.2s ease;
}

.legend-pill:hover .legend-pill-add {
  width: 24px;
  padding: 0.25rem 0.375rem;
  border-left-color: #e9ecef;
}

.legend-pill-add:hover {
  background-color: rgba(25, 135, 84, 0.1);
  color: #146c43;
}

/* Remove button (x icon) - shown when selected */
.legend-pill-remove {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  padding: 0.25rem 0.375rem;
  font-size: 11px;
  color: #6c757d;
  background: transparent;
  border: none;
  border-left: 1px solid rgba(255, 255, 255, 0.3);
  cursor: pointer;
  transition: all 0.15s ease;
}

.legend-pill-remove:hover {
  background-color: rgba(220, 53, 69, 0.15);
  color: #dc3545;
}

/* Selected pill state */
.legend-pill--selected {
  background: linear-gradient(135deg, #0d6efd 0%, #0a58ca 100%);
  border-color: #0a58ca;
  box-shadow: 0 2px 6px rgba(13, 110, 253, 0.35);
}

.legend-pill--selected .legend-pill-main {
  color: white;
}

.legend-pill--selected .legend-pill-main:hover {
  background-color: rgba(255, 255, 255, 0.1);
}

.legend-pill--selected .legend-color {
  border-color: rgba(255, 255, 255, 0.5);
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.25);
}

/* All clusters mode - subtle equal highlight */
.legend-pill--all {
  background-color: #f8f9fa;
  border-color: #dee2e6;
}

/* Cluster color indicator */
.legend-color {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  margin-right: 0.375rem;
  border: 1.5px solid rgba(0, 0, 0, 0.2);
  flex-shrink: 0;
}

/* ============================================
   Dropdown Cluster Items - Polished Design
   ============================================ */

.cluster-dropdown-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  border-radius: 4px;
  margin: 0.125rem 0.5rem;
  transition: background-color 0.15s ease;
}

.cluster-dropdown-item:hover {
  background-color: #f8f9fa;
}

.cluster-dropdown-item--selected {
  background-color: #e7f1ff;
}

.cluster-dropdown-item--selected:hover {
  background-color: #d0e3ff;
}

/* Main clickable area in dropdown */
.cluster-dropdown-main {
  flex: 1;
  display: flex;
  align-items: center;
  padding: 0.5rem 0.75rem;
  font-size: 13px;
  color: #212529;
  background: transparent;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: background-color 0.15s ease;
}

.cluster-dropdown-main:hover {
  background-color: rgba(0, 0, 0, 0.04);
}

.cluster-dropdown-main:focus {
  outline: none;
  box-shadow: inset 0 0 0 2px rgba(13, 110, 253, 0.25);
}

.cluster-dropdown-main .cluster-label {
  font-weight: 500;
}

/* Action buttons in dropdown */
.cluster-dropdown-action {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  font-size: 14px;
  background: transparent;
  border: 1px solid transparent;
  border-radius: 50%;
  cursor: pointer;
  transition: all 0.15s ease;
  flex-shrink: 0;
}

.cluster-dropdown-action--add {
  color: #198754;
}

.cluster-dropdown-action--add:hover {
  background-color: #d1e7dd;
  border-color: #a3cfbb;
  color: #146c43;
}

.cluster-dropdown-action--remove {
  color: #6c757d;
}

.cluster-dropdown-action--remove:hover {
  background-color: #f8d7da;
  border-color: #f1aeb5;
  color: #dc3545;
}

/* Button group styling */
.btn-group-sm > .btn {
  padding: 0.25rem 0.4rem;
}
</style>
