# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-21)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v2 Docker Infrastructure Modernization

## Current Position

**Milestone:** v2 Docker Infrastructure Modernization
**Phase:** 6 - Security and Compose Foundation
**Plan:** Not started
**Status:** Roadmap complete, ready for planning
**Last activity:** 2026-01-21 — Roadmap created

```
v2 Progress: [░░░░░░░░░░] 0%
Phase 6:     [░░░░░░░░░░] 0/13 requirements
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
| 6 | Security and Compose Foundation | 13 | Not Started |
| 7 | API Dockerfile Optimization | 12 | Not Started |
| 8 | Frontend Dockerfile Modernization | 4 | Not Started |
| 9 | Developer Experience | 8 | Not Started |

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
| Node 24 LTS over 22 | Current LTS, security patches through 2027 | 8 |
| Compose Watch over bind mounts | Modern, cross-platform, no polling config | 9 |

## Resume Instructions

**Roadmap complete.** Next step: plan Phase 6.

```
/gsd:plan-phase 6
```

Phase 6 delivers: Traefik reverse proxy, named networks, named volumes, health checks, MySQL update, resource limits, .dockerignore files.

## Research Location

Detailed implementation guidance: `.plan/DOCKER-REVIEW-REPORT.md`

## Archive Location

v1 artifacts: `.planning/milestones/`

---
*Last updated: 2026-01-21 — Roadmap created*
