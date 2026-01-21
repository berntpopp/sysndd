# Requirements: SysNDD v2 Docker Infrastructure

**Defined:** 2026-01-21
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v2 Requirements

Requirements for Docker infrastructure modernization. Each maps to roadmap phases.

### Security

- [ ] **SEC-01**: Replace dockercloud/haproxy:1.6.7 with Traefik v3.6
- [ ] **SEC-02**: Add .dockerignore file to api/ directory
- [ ] **SEC-03**: Add .dockerignore file to app/ directory
- [ ] **SEC-04**: Fix HTTP CRAN repos to HTTPS in API Dockerfile
- [ ] **SEC-05**: Add non-root user to API container
- [ ] **SEC-06**: Add non-root user to App container
- [ ] **SEC-07**: Make Docker socket read-only in Traefik service

### Build Efficiency

- [ ] **BUILD-01**: Consolidate API Dockerfile RUN layers (34 to 5-6 layers)
- [ ] **BUILD-02**: Configure Posit Package Manager for pre-compiled R binaries
- [ ] **BUILD-03**: Use pak instead of devtools::install_version()
- [ ] **BUILD-04**: Enable parallel package installation (--ncpus -1 / Ncpus)
- [ ] **BUILD-05**: Switch base image from rocker/tidyverse to rocker/r-ver
- [ ] **BUILD-06**: Add ccache for C/C++ compilation caching
- [ ] **BUILD-07**: Configure BuildKit cache mounts for incremental builds
- [ ] **BUILD-08**: Strip debug symbols from R package .so files
- [ ] **BUILD-09**: Create multi-stage API Dockerfile (base to packages to production)

### Frontend Modernization

- [ ] **FRONT-01**: Upgrade Node.js from 16.16.0 to 24 LTS
- [ ] **FRONT-02**: Convert to alpine-based multi-stage build
- [ ] **FRONT-03**: Add HEALTHCHECK instruction to App Dockerfile
- [ ] **FRONT-04**: Create app/Dockerfile.dev for hot-reload development

### Docker Compose

- [ ] **COMP-01**: Remove obsolete `version: '3.8'` field
- [ ] **COMP-02**: Replace deprecated `links:` directive with networks
- [ ] **COMP-03**: Add named networks for service isolation (proxy, backend)
- [ ] **COMP-04**: Convert to named volumes (remove ../data/ external paths)
- [ ] **COMP-05**: Add health checks to all services
- [ ] **COMP-06**: Update MySQL from 8.0.29 to 8.0.40
- [ ] **COMP-07**: Use caching_sha2_password authentication plugin
- [ ] **COMP-08**: Add resource limits (memory, CPU) to all services
- [ ] **COMP-09**: Configure Traefik auto-discovery with Docker labels
- [ ] **COMP-10**: Add HEALTHCHECK to API container

### Developer Experience

- [ ] **DEV-01**: Create docker-compose.override.yml for development
- [ ] **DEV-02**: Configure volume mounts for live code changes
- [ ] **DEV-03**: Expose MySQL port for local development tools
- [ ] **DEV-04**: Create docker-compose.dev.yml with Compose Watch configuration
- [ ] **DEV-05**: Configure Compose Watch sync actions for app/src
- [ ] **DEV-06**: Configure Compose Watch sync actions for api/endpoints and api/functions
- [ ] **DEV-07**: Create .env.example template file

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
| SEC-01 | Phase 6 | Pending |
| SEC-02 | Phase 6 | Pending |
| SEC-03 | Phase 6 | Pending |
| SEC-04 | Phase 7 | Pending |
| SEC-05 | Phase 7 | Pending |
| SEC-06 | Phase 8 | Pending |
| SEC-07 | Phase 6 | Pending |
| BUILD-01 | Phase 7 | Pending |
| BUILD-02 | Phase 7 | Pending |
| BUILD-03 | Phase 7 | Pending |
| BUILD-04 | Phase 7 | Pending |
| BUILD-05 | Phase 7 | Pending |
| BUILD-06 | Phase 7 | Pending |
| BUILD-07 | Phase 7 | Pending |
| BUILD-08 | Phase 7 | Pending |
| BUILD-09 | Phase 7 | Pending |
| FRONT-01 | Phase 8 | Pending |
| FRONT-02 | Phase 8 | Pending |
| FRONT-03 | Phase 8 | Pending |
| FRONT-04 | Phase 9 | Pending |
| COMP-01 | Phase 6 | Pending |
| COMP-02 | Phase 6 | Pending |
| COMP-03 | Phase 6 | Pending |
| COMP-04 | Phase 6 | Pending |
| COMP-05 | Phase 6 | Pending |
| COMP-06 | Phase 6 | Pending |
| COMP-07 | Phase 6 | Pending |
| COMP-08 | Phase 6 | Pending |
| COMP-09 | Phase 6 | Pending |
| COMP-10 | Phase 7 | Pending |
| DEV-01 | Phase 9 | Pending |
| DEV-02 | Phase 9 | Pending |
| DEV-03 | Phase 9 | Pending |
| DEV-04 | Phase 9 | Pending |
| DEV-05 | Phase 9 | Pending |
| DEV-06 | Phase 9 | Pending |
| DEV-07 | Phase 9 | Pending |

**Coverage:**
- v2 requirements: 37 total
- Mapped to phases: 37
- Unmapped: 0

**Phase Distribution:**
| Phase | Requirements | Count |
|-------|--------------|-------|
| Phase 6 | SEC-01, SEC-02, SEC-03, SEC-07, COMP-01 through COMP-09 | 13 |
| Phase 7 | SEC-04, SEC-05, BUILD-01 through BUILD-09, COMP-10 | 12 |
| Phase 8 | SEC-06, FRONT-01, FRONT-02, FRONT-03 | 4 |
| Phase 9 | FRONT-04, DEV-01 through DEV-07 | 8 |

---
*Requirements defined: 2026-01-21*
*Last updated: 2026-01-21 — Roadmap traceability complete*
