---
phase: 43
plan: 03
subsystem: frontend-visualization
completed: 2026-01-28
duration: ~3 minutes
tags: [vue, protein-domains, clinvar, d3, data-integration]

dependency-graph:
  requires: [43-01, 43-02, 42-01]
  provides: [protein-domain-card-component, geneview-lollipop-integration]
  affects: [45-3d-structure-viewer]

tech-stack:
  added: []
  patterns: [card-wrapper-pattern, parallel-data-fetching, graceful-degradation]

key-files:
  created:
    - app/src/components/gene/ProteinDomainLollipopCard.vue
  modified:
    - app/src/views/pages/GeneView.vue

decisions:
  - id: CARD-01
    title: Inline UniProt fetching in GeneView
    choice: Add inline fetchUniprotData in GeneView rather than extending composable
    rationale: useGeneExternalData was simplified to ClinVar-only; extending scope would require separate plan

metrics:
  tasks: 2/2
  commits: 2
  files-changed: 2
---

# Phase 43 Plan 03: Card Wrapper and GeneView Integration Summary

Card wrapper component connecting lollipop plot to real external data with loading/error handling and GeneView integration.

## Commits

| Hash | Message |
|------|---------|
| 7f40fd86 | feat(43-03): create ProteinDomainLollipopCard wrapper component |
| 7c48240a | feat(43-03): integrate protein domain lollipop card into GeneView |

## What Was Built

### ProteinDomainLollipopCard.vue (261 lines)
Card wrapper component that:
- Accepts raw UniProt and ClinVar API responses as props
- Handles 4 UI states: loading, full error, data available, empty
- Processes raw API data into ProteinPlotData format:
  - Transforms UniProt domains into ProteinDomain[]
  - Transforms ClinVar variants into ProcessedVariant[] with position parsing
- Shows partial data when one source fails (graceful degradation)
- Estimates protein length from max variant position when UniProt unavailable
- Emits retry and variant-click events

### GeneView.vue Integration
- Added ProteinDomainLollipopCard as full-width card below constraint/ClinVar cards
- Inline UniProt data fetching via `/api/external/uniprot/domains/<symbol>`
- Parallel fetching of ClinVar and UniProt data via Promise.all
- Non-blocking external data loading (gene info renders immediately)
- Retry handler for both data sources

## Key Technical Decisions

1. **Inline UniProt fetching**: Added `fetchUniprotData()` directly in GeneView.vue rather than extending `useGeneExternalData` composable. The composable was simplified to ClinVar-only in Phase 42; extending its scope would require a separate plan.

2. **Parallel data fetching**: Both ClinVar and UniProt are fetched in parallel via `Promise.all([fetchClinvarData(), fetchUniprotData()])` for faster page load.

3. **Graceful degradation**: The card renders with partial data if one source fails:
   - UniProt fails: Shows variants-only plot with estimated protein length
   - ClinVar fails: Shows domains-only plot with backbone

4. **Position parsing fallback**: When `hgvsp` is unavailable, calculates approximate amino acid position from `hgvsc` using codon math.

## Deviations from Plan

None - plan executed exactly as written.

## Files Changed

| File | Lines | Change Type |
|------|-------|-------------|
| ProteinDomainLollipopCard.vue | 261 | Created |
| GeneView.vue | +101/-1 | Modified |

## Verification Results

1. Build succeeds with no errors
2. ProteinDomainLollipopCard.vue: 261 lines (exceeds 60 min)
3. Key links verified:
   - Card imports ProteinDomainLollipopPlot component
   - Card imports normalizeClassification/parseProteinPosition from protein.ts
   - GeneView imports ProteinDomainLollipopCard
   - GeneView uses useGeneExternalData composable
4. UniProt API endpoint used: `/api/external/uniprot/domains/<symbol>`

## Integration Points

- **From 43-01**: Uses ProcessedVariant, ProteinDomain, ProteinPlotData types; normalizeClassification, parseProteinPosition helpers
- **From 43-02**: Renders ProteinDomainLollipopPlot child component
- **From 42-01**: Uses ClinVarVariant type, useGeneExternalData composable for ClinVar data
- **To 45-xx**: variant-click event ready for 3D structure viewer linking

## Next Phase Readiness

Phase 43 complete. All 3 plans executed:
- 43-01: Types and D3 composable
- 43-02: ProteinDomainLollipopPlot Vue component
- 43-03: Card wrapper and GeneView integration

The protein domain lollipop plot is now visible on the gene page, showing UniProt domains and ClinVar variants with brush-to-zoom and legend filtering.

Ready for Phase 44 (Gene Structure Visualization) or Phase 45 (3D Protein Structure Viewer).
