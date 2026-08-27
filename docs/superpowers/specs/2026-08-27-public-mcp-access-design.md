# Public MCP Access Design

**Issue:** [#629](https://github.com/berntpopp/sysndd/issues/629)

**Status:** Approved for implementation after adversarial review

## Problem

Production intentionally serves the SysNDD MCP transport at
`https://sysndd.dbmr.unibe.ch/mcp` without client credentials. The repository
describes a different deployment: Compose keeps the sidecar internal, the
deployment guide requires a protected operator overlay, the canonical agent
policy forbids public unauthenticated MCP, and the public information page asks
users for a bearer token that does not exist.

The mismatch is the root cause. The approved-public read boundary is not
changing: MCP continues to use its attested SELECT-only database principal and
public projection views.

## Requirements

1. Enabling the opt-in production Compose `mcp` profile exposes exact-path MCP
   protocol traffic at `/mcp` without authentication.
2. Ordinary browser `GET /mcp` navigation continues to render the Vue
   information page.
3. Public protocol traffic is rate-, body-, concurrency-, and read-time bounded
   before it reaches the single R process.
4. Public reachability must not give the MCP container outbound internet access.
5. Rejections generated at the edge must be observable without logging request
   bodies, headers, or query parameters.
6. Documentation, canonical agent policy, tests, and client setup instructions
   state that the production endpoint is public and credential-free and do not
   request a bearer token.
7. The approved-public, read-only, no-external-call, and no-generation MCP
   invariants remain unchanged.
8. Fast structural tests and an isolated live-Traefik smoke make the routing and
   abuse-control posture executable rather than comment-only.

## Standards Position

MCP authorization is optional. SysNDD deliberately does not authenticate this
endpoint because all callers receive the same approved public research data,
there are no user-specific authorization decisions, and there are no
write-capable tools. If private, user-specific, or write-capable tools are ever
added, this decision must be revisited and MCP-compliant OAuth used before those
tools are exposed.

The Streamable HTTP Origin check is retained and tested, but it is not described
as authentication or an abuse control. Its purpose is to reject untrusted
browser-originated requests and DNS-rebinding attacks. Server-to-server MCP
clients normally omit `Origin`; an absent Origin remains accepted. The canonical
production Origin is accepted through the exact `MCP_ALLOWED_ORIGINS` allowlist,
while empty, malformed, and untrusted third-party values fail closed with 403.

The substantive controls are:

- the attested SELECT-only principal limited to approved-public projection views;
- bounded and validated tool arguments and response budgets;
- no writes, raw SQL/R, external provider calls, or on-demand LLM generation;
- no egress-capable network attached to the MCP container;
- shared edge request-rate, POST concurrency, request-body, and read-time limits.

References:

- [MCP authorization](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization)
- [MCP Streamable HTTP transport](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)
- [MCP security best practices](https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices)
- [Traefik routing rules](https://doc.traefik.io/traefik/reference/routing-configuration/http/routing/rules-and-priority/)
- [Traefik rate limiting](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/ratelimit/)
- [Traefik in-flight request limiting](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/inflightreq/)
- [Traefik request buffering](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/buffering/)

## Architecture

### Network isolation

Add a dedicated `sysndd_mcp_edge` bridge with `internal: true`. Traefik joins
that network in addition to its existing public `proxy` network; MCP joins it in
addition to the internal `backend` database network. The MCP service does not
join `proxy`. Its per-service `traefik.docker.network` label selects
`sysndd_mcp_edge`.

This lets Traefik reach port 8787 without restoring internet egress to the MCP
container or placing Traefik on the database network.

### Routing

Two priority-200 routers take only protocol-shaped traffic from the priority-1
app catch-all:

- exact `POST /mcp` for JSON-RPC messages;
- exact `GET /mcp` whose `Accept` header contains the case-insensitive
  `text/event-stream` media-type token (not an arbitrary substring).

Traefik is pinned to v3.7.3 because the query-parameter access-log privacy
setting requires that patch level. It uses the singular `HeaderRegexp` matcher. Both routers explicitly
bind to service `mcp`, and both strip `/mcp` before forwarding to the `mcptools`
root endpoint. Ordinary browser GET requests remain on the Vue app.

The pinned `mcptools` transport currently returns 405 for GET, which is permitted
when a Streamable HTTP server does not offer a standalone SSE listening stream.
Routing an SSE-shaped GET to MCP therefore yields a protocol-appropriate 405
instead of misleading SPA HTML. The UI and docs must not claim that standalone
SSE is currently supported. The server is stateless and issues no session ID;
DELETE-based session termination is therefore not offered. Direct browser CORS
clients and `/mcp/` are outside the v1 contract.

### Edge controls

The public route uses fixed source-controlled values so Traefik's zero-means-
disabled defaults cannot silently remove a control:

- **Shared rate:** 120 requests per minute per request Host, burst 20. The router
  matches one production Host, making this a deliberately shared global bucket.
  This remains correct behind the current institutional TLS proxy and resists
  distributed source-address rotation without trusting client-supplied XFF.
- **POST concurrency:** four fully received JSON-RPC requests in flight per
  request Host. The criterion is explicit. The GET router does not share this
  small work cap because a future long-lived stream must not starve POST work.
- **Body size:** 262,144 bytes (256 KiB) for POST. Oversized bodies receive 413
  before R parses them.
- **Read time:** the `web` entrypoint's 60-second whole-request read timeout is
  made explicit. Slow or incomplete uploads cannot hold Traefik indefinitely.

The POST middleware order is `shared rate -> body limit -> in-flight -> strip`.
Rate rejection is cheapest; buffering reads and caps the body within the edge
timeout; only a complete admitted request occupies an R-work slot. The GET chain
is `shared rate -> strip`.

The local token bucket is sufficient for the shipped single-Traefik topology.
Operators who scale Traefik horizontally must use the distributed Redis-backed
limiter or document that each instance has an independent bucket.

### Edge observability

Enable Traefik JSON access logging globally but disable it by default on the
shared `web` entrypoint. Opt only the two MCP routers back in. Headers remain
dropped, query parameters are dropped explicitly, and bodies are never logged.
Existing Docker log rotation bounds storage. This records route, status, peer,
and duration for successful MCP traffic and edge-generated 403/405/413/429
responses without widening logs for the rest of the application.

### User-facing and repository contract

`McpInfoView.vue` will state that the displayed URL is both the browser
information route and the credential-free protocol URL. Product guidance remains
conservative: leave authentication unset, or select the client's unauthenticated
option if it requires a choice. It will explain shared capacity, HTTP 429,
backoff, compact calls, and caching stable results.

Update all persistent sources of the old policy:

- `AGENTS.md`;
- base and development Compose comments;
- API and deployment chapters;
- the Vue page, Vitest, and Playwright spec;
- the Unreleased changelog.

The subsystem skill already defines only the read/data-safety contract and does
not assert private reachability, so it does not change.

## Error behavior

- No Origin or no authentication header: protocol handling proceeds.
- Exact configured Origin: protocol handling proceeds.
- Empty, malformed, or untrusted Origin: 403 from the patched MCP transport.
- SSE-shaped GET: 405 from the current transport.
- Oversized POST: 413 from Traefik.
- Shared rate or POST concurrency exceeded: 429 from Traefik.
- Tool validation/availability errors: the existing MCP JSON error envelope.
- Sidecar unavailable: the existing proxy/service failure response.

## Testing

Implementation follows test-driven development:

1. Parse Compose as YAML and compare exact label keys/values, service bindings,
   network membership, network isolation, middleware chains, and observability.
2. Run that test red before changing Compose.
3. Add an isolated Docker smoke that reads the resolved labels from the base
   Compose model, attaches them to disposable app/MCP stubs behind Traefik 3.7,
   and proves router status plus browser HTML, POST forwarding, GET 405, 413, and
   429 behavior. It never contacts production.
4. Normalize rendered whitespace in Vitest and assert positive public/no-auth
   guidance plus comprehensive negative token/protected wording.
5. Scope documentation assertions to each MCP section and the Unreleased
   changelog rather than concatenating entire files.
6. Update the focused Playwright information-page assertion; the protocol test
   remains environment-gated because the standard Playwright stack does not run
   the MCP profile.
7. Run Compose resolution, isolated edge smoke, targeted Vitest/testthat,
   frontend lint/type-check, API lint, code-quality audit, and pre-commit.

The already-performed production probe is limited to one credential-free
initialize (200) and one invalid-Origin initialize (403). Do not rate-limit or
body-limit test production.

## Non-goals

- Adding OAuth, API keys, accounts, per-user quotas, billing, or identity.
- Trusting arbitrary `X-Forwarded-For` or discovering institutional proxy CIDRs.
- Changing MCP schemas, tools, resources, prompts, queries, or data classes.
- Adding Redis solely for the shipped single-Traefik deployment.
- Adding standalone SSE, sessions, browser CORS, or `/mcp/` compatibility.
- Load-testing production.

## Deployment and rollback

After deployment, verify browser `GET /mcp`, credential-free initialize and
`tools/list`, absent-Origin success, invalid-Origin rejection, and MCP-only
access-log entries. The isolated smoke—not production—proves 405/413/429.

Monitor MCP router access logs for 4xx volume and request duration. Any limit
change is a reviewed Compose change. Horizontal Traefik scaling requires an
explicit limiter review.

Rollback must revert the Compose route/network/observability configuration and
the public-access UI/docs/policy in the same release. Removing only the labels
would recreate issue #629 in the opposite direction. The read-only database
boundary and MCP schema are unchanged in either state.
