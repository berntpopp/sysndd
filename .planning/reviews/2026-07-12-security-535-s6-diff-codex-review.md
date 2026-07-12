# S6 diff — Codex adversarial review (gpt-5.6-sol, xhigh) — Verdict round 1: FIX-FIRST → folded

## HIGH (folded round 2)
- **Unbounded store cardinality = memory DoS:** rotating X-Forwarded-For values each created a
  permanent 1-entry bucket (recorded before the global cap), so an attacker could grow process memory
  even while every request was 503'd. → Fixed: `.async_job_submit_sweep()` drops fully-idle
  fingerprints and hard-evicts the least-recently-active over `CLUSTERING_SUBMIT_MAX_TRACKED` (20000),
  bounding memory to O(cap).
- **X-Forwarded-For spoofing:** trusting the FIRST hop is client-spoofable → bucket rotation bypass.
  → Fixed: `async_job_submit_fingerprint()` now takes the proxy-appended hop `trusted_hops` positions
  from the RIGHT (Traefik=1 default, env `CLUSTERING_SUBMIT_TRUSTED_PROXY_HOPS`) — the appended hop is
  not client-forgeable; leftmost entries are never trusted.

## MEDIUM (folded)
- Unsafe env parsing (`as.integer("abc")` → NA silently disabled/corrupted the limiter). → Fixed:
  `.async_job_submit_env_int()` falls back to the safe default on any invalid value; the limiter also
  treats an NA/≤0 window as disabled-allow rather than crashing.
- (Not changed) Throttle runs after cheap indexed cache/dup checks but before job creation — it
  protects the expensive resource (worker jobs); the pre-checks are cheap. Documented residual.

## LOW (folded)
- Compose api service now passes `CLUSTERING_SUBMIT_*` env through (explicit env-map requirement).
- Attempt-limiter (records before capacity/create_job) — intentional (bounds attempts, not just
  successful creations).

## Confirmed correct (round 1)
Pruning / exact max_n boundary / expiry-at-oldest+window / retry_after rounding correct; non-positive
cap disables without storing; no within-process race; identical placement in both submit services;
`req$HTTP_X_FORWARDED_FOR` is the correct plumber mapping; no other anonymous heavy-submit route
(network-layout/maintenance/pubtator/snapshot/LLM are role-gated). Multi-replica per-process
enforcement documented.

## New tests (round 2): rightmost-hop + spoofing + 2-hop; bounded-store rotation; invalid-env-default.
Round-1 fixes are well-understood, mechanical guards; folded without a second full xhigh round to
conserve budget (all changes are additive guards with deterministic tests).
