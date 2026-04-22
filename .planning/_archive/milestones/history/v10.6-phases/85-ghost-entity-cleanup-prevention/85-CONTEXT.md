# Phase 85: Ghost Entity Cleanup & Prevention - Context

**Gathered:** 2026-02-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Deactivate/remove orphaned ghost entities that have `is_active=1` but no status or review records, and wrap entity creation in a transaction to prevent future orphans. The cleanup targets production data via a `sysndd-administration` GitHub issue; the prevention fix is a backend code change.

</domain>

<decisions>
## Implementation Decisions

### Cleanup approach
- **Delete** all three ghost entities (4469/GAP43, 4474/FGF14, 4188/VCP) from the database — not just deactivate
- Before deleting entity 4188: NULL out `replaced_by` on entity 1249 (which points to 4188 as its replacement)
- Include a **detection query** that finds ALL entities with `is_active=1` and zero status records, not just the known three — report any newly discovered ghosts
- Cleanup is a **production task** — deliver as a detailed GitHub issue in `https://github.com/berntpopp/sysndd-administration` with problem description, remediation SQL, and verification steps
- Do NOT run cleanup in development — the issue describes what to do and the production team implements it

### Prevention mechanism
- **Add as wrapper** around existing entity creation endpoint — keep the current code but wrap it with transaction logic using `svc_entity_create_with_review_status`
- **Full rollback** on partial failure — if entity INSERT succeeds but status/review fails, roll back everything. User sees error and retries.
- **Backend only** — no frontend changes needed, the frontend already calls the same endpoint
- **Testing:** R unit tests for transaction rollback behavior + manual E2E verification via Playwright MCP after integration

### Audit & visibility
- **No in-app visibility** for the cleanup — ghost entities were already invisible, no need to announce removal
- **Log failed transaction attempts** — when atomic creation rolls back, log details (user, gene, disease, error) for future debugging

### Safety net
- **Trust the fix** — atomic transactions eliminate the root cause, no ongoing ghost detection needed
- **Application-level only** — no database triggers or constraints. Transaction wrapper is sufficient.

### Claude's Discretion
- Exact SQL phrasing for the `sysndd-administration` issue
- How to structure the transaction wrapper around the existing endpoint (tryCatch vs withCallingHandlers)
- Log format and destination for failed creation attempts
- Unit test scenarios for rollback coverage

</decisions>

<specifics>
## Specific Ideas

- Three confirmed ghost entities: 4469 (GAP43), 4474 (FGF14), 4188 (VCP) — all `is_active=1`, zero status/review records
- Entity 4188 has a dangling FK: entity 1249 has `replaced_by=4188`
- Entity 4469 is the ONLY entity for GAP43 — deletion means the gene has no representation until re-curated
- Entity 4474 (FGF14/nervous system disorders/AR) appears to be an accidental creation — 59 seconds after 4473
- The `svc_entity_create_with_review_status` service function already exists from Phase 75 but may not be wired into the actual endpoint
- `sysndd-administration` repo uses Python — issue should describe the problem and SQL, not prescribe implementation language

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 85-ghost-entity-cleanup-prevention*
*Context gathered: 2026-02-10*
