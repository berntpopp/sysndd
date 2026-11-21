import { describe, it, expect, vi, afterEach } from 'vitest';
import { nextTick, ref } from 'vue';
import {
  isMissing,
  displayValue,
  parseApiDate,
  formatLongDate,
  formatDateTime,
  formatDuration,
  formatCount,
  shortDigest,
  useDelayedFlag,
} from './adminDisplay';

describe('adminDisplay', () => {
  it('treats R missing values as missing', () => {
    for (const v of [null, undefined, '', 'NA', 'NaN', Number.NaN, ['NA']]) {
      expect(isMissing(v)).toBe(true);
    }
    for (const v of [0, 'NAME', 'x', false]) expect(isMissing(v)).toBe(false);
    expect(displayValue('NA')).toBe('—');
    expect(displayValue(['FBXO11'])).toBe('FBXO11');
  });

  it('parses naive API timestamps as UTC', () => {
    expect(parseApiDate('2026-11-21 13:19:00')?.toISOString()).toBe('2026-11-21T13:19:00.000Z');
    expect(parseApiDate('2026-09-01')?.toISOString()).toBe('2026-09-01T00:00:00.000Z');
    expect(parseApiDate('2026-11-21T12:12:53Z')?.toISOString()).toBe('2026-11-21T12:12:53.000Z');
    expect(parseApiDate('NA')).toBeNull();
    expect(parseApiDate('not a date')).toBeNull();
  });

  it('formats dates and timestamps in one style, in UTC', () => {
    expect(formatLongDate('2026-07-18 20:01:55')).toBe('July 18, 2026');
    expect(formatLongDate('2026-09-01')).toBe('September 1, 2026');
    expect(formatDateTime('2026-07-18 20:01:55')).toBe('July 18, 2026, 20:01 UTC');
    expect(formatDateTime(new Date('2026-05-17T19:31:47Z'))).toBe('May 17, 2026, 19:31 UTC');
    expect(formatDateTime('NA')).toBe('—');
    expect(formatLongDate(null)).toBe('—');
  });

  it('formats durations given in seconds', () => {
    expect(formatDuration(0.039)).toBe('39 ms');
    expect(formatDuration(2.44)).toBe('2.4 s');
    expect(formatDuration(160.048)).toBe('3 min');
    expect(formatDuration(null)).toBe('—');
  });

  it('formats counts with separators and shortens digests', () => {
    expect(formatCount(41372)).toBe('41,372');
    expect(formatCount('NA')).toBe('—');
    expect(shortDigest('a'.repeat(64))).toBe('aaaaaaaaaaaa…');
    expect(shortDigest('abc')).toBe('abc');
  });

  describe('useDelayedFlag', () => {
    afterEach(() => vi.useRealTimers());

    it('stays false for a short load and turns true after the delay', async () => {
      vi.useFakeTimers();
      const loading = ref(true);
      const shown = useDelayedFlag(loading, 300);
      vi.advanceTimersByTime(299);
      expect(shown.value).toBe(false);
      loading.value = false;
      await nextTick();
      vi.advanceTimersByTime(500);
      expect(shown.value).toBe(false);

      loading.value = true;
      await nextTick();
      vi.advanceTimersByTime(300);
      expect(shown.value).toBe(true);
      // A load ending 20 ms after the spinner appeared keeps it up for 400 ms in total.
      vi.advanceTimersByTime(20);
      loading.value = false;
      await nextTick();
      expect(shown.value).toBe(true);
      vi.advanceTimersByTime(379);
      expect(shown.value).toBe(true);
      vi.advanceTimersByTime(1);
      expect(shown.value).toBe(false);
    });
  });
});
