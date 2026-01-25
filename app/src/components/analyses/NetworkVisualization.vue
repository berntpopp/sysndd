<!-- src/components/analyses/NetworkVisualization.vue -->
<template>
  <div class="network-visualization">
    <!-- Card with header controls -->
    <BCard
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center flex-wrap">
          <div class="d-flex align-items-center flex-wrap">
            <h6 class="mb-0 font-weight-bold me-2">
              Protein-Protein Interaction Network
            </h6>
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
                      Category data not available.<br>
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
              <BDropdown
                size="sm"
                variant="outline-secondary"
                :text="clusterFilterLabel"
              >
                <BDropdownItemButton
                  :active="showAllClusters"
                  @click="setShowAllClusters(true)"
                >
                  All Clusters
                </BDropdownItemButton>
                <BDropdownDivider />
                <BDropdownItemButton
                  v-for="cluster in legendClusters"
                  :key="cluster.id"
                  :active="selectedClusters.has(cluster.id)"
                  @click="toggleCluster(cluster.id)"
                >
                  <span
                    class="legend-color me-2"
                    :style="{ backgroundColor: cluster.color }"
                  />
                  Cluster {{ cluster.id }}
                </BDropdownItemButton>
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
        <div
          v-if="isLoading || isCytoscapeLoading"
          class="loading-overlay"
        >
          <BSpinner
            label="Loading network..."
            class="spinner"
          />
          <div class="loading-text mt-2">
            <small class="text-muted">
              {{ isLoading ? 'Loading network data...' : 'Running layout...' }}
            </small>
          </div>
        </div>

        <!-- Error state -->
        <div
          v-if="error && !isLoading"
          class="error-container"
        >
          <div class="alert alert-danger m-3">
            <i class="bi bi-exclamation-triangle me-2" />
            Failed to load network: {{ error.message }}
          </div>
        </div>

        <!-- Cytoscape canvas -->
        <div
          ref="cytoscapeContainer"
          class="cytoscape-canvas"
        />

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
                <span class="text-muted">HGNC:</span> {{ tooltipData.hgncId }}<br>
                <span class="text-muted">Category:</span> {{ tooltipData.category }}<br>
                <span class="text-muted">Cluster:</span> {{ tooltipData.cluster }}<br>
                <span class="text-muted">Connections:</span> {{ tooltipData.degree }}
              </template>
            </div>
          </div>
        </div>
      </div>

      <!-- Network legend -->
      <div
        v-if="legendClusters.length > 0"
        class="network-legend p-2 border-top"
      >
        <small class="text-muted me-2">Clusters:</small>
        <span
          v-for="cluster in legendClusters"
          :key="cluster.id"
          class="legend-item me-3"
        >
          <span
            class="legend-color"
            :style="{ backgroundColor: cluster.color }"
          />
          {{ cluster.id }}
        </span>
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
import { useCytoscape, useNetworkData, useNetworkFilters } from '@/composables';
import type { CategoryFilter } from '@/composables';

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
const {
  isLoading,
  error,
  metadata,
  fetchNetworkData,
  cytoscapeElements,
} = useNetworkData();

// Network filters composable
const {
  categoryLevel,
  selectedClusters,
  showAllClusters,
  applyFilters,
  getVisibleNodeCount,
  getVisibleEdgeCount,
} = useNetworkFilters();

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

// Computed legend clusters
const legendClusters = computed(() => {
  // D3 category10 palette used in useNetworkData
  const colors = [
    '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd',
    '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf',
  ];

  if (!metadata.value || !metadata.value.cluster_count) return [];

  const count = Math.min(metadata.value.cluster_count, 10);
  return Array.from({ length: count }, (_, i) => ({
    id: i + 1,
    color: colors[i % colors.length],
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
  const withString = metadata.value.genes_with_string || 0;
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
        const visibleChildren = children.filter((n) => (n as any).visible());

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
}

// Category level change handler
function setCategoryLevel(level: CategoryFilter) {
  categoryLevel.value = level;
  handleApplyFilters();
}

// Toggle cluster selection
function toggleCluster(clusterId: number) {
  showAllClusters.value = false;
  const newSet = new Set(selectedClusters.value);
  if (newSet.has(clusterId)) {
    newSet.delete(clusterId);
  } else {
    newSet.add(clusterId);
  }
  selectedClusters.value = newSet;

  // If no clusters selected, show all
  if (newSet.size === 0) {
    showAllClusters.value = true;
  }

  handleApplyFilters();
}

// Show all clusters handler
function setShowAllClusters(value: boolean) {
  showAllClusters.value = value;
  if (value) {
    selectedClusters.value = new Set();
  }
  handleApplyFilters();
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
watch(() => props.clusterType, async (newType) => {
  await fetchNetworkData(newType);
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

.legend-item {
  display: inline-flex;
  align-items: center;
  white-space: nowrap;
}

.legend-color {
  display: inline-block;
  width: 12px;
  height: 12px;
  border-radius: 2px;
  margin-right: 4px;
  border: 1px solid #333;
}

/* Button group styling */
.btn-group-sm > .btn {
  padding: 0.25rem 0.4rem;
}
</style>
