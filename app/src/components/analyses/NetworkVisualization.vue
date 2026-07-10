<!-- src/components/analyses/NetworkVisualization.vue -->
<!--
  Thin shell for the protein-protein interaction network. All Cytoscape lifecycle
  state lives in the single controller composable (useNetworkVisualizationController);
  this SFC only binds the container ref, renders the canvas / loading / error /
  tooltip chrome, and wires the stateless Controls + Legend children to the
  controller. Decomposed from a 1326-line SFC (#346) without changing behavior.
-->
<template>
  <div class="network-visualization">
    <section class="network-panel">
      <NetworkVisualizationControls
        :is-initialized="isInitialized"
        :is-cytoscape-loading="isCytoscapeLoading"
        :metadata="metadata"
        :visible-node-count="visibleNodeCount"
        :visible-edge-count="visibleEdgeCount"
        :is-network-filtered="isNetworkFiltered"
        :gene-count-tooltip="geneCountTooltip"
        :network-coverage-tooltip="networkCoverageTooltip"
        :edges-filtered-tooltip="edgesFilteredTooltip"
        :has-category-data="hasCategoryData"
        :category-filter-label="categoryFilterLabel"
        :category-options-with-counts="categoryOptionsWithCounts"
        :category-level="categoryLevel"
        :cluster-filter-label="clusterFilterLabel"
        :show-all-clusters="showAllClusters"
        :legend-clusters="legendClusters"
        :selected-clusters="selectedClusters"
        @set-category-level="setCategoryLevel"
        @set-show-all-clusters="setShowAllClusters"
        @select-single-cluster="selectSingleCluster"
        @add-cluster="addClusterToSelection"
        @remove-cluster="removeClusterFromSelection"
        @fit-to-screen="handleFitToScreen"
        @reset-layout="handleResetLayout"
        @zoom-in="handleZoomIn"
        @zoom-out="handleZoomOut"
        @export-png="handleExportPNG"
        @export-svg="handleExportSVG"
      />

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

        <!-- Snapshot being prepared (503) — takes precedence over the error card -->
        <div v-if="isPreparing && !isLoading" class="preparing-container text-center py-4">
          <i class="bi bi-hourglass-split text-primary fs-1 mb-3 d-block" />
          <p class="text-muted mb-3">
            This analysis is being prepared and will appear here shortly. This can take a couple of
            minutes after a deploy or data update.
          </p>
          <BButton variant="primary" @click="retryLoadNetwork">
            <i class="bi bi-arrow-clockwise me-1" />
            Check again
          </BButton>
        </div>

        <!-- Error state with retry -->
        <div v-else-if="error && !isLoading" class="error-container text-center">
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
      <NetworkVisualizationLegend
        :clusters="legendClusters"
        :selected-clusters="selectedClusters"
        :show-all-clusters="showAllClusters"
        @select-single-cluster="selectSingleCluster"
        @add-cluster="addClusterToSelection"
        @remove-cluster="removeClusterFromSelection"
      />
    </section>
  </div>
</template>

<script setup lang="ts">
import { BButton, BSpinner } from 'bootstrap-vue-next';
import NetworkVisualizationControls from './NetworkVisualizationControls.vue';
import NetworkVisualizationLegend from './NetworkVisualizationLegend.vue';
import { useNetworkVisualizationController } from './useNetworkVisualizationController';

// Emits (unchanged public surface).
const emit = defineEmits<{
  (e: 'cluster-selected', hgncId: string): void;
  (e: 'clusters-changed', clusters: number[], showAll: boolean): void;
  (e: 'node-hover', nodeId: string | null): void;
  (e: 'search-match-count', count: number): void;
  (e: 'network-ready'): void;
}>();

// The single owner of Cytoscape lifecycle state; the shell only binds its
// returned values to the template and children.
const {
  cytoscapeContainer,
  isLoading,
  error,
  isPreparing,
  metadata,
  isInitialized,
  isCytoscapeLoading,
  tooltipVisible,
  tooltipPosition,
  tooltipData,
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
  categoryLevel,
  selectedClusters,
  showAllClusters,
  setCategoryLevel,
  setShowAllClusters,
  selectSingleCluster,
  addClusterToSelection,
  removeClusterFromSelection,
  handleFitToScreen,
  handleResetLayout,
  handleZoomIn,
  handleZoomOut,
  handleExportPNG,
  handleExportSVG,
  retryLoadNetwork,
  highlightNodeFromTable,
  isRowHighlighted,
  clearHighlights,
  searchMatchCount,
  selectCluster,
} = useNetworkVisualizationController(emit);

// Expose methods for the parent component (bidirectional highlighting + sync).
defineExpose({
  highlightNodeFromTable,
  isRowHighlighted,
  clearHighlights,
  searchMatchCount,
  selectCluster,
  selectSingleCluster,
});
</script>

<style scoped>
.network-visualization {
  width: 100%;
}

.network-panel {
  overflow: hidden;
  border: 1px solid var(--border-subtle, #e2e8f0);
  border-radius: var(--radius-md, 6px);
  background: #fff;
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

.error-container,
.preparing-container {
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
</style>
