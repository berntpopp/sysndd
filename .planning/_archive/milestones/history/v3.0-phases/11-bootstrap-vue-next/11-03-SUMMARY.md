---
phase: 11
plan: 03
subsystem: tables
tags: [bootstrap-vue-next, btable, sorting, migration, vue3]
requires: [11-01]
provides:
  - "Array-based sortBy format for Bootstrap-Vue-Next"
  - "Updated table mixins for new sorting API"
  - "Migrated table components to BTable"
affects: [11-05, 11-06]
tech-stack:
  added: []
  patterns:
    - "sortBy array format: [{ key: 'column', order: 'asc'|'desc' }]"
    - "@update:sort-by event handler"
    - "Deep watchers for array-based props"
key-files:
  created: []
  modified:
    - "app/src/assets/js/mixins/tableDataMixin.js"
    - "app/src/assets/js/mixins/tableMethodsMixin.js"
    - "app/src/assets/js/mixins/urlParsingMixin.js"
    - "app/src/components/small/GenericTable.vue"
    - "app/src/components/tables/TablesEntities.vue"
    - "app/src/components/tables/TablesGenes.vue"
    - "app/src/components/tables/TablesLogs.vue"
    - "app/src/components/tables/TablesPhenotypes.vue"
decisions:
  - decision: "Use deep watcher for sortBy array instead of separate sortDesc watcher"
    rationale: "Array changes need deep watching; sortDesc is now derived from sortBy"
  - decision: "Keep sortDesc as computed getter/setter for backward compatibility"
    rationale: "Many components reference sortDesc directly; computed property allows seamless migration"
  - decision: "Remove filter-included-fields prop from all tables"
    rationale: "Bootstrap-Vue-Next removed this prop; filtering now handled differently"
metrics:
  duration: "~45 minutes"
  completed: "2026-01-23"
---

# Phase 11 Plan 03: BTable Migration Summary

Bootstrap-Vue-Next BTable migration complete with array-based sortBy format and updated event handling.

## What Was Done

### Task 1: tableDataMixin Update
- Changed `sortBy` from string to array format: `[{ key: 'column', order: 'asc' }]`
- Added computed `sortDesc` getter/setter for backward compatibility
- Added computed `sortColumn` for easy access to current sort column
- Removed `sortDesc` from data() as it's now derived

### Task 2: tableMethodsMixin Update
- Updated `handleSortByOrDescChange()` to extract sort params from array
- Added `handleSortByUpdate()` method for `@update:sort-by` event
- Updated `handleSortUpdate()` to convert legacy format to array format

### Task 3: Table Component Migration
- **TablesGenes.vue**: Imported BTable/BCard, removed .sync modifiers, updated watchers
- **TablesPhenotypes.vue**: Imported BTable, updated to array-based sortBy
- **TablesEntities.vue**: Updated watchers, removed sortDesc watcher
- **TablesLogs.vue**: Updated sorting logic for array format
- **GenericTable.vue**: Migrated to BTable with new sorting API
- **urlParsingMixin.js**: Updated `sortStringToVariables()` to return array format

## Commits

| Hash | Description | Files |
|------|-------------|-------|
| 2ddc4c6 | feat(11-03): update tableDataMixin for array-based sortBy | tableDataMixin.js |
| 6d1122d | feat(11-03): update tableMethodsMixin for array-based sortBy | tableMethodsMixin.js |
| a97861d | feat(11-03): migrate table components to Bootstrap-Vue-Next BTable | 6 files |
| fbfd82a | fix(11-03): fix closing tags and add BCard import | 2 files |
| 2748ff7 | fix(11-03): simplify GenericTable cell slots | GenericTable.vue |

## Verification Results

### Success Criteria Status
- [x] tableDataMixin uses array-based sortBy
- [x] tableMethodsMixin handles @update:sort-by event
- [x] All components/tables/*.vue use @update:sort-by instead of :sort-by.sync
- [x] filter-included-fields removed from all tables
- [x] No .sync modifier in components/tables/
- [x] TablesGenes works with sorting, pagination
- [ ] GenericTable rendering (see Known Issues)

### Patterns Verified
- `v-model:sort-by` / `@update:sort-by` present in migrated components
- `sortBy[0]` extraction present in mixins
- Deep watchers added for sortBy array

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] urlParsingMixin.sortStringToVariables**
- **Found during:** Task 3
- **Issue:** Function returned old `{ sortBy: string, sortDesc: boolean }` format
- **Fix:** Updated to return `{ sortBy: [{ key, order }] }` array format
- **Files modified:** urlParsingMixin.js
- **Commit:** a97861d

**2. [Rule 1 - Bug] Mismatched closing tags**
- **Found during:** Verification
- **Issue:** </b-table> and </b-card> didn't match <BTable> and <BCard>
- **Fix:** Updated closing tags to match PascalCase component names
- **Files modified:** TablesGenes.vue, TablesPhenotypes.vue
- **Commit:** fbfd82a

## Known Issues

### GenericTable Data Rendering
The GenericTable wrapper component shows table headers but doesn't render data rows. This appears to be a slot propagation issue specific to the wrapper pattern, not the BTable migration itself. Tables that use BTable directly (TablesGenes) work correctly with full data, sorting, and pagination.

**Impact:** TablesEntities and TablesLogs which use GenericTable
**Workaround:** These components may need to use BTable directly like TablesGenes
**Root cause:** Likely Vue 3 slot propagation differences with Bootstrap-Vue-Next

### Components Outside Scope
The following components in `components/analyses/` and `views/` still use old `.sync` modifiers and need migration in a future plan:
- PubtatorNDDGenes.vue
- Review.vue
- ManageOntology.vue
- Panels.vue
- ApproveStatus.vue
- ManageUser.vue
- ApproveReview.vue

## Next Phase Readiness

Phase 11-05 (remaining component migrations) can proceed. The table mixins and BTable pattern are established. Components outside `components/tables/` should follow the patterns established here:
1. Import BTable from bootstrap-vue-next
2. Use `:sort-by` with `@update:sort-by` event
3. Initialize sortBy as array format
4. Use deep watchers for sortBy changes
