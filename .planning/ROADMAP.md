# Roadmap: SysNDD v2 Docker Infrastructure Modernization

**Milestone:** v2
**Goal:** Transform Docker infrastructure from 4/10 to 9/10 across security, build efficiency, developer experience, maintainability, and production readiness.
**Phases:** 4 (Phase 6-9, continuing from v1)
**Depth:** Standard

## Overview

This roadmap transforms the Docker infrastructure from a functional but outdated setup to a modern, secure, and efficient development environment. The four phases follow a logical dependency chain: foundation (Compose + Traefik) enables optimized builds (API + Frontend), which enables the developer experience layer.

## Phases

### Phase 6: Security and Compose Foundation

**Goal:** Establish secure, modern Docker Compose infrastructure with Traefik reverse proxy and proper network isolation.

**Dependencies:** None (foundation phase)

**Plans:** 1 plan

Plans:
- [ ] 06-01-PLAN.md — Docker Compose modernization with Traefik, networks, health checks, resource limits

**Requirements:**
- SEC-01: Replace dockercloud/haproxy:1.6.7 with Traefik v3.6
- SEC-02: Add .dockerignore file to api/ directory
- SEC-03: Add .dockerignore file to app/ directory
- SEC-07: Make Docker socket read-only in Traefik service
- COMP-01: Remove obsolete version field
- COMP-02: Replace deprecated links directive with networks
- COMP-03: Add named networks for service isolation (proxy, backend)
- COMP-04: Convert to named volumes (remove ../data/ external paths)
- COMP-05: Add health checks to all services
- COMP-06: Update MySQL from 8.0.29 to 8.0.40
- COMP-07: Use caching_sha2_password authentication plugin
- COMP-08: Add resource limits (memory, CPU) to all services
- COMP-09: Configure Traefik auto-discovery with Docker labels

**Success Criteria:**
1. `docker compose up` starts all services with Traefik handling routing
2. Services communicate via named networks (proxy, backend) with MySQL isolated from public network
3. Health checks pass for all services within 60 seconds of startup
4. `docker compose config` shows no deprecated warnings (no version field, no links)
5. Docker socket mounted read-only (:ro) in Traefik service

---

### Phase 7: API Dockerfile Optimization

**Goal:** Reduce API Docker build time from 45 minutes to under 12 minutes while improving security and image size.

**Dependencies:** Phase 6 (needs health check infrastructure, networks)

**Plans:** 3 plans

Plans:
- [x] 07-01-PLAN.md — Add /health endpoint for Docker HEALTHCHECK
- [x] 07-02-PLAN.md — Multi-stage Dockerfile with ccache, debug stripping, non-root user
- [x] 07-03-PLAN.md — Gap closure: Update success criteria for Bioconductor constraints

**Requirements:**
- SEC-04: Fix HTTP CRAN repos to HTTPS in API Dockerfile (DONE - already uses HTTPS)
- SEC-05: Add non-root user to API container
- BUILD-01: Consolidate API Dockerfile RUN layers (DONE - already consolidated)
- BUILD-02: Configure Posit Package Manager for pre-compiled R binaries (DONE - already configured)
- BUILD-03: Use pak instead of devtools::install_version() (DONE - using renv + install.packages)
- BUILD-04: Enable parallel package installation (DONE - Ncpus configured)
- BUILD-05: Switch base image from rocker/tidyverse to rocker/r-ver (DONE - already uses r-ver)
- BUILD-06: Add ccache for C/C++ compilation caching
- BUILD-07: Configure BuildKit cache mounts for incremental builds (DONE - already configured)
- BUILD-08: Strip debug symbols from R package .so files
- BUILD-09: Create multi-stage API Dockerfile (base to packages to production)
- COMP-10: Add HEALTHCHECK to API container

**Success Criteria:**
1. Cold API build completes in under 12 minutes (Bioconductor packages require source compilation)
2. Warm API build with BuildKit cache completes in under 2 minutes
3. API container runs as non-root user (uid 1001)
4. `docker history` shows 6 or fewer RUN layers in final image
5. API health check endpoint responds at /health within 30 seconds of container start

> **Note:** Bioconductor packages (STRINGdb, biomaRt, Biostrings, IRanges, S4Vectors) do not have pre-compiled binaries for Ubuntu focal/R 4.1.2 and require source compilation, adding ~2.5-3 minutes to cold builds. This is an inherent platform constraint. The original 5-8 minute target assumed all packages would have P3M binaries available.

---

### Phase 8: Frontend Dockerfile Modernization

**Goal:** Modernize frontend build with Node.js 20 LTS (Vue 2 compatible), Alpine base, and security hardening.

**Dependencies:** Phase 6 (needs Traefik labels, networks)

**Plans:** 1 plan

Plans:
- [x] 08-01-PLAN.md — Multi-stage Dockerfile with Node 20 Alpine, nginx-unprivileged, HEALTHCHECK

**Requirements:**
- SEC-06: Add non-root user to App container
- FRONT-01: Upgrade Node.js from 16.16.0 to 20 LTS (NOT 24 - Vue 2 compatibility)
- FRONT-02: Convert to alpine-based multi-stage build
- FRONT-03: Add HEALTHCHECK instruction to App Dockerfile

**Success Criteria:**
1. Frontend build uses Node.js 20 LTS (verified with `node --version` in builder container)
2. Final production image based on nginxinc/nginx-unprivileged:alpine (under 50MB for nginx layer)
3. App container runs as non-root user (UID 101 using nginx user)
4. Health check at http://localhost:8080/ responds within 5 seconds of container start

---

### Phase 9: Developer Experience

**Goal:** Enable instant hot-reload development workflow with Docker Compose Watch and development-specific configurations.

**Dependencies:** Phase 7 (API Dockerfile), Phase 8 (Frontend Dockerfile)

**Plans:** 3 plans

Plans:
- [ ] 09-01-PLAN.md — Create app/Dockerfile.dev and .env.example template
- [ ] 09-02-PLAN.md — Create docker-compose.override.yml with volume mounts and MySQL port
- [ ] 09-03-PLAN.md — Verify end-to-end hot-reload workflow and update documentation

**Requirements:**
- FRONT-04: Create app/Dockerfile.dev for hot-reload development
- DEV-01: Create docker-compose.override.yml for development
- DEV-02: Configure volume mounts for live code changes
- DEV-03: Expose MySQL port for local development tools
- DEV-04: Create docker-compose.dev.yml with Compose Watch configuration
- DEV-05: Configure Compose Watch sync actions for app/src
- DEV-06: Configure Compose Watch sync actions for api/endpoints and api/functions
- DEV-07: Create .env.example template file

**Success Criteria:**
1. `docker compose watch` starts and syncs file changes without container rebuild
2. Editing app/src/*.vue triggers hot module reload in browser within 2 seconds
3. Editing api/endpoints/*.R reflects in API responses without manual restart
4. MySQL accessible at localhost:7654 for local database tools (DBeaver, etc.)
5. New developer can start full stack with `cp .env.example .env && docker compose up`

---

## Progress

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 6 | Security and Compose Foundation | 13 | Complete |
| 7 | API Dockerfile Optimization | 12 | Complete |
| 8 | Frontend Dockerfile Modernization | 4 | Complete |
| 9 | Developer Experience | 8 | Planned |

**Total:** 37 requirements across 4 phases

## Dependency Graph

```
Phase 6: Security + Compose Foundation
    |
    +---> Phase 7: API Dockerfile Optimization
    |         |
    |         +---> Phase 9: Developer Experience
    |         |
    +---> Phase 8: Frontend Dockerfile Modernization
              |
              +---> Phase 9: Developer Experience
```

Phase 9 depends on both Phase 7 and Phase 8 because:
- Dockerfile.dev requires the optimized base Dockerfiles
- Compose Watch sync targets reference the new Dockerfile structures
- Override file builds on production compose structure

## Research Context

Detailed implementation guidance available in `.plan/DOCKER-REVIEW-REPORT.md`:
- Optimized API Dockerfile template (pak + P3M + ccache)
- Optimized Frontend Dockerfile (Node 20 + alpine for Vue 2 compatibility)
- Production docker-compose.yml with Traefik
- Development docker-compose.override.yml
- Docker Compose Watch configuration

---
*Roadmap created: 2026-01-21*
*Last updated: 2026-01-22 — Phase 9 planned (3 plans in 2 waves)*
