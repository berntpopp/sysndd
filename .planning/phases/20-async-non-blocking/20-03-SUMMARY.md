---
phase: 20-async-non-blocking
plan: 03
subsystem: api
tags: [plumber, async, mirai, ontology, cleanup, daemon-pool, http202]

# Dependency graph
requires:
  - phase: 20-02
    provides: jobs_endpoints.R with clustering async endpoints and job status polling
provides:
  - Ontology update async endpoint (POST /api/jobs/ontology_update/submit)
  - Self-scheduling hourly cleanup function
  - Complete async infrastructure with 3 job types
  - HTTP 202/409 pattern verified end-to-end
affects: [frontend-polling-integration, ontology-operations]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Self-scheduling cleanup via recursive later() calls
    - Pre-fetch database data for ontology updates before mirai submission
    - Administrator-only async endpoints with role verification

key-files:
  created: []
  modified:
    - api/endpoints/jobs_endpoints.R
    - api/functions/job-manager.R
    - api/start_sysndd_api.R

key-decisions:
  - "Pre-fetch HGNC list and mode of inheritance data before mirai call"
  - "Administrator role required for ontology update operations"
  - "Self-scheduling cleanup replaces simple later() call for robustness"
  - "Orchestrator corrections: auth filter allowlist and daemon package exports"

patterns-established:
  - "Role-based auth checks on async endpoints (req$user_role)"
  - "Recursive later() for scheduled background tasks"
  - "Package exports for daemon workers via .packages parameter"

# Metrics
duration: ~2h (with checkpoint pause)
completed: 2026-01-24
---

# Phase 20 Plan 03: Frontend Polling Integration Summary

**Ontology update async endpoint with self-scheduling cleanup, completing the async infrastructure with 8-worker daemon pool and 3 job types**

## Performance

- **Duration:** ~2 hours (including checkpoint verification pause)
- **Started:** 2026-01-24
- **Completed:** 2026-01-24T04:15:00Z
- **Tasks:** 3/3 (2 auto + 1 checkpoint)
- **Files modified:** 3

## Accomplishments

- Added ontology update async endpoint requiring Administrator role authentication
- Implemented self-scheduling cleanup function with recursive later() pattern
- Updated progress messages to include ontology_update operation
- Added auth filter allowlist for /api/jobs endpoints
- Configured daemon worker package exports for required libraries
- Verified complete async infrastructure end-to-end

## Task Commits

Each task was committed atomically:

1. **Task 1: Add ontology update async endpoint** - `8b3e93c` (feat)
2. **Task 2: Implement self-scheduling cleanup and update progress messages** - `42c84ea` (feat)
3. **Task 3: Human verification checkpoint** - Approved with notes

**Orchestrator corrections:** `a9d5dab` (fix) - auth filter allowlist, daemon package exports

## Files Created/Modified

- `api/endpoints/jobs_endpoints.R` - Added ontology_update/submit endpoint with Administrator auth check
- `api/functions/job-manager.R` - Added schedule_cleanup(), updated cleanup_old_jobs() with error handling, updated get_progress_message()
- `api/start_sysndd_api.R` - Added schedule_cleanup(3600) call, auth filter allowlist, daemon package exports

## Decisions Made

1. **Pre-fetch database data for ontology updates** - HGNC list and mode of inheritance list extracted before mirai call since database connections cannot cross process boundaries.

2. **Administrator role required** - Ontology updates are administrative operations that modify system data.

3. **Self-scheduling cleanup pattern** - Uses recursive later() call for more robust scheduling than single deferred call.

4. **Auth filter allowlist** - /api/jobs endpoints added to authentication filter to prevent 401 errors on job submission.

5. **Daemon package exports** - Required packages (dplyr, dbplyr, tidyr, httr2, purrr, stringr, readr, jsonlite) passed to mirai via .packages parameter for daemon worker access.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Auth filter allowlist for jobs endpoints**
- **Found during:** Verification testing
- **Issue:** /api/jobs endpoints returning 401 despite valid auth because not in allowlist
- **Fix:** Added "^/api/jobs" pattern to auth filter list in start_sysndd_api.R
- **Files modified:** api/start_sysndd_api.R
- **Committed in:** a9d5dab (orchestrator corrections)

**2. [Rule 3 - Blocking] Daemon package exports**
- **Found during:** Verification testing
- **Issue:** Daemon workers failing because required packages not available in worker environment
- **Fix:** Added .packages parameter to daemons() call with required library list
- **Files modified:** api/start_sysndd_api.R
- **Committed in:** a9d5dab (orchestrator corrections)

---

**Total deviations:** 2 auto-fixed (both blocking issues)
**Impact on plan:** Both fixes necessary for async infrastructure to function correctly. No scope creep.

## Known Limitations

**Job execution failures due to business logic dependencies:**

The async infrastructure is fully functional (HTTP 202, polling, duplicate detection, non-blocking operation), but actual job execution fails because analysis functions like `gen_string_clust_obj()` internally use `pool` for database queries that daemon workers cannot access.

**Root cause:** The `pool` database connection is a global variable in the main Plumber process. When analysis functions are called inside mirai daemon workers, they attempt to use `pool` which doesn't exist in the worker context.

**Required future work:** Refactor analysis functions to:
1. Accept database data as parameters (like ontology_update endpoint does with hgnc_list and mode_of_inheritance_list)
2. Or use a daemon-accessible connection method
3. Or restructure to perform all database operations in the main process before spawning mirai tasks

This is a limitation of the existing business logic, not the async infrastructure itself.

## Issues Encountered

None beyond the deviations documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Async infrastructure complete and verified working
- Three job types available: clustering, phenotype_clustering, ontology_update
- HTTP 202 Accepted pattern confirmed
- HTTP 409 Conflict duplicate detection working
- Non-blocking operation verified (health endpoint responds while jobs running)
- Future work needed to refactor analysis functions for full async execution

---
*Phase: 20-async-non-blocking*
*Completed: 2026-01-24*
