---
phase: 43-protein-domain-lollipop-plot
plan: 01
subsystem: ui
tags: [d3, typescript, protein-visualization, lollipop-plot, clinvar, uniprot]

# Dependency graph
requires:
  - phase: 40-backend-external-api-layer
    provides: UniProt domain and gnomAD ClinVar API proxy endpoints
  - phase: 42-constraint-scores-variant-summaries
    provides: useGeneExternalData composable, external data TypeScript interfaces
provides:
  - TypeScript interfaces for protein domain visualization (ProteinDomain, ProcessedVariant, ProteinPlotData)
  - PATHOGENICITY_COLORS constant with ACMG-consistent color palette
  - normalizeClassification() helper for gnomAD clinical_significance normalization
  - parseProteinPosition() helper for HGVS notation parsing
  - useD3Lollipop composable for D3.js lifecycle management
affects: [43-02-data-transformation, 43-03-lollipop-component, 45-3d-protein-structure-viewer]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Non-reactive D3 state (let svg not ref) to prevent Vue layout thrashing
    - D3 join pattern for enter/update/exit rendering
    - Brush-to-zoom with double-click reset
    - Tooltip with viewport edge detection

key-files:
  created:
    - app/src/types/protein.ts
    - app/src/composables/useD3Lollipop.ts
  modified:
    - app/src/types/index.ts
    - app/src/composables/index.ts

key-decisions:
  - "Use d3.symbolCircle for coding variants and d3.symbolDiamond for splice variants to visually distinguish variant types"
  - "Store D3 selections in non-reactive let variables following useCytoscape pattern (COMPOSE-04)"
  - "Implement variant stacking by position using d3.group() to handle overlapping variants"
  - "Map combined ClinVar classifications (e.g., Pathogenic/Likely_pathogenic) to the more severe class"

patterns-established:
  - "useD3Lollipop pattern: Non-reactive D3 state, onBeforeUnmount cleanup, brush-to-zoom, tooltip edge detection"
  - "PathogenicityClass normalization: Handle gnomAD underscore format and combined classifications"
  - "HGVS position parsing: Prefer hgvsp, fall back to hgvsc with codon calculation"

# Metrics
duration: 4min
completed: 2026-01-28
---

# Phase 43 Plan 01: Types and D3 Composable Summary

**TypeScript interfaces for protein domain visualization and useD3Lollipop composable following useCytoscape pattern for D3.js lifecycle management**

## Performance

- **Duration:** 4 min
- **Started:** 2026-01-28T21:26:11Z
- **Completed:** 2026-01-28T21:29:57Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- TypeScript interfaces define complete data contract for protein domain visualization (ProteinDomain, ProcessedVariant, ProteinPlotData, LollipopFilterState)
- Helper functions for gnomAD data normalization (normalizeClassification, parseProteinPosition)
- useD3Lollipop composable with D3 lifecycle management, brush-to-zoom, tooltip with edge detection, variant stacking

## Task Commits

Each task was committed atomically:

1. **Task 1: Create TypeScript interfaces for protein visualization data** - `d76de5a9` (feat)
2. **Task 2: Create useD3Lollipop composable for D3 lifecycle management** - `6207e028` (feat)

## Files Created/Modified
- `app/src/types/protein.ts` - TypeScript interfaces for protein domain visualization (PathogenicityClass, ProteinDomain, ProcessedVariant, ProteinPlotData, LollipopFilterState), PATHOGENICITY_COLORS constant, normalizeClassification() and parseProteinPosition() helpers
- `app/src/composables/useD3Lollipop.ts` - D3.js lifecycle composable with SVG initialization, domain/variant rendering, brush-to-zoom, tooltip, cleanup
- `app/src/types/index.ts` - Added barrel re-export for protein types
- `app/src/composables/index.ts` - Added barrel export for useD3Lollipop composable

## Decisions Made
- **Symbol differentiation:** Use d3.symbolCircle for coding variants and d3.symbolDiamond for splice variants to visually distinguish variant types on the lollipop plot
- **Non-reactive D3 state:** Store D3 selections in non-reactive `let` variables (not `ref()`) following the established useCytoscape pattern to prevent Vue reactivity from triggering unnecessary layout recalculations
- **Variant stacking:** Group variants by position using `d3.group()` and render with vertical stack offset (14px) to handle overlapping variants at the same amino acid position
- **Classification normalization:** Map combined ClinVar classifications (e.g., "Pathogenic/Likely_pathogenic") to the more severe class for consistent filtering and coloring
- **HGVS position parsing:** Prefer hgvsp for protein position (most accurate), fall back to hgvsc with codon calculation (Math.ceil(codingPos/3)), mark splice variants as approximate

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- TypeScript error with `this` in D3 `.each()` callback - refactored to use attr callbacks with arrow functions instead of function declarations to avoid implicit `any` typing

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Types and composable ready for 43-02 data transformation layer
- useD3Lollipop exposes renderPlot(), resetZoom(), and reactive state (isInitialized, isLoading, currentZoomDomain)
- onVariantClick and onVariantHover callbacks prepared for Phase 45 3D viewer bidirectional linking

---
*Phase: 43-protein-domain-lollipop-plot*
*Completed: 2026-01-28*
