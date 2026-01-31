---
phase: 08-frontend-dockerfile-modernization
plan: 01
subsystem: infra
tags: [docker, node, nginx, alpine, security, healthcheck]

# Dependency graph
requires:
  - phase: 07-api-dockerfile-optimization
    provides: Multi-stage build patterns, non-root user approach, HEALTHCHECK patterns
provides:
  - Node.js 20 LTS Alpine builder for Vue.js frontend
  - nginx-unprivileged:1.27.4-alpine production image running as UID 101
  - Non-privileged port 8080 for nginx
  - HEALTHCHECK instruction with wget
  - Brotli compression modules functional in non-root context
affects: [09-developer-experience, production-deployment]

# Tech tracking
tech-stack:
  added: [nginxinc/nginx-unprivileged, node:20-alpine]
  patterns: [non-root nginx, Alpine minimal images, BuildKit cache mounts for npm]

key-files:
  created: []
  modified: [app/Dockerfile, app/docker/nginx/nginx.conf, app/docker/nginx/local.conf, docker-compose.yml]

key-decisions:
  - "Node.js 20 LTS over 22/24 for Vue 2.7 compatibility (OpenSSL 3.0 MD4 issue)"
  - "nginxinc/nginx-unprivileged runs as nginx user (UID 101) by default"
  - "Port 8080 for non-root operation (ports <1024 require root privileges)"
  - "PID file at /tmp/nginx.pid (writable by non-root user)"
  - "wget for health checks (included in Alpine busybox, no curl needed)"
  - "10s start_period for health check (nginx starts faster than R/plumber)"

patterns-established:
  - "Frontend follows same security pattern as API: non-root user, Alpine base, health checks"
  - "BuildKit cache mounts for dependency managers (npm ci --mount=type=cache)"
  - "3-stage build: builder (Node Alpine) + module compiler (Debian) + production (nginx-unprivileged Alpine)"

# Metrics
duration: 2min
completed: 2026-01-22
---

# Phase 08 Plan 01: Frontend Dockerfile Modernization Summary

**Node.js 20 Alpine builder with nginx-unprivileged:1.27.4-alpine production image, non-root user (UID 101), port 8080, and wget-based health checks**

## Performance

- **Duration:** 2 minutes
- **Started:** 2026-01-22T12:19:49+01:00
- **Completed:** 2026-01-22T12:21:28+01:00
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Upgraded frontend build from Node.js 16 Bullseye to Node.js 20 Alpine (LTS with Vue 2.7 compatibility)
- Migrated production image from nginx:1.27.4 to nginxinc/nginx-unprivileged:1.27.4-alpine (non-root, Alpine minimal)
- Configured nginx for non-root operation (PID at /tmp, port 8080, no user directive)
- Added HEALTHCHECK instruction with wget for container health monitoring
- Updated docker-compose.yml health check and Traefik routing for port 8080

## Task Commits

Each task was committed atomically:

1. **Task 1: Modernize app/Dockerfile with Node 20 Alpine and nginx-unprivileged** - `ef44011` (feat)
   - Rewritten as 3-stage build with Node 20 Alpine builder, brotli module builder, and nginx-unprivileged production
   - Added BuildKit cache mount for npm ci
   - Added HEALTHCHECK instruction with wget
   - Changed EXPOSE from 80 to 8080
   - Added --chown=nginx:nginx to all COPY commands

2. **Task 2: Update nginx configs for non-root operation** - `f5f5165` (feat)
   - Removed 'user nginx;' directive (incompatible with non-root)
   - Changed PID file from /var/run/nginx.pid to /tmp/nginx.pid
   - Changed listen ports from 80 to 8080 in local.conf

3. **Task 3: Update docker-compose for non-root app service** - `e5c5862` (feat)
   - Changed health check from curl to wget (Alpine busybox)
   - Updated health check port from 80 to 8080
   - Reduced start_period from 60s to 10s (nginx starts faster)
   - Updated Traefik loadbalancer port label from 80 to 8080

## Files Created/Modified

- `app/Dockerfile` - 3-stage build: Node 20 Alpine builder, Debian-based brotli module compiler, nginx-unprivileged Alpine production
- `app/docker/nginx/nginx.conf` - Removed 'user nginx;' directive, changed PID to /tmp/nginx.pid for non-root writability
- `app/docker/nginx/local.conf` - Changed listen directives from port 80 to 8080 (IPv4 and IPv6)
- `docker-compose.yml` - Updated app service health check to use wget with port 8080, updated Traefik label

## Decisions Made

**Node.js 20 LTS over 22/24:**
- Node.js 22+ has OpenSSL 3.0 MD4 hash deprecation that breaks Vue CLI 5 + webpack 5 combination
- Node.js 20 LTS is current LTS with support through 2026-04-30
- Vue 2.7 is stable on Node 20 with webpack 5

**nginxinc/nginx-unprivileged over standard nginx:**
- Pre-configured to run as nginx user (UID 101)
- No need for manual user configuration
- Follows same security pattern as API (non-root operation)

**Port 8080 instead of 80:**
- Non-root users cannot bind to privileged ports (<1024)
- 8080 is standard non-privileged HTTP port
- Traefik routes external traffic to container port 8080

**PID file at /tmp:**
- Default /var/run/nginx.pid not writable by non-root user
- /tmp is world-writable and appropriate for ephemeral PID files

**wget for health checks:**
- Alpine busybox includes wget by default
- curl would require additional package installation
- wget --spider is lightweight (doesn't download content)

**10s start_period instead of 60s:**
- nginx starts much faster than R/plumber API
- Vue.js static assets served immediately after nginx start
- Shorter start_period prevents delayed health status

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all tasks completed without issues.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Phase 9 (Developer Experience):**
- Frontend container now uses same security patterns as API (non-root, Alpine, health checks)
- Port 8080 provides consistent non-privileged port across services
- HEALTHCHECK enables Docker to monitor container health
- Brotli compression modules functional in non-root context

**Blockers/Concerns:**
- None

**Testing notes:**
- Full build test recommended to verify brotli modules compile and copy correctly
- Container runtime test should verify nginx runs as UID 101 (non-root)
- Health check should respond within 10 seconds of container start

---
*Phase: 08-frontend-dockerfile-modernization*
*Completed: 2026-01-22*
