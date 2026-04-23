# Async Job Durability Refactor Design

**Date:** 2026-04-23  
**Scope:** Replace in-process async job ownership with a durable, MySQL-backed job system and dedicated R worker runtime, while keeping the stack inside `MySQL + R + mirai`.

## Goal

Eliminate the current async job reliability gap by moving SysNDD job state, progress, and recovery out of API-process memory and into durable storage, so API restarts, replica changes, and worker death do not orphan or lose job truth.

## Decision

Use a long-term maintainable refactor based on:

- MySQL-backed durable job state and queue semantics
- dedicated R worker processes separate from the API process
- `mirai` only as a bounded execution primitive inside workers, not as the durability boundary

Why:

- `api/functions/job-manager.R` currently stores canonical state in `jobs_env`, which is lost on restart.
- `app/src/composables/useAsyncJob.ts` currently depends on sticky-session behavior, which leaks backend implementation details into frontend correctness.
- The current stack already includes MySQL and `mirai`, so this design fixes the architecture without introducing Redis, RabbitMQ, or another new infrastructure dependency.
- This split creates clear implementation boundaries that can be parallelized safely across schema, API, worker, frontend, and docs workstreams.

## Roadmap Relationship

This design is the concrete long-term target for the async job durability recommendation in `.planning/reviews/2026-04-23-codebase-review.md` and open issue `#154`.

Decision:

- Treat this as the next major backend reliability milestone after the auth/query-string hard cut landed in PR `#304`.
- Prefer the full durable architecture over a smaller MySQL-backed cache layer, because the long-term maintainable fix is to remove API-process-owned job truth entirely.
- Keep the scope bounded to async job durability, worker execution, status polling, and related operational documentation. Do not bundle unrelated frontend migration or general API bootstrap redesign into this refactor.

## In Scope

1. Replace `jobs_env` as canonical job state with durable MySQL-backed job records.
2. Introduce a dedicated worker runtime that claims and executes jobs independently of the API request process.
3. Persist job lifecycle, progress, result metadata, error state, and retry/recovery information durably.
4. Add claim leasing and stale-worker recovery so abandoned jobs can be requeued or terminally failed deterministically.
5. Adapt existing async-producing API flows to submit durable jobs instead of owning them in memory.
6. Make API status endpoints read durable job truth so any API replica can answer.
7. Remove sticky-session correctness assumptions from frontend async polling.
8. Update deployment, development, and agent docs for the new worker process model.
9. Structure the implementation so major slices can be executed in parallel with minimal overlap.

## Out of Scope

1. Adding Redis, RabbitMQ, SQS, or any new queue infrastructure.
2. General frontend architecture migration outside the async-job polling surface.
3. Rewriting unrelated endpoint families that do not participate in async jobs.
4. Building a broad event-streaming or websocket architecture for job progress updates.
5. A compatibility layer that preserves `jobs_env` as a long-term fallback path.
6. Large-scale redesign of mirai-based computation internals beyond adapting them to the new worker execution boundary.

## Design

### Current Problem

Current state:

- `api/functions/job-manager.R` creates jobs in `jobs_env`, stores `mirai` objects in memory, and updates completion state through promise callbacks in the API process.
- `app/src/composables/useAsyncJob.ts` explicitly keeps polling pinned with `withCredentials` because sticky-session cookies currently matter for correctness.
- `api/bootstrap/setup_workers.R` preloads worker-executed code once at daemon startup, which is compatible with background execution but not with the current in-memory ownership model.

Failure modes today:

- API restart loses in-memory job state.
- Replica changes can make a valid job appear missing.
- Sticky sessions reduce routing drift but do not provide durability.
- Worker death or host restart lacks a durable recovery model.

### Target Architecture

Use a control-plane / execution-plane split.

- The API process becomes the control plane:
  - validates async requests
  - writes job submissions durably
  - exposes status, result, cancel, and retry endpoints
- MySQL becomes the system of record:
  - durable queue state
  - lifecycle timestamps
  - claim ownership and lease expiry
  - progress snapshots
  - result metadata and failure details
- Dedicated R worker processes become the execution plane:
  - claim queued jobs transactionally
  - execute registered handlers
  - heartbeat progress and ownership
  - persist final state
- `mirai` remains available inside workers to bound concurrency for heavy computations, but no correctness or durability rule may depend on a `mirai` object living in a web process.

### Data Model

#### `async_jobs`

Primary durable job table.

Required columns:

- `job_id`
- `job_type`
- `status`
- `request_payload_json`
- `submitted_by`
- `submitted_at`
- `started_at`
- `completed_at`
- `claimed_by_worker`
- `claim_expires_at`
- `attempt_count`
- `max_attempts`
- `last_error_code`
- `last_error_message`
- `result_json`

Status values:

- `queued`
- `claimed`
- `running`
- `completed`
- `failed`
- `cancel_requested`
- `cancelled`
- `retryable`

Notes:

- Keep the row narrow enough for normal status polling and orchestration.
- If large result payloads become awkward, split them later into a dedicated artifact table. The initial design should only do that if existing async results clearly require it.

#### `async_job_events`

Append-only event/history table.

Purpose:

- durable progress timeline
- lifecycle audit trail
- debugging support
- operator visibility into claim/recovery/retry behavior

Typical events:

- submitted
- claimed
- started
- progress update
- heartbeat
- cancel requested
- completed
- failed
- requeued
- cancelled

### Execution Flow

1. API endpoint validates request data and maps it to a supported `job_type`.
2. API writes a new `async_jobs` row with `status = queued`.
3. API returns `job_id` immediately.
4. Worker loop claims a job transactionally using MySQL row-locking appropriate for queue-like work.
5. Worker writes ownership metadata, lease expiry, and `running` lifecycle state.
6. Worker dispatches the job to a registered handler.
7. Handler emits durable progress updates and event rows while executing.
8. Worker writes final `completed`, `failed`, or `cancelled` state and clears ownership metadata as appropriate.
9. API status endpoint reads MySQL-backed state only; any API replica can answer correctly.
10. Recovery loop requeues or terminally fails stale jobs whose lease expired without heartbeat renewal.

### Claiming And Recovery

Use transactional claim leasing, not process-local ownership.

Rules:

- workers claim only `queued` jobs or explicitly `retryable` jobs
- claim transaction must be short and commit immediately after ownership is persisted
- running workers heartbeat by extending `claim_expires_at`
- stale running jobs whose lease expires are not considered owned
- stale-job recovery requeues work if retry budget remains; otherwise marks the job `failed`

Status semantics:

- `queued`: eligible for claim
- `claimed`: transitional state between claim and active execution
- `running`: actively executing with valid lease
- `completed`: terminal success
- `failed`: terminal failure
- `cancel_requested`: cancellation requested but not yet finalized
- `cancelled`: terminal cancellation
- `retryable`: failed execution that remains eligible for bounded retry

### Component Boundaries

#### `api/functions/async-job-repository.R`

Responsibility:

- DB access only
- create job rows
- claim jobs
- persist heartbeats
- persist progress snapshots
- append event rows
- complete/fail/cancel jobs
- recover stale leases

#### `api/functions/async-job-service.R`

Responsibility:

- API-facing orchestration
- validate payload shape for each job type
- translate endpoint requests into durable job submissions
- expose status/result/cancel/retry service methods

#### `api/functions/async-job-worker.R`

Responsibility:

- worker main loop
- claim/lease lifecycle
- handler dispatch
- heartbeat timing
- final state persistence

#### `api/functions/async-job-handlers.R`

Responsibility:

- map `job_type` values to execution handlers
- keep orchestration separate from job-specific computation
- adapt existing clustering, phenotype clustering, ontology update, HGNC update, PubTator, comparisons, and LLM-related async entrypoints into durable handlers

#### API endpoints

Primary files:

- `api/endpoints/jobs_endpoints.R`
- existing async-producing endpoint files that currently call `create_job(...)`

Responsibility:

- submit jobs via the service layer
- return durable `job_id`
- read DB-backed job status
- expose cancel/retry where supported

#### Frontend polling

Primary file:

- `app/src/composables/useAsyncJob.ts`

Responsibility:

- keep polling, progress formatting, and UI-facing state only
- stop depending on sticky-session correctness for job visibility
- continue handling R/Plumber response quirks if they remain relevant on the status endpoint

### Hard-Cut Boundary

Final-state rules:

- `jobs_env` is removed as canonical async job state
- job status must never depend on API-process-local objects
- sticky sessions may remain operationally harmless, but they cannot be part of correctness
- the final implementation must have one durable async-job path, not dual long-term paths

Short-lived implementation sequencing is acceptable while the refactor is in progress, but the landing state must be a hard cut to the durable model.

## Testing

### Repository and persistence coverage

- claim semantics under concurrent workers
- lease extension / heartbeat behavior
- stale-job recovery behavior
- retry-budget transitions
- event persistence correctness

### Service and API coverage

- durable submission returns a `job_id`
- unknown job ids return the expected not-found response
- DB-backed status reads succeed independent of prior local process state
- cancel and retry semantics behave as designed
- invalid payloads are rejected before durable submission

### Worker coverage

- handler dispatch by `job_type`
- progress persistence during execution
- final completion state persistence
- failure persistence with error details
- stale lease recovery after simulated worker death

### Frontend coverage

- `useAsyncJob.ts` polls durable status without relying on sticky-session correctness
- completion, failure, and job-not-found behavior remain correct in the UI layer

### Verification

Implementation hard gate:

1. targeted async-job repository/service/worker/API tests
2. relevant frontend async polling tests
3. `make test-api-fast`
4. `make ci-local` before completion

## Rollout Strategy

1. add schema and repository primitives
2. add worker runtime and handler registry
3. migrate one async job family end-to-end through the durable path
4. migrate remaining async job types
5. remove `jobs_env` ownership and sticky-session correctness assumptions
6. update deployment/dev/agent docs for worker lifecycle and operational behavior

This sequencing keeps risk bounded while preserving the long-term hard-cut end state.

## Parallel Execution Shape

The implementation splits into five mostly independent streams:

1. DB schema and repository layer
2. worker runtime, lease handling, and handler registry
3. API submission/status/cancel/retry integration
4. frontend polling cleanup and regression coverage
5. docs, deployment model, and verification updates

These streams should converge at integrated async-job verification and full `make ci-local`.

## Risks

1. Existing async handlers may assume direct access to process-local job state and need careful adaptation.
2. Some job result payloads may be too large or awkward for naive inline JSON storage.
3. Cancellation semantics may vary by job type and require explicit documentation of which operations are cooperative vs non-interruptible.
4. Worker lifecycle and claim timeout tuning may be environment-sensitive and require conservative defaults.
5. Migration will touch multiple async-producing endpoints, so incomplete handler registration could strand part of the async surface on the old path if not tracked carefully.

## Recommendation

Proceed with the MySQL-backed durable queue/state model and dedicated worker runtime as the long-term async refactor target. It is the smallest architecture that removes the current reliability failure modes while staying within the existing SysNDD stack and enabling safe parallel implementation.
