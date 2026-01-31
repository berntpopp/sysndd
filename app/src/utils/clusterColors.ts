// utils/clusterColors.ts

/**
 * Shared cluster color utilities
 *
 * Provides consistent cluster colors across all components
 * (NetworkVisualization, AnalyseGeneClusters table, etc.)
 *
 * Uses D3 category10 palette for distinct cluster visualization.
 */

/**
 * D3 category10 color palette for cluster visualization
 * Provides 15 distinct colors that cycle for larger cluster counts
 */
export const CLUSTER_COLORS: readonly string[] = [
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
] as const;

/**
 * Get color for a cluster based on its ID
 *
 * Uses the cluster number directly as the index (not 0-indexed).
 * This ensures Cluster 1 gets color at index 1, Cluster 2 at index 2, etc.
 *
 * @param cluster - Cluster number or string ID (e.g., 1 or "1.2" for subclusters)
 * @returns Hex color string
 *
 * @example
 * getClusterColor(1)     // Returns '#ff7f0e' (orange)
 * getClusterColor(2)     // Returns '#2ca02c' (green)
 * getClusterColor("1.2") // Returns '#ff7f0e' (orange, uses main cluster)
 */
export function getClusterColor(cluster: number | string): string {
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

export default { CLUSTER_COLORS, getClusterColor };
