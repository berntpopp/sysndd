---
phase: 37-form-modernization
plan: 03
subsystem: ui
tags: [draft-persistence, localStorage, form-state, modal-events, vue-composables]

# Dependency graph
requires:
  - phase: 37-01
    provides: useReviewForm composable with form state management
  - phase: 37-02
    provides: useStatusForm composable with form state management
provides:
  - Draft auto-save with 2s debounce for review and status forms
  - Draft restoration prompts when opening forms with existing drafts
  - Modal @show handlers that reset form state (FORM-07)
  - Draft save indicator in Review.vue modal
affects: [38-re-review-system-overhaul]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - useFormDraft composable integration
    - Modal @show event for form reset
    - window.confirm for draft restoration prompt

key-files:
  created: []
  modified:
    - app/src/views/curate/composables/useReviewForm.ts
    - app/src/views/curate/composables/useStatusForm.ts
    - app/src/views/review/Review.vue
    - app/src/views/curate/ModifyEntity.vue

key-decisions:
  - "Draft restoration via window.confirm for simplicity"
  - "Reset form on @show event (before data load) to prevent stale data flash"

patterns-established:
  - "Draft persistence pattern: composable calls scheduleSave on watch, clearDraft on submit"
  - "Modal @show handler pattern: reset form state before loading new data"

# Metrics
duration: 2min
completed: 2026-01-26
---

# Phase 37 Plan 03: Draft Persistence Summary

**Draft auto-save with 2s debounce integrated into review/status forms with restoration prompts and modal @show reset handlers (FORM-07)**

## Performance

- **Duration:** 2 min
- **Started:** 2026-01-26T19:48:36Z
- **Completed:** 2026-01-26T19:50:27Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Draft persistence integrated into useReviewForm with auto-save on meaningful content changes
- Draft persistence integrated into useStatusForm with auto-save on meaningful content changes
- Modal @show handlers added to all 6 modals (Review.vue: 2, ModifyEntity.vue: 4)
- Draft restoration prompts using window.confirm before loading server data
- Draft save indicator added to Review.vue modal showing "Saving draft..." and "Draft saved [time]"

## Task Commits

Each task was committed atomically:

1. **Task 1: Integrate useFormDraft into useReviewForm** - `b90df9c` (feat)
2. **Task 2: Integrate useFormDraft into useStatusForm** - `76c6291` (feat)
3. **Task 3: Add draft restoration prompts and @show handlers to modals** - `d25271b` (feat)

## Files Created/Modified

- `app/src/views/curate/composables/useReviewForm.ts` - Added useFormDraft integration, watch for auto-save, restoreFromDraft method
- `app/src/views/curate/composables/useStatusForm.ts` - Added useFormDraft integration, watch for auto-save, restoreFromDraft method
- `app/src/views/review/Review.vue` - Added @show handlers, draft restoration prompts, draft save indicator
- `app/src/views/curate/ModifyEntity.vue` - Added @show handlers for all 4 modals (rename, deactivate, review, status)

## Decisions Made

- **Draft restoration via window.confirm**: Simple synchronous prompt for draft restoration - adequate for curator workflow, no need for toast/modal complexity
- **Reset form on @show event**: Form state reset happens immediately on modal show (before async data load) to ensure no stale data flash (FORM-07)
- **Meaningful content threshold**: Only save drafts when form has meaningful content (synopsis/phenotypes/publications for review, category_id/comment for status)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fix ESLint error in useReviewForm**
- **Found during:** Task 3 verification
- **Issue:** Unnecessary try/catch wrapper flagged as lint error (no-useless-catch)
- **Fix:** Removed try/catch wrapper, let error bubble up naturally
- **Files modified:** app/src/views/curate/composables/useReviewForm.ts
- **Verification:** `npx eslint` passes with 0 errors
- **Committed in:** d25271b (Task 3 commit)

**2. [Rule 3 - Blocking] Fix unused variable warnings**
- **Found during:** Task 3 verification
- **Issue:** `saveDraft` destructured but never used directly (scheduleSave calls it internally)
- **Fix:** Removed `saveDraft` from destructuring in both composables
- **Files modified:** useReviewForm.ts, useStatusForm.ts
- **Verification:** No unused variable warnings
- **Committed in:** d25271b (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (2 blocking - lint errors)
**Impact on plan:** Both auto-fixes necessary for lint compliance. No scope creep.

## Issues Encountered

None - plan executed with only lint fixes needed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Form modernization complete for Review.vue and ModifyEntity.vue
- Draft persistence working for both review and status forms
- Ready for Phase 38: Re-Review System Overhaul
- All FORM-07 requirements met (modal state reset on @show)

---
*Phase: 37-form-modernization*
*Completed: 2026-01-26*
