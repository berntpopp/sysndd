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

**Phase:** 41 - Gene Page Redesign (IN PROGRESS)
**Plan:** 1/5 complete (41-02)
**Status:** In progress
**Progress:** █▱▱▱▱▱▱▱▱▱ 14% (41 in progress of 46 total, plan 41-02 complete)

**Last completed:** 41-02 — Added bed_hg38 field to gene endpoint (2026-01-27)
**Next step:** Continue executing phase 41 plans.

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 205
- Milestones shipped: 7 (v1-v7)
- Phases completed: 40

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
- **Test coverage (40-05):** Mock-based unit tests for infrastructure (validation, error format, caching, throttle) and error isolation without network calls

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

- [x] Phase 40: Backend External API Layer (12 requirements) ✓
- [ ] Phase 41: Gene Page Redesign (10 requirements)
- [ ] Phase 42: Constraint Scores & Variant Summaries (13 requirements)
- [ ] Phase 43: Protein Domain Lollipop Plot (11 requirements)
- [ ] Phase 44: Gene Structure Visualization (4 requirements)
- [ ] Phase 45: 3D Protein Structure Viewer (9 requirements)
- [ ] Phase 46: Model Organism Phenotypes & Final Integration (5 requirements)

### Blockers/Concerns

**None** - Phase 40 complete and verified. Ready for Phase 41.

---

## Session Continuity

**Last session:** 2026-01-27T20:45:52Z
**Stopped at:** Completed 41-02-PLAN.md (Gene endpoint bed_hg38 field)
**Next action:** Continue phase 41 execution

**Handoff notes:**

1. **Phase 40 completed** (2026-01-27): All 5 plans executed, 12/12 requirements verified. Backend proxy layer operational with 8 Plumber endpoints, 6 external API sources, 3-tier caching, error isolation.

2. **Phase 40 deliverables:**
   - `api/functions/external-proxy-functions.R` — shared infrastructure (cache, retry, throttle, error format)
   - `api/functions/external-proxy-gnomad.R` — GraphQL proxy for constraints + ClinVar
   - `api/functions/external-proxy-uniprot.R` — REST proxy for protein domains
   - `api/functions/external-proxy-ensembl.R` — REST proxy for gene structure
   - `api/functions/external-proxy-alphafold.R` — REST proxy for 3D structure metadata
   - `api/functions/external-proxy-mgi.R` — REST proxy for mouse phenotypes
   - `api/functions/external-proxy-rgd.R` — REST proxy for rat phenotypes
   - `api/endpoints/external_endpoints.R` — 8 Plumber endpoints (7 per-source + 1 aggregation)
   - 34 unit tests covering infrastructure and error isolation

3. **Phase structure follows dependency chain:**
   - Phase 40 (Backend) ✓ → all frontend features unblocked
   - Phase 41 (Redesign) can start immediately (no dependencies)
   - Phase 42 (Constraints) → Phase 43 (Lollipop) → Phase 45 (3D Viewer)
   - Phase 44 (Gene Structure) independent
   - Phase 46 (Phenotypes) final integration

4. **Research flags (deeper investigation during planning):**
   - Phase 43: HGVS protein notation parsing, D3.js performance for >100 variants
   - Phase 45: Mol* selection API for variant highlighting, code splitting for 74MB bundle

---

*State initialized: 2026-01-20*
*Last updated: 2026-01-27 — Phase 40 complete*
