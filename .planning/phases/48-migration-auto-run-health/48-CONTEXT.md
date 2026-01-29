# Phase 48: Migration Auto-Run & Health - Context

**Gathered:** 2026-01-29
**Status:** Ready for planning

<domain>
## Phase Boundary

API startup automatically applies pending migrations with health visibility. Extends Phase 47's migration foundation to run migrations on startup and expose migration status via health endpoints. Manual migration runner and schema_version table come from Phase 47.

</domain>

<decisions>
## Implementation Decisions

### Startup Behavior
- Block all requests until migrations complete — API only serves when schema is current
- Use database-level locking on schema_version table for multi-worker coordination
- First worker acquires lock, applies migrations, releases; others wait then proceed
- 30-second timeout for lock acquisition — fail with clear error if exceeded

### Health Reporting
- Expose just pending migration count — minimal info: `{pending_migrations: 0}`
- Return HTTP 503 when migrations are pending, 200 when ready
- Public access — no authentication required for health endpoints
- Two endpoints: `/health` (liveness) and `/health/ready` (readiness with migration check)

### Failure Handling
- Crash API on migration failure — forces fix before deploy
- No auto-rollback — leave partial state for manual debugging
- Track failures in schema_version table with error message
- Require manual reset of failed status before retry (prevents boot loops)

### Logging Output
- Summary logging: "Applying N migrations..." → "Migrations complete (list)"
- Brief confirmation when current: "Schema up to date (N migrations applied)"
- Full error + SQL on failure for debugging
- Include timing for total and per-migration duration

### Claude's Discretion
- Exact locking SQL implementation (GET_LOCK vs table-level lock)
- Log formatting and structure
- Health endpoint response structure beyond required fields
- Error message wording

</decisions>

<specifics>
## Specific Ideas

- Based on industry best practices for migration coordination (database-level locking as used by Rails, EF Core, Flyway)
- /health vs /health/ready follows Kubernetes probe patterns (liveness vs readiness)
- Lock timeout of 30s balances responsiveness with allowing migrations to complete

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 48-migration-auto-run-health*
*Context gathered: 2026-01-29*
