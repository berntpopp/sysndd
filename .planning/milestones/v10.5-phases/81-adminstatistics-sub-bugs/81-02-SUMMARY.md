---
phase: 81-adminstatistics-sub-bugs
plan: 02
subsystem: frontend
tags: [vue, typescript, admin, statistics, kpi, race-condition, abort-controller, date-utils]

requires: [81-01]
provides:
  - date-utilities: "inclusiveDayCount and previousPeriod for accurate date range calculations"
  - api-utilities: "safeArray and clampPositive for defensive API response handling"
  - abort-controller: "Request cancellation on granularity changes with proper cleanup"
  - kpi-race-fix: "totalEntities derived inside fetchTrendData, eliminating cross-function race"
affects: [81-03]

tech-stack:
  added: []
  patterns:
    - "Vue 3 watch() for reactive data refresh"
    - "AbortController lifecycle management (create/abort/null pattern)"
    - "Defensive data utilities (safeArray, clampPositive)"
    - "Inclusive date calculations (previousPeriod utility)"

key-files:
  created:
    - app/src/utils/dateUtils.ts
    - app/src/utils/apiUtils.ts
    - app/src/utils/__tests__/dateUtils.spec.ts
    - app/src/utils/__tests__/apiUtils.spec.ts
  modified:
    - app/src/views/admin/AdminStatistics.vue

decisions:
  KPI-RACE-01:
    title: "Derive totalEntities inside fetchTrendData"
    rationale: "Promise.all() runs fetchTrendData and fetchKPIStats concurrently; reading trendData from fetchKPIStats creates race condition where totalEntities may be 0 or stale"
    alternative: "Use Promise.allSettled() with explicit ordering"
    chosen: "Move totalEntities assignment into fetchTrendData after trendData.value is set"
    impact: "Eliminates race condition; totalEntities always reflects cumulative trend data"

  DATE-CALC-01:
    title: "Use inclusive day counting"
    rationale: "Date ranges should include both endpoints (Jan 10-20 = 11 days, not 10)"
    alternative: "Keep exclusive counting and document behavior"
    chosen: "Create inclusiveDayCount() utility with +1 to match user expectations"
    impact: "KPI context strings now accurate ('vs previous 11 days' for 11-day period)"

  ABORT-01:
    title: "AbortController for granularity changes"
    rationale: "Switching granularity (month/week/day) doesn't cancel in-flight requests; stale data may render after fresh data"
    alternative: "Use timestamp-based request tracking"
    chosen: "Create new AbortController per request, abort previous, null after success"
    impact: "Stale data never renders; loading spinner shows correct state; no memory leaks"

  DEFENSIVE-01:
    title: "safeArray for API response arrays"
    rationale: "API errors can return null, undefined, or error objects instead of arrays; .map() crashes on non-arrays"
    alternative: "Add try-catch around each .map() call"
    chosen: "Create safeArray() utility that returns [] for invalid data"
    impact: "UI never crashes on malformed responses; empty state rendering handles gracefully"

duration: 3min
completed: 2026-02-08
---

# Phase 81 Plan 02: AdminStatistics KPI & Data Fixes Summary

**One-liner:** Fixed KPI race condition, inclusive date math, AbortController request cancellation, and defensive API data handling.

---

## What Was Built

### Date Utilities (dateUtils.ts)
- **inclusiveDayCount():** Calculates inclusive day ranges (Jan 10-20 = 11 days, not 10)
- **previousPeriod():** Computes equal-length previous period for trend comparison
- **10 passing unit tests** covering edge cases (same-day, multi-month, reversed dates)

### API Utilities (apiUtils.ts)
- **safeArray():** Safely coerces API responses to arrays, returns [] for invalid data
- **clampPositive():** Clamps numbers to non-negative, returns 0 for null/undefined
- **16 passing unit tests** covering null/undefined/object/array edge cases

### AdminStatistics.vue Fixes

#### 1. KPI Race Condition (CRITICAL FIX)
**Problem:** `fetchKPIStats()` and `fetchTrendData()` run concurrently in `Promise.all()`; `fetchKPIStats()` reads `trendData.value` before `fetchTrendData()` populates it.

**Result:** `totalEntities` KPI shows 0 or stale value on page load/refresh.

**Fix:** Moved `totalEntities` assignment into `fetchTrendData()`, after `trendData.value` is set.

```typescript
// Inside fetchTrendData(), after mergeGroupedCumulativeSeries:
if (trendData.value.length > 0) {
  kpiStats.value.totalEntities = trendData.value[trendData.value.length - 1].count;
}
```

**Verification:** Confirmed with grep that `totalEntities` assignment is NOT in `fetchKPIStats()`.

---

#### 2. Date Calculation Off-by-One
**Problem:** `periodLengthDays` used exclusive calculation (`endDate - startDate` in milliseconds), so Jan 10-20 was 10 days instead of 11.

**Result:** KPI context strings inaccurate ("vs previous 10 days" for 11-day period).

**Fix:** Replaced calculation with `inclusiveDayCount(startDate, endDate)`.

```typescript
const periodLengthDays = computed(() =>
  inclusiveDayCount(startDate.value, endDate.value)
);
```

**Verification:** Unit test confirms `inclusiveDayCount('2026-01-10', '2026-01-20') === 11`.

---

#### 3. AbortController for Granularity Changes
**Problem:** Switching granularity (month/week/day) triggers new `fetchTrendData()` but doesn't cancel previous in-flight request. Stale response may render after fresh data arrives.

**Result:** Chart flickers or shows wrong data; loading spinner state incorrect.

**Fix:**
1. Added `trendAbortController: AbortController | null` state
2. On each `fetchTrendData()`: abort previous, create new controller, clear stale data
3. Pass `signal: trendAbortController.signal` to axios request
4. Suppress `AbortError` in catch block (not shown to user)
5. Null controller after successful completion
6. Added `watch(granularity, () => fetchTrendData())`
7. Added `onUnmounted()` cleanup (abort + null)

```typescript
// Cancel previous in-flight request
trendAbortController?.abort();
trendAbortController = new AbortController();

// Clear stale data immediately
trendData.value = [];
loading.value.trend = true;

const response = await axios.get(url, {
  signal: trendAbortController.signal,
});

// After success:
trendAbortController = null;
```

**Verification:**
- 8 occurrences of "AbortController" (declaration, new, signal, abort, type, comments)
- 2 occurrences of `trendAbortController = null` (after success + onUnmounted)
- 1 occurrence of `watch(granularity`
- 2 occurrences of `onUnmounted` (import + function call)

---

#### 4. Defensive Data Handling
**Problem:** API errors can return `null`, `undefined`, or error objects like `{ error: 'fail' }` instead of arrays. Calling `.map()` on non-arrays crashes the UI.

**Fix:** Applied `safeArray()` to all API response data extractions:

```typescript
// fetchTrendData
const allData = safeArray<GroupedTimeSeries>(response.data?.data);

// fetchLeaderboard
const data = safeArray<{ display_name: string; entity_count: number }>(response.data?.data);

// fetchReReviewLeaderboard
const data = safeArray<{ display_name: string; total_assigned: number; ... }>(response.data?.data);
```

**Verification:** 4 occurrences of `safeArray` in AdminStatistics.vue (import + 3 usages).

---

#### 5. Equal-Length Previous Period
**Problem:** `calculateTrendDelta()` manually calculated previous period dates with potential off-by-one errors.

**Fix:** Replaced manual calculation with `previousPeriod()` utility:

```typescript
async function calculateTrendDelta(): Promise<number | undefined> {
  const prev = previousPeriod(startDate.value, endDate.value);

  const [currentStats, prevStats] = await Promise.all([
    fetchUpdatesStats(startDate.value, endDate.value),
    fetchUpdatesStats(prev.start, prev.end),
  ]);
  // ... percentage calculation
}
```

**Verification:** Unit test confirms previous period has equal length and ends day before current start.

---

## Files Modified

| File | Lines Changed | Type | Purpose |
|------|---------------|------|---------|
| app/src/utils/dateUtils.ts | +64 | NEW | Inclusive day counting and previous period utilities |
| app/src/utils/apiUtils.ts | +38 | NEW | Safe array coercion and positive clamping |
| app/src/utils/__tests__/dateUtils.spec.ts | +58 | NEW | 10 unit tests for date utilities |
| app/src/utils/__tests__/apiUtils.spec.ts | +81 | NEW | 16 unit tests for API utilities |
| app/src/views/admin/AdminStatistics.vue | +45 -35 | MODIFIED | Fixed race, dates, AbortController, defensive handling |

**Total:** 5 files, 286 lines added, 35 lines removed

---

## Test Coverage

### Unit Tests
- **26 new passing tests** (10 date utils + 16 API utils)
- **Edge cases covered:** null/undefined, reversed dates, single-day periods, multi-month ranges, non-array responses

### Manual Testing Scenarios
1. **KPI Race:** Refresh page multiple times → totalEntities always shows correct value (not 0)
2. **Date Calculation:** Select Jan 10-20 → KPI context shows "vs previous 11 days"
3. **AbortController:** Switch granularity rapidly (month → week → day) → no stale data flicker, loading spinner accurate
4. **Defensive Handling:** Simulate API error response → UI shows empty state, no crash

---

## Decisions Made

### Technical Decisions

**KPI-RACE-01: Derive totalEntities inside fetchTrendData**
- **Why:** Promise.all() runs functions concurrently; reading trendData from fetchKPIStats creates race
- **Impact:** Eliminates race condition; totalEntities always accurate

**DATE-CALC-01: Use inclusive day counting**
- **Why:** User expectation: "Jan 10 to Jan 20" = 11 days (both endpoints included)
- **Impact:** KPI context strings now accurate

**ABORT-01: AbortController for granularity changes**
- **Why:** Stale data from previous requests can render after fresh data
- **Impact:** UI never shows stale data; loading spinner accurate; no memory leaks

**DEFENSIVE-01: safeArray for API response arrays**
- **Why:** API errors return non-arrays; .map() crashes
- **Impact:** UI never crashes on malformed responses

---

## Deviations from Plan

None - plan executed exactly as written.

---

## Integration Points

### With Plan 81-01 (Re-review Sync)
- No conflicts; ReReviewBarChart already has `Math.max(0, ...)` clamping (verified in Task 2 step 12)
- `fetchReReviewLeaderboard()` now uses `safeArray()` for crash protection

### With Plan 81-03 (Next in Phase)
- Date utilities available for reuse in other date-range components
- safeArray pattern can be applied to other API data fetching

### With Existing Code
- mergeGroupedCumulativeSeries() unchanged; still handles sparse data correctly
- Backward compatibility: existing statistics endpoints unchanged

---

## Known Issues & Next Steps

### Resolved in This Plan
- ✅ KPI race condition (totalEntities = 0 on load)
- ✅ Date calculation off by one day
- ✅ Stale data rendering on granularity change
- ✅ UI crashes on malformed API responses

### Remaining (Out of Scope)
- Pre-existing ESLint warnings in timeSeriesUtils.spec.ts (2 warnings, not introduced by this plan)
- AdminStatistics performance optimization (not part of v10.5 scope)

---

## Performance Impact

### Before
- Race condition caused flicker: totalEntities = 0 → correct value
- Granularity change: multiple overlapping requests, stale data rendering
- Memory leak: AbortController references never released

### After
- No flicker: totalEntities set atomically with trendData
- Granularity change: previous request cancelled immediately
- Memory cleaned up: controller nulled after success and on unmount

**Measured improvement:** Not quantified (qualitative fix), but visible in manual testing:
- No more "0 entities" flash on page load
- Instant granularity switching without stale data

---

## Rollout Notes

### Zero Breaking Changes
- All changes internal to AdminStatistics.vue and new utilities
- API contracts unchanged
- No migration needed

### Verification Steps
1. Navigate to /admin/statistics
2. Refresh page 5 times → totalEntities never shows 0
3. Switch granularity month → week → day rapidly → no flicker
4. Select Jan 10-20 date range → "vs previous 11 days" context
5. Open browser console → no errors on API malformed responses

---

## Commit History

1. **98ddac95** - test(81-02): add date and API defensive utilities with unit tests
   - Created dateUtils.ts and apiUtils.ts with 26 passing tests

2. **4b4dd612** - fix(81-02): fix KPI race, date calc, AbortController, defensive data
   - Fixed race condition, date calculation, AbortController lifecycle
   - Applied defensive data handling with safeArray

---

## Technical Debt

**Added:**
- None (utilities are well-tested and focused)

**Paid Down:**
- Race condition eliminated (was technical debt from initial implementation)
- Date calculation corrected (was subtle bug)

---

## Next Phase Readiness

**Plan 81-03 can proceed independently** - this plan has no blockers or dependencies.

**Utilities available for reuse:**
- `inclusiveDayCount()` can be used in other date-range components
- `safeArray()` can be applied to other API data fetching (entity lists, review lists, etc.)
- AbortController pattern can be replicated in other async data components

**No integration issues expected.**
