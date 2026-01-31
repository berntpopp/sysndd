# Phase 6: Security and Compose Foundation - Context

**Gathered:** 2026-01-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish secure, modern Docker Compose infrastructure with Traefik reverse proxy and proper network isolation. This includes replacing dockercloud/haproxy with Traefik v3.6, adding .dockerignore files, configuring named networks and volumes, adding health checks to all services, updating MySQL, and setting resource limits.

</domain>

<decisions>
## Implementation Decisions

### Traefik Configuration
- Dashboard disabled entirely (security)
- Path-based routing: `/api/*` → API, `/*` → Frontend (single domain)
- No TLS termination in this phase (HTTP only, TLS handled externally or added later)
- Minimal logging: errors and warnings only

### Network Topology
- Two networks: `proxy` (public-facing) and `backend` (internal)
- MySQL isolated to `backend` network only — not accessible from proxy network
- API connects to both networks (receives traffic from proxy, talks to MySQL on backend)
- Frontend on proxy network only
- Traefik on proxy network only
- Networks are internal to this compose project (not external/shared)

### Health Check Behavior
- 60 second startup grace period for all services
- 3 consecutive failures before marking unhealthy
- 30 second check interval
- Restart policy: `unless-stopped` (restart on failure or daemon restart)

### Resource Limits
- Target environment: 8GB VPS with other containers running
- Memory limits only, no CPU limits (CPU shares naturally)
- API gets generous allocation: 4GB+ to handle peak memory operations
- MySQL: moderate allocation (~1GB)
- Frontend/Traefik: minimal allocation (~256MB each)
- OOM behavior: kill and restart (default Docker behavior)

### Claude's Discretion
- Exact memory numbers within the allocation strategy above
- Health check endpoint paths per service
- Traefik label syntax and router configuration
- .dockerignore patterns based on codebase analysis

</decisions>

<specifics>
## Specific Ideas

- API may need more than 4GB peak memory for certain operations — don't be too conservative with its limit
- Conservative overall sizing since the VPS hosts other containers

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-security-compose-foundation*
*Context gathered: 2026-01-21*
