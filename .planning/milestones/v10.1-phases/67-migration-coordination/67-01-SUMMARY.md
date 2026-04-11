---
phase: 67-migration-coordination
plan: 01
subsystem: infra
tags: [mysql, advisory-locks, migrations, docker, parallel-startup]

# Dependency graph
requires:
  - phase: 66-infrastructure-fixes
    provides: Infrastructure configuration with container scaling support
provides:
  - Double-checked locking pattern for database migrations
  - Fast path optimization (skip lock when schema is up-to-date)
  - Health endpoint reporting migration coordination status
  - get_pending_migrations() helper function for pre-lock checks
affects: [68-local-production-testing, deployment, scaling]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Double-checked locking for advisory lock coordination
    - Fast path optimization (check before acquiring expensive resource)
    - Race condition handling (re-check after lock acquisition)

key-files:
  created: []
  modified:
    - api/functions/migration-runner.R
    - api/start_sysndd_api.R
    - api/endpoints/health_endpoints.R

key-decisions:
  - "Check pending migrations BEFORE acquiring lock (fast path when up-to-date)"
  - "Re-check pending migrations AFTER acquiring lock (handles race condition)"
  - "Track fast_path and lock_acquired in migration_status for observability"
  - "Health endpoint reports current lock status via IS_USED_LOCK() query"

patterns-established:
  - "Double-checked locking: expensive check → conditional lock → re-check → action"
  - "Fast path optimization: common case (schema current) bypasses lock entirely"
  - "Observability: track startup behavior (fast_path/lock_acquired) for debugging"

# Metrics
duration: 3min
completed: 2026-02-01
---

# Phase 67 Plan 01: Migration Coordination Summary

**Double-checked locking for parallel API container startup: containers skip lock when schema is current, enabling instant startup for 4+ containers**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-01T20:07:04Z
- **Completed:** 2026-02-01T20:09:43Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Implemented double-checked locking pattern in migration startup sequence
- Added get_pending_migrations() helper for fast schema status check
- Enhanced health endpoint to report migration lock coordination status
- Fixed issue #136: containers no longer timeout waiting for lock when schema is current

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement double-checked locking in startup sequence** - `b166be37` (feat)
2. **Task 2: Enhance health endpoint with migration lock status** - `e7e498ac` (feat)

## Files Created/Modified
- `api/functions/migration-runner.R` - Added get_pending_migrations() helper for pre-lock checks
- `api/start_sysndd_api.R` - Replaced lock-first with double-checked locking in section 7.5
- `api/endpoints/health_endpoints.R` - Added lock status reporting (fast_path, lock_acquired, current lock state)

## Decisions Made

**1. Fast path optimization**
Check pending migrations BEFORE acquiring advisory lock. If schema is up-to-date (common case), skip lock entirely and proceed immediately. This eliminates the 30-second timeout issue when scaling to 4+ containers.

**2. Race condition handling**
Re-check pending migrations AFTER acquiring lock but before applying. Handles the race where another container applies migrations while we waited for lock. This container then takes fast exit without re-applying.

**3. Observability tracking**
Track `fast_path` (boolean) and `lock_acquired` (boolean) in global `migration_status` variable. Health endpoint exposes these fields so operators can verify parallel startup behavior in production.

**4. Current lock status query**
Health endpoint queries `IS_USED_LOCK('sysndd_migration')` to report whether lock is currently held. Useful for debugging coordination issues (e.g., orphaned locks, stuck migrations).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - implementation proceeded smoothly following research phase design.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Phase 68 (Local Production Testing):**
- Migration coordination logic complete and committed
- Health endpoint provides observability into startup behavior
- Ready to test parallel container startup with `docker compose --scale api=4`

**Test verification checklist:**
- [ ] Single container starts instantly (fast path)
- [ ] Four containers start simultaneously without timeout
- [ ] Health endpoint shows fast_path=true for containers 2-4
- [ ] Lock is never orphaned (all containers report healthy)
- [ ] Logs show "Fast path: schema up to date, no lock needed" message

**No blockers or concerns.**

---
*Phase: 67-migration-coordination*
*Completed: 2026-02-01*
