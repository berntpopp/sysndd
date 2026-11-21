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

/** WCAG relative luminance of a #rrggbb color. */
function relativeLuminance(hex: string): number {
  const [r, g, b] = [1, 3, 5].map((i) => {
    const c = parseInt(hex.slice(i, i + 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/**
 * Black or white, whichever contrasts more with the cluster's badge color.
 * The better of the two is always >= 4.58:1, so badge text meets WCAG AA.
 */
export function getClusterTextColor(cluster: number | string): string {
  const l = relativeLuminance(getClusterColor(cluster));
  return 1.05 / (l + 0.05) >= (l + 0.05) / 0.05 ? '#ffffff' : '#000000';
}

export default { CLUSTER_COLORS, getClusterColor, getClusterTextColor };
