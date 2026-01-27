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

**Phase:** 42 - Constraint Scores & Variant Summaries (IN PROGRESS)
**Plan:** 1 of 3 complete (42-01)
**Status:** External data layer foundation complete
**Progress:** ████▱▱▱▱▱▱ 40% (Phase 42 plan 1/3, 1/7 phases done)

**Last completed:** 42-01 — External data layer (types + composable) (2026-01-27)
**Next step:** Continue Phase 42 execution (Plans 42-02 and 42-03 next).

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 210
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

**Gene Page Redesign (Phase 41):**
- **Foundation components (41-01):**
  - GeneApiData interface: All fields are `string[]` matching R backend `str_split` behavior
  - IdentifierRow component: Reusable label-value rows with copy-to-clipboard and external link buttons
  - ResourceLink component: Card-style external resource links with icon, name, description
  - Empty state pattern: Show "Not available" for missing values rather than hiding rows
  - useToast composable for clipboard feedback following existing SysNDD pattern
- **Gene endpoint bed_hg38 field (41-02):**
  - Added bed_hg38 field to gene API endpoint for chromosome coordinates display
  - Integration tests verify field presence and format (chrN:start-end pattern)
- **Section components (41-03):**
  - GeneHero: Display-only banner with GeneBadge (size="lg"), gene name, chromosome location
  - IdentifierCard: 8 identifier rows (HGNC, Entrez, Ensembl, UniProt, UCSC, CCDS, STRING, MANE Select) with computed external URLs
  - ClinicalResourcesCard: 8 clinical resources in 4 groups (Curation, Disease/Phenotype, Gene Information, Model Organisms)
  - Card pattern: BCard with drop shadow, no border, consistent headers
  - Responsive grid: cols="12" md="6" lg="4" for resource links
- **GeneView.vue Composition API refactor (41-04):**
  - Refactored from 539-line Options API to 140-line Composition API with script setup
  - Component-based layout replaces inline BTable templates (GeneHero + IdentifierCard + ClinicalResourcesCard)
  - Computed properties for all derived data (no direct array access in template)
  - Direct axios import instead of Vue plugin injection for cleaner Composition API code
  - Simple loading state (centered spinner) instead of skeleton screens per CONTEXT.md
  - Responsive grid: cols="12" lg="6" for side-by-side cards on desktop (>=992px)
  - Route watcher for gene-to-gene SPA navigation without full page reload

**External Data Layer (Phase 42-01):**
- **TypeScript interfaces for external API responses:**
  - GnomADConstraints: All constraint fields (pLI, oe_lof with CI, oe_mis, oe_syn, exp/obs counts, z-scores)
  - ClinVarVariant: Clinical significance, HGVS notation (hgvsc/hgvsp), review status (gold_stars), in_gnomad flag
  - ExternalDataResponse: Aggregation endpoint response with sources object and errors map
  - ExternalApiError: RFC 9457 Problem Details format
  - SourceState<T>: Generic per-source state container (loading/error/data)
- **useGeneExternalData composable:**
  - Per-source state isolation: gnomad and clinvar objects with independent loading/error/data refs (COMPOSE-02/03)
  - Plain object with ref properties (not ref of object) for template access pattern
  - Fetches from combined endpoint without auth header (public endpoints per AUTH_ALLOWLIST)
  - Handles partial success (some sources succeed, others fail)
  - Handles found: false as no data (not error)
  - toRef pattern accepts both Ref<string> and plain string
  - No auto-fetch on creation - consumer calls fetchData() explicitly
  - Provides retry() convenience method
- **Data layer foundation for all Phase 42 UI components** - enables graceful degradation (one source fails, others render)

**Constraint & ClinVar Visualization (Phase 42-02):**
- **GeneConstraintCard component:**
  - gnomAD-style constraint table: Category | Expected SNVs | Observed SNVs | Constraint Metrics
  - Three rows: Synonymous, Missense, pLoF (each showing Z-score, o/e ratio, CI bar)
  - pLI embedded in pLoF row (not prominently displayed) following gnomAD pattern
  - LOEUF < 0.6 highlighted in amber (#ffc107) per gnomAD v4 guideline for highly constrained genes
  - Pure CSS/SVG confidence interval bars with scaleOE() helper (0-2 range mapped to 0-100px)
  - ARIA labels on SVG bars for screen reader accessibility
  - External link to gnomAD gene page in card header
- **GeneClinVarCard component:**
  - ACMG 5-class colored badges: Pathogenic (red), Likely Pathogenic (orange #fd7e14), VUS (yellow), Likely Benign (teal #20c997), Benign (green)
  - Total variant count in header: "ClinVar Variants (N)"
  - Handles both underscore and space formats in clinical_significance field
  - External link to NCBI ClinVar gene page
  - ARIA labels on badges for accessibility
- **Independent card error handling:** Each card can show data/error/loading states independently (partial success pattern)
- **No interpretation text:** Researchers interpret constraint scores themselves per CONTEXT.md decision

**Critical Pitfalls to Avoid:**
1. Vue Proxy wrapping of Three.js/WebGL objects - use `markRaw()` or non-reactive variables
2. WebGL context leaks - call `stage.dispose()` in cleanup
3. R/Plumber blocking during external API calls - mitigate with server-side caching
4. D3.js vs Vue DOM ownership conflict - D3 owns SVG element exclusively
5. gnomAD API rate limiting - 24h cache TTL, exponential backoff retry
6. GeneApiData array fields - Always access first element: `geneData[0]?.symbol[0]`

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

**Last session:** 2026-01-27T23:43:02Z
**Stopped at:** Completed 42-01-PLAN.md (External data layer types + composable)
**Next action:** Continue Phase 42 execution (Plans 42-02 and 42-03 next)

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
*Last updated: 2026-01-27 — Phase 42 in progress (1/3 plans complete, plan 42-01)*
