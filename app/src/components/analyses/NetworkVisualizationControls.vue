<!-- src/components/analyses/NetworkVisualizationControls.vue -->
<!--
  Stateless header controls for NetworkVisualization: the count badges, the
  Category/Clusters filter dropdowns, and the fit/reset/zoom/export button group.
  It owns none of the Cytoscape state — every value arrives as a prop and every
  interaction is an explicit value/update/action emit, wired by the shell to the
  single controller composable. Extracted from NetworkVisualization.vue (#346)
  together with its control styles.
-->
<template>
  <header class="network-panel__header">
    <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
      <div class="d-flex align-items-center flex-wrap">
        <h2 class="mb-0 fw-bold me-2 network-panel__title">
          Protein-Protein Interaction Network
        </h2>
        <!-- Visible / Total in network. When a filter hides some genes the
             badge turns amber + shows a funnel so the reduced count reads as
             "filtered", not "missing"; the tooltip (bound via the directive
             VALUE so it stays reactive to filter changes) names the active
             filter. -->
        <BBadge
          v-if="isInitialized && visibleNodeCount > 0"
          v-b-tooltip.hover.bottom="geneCountTooltip"
          :variant="isNetworkFiltered ? 'warning' : 'info'"
          class="me-1"
        >
          <i v-if="isNetworkFiltered" class="bi bi-funnel-fill me-1" aria-hidden="true" />
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
            :aria-label="`Filter by category: ${categoryFilterLabel}`"
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
                @click="$emit('set-category-level', opt.value)"
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
            :aria-label="`Filter by cluster: ${clusterFilterLabel}`"
          >
            <BDropdownItemButton
              :active="showAllClusters"
              @click="$emit('set-show-all-clusters', true)"
            >
              <i class="bi bi-grid-3x3-gap me-2" />
              All Clusters
            </BDropdownItemButton>
            <BDropdownDivider />
            <div class="px-3 py-1 small text-muted cluster-dropdown-note">
              Cluster IDs are stable partition labels; small clusters (&lt; 10 genes) are
              omitted, so the numbers are not consecutive.
            </div>
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
                :aria-label="`View cluster ${cluster.id} only`"
                @click="$emit('select-single-cluster', cluster.id)"
              >
                <span
                  class="legend-color me-2"
                  :style="{ backgroundColor: cluster.color }"
                  aria-hidden="true"
                />
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
                :aria-label="`Add cluster ${cluster.id} to selection`"
                @click.stop="$emit('add-cluster', cluster.id)"
              >
                <i class="bi bi-plus-lg" aria-hidden="true" />
              </button>
              <button
                v-else
                type="button"
                class="cluster-dropdown-action cluster-dropdown-action--remove"
                title="Remove from selection"
                :aria-label="`Remove cluster ${cluster.id} from selection`"
                @click.stop="$emit('remove-cluster', cluster.id)"
              >
                <i class="bi bi-x-lg" aria-hidden="true" />
              </button>
            </div>
          </BDropdown>
        </div>
      </div>

      <!-- Control buttons: aria-label required for icon-only buttons (button-name) -->
      <div
        class="btn-group btn-group-sm mt-1 mt-md-0"
        role="group"
        aria-label="Network controls"
      >
        <BButton
          v-b-tooltip.hover
          variant="outline-secondary"
          size="sm"
          title="Fit to screen"
          aria-label="Fit network to screen"
          :disabled="!isInitialized"
          @click="$emit('fit-to-screen')"
        >
          <i class="bi bi-arrows-fullscreen" aria-hidden="true" />
        </BButton>
        <BButton
          v-b-tooltip.hover
          variant="outline-secondary"
          size="sm"
          title="Reset layout"
          aria-label="Reset network layout"
          :disabled="!isInitialized || isCytoscapeLoading"
          @click="$emit('reset-layout')"
        >
          <i class="bi bi-arrow-clockwise" aria-hidden="true" />
        </BButton>
        <BButton
          v-b-tooltip.hover
          variant="outline-secondary"
          size="sm"
          title="Zoom in"
          aria-label="Zoom in"
          :disabled="!isInitialized"
          @click="$emit('zoom-in')"
        >
          <i class="bi bi-zoom-in" aria-hidden="true" />
        </BButton>
        <BButton
          v-b-tooltip.hover
          variant="outline-secondary"
          size="sm"
          title="Zoom out"
          aria-label="Zoom out"
          :disabled="!isInitialized"
          @click="$emit('zoom-out')"
        >
          <i class="bi bi-zoom-out" aria-hidden="true" />
        </BButton>
        <BButton
          v-b-tooltip.hover
          variant="outline-primary"
          size="sm"
          title="Export as PNG"
          aria-label="Export network as PNG image"
          :disabled="!isInitialized"
          @click="$emit('export-png')"
        >
          <i class="bi bi-image" aria-hidden="true" />
        </BButton>
        <BButton
          v-b-tooltip.hover
          variant="outline-primary"
          size="sm"
          title="Export as SVG"
          aria-label="Export network as SVG image"
          :disabled="!isInitialized"
          @click="$emit('export-svg')"
        >
          <i class="bi bi-file-earmark-image" aria-hidden="true" />
        </BButton>
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
import { BButton, BBadge, BDropdown, BDropdownItemButton, BDropdownDivider } from 'bootstrap-vue-next';
import type { NetworkMetadata } from '@/api/analysis';
import type { CategoryFilter } from '@/composables';
import type {
  CategoryOptionWithCount,
  LegendCluster,
} from './networkVisualizationPresentation';

defineProps<{
  isInitialized: boolean;
  isCytoscapeLoading: boolean;
  metadata: NetworkMetadata | null;
  visibleNodeCount: number;
  visibleEdgeCount: number;
  isNetworkFiltered: boolean;
  geneCountTooltip: string;
  networkCoverageTooltip: string;
  edgesFilteredTooltip: string;
  hasCategoryData: boolean;
  categoryFilterLabel: string;
  categoryOptionsWithCounts: CategoryOptionWithCount[];
  categoryLevel: CategoryFilter;
  clusterFilterLabel: string;
  showAllClusters: boolean;
  legendClusters: LegendCluster[];
  selectedClusters: Set<number>;
}>();

defineEmits<{
  (e: 'set-category-level', level: CategoryFilter): void;
  (e: 'set-show-all-clusters', value: boolean): void;
  (e: 'select-single-cluster', clusterId: number): void;
  (e: 'add-cluster', clusterId: number): void;
  (e: 'remove-cluster', clusterId: number): void;
  (e: 'fit-to-screen'): void;
  (e: 'reset-layout'): void;
  (e: 'zoom-in'): void;
  (e: 'zoom-out'): void;
  (e: 'export-png'): void;
  (e: 'export-svg'): void;
}>();
</script>

<style scoped>
.network-panel__header {
  padding: 0.65rem 0.75rem;
  border-bottom: 1px solid var(--border-subtle, #e6ebf2);
}

/* Promoted from h6 to h2 (heading-order); keep the compact panel-title size. */
.network-panel__title {
  font-size: 1rem;
  color: var(--neutral-900, #212121);
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

.cluster-dropdown-main:focus-visible {
  outline: 2px solid var(--medical-blue-700, #0d47a1);
  outline-offset: 1px;
  box-shadow: none;
}

.cluster-dropdown-main:focus:not(:focus-visible) {
  outline: none;
  box-shadow: none;
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

/* Cluster color indicator (shared with the legend pills) */
.legend-color {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  margin-right: 0.375rem;
  border: 1.5px solid rgba(0, 0, 0, 0.2);
  flex-shrink: 0;
}

/* Button group styling */
.btn-group-sm > .btn {
  padding: 0.25rem 0.4rem;
}
</style>
