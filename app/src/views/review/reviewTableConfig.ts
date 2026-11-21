// Static configuration of the re-review queue table (moved out of Review.vue).

export const TABLE_FIELDS = Object.freeze([
  { key: 'entity_id', label: 'Entity', sortable: true, sortDirection: 'desc', class: 'text-start' },
  {
    key: 'symbol',
    label: 'Gene',
    sortable: true,
    filterable: true,
    sortDirection: 'desc',
    class: 'text-start',
  },
  {
    key: 'disease_ontology_name',
    label: 'Disease',
    sortable: true,
    class: 'text-start',
    sortByFormatted: true,
    filterByFormatted: true,
  },
  {
    key: 'hpo_mode_of_inheritance_term_name',
    label: 'Inheritance',
    sortable: true,
    class: 'text-start',
    sortByFormatted: true,
    filterByFormatted: true,
  },
  { key: 'category', label: 'Category', sortable: true, class: 'text-center' },
  { key: 'ndd_phenotype_word', label: 'NDD', sortable: true, class: 'text-center' },
  {
    key: 'review_date',
    label: 'Review date',
    sortable: true,
    filterable: true,
    class: 'text-start',
  },
  { key: 'review_user_name', label: 'User', sortable: true, filterable: true, class: 'text-start' },
  { key: 'actions', label: 'Actions', class: 'text-center' },
]);

export const LEGEND_ITEMS = Object.freeze([
  { icon: 'bi bi-stoplights-fill', color: '#4caf50', label: 'Definitive' },
  { icon: 'bi bi-stoplights-fill', color: '#2196f3', label: 'Moderate' },
  { icon: 'bi bi-stoplights-fill', color: '#ff9800', label: 'Limited' },
  { icon: 'bi bi-stoplights-fill', color: '#f44336', label: 'Refuted' },
  { icon: 'bi bi-check-circle-fill', color: '#198754', label: 'Re-review approved' },
  { icon: 'bi bi-hourglass-split', color: '#ffc107', label: 'Pending re-review' },
]);

export const EMPTY_USER = Object.freeze({
  user_id: [],
  user_name: [],
  email: [],
  user_role: [],
  user_created: [],
  abbreviation: [],
  orcid: [],
  exp: [],
});
