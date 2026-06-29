import { describe, it, expect } from 'vitest';
import { useColumnTooltip } from './useColumnTooltip';

describe('useColumnTooltip', () => {
  const { getTooltipText, getCompactTooltipText } = useColumnTooltip();

  describe('getTooltipText (standard faceted format)', () => {
    it('formats filtered/total counts', () => {
      expect(
        getTooltipText({ key: 'symbol', label: 'Symbol', count: 4978, count_filtered: 1829 })
      ).toBe('Symbol (unique filtered/total values: 1829/4978)');
    });

    it('falls back to the key when no label is present', () => {
      expect(getTooltipText({ key: 'symbol', count: 5, count_filtered: 5 })).toBe(
        'symbol (unique filtered/total values: 5/5)'
      );
    });

    it('coalesces missing counts to zero', () => {
      expect(getTooltipText({ key: 'details', label: 'Details' })).toBe(
        'Details (unique filtered/total values: 0/0)'
      );
    });
  });

  describe('getCompactTooltipText (guarded analysis format)', () => {
    it('appends compact counts when a filtered count is present', () => {
      expect(
        getCompactTooltipText({
          key: 'publication_count',
          label: 'Publication count',
          count: 10,
          count_filtered: 2,
        })
      ).toBe('Publication count (unique/total: 2/10)');
    });

    it('returns the bare label when there is no filtered count (no meaningless 0/0)', () => {
      expect(getCompactTooltipText({ key: 'enrichment_ratio', label: 'Enrichment ratio' })).toBe(
        'Enrichment ratio'
      );
      expect(
        getCompactTooltipText({ key: 'npmi', label: 'NPMI', count: 0, count_filtered: 0 })
      ).toBe('NPMI');
    });
  });
});
