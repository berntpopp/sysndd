import { describe, expect, it } from 'vitest';
import { normalizeSelectOptions } from '../selectOptions';

describe('normalizeSelectOptions', () => {
  it('returns [] for null, undefined, and non-array input', () => {
    expect(normalizeSelectOptions(null)).toEqual([]);
    expect(normalizeSelectOptions(undefined)).toEqual([]);
    expect(normalizeSelectOptions('GET')).toEqual([]);
  });

  it('maps id/label objects to value/text', () => {
    expect(normalizeSelectOptions([{ id: 'GET', label: 'GET requests' }])).toEqual([
      { value: 'GET', text: 'GET requests' },
    ]);
  });

  it('keeps value/text objects and falls back text to id', () => {
    expect(normalizeSelectOptions([{ value: '200', text: '200 OK' }])).toEqual([
      { value: '200', text: '200 OK' },
    ]);
    expect(normalizeSelectOptions([{ id: 404 }])).toEqual([{ value: 404, text: 404 }]);
  });

  it('wraps primitives as identical value/text pairs', () => {
    expect(normalizeSelectOptions(['GET', 7])).toEqual([
      { value: 'GET', text: 'GET' },
      { value: 7, text: 7 },
    ]);
  });
});
