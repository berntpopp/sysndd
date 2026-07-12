# S7 — Perf & Retention: async_jobs retention prune — Design

> **Implementation note (supersedes the SQL details below).** The shipped design
> hardened well past this draft during adversarial review: the retention SQL is
> **fully parameterized** (bound `TIMESTAMPADD(DAY, ?, …)` window + `LIMIT ?`, no
> interpolation), the age gate requires **both** `submitted_at` **and** `updated_at`
> older than the window, and deletion is a **lock-safe non-locking candidate-PK read
> then delete-by-PK with a full-predicate re-check** (not a single `DELETE … LIMIT`),
> with batch-count + soft between-batch time caps, per-batch row+metadata lock-wait
> bounds, fail-closed clamps on the tunable knobs, and a fail-safe dry-run parse.
> See `api/functions/async-job-retention.R` and the diff review at
> `.planning/reviews/2026-07-13-security-535-s7-diff-codex-review.md`.

Date: 2026-07-12
Issue: [#535](https://github.com/berntpopp/sysndd/issues/535) — umbrella hardening, slice **S7**
(audit P2-2/4/5/6). Parent design: `.../specs/2026-07-11-security-hardening-535-design.md` §3 (S7).

## 1. Scope decision — implement the job-retention item; defer the rest with rationale
S7 groups four perf/retention items. Assessed against current code:

| Item | Current state | Verdict |
|------|---------------|---------|
| **Job retention** | `async_jobs` (+ cascading `async_job_events`, unbounded `result_json`/`request_payload_json` JSON) is **never pruned** — `log-cleanup.R` deliberately scopes to `logging` only. Monotonic growth. | **REAL gap, low-risk fix → implemented here.** |
| External-proxy cache | Already bounded: `cache_disk(max_age=…, max_size=200MB)` per bucket + `cachem` LRU + error-payloads excluded. | Already mitigated — no change. |
| Backup I/O | `execute_mysqldump` captures stdout whole-in-memory; download slurps whole file. Real, but the fix is **medium-risk** (documented `system2` stdout/stderr interaction). | Deferred to a dedicated, carefully-tested slice. |
| Composables barrel tree-shaking | Heavy deps (ngl/markdown/d3/cytoscape) re-exported from `@/composables`; 46 files import via the barrel. Real, but needs **bundle-diff verification** and touches many views. | Deferred to a dedicated FE slice with a bundle-size gate. |

This slice implements only the clean, low-risk, high-value **job retention**; the other three are
documented for follow-up (two need risk-managed dedicated work, one is already mitigated).

## 2. Design — mirror the proven `log-cleanup.R` pattern
Prune only **terminal, non-retryable** job rows older than a retention window. New
`api/functions/async-job-retention.R` mirrors `log-cleanup.R`'s injection-safe, DB-injected,
unit-testable shape and **reuses its `validate_retention_days()`** guard (the only value interpolated
into SQL; everything else is a fixed literal).

- Predicate: `status IN ('completed','failed','cancelled') AND active_request_hash IS NULL AND
  submitted_at < (NOW() - INTERVAL <validated int> DAY)`. `active_request_hash IS NULL` is S2's exact
  definition of "not active and not retry-pending", so this **never** deletes a queued/running/
  cancel-requested/retry-pending job. `submitted_at` is indexed (`idx_async_jobs_history`). Deleting
  a parent cascades to `async_job_events`.
- `run_async_job_retention(config, count_fn, execute_fn, logger)` — count, then (unless dry-run)
  delete; structured summary; DB layer injected (fully host-testable).
- Config: `ASYNC_JOB_RETENTION_DAYS` (default **90** — longer than the 30-day log window because job
  history is more operationally useful), `ASYNC_JOB_RETENTION_DRY_RUN`.
- **Wiring (minimal topology change):** the existing `log-cleanup` sidecar's daily loop runs a second
  `Rscript scripts/delete_old_jobs.R` (a thin entrypoint mirroring `delete_old_logs.R`), reusing the
  same DB-only container, schedule, and mounts — no new container. Env vars added to that service.

## 3. Tests (pure, host-runnable — no live DB)
`test-unit-async-job-retention.R`: the count/delete SQL target only terminal+non-retryable+aged rows
and are identical in predicate; retention days validated (injection-proof; `"30; DROP…"` → error;
`0` → error; empty → default 90); `config_from_env` reads the env with defaults; dry-run counts but
never issues the DELETE; non-dry-run deletes and reports rows.

## 4. Verification
- Host R: retention test green. `make lint-api`; `docker compose config` validates the sidecar edit;
  files < 600. Codex adversarial review before PR. (No migration; additive.)

## 5. Out of scope (tracked follow-ups)
- Backup mysqldump/download streaming (medium-risk, dedicated slice).
- Composables barrel tree-shaking (FE, bundle-diff-gated dedicated slice).
- External-proxy cache is already bounded (no change).
