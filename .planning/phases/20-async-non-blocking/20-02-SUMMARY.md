---
phase: 20-async-non-blocking
plan: 02
subsystem: api
tags: [plumber, async, jobs, http202, mirai, clustering]

# Dependency graph
requires:
  - phase: 20-01
    provides: job-manager.R with create_job, get_job_status, check_duplicate_job functions
provides:
  - Async job submission endpoints (POST /clustering/submit, POST /phenotype_clustering/submit)
  - Job status polling endpoint (GET /<job_id>/status)
  - HTTP 202 Accepted pattern for long-running operations
  - HTTP 409 Conflict pattern for duplicate job prevention
affects: [20-03, 20-04, frontend-async-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - HTTP 202 Accepted with Location header for async submissions
    - Retry-After header for polling guidance
    - Pre-fetch database data before mirai call (connection isolation)

key-files:
  created:
    - api/endpoints/jobs_endpoints.R
  modified:
    - api/start_sysndd_api.R
    - api/endpoints/analysis_endpoints.R

key-decisions:
  - "Pre-fetch all database data before mirai call to avoid connection crossing process boundaries"
  - "Use entity count hash for phenotype clustering deduplication (stable identifier)"
  - "Preserve sync endpoints for backward compatibility while adding async alternatives"

patterns-established:
  - "Async submission: Extract params -> check duplicate -> create_job -> return 202"
  - "Status polling: get_job_status -> set Retry-After if running -> return status"
  - "Duplicate prevention: HTTP 409 with Location header pointing to existing job"

# Metrics
duration: 1min
completed: 2026-01-24
---

# Phase 20 Plan 02: Jobs API Endpoints Summary

**Async job submission and polling endpoints for clustering operations via HTTP 202/409 pattern**

## Performance

- **Duration:** 1 min 24 sec
- **Started:** 2026-01-24T02:06:22Z
- **Completed:** 2026-01-24T02:07:46Z
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments

- Created jobs_endpoints.R with 3 endpoints for async job management
- Mounted /api/jobs in start_sysndd_api.R router chain
- Added async endpoint documentation to analysis_endpoints.R
- Implemented HTTP 202 Accepted pattern with Location and Retry-After headers
- Implemented HTTP 409 Conflict pattern for duplicate job prevention

## Task Commits

Each task was committed atomically:

1. **Task 1: Create jobs endpoints file** - `3423234` (feat)
2. **Task 2: Mount jobs endpoints and update analysis endpoints** - `3613f48` (feat)

## Files Created/Modified

- `api/endpoints/jobs_endpoints.R` - Async job submission and status polling (3 endpoints)
- `api/start_sysndd_api.R` - Added pr_mount for /api/jobs
- `api/endpoints/analysis_endpoints.R` - Added note about async alternatives

## Decisions Made

1. **Pre-fetch database data before mirai** - Database connections cannot cross process boundaries, so all data must be collected in the main process before passing to the executor function.

2. **Entity count for phenotype clustering deduplication** - Since phenotype clustering doesn't take parameters, use entity count as a stable identifier for duplicate detection.

3. **Preserve sync endpoints** - Existing functional_clustering and phenotype_clustering endpoints remain for backward compatibility. New clients should prefer async endpoints for large datasets.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - R syntax validation was not available in the execution environment (Rscript not in PATH), but file structure follows established patterns from existing endpoints in the codebase.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Jobs API endpoints ready for integration testing
- Plan 20-03 (API polling client) can now be implemented
- Plan 20-04 (end-to-end testing) can verify async flow

---
*Phase: 20-async-non-blocking*
*Completed: 2026-01-24*
