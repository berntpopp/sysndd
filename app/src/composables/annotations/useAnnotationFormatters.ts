// composables/annotations/useAnnotationFormatters.ts
/**
 * Shared formatting helpers for the Manage Annotations view and its
 * sub-cards (Phase E.E4). Stateless — safe to import into multiple
 * components without coupling them.
 */

import { formatDateTime, formatDuration, formatLongDate } from '@/views/admin/adminDisplay';

export type UnwrappableScalar<T> = T | T[];

/**
 * R/Plumber serialises scalar fields as single-element arrays.  Unwrap
 * them back to scalars for display; R's missing values ("NA", "NaN") from
 * the `na="string"` serializer become `null`.
 */
export function unwrapValue<T>(val: UnwrappableScalar<T>): T {
  const v = Array.isArray(val) && val.length === 1 ? val[0] : (val as T);
  return (v === 'NA' || v === 'NaN' ? null : v) as T;
}

/** Shared admin date/duration styles ("July 18, 2026", "39 ms"); "—" when missing. */
export const formatDate = formatLongDate;
export { formatDateTime, formatDuration };

/**
 * Human-readable label for a job operation identifier.
 */
export function formatOperationType(operation: string): string {
  const labels: Record<string, string> = {
    clustering: 'Clustering',
    phenotype_clustering: 'Phenotype Clustering',
    ontology_update: 'Ontology Update',
    omim_update: 'Ontology Update',
    force_apply_ontology: 'Force Apply Ontology',
    hgnc_update: 'HGNC Update',
    pubtator_update: 'Pubtator Update',
    publication_refresh: 'Publication Refresh',
    comparisons_update: 'Comparisons Update',
  };
  return labels[operation] || operation;
}

/**
 * Bootstrap badge class for a job status string.
 */
export function getStatusBadgeClass(status: string): string {
  const classes: Record<string, string> = {
    completed: 'bg-success',
    failed: 'bg-danger',
    running: 'bg-primary',
    pending: 'bg-info',
  };
  return classes[status] || 'bg-secondary';
}

/**
 * Bootstrap badge class for an NDD category.
 */
export function categoryBadgeClass(category: string): string {
  const classes: Record<string, string> = {
    Definitive: 'bg-success',
    Moderate: 'bg-info',
    Limited: 'bg-warning text-dark',
    Refuted: 'bg-danger',
  };
  return classes[category] || 'bg-secondary';
}

/**
 * Truncate a string to `maxLength` characters, adding an ellipsis when
 * it was cut.  Safe to call with null/empty.
 */
export function truncateText(text: string | null | undefined, maxLength: number): string {
  if (!text || text.length <= maxLength) return text || '';
  return `${text.substring(0, maxLength)}...`;
}

/**
 * Shorten a job "step" description for display inside a progress bar.
 */
export function shortStepLabel(step: string | null | undefined): string {
  const value = step || '';
  if (!value) return 'Initializing...';
  if (value.length > 40) {
    return `${value.substring(0, 37)}...`;
  }
  return value;
}

/**
 * Build the axios config used by every authenticated call on the Manage
 * Annotations view.
 *
 * v11.0 closeout F2a: the inline Authorization header that used to be
 * populated here has been removed. The `apiClient` request interceptor
 * (`@/api/client`) now reads `useAuth().token.value` and injects the
 * Bearer header on every outbound call against the shared axios
 * singleton, so call sites (in `useAnnotationsApi.ts` and elsewhere) no
 * longer need to supply one.
 *
 * The return type stays a `withCredentials: true` opt-in so existing
 * spread-into-config call sites keep compiling unchanged.
 */
export function authRequestConfig(): {
  withCredentials: true;
} {
  return {
    withCredentials: true,
  };
}
