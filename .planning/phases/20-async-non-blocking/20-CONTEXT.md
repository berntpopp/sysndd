# Phase 20: Async/Non-blocking - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Long-running API operations (ontology updates, clustering analysis) execute without blocking other requests. Users submit jobs, receive job IDs immediately, and poll for status/completion. The mirai package provides async execution.

</domain>

<decisions>
## Implementation Decisions

### Job Lifecycle
- Submit returns HTTP 202 Accepted with job ID + estimated wait time in seconds
- Response includes `Location` header pointing to status URL (RFC 9110 compliant)
- Status endpoint includes results inline when job completes (no separate results endpoint)
- Job IDs are unguessable UUIDs; anyone with the ID can poll status (no owner verification)

### Progress Reporting
- Status endpoint returns: state (pending/running/completed/failed) + current step description
- Example: `{"status": "running", "step": "Fetching ontology data...", "estimated_seconds": 45}`
- Retry-After header included on every status response (suggested polling interval)
- Estimated completion time provided when calculable from job progress
- No job cancellation endpoint — jobs run to completion or timeout

### Error & Timeout Handling
- Maximum job runtime: 30 minutes before forced timeout
- Failed jobs return user-friendly message + machine-readable error code
- Transient failures (network, timeout) auto-retry up to 3 times
- Data/logic errors fail immediately without retry
- Duplicate job submission returns HTTP 409 Conflict pointing to existing running job

### Result Retention
- Completed job results retained for 24 hours
- Job state stored in-memory only (jobs lost on container restart)
- Periodic background sweep cleans up jobs older than 24 hours (hourly)
- Global limit on concurrent running jobs (prevents resource exhaustion)

### Claude's Discretion
- Exact number for global concurrent job limit (5-10 range)
- Specific step descriptions for each job type
- Retry delay strategy for transient failures (exponential backoff vs fixed)
- Sweep interval tuning

</decisions>

<specifics>
## Specific Ideas

- Follow RFC 9110 for HTTP 202 Accepted pattern
- Retry-After header for polling guidance (industry standard)
- HTTP 409 Conflict for duplicate job detection
- mirai package for R async execution (per ASYNC-01 requirement)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 20-async-non-blocking*
*Context gathered: 2026-01-23*
