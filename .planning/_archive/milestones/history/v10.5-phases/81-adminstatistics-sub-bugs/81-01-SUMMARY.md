---
phase: 81-adminstatistics-sub-bugs
plan: 01
subsystem: api, admin-ui
tags: r, plumber, vue, typescript, dplyr, re-review, statistics, leaderboard

# Dependency graph
requires:
  - phase: 80-foundation-fixes
    provides: Foundation database and API stability
provides:
  - sync_rereview_approval() shared utility for transactional re-review flag updates
  - Refactored re-review endpoint delegating to repository functions
  - Three-segment leaderboard chart showing all assigned re-review states
  - Dynamic denominator for re-review completion percentage
affects: [admin-ui, statistics, re-review-workflow]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Shared sync utilities called within repository transactions
    - Repository delegation pattern for endpoint simplification
    - Three-segment stacked bar charts for workflow visualization

key-files:
  created:
    - api/functions/re-review-sync.R
    - api/tests/testthat/test-integration-rereview-sync.R
  modified:
    - api/functions/review-repository.R
    - api/functions/status-repository.R
    - api/endpoints/re_review_endpoints.R
    - api/start_sysndd_api.R
    - api/endpoints/statistics_endpoints.R
    - app/src/views/admin/components/charts/ReReviewBarChart.vue
    - app/src/views/admin/AdminStatistics.vue

key-decisions:
  - "sync_rereview_approval() uses transaction-aware conn parameter to participate in caller's transaction"
  - "Re-review endpoint delegates to review_approve() and status_approve() for single source of truth"
  - "Leaderboard includes all assigned re-reviews (not just submitted) to show total workload"
  - "Three-segment chart uses Math.max(0, ...) to clamp negative values from race conditions"
  - "Replace hardcoded 3650 denominator with dynamic COUNT query for accurate percentage"

patterns-established:
  - "Sync utilities: Accept conn parameter, use db_execute_statement for transaction participation"
  - "Endpoint delegation: Complex approval logic lives in repositories, endpoints are thin wrappers"
  - "Chart data segmentation: total_assigned - submitted_count = not submitted, submitted_count - approved_count = pending"

# Metrics
duration: 4min
completed: 2026-02-08
---

# Phase 81 Plan 01: Re-Review Approval Sync & Leaderboard Summary

**Re-review approval flag now syncs atomically with review/status approvals, and leaderboard displays three-segment bars showing Approved, Pending Review, and Not Yet Submitted work.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-08T21:35:58Z
- **Completed:** 2026-02-08T21:39:51Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Created `sync_rereview_approval()` utility called transactionally from both `review_approve()` and `status_approve()`
- Refactored re-review approve endpoint from 80 lines of inline SQL to clean delegation pattern (zero SQL)
- Updated leaderboard query to return `total_assigned`, `submitted_count`, `approved_count` for all assigned re-reviews
- Added three-segment stacked bar chart with clamped non-negative values
- Replaced hardcoded 3650 denominator with dynamic COUNT query for accurate percentage

## Task Commits

Each task was committed atomically:

1. **Task 1: Create sync utility, integrate into repository transactions, and refactor re-review endpoint** - `6ad955d7` (feat)
2. **Task 2: Update leaderboard query and three-segment chart** - `1e2931f2` (feat)

## Files Created/Modified

- `api/functions/re-review-sync.R` - Shared utility for syncing re_review_approved flag atomically within transactions
- `api/functions/review-repository.R` - Added sync_rereview_approval() call in review_approve() transaction block
- `api/functions/status-repository.R` - Added sync_rereview_approval() call in status_approve() transaction block
- `api/endpoints/re_review_endpoints.R` - Refactored approve endpoint to delegate to repository functions
- `api/start_sysndd_api.R` - Source re-review-sync.R after status-repository.R
- `api/endpoints/statistics_endpoints.R` - Removed submitted-only filter, added total_assigned, .groups = "drop", dynamic denominator
- `app/src/views/admin/components/charts/ReReviewBarChart.vue` - Three-segment chart with Approved/Pending/Not Yet Submitted
- `app/src/views/admin/AdminStatistics.vue` - Updated interface to include total_assigned
- `api/tests/testthat/test-integration-rereview-sync.R` - Integration tests for sync utility

## Decisions Made

**SYNC-01:** sync_rereview_approval() accepts `conn = pool` parameter for transaction participation
- **Rationale:** Enables atomic updates within caller's transaction, consistent with other repository functions
- **Impact:** Re-review flag updates are guaranteed consistent with review/status approvals

**SYNC-02:** Re-review approve endpoint delegates to review_approve() and status_approve()
- **Rationale:** Single source of truth for approval logic, eliminates duplicate SQL
- **Impact:** Reduced endpoint from 80 lines to 30, automatic sync via repository calls

**SYNC-03:** Use `dplyr::select()` instead of bare `select()` in statistics endpoint
- **Rationale:** biomaRt package masks dplyr::select(), causing namespace conflicts
- **Impact:** Prevents future runtime errors from package loading order

**SYNC-04:** Leaderboard query includes all assigned re-reviews (not just submitted)
- **Rationale:** Shows complete workload per reviewer, not just what's been submitted
- **Impact:** Chart now displays three segments: approved, pending review, not yet submitted

**SYNC-05:** Dynamic denominator query replaces hardcoded 3650
- **Rationale:** Accurate percentage calculation as pipeline size changes
- **Impact:** Percentage finished metric now reflects actual total re-reviews in pipeline

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Re-review approval sync is complete and transactional
- Leaderboard accurately reflects all re-review states
- Ready for remaining AdminStatistics bug fixes (KPIs, charts)
- No blockers for Phase 81 Plans 02-03

---
*Phase: 81-adminstatistics-sub-bugs*
*Completed: 2026-02-08*
