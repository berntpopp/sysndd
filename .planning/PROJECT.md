# SysNDD Developer Experience Improvements

## What This Is

Developer experience infrastructure for SysNDD, a neurodevelopmental disorders database. v4 delivered a complete backend modernization with R 4.4.3 upgrade, security hardening (66 SQL injection fixes, Argon2id passwords), async processing (mirai job system), repository/service architecture layers, and OMIM data source migration from genemap2 to mim2gene.txt + JAX API.

## Core Value

A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## Current State (v4 shipped 2026-01-24)

**Backend Stack:** 10/10 (up from 6/10)
- R 4.4.3 with 281 packages in renv.lock
- Argon2id password hashing with progressive migration
- 66 SQL injection vulnerabilities fixed (parameterized queries)
- 8 domain repositories with 131 parameterized DB calls
- 7 service layers with dependency injection
- require_auth middleware with AUTH_ALLOWLIST pattern
- mirai job system with 8-worker daemon pool
- OMIM via mim2gene.txt + JAX API + MONDO SSSOM mappings
- RFC 9457 error format across all endpoints
- 0 lintr issues (from 1,240), 0 TODO comments (from 29)

**Backend Testing:** 634 tests passing, 20.3% coverage, 24 integration tests

**Frontend Stack:** 10/10 (from v3)
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

**Automation:** 13 Makefile targets across 5 categories

## Current Milestone: v5.0 Analysis Modernization

**Goal:** Transform the analysis pages (Phenotype Clusters, Gene Networks, Correlation) into a fast, interconnected, and modern visualization experience with true network graphs and professional UI/UX.

**Target features:**
- Performance optimization: cold start from ~15s to <5s (Leiden algorithm, HCPC pre-partition, SQL push-down)
- True network visualization: Cytoscape.js with actual protein-protein interaction edges
- Gene search: wildcard pattern matching with highlighting
- Hybrid views: compound nodes showing genes within cluster containers
- UI/UX: interlinking between pages, click-through navigation, rich tooltips
- Filter improvements: numeric comparisons, dropdown selects for categories

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

<!-- Shipped in v4 -->

- ✓ R upgraded from 4.1.2 to 4.4.3 — v4
- ✓ Fresh renv.lock with 281 packages (no Dockerfile workarounds) — v4
- ✓ 66 SQL injection vulnerabilities fixed with parameterized queries — v4
- ✓ Argon2id password hashing with progressive migration — v4
- ✓ RFC 9457 error format across all endpoints — v4
- ✓ Logging sanitized to exclude sensitive data — v4
- ✓ mirai async processing with 8-worker daemon pool — v4
- ✓ HTTP 202 Accepted pattern for long-running operations — v4
- ✓ Job status polling endpoint — v4
- ✓ Database access layer (db_execute_query, db_execute_statement, db_with_transaction) — v4
- ✓ 8 domain repositories (entity, review, status, publication, phenotype, ontology, user, hash) — v4
- ✓ 7 service layers (auth, entity, review, approval, user, status, search) — v4
- ✓ require_auth middleware with AUTH_ALLOWLIST — v4
- ✓ database-functions.R god file eliminated (1,226 lines decomposed) — v4
- ✓ OMIM via mim2gene.txt + JAX API (replacing genemap2) — v4
- ✓ MONDO equivalence via SSSOM mappings — v4
- ✓ ManageAnnotations async job polling UI — v4
- ✓ /api/version endpoint with semantic version and git commit — v4
- ✓ Cursor-based pagination with 500-item max — v4
- ✓ 0 lintr issues (from 1,240) — v4
- ✓ 0 TODO comments (from 29) — v4
- ✓ 24 API integration tests — v4

### Active

<!-- v5 scope - Analysis Modernization -->

**Performance:**
- [ ] Replace Walktrap with Leiden algorithm for clustering (2-3x faster)
- [ ] HCPC pre-partitioning with kk parameter (50-70% faster)
- [ ] Push database joins to SQL (single collect(), 4x faster)
- [ ] Reduce MCA principal components from 15 to 8
- [ ] Pre-warm cache on API startup
- [ ] Paginate large responses (functional_clustering 8.6MB → <500KB)

**Network Visualization:**
- [ ] New `/api/analysis/functional_network` endpoint returning Cytoscape JSON
- [ ] Extract STRING network edges (currently discarded)
- [ ] Cytoscape.js integration with cose-bilkent layout
- [ ] Gene search with wildcard support and highlighting
- [ ] Compound nodes for hybrid cluster/network view
- [ ] Multiple layout algorithms (COSE, circle, grid)
- [ ] WebGL renderer for large networks (>500 nodes)

**UI/UX:**
- [ ] Navigation tabs across all analysis pages
- [ ] Click-through from correlation heatmap to clusters
- [ ] Numeric column filters with comparison operators
- [ ] Dropdown filters for categories
- [ ] URL state sync for bookmarking/sharing
- [ ] Enhanced tooltips with context and navigation
- [ ] Color legends for heatmaps
- [ ] Fix `filter=undefined` bug in cluster links
- [ ] Enable download buttons (PNG/SVG)

### Deferred to v6

- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Trivy security scanning
- [ ] Expanded frontend test coverage (40-50%)
- [ ] Vue component TypeScript conversion
- [ ] URL path versioning (/api/v1/)
- [ ] Version displayed in frontend

### Out of Scope

- R/Plumber replacement — keeping current stack, modernized it instead
- Database schema changes — MySQL 8.0.40 works well
- Server-side rendering — SPA approach sufficient
- PWA features — keep existing
- bcrypt package — sodium with Argon2id is OWASP 2025 recommended

## Context

**After v4:**
- Backend fully modernized to R 4.4.3 with modern security
- All 66 SQL injection vulnerabilities fixed
- Async processing for long-running operations
- Clean architecture with repository + service layers
- OMIM data source migrated to freely available sources
- Zero technical debt (0 lintr issues, 0 TODOs)

**Remaining items for v5:**
- CI/CD pipeline not yet implemented
- Frontend test coverage still ~1.5%
- Vue components still .vue JavaScript (not TypeScript)

**GitHub Issues:**
- #109: Refactor sysndd_plumber.R into smaller endpoint files — Ready for PR (v4 complete)
- #123: Implement comprehensive testing — Foundation complete, integration tests added in v4

**Codebase map:** See `.planning/codebase/` for detailed analysis

## Constraints

- **Stack**: R/Plumber API (modernized), Vue 3 + TypeScript for frontend
- **R Version**: R 4.4.3 (upgraded from 4.1.2 in v4)
- **Database**: MySQL 8.0.40 (unchanged)
- **Docker**: rocker/r-ver:4.4.3 base image
- **Compatibility**: Must work on Windows (WSL2), macOS, and Linux
- **Node.js**: Node 24 LTS (Vue 3 + Vite)
- **Component Library**: Bootstrap-Vue-Next 0.42.0
- **Browser Support**: Modern browsers (Chrome, Firefox, Safari, Edge — last 2 versions)
- **OMIM Data**: mim2gene.txt + JAX API (no OMIM license required)

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
| sodium over bcrypt | Argon2id is OWASP 2025 recommended | ✓ Good |
| Progressive password migration | Zero-downtime, no forced resets | ✓ Good |
| mirai over future/promises | Production-ready, better Plumber integration | ✓ Good |
| Pre-fetch data for async jobs | Workaround for pool cross-process limitation | ✓ Good |
| mim2gene.txt + JAX API | Free OMIM data sources, no license needed | ✓ Good |
| MONDO SSSOM mappings | Standard cross-ontology equivalence format | ✓ Good |
| Repository + Service layers | DRY/KISS/SOLID, testable, maintainable | ✓ Good |
| require_auth middleware | Centralized auth, eliminates duplicated checks | ✓ Good |

---
*Last updated: 2026-01-24 after starting v5 Analysis Modernization milestone*
