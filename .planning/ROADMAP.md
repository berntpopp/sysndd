# Roadmap: SysNDD v5.0 Analysis Modernization

## Overview

The v5.0 Analysis Modernization milestone transforms SysNDD's analysis pages from basic D3.js bubble charts to sophisticated interactive network visualizations with optimized backend clustering performance. This roadmap delivers in three sequential phases: backend performance optimization (Phase 25), core network visualization with Cytoscape.js (Phase 26), and advanced features including wildcard search, filters, and bidirectional navigation (Phase 27). The journey achieves 50-65% reduction in cold start time (15s to 5-7s), replaces bubble charts with true protein-protein interaction networks, and establishes differentiating features like click-cluster-to-filter-table workflows that distinguish SysNDD from competitors.

## Milestones

- ✅ **v1.0 Developer Experience** - Phases 1-5 (shipped 2026-01-21)
- ✅ **v2.0 Docker Infrastructure** - Phases 6-9 (shipped 2026-01-22)
- ✅ **v3.0 Frontend Modernization** - Phases 10-17 (shipped 2026-01-23)
- ✅ **v4.0 Backend Overhaul** - Phases 18-24 (shipped 2026-01-24)
- 🚧 **v5.0 Analysis Modernization** - Phases 25-27 (in progress)

## Phases

**Phase Numbering:**
- Integer phases (25, 26, 27): Planned milestone work
- Decimal phases (25.1, 25.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 25: Performance Optimization** - Backend infrastructure for fast clustering and caching
- [x] **Phase 26: Network Visualization** - Cytoscape.js integration with PPI edges and composables
- [ ] **Phase 27: Advanced Features & Filters** - Search, filters, navigation, and UI polish

## Phase Details

<details>
<summary>✅ v1.0 Developer Experience (Phases 1-5) - SHIPPED 2026-01-21</summary>

**Key accomplishments:**
- Completed API modularization: 21 endpoint files, 94 endpoints verified working
- Established testthat test framework with 610 passing tests
- Configured renv for reproducible R environment (277 packages locked)
- Created Docker development workflow with hot-reload and isolated test databases
- Built 163-line Makefile with 13 targets across 5 categories
- Achieved 20.3% unit test coverage

**Stats:** 103 files created/modified, 27,053 lines added, 5 phases, 19 plans

</details>

<details>
<summary>✅ v2.0 Docker Infrastructure (Phases 6-9) - SHIPPED 2026-01-22</summary>

**Key accomplishments:**
- Replaced abandoned dockercloud/haproxy with Traefik v3.6 reverse proxy
- Reduced API build time from 45 min to ~10 min cold / ~2 min warm
- Added multi-stage Dockerfiles with BuildKit cache mounts and ccache
- Implemented non-root users (API uid 1001, App nginx user)
- Created Docker Compose Watch hot-reload development workflow
- Added health checks and resource limits to all containers

**Stats:** 48 files created/modified, 9,436 lines added, 4 phases, 8 plans

</details>

<details>
<summary>✅ v3.0 Frontend Modernization (Phases 10-17) - SHIPPED 2026-01-23</summary>

**Key accomplishments:**
- Vue 3.5.25 running in pure mode (no compat layer)
- TypeScript 5.9.3 with branded domain types (GeneId, EntityId)
- Bootstrap-Vue-Next 0.42.0 with Bootstrap 5.3.8
- Vite 7.3.1 with 164ms dev startup (vs ~30s webpack)
- All 7 mixins converted to Vue 3 composables
- Vitest testing infrastructure with 144 example tests
- WCAG 2.2 AA compliance (Lighthouse Accessibility 100)

**Stats:** 35,970 lines of Vue/TypeScript/SCSS, 8 phases, 53 plans

</details>

<details>
<summary>✅ v4.0 Backend Overhaul (Phases 18-24) - SHIPPED 2026-01-24</summary>

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

**Stats:** 23,552 lines of R code, 7 phases, 42 plans

</details>

### 🚧 v5.0 Analysis Modernization (In Progress)

**Milestone Goal:** Transform analysis pages into fast, interconnected, modern visualization experience with true network graphs and professional UI/UX

### Phase 25: Performance Optimization

**Goal:** Optimize backend clustering infrastructure for 50-65% cold start reduction (15s to 5-7s) with Leiden algorithm, HCPC pre-partitioning, cache versioning, and pagination

**Depends on:** Phase 24 (v4 complete)

**Requirements:** PERF-01, PERF-02, PERF-03, PERF-04, PERF-05, PERF-06, PERF-07

**Success Criteria** (what must be TRUE):
1. Clustering completes in under 7 seconds for typical gene sets (200+ genes)
2. Cache keys include algorithm name and STRING version, preventing stale results
3. Functional clustering endpoint returns paginated responses (10-20 clusters per page) instead of 8.6MB single response
4. Timeout handling works correctly without exhausting mirai worker pool
5. MCA uses 8 dimensions (reduced from 15) with maintained analysis quality

**Plans:** 3 plans

Plans:
- [x] 25-01-PLAN.md — Cache key versioning + Leiden algorithm migration (PERF-01, PERF-04)
- [x] 25-02-PLAN.md — Pagination infrastructure for functional_clustering (PERF-05)
- [x] 25-03-PLAN.md — HCPC pre-partitioning (kk=50) + MCA dimension reduction (ncp=8) + performance monitoring (PERF-02, PERF-03, PERF-06)

### Phase 26: Network Visualization

**Goal:** Deliver true protein-protein interaction network visualization using Cytoscape.js with force-directed layout, interactive controls, and proper Vue 3 lifecycle management

**Depends on:** Phase 25

**Requirements:** NETV-01, NETV-02, NETV-03, NETV-04, NETV-05, NETV-06, NETV-07, NETV-08, NETV-09, NETV-10, NETV-11

**Success Criteria** (what must be TRUE):
1. Network displays actual protein-protein interaction edges (not just gene bubbles)
2. User can pan, zoom, and interact with network using force-directed layout
3. Hovering over nodes/edges highlights connections with rich contextual tooltips
4. Clicking a node navigates to entity detail page maintaining existing integration
5. Network component cleans up properly on navigation (no memory leaks from 100-300MB Cytoscape instances)

**Plans:** 3 plans

Plans:
- [x] 26-01-PLAN.md — Backend network_edges endpoint + TypeScript types (NETV-01, NETV-03)
- [x] 26-02-PLAN.md — useCytoscape + useNetworkData composables (NETV-08, NETV-09, NETV-10, NETV-11)
- [x] 26-03-PLAN.md — NetworkVisualization component + AnalyseGeneClusters integration (NETV-02, NETV-04, NETV-05, NETV-06, NETV-07)

### Phase 27: Advanced Features & Filters

**Goal:** Establish competitive differentiators through wildcard gene search, comprehensive filters, bidirectional network-table navigation, and UI polish

**Depends on:** Phase 26

**Requirements:** FILT-01, FILT-02, FILT-03, FILT-04, FILT-05, FILT-06, FILT-07, FILT-08, NAVL-01, NAVL-02, NAVL-03, NAVL-04, NAVL-05, NAVL-06, NAVL-07, UIUX-01, UIUX-02, UIUX-03, UIUX-04, UIUX-05

**Success Criteria** (what must be TRUE):
1. User can search genes with wildcard patterns (PKD*, BRCA?) matching biologist mental models
2. Network highlights matching nodes from search query
3. Data tables provide column-level text filters, numeric range filters (FDR < 0.05), and dropdown categorical filters
4. Clicking a cluster in correlation heatmap navigates to corresponding phenotype cluster view
5. Filter state persists in URL for bookmarkable/shareable analysis views
6. Navigation tabs connect all analysis pages (Phenotype Clusters, Gene Networks, Correlation)

**Plans:** 5 plans

Plans:
- [ ] 27-01-PLAN.md — Core composables: useFilterSync, useWildcardSearch, useNetworkHighlight (NAVL-06)
- [ ] 27-02-PLAN.md — Reusable filter components: CategoryFilter, ScoreSlider, TermSearch (FILT-06, FILT-07, FILT-08)
- [ ] 27-03-PLAN.md — Navigation tabs + AnalysisView + router + bug fix (NAVL-01, NAVL-03, NAVL-04, NAVL-07)
- [ ] 27-04-PLAN.md — Search highlighting + heatmap navigation + bidirectional hover (FILT-04, FILT-05, NAVL-02, NAVL-05)
- [ ] 27-05-PLAN.md — UI polish: ColorLegend, enhanced tooltips, loading/error states (UIUX-01 through UIUX-05)

## Progress

**Execution Order:**
Phases execute in numeric order: 25 → 26 → 27

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 25. Performance Optimization | 3/3 | ✓ Complete | 2026-01-25 |
| 26. Network Visualization | 3/3 | ✓ Complete | 2026-01-25 |
| 27. Advanced Features & Filters | 0/5 | Ready for execution | - |

---
*Roadmap created: 2026-01-24*
*Last updated: 2026-01-25 — Phase 26 complete (3/3 plans, verified)*
