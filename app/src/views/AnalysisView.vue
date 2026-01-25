<!-- src/views/AnalysisView.vue -->
<template>
  <div class="analysis-view">
    <!-- Navigation tabs -->
    <AnalysisTabs />

    <!-- Loading state -->
    <div
      v-if="isLoading"
      class="text-center py-5"
    >
      <BSpinner
        variant="primary"
        label="Loading..."
      />
      <p class="mt-2 text-muted">
        Loading analysis view...
      </p>
    </div>

    <!-- Active analysis component -->
    <Suspense v-else>
      <template #default>
        <component
          :is="currentComponent"
          :filter-state="filterState"
          @cluster-selected="handleClusterSelected"
        />
      </template>
      <template #fallback>
        <div class="text-center py-5">
          <BSpinner
            variant="primary"
            label="Loading..."
          />
          <p class="mt-2 text-muted">
            Loading {{ currentTabLabel }}...
          </p>
        </div>
      </template>
    </Suspense>
  </div>
</template>

<script setup lang="ts">
/**
 * @fileoverview Analysis parent view component
 *
 * Orchestrates the tabbed analysis interface with shared filter state.
 * Acts as the parent container for:
 * - AnalysisTabs navigation
 * - Dynamically loaded analysis components (Phenotype Clusters, Gene Networks, Correlation)
 *
 * Features:
 * - Lazy loading of analysis components via defineAsyncComponent
 * - Shared filter state passed to child components
 * - URL state management via useFilterSync
 * - Suspense boundaries for loading states
 *
 * @example
 * Router configuration:
 * ```typescript
 * {
 *   path: '/analysis',
 *   name: 'Analysis',
 *   component: () => import('@/views/AnalysisView.vue'),
 * }
 * ```
 */

import { computed, defineAsyncComponent, ref, watch, type Component } from 'vue';
import { useFilterSync, type AnalysisTab } from '@/composables';
import AnalysisTabs from '@/components/navigation/AnalysisTabs.vue';

// Get filter state and actions from composable
const { filterState, setCluster } = useFilterSync();

/**
 * Loading state for initial component load
 */
const isLoading = ref(false);

/**
 * Lazy load analysis components for better performance
 * Each component is loaded only when its tab is selected
 */
const AnalysesPhenotypeClusters = defineAsyncComponent(
  () => import('@/components/analyses/AnalysesPhenotypeClusters.vue'),
);

const AnalyseGeneClusters = defineAsyncComponent(
  () => import('@/components/analyses/AnalyseGeneClusters.vue'),
);

const AnalysesPhenotypeCorrelogram = defineAsyncComponent(
  () => import('@/components/analyses/AnalysesPhenotypeCorrelogram.vue'),
);

/**
 * Map of tab IDs to their corresponding components
 */
const componentMap: Record<AnalysisTab, Component> = {
  clusters: AnalysesPhenotypeClusters,
  networks: AnalyseGeneClusters,
  correlation: AnalysesPhenotypeCorrelogram,
};

/**
 * Tab labels for loading state messages
 */
const tabLabels: Record<AnalysisTab, string> = {
  clusters: 'Phenotype Clusters',
  networks: 'Gene Networks',
  correlation: 'Correlation',
};

/**
 * Currently active component based on tab state
 */
const currentComponent = computed<Component>(
  () => componentMap[filterState.value.tab] || AnalysesPhenotypeClusters,
);

/**
 * Label for the current tab (used in loading messages)
 */
const currentTabLabel = computed<string>(
  () => tabLabels[filterState.value.tab] || 'Analysis',
);

/**
 * Handle cluster selection from child components
 * Updates the filter state which syncs to URL
 *
 * @param clusterId - The selected cluster ID
 */
const handleClusterSelected = (clusterId: number): void => {
  setCluster(clusterId);
};

/**
 * Watch for tab changes to potentially trigger loading states
 */
watch(
  () => filterState.value.tab,
  () => {
    // Component will handle its own loading state via Suspense
    // This watcher is available for future enhancements
  },
);
</script>

<style scoped>
.analysis-view {
  padding: 1rem;
}

/* Ensure content area has consistent styling */
.analysis-view :deep(.container-fluid) {
  padding-left: 0;
  padding-right: 0;
}
</style>
