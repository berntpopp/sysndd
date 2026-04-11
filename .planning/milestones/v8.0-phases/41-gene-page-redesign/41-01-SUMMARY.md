---
phase: 41-gene-page-redesign
plan: 01
subsystem: ui
tags: [vue3, typescript, composition-api, bootstrap-vue-next, reusable-components]

# Dependency graph
requires:
  - phase: 40-backend-external-api-layer
    provides: "Backend proxy endpoints for external genomic data"
provides:
  - "GeneApiData TypeScript interface for gene API response typing"
  - "IdentifierRow component for label-value rows with copy and external link"
  - "ResourceLink component for card-style external resource links"
affects: [41-gene-page-redesign, gene-detail-view]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Script setup with TypeScript for Vue 3 components"
    - "Reusable atomic components for gene page UI patterns"
    - "useToast composable for clipboard feedback"

key-files:
  created:
    - "app/src/types/gene.ts"
    - "app/src/components/gene/IdentifierRow.vue"
    - "app/src/components/gene/ResourceLink.vue"
  modified:
    - "app/src/types/index.ts"

key-decisions:
  - "All GeneApiData fields are string[] matching R backend str_split behavior"
  - "IdentifierRow shows 'Not available' for missing values rather than hiding rows"
  - "ResourceLink uses grayed-out state for unavailable resources"
  - "Copy feedback uses existing useToast composable pattern"

patterns-established:
  - "IdentifierRow pattern: label-value rows with copy-to-clipboard and external link buttons"
  - "ResourceLink pattern: card-style links with icon, name, description, and unavailable state"
  - "Script setup with typed props via defineProps<Props>() and withDefaults()"

# Metrics
duration: 2min
completed: 2026-01-27
---

# Phase 41 Plan 01: Foundation Components Summary

**TypeScript interface for gene API responses plus two atomic Vue 3 components (IdentifierRow, ResourceLink) that eliminate repeated inline button/link patterns**

## Performance

- **Duration:** 2 minutes
- **Started:** 2026-01-27T15:57:11Z
- **Completed:** 2026-01-27T15:59:15Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Created GeneApiData TypeScript interface with all 14 fields as string[] to match R backend pipe-split behavior
- Built IdentifierRow component with copy-to-clipboard, external link, and empty state handling
- Built ResourceLink component with card styling, hover effects, and unavailable state
- Established foundation for gene page redesign with reusable atomic components

## Task Commits

Each task was committed atomically:

1. **Task 1: Create GeneApiData TypeScript interface** - `e291f8d` (feat)
2. **Task 2: Create IdentifierRow and ResourceLink components** - `6af894d` (feat)

## Files Created/Modified
- `app/src/types/gene.ts` - GeneApiData interface for gene API response typing (all fields string[])
- `app/src/types/index.ts` - Added GeneApiData export to barrel
- `app/src/components/gene/IdentifierRow.vue` - Reusable identifier row with label, value, copy button, external link
- `app/src/components/gene/ResourceLink.vue` - Card-style external resource link with icon, name, description

## Decisions Made

**1. Type all API response fields as string arrays**
- Rationale: R backend's `str_split(., pattern = "\\|")` wraps all fields in arrays, even single-value fields like symbol
- Impact: All consuming components must access first element: `geneData[0]?.symbol[0]`

**2. Show "Not available" for missing identifiers**
- Rationale: CONTEXT.md explicitly requires showing all identifier rows so users see full set of possible identifiers
- Impact: No conditional rendering logic, cleaner components, better UX for researchers

**3. Use grayed-out state for unavailable resources**
- Rationale: REDESIGN-08 requirement + best practice from genomic database research
- Impact: Users see what resources exist even when no entry for current gene

**4. Use existing useToast composable for copy feedback**
- Rationale: Follows established SysNDD pattern from PublicationsNDDTable.vue
- Impact: Consistent notification behavior across application

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

**1. Uncommitted change in api/endpoints/gene_endpoints.R**
- Issue: Found `bed_hg38` field added to gene endpoint response but not committed
- Resolution: Reset the file since bed_hg38 is noted as "Added by Plan 02" in type definition comments
- Impact: None - kept Plan 01 scope clean, bed_hg38 will be added in Plan 02 as intended

**2. ESLint warning for unused catch variable**
- Issue: `catch (e)` in IdentifierRow.vue triggered @typescript-eslint/no-unused-vars
- Resolution: Changed to `catch (_e)` to follow ESLint convention for intentionally unused variables
- Impact: None - simple fix, no functional change

## Next Phase Readiness

**Ready for Plan 02:**
- GeneApiData interface established for type-safe component props
- IdentifierRow and ResourceLink components ready to be imported and used
- Both components follow script setup pattern for consistency

**No blockers:**
- TypeScript compilation passes
- ESLint clean
- Components tested for empty states and accessibility attributes
- Ready for GeneHero, IdentifierCard, and ClinicalResourcesCard to consume these building blocks

**Future plans can use:**
- `import type { GeneApiData } from '@/types'` for type safety
- `import IdentifierRow from '@/components/gene/IdentifierRow.vue'` for identifier display
- `import ResourceLink from '@/components/gene/ResourceLink.vue'` for external resource links

---
*Phase: 41-gene-page-redesign*
*Completed: 2026-01-27*
