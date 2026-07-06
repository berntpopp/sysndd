---
name: sysndd-async-jobs
description: Use when adding or changing durable async jobs, worker-executed code, job handlers, queue lanes or priorities in SysNDD — or diagnosing why a submitted job never runs, stays queued, or fails with "No durable async job handler registered"
---

# SysNDD Async Jobs & Workers

Use this skill before touching any durable background job or worker-executed code. Jobs are durable and MySQL-backed: the web API submits and serves status; a separate **worker** claims and executes. Worker code is sourced **once at worker startup** — a change is not live until the worker restarts.

## Mental Model

- Submit: `create_job()` → `async_job_service_submit()` inserts a row. `job_type` is `VARCHAR(64)` with **no enum and no submit-side allowlist** — a typo or unregistered type inserts fine and only fails later, at execution.
- Execute: the worker claims by `priority ASC, scheduled_at ASC`, then looks the type up in `async_job_handler_registry` (`async-job-handlers.R`). **Unregistered type → the claimed job hard-fails** with "No durable async job handler registered for '<type>'".
- Two lanes (#486): `default` (interactive) and `maintenance` (heavy/bulk/external), drained by the `worker` and `worker-maintenance` containers respectively.

## Adding a Durable Job Type

1. **Define the executor** (e.g. `widget_refresh_async(params)`) in a `functions/` file.
2. **Register the file in `bootstrap/load_modules.R`** (`function_files`). This single loader is used by both the API and the durable worker (`start_async_worker.R`). Adding it only to `setup_workers.R` (mirai legacy parity) is **not** enough — durable jobs do not run on the mirai pool.
3. **Register the handler** in `async_job_handler_registry`: `run = .async_job_run_passthrough("widget_refresh_async")` (lazy-resolves by name, like `comparisons_update`) or a dedicated runner, plus a `cancel_mode` and `after_success`.
4. **Route the lane/priority** in `async-job-service.R`: add heavy/external types to `ASYNC_MAINTENANCE_JOB_TYPES` (→ `maintenance` queue, priority 50). Interactive types get priority 10 in `async_job_priority_for_type()`. Lane/priority are resolved at **submit time**, so the submitter must run new code too.
5. **External calls** inside the job must go through `external_proxy_budget()` / `make_external_request()` (enforced by `test-unit-external-budget-guard.R`) — never a hardcoded `req_timeout()`. An external-heavy **batch** must reset the per-request accumulator per call (see `.pubtatornidd_reset_external_budget()`), and the worker resets it per job (`external_proxy_request_reset()` in `async-job-worker.R`).
6. **Secrets** used by the job must be added to the `worker` **and** `worker-maintenance` `environment:` maps in `docker-compose.yml`. Compose uses explicit env maps — a bare `.env` value is invisible to the container otherwise.

## Operational — Restart the Worker

After changing worker-executed code (handlers, executors, `load_modules.R`): **restart `worker` and `worker-maintenance`**. Bind-mounted `.R` files are not hot-reloaded inside a running worker. Restart the `api`/submitter too when lane routing or a submit endpoint changed. Local dev runs one `worker` draining `default,maintenance` (`docker-compose.override.yml`); prod keeps the two containers as a deliberate mirror — only `ASYNC_JOB_QUEUES` differs.

## Verify

Submit a job; confirm the worker logs claim it on the expected lane and it completes (not `failed` with the "no handler" message). The two most-missed steps are **registering the handler** and **restarting the worker**.

## Common Mistakes

| Symptom | Cause |
|---|---|
| Job inserts but immediately `failed` | Handler not in `async_job_handler_registry` |
| Handler exists but old behavior runs | Worker not restarted after code change |
| Function-not-found at run time | New file not added to `bootstrap/load_modules.R` |
| Heavy job blocks interactive work | Type missing from `ASYNC_MAINTENANCE_JOB_TYPES` (stuck on `default`) |
| External calls 503 mid-batch | Per-call budget not reset in a batch job |
