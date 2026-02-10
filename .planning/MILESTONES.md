# Project Milestones: SysNDD Developer Experience

## v10.6 Curation UX Fixes & Security (Shipped: 2026-02-10)

**Delivered:** Fix critical curation workflow regressions (HTTP 500 on status change, unnecessary status approvals, ghost entity prevention), patch axios DoS vulnerability, and add dismiss/auto-dismiss capability for pending queue management.

**Phases completed:** 83-86 (6 plans total)

**Key accomplishments:**

- Fixed HTTP 500 on status change caused by modal lifecycle race condition (resetForm after loadData) + backend NULL compact fix
- Patched axios CVE-2026-25639 DoS vulnerability (1.13.4 → 1.13.5)
- Added change detection to all 3 curation views (ModifyEntity, ApproveReview, ApproveStatus) preventing unnecessary status/review creation
- Verified ghost entity prevention via atomic svc_entity_create_full() transaction wrapper, enhanced rollback contract tests
- Built dismiss & auto-dismiss for pending statuses/reviews with 40 integration test assertions and full E2E Playwright verification
- Restored "approve both" checkbox functionality (symptom of status creation bug, auto-fixed)

**Stats:**

- 40 files modified (+6,467/-43 lines)
- 63,911 lines R code, 75,287 lines Vue/TS
- 4 phases, 6 plans, 30 commits
- 1 day (2026-02-10)

**Git range:** `aeca2118` → `d6df155f`

**Target Issues:**
- HTTP 500 on status change for ATOH1 entities — RESOLVED
- "Approve both" checkbox not appearing — RESOLVED (symptom fix)
- Status requiring approval even when unchanged — RESOLVED
- Ghost entity prevention — VERIFIED (remediation SQL documented)
- axios DoS vulnerability CVE-2026-25639 — RESOLVED
- Pending queue cluttered with dismissed items — RESOLVED

**What's next:** Planning next milestone

---

## v10.5 Bug Fixes & Data Integrity (Shipped: 2026-02-09)

**Delivered:** Fix 5 open bugs across CurationComparisons (#173), AdminStatistics (#172, #171), PubTator (#170), and Traefik (#169) with significant unplanned improvements including BioCJSON parsing pipeline rewrite (72% annotation loss fixed) and 18 broken transaction callers repaired.

**Phases completed:** 80-82 (6 plans total)

**Key accomplishments:**

- Fixed CurationComparisons cross-database max aggregation with shared `normalize_comparison_categories()` helper (#173)
- Fixed AdminStatistics re-review approval sync, KPI race condition, date calculations, and request cancellation (#172)
- Fixed entity trend chart sparse time-series aggregation with `mergeGroupedCumulativeSeries()` (#171)
- Rewrote BioCJSON parsing pipeline fixing 72% annotation loss; annotation coverage improved from 110 to 491 PMIDs (#170)
- Fixed 18 broken `db_with_transaction` callers that had zero atomicity (expression pattern → function pattern)
- Added entity trend chart filter controls (NDD/Non-NDD/All, Combined/By Category, per-category checkboxes)

**Stats:**

- 88 files modified (+12,594/-3,292 lines)
- 106,108 lines R code, 74,057 lines Vue/TS
- 3 phases, 6 plans, 49 commits
- 2 days (2026-02-08 → 2026-02-09)

**Git range:** `6906b12c` → `632e10f3`

**Target Issues:**
- #173: CurationComparisons cross-database max category aggregation — RESOLVED
- #172: AdminStatistics re-review approval sync and sub-bugs — RESOLVED
- #171: AdminStatistics entity trend chart aggregation — RESOLVED
- #170: PubTator annotation storage failure — RESOLVED
- #169: Traefik TLS cert selection and startup warnings — RESOLVED

**Deferred:** 6 requirements (INTEG-01 through INTEG-06 for #167 entity integrity audit) deferred to v10.6

**What's next:** Planning next milestone

---

## v10.2 Performance & Memory Optimization (Shipped: 2026-02-03)

**Delivered:** Optimize API memory usage for memory-constrained servers with configurable mirai workers, STRING threshold optimization, adaptive layout algorithms, and fix ViewLogs performance bug with database-side filtering.

**Phases completed:** 69-72 (11 plans total)

**Key accomplishments:**

- Implemented configurable mirai workers via MIRAI_WORKERS env var with bounds validation (1-8)
- Increased STRING score_threshold from 200 to 400 (medium confidence, ~50% fewer false positive edges)
- Added adaptive layout algorithm selection (DrL >1000 nodes, FR-grid 500-1000, FR <500)
- Built database-side filtering for logs endpoint eliminating collect() memory anti-pattern
- Created query builder with column whitelist and parameterized SQL preventing injection
- Added 5 database indexes for logging table (timestamp, status, path, composites)
- Implemented gc() calls in LLM batch processing (every 10 clusters)
- Created comprehensive unit and integration test coverage
- Documented memory configuration with deployment profiles

**Stats:**

- 100,143 lines R code
- 4 phases, 11 plans
- 39 requirements satisfied
- 1 day (2026-02-03)

**Git range:** `dbaf0bc5` → `a8fff3a7`

**Target Issues:**
- #150: Optimize mirai worker configuration for memory-constrained servers — RESOLVED
- #152: ViewLogs endpoint loads entire table into memory before filtering — RESOLVED

**What's next:** Planning next milestone

---

## v10.1 Production Deployment Fixes (Shipped: 2026-02-03)

**Delivered:** Fixed production deployment issues including API container UID mismatch, migration lock timeout, missing favicon, and container_name directive blocking scaling.

**Phases completed:** 66-68 (4 plans total)

**Key accomplishments:**

- Fixed API container UID mismatch with configurable build-arg (default 1000)
- Fixed migration lock timeout with double-checked locking pattern
- Restored favicon image from _old directory
- Removed container_name directive from API service for scaling

**Stats:**

- 3 phases, 4 plans
- 1 day (2026-02-03)

**What's next:** v10.2 Performance & Memory Optimization

---

## v10.0 Data Quality & AI Insights (Shipped: 2026-02-01)

**Delivered:** Stabilize data quality with 8 major bug fixes, enhance literature research tools (Publications, Pubtator), and add AI-generated cluster summaries using Gemini API with LLM-as-judge validation and full admin dashboard.

**Phases completed:** 55-65 (25 plans total, 12 phases including decimal phases)

**Key accomplishments:**

- Fixed 8 critical bugs blocking entity updates, viewer profile access, PMID preservation, and chart accuracy
- Built variant navigation links from correlation matrix/counts to filtered entity table
- Enhanced Publications with TimePlot aggregation, Stats cards, row details, and admin bulk refresh
- Created Pubtator gene prioritization with novel alerts, PMID chips, and Excel export
- Integrated Gemini API via ellmer package with structured JSON output and entity validation
- Built LLM-as-judge validation pipeline with accept/low_confidence/reject verdicts
- Implemented hash-based cache invalidation for cluster summary freshness
- Created LlmSummaryCard component with AI provenance badge and confidence indicator
- Built complete LLM admin dashboard (ManageLLM.vue) with 5 tabs: Overview, Config, Prompts, Cache, Logs
- Migrated documentation to Quarto with GitHub Actions deployment
- Created comparisons data refresh async job with 7 external database parsers

**Stats:**

- 83,622 lines R code, 72,092 lines Vue/TS
- 12 phases (including decimal), 25 plans
- 163 commits
- 2 days (2026-01-31 → 2026-02-01)

**Git range:** `5e674728` → `320719b9`

**Patterns established:**
- LLM batch generation chained after clustering job (mirai promise callback)
- LLM-as-judge validation integrated into summary pipeline
- Hash-based cache invalidation for cluster composition changes
- set.seed(42) for clustering determinism (hash consistency)
- Plumber array unwrapping helper for R/Vue integration
- Tab-based admin dashboard with child component emit patterns

**What's next:** Planning next milestone

---

## v9.0 Production Readiness (Shipped: 2026-01-31)

**Delivered:** Make SysNDD production-ready with automated database migrations, backup management with admin UI, verified user lifecycle workflows with real SMTP testing, and production Docker validation with security hardening.

**Phases completed:** 47-54 (16 plans total)

**Key accomplishments:**

- Built migration runner infrastructure with schema_version tracking and idempotent execution
- Integrated auto-migration on API startup with multi-worker lock coordination
- Created backup management API (list, create, download, restore) with async job handling
- Built ManageBackups admin UI with type-to-confirm safety for restore operations
- Added Mailpit container for development email capture
- Created comprehensive E2E tests for user registration, approval, and password reset flows
- Configured production Docker with explicit connection pool sizing (DB_POOL_SIZE)
- Added /api/health/ready endpoint with database connectivity and migration status checks
- Created `make preflight` target for production validation
- Hardened Docker: pinned nginx-brotli v1.28.0, 1-year immutable asset caching, Brotli compression
- Added security_opt no-new-privileges, CPU limits, and log rotation to all services
- Implemented graceful shutdown handler in API for clean pool closure
- Post-milestone: batch assignment email notification and self-service profile editing

**Stats:**

- 32,275 lines R code, 64,597 lines Vue/TS
- 8 phases, 16 plans
- 102 commits
- 320 files modified (+27,140/-9,056 lines)
- 3 days (2026-01-29 → 2026-01-31)

**Git range:** `f747e97c` → `5e674728`

**Patterns established:**
- Migration lock pattern (single worker applies, others skip)
- Type-to-confirm pattern for destructive operations ("RESTORE")
- Async backup jobs with polling via useAsyncJob composable
- Mailpit helper pattern for E2E email testing
- Health endpoint pattern with DB ping + migration status
- Preflight validation pattern (build → start → health check → cleanup)
- Docker hardening pattern (security_opt, resource limits, log rotation)

**What's next:** Planning next milestone

---

## v8.0 Gene Page & Genomic Data Integration (Shipped: 2026-01-29)

**Delivered:** Transform the gene detail page from a flat identifier list into a modern genomic analysis interface with gnomAD constraint scores, ClinVar variant summaries, D3.js protein domain lollipop plots, gene structure visualization, 3D AlphaFold structure viewer with variant highlighting, and model organism phenotypes from MGI and RGD — all with WCAG 2.2 AA accessibility compliance.

**Phases completed:** 40-46 (25 plans total)

**Key accomplishments:**

- Built backend proxy layer for 6 external APIs (gnomAD, UniProt, Ensembl, AlphaFold, MGI, RGD) with disk caching and rate limiting
- Redesigned gene page with hero section, grouped identifier cards, and clinical resources grid
- Created constraint score display with gnomAD-style SVG confidence interval bars (pLI, LOEUF, missense Z)
- Built ClinVar variant summary with ACMG 5-class colored badges and pathogenicity breakdown
- Implemented D3.js protein domain lollipop plot with UniProt domains and ClinVar variant mapping
- Added gene structure visualization with exons, introns, UTRs, and strand orientation from Ensembl
- Integrated NGL Viewer for 3D AlphaFold structure with pLDDT coloring and variant highlighting
- Created model organism phenotype cards (MGI mouse, RGD rat) with zygosity breakdown

**Stats:**

- 24 files created (17 Vue components + 7 R proxy files)
- ~8,000 lines of code (gene page components + proxy layer)
- 7 phases, 25 plans
- 143 commits
- 3 days (2026-01-27 → 2026-01-29)

**Git range:** `1918ee18` → `623b28d6`

**Patterns established:**
- External API proxy pattern (httr2 with memoise caching, per-source TTL)
- Error isolation pattern (partial success with tryCatch per source)
- Non-reactive WebGL pattern (let stage + markRaw() for Vue 3/NGL)
- ResizeObserver pattern for lazy tab WebGL initialization

**What's next:** Planning next milestone

---

## v7.0 Curation Workflow Modernization (Shipped: 2026-01-27)

**Delivered:** Transform curation views from basic forms into modern, accessible interfaces with hierarchical multi-select, reusable form composables, dynamic re-review batch management, and WCAG 2.2 AA accessibility compliance across all curation workflows.

**Phases completed:** 34-39 (21 plans total)

**Key accomplishments:**

- Fixed 4 critical bugs blocking basic curation operations (ApproveUser crash, dropdown, names, modal staleness)
- Built custom TreeMultiSelect component with Bootstrap-Vue-Next primitives, replacing vue3-treeselect dependency
- Created GeneBadge, DiseaseBadge, EntityBadge components for rich entity previews across 13 files
- Extracted useReviewForm, useStatusForm, useFormDraft composables reducing 665 lines of duplication
- Built complete re-review batch management system (service layer, 6 API endpoints, batch creation/preview/assign/recalculate UI)
- Added WCAG 2.2 AA accessibility pass: SkipLink, AriaLiveRegion, IconLegend, aria-hidden, 6 vitest-axe test suites

**Stats:**

- 109 files modified (+29,578/-3,275 lines)
- 7 phases (including 35.1 inserted), 21 plans
- 122 commits
- 2 days (2026-01-26 → 2026-01-27)

**Git range:** `44eab5f` → `98f4a74`

**Patterns established:**
- TreeMultiSelect recursive component pattern (Options API for self-reference)
- Form composable extraction pattern (useReviewForm, useStatusForm)
- Draft persistence pattern (useFormDraft with auto-save and restoration prompts)
- Dual feedback pattern (makeToast + announce for accessibility)
- Re-review batch service layer pattern (service → endpoint → composable → component)
- IconLegend pattern for explaining symbolic icons in tables

**What's next:** Planning next milestone

---

## v6.0 Admin Panel Modernization (Shipped: 2026-01-26)

**Delivered:** Transform admin views from basic CRUD forms into modern, feature-rich management interfaces with consistent UI/UX, pagination, search, bulk operations, Chart.js visualizations, CMS-style content editing, and improved async job monitoring.

**Phases completed:** 28-33 (20 plans total)

**Key accomplishments:**

- Modernized ManageUser and ManageOntology with TablesEntities pattern (search, pagination, URL sync, export)
- Implemented bulk user operations (approve, delete, role assignment) with Bootstrap modal confirmations
- Built statistics dashboard with Chart.js visualizations (EntityTrendChart, ContributorBarChart, KPI cards)
- Created CMS-style content editing for About page with draft/publish workflow
- Extracted useAsyncJob composable with VueUse auto-cleanup for HGNC update jobs
- Added advanced log filtering with detail drawer, keyboard navigation, and compliance export

**Stats:**

- 48,643 lines Vue/TypeScript, 63,640 lines R
- 6 phases, 20 plans
- 104 commits
- 118 files modified (+26,301/-1,347 lines)
- 2 days (2026-01-25 → 2026-01-26)

**Git range:** `3d355cf` (docs(28): capture phase context) → `599e4dc` (feat(33): add delete older logs)

**Patterns established:**
- Module-level caching pattern (prevents duplicate API calls on component remount)
- Filter pills pattern (visual feedback with individual removal)
- Bulk action pattern (useBulkSelection composable with Set-based ID storage)
- CMS draft/publish pattern (useCmsContent composable with versioning)
- Async job pattern (useAsyncJob with VueUse useIntervalFn auto-cleanup)
- Drawer detail pattern (BOffcanvas with copy to clipboard and keyboard navigation)

**What's next:** CI/CD pipeline (GitHub Actions), Trivy security scanning, frontend test coverage expansion

---

## v5.0 Analysis Modernization (Shipped: 2026-01-25)

**Delivered:** Transform analysis pages from D3.js bubble charts to Cytoscape.js network visualization with real PPI edges, 50-65% performance improvement via Leiden clustering, and modern filter/navigation composables.

**Phases completed:** 25-27 (16 plans total)

**Key accomplishments:**

- Migrated clustering from Walktrap to Leiden algorithm (2-3x faster)
- Added cache key versioning with algorithm and STRING version
- Created /api/analysis/network_edges endpoint (66k+ PPI edges)
- Built Cytoscape.js NetworkVisualization component (807 lines) with fcose layout
- Created URL-synced filter composables (useFilterSync, useWildcardSearch)
- Added biologist-friendly wildcard search (PKD*, BRCA?)
- Built AnalysisTabs navigation with bidirectional table-network interaction
- Migrated PhenotypeClusters from D3 to Cytoscape
- Proper memory leak prevention (cy.destroy() on navigation)

**Stats:**

- 42,376 lines Vue/TypeScript, 62,334 lines R
- 3 phases, 16 plans
- 99 commits
- 102 files modified (+24,117/-4,991 lines)
- 2 days (2026-01-24 → 2026-01-25)

**Git range:** `a005da7` (docs: start milestone v5.0) → `06fa54b` (chore: add v5.0 milestone audit)

**Tech debt (minor):**
- FDR column sorting needs sortCompare for scientific notation
- ScoreSlider presets need domain-specific values
- Correlation heatmap → cluster navigation (architectural limitation)

**What's next:** CI/CD pipeline (GitHub Actions), Trivy security scanning, frontend test coverage expansion

---

## v4 Backend Overhaul (Shipped: 2026-01-24)

**Delivered:** Complete backend modernization with R 4.4.3 upgrade, security hardening (66 SQL injection fixes, Argon2id passwords), async processing (mirai job system), repository/service layers, and OMIM data source migration.

**Phases completed:** 18-24 (42 plans total)

**Key accomplishments:**

- R upgraded from 4.1.2 to 4.4.3 with clean renv.lock (281 packages)
- Fixed 66 SQL injection vulnerabilities with parameterized queries
- Implemented Argon2id password hashing with progressive migration
- Created mirai-based job manager with 8-worker daemon pool
- Built 8 domain repositories with 131 parameterized database calls
- Created 7 service layers and require_auth middleware
- Eliminated 1,226-line database-functions.R god file
- Migrated OMIM from genemap2 to mim2gene.txt + JAX API + MONDO
- Achieved 0 lintr issues (from 1,240) and 0 TODO comments (from 29)

**Stats:**

- 23,552 lines of R code
- 7 phases, 42 plans
- 167 commits
- 83 files modified (+11,417/-3,822 lines)
- 2 days (2026-01-23 → 2026-01-24)

**Git range:** `docs(18): create phase plan` → `docs(24): complete Versioning, Pagination & Cleanup phase`

**What's next:** CI/CD pipeline (GitHub Actions), Trivy security scanning, expanded frontend test coverage

---

## v3 Frontend Modernization (Shipped: 2026-01-23)

**Delivered:** Complete frontend modernization from Vue 2 + JavaScript to Vue 3 + TypeScript with Bootstrap-Vue-Next, including Vite build tooling and WCAG 2.2 accessibility compliance.

**Phases completed:** 10-17 (53 plans total)

**Key accomplishments:**

- Vue 3.5.25 running in pure mode (no compat layer)
- TypeScript 5.9.3 with branded domain types (GeneId, EntityId)
- Bootstrap-Vue-Next 0.42.0 with Bootstrap 5.3.8
- Vite 7.3.1 with 164ms dev startup (vs ~30s webpack)
- All 7 mixins converted to Vue 3 composables
- Vitest testing infrastructure with 144 example tests
- WCAG 2.2 AA compliance (Lighthouse Accessibility 100)
- Modern UI design system with CSS custom properties

**Stats:**

- 35,970 lines of Vue/TypeScript/SCSS
- 8 phases, 53 plans
- 271 commits
- 2 days (2026-01-22 → 2026-01-23)

**Bundle:** 520 KB gzipped (74% under 2MB target)

**Git range:** Phase 10 → Phase 17

**What's next:** v4 will focus on CI/CD pipeline, expanded test coverage, and backend improvements

---

## v2 Docker Infrastructure Modernization (Shipped: 2026-01-22)

**Delivered:** Modern Docker infrastructure with Traefik v3.6 reverse proxy, optimized multi-stage builds, security hardening (non-root users), and hot-reload development workflow.

**Phases completed:** 6-9 (8 plans total)

**Key accomplishments:**

- Replaced abandoned dockercloud/haproxy with Traefik v3.6 reverse proxy
- Reduced API build time from 45 min to ~10 min cold / ~2 min warm
- Added multi-stage Dockerfiles with BuildKit cache mounts and ccache
- Implemented non-root users (API uid 1001, App nginx user)
- Created Docker Compose Watch hot-reload development workflow
- Added health checks and resource limits to all containers

**Stats:**

- 48 files created/modified
- 9,436 lines added, 304 deleted
- 4 phases, 8 plans
- 2 days (2026-01-21 to 2026-01-22)

**Git range:** `docs(06): create phase plan` to `docs(09): complete Developer Experience phase`

**What's next:** CI/CD pipeline, Trivy security scanning, integration tests

---

## v1 Developer Experience (Shipped: 2026-01-21)

**Delivered:** Modern developer experience with modular API, comprehensive R testing infrastructure, reproducible environments, and unified Makefile automation.

**Phases completed:** 1-5 (19 plans total)

**Key accomplishments:**

- Completed API modularization: 21 endpoint files, 94 endpoints verified working
- Established testthat test framework with 610 passing tests
- Configured renv for reproducible R environment (277 packages locked)
- Created Docker development workflow with hot-reload and isolated test databases
- Built 163-line Makefile with 13 targets across 5 categories
- Achieved 20.3% unit test coverage (practical maximum for DB/network-coupled code)

**Stats:**

- 103 files created/modified
- 27,053 lines added, 909 deleted
- 5 phases, 19 plans, ~45 tasks
- 2 days (2026-01-20 to 2026-01-21)

**Git range:** `22b91cd` (docs(01): create phase plan) to `bd30405` (docs(05): complete expanded test coverage)

**What's next:** Integration test infrastructure, lint cleanup, frontend tooling fixes

---
