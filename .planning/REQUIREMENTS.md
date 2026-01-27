# Requirements: SysNDD v8.0 Gene Page & Genomic Data Integration

**Defined:** 2026-01-27
**Core Value:** A researcher can view a gene page and immediately understand its constraint metrics, clinical variant landscape, protein domain impact, and 3D structural context — all from a single, well-organized interface.

## v1 Requirements

Requirements for v8.0 release. Each maps to roadmap phases.

### Gene Page Redesign (REDESIGN)

- [ ] **REDESIGN-01**: Gene page displays hero section with symbol badge, gene name, chromosome location, and key identifiers prominently
- [ ] **REDESIGN-02**: Gene identifiers are grouped into a card with copy-to-clipboard and external link buttons for each ID (Entrez, Ensembl, UniProt, UCSC, CCDS, STRING)
- [ ] **REDESIGN-03**: Clinical resources are grouped into a visual card-grid with links to OMIM, ClinGen, SFARI, PanelApp, gene2phenotype, HGNC
- [ ] **REDESIGN-04**: Model organisms section displays MGI and RGD links with availability indicators
- [ ] **REDESIGN-05**: Loading skeleton placeholder renders while gene data loads (instead of spinner)
- [ ] **REDESIGN-06**: Empty state indicators show "Not available" for missing IDs (instead of blank)
- [ ] **REDESIGN-07**: Reusable IdentifierRow component handles copy-to-clipboard and external link for any database ID
- [ ] **REDESIGN-08**: Reusable ResourceLink component renders card-style external resource links with icon and description
- [ ] **REDESIGN-09**: Gene page uses responsive grid layout that works on desktop and tablet
- [ ] **REDESIGN-10**: Gene.vue refactored to Composition API (script setup) using new sub-components

### Backend External API Proxy (PROXY)

- [x] **PROXY-01**: R/Plumber endpoint proxies gnomAD GraphQL API for gene constraint scores and ClinVar variants
- [x] **PROXY-02**: R/Plumber endpoint proxies UniProt REST API for protein domain and feature data
- [x] **PROXY-03**: R/Plumber endpoint proxies Ensembl REST API for gene structure (exons, transcripts)
- [x] **PROXY-04**: R/Plumber endpoint proxies AlphaFold API for 3D structure metadata and file URLs
- [x] **PROXY-05**: R/Plumber endpoint proxies MGI/JAX API for mouse phenotype data
- [x] **PROXY-06**: R/Plumber endpoint proxies RGD API for rat phenotype data
- [x] **PROXY-07**: Combined endpoint aggregates all external sources for a gene in a single request with error isolation
- [x] **PROXY-08**: Server-side disk caching (memoise + cachem) with configurable TTL per source
- [x] **PROXY-09**: httr2 retry logic with exponential backoff for all external API calls
- [x] **PROXY-10**: Rate limiting protection (req_throttle) to avoid exceeding external API limits
- [x] **PROXY-11**: External API endpoints are publicly accessible (no auth required) via AUTH_ALLOWLIST
- [x] **PROXY-12**: RFC 9457 error format for external API failures with source identification

### gnomAD Constraint Scores (GNOMAD)

- [ ] **GNOMAD-01**: Gene page displays pLI score with visual gauge/indicator and interpretation
- [ ] **GNOMAD-02**: Gene page displays LOEUF (oe_lof_upper) score with visual gauge and interpretation
- [ ] **GNOMAD-03**: Gene page displays missense Z-score (mis_z) with visual indicator
- [ ] **GNOMAD-04**: Constraint scores card shows observed vs expected counts for LoF, missense, and synonymous variants
- [ ] **GNOMAD-05**: Constraint score thresholds use gnomAD v4 guidelines (pLI >= 0.9, LOEUF < 0.6 for constrained)

### ClinVar Variant Integration (CLINVAR)

- [ ] **CLINVAR-01**: Gene page displays ClinVar variant summary card with counts by pathogenicity classification
- [ ] **CLINVAR-02**: Summary uses ACMG color coding (pathogenic=red, likely pathogenic=orange, VUS=yellow, likely benign=light green, benign=green)
- [ ] **CLINVAR-03**: ClinVar variants are fetched via gnomAD GraphQL API (clinvar_variants field)
- [ ] **CLINVAR-04**: ClinVar variant positions are mapped onto the protein domain lollipop plot
- [ ] **CLINVAR-05**: Lollipop plot supports filtering by pathogenicity classification (P/LP/VUS/LB/B)

### Protein Domain Visualization (PROTEIN)

- [ ] **PROTEIN-01**: D3.js lollipop plot displays protein backbone with amino acid scale
- [ ] **PROTEIN-02**: Protein domains from UniProt are rendered as colored rectangles on the backbone
- [ ] **PROTEIN-03**: ClinVar variants are rendered as lollipop markers at their protein position
- [ ] **PROTEIN-04**: Lollipop markers are colored by pathogenicity classification (ACMG colors)
- [ ] **PROTEIN-05**: Hovering a variant marker shows tooltip with variant details (HGVS, classification, review status)
- [ ] **PROTEIN-06**: Plot supports zoom and pan for exploring dense variant regions
- [ ] **PROTEIN-07**: Domain legend shows color mapping for domain types
- [ ] **PROTEIN-08**: Variant count indicator for positions with multiple overlapping variants

### Gene Structure Visualization (GENSTRUCT)

- [ ] **GENSTRUCT-01**: Gene structure plot displays exons and introns from Ensembl canonical transcript
- [ ] **GENSTRUCT-02**: Exons rendered as rectangles, introns as lines, with UTR regions distinguished
- [ ] **GENSTRUCT-03**: Gene orientation (strand +/-) is indicated
- [ ] **GENSTRUCT-04**: Chromosome coordinates displayed on axis

### 3D Protein Structure (STRUCT3D)

- [ ] **STRUCT3D-01**: 3D viewer renders AlphaFold predicted structure with pLDDT confidence coloring
- [ ] **STRUCT3D-02**: User can toggle between cartoon, surface, and ball+stick representations
- [ ] **STRUCT3D-03**: User can highlight selected ClinVar variant on 3D structure with ACMG-colored marker
- [ ] **STRUCT3D-04**: Variant panel lists available ClinVar variants with pathogenicity for selection
- [ ] **STRUCT3D-05**: Viewer supports mouse pan, zoom, and rotate controls
- [ ] **STRUCT3D-06**: Reset view button returns to default orientation
- [ ] **STRUCT3D-07**: Graceful fallback message when AlphaFold structure is not available
- [ ] **STRUCT3D-08**: Structure viewer properly cleans up WebGL resources on component unmount

### Model Organism Phenotypes (ORGANISM)

- [ ] **ORGANISM-01**: Mouse phenotype card displays phenotype count from MGI with zygosity breakdown
- [ ] **ORGANISM-02**: Rat phenotype card displays available phenotype data from RGD
- [ ] **ORGANISM-03**: Phenotype data fetched via backend proxy (not direct frontend calls)
- [ ] **ORGANISM-04**: Graceful empty state when no phenotype data available

### Frontend Composables (COMPOSE)

- [ ] **COMPOSE-01**: useGeneExternalData composable fetches all external data via combined backend endpoint
- [ ] **COMPOSE-02**: Composable exposes per-source loading states for independent card loading indicators
- [ ] **COMPOSE-03**: Composable exposes per-source error states for graceful degradation
- [ ] **COMPOSE-04**: useD3Lollipop composable manages D3 rendering lifecycle (create, update, destroy)
- [ ] **COMPOSE-05**: use3DStructure composable wraps Mol*/NGL.js with markRaw() pattern for Vue 3 compatibility

### Accessibility (A11Y)

- [ ] **A11Y-01**: All visualization cards have screen reader alternative text summarizing the data
- [ ] **A11Y-02**: Constraint score gauges have aria-label with numeric values
- [ ] **A11Y-03**: Copy-to-clipboard buttons have descriptive aria-labels
- [ ] **A11Y-04**: 3D viewer has keyboard-accessible controls
- [ ] **A11Y-05**: Color coding (ACMG) is supplemented with text labels (not color-only)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Gene Table Annotations

- **TABLE-01**: TablesGenes displays pLI/LOEUF columns with data from backend
- **TABLE-02**: Constraint score columns are sortable and filterable

### Advanced Variant Features

- **VARIANT-01**: Variant table with sortable columns (position, HGVS, classification, review status)
- **VARIANT-02**: ClinVar submission details for conflicting variants
- **VARIANT-03**: gnomAD allele frequency data for variants

### Enhanced Visualizations

- **VIZ-01**: Gene structure plot with ClinVar variant overlay (genomic coordinates)
- **VIZ-02**: AlphaMissense pathogenicity overlay on 3D structure
- **VIZ-03**: Distance calculation from variant to functional domains in 3D

## Out of Scope

| Feature | Reason |
|---------|--------|
| Direct frontend API calls to external sources | All routed through backend for caching/rate limiting |
| gnomAD constraint columns in gene table | Gene detail page only for v8 — deferred to v9 |
| Server-side pagination for variant lists | Client-side sufficient for ClinVar counts per gene |
| Custom gnomAD variant browser | Link to gnomAD browser instead |
| Inline variant annotation editing | Read-only display of external data |
| OMIM phenotype text display | Link to OMIM instead (license constraints) |
| PDB experimental structure fallback | AlphaFold predictions sufficient for v8 |
| Real-time external API data | Cached with TTL — not streaming |
| Gene page export to PDF | Standard browser print sufficient |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| REDESIGN-01 | Phase 41 | Pending |
| REDESIGN-02 | Phase 41 | Pending |
| REDESIGN-03 | Phase 41 | Pending |
| REDESIGN-04 | Phase 41 | Pending |
| REDESIGN-05 | Phase 41 | Pending |
| REDESIGN-06 | Phase 41 | Pending |
| REDESIGN-07 | Phase 41 | Pending |
| REDESIGN-08 | Phase 41 | Pending |
| REDESIGN-09 | Phase 41 | Pending |
| REDESIGN-10 | Phase 41 | Pending |
| PROXY-01 | Phase 40 | Pending |
| PROXY-02 | Phase 40 | Pending |
| PROXY-03 | Phase 40 | Pending |
| PROXY-04 | Phase 40 | Pending |
| PROXY-05 | Phase 40 | Pending |
| PROXY-06 | Phase 40 | Pending |
| PROXY-07 | Phase 40 | Pending |
| PROXY-08 | Phase 40 | Pending |
| PROXY-09 | Phase 40 | Pending |
| PROXY-10 | Phase 40 | Pending |
| PROXY-11 | Phase 40 | Pending |
| PROXY-12 | Phase 40 | Pending |
| GNOMAD-01 | Phase 42 | Pending |
| GNOMAD-02 | Phase 42 | Pending |
| GNOMAD-03 | Phase 42 | Pending |
| GNOMAD-04 | Phase 42 | Pending |
| GNOMAD-05 | Phase 42 | Pending |
| CLINVAR-01 | Phase 42 | Pending |
| CLINVAR-02 | Phase 42 | Pending |
| CLINVAR-03 | Phase 42 | Pending |
| CLINVAR-04 | Phase 43 | Pending |
| CLINVAR-05 | Phase 43 | Pending |
| PROTEIN-01 | Phase 43 | Pending |
| PROTEIN-02 | Phase 43 | Pending |
| PROTEIN-03 | Phase 43 | Pending |
| PROTEIN-04 | Phase 43 | Pending |
| PROTEIN-05 | Phase 43 | Pending |
| PROTEIN-06 | Phase 43 | Pending |
| PROTEIN-07 | Phase 43 | Pending |
| PROTEIN-08 | Phase 43 | Pending |
| GENSTRUCT-01 | Phase 44 | Pending |
| GENSTRUCT-02 | Phase 44 | Pending |
| GENSTRUCT-03 | Phase 44 | Pending |
| GENSTRUCT-04 | Phase 44 | Pending |
| STRUCT3D-01 | Phase 45 | Pending |
| STRUCT3D-02 | Phase 45 | Pending |
| STRUCT3D-03 | Phase 45 | Pending |
| STRUCT3D-04 | Phase 45 | Pending |
| STRUCT3D-05 | Phase 45 | Pending |
| STRUCT3D-06 | Phase 45 | Pending |
| STRUCT3D-07 | Phase 45 | Pending |
| STRUCT3D-08 | Phase 45 | Pending |
| ORGANISM-01 | Phase 46 | Pending |
| ORGANISM-02 | Phase 46 | Pending |
| ORGANISM-03 | Phase 46 | Pending |
| ORGANISM-04 | Phase 46 | Pending |
| COMPOSE-01 | Phase 42 | Pending |
| COMPOSE-02 | Phase 42 | Pending |
| COMPOSE-03 | Phase 42 | Pending |
| COMPOSE-04 | Phase 43 | Pending |
| COMPOSE-05 | Phase 45 | Pending |
| A11Y-01 | Phase 42 | Pending |
| A11Y-02 | Phase 42 | Pending |
| A11Y-03 | Phase 43 | Pending |
| A11Y-04 | Phase 45 | Pending |
| A11Y-05 | Phase 46 | Pending |

**Coverage:**
- v1 requirements: 57 total
- Mapped to phases: 57
- Unmapped: 0

**Coverage validation:** 100% ✓

---
*Requirements defined: 2026-01-27*
*Last updated: 2026-01-27 after roadmap creation*
