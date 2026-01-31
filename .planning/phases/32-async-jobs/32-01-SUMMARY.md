# Phase 32 Plan 01: useAsyncJob Composable Summary

**One-liner:** Extracted reusable useAsyncJob composable with VueUse useIntervalFn for auto-cleanup polling, elapsed time display, and reactive progress state.

## What Was Built

Created `useAsyncJob.ts` composable that extracts the proven async job pattern from ManageAnnotations.vue into a reusable module for all long-running jobs (ontology updates, HGNC updates, clustering).

### Key Features

1. **Polling with Auto-Cleanup**: Uses VueUse `useIntervalFn` which auto-cleans via `tryOnCleanup` on component unmount
2. **Elapsed Time Display**: Updates every second, formatted as "Xm Ys" or "Ys"
3. **Progress Tracking**: Switches between indeterminate (striped) and determinate (percentage) based on `hasRealProgress`
4. **R/Plumber Compatibility**: Handles array-wrapped scalar values from R API
5. **Terminal State Handling**: Automatically stops polling on 'completed' or 'failed' status
6. **Safety Net Cleanup**: Explicit `onUnmounted` hook as backup for interval cleanup

### Composable API

```typescript
const {
  // State
  jobId, status, step, progress, error, elapsedSeconds,
  // Computed
  hasRealProgress, progressPercent, elapsedTimeDisplay,
  progressVariant, statusBadgeClass, isLoading, isPolling,
  // Methods
  startJob, stopPolling, reset
} = useAsyncJob((jobId) => `/api/jobs/${jobId}/status`);
```

## Files Changed

| File | Action | Lines | Purpose |
|------|--------|-------|---------|
| `app/src/composables/useAsyncJob.ts` | Created | 319 | Core async job composable |
| `app/src/composables/index.ts` | Modified | +9 | Barrel export for useAsyncJob |

## Commits

| Hash | Type | Description |
|------|------|-------------|
| f7d99cc | feat | Create useAsyncJob composable |
| d1bd4a1 | feat | Export useAsyncJob from composables index |

## Verification Results

- [x] TypeScript check passes (`npm run type-check`)
- [x] useAsyncJob exported from `useAsyncJob.ts`
- [x] VueUse `useIntervalFn` imported and used for both polling and timer
- [x] `onUnmounted` cleanup hook present
- [x] Exported from composables index
- [x] Minimum 100 lines (319 lines)

## Pattern Extracted

The composable extracts these patterns from ManageAnnotations.vue (lines 346-641):

| Pattern | Source Lines | Implementation |
|---------|--------------|----------------|
| Elapsed time display | 398-405 | `elapsedTimeDisplay` computed |
| Status badge class | 411-418 | `statusBadgeClass` computed |
| Progress variant | 406-409 | `progressVariant` computed |
| Real progress check | 388-390 | `hasRealProgress` computed |
| Progress percent | 391-396 | `progressPercent` computed |
| Polling interval | 565-570 | `useIntervalFn` with 3s default |
| Terminal state check | 624-635 | Stop polling on completed/failed |

## Deviations from Plan

None - plan executed exactly as written.

## Next Steps

This composable is ready for use in:
- Phase 32-02: Refactor ManageAnnotations.vue to use useAsyncJob
- Future admin views with async jobs (clustering, data exports)

---

*Completed: 2026-01-26*
*Duration: ~3 minutes*
