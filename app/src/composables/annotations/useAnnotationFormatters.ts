// composables/annotations/useAnnotationFormatters.ts
/**
 * Shared formatting helpers for the Manage Annotations view and its
 * sub-cards (Phase E.E4). Stateless — safe to import into multiple
 * components without coupling them.
 */

export type UnwrappableScalar<T> = T | T[];

/**
 * R/Plumber serialises scalar fields as single-element arrays.  Unwrap
 * them back to scalars for display.
 */
export function unwrapValue<T>(val: UnwrappableScalar<T>): T {
  return Array.isArray(val) && val.length === 1 ? val[0] : (val as T);
}

/**
 * Format a date-ish string as the user's locale date.  Falls back to
 * the raw string when it cannot be parsed.
 */
export function formatDate(dateString: string | null | undefined): string {
  if (!dateString) return '';
  const date = new Date(dateString);
  if (Number.isNaN(date.getTime())) return String(dateString);
  return date.toLocaleDateString();
}

/**
 * Format a datetime-ish string as the user's locale date + time.
 */
export function formatDateTime(dateString: string | null | undefined): string {
  if (!dateString) return '';
  const date = new Date(dateString);
  if (Number.isNaN(date.getTime())) return String(dateString);
  return date.toLocaleString();
}

/**
 * Format a duration in seconds as "Xm Ys" or "Ys".
 */
export function formatDuration(seconds: number | null | undefined): string {
  if (seconds === null || seconds === undefined) return '—';
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  if (mins > 0) {
    return `${mins}m ${secs}s`;
  }
  return `${secs}s`;
}

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
