# Phase 21: Repository Layer - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Create a database access layer that centralizes all SQL queries behind repository abstractions. Eliminate direct `dbConnect()` calls from endpoints, ensure all queries use parameterized parameters via `dbBind`, and establish domain-specific repositories (entity, review, status, publication, phenotype, ontology, user, hash).

</domain>

<decisions>
## Implementation Decisions

### Repository Organization
- One file per domain (8 repository files matching success criteria domains)
- File location: **Research needed** — investigate R/Plumber project structure conventions
- Class vs functions pattern: **Research needed** — investigate R repository patterns (R6 classes vs plain functions)
- Repositories can join related tables and return nested structures (eager loading for common access patterns)

### Query Helper Design
- Named parameters only: `execute_query(sql, list(id = 5, name = 'x'))` — clearer, self-documenting
- Empty result handling: **Research needed** — investigate what return type works best with JSON:API serialization
- Error handling pattern: **Research needed** — investigate R error handling patterns for APIs
- Always log executed queries with sanitized params at DEBUG level

### Connection Pool Usage
- Connection acquisition pattern: **Research needed** — investigate R connection pool patterns
- Health checks: Validate connection on checkout before returning from pool
- Pool exhaustion: Wait with timeout for a connection, then error
- Pool configuration: **Research needed** — compare current implementation against best practices and recommend approach

### Transaction Handling
- Multi-table write pattern: **Research needed** — investigate R transaction patterns
- Rollback behavior: Auto-rollback on failure and throw error with details
- No savepoints — flat transactions only (all-or-nothing)
- Log transaction lifecycle events (start/commit/rollback) at DEBUG level

### Claude's Discretion
- Exact method signatures for repository functions
- Internal helper function organization
- Specific logging format and levels beyond DEBUG
- Connection validation query implementation

</decisions>

<specifics>
## Specific Ideas

- JSON:API compatibility is important — return types must serialize correctly
- Query logging should always be enabled (not configurable) for debugging production issues
- Transaction logging provides audit trail for data modifications

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 21-repository-layer*
*Context gathered: 2026-01-23*
