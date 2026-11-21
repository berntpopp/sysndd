import { describe, it, expect } from 'vitest';
import { isMissing, displayValue, formatCount, formatShowingRange } from '../displayFormat';

describe('displayFormat', () => {
  it('treats R/JS missing markers as missing', () => {
    for (const v of [null, undefined, '', '  ', 'NA', 'NaN', Number.NaN]) {
      expect(isMissing(v)).toBe(true);
    }
    for (const v of [0, 'no', 'N/A text', 'NAME', false]) expect(isMissing(v)).toBe(false);
  });

  it('shows a dash for missing values and the value otherwise', () => {
    expect(displayValue('NA')).toBe('—');
    expect(displayValue(undefined)).toBe('—');
    expect(displayValue(0)).toBe('0');
    expect(displayValue('present')).toBe('present');
  });

  it('formats counts with a thousands separator', () => {
    expect(formatCount(4200)).toBe('4,200');
    expect(formatCount(12)).toBe('12');
    expect(formatCount(undefined)).toBe('—');
    expect(formatCount('1051')).toBe('1,051');
    expect(formatCount(['NA'])).toBe('—');
  });

  it('formats a showing range', () => {
    expect(formatShowingRange(1, 10, 4200)).toBe('Showing 1–10 of 4,200');
    expect(formatShowingRange(1, 5, 5)).toBe('Showing 1–5 of 5');
    expect(formatShowingRange(0, 0, 0)).toBe('No results');
    // A page past the last row (empty page, total still > 0) never reads "41–40".
    expect(formatShowingRange(41, 40, 30)).toBe('No results');
  });
});
