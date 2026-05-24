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

import { ref, shallowRef, computed, type Ref, type ComputedRef } from 'vue';
import type { ElementDefinition } from 'cytoscape';
import { getNetworkEdges } from '@/api/analysis';
import type { NetworkNode, NetworkEdge, NetworkResponse, NetworkMetadata } from '@/api/analysis';
import { getClusterColor } from '../utils/clusterColors';

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
  fetchNetworkData: (clusterType?: 'clusters' | 'subclusters', maxEdges?: number) => Promise<void>;
  /** Transformed data in Cytoscape.js ElementDefinition format */
  cytoscapeElements: ComputedRef<ElementDefinition[]>;
  /** Initial graph render with all nodes and default-visible edges */
  cytoscapeInitialElements: ComputedRef<ElementDefinition[]>;
  /** Node-only graph render for the first paint */
  cytoscapeNodeElements: ComputedRef<ElementDefinition[]>;
  /** Clear network data and reset state */
  clearNetworkData: () => void;
}

const INITIAL_EDGE_CATEGORY = 'Definitive';
const inflightNetworkRequests = new Map<string, Promise<NetworkResponse>>();

function networkRequestKey(clusterType: 'clusters' | 'subclusters', maxEdges: number): string {
  return `${clusterType}:${maxEdges}`;
}

export function preloadNetworkData(
  clusterType: 'clusters' | 'subclusters' = 'clusters',
  maxEdges: number = 10000
): Promise<NetworkResponse> {
  const key = networkRequestKey(clusterType, maxEdges);
  const existing = inflightNetworkRequests.get(key);
  if (existing) return existing;

  const request = getNetworkEdges({
    cluster_type: clusterType,
    max_edges: String(maxEdges),
  }).finally(() => {
    inflightNetworkRequests.delete(key);
  });
  inflightNetworkRequests.set(key, request);
  return request;
}

function getMainClusterId(cluster: NetworkNode['cluster']): number | string {
  return typeof cluster === 'string' ? parseInt(cluster.split('.')[0], 10) : cluster;
}

function buildCytoscapeElements(
  data: NetworkResponse,
  options: { initialDefaultEdgesOnly?: boolean; omitEdges?: boolean } = {}
): ElementDefinition[] {
  const hasDisplayLayout = data.metadata?.display_layout_status === 'available';
  const clusterIds = new Set<number | string>();
  const initialEdgeNodeIds = new Set<string>();

  const nodes: ElementDefinition[] = data.nodes.map((node: NetworkNode) => {
    const mainCluster = getMainClusterId(node.cluster);
    const category = node.category || INITIAL_EDGE_CATEGORY;
    const hasPosition = hasDisplayLayout && Number.isFinite(node.x) && Number.isFinite(node.y);

    if (mainCluster !== undefined && mainCluster !== null) {
      clusterIds.add(mainCluster);
    }
    if (category === INITIAL_EDGE_CATEGORY) {
      initialEdgeNodeIds.add(node.hgnc_id);
    }

    return {
      data: {
        id: node.hgnc_id,
        parent: mainCluster !== undefined ? `cluster-${mainCluster}` : undefined,
        symbol: node.symbol,
        cluster: node.cluster,
        degree: node.degree,
        category,
        size: Math.max(15, Math.sqrt(node.degree || 1) * 6),
        color: getClusterColor(node.cluster),
      },
      ...(hasPosition ? { position: { x: Number(node.x), y: Number(node.y) } } : {}),
    };
  });

  const clusterParentNodes: ElementDefinition[] = Array.from(clusterIds).map((clusterId) => ({
    data: {
      id: `cluster-${clusterId}`,
      label: `Cluster ${clusterId}`,
      isClusterParent: true,
      color: getClusterColor(clusterId),
    },
  }));

  const edges: ElementDefinition[] = options.omitEdges
    ? []
    : data.edges.flatMap((edge: NetworkEdge, idx: number) => {
        if (
          options.initialDefaultEdgesOnly &&
          (!initialEdgeNodeIds.has(edge.source) || !initialEdgeNodeIds.has(edge.target))
        ) {
          return [];
        }
        return [
          {
            data: {
              id: `e${idx}`,
              source: edge.source,
              target: edge.target,
              confidence: edge.confidence,
              width: Math.max(0.5, edge.confidence * 3),
            },
          },
        ];
      });

  return [...clusterParentNodes, ...nodes, ...edges];
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
  const networkData = shallowRef<NetworkResponse | null>(null);
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
   * PERFORMANCE: Uses max_edges parameter (default 10000) to limit edges
   * returned. This prevents browser from being overwhelmed with 66k+ edges.
   * Higher confidence edges are prioritized when filtering.
   *
   * @param clusterType - Type of clustering to use ('clusters' or 'subclusters')
   * @param maxEdges - Maximum edges to return (default 10000, 0 for all)
   */
  const fetchNetworkData = async (
    clusterType: 'clusters' | 'subclusters' = 'clusters',
    maxEdges: number = 10000
  ): Promise<void> => {
    isLoading.value = true;
    error.value = null;

    console.log(
      `[useNetworkData] Fetching network data (cluster_type=${clusterType}, max_edges=${maxEdges})`
    );
    const startTime = performance.now();

    try {
      const data = await preloadNetworkData(clusterType, maxEdges);
      networkData.value = data;

      const elapsed = performance.now() - startTime;
      console.log(`[useNetworkData] Fetch complete in ${elapsed.toFixed(0)}ms`);
      console.log(
        `[useNetworkData] Received ${data.nodes?.length || 0} nodes, ${data.edges?.length || 0} edges`
      );

      if (data.metadata?.edges_filtered) {
        console.log(
          `[useNetworkData] Edges filtered: showing ${data.metadata.edge_count} of ${data.metadata.total_edges} total`
        );
      }
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
   * PERFORMANCE OPTIMIZED:
   * - Uses backend fCoSE display coordinates when complete, with client fCoSE fallback
   * - Pre-computes node size and edge width as data properties
   * - Creates compound parent nodes for clusters to enable visual separation
   * - Cytoscape uses fcose layout with compound node support
   *
   * Computed property that automatically updates when networkData changes.
   */
  const cytoscapeElements = computed<ElementDefinition[]>(() => {
    if (!networkData.value) return [];

    console.log(
      `[useNetworkData] Transforming ${networkData.value.nodes.length} nodes, ${networkData.value.edges.length} edges`
    );
    const startTime = performance.now();
    const elements = buildCytoscapeElements(networkData.value);

    const elapsed = performance.now() - startTime;
    console.log(
      `[useNetworkData] Transform complete in ${elapsed.toFixed(0)}ms (${elements.length} elements)`
    );
    return elements;
  });

  const cytoscapeInitialElements = computed<ElementDefinition[]>(() => {
    if (!networkData.value) return [];

    console.log(
      `[useNetworkData] Building initial graph from ${networkData.value.nodes.length} nodes, ${networkData.value.edges.length} edges`
    );
    const startTime = performance.now();
    const elements = buildCytoscapeElements(networkData.value, { initialDefaultEdgesOnly: true });

    const elapsed = performance.now() - startTime;
    console.log(
      `[useNetworkData] Initial graph built in ${elapsed.toFixed(0)}ms (${elements.length} elements)`
    );
    return elements;
  });

  const cytoscapeNodeElements = computed<ElementDefinition[]>(() => {
    if (!networkData.value) return [];

    console.log(
      `[useNetworkData] Building node graph from ${networkData.value.nodes.length} nodes`
    );
    const startTime = performance.now();
    const elements = buildCytoscapeElements(networkData.value, { omitEdges: true });

    const elapsed = performance.now() - startTime;
    console.log(
      `[useNetworkData] Node graph built in ${elapsed.toFixed(0)}ms (${elements.length} elements)`
    );
    return elements;
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
    cytoscapeInitialElements,
    cytoscapeNodeElements,
    clearNetworkData,
  };
}

export default useNetworkData;

// Re-export types for convenience
export type { NetworkNode, NetworkEdge, NetworkResponse, NetworkMetadata } from '@/api/analysis';
