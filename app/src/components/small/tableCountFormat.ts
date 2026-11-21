// Count wording shared by the table headers and the pager.
// ponytail: mirrors formatCount/formatShowingRange planned for utils/displayFormat.ts
// (ui-quality F0); switch the imports there once that file lands.

const COUNT_FORMAT = new Intl.NumberFormat('en-US');

/** "4200" -> "4,200"; a missing or non-numeric count reads "—". */
export function formatCount(value: number | string | null | undefined): string {
  const n = typeof value === 'string' ? Number(value) : value;
  return typeof n === 'number' && Number.isFinite(n) ? COUNT_FORMAT.format(n) : '—';
}

/** "Showing 11–20 of 4,200" for the rows on screen; "No results" when there are none. */
export function formatShowingRange(first: number, last: number, total: number): string {
  if (!total || last < first) return 'No results';
  return `Showing ${formatCount(first)}–${formatCount(last)} of ${formatCount(total)}`;
}

/** Range for page `page` (1-based) of `perPage` rows when `shown` rows are on screen. */
export function formatPageRange(page: number, perPage: number, shown: number, total: number) {
  const first = (Math.max(page || 1, 1) - 1) * perPage + 1;
  return formatShowingRange(first, first + shown - 1, total);
}
