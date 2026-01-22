# SysNDD Developer Experience Improvements

## What This Is

Developer experience infrastructure for SysNDD, a neurodevelopmental disorders database. v2 delivered modern Docker infrastructure with Traefik reverse proxy, optimized multi-stage builds, security hardening, and hot-reload development workflow.

## Core Value

A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## Current State (v2 shipped 2026-01-22)

**Docker Infrastructure:** 9/10 (up from 4/10)
- Traefik v3.6 reverse proxy with Docker auto-discovery
- Multi-stage Dockerfiles with ccache and BuildKit cache mounts
- Non-root users: API (uid 1001), App (nginx)
- API build time: ~10 min cold, ~2 min warm (down from 45 min)
- Health checks and resource limits on all containers
- Docker Compose Watch hot-reload development workflow

**Test Suite:** 610 tests passing in ~74 seconds, 20.3% coverage

**Automation:** 13 Makefile targets across 5 categories

## Requirements

### Validated

<!-- Shipped in v1 -->

- ✓ Modular R/Plumber API with 21 endpoint files — v1
- ✓ Vue 2 SPA frontend with Bootstrap-Vue — existing
- ✓ JWT-based authentication system — existing
- ✓ Database connection pooling with pool package — existing
- ✓ R code linting with lintr + styler — existing
- ✓ Frontend linting with ESLint — existing
- ✓ Docker Compose multi-service setup — existing
- ✓ npm package-lock.json for frontend dependencies — existing
- ✓ All 21 API endpoints verified working — v1
- ✓ Legacy api/_old/ directory removed — v1
- ✓ API documentation updated — v1
- ✓ testthat + mirai testing framework installed — v1
- ✓ Test directory structure with helpers — v1
- ✓ Unit tests for core utility functions (38 test blocks) — v1
- ✓ Authentication JWT tests (9 test blocks) — v1
- ✓ Entity helper tests (9 test blocks) — v1
- ✓ Test database configuration isolated — v1
- ✓ External API mocking with httptest2 — v1
- ✓ Makefile with self-documenting help — v1
- ✓ Dev setup targets (install-api, install-app, dev) — v1
- ✓ Testing targets (test-api, lint-api, lint-app, coverage) — v1
- ✓ Docker targets (docker-build, docker-up, docker-down) — v1
- ✓ Quality targets (format-api, pre-commit) — v1
- ✓ docker-compose.dev.yml for hybrid development — v1
- ✓ Docker Compose Watch for hot-reload — v1
- ✓ .dockerignore files for faster builds — v1
- ✓ renv for R package version locking — v1
- ✓ Coverage reporting via covr — v1

<!-- Shipped in v2 -->

- ✓ Traefik v3.6 reverse proxy replacing dockercloud/haproxy — v2
- ✓ Multi-stage API Dockerfile with ccache and BuildKit cache — v2
- ✓ Non-root users in all containers — v2
- ✓ Health checks on all services — v2
- ✓ Resource limits (memory, CPU) on all services — v2
- ✓ Node.js 20 LTS for frontend (Vue 2 compatible) — v2
- ✓ Alpine-based frontend with nginx-unprivileged — v2
- ✓ Named networks for service isolation (proxy, backend) — v2
- ✓ MySQL 8.0.40 with caching_sha2_password — v2
- ✓ docker-compose.override.yml for development — v2
- ✓ app/Dockerfile.dev for hot-reload development — v2
- ✓ .env.example template for developer onboarding — v2

### Active

<!-- Next milestone scope (v3 CI/CD) -->

(No requirements defined yet. Run `/gsd:new-milestone` to start next milestone.)

### Out of Scope

- Vue 3 migration — scheduled for later, keeping Vue 2 for now
- R/Plumber replacement — keeping current stack
- Frontend testing — R API testing is priority; frontend tests later

## Context

**After v2:**
- Docker infrastructure modernized — Traefik, multi-stage builds, security hardening
- Developer workflow improved — hot-reload, 2-minute rebuild cycles
- All v2 requirements shipped — 37/37 complete

**GitHub Issues:**
- #109: Refactor sysndd_plumber.R into smaller endpoint files — Ready for PR
- #123: Implement comprehensive testing — Foundation complete, integration tests deferred

**Tech Debt (carried from v1):**
- lint-app crashes (esm module compatibility)
- 1240 lintr issues in R codebase
- renv.lock incomplete (Dockerfile workarounds)
- No HTTP endpoint integration tests

**Codebase map:** See `.planning/codebase/` for detailed analysis

## Constraints

- **Stack**: Must stay with R/Plumber for API, Vue 2 for frontend (Vue 3 later)
- **Database**: MySQL 8.0.40 (upgraded in v2)
- **Docker**: rocker/r-ver:4.1.2 base image (matched to renv.lock R version)
- **Compatibility**: Must work on Windows (WSL2), macOS, and Linux
- **Node.js**: Node 20 LTS for Vue 2 compatibility (not 22/24 due to OpenSSL 3.0 MD4 deprecation)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| testthat + mirai for R testing | mirai production-ready; callthat experimental | ✓ Good |
| renv for R package management | Industry standard, replaces deprecated packrat | ✓ Good |
| Makefile over Taskfile | Universal availability, no extra dependencies | ✓ Good |
| Docker Compose Watch for hot-reload | Modern approach, cross-platform consistent | ✓ Good |
| Hybrid dev setup (DB in Docker, API local) | Fast iteration, debugger access | ✓ Good |
| 20% coverage practical maximum | Most functions are DB/network-coupled | ✓ Good |
| covr::file_coverage over package_coverage | API is not an R package | ✓ Good |
| Traefik over HAProxy 2.9 | Native Docker integration, auto-discovery, Let's Encrypt | ✓ Good |
| pak over devtools | Parallel, binary-preferring, modern (via renv) | ✓ Good |
| Posit Package Manager | Pre-compiled Linux binaries, 10x faster | ✓ Good |
| Node 20 LTS over 24 | Vue 2.7 compatibility (OpenSSL 3.0 MD4 issue) | ✓ Good |
| nginxinc/nginx-unprivileged | Pre-configured non-root nginx, Alpine-based | ✓ Good |
| 12-minute cold build target | Bioconductor packages require source compilation | ✓ Good |

---
*Last updated: 2026-01-22 after v2 milestone shipped*
