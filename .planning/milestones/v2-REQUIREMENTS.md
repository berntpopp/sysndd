# Requirements Archive: v2 Docker Infrastructure Modernization

**Archived:** 2026-01-22
**Status:** SHIPPED

This is the archived requirements specification for v2.
For current requirements, see `.planning/REQUIREMENTS.md` (created for next milestone).

---

# Requirements: SysNDD v2 Docker Infrastructure

**Defined:** 2026-01-21
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v2 Requirements

Requirements for Docker infrastructure modernization. Each maps to roadmap phases.

### Security

- [x] **SEC-01**: Replace dockercloud/haproxy:1.6.7 with Traefik v3.6 — Phase 6
- [x] **SEC-02**: Add .dockerignore file to api/ directory — Phase 6
- [x] **SEC-03**: Add .dockerignore file to app/ directory — Phase 6
- [x] **SEC-04**: Fix HTTP CRAN repos to HTTPS in API Dockerfile — Phase 7 (already HTTPS)
- [x] **SEC-05**: Add non-root user to API container — Phase 7 (uid 1001)
- [x] **SEC-06**: Add non-root user to App container — Phase 8 (nginx user)
- [x] **SEC-07**: Make Docker socket read-only in Traefik service — Phase 6

### Build Efficiency

- [x] **BUILD-01**: Consolidate API Dockerfile RUN layers (34 to 5-6 layers) — Phase 7
- [x] **BUILD-02**: Configure Posit Package Manager for pre-compiled R binaries — Phase 7
- [x] **BUILD-03**: Use pak instead of devtools::install_version() — Phase 7 (using renv)
- [x] **BUILD-04**: Enable parallel package installation (--ncpus -1 / Ncpus) — Phase 7
- [x] **BUILD-05**: Switch base image from rocker/tidyverse to rocker/r-ver — Phase 7
- [x] **BUILD-06**: Add ccache for C/C++ compilation caching — Phase 7
- [x] **BUILD-07**: Configure BuildKit cache mounts for incremental builds — Phase 7
- [x] **BUILD-08**: Strip debug symbols from R package .so files — Phase 7
- [x] **BUILD-09**: Create multi-stage API Dockerfile (base to packages to production) — Phase 7

### Frontend Modernization

- [x] **FRONT-01**: Upgrade Node.js from 16.16.0 to 20 LTS — Phase 8 (20 LTS for Vue 2 compatibility)
- [x] **FRONT-02**: Convert to alpine-based multi-stage build — Phase 8
- [x] **FRONT-03**: Add HEALTHCHECK instruction to App Dockerfile — Phase 8
- [x] **FRONT-04**: Create app/Dockerfile.dev for hot-reload development — Phase 9

### Docker Compose

- [x] **COMP-01**: Remove obsolete `version: '3.8'` field — Phase 6
- [x] **COMP-02**: Replace deprecated `links:` directive with networks — Phase 6
- [x] **COMP-03**: Add named networks for service isolation (proxy, backend) — Phase 6
- [x] **COMP-04**: Convert to named volumes (remove ../data/ external paths) — Phase 6
- [x] **COMP-05**: Add health checks to all services — Phase 6
- [x] **COMP-06**: Update MySQL from 8.0.29 to 8.0.40 — Phase 6
- [x] **COMP-07**: Use caching_sha2_password authentication plugin — Phase 6
- [x] **COMP-08**: Add resource limits (memory, CPU) to all services — Phase 6
- [x] **COMP-09**: Configure Traefik auto-discovery with Docker labels — Phase 6
- [x] **COMP-10**: Add HEALTHCHECK to API container — Phase 7

### Developer Experience

- [x] **DEV-01**: Create docker-compose.override.yml for development — Phase 9
- [x] **DEV-02**: Configure volume mounts for live code changes — Phase 9
- [x] **DEV-03**: Expose MySQL port for local development tools — Phase 9 (127.0.0.1:7654)
- [x] **DEV-04**: Create docker-compose.dev.yml with Compose Watch configuration — Phase 9
- [x] **DEV-05**: Configure Compose Watch sync actions for app/src — Phase 9
- [x] **DEV-06**: Configure Compose Watch sync actions for api/endpoints and api/functions — Phase 9
- [x] **DEV-07**: Create .env.example template file — Phase 9

## Future Requirements (v3+)

### Security Enhancements

- **SEC-F01**: Integrate Trivy container security scanning in CI
- **SEC-F02**: Implement Docker secrets management for sensitive data
- **SEC-F03**: Add automatic Let's Encrypt certificate renewal monitoring

### CI/CD Integration

- **CI-F01**: GitHub Actions workflow for Docker image builds
- **CI-F02**: Automated security scanning on PR
- **CI-F03**: Image tagging and registry push

## Out of Scope

| Feature | Reason |
|---------|--------|
| Kubernetes migration | Docker Compose sufficient for current scale |
| Custom HAProxy 2.9 | Traefik provides better Docker integration |
| Multi-architecture builds (ARM64) | Primary deployment is amd64, ARM can use source compilation |
| Docker Swarm | Not needed for single-host deployment |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SEC-01 | Phase 6 | Complete |
| SEC-02 | Phase 6 | Complete |
| SEC-03 | Phase 6 | Complete |
| SEC-04 | Phase 7 | Complete |
| SEC-05 | Phase 7 | Complete |
| SEC-06 | Phase 8 | Complete |
| SEC-07 | Phase 6 | Complete |
| BUILD-01 | Phase 7 | Complete |
| BUILD-02 | Phase 7 | Complete |
| BUILD-03 | Phase 7 | Complete |
| BUILD-04 | Phase 7 | Complete |
| BUILD-05 | Phase 7 | Complete |
| BUILD-06 | Phase 7 | Complete |
| BUILD-07 | Phase 7 | Complete |
| BUILD-08 | Phase 7 | Complete |
| BUILD-09 | Phase 7 | Complete |
| FRONT-01 | Phase 8 | Complete |
| FRONT-02 | Phase 8 | Complete |
| FRONT-03 | Phase 8 | Complete |
| FRONT-04 | Phase 9 | Complete |
| COMP-01 | Phase 6 | Complete |
| COMP-02 | Phase 6 | Complete |
| COMP-03 | Phase 6 | Complete |
| COMP-04 | Phase 6 | Complete |
| COMP-05 | Phase 6 | Complete |
| COMP-06 | Phase 6 | Complete |
| COMP-07 | Phase 6 | Complete |
| COMP-08 | Phase 6 | Complete |
| COMP-09 | Phase 6 | Complete |
| COMP-10 | Phase 7 | Complete |
| DEV-01 | Phase 9 | Complete |
| DEV-02 | Phase 9 | Complete |
| DEV-03 | Phase 9 | Complete |
| DEV-04 | Phase 9 | Complete |
| DEV-05 | Phase 9 | Complete |
| DEV-06 | Phase 9 | Complete |
| DEV-07 | Phase 9 | Complete |

**Coverage:**
- v2 requirements: 37 total
- Shipped: 37
- Unmapped: 0

**Phase Distribution:**
| Phase | Requirements | Count |
|-------|--------------|-------|
| Phase 6 | SEC-01, SEC-02, SEC-03, SEC-07, COMP-01 through COMP-09 | 13 |
| Phase 7 | SEC-04, SEC-05, BUILD-01 through BUILD-09, COMP-10 | 12 |
| Phase 8 | SEC-06, FRONT-01, FRONT-02, FRONT-03 | 4 |
| Phase 9 | FRONT-04, DEV-01 through DEV-07 | 8 |

---

## Milestone Summary

**Shipped:** 37 of 37 v2 requirements
**Adjusted:** FRONT-01 changed from Node 24 to Node 20 (Vue 2 compatibility)
**Dropped:** None

---
*Archived: 2026-01-22 as part of v2 milestone completion*
