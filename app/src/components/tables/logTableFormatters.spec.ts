import { describe, expect, it, vi } from 'vitest';

import {
  formatAbsoluteLogTime,
  formatLogDuration,
  formatRelativeLogTime,
  getLogDurationClass,
  getLogMethodVariant,
  getLogStatusVariant,
} from './logTableFormatters';

describe('logTableFormatters', () => {
  it('formats duration values and performance classes', () => {
    expect(formatLogDuration(null)).toBe('-');
    expect(formatLogDuration(0.4)).toBe('<1ms');
    expect(formatLogDuration(42.2)).toBe('42ms');
    expect(formatLogDuration(1520)).toBe('1.52s');

    expect(getLogDurationClass(40)).toBe('text-success');
    expect(getLogDurationClass(250)).toBe('text-warning');
    expect(getLogDurationClass(800)).toBe('text-danger fw-bold');
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
