import { describe, expect, it, vi } from 'vitest';

import {
  formatAbsoluteLogTime,
  formatLogDuration,
  formatRelativeLogTime,
  getLogDurationClass,
  getLogMethodVariant,
  getLogStatusVariant,
  parseLogTime,
} from './logTableFormatters';

describe('logTableFormatters', () => {
  it('reads durations as the seconds the API logs (ADM-03)', () => {
    expect(formatLogDuration(null)).toBe('—');
    expect(formatLogDuration(0.039)).toBe('39 ms');
    expect(formatLogDuration('0.0004')).toBe('<1 ms');
    expect(formatLogDuration(1.52)).toBe('1.52 s');

    expect(getLogDurationClass(0.04)).toBe('text-success');
    expect(getLogDurationClass(0.25)).toBe('text-warning-emphasis'); // amber text is 1.6:1 on white
    expect(getLogDurationClass(0.8)).toBe('text-danger fw-bold');
  });

  it('parses naive API timestamps as UTC (ADM-06)', () => {
    vi.setSystemTime(new Date('2026-11-21T13:20:00Z'));

    expect(parseLogTime('2026-11-21 13:19:00')?.toISOString()).toBe('2026-11-21T13:19:00.000Z');
    expect(formatRelativeLogTime('2026-11-21 13:19:00')).toBe('1 minute ago');
    expect(formatAbsoluteLogTime('2026-11-21 13:19:00')).toBe('Nov 21, 2026, 13:19:00 UTC');
    expect(parseLogTime('NA')).toBeNull();

    vi.useRealTimers();
  });

  it('maps status codes and methods to Bootstrap variants', () => {
    expect(getLogStatusVariant(204)).toBe('success');
    expect(getLogStatusVariant(404)).toBe('warning');
    expect(getLogStatusVariant(503)).toBe('danger');
    expect(getLogStatusVariant(101)).toBe('secondary');

    expect(getLogMethodVariant('GET')).toBe('success');
    expect(getLogMethodVariant('POST')).toBe('primary');
    expect(getLogMethodVariant('DELETE')).toBe('danger');
    expect(getLogMethodVariant('PATCH')).toBe('secondary');
  });

  it('formats relative and absolute timestamps deterministically', () => {
    vi.setSystemTime(new Date('2026-05-19T12:00:00Z'));

    expect(formatRelativeLogTime('2026-05-19T11:30:00Z')).toBe('30 minutes ago');
    expect(formatAbsoluteLogTime('2026-05-19T11:30:00Z')).toContain('May');
    expect(formatAbsoluteLogTime(null)).toBe('');

    vi.useRealTimers();
  });
});
