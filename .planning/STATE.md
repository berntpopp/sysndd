# Project State: SysNDD v8.0

**Last updated:** 2026-01-28
**Current milestone:** v8.0 Gene Page & Genomic Data Integration

---

## Project Reference

**Core Value:** A researcher can view a gene page and immediately understand its constraint metrics, clinical variant landscape, protein domain impact, and 3D structural context — all from a single, well-organized interface.

**Current Focus:** Transform gene detail page with external genomic data integration (gnomAD, UniProt, Ensembl, AlphaFold, MGI/RGD).

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** 43 - Protein Domain Lollipop Plot (IN PROGRESS)
**Plan:** 2 of 3 complete
**Status:** In progress — types, D3 composable, and plot component created
**Progress:** █████▓▱▱▱▱ 56% (Phase 43 plan 2 complete, 3/7 phases in progress)

**Last completed:** 43-02 — ProteinDomainLollipopPlot Vue component (2026-01-28)
**Next step:** Execute 43-03 (Card wrapper and GeneView integration).

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

**HGNC gnomAD Enrichment Infrastructure (2026-01-28):**
- **Bulk TSV approach** instead of per-gene API calls: Downloads gnomAD v4.1 constraint_metrics.tsv (~10MB) once, filters for MANE Select transcripts, joins by gene symbol
- **Performance:** Completes in seconds vs. ~73 hours for the per-gene API approach
- **Database columns added:**
  - `gnomad_constraints` (TEXT): JSON blob with pLI, LOEUF, o/e ratios, Z-scores, expected/observed counts
  - `alphafold_id` (VARCHAR(100)): Pre-computed AlphaFold model identifier (AF-{uniprot_id}-F1)
- **File-based job progress:** Daemon processes write throttled progress to /tmp/sysndd_jobs/{job_id}.json; main process reads during status polling
- **Column schema fixes:** Migration 003 handles HGNC upstream schema changes (rna_central_ids→rna_central_id rename, VARCHAR widths)

**Protein Domain Lollipop Plot Foundation (Phase 43-01):**
- **TypeScript interfaces (app/src/types/protein.ts):**
  - PathogenicityClass: Union type for ACMG 5-class + 'other'
  - ProteinDomain: Maps UniProt features API response (type, description, begin, end)
  - ProcessedVariant: Processed ClinVar variant with proteinPosition, classification, splice flag
  - ProteinPlotData: Aggregated domains + variants + protein metadata
  - LollipopFilterState: Boolean visibility flags per pathogenicity class
  - PATHOGENICITY_COLORS: ACMG-consistent color palette (red spectrum pathogenic, green spectrum benign)
- **Helper functions:**
  - normalizeClassification(): Handles gnomAD underscore format, combined classifications (Pathogenic/Likely_pathogenic -> Pathogenic)
  - parseProteinPosition(): Extracts AA position from hgvsp (preferred) or hgvsc (fallback with codon calculation)
- **useD3Lollipop composable (app/src/composables/useD3Lollipop.ts):**
  - Non-reactive D3 state (let svg, not ref) following useCytoscape pattern
  - D3 join pattern for enter/update/exit rendering
  - Brush-to-zoom with double-click reset
  - Tooltip with viewport edge detection
  - Variant stacking by position using d3.group()
  - d3.symbolCircle for coding variants, d3.symbolDiamond for splice variants
  - onBeforeUnmount cleanup for memory leak prevention
  - onVariantClick/onVariantHover callbacks for Phase 45 3D viewer linking

**Critical Pitfalls to Avoid:**
1. Vue Proxy wrapping of Three.js/WebGL objects - use `markRaw()` or non-reactive variables
2. WebGL context leaks - call `stage.dispose()` in cleanup
3. R/Plumber blocking during external API calls - mitigate with server-side caching
4. D3.js vs Vue DOM ownership conflict - D3 owns SVG element exclusively
5. gnomAD API rate limiting - 24h cache TTL, exponential backoff retry
6. GeneApiData array fields - Always access first element: `geneData[0]?.symbol[0]`
7. JSON column pipe-split: `gnomad_constraints` column should be excluded from str_split transformation (see backlog)
8. D3 `this` typing in TypeScript - Use attr callbacks with arrow functions instead of `.each(function(d))`

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
- [x] Phase 42: Constraint Scores & Variant Summaries (13 requirements) ✓
- [ ] Phase 43: Protein Domain Lollipop Plot (11 requirements)
- [ ] Phase 44: Gene Structure Visualization (4 requirements)
- [ ] Phase 45: 3D Protein Structure Viewer (9 requirements)
- [ ] Phase 46: Model Organism Phenotypes & Final Integration (5 requirements)

### Blockers/Concerns

**None** - Phases 40 and 42 complete. Ready for Phase 43 or 44.

---

## Session Continuity

**Last session:** 2026-01-28T21:35:05Z
**Stopped at:** Phase 43-02 complete — ProteinDomainLollipopPlot Vue component
**Next action:** Execute 43-03 (Card wrapper and GeneView integration)

**Handoff notes:**

1. **Phase 43-02 completed** (2026-01-28): Vue 3 SFC wrapping useD3Lollipop composable.

2. **Phase 43-02 deliverables:**
   - `app/src/components/gene/ProteinDomainLollipopPlot.vue` — Vue 3 SFC (360 lines) with D3 integration, reactive legend filters, domain color legend

3. **Phase 43-01 completed** (2026-01-28): Types and D3 composable for lollipop plot visualization.
   - `app/src/types/protein.ts` — TypeScript interfaces, PATHOGENICITY_COLORS, helper functions
   - `app/src/composables/useD3Lollipop.ts` — D3 lifecycle composable with brush-to-zoom, tooltip, variant stacking

4. **Phase 42 completed** (2026-01-28): All 3 plans executed. GeneView now displays gnomAD constraint cards and ClinVar variant summary cards with independent loading states.

5. **Backlog items captured:**
   - `fix-pipe-split-on-json-column.md` — Medium priority JSON column handling
   - `make-migration-002-idempotent.md` — Low priority migration robustness
   - `optimize-ensembl-biomart-connections.md` — High priority performance issue

6. **Phase 44 context gathered** (2026-01-28): Gene structure visualization requirements documented

---

*State initialized: 2026-01-20*
*Last updated: 2026-01-28 — Phase 43-02 complete (ProteinDomainLollipopPlot Vue component)*
