---
phase: 86-dismiss-autodismiss-pending
plan: 01
subsystem: backend, frontend
tags: [dismiss, auto-dismiss, pending-queue, approval, curation-ux, status, review]

# Dependency graph
requires:
  - phase: 84-status-change-detection
    provides: Change detection composables and approve modal enhancements
  - phase: 85-ghost-entity-cleanup-prevention
    provides: Clean entity creation flow
provides:
  - Dismiss/reject capability for pending statuses and reviews
  - Auto-dismiss sibling pending items when one is approved
  - Duplicate warning icons for entities with multiple pending items
  - Enhanced approve modals with auto-dismiss info alerts
  - Integration test suite (40 assertions) for dismiss/auto-dismiss logic
affects: [approval workflows, pending queue management, curation UX]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Use existing approving_user_id column as dismiss marker (no schema changes)"
    - "dbplyr inline conditional filter: {if (!flag) filter(., is.na(col)) else .}"
    - "Auto-dismiss siblings via UPDATE with NOT IN (approved_ids) clause"

key-files:
  created:
    - api/tests/testthat/test-integration-dismiss-autodismiss.R
  modified:
    - api/endpoints/status_endpoints.R
    - api/endpoints/review_endpoints.R
    - api/services/approval-service.R
    - api/functions/status-repository.R
    - api/functions/review-repository.R
    - app/src/views/curate/ApproveStatus.vue
    - app/src/views/curate/ApproveReview.vue

key-decisions:
  - "Use approving_user_id as dismiss marker — no schema migration needed"
  - "Filter dismissed items via is.na(approving_user_id) in all pending queries"
  - "Auto-dismiss only same-entity siblings, preserving cross-entity isolation"

patterns-established:
  - "Pending state: status_approved=0 AND approving_user_id IS NULL"
  - "Dismissed state: status_approved=0 AND approving_user_id IS NOT NULL"
  - "Auto-dismiss UPDATE pattern with entity_id IN + status_id NOT IN"

# Metrics
duration: ~45min
completed: 2026-02-10
---

# Phase 86 Plan 01: Dismiss & Auto-Dismiss Pending Statuses/Reviews Summary

**Curators can now dismiss unwanted pending statuses/reviews and auto-clean siblings on approval. No schema changes — uses existing approving_user_id column as dismiss marker.**

## Performance

- **Duration:** ~45 min
- **Completed:** 2026-02-10
- **Tasks:** 7
- **Files modified:** 7
- **Files created:** 1

## Accomplishments

### Backend (5 files)
- **Pending filter**: Added `is.na(approving_user_id)` filter to status_endpoints.R, review_endpoints.R, and approval-service.R so dismissed items no longer appear in pending queues
- **Auto-dismiss siblings**: Added UPDATE statements in status-repository.R and review-repository.R that set `approving_user_id` on remaining pending siblings when one is approved
- **Integration tests**: Created test-integration-dismiss-autodismiss.R with 40 assertions covering: dismiss state, pending filter, auto-dismiss siblings, approve-all skip, cross-entity isolation, re-submission after dismiss

### Frontend (2 files)
- **ApproveStatus.vue**: Added dismiss button (red X, `bi-x-circle`), dismiss confirmation modal (danger theme), duplicate warning icon (yellow triangle), auto-dismiss info alert in approve modal, updated legend
- **ApproveReview.vue**: Same dismiss pattern — button, modal, methods, auto-dismiss warning in approve modal, updated legend

### Verification
- **TypeScript type-check**: PASS
- **ESLint**: PASS
- **Backend integration tests**: 40/40 PASS (FAIL 0, WARN 0, SKIP 0, PASS 40)
- **E2E Playwright tests (ApproveStatus)**:
  - Initial: 10 statuses, entity 304 with 6 rows + duplicate warnings
  - Dismiss one: count 10→9, row removed
  - Approve one with auto-dismiss: count 9→4, all entity 304 rows gone
- **E2E Playwright tests (ApproveReview)**:
  - Initial: 8 reviews, entity 1181 with 4 rows + duplicate warnings
  - Dismiss one: count 8→7, row removed
  - Approve one with auto-dismiss: count 7→4, all entity 1181 rows gone

## Files Created/Modified

### Created
- `api/tests/testthat/test-integration-dismiss-autodismiss.R` — 380+ lines, 11 test cases, 40 assertions

### Modified
- `api/endpoints/status_endpoints.R` — Add `is.na(approving_user_id)` filter for pending statuses
- `api/endpoints/review_endpoints.R` — Add `is.na(approving_user_id)` filter for pending reviews
- `api/services/approval-service.R` — Filter dismissed from "approve all" batch queries (both status and review)
- `api/functions/status-repository.R` — Auto-dismiss sibling statuses on approve
- `api/functions/review-repository.R` — Auto-dismiss sibling reviews on approve
- `app/src/views/curate/ApproveStatus.vue` — Dismiss button/modal, duplicate warning, enhanced approve modal
- `app/src/views/curate/ApproveReview.vue` — Dismiss button/modal, auto-dismiss warning

## Decisions Made

**D86-01-01:** Use existing `approving_user_id` column as dismiss marker — no schema migration needed
- **Rationale:** The column already exists and the reject API path already sets it. Adding `IS NULL` to pending queries is the minimal change to make the state model work.

**D86-01-02:** Auto-dismiss only same-entity siblings
- **Rationale:** When approving one status for entity A, only other pending statuses for entity A should be auto-dismissed. Pending items for other entities must not be affected.

**D86-01-03:** Show auto-dismiss warning in approve modal only when entity has duplicates
- **Rationale:** The warning is relevant context when multiple pending items exist. For single pending items, auto-dismiss has no effect and the warning would be confusing.

## Deviations from Plan

None — plan executed as designed.

## Issues Encountered

**Auth token retrieval**: Could not authenticate via curl to create test data through the API. Resolved by inserting test data directly into the database via R scripts executed in the API container.

**Review table schema**: Initial attempt used `category_id` column (exists in status table but not review table). Corrected to use `synopsis` column for review inserts.

## User Setup Required

None — restart API container to pick up backend changes (`docker compose restart api`).

## Next Phase Readiness

The dismiss/auto-dismiss feature is complete and tested. The pending queue management is now fully functional:
- Curators can dismiss unwanted items individually
- Approving one item auto-cleans siblings for the same entity
- Re-submitted items after dismissal appear normally (NULL approving_user_id)
- "Approve All" correctly skips dismissed items

---
*Phase: 86-dismiss-autodismiss-pending*
*Completed: 2026-02-10*
