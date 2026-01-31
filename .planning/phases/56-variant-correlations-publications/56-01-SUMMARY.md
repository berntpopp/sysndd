---
phase: 56-variant-correlations-publications
plan: 01
subsystem: frontend-analyses
tags: [vue, d3, navigation, routing, bugfix]

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

**Fix:** Route to `/Entities/` with the `modifier_variant_id` filter parameter, which correctly filters the Entities table to show only entities with the selected variant(s).

**Filter Parameter Format:**
- Single variant: `all(modifier_variant_id,{vario_id})`
- Variant combination: `all(modifier_variant_id,{x_vario_id},{y_vario_id})`

## Verification

- ESLint: Pass (no new errors)
- TypeScript: Pass (no type errors)
- Existing functionality preserved (tooltips, chart rendering, download buttons)

## Deviations from Plan

None - plan executed exactly as written.

## Requirements Addressed

| ID | Requirement | Status |
|----|-------------|--------|
| VCOR-01 | VariantCorrelations view navigation links route to /Entities/ with correct filter parameters | Done |
| VCOR-02 | VariantCounts view navigation links route to /Entities/ with correct filter parameters | Done |

## Next Steps

- Manual verification recommended: Start dev server and click chart elements to confirm navigation works
- Plan 56-02 will address publication search functionality (PUB-01 to PUB-04)
