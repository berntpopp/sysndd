---
phase: 66-infrastructure-fixes
plan: 01
subsystem: infra
tags: [docker, dockerfile, uid, horizontal-scaling, favicon]

# Dependency graph
requires:
  - phase: 66-RESEARCH
    provides: UID configuration strategy and scaling diagnosis
provides:
  - ARG-based UID/GID configuration in API Dockerfile
  - Horizontal scaling capability for API service
  - Restored favicon image
affects: [67-migration-coordination, 68-local-production-testing, deployment]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - ARG-based UID/GID for bind mount compatibility
    - Singleton vs scalable service distinction in docker-compose

key-files:
  created:
    - app/public/brain-neurodevelopmental-disorders-sysndd.png
  modified:
    - api/Dockerfile
    - docker-compose.yml

key-decisions:
  - "UID default 1000 (matches most Linux users) with --build-arg override"
  - "Remove container_name only from api service (enable scaling)"
  - "Keep container_name on singleton services (traefik, mysql, backup, app)"

patterns-established:
  - "Build-time UID/GID via ARG with sensible defaults"
  - "Scalable services omit container_name directive"

# Metrics
duration: 1min
completed: 2026-02-01
---

# Phase 66 Plan 01: Infrastructure Fixes Summary

**ARG-based UID/GID in Dockerfile (default 1000), removed API container_name for scaling, restored favicon PNG**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-01T19:39:45Z
- **Completed:** 2026-02-01T19:41:01Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- API Dockerfile now uses configurable UID/GID via build-arg (default 1000)
- API service can scale horizontally with `docker compose --scale api=N`
- Favicon image restored to public root, fixing 404 errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Add ARG-based UID/GID to API Dockerfile** - `9e34a23e` (feat)
2. **Task 2: Remove container_name from API service** - `c9741eab` (feat)
3. **Task 3: Copy favicon image to public root** - `ca7d1a67` (fix)

## Files Created/Modified

- `api/Dockerfile` - Added ARG UID=1000, ARG GID=1000, templated useradd/groupadd
- `docker-compose.yml` - Removed container_name from api service
- `app/public/brain-neurodevelopmental-disorders-sysndd.png` - Restored favicon (192x192 PNG)

## Decisions Made

- **UID default 1000:** Matches most Linux host users; VPS deployments can override with `--build-arg UID=1001`
- **Selective container_name removal:** Only api service needs scaling; singleton services (traefik, mysql, backup, app) retain names for predictable management

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Infrastructure fixes complete for Phase 66
- API container can now write to bind-mounted directories when built with matching UID
- Horizontal scaling enabled for production VPS deployment
- Ready for Phase 67 (Migration Coordination) or Phase 68 (Local Production Testing)

---
*Phase: 66-infrastructure-fixes*
*Completed: 2026-02-01*
