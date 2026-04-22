# Phase 50: Backup Admin UI - Context

**Gathered:** 2026-01-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Administrative interface for managing database backups through the admin panel. Admins can view backup list, download backup files, trigger manual backups, and restore from backups with safety confirmation. API layer already exists from Phase 49.

</domain>

<decisions>
## Implementation Decisions

### List presentation
- Essential columns only: filename, size, date
- Sorted newest first by default
- Human-readable file sizes ("1.2 GB", "458 MB")
- Absolute date format ("2026-01-29 14:30")

### Action workflow
- Download functionality included — admins can download .sql backup files
- Button placement, restore trigger method, and download trigger: Claude decides based on UX best practices research and existing admin panel patterns

### Confirmation patterns
- Restore requires typing "RESTORE" exactly (case-sensitive)
- Minimal warning message: "This will overwrite the current database. Type RESTORE to confirm."
- Confirm button stays disabled until exact match — no error message needed
- "Backup Now" requires no confirmation — non-destructive operation

### Status feedback
- Spinner only during operations ("Backing up...", "Restoring...")
- Auto-refresh list after successful backup completes
- Status location and post-restore behavior: Claude decides based on UX research and existing admin patterns

### Claude's Discretion
- Button placement and action trigger patterns (research UX best practices)
- Status feedback location (inline, toast, or modal)
- Post-restore behavior (message, suggest logout, or force reload)
- Overall visual styling to match existing admin panel
- Error state handling and messaging

</decisions>

<specifics>
## Specific Ideas

- Research senior UI/UX designer best practices for backup management interfaces
- Follow patterns established in other admin endpoint designs in this codebase
- Keep the interface minimal and functional — this is an admin tool, not a consumer feature

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 50-backup-admin-ui*
*Context gathered: 2026-01-29*
