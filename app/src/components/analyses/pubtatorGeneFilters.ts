export interface PubtatorGeneFilterField {
  content: string | string[] | null;
  operator: string;
  join_char: string | null;
}

export type PubtatorGeneFilter = Record<string, PubtatorGeneFilterField>;

export function createDefaultPubtatorGeneFilter(): PubtatorGeneFilter {
  return {
    any: { content: null, join_char: null, operator: 'contains' },
    gene_name: { content: null, join_char: null, operator: 'contains' },
    gene_symbol: { content: null, join_char: null, operator: 'contains' },
    gene_normalized_id: { content: null, join_char: null, operator: 'contains' },
    hgnc_id: { content: null, join_char: null, operator: 'contains' },
    publication_count: { content: null, join_char: null, operator: 'greaterThanOrEqual' },
    oldest_pub_date: { content: null, join_char: null, operator: 'greaterThanOrEqual' },
    is_novel: { content: null, join_char: null, operator: 'equals' },
  };
}

export function applyPubtatorGenePrioritizationFilters(
  filter: PubtatorGeneFilter,
  options: {
    minPublications: string;
    dateRangeYears: string;
    today?: Date;
  }
): PubtatorGeneFilter {
  const nextFilter = {
    ...filter,
    publication_count: { ...filter.publication_count },
    oldest_pub_date: { ...filter.oldest_pub_date },
  };

  nextFilter.publication_count.content =
    options.minPublications === 'all' ? null : options.minPublications;

  if (options.dateRangeYears === 'all') {
    nextFilter.oldest_pub_date.content = null;
  } else {
    const cutoffDate = new Date(options.today ?? new Date());
    cutoffDate.setFullYear(cutoffDate.getFullYear() - parseInt(options.dateRangeYears, 10));
    nextFilter.oldest_pub_date.content = cutoffDate.toISOString().split('T')[0];
  }

  return nextFilter;
}
