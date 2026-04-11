# Fix Proposal: Entity Trend Chart Aggregation Bug (#171)

## Problem

`AdminStatistics.vue:fetchTrendData()` re-derives global cumulative totals by summing incremental `count` values across categories, then recalculating cumulative sums. This produces incorrect totals because not all categories have data points at every date.

The API returns **per-category** time series where `cumulative_count` is cumulative *within each category*. At dates where only one category has an entry, the cross-category sum of incremental counts misses the other categories' running totals entirely.

## Root Cause

```typescript
// AdminStatistics.vue lines 417-433
// WRONG: sums incremental counts, then re-derives cumulative
dateCountMap.set(item.entry_date, existing + item.count);
// ...
cumulative += count;
```

## Correct Approach

The public `AnalysesTimePlot.vue` does it right: use `cumulative_count` directly from the API. For a single combined line, sum each category's `cumulative_count` at each date, forward-filling gaps.

## Proposed Fix

### Extract a pure utility function (SRP, DRY, testable)

**New file:** `app/src/utils/timeSeriesUtils.ts`

```typescript
/**
 * Merges per-group cumulative time series into a single global cumulative series.
 *
 * Handles sparse data: when a group has no entry at a given date, its last known
 * cumulative value is carried forward (forward-fill). The global total at each
 * date is the sum of all groups' (forward-filled) cumulative counts.
 *
 * @param groups - Array of { group, values: [{ entry_date, count, cumulative_count }] }
 * @returns Sorted array of { date, count } where count is the global cumulative total
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

export function mergeGroupedCumulativeSeries(
  groups: GroupedTimeSeries[]
): AggregatedPoint[] {
  // 1. Collect union of all dates
  const allDates = new Set<string>();
  for (const g of groups) {
    for (const v of g.values ?? []) {
      allDates.add(v.entry_date);
    }
  }

  // 2. Build per-group lookup: date -> cumulative_count
  const groupMaps = groups.map((g) => {
    const map = new Map<string, number>();
    for (const v of g.values ?? []) {
      map.set(v.entry_date, v.cumulative_count);
    }
    return map;
  });

  // 3. Forward-fill and sum across groups at each date
  const sortedDates = Array.from(allDates).sort();
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
```

### Update `fetchTrendData()` in AdminStatistics.vue

```typescript
import { mergeGroupedCumulativeSeries } from '@/utils/timeSeriesUtils';

async function fetchTrendData(): Promise<void> {
  if (!axios) return;
  loading.value.trend = true;
  try {
    const response = await axios.get(`${apiUrl}/api/statistics/entities_over_time`, {
      params: {
        aggregate: 'entity_id',
        group: 'category',
        summarize: granularity.value,
      },
      headers: getAuthHeaders(),
    });

    const allData = response.data.data ?? [];
    trendData.value = mergeGroupedCumulativeSeries(allData);
  } catch (error) {
    console.error('Failed to fetch trend data:', error);
    makeToast('Failed to fetch trend data', 'Error', 'danger');
    trendData.value = [];
  } finally {
    loading.value.trend = false;
  }
}
```

## Why This Design

| Principle | How Applied |
|-----------|-------------|
| **SRP** | `mergeGroupedCumulativeSeries` does exactly one thing: merge grouped cumulative time series |
| **DRY** | Extracted to `utils/` so any future admin view needing the same aggregation reuses it |
| **KISS** | Forward-fill is the simplest correct algorithm for sparse cumulative series |
| **OCP** | New group types (e.g., inheritance) work without modifying the function |
| **Testable** | Pure function with no side effects; easy to unit test with mock data |

## Test Cases

```typescript
describe('mergeGroupedCumulativeSeries', () => {
  it('sums cumulative counts across groups at shared dates', () => { ... });
  it('forward-fills missing dates within a group', () => { ... });
  it('handles empty groups gracefully', () => { ... });
  it('produces monotonically non-decreasing output', () => { ... });
  it('handles single group (passthrough)', () => { ... });
});
```

## Files Changed

- `app/src/utils/timeSeriesUtils.ts` (NEW)
- `app/src/views/admin/AdminStatistics.vue` (modify `fetchTrendData`)
