// composables/approval/useStatusHelpers.ts
/**
 * Status-specific helpers for Phase E.E6 `ApprovalTableView.vue`.
 *
 * Mirrors the shape of `@/composables/review/useReviewHelpers` — but for the
 * status-approval stream. Centralises:
 *   - the BTable field list,
 *   - the legend rows,
 *   - the `problematic_text` tooltip lookup.
 *
 * Kept shape-only (no reactive state) so both `ApprovalTableView.vue` and
 * `ApproveStatus.vue` can import it at module load.
 */

// `TableField` is intentionally not imported: BTable accepts
// `filterable`, `sortDirection`, `sortByFormatted`, `filterByFormatted`
// as extra keys, which aren't in the narrow shared interface. Keeping
// the inferred tuple type matches how `reviewTableFields` is declared
// in `@/composables/review/useReviewHelpers` (E5).

/** Table field defaults for the status approval table. */
export const statusTableFields = [
  {
    key: 'entity_id',
    label: 'Entity',
    sortable: true,
    filterable: true,
    sortDirection: 'desc',
    class: 'text-start',
  },
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
  {
    key: 'category',
    label: 'Category',
    sortable: true,
    filterable: true,
    class: 'text-start',
  },
  {
    key: 'comment',
    label: 'Comment',
    sortable: true,
    filterable: true,
    class: 'text-start',
  },
  {
    key: 'problematic',
    label: 'Problematic',
    sortable: true,
    filterable: true,
    class: 'text-start',
  },
  {
    key: 'status_date',
    label: 'Status date',
    sortable: true,
    filterable: true,
    class: 'text-start',
  },
  {
    key: 'status_user_name',
    label: 'User',
    sortable: true,
    filterable: true,
    class: 'text-start',
  },
  {
    key: 'actions',
    label: 'Actions',
    class: 'text-start',
  },
];

/** Legend-item rows shared across the status approval UI. */
export const statusLegendItems = [
  { icon: 'bi bi-stoplights-fill', color: '#4caf50', label: 'Definitive' },
  { icon: 'bi bi-stoplights-fill', color: '#2196f3', label: 'Moderate' },
  { icon: 'bi bi-stoplights-fill', color: '#ff9800', label: 'Limited' },
  { icon: 'bi bi-stoplights-fill', color: '#f44336', label: 'Refuted' },
  { icon: 'bi bi-check-circle-fill', color: '#198754', label: 'No problems' },
  { icon: 'bi bi-exclamation-triangle-fill', color: '#dc3545', label: 'Problematic' },
  {
    icon: 'bi bi-exclamation-triangle-fill',
    color: '#ffc107',
    label: 'Review change pending',
  },
  {
    icon: 'bi bi-exclamation-triangle-fill',
    color: '#ffc107',
    label: 'Multiple pending statuses',
  },
  { icon: 'bi bi-eye', color: '#0d6efd', label: 'Toggle details' },
  { icon: 'bi bi-pen', color: '#6c757d', label: 'Edit status' },
  { icon: 'bi bi-check2-circle', color: '#dc3545', label: 'Approve status' },
  { icon: 'bi bi-x-circle', color: '#dc3545', label: 'Dismiss status' },
];

/** Tooltip text for the problematic cell. */
export const problematicText: Record<number | string, string> = {
  0: 'No problems',
  1: 'Entity status marked problematic',
};
