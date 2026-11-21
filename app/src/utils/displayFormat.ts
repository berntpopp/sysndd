// utils/displayFormat.ts
// Shared display helpers so missing values and counts read the same app-wide.

const MISSING = '—';

/** True for null, undefined, NaN, blank strings and the R markers "NA"/"NaN". */
export function isMissing(value: unknown): boolean {
  if (value == null) return true;
  if (typeof value === 'number') return Number.isNaN(value);
  if (typeof value === 'string') {
    const s = value.trim();
    return s === '' || s === 'NA' || s === 'NaN';
  }
  return false;
}

/** The value as text, or "—" when missing. */
export function displayValue(value: unknown): string {
  return isMissing(value) ? MISSING : String(value);
}

/** 4200 -> "4,200"; "—" when missing. */
export function formatCount(value: number | null | undefined): string {
  return value == null || Number.isNaN(value) ? MISSING : value.toLocaleString('en-US');
}

/** "Showing 1–10 of 4,200", or "No results" for an empty set. */
export function formatShowingRange(first: number, last: number, total: number): string {
  if (!total) return 'No results';
  return `Showing ${formatCount(first)}–${formatCount(last)} of ${formatCount(total)}`;
}
