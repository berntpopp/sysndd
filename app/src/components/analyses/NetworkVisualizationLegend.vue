<!-- src/components/analyses/NetworkVisualizationLegend.vue -->
<!--
  Stateless interactive cluster legend for NetworkVisualization: the row of
  cluster pills with single-select / add / remove affordances. It holds no
  Cytoscape state — the cluster list and current selection arrive as props and
  every interaction is an explicit selection emit, wired by the shell to the
  single controller composable. Extracted from NetworkVisualization.vue (#346)
  together with its pill styles.
-->
<template>
  <div v-if="clusters.length > 0" class="network-legend p-2 border-top">
    <small class="text-muted me-2">Clusters:</small>
    <div class="legend-pills">
      <div
        v-for="cluster in clusters"
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
          :aria-label="`View cluster ${cluster.id} only`"
          @click="$emit('select-single-cluster', cluster.id)"
        >
          <span
            class="legend-color"
            :style="{ backgroundColor: cluster.color }"
            aria-hidden="true"
          />
          {{ cluster.id }}
        </button>
        <!-- Add button - appears on hover when not selected -->
        <button
          v-if="!selectedClusters.has(cluster.id) || showAllClusters"
          type="button"
          class="legend-pill-add"
          title="Add to selection"
          :aria-label="`Add cluster ${cluster.id} to selection`"
          @click.stop="$emit('add-cluster', cluster.id)"
        >
          <i class="bi bi-plus" aria-hidden="true" />
        </button>
        <!-- Remove button - shown when selected in multi-select mode -->
        <button
          v-else-if="selectedClusters.size > 1"
          type="button"
          class="legend-pill-remove"
          title="Remove from selection"
          :aria-label="`Remove cluster ${cluster.id} from selection`"
          @click.stop="$emit('remove-cluster', cluster.id)"
        >
          <i class="bi bi-x" aria-hidden="true" />
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { LegendCluster } from './networkVisualizationPresentation';

defineProps<{
  clusters: LegendCluster[];
  selectedClusters: Set<number>;
  showAllClusters: boolean;
}>();

defineEmits<{
  (e: 'select-single-cluster', clusterId: number): void;
  (e: 'add-cluster', clusterId: number): void;
  (e: 'remove-cluster', clusterId: number): void;
}>();
</script>

<style scoped>
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

.legend-pill-main:focus-visible {
  outline: 2px solid var(--medical-blue-700, #0d47a1);
  outline-offset: 1px;
}

.legend-pill-main:focus:not(:focus-visible) {
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

/* Selected pill state — uses medical-blue-700 token, no gradient per quiet-chip rule */
@media (prefers-reduced-motion: no-preference) {
  .legend-pill {
    transition: all 0.2s ease;
  }
}

.legend-pill--selected {
  background-color: var(--medical-blue-700, #0d47a1);
  border-color: var(--medical-blue-700, #0d47a1);
  box-shadow: var(--shadow-sm, 0 1px 2px rgba(15, 23, 42, 0.08));
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

/* Cluster color indicator (shared with the dropdown items) */
.legend-color {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  margin-right: 0.375rem;
  border: 1.5px solid rgba(0, 0, 0, 0.2);
  flex-shrink: 0;
}
</style>
