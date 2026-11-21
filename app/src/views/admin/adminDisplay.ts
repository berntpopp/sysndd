// Display helpers shared by the Administrator pages: one date style, one
// duration style, and one rule for missing values ("—", never "NA"/"NaN").
//
// ponytail: these mirror the planned F0 helpers (`utils/dateUtils.ts` +
// `utils/displayFormat.ts`, owned by fix/ui-shell-pages) with the same names and
// output. Once F0 is on master, re-export from there and delete this file.

import { onScopeDispose, ref, watch, type Ref } from 'vue';

const DASH = '—';

/** R/Plumber scalars arrive as one-element arrays; missing ones as "NA"/"NaN". */
function scalar(value: unknown): unknown {
  return Array.isArray(value) && value.length === 1 ? value[0] : value;
}

export function isMissing(value: unknown): boolean {
  const v = scalar(value);
  return (
    v === null ||
    v === undefined ||
    v === '' ||
    v === 'NA' ||
    v === 'NaN' ||
    (typeof v === 'number' && Number.isNaN(v))
  );
}

export function displayValue(value: unknown): string {
  return isMissing(value) ? DASH : String(scalar(value));
}

/** Naive "YYYY-MM-DD[ HH:MM:SS]" from the API is UTC; ISO strings with a zone keep it. */
export function parseApiDate(value: unknown): Date | null {
  const v = scalar(value);
  if (v instanceof Date) return Number.isNaN(v.getTime()) ? null : v;
  if (isMissing(v) || typeof v !== 'string') return null;
  const naive = /^\d{4}-\d{2}-\d{2}([ T]\d{2}:\d{2}(:\d{2}(\.\d+)?)?)?$/.test(v);
  const iso = naive ? `${v.replace(' ', 'T')}${v.length === 10 ? 'T00:00:00' : ''}Z` : v;
  const parsed = new Date(iso);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

const LONG_DATE = new Intl.DateTimeFormat('en-US', {
  year: 'numeric',
  month: 'long',
  day: 'numeric',
  timeZone: 'UTC',
});
const TIME = new Intl.DateTimeFormat('en-GB', {
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
  timeZone: 'UTC',
});

/** "July 18, 2026" */
export function formatLongDate(value: unknown): string {
  const d = parseApiDate(value);
  return d ? LONG_DATE.format(d) : DASH;
}

/** "July 18, 2026, 20:01 UTC" */
export function formatDateTime(value: unknown): string {
  const d = parseApiDate(value);
  return d ? `${LONG_DATE.format(d)}, ${TIME.format(d)} UTC` : DASH;
}

/** Seconds to "39 ms", "2.4 s" or "3 min". */
export function formatDuration(seconds: unknown): string {
  const s = Number(scalar(seconds));
  if (isMissing(seconds) || !Number.isFinite(s)) return DASH;
  if (s < 1) return `${Math.round(s * 1000)} ms`;
  if (s < 60) return `${s.toFixed(1)} s`;
  return `${Math.round(s / 60)} min`;
}

export function formatCount(value: unknown): string {
  const n = Number(scalar(value));
  return isMissing(value) || !Number.isFinite(n) ? DASH : n.toLocaleString('en-US');
}

/** First 12 characters of a content digest; the full value belongs in a `title`. */
export function shortDigest(value: unknown, length = 12): string {
  const v = displayValue(value);
  return v.length > length ? `${v.slice(0, length)}…` : v;
}

/**
 * True only once `source` has stayed true for `delayMs`, so a fast load never
 * flashes a spinner; once shown, it stays for at least `minVisibleMs` so a load
 * that ends just after the delay does not flash one either.
 */
export function useDelayedFlag(
  source: Ref<boolean>,
  delayMs = 300,
  minVisibleMs = 400
): Ref<boolean> {
  const shown = ref(false);
  let timer: ReturnType<typeof setTimeout> | undefined;
  let shownAt = 0;
  watch(
    source,
    (on) => {
      clearTimeout(timer);
      if (on) {
        if (!shown.value) {
          timer = setTimeout(() => {
            shown.value = true;
            shownAt = Date.now();
          }, delayMs);
        }
        return;
      }
      const remaining = shown.value ? minVisibleMs - (Date.now() - shownAt) : 0;
      if (remaining > 0) timer = setTimeout(() => (shown.value = false), remaining);
      else shown.value = false;
    },
    { immediate: true }
  );
  onScopeDispose(() => clearTimeout(timer));
  return shown;
}
