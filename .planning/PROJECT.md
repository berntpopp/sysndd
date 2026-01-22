# SysNDD Developer Experience Improvements

## What This Is

Developer experience infrastructure for SysNDD, a neurodevelopmental disorders database. v2 delivered modern Docker infrastructure with Traefik reverse proxy, optimized multi-stage builds, security hardening, and hot-reload development workflow. v3 will modernize the frontend with Vue 3, TypeScript, and UI/UX improvements.

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

<!-- v3 Frontend Modernization scope -->

- [ ] Vue 3 migration from Vue 2.7
- [ ] TypeScript adoption across all components
- [ ] Bootstrap-Vue → Bootstrap-Vue-Next component library
- [ ] Vite build tooling (replacing Vue CLI + Webpack)
- [ ] vue-router@4 migration
- [ ] Vitest + Vue Test Utils for frontend testing
- [ ] UI/UX polish: color palette, card styling, typography
- [ ] UI/UX polish: table improvements, search enhancement
- [ ] UI/UX polish: loading states, empty states
- [ ] UI/UX polish: mobile responsive refinements
- [ ] Accessibility improvements (WCAG 2.2 compliance)

### Out of Scope

- R/Plumber replacement — keeping current stack
- Backend changes — v3 is frontend-only
- CI/CD pipeline — deferred to v4
- Trivy security scanning — deferred to v4

## Current Milestone: v3 Frontend Modernization

**Goal:** Modernize the frontend from Vue 2 + JavaScript to Vue 3 + TypeScript with Bootstrap-Vue-Next, including comprehensive UI/UX improvements based on medical web application best practices.

**Target features:**
- Vue 3 with Composition API and `<script setup>` syntax
- Full TypeScript adoption with strict type checking
- Bootstrap-Vue-Next (0.42+) component library
- Vite for faster build times and modern tooling
- Vitest for unit/component testing
- Modernized UI: color palette, shadows, spacing, loading states
- WCAG 2.2 accessibility compliance

**Frontend Review:** See `.planning/FRONTEND-REVIEW-REPORT.md` for detailed analysis

## Context

**After v2:**
- Docker infrastructure modernized — Traefik, multi-stage builds, security hardening
- Developer workflow improved — hot-reload, 2-minute rebuild cycles
- All v2 requirements shipped — 37/37 complete

**Frontend state (pre-v3):**
- Vue 2.7.8 with @vue/composition-api backport
- Bootstrap-Vue 2.21.2 (no Vue 3 support)
- 50+ Vue components, 100% JavaScript
- Bootstrap 4 visual aesthetic (dated)
- No frontend test coverage

**GitHub Issues:**
- #109: Refactor sysndd_plumber.R into smaller endpoint files — Ready for PR
- #123: Implement comprehensive testing — Foundation complete, integration tests deferred

**Tech Debt (carried from v1):**
- lint-app crashes (esm module compatibility) — will be resolved by Vite migration
- 1240 lintr issues in R codebase
- renv.lock incomplete (Dockerfile workarounds)
- No HTTP endpoint integration tests

**Codebase map:** See `.planning/codebase/` for detailed analysis

## Constraints

- **Stack**: R/Plumber API unchanged, Vue 3 + TypeScript for frontend
- **Database**: MySQL 8.0.40 (unchanged from v2)
- **Docker**: rocker/r-ver:4.1.2 base image (unchanged from v2)
- **Compatibility**: Must work on Windows (WSL2), macOS, and Linux
- **Node.js**: Node 20 LTS (Vue 3 + Vite compatible)
- **Component Library**: Bootstrap-Vue-Next (minimize visual disruption)
- **Browser Support**: Modern browsers (Chrome, Firefox, Safari, Edge — last 2 versions)

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

| Bootstrap-Vue-Next over PrimeVue | Minimize visual disruption for researchers/clinicians | — Pending |
| Vite over Vue CLI | Faster builds, modern tooling, ESM native | — Pending |
| Vitest over Jest | Native Vite integration, faster, ESM compatible | — Pending |

---
*Last updated: 2026-01-22 after v3 milestone started*
