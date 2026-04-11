# Fix Proposal: Stale Data on Granularity Change (#172, Bug 7)

## Problem

When switching granularity (Monthly/Weekly/Daily), the old chart remains visible while the new request is in flight. Combined with no request cancellation, a slow response can cause the wrong dataset to display.

## Proposed Fix

Clear data immediately and cancel any in-flight request using `AbortController`.

```typescript
// AdminStatistics.vue

let trendAbortController: AbortController | null = null;

async function fetchTrendData(): Promise<void> {
  // Cancel previous request
  trendAbortController?.abort();
  trendAbortController = new AbortController();

  // Clear stale data immediately
  trendData.value = [];
  loading.value.trend = true;

  try {
    const response = await axios.get(`${apiUrl}/api/statistics/entities_over_time`, {
      params: { aggregate: 'entity_id', group: 'category', summarize: granularity.value },
      headers: getAuthHeaders(),
      signal: trendAbortController.signal,
    });
    trendData.value = mergeGroupedCumulativeSeries(response.data.data ?? []);
  } catch (error) {
    if ((error as Error).name !== 'AbortError') {
      console.error('Failed to fetch trend data:', error);
      makeToast('Failed to fetch trend data', 'Error', 'danger');
    }
  } finally {
    loading.value.trend = false;
  }
}
```

Add cleanup on unmount:

```typescript
onUnmounted(() => {
  trendAbortController?.abort();
});
```

## Why

| Principle | How Applied |
|-----------|-------------|
| **KISS** | `AbortController` is the standard browser API for request cancellation |
| **No Stale State** | Clear first, then fetch — user sees spinner, not wrong data |
| **Resource Cleanup** | Abort on unmount prevents orphaned requests |

## Files Changed

- `app/src/views/admin/AdminStatistics.vue`
