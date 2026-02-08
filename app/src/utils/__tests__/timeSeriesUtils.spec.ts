import { describe, it, expect } from 'vitest';
import { mergeGroupedCumulativeSeries, extractPerGroupSeries } from '../timeSeriesUtils';
import type { GroupedTimeSeries } from '../timeSeriesUtils';

describe('mergeGroupedCumulativeSeries', () => {
  it('returns empty array for empty input', () => {
    const result = mergeGroupedCumulativeSeries([]);
    expect(result).toEqual([]);
  });

  it('returns empty array for groups with no values', () => {
    const groups: GroupedTimeSeries[] = [{ group: 'A', values: [] }];
    const result = mergeGroupedCumulativeSeries(groups);
    expect(result).toEqual([]);
  });

  it('handles single group with complete data', () => {
    const groups: GroupedTimeSeries[] = [
      {
        group: 'Definitive',
        values: [
          { entry_date: '2025-01-01', count: 10, cumulative_count: 10 },
          { entry_date: '2025-01-02', count: 5, cumulative_count: 15 },
          { entry_date: '2025-01-03', count: 3, cumulative_count: 18 },
        ],
      },
    ];

    const result = mergeGroupedCumulativeSeries(groups);

    expect(result).toHaveLength(3);
    expect(result[0]).toEqual({ date: '2025-01-01', count: 10 });
    expect(result[1]).toEqual({ date: '2025-01-02', count: 15 });
    expect(result[2]).toEqual({ date: '2025-01-03', count: 18 });
  });

  it('forward-fills missing dates within a group', () => {
    const groups: GroupedTimeSeries[] = [
      {
        group: 'A',
        values: [
          { entry_date: '2025-01-01', count: 1, cumulative_count: 5 },
          // Missing 2025-01-02
          { entry_date: '2025-01-03', count: 2, cumulative_count: 7 },
        ],
      },
      {
        group: 'B',
        values: [
          { entry_date: '2025-01-01', count: 2, cumulative_count: 2 },
          { entry_date: '2025-01-02', count: 3, cumulative_count: 5 },
          { entry_date: '2025-01-03', count: 1, cumulative_count: 6 },
        ],
      },
    ];

    const result = mergeGroupedCumulativeSeries(groups);

    expect(result).toHaveLength(3);
    expect(result[0]).toEqual({ date: '2025-01-01', count: 7 }); // 5 + 2
    expect(result[1]).toEqual({ date: '2025-01-02', count: 10 }); // 5 (forward-filled) + 5
    expect(result[2]).toEqual({ date: '2025-01-03', count: 13 }); // 7 + 6
  });

  it('produces monotonically non-decreasing totals', () => {
    const groups: GroupedTimeSeries[] = [
      {
        group: 'Definitive',
        values: [
          { entry_date: '2025-01-01', count: 10, cumulative_count: 10 },
          { entry_date: '2025-01-03', count: 5, cumulative_count: 15 },
        ],
      },
      {
        group: 'Moderate',
        values: [
          { entry_date: '2025-01-01', count: 3, cumulative_count: 3 },
          { entry_date: '2025-01-02', count: 2, cumulative_count: 5 },
        ],
      },
      {
        group: 'Limited',
        values: [
          { entry_date: '2025-01-02', count: 1, cumulative_count: 1 },
          { entry_date: '2025-01-03', count: 1, cumulative_count: 2 },
        ],
      },
    ];

    const result = mergeGroupedCumulativeSeries(groups);

    expect(result).toHaveLength(3);
    expect(result[0]).toEqual({ date: '2025-01-01', count: 13 }); // 10 + 3 + 0
    expect(result[1]).toEqual({ date: '2025-01-02', count: 16 }); // 10 + 5 + 1
    expect(result[2]).toEqual({ date: '2025-01-03', count: 22 }); // 15 + 5 + 2

    // Assert monotonically non-decreasing
    for (let i = 1; i < result.length; i++) {
      expect(result[i].count).toBeGreaterThanOrEqual(result[i - 1].count);
    }
  });

  it('handles null/undefined values array', () => {
    const groups: GroupedTimeSeries[] = [
      { group: 'A', values: undefined as any },
      { group: 'B', values: null as any },
    ];

    const result = mergeGroupedCumulativeSeries(groups);
    expect(result).toEqual([]);
  });

  it('correctly sums across multiple groups at same date', () => {
    const groups: GroupedTimeSeries[] = [
      {
        group: 'A',
        values: [{ entry_date: '2025-01-01', count: 10, cumulative_count: 10 }],
      },
      {
        group: 'B',
        values: [{ entry_date: '2025-01-01', count: 5, cumulative_count: 5 }],
      },
      {
        group: 'C',
        values: [{ entry_date: '2025-01-01', count: 3, cumulative_count: 3 }],
      },
    ];

    const result = mergeGroupedCumulativeSeries(groups);

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({ date: '2025-01-01', count: 18 }); // 10 + 5 + 3
  });

  it('dates are sorted chronologically', () => {
    const groups: GroupedTimeSeries[] = [
      {
        group: 'A',
        values: [
          { entry_date: '2025-01-03', count: 3, cumulative_count: 18 },
          { entry_date: '2025-01-01', count: 1, cumulative_count: 10 },
          { entry_date: '2025-01-02', count: 2, cumulative_count: 15 },
        ],
      },
    ];

    const result = mergeGroupedCumulativeSeries(groups);

    expect(result).toHaveLength(3);
    expect(result[0].date).toBe('2025-01-01');
    expect(result[1].date).toBe('2025-01-02');
    expect(result[2].date).toBe('2025-01-03');
  });

  it('handles groups with different sparsity patterns', () => {
    const groups: GroupedTimeSeries[] = [
      {
        group: 'Dense',
        values: [
          { entry_date: '2025-01-01', count: 1, cumulative_count: 1 },
          { entry_date: '2025-01-02', count: 1, cumulative_count: 2 },
          { entry_date: '2025-01-03', count: 1, cumulative_count: 3 },
          { entry_date: '2025-01-04', count: 1, cumulative_count: 4 },
        ],
      },
      {
        group: 'Sparse',
        values: [
          { entry_date: '2025-01-01', count: 10, cumulative_count: 10 },
          { entry_date: '2025-01-04', count: 10, cumulative_count: 20 },
        ],
      },
    ];

    const result = mergeGroupedCumulativeSeries(groups);

    expect(result).toHaveLength(4);
    expect(result[0]).toEqual({ date: '2025-01-01', count: 11 }); // 1 + 10
    expect(result[1]).toEqual({ date: '2025-01-02', count: 12 }); // 2 + 10 (forward-filled)
    expect(result[2]).toEqual({ date: '2025-01-03', count: 13 }); // 3 + 10 (forward-filled)
    expect(result[3]).toEqual({ date: '2025-01-04', count: 24 }); // 4 + 20
  });
});

describe('extractPerGroupSeries', () => {
  it('returns empty dates and series for empty input', () => {
    const result = extractPerGroupSeries([]);
    expect(result).toEqual({ dates: [], series: {} });
  });

  it('returns per-group cumulative values', () => {
    const groups: GroupedTimeSeries[] = [
      {
        group: 'Definitive',
        values: [
          { entry_date: '2025-01-01', count: 10, cumulative_count: 10 },
          { entry_date: '2025-01-02', count: 5, cumulative_count: 15 },
        ],
      },
      {
        group: 'Moderate',
        values: [
          { entry_date: '2025-01-01', count: 3, cumulative_count: 3 },
          { entry_date: '2025-01-02', count: 2, cumulative_count: 5 },
        ],
      },
    ];

    const result = extractPerGroupSeries(groups);

    expect(result.dates).toEqual(['2025-01-01', '2025-01-02']);
    expect(result.series['Definitive']).toEqual([10, 15]);
    expect(result.series['Moderate']).toEqual([3, 5]);
  });

  it('forward-fills missing dates per group', () => {
    const groups: GroupedTimeSeries[] = [
      {
        group: 'A',
        values: [
          { entry_date: '2025-01-01', count: 1, cumulative_count: 5 },
          { entry_date: '2025-01-03', count: 2, cumulative_count: 7 },
        ],
      },
      {
        group: 'B',
        values: [
          { entry_date: '2025-01-01', count: 2, cumulative_count: 2 },
          { entry_date: '2025-01-02', count: 3, cumulative_count: 5 },
          { entry_date: '2025-01-03', count: 1, cumulative_count: 6 },
        ],
      },
    ];

    const result = extractPerGroupSeries(groups);

    expect(result.dates).toEqual(['2025-01-01', '2025-01-02', '2025-01-03']);
    expect(result.series['A']).toEqual([5, 5, 7]); // forward-filled at 2025-01-02
    expect(result.series['B']).toEqual([2, 5, 6]);
  });

  it('handles null/undefined values array', () => {
    const groups: GroupedTimeSeries[] = [
      { group: 'A', values: undefined as any },
      { group: 'B', values: null as any },
    ];

    const result = extractPerGroupSeries(groups);
    expect(result).toEqual({ dates: [], series: {} });
  });

  it('sorts dates chronologically', () => {
    const groups: GroupedTimeSeries[] = [
      {
        group: 'A',
        values: [
          { entry_date: '2025-01-03', count: 3, cumulative_count: 18 },
          { entry_date: '2025-01-01', count: 1, cumulative_count: 10 },
        ],
      },
    ];

    const result = extractPerGroupSeries(groups);
    expect(result.dates).toEqual(['2025-01-01', '2025-01-03']);
    expect(result.series['A']).toEqual([10, 18]);
  });
});
