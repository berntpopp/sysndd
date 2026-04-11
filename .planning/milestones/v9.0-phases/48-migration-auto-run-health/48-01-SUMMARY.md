---
phase: 48-migration-auto-run-health
plan: 01
subsystem: database
tags: [migrations, mysql, advisory-locks, r-dbi, startup-automation]

# Dependency graph
requires:
  - phase: 47-migration-system-foundation
    provides: "Migration runner with schema_version tracking"
provides:
  - "Automatic migration execution on API startup"
  - "Multi-worker coordination via MySQL advisory locks"
  - "migration_status global variable for health endpoint access"
affects: [48-02-health-endpoint, production-deployment]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "MySQL advisory locks (GET_LOCK/RELEASE_LOCK) for distributed coordination"
    - "on.exit() chains for guaranteed cleanup"
    - "Fail-fast startup pattern (crash on migration error)"

key-files:
  created: []
  modified:
    - "api/functions/migration-runner.R"
    - "api/start_sysndd_api.R"

key-decisions:
  - "Use MySQL advisory locks instead of file locks for multi-container coordination"
  - "Crash API on migration failure (forces fix before deploy)"
  - "30-second lock timeout (prevents infinite wait on stuck worker)"
  - "Store migration result in global variable for health endpoint visibility"

patterns-established:
  - "Startup integration pattern: source → checkout connection → acquire lock → run → release lock → return connection"
  - "on.exit() chains for guaranteed resource cleanup"

# Metrics
duration: 1.5min
completed: 2026-01-29
---

# Phase 48 Plan 01: Migration Auto-Run & Health Summary

**MySQL advisory locks coordinate multi-worker migration execution on API startup with fail-fast crash on error**

## Performance

- **Duration:** 1.5 min
- **Started:** 2026-01-29T21:47:40Z
- **Completed:** 2026-01-29T21:49:08Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Advisory lock functions (acquire_migration_lock, release_migration_lock) coordinate multi-worker execution
- API startup automatically runs migrations before serving requests
- Migration status stored in global variable for health endpoint access
- API crashes on migration failure (forces fix before deploy)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add advisory lock functions to migration-runner.R** - `47b3fbe` (feat)
2. **Task 2: Integrate migration runner into API startup** - `2f0019e` (feat)

## Files Created/Modified
- `api/functions/migration-runner.R` - Added acquire_migration_lock() and release_migration_lock() for MySQL advisory lock coordination
- `api/start_sysndd_api.R` - Integrated migration runner between pool creation and global objects, added migration_status global variable

## Decisions Made

**MySQL advisory locks for coordination:**
- Chose GET_LOCK/RELEASE_LOCK over file locks for multi-container coordination
- 30-second timeout prevents infinite wait if worker crashes while holding lock
- Locks are connection-scoped (automatically released on disconnect)

**Fail-fast startup pattern:**
- API crashes on migration error (forces fix before deploy)
- No partial startup (either migrations succeed or API exits)
- Clear error messages in logs for debugging

**Global migration_status variable:**
- Stores result for health endpoint access (without requiring database query)
- Captures: pending_migrations, total_migrations, last_run, newly_applied, filenames

**Startup integration point:**
- Placed between pool creation (section 7) and global objects (section 8)
- Uses poolCheckout for dedicated migration connection (separate from pool operations)
- on.exit() chains guarantee connection return and lock release (even on error)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - implementation proceeded smoothly. API startup logs confirmed migration integration working correctly.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 48-02: Health endpoint implementation can access `migration_status` global variable.

**What's ready:**
- migration_status global variable populated on startup
- Clear migration logging in startup console
- Multi-worker coordination tested (API restarts successfully)

**Future phases that will use this:**
- 48-02: Health endpoint will read migration_status for status checks
- Production deployment: Multiple API workers will coordinate via advisory locks

---
*Phase: 48-migration-auto-run-health*
*Completed: 2026-01-29*
