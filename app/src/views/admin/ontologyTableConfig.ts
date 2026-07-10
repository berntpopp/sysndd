// views/admin/ontologyTableConfig.ts
//
// Static column/filter/select-option configuration for the Admin "Manage
// Ontology" (VariO variant-ontology) table. Extracted from
// ManageOntology.vue (#346 Wave 2) so useOntologyAdminTable.ts stays focused
// on behaviour (filter/watch/URL-sync/load/edit/update/export
// orchestration). Unlike the public Genes/Entities tables, `GET
// /api/ontology/variant/table` does not return an `fspec` in its response
// meta — these fields are never overwritten at runtime, so they are safe to
// keep as plain constants (see applyApiResponse in useOntologyAdminTable.ts,
// which never assigns to `fields`).

export interface OntologyTableField {
  key: string;
  label: string;
  sortable?: boolean;
  filterable?: boolean;
  selectable?: boolean;
  class?: string;
}

/** Table columns for the VariO variant-ontology admin table. */
export const ONTOLOGY_TABLE_FIELDS: OntologyTableField[] = [
  {
    key: 'vario_id',
    label: 'ID',
    sortable: true,
    filterable: true,
    class: 'text-start',
  },
  {
    key: 'vario_name',
    label: 'Name',
    sortable: true,
    filterable: true,
    class: 'text-start',
  },
  {
    key: 'definition',
    label: 'Definition',
    sortable: true,
    filterable: true,
    class: 'text-start',
  },
  {
    key: 'obsolete',
    label: 'Obsolete',
    sortable: true,
    selectable: true,
    class: 'text-center',
  },
  {
    key: 'is_active',
    label: 'Active',
    sortable: true,
    selectable: true,
    class: 'text-center',
  },
  {
    key: 'sort',
    label: 'Sort',
    sortable: true,
    class: 'text-center',
  },
  {
    key: 'update_date',
    label: 'Updated',
    sortable: true,
    class: 'text-start',
  },
  {
    key: 'actions',
    label: 'Actions',
    class: 'text-center',
  },
];

export interface OntologySelectOption {
  value: string;
  text: string;
}

/** Options for the "All Status" filter select. */
export const ONTOLOGY_ACTIVE_FILTER_OPTIONS: OntologySelectOption[] = [
  { value: '1', text: 'Active' },
  { value: '0', text: 'Inactive' },
];

/** Options for the "All Terms" filter select. */
export const ONTOLOGY_OBSOLETE_FILTER_OPTIONS: OntologySelectOption[] = [
  { value: '0', text: 'Current' },
  { value: '1', text: 'Obsolete' },
];

/** Options for the mobile-only sort <select>. */
export const ONTOLOGY_MOBILE_SORT_OPTIONS: OntologySelectOption[] = [
  { value: '+vario_id', text: 'ID ascending' },
  { value: '-vario_id', text: 'ID descending' },
  { value: '+vario_name', text: 'Name ascending' },
  { value: '-vario_name', text: 'Name descending' },
  { value: '+update_date', text: 'Updated ascending' },
  { value: '-update_date', text: 'Updated descending' },
];

/** Column header map used by the client-side Excel export. */
export const ONTOLOGY_EXPORT_HEADERS: Record<string, string> = {
  vario_id: 'Vario ID',
  vario_name: 'Name',
  definition: 'Definition',
  obsolete: 'Obsolete',
  is_active: 'Active',
  sort: 'Sort Order',
  update_date: 'Last Updated',
};

export interface OntologyFilterField {
  content: string | string[] | null;
  join_char: string | null;
  operator: string;
}

export type OntologyFilter = Record<string, OntologyFilterField>;

/**
 * Single source of truth for the empty ontology-filter shape, used by both
 * the initial `filter` ref and `removeFilters()` so the two never drift.
 */
export function createEmptyOntologyFilter(): OntologyFilter {
  return {
    any: { content: null, join_char: null, operator: 'contains' },
    vario_id: { content: null, join_char: null, operator: 'contains' },
    vario_name: { content: null, join_char: null, operator: 'contains' },
    definition: { content: null, join_char: null, operator: 'contains' },
    obsolete: { content: null, join_char: null, operator: 'equals' },
    is_active: { content: null, join_char: null, operator: 'equals' },
  };
}
