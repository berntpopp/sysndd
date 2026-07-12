# S6 — Clustering Admission Controls (per-caller submit throttle) — Design

Date: 2026-07-12
Issue: [#535](https://github.com/berntpopp/sysndd/issues/535) — umbrella hardening, slice **S6**
(audit finding P2-1). Parent design: `.../specs/2026-07-11-security-hardening-535-design.md` §3 (S6).

## 1. Gap
The two **public, unauthenticated** clustering submit routes (`/api/jobs/clustering/submit`,
`/api/jobs/phenotype_clustering/submit`) create expensive worker jobs. Today the only admission
control is a **global** queue-depth cap (`async_job_capacity_exceeded()` / `async_job_active_count()`,
`ASYNC_PUBLIC_JOB_CAP=8`): it bounds total in-flight jobs but **a single caller can consume all 8
slots** (no per-caller dimension), and there is no per-IP throttle anywhere in the API.

## 2. Design — extend the existing cap with a per-caller dimension (do not reinvent)
Add a **second admission dimension** layered on the existing global cap: a per-caller sliding-window
submit rate limit. Kept intentionally small and self-contained.

- **`async_job_submit_rate_limit(fingerprint, now, max_n, window_s, store)`** (in
  `async-job-service.R`, next to `async_job_capacity_exceeded`): a pure sliding-window limiter with an
  **injectable clock and store** (deterministic tests). Prunes timestamps older than `now - window_s`;
  allows and records if under `max_n`, else returns `allowed=FALSE` + a computed `retry_after`. A
  non-positive `max_n` disables it. Tunable via `CLUSTERING_SUBMIT_PER_CALLER_MAX` (default 5) and
  `CLUSTERING_SUBMIT_WINDOW_SECONDS` (default 60).
- **`async_job_submit_fingerprint(req)`**: prefers the real client IP behind the trusted reverse
  proxy — the **first hop of `X-Forwarded-For`** (set by Traefik) — over `REMOTE_ADDR`, which in the
  Compose topology is the **proxy container's** address (shared by every client, so throttling on it
  alone would rate-limit all callers as one). Falls back to `REMOTE_ADDR`, then `"unknown"`.
- Both submit services call the throttle **after** the cache-hit and duplicate-job short-circuits
  (those are cheap and must not consume a caller's budget) and **before** the global capacity cap;
  on throttle → `429 + Retry-After` (`RATE_LIMITED`).

### Why in-memory / process-local (documented trade-off)
The store is an in-process environment, so a caller's window is per API process. In the single-API
Compose topology this is exact; with multiple API replicas each enforces independently while the
**DB-backed global cap remains the cross-process backstop**. This is proportionate defense-in-depth
without a schema change or a heavyweight rate-limiting framework — it *extends* the existing cap
rather than replacing it. A DB-backed per-caller counter (a `submitter_fingerprint` column + a
windowed count) is the cross-replica upgrade path, noted as a follow-up.

## 3. Tests (deterministic, pure — host-runnable, no DB)
`test-unit-clustering-submit-throttle.R`: allows up to `max_n` then throttles; window slides;
`retry_after` reflects the oldest in-window entry; distinct fingerprints independent; non-positive cap
disables; empty/NULL fingerprint collapses to one bucket; fingerprint prefers XFF first hop, falls
back to REMOTE_ADDR then `"unknown"`.

## 4. Verification
- Host R: the pure throttle test (passes). `make lint-api`; file sizes < 600.
- **Live (recommended, flagged):** behind the dev Traefik, confirm `X-Forwarded-For` carries the real
  client IP so the fingerprint is per-client not per-proxy (the correctness-critical prod behavior);
  drive N+1 rapid submits from one client → 429 + Retry-After, and confirm a second client is
  unaffected. Codex adversarial review before PR.

## 5. Out of scope / non-goals
- No change to the global cap, the cache-first path, or the duplicate-job check.
- No authentication gate added (the routes stay public by product design; this bounds abuse, it does
  not gate access).
- Cross-replica per-caller accounting (DB-backed) is a follow-up.
