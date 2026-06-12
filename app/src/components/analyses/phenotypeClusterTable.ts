// src/components/analyses/phenotypeClusterTable.ts
//
// Pure client-side table transforms and export configuration for the phenotype
// clustering analysis (AnalysesPhenotypeClusters.vue): row sorting (numeric and
// scientific-notation aware), the global "any" + per-column filter, and the
// Excel export header/label/filename config. Extracted so the component stays a
// thinner shell. None of these touch the Cytoscape graph.

export type PhenotypeClusterTableType = 'quali_inp_var' | 'quali_sup_var' | 'quanti_sup_var';

/** A single phenotype-cluster table row (variable / p.value / v.test + extras). */
export type PhenotypeClusterRow = Record<string, unknown>;

/** Per-column filter entry shape. */
export interface PhenotypeFilterEntry {
  content: string | null;
  join_char: string | null;
  operator: string;
}

export type PhenotypeClusterFilter = Record<string, PhenotypeFilterEntry>;

/**
 * Sort rows by a column. Numeric values (including scientific notation strings
 * such as "1.23e-20") sort numerically; everything else sorts as a
 * lower-cased string. Null/undefined values are pushed to the end. Returns a
 * new array; the input is not mutated.
 */
export function sortPhenotypeClusterRows(
  rows: PhenotypeClusterRow[],
  sortBy: string | null | undefined,
  sortDesc: boolean
): PhenotypeClusterRow[] {
  if (!sortBy) return [...rows];
  return [...rows].sort((a, b) => {
    const aVal = a[sortBy];
    const bVal = b[sortBy];

    // Handle null/undefined - push to end
    if (aVal == null && bVal == null) return 0;
    if (aVal == null) return 1;
    if (bVal == null) return -1;

    // Handle numeric comparison (including scientific notation)
    const aNum = typeof aVal === 'number' ? aVal : parseFloat(String(aVal));
    const bNum = typeof bVal === 'number' ? bVal : parseFloat(String(bVal));

    if (!isNaN(aNum) && !isNaN(bNum)) {
      const diff = aNum - bNum;
      return sortDesc ? -diff : diff;
    }

    // String comparison for non-numeric values
    const aStr = String(aVal).toLowerCase();
    const bStr = String(bVal).toLowerCase();
    if (aStr < bStr) return sortDesc ? 1 : -1;
    if (aStr > bStr) return sortDesc ? -1 : 1;
    return 0;
  });
}

/**
 * Apply the global "any" filter and per-column "contains" filters to the rows.
 *
 * The `any` filter matches against the concatenation of all row values; the
 * remaining filter keys match against the corresponding column (case-insensitive
 * substring). Empty filter values are ignored.
 */
export function filterPhenotypeClusterRows(
  rows: PhenotypeClusterRow[],
  filter: PhenotypeClusterFilter
): PhenotypeClusterRow[] {
  const anyFilterValue = (filter.any?.content || '').toLowerCase();
  const filterKeys = Object.keys(filter).filter((f) => f !== 'any');

  return rows.filter((row) => {
    // 1. Global "any" filter
    if (anyFilterValue) {
      const rowString = Object.values(row).join(' ').toLowerCase();
      if (!rowString.includes(anyFilterValue)) {
        return false;
      }
    }
    // 2. Column-specific filters
    let keepRow = true;
    filterKeys.forEach((fieldKey) => {
      const colFilterVal = (filter[fieldKey].content || '').toLowerCase();
      if (colFilterVal) {
        const rowVal = String(row[fieldKey] || '').toLowerCase();
        if (!rowVal.includes(colFilterVal)) {
          keepRow = false;
        }
      }
    });
    return keepRow;
  });
}

/** Sheet-name labels for the Excel export, keyed by table type. */
export const PHENOTYPE_CLUSTER_EXPORT_LABELS: Record<PhenotypeClusterTableType, string> = {
  quali_inp_var: 'Qualitative Input Variables',
  quali_sup_var: 'Qualitative Supplementary Variables',
  quanti_sup_var: 'Quantitative Supplementary Variables',
};

/** Column headers for the Excel export (superset across all table types). */
export const PHENOTYPE_CLUSTER_EXPORT_HEADERS: Record<string, string> = {
  variable: 'Variable',
  'p.value': 'p-value',
  'v.test': 'v-test',
  // Additional columns that might be present
  Mean_in_category: 'Mean in Category',
  Overall_mean: 'Overall Mean',
  sd_in_category: 'SD in Category',
  Overall_sd: 'Overall SD',
};

/** Build the Excel export filename for a phenotype cluster table. */
export function buildPhenotypeClusterExportFilename(
  activeCluster: string | number,
  tableType: PhenotypeClusterTableType
): string {
  return `sysndd_phenotype_cluster_${activeCluster}_${tableType}`;
}

/** Sheet name for the Excel export (defaults to 'Data' for unknown types). */
export function phenotypeClusterExportSheetName(tableType: PhenotypeClusterTableType): string {
  return PHENOTYPE_CLUSTER_EXPORT_LABELS[tableType] || 'Data';
}
