Do not call tools. Give a concise final adversarial plan review based only on this
implementation proposal for #550:

1. Move all S6 generic internals (safe integer config parser; IPv4/IPv6 parser,
CIDR trust matching; rightmost-XFF non-spoofable fingerprint; bounded active
caller store with idle reclaim/overflow; injected-clock sliding-window decision;
failure-safe admission result) from clustering-submit-throttle.R into a new
per-caller-throttle.R.
2. Keep clustering wrappers and the exact current S6 config/API/response shape.
3. New auth-endpoint-throttle.R gets a separate store plus AUTH_ENDPOINT_* config
(max, window, max tracked, trusted proxy CIDRs) and turns limiter errors into
503 THROTTLE_UNAVAILABLE + Retry-After. Excess returns 429 RATE_LIMITED +
positive Retry-After.
4. Source generic before S6 and auth adapter in bootstrap/load_modules.R.
5. First executable line of POST /api/auth/signup, POST /api/auth/authenticate,
and POST /api/user/password/reset/request calls the auth guard and returns on
denial, before JSON parsing/DB/email/password work. Inputs remain JSON body only.
6. Deterministic tests check N/N+1 status/header, independent client fingerprint,
spoofed leftmost XFF, bounded rotation, failure closed, and that denied handlers
cannot call auth/DB/email services. Deployment docs provide env controls.

Find security defects or missing tests that would permit bypass, spoofing, state
DoS, resource exhaustion, information disclosure, invalid Retry-After, altered
S6 behavior, source-order/masked base::get failure, or problem+json regression.
Rank only concrete blocker/high/medium/low issues. End exactly with
`Verdict: SHIP` if there are no blocker/high findings, otherwise
`Verdict: FIX-FIRST`.
