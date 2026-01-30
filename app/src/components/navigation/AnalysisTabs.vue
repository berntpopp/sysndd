<!-- src/components/navigation/AnalysisTabs.vue -->
<template>
  <BNav tabs class="analysis-tabs mb-3">
    <!-- Tab navigation items -->
    <BNavItem
      v-for="tab in tabs"
      :key="tab.id"
      :active="activeTab === tab.id"
      @click="setActiveTab(tab.id)"
    >
      <i :class="tab.icon" class="me-1" />
      {{ tab.label }}
    </BNavItem>

    <!-- Filter status badge - shows active filter count with clear button -->
    <BNavItem v-if="activeFilterCount > 0" disabled class="ms-auto filter-status">
      <BBadge variant="primary" pill class="me-1">
        {{ activeFilterCount }} {{ activeFilterCount === 1 ? 'filter' : 'filters' }} active
      </BBadge>
      <BButton
        size="sm"
        variant="link"
        class="p-0 clear-filters-btn"
        @click.stop="handleClearFilters"
      >
        <i class="bi bi-x-circle me-1" />
        Clear
      </BButton>
    </BNavItem>
  </BNav>
</template>

<script setup lang="ts">
/**
 * @fileoverview Analysis navigation tabs component
 *
 * Provides horizontal tab navigation between analysis views:
 * - Phenotype Clusters
 * - Gene Networks
 * - Correlation
 *
 * Features:
 * - URL state sync via useFilterSync composable
 * - Active filter count badge with clear button
 * - BNav used (not BTabs) for proper URL navigation per accessibility guidelines
 *
 * @example
 * ```vue
 * <AnalysisTabs />
 * ```
 */

import { computed } from 'vue';
import { useFilterSync, type AnalysisTab } from '@/composables';

// Get filter state and actions from composable
const { filterState, activeFilterCount, setTab, clearAllFilters } = useFilterSync();

/**
 * Tab configuration for analysis views
 */
const tabs = [
  { id: 'clusters' as const, label: 'Phenotype Clusters', icon: 'bi bi-diagram-3' },
  { id: 'networks' as const, label: 'Gene Networks', icon: 'bi bi-share' },
  { id: 'correlation' as const, label: 'Correlation', icon: 'bi bi-grid-3x3' },
];

/**
 * Currently active tab derived from filter state
 */
const activeTab = computed<AnalysisTab>(() => filterState.value.tab);

/**
 * Handle tab click - updates URL state via composable
 * @param tabId - The ID of the clicked tab
 */
const setActiveTab = (tabId: AnalysisTab): void => {
  setTab(tabId);
};

/**
 * Handle clear filters button click
 * Clears all active filters while preserving current tab
 */
const handleClearFilters = (): void => {
  clearAllFilters();
};
</script>

<style scoped>
.analysis-tabs {
  border-bottom: 2px solid var(--bs-border-color);
}

.analysis-tabs :deep(.nav-link) {
  cursor: pointer;
  transition:
    color 0.15s ease-in-out,
    background-color 0.15s ease-in-out;
}

.analysis-tabs :deep(.nav-link:hover:not(.active)) {
  color: var(--bs-primary);
  background-color: rgba(var(--bs-primary-rgb), 0.05);
}

.analysis-tabs :deep(.nav-link.active) {
  font-weight: 600;
}

/* Filter status section styling */
.filter-status :deep(.nav-link) {
  display: flex;
  align-items: center;
  cursor: default;
}

.clear-filters-btn {
  color: var(--bs-primary);
  text-decoration: none;
  font-size: 0.875rem;
}

.clear-filters-btn:hover {
  color: var(--bs-danger);
  text-decoration: underline;
}
</style>
