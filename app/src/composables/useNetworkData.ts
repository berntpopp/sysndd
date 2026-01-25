// composables/useNetworkData.ts

/**
 * Composable for network data fetching and transformation
 *
 * Provides data fetching from the /api/analysis/network_edges endpoint
 * and transforms the response into Cytoscape.js ElementDefinition format.
 *
 * Follows the established useTableData.ts pattern for data fetching
 * with loading states and error handling.
 *
 * @returns Network data state and fetch function
 */

import { ref, computed, type Ref, type ComputedRef } from 'vue';
import axios from 'axios';
import type { ElementDefinition } from 'cytoscape';
import type { NetworkNode, NetworkEdge, NetworkResponse, NetworkMetadata } from '../types/models';

/**
 * Cluster colors - D3 category10 palette for distinct cluster visualization
 * User decision: categorical color palette for easy cluster differentiation
 */
const CLUSTER_COLORS: string[] = [
  '#1f77b4', // blue
  '#ff7f0e', // orange
  '#2ca02c', // green
  '#d62728', // red
  '#9467bd', // purple
  '#8c564b', // brown
  '#e377c2', // pink
  '#7f7f7f', // gray
  '#bcbd22', // olive
  '#17becf', // cyan
  '#aec7e8', // light blue
  '#ffbb78', // light orange
  '#98df8a', // light green
  '#ff9896', // light red
  '#c5b0d5', // light purple
];

/**
 * Get color for a cluster based on its index
 *
 * @param cluster - Cluster number or string ID (e.g., 1 or "1.2" for subclusters)
 * @returns Hex color string
 */
function getClusterColor(cluster: number | string): string {
  // Handle string cluster IDs (subclusters like "1.2")
  // Extract the main cluster number from combined ID
  let index: number;
  if (typeof cluster === 'string') {
    // Parse main cluster from combined ID (e.g., "1.2" -> 1)
    const mainCluster = parseInt(cluster.split('.')[0], 10);
    index = isNaN(mainCluster) ? 0 : mainCluster;
  } else {
    index = cluster >= 0 ? cluster : 0;
  }
  return CLUSTER_COLORS[index % CLUSTER_COLORS.length];
}

/**
 * State returned by the useNetworkData composable
 */
export interface NetworkDataState {
  /** Raw network data from API */
  networkData: Ref<NetworkResponse | null>;
  /** Loading state */
  isLoading: Ref<boolean>;
  /** Error state */
  error: Ref<Error | null>;
  /** Network metadata for UI display */
  metadata: ComputedRef<NetworkMetadata | null>;
  /** Fetch network data from API */
  fetchNetworkData: (clusterType?: 'clusters' | 'subclusters') => Promise<void>;
  /** Transformed data in Cytoscape.js ElementDefinition format */
  cytoscapeElements: ComputedRef<ElementDefinition[]>;
  /** Clear network data and reset state */
  clearNetworkData: () => void;
}

/**
 * Composable for fetching and transforming network data
 *
 * @returns State and functions for managing network data
 *
 * @example
 * ```typescript
 * const {
 *   networkData,
 *   isLoading,
 *   error,
 *   fetchNetworkData,
 *   cytoscapeElements,
 * } = useNetworkData();
 *
 * onMounted(async () => {
 *   await fetchNetworkData('clusters');
 * });
 *
 * // Use cytoscapeElements with useCytoscape composable
 * watch(cytoscapeElements, (elements) => {
 *   updateElements(elements);
 * });
 * ```
 */
export function useNetworkData(): NetworkDataState {
  // Reactive state
  const networkData = ref<NetworkResponse | null>(null);
  const isLoading = ref(false);
  const error = ref<Error | null>(null);

  /**
   * Computed metadata for UI display
   */
  const metadata = computed<NetworkMetadata | null>(() => {
    return networkData.value?.metadata || null;
  });

  /**
   * Fetch network data from the API
   *
   * @param clusterType - Type of clustering to use ('clusters' or 'subclusters')
   */
  const fetchNetworkData = async (
    clusterType: 'clusters' | 'subclusters' = 'clusters'
  ): Promise<void> => {
    isLoading.value = true;
    error.value = null;

    try {
      const response = await axios.get<NetworkResponse>('/api/analysis/network_edges', {
        params: {
          cluster_type: clusterType,
          include_metadata: true,
        },
      });
      networkData.value = response.data;
    } catch (err) {
      error.value = err instanceof Error ? err : new Error('Failed to fetch network data');
      console.error('Network data fetch error:', err);
    } finally {
      isLoading.value = false;
    }
  };

  /**
   * Transform network data to Cytoscape.js ElementDefinition format
   *
   * Computed property that automatically updates when networkData changes.
   * Maps nodes and edges to the format expected by Cytoscape.js.
   */
  const cytoscapeElements = computed<ElementDefinition[]>(() => {
    if (!networkData.value) return [];

    // Transform nodes to Cytoscape format
    const nodes: ElementDefinition[] = networkData.value.nodes.map((node: NetworkNode) => ({
      data: {
        id: node.hgnc_id,
        symbol: node.symbol,
        cluster: node.cluster,
        degree: node.degree,
        // Cluster color - user decision: distinct colors for easy differentiation
        color: getClusterColor(node.cluster),
      },
    }));

    // Transform edges to Cytoscape format
    const edges: ElementDefinition[] = networkData.value.edges.map(
      (edge: NetworkEdge, idx: number) => ({
        data: {
          id: `e${idx}`,
          source: edge.source,
          target: edge.target,
          confidence: edge.confidence,
        },
      })
    );

    return [...nodes, ...edges];
  });

  /**
   * Clear network data and reset state
   */
  const clearNetworkData = (): void => {
    networkData.value = null;
    error.value = null;
    isLoading.value = false;
  };

  return {
    networkData,
    isLoading,
    error,
    metadata,
    fetchNetworkData,
    cytoscapeElements,
    clearNetworkData,
  };
}

export default useNetworkData;

// Re-export types for convenience
export type { NetworkNode, NetworkEdge, NetworkResponse, NetworkMetadata };
