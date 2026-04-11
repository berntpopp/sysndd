---
phase: 10-vue3-core-migration
plan: 04
subsystem: ui
tags: [vue3, pinia, eventbus-removal, cross-component-communication]

# Dependency graph
requires:
  - phase: 10-vue3-core-migration
    plan: 02
    provides: Vue 3 with Pinia installed and configured
provides:
  - Pinia UI store for cross-component scrollbar events
  - All components using Pinia store actions instead of EventBus
  - EventBus pattern fully removed from codebase
affects: [10-05, 10-06, all-subsequent-vue3-plans]

# Tech tracking
tech-stack:
  added: []
  removed: [eventBus.js, EventBus pattern]
  patterns: [Pinia store for cross-component communication, Counter pattern for watcher triggering]

key-files:
  created: [app/src/stores/ui.js]
  modified: [
    app/src/App.vue,
    app/src/components/analyses/PublicationsNDDTable.vue,
    app/src/components/analyses/PubtatorNDDGenes.vue,
    app/src/components/analyses/PubtatorNDDTable.vue,
    app/src/components/tables/TablesEntities.vue,
    app/src/components/tables/TablesGenes.vue,
    app/src/components/tables/TablesLogs.vue,
    app/src/components/tables/TablesPhenotypes.vue,
    app/src/views/admin/ManageOntology.vue,
    app/src/views/admin/ManageUser.vue,
    app/src/views/curate/ApproveReview.vue,
    app/src/views/curate/ApproveStatus.vue,
    app/src/views/curate/ApproveUser.vue,
    app/src/views/curate/ManageReReview.vue,
    app/src/views/tables/Panels.vue
  ]

key-decisions:
  - "Used counter pattern (increment) for scrollbarUpdateTrigger to guarantee watcher fires on every update"
  - "Kept useUiStore() call inside methods in Options API components (auto-cached by Pinia)"
  - "Did not touch $root.$emit patterns (Bootstrap-Vue modals, deferred to Phase 11)"

patterns-established:
  - "Pinia stores for all cross-component communication (no mitt or other event libraries)"
  - "Counter pattern for triggering watchers reliably"
  - "UI store for cross-cutting UI concerns (scrollbar, future: loading states, toasts)"

# Metrics
duration: 6min
completed: 2026-01-22
---

# Phase 10 Plan 04: EventBus to Pinia Migration Summary

**EventBus pattern fully replaced with Pinia store-based cross-component communication for scrollbar updates across 14 components**

## Performance

- **Duration:** 6 min
- **Started:** 2026-01-22T21:58:34Z
- **Completed:** 2026-01-22T22:04:54Z
- **Tasks:** 3
- **Files modified:** 15 (1 created, 14 updated, 1 deleted)

## Accomplishments

- Created Pinia UI store with scrollbarUpdateTrigger state and requestScrollbarUpdate action
- Migrated App.vue from EventBus listener to Pinia watcher pattern
- Updated all 14 emitting components to use Pinia store action
- Removed eventBus.js file (no longer needed)
- Build completes successfully with all changes
- Zero EventBus references remaining in codebase (except comments)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Pinia UI store** - `805b6fc` (feat)
2. **Task 2: Update App.vue to listen via Pinia** - `99953c5` (feat)
3. **Task 3: Replace EventBus in 14 components** - `2b4ff6c` (feat)
4. **Cleanup: Remove eventBus.js** - `f7ca0cf` (chore)

## Files Created/Modified

**Created:**
- `app/src/stores/ui.js` - Pinia store with scrollbarUpdateTrigger state and requestScrollbarUpdate action

**Modified:**
- `app/src/App.vue` - Replaced EventBus listener with Pinia watcher
- 4 table components: TablesEntities, TablesGenes, TablesLogs, TablesPhenotypes
- 3 analysis components: PublicationsNDDTable, PubtatorNDDGenes, PubtatorNDDTable
- 2 admin views: ManageOntology, ManageUser
- 4 curation views: ApproveReview, ApproveStatus, ApproveUser, ManageReReview
- 1 table view: Panels

**Deleted:**
- `app/src/assets/js/eventBus.js` - No longer needed after migration

## Decisions Made

1. **Counter pattern for scrollbarUpdateTrigger**
   - Incrementing a number guarantees Vue watchers fire on every update
   - More reliable than boolean toggle or object mutation
   - Simple and debuggable via Vue DevTools

2. **useUiStore() inside methods**
   - Options API components call useUiStore() directly in methods
   - Pinia automatically caches the store instance (singleton pattern)
   - No need to create in data() or setup() for simple action calls

3. **Did not touch $root.$emit patterns**
   - These are for Bootstrap-Vue modal communication
   - Will be replaced in Phase 11 (Bootstrap-Vue-Next migration)
   - Keeping them separate avoids scope creep

4. **UI store for cross-cutting concerns**
   - Named 'ui' not 'scrollbar' for future extensibility
   - Can add loading states, toast notifications, etc. later
   - Follows Pinia best practice of domain-based stores

## Deviations from Plan

None - plan executed exactly as written. All 14 files identified in pre-audit were updated successfully.

## Issues Encountered

None - migration was straightforward with clear patterns.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Phase 10-05 (Lifecycle hooks and reactivity patterns):**
- EventBus pattern fully removed
- Pinia store established for cross-component communication
- No compat warnings related to EventBus
- Pattern can be replicated for other event bus usages if discovered

**Testing recommendation:**
- Manual smoke test: Navigate to /Entities, /Genes, /Panels pages
- Verify scrollbar updates correctly when table data loads
- Check Vue DevTools for Pinia store state changes

**No blockers** - EventBus migration complete, ready for next plan.

---
*Phase: 10-vue3-core-migration*
*Completed: 2026-01-22*
