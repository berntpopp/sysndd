// src/components/analyses/publicationsTableFormatters.ts
//
// Pure presentation/formatting helpers for the SysNDD curated publications
// table (PublicationsNDDTable.vue). Extracted so the component stays a thin
// shell and the formatting logic is independently unit-testable.

/** Minimal field shape used by the publications table fspec merge. */
export interface PublicationTableField {
  key: string;
  label?: string;
  class?: string;
  sortable?: boolean;
  [extra: string]: unknown;
}

/**
 * Construct a PubMed URL from a publication ID.
 *
 * Accepts formats like "PMID:12345678" or a bare "12345678".
 *
 * @param pubId - Publication ID
 * @returns PubMed article URL
 */
export function getPubMedUrl(pubId: string | null | undefined): string {
  // Extract numeric ID from formats like "PMID:12345678" or just "12345678"
  const numericId = pubId?.replace(/^PMID:/i, '') || pubId;
  return `https://pubmed.ncbi.nlm.nih.gov/${numericId}`;
}

/**
 * Format a date string for display (e.g. "Jan 15, 2024").
 *
 * Falls back to the raw input if it cannot be parsed.
 *
 * @param dateStr - Date string (e.g. "2024-01-15")
 * @returns Formatted date, or '' when no input
 */
export function formatDate(dateStr: string | null | undefined): string {
  if (!dateStr) return '';
  try {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  } catch {
    return dateStr;
  }
}

/**
 * Combine semicolon-separated last names and first names into a readable
 * author list (e.g. "Doe Jane, Smith John").
 *
 * @param lastNames - Semicolon-separated last names
 * @param firstNames - Semicolon-separated first names
 * @returns Formatted author list, or '' when no last names
 */
export function formatAuthors(
  lastNames: string | null | undefined,
  firstNames: string | null | undefined
): string {
  if (!lastNames) return '';
  const lasts = lastNames.split(';').map((s) => s.trim());
  const firsts = firstNames ? firstNames.split(';').map((s) => s.trim()) : [];
  return lasts
    .map((last, i) => {
      const first = firsts[i] || '';
      return first ? `${last} ${first}` : last;
    })
    .join(', ');
}

/**
 * Split a semicolon-separated keyword string into a trimmed, non-empty array.
 *
 * @param keywords - Semicolon-separated keywords
 * @returns Array of keyword strings
 */
export function parseKeywords(keywords: string | null | undefined): string[] {
  if (!keywords) return [];
  return keywords
    .split(';')
    .map((k) => k.trim())
    .filter((k) => k.length > 0);
}

/**
 * Filter and order the inbound fspec from the backend for the main table view.
 *
 * Only the visible columns are kept (in order), short labels are applied, and a
 * non-sortable "details" column is appended for row expansion.
 *
 * @param inboundFields - fspec field definitions from the API
 * @returns Ordered list of visible table fields
 */
export function mergePublicationFields(
  inboundFields: PublicationTableField[]
): PublicationTableField[] {
  // Fields we want to show as columns (in order)
  const visibleColumnKeys = ['publication_id', 'Title', 'Publication_date', 'Journal'];
  // Short labels for cleaner display
  const shortLabels: Record<string, string> = {
    publication_id: 'PMID',
    Publication_date: 'Date',
  };

  // Build merged array in the correct order
  const merged = visibleColumnKeys
    .map((key) => {
      const apiField = inboundFields.find((f) => f.key === key);
      if (!apiField) return null;
      return {
        ...apiField,
        label: shortLabels[key] || apiField.label,
        class: 'text-start',
      } as PublicationTableField;
    })
    .filter((f): f is PublicationTableField => Boolean(f));

  // Always add details column at the end
  merged.push({
    key: 'details',
    label: 'Details',
    class: 'text-center',
    sortable: false,
  });

  return merged;
}
