---
phase: 49-backup-api-layer
plan: 02
subsystem: api
tags: [plumber, backup, mysql, rest-api, async-jobs, job-manager]

# Dependency graph
requires:
  - phase: 49-01
    provides: Backup infrastructure and list endpoint with volume mount
provides:
  - POST /api/backup/create endpoint for manual backup creation
  - POST /api/backup/restore endpoint with pre-restore safety backup
  - Async job execution for backup operations (10 minute timeout)
  - Concurrent backup protection (409 Conflict on duplicate)
affects: [49-03, backup-ui, admin-dashboard]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Async backup operations using existing job manager"
    - "Pre-restore safety backup (BKUP-05) before destructive operations"
    - "Single concurrent backup enforcement via check_duplicate_job()"

key-files:
  created: []
  modified:
    - api/functions/backup-functions.R
    - api/endpoints/backup_endpoints.R
    - api/functions/job-manager.R

key-decisions:
  - "Use job manager for async execution (600000ms timeout per CONTEXT.md)"
  - "Manual backup naming: manual_YYYY-MM-DD_HH-MM-SS.sql"
  - "Pre-restore backup naming: pre-restore_YYYY-MM-DD_HH-MM-SS.sql"
  - "Block restore if pre-restore backup fails (return 503)"
  - "5 second polling interval via Retry-After header"

patterns-established:
  - "Backup execution via system2() with mysqldump binary"
  - "Restore handling for both .sql and .sql.gz formats"
  - "Pre-restore safety backup pattern for destructive operations"

# Metrics
duration: 2min
completed: 2026-01-29
---

# Phase 49 Plan 02: Backup Creation & Restore Endpoints Summary

**REST API endpoints for manual backup creation and restore with async job execution, pre-restore safety backups, and concurrent operation protection**

## Performance

- **Duration:** 2 min
- **Started:** 2026-01-29T22:08:29Z
- **Completed:** 2026-01-29T22:10:49Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- POST /api/backup/create triggers manual database backup asynchronously
- POST /api/backup/restore restores from backup with automatic pre-restore safety backup
- Concurrent backup operations prevented via duplicate job detection (409 Conflict)
- Job manager integration for timeout handling (10 minutes per CONTEXT.md)
- Progress messages for backup operations in job status polling

## Task Commits

Each task was committed atomically:

1. **Task 1: Add backup execution functions** - `ed29aa6d` (feat)
2. **Task 2: Add progress messages for backup operations** - `7a849e20` (feat)
3. **Task 3: Add backup creation and restore endpoints** - `739a175d` (feat)

## Files Created/Modified

- `api/functions/backup-functions.R` - Added execute_mysqldump(), execute_restore(), check_backup_in_progress()
- `api/functions/job-manager.R` - Added backup_create and backup_restore progress messages
- `api/endpoints/backup_endpoints.R` - Added POST /create and POST /restore endpoints

## Decisions Made

**1. Use system2() with mysqldump for backup creation**
- Rationale: Standard approach, handles triggers/routines/constraints correctly per RESEARCH.md
- Flags: --single-transaction (InnoDB consistency), --routines, --triggers, --quick
- Alternative considered: DBI table exports would miss database-level objects

**2. Pre-restore backup before restore (BKUP-05)**
- Rationale: Requirement for safety - restores are destructive operations
- Naming: pre-restore_YYYY-MM-DD_HH-MM-SS.sql distinguishes from regular backups
- Failure handling: Block restore with 503 if pre-restore backup fails
- Storage: Same /backup directory, no automatic retention limit

**3. 10 minute timeout for backup jobs**
- Rationale: Per CONTEXT.md decision matching other long-running operations
- Implementation: timeout_ms = 600000 in create_job() call
- Polling: 5 second Retry-After header per CONTEXT.md

**4. Single concurrent backup enforcement**
- Rationale: Per CONTEXT.md - prevent disk exhaustion and file corruption
- Implementation: check_duplicate_job() before create_job(), return 409 if running
- Scope: Blocks both backup_create and backup_restore operations

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - implementation straightforward following existing job manager patterns.

## Next Phase Readiness

**Ready for 49-03 (Admin UI if planned):**
- Endpoints operational: POST /create, POST /restore
- Job status polling via /api/jobs/:id/status
- Error responses standardized (409, 503, 404, 400)

**Ready for 50 (Backup Admin UI):**
- Full REST API available: list, create, restore
- Async job pattern with progress messages
- Pre-restore safety backup automatic
- Response format consistent with other admin endpoints

**Foundation complete:**
- Backup operations integrated with job manager
- Safety mechanisms (pre-restore, concurrency control)
- Administrator role required for all operations
- 202 Accepted + polling pattern established

**No blockers identified.**

---
*Phase: 49-backup-api-layer*
*Completed: 2026-01-29*
