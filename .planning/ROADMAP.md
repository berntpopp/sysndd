# Roadmap: SysNDD v8.0 Gene Page & Genomic Data Integration

**Created:** 2026-01-27
**Milestone:** v8.0
**Phases:** 7 (continuing from Phase 39)
**Requirements covered:** 57/57

## Overview

Transform the gene detail page from a flat identifier list into a modern genomic analysis interface. Backend proxy layer provides cached access to gnomAD, UniProt, Ensembl, AlphaFold, and MGI/RGD APIs. Frontend delivers constraint scores with visual gauges, ClinVar variant summaries with ACMG color coding, D3.js protein domain lollipop plots, gene structure visualization, 3D AlphaFold structure viewer with variant highlighting, and enhanced model organism phenotypes — all with WCAG 2.2 AA accessibility compliance and graceful degradation when external data is unavailable.

---

## Phase 40: Backend External API Layer

**Goal:** Users can access gnomAD, UniProt, Ensembl, AlphaFold, and MGI/RGD data through cached R/Plumber endpoints with rate limiting and error isolation

**Plans:** 5 plans

Plans:
- [x] 40-01-PLAN.md — Shared proxy infrastructure (cache backends, retry/throttle, error format)
- [x] 40-02-PLAN.md — gnomAD, UniProt, Ensembl proxy functions
- [x] 40-03-PLAN.md — AlphaFold, MGI, RGD proxy functions
- [x] 40-04-PLAN.md — Plumber endpoints, aggregation, AUTH_ALLOWLIST
- [x] 40-05-PLAN.md — Unit tests for proxy infrastructure and endpoints

**Requirements:**
- PROXY-01: gnomAD GraphQL proxy for constraint scores and ClinVar variants
- PROXY-02: UniProt REST proxy for protein domains and features
- PROXY-03: Ensembl REST proxy for gene structure (exons, transcripts)
- PROXY-04: AlphaFold proxy for 3D structure metadata and file URLs
- PROXY-05: MGI/JAX proxy for mouse phenotype data
- PROXY-06: RGD proxy for rat phenotype data
- PROXY-07: Combined aggregation endpoint for single-request gene data
- PROXY-08: Server-side disk caching with configurable TTL per source
- PROXY-09: httr2 retry logic with exponential backoff for external calls
- PROXY-10: Rate limiting protection via req_throttle
- PROXY-11: External API endpoints are publicly accessible (AUTH_ALLOWLIST)
- PROXY-12: RFC 9457 error format with source identification

**Success Criteria:**
1. Developer can call `/api/external/gene/<symbol>` and receive cached data from all 5 sources (gnomAD, UniProt, Ensembl, AlphaFold, MGI) in single request
2. Backend respects external API rate limits and never triggers blocking (req_throttle prevents >10 queries/min to gnomAD)
3. When one external API fails, other sources still return data (error isolation works)
4. Second request for same gene returns cached data instantly (no external API call made)
5. Error responses follow RFC 9457 format with source identification so frontend can display meaningful messages

**Dependencies:** None

---

## Phase 41: Gene Page Redesign

**Goal:** Users see a modern, organized gene page with hero section, grouped information cards, and responsive layout before any external data loads

**Plans:** 5 plans

Plans:
- [ ] 41-01-PLAN.md — Reusable components (IdentifierRow, ResourceLink) and GeneApiData TypeScript interface
- [ ] 41-02-PLAN.md — Backend: Add bed_hg38 chromosome coordinates to gene API endpoint
- [ ] 41-03-PLAN.md — Section components (GeneHero, IdentifierCard, ClinicalResourcesCard)
- [ ] 41-04-PLAN.md — GeneView.vue refactor to Composition API with new component layout
- [ ] 41-05-PLAN.md — Visual and functional verification checkpoint

**Requirements:**
- REDESIGN-01: Hero section with symbol badge, gene name, chromosome location, key identifiers
- REDESIGN-02: Identifier card with copy-to-clipboard and external links (Entrez, Ensembl, UniProt, UCSC, CCDS, STRING)
- REDESIGN-03: Clinical resources card-grid with links to OMIM, ClinGen, SFARI, PanelApp, gene2phenotype, HGNC
- REDESIGN-04: Model organisms section with MGI and RGD links with availability indicators
- REDESIGN-05: Loading skeleton placeholder while gene data loads
- REDESIGN-06: Empty state indicators for missing IDs
- REDESIGN-07: Reusable IdentifierRow component for copy-to-clipboard and external link
- REDESIGN-08: Reusable ResourceLink component for card-style external resource links
- REDESIGN-09: Responsive grid layout for desktop and tablet
- REDESIGN-10: Gene.vue refactored to Composition API with script setup

**Success Criteria:**
1. Researcher opens gene page and immediately sees hero section with gene symbol, name, and chromosome location (before any external data loads)
2. Identifiers are visually grouped into a card with one-click copy buttons that work for Entrez, Ensembl, UniProt IDs
3. Clinical resource links (OMIM, ClinGen, SFARI) are displayed as visual cards instead of plain text list
4. When a gene lacks a UniProt ID, empty state shows "Not available" instead of blank space
5. Layout adapts to tablet screen size without horizontal scrolling or overlapping content

**Dependencies:** None (can develop in parallel with Phase 40)

---

## Phase 42: Constraint Scores & Variant Summaries

**Goal:** Users can immediately assess gene constraint and variant burden through gnomAD pLI/LOEUF scores and ClinVar pathogenicity counts

**Plans:** 3 plans

Plans:
- [ ] 42-01-PLAN.md — TypeScript interfaces and useGeneExternalData composable (data layer)
- [ ] 42-02-PLAN.md — GeneConstraintCard and GeneClinVarCard Vue components
- [ ] 42-03-PLAN.md — GeneView.vue integration and visual verification

**Requirements:**
- GNOMAD-01: pLI score with visual gauge and interpretation
- GNOMAD-02: LOEUF (oe_lof_upper) score with visual gauge and interpretation
- GNOMAD-03: Missense Z-score (mis_z) with visual indicator
- GNOMAD-04: Observed vs expected counts for LoF, missense, synonymous variants
- GNOMAD-05: Constraint thresholds use gnomAD v4 guidelines (pLI >= 0.9, LOEUF < 0.6)
- CLINVAR-01: ClinVar variant summary card with counts by pathogenicity classification
- CLINVAR-02: ACMG color coding (pathogenic=red, likely pathogenic=orange, VUS=yellow, likely benign=light green, benign=green)
- CLINVAR-03: ClinVar variants fetched via gnomAD GraphQL API
- COMPOSE-01: useGeneExternalData composable fetches all external data via combined endpoint
- COMPOSE-02: Composable exposes per-source loading states for independent card loading
- COMPOSE-03: Composable exposes per-source error states for graceful degradation
- A11Y-01: Visualization cards have screen reader alternative text summarizing data
- A11Y-02: Constraint score gauges have aria-label with numeric values

**Success Criteria:**
1. Clinical geneticist views gene page and sees pLI score displayed as gauge with interpretation text (e.g., "pLI = 0.95 - Likely haploinsufficient")
2. LOEUF score displays with visual gauge, and values < 0.6 are highlighted as "Highly constrained"
3. ClinVar summary card shows counts for each pathogenicity category (15 Pathogenic, 8 Likely Pathogenic, 23 VUS, etc.) with ACMG color coding
4. When gnomAD API is unavailable, constraint card shows error message but ClinVar card still loads independently
5. Screen reader user hears constraint score values announced (aria-label provides numeric values, not just visual gauges)

**Dependencies:** Phase 40 (requires gnomAD endpoint)

---

## Phase 43: Protein Domain Lollipop Plot

**Goal:** Users can visualize protein domains with ClinVar variants mapped to amino acid positions, revealing clustering patterns in functional domains

**Plans:** 4 plans

Plans:
- [ ] 43-01-PLAN.md — TypeScript interfaces (protein.ts) and useD3Lollipop composable
- [ ] 43-02-PLAN.md — ProteinDomainLollipopPlot.vue D3 visualization component
- [ ] 43-03-PLAN.md — ProteinDomainLollipopCard.vue wrapper and GeneView.vue integration
- [ ] 43-04-PLAN.md — Automated checks and visual verification checkpoint

**Requirements:**
- PROTEIN-01: D3.js lollipop plot with protein backbone and amino acid scale
- PROTEIN-02: Protein domains from UniProt rendered as colored rectangles
- PROTEIN-03: ClinVar variants rendered as lollipop markers at protein position
- PROTEIN-04: Lollipop markers colored by pathogenicity classification (ACMG colors)
- PROTEIN-05: Hover tooltip shows variant details (HGVS, classification, review status)
- PROTEIN-06: Zoom and pan support for dense variant regions
- PROTEIN-07: Domain legend shows color mapping for domain types
- PROTEIN-08: Variant count indicator for overlapping variants at same position
- CLINVAR-04: ClinVar variant positions mapped onto protein lollipop plot
- CLINVAR-05: Lollipop plot supports filtering by pathogenicity classification (P/LP/VUS/LB/B)
- COMPOSE-04: useD3Lollipop composable manages D3 rendering lifecycle (create, update, destroy)
- A11Y-03: Copy-to-clipboard buttons have descriptive aria-labels

**Success Criteria:**
1. Researcher views gene page and sees protein domains (e.g., "Protein kinase domain AA 50-300") rendered as colored rectangles on horizontal backbone
2. ClinVar pathogenic variants appear as red lollipop markers at their amino acid positions above the protein backbone
3. Hovering a variant marker shows tooltip with "p.Arg123Trp, Pathogenic, 3-star review status"
4. User can filter to show only Pathogenic/Likely Pathogenic variants, hiding VUS and benign variants
5. For gene with >100 variants, user can zoom into dense region (e.g., AA 200-250) and pan along protein to explore all variants

**Dependencies:** Phase 40 (requires UniProt and gnomAD endpoints), Phase 42 (uses ClinVar data)

---

## Phase 44: Gene Structure Visualization

**Goal:** Users can view gene structure with exons, introns, UTRs, and strand orientation from Ensembl canonical transcript

**Plans:** 3 plans

Plans:
- [ ] 44-01-PLAN.md — TypeScript interfaces (ensembl.ts) and useD3GeneStructure composable
- [ ] 44-02-PLAN.md — GeneStructurePlot.vue and GeneStructureCard.vue components
- [ ] 44-03-PLAN.md — GeneView.vue integration and visual verification checkpoint

**Requirements:**
- GENSTRUCT-01: Gene structure plot displays exons and introns from Ensembl canonical transcript
- GENSTRUCT-02: Exons rendered as rectangles, introns as lines, UTR regions distinguished
- GENSTRUCT-03: Gene orientation (strand +/-) indicated
- GENSTRUCT-04: Chromosome coordinates displayed on axis

**Success Criteria:**
1. Researcher views gene page and sees exons rendered as blue rectangles with introns as connecting lines
2. UTR regions (5' and 3') are visually distinguished from coding exons (lighter color or pattern)
3. Gene orientation is clearly indicated (arrow or +/- symbol shows forward or reverse strand)
4. Chromosome coordinates on X-axis show genomic positions (e.g., chr1:12,345,678-12,356,789)

**Dependencies:** Phase 40 (requires Ensembl endpoint)

---

## Phase 45: 3D Protein Structure Viewer

**Goal:** Users can explore AlphaFold 3D structure with pLDDT confidence coloring, toggle representations, and highlight ClinVar variants spatially

**Requirements:**
- STRUCT3D-01: 3D viewer renders AlphaFold structure with pLDDT confidence coloring
- STRUCT3D-02: User can toggle between cartoon, surface, and ball+stick representations
- STRUCT3D-03: User can highlight selected ClinVar variant on 3D structure with ACMG-colored marker
- STRUCT3D-04: Variant panel lists available ClinVar variants with pathogenicity for selection
- STRUCT3D-05: Mouse pan, zoom, and rotate controls supported
- STRUCT3D-06: Reset view button returns to default orientation
- STRUCT3D-07: Graceful fallback message when AlphaFold structure not available
- STRUCT3D-08: Structure viewer cleans up WebGL resources on component unmount
- COMPOSE-05: use3DStructure composable wraps Mol* with markRaw() for Vue 3 compatibility
- A11Y-04: 3D viewer has keyboard-accessible controls

**Success Criteria:**
1. Structural biologist opens gene page and sees 3D AlphaFold structure rendered with high-confidence regions (pLDDT > 90) in blue and low-confidence in orange
2. User clicks "Surface" representation button and structure switches from ribbon cartoon to molecular surface view
3. User selects pathogenic variant "p.Arg123Trp" from variant panel and structure highlights position 123 with red marker in 3D space
4. User can rotate structure with mouse drag, zoom with scroll wheel, and reset to default orientation with "Reset View" button
5. When gene has no AlphaFold structure, card shows "3D structure not available for this protein" instead of blank/broken viewer
6. Navigating away from gene page properly disposes WebGL context (no memory leak, no "Too many WebGL contexts" error after 15 genes)

**Dependencies:** Phase 40 (requires AlphaFold endpoint), Phase 42 (uses ClinVar data for variant highlighting)

---

## Phase 46: Model Organism Phenotypes & Final Integration

**Goal:** Users can view model organism phenotype data from MGI and RGD, with all gene page features integrated and accessibility validated

**Requirements:**
- ORGANISM-01: Mouse phenotype card displays phenotype count from MGI with zygosity breakdown
- ORGANISM-02: Rat phenotype card displays available phenotype data from RGD
- ORGANISM-03: Phenotype data fetched via backend proxy (not direct frontend calls)
- ORGANISM-04: Graceful empty state when no phenotype data available
- A11Y-05: Color coding supplemented with text labels (not color-only)

**Success Criteria:**
1. NDD researcher views gene page and sees mouse phenotype card showing "37 phenotypes (15 homozygous lethal, 22 heterozygous viable)"
2. Rat phenotype card shows "12 phenotypes available" with link to RGD database for details
3. When gene has no mouse model, card shows "No mouse phenotype data available" instead of blank space
4. All ACMG pathogenicity colors (used in ClinVar summary, lollipop plot, 3D viewer) include text labels so color-blind users can distinguish categories
5. Full gene page passes WCAG 2.2 AA validation (Lighthouse Accessibility score 100) with keyboard navigation working for all interactive elements

**Dependencies:** Phase 40 (requires MGI/RGD endpoints), all previous phases (final integration)

---

## Progress

| Phase | Requirements | Status | Plans | Completed |
|-------|-------------|--------|-------|-----------|
| 40 - Backend External API Layer | 12 | ✓ Complete | 5/5 | 2026-01-27 |
| 41 - Gene Page Redesign | 10 | Planned | 0/5 | — |
| 42 - Constraint Scores & Variant Summaries | 13 | Planned | 0/3 | — |
| 43 - Protein Domain Lollipop Plot | 12 | Planned | 0/4 | — |
| 44 - Gene Structure Visualization | 4 | Planned | 0/3 | — |
| 45 - 3D Protein Structure Viewer | 9 | Pending | 0/0 | — |
| 46 - Model Organism Phenotypes & Final Integration | 5 | Pending | 0/0 | — |

**Total:** 57 requirements across 7 phases

---

*Roadmap created: 2026-01-27*
*Last updated: 2026-01-27 — Phase 44 planned (3 plans in 3 waves)*
