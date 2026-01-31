---
phase: 41-gene-page-redesign
plan: 04
subsystem: ui
tags: [vue3, typescript, composition-api, bootstrap-vue-next, gene-page, refactor]

# Dependency graph
requires:
  - phase: 41-01
    provides: "IdentifierRow and ResourceLink foundation components, GeneApiData interface"
  - phase: 41-03
    provides: "GeneHero, IdentifierCard, and ClinicalResourcesCard section components"
provides:
  - "Refactored GeneView.vue using Composition API with script setup"
  - "Component-based gene page layout replacing 400+ line BTable template"
  - "Responsive grid layout for desktop/tablet/mobile"
affects: [gene-detail-view, future-component-refactors]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Composition API refactor pattern for Options API pages"
    - "Computed properties for derived data to avoid template complexity"
    - "Route watcher for SPA navigation without full page reload"
    - "Simple loading state (centered spinner) instead of skeleton screens"

key-files:
  created: []
  modified:
    - "app/src/views/pages/GeneView.vue"

key-decisions:
  - "All derived data accessed via computed properties (no direct array access in template)"
  - "Direct axios import instead of Vue plugin injection for cleaner Composition API code"
  - "Content appears all at once when loading completes (no progressive reveal)"
  - "Responsive grid uses lg breakpoint (cols=12 lg=6) for side-by-side cards on desktop"

patterns-established:
  - "Page refactor pattern: Load data in onMounted, distribute to child components via props"
  - "Loading state pattern: v-if with BSpinner, v-else with content"
  - "Dynamic useHead with computed title and meta description"
  - "Route watcher pattern for gene-to-gene navigation"

# Metrics
duration: 5min
completed: 2026-01-27
---

# Phase 41 Plan 04: GeneView.vue Composition API Refactor Summary

**GeneView.vue refactored from 539-line Options API BTable layout to 140-line Composition API with component-based architecture using GeneHero, IdentifierCard, and ClinicalResourcesCard**

## Performance

- **Duration:** 5 minutes
- **Started:** 2026-01-27T20:50:00Z
- **Completed:** 2026-01-27T20:55:20Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Converted GeneView.vue from Options API to Composition API with script setup
- Replaced 400+ lines of inline BTable templates with three section components
- Reduced file from 539 to 140 lines (74% reduction)
- Implemented responsive grid layout (cols=12 lg=6) for desktop/tablet
- Preserved TablesEntities section and all existing navigation behavior
- Added route watcher for gene-to-gene navigation without page reload

## Task Commits

Each task was committed atomically:

1. **Task 1: Refactor GeneView.vue to Composition API with new layout** - `d7e9842` (refactor)

## Files Created/Modified
- `app/src/views/pages/GeneView.vue` (modified) - Refactored from Options API to Composition API, replaced BTable with GeneHero + IdentifierCard + ClinicalResourcesCard in responsive grid

## Decisions Made

**1. All derived data via computed properties**
- Rationale: REDESIGN-10 requirement to avoid template complexity, STATE.md critical pitfall warns about GeneApiData array fields
- Pattern: `const geneSymbol = computed(() => gene.value?.symbol?.[0] || '')`
- Impact: Clean template, centralized null safety, no nested array access in v-bind

**2. Direct axios import instead of plugin injection**
- Rationale: Composition API doesn't have `this.axios`, and main.ts shows axios is available via import (used in other composables)
- Pattern: `import axios from 'axios'`
- Impact: Cleaner code, consistent with other script setup components

**3. Content appears all at once (no progressive reveal)**
- Rationale: CONTEXT.md explicitly requires "page content appears all at once when ready (not shimmer skeletons)"
- Implementation: Single `v-if="loading"` for spinner, `v-else` for all content
- Impact: Simpler loading state, faster perceived performance for small payloads

**4. Responsive grid uses lg breakpoint**
- Rationale: Plan specifies `cols="12" lg="6"` for side-by-side layout on desktop
- Breakpoints: Mobile/tablet stacked (cols=12), desktop side-by-side (lg=6 at >=992px)
- Impact: Optimal reading width on mobile, efficient space usage on desktop

**5. Route watcher for gene-to-gene navigation**
- Rationale: User may navigate from gene badge in TablesEntities to another gene without full page reload
- Implementation: `watch(() => route.params.symbol, () => loadGeneInfo())`
- Impact: SPA navigation works correctly, data refreshes on route change

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

**1. Pre-existing TypeScript errors in test files**
- Issue: tsc reports Cannot find module errors for AppFooter.vue, AppBanner.vue, FooterNavItem.vue
- Resolution: These are pre-existing test file issues unrelated to GeneView.vue refactor
- Verification: TypeScript compiles GeneView.vue successfully, ESLint passes, Vite build succeeds
- Impact: None - GeneView.vue changes are type-safe and build successfully

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Phase 41 Plan 04 complete:**
- All 10 REDESIGN requirements addressed across Plans 01-04:
  - REDESIGN-01: Hero section ✓ (GeneHero component)
  - REDESIGN-02: Identifier card ✓ (IdentifierCard component)
  - REDESIGN-03: Clinical resources ✓ (ClinicalResourcesCard component)
  - REDESIGN-04: Model organisms ✓ (MGI, RGD in ClinicalResourcesCard)
  - REDESIGN-05: Loading spinner ✓ (BSpinner, not skeleton per CONTEXT.md)
  - REDESIGN-06: Empty states ✓ (handled by IdentifierRow/ResourceLink)
  - REDESIGN-07: IdentifierRow component ✓ (Plan 01)
  - REDESIGN-08: ResourceLink component ✓ (Plan 01)
  - REDESIGN-09: Responsive grid ✓ (BRow/BCol breakpoints)
  - REDESIGN-10: Composition API refactor ✓ (this plan)

**Ready for visual verification:**
- GeneView.vue fully refactored and operational
- All components integrated correctly
- TypeScript compilation passes
- ESLint clean
- Vite build succeeds
- Next: Plan 05 checkpoint for visual/functional verification

**No blockers:**
- Gene page redesign foundation complete
- Component-based architecture established
- Ready for Phase 42 (Constraint Scores & Variant Summaries) which will add new sections using same patterns

**Pattern reuse for future sections:**
- Card-based section layout with BCard + drop shadow
- Props-based data distribution from page to components
- Computed properties for URL construction with null safety
- Responsive grid with BRow/BCol

---
*Phase: 41-gene-page-redesign*
*Completed: 2026-01-27*
