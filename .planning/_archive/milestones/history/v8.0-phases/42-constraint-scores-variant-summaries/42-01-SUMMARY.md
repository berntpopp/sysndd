---
phase: 42-constraint-scores-variant-summaries
plan: 01
subsystem: frontend-data-layer
tags: [typescript, vue3, composable, genomic-data, gnomad, clinvar, axios]

# Dependency graph
requires:
  - phase: 40-backend-external-api-layer
    provides: Combined aggregation endpoint /api/external/gene/<symbol> with error isolation
provides:
  - TypeScript interfaces for gnomAD constraints and ClinVar variants
  - useGeneExternalData composable with per-source loading/error/data state
  - Data layer foundation for all Phase 42 UI components
affects: [42-02, 42-03, 43-protein-domain-lollipop, 45-3d-protein-structure-viewer]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-source state isolation pattern for external API composables"
    - "Plain object with ref properties (not ref of object) for template access"
    - "toRef pattern for accepting both reactive ref and plain string parameters"
    - "Public endpoint pattern (no Authorization header for external proxy endpoints)"

key-files:
  created:
    - app/src/types/external.ts
    - app/src/composables/useGeneExternalData.ts
  modified:
    - app/src/types/index.ts
    - app/src/composables/index.ts

key-decisions:
  - "Per-source state objects (gnomad, clinvar) with independent loading/error/data refs enable graceful degradation"
  - "No auto-fetch on composable creation - consumer calls fetchData() explicitly (matches existing patterns)"
  - "Handle found: false as no data available (not error) per backend pattern"

patterns-established:
  - "SourceState<T> generic interface for per-source state containers"
  - "ExternalApiError interface follows RFC 9457 Problem Details format"
  - "Composable accepts both Ref<string> and string via toRef() normalization"

# Metrics
duration: 3min
completed: 2026-01-27
---

# Phase 42 Plan 01: External Data Layer Foundation Summary

**TypeScript interfaces for gnomAD constraints/ClinVar variants and useGeneExternalData composable with per-source state isolation enabling graceful degradation**

## Performance

- **Duration:** 3 min
- **Started:** 2026-01-27T23:39:47Z
- **Completed:** 2026-01-27T23:43:02Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Created comprehensive TypeScript interfaces matching backend API response structure (GnomADConstraints, ClinVarVariant, ExternalDataResponse, ExternalApiError, SourceState<T>)
- Built useGeneExternalData composable with per-source loading/error/data state objects
- Established data layer foundation for all Phase 42 constraint/variant UI components
- Implemented graceful degradation pattern (one source fails, others still render)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create TypeScript interfaces for external API responses** - `f66e8568` (feat)
2. **Task 2: Create useGeneExternalData composable with per-source state** - `7946bfd5` (feat)

## Files Created/Modified
- `app/src/types/external.ts` - TypeScript interfaces for gnomAD constraints, ClinVar variants, and aggregation response
- `app/src/composables/useGeneExternalData.ts` - Composable with per-source loading/error/data state
- `app/src/types/index.ts` - Added external types barrel export
- `app/src/composables/index.ts` - Added useGeneExternalData barrel export

## Decisions Made

**1. Per-source state isolation pattern**
- Rationale: Each external data source (gnomAD constraints, ClinVar variants) can fail independently. Per-source loading/error/data state enables graceful degradation - if one source fails, others still render.
- Implementation: Plain objects with ref properties (`gnomad.loading.value`, `clinvar.data.value`) instead of ref of object
- Benefits: Template access pattern, independent error handling, partial success support

**2. No auto-fetch on composable creation**
- Rationale: Matches existing project patterns (useAsyncJob, useEntityForm)
- Implementation: Consumer calls `fetchData()` explicitly (e.g., in `onMounted()`)
- Benefits: Control over when data fetches occur, supports conditional fetching

**3. Handle found: false as no data (not error)**
- Rationale: Backend returns `found: false` for genes without constraint data (not an error condition)
- Implementation: Set `data.value = null` and `error.value = null` for found: false
- Benefits: Distinguishes "no data available" from "fetch failed"

**4. Interface field names match backend keys**
- Rationale: Type safety and clarity require exact key matching
- Implementation: `gnomad_constraints` (not `gnomad`), `gnomad_clinvar` (not `clinvar`), constraint data nested under `.constraints`, variant data nested under `.variants`
- Verification: Confirmed by reading `api/endpoints/external_endpoints.R` lines 488-496

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. TypeScript interfaces compiled cleanly on first pass, composable followed existing patterns from useAsyncJob.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Phase 42 Plan 02/03 (UI components)**
- Data layer foundation complete
- Per-source state enables independent card rendering
- TypeScript interfaces provide type safety for UI components
- Composable follows COMPOSE-01/02/03 requirements exactly

**Key exports available:**
- `GnomADConstraints` interface - constraint scores with all fields (pLI, oe_lof, etc.)
- `ClinVarVariant` interface - variant with clinical significance and HGVS notation
- `useGeneExternalData(symbol)` composable - per-source state with fetchData() method

**Pattern established for future sources:**
- UniProt domains (Phase 43)
- AlphaFold structure (Phase 45)
- MGI/RGD phenotypes (Phase 46)

All can follow same `SourceState<T>` pattern with independent loading/error/data refs.

---
*Phase: 42-constraint-scores-variant-summaries*
*Completed: 2026-01-27*
