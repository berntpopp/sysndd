import { describe, expect, it } from 'vitest';

import type { NetworkMetadata } from '@/api/analysis';
import { getClusterColor } from '@/utils/clusterColors';
import {
  CATEGORY_OPTIONS,
  categoryCountsHaveData,
  computeCategoryFilterLabel,
  computeCategoryOptionsWithCounts,
  computeClusterFilterLabel,
  computeEdgesFilteredTooltip,
  computeGeneCountTooltip,
  computeIsNetworkFiltered,
  computeLegendClusters,
  computeNetworkCoverageTooltip,
  firstNodeCategoryIsKnown,
} from './networkVisualizationPresentation';

/** Build a NetworkMetadata with sensible defaults for the fields under test. */
function meta(partial: Partial<NetworkMetadata>): NetworkMetadata {
  return {
    node_count: 0,
    edge_count: 0,
    cluster_count: 0,
    total_edges: 0,
    edges_filtered: false,
    elapsed_seconds: 0,
    ...partial,
  } as NetworkMetadata;
}

/** Build node ElementDefinition-like objects carrying a cluster in data. */
function nodesWithClusters(clusters: Array<number | string | null | undefined>) {
  return clusters.map((cluster) => ({ data: { id: `n-${cluster}`, cluster } }));
}

describe('networkVisualizationPresentation', () => {
  describe('computeLegendClusters', () => {
    it('orders sparse cluster ids by count desc then id asc, with no synthetic ids', () => {
      // Sparse partition labels 2, 7, 11 (never a contiguous 1..N). Give 2 and 7
      // the same member count so the tie must break by ascending id, and 11 the
      // smallest count so it lands last regardless of id.
      const nodes = nodesWithClusters([7, 7, 7, 2, 2, 2, 11]);

      const result = computeLegendClusters(nodes);

      expect(result.map((c) => c.id)).toEqual([2, 7, 11]);
      // No fabricated 1..N ids leak in.
      expect(result.map((c) => c.id)).not.toContain(1);
      expect(result.map((c) => c.id)).not.toContain(3);
    });

    it('coerces string subcluster ids to their main cluster and skips missing clusters', () => {
      const nodes = nodesWithClusters(['11.2', '11.4', '2.1', null, undefined, 7]);

      const result = computeLegendClusters(nodes);

      // 11 appears twice, 2 once, 7 once; null/undefined dropped.
      expect(result.map((c) => c.id)).toEqual([11, 2, 7]);
    });

    it('assigns each cluster the shared getClusterColor value', () => {
      const result = computeLegendClusters(nodesWithClusters([7, 2]));

      for (const cluster of result) {
        expect(cluster.color).toBe(getClusterColor(cluster.id));
      }
    });

    it('returns an empty list when there are no node elements', () => {
      expect(computeLegendClusters([])).toEqual([]);
    });
  });

  describe('category options and availability', () => {
    it('computes cumulative category option counts', () => {
      const options = computeCategoryOptionsWithCounts({
        Definitive: 10,
        Moderate: 5,
        Limited: 3,
      });

      expect(options).toEqual([
        { value: 'Definitive', label: 'Definitive only', count: 10 },
        { value: 'Moderate', label: '+ Moderate', count: 15 },
        { value: 'Limited', label: '+ Limited', count: 18 },
      ]);
    });

    it('treats missing category data as all-zero counts', () => {
      expect(computeCategoryOptionsWithCounts(undefined)).toEqual([
        { value: 'Definitive', label: 'Definitive only', count: 0 },
        { value: 'Moderate', label: '+ Moderate', count: 0 },
        { value: 'Limited', label: '+ Limited', count: 0 },
      ]);
      expect(computeCategoryOptionsWithCounts({})).toEqual([
        { value: 'Definitive', label: 'Definitive only', count: 0 },
        { value: 'Moderate', label: '+ Moderate', count: 0 },
        { value: 'Limited', label: '+ Limited', count: 0 },
      ]);
    });

    it('reports category data present only when the counts sum above zero', () => {
      expect(categoryCountsHaveData({ Definitive: 0, Moderate: 0, Limited: 0 })).toBe(false);
      expect(categoryCountsHaveData({ Definitive: 2, Moderate: 0, Limited: 0 })).toBe(true);
      expect(categoryCountsHaveData(undefined)).toBe(false);
    });

    it('reads a first-node category as known unless it is empty or Unknown', () => {
      expect(firstNodeCategoryIsKnown('Definitive')).toBe(true);
      expect(firstNodeCategoryIsKnown('Unknown')).toBe(false);
      expect(firstNodeCategoryIsKnown('')).toBe(false);
      expect(firstNodeCategoryIsKnown(undefined)).toBe(false);
    });

    it('exposes the fixed category option catalog', () => {
      expect(CATEGORY_OPTIONS.map((o) => o.value)).toEqual(['Definitive', 'Moderate', 'Limited']);
      expect(computeCategoryFilterLabel('Moderate')).toBe('Category: + Moderate');
      expect(computeCategoryFilterLabel('Unknown')).toBe('Category: Unknown');
    });
  });

  describe('computeClusterFilterLabel', () => {
    it('labels all-clusters, none, and a selection count', () => {
      expect(computeClusterFilterLabel(true, 0)).toBe('Clusters: All');
      expect(computeClusterFilterLabel(false, 0)).toBe('Clusters: None');
      expect(computeClusterFilterLabel(false, 3)).toBe('Clusters: 3 selected');
    });
  });

  describe('computeNetworkCoverageTooltip (STRING coverage)', () => {
    it('names the STRING-covered subset when fewer genes than total are shown', () => {
      expect(
        computeNetworkCoverageTooltip(meta({ node_count: 1310, total_ndd_genes: 2154 }))
      ).toBe(
        '1310 of 2154 NDD genes shown. Only genes with STRING protein-protein interaction data are included.'
      );
    });

    it('falls back to the plain interaction count when all genes are shown', () => {
      expect(
        computeNetworkCoverageTooltip(meta({ node_count: 2154, total_ndd_genes: 2154 }))
      ).toBe('2154 genes with protein-protein interactions');
    });

    it('returns an empty string without metadata', () => {
      expect(computeNetworkCoverageTooltip(null)).toBe('');
    });
  });

  describe('computeIsNetworkFiltered', () => {
    it('is true only when a positive visible count is below the total', () => {
      expect(computeIsNetworkFiltered(1310, 2154)).toBe(true);
      expect(computeIsNetworkFiltered(2154, 2154)).toBe(false);
      expect(computeIsNetworkFiltered(0, 2154)).toBe(false);
    });
  });

  describe('computeGeneCountTooltip (active-filter gene tooltip)', () => {
    it('names the active category and cluster filters when filtering hides genes', () => {
      expect(
        computeGeneCountTooltip({
          isNetworkFiltered: true,
          networkCoverageTooltip: 'coverage-fallback',
          visibleNodeCount: 1310,
          nodeCount: 2154,
          showAllClusters: false,
          selectedClusterCount: 2,
          categoryFilterLabel: 'Category: Definitive only',
          clusterFilterLabel: 'Clusters: 2 selected',
        })
      ).toBe(
        'Showing 1310 of 2154 network genes. Active filter — Category: Definitive only, Clusters: 2 selected. Use the Category / Clusters dropdowns to show more.'
      );
    });

    it('omits the cluster part when all clusters are shown', () => {
      expect(
        computeGeneCountTooltip({
          isNetworkFiltered: true,
          networkCoverageTooltip: 'coverage-fallback',
          visibleNodeCount: 1310,
          nodeCount: 2154,
          showAllClusters: true,
          selectedClusterCount: 0,
          categoryFilterLabel: 'Category: Definitive only',
          clusterFilterLabel: 'Clusters: All',
        })
      ).toBe(
        'Showing 1310 of 2154 network genes. Active filter — Category: Definitive only. Use the Category / Clusters dropdowns to show more.'
      );
    });

    it('falls back to the coverage tooltip when the network is not filtered', () => {
      expect(
        computeGeneCountTooltip({
          isNetworkFiltered: false,
          networkCoverageTooltip: 'coverage-fallback',
          visibleNodeCount: 2154,
          nodeCount: 2154,
          showAllClusters: true,
          selectedClusterCount: 0,
          categoryFilterLabel: 'Category: Definitive only',
          clusterFilterLabel: 'Clusters: All',
        })
      ).toBe('coverage-fallback');
    });
  });

  describe('computeEdgesFilteredTooltip (filtered edge tooltip)', () => {
    it('names the capped subset when edges are filtered for performance', () => {
      expect(
        computeEdgesFilteredTooltip(
          meta({ edge_count: 10000, total_edges: 45000, edges_filtered: true })
        )
      ).toBe(
        'Showing 10000 of 45000 total edges. Limited to 10,000 for performance (high confidence prioritized).'
      );
    });

    it('falls back to the plain interaction count when edges are not filtered', () => {
      expect(
        computeEdgesFilteredTooltip(meta({ edge_count: 42, edges_filtered: false }))
      ).toBe('42 protein-protein interactions');
    });

    it('returns an empty string without metadata', () => {
      expect(computeEdgesFilteredTooltip(null)).toBe('');
    });
  });
});
