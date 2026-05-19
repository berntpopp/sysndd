export type FunctionalClusterTableType = 'term_enrichment' | 'identifiers';

export interface FunctionalClusterRow {
  [key: string]: unknown;
}

export interface FunctionalClusterFilterOptions {
  tableType: FunctionalClusterTableType;
  searchPattern?: string | null;
  wildcardMatches?: (symbol: string) => boolean;
  categoryFilter?: string | null;
  fdrThreshold?: number | null;
  anyText?: string | null;
  columnFilters?: Record<string, string | null | undefined>;
}

export function filterFunctionalClusterRows<T extends FunctionalClusterRow>(
  rows: T[],
  options: FunctionalClusterFilterOptions
): T[] {
  const anyText = (options.anyText || '').toLowerCase();
  const searchPattern = options.searchPattern || '';
  const columnFilters = options.columnFilters || {};

  return rows.filter((row) => {
    if (searchPattern && options.tableType === 'identifiers' && row.symbol) {
      const matches = options.wildcardMatches ?? (() => true);
      if (!matches(String(row.symbol))) {
        return false;
      }
    }

    if (options.categoryFilter && options.tableType === 'term_enrichment') {
      if (row.category !== options.categoryFilter) {
        return false;
      }
    }

    if (options.fdrThreshold !== null && options.fdrThreshold !== undefined) {
      if (options.tableType === 'term_enrichment') {
        const fdrValue = parseFloat(String(row.fdr));
        if (Number.isNaN(fdrValue) || fdrValue >= options.fdrThreshold) {
          return false;
        }
      }
    }

    if (anyText) {
      const rowString = Object.values(row).join(' ').toLowerCase();
      if (!rowString.includes(anyText)) {
        return false;
      }
    }

    return Object.entries(columnFilters).every(([fieldKey, content]) => {
      const columnText = (content || '').toLowerCase();
      if (!columnText) return true;
      return String(row[fieldKey] || '')
        .toLowerCase()
        .includes(columnText);
    });
  });
}

export function sortFunctionalClusterRows<T extends FunctionalClusterRow>(
  rows: T[],
  sortBy: string | null | undefined,
  sortDesc: boolean
): T[] {
  if (!sortBy) return rows;

  return [...rows].sort((a, b) => {
    const aValue = a[sortBy];
    const bValue = b[sortBy];

    if (aValue == null && bValue == null) return 0;
    if (aValue == null) return 1;
    if (bValue == null) return -1;

    const aNumber = typeof aValue === 'number' ? aValue : parseFloat(String(aValue));
    const bNumber = typeof bValue === 'number' ? bValue : parseFloat(String(bValue));

    if (!Number.isNaN(aNumber) && !Number.isNaN(bNumber)) {
      const diff = aNumber - bNumber;
      return sortDesc ? -diff : diff;
    }

    const aString = String(aValue).toLowerCase();
    const bString = String(bValue).toLowerCase();
    if (aString < bString) return sortDesc ? 1 : -1;
    if (aString > bString) return sortDesc ? -1 : 1;
    return 0;
  });
}
