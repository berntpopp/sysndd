# SysNDD Developer Experience Improvements

## What This Is

Developer experience infrastructure for SysNDD, a neurodevelopmental disorders database. v3 delivered a complete frontend modernization from Vue 2 + JavaScript to Vue 3 + TypeScript with Bootstrap-Vue-Next, Vite build tooling, and WCAG 2.2 accessibility compliance.

## Core Value

A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## Current State (v3 shipped 2026-01-23)

**Frontend Stack:** 10/10 (up from 6/10)
- Vue 3.5.25 with Composition API (pure, no compat layer)
- TypeScript 5.9.3 with branded domain types
- Bootstrap-Vue-Next 0.42.0 with Bootstrap 5.3.8
- Vite 7.3.1 (164ms dev startup, 520 KB gzipped bundle)
- 10 Vue 3 composables replacing mixins
- WCAG 2.2 AA compliance (Lighthouse Accessibility 100)

**Frontend Testing:** 144 tests passing with Vitest + Vue Test Utils

**Docker Infrastructure:** 9/10 (from v2)
- Traefik v3.6 reverse proxy with Docker auto-discovery
- Multi-stage Dockerfiles with ccache and BuildKit cache mounts
- Non-root users: API (uid 1001), App (nginx)
- Docker Compose Watch hot-reload development workflow

**API Test Suite:** 610 tests passing in ~74 seconds, 20.3% coverage

**Automation:** 13 Makefile targets across 5 categories

## Requirements

### Validated

<!-- Shipped in v1 -->

- ✓ Modular R/Plumber API with 21 endpoint files — v1
- ✓ JWT-based authentication system — existing
- ✓ Database connection pooling with pool package — existing
- ✓ R code linting with lintr + styler — existing
- ✓ Docker Compose multi-service setup — existing
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
- ✓ Node.js 20 LTS for frontend — v2
- ✓ Alpine-based frontend with nginx-unprivileged — v2
- ✓ Named networks for service isolation (proxy, backend) — v2
- ✓ MySQL 8.0.40 with caching_sha2_password — v2
- ✓ docker-compose.override.yml for development — v2
- ✓ app/Dockerfile.dev for hot-reload development — v2
- ✓ .env.example template for developer onboarding — v2

<!-- Shipped in v3 -->

- ✓ Vue 3 migration from Vue 2.7 — v3
- ✓ TypeScript adoption across infrastructure files — v3
- ✓ Bootstrap-Vue → Bootstrap-Vue-Next component library — v3
- ✓ Vite build tooling (replacing Vue CLI + Webpack) — v3
- ✓ vue-router@4 migration — v3
- ✓ Vitest + Vue Test Utils for frontend testing — v3
- ✓ UI/UX polish: color palette, card styling, typography — v3
- ✓ UI/UX polish: table improvements, search enhancement — v3
- ✓ UI/UX polish: loading states, empty states — v3
- ✓ UI/UX polish: mobile responsive refinements — v3
- ✓ Accessibility improvements (WCAG 2.2 AA compliance) — v3
- ✓ Mixin → Composable conversion (all 7 mixins) — v3
- ✓ @vue/compat removal (pure Vue 3) — v3
- ✓ ESLint 9 flat config with TypeScript support — v3
- ✓ Prettier for code formatting — v3
- ✓ Pre-commit hooks with lint-staged — v3

### Active

<!-- v4 scope TBD -->

- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Trivy security scanning
- [ ] HTTP endpoint integration tests
- [ ] Expanded frontend test coverage (40-50%)
- [ ] Vue component TypeScript conversion

### Out of Scope

- R/Plumber replacement — keeping current stack
- Database changes — MySQL 8.0.40 works well
- Server-side rendering — SPA approach sufficient
- PWA features — keep existing

## Context

**After v3:**
- Frontend fully modernized to Vue 3 + TypeScript
- Developer workflow excellent — 164ms dev startup, instant HMR
- Accessibility compliant — WCAG 2.2 AA, Lighthouse 100
- Bundle optimized — 520 KB gzipped (74% under 2MB target)

**Remaining tech debt:**
- Vue components still .vue JavaScript (not .vue TypeScript)
- Frontend test coverage ~1.5% (infrastructure ready, tests needed)
- lint-app fixed (was crashing, now works via Vite)
- 1240 lintr issues in R codebase
- renv.lock incomplete (Dockerfile workarounds)
- No HTTP endpoint integration tests

**GitHub Issues:**
- #109: Refactor sysndd_plumber.R into smaller endpoint files — Ready for PR
- #123: Implement comprehensive testing — Foundation complete, integration tests deferred

**Codebase map:** See `.planning/codebase/` for detailed analysis

## Constraints

- **Stack**: R/Plumber API unchanged, Vue 3 + TypeScript for frontend
- **Database**: MySQL 8.0.40 (unchanged from v2)
- **Docker**: rocker/r-ver:4.1.2 base image (unchanged from v2)
- **Compatibility**: Must work on Windows (WSL2), macOS, and Linux
- **Node.js**: Node 24 LTS (Vue 3 + Vite)
- **Component Library**: Bootstrap-Vue-Next 0.42.0
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
| Node 24 LTS | Vue 3 + Vite compatible, latest LTS | ✓ Good |
| nginxinc/nginx-unprivileged | Pre-configured non-root nginx, Alpine-based | ✓ Good |
| 12-minute cold build target | Bioconductor packages require source compilation | ✓ Good |
| Bootstrap-Vue-Next over PrimeVue | Minimize visual disruption for researchers/clinicians | ✓ Good |
| Vite over Vue CLI | 164ms startup vs ~30s, ESM native | ✓ Good |
| Vitest over Jest | Native Vite integration, faster, ESM compatible | ✓ Good |
| Incremental Vue 3 migration | @vue/compat for safety, removed at end | ✓ Good |
| TypeScript strict: false | Pragmatic start, can tighten later | ✓ Good |
| Branded domain types | GeneId, EntityId prevent ID confusion | ✓ Good |

---
*Last updated: 2026-01-23 after v3 milestone shipped*
