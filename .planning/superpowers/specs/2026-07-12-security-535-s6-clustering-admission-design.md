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
- **`async_job_submit_fingerprint(req)`**: takes the client IP the **trusted reverse proxy appended**
  to `X-Forwarded-For` — the entry `CLUSTERING_SUBMIT_TRUSTED_PROXY_HOPS` positions from the **RIGHT**
  (Traefik = 1 hop → the **rightmost** entry). The proxy appends the address of the peer it actually
  saw, so that hop is not spoofable; the leftmost XFF entries are client-supplied and an attacker
  could rotate them to evade the limit or exhaust the store, so they are never trusted. The selected
  value must **validate as an IP** (`.async_job_submit_normalize_ip()`): a non-IP token (e.g. an
  injected `X_Forwarded_For` header-alias value) is discarded, IPv4 `:port` suffixes are stripped, and
  IPv6 is grouped to its **`/64`** so a whole allocation is one caller, not 2^64 buckets. Falls back to
  a validated `REMOTE_ADDR` (the proxy's own address in the Compose topology — coarse but unspoofable),
  then `"unknown"`. It never throws — crafted headers degrade to the `"unknown"` bucket.
- **`async_job_submit_admission_guard(req, res)`**: the single entry point both submit services call.
  Wraps the throttle in `tryCatch` and **fails CLOSED** on any internal error (`503
  THROTTLE_UNAVAILABLE + Retry-After`) so a throttle bug can neither 500 the endpoint nor silently
  admit. On throttle → `429 + Retry-After` (`RATE_LIMITED`). Sharing one guard also removes copy drift
  between the two services.
- Both submit services call the guard **FIRST — before any DB/cache/duplicate work** — so an abusive
  caller is rejected before it can do or provoke expensive work (a cache hit still writes a completed
  `async_jobs` row; the phenotype path collects five tables and builds the wide MCA matrix). It is
  layered on the global capacity cap that still runs after.

### Store bounding under rotation (no active-caller eviction)
Memory is capped at `CLUSTERING_SUBMIT_MAX_TRACKED` fingerprints. When the store is saturated with
**active** callers, a brand-new fingerprint is routed into a single shared **overflow bucket**
(collectively throttled) instead of evicting a legitimate caller's window — so X-Forwarded-For
rotation can neither exhaust memory nor reset an innocent caller's limit. Reclaim drops only
**fully-idle** buckets, is sort-free (`names()`, not the sorting `ls()`), and is time-gated to at
most once per window so a flood cannot force an O(n) scan on every request. There is **no env
kill-switch**: `CLUSTERING_SUBMIT_PER_CALLER_MAX` floors at 1 (a stray `=0`/invalid → default), all
limits clamp to sane ceilings, and the guard **fails closed** (`503 THROTTLE_UNAVAILABLE`) on any
internal error. The sibling `ASYNC_PUBLIC_JOB_CAP` parse was hardened the same way (an invalid value
no longer parses to `NA` and silently disables the DB-backed backstop).

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
