// components/tables/geneTableConfig.ts
//
// Static column/detail-column configuration for the /Genes table. Extracted
// from TablesGenes.vue so useGenesTable.ts stays focused on behaviour (URL
// sync, request/response orchestration, pagination). Field definitions below
// are the DEFAULT columns; the API's `fspec` response overwrites `fields` at
// runtime (see applyApiResponse in useGenesTable.ts) — this mirrors the
// established logTableConfig.ts / LOG_TABLE_FIELDS pattern.

export interface GeneTableField {
  key: string;
  label: string;
  sortable?: boolean;
  sortDirection?: string;
  class?: string;
  // Runtime fspec rows from the API carry extra keys (filterable, selectable,
  // selectOptions, multi_selectable, …); the index signature keeps the
  // default config and the API-overwritten config the same shape.
  [k: string]: unknown;
}

/**
 * Default top-level gene table columns. Overwritten at runtime by the API
 * `fspec` when present (see applyApiResponse in useGenesTable.ts).
 */
export const GENE_TABLE_FIELDS: GeneTableField[] = [
  {
    key: 'symbol',
    label: 'Gene Symbol',
    sortable: true,
    sortDirection: 'desc',
    class: 'text-start',
  },
  {
    key: 'category',
    label: 'Category',
    sortable: false,
    class: 'text-start',
  },
  {
    key: 'hpo_mode_of_inheritance_term_name',
    label: 'Inheritance',
    sortable: false,
    class: 'text-start',
  },
  {
    key: 'ndd_phenotype_word',
    label: 'NDD',
    sortable: false,
    class: 'text-start',
  },
  {
    key: 'entities_count',
    label: 'Entities count',
  },
  {
    key: 'details',
    label: 'Details',
  },
];

/**
 * Columns for the per-gene "entities" row-expansion detail table. Static —
 * not overwritten by the API fspec (that only applies to the top-level
 * `fields`).
 */
export const GENE_TABLE_DETAIL_FIELDS: GeneTableField[] = [
  {
    key: 'entity_id',
    label: 'Entity',
    sortable: true,
    sortDirection: 'desc',
    class: 'text-start',
  },
  {
    key: 'disease_ontology_name',
    label: 'Disease',
    sortable: true,
    class: 'text-start',
  },
  {
    key: 'hpo_mode_of_inheritance_term_name',
    label: 'Inheritance',
    sortable: false,
    class: 'text-start',
  },
  {
    key: 'category',
    label: 'Category',
    sortable: false,
    class: 'text-start',
  },
  {
    key: 'ndd_phenotype_word',
    label: 'NDD',
    sortable: false,
    class: 'text-start',
  },
];

/**
 * Default `fspecInput` prop value requested from the API when the parent
 * view doesn't override it. Mirrors GENE_TABLE_FIELDS' key order.
 */
export const GENE_TABLE_DEFAULT_FSPEC =
  'symbol,category,hpo_mode_of_inheritance_term_name,ndd_phenotype_word,entities_count,details';
