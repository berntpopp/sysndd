// components/tables/entityTableConfig.ts
//
// Static column, detail, and filter configuration for the entities table
// (TablesEntities.vue). Extracted so useEntitiesTable.ts stays focused on
// behaviour (issue #346). Runtime API `fspec` rows overwrite `fields` at
// response time (see applyApiResponse in useEntitiesTable.ts).

export interface EntityTableField {
  key: string;
  label: string;
  sortable?: boolean;
  sortDirection?: string;
  class?: string;
  filterable?: boolean;
  selectable?: boolean;
  multi_selectable?: boolean;
  selectOptions?: unknown[];
  // Runtime fspec rows from the API carry extra keys (filterable, selectable,
  // selectOptions, …); the index signature keeps the default config and the
  // API-overwritten config the same shape.
  [k: string]: unknown;
}

export interface EntityFilterField {
  content: string | null;
  join_char: string | null;
  operator: string;
}

export type EntityFilter = Record<string, EntityFilterField>;

/** Default column definitions. Overwritten at runtime by the API `fspec` when present. */
export const ENTITY_TABLE_FIELDS: EntityTableField[] = [
  {
    key: 'entity_id',
    label: 'Entity',
    sortable: true,
    sortDirection: 'asc',
    class: 'text-start',
  },
  {
    key: 'symbol',
    label: 'Symbol',
    sortable: true,
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
    sortable: true,
    class: 'text-start',
  },
  {
    key: 'category',
    label: 'Category',
    sortable: true,
    class: 'text-start',
  },
  {
    key: 'ndd_phenotype_word',
    label: 'NDD',
    sortable: true,
    class: 'text-start',
  },
  {
    key: 'details',
    label: 'Details',
  },
];

/** Row-expansion detail-card fields rendered by GenericTable's default detail card. */
export const ENTITY_TABLE_FIELD_DETAILS: EntityTableField[] = [
  { key: 'hgnc_id', label: 'HGNC ID', class: 'text-start' },
  {
    key: 'disease_ontology_id_version',
    label: 'Ontology ID version',
    class: 'text-start',
  },
  {
    key: 'disease_ontology_name',
    label: 'Disease ontology name',
    class: 'text-start',
  },
  { key: 'entry_date', label: 'Entry date', class: 'text-start' },
  { key: 'last_update', label: 'Last updated', class: 'text-start' },
  { key: 'synopsis', label: 'Clinical Synopsis', class: 'text-start' },
];

/**
 * Short label overrides applied on top of the server `fspec`, so mobile-
 * stacked table headers stay compact even though the API sends longer labels.
 */
export const ENTITY_SHORT_LABELS: Record<string, string> = {
  entity_id: 'Entity',
  disease_ontology_name: 'Disease',
  hpo_mode_of_inheritance_term_name: 'Inheritance',
  ndd_phenotype_word: 'NDD',
};

/** Single source of truth for the empty entity-filter shape. */
export function createEmptyEntityFilter(): EntityFilter {
  return {
    any: { content: null, join_char: null, operator: 'contains' },
    entity_id: { content: null, join_char: null, operator: 'contains' },
    symbol: { content: null, join_char: null, operator: 'contains' },
    disease_ontology_name: { content: null, join_char: null, operator: 'contains' },
    disease_ontology_id_version: { content: null, join_char: null, operator: 'contains' },
    hpo_mode_of_inheritance_term_name: { content: null, join_char: ',', operator: 'any' },
    hpo_mode_of_inheritance_term: { content: null, join_char: ',', operator: 'any' },
    ndd_phenotype_word: { content: null, join_char: null, operator: 'contains' },
    category: { content: null, join_char: ',', operator: 'any' },
    entities_count: { content: null, join_char: ',', operator: 'any' },
  };
}

/**
 * Normalize select options for BFormSelect (multi-select filter columns).
 *
 * Kept distinct from the shared `app/src/utils/selectOptions.ts` normalizer
 * — that helper prioritizes `id`/`label` first, whereas this table's original
 * inlined normalizer prioritized `value`/`text`/`name`. Preserved verbatim
 * here to stay behavior-preserving for the entities table (issue #346).
 */
export function normalizeEntitySelectOptions(
  options: unknown
): Array<{ value: unknown; text: unknown }> {
  if (!options || !Array.isArray(options)) {
    return [];
  }
  return options.map((opt) => {
    if (typeof opt === 'string') {
      return { value: opt, text: opt };
    }
    if (typeof opt === 'object' && opt !== null) {
      const o = opt as Record<string, unknown>;
      return {
        value: o.value || o.id || opt,
        text: o.text || o.label || o.name || opt,
      };
    }
    return { value: opt, text: String(opt) };
  });
}
