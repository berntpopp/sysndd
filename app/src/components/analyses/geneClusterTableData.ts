// src/components/analyses/geneClusterTableData.ts
//
// Pure data-normalization and table-configuration helpers for the gene
// functional-clustering analysis (AnalyseGeneClusters.vue). Extracted so the
// component stays a thinner shell and these transforms are unit-testable in
// isolation. None of these helpers touch the network/layout strategy.

/** A single functional-cluster record as returned by the clustering API. */
export interface FunctionalCluster {
  cluster: number;
  term_enrichment?: Array<Record<string, unknown>>;
  identifiers?: Array<Record<string, unknown>>;
  hash_filter?: string | null;
  [extra: string]: unknown;
}

/** Term-enrichment / identifiers rows keyed by table type. */
export interface SelectedClusterData {
  term_enrichment: Array<Record<string, unknown>>;
  identifiers: Array<Record<string, unknown>>;
}

/** A category descriptor used for label and link resolution. */
export interface CategoryDescriptor {
  value: string;
  text: string;
  link?: string;
}

/** Bootstrap-Vue-Next table field descriptor. */
export interface ClusterTableField {
  key: string;
  label: string;
  sortable: boolean;
  thClass: string;
  tdClass: string;
  sortByFormatted?: boolean;
  sortCompare?: (aRow: Record<string, unknown>, bRow: Record<string, unknown>, key: string) => number;
}

export type ClusterTableType = 'term_enrichment' | 'identifiers';

/**
 * Tag each row of a cluster's term-enrichment and identifiers arrays with the
 * cluster number so combined/multi-cluster tables show provenance.
 */
export function clusterRowsWithNumber(
  cluster: FunctionalCluster | undefined,
  clusterNum: number | null
): SelectedClusterData {
  if (!cluster) {
    return { term_enrichment: [], identifiers: [] };
  }
  return {
    term_enrichment: (cluster.term_enrichment || []).map((row) => ({
      ...row,
      cluster_num: clusterNum,
    })),
    identifiers: (cluster.identifiers || []).map((row) => ({
      ...row,
      cluster_num: clusterNum,
    })),
  };
}

/**
 * Combine data from multiple clusters into a single object, tagging each row
 * with its source cluster number so users can see which cluster it belongs to.
 */
export function combineClusterData(clusterArray: FunctionalCluster[]): SelectedClusterData {
  const combined: SelectedClusterData = {
    term_enrichment: [],
    identifiers: [],
  };

  clusterArray.forEach((cluster) => {
    const clusterNum = cluster.cluster;
    if (cluster.term_enrichment) {
      const enrichmentWithCluster = cluster.term_enrichment.map((row) => ({
        ...row,
        cluster_num: clusterNum,
      }));
      combined.term_enrichment = combined.term_enrichment.concat(enrichmentWithCluster);
    }
    if (cluster.identifiers) {
      const identifiersWithCluster = cluster.identifiers.map((row) => ({
        ...row,
        cluster_num: clusterNum,
      }));
      combined.identifiers = combined.identifiers.concat(identifiersWithCluster);
    }
  });

  return combined;
}

/**
 * Build the Bootstrap-Vue-Next field array for the cluster table, including the
 * leading cluster column. FDR is sorted by parsed numeric value so scientific
 * notation strings (e.g. "1.23e-20") order correctly.
 */
export function buildClusterTableFields(tableType: ClusterTableType): ClusterTableField[] {
  const clusterColumn: ClusterTableField = {
    key: 'cluster_num',
    label: 'Cluster',
    sortable: true,
    thClass: 'text-start bg-light',
    tdClass: 'text-start',
  };

  if (tableType === 'term_enrichment') {
    const fields: ClusterTableField[] = [
      {
        key: 'category',
        label: 'Category',
        sortable: true,
        thClass: 'text-start bg-light',
        tdClass: 'text-start',
      },
      {
        key: 'number_of_genes',
        label: '#Genes',
        sortable: true,
        thClass: 'text-start bg-light',
        tdClass: 'text-start',
      },
      {
        key: 'fdr',
        label: 'FDR',
        sortable: true,
        // Sort by numeric value (scientific notation strings like "1.23e-20")
        sortByFormatted: false,
        sortCompare: (aRow, bRow, key) => {
          const a = parseFloat(String(aRow[key])) || 0;
          const b = parseFloat(String(bRow[key])) || 0;
          return a - b;
        },
        thClass: 'text-start bg-light',
        tdClass: 'text-start',
      },
      {
        key: 'description',
        label: 'Description',
        sortable: true,
        thClass: 'text-start bg-light',
        tdClass: 'text-start',
      },
    ];
    fields.unshift(clusterColumn);
    return fields;
  }

  // 'identifiers' case
  const fields: ClusterTableField[] = [
    {
      key: 'symbol',
      label: 'Symbol',
      sortable: true,
      thClass: 'text-start bg-light',
      tdClass: 'text-start',
    },
    {
      key: 'STRING_id',
      label: 'STRING ID',
      sortable: true,
      thClass: 'text-start bg-light',
      tdClass: 'text-start',
    },
  ];
  fields.unshift(clusterColumn);
  return fields;
}

/**
 * Find the human-readable label for a category value, falling back to the raw
 * value when not present in the descriptor list.
 */
export function findCategoryText(
  categories: CategoryDescriptor[],
  categoryVal: string
): string {
  const found = categories.find((cat) => cat.value === categoryVal);
  return found ? found.text : categoryVal;
}

/**
 * Build an external link for a category term, falling back to '#' when the
 * category descriptor is unknown.
 */
export function findCategoryLink(
  categories: CategoryDescriptor[],
  categoryVal: string,
  termVal: string
): string {
  const found = categories.find((cat) => cat.value === categoryVal);
  return found ? `${found.link}${termVal}` : '#';
}

/**
 * Map a category value to a sysndd-chip modifier class. Uses quiet token chips
 * instead of a heavy dark-bordered badge; unknown categories fall back to the
 * neutral chip.
 */
export function categoryChipClass(category: string): string {
  const map: Record<string, string> = {
    GO: 'sysndd-chip--teal',
    KEGG: 'sysndd-chip--blue',
    MONDO: 'sysndd-chip--info',
    HPO: 'sysndd-chip--success',
  };
  return map[category] || 'sysndd-chip--neutral';
}

/**
 * Format an FDR value as scientific notation so tiny values (e.g. 1e-15) render
 * meaningfully instead of collapsing to "0".
 */
export function formatFdr(fdr: unknown): string {
  if (fdr == null) return '—';
  const n = Number(fdr);
  if (Number.isNaN(n)) return String(fdr);
  if (n === 0) return '0';
  if (n < 0.001 || n >= 1000) {
    return n.toExponential(2);
  }
  return n.toPrecision(3);
}

/** Column headers used for the Excel export, keyed by table type. */
export const CLUSTER_EXPORT_HEADERS: Record<ClusterTableType, Record<string, string>> = {
  term_enrichment: {
    cluster_num: 'Cluster',
    category: 'Category',
    number_of_genes: '# Genes',
    fdr: 'FDR',
    description: 'Description',
    term: 'Term ID',
  },
  identifiers: {
    cluster_num: 'Cluster',
    symbol: 'Gene Symbol',
    hgnc_id: 'HGNC ID',
    STRING_id: 'STRING ID',
  },
};

/**
 * Build the export filename for the cluster table based on which clusters are
 * displayed.
 */
export function buildClusterExportFilename(
  tableType: ClusterTableType,
  showAllClusters: boolean,
  displayedClusters: number[]
): string {
  const clusterLabel = showAllClusters
    ? 'all_clusters'
    : `clusters_${displayedClusters.join('_')}`;
  return `sysndd_gene_${tableType}_${clusterLabel}`;
}

/** Sheet name used for the Excel export, keyed by table type. */
export function clusterExportSheetName(tableType: ClusterTableType): string {
  return tableType === 'term_enrichment' ? 'Enrichment' : 'Identifiers';
}
