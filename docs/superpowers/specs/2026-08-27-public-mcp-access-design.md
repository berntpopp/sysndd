# Public MCP Access Design

**Issue:** [#629](https://github.com/berntpopp/sysndd/issues/629)

**Status:** Approved for implementation

## Problem

Production intentionally serves the SysNDD MCP transport at
`https://sysndd.dbmr.unibe.ch/mcp` without client credentials. The repository
describes a different deployment: `docker-compose.yml` keeps the sidecar on the
internal network, the deployment guide requires a protected operator overlay,
and the public information page tells users to obtain a bearer token. The live
service is usable, but the repository makes that behavior look accidental and
does not encode an abuse-control policy for it.

The mismatch is the root cause. The read boundary itself is not changing: MCP
continues to use the attested SELECT-only database principal and approved-public
projection views.

## Requirements

1. Enabling the opt-in Compose `mcp` profile exposes the MCP transport publicly
   at `/mcp` without authentication.
2. Normal browser navigation to `GET /mcp` continues to render the Vue
   information page.
3. Public protocol traffic is bounded before it reaches the single R process.
4. Documentation and client setup instructions state that the production
   endpoint is public and credential-free; they must not request a bearer token.
5. The approved-public, read-only, no-external-call, and no-generation MCP
   invariants remain unchanged.
6. Tests make the reachability and abuse-control posture explicit so a future
   deployment change cannot silently recreate the mismatch.

## Standards Position

MCP authorization is optional. The Streamable HTTP transport nevertheless
recommends authentication and requires Origin validation. SysNDD deliberately
does not authenticate this endpoint because it exposes the same approved public
research data to every caller, has no user-specific authorization decisions,
and offers no write-capable tools. Compensating controls are:

- the pinned `mcptools` transport's Origin validation;
- an attested SELECT-only database principal limited to public projection views;
- bounded, validated tool arguments and response budgets;
- no writes, raw SQL/R, external provider calls, or on-demand LLM generation;
- edge request-rate, concurrency, and body-size limits.

If private or user-specific tools are ever added, this decision must be revisited
and MCP-compliant OAuth used rather than accepting arbitrary bearer tokens.

References:

- [MCP authorization](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization)
- [MCP Streamable HTTP transport](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)
- [MCP security best practices](https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices)
- [Traefik rate limiting](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/ratelimit/)
- [Traefik in-flight request limiting](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/inflightreq/)
- [Traefik request buffering](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/buffering/)

## Architecture

### Routing

The existing opt-in `mcp` service joins both networks:

- `backend` for its SELECT-only MySQL connection;
- `proxy` so Traefik can reach the HTTP transport.

Two priority-200 Traefik routers take only protocol-shaped traffic from the
priority-1 app catch-all:

- `POST /mcp` for JSON-RPC messages;
- `GET /mcp` with an `Accept` header containing `text/event-stream` for
  Streamable HTTP/SSE compatibility.

The middleware chain strips `/mcp` before forwarding to the `mcptools` root
endpoint. A normal `GET /mcp` without the SSE accept header does not match the
MCP router and therefore continues to render `McpInfoView.vue`.

### Edge Controls

The public route uses fixed, source-controlled safe limits rather than
environment variables that can accidentally resolve to Traefik's disabling
zero value:

- **Rate:** 120 requests per minute per remote address, burst 20. IPv6 callers
  are grouped by `/64` so rotating addresses inside one allocation cannot create
  unlimited buckets.
- **Concurrency:** four in-flight MCP requests globally. This bounds queued work
  in front of the single R process and its two-connection DB pool.
- **Body size:** 262,144 bytes (256 KiB). Oversized JSON-RPC bodies receive 413
  from Traefik without being parsed by R.

Middleware order is `in-flight -> rate -> body limit -> strip prefix`: slow
uploads consume an in-flight slot, excessive frequency is rejected before body
buffering, and only admitted requests reach the sidecar.

Traefik's local token bucket is sufficient because the shipped deployment has
one Traefik instance. Operators who scale Traefik horizontally must replace it
with the distributed Redis-backed limiter or accept a per-instance effective
limit. Operators placing a trusted reverse proxy in front of Traefik must
configure forwarded-header trust and rate-limit IP selection together; otherwise
the proxy address becomes the shared bucket, which fails toward throttling rather
than bypassing the limit.

### User-Facing Contract

`McpInfoView.vue` will state:

- the displayed URL is both the human information route for browser navigation
  and the public protocol URL used by MCP clients;
- the protocol endpoint needs no SysNDD account, API key, or bearer token;
- clients should select "No authentication" when they request an auth method;
- calls may receive HTTP 429 and should retry with backoff;
- callers should cache stable results and prefer compact, focused requests.

Claude Code, Claude Desktop, Cursor, and generic browser-chatbot instructions
retain their credential-free URL/configuration examples. Product-specific UI
wording stays conservative where current official documentation does not prove
an exact label.

`documentation/03-api.qmd` describes the public runtime contract and its safety
boundary. `documentation/09-deployment.qmd` treats the public route as built-in,
documents the fixed limits and reverse-proxy/scaling caveats, and removes the
obsolete protected-overlay example. Compose comments use the same terminology.

## Error Behavior

- Invalid Origin: 403 from the pinned MCP transport.
- Oversized request: 413 from Traefik.
- Rate or concurrency limit exceeded: 429 from Traefik.
- Tool validation and availability errors: the existing MCP JSON error envelope.
- Sidecar unavailable: the existing proxy/service failure response.

Authentication errors are not part of the public v1 contract because no
credential is requested or interpreted.

## Testing

Implementation follows test-driven development:

1. Extend `McpInfoView.spec.ts` first so it fails while protected/token wording
   remains and passes only when credential-free public access and fair-use
   guidance are visible.
2. Add a focused R contract test first for the Compose routers, network
   attachment, absence of auth middleware, rate limit, IPv6 grouping, global
   in-flight cap, body cap, middleware order, and documentation alignment.
3. Run each test in its red state before changing production/configuration files.
4. Verify the final Compose model with `docker compose --profile mcp config`.
5. Run targeted Vitest and testthat files, frontend lint/type-check, API lint,
   `make code-quality-audit`, and the appropriate pre-commit gate.

The live deployment check is limited to one credential-free initialization and
one invalid-Origin initialization; abuse-control verification belongs in an
isolated local stack rather than load-testing production.

## Non-Goals

- Adding OAuth, API keys, accounts, quotas, billing, or user identity.
- Changing MCP schemas, tools, resources, prompts, repository queries, or data
  classes.
- Adding Redis solely for this single-Traefik deployment.
- Weakening the SELECT-only/public-projection attestation.
- Load-testing the production endpoint.

## Deployment and Rollback

After deployment, verify browser `GET /mcp`, credential-free MCP initialize and
`tools/list`, invalid-Origin rejection, and an isolated-stack 413/429 response.
Monitor Traefik 429/413 volume and MCP latency; adjust limits only through a
reviewed Compose change.

Rollback removes the MCP Traefik labels and `proxy` attachment, returning the
sidecar to internal-only reachability. The read-only database boundary and MCP
schema are unaffected in either state.
