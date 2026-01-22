# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-21)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v2 Docker Infrastructure Modernization

## Current Position

**Milestone:** v2 Docker Infrastructure Modernization
**Phase:** 9 - Developer Experience
**Plan:** 03 of 8
**Status:** In Progress
**Last activity:** 2026-01-22 — Completed 09-03-PLAN.md

```
v2 Progress: [██████████] 100% (26/26 plans)
Phase 9:     [██████░░░░░░] 3/8 plans
```

## v2 Scope

**Goal:** Transform Docker infrastructure from 4/10 to 9/10

**Ratings to improve:**
| Category | Current | Target |
|----------|---------|--------|
| Security | 4/10 | 9/10 |
| Build Efficiency | 3/10 | 9/10 |
| Developer Experience | 2/10 | 9/10 |
| Maintainability | 5/10 | 9/10 |
| Production Readiness | 6/10 | 9/10 |

**Key deliverables:**
- Replace dockercloud/haproxy with Traefik v3.6
- API build time: 45 min to 3-5 min
- Node.js 16 to 24 LTS
- Health checks, resource limits, non-root users
- Docker Compose Watch for hot-reload

## Phase Structure

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 6 | Security and Compose Foundation | 13 | Complete |
| 7 | API Dockerfile Optimization | 12 | Complete |
| 8 | Frontend Dockerfile Modernization | 4 | Complete |
| 9 | Developer Experience | 8 | In Progress (2/8) |

## GitHub Issues

| Issue | Description | Status |
|-------|-------------|--------|
| #109 | Refactor sysndd_plumber.R into smaller endpoint files | Ready for PR |
| #123 | Implement comprehensive testing | Foundation complete, integration tests deferred |

## Tech Debt (from v1 audit)

- lint-app crashes (esm module compatibility)
- 1240 lintr issues in R codebase
- renv.lock incomplete (Dockerfile workarounds)
- No HTTP endpoint integration tests
- httptest2 fixtures not yet recorded

## Key Decisions

| Decision | Rationale | Phase |
|----------|-----------|-------|
| Traefik over HAProxy 2.9 | Native Docker integration, auto-discovery, Let's Encrypt | 6 |
| pak over devtools | Parallel, binary-preferring, modern | 7 |
| Posit Package Manager | Pre-compiled Linux binaries, 10x faster | 7 |
| Health endpoint at /health | Standard convention for health checks; shorter path for HEALTHCHECK | 07-01 |
| No database query in health | Fast response time; HEALTHCHECK should validate API process, not DB connectivity | 07-01 |
| Multi-stage Dockerfile | Separates build dependencies from production image; enables ccache and debug stripping | 07-02 |
| ccache with BuildKit cache mounts | Persistent compilation cache across builds for 30-40% faster rebuilds | 07-02 |
| Non-root user uid 1001 | Security best practice; specific uid enables consistent file ownership | 07-02 |
| HEALTHCHECK with 30s start period | Prevents premature unhealthy status during R package loading | 07-02 |
| 12-minute cold build target | Bioconductor packages lack binaries for focal/R 4.1.2; source compilation adds ~2.5 min overhead | 07-03 |
| Node 20 LTS for frontend | Vue 2.7 compatible (Node 22+ breaks webpack 5 with OpenSSL 3.0 MD4 deprecation) | 08-01 |
| nginxinc/nginx-unprivileged | Pre-configured non-root nginx (UID 101), Alpine-based, follows API security pattern | 08-01 |
| Port 8080 for frontend | Non-privileged port for non-root user; ports <1024 require root | 08-01 |
| wget for health checks | Included in Alpine busybox; no curl installation needed | 08-01 |
| Compose Watch over bind mounts | Modern, cross-platform, no polling config | 9 |
| 60s HEALTHCHECK start-period for dev | Longer start for webpack-dev-server vs nginx | 09-01 |
| Source code via volume mount not COPY | Enables hot-reload; Dockerfile.dev only installs deps | 09-01 |
| Placeholder values 'your_xxx_here' pattern | Clear indication of required user input in .env.example | 09-01 |
| MySQL port 127.0.0.1:7654 | Localhost-only binding for security; accessible to DBeaver/Workbench | 09-02 |
| Anonymous volume for node_modules | Cross-platform native binary isolation; prevents host/container conflicts | 09-02 |
| App watch in override, API watch in main | API uses same Dockerfile; app uses dev-only Dockerfile.dev | 09-02 |
| 127.0.0.1 for Alpine healthchecks | IPv6 resolution issues with localhost in Alpine containers | 09-03 |
| allowedHosts: 'all' for dev server | Required for webpack-dev-server to accept Traefik proxy requests | 09-03 |
| Traefik dashboard at localhost:8090 | Development debugging for routing issues | 09-03 |
| 120s healthcheck start-period for dev | Extended time needed for webpack compilation | 09-03 |

## Resume Instructions

**Phase 9 in progress.** Continue with Plan 04 (documentation).

Phase 9 achievements so far:
- Plan 01: app/Dockerfile.dev created with Node 20 Alpine and webpack-dev-server
- Plan 02: docker-compose.override.yml with Dockerfile.dev, MySQL localhost:7654, Compose Watch
- Plan 03: End-to-end workflow verified, Traefik routing fixed, hot-reload confirmed

Next: Plan 04 (Development Environment documentation)

## Research Location

Detailed implementation guidance: `.plan/DOCKER-REVIEW-REPORT.md`

## Archive Location

v1 artifacts: `.planning/milestones/`

## Session Continuity

**Last session:** 2026-01-22 18:45:00 UTC
**Stopped at:** Completed 09-03-SUMMARY.md
**Resume file:** None

---
*Last updated: 2026-01-22 — Added 09-03-SUMMARY.md*
