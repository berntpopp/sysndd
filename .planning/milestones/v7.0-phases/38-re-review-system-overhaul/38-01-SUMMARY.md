---
phase: 38-re-review-system-overhaul
plan: 01
subsystem: api
tags: [r, plumber, service-layer, batch-management, transactions, glue-sql]

# Dependency graph
requires:
  - phase: 18-24 (v4 Backend Overhaul)
    provides: db-helpers.R with db_with_transaction, db_execute_query, db_execute_statement
  - phase: 37-form-modernization
    provides: Service layer patterns from entity-service.R, status-service.R
provides:
  - Re-review batch management service layer
  - Dynamic criteria-based batch creation
  - Entity overlap prevention across active batches
  - Gene-specific assignment workflow (entity_assign)
  - Batch recalculation before assignment (batch_recalculate)
affects: [38-02, 38-03, 38-04, re-review-endpoints, manage-re-review-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Service function with pool dependency injection
    - db_with_transaction for multi-step atomicity
    - Dynamic WHERE clause builder with parameterized queries
    - Entity exclusion query for overlap prevention

key-files:
  created:
    - api/services/re-review-service.R
  modified:
    - api/start_sysndd_api.R

key-decisions:
  - "Parameterized queries with build_batch_params() helper for safe SQL"
  - "Entity overlap prevention via exclusion subquery in all batch operations"
  - "Batch recalculation only allowed for unassigned batches"
  - "Soft delete via assignment removal, preserving entity_connect audit trail"

patterns-established:
  - "build_batch_where_clause/build_batch_params pattern for dynamic SQL"
  - "Transaction-wrapped batch operations with db_with_transaction"
  - "Entity validation before batch assignment"

# Metrics
duration: 12min
completed: 2026-01-26
---

# Phase 38 Plan 01: Re-Review Service Summary

**Re-review batch management service with 8 functions for dynamic batch creation, assignment, reassignment, gene-specific assignment, and batch recalculation using transaction-safe operations**

## Performance

- **Duration:** 12 min
- **Started:** 2026-01-26T10:00:00Z
- **Completed:** 2026-01-26T10:12:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created re-review-service.R with 8 batch management functions (778 lines)
- Implemented dynamic WHERE clause builder for criteria-based entity selection
- Added entity overlap prevention to exclude entities in active batches
- Implemented entity_assign() for gene-specific user assignment (RRV-03, RRV-06)
- Implemented batch_recalculate() for updating batch contents before assignment (RRV-05)
- All multi-step operations use db_with_transaction() for atomicity

## Task Commits

Each task was committed atomically:

1. **Task 1: Create re-review-service.R with batch management functions** - `6867620` (feat)
2. **Task 2: Source re-review-service.R in API startup** - `12a84cb` (chore)

## Files Created/Modified
- `api/services/re-review-service.R` - Batch management business logic with 8 exported functions
- `api/start_sysndd_api.R` - Added source() call for new service

## Functions Implemented

| Function | Purpose | Transaction-safe |
|----------|---------|------------------|
| `build_batch_where_clause()` | Build dynamic WHERE clause from criteria | N/A |
| `build_batch_params()` | Build parameter list matching WHERE clause | N/A |
| `batch_preview()` | Preview matching entities without creating batch | No |
| `batch_create()` | Create batch with criteria-based entity selection | Yes |
| `batch_assign()` | Assign unassigned batch to user | No |
| `batch_reassign()` | Reassign batch to different user | No |
| `batch_archive()` | Soft delete batch (remove assignment) | No |
| `entity_assign()` | Assign specific entities to user | Yes |
| `batch_recalculate()` | Recalculate batch entities with new criteria | Yes |

## Decisions Made
- **Parameterized query approach:** Used build_batch_params() helper to create ordered parameter list matching WHERE clause placeholders, avoiding SQL injection via glue_sql
- **Entity overlap prevention:** All batch creation/recalculation queries exclude entities already in active batches using subquery on re_review_entity_connect joined with re_review_assignment where re_review_approved = 0
- **Recalculation restriction:** batch_recalculate() only allowed for unassigned batches (per CONTEXT: "Recalculation allowed only before assignment")
- **Soft delete pattern:** batch_archive() removes from re_review_assignment but preserves re_review_entity_connect records for audit trail

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Service layer complete with all 8 required functions
- Ready for Phase 38-02: API endpoint creation using these service functions
- Service functions available via start_sysndd_api.R sourcing
- Entity overlap prevention tested in query design

---
*Phase: 38-re-review-system-overhaul*
*Completed: 2026-01-26*
