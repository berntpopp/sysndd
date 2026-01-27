# Project Research Summary

**Project:** SysNDD v8.0 Gene Page & Genomic Data Integration
**Domain:** Clinical genetics database - gene detail page enhancement with external genomic data sources
**Researched:** 2026-01-27
**Confidence:** HIGH

## Executive Summary

Modern gene detail pages in clinical genetics databases serve as decision-support tools requiring integration of constraint scores (gnomAD), clinical variant data (ClinVar), protein structure visualization (AlphaFold), and model organism phenotypes (MGI/RGD). Research across competitive examples (gnomAD, DECIPHER, ClinGen, UniProt) reveals a clear industry shift toward card-based layouts with interactive visualizations, where constraint scores and variant summaries are now baseline expectations rather than differentiators.

The recommended approach leverages SysNDD's existing validated stack (Vue 3.5.25 + TypeScript, R 4.4.3 with Plumber, httr2, memoise) by adding two critical components: (1) **Mol* v5.5.0** for 3D protein structure visualization (NGL.js was deprecated by RCSB.org in June 2024), and (2) **ghql v0.1.2** for GraphQL queries to gnomAD v4.1 API. All external API calls route through R/Plumber backend with server-side caching (24h-90d TTL based on data volatility) to mitigate gnomAD's strict rate limits (~10 queries before blocking). D3.js v7.4.2 is already in the project for lollipop plot visualizations.

Key risks center on **Vue 3 reactivity conflicts with WebGL libraries** (Mol* uses Three.js internally - requires `markRaw()` pattern to prevent Proxy wrapping), **memory leaks from improper WebGL cleanup** (100-300MB per navigation without `stage.dispose()`), and **R/Plumber blocking during external API calls** (1-3 second gnomAD queries block entire Plumber instance). The existing codebase demonstrates correct mitigation patterns: Cytoscape.js uses non-reactive instance variables and explicit `destroy()` in cleanup, httr2 retry logic with exponential backoff, and memoise disk-based caching. The critical success factor is **consistent application** of these proven patterns to new integration points.

## Key Findings

### Recommended Stack

**Critical Decision: Mol* over NGL.js** - RCSB.org deprecated NGL.js viewer on June 28, 2024, recommending full transition to Mol*. While Mol* has a larger bundle size (74.4 MB vs 23 MB), it offers superior AlphaFold support, active maintenance (v5.5.0 released January 2026), and is the official viewer for PDBe, RCSB PDB, and AlphaFold DB. NGL.js is in maintenance mode (last release April 2024, 9+ months ago).

**Core technologies:**
- **Mol* v5.5.0**: 3D protein structure visualization - industry standard, native AlphaFold support, specialized mutation visualization capabilities, bundle size mitigated via code splitting
- **ghql v0.1.2**: GraphQL client for R - CRAN package, active maintenance (Sept 2025), designed for parameterized queries, rOpenSci maintained
- **D3.js v7.4.2**: Lollipop plot visualization - already in project, no new dependency, well-documented Vue 3 Composition API integration patterns
- **httr2**: REST API client - already in project, used for UniProt/Ensembl/AlphaFold/MGI endpoints
- **memoise + cachem**: Server-side caching - already in project, critical for gnomAD rate limit mitigation

**New Dependencies:**
- Frontend: `npm install molstar@5.5.0`
- Backend: `install.packages("ghql")`

**Bundle Impact:** +74.4 MB (Mol* only) - acceptable for specialized feature, load via lazy import only on gene pages with 3D structures.

### Expected Features

Research of competitive examples reveals clear feature categorization for clinical genetics gene pages:

**Must have (table stakes):**
- **TS-1: Hero section with core gene identity** - gnomAD, DECIPHER, ClinGen all use prominent above-the-fold sections; users need immediate gene confirmation
- **TS-2: gnomAD constraint scores (pLI, LOEUF, mis_z)** - pLI ≥ 0.9 is standard haploinsufficiency threshold; ClinGen explicitly recommends in gene-disease curation; used in every clinical variant interpretation workflow
- **TS-3: ClinVar variant summary** - aggregate counts by clinical significance (P/LP/VUS/Benign); standard clinical question "how many pathogenic variants exist?"
- **TS-4: Logical grouping of external links** - current flat table of 11 links creates cognitive load; card-based grouping (Clinical Resources, Sequence Databases, Model Organisms) is now standard
- **TS-5: Protein domain lollipop plot** - standard visualization in gnomAD, ClinGen, DECIPHER; reveals variant clustering patterns critical for ACMG PS1 criterion
- **TS-6: Empty state handling** - graceful "Not available" messages, independent loading states per card, prevents silent failures

**Should have (competitive differentiators):**
- **DIFF-1: Model organism phenotype summaries with NDD relevance** - most databases only show MGI/RGD links; filtering neuronal/behavioral phenotypes (MP ontology) saves time for NDD researchers
- **DIFF-2: 3D AlphaFold structure viewer with variant highlighting** - most gene pages link to AlphaFold DB but don't embed viewer; removes navigation friction; spatial variant clustering not visible in 1D lollipop
- **DIFF-3: SysNDD curation summary** - showcase internal gene-disease associations with metadata (inheritance, confidence, review status); other databases don't show internal curation prominently
- **DIFF-4: Genomic lollipop plot (exon structure)** - protein lollipop doesn't show splice variants, UTRs, or intronic variants; complements protein view for complete picture

**Defer (v2+):**
- AlphaMissense pathogenicity score integration (AlphaFold 2025 redesign feature)
- Custom variant upload for structure highlighting
- Cache warming admin endpoint

### Architecture Approach

**Single unified backend endpoint file** (`external_genomic_endpoints.R`) with per-source function modules, using established httr2 retry logic, disk-based caching with TTL policies (7d gnomAD, 30d UniProt, 90d Ensembl/AlphaFold), and composable-driven frontend. All five external data sources (gnomAD, UniProt, Ensembl, AlphaFold, MGI) share common concerns - rate limiting, caching, error handling, graceful degradation - making single-file organization with modular functions the optimal pattern.

**Major components:**

1. **Backend API proxy layer** - R/Plumber endpoints wrap external APIs with caching (memoise + cachem), retry logic (httr2 exponential backoff), and rate limiting (req_throttle). Pattern: one function module per source (`gnomad-functions.R`, `uniprot-functions.R`, etc.) called by unified `external_genomic_endpoints.R`.

2. **Combined aggregation endpoint** - `/api/external/gene/<symbol>` fetches all sources in parallel with error isolation (one source failure doesn't block others), returns partial data structure enabling independent card rendering. Frontend composable (`useGeneExternalData.ts`) coordinates single request.

3. **Frontend visualization components** - Card-based layout with independent loading states. D3.js lollipop plots use non-reactive instance variables (`let svg`, not `ref()`) with Vue lifecycle hooks (onMounted, onBeforeUnmount). Mol* 3D viewer uses `markRaw()` to prevent Vue Proxy wrapping of WebGL objects.

4. **Cache strategy** - Per-source TTL based on data volatility: gnomAD 7d (constraint scores stable), UniProt 30d (protein domains quarterly updates), Ensembl/AlphaFold 90d (structures stable between releases). Disk-based cache survives R session restarts.

5. **Error handling pattern** - Backend returns structured errors per source `{ error: "message", status: "error" }`. Frontend renders available cards, shows `ErrorAlert` for failures, maintains layout consistency with empty states.

### Critical Pitfalls

Research identified three **CRITICAL** (will block) and multiple HIGH/MEDIUM pitfalls. Top 5:

1. **Vue 3 Proxy wrapping of Three.js/WebGL objects** (CRITICAL) - Mol* uses Three.js internally; Vue's reactivity system wrapping these objects triggers 100+ layout recalculations, TypeError on mutations, 2-3 second freeze. **Prevention:** Use `markRaw()` for Mol* viewer instance or store in non-reactive variable (`let viewer`, not `ref()`). Existing Cytoscape.js code demonstrates correct pattern.

2. **WebGL context leaks from missing stage.dispose()** (CRITICAL) - Browsers limit WebGL contexts to 8-16 per page. Without explicit cleanup: 100-300MB memory leak per navigation, "Too many active WebGL contexts" after 10-15 genes. **Prevention:** Call `stage.dispose()` in `onBeforeUnmount()`. Existing Cytoscape.js cleanup (`cy.destroy()`) demonstrates correct pattern.

3. **R/Plumber blocking during external API calls** (CRITICAL) - R is single-threaded; gnomAD/AlphaFold calls take 1-5 seconds and block entire Plumber instance. All other requests queue. **Prevention:** Server-side caching (first call blocks, subsequent calls instant), consider client-side direct API calls for non-sensitive endpoints like gnomAD constraint scores.

4. **D3.js vs Vue DOM ownership conflict** (HIGH) - Both D3 and Vue manipulate DOM; simultaneous updates cause race conditions. **Prevention:** D3 owns SVG element exclusively, Vue never updates that subtree. Use ref for DOM element, non-reactive variable for D3 instance, `watch()` for data-driven re-renders.

5. **gnomAD API rate limiting and IP blocking** (MEDIUM) - Rate limits not documented but confirmed (~10 queries before blocking). **Prevention:** 24h cache TTL ensures single query per gene per day, exponential backoff retry logic, consider whitelisting for production.

## Implications for Roadmap

Based on architectural dependencies, risk mitigation, and MVP prioritization, recommended phase structure:

### Phase 1: Backend External API Layer (Foundation)
**Rationale:** All frontend features depend on backend proxy layer. Must establish caching, rate limiting, and error handling patterns before building visualizations. Backend can be developed and tested independently without frontend changes.

**Delivers:**
- `/api/external/gnomad/<symbol>` endpoint with constraint scores + ClinVar variants
- `/api/external/uniprot/<uniprot_id>` endpoint with protein domains
- `/api/external/ensembl/<ensembl_id>` endpoint with exon structure
- `/api/external/alphafold/<uniprot_id>` endpoint with structure URLs
- `/api/external/mgi/<symbol>` endpoint with phenotypes
- Unified caching strategy with TTL policies
- httr2 retry logic with exponential backoff

**Addresses:**
- TS-2 (gnomAD constraint scores) - data source
- TS-3 (ClinVar variants) - data source
- TS-5 (protein domains) - data source
- DIFF-1 (MGI phenotypes) - data source

**Avoids:**
- Pitfall #3 (R blocking) via caching
- Pitfall #5 (rate limiting) via req_throttle

**Research flag:** Standard patterns (httr2 + memoise already in codebase)

### Phase 2: Gene Page Redesign (UX Foundation)
**Rationale:** Establishes hero section, card-based layout, and logical grouping before adding complex visualizations. Low-complexity features provide immediate UX improvement. Can develop in parallel with Phase 1.

**Delivers:**
- Hero section with gene symbol, identifiers, quick actions (TS-1)
- Grouped external links as cards (TS-4)
- Empty state/loading skeleton components (TS-6)
- SysNDD curation summary card (DIFF-3)

**Addresses:**
- TS-1 (hero section)
- TS-4 (logical grouping)
- TS-6 (empty states)
- DIFF-3 (curation summary)

**Avoids:**
- Pitfall #4 (DOM ownership) not yet relevant
- Establishes layout before complex components

**Research flag:** Standard Vue patterns

### Phase 3: Constraint Scores & Variant Summaries (Clinical MVP)
**Rationale:** Highest clinical utility features. Simple data display (numbers, counts) requires backend from Phase 1 but not complex visualizations. Clinical geneticists expect these features - missing them reduces trust.

**Delivers:**
- gnomAD constraint card with gauge visualizations (pLI, LOEUF, mis_z)
- ClinVar variant summary with ACMG color-coded counts
- Version indicators and update timestamps
- Error handling with retry buttons

**Addresses:**
- TS-2 (gnomAD constraints)
- TS-3 (ClinVar summary)

**Uses:**
- gnomAD endpoint from Phase 1
- Card layout from Phase 2

**Avoids:**
- Pitfall #5 (rate limiting) via backend caching

**Research flag:** Standard patterns (numeric display, simple charts)

### Phase 4: Protein Domain Lollipop Plot (Enhanced MVP)
**Rationale:** High clinical value (variant clustering reveals functional domains) but requires D3.js integration expertise. Depends on UniProt domains + ClinVar variants from Phase 1. Critical for ACMG criteria application.

**Delivers:**
- D3.js lollipop plot showing protein domains (UniProt)
- ClinVar variants mapped to amino acid positions
- ACMG color-coding by pathogenicity
- Interactive tooltips with variant details
- Zoom/pan for long proteins

**Addresses:**
- TS-5 (protein lollipop)

**Uses:**
- UniProt endpoint (domains)
- gnomAD endpoint (ClinVar variants)
- D3.js v7.4.2 (already in project)

**Avoids:**
- Pitfall #4 (D3 vs Vue DOM) via non-reactive D3 instance
- Pitfall #8 (D3 event leaks) via onBeforeUnmount cleanup

**Research flag:** **NEEDS DEEPER RESEARCH** - D3.js + Vue integration, HGVS parsing for amino acid positions, performance optimization for >100 variants

### Phase 5: 3D Protein Structure Viewer (Advanced Features)
**Rationale:** High complexity (WebGL, Mol* library, variant highlighting). Defer until core features stable. Requires AlphaFold URLs from Phase 1 and careful Vue reactivity handling. Provides unique spatial insight but not critical for clinical decisions.

**Delivers:**
- Mol* 3D structure viewer with AlphaFold models
- Variant highlighting on 3D structure (linked to lollipop plot)
- Representation controls (cartoon, surface, ball+stick)
- Color by confidence (pLDDT) or pathogenicity

**Addresses:**
- DIFF-2 (3D structure viewer)

**Uses:**
- AlphaFold endpoint (structure URLs)
- Mol* v5.5.0 library
- ClinVar variants (from Phase 3)

**Implements:**
- Linked interactions: select variant in lollipop -> highlight in 3D

**Avoids:**
- Pitfall #1 (Vue Proxy wrapping) via markRaw()
- Pitfall #2 (WebGL leaks) via stage.dispose()

**Research flag:** **NEEDS DEEPER RESEARCH** - Mol* API, variant highlighting implementation, WebGL performance optimization, code splitting strategy

### Phase 6: Model Organism Phenotypes (Post-MVP)
**Rationale:** Useful for NDD researchers but not critical for clinical variant interpretation. Independent of other phases (no visualization complexity). Can develop in parallel with Phase 5 if resources allow.

**Delivers:**
- MGI/RGD phenotype cards with count summaries
- NDD-relevant phenotype highlighting (MP ontology filtering)
- Zygosity breakdown (homozygous lethal vs heterozygous viable)
- Links to detailed model organism databases

**Addresses:**
- DIFF-1 (model organism phenotypes)

**Uses:**
- MGI endpoint from Phase 1

**Research flag:** Standard patterns (API integration, table display)

### Phase Ordering Rationale

**Why this order:**
1. **Backend first (Phase 1)** - All features depend on external data; caching mitigates rate limits; can develop/test independently
2. **UX foundation (Phase 2)** - Establishes layout and empty state patterns before complex components; immediate UX improvement
3. **Simple data display (Phase 3)** - Highest clinical value, lowest complexity; validates backend integration before visualizations
4. **D3 visualization (Phase 4)** - High clinical value but requires D3 expertise; establishes patterns for genomic lollipop if needed
5. **WebGL viewer (Phase 5)** - Highest complexity/risk; defer until core features proven; provides differentiation but not critical
6. **Phenotypes (Phase 6)** - Independent, useful but not critical; can parallelize with Phase 5

**Dependency chain:**
```
Phase 1 (Backend) ────────────────────┐
    │                                 │
    ├──> Phase 2 (UX) ──┐             │
    │                   │             │
    └──> Phase 3 (Constraints) ───────┼──> Phase 5 (3D Viewer)
         │                            │
         └──> Phase 4 (Lollipop) ─────┘

Phase 6 (Phenotypes) ← independent, can parallelize
```

**How this avoids pitfalls:**
- Backend caching (Phase 1) mitigates Pitfall #3 (R blocking) and #5 (rate limits) before frontend calls
- UX foundation (Phase 2) establishes empty state patterns before complex error scenarios
- Simple features first (Phase 3) validates error handling before WebGL complexity
- D3 patterns (Phase 4) established before 3D viewer (Phase 5) - both require non-reactive instances
- WebGL cleanup (Phase 5) isolated to single phase - easier to validate memory leak prevention

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 4 (Lollipop):** HGVS protein notation parsing (extract amino acid positions), D3.js performance optimization for genes with >100 variants, responsive design patterns for mobile/tablet
- **Phase 5 (3D Viewer):** Mol* selection API for variant highlighting, color scheme configuration, code splitting strategy for 74MB bundle, WebGL fallback for unsupported browsers

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Backend):** httr2 retry patterns already in `omim-functions.R`, memoise caching in `analyses-functions.R`
- **Phase 2 (UX):** Bootstrap-Vue-Next cards, Vue Router navigation, standard component patterns
- **Phase 3 (Constraints):** Simple data display, gauge visualizations (Bootstrap or custom CSS)
- **Phase 6 (Phenotypes):** REST API integration, table/card display

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| **Stack** | HIGH | Mol* vs NGL.js decision backed by RCSB deprecation notice (June 2024); ghql is active CRAN package (v0.1.2 Sept 2025); D3/httr2/memoise already validated in project |
| **Features** | HIGH | Competitive analysis of gnomAD, DECIPHER, ClinGen, UniProt verified table stakes vs differentiators; gnomAD constraint scores are ClinGen-recommended standard |
| **Architecture** | HIGH | Reuses proven patterns from existing codebase (Cytoscape.js non-reactive instance, httr2 retry, memoise caching); backend proxy architecture is standard for external API integration |
| **Pitfalls** | MEDIUM-HIGH | Vue+WebGL conflicts verified via Three.js GitHub issues and existing Cytoscape pattern; gnomAD rate limits confirmed in community discussions but specific thresholds undocumented; AlphaFold API transition timeline clear (June 2026 sunset) |

**Overall confidence:** HIGH

### Gaps to Address

Research was comprehensive but identified areas requiring validation during implementation:

- **gnomAD GraphQL query optimization** - Field selection, fragment reuse for performance; rate limit behavior under production load (specific numeric limits not documented)
- **ClinVar variant coordinate mapping** - Genomic (HGVS g.) to protein (HGVS p.) position transformation; handle cases where protein position unavailable (intronic, UTR variants)
- **D3 lollipop plot responsive design** - Mobile vs desktop layouts for long proteins (>500 AA); touch interaction patterns for variant tooltips
- **Mol* variant highlighting implementation** - Selection API syntax for residue highlighting; color scheme configuration for ACMG pathogenicity colors; performance with >50 highlighted variants
- **AlphaFold structure availability** - Not all proteins have AlphaFold predictions; handle 404 responses gracefully; consider PDB fallback for proteins with experimental structures
- **Bundle size optimization** - Mol* selective feature exclusion (movie export, volume server); measure actual impact of 74MB on page load time
- **MGI/RGD API stability** - MouseMine InterMine API less mature than UniProt/Ensembl; may require web scraping fallback if API changes

**Mitigation strategy:**
- Validate gnomAD rate limits early in Phase 1 (load testing with realistic query volume)
- Phase 4 research should include HGVS parsing library evaluation (biocommons.hgvs Python, Mutalyzer API, or custom regex)
- Phase 5 research should include Mol* API documentation deep-dive and reference implementation analysis (fowler-lab/molstar-mutation)
- All phases: maintain error isolation and graceful degradation patterns to handle data gaps

## Sources

### Primary (HIGH confidence)

**Technology Stack:**
- [Molstar npm package](https://www.npmjs.com/package/molstar) - v5.5.0 released Jan 2026
- [RCSB PDB NGL Viewer Deprecation Notice](https://www.rcsb.org/news/feature/65b42d3fc76ca3abcc925d15) - June 28, 2024
- [ghql CRAN package](https://cran.r-project.org/web/packages/ghql/index.html) - v0.1.2, Sept 2025
- [UniProt API Documentation](https://www.uniprot.org/api-documentation/uniprotkb) - 2025_01 release
- [Ensembl REST API](https://rest.ensembl.org/) - v15.10
- [AlphaFold API Documentation](https://alphafold.ebi.ac.uk/api-docs) - API transition timeline (June 2026)

**Feature Landscape:**
- [gnomAD v4.0 Gene Constraint](https://gnomad.broadinstitute.org/news/2024-03-gnomad-v4-0-gene-constraint/)
- [Simple ClinVar](https://simple-clinvar.broadinstitute.org/) - reference implementation
- [ClinVar Classifications](https://www.ncbi.nlm.nih.gov/clinvar/docs/clinsig/) - ACMG terminology
- [DECIPHER Supporting interpretation](https://pmc.ncbi.nlm.nih.gov/articles/PMC9303633/)
- [UniProt 2025 Update](https://academic.oup.com/nar/article/53/D1/D609/7902999)

**Architecture Patterns:**
- [httr2 Retry Documentation](https://httr2.r-lib.org/reference/req_retry.html)
- [Vue 3 markRaw API](https://vuejs.org/api/reactivity-advanced)
- [Using Vue 3's Composition API with D3](https://dev.to/muratkemaldar/using-vue-3-with-d3-composition-api-3h1g)

### Secondary (MEDIUM confidence)

**Rate Limiting:**
- [gnomAD API blocking discussion](https://discuss.gnomad.broadinstitute.org/t/blocked-when-using-api-to-get-af/149) - Community reports ~10 queries
- [Ensembl Rate Limits Wiki](https://github.com/Ensembl/ensembl-rest/wiki/Rate-Limits) - 15 req/sec documented

**Vue + WebGL Integration:**
- [Three.js Proxy conflicts Issue #21075](https://github.com/mrdoob/three.js/issues/21075) - Vue 3 compatibility
- [NGL.js dispose Issue #532](https://github.com/arose/ngl/issues/532) - Cleanup patterns
- [Vue.js Memory Leak Blog](https://blog.jobins.jp/vuejs-memory-leak-identification-and-solution)

**Visualization Best Practices:**
- [Ten simple rules for genomics visualization](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1010622)
- [g3lollipop.js GitHub](https://github.com/G3viz/g3lollipop.js/) - Reference implementation
- [Mol* Viewer PMC Paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC8262734/)

### Tertiary (LOW confidence - needs validation)

- MGI MouseMine API documentation (less mature than UniProt/Ensembl)
- AlphaMissense integration patterns (2025 redesign, implementation details sparse)
- Mol* variant highlighting performance with >50 variants (no benchmarks found)

---

**Research completed:** 2026-01-27
**Ready for roadmap:** Yes
**Recommended next step:** Create roadmap with 6 phases following suggested structure above
