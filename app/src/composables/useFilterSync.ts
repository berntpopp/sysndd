// composables/useFilterSync.ts

/**
 * @fileoverview Composable for URL-synced filter state management
 *
 * Provides reactive filter state that automatically syncs with URL query parameters
 * using VueUse's useUrlSearchParams. Uses a singleton pattern to share state across
 * all analysis components.
 *
 * Features:
 * - Bidirectional URL sync (changes update URL, URL changes update state)
 * - Typed filter state with proper type coercion
 * - History mode for browser back/forward navigation
 * - Active filter count for UI badges
 * - Clear all filters functionality
 *
 * @example
 * ```typescript
 * import { useFilterSync } from '@/composables';
 *
 * // In component setup
 * const {
 *   filterState,
 *   activeFilterCount,
 *   setTab,
 *   setSearch,
 *   setFdr,
 *   setCategory,
 *   setCluster,
 *   clearAllFilters,
 * } = useFilterSync();
 *
 * // Read current state
 * console.log(filterState.value.tab); // 'clusters'
 *
 * // Update state (automatically syncs to URL)
 * setSearch('PKD*');
 * setFdr(0.05);
 * ```
 */

import { computed, type ComputedRef } from 'vue';
import { useUrlSearchParams } from '@vueuse/core';

/**
 * Valid tab identifiers for analysis views
 */
export type AnalysisTab = 'clusters' | 'networks' | 'correlation';

/**
 * Filter state structure for analysis views
 */
export interface FilterState {
  /** Currently active analysis tab */
  tab: AnalysisTab;
  /** Wildcard gene search pattern (e.g., PKD*, BRCA?) */
  search: string;
  /** FDR threshold filter (null = no filter) */
  fdr: number | null;
  /** Category filter (GO, KEGG, MONDO, etc.) */
  category: string | null;
  /** Selected cluster ID filter */
  cluster: number | null;
}

/**
 * Return type for the useFilterSync composable
 */
export interface FilterSyncReturn {
  /** Computed reactive filter state derived from URL params */
  filterState: ComputedRef<FilterState>;
  /** Count of active filters (excluding tab) */
  activeFilterCount: ComputedRef<number>;
  /** Set the active analysis tab */
  setTab: (tab: AnalysisTab) => void;
  /** Set the gene search pattern */
  setSearch: (search: string) => void;
  /** Set the FDR threshold filter */
  setFdr: (fdr: number | null) => void;
  /** Set the category filter */
  setCategory: (category: string | null) => void;
  /** Set the cluster ID filter */
  setCluster: (cluster: number | null) => void;
  /** Clear all filters (preserves current tab) */
  clearAllFilters: () => void;
  /** Raw URL params for edge cases (reactive object from VueUse) */
  rawParams: Record<string, string | string[] | undefined>;
}

// Valid tab values for type checking
const VALID_TABS: AnalysisTab[] = ['clusters', 'networks', 'correlation'];

/**
 * Validates if a string is a valid analysis tab
 */
function isValidTab(value: string | undefined): value is AnalysisTab {
  return VALID_TABS.includes(value as AnalysisTab);
}

/**
 * Safely parses a string to a float, returning null on failure
 */
function parseFloatSafe(value: string | undefined): number | null {
  if (!value) return null;
  const parsed = parseFloat(value);
  return Number.isFinite(parsed) ? parsed : null;
}

/**
 * Safely parses a string to an integer, returning null on failure
 */
function parseIntSafe(value: string | undefined): number | null {
  if (!value) return null;
  const parsed = parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

/**
 * Creates the filter sync instance
 * Internal function - not exported directly
 */
function createFilterSync(): FilterSyncReturn {
  // VueUse handles URL sync automatically
  // - 'history' mode uses history.replaceState for cleaner URLs
  // - removeNullishValues ensures empty filters don't clutter URL
  // - write: true enables bidirectional sync
  const params = useUrlSearchParams('history', {
    removeNullishValues: true,
    removeFalsyValues: false,
    write: true,
  });

  /**
   * Computed filter state derived from URL params with type coercion
   * Reads from URL and provides typed access
   */
  const filterState = computed<FilterState>(() => {
    const tabParam = Array.isArray(params.tab) ? params.tab[0] : params.tab;
    const searchParam = Array.isArray(params.search) ? params.search[0] : params.search;
    const fdrParam = Array.isArray(params.fdr) ? params.fdr[0] : params.fdr;
    const categoryParam = Array.isArray(params.category) ? params.category[0] : params.category;
    const clusterParam = Array.isArray(params.cluster) ? params.cluster[0] : params.cluster;

    return {
      tab: isValidTab(tabParam) ? tabParam : 'clusters',
      search: searchParam || '',
      fdr: parseFloatSafe(fdrParam),
      category: categoryParam || null,
      cluster: parseIntSafe(clusterParam),
    };
  });

  /**
   * Count of active filters (excluding tab)
   * Used for displaying badge count in UI
   */
  const activeFilterCount = computed<number>(() => {
    let count = 0;
    if (filterState.value.search) count += 1;
    if (filterState.value.fdr !== null) count += 1;
    if (filterState.value.category) count += 1;
    if (filterState.value.cluster !== null) count += 1;
    return count;
  });

  /**
   * Set the active analysis tab
   */
  const setTab = (tab: AnalysisTab): void => {
    params.tab = tab;
  };

  /**
   * Set the gene search pattern
   * Empty string removes the parameter from URL
   */
  const setSearch = (search: string): void => {
    params.search = search || undefined;
  };

  /**
   * Set the FDR threshold filter
   * Null removes the parameter from URL
   */
  const setFdr = (fdr: number | null): void => {
    params.fdr = fdr !== null ? fdr.toString() : undefined;
  };

  /**
   * Set the category filter
   * Null or empty string removes the parameter from URL
   */
  const setCategory = (category: string | null): void => {
    params.category = category || undefined;
  };

  /**
   * Set the cluster ID filter
   * Null removes the parameter from URL
   */
  const setCluster = (cluster: number | null): void => {
    params.cluster = cluster !== null ? cluster.toString() : undefined;
  };

  /**
   * Clear all filters while preserving the current tab
   * Useful for "Reset Filters" button
   */
  const clearAllFilters = (): void => {
    const currentTab = params.tab;

    // Clear all filter params
    params.search = undefined;
    params.fdr = undefined;
    params.category = undefined;
    params.cluster = undefined;

    // Restore tab (was preserved before clearing)
    if (currentTab) {
      params.tab = currentTab;
    }
  };

  return {
    filterState,
    activeFilterCount,
    setTab,
    setSearch,
    setFdr,
    setCategory,
    setCluster,
    clearAllFilters,
    rawParams: params as Record<string, string | string[] | undefined>,
  };
}

// Module-level instance for singleton pattern
// Ensures all components share the same filter state
let filterSyncInstance: FilterSyncReturn | null = null;

/**
 * Composable for URL-synced filter state management
 *
 * Uses a singleton pattern to ensure all analysis components share
 * the same filter state. The first call creates the instance,
 * subsequent calls return the same instance.
 *
 * @returns Filter state and control functions
 */
export function useFilterSync(): FilterSyncReturn {
  if (!filterSyncInstance) {
    filterSyncInstance = createFilterSync();
  }
  return filterSyncInstance;
}

/**
 * Reset the singleton instance (for testing purposes)
 * @internal
 */
export function resetFilterSyncInstance(): void {
  filterSyncInstance = null;
}

export default useFilterSync;
