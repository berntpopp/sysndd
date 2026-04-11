---
phase: 17-cleanup-polish
plan: 03
subsystem: ui
tags: [vue3, components, tree-shaking, vite, build-optimization]

# Dependency graph
requires:
  - phase: 17-01
    provides: Bundle analysis baseline
provides:
  - Explicit component imports replacing global registration
  - Better tree-shaking support for production builds
  - Clearer component dependencies in codebase
affects: [bundle-optimization, code-clarity, developer-experience]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Explicit component imports in script section
    - Components registered in components: {} option
    - No global component registration (except Bootstrap-Vue-Next)

key-files:
  created: []
  modified:
    - app/src/main.ts
    - app/src/App.vue
    - app/src/components/Navbar.vue
    - app/src/components/tables/TablesEntities.vue
    - app/src/components/tables/TablesGenes.vue
    - app/src/components/tables/TablesPhenotypes.vue
    - app/src/components/analyses/AnalysesCurationComparisonsTable.vue
    - app/src/views/Home.vue
    - app/src/views/tables/Entities.vue
    - app/src/views/tables/Genes.vue
    - app/src/views/tables/Phenotypes.vue
    - app/src/views/admin/ViewLogs.vue
    - app/src/views/analyses/GeneNetworks.vue
    - app/src/views/analyses/EntriesOverTime.vue
    - app/src/views/pages/Entity.vue
    - app/src/views/pages/Gene.vue
    - app/src/views/pages/Ontology.vue
    - app/src/views/pages/Search.vue
  deleted:
    - app/src/global-components.js

key-decisions:
  - "Remove legacy global component registration pattern"
  - "Use explicit imports for better tree-shaking and code clarity"
  - "Keep Bootstrap-Vue-Next as global (framework components)"

patterns-established:
  - "Component imports: import ComponentName from '@/components/path/ComponentName.vue'"
  - "Component registration: components: { ComponentName } in script options"
  - "Badge components imported where used (CategoryIcon, NddIcon, EntityBadge, GeneBadge, DiseaseBadge, InheritanceBadge)"

# Metrics
duration: 6min
completed: 2026-01-23
---

# Phase 17 Plan 03: Remove Global Component Registration Summary

**Deleted global-components.js and converted to explicit component imports for better tree-shaking and code clarity**

## Performance

- **Duration:** 6 min
- **Started:** 2026-01-23T15:46:58Z
- **Completed:** 2026-01-23T15:52:55Z
- **Tasks:** 3
- **Files modified:** 17
- **Files deleted:** 1

## Accomplishments
- Removed legacy global component registration pattern from main.ts
- Added explicit imports to all 17 files using previously global components
- Deleted global-components.js file
- Production build succeeds with improved tree-shaking capability
- All component dependencies now explicit and traceable

## Task Commits

Each task was committed atomically:

1. **Task 2: Add explicit imports to components** - `f927ae3` (refactor)
   - App.vue: import Navbar, Footer, HelperBadge
   - Home.vue: import SearchBar, Banner, all badge components
   - View components: import table and badge components
   - Table components: import all badge components
   - Analysis components: import badge components
   - Navbar: import SearchBar, IconPairDropdownMenu

2. **Task 3: Remove global registration** - `549585a` (refactor)
   - Remove import of global-components.js from main.ts
   - Remove global component registration loop
   - Delete global-components.js file

## Files Created/Modified

### Deleted
- `app/src/global-components.js` - Legacy global registration removed

### Modified
- `app/src/main.ts` - Removed global component registration
- `app/src/App.vue` - Added Navbar, Footer, HelperBadge imports
- `app/src/components/Navbar.vue` - Added SearchBar, IconPairDropdownMenu imports
- `app/src/components/tables/TablesEntities.vue` - Added all badge component imports
- `app/src/components/tables/TablesGenes.vue` - Added CategoryIcon, NddIcon, GeneBadge, InheritanceBadge imports
- `app/src/components/tables/TablesPhenotypes.vue` - Added all badge component imports
- `app/src/components/analyses/AnalysesCurationComparisonsTable.vue` - Added CategoryIcon, GeneBadge imports
- `app/src/views/Home.vue` - Added SearchBar, Banner, and all badge components
- `app/src/views/tables/Entities.vue` - Added TablesEntities import
- `app/src/views/tables/Genes.vue` - Added TablesGenes import
- `app/src/views/tables/Phenotypes.vue` - Added TablesPhenotypes import
- `app/src/views/admin/ViewLogs.vue` - Added TablesLogs import
- `app/src/views/analyses/GeneNetworks.vue` - Added AnalyseGeneClusters import
- `app/src/views/analyses/EntriesOverTime.vue` - Added AnalysesTimePlot import
- `app/src/views/pages/Entity.vue` - Added all badge component imports
- `app/src/views/pages/Gene.vue` - Added TablesEntities, GeneBadge imports
- `app/src/views/pages/Ontology.vue` - Added TablesEntities, DiseaseBadge, InheritanceBadge imports
- `app/src/views/pages/Search.vue` - Added EntityBadge import

## Decisions Made

None - plan executed exactly as written

## Deviations from Plan

None - plan executed exactly as written

## Issues Encountered

None - straightforward refactoring task completed successfully

## User Setup Required

None - no external service configuration required

## Next Phase Readiness

Ready for further bundle optimization. Key benefits:
- **Better tree-shaking:** Vite can now detect unused components and exclude them from bundles
- **Explicit dependencies:** Component usage is clear from imports, aiding code navigation
- **Reduced bundle size potential:** Unused components no longer forced into bundles via global registration
- **Code clarity:** Import statements document component dependencies at the top of each file

No blockers. Ready to proceed with additional optimization tasks (lazy loading, code splitting, etc.)

---
*Phase: 17-cleanup-polish*
*Completed: 2026-01-23*
