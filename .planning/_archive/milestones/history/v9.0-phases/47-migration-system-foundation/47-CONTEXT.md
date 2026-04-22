# Phase 47: Migration System Foundation - Context

**Gathered:** 2026-01-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Build infrastructure for running database migrations with state tracking. The system tracks which migrations have run, executes them in sequential order, and is safe to run multiple times (idempotent). This phase creates the foundation — auto-run on API startup is Phase 48.

</domain>

<decisions>
## Implementation Decisions

### Tracking table design
- Minimal metadata: filename, applied_at timestamp, success flag only
- Version derived from filename prefix (001, 002, ...), no separate version column
- Table lives in main sysndd database alongside application tables
- Only record successful migrations (failed attempts not tracked)

### Failure handling
- Stop immediately on first error — don't attempt remaining migrations
- Per-migration transactions — each migration wrapped in transaction, auto-rollback on failure
- Require manual resolution for dirty state (migration started but not recorded)
- No down migrations — forward-only, rollback by creating new migration

### Logging & output
- Default output is summary only: "Applied 3 migrations (001, 002, 003)"
- Optional verbose flag for debugging (shows detailed execution)
- Console only — no separate log file (Docker logs capture it)
- Successful migrations logged at INFO level (always visible)

### File conventions
- Keep existing location: db/migrations/
- Keep existing naming: NNN_name.sql (001_init.sql, 002_features.sql)
- Edit migration 002 in place to add IF NOT EXISTS guards
- No migration generator — developers copy existing files as templates

### Claude's Discretion
- Transaction handling nuances for MySQL DDL limitations
- Exact dirty state detection mechanism
- Verbose output formatting

</decisions>

<specifics>
## Specific Ideas

- Migration 003 uses correct stored procedure pattern (reference for best practices)
- Migration 002 needs IF NOT EXISTS guards to become idempotent
- Integration point is api/start_sysndd_api.R (research finding)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 47-migration-system-foundation*
*Context gathered: 2026-01-29*
