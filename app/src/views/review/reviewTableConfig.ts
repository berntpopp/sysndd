import { categoryLegendItems } from '@/composables/approval/useStatusHelpers';

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
    label: 'Reviewed',
    sortable: true,
    filterable: true,
    class: 'text-start',
  },
  {
    key: 'review_user_name',
    label: 'Last reviewed by',
    sortable: true,
    filterable: true,
    class: 'text-start',
  },
  // Four 30 px buttons plus gaps; narrower and the flag button wrapped to a second line.
  {
    key: 'actions',
    label: 'Actions',
    class: 'text-center text-nowrap',
    thStyle: { width: '10.5rem' },
  },
]);

export const LEGEND_ITEMS = Object.freeze([
  ...categoryLegendItems,
  { icon: 'bi bi-pencil-square', color: '#0d6efd', label: 'Edit review' },
  { icon: 'bi bi-stoplights', color: '#6c757d', label: 'Edit status' },
  { icon: 'bi bi-send-check', color: '#198754', label: 'Submit re-review' },
  { icon: 'bi bi-flag', color: '#b45309', label: 'Refuse (needs specialist)' },
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
