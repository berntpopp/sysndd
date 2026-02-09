// utils/dateUtils.ts

/**
 * Date calculation utilities for AdminStatistics
 *
 * Provides inclusive day counting and previous period calculation
 * for accurate KPI trend comparison.
 */

const MS_PER_DAY = 1000 * 60 * 60 * 24;

/**
 * Count days inclusively between two dates.
 * "Jan 10 to Jan 20" = 11 days (both endpoints included).
 *
 * @param start - Start date (Date object or ISO string)
 * @param end - End date (Date object or ISO string)
 * @returns Number of days (inclusive)
 *
 * @example
 * inclusiveDayCount('2026-01-10', '2026-01-20') // Returns 11
 * inclusiveDayCount('2026-01-15', '2026-01-15') // Returns 1
 */
export function inclusiveDayCount(start: Date | string, end: Date | string): number {
  const s = typeof start === 'string' ? new Date(start) : start;
  const e = typeof end === 'string' ? new Date(end) : end;
  return Math.round(Math.abs(e.getTime() - s.getTime()) / MS_PER_DAY) + 1;
}

/**
 * Compute the previous period of equal length for comparison.
 * Given [start, end] with N inclusive days, returns [prevStart, prevEnd]
 * where prevEnd = start - 1 day, prevStart = prevEnd - (N - 1) days.
 *
 * @param start - Current period start date
 * @param end - Current period end date
 * @returns Object with start and end dates (ISO strings) for previous period
 *
 * @example
 * // For Jan 10-20 (11 days), returns Dec 30 - Jan 9 (11 days)
 * previousPeriod('2026-01-10', '2026-01-20')
 * // Returns: { start: '2025-12-30', end: '2026-01-09' }
 */
export function previousPeriod(
  start: Date | string,
  end: Date | string
): { start: string; end: string } {
  const s = typeof start === 'string' ? new Date(start) : start;
  const e = typeof end === 'string' ? new Date(end) : end;
  const dayCount = inclusiveDayCount(s, e);

  const prevEnd = new Date(s);
  prevEnd.setDate(prevEnd.getDate() - 1);

  const prevStart = new Date(prevEnd);
  prevStart.setDate(prevStart.getDate() - (dayCount - 1));

  return {
    start: prevStart.toISOString().split('T')[0],
    end: prevEnd.toISOString().split('T')[0],
  };
}
