// composables/useNetworkFilters.ts

/**
 * Composable for network visualization filtering
 *
 * Provides category filtering (Definitive, +Moderate, +Limited) and
 * cluster selection for the network visualization component.
 *
 * Filtering is done client-side using Cytoscape show()/hide() for
 * instant feedback without re-layout.
 */

import { ref, computed, type Ref, type ComputedRef } from 'vue';
import type { Core } from 'cytoscape';

// Extend Cytoscape types with show/hide methods that exist at runtime
// but are not properly typed in @types/cytoscape
interface CytoscapeElementExtended {
  show(): void;
  hide(): void;
  visible(): boolean;
}

/**
 * Category filter levels (accumulative)
 * - Definitive: Show only Definitive genes
 * - Moderate: Show Definitive + Moderate genes
 * - Limited: Show Definitive + Moderate + Limited genes
 */
export type CategoryFilter = 'Definitive' | 'Moderate' | 'Limited';

/**
 * State and methods returned by the useNetworkFilters composable
 */
export interface NetworkFiltersState {
  /** Current category filter level */
  categoryLevel: Ref<CategoryFilter>;
  /** Set of selected cluster IDs (only used when showAllClusters is false) */
  selectedClusters: Ref<Set<number>>;
  /** Whether to show all clusters or filter by selection */
  showAllClusters: Ref<boolean>;
  /** Apply current filters to the Cytoscape instance */
  applyFilters: (cy: Core) => void;
  /** Computed list of included categories based on current filter level */
  includedCategories: ComputedRef<string[]>;
  /** Reset all filters to defaults */
  resetFilters: () => void;
  /** Get count of visible nodes after applying filters */
  getVisibleNodeCount: (cy: Core) => number;
  /** Get count of visible edges after applying filters */
  getVisibleEdgeCount: (cy: Core) => number;
}

/**
 * Composable for filtering network visualization
 *
 * @returns Filter state and methods
 *
 * @example
 * ```typescript
 * const {
 *   categoryLevel,
 *   selectedClusters,
 *   showAllClusters,
 *   applyFilters,
 *   includedCategories,
 *   resetFilters,
 * } = useNetworkFilters();
 *
 * // Change category filter
 * categoryLevel.value = 'Moderate';
 * applyFilters(cyInstance);
 *
 * // Select specific clusters
 * showAllClusters.value = false;
 * selectedClusters.value = new Set([1, 2, 3]);
 * applyFilters(cyInstance);
 * ```
 */
export function useNetworkFilters(): NetworkFiltersState {
  // Category filter level (accumulative)
  const categoryLevel = ref<CategoryFilter>('Definitive');

  // Selected clusters (used when showAllClusters is false)
  const selectedClusters = ref<Set<number>>(new Set());

  // Whether to show all clusters
  const showAllClusters = ref(true);

  /**
   * Computed list of included categories based on current filter level
   * Categories are accumulative: Definitive < +Moderate < +Limited
   */
  const includedCategories = computed<string[]>(() => {
    switch (categoryLevel.value) {
      case 'Definitive':
        return ['Definitive'];
      case 'Moderate':
        return ['Definitive', 'Moderate'];
      case 'Limited':
        return ['Definitive', 'Moderate', 'Limited'];
      default:
        return ['Definitive'];
    }
  });

  /**
   * Apply current filters to the Cytoscape instance
   *
   * PERFORMANCE: Uses Cytoscape show()/hide() which is instant (<16ms)
   * and preserves node positions (no re-layout needed).
   *
   * Handles compound nodes: cluster parent nodes are shown/hidden based on
   * whether they have visible children.
   *
   * @param cy - Cytoscape instance to apply filters to
   */
  function applyFilters(cy: Core): void {
    if (!cy) return;

    // First, show all elements (cast to extended type for show/hide methods)
    (cy.elements() as unknown as CytoscapeElementExtended).show();

    // Get gene nodes (non-parent nodes) and cluster parent nodes separately
    const geneNodes = cy.nodes().filter((node) => !node.data('isClusterParent'));
    const clusterParentNodes = cy.nodes().filter((node) => node.data('isClusterParent'));

    // Filter gene nodes by category
    geneNodes.forEach((node) => {
      const category = node.data('category');
      // Hide nodes with categories not in the included list
      // Nodes without category default to visible (treat as Definitive)
      if (category && !includedCategories.value.includes(category)) {
        (node as unknown as CytoscapeElementExtended).hide();
      }
    });

    // Filter gene nodes by cluster (only if not showing all clusters)
    if (!showAllClusters.value && selectedClusters.value.size > 0) {
      geneNodes.forEach((node) => {
        const nodeExt = node as unknown as CytoscapeElementExtended;
        if (!nodeExt.visible()) return; // Already hidden by category filter

        const cluster = node.data('cluster');
        // Parse cluster number (handles both number and string like "1.2")
        const clusterNum =
          typeof cluster === 'string' ? parseInt(cluster.split('.')[0], 10) : cluster;

        if (!selectedClusters.value.has(clusterNum)) {
          nodeExt.hide();
        }
      });
    }

    // Hide orphan edges (edges where source or target is hidden)
    cy.edges().forEach((edge) => {
      const source = edge.source() as unknown as CytoscapeElementExtended;
      const target = edge.target() as unknown as CytoscapeElementExtended;
      if (!source.visible() || !target.visible()) {
        (edge as unknown as CytoscapeElementExtended).hide();
      }
    });

    // Hide cluster parent nodes that have no visible children
    clusterParentNodes.forEach((parentNode) => {
      const parentId = parentNode.id();
      const children = cy.nodes().filter((node) => node.data('parent') === parentId);
      const hasVisibleChildren = children.some((child) =>
        (child as unknown as CytoscapeElementExtended).visible()
      );
      if (!hasVisibleChildren) {
        (parentNode as unknown as CytoscapeElementExtended).hide();
      }
    });
  }

  /**
   * Reset all filters to default values
   */
  function resetFilters(): void {
    categoryLevel.value = 'Definitive';
    selectedClusters.value = new Set();
    showAllClusters.value = true;
  }

  /**
   * Get count of visible gene nodes (excludes cluster parent nodes)
   *
   * @param cy - Cytoscape instance
   * @returns Number of visible gene nodes
   */
  function getVisibleNodeCount(cy: Core): number {
    if (!cy) return 0;
    // Only count gene nodes (not cluster parent nodes)
    return cy
      .nodes()
      .filter(
        (node) =>
          !node.data('isClusterParent') && (node as unknown as CytoscapeElementExtended).visible()
      ).length;
  }

  /**
   * Get count of visible edges
   *
   * @param cy - Cytoscape instance
   * @returns Number of visible edges
   */
  function getVisibleEdgeCount(cy: Core): number {
    if (!cy) return 0;
    return cy.edges().filter((edge) => (edge as unknown as CytoscapeElementExtended).visible())
      .length;
  }

  return {
    categoryLevel,
    selectedClusters,
    showAllClusters,
    applyFilters,
    includedCategories,
    resetFilters,
    getVisibleNodeCount,
    getVisibleEdgeCount,
  };
}

export default useNetworkFilters;
