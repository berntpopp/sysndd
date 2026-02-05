# Roadmap: SysNDD v10.3 Bug Fixes & Stabilization

## Milestones

- ✅ **v1.0 Developer Experience** - Phases 1-5 (shipped 2026-01-21)
- ✅ **v2.0 Docker Infrastructure** - Phases 6-9 (shipped 2026-01-22)
- ✅ **v3.0 Frontend Modernization** - Phases 10-17 (shipped 2026-01-23)
- ✅ **v4.0 Backend Overhaul** - Phases 18-24 (shipped 2026-01-24)
- ✅ **v5.0 Analysis Modernization** - Phases 25-27 (shipped 2026-01-25)
- ✅ **v6.0 Admin Panel** - Phases 28-33 (shipped 2026-01-26)
- ✅ **v7.0 Curation Workflows** - Phases 34-39 (shipped 2026-01-27)
- ✅ **v8.0 Gene Page** - Phases 40-46 (shipped 2026-01-29)
- ✅ **v9.0 Production Readiness** - Phases 47-54 (shipped 2026-01-31)
- ✅ **v10.0 Data Quality & AI Insights** - Phases 55-65 (shipped 2026-02-01)
- ✅ **v10.1 Production Deployment Fixes** - Phases 66-68 (shipped 2026-02-03)
- ✅ **v10.2 Performance & Memory Optimization** - Phases 69-72 (shipped 2026-02-03)
- 🚧 **v10.3 Bug Fixes & Stabilization** - Phases 73-75 (in progress)

## Phases

<details>
<summary>✅ v1.0 through v10.2 (Phases 1-72) - See MILESTONES.md</summary>

Phases 1-72 delivered across milestones v1.0 through v10.2. See `.planning/MILESTONES.md` for full history.

</details>

### 🚧 v10.3 Bug Fixes & Stabilization (In Progress)

**Milestone Goal:** Fix 10 open bugs and UX issues to stabilize the production deployment after v10.0-v10.2 feature work.

- [x] **Phase 73: Data Infrastructure & Cache Fixes** - Database migrations and cache invalidation
- [x] **Phase 74: API Bug Fixes** - Fix three independent 500 errors in API endpoints
- [ ] **Phase 75: Frontend Fixes & UX Improvements** - Documentation links, column stats, phenotype selection, layout

## Phase Details

### Phase 73: Data Infrastructure & Cache Fixes
**Goal**: Database schema and external data sources are correct, and cached data stays fresh after code changes
**Depends on**: Nothing (first phase of v10.3)
**Requirements**: DATA-01, DATA-02, DATA-03
**Success Criteria** (what must be TRUE):
  1. Comparisons Data Refresh job completes without column truncation errors (columns wide enough for all external source data)
  2. Gene2Phenotype download fetches data from the new API URL and correctly parses the updated file format
  3. After a code deployment that changes cached data structures, GeneNetworks table and LLM summaries display correctly (stale memoisation cache does not serve outdated formats)
  4. All three database migrations are idempotent (can be re-run without error)
**Plans:** 2 plans
Plans:
- [x] 73-01-PLAN.md -- Database migrations: widen comparison columns (DATA-01) and update Gene2Phenotype URL (DATA-02)
- [x] 73-02-PLAN.md -- Cache versioning: CACHE_VERSION env var for automatic invalidation on deployment (DATA-03)

### Phase 74: API Bug Fixes
**Goal**: API endpoints that currently return 500 errors respond correctly for all valid inputs
**Depends on**: Phase 73 (data layer must be stable before fixing API endpoints that read from it)
**Requirements**: API-01, API-02, API-03
**Success Criteria** (what must be TRUE):
  1. Creating a new entity with direct approval (skipping separate review step) succeeds and returns the new entity without a 500 error
  2. The Panels page loads successfully, displaying all panel data with correctly aliased columns matching the query result set
  3. Clustering endpoints return a valid empty response (not a 500 error) when called for gene sets that produce zero STRING interactions (empty tibble in rowwise context)
**Plans:** 3 plans
Plans:
- [x] 74-01-PLAN.md -- Fix direct approval entity creation 500 error (API-01, #166)
- [x] 74-02-PLAN.md -- Fix Panels page column alias mismatch (API-02, #161)
- [x] 74-03-PLAN.md -- Fix clustering empty tibble crash and scan all rowwise patterns (API-03, #155)

### Phase 75: Frontend Fixes & UX Improvements
**Goal**: Frontend displays correct information and provides a smooth user experience for entity creation and gene browsing
**Depends on**: Phase 74 (API fixes ensure backend returns correct data for frontend to display)
**Requirements**: FE-01, FE-02, UX-01, UX-02
**Success Criteria** (what must be TRUE):
  1. Documentation links in the application navigate to the correct numbered-prefix URLs on GitHub Pages (no 404 errors)
  2. Hovering over table column headers displays statistics and metadata tooltips (restored from previous behavior)
  3. Create Entity step 3 uses the same TreeMultiSelect phenotype component as ModifyEntity, providing consistent search, hierarchy navigation, and multi-select behavior
  4. On the Genes detail view, the Associated Entities section appears above the Constraint Scores and ClinVar sections in the page layout
**Plans**: TBD

## Progress

**Execution Order:** 73 → 74 → 75

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 73. Data Infrastructure & Cache Fixes | v10.3 | 2/2 | ✓ Complete | 2026-02-05 |
| 74. API Bug Fixes | v10.3 | 3/3 | ✓ Complete | 2026-02-05 |
| 75. Frontend Fixes & UX Improvements | v10.3 | 0/TBD | Not started | - |

---
*Roadmap created: 2026-02-05*
*Last updated: 2026-02-05 -- Phase 74 complete (3/3 plans, verified)*
