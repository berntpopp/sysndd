// src/components/analyses/networkVisualizationPresentation.ts
//
// Pure presentation helpers for NetworkVisualization: cluster legend derivation,
// category option/label/availability computation, and the badge tooltip strings
// (STRING coverage, active-filter gene count, filtered edge count). None of these
// touch the Cytoscape graph or Vue reactivity — they are deterministic functions
// of their inputs, so they can be unit-tested in isolation and reused by the
// controller composable and the child components. Extracted from the SFC so the
// shell stays thin (#346).

import type { NetworkMetadata } from '@/api/analysis';
import type { CategoryFilter } from '@/composables/useNetworkFilters';
import { getClusterColor } from '@/utils/clusterColors';

/** A cluster entry for the legend / dropdown: real partition id + display color. */
export interface LegendCluster {
  id: number;
  color: string;
}

/** A category filter option (value + human label). */
export interface CategoryOption {
  value: CategoryFilter;
  label: string;
}

/** A category filter option carrying its cumulative member count. */
export interface CategoryOptionWithCount extends CategoryOption {
  count: number;
}

/**
 * Minimal node-element shape. `data` is intentionally `unknown` (rather than a
 * narrow `{ cluster? }`) so a Cytoscape `ElementDefinition[]` — whose `data` is a
 * node/edge-data interface without an index signature — is accepted; the cluster
 * is read out with the same targeted cast the original SFC used.
 */
export interface NetworkNodeElementLike {
  data?: unknown;
}

/** Parameters for the active-filter gene-count tooltip. */
export interface GeneCountTooltipParams {
  isNetworkFiltered: boolean;
  networkCoverageTooltip: string;
  visibleNodeCount: number;
  nodeCount: number;
  showAllClusters: boolean;
  selectedClusterCount: number;
  categoryFilterLabel: string;
  clusterFilterLabel: string;
}

/**
 * The fixed category filter catalog. Progressive-inclusion labels: "Definitive
 * only" then "+ Moderate" then "+ Limited".
 */
export const CATEGORY_OPTIONS: readonly CategoryOption[] = [
  { value: 'Definitive', label: 'Definitive only' },
  { value: 'Moderate', label: '+ Moderate' },
  { value: 'Limited', label: '+ Limited' },
];

/**
 * Build the cluster legend from the REAL distinct cluster ids present on the
 * nodes — never a fabricated `1..N`. IDs are coerced the same way the filter
 * matches them (main cluster = integer part of a `"1.2"` subcluster id), missing
 * clusters are skipped, and entries are sorted by member count descending then id
 * ascending so the largest clusters lead. Colors cycle via `getClusterColor`.
 */
export function computeLegendClusters(
  nodeElements: ReadonlyArray<NetworkNodeElementLike>
): LegendCluster[] {
  const counts = new Map<number, number>();
  for (const el of nodeElements) {
    const raw = (el.data as { cluster?: number | string } | undefined)?.cluster;
    if (raw === undefined || raw === null) continue;
    const id = typeof raw === 'string' ? parseInt(raw.split('.')[0], 10) : raw;
    if (!Number.isFinite(id)) continue;
    counts.set(id, (counts.get(id) ?? 0) + 1);
  }
  return Array.from(counts.entries())
    .sort((a, b) => b[1] - a[1] || a[0] - b[0])
    .map(([id]) => ({ id, color: getClusterColor(id) }));
}

/** Label for the category dropdown button (e.g. "Category: + Moderate"). */
export function computeCategoryFilterLabel(categoryLevel: CategoryFilter | string): string {
  const opt = CATEGORY_OPTIONS.find((o) => o.value === categoryLevel);
  return `Category: ${opt?.label || categoryLevel}`;
}

/** Label for the cluster dropdown button. */
export function computeClusterFilterLabel(
  showAllClusters: boolean,
  selectedClusterCount: number
): string {
  if (showAllClusters) {
    return 'Clusters: All';
  }
  return selectedClusterCount === 0
    ? 'Clusters: None'
    : `Clusters: ${selectedClusterCount} selected`;
}

/**
 * Category options with cumulative counts: Definitive, Definitive+Moderate,
 * Definitive+Moderate+Limited. Missing category data is treated as all-zero.
 */
export function computeCategoryOptionsWithCounts(
  categoryCounts: Record<string, number> | undefined
): CategoryOptionWithCount[] {
  const counts = categoryCounts || {};
  const defCount = counts.Definitive || 0;
  const modCount = counts.Moderate || 0;
  const limCount = counts.Limited || 0;

  return [
    { value: 'Definitive', label: 'Definitive only', count: defCount },
    { value: 'Moderate', label: '+ Moderate', count: defCount + modCount },
    { value: 'Limited', label: '+ Limited', count: defCount + modCount + limCount },
  ];
}

/** True when the category_counts metadata reports at least one classified gene. */
export function categoryCountsHaveData(
  categoryCounts: Record<string, number> | undefined
): boolean {
  if (!categoryCounts) return false;
  return (
    (categoryCounts.Definitive || 0) +
      (categoryCounts.Moderate || 0) +
      (categoryCounts.Limited || 0) >
    0
  );
}

/** True when a node's `category` value is present and not the "Unknown" sentinel. */
export function firstNodeCategoryIsKnown(category: unknown): boolean {
  return Boolean(category) && category !== 'Unknown';
}

/**
 * STRING-coverage tooltip for the gene-count badge: when the network shows fewer
 * genes than the total NDD gene set it explains that only STRING-covered genes
 * are included; otherwise it states the plain interaction count.
 */
export function computeNetworkCoverageTooltip(metadata: NetworkMetadata | null): string {
  if (!metadata) return '';
  const total = metadata.total_ndd_genes || 0;
  const inNetwork = metadata.node_count || 0;
  if (total && inNetwork < total) {
    return `${inNetwork} of ${total} NDD genes shown. Only genes with STRING protein-protein interaction data are included.`;
  }
  return `${inNetwork} genes with protein-protein interactions`;
}

/**
 * True when the active Category/Clusters filters hide some of the network's genes
 * (positive visible count strictly below the total), so the badge can flag itself.
 */
export function computeIsNetworkFiltered(visibleNodeCount: number, nodeCount: number): boolean {
  return visibleNodeCount > 0 && visibleNodeCount < nodeCount;
}

/**
 * Filter-aware tooltip for the gene-count badge: when a filter is hiding genes it
 * names the active filter; otherwise it falls back to the STRING-coverage string.
 */
export function computeGeneCountTooltip(params: GeneCountTooltipParams): string {
  if (!params.isNetworkFiltered) return params.networkCoverageTooltip;
  const clusterPart =
    !params.showAllClusters && params.selectedClusterCount > 0
      ? `, ${params.clusterFilterLabel}`
      : '';
  return `Showing ${params.visibleNodeCount} of ${params.nodeCount} network genes. Active filter — ${params.categoryFilterLabel}${clusterPart}. Use the Category / Clusters dropdowns to show more.`;
}

/**
 * Tooltip for the edge-count badge: when edges were capped for performance it
 * names the capped subset; otherwise it states the plain interaction count.
 */
export function computeEdgesFilteredTooltip(metadata: NetworkMetadata | null): string {
  if (!metadata) return '';
  if (metadata.edges_filtered && metadata.total_edges) {
    return `Showing ${metadata.edge_count} of ${metadata.total_edges} total edges. Limited to 10,000 for performance (high confidence prioritized).`;
  }
  return `${metadata.edge_count} protein-protein interactions`;
}
