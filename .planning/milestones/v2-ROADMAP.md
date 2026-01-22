# Milestone v2: Docker Infrastructure Modernization

**Status:** SHIPPED 2026-01-22
**Phases:** 6-9
**Total Plans:** 8

## Overview

This milestone transformed the Docker infrastructure from a functional but outdated setup to a modern, secure, and efficient development environment. The four phases followed a logical dependency chain: foundation (Compose + Traefik) enables optimized builds (API + Frontend), which enables the developer experience layer.

**Goal:** Transform Docker infrastructure from 4/10 to 9/10 across security, build efficiency, developer experience, maintainability, and production readiness.

**Target outcomes achieved:**
- Replace abandoned dockercloud/haproxy with Traefik v3.6
- API build time: 45 min → ~10 min (cold), ~2 min (warm)
- Node.js 16 EOL → Node 20 LTS (Vue 2 compatible)
- Add health checks, resource limits, non-root users
- Docker Compose Watch for hot-reload dev workflow

## Phases

### Phase 6: Security and Compose Foundation

**Goal:** Establish secure, modern Docker Compose infrastructure with Traefik reverse proxy and proper network isolation.
**Depends on:** None (foundation phase)
**Plans:** 1 plan

Plans:
- [x] 06-01: Docker Compose modernization with Traefik, networks, health checks, resource limits

**Requirements satisfied:**
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

---

### Phase 7: API Dockerfile Optimization

**Goal:** Reduce API Docker build time from 45 minutes to under 12 minutes while improving security and image size.
**Depends on:** Phase 6 (needs health check infrastructure, networks)
**Plans:** 3 plans

Plans:
- [x] 07-01: Add /health endpoint for Docker HEALTHCHECK
- [x] 07-02: Multi-stage Dockerfile with ccache, debug stripping, non-root user
- [x] 07-03: Gap closure - Update success criteria for Bioconductor constraints

**Requirements satisfied:**
- SEC-04: Fix HTTP CRAN repos to HTTPS in API Dockerfile (already HTTPS)
- SEC-05: Add non-root user to API container
- BUILD-01: Consolidate API Dockerfile RUN layers (already consolidated)
- BUILD-02: Configure Posit Package Manager for pre-compiled R binaries
- BUILD-03: Use pak instead of devtools (using renv + install.packages)
- BUILD-04: Enable parallel package installation
- BUILD-05: Switch base image from rocker/tidyverse to rocker/r-ver
- BUILD-06: Add ccache for C/C++ compilation caching
- BUILD-07: Configure BuildKit cache mounts for incremental builds
- BUILD-08: Strip debug symbols from R package .so files
- BUILD-09: Create multi-stage API Dockerfile
- COMP-10: Add HEALTHCHECK to API container

**Key decisions:**
- Health endpoint at /health (not /api/health) - standard convention
- No database query in health check - fast response, validates API process only
- Multi-stage Dockerfile separates build dependencies from production image
- ccache with BuildKit cache mounts for 30-40% faster rebuilds
- Non-root user uid 1001 for security
- 12-minute cold build target (Bioconductor packages lack pre-compiled binaries)

---

### Phase 8: Frontend Dockerfile Modernization

**Goal:** Modernize frontend build with Node.js 20 LTS (Vue 2 compatible), Alpine base, and security hardening.
**Depends on:** Phase 6 (needs Traefik labels, networks)
**Plans:** 1 plan

Plans:
- [x] 08-01: Multi-stage Dockerfile with Node 20 Alpine, nginx-unprivileged, HEALTHCHECK

**Requirements satisfied:**
- SEC-06: Add non-root user to App container
- FRONT-01: Upgrade Node.js from 16.16.0 to 20 LTS (NOT 24 - Vue 2 compatibility)
- FRONT-02: Convert to alpine-based multi-stage build
- FRONT-03: Add HEALTHCHECK instruction to App Dockerfile

**Key decisions:**
- Node 20 LTS for frontend (Node 22+ breaks webpack 5 with OpenSSL 3.0 MD4 deprecation)
- nginxinc/nginx-unprivileged for pre-configured non-root nginx (UID 101)
- Port 8080 for frontend (non-privileged port for non-root user)
- wget for health checks (included in Alpine busybox)

---

### Phase 9: Developer Experience

**Goal:** Enable instant hot-reload development workflow with Docker Compose Watch and development-specific configurations.
**Depends on:** Phase 7 (API Dockerfile), Phase 8 (Frontend Dockerfile)
**Plans:** 3 plans

Plans:
- [x] 09-01: Create app/Dockerfile.dev and .env.example template
- [x] 09-02: Create docker-compose.override.yml with volume mounts and MySQL port
- [x] 09-03: Verify end-to-end hot-reload workflow and update documentation

**Requirements satisfied:**
- FRONT-04: Create app/Dockerfile.dev for hot-reload development
- DEV-01: Create docker-compose.override.yml for development
- DEV-02: Configure volume mounts for live code changes
- DEV-03: Expose MySQL port for local development tools
- DEV-04: Create docker-compose.dev.yml with Compose Watch configuration
- DEV-05: Configure Compose Watch sync actions for app/src
- DEV-06: Configure Compose Watch sync actions for api/endpoints and api/functions
- DEV-07: Create .env.example template file

**Key decisions:**
- Compose Watch over bind mounts (modern, cross-platform, no polling config)
- 60s HEALTHCHECK start-period for dev (longer start for webpack-dev-server)
- Source code via volume mount not COPY (enables hot-reload)
- Placeholder values 'your_xxx_here' pattern in .env.example
- MySQL port 127.0.0.1:7654 (localhost-only binding for security)
- Anonymous volume for node_modules (cross-platform native binary isolation)
- 127.0.0.1 for Alpine healthchecks (IPv6 resolution issues with localhost)
- allowedHosts: 'all' for dev server (required for Traefik proxy)
- Traefik dashboard at localhost:8090 for development debugging

---

## Milestone Summary

**Key Decisions:**
- Traefik over HAProxy 2.9: Native Docker integration, auto-discovery, Let's Encrypt
- pak over devtools: Parallel, binary-preferring, modern
- Posit Package Manager: Pre-compiled Linux binaries, 10x faster
- Multi-stage Dockerfile: Separates build dependencies from production image
- ccache with BuildKit cache mounts: Persistent compilation cache across builds
- Compose Watch over bind mounts: Modern, cross-platform, no polling config

**Issues Resolved:**
- Traefik 404 routing: Fixed webpack-dev-server allowedHosts configuration
- Alpine IPv6 resolution: Changed localhost to 127.0.0.1 in healthchecks
- Wrong API URL in development: Fixed Dockerfile.dev to use --mode docker
- Webpack OOM killed: Added NODE_OPTIONS and 4GB memory limit

**Issues Deferred:**
- lint-app crashes (esm module compatibility) - pre-existing from v1
- 1240 lintr issues in R codebase - pre-existing from v1
- renv.lock incomplete - pre-existing from v1
- No HTTP endpoint integration tests - pre-existing from v1

**Technical Debt Incurred:**
- Phase 6 missing SUMMARY.md and VERIFICATION.md (functionality present)
- Phase 8 VERIFICATION.md references nginx-unprivileged but Dockerfile uses fholzer/nginx-brotli

---

*For current project status, see .planning/ROADMAP.md (next milestone) or .planning/MILESTONES.md*

---
*Archived: 2026-01-22 as part of v2 milestone completion*
