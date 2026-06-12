// Static table/display configuration for ManageReReview.vue.
// Extracted verbatim (#346 WP5) to keep the view thinner. These are read-only
// display constants (never mutated at runtime), so the view references them
// directly as the initial value of the corresponding data() fields.

export interface ReReviewTableField {
  key: string;
  label: string;
  sortable?: boolean;
  sortDirection?: string;
  class?: string;
  thStyle?: Record<string, string>;
}

export interface ReReviewLegendItem {
  icon: string;
  color: string;
  label: string;
}

/** Column definitions for the main re-review management table. */
export const reReviewTableFields: ReReviewTableField[] = [
  {
    key: 'user_name',
    label: 'User',
    sortable: true,
    sortDirection: 'desc',
    class: 'text-start',
    thStyle: { width: '140px' },
  },
  {
    key: 're_review_batch',
    label: 'Batch',
    sortable: true,
    class: 'text-center',
    thStyle: { width: '80px' },
  },
  {
    key: 're_review_review_saved',
    label: 'Saved',
    sortable: true,
    class: 'text-center',
    thStyle: { width: '70px' },
  },
  {
    key: 're_review_status_saved',
    label: 'Status',
    sortable: true,
    class: 'text-center',
    thStyle: { width: '70px' },
  },
  {
    key: 're_review_submitted',
    label: 'Submitted',
    sortable: true,
    class: 'text-center',
    thStyle: { width: '85px' },
  },
  {
    key: 're_review_approved',
    label: 'Approved',
    sortable: true,
    class: 'text-center',
    thStyle: { width: '85px' },
  },
  {
    key: 'entity_count',
    label: 'Total',
    sortable: true,
    class: 'text-center',
    thStyle: { width: '70px' },
  },
  {
    key: 'actions',
    label: 'Actions',
    class: 'text-center',
    thStyle: { width: '100px' },
  },
];

/** Column definitions for the gene-specific entity selection table. */
export const reReviewEntitySelectFields: ReReviewTableField[] = [
  { key: 'selected', label: '', thStyle: { width: '44px' } },
  { key: 'entity_id', label: 'ID', sortable: true },
  { key: 'gene_symbol', label: 'Gene', sortable: true },
  { key: 'disease_ontology_name', label: 'Disease', sortable: true },
  { key: 'review_date', label: 'Last Review', sortable: true },
  { key: 'status_name', label: 'Status', sortable: true },
];

/** Icon legend shown alongside the re-review management table. */
export const reReviewLegendItems: ReReviewLegendItem[] = [
  { icon: 'bi bi-person-fill', color: '#0d6efd', label: 'Assigned user' },
  { icon: 'bi bi-person', color: '#6c757d', label: 'Unassigned batch' },
  { icon: 'bi bi-calculator', color: '#6c757d', label: 'Recalculate batch' },
  { icon: 'bi bi-person-lines-fill', color: '#b45309', label: 'Reassign batch' },
  { icon: 'bi bi-person-dash-fill', color: '#dc3545', label: 'Unassign batch' },
];
