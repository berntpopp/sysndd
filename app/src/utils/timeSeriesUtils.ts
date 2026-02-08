// utils/timeSeriesUtils.ts

/**
 * Time-series aggregation utilities for cumulative metrics
 *
 * Provides utilities for merging grouped time-series data with sparse entries,
 * handling forward-fill of cumulative counts to produce monotonically
 * non-decreasing aggregated totals.
 */

export interface TimeSeriesPoint {
  entry_date: string;
  count: number;
  cumulative_count: number;
}

export interface GroupedTimeSeries {
  group: string;
  values: TimeSeriesPoint[];
}

export interface AggregatedPoint {
  date: string;
  count: number;
}

/**
 * Merges per-group cumulative time series into a single global cumulative series.
 *
 * Handles sparse data: when a group has no entry at a given date, its last known
 * cumulative value is carried forward (forward-fill). The global total at each
 * date is the sum of all groups' (forward-filled) cumulative counts.
 *
 * @param groups - Array of grouped time series data
 * @returns Array of aggregated points with dates and cumulative totals
 *
 * @example
 * ```typescript
 * const groups = [
 *   { group: 'Definitive', values: [
 *     { entry_date: '2025-01-01', count: 10, cumulative_count: 10 },
 *     { entry_date: '2025-01-03', count: 5, cumulative_count: 15 },
 *   ]},
 *   { group: 'Moderate', values: [
 *     { entry_date: '2025-01-01', count: 3, cumulative_count: 3 },
 *     { entry_date: '2025-01-02', count: 2, cumulative_count: 5 },
 *   ]},
 * ];
 *
 * const result = mergeGroupedCumulativeSeries(groups);
 * // [
 * //   { date: '2025-01-01', count: 13 },  // 10 + 3
 * //   { date: '2025-01-02', count: 15 },  // 10 (forward-filled) + 5
 * //   { date: '2025-01-03', count: 20 },  // 15 + 5 (forward-filled)
 * // ]
 * ```
 */
export function mergeGroupedCumulativeSeries(
  groups: GroupedTimeSeries[]
): AggregatedPoint[] {
  // Step 1: Collect union of all dates from all groups
  const allDates = new Set<string>();
  for (const g of groups) {
    for (const v of g.values ?? []) {
      allDates.add(v.entry_date);
    }
  }

  // Handle empty data
  if (allDates.size === 0) {
    return [];
  }

  // Step 2: Build per-group lookup: date -> cumulative_count
  const groupMaps = groups.map((g) => {
    const map = new Map<string, number>();
    for (const v of g.values ?? []) {
      map.set(v.entry_date, v.cumulative_count);
    }
    return map;
  });

  // Step 3: Sort dates chronologically (string sort works for YYYY-MM-DD)
  const sortedDates = Array.from(allDates).sort();

  // Step 4: Forward-fill and sum across groups at each date
  const lastSeen = new Array<number>(groups.length).fill(0);

  return sortedDates.map((date) => {
    let total = 0;
    for (let i = 0; i < groupMaps.length; i++) {
      const val = groupMaps[i].get(date);
      if (val !== undefined) {
        lastSeen[i] = val;
      }
      total += lastSeen[i];
    }
    return { date, count: total };
  });
}

/**
 * Extracts per-group cumulative time series with forward-fill.
 *
 * Returns a union of all dates and each group's forward-filled cumulative count,
 * suitable for rendering one line per category in a chart.
 *
 * @param groups - Array of grouped time series data
 * @returns Object with sorted date labels and per-group cumulative value arrays
 */
export function extractPerGroupSeries(
  groups: GroupedTimeSeries[]
): { dates: string[]; series: Record<string, number[]> } {
  const allDates = new Set<string>();
  for (const g of groups) {
    for (const v of g.values ?? []) {
      allDates.add(v.entry_date);
    }
  }

  if (allDates.size === 0) {
    return { dates: [], series: {} };
  }

  const sortedDates = Array.from(allDates).sort();

  const groupMaps = groups.map((g) => {
    const map = new Map<string, number>();
    for (const v of g.values ?? []) {
      map.set(v.entry_date, v.cumulative_count);
    }
    return { name: g.group, map };
  });

  const series: Record<string, number[]> = {};
  const lastSeen: Record<string, number> = {};

  for (const { name } of groupMaps) {
    series[name] = [];
    lastSeen[name] = 0;
  }

  for (const date of sortedDates) {
    for (const { name, map } of groupMaps) {
      const val = map.get(date);
      if (val !== undefined) {
        lastSeen[name] = val;
      }
      series[name].push(lastSeen[name]);
    }
  }

  return { dates: sortedDates, series };
}

export default { mergeGroupedCumulativeSeries, extractPerGroupSeries };
