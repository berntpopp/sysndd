---
phase: 36-curation-table-modernization
plan: 01
name: "Column Filters Implementation"
subsystem: curate
tags: [vue, table-filters, pagination, bootstrap-vue-next]

# Dependency graph
requires: [34, 35, 35.1]
provides: [column-filters, standardized-pagination]
affects: [36-02, 36-03]

# Tech tracking
tech-stack:
  added: []
  patterns: [column-filtering, computed-filtered-items, filter-watchers]

# File tracking
key-files:
  created: []
  modified:
    - app/src/views/curate/ApproveReview.vue
    - app/src/views/curate/ApproveStatus.vue

# Decisions from this plan
decisions:
  - id: TBL-01
    choice: "Client-side column filtering with computed property"
    why: "Existing tables load all data, consistent with current architecture"
  - id: TBL-02
    choice: "Case-insensitive partial match for user filter"
    why: "Best UX for curator workflow"
  - id: TBL-03
    choice: "Standardize pagination to [10, 25, 50, 100]"
    why: "Consistent with other modernized tables, 200 was excessive"

# Metrics
metrics:
  duration: "~10 minutes"
  completed: "2026-01-26"
---

# Phase 36 Plan 01: Column Filters Implementation Summary

**One-liner:** Added category, user, and date range column filters to ApproveReview and ApproveStatus tables with standardized [10, 25, 50, 100] pagination.

## Changes Made

### Task 1: ApproveReview.vue Column Filters (c80b585)

**Files modified:**
- `app/src/views/curate/ApproveReview.vue`

**Implementation:**
1. Added filter state variables: `categoryFilter`, `userFilter`, `dateRangeStart`, `dateRangeEnd`
2. Added `categoryOptions` computed property that derives options from `stoplights_style` keys
3. Added `columnFilteredItems` computed property:
   - Filters by `active_category` if categoryFilter set
   - Filters by `review_user_name` (case-insensitive partial match)
   - Filters by date range using Date objects
4. Added filter row UI with BFormSelect and BFormInput components
5. Added watchers to reset `currentPage` and update `totalRows` when filters change
6. Updated BTable to use `:items="columnFilteredItems"`
7. Changed pagination from `[10, 25, 50, 200]` to `[10, 25, 50, 100]`

### Task 2: ApproveStatus.vue Column Filters (b38be2b)

**Files modified:**
- `app/src/views/curate/ApproveStatus.vue`

**Implementation:**
1. Added filter state variables: `categoryFilter`, `userFilter`, `dateRangeStart`, `dateRangeEnd`
2. Added `categoryOptions` computed property that derives options from `stoplights_style` keys
3. Added `columnFilteredItems` computed property:
   - Filters by `category` field (note: ApproveStatus uses `category`, not `active_category`)
   - Filters by `status_user_name` (case-insensitive partial match)
   - Filters by date range using Date objects
4. Added filter row UI with BFormSelect and BFormInput components
5. Added watchers to reset `currentPage` and update `totalRows` when filters change
6. Updated BTable to use `:items="columnFilteredItems"`
7. Changed pagination from `[10, 25, 50, 200]` to `[10, 25, 50, 100]`

## Verification Results

1. `npm run lint --prefix app` passes (no new errors, only pre-existing warnings)
2. Both views have filter rows with Category dropdown, User input, From Date, To Date
3. Both views show pagination options [10, 25, 50, 100]
4. Column filters implemented with proper computed properties
5. Global search (`:filter` prop) preserved alongside column filters
6. Pagination resets when filters change (watchers implemented)

## Deviations from Plan

None - plan executed exactly as written.

## Decisions Made

| ID | Decision | Rationale |
|----|----------|-----------|
| TBL-01 | Client-side filtering via computed property | Consistent with existing table architecture |
| TBL-02 | Case-insensitive partial match for user filter | Better UX for curator workflow |
| TBL-03 | Pagination standardized to [10, 25, 50, 100] | 200 was excessive, aligns with other tables |

## Technical Notes

### Filter Architecture

Both tables now use a two-layer filtering approach:
1. **Column filters** (category, user, date) - Applied via `columnFilteredItems` computed
2. **Global search** (`:filter` prop) - Applied by BTable internally on the filtered items

This stacking means a curator can first narrow by category, then search within that subset.

### Date Filtering Logic

Date filtering uses `substring(0, 10)` to extract YYYY-MM-DD from datetime strings, then creates Date objects for comparison. This handles both full datetime strings and date-only strings.

## Commits

| Hash | Type | Description |
|------|------|-------------|
| c80b585 | feat | Add column filters to ApproveReview.vue |
| b38be2b | feat | Add column filters to ApproveStatus.vue |

## Next Phase Readiness

Ready for Plan 36-02: Table Configuration Panel
- Both tables now have the filter infrastructure in place
- Pattern established can be replicated for ManageReReview.vue
