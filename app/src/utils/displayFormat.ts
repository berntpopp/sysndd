// utils/displayFormat.ts
// Shared display helpers so missing values and counts read the same app-wide.

const MISSING = '—';

/** R/Plumber scalars can arrive as one-element arrays; unwrap them. */
export function scalar(value: unknown): unknown {
  return Array.isArray(value) && value.length === 1 ? value[0] : value;
}

/** True for null, undefined, NaN, blank strings and the R markers "NA"/"NaN". */
export function isMissing(input: unknown): boolean {
  const value = scalar(input);
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
  return isMissing(value) ? MISSING : String(scalar(value));
}

/** 4200 or "4200" -> "4,200"; "—" when missing or not a number. */
export function formatCount(value: unknown): string {
  const n = Number(scalar(value));
  return isMissing(value) || !Number.isFinite(n) ? MISSING : n.toLocaleString('en-US');
}

/** "Showing 1–10 of 4,200", or "No results" for an empty set. */
export function formatShowingRange(first: number, last: number, total: number): string {
  if (!total || last < first) return 'No results';
  return `Showing ${formatCount(first)}–${formatCount(last)} of ${formatCount(total)}`;
}
