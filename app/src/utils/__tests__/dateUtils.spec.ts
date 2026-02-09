// utils/__tests__/dateUtils.spec.ts

import { describe, it, expect } from 'vitest';
import { inclusiveDayCount, previousPeriod } from '../dateUtils';

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
