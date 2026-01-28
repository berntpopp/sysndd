---
phase: 43-protein-domain-lollipop-plot
plan: 02
subsystem: ui
tags: [vue, d3, protein-visualization, lollipop-plot, clinvar, uniprot, component]

# Dependency graph
requires:
  - phase: 43-01
    provides: TypeScript interfaces, PATHOGENICITY_COLORS, useD3Lollipop composable
affects: [43-03-card-wrapper, 45-3d-protein-structure-viewer]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Vue 3 SFC with script setup and TypeScript for type-safe components
    - D3 owns SVG element exclusively, Vue owns legend elements (DOM ownership separation)
    - Computed properties for reactive legend rendering from data props
    - watchEffect for automatic re-rendering on filter/data changes
    - Scoped styles with :deep() for D3-created DOM elements

key-files:
  created:
    - app/src/components/gene/ProteinDomainLollipopPlot.vue

key-decisions:
  - "D3 schemeSet2 color scale for domain types shared between composable and Vue legend via same domain ordering"
  - "Domain type label mapping via formatDomainType() helper covering UniProt feature types"
  - "Reactive filterState with watchEffect ensures immediate re-render on legend toggle"
  - "Deep watch on data prop for nested object changes (domains/variants arrays)"

patterns-established:
  - "ProteinDomainLollipopPlot pattern: Props (data, geneSymbol), emits (variant-click, variant-hover), reactive filter state, computed legends"
  - "D3/Vue DOM ownership: D3 appends SVG to container ref, Vue renders legend buttons and domain legend"

# Metrics
duration: 2min
completed: 2026-01-28
---

# Phase 43 Plan 02: ProteinDomainLollipopPlot Vue Component Summary

**Vue 3 SFC wrapping useD3Lollipop composable with reactive pathogenicity legend filters and domain color legend**

## Performance

- **Duration:** 2 min
- **Started:** 2026-01-28T21:33:17Z
- **Completed:** 2026-01-28T21:35:05Z
- **Tasks:** 1
- **Files created:** 1

## Accomplishments
- Vue 3 SFC with script setup and TypeScript for type-safe component definition
- Props: data (ProteinPlotData), geneSymbol (for ARIA accessibility)
- Emits: variant-click, variant-hover for Phase 45 3D viewer bidirectional linking
- Reactive filterState (LollipopFilterState) with all pathogenicity classes enabled by default
- Computed legendItems with variant counts per pathogenicity class
- Computed domainLegendItems with d3.schemeSet2 color scale matching composable
- Clickable legend buttons toggle pathogenicity visibility with aria-pressed state
- Domain legend displays human-readable labels via formatDomainType() helper
- watchEffect triggers renderPlot() on initialization and filter state changes
- Deep watch on data prop handles nested object changes (domains/variants arrays)
- Scoped styles with :deep() for D3-created tooltip element

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ProteinDomainLollipopPlot Vue component** - `56e7b4fc` (feat)

## Files Created
- `app/src/components/gene/ProteinDomainLollipopPlot.vue` - Vue 3 SFC (360 lines) with D3 lollipop plot integration, reactive legend filters, and domain color legend

## Decisions Made
- **Color scale consistency:** Use d3.schemeSet2 (same as useD3Lollipop composable) for domain type colors in Vue legend to ensure visual consistency
- **Domain type labels:** Create formatDomainType() helper with type mapping for common UniProt feature types (DOMAIN, ZN_FING, DNA_BIND, etc.) with title-case fallback
- **Reactive rendering:** Use watchEffect for automatic re-render when isInitialized becomes true or filterState changes
- **Deep watching:** Watch props.data with deep:true to catch changes to nested domains/variants arrays
- **DOM ownership:** D3 owns SVG element inside plotContainer div, Vue owns legend button elements and domain legend spans

## Deviations from Plan

None - plan executed exactly as written.

## Requirements Addressed

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| PROTEIN-01 | Ready | D3 lollipop plot with backbone and AA scale (via composable) |
| PROTEIN-02 | Ready | UniProt domains as colored rectangles (via composable) |
| PROTEIN-03 | Ready | ClinVar variants as lollipop markers (via composable) |
| PROTEIN-04 | Ready | Markers colored by ACMG pathogenicity (via composable) |
| PROTEIN-05 | Ready | Tooltip shows variant details on hover (via composable) |
| PROTEIN-06 | Ready | Brush-to-zoom with double-click reset (via composable) |
| PROTEIN-07 | Complete | Domain legend with color mapping in Vue template |
| PROTEIN-08 | Ready | Stacked markers for overlapping variants (via composable) |
| CLINVAR-04 | Ready | Variants mapped at correct positions (via composable) |
| CLINVAR-05 | Complete | Legend toggles filter variant visibility by classification |

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Component ready for integration into card wrapper (43-03)
- Emits variant-click and variant-hover for Phase 45 3D viewer bidirectional linking
- TypeScript types ensure data contract enforcement at compile time
- Responsive SVG via viewBox scales to container width

---
*Phase: 43-protein-domain-lollipop-plot*
*Completed: 2026-01-28*
