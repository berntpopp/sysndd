// utils/__tests__/dateUtils.spec.ts

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import {
  inclusiveDayCount,
  previousPeriod,
  parseApiDate,
  formatLongDate,
  formatDateTime,
  formatDuration,
} from '../dateUtils';

describe('dateUtils', () => {
  describe('inclusiveDayCount', () => {
    it('Jan 10 to Jan 20 is 11 days', () => {
      expect(inclusiveDayCount('2026-01-10', '2026-01-20')).toBe(11);
    });

    it('same day is 1 day', () => {
      expect(inclusiveDayCount('2026-01-15', '2026-01-15')).toBe(1);
    });

    it('accepts Date objects', () => {
      expect(inclusiveDayCount(new Date('2026-01-01'), new Date('2026-01-31'))).toBe(31);
    });

    it('handles reversed dates (absolute difference)', () => {
      expect(inclusiveDayCount('2026-01-20', '2026-01-10')).toBe(11);
    });

    it('calculates multi-month ranges correctly', () => {
      // Feb 1 to March 1 (2026 is not a leap year)
      expect(inclusiveDayCount('2026-02-01', '2026-03-01')).toBe(29);
    });
  });

  describe('previousPeriod', () => {
    it('11-day period produces equal-length previous period', () => {
      const result = previousPeriod('2026-01-10', '2026-01-20');
      // Previous period should also be 11 days
      expect(inclusiveDayCount(result.start, result.end)).toBe(11);
    });

    it('previous period ends the day before current starts', () => {
      const result = previousPeriod('2026-01-10', '2026-01-20');
      expect(result.end).toBe('2026-01-09');
    });

    it('11-day period starting Jan 10 has previous ending Jan 9', () => {
      const result = previousPeriod('2026-01-10', '2026-01-20');
      // 11 days ending Jan 9 means starting Dec 30
      expect(result.start).toBe('2025-12-30');
      expect(result.end).toBe('2026-01-09');
    });

    it('handles single-day periods', () => {
      const result = previousPeriod('2026-01-15', '2026-01-15');
      expect(inclusiveDayCount(result.start, result.end)).toBe(1);
      expect(result.end).toBe('2026-01-14');
      expect(result.start).toBe('2026-01-14');
    });

    it('accepts Date objects', () => {
      const result = previousPeriod(new Date('2026-01-10'), new Date('2026-01-20'));
      expect(result.end).toBe('2026-01-09');
      expect(inclusiveDayCount(result.start, result.end)).toBe(11);
    });
  });
});

describe('display date helpers', () => {
  // A non-UTC zone, so a parse that silently uses local time fails here and in UTC CI.
  const originalTz = process.env.TZ;
  beforeAll(() => {
    process.env.TZ = 'America/Los_Angeles';
  });
  afterAll(() => {
    process.env.TZ = originalTz;
  });

  it('parses a naive API timestamp as UTC', () => {
    expect(parseApiDate('2026-07-18 20:01:00')?.toISOString()).toBe('2026-07-18T20:01:00.000Z');
    expect(parseApiDate('2026-07-18')?.toISOString()).toBe('2026-07-18T00:00:00.000Z');
    expect(parseApiDate('2026-07-18T20:01:00+02:00')?.toISOString()).toBe(
      '2026-07-18T18:01:00.000Z'
    );
  });

  it('returns null for missing or unparseable values', () => {
    for (const v of [null, undefined, '', 'NA', 'not a date']) expect(parseApiDate(v)).toBeNull();
  });

  it('formats a long en-US date in UTC', () => {
    expect(formatLongDate('2026-07-18')).toBe('July 18, 2026');
    // 23:30 UTC stays on the 18th regardless of the viewer's zone
    expect(formatLongDate('2026-07-18 23:30:00')).toBe('July 18, 2026');
    expect(formatLongDate(null)).toBe('—');
    expect(formatLongDate('NA')).toBe('—');
  });

  it('formats a 24-hour UTC timestamp', () => {
    expect(formatDateTime('2026-07-18 20:01:59')).toBe('July 18, 2026, 20:01 UTC');
    expect(formatDateTime('2026-07-18 00:05:00')).toBe('July 18, 2026, 00:05 UTC');
    expect(formatDateTime(undefined)).toBe('—');
  });

  it('formats durations in the largest sensible unit', () => {
    expect(formatDuration(0.039)).toBe('39 ms');
    expect(formatDuration(2.4)).toBe('2.4 s');
    expect(formatDuration(180)).toBe('3 min');
    expect(formatDuration(null)).toBe('—');
    expect(formatDuration(Number.NaN)).toBe('—');
  });
});
