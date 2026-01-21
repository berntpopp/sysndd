# SysNDD Developer Experience Improvements

## What This Is

Developer experience infrastructure for SysNDD, a neurodevelopmental disorders database. v1 delivered modular API structure, comprehensive R testing with testthat, reproducible environments via renv, and unified Makefile automation.

## Core Value

A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## Current Milestone: v2 Docker Infrastructure Modernization

**Goal:** Transform Docker infrastructure from 4/10 → 9/10 across security, build efficiency, developer experience, maintainability, and production readiness.

**Target outcomes:**
- Replace abandoned dockercloud/haproxy with Traefik v3
- API build time: 45 min → 3-5 min (pak + Posit Package Manager binaries)
- Node.js 16 EOL → Node 24 LTS
- Add health checks, resource limits, non-root users
- Docker Compose Watch for hot-reload dev workflow

## v1 State (shipped 2026-01-21)

- **Test suite:** 610 tests passing in ~74 seconds
- **Coverage:** 20.3% unit test coverage (practical max for DB/network-coupled code)
- **Automation:** 13 Makefile targets across 5 categories
- **Docker build:** ~8 minutes (down from 45+)
- **Packages:** 277 R packages locked in renv.lock

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

### Active

<!-- v2 Docker Infrastructure Modernization scope -->

- [ ] Replace dockercloud/haproxy:1.6.7 with Traefik v3.6
- [ ] Add .dockerignore files (api/, app/)
- [ ] Fix HTTP CRAN repos → HTTPS in API Dockerfile
- [ ] Add non-root users to all containers
- [ ] Make Docker socket read-only
- [ ] Consolidate API Dockerfile RUN layers (34 → 5-6)
- [ ] Use Posit Package Manager binaries
- [ ] Use pak instead of devtools::install_version()
- [ ] Parallel package installation (--ncpus -1)
- [ ] Switch from rocker/tidyverse to rocker/r-ver
- [ ] Add ccache for C/C++ compilation caching
- [ ] Add BuildKit cache mounts for incremental builds
- [ ] Strip debug symbols for smaller images
- [ ] Upgrade Node.js 16.16.0 → 24 LTS
- [ ] Add HEALTHCHECK to all containers
- [ ] Remove obsolete docker-compose version field
- [ ] Replace links with networks
- [ ] Add named networks for isolation
- [ ] Add named volumes (remove ../data/ paths)
- [ ] Update MySQL 8.0.29 → 8.0.40
- [ ] Use caching_sha2_password auth plugin
- [ ] Add resource limits (memory, CPU)
- [ ] Add Traefik auto-discovery with labels
- [ ] Create docker-compose.override.yml for dev
- [ ] Add Docker Compose Watch configuration
- [ ] Create app/Dockerfile.dev for hot-reload

### Out of Scope

- Vue 3 migration — scheduled for later, keeping Vue 2 for now
- R/Plumber replacement — keeping current stack
- Frontend testing — R API testing is priority; frontend tests later
- CI/CD pipeline — focus on local development first
- Production deployment changes — this is developer experience focused

## Context

**After v1:**
- API refactoring complete — 21 endpoint files, 94 endpoints
- Test infrastructure established — 610 tests, 20.3% coverage
- Docker dev workflow working — hybrid setup, hot-reload
- renv package management — 277 packages locked
- Makefile automation — 13 targets, self-documenting

**GitHub Issues:**
- #109: Refactor sysndd_plumber.R into smaller endpoint files — Ready for PR
- #123: Implement comprehensive testing — Foundation complete, integration tests deferred

**Tech Debt (from v1 audit):**
- lint-app crashes (esm module compatibility)
- 1240 lintr issues in R codebase
- renv.lock incomplete (Dockerfile workarounds)
- No HTTP endpoint integration tests

**Codebase map:** See `.planning/codebase/` for detailed analysis

## Constraints

- **Stack**: Must stay with R/Plumber for API, Vue 2 for frontend (Vue 3 later)
- **Database**: MariaDB/MySQL 8.0.29 compatibility required
- **Docker**: rocker/r-ver:4.1.2 base image (matched to renv.lock R version)
- **Compatibility**: Must work on Windows (WSL2), macOS, and Linux

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

---
*Last updated: 2026-01-21 after v2 milestone started*
