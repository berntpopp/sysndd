import { describe, expect, it } from 'vitest';
import { formatCount, formatPageRange, formatShowingRange } from './tableCountFormat';

describe('tableCountFormat', () => {
  it('adds thousands separators and reads missing counts as a dash', () => {
    expect(formatCount(4200)).toBe('4,200');
    expect(formatCount('1051')).toBe('1,051');
    expect(formatCount(null)).toBe('—');
    expect(formatCount('NA')).toBe('—');
  });

  it('describes the rows on screen, not the page size', () => {
    expect(formatShowingRange(1, 10, 4200)).toBe('Showing 1–10 of 4,200');
    expect(formatPageRange(1, 10, 4, 4)).toBe('Showing 1–4 of 4');
    expect(formatPageRange(3, 25, 25, 1051)).toBe('Showing 51–75 of 1,051');
    expect(formatPageRange(1, 10, 0, 0)).toBe('No results');
  });
});
