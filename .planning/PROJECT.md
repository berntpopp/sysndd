# SysNDD Developer Experience Improvements

## What This Is

Developer experience infrastructure for SysNDD, a neurodevelopmental disorders database. v10 focuses on data quality, literature integration, and AI-assisted cluster interpretation — fixing major bugs, improving Publications and Pubtator views for research and curation, adding LLM-generated cluster summaries with Gemini API, and modernizing GitHub Pages deployment. Building on v9's production readiness, v8's gene page, v7's curation workflows, v6's admin panel, v5's visualizations, v4's backend, v3's Vue 3, v2's Docker, and v1's developer tooling.

## Current State (v10.2 shipped 2026-02-03)

**Recent Milestone:** v10.2 Performance & Memory Optimization

**Delivered:**
- Configurable mirai workers via MIRAI_WORKERS env var (1-8 workers, production default 2, dev default 1)
- STRING score_threshold increased to 400 (medium confidence, ~50% fewer false positive edges)
- Adaptive layout algorithms (DrL >1000 nodes, FR-grid 500-1000, FR <500)
- Database-side filtering for logs endpoint (fixed #152 memory bug)
- Query builder with column whitelist and parameterized SQL
- 5 database indexes for logging table
- Comprehensive unit and integration test coverage
- Deployment documentation with memory profiles

**Target issues (RESOLVED):**
- #150: Optimize mirai worker configuration for memory-constrained servers
- #152: ViewLogs endpoint loads entire table into memory before filtering

## Previous State (v10.1 shipped 2026-02-03)

**Recent Milestone:** v10.1 Production Deployment Fixes

**Delivered:**
- Fixed API container UID mismatch (configurable via build-arg, default 1000)
- Fixed migration lock timeout with double-checked locking pattern
- Restored favicon image from _old directory
- Removed container_name directive from API service for scaling

## Previous State (v10.0 shipped 2026-02-01)

**Recent Milestone:** v10.0 Data Quality & AI Insights

**Delivered:**
- Fixed 8 major bugs (EIF2AK2, GAP43, MEF2C, viewer profile, PMID deletion, entities over time, disease renaming, re-reviewer identity)
- Variant navigation links from correlation matrix/counts to filtered entity table
- Publications view: TimePlot aggregation, Stats cards, row details, admin bulk refresh
- Pubtator: gene prioritization with novel alerts, PMID chips, Excel export
- LLM cluster summaries: Gemini API with ellmer, batch pre-generation, LLM-as-judge validation
- LLM admin dashboard: ManageLLM.vue with 5 tabs (Overview, Config, Prompts, Cache, Logs)
- Comparisons data refresh async job with 7 external database parsers
- Documentation migrated to Quarto with GitHub Actions deployment

## Core Value

A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## Technical Stack (v10.0)

**Backend Stack:** 10/10
- R 4.4.3 with 285 packages in renv.lock (added ellmer, coro for LLM)
- Argon2id password hashing with progressive migration
- 66 SQL injection vulnerabilities fixed (parameterized queries)
- 8 domain repositories with 131 parameterized DB calls
- 8 service layers with dependency injection
- require_auth middleware with AUTH_ALLOWLIST pattern
- mirai job system with 8-worker daemon pool + job history
- OMIM via mim2gene.txt + JAX API + MONDO SSSOM mappings
- RFC 9457 error format across all endpoints
- 0 lintr issues, 0 TODO comments
- External API proxy layer (gnomAD, UniProt, Ensembl, AlphaFold, MGI, RGD) with disk caching

**Backend Testing:** 687 tests + 11 E2E passing, 20.3% coverage, 24 integration tests

**Frontend Stack:** 10/10
- Vue 3.5.25 with Composition API (pure, no compat layer)
- TypeScript 5.9.3 with branded domain types
- Bootstrap-Vue-Next 0.42.0 with Bootstrap 5.3.8
- Vite 7.3.1 (164ms dev startup, ~600 KB gzipped bundle)
- 31 Vue 3 composables (added useLlmAdmin, useExcelExport, usePubtatorAdmin in v10)
- WCAG 2.2 AA compliance with vitest-axe accessibility tests
- Chart.js + vue-chartjs for statistics visualizations
- Cytoscape.js for network and phenotype cluster visualizations
- D3.js for protein domain lollipop plots and gene structure visualization
- NGL Viewer for 3D AlphaFold structure with variant highlighting
- Custom TreeMultiSelect component (replaced vue3-treeselect)
- 17 gene page components + 5 LLM components (LlmSummaryCard, LlmConfigPanel, LlmPromptEditor, LlmCacheManager, LlmLogViewer)
- Module-level caching pattern for admin tables
- URL-synced filter state with VueUse

**Frontend Testing:** 190 tests + 6 accessibility test suites with Vitest + Vue Test Utils + vitest-axe

**Docker Infrastructure:** 9/10
- Traefik v3.6 reverse proxy with Docker auto-discovery
- Multi-stage Dockerfiles with ccache and BuildKit cache mounts
- Non-root users: API (uid 1001), App (nginx)
- Docker Compose Watch hot-reload development workflow

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

<!-- Shipped in v5 -->

- ✓ Leiden clustering algorithm (2-3x faster than Walktrap) — v5
- ✓ HCPC kk=50 pre-partitioning (50-70% faster) — v5
- ✓ MCA ncp=8 dimensions (20-30% faster) — v5
- ✓ Cache key versioning with algorithm + STRING version — v5
- ✓ functional_clustering pagination (8.6MB → <500KB) — v5
- ✓ /api/analysis/network_edges endpoint (66k+ PPI edges) — v5
- ✓ Cytoscape.js network visualization with fcose layout — v5
- ✓ Real protein-protein interaction edges in network — v5
- ✓ Interactive hover highlighting with rich tooltips — v5
- ✓ Pan/zoom network controls — v5
- ✓ Click node → entity detail navigation — v5
- ✓ useCytoscape composable with cy.destroy() cleanup — v5
- ✓ useNetworkData composable for data fetching — v5
- ✓ hideEdgesOnViewport optimization — v5
- ✓ useFilterSync composable with VueUse URL sync — v5
- ✓ Wildcard gene search (PKD*, BRCA?) — v5
- ✓ Search highlights matching nodes in network — v5
- ✓ CategoryFilter dropdown component — v5
- ✓ ScoreSlider numeric filter component — v5
- ✓ TermSearch wildcard component — v5
- ✓ Analysis navigation tabs — v5
- ✓ URL state sync for bookmarkable views — v5
- ✓ Bidirectional network-to-table interaction — v5
- ✓ ColorLegend for correlation heatmap — v5
- ✓ Enhanced tooltips with correlation interpretation — v5
- ✓ Download buttons (PNG/SVG) on visualizations — v5
- ✓ Loading states with progress indication — v5
- ✓ Error states with retry buttons — v5
- ✓ Fixed filter=undefined bug in entity links — v5
- ✓ PhenotypeClusters migrated to Cytoscape — v5
- ✓ Correlation heatmap click navigation — v5

<!-- Shipped in v6 -->

- ✓ ManageUser: search, pagination, bulk approve/delete, role management — v6
- ✓ ManageAnnotations: async job composable, progress UI, job history — v6
- ✓ ManageOntology: pagination, search, URL sync, export — v6
- ✓ ManageAbout: CMS markdown editor with draft/publish workflow — v6
- ✓ AdminStatistics: Chart.js dashboard with KPI cards and scientific context — v6
- ✓ ViewLogs: feature parity with Entities table (filters, export, detail drawer) — v6
- ✓ Admin API endpoints: pagination, search, bulk operations — v6
- ✓ Statistics API: entities over time, contributor leaderboard — v6
- ✓ useBulkSelection composable with Set-based cross-page selection — v6
- ✓ useFilterPresets composable with localStorage persistence — v6
- ✓ useAsyncJob composable with VueUse auto-cleanup — v6
- ✓ useCmsContent composable with draft/publish workflow — v6
- ✓ LogDetailDrawer with copy to clipboard and keyboard navigation — v6

<!-- Shipped in v7 -->

- ✓ Fix ApproveUser page crash (JavaScript reduce error) — v7
- ✓ Fix ModifyEntity status dropdown (empty options bug) — v7
- ✓ Custom TreeMultiSelect component replacing vue3-treeselect — v7
- ✓ Multi-select for phenotypes and variations restored — v7
- ✓ GeneBadge, DiseaseBadge, EntityBadge UI components — v7
- ✓ ModifyEntity entity preview with rich badge components — v7
- ✓ Contextual modal headers with entity context — v7
- ✓ Column filters on ApproveReview, ApproveStatus tables — v7
- ✓ Standardized pagination (10/25/50/100) across all curation views — v7
- ✓ ManageReReview search functionality — v7
- ✓ Accessibility labels on all curation action buttons — v7
- ✓ useReviewForm composable and ReviewFormFields component — v7
- ✓ useStatusForm composable for status modification — v7
- ✓ useFormDraft composable with auto-save and restoration — v7
- ✓ Modal @show reset handlers preventing stale data — v7
- ✓ Re-review batch management service layer (re-review-service.R) — v7
- ✓ 6 re-review API endpoints (batch create/preview/reassign/archive/assign/recalculate) — v7
- ✓ BatchCriteriaForm and useBatchForm for dynamic batch creation — v7
- ✓ Gene-specific user assignment for re-review — v7
- ✓ SkipLink, AriaLiveRegion, IconLegend accessibility components — v7
- ✓ useAriaLive composable with dual feedback pattern — v7
- ✓ vitest-axe accessibility tests for all 6 curation views — v7

<!-- Shipped in v8 -->

- ✓ Gene page redesign with hero section, grouped cards, copy-to-clipboard — v8
- ✓ Backend external API proxy layer (gnomAD, UniProt, Ensembl, AlphaFold, MGI/RGD) — v8
- ✓ Server-side caching for external API responses (memoise + cachem) — v8
- ✓ gnomAD constraint scores display (pLI, LOEUF, mis_z) on gene detail page — v8
- ✓ ClinVar variant summary via gnomAD GraphQL API — v8
- ✓ Protein domain lollipop plot (D3.js) with ClinVar variant mapping — v8
- ✓ 3D protein structure viewer (NGL.js) with AlphaFold structures and variant highlighting — v8
- ✓ Enhanced model organism phenotype data (MGI/RGD via backend proxy) — v8
- ✓ Gene structure visualization with exon/intron display — v8
- ✓ Reusable gene page components (IdentifierRow, ResourceLink, etc.) — v8

<!-- Shipped in v9 -->

- ✓ Automated migration system with schema_version tracking — v9
- ✓ Migration runner auto-applies on API startup — v9
- ✓ Migration 002 idempotent (IF NOT EXISTS guards) — v9
- ✓ Backup management API (list, create, download, restore) — v9
- ✓ ManageBackups admin UI with download and restore — v9
- ✓ Type-to-confirm pattern for restore ("RESTORE") — v9
- ✓ Pre-restore automatic backup creation — v9
- ✓ Mailpit container for development email capture — v9
- ✓ /api/admin/smtp/test endpoint — v9
- ✓ User registration E2E tests with email verification — v9
- ✓ Password reset E2E tests with Mailpit — v9
- ✓ Production Docker with explicit DB_POOL_SIZE — v9
- ✓ /api/health/ready endpoint with DB ping and migration status — v9
- ✓ Makefile preflight target for production validation — v9
- ✓ Docker security_opt no-new-privileges on all services — v9
- ✓ Docker CPU resource limits on all services — v9
- ✓ Docker log rotation on all services — v9
- ✓ nginx-brotli with pinned version and Brotli compression — v9
- ✓ Static asset caching with 1-year immutable headers — v9
- ✓ API graceful shutdown handler — v9
- ✓ Batch assignment email notification — v9
- ✓ Self-service profile editing (email/ORCID) — v9

<!-- Shipped in v10 -->

- ✓ Fix EIF2AK2 publication update incomplete (#122) — v10
- ✓ Fix GAP43 entity not visible (#115) — v10
- ✓ Fix MEF2C entity updating issues (#114) — v10
- ✓ Fix viewer profile / auto-logout bug — v10
- ✓ Fix PMID deletion when adding new PMID during re-review — v10
- ✓ Fix entities over time by gene counts (#44) — v10
- ✓ Fix disease renaming requiring no approval (#41) — v10 (WONTFIX)
- ✓ Fix re-reviewer identity preservation (#41) — v10
- ✓ Fix Variant Correlations broken links (VariantCounts, VariantCorrelations) — v10
- ✓ Publications table UX improvements — v10
- ✓ Publications API metadata fetching view — v10
- ✓ Publications TimePlot improvements — v10
- ✓ Publications Stats improvements — v10
- ✓ Pubtator Stats fix — v10
- ✓ Pubtator curator gene prioritization lists — v10
- ✓ Pubtator user research tools — v10
- ✓ Pubtator concept documentation — v10
- ✓ LLM cluster summary backend (Gemini API with ellmer) — v10
- ✓ LLM batch pre-generation job via mirai — v10
- ✓ LLM structured output prompts — v10
- ✓ LLM-as-judge validation pipeline — v10
- ✓ Phenotype cluster summaries with LlmSummaryCard — v10
- ✓ Functional cluster summaries with LlmSummaryCard — v10
- ✓ Admin comparisons data refresh async job — v10
- ✓ GitHub Pages Actions workflow deployment — v10

<!-- Shipped in v10.2 -->

- ✓ Configurable mirai workers via MIRAI_WORKERS (1-8) — v10.2
- ✓ STRING score_threshold 400 (medium confidence) — v10.2
- ✓ Adaptive layout algorithms (DrL/FR-grid/FR) — v10.2
- ✓ Database-side filtering for logs endpoint — v10.2
- ✓ Query builder with column whitelist — v10.2
- ✓ Parameterized SQL preventing injection — v10.2
- ✓ Logging table indexes (timestamp, status, path, composites) — v10.2
- ✓ LLM batch gc() every 10 clusters — v10.2
- ✓ Deployment documentation with memory profiles — v10.2
- ✓ Unit tests for worker config and query builder — v10.2
- ✓ Integration tests for logs pagination — v10.2
- ✓ LLM admin dashboard (ManageLLM.vue with 5 tabs) — v10

### Active

(None — start next milestone with `/gsd:new-milestone`)

### Out of Scope

- R/Plumber replacement — keeping current stack, modernized it instead
- Database schema changes — MySQL 8.0.40 works well
- Server-side rendering — SPA approach sufficient
- PWA features — keep existing
- bcrypt package — sodium with Argon2id is OWASP 2025 recommended
- 3D network visualization — depth perception issues
- WebGL renderer for >500 nodes — defer to future milestone
- STRINGdb v12.0 upgrade — requires database migration
- PrimeVue TreeSelect — using Bootstrap-Vue-Next only for ecosystem consistency
- Server-side pagination for curation tables — client-side sufficient for current data volumes
- gnomAD constraint columns in gene table — gene detail page only for v8, may revisit in v9
- Direct frontend calls to external APIs — all routed through R/Plumber backend

## Context

**After v10:**
- Complete LLM cluster summary pipeline with Gemini API integration
- LLM admin dashboard for model management, cache control, and log viewing
- All 8 major bugs fixed, literature tools enhanced
- 1,381 tests passing across R API and Vue frontend
- 31 Vue 3 composables total

**After v9:**
- Production-ready with automated database migrations, backup management, and E2E tested user workflows
- Migration runner with schema_version tracking and idempotent execution
- Backup management API and admin UI with type-to-confirm safety for restore

**Minor tech debt (non-blocking):**
- FDR column sorting needs sortCompare for scientific notation
- ScoreSlider presets need domain-specific values
- Correlation heatmap → cluster navigation (architectural limitation)
- ModifyEntity review modal not yet refactored to useReviewForm
- Clustering determinism via set.seed(42) — fragile if algorithm parameters change

**GitHub Issues:**
- #115 (GAP43 orphaned entity) — fixed with atomic entity creation

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
| Leiden over Walktrap | 2-3x faster, modularity objective for biological networks | ✓ Good |
| Cytoscape.js over D3 force | Rich algorithms, compound nodes, WebGL support | ✓ Good |
| fcose over cose-bilkent | 2x speed improvement, active maintenance | ✓ Good |
| VueUse useUrlSearchParams | Zero boilerplate URL state sync | ✓ Good |
| Non-reactive cy instance | let cy (not ref()) prevents layout recalculations | ✓ Good |
| cy.destroy() cleanup | Prevents 100-300MB memory leaks per navigation | ✓ Good |
| Module-level singleton for useFilterSync | Simpler than Pinia, sufficient for analysis pages | ✓ Good |
| Module-level API caching for admin tables | Prevents duplicate calls on URL-triggered remounts | ✓ Good |
| history.replaceState for URL sync | Avoids component remount cycles | ✓ Good |
| Set-based bulk selection | O(1) lookups, cross-page persistence | ✓ Good |
| Type-to-confirm for destructive actions | Requires exact "DELETE" text for safety | ✓ Good |
| Tree-shaken Chart.js registration | Reduces bundle size ~30-40% vs registerables | ✓ Good |
| JSON column for CMS sections | Flexible schema without migrations | ✓ Good |
| VueUse useIntervalFn for polling | Auto-cleanup via tryOnCleanup | ✓ Good |
| BOffcanvas for detail drawers | Bootstrap-Vue-Next pattern consistency | ✓ Good |
| Custom TreeMultiSelect over vue3-treeselect | Bootstrap-Vue-Next only, zero new dependencies | ✓ Good |
| Options API for recursive TreeNode | script setup doesn't support self-reference | ✓ Good |
| Ancestor context in tree search | Shows hierarchy path when children match search | ✓ Good |
| null vs [] for loading state | null = not loaded, [] = loaded empty — prevents crashes | ✓ Good |
| Composable-based form extraction | useReviewForm/useStatusForm pattern for DRY forms | ✓ Good |
| useFormDraft with auto-save | 2s debounce + localStorage + restoration prompts | ✓ Good |
| Parameterized batch queries | build_batch_params() for safe dynamic WHERE clauses | ✓ Good |
| Entity overlap prevention in batches | Exclusion subquery prevents double-assignment | ✓ Good |
| Dual feedback pattern | makeToast (visual) + announce (screen reader) for a11y | ✓ Good |
| vitest-axe for accessibility testing | Industry-standard axe-core, catches ~57% WCAG issues | ✓ Good |
| httr2 for external API proxying | Modern R HTTP client with retry/throttle built-in | ✓ Good |
| memoise + cachem for API caching | Disk-based caching with per-source TTL | ✓ Good |
| NGL Viewer over Mol* | Smaller footprint, simpler API for single structure viewing | ✓ Good |
| Non-reactive NGL Stage | let stage (not ref()) prevents Vue proxy issues with WebGL | ✓ Good |
| ResizeObserver for lazy tab init | Detects valid container dimensions for WebGL in hidden tabs | ✓ Good |
| Error isolation in aggregation | tryCatch per source returns partial data on failures | ✓ Good |
| ellmer >= 0.4.0 for Gemini API | More features than gemini.R, better maintained | ✓ Good |
| Entity validation mandatory for LLM | LLMs invent plausible gene names | ✓ Good |
| LLM-as-judge in batch pipeline | Validates summary accuracy before caching | ✓ Good |
| Hash-based cache invalidation | Cluster composition changes invalidate old summaries | ✓ Good |
| set.seed(42) for clustering | Ensures hash consistency between batch and API | ⚠️ Fragile |
| noble P3M URL for Docker | rocker/r-ver:4.4.3 uses Ubuntu 24.04 with ICU 74 | ✓ Good |
| DBI NULL to NA conversion | DBI::dbBind requires length 1 for parameters | ✓ Good |
| Plumber array unwrapping helper | R/Plumber wraps scalars in arrays | ✓ Good |

---
*Last updated: 2026-02-03 after v10.2 milestone completed*
