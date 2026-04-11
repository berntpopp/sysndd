---
phase: 12
plan: 05
subsystem: docker
tags: [vite, docker, dockerfile, compose, hmr, node24]
dependency-graph:
  requires: [12-01, 12-02, 12-03, 12-04]
  provides:
    - vite-docker-dev
    - vite-docker-prod
    - vite-hmr-config
  affects: [12-06]
tech-stack:
  added: []
  patterns:
    - vite-docker-integration
    - vite-hmr-in-containers
key-files:
  created: []
  modified:
    - app/Dockerfile.dev
    - app/Dockerfile
    - docker-compose.override.yml
decisions:
  - id: DEC-12-05-001
    choice: "Node 24 LTS for Docker images"
    rationale: "Vite 7 requires Node 18+, Node 24 LTS provides best compatibility"
  - id: DEC-12-05-002
    choice: "Port 5173 for Vite dev server"
    rationale: "Vite default port, differentiates from webpack 8080"
  - id: DEC-12-05-003
    choice: "Reduced memory limits for Vite"
    rationale: "Vite uses less memory than webpack (2GB vs 4GB)"
metrics:
  duration: "5 minutes"
  completed: "2026-01-23"
---

# Phase 12 Plan 05: Docker Configuration Summary

**One-liner:** Docker configuration updated for Vite with port 5173, Node 24, and optimized memory settings.

## What Was Done

### Task 1: Dockerfile.dev for Vite
Updated development Dockerfile to use Vite dev server:
- Changed `NODE_VERSION` from 20 to 24 (Vite 7 requirement)
- Changed exposed port from 8080 to 5173 (Vite default)
- Changed command from `npm run serve` to `npm run dev`
- Reduced `start-period` from 120s to 60s (Vite is faster)
- Removed `NODE_OPTIONS` heap size (Vite is more memory efficient)

### Task 2: Dockerfile for Vite Production
Updated production Dockerfile to use Vite build:
- Changed `NODE_VERSION` from 20 to 24
- Changed build command from `npm run build` to `npm run build:vite`
- Updated comments to reference Vite
- nginx stage unchanged (just serves dist/ folder)

### Task 3: docker-compose.override.yml for Vite
Updated development compose overrides:
- Changed port mapping from 8080:8080 to 5173:5173
- Updated healthcheck URL to port 5173
- Reduced `start_period` from 120s to 60s
- Reduced memory limit from 4096M to 2048M
- Changed watch path from `vue.config.js` to `vite.config.js`
- Removed `NODE_OPTIONS` environment variable

## Commit Log

| Commit | Type | Description |
|--------|------|-------------|
| a9b7485 | feat | update Dockerfile.dev for Vite dev server |
| 895a668 | feat | update Dockerfile for Vite production build |
| a3ae917 | feat | update docker-compose.override.yml for Vite |

## Key Configuration Changes

### Port Mapping
```
webpack:   8080 -> 8080
vite:      5173 -> 5173
```

### Node Version
```
webpack:   Node 20 LTS
vite:      Node 24 LTS
```

### Memory Requirements
```
webpack:   4096M (4GB)
vite:      2048M (2GB)
```

### Startup Time
```
webpack:   start-period 120s
vite:      start-period 60s
```

## Files Modified

| File | Changes |
|------|---------|
| `app/Dockerfile.dev` | Vite dev server, port 5173, Node 24 |
| `app/Dockerfile` | Vite build command, Node 24 |
| `docker-compose.override.yml` | Port 5173, reduced memory, vite.config.js watch |

## Verification Results

All verification checks passed:
- Port 5173 exposed in Dockerfile.dev
- `npm run dev` command in Dockerfile.dev
- `npm run build:vite` command in Dockerfile
- Port 5173:5173 mapping in docker-compose.override.yml
- `vite.config.js` watch path in docker-compose.override.yml

## Deviations from Plan

None - plan executed exactly as written.

## Dependencies for Next Plan

Plan 12-06 (Verification & Cleanup) can now:
- Test Docker development workflow with Vite HMR
- Test Docker production build with Vite
- Clean up Vue CLI remnants if everything works

## Notes

- HMR in Docker containers relies on `vite.config.js` having `usePolling: true` (configured in Plan 12-01)
- The `--mode docker` flag uses `.env.docker` for correct API URL through Traefik
- Anonymous volume for `node_modules` prevents cross-platform binary issues
