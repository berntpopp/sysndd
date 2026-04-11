---
phase: 84-status-change-detection
plan: 02
subsystem: ui
tags: [vue3, typescript, bootstrap-vue-next, change-detection, curation]

# Dependency graph
requires:
  - phase: 84-status-change-detection
    plan: 01
    provides: hasChanges computed in useStatusForm and useReviewForm composables
provides:
  - ModifyEntity.vue wired with change detection for both status and review forms
  - Silent skip on save when no changes detected (prevents unnecessary API calls)
  - Unsaved changes warning dialog on modal close
  - Local change detection for review form with array comparison
affects: [85-ghost-entity-cleanup]

# Tech tracking
tech-stack:
  added: []
  patterns: [local-change-detection-options-api, composable-change-detection-integration]

key-files:
  created: []
  modified:
    - app/src/views/curate/ModifyEntity.vue

key-decisions:
  - "Wire hasChanges from useStatusForm composable into ModifyEntity status modal"
  - "Implement local change detection for review form (no composable) with computed property"
  - "Use sorted array comparison for phenotype/variation/publication arrays (order-independent)"

patterns-established:
  - "Change detection pattern: composable-based for status form, local computed for review form"
  - "Silent skip pattern: check hasChanges before setting submitting state, hide modal directly"
  - "Unsaved changes warning: check hasChanges && !submitting in @hide handler"

# Metrics
duration: 2.5min
completed: 2026-02-10
---

# Phase 84 Plan 02: ModifyEntity Change Detection Summary

**ModifyEntity wired with change detection for both status (composable-based) and review (local Options API) forms, preventing unnecessary status/review creation on unchanged saves**

## Performance

- **Duration:** 2.5 min
- **Started:** 2026-02-10T10:44:48Z
- **Completed:** 2026-02-10T10:47:15Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Status form wired to use hasChanges from useStatusForm composable with silent skip and unsaved changes warning
- Review form implements local hasReviewChanges computed property with array comparison logic
- Both modals now skip API call and close silently when no changes detected
- Unsaved changes confirmation dialog prevents accidental data loss on close

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire hasChanges into ModifyEntity status form (composable-based)** - `d775849e` (feat)
2. **Task 2: Add local change detection to ModifyEntity review form (Options API)** - `3a7046cb` (feat)

## Files Created/Modified

- `app/src/views/curate/ModifyEntity.vue` - Added change detection for both status and review forms, silent skip guards, unsaved changes warnings

## Decisions Made

**D84-02-01: Wire composable-provided hasChanges for status form**
- Rationale: Status form already uses useStatusForm composable (Plan 84-01 added hasChanges), just needed wiring

**D84-02-02: Implement local change detection for review form**
- Rationale: Review form does NOT use composable (raw Review class + direct API calls), requires local computed property with manual snapshot

**D84-02-03: Use sorted array comparison for review arrays**
- Rationale: Order shouldn't matter for phenotype/variation/publication changes (user may reorder in TreeMultiSelect without changing content)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - straightforward implementation following established patterns from Plan 84-03 (ApproveReview/ApproveStatus).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**All Phase 84 plans complete:**
- 84-01: Composables have change detection
- 84-02: ModifyEntity wired (this plan)
- 84-03: ApproveReview & ApproveStatus wired

**Ready for Phase 85 (Ghost Entity Cleanup):**
- Change detection prevents creation of unnecessary status records
- Curator UX improved with silent skip and unsaved changes warnings
- No regressions in existing tests (244 tests passing)

**Technical foundation solid:**
- Composable pattern for reusable forms (status)
- Local computed pattern for one-off forms (review)
- Silent skip prevents unnecessary database writes
- Unsaved changes warning prevents accidental data loss

---
*Phase: 84-status-change-detection*
*Completed: 2026-02-10*
