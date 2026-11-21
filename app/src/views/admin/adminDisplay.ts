// Display helpers for the Administrator pages. Dates, durations, counts and
// missing values come from the shared app-wide helpers.

import { onScopeDispose, ref, watch, type Ref } from 'vue';
import { displayValue } from '@/utils/displayFormat';

export { displayValue, formatCount, isMissing } from '@/utils/displayFormat';
export { formatDateTime, formatDuration, formatLongDate, parseApiDate } from '@/utils/dateUtils';

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
