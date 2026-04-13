// composables/review/useReviewHelpers.ts
/**
 * Small, pure helpers for the Phase E.E5 `ApproveReview.vue` rewrite.
 * Extracted so the view stays under its 700 LoC cap and so E.E6's generic
 * `ApprovalTableView` can import the same helpers (PMID validation, the
 * phenotype/variation tree-shape transform).
 */

export interface TreeNode {
  id: string;
  label: string;
  children?: TreeNode[];
  [key: string]: unknown;
}

/**
 * Sanitize a PMID input ("PMID: 123456" -> "PMID:123456").
 * Returns the input untouched if it isn't a valid PMID-shaped string.
 */
export const sanitizePMID = (input: string): string => {
  if (!input) return '';
  const parts = input.split(':');
  if (parts.length !== 2 || !parts[0].trim().startsWith('PMID')) return input;
  return `${parts[0].trim()}:${parts[1].trim()}`;
};

/** Bootstrap-Vue-Next tag validator for PMID fields. */
export const tagValidatorPMID = (tag: string): boolean => {
  const clean = sanitizePMID(tag);
  const body = clean.replace('PMID:', '');
  return (
    !Number.isNaN(Number(body.replaceAll('PMID:', ''))) &&
    clean.includes('PMID:') &&
    body.length > 4 &&
    body.length < 9
  );
};

/**
 * Transform the phenotype/variation tree the API returns (which puts
 * "present: X" as the parent) into a shape where each modifier is a
 * selectable child: "X" → ["present: X", "uncertain: X", ...].
 */
export const transformModifierTree = (nodes: TreeNode[]): TreeNode[] => {
  if (!Array.isArray(nodes)) return [];
  return nodes.map((node) => {
    const phenotypeName = node.label.replace(/^present:\s*/, '');
    const ontologyCode = node.id.replace(/^\d+-/, '');
    return {
      id: `parent-${ontologyCode}`,
      label: phenotypeName,
      children: [
        { id: node.id, label: `present: ${phenotypeName}` },
        ...(node.children || []).map((child) => {
          const modifier = child.label.replace(/:\s*.*$/, '');
          return { id: child.id, label: `${modifier}: ${phenotypeName}` };
        }),
      ],
    };
  });
};

/** Shallow array equality for change-detection snapshots. */
export const arraysAreEqual = (a: string[], b: string[]): boolean =>
  a.length === b.length && a.every((v, i) => v === b[i]);

/** Table field defaults for the review approval table. */
export const reviewTableFields = [
  { key: 'entity_id', label: 'Entity', sortable: true, class: 'text-start' },
  { key: 'symbol', label: 'Gene', sortable: true, class: 'text-start' },
  { key: 'disease_ontology_name', label: 'Disease', sortable: true, class: 'text-start' },
  {
    key: 'hpo_mode_of_inheritance_term_name',
    label: 'Inheritance',
    sortable: true,
    class: 'text-start',
  },
  { key: 'synopsis', label: 'Clinical synopsis', sortable: true, class: 'text-start' },
  { key: 'comment', label: 'Comment', sortable: true, class: 'text-start' },
  { key: 'review_date', label: 'Review date', sortable: true, class: 'text-start' },
  { key: 'review_user_name', label: 'User', sortable: true, class: 'text-start' },
  { key: 'actions', label: 'Actions', class: 'text-start' },
];

/** Legend-item rows shared across the review approval UI. */
export const reviewLegendItems = [
  { icon: 'bi bi-stoplights-fill', color: '#4caf50', label: 'Definitive' },
  { icon: 'bi bi-stoplights-fill', color: '#2196f3', label: 'Moderate' },
  { icon: 'bi bi-stoplights-fill', color: '#ff9800', label: 'Limited' },
  { icon: 'bi bi-stoplights-fill', color: '#f44336', label: 'Refuted' },
  { icon: 'bi bi-exclamation-triangle-fill', color: '#dc3545', label: 'Status change pending' },
  { icon: 'bi bi-exclamation-triangle-fill', color: '#ffc107', label: 'Multiple pending reviews' },
  { icon: 'bi bi-eye', color: '#0d6efd', label: 'Toggle details' },
  { icon: 'bi bi-pen', color: '#6c757d', label: 'Edit review' },
  { icon: 'bi bi-check2-circle', color: '#dc3545', label: 'Approve review' },
  { icon: 'bi bi-x-circle', color: '#dc3545', label: 'Dismiss review' },
];
