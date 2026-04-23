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
8. Preserve current user-visible async behaviors that matter operationally:
   - duplicate-job suppression via parameter hashing
   - clustering and phenotype-clustering post-completion chaining into LLM generation
   - admin job-history visibility
9. Update deployment, development, and agent docs for the new worker process model.
10. Structure the implementation so major slices can be executed in parallel with minimal overlap.

## Out of Scope

1. Adding Redis, RabbitMQ, SQS, or any new queue infrastructure.
2. General frontend architecture migration outside the async-job polling surface.
3. Rewriting unrelated endpoint families that do not participate in async jobs.
4. Building a broad event-streaming or websocket architecture for job progress updates.
5. A compatibility layer that preserves `jobs_env` as a long-term fallback path.
6. Large-scale redesign of mirai-based computation internals beyond adapting them to the new worker execution boundary.
7. Changing the same-image deployment strategy; the worker should run as a separate service with a different entrypoint, not as a separate image family.

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
  - exposes status, result, history, cancel, and retry endpoints
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
- `queue_name`
- `priority`
- `request_payload_json`
- `submitted_by`
- `submitted_at`
- `scheduled_at`
- `started_at`
- `completed_at`
- `claimed_by_worker`
- `worker_hostname`
- `worker_pid`
- `last_heartbeat_at`
- `claim_expires_at`
- `attempt_count`
- `max_attempts`
- `next_attempt_at`
- `progress_pct`
- `progress_message`
- `last_error_code`
- `last_error_message`
- `cancelled_by`
- `updated_at`
- `result_json`

Status values:

- `queued`
- `running`
- `completed`
- `failed`
- `cancel_requested`
- `cancelled`

Notes:

- Keep the row narrow enough for normal status polling and orchestration.
- Treat retry eligibility as derived state, not a separate status:
  - `status = failed`
  - `attempt_count < max_attempts`
  - `next_attempt_at <= NOW()`
- If large result payloads become awkward, split them later into a dedicated artifact table. The initial design should only do that if existing async results clearly require it.
- `result_json` is acceptable in-table at current scale, but status polling queries should exclude it from the normal select list.
- `submitted_by` should preserve audit history even if the user is later removed; avoid cascading user deletion into async-job audit loss.

#### `async_job_events`

Append-only event/history table.

Purpose:

- durable progress timeline
- lifecycle audit trail
- debugging support
- operator visibility into claim/recovery/retry behavior

Typical events:

- submitted
- started
- progress update
- retried
- cancel requested
- completed
- failed
- requeued
- cancelled

Event policy:

- append events for lifecycle transitions and meaningful progress milestones
- do not write an event row for every heartbeat
- keep heartbeats as row updates on `async_jobs`, optionally downsampling them into events only for coarse operational visibility

### Execution Flow

1. API endpoint validates request data and maps it to a supported `job_type`.
2. API writes a new `async_jobs` row with `status = queued`.
3. API returns `job_id` immediately.
4. Worker loop claims a job transactionally using MySQL row-locking appropriate for queue-like work.
5. Worker writes ownership metadata, lease expiry, and `running` lifecycle state in the claim path.
6. Worker dispatches the job to a registered handler.
7. Handler emits durable progress updates and event rows while executing.
8. Worker writes final `completed`, `failed`, or `cancelled` state and clears ownership metadata as appropriate.
9. API status endpoint reads MySQL-backed state only; any API replica can answer correctly.
10. Recovery loop requeues or terminally fails stale jobs whose lease expired without heartbeat renewal.
11. Post-completion hooks run where required, including the existing clustering and phenotype-clustering chain into LLM generation.

### Claiming And Recovery

Use transactional claim leasing, not process-local ownership.

Rules:

- workers claim only `queued` jobs or failed jobs whose retry window has opened
- claim transaction must be short and commit immediately after ownership is persisted
- `queued -> running` should happen in the claim transaction; there is no separate long-lived `claimed` state
- running workers heartbeat by updating `last_heartbeat_at` and extending `claim_expires_at`
- stale running jobs whose lease expires are not considered owned
- stale-job recovery requeues work if retry budget remains; otherwise marks the job `failed`

Status semantics:

- `queued`: eligible for claim
- `running`: actively executing with valid lease
- `completed`: terminal success
- `failed`: terminal failure
- `cancel_requested`: cancellation requested but not yet finalized
- `cancelled`: terminal cancellation

Retry semantics:

- retryability is derived from job state and scheduling metadata, not a dedicated status
- retries should be scheduled via `next_attempt_at`, not by sleeping inside a worker

### Component Boundaries

#### `api/functions/async-job-repository.R`

Responsibility:

- DB access only
- create job rows
- claim jobs
- persist heartbeats
- persist progress snapshots on the job row
- append event rows
- complete/fail/cancel jobs
- recover stale leases
- implement duplicate-job detection using durable request hashing rather than in-memory scans

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
- bounded worker lifetime rules such as max jobs per worker and max worker lifetime
- clean stop handling so a draining worker does not claim new jobs and releases leases safely between jobs

#### `api/functions/async-job-handlers.R`

Responsibility:

- map `job_type` values to execution handlers
- keep orchestration separate from job-specific computation
- adapt every current `create_job(...)` call site into the durable registry:
  - `clustering`
  - `phenotype_clustering`
  - `ontology_update`
  - `hgnc_update`
  - `comparisons_update`
  - `pubtator_update`
  - `llm_generation`
  - `backup_create`
  - `backup_restore`
  - `omim_update`
  - `force_apply_ontology`
  - `publication_refresh`
- support post-completion hooks where existing behavior requires them, especially clustering-driven LLM chaining
- require each handler to declare cancellation capability as one of:
  - `cooperative`
  - `best_effort`
  - `non_interruptible`

#### API endpoints

Primary files:

- `api/endpoints/jobs_endpoints.R`
- existing async-producing endpoint files that currently call `create_job(...)`

Responsibility:

- submit jobs via the service layer
- return durable `job_id`
- read DB-backed job status
- preserve admin job history on durable data
- expose cancel/retry where supported

#### Frontend polling

Primary file:

- `app/src/composables/useAsyncJob.ts`

Responsibility:

- keep polling, progress formatting, and UI-facing state only
- stop depending on sticky-session correctness for job visibility
- continue handling R/Plumber response quirks if they remain relevant on the status endpoint
- consume cheap row-level progress fields rather than requiring event-table scans for normal polling

### Progress Model

Current behavior uses file-based progress reporting under `/tmp/sysndd_jobs`, which lets workers write cheap progress snapshots and the API read them during polling.

Replacement rule:

- replace file-based progress with durable row-level fields on `async_jobs`
- keep `progress_pct` and `progress_message` on the primary row for cheap polling
- use `async_job_events` for lifecycle history and meaningful progress milestones, not as the primary source of every status poll
- remove the file-based progress path in the final hard-cut state

### Preserved Behaviors

The durable refactor must preserve these current semantics unless explicitly redesigned later:

- duplicate expensive jobs are suppressed based on operation plus parameter hash
- `clustering` and `phenotype_clustering` trigger downstream LLM batch generation on successful completion, including cache-hit paths that currently perform that chain synchronously from the endpoint layer
- admin job history remains available through durable storage rather than process memory

### Hard-Cut Boundary

Final-state rules:

- `jobs_env` is removed as canonical async job state
- job status must never depend on API-process-local objects
- sticky sessions may remain operationally harmless, but they cannot be part of correctness
- the final implementation must have one durable async-job path, not dual long-term paths
- worker claims must not begin before the required schema is available; worker startup should gate on API/schema readiness rather than racing migrations

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
- clustering post-completion chaining into LLM generation
- bounded worker-drain behavior during shutdown

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

Operational rollout details:

- run workers from the same application image with a different entrypoint, not a separate image lineage
- gate worker startup on readiness or schema availability so workers cannot execute against pre-migration state
- document conservative defaults for worker draining and restart behavior, including a compose-level grace period

## Parallel Execution Shape

The implementation splits into five mostly independent streams:

1. DB schema and repository layer
2. worker runtime, lease handling, and handler registry
3. API submission/status/cancel/retry integration
4. frontend polling cleanup and regression coverage
5. docs, deployment model, and verification updates

These streams should converge at integrated async-job verification and full `make ci-local`.

Parallelization note:

- the handler-registry stream should own a complete inventory of the twelve current async operations so no endpoint family is silently stranded on the old path

## Risks

1. Existing async handlers may assume direct access to process-local job state and need careful adaptation.
2. Some job result payloads may be too large or awkward for naive inline JSON storage.
3. Cancellation semantics may vary by job type and require explicit documentation of which operations are cooperative vs non-interruptible.
4. Worker lifecycle and claim timeout tuning may be environment-sensitive and require conservative defaults.
5. Migration will touch multiple async-producing endpoints, so incomplete handler registration could strand part of the async surface on the old path if not tracked carefully.
6. Long-lived R workers can accumulate memory; the worker contract should include bounded lifetime and max-job limits so the supervisor can recycle processes predictably.
7. Termination handling on R workers needs explicit treatment so workers drain safely and do not strand leases during deploys or restarts.

## Recommendation

Proceed with the MySQL-backed durable queue/state model and dedicated worker runtime as the long-term async refactor target. It is the smallest architecture that removes the current reliability failure modes while staying within the existing SysNDD stack and enabling safe parallel implementation.
