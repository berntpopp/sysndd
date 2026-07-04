// src/components/analyses/curationComparisonsTableConfig.ts
//
// Static table configuration for the curation-comparisons table
// (AnalysesCurationComparisonsTable.vue): the default column field
// descriptors, the default filter object, and the source-column list used by
// the "definitive only" toggle. Extracted so the component stays a thinner
// shell and the default filter shape lives in one place (previously duplicated
// in data() and removeFilters()).

/** Bootstrap-Vue-Next field descriptor for the comparisons table. */
export interface ComparisonTableField {
  key: string;
  label: string;
  sortable: boolean;
  filterable: boolean;
  class: string;
}

/** Per-column filter entry shape. */
export interface ComparisonFilterEntry {
  content: string | string[] | null;
  join_char: string | null;
  operator: string;
}

export type ComparisonFilter = Record<string, ComparisonFilterEntry>;

/**
 * Source columns (excluding the free-text `symbol` search) toggled together by
 * the "Definitive only" switch.
 */
export const COMPARISON_SOURCE_COLUMNS = [
  'SysNDD',
  'gene2phenotype',
  'panelapp',
  'radboudumc_ID',
  'sfari',
  'ndd_genehub',
  'orphanet_id',
  'omim_ndd',
] as const;

/**
 * Default column descriptors for the comparisons table (overwritten by the
 * backend fspec once data loads).
 */
export function createComparisonFields(): ComparisonTableField[] {
  return [
    { key: 'symbol', label: 'Symbol', sortable: true, filterable: true, class: 'text-start' },
    { key: 'SysNDD', label: 'SysNDD', sortable: true, filterable: true, class: 'text-start' },
    {
      key: 'gene2phenotype',
      label: 'Gene2Phenotype',
      sortable: true,
      filterable: true,
      class: 'text-start',
    },
    { key: 'panelapp', label: 'PanelApp', sortable: true, filterable: true, class: 'text-start' },
    {
      key: 'radboudumc_ID',
      label: 'Radboudumc',
      sortable: true,
      filterable: true,
      class: 'text-start',
    },
    { key: 'sfari', label: 'SFARI', sortable: true, filterable: true, class: 'text-start' },
    {
      key: 'ndd_genehub',
      label: 'NDD GeneHub',
      sortable: true,
      filterable: true,
      class: 'text-start',
    },
    {
      key: 'orphanet_id',
      label: 'Orphanet',
      sortable: true,
      filterable: true,
      class: 'text-start',
    },
    { key: 'omim_ndd', label: 'OMIM NDD', sortable: true, filterable: true, class: 'text-start' },
  ];
}

/**
 * Overlay the curated, source-correct column labels onto the backend field
 * spec, preserving every backend-computed property (`count`, `count_filtered`,
 * `selectOptions`, `filterable`, …).
 *
 * The backend derives generic labels via `str_to_sentence(key)`
 * ("SysNDD" -> "Sysndd", "panelapp" -> "Panelapp", "omim_ndd" -> "Omim ndd").
 * Those are wrong for these external sources, so we re-apply the curated labels
 * from {@link createComparisonFields} (matched by `key`) while keeping the
 * backend's count facets that drive the column-statistics header tooltip.
 *
 * @param fspec - The `meta[0].fspec` array returned by `/api/comparisons/browse`.
 * @returns The same entries with curated labels applied where the key is known.
 */
export function withCuratedComparisonLabels<T extends { key: string; label?: string }>(
  fspec: T[]
): T[] {
  if (!Array.isArray(fspec)) {
    return fspec;
  }
  const curatedLabels = new Map(createComparisonFields().map((field) => [field.key, field.label]));
  return fspec.map((field) =>
    curatedLabels.has(field.key)
      ? { ...field, label: curatedLabels.get(field.key) as string }
      : field
  );
}

/**
 * Default (empty) filter object for the comparisons table. Returns a fresh
 * object each call so `data()` and `removeFilters()` never share state.
 */
export function createComparisonFilter(): ComparisonFilter {
  return {
    any: { content: null, join_char: null, operator: 'contains' },
    symbol: { content: null, join_char: null, operator: 'contains' },
    SysNDD: { content: null, join_char: ',', operator: 'any' },
    gene2phenotype: { content: null, join_char: ',', operator: 'any' },
    panelapp: { content: null, join_char: ',', operator: 'any' },
    radboudumc_ID: { content: null, join_char: null, operator: 'contains' },
    sfari: { content: null, join_char: ',', operator: 'any' },
    ndd_genehub: { content: null, join_char: null, operator: 'contains' },
    orphanet_id: { content: null, join_char: null, operator: 'contains' },
    omim_ndd: { content: null, join_char: null, operator: 'contains' },
  };
}
