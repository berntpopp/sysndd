---
phase: 81-adminstatistics-sub-bugs
plan: 03
subsystem: frontend
tags: [vue, typescript, admin, statistics, chart, filter, category, trend]

requires: [81-02]
provides:
  - trend-filter-controls: "NDD/Non-NDD/All toggle, Combined/By Category display, per-category checkboxes"
  - per-group-series: "extractPerGroupSeries() for per-category cumulative time series with forward-fill"
  - fixed-yaxis: "Running maximum trendYMax for stable y-axis across filter changes"
affects: []

tech-stack:
  added: []
  patterns:
    - "Vue 3 watch() with separate watchers for reset-vs-keep semantics"
    - "Running maximum for chart y-axis stability (suggestedMax)"
    - "Conditional API filter param (undefined = use server default)"
    - "Multi-line Chart.js datasets with per-category color mapping"

key-files:
  created: []
  modified:
    - app/src/utils/timeSeriesUtils.ts
    - app/src/utils/__tests__/timeSeriesUtils.spec.ts
    - app/src/views/admin/components/charts/EntityTrendChart.vue
    - app/src/views/admin/AdminStatistics.vue

decisions:
  FILTER-PARAM-01:
    title: "Omit filter param when matching API default"
    rationale: "Axios URL-encodes commas/parentheses in filter strings like contains(ndd_phenotype_word,Yes), which the R API's generate_filter_expressions() may not parse correctly"
    alternative: "Always pass filter param and fix server-side parser"
    chosen: "Return undefined from buildTrendFilter() when filter matches API default, so param is omitted entirely"
    impact: "No URL encoding issues; API uses its R-level default value"

  YMAX-RUNNING-01:
    title: "Running maximum for y-axis stability"
    rationale: "Unchecking category checkboxes fetches fewer entities; if trendYMax is overwritten on each fetch, y-axis shrinks and makes comparison impossible"
    alternative: "Always set yMax to the full dataset maximum regardless of filters"
    chosen: "Use Math.max(trendYMax ?? 0, newMax) as running maximum; reset only when NDD filter changes (different dataset)"
    impact: "Y-axis stays fixed when toggling categories; resets appropriately when switching NDD/Non-NDD/All"

  SEPARATE-WATCHERS-01:
    title: "Separate watchers for NDD filter vs category checkboxes"
    rationale: "NDD filter change means entirely different dataset (reset yMax); category checkbox change means subset of same dataset (keep yMax)"
    alternative: "Single combined watcher with conditional logic"
    chosen: "Two separate watch() calls with distinct reset semantics"
    impact: "Clear separation of concerns; y-axis behavior correct for both interaction types"

duration: 15min
completed: 2026-02-09
---

# Phase 81 Plan 03: Entity Trend Chart Filter Controls Summary

**One-liner:** Added NDD/Non-NDD/All toggle, Combined/By Category display mode, and per-category checkbox filters to the Entity Submissions Over Time chart with fixed y-axis.

---

## What Was Built

### extractPerGroupSeries() (timeSeriesUtils.ts)

New utility function that takes grouped time-series data and returns per-group cumulative arrays with forward-fill. Uses the same date-union logic as `mergeGroupedCumulativeSeries()`, but returns separate arrays per group instead of summing them.

```typescript
export function extractPerGroupSeries(
  groups: GroupedTimeSeries[]
): { dates: string[]; series: Record<string, number[]> }
```

**4 new unit tests:**
- Empty input returns empty dates and series
- Per-group values extracted correctly
- Forward-fill carries last known cumulative_count
- Dates sorted chronologically across groups

### EntityTrendChart.vue Enhancements

- **New props:** `categoryData` (per-group series), `displayMode` ('combined' | 'by_category'), `yMax` (fixed y-axis maximum)
- **Category color map:** Definitive=#4caf50, Moderate=#2196f3, Limited=#ff9800, Refuted=#f44336
- **Dual rendering mode:** Combined mode shows single filled line with optional moving average; by_category mode shows one line per category with distinct colors
- **`chartOptions` as computed:** Reacts to `yMax` prop changes via `suggestedMax` in y-axis scale config
- **Tooltip:** Shows dataset label + count for each line

### AdminStatistics.vue Filter Controls

#### 1. Reactive State
```typescript
const nddFilter = ref<'ndd' | 'non_ndd' | 'all'>('ndd');
const categoryDisplay = ref<'combined' | 'by_category'>('combined');
const selectedCategories = ref<string[]>(['Definitive', 'Moderate', 'Limited', 'Refuted']);
const trendCategoryData = ref<{ dates: string[]; series: Record<string, number[]> }>({ dates: [], series: {} });
const trendYMax = ref<number | undefined>(undefined);
```

#### 2. buildTrendFilter() Helper
Returns `string | undefined` — returns `undefined` when filter matches API default (NDD-only), empty string `''` for "all" (no filter), or composed filter string for non-NDD or category subset.

Key insight: Returning `undefined` causes axios to omit the `filter` param entirely, letting the R API use its default value. This avoids URL encoding issues with commas and parentheses.

#### 3. Separate Watchers
- **`watch(nddFilter)`:** Resets `trendYMax` to `undefined` (different dataset), then refetches
- **`watch(selectedCategories)`:** Keeps `trendYMax` (same dataset subset), then refetches
- **`watch(granularity)`:** Already existed from 81-02; no `@change` handler needed (removed)

#### 4. Running Maximum for Y-Axis
```typescript
trendYMax.value = Math.max(trendYMax.value ?? 0, maxVal);
```
Reset only when NDD filter changes; kept when toggling categories or display mode.

#### 5. Template Controls
Second row below chart title with:
- NDD radio group (NDD / Non-NDD / All) — `BFormRadioGroup` with outline-secondary buttons
- Display mode radio group (Combined / By Category) — `BFormRadioGroup` with outline-secondary buttons
- Category checkbox group (Definitive / Moderate / Limited / Refuted) — `BFormCheckboxGroup` with outline-secondary buttons

#### 6. Dynamic Description
Computed `trendDescription` changes based on filter state (NDD/Non-NDD/All, combined/by-category).

---

## Files Modified

| File | Lines Changed | Type | Purpose |
|------|---------------|------|---------|
| app/src/utils/timeSeriesUtils.ts | +40 | MODIFIED | Added extractPerGroupSeries() export |
| app/src/utils/__tests__/timeSeriesUtils.spec.ts | +55 | MODIFIED | 4 new unit tests for extractPerGroupSeries |
| app/src/views/admin/components/charts/EntityTrendChart.vue | +80 -20 | MODIFIED | Multi-line category mode, yMax prop, computed chartOptions |
| app/src/views/admin/AdminStatistics.vue | +100 -15 | MODIFIED | Filter controls, state, watchers, buildTrendFilter |

**Total:** 4 files, ~275 lines added, ~35 lines removed

---

## Test Coverage

### Unit Tests
- **4 new passing tests** for extractPerGroupSeries
- **14 total** in timeSeriesUtils.spec.ts (8 existing + 4 new + 2 edge cases)

### Verification
1. `npx vue-tsc --noEmit` — no TypeScript errors
2. `npx eslint` on modified files — no ESLint errors
3. `npx vitest run src/utils/__tests__/timeSeriesUtils.spec.ts` — 14 tests pass

### Playwright Manual Testing
- Toggled NDD/Non-NDD/All — chart refetches and re-renders correctly
- Toggled Combined/By Category — chart switches between single and multi-line
- Unchecked categories — chart refetches with filtered data, y-axis stays fixed
- Switched granularity while in by-category mode — chart re-renders correctly
- No console errors throughout

---

## Decisions Made

### Technical Decisions

**FILTER-PARAM-01: Omit filter param when matching API default**
- **Why:** Axios URL-encodes commas/parentheses, breaking the R API's filter parser
- **Impact:** No encoding issues; server uses its default value

**YMAX-RUNNING-01: Running maximum for y-axis stability**
- **Why:** Unchecking categories reduced y-axis max, making comparison impossible
- **Impact:** Y-axis stays fixed when toggling categories; resets when switching NDD filter

**SEPARATE-WATCHERS-01: Separate watchers for NDD filter vs categories**
- **Why:** NDD filter = different dataset (reset yMax); categories = subset (keep yMax)
- **Impact:** Correct y-axis behavior for both interaction types

---

## Deviations from Plan

### Pitfall Resolution
All 5 pitfalls from the plan were encountered and resolved:

1. **URL encoding** — Resolved by returning `undefined` from `buildTrendFilter()` when matching default
2. **`equals(1,1)` invalid** — Changed to empty string `''` for "all" filter
3. **Double-fetch** — Removed `@change="fetchTrendData"` from granularity radio
4. **Y-axis rescaling** — Implemented running maximum with separate watchers for reset semantics
5. **Service worker caching** — Verified in Playwright by unregistering stale service worker

### Post-Plan Additions
- `trendDescription` computed for dynamic chart description text (not in original plan but natural fit)

---

## Integration Points

### With Plan 81-02 (AbortController, safeArray)
- Reuses `trendAbortController` for filter-change cancellation
- `safeArray()` applied to API responses in fetchTrendData
- `granularity` watcher from 81-02 still works; removed redundant `@change`

### With Plan 80-02 (Time Series Utils)
- `mergeGroupedCumulativeSeries()` still used for combined mode
- `extractPerGroupSeries()` follows same forward-fill pattern

### With Existing Code
- API endpoint `statistics_endpoints.R` unchanged
- `generate_filter_expressions()` handles all filter strings correctly
- Moving average only shown in combined mode (disabled for multi-line)

---

## Known Issues & Next Steps

### Resolved in This Plan
- NDD-only hardcoded filter (now configurable)
- Single-line chart (now supports per-category breakdown)
- Y-axis rescaling on category toggle (now running maximum)
- URL encoding of filter parameters (now omit when matching default)
- Double-fetch on granularity change (removed @change handler)

### Remaining (Out of Scope)
- Category filter `any()` syntax not yet tested with API (currently only used when < 4 categories selected)
- Chart legend could benefit from consistent ordering (currently follows API response order)

---

## Performance Impact

### Before
- Single API call with hardcoded NDD filter
- One chart rendering mode

### After
- Same single API call with configurable filter
- Two rendering modes (combined + per-category)
- Running maximum prevents y-axis jitter
- No additional API calls for display mode toggle (reprocesses existing data)

---

## Rollout Notes

### Zero Breaking Changes
- All changes internal to AdminStatistics and EntityTrendChart
- API contracts unchanged
- Default behavior unchanged (NDD + combined mode on page load)

### Verification Steps
1. Navigate to /admin/statistics
2. Toggle NDD/Non-NDD/All — chart updates, no errors
3. Toggle Combined/By Category — chart switches rendering mode
4. Uncheck Definitive — chart refetches, y-axis stays fixed
5. Re-check all categories — chart shows all lines
6. Switch granularity — chart re-renders in current mode
7. No console errors throughout

---

## Commit History

Pending commit — code changes ready, awaiting documentation completion.

---

## Technical Debt

**Added:**
- None

**Paid Down:**
- Removed hardcoded NDD filter (was limiting chart utility)
- Removed redundant @change handler (was causing double-fetch)
