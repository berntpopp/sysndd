# S7 — async_jobs retention prune — Plan

> Design: `.../specs/2026-07-12-security-535-s7-job-retention-design.md`. TDD.

- [x] **Task 1 (TDD):** `test-unit-async-job-retention.R` (SQL predicate, injection guard, config env,
  dry-run vs delete) — host-runnable, injected DB. GREEN.
- [x] **Task 2:** `functions/async-job-retention.R` — count/delete builders (terminal +
  `active_request_hash IS NULL` + aged `submitted_at`, validated-integer interval) reusing
  `validate_retention_days`; `async_job_retention_config_from_env`; `run_async_job_retention`.
- [x] **Task 3:** `scripts/delete_old_jobs.R` (mirror `delete_old_logs.R`); wire into the existing
  `log-cleanup` sidecar daily loop + `ASYNC_JOB_RETENTION_DAYS`/`_DRY_RUN` env (no new container).
- [x] **Verify:** host test green; lint clean; `docker compose config` OK; files < 600.
- [ ] Codex diff review (xhigh); fold; PR (do-not-auto-merge).

## Self-review
Mirrors the proven log-cleanup pattern; reuses its injection-safe validator; never deletes an
active/retry-pending job (`active_request_hash IS NULL`); cascades to `async_job_events`; additive
(no migration); minimal topology change (reuses the log-cleanup sidecar).
