# Fix Proposal: Race Condition — KPI Depends on trendData (#172, Bug 3)

## Problem

`fetchStatistics()` runs 5 data fetches in parallel via `Promise.all()`. `fetchKPIStats()` reads `trendData.value` to compute `totalEntities`, but `fetchTrendData()` populates `trendData` — and there's no guarantee it finishes first.

```typescript
// AdminStatistics.vue:663-670
await Promise.all([
  fetchTrendData(),       // writes trendData
  fetchKPIStats(),        // reads trendData.value[last].count → may be 0
  // ...
]);
```

## Root Cause

Cross-function data dependency hidden inside a parallel execution block. Violates the principle that parallel tasks should be independent.

## Proposed Fix

**Compute `totalEntities` inside `fetchTrendData()` immediately after data is ready.** This eliminates the cross-function dependency entirely.

```typescript
async function fetchTrendData(): Promise<void> {
  // ... fetch and process ...
  trendData.value = mergeGroupedCumulativeSeries(allData);

  // Derive KPI directly — no race condition
  if (trendData.value.length > 0) {
    kpiStats.value.totalEntities = trendData.value[trendData.value.length - 1].count;
  }
}
```

Remove the `trendData` dependency from `fetchKPIStats()`.

## Why

| Principle | How Applied |
|-----------|-------------|
| **SRP** | Each fetch function owns its own outputs completely |
| **No Temporal Coupling** | Parallel tasks no longer depend on execution order |
| **KISS** | Simpler than adding await chains or watchers |

## Files Changed

- `app/src/views/admin/AdminStatistics.vue`
