# Project State: SysNDD v8.0

**Last updated:** 2026-01-27
**Current milestone:** v8.0 Gene Page & Genomic Data Integration

---

## Project Reference

**Core Value:** A researcher can view a gene page and immediately understand its constraint metrics, clinical variant landscape, protein domain impact, and 3D structural context — all from a single, well-organized interface.

**Current Focus:** Transform gene detail page with external genomic data integration (gnomAD, UniProt, Ensembl, AlphaFold, MGI/RGD).

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** 40 - Backend External API Layer
**Plan:** 04 of 12 complete (40-01, 40-02, 40-03, 40-04 completed)
**Status:** In Progress
**Progress:** ███▱▱▱▱▱▱▱ 33% (Phase 40 of 46, Plan 4 of 12)

**Current objective:** Build R/Plumber proxy endpoints for gnomAD GraphQL, UniProt REST, Ensembl REST, AlphaFold, and MGI/RGD APIs with server-side caching (cachem), httr2 retry logic with exponential backoff, rate limiting protection, and error isolation.

**Last completed:** 40-04 (external proxy endpoints with aggregation) - 2026-01-27
**Next step:** Continue Phase 40 backend development (plans 40-05 through 40-12).

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 200
- Milestones shipped: 7 (v1-v7)
- Phases completed: 39

**By Milestone:**

| Milestone | Phases | Plans | Shipped |
|-----------|--------|-------|---------|
| v1 Developer Experience | 1-5 | 19 | 2026-01-21 |
| v2 Docker Infrastructure | 6-9 | 8 | 2026-01-22 |
| v3 Frontend Modernization | 10-17 | 53 | 2026-01-23 |
| v4 Backend Overhaul | 18-24 | 42 | 2026-01-24 |
| v5 Analysis Modernization | 25-27 | 16 | 2026-01-25 |
| v6 Admin Panel Modernization | 28-33 | 20 | 2026-01-26 |
| v7 Curation Workflow Modernization | 34-39 | 21 | 2026-01-27 |

**Current Milestone (v8.0):**

| Metric | Current | Notes |
|--------|---------|-------|
| **Backend Tests** | 634 passing | 20.3% coverage, 24 integration tests |
| **Frontend Tests** | 144 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Lintr Issues** | 0 | From 1,240 in v4 |
| **TODO Comments** | 0 | From 29 in v4 |
| **ESLint Issues** | 0 | 240 errors fixed in v7 |
| **Bundle Size** | ~600 KB gzipped | Vite 7.3.1, 164ms dev startup |
| **Docker Build** | ~10 min cold, ~2 min warm | BuildKit cache + ccache |

---

## Accumulated Context

### Milestone v8.0 Architecture Decisions

**Backend Proxy Layer (Phase 40):**
- **Single unified endpoint file** (`external_genomic_endpoints.R`) with per-source function modules
- **httr2** for GraphQL (gnomAD) and REST calls (UniProt/Ensembl/AlphaFold/MGI/RGD)
- **memoise + cachem** for disk-based caching with per-source TTL:
  - cache_static (30d): gnomAD constraints, AlphaFold structures
  - cache_dynamic (7d): gnomAD ClinVar variants
  - cache_stable (14d): UniProt domains, Ensembl structure, MGI/RGD phenotypes
- **GraphQL pattern (gnomAD):** httr2 POST with JSON body (query + variables), no ghql dependency
- **Two-step lookup pattern (REST APIs):** Gene symbol → service-specific ID → detailed data
  - UniProt: symbol → accession → features
  - Ensembl: symbol → gene_id → structure with canonical transcript
  - AlphaFold: symbol → UniProt accession → structure metadata
- **Defensive error handling** for undocumented APIs (MGI, RGD): structured not-found responses instead of crashes
- **Combined aggregation endpoint** `/api/external/gene/<symbol>` fetches all sources in parallel with error isolation
- **Plumber endpoint pattern** (40-04): validation → fetch → error handling → success
- **Error isolation pattern:** tryCatch per source, partial success returns 200 with available data
- **Public access:** All external proxy endpoints in AUTH_ALLOWLIST (GET endpoints already public per middleware)

**Frontend Visualization Stack:**
- **D3.js v7.4.2** for protein domain lollipop plot (already in project)
- **Mol* v5.5.0** for 3D structure viewer (NGL.js deprecated by RCSB June 2024)
- **Vue 3 reactivity patterns:** Non-reactive instances (`let viewer`, not `ref()`) + `markRaw()` for WebGL libraries
- **Cleanup pattern:** Explicit disposal in `onBeforeUnmount()` (Cytoscape `cy.destroy()` pattern reused)

**Critical Pitfalls to Avoid:**
1. Vue Proxy wrapping of Three.js/WebGL objects - use `markRaw()` or non-reactive variables
2. WebGL context leaks - call `stage.dispose()` in cleanup
3. R/Plumber blocking during external API calls - mitigate with server-side caching
4. D3.js vs Vue DOM ownership conflict - D3 owns SVG element exclusively
5. gnomAD API rate limiting - 24h cache TTL, exponential backoff retry

### Roadmap Evolution

**v8.0 Phases:**
- Phase 40: Backend External API Layer (12 requirements)
- Phase 41: Gene Page Redesign (10 requirements)
- Phase 42: Constraint Scores & Variant Summaries (13 requirements)
- Phase 43: Protein Domain Lollipop Plot (11 requirements)
- Phase 44: Gene Structure Visualization (4 requirements)
- Phase 45: 3D Protein Structure Viewer (9 requirements)
- Phase 46: Model Organism Phenotypes & Final Integration (5 requirements)

**Total:** 64 requirements across 7 phases

### Pending Todos

- [ ] Phase 40: Backend External API Layer (12 requirements)
- [ ] Phase 41: Gene Page Redesign (10 requirements)
- [ ] Phase 42: Constraint Scores & Variant Summaries (13 requirements)
- [ ] Phase 43: Protein Domain Lollipop Plot (11 requirements)
- [ ] Phase 44: Gene Structure Visualization (4 requirements)
- [ ] Phase 45: 3D Protein Structure Viewer (9 requirements)
- [ ] Phase 46: Model Organism Phenotypes & Final Integration (5 requirements)

### Blockers/Concerns

**None** - Research phase completed, roadmap approved, ready to start Phase 40 planning.

---

## Session Continuity

**Last session:** 2026-01-27
**Stopped at:** Completed 40-04 plan execution (external proxy endpoints)
**Next action:** Continue Phase 40 backend development

**Handoff notes:**

1. **Milestone v8.0 initialized** (2026-01-27): Requirements defined (57 v1 requirements), research completed (HIGH confidence), roadmap created (7 phases starting at Phase 40).

2. **Phase structure follows dependency chain:**
   - Phase 40 (Backend) → all frontend features
   - Phase 41 (Redesign) can parallel Phase 40
   - Phase 42 (Constraints) → Phase 43 (Lollipop) → Phase 45 (3D Viewer)
   - Phase 44 (Gene Structure) independent
   - Phase 46 (Phenotypes) final integration

3. **Research flags (deeper investigation during planning):**
   - Phase 43: HGVS protein notation parsing, D3.js performance for >100 variants
   - Phase 45: Mol* selection API for variant highlighting, code splitting for 74MB bundle

4. **Reusable patterns from existing codebase:**
   - Cytoscape.js cleanup pattern (non-reactive instance + explicit destroy) applies to D3 and Mol*
   - httr2 retry logic in `omim-functions.R` applies to all external APIs
   - memoise caching in `analyses-functions.R` applies to external API proxy
   - Module-level caching pattern prevents duplicate API calls

---

*State initialized: 2026-01-20*
*Last updated: 2026-01-27 - v8.0 roadmap created*
