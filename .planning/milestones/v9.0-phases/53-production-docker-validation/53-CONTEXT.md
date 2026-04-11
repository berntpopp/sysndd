# Phase 53: Production Docker Validation - Context

**Gathered:** 2026-01-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Validate production Docker build with 4 API workers, correct connection pool sizing, extended health checks, and a Makefile preflight target. This phase ensures the system is deployment-ready — not adding new features, just validating existing infrastructure works correctly in production configuration.

</domain>

<decisions>
## Implementation Decisions

### Health check behavior
- `/health/ready` verifies: database connected AND all migrations applied
- Response format: JSON with details — `{"status": "healthy", "database": "connected", "migrations": {"pending": 0, "applied": 3}, "pool": {...}}`
- Binary status codes: 200 = healthy, 503 = unhealthy (no degraded state)
- Pending migrations = 503 (not ready for traffic)

### Preflight validation scope
- `make preflight` validates: build prod image → start containers → verify `/health/ready` returns 200
- Output verbosity: progress during each step + final PASS/FAIL summary
- Cleanup behavior: auto-cleanup containers after validation (pass or fail)
- Exit codes: standard Unix (0 = pass, 1 = fail)

### Pool sizing strategy
- **Research needed:** Investigate best practices for R Plumber with multi-worker setups
- Configurable via environment variable (DB_POOL_SIZE) with sensible default
- Pool exhaustion handling: queue with timeout, then return 503
- Pool stats exposed in `/health/ready` response (active/idle/max connections)

### Failure reporting
- Preflight failures show: step + reason + actionable suggestion
- Failed preflight dumps last 50 lines of container logs
- `/health/ready` failures return 503 with JSON details: `{"status": "unhealthy", "reason": "...", "details": "..."}`
- Logging via stdout/stderr only (standard Docker logging)

### Claude's Discretion
- Exact pool size calculation based on research findings
- Health check response structure details
- Preflight script implementation approach (bash vs makefile recipes)
- Timeout values for health check polling

</decisions>

<specifics>
## Specific Ideas

- Pool sizing should follow R Plumber best practices discovered during research
- Preflight should be CI-friendly (exit codes, no interactive prompts)
- Health check response should be useful for both load balancers and human debugging

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 53-production-docker-validation*
*Context gathered: 2026-01-30*
