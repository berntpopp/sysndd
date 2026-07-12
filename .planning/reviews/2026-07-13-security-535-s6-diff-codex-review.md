# S6 diff — Codex adversarial review (gpt-5.6-sol, xhigh) — Verdict: SHIP (round 6)

PR #547 — per-caller admission throttle for the two PUBLIC clustering submit routes
(`POST /api/jobs/clustering/submit`, `POST /api/jobs/phenotype_clustering/submit`),
slice S6 of umbrella hardening #535. Fresh full adversarial re-review after the fold.

Deep adversarial diff review run read-only via
`codex exec -s read-only -c model_reasoning_effort=xhigh`, iterated to convergence over
six rounds. Each round's BLOCKER/HIGH (plus cheap MEDIUM/LOW) folded TDD red→green before
re-review.

## Round history

- **CI blocker (fixed first):** bare `get()`/`exists()` with `envir=`/`inherits=` in
  `clustering-submit-throttle.R` — `config::get` masks `base::get` in the loaded API env,
  a runtime 500 on the second submit and a `test-unit-base-exists-get-guard.R` failure.
  Namespaced all four to `base::`.
- **Round 1 → FIX-FIRST:** BLOCKER masked verbs (already fixed); BLOCKER cache-hit path
  bypassed the throttle and grew `async_jobs` unbounded; HIGH XFF underscore-alias
  collision; HIGH fail-open/500 + drift; MEDIUM IPv6 rotation & key length; MEDIUM test
  labels / config; MEDIUM multi-replica; LOW design doc.
- **Round 2 → FIX-FIRST:** BLOCKER Traefik must strip `X_Forwarded_For` aliases; HIGH
  store evicted active buckets + sort cost; MEDIUM `MAX=0` disables; MEDIUM pre-existing
  `ASYNC_PUBLIC_JOB_CAP` NA parse; MEDIUM multi-replica.
- **Round 3 → FIX-FIRST (no BLOCKER):** HIGH institutional-front-proxy `trustedIPs`;
  MEDIUM IPv6 `::` expansion correctness; LOW ceilings + `MAX_TRACKED` compose.
- **Round 4 → FIX-FIRST (no BLOCKER):** HIGH fixed hop-index spoofable when hops>1 +
  direct ingress; MEDIUM fail-open on invalid params; MEDIUM O(n) `length(env)`; LOW
  `ASYNC_PUBLIC_JOB_CAP` compose.
- **Round 5 → FIX-FIRST (no BLOCKER/HIGH/LOW):** single MEDIUM — IPv6 trusted proxy never
  matches (trust evaluated on the /64 key).
- **Round 6 → SHIP.**

## Key remediations folded

- **Admission-first:** the guard runs at function entry in BOTH submit services, before
  any DB/cache/duplicate work; a cache hit no longer bypasses the limit or grows
  `async_jobs`.
- **Non-spoofable client IP:** replaced the fixed hop-index with a trusted-proxy CIDR
  WALK (`CLUSTERING_SUBMIT_TRUSTED_PROXY_CIDRS`) — X-Forwarded-For scanned right-to-left,
  first address NOT in a trusted CIDR wins. Unspoofable even with direct ingress or a
  forged trusted-CIDR hop on the left. Empty default (shipped single-Traefik edge) = the
  rightmost Traefik-appended hop. Real IPv4 AND IPv6 CIDR/exact matching; trust evaluated
  on the canonical full address, `/64` grouping applied only to the selected client.
- **Traefik `api-strip-xff-alias` middleware** deletes `X_Forwarded_For` /
  `X-Forwarded_For` / `X_Forwarded-For` before forwarding (Plumber folds them into the
  same CGI field).
- **Fail-closed:** the shared admission guard wraps the throttle in `tryCatch` and returns
  `503 THROTTLE_UNAVAILABLE`; invalid `max_n`/`window_s` `stop()`; no env kill-switch
  (floors/ceilings can never disable the control).
- **Bounded store, no active eviction:** saturation routes new callers into one shared
  overflow bucket (never evicts an active caller); sort-free, window-gated reclaim; O(1)
  tracked-caller counter.

## Round-6 verdict (verbatim)

BLOCKER / HIGH / LOW: None.

MEDIUM — pre-existing, outside this diff: `api/endpoints/phenotype_endpoints.R:111`,
`api/core/filters.R:67`, `api/functions/async-job-provider-handlers.R:238` and other
unchanged runtime files still use bare `exists(..., mode=/envir=)`. (Follow-up: expand
`test-unit-base-exists-get-guard.R` beyond `inherits=` and namespace those calls.)

Confirmed sound: XFF walked right-to-left with aliases stripped at Traefik; blank/missing
XFF falls back to validated `REMOTE_ADDR` then `"unknown"`; store cardinality and
timestamp vectors bounded, reclamation linear + window-gated; internal errors fail closed
as controlled 503s; both public services use the same guard first; 429 has a valid integer
`Retry-After` + matching body; unset/zero/negative/malformed/oversized limits cannot
disable the throttle; other enqueue paths role-gated; no bare masked calls added by this
diff. `git diff --check` and `docker compose config --quiet` passed.

Verdict: SHIP
