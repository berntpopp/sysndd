# S7 — async_jobs retention prune: adversarial diff review (Codex, xhigh)

- **PR:** #548 — S7 `async_jobs` retention prune (slice of umbrella #535).
- **Branch:** `fix/535-s7-job-retention`.
- **Reviewer:** Codex `xhigh`, read-only, `git diff master...HEAD`, 10 rounds (fresh full re-review after the prior fold).
- **Final verdict (round 10): `SHIP`** — no BLOCKER, no HIGH, no MEDIUM. One LOW (planning-doc drift) folded.

## Core safety — confirmed clean every round (10/10)

Codex confirmed on every round, and it was additionally **verified end-to-end against the live dev MySQL/RMariaDB** (not just unit tests):

- The DELETE is **fully parameterized** (bound `TIMESTAMPADD(DAY, ?, CURRENT_TIMESTAMP(6))` window + `LIMIT ?` + `job_id IN (?, …)` PKs); no value is interpolated.
- The predicate exactly matches migration 020's `active_request_hash` generated-column invariant: `status IN ('completed','failed','cancelled') AND active_request_hash IS NULL AND submitted_at < cutoff AND updated_at < cutoff`. It **cannot** delete queued / running / cancel-requested / retry-pending jobs (a live status-matrix probe confirmed a freshly-touched terminal row is excluded and survives; the qualifying row is deleted and `async_job_events` cascades).
- Retention `0` / negative / malformed **fails closed**; unset defaults to 90 days.
- Sidecar is non-root, `backend`-only (no egress), logs no credentials.
- No masked bare `get`/`exists` runtime call introduced (the round-6 HIGH was a **false positive** — see below).

## Findings folded (TDD red→green), by round

| Round | Severity | Finding | Disposition |
|---|---|---|---|
| 3 | LOW→MED | DELETE not fully parameterized | **Folded** — bind `TIMESTAMPADD(DAY, ?, …)` + `LIMIT ?`; kept `validate_retention_days` as defense-in-depth. Verified `LIMIT ?`/`TIMESTAMPADD ?` bind live. |
| 3 | MED | unbounded batch loop | **Folded** — `max_batches` cap (≤1M rows/run). |
| 3 | MED (part) | non-deterministic `DELETE … LIMIT` | **Folded** — `ORDER BY submitted_at, job_id` (PK tiebreak, binlog-safe). |
| 3 | LOW | typo'd dry-run flag silently deletes | **Folded** — fail-safe parse: unrecognized → dry-run + warning. |
| 2 | MED | compose `LOG_CLEANUP_AT` tight-loop DoS | **Folded** — strict `HH:MM` validation, exit non-zero (fail loud, non-destructive), drop `|| date +%s` fallback. |
| 4 | MED | 600s cap only checked after a full DELETE | **Folded** — held connection + `SET SESSION innodb_lock_wait_timeout`. |
| 5 | MED | `innodb_lock_wait_timeout` misses metadata locks | **Folded** — also `SET SESSION lock_wait_timeout`. |
| 5 | MED | `DELETE … LIMIT` locks every SCANNED row | **Folded** — non-locking candidate-PK read → delete-by-PK with **full-predicate re-check** (locks only target PKs; strengthens the anti-active-deletion guarantee). Verified live incl. cascade + touched-row survival. |
| 6 | LOW | `ASYNC_JOB_RETENTION_LOCK_WAIT_SECONDS` not wired through compose | **Folded** — wired into the service env. |
| 6 | MED | unbounded FK cascade per DELETE | **Partially folded** — tunable `ASYNC_JOB_RETENTION_BATCH_SIZE` (proportionally shrinks the cascade). Child-first deletion **declined**: it would orphan events of a parent the predicate re-check then spares; the atomic FK cascade is the safe design. |
| 7 | MED | tunable knobs accept any positive int (re-opens giant-DELETE / defeats time cap) | **Folded** — `async_job_retention_bounded_int()` clamps DOWN to fail-closed maxima (batch ≤1000, lock-wait ≤30s) with a warning; 0/negative still fail closed. |
| 8 | LOW | `.env.example`/script header omit the knobs | **Folded** — documented the four vars + safe defaults. |
| 8 | LOW | 600s "ceiling" is a between-batch check | **Folded (doc)** — framed accurately as a **soft between-batch budget**; single statements bounded by the lock-wait timeout. |
| 9 | LOW | cleanup default 03:00 collides with the 03:00 backup | **Folded** — moved `LOG_CLEANUP_AT` default to 04:00 (compose + `.env.example` + doc). |
| 9 | MED | bounded prune runs AFTER the legacy unbounded log cleanup | **Folded (minimal, in-scope)** — reordered the scheduler loop so the fully-bounded `async_jobs` prune runs FIRST; it can never be starved, and being bounded it cannot starve the log cleanup. |
| 10 | LOW | planning spec/plan describe the pre-fold design | **Folded (doc)** — superseding notes added. |

## Declined findings (documented rationale — verify, don't blindly implement)

- **Round-6 HIGH — bare `exists(…, mode="function")` in `async-job-repository.R` / `async-job-worker.R`.** **False positive, out of scope.** Those files are **not in the S7 diff** (pre-existing, untouched). AGENTS.md documents — and a live check in the loaded API env confirms — that `config` masks `base::get` (no `mode` arg) **but `exists(…, mode="function")` is NOT masked** (verified: `exists("sum", mode="function")` returns `TRUE` in the fully-loaded worker env). Not a runtime bug; not S7's code.
- **Sibling `log-cleanup.R` single unbounded DELETE (raised rounds 3–9).** Out of S7 scope (separate slice / issue #105, own exact-match test contract). Mitigated for S7 by the scheduler **reorder** (bounded prune runs first) and the compose `||` (job-retention runs even if log cleanup fails); log-cleanup's DELETE is itself bounded by the 30-day window + `idx_logging_timestamp` + the server-default `innodb_lock_wait_timeout`. Fully batching/bounding it is a follow-up in the log-cleanup slice.

## Deferred (LOW, non-blocking; per coordinator)

- A committed `with_test_db_transaction()` status-matrix integration test (all statuses / retry-pending / boundary ages / cascade). The destructive path was **manually verified live** against the dev DB (documented above); a committed integration matrix is a nice-to-have but cannot run in the host gates (tests are not bind-mounted into the container) and belongs in a CI-DB harness.

## Decision

**SHIP for merge.** Round 10 = `Verdict: SHIP` (no BLOCKER/HIGH/MEDIUM); rounds 7–9 already reported "No BLOCKER or HIGH findings". Core predicate/parameterization/fail-closed/lock-safety proven across all 10 rounds and verified end-to-end against a live MySQL. Remaining item is a deferred LOW integration test.
