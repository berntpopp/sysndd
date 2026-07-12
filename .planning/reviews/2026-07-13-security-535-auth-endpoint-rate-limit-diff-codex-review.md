# Codex adversarial diff review — #550 auth endpoint rate limit

Model: `gpt-5.6-sol`; reasoning effort: `xhigh`; sandbox: `read-only`.
Final base: `bd2b4322` (merged #551 prerequisite). Raw CLI transcripts remain in
`/tmp`; this file is the durable review and disposition record.

## Round 1 — FIX-FIRST

Findings and dispositions:

- HIGH: XFF provenance was not anchored to an immediate peer. Disposition:
  architecture-specific rejection. The accepted #550/S6 contract requires the
  rightmost-untrusted-hop algorithm; shipped Compose exposes only Traefik, which
  appends the observed peer, strips alias headers, and forwards to an API with no
  public host port. Direct API ingress is explicitly unsupported and documented.
- HIGH: unbounded XFF processing. Fixed with a 4 KiB header limit and 32-hop cap
  before splitting; oversized input falls back to `REMOTE_ADDR`.
- MEDIUM: unsafe `MAX * MAX_TRACKED` cross-product. Fixed with an auth aggregate
  budget of 2,000,000 timestamps.
- MEDIUM: authenticate and reset lacked strict JSON media/object/scalar checks.
  Fixed with `application/json`, named-object, and scalar-string validation.
- MEDIUM: weak endpoint proof. Tests now cover malformed N+1 denial,
  pre-side-effect behavior, real A/B client isolation, positive integer
  `Retry-After`, and credential-free responses.
- LOW: S6 failure observability and test cleanup. Fixed with request-free static
  warnings and `on.exit()` cleanup.

## Round 2 — FIX-FIRST

One HIGH remained: Plumber's default JSON parser ran before endpoint guards.
The locked Plumber 1.3.2 `none` registration uses invalid regex `*`, so a
route-local `auth_body_raw` parser wraps `parser_none` with valid regex `.*`.
All three protected routes use it. A mounted-router regression proves malformed
JSON reaches 429 before JSON decoding.

Other findings folded: trusted-CIDR configuration is bounded to 4 KiB / 32
entries; malformed denied decisions fail closed; Playwright receives a bounded
test quota and retains XFF alias stripping; touched tests were split so every
touched handwritten source/test file is under 600 lines.

## Round 3 — FIX-FIRST

One HIGH remained: the root postroute logger decoded, sanitized, and re-encoded
denied bodies after a 429. Fixed by marking protected auth bodies sensitive and
returning a fixed sentinel before forcing Plumber's delayed `postBody`. The real
root `pr_mount()` regression proves the denied body is not materialized.

Round 3's strict-signup finding was also folded (`simplifyVector = FALSE`, named
object, scalar strings), and the aggregate cap now reserves the shared overflow
bucket: `(MAX_TRACKED + 1) * MAX <= 2,000,000`.

## Round 4 — FIX-FIRST

One HIGH remained: the marker covered denied requests only, so an admitted but
malformed unnamed JSON array could be persisted verbatim by postroute logging.
Fixed by setting the body-sensitive marker before every auth limiter decision.
The mounted test proves an admitted malformed secret and a denied malformed body
both log only `[AUTH_REQUEST_BODY]`.

## Round 5 — FIX-FIRST

One HIGH remained in the exception path: `sanitize_request()` still forwarded
raw `req$args`, `req$body`, and `req$argsBody` to `errorHandler()` logging after
an admitted downstream exception. Fixed by checking the marker before touching
body-derived fields, omitting args/argsBody, and emitting only the sentinel. A
mounted child with the production error handler deliberately throws after the
real guard; captured `log_error` input contains no credential.

## Round 6 — APPROVE

Final verdict:

> No concrete findings. Round 5's HIGH is closed: the auth marker is set before
> admission work, `sanitize_request()` omits all body-derived fields when
> marked, and the mounted-child exception test exercises the production error
> handler.

`BLOCKER/HIGH remaining: no`.

Optional, non-blocking defenses were an edge request-body byte cap and a
centralized counter for multi-replica deployments. Neither changes the accepted
single-Traefik/single-API architecture or #550 scope.

## Verification evidence

- Targeted RED-to-GREEN evidence covered N+1, independent callers, spoofed XFF,
  malformed config/CIDRs/decisions, Retry-After, parser order, strict signup
  shape, aggregate overflow accounting, normal postroute logging, and exception
  logging.
- Final `make test-api-fast`: PASS 6344, FAIL 0, SKIP 314. Skips were classified
  by the repository runner; no SKIP was treated as PASS.
- `make code-quality-audit`: green.
- `make lint-api`: 175 R files, zero findings.
- `git diff --check`: green.
- Base and Playwright Compose renders: green; the overlay retains all three XFF
  alias-removal labels.
- Touched handwritten source/test files above 600 lines: none.
- Live Traefik verification with `AUTH_ENDPOINT_PER_CALLER_MAX=2`: client A
  received 400, 400, then 429 with `Retry-After: 60`; a network-distinct client
  B received 400 rather than 429. No request body or credential was printed.
  The API was restored to master mounts and confirmed healthy afterward.
