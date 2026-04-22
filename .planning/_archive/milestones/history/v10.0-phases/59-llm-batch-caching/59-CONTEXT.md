# Phase 59: LLM Batch & Caching - Context

**Gathered:** 2026-01-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Generate LLM cluster summaries as part of the clustering pipeline with hash-based caching. This is a **user operation** (not admin) — summaries are generated automatically when users trigger clustering and are ready immediately when viewing results.

**Critical insight:** Phase 61's LLM-as-judge validation should be integrated into this pipeline as the final step, creating a fully automated end-to-end flow with no human approval needed.

**Full pipeline:**
User triggers clustering → clustering runs → LLM summaries generated → LLM-as-judge validates → final results cached with long TTL

</domain>

<decisions>
## Implementation Decisions

### Job Triggering & Scheduling
- Chained after clustering: clustering job completes → automatically triggers LLM generation for changed clusters
- No standalone LLM regeneration option — always follows clustering
- Generate for both phenotype and functional cluster types
- Rate limit: 30 RPM (conservative, half of Paid Tier 1 limit)

### Progress & Monitoring
- Show in existing job manager panel (same as clustering jobs)
- Per-cluster progress: "Generating 15/47 clusters" with current cluster name
- Summary-only logging: totals for succeeded, failed, skipped (no per-cluster audit trail)
- No notifications — user operation, not admin operation

### Cache Invalidation Strategy
- Invalidate on cluster composition change only (hash of cluster members)
- Same gene list = same cache, even if underlying gene data changed
- Prompt/model version tracked in metadata but does NOT trigger regeneration
- Metadata includes: model used, prompt version, generation date

### Failure & Retry Behavior
- 3 retries per cluster before giving up, then continue to next cluster
- Failed clusters logged but don't stop batch
- No checkpoint/resume — restart from beginning if entire batch fails
- Cached clusters won't regenerate anyway, so restart is efficient

### LLM-as-Judge Integration
- Validation runs as final pipeline step, not separate phase
- Research best practices for handling validation failures during planning
- Results are fully automated — no human approval workflow needed

### Claude's Discretion
- Exact retry backoff strategy
- How to handle validation failures (research during planning)
- Job queue management details
- Specific error messages and logging format

</decisions>

<specifics>
## Specific Ideas

- "Data can be displayed immediately after request" — key UX goal is instant availability
- "Same as clustering" — follow clustering patterns for job management and caching
- "Long TTL like clusters" — cache lifetime should match clustering cache behavior
- "No admin needed" — this is a user-facing feature, not admin workflow

</specifics>

<deferred>
## Deferred Ideas

- Phase 61 LLM Validation originally scoped as separate → now integrated into this pipeline
- Admin override to force regeneration → not needed, clustering triggers regeneration
- Email notifications on completion → user operation, not admin workflow

</deferred>

---

*Phase: 59-llm-batch-caching*
*Context gathered: 2026-01-31*
