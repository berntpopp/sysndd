# Phase 22: Service Layer & Middleware - Context

**Gathered:** 2026-01-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract business logic into service layer and implement authentication middleware. Decompose the 1,234-line database-functions.R god file into domain-specific services. Eliminate global mutable state (<<-) except for approved globals. Verify all endpoints maintain compatibility with production frontend.

</domain>

<decisions>
## Implementation Decisions

### Auth Middleware Design
- Filter with allowlist pattern — global filter checks all requests, skips explicitly listed public endpoints
- Role hierarchy: Admin > Curator > Reviewer > Viewer — highest role wins, check against single effective role
- **Research needed:** 401 vs 403 distinction — research best practices and community standards
- **Research needed:** User context attachment — research best practices, compare with current implementation

### God File Decomposition
- Split by domain — entity-service.R, user-service.R, phenotype-service.R matching Phase 21 repositories
- **Research needed:** File location — research best practices, compare with previous phase decisions
- Cross-cutting helpers go in utils.R — no catch-all but shared utilities allowed
- Delete database-functions.R immediately once all functions migrated — no deprecated reference kept

### Global State Elimination
- **Research needed:** Primary replacement strategy — research best practices and community standards for R
- Approved globals: Pool + config — connection pool and config.yml settings remain global
- Target: Complete elimination — zero <<- usages except pool/config by end of phase
- Dependency pattern: Module globals — each service file defines its dependencies at top, simple and explicit

### Verification Strategy
- Integration tests with testthat for development confidence
- Core data match — primary data fields must match, metadata can differ
- Playwright validation after each phase for full workflow coverage
- Full workflow testing — all user journeys including admin functions
- Responses allowed to change (e.g., new meta information) as long as frontend works

### Claude's Discretion
- Exact service method signatures
- Integration test organization and naming
- Specific Playwright test scenarios beyond critical flows
- Order of function migration from god file

</decisions>

<specifics>
## Specific Ideas

- Playwright is the ultimate validation — if frontend renders correctly, API is correct enough
- Adding tests helps development but frontend validation is the critical gate
- Responses may gain new fields but core data must remain stable

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 22-service-layer-middleware*
*Context gathered: 2026-01-24*
