Act as an adversarial staff security engineer. Review the implementation plan at
.planning/superpowers/plans/2026-07-13-security-535-auth-endpoint-rate-limit-plan.md
for SysNDD issue #550. This is security-critical.

Goal: rate-limit public body-only POST /api/auth/authenticate, /api/auth/signup,
and /api/user/password/reset/request. Extract a truly generic per-caller limiter
from functions/clustering-submit-throttle.R, retaining the S6 security properties:
rightmost-XFF fingerprint selected after trusted proxies, bounded memory under
rotating client IDs, fail-closed guard, and base::get/base::exists in the loaded
R environment. Reuse safely; do not duplicate internals. Each denied request must
be 429 with valid Retry-After; internal limiter failure must deny (503). The guard
must execute before database authentication, signup DB/email, and reset DB/email.
Inputs must stay JSON body only; never log credentials, emails, raw request bodies,
or query strings. Existing mount_endpoint problem+json semantics must remain.

Inspect adjacent public authentication routes and the S6 throttle implementation,
tests, source order, Traefik XFF alias stripping, and deployment configuration.
Look for bypass, spoofing, memory DoS, shared-bucket collateral damage, response
leaks, header injection, source-order/masked-get failures, and tests that could
pass without exercising endpoint behavior. Be concrete, severity-ranked, concise.
End with `Verdict: SHIP` only if no blocker/high remains, otherwise
`Verdict: FIX-FIRST`.
