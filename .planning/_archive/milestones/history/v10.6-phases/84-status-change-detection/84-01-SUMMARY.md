---
phase: 84-status-change-detection
plan: 01
subsystem: ui
tags: [vue3, typescript, composables, vitest, change-detection]

# Dependency graph
requires:
  - phase: 83-status-creation-fix-security
    provides: Working status form (resetForm timing fix)
provides:
  - hasChanges computed property in useStatusForm
  - hasChanges computed property in useReviewForm
  - Comprehensive change detection unit tests
affects: [84-02, 84-03, 84-04]

# Tech tracking
tech-stack:
  added: []
  patterns: [loadedData ref pattern for change tracking, arraysEqual helper for array comparison]

key-files:
  created:
    - app/src/views/curate/composables/__tests__/useStatusForm.spec.ts
  modified:
    - app/src/views/curate/composables/useStatusForm.ts
    - app/src/views/curate/composables/useReviewForm.ts
    - app/src/views/curate/composables/__tests__/useReviewForm.spec.ts

key-decisions:
  - "Use exact comparison for all fields including whitespace in comments"
  - "Snapshot loaded data immediately after API load completes"
  - "Return false when no data loaded (initial state)"
  - "Use arraysEqual helper for array field comparison in useReviewForm"

patterns-established:
  - "loadedData ref pattern: Store snapshot of loaded values for comparison with current formData"
  - "hasChanges computed: Returns false if no loadedData, true if any field differs"
  - "Clear loadedData on resetForm to return to initial state"

# Metrics
duration: 3min
completed: 2026-02-10
---

# Phase 84 Plan 01: Composable Change Detection Summary

**Both useStatusForm and useReviewForm export hasChanges computed tracking all editable fields with comprehensive unit test coverage**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-10T10:37:37Z
- **Completed:** 2026-02-10T10:40:29Z
- **Tasks:** 2
- **Files modified:** 4 (2 composables + 2 test files)

## Accomplishments
- useStatusForm tracks category_id, comment, and problematic fields for changes
- useReviewForm tracks synopsis, comment, phenotypes, variationOntology, publications, and genereviews
- 14 new unit tests (8 for useStatusForm, 6 for useReviewForm)
- All existing BUG-05 tests still pass (publication preservation)
- Exact comparison detects whitespace changes in comments
- hasChanges returns false after resetForm (clean state)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add hasChanges to useStatusForm and useReviewForm composables** - `bcc2f744` (feat)
2. **Task 2: Add unit tests for change detection in both composables** - `cc26b901` (test)

## Files Created/Modified

**Created:**
- `app/src/views/curate/composables/__tests__/useStatusForm.spec.ts` - 8 change detection tests for status form

**Modified:**
- `app/src/views/curate/composables/useStatusForm.ts` - Added hasChanges computed, loadedData ref, snapshots in load methods, clear on reset
- `app/src/views/curate/composables/useReviewForm.ts` - Added hasChanges computed, loadedData ref, arraysEqual helper, snapshots in loadReviewData, clear on reset
- `app/src/views/curate/composables/__tests__/useReviewForm.spec.ts` - Added 6 change detection tests

## Decisions Made

**1. Exact comparison for all fields**
- Rationale: Users expect whitespace changes to count as modifications (trailing space in comment should trigger hasChanges)

**2. Snapshot immediately after API load**
- Rationale: loadedData must reflect the server state, not an interim reactive state

**3. Return false when no data loaded**
- Rationale: Initial state (before first load) has no baseline, so no changes possible

**4. Use arraysEqual helper in useReviewForm**
- Rationale: Array fields (phenotypes, publications, etc.) need order-preserving comparison

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - implementation was straightforward following the LlmPromptEditor pattern.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Composables ready for consumption by view components
- Plan 84-02 can now integrate hasChanges into modal save logic
- Plan 84-03 can add unsaved changes warnings using hasChanges
- Foundation complete for silent skip behavior

---
*Phase: 84-status-change-detection*
*Completed: 2026-02-10*
