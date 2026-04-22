---
phase: 46-model-organism-phenotypes
plan: 02
subsystem: ui
tags: [vue3, typescript, bootstrap-vue-next, mgi, rgd, model-organisms, phenotypes, accessibility]

# Dependency graph
requires:
  - phase: 46-01-data-layer
    provides: "MGIPhenotypeData and RGDPhenotypeData interfaces, useModelOrganismData composable"
  - phase: 42-clinvar-card
    provides: "GeneClinVarCard.vue pattern for external data cards with loading/error/data states"
provides:
  - "ModelOrganismsCard.vue component for displaying MGI and RGD phenotype data"
  - "Two-column card layout pattern with independent per-source states"
  - "Zygosity breakdown visualization for mouse phenotypes"
affects: [46-final-integration, future-gene-page-enhancements]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Two-column card layout with border-end-md responsive pattern", "Conditional visibility based on data/error/loading state"]

key-files:
  created:
    - app/src/components/gene/ModelOrganismsCard.vue
  modified:
    - app/src/views/pages/GeneView.vue

key-decisions:
  - "Hide card entirely when both sources have no data AND no error AND not loading"
  - "Use badge-warning-custom for heterozygous phenotypes (yellow/warning color)"
  - "Place ModelOrganismsCard after ClinVar card in single-column layout (cols=\"12\" md=\"6\")"
  - "Wire retry to retryModelOrganismData for independent retry handling"

patterns-established:
  - "Two-column card layout: Left column (Mouse/MGI) with right border on md+, Right column (Rat/RGD)"
  - "Per-source state sections: Independent loading/error/empty/data states within single card"
  - "Zygosity badge visualization: hm (danger), ht (warning-custom), cn (info)"

# Metrics
duration: 2min
completed: 2026-01-29
---

# Phase 46 Plan 02: Model Organisms Card UI Component Summary

**Two-column ModelOrganismsCard component displaying MGI mouse and RGD rat phenotype data with zygosity breakdown and external database links**

## Performance

- **Duration:** 2 min
- **Started:** 2026-01-29T08:31:03Z
- **Completed:** 2026-01-29T08:33:09Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created ModelOrganismsCard.vue with two-column responsive layout (Mouse left, Rat right)
- Implemented independent loading/error/empty/data states for each organism source
- Added zygosity breakdown badges for mouse phenotypes (homozygous, heterozygous, conditional)
- Integrated card into GeneView with parallel data fetching alongside ClinVar and UniProt
- Achieved WCAG 2.2 AA accessibility with aria-labels and role attributes

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ModelOrganismsCard.vue component** - `a668176a` (feat)
2. **Task 2: Integrate ModelOrganismsCard into GeneView.vue** - `e36687d8` (feat)

## Files Created/Modified
- `app/src/components/gene/ModelOrganismsCard.vue` - Combined MGI + RGD phenotype display card with two-column layout, independent per-source states, zygosity badges, external links
- `app/src/views/pages/GeneView.vue` - Added useModelOrganismData composable, ModelOrganismsCard component, parallel fetching in fetchExternalData

## Decisions Made

**1. Hide card entirely when both sources empty and not loading/error**
- Rationale: Avoid showing empty card that provides no value to user
- Implementation: `showCard` computed property checks if any source has data, error, or is loading
- Impact: Cleaner UI for genes without model organism data

**2. Use badge-warning-custom for heterozygous phenotypes**
- Rationale: Bootstrap's default warning variant (yellow) provides good visual distinction from homozygous (red/danger) and conditional (blue/info)
- Implementation: Custom CSS class with #ffc107 background, black text
- Impact: Clear visual hierarchy for zygosity breakdown

**3. Place ModelOrganismsCard in single-column layout after ClinVar**
- Rationale: Card contains two sub-columns internally, doesn't need side-by-side placement with other cards
- Implementation: Full-width row (cols="12" md="6") placed after ClinVar card row
- Impact: Consistent with existing card layout pattern, leaves room for potential side-by-side pairing in future

**4. Independent retry handler for model organism data**
- Rationale: MGI and RGD data fetching is independent from ClinVar/UniProt fetching
- Implementation: @retry="retryModelOrganismData" wired to composable's retry method
- Impact: Users can retry model organism data without re-fetching all external sources

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - TypeScript compilation passed, ESLint passed, and all verification criteria met on first attempt.

## User Setup Required

None - no external service configuration required. Backend MGI and RGD proxy endpoints already exist from Phase 40.

## Next Phase Readiness

**Ready for Phase 46 Plan 03+ (Final Integration and Enhancements):**
- Model Organisms card fully integrated into gene page
- UI follows established card patterns (GeneClinVarCard, GeneConstraintCard)
- Data fetching integrated into existing parallel fetch pattern
- Accessibility requirements met (WCAG 2.2 AA)

**Success Criteria Met:**
- ✓ ORGANISM-01: Mouse phenotype card displays count with zygosity breakdown (hm/ht/cn badges)
- ✓ ORGANISM-02: Rat phenotype card displays phenotype count
- ✓ ORGANISM-03: Data fetched via backend proxy endpoints (useModelOrganismData composable)
- ✓ ORGANISM-04: Empty state shows "No [mouse/rat] phenotype data" when no phenotypes
- ✓ Card hidden entirely when neither source has data/error/loading

**No blockers:**
- All verification checks passed
- Component follows existing patterns
- Integration complete with no side effects

---
*Phase: 46-model-organism-phenotypes*
*Completed: 2026-01-29*
