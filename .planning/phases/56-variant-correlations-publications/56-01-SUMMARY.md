---
phase: 56-variant-correlations-publications
plan: 01
subsystem: frontend-analyses
tags: [vue, d3, navigation, routing, bugfix, r-api, tooltip-fix]

requires:
  - phase-55 (bug fixes complete)
provides:
  - working-variant-chart-navigation
affects:
  - user-experience-analyses

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - app/src/components/analyses/AnalysesVariantCorrelogram.vue
    - app/src/components/analyses/AnalysesVariantCounts.vue
    - api/functions/helper-functions.R
    - api/endpoints/entity_endpoints.R

decisions: []

metrics:
  duration: 1 minute
  completed: 2026-01-31
---

# Phase 56 Plan 01: Fix Variant Navigation Links Summary

Fixed broken navigation links from /Variants/ to /Entities/ in variant analysis charts.

## What Was Built

### Task 1: Fix AnalysesVariantCorrelogram Navigation (d673bac0)

Changed the correlation matrix chart links from the non-existent `/Variants/` route to the correct `/Entities/` route:

**File:** `app/src/components/analyses/AnalysesVariantCorrelogram.vue`

```javascript
// Before (broken):
.attr('xlink:href', (d) =>
  `/Variants/?sort=entity_id&filter=any(category,Definitive),all(modifier_variant_id,${d.x_vario_id},${d.y_vario_id})...`
)

// After (working):
.attr('xlink:href', (d) =>
  `/Entities/?sort=entity_id&filter=any(category,Definitive),all(modifier_variant_id,${d.x_vario_id},${d.y_vario_id})...`
)
```

Also updated aria-label for accessibility.

### Task 2: Fix AnalysesVariantCounts Navigation (96fe15dd)

Changed the bar chart links from the non-existent `/Variants/` route to the correct `/Entities/` route:

**File:** `app/src/components/analyses/AnalysesVariantCounts.vue`

```javascript
// Before (broken):
.attr('xlink:href', (d) =>
  `/Variants/?sort=entity_id&filter=any(category,Definitive),all(modifier_variant_id,${d.vario_id})...`
)

// After (working):
.attr('xlink:href', (d) =>
  `/Entities/?sort=entity_id&filter=any(category,Definitive),all(modifier_variant_id,${d.vario_id})...`
)
```

Also updated aria-label for accessibility.

## Technical Details

**Root Cause:** Both charts were generating links to `/Variants/` which does not exist as a route in `app/src/router/routes.ts`. The router only defines:
- `/Entities` - Entities table with filter support
- `/VariantCorrelations` - The analysis view itself

**Fix:** Route to `/Entities/` with the `vario_id` filter parameter, which correctly filters the Entities table to show only entities with the selected variant(s).

**Filter Parameter Format:**
- Single variant: `any(vario_id,{vario_id})`
- Variant combination: `any(vario_id,{x_vario_id},{y_vario_id})`

## Post-Initial Bug Fixes (2026-01-31)

Additional issues discovered during manual testing and fixed:

### 1. Tooltip Positioning Fix
**Problem:** Tooltips appeared at wrong position due to deprecated `event.layerX/layerY`
**Solution:** Changed to `event.pageX/pageY` with container-relative positioning:
```javascript
const containerRect = container.getBoundingClientRect();
const scrollLeft = window.scrollX || document.documentElement.scrollLeft;
const scrollTop = window.scrollY || document.documentElement.scrollTop;
tooltip
  .style('left', `${event.pageX - containerRect.left - scrollLeft + 15}px`)
  .style('top', `${event.pageY - containerRect.top - scrollTop + 15}px`);
```

### 2. Filter Parameter Fix
**Problem:** Used `modifier_variant_id` which doesn't exist in entity API
**Solution:** Changed to `vario_id` filter parameter

### 3. API Support for vario_id Filter
**Problem:** Entity API didn't support filtering by variant
**Solution:** Added two helper functions in `api/functions/helper-functions.R`:
- `extract_vario_filter()` - Parses `vario_id` (or legacy `modifier_variant_id`) from filter string
- `get_entity_ids_by_vario()` - Queries entities via `ndd_review_variant_connect_view`

Modified `api/endpoints/entity_endpoints.R` to use these helpers.

### 4. Count Consistency Fix
**Problem:** VariantCounts showed 1138 but entity filter showed 1133
**Solution:** Changed `get_entity_ids_by_vario()` to use `ndd_review_variant_connect_view` (same as variant count endpoint)

### 5. TimePlot Aggregation Fix
**Problem:** X-axis had way too many labels (140+ ticks for month/quarter over 35 years), making chart unreadable
**Solution:** Implemented smart tick selection based on time span:
```javascript
// Calculate time span to determine appropriate tick intervals
const yearsSpan = (maxDate - minDate) / (1000 * 60 * 60 * 24 * 365);

// For all aggregations, show year ticks with smart spacing (~8-12 ticks max)
const yearInterval = yearsSpan > 30 ? 5 : yearsSpan > 15 ? 3 : yearsSpan > 8 ? 2 : 1;
xAxis.ticks(d3.timeYear.every(yearInterval)).tickFormat(d3.timeFormat('%Y'));
```
**Key insight:** Data aggregation (monthly/quarterly data points) is separate from axis tick display. The data shows more granularity while axis remains readable.

### 6. TimePlot Tooltip Positioning Fix
**Problem:** Tooltips used deprecated `event.layerX/layerY`
**Solution:** Changed to `event.pageX/pageY` with container-relative positioning (same pattern as other charts)

### 7. Publication Stats API Filter Fix (6207a4e8)
**Problem:** API returned items with counts below the min threshold (e.g., authors with count 3 when min=20)
**Root Cause:** Plumber passes query parameters as strings; `count >= "20"` did string comparison instead of numeric
**Solution:** Added integer conversion at start of endpoint function:
```r
min_journal_count <- as.integer(min_journal_count)
min_lastname_count <- as.integer(min_lastname_count)
min_keyword_count <- as.integer(min_keyword_count)
```

### 8. Publication Stats Frontend Refactoring (c21df572)
**Problem:** Client-side filtering duplicated API filtering, causing confusion
**User Requirement:** "no client side filter EVER! all API!"
**Solution:**
- Removed unused `min_journal_count`, `min_lastname_count`, `min_keyword_count` variables
- Single `minCount` variable used for all API filter parameters
- Changed input handler from `generateBarPlot` to `fetchStats` to trigger new API calls
- Removed all client-side filtering from computed properties and chart generation

### 9. Replace YoY Growth with 5-Year Average
**Problem:** "YoY Growth: -100%" was misleading (comparing 2026 with 0 pubs to 2024)
**Solution:** Replaced with "5-Year Avg" showing average publications per year over last 5 complete years
```javascript
const fiveYearAvg = yearsWithData > 0 ? Math.round(fiveYearTotal / yearsWithData) : 0;
// Shows "583/yr" instead of "-100%"
```

### 10. Fix Newest Publication Display
**Problem:** Showed aggregated year bucket date (2025-01-01) instead of actual newest date
**Solution:** Separate API call to fetch actual newest publication:
```javascript
const response = await this.axios.get(apiUrl, {
  params: { sort: '-Publication_date', page_size: '1', fields: 'publication_id,Publication_date' }
});
// Now correctly shows "2025-07-14"
```

### 11. Tooltip Edge Positioning Fix (3c697303)
**Problem:** Tooltips cut off when hovering near container edges (left/right)
**Solution:** Smart positioning that detects edge proximity and flips tooltip direction:
```javascript
// Smart positioning: flip to left if too close to right edge
let left = mouseX + offset;
if (mouseX + tooltipWidth + offset > containerRect.width) {
  left = mouseX - tooltipWidth - offset;
}
```
Also changed `overflow: hidden` to `overflow: visible` on svg-container class.

Applied to both `PublicationsNDDStats.vue` and `PublicationsNDDTimePlot.vue`.

## Verification

- ESLint: Pass (no new errors)
- TypeScript: Pass (no type errors)
- Playwright: Pass (navigation and counts verified)
- Existing functionality preserved (tooltips, chart rendering, download buttons)

## Deviations from Plan

Additional bug fixes required beyond initial plan scope.

## Requirements Addressed

| ID | Requirement | Status |
|----|-------------|--------|
| VCOR-01 | VariantCorrelations view navigation links route to /Entities/ with correct filter parameters | Done |
| VCOR-02 | VariantCounts view navigation links route to /Entities/ with correct filter parameters | Done |

## Files Modified (Full List)

**Frontend:**
- `app/src/components/analyses/AnalysesVariantCorrelogram.vue` - Tooltip fix, filter parameter fix
- `app/src/components/analyses/AnalysesVariantCounts.vue` - Tooltip fix, filter parameter fix
- `app/src/components/analyses/PublicationsNDDTimePlot.vue` - Aggregation tick format fix, tooltip fix, smart edge positioning
- `app/src/components/analyses/PublicationsNDDStats.vue` - API-only filtering, 5-Year Avg metric, Newest Publication fix, smart edge positioning

**API:**
- `api/functions/helper-functions.R` - Added `extract_vario_filter()`, `get_entity_ids_by_vario()`
- `api/endpoints/entity_endpoints.R` - Integrated vario_id filter support
- `api/endpoints/statistics_endpoints.R` - Fixed min count parameter type conversion (string to integer)

## Commits (Full List)

| Commit | Description |
|--------|-------------|
| d673bac0 | fix(nav): update correlogram links to /Entities/ route |
| 96fe15dd | fix(nav): update variant counts links to /Entities/ route |
| c21df572 | refactor(stats): use API-only filtering for publication stats |
| 6207a4e8 | fix(api): convert min count params to integers in publication_stats |
| 3c697303 | fix(charts): prevent tooltips from being cut off at edges |

## Next Steps

- ✅ Manual verification completed via Playwright
- ✅ API filtering verified working correctly
- ✅ Tooltip edge positioning verified on both Stats and TimePlot
- Plan 56-02 addresses publication search functionality (PUB-01 to PUB-04)
