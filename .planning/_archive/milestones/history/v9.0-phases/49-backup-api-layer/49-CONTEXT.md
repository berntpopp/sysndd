# Phase 49: Backup API Layer - Context

**Gathered:** 2026-01-29
**Status:** Ready for planning

<domain>
## Phase Boundary

REST API endpoints for programmatic backup management. Users can list backups with metadata, trigger manual backups, and restore from backups. Automatic pre-restore backups ensure safety. Admin UI for these endpoints is Phase 50.

</domain>

<decisions>
## Implementation Decisions

### Response Format
- Paginated response structure: `{data: [...], total: N, page: 1}`
- Minimal metadata per backup: filename, size, date, table_count (no checksums or compression info)
- Sort only: newest first by default, optional `?sort=oldest` parameter
- Page size: 20 backups per page (matches other admin endpoints)

### Job Mechanics
- Use existing job manager (`api/functions/job-manager.R`) for consistency
- 10 minute timeout for backup jobs
- 5 second recommended polling interval for job status
- Job record retention: Research best practices (Claude's discretion based on findings)

### Error Responses
- Detailed error messages for admins (include disk space, permissions, connection errors)
- Failed backup attempts logged to API logs only (not persisted in job manager)
- Standard HTTP status codes: 409 Conflict (backup in progress), 507 Insufficient Storage, 503 Service Unavailable
- Concurrent backup requests blocked with 409 — only one backup at a time

### Pre-restore Backup
- Naming convention: `pre-restore_YYYY-MM-DD_HH-MM-SS.sql`
- Same storage location as regular backups (distinguished by naming prefix)
- No automatic retention limit — keep all pre-restore backups
- Block restore if pre-restore backup fails (cannot proceed without successful safety backup)

### Claude's Discretion
- Job record retention duration (research best practices first)
- Exact pagination implementation details
- Backup file format handling (existing backup container patterns)

</decisions>

<specifics>
## Specific Ideas

- Follow patterns from existing `api/endpoints/admin_endpoints.R`
- Leverage existing backup container (`fradelg/mysql-cron-backup`) already running
- Job manager patterns already established — reuse rather than create new

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 49-backup-api-layer*
*Context gathered: 2026-01-29*
