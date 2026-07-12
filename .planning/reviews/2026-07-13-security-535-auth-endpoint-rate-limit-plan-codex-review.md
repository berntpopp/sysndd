# Codex adversarial plan review — #550 auth endpoint rate limit

Model: `gpt-5.6-sol`; reasoning effort: `xhigh`; sandbox: `read-only`.

## Round 1

The requested background command was started twice, but the runner reaped the
background child before it wrote output. The identical foreground command then
started a broad repository review and emitted a FIX-FIRST assessment. The
actionable findings were folded into the plan: explicit Compose environment
wiring; preservation of the bounded overflow bucket; deployment documentation
for the single-process/multi-replica limitation; real mounted live verification;
and guard coverage for source order, masked base lookups, XFF spoofing, malformed
configuration, and pre-side-effect denial. Raw CLI transcripts are intentionally
not committed; this disposition is the durable review record.

## Round 2 (bounded follow-up)

The review was constrained to a no-tool final verdict to avoid the CLI's
post-inspection non-response. It returned:

> Verdict: FIX-FIRST — trust X-Forwarded-For only from explicitly trusted
> proxies and derive the client IP from the rightmost untrusted hop to prevent
> spoofing-based rate-limit bypass.

### Disposition

Valid and folded. Task 2 now makes the right-to-left validated-hop traversal a
non-negotiable generic-module invariant. Task 3 preserves S6's direct-Traefik
empty-trust default and explicitly documents that only genuine upstream proxy
CIDRs may be trusted. The RED tests include a spoofed-leftmost XFF case and an
auth-adapter rightmost-hop assertion. No production code was written before this
plan-review disposition.
