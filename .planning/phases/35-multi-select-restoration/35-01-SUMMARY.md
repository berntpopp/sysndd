---
phase: 35-multi-select-restoration
plan: 01
subsystem: ui
tags: [bootstrap-vue-next, tree-select, multi-select, composables, vue3, typescript]

# Dependency graph
requires:
  - phase: 34-admin-composable-extraction
    provides: useModalControls composable pattern
provides:
  - TreeMultiSelect component for hierarchical multi-selection
  - useTreeSearch composable with ancestor preservation
  - useHierarchyPath composable with memoization
  - TreeNode recursive component for tree display
affects: [36-phenotype-variation-migration, review-modernization, entity-creation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Recursive component with Options API for self-reference
    - Tree search with ancestor context preservation
    - Hierarchy path caching for tooltip performance

key-files:
  created:
    - app/src/composables/useTreeSearch.ts
    - app/src/composables/useHierarchyPath.ts
    - app/src/components/forms/TreeNode.vue
    - app/src/components/forms/TreeMultiSelect.vue
  modified:
    - app/src/composables/index.ts

key-decisions:
  - "Options API with name property for recursive component self-reference"
  - "Bootstrap-Vue-Next only (no PrimeVue) for ecosystem consistency"
  - "BDropdown with auto-close=false for multi-select UX"
  - "Ancestor context preservation in tree search for better discoverability"

patterns-established:
  - "TreeNode uses Options API with name: 'TreeNode' for recursive self-reference (script setup doesn't support self-reference)"
  - "Search filtering preserves ancestor nodes when children match to show context"
  - "Hierarchy path computed with memoization via Map for tooltip performance"
  - "BFormTag chips below selector match existing PMID pattern from Review.vue"

# Metrics
duration: 3min
completed: 2026-01-26
---

# Phase 35 Plan 01: TreeMultiSelect Component Foundation Summary

**Custom hierarchical multi-select using Bootstrap-Vue-Next primitives (BDropdown, BFormTag, BCollapse, BFormCheckbox) with search, tooltips, and zero new dependencies**

## Performance

- **Duration:** 3 min
- **Started:** 2026-01-26T10:54:28Z
- **Completed:** 2026-01-26T10:57:08Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- TreeMultiSelect component provides hierarchical multi-selection with visual hierarchy, search, and chip display
- useTreeSearch composable filters tree while preserving ancestor context for better search results
- useHierarchyPath composable computes full hierarchy paths with caching for tooltip performance
- All components use only Bootstrap-Vue-Next (no PrimeVue), requiring zero new npm dependencies

## Task Commits

Each task was committed atomically:

1. **Task 1: Create tree composables** - `22137ca` (feat)
2. **Task 2: Create TreeNode recursive component** - `bf234cf` (feat)
3. **Task 3: Create TreeMultiSelect wrapper component** - `e97aeb5` (feat)

## Files Created/Modified

- `app/src/composables/useTreeSearch.ts` - Filters tree with ancestor preservation for search results
- `app/src/composables/useHierarchyPath.ts` - Computes and caches full hierarchy paths for tooltips
- `app/src/composables/index.ts` - Added exports for new composables
- `app/src/components/forms/TreeNode.vue` - Recursive tree node component with Options API self-reference
- `app/src/components/forms/TreeMultiSelect.vue` - Wrapper component with dropdown, search, and chips

## Decisions Made

**Options API for recursive component**
- TreeNode must use Options API with `name: 'TreeNode'` property to enable self-reference
- Script setup does NOT support self-referencing components
- This is the standard Vue pattern for recursive components

**Bootstrap-Vue-Next only (no PrimeVue)**
- Per Phase 35 research decision, stay within Bootstrap-Vue-Next ecosystem
- Uses BDropdown (auto-close=false), BFormTag, BCollapse, BFormCheckbox
- Zero new npm dependencies required

**Ancestor context preservation in search**
- useTreeSearch preserves ancestor nodes when children match query
- Provides context: "Nervous system > Brain > Seizures" instead of just "Seizures"
- Improves discoverability in deep hierarchies

**Hierarchy path caching**
- useHierarchyPath uses Map for memoization
- Rebuilds cache when options change (watch with deep: true)
- Optimizes tooltip rendering for large trees

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all components compiled and passed linting on first attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for:**
- Phase 36: Migrate existing multi-select fields (phenotypes, variations) to TreeMultiSelect
- Integration testing with real HPO/HGVS hierarchies
- ReviewModernization can use TreeMultiSelect for multi-select restoration

**Components available:**
- TreeMultiSelect component accepts options (TreeNode[]) and v-model (string[])
- Supports search with debounce, chips with hierarchy tooltips, validation error display
- TreeNode handles both parent nodes (navigation) and leaf nodes (selectable)

**Concerns:**
- Component not yet tested with actual HPO/HGVS data structures
- May need data adapter if backend format differs from TreeNode interface
- Performance with very large trees (>1000 nodes) not yet validated

---
*Phase: 35-multi-select-restoration*
*Completed: 2026-01-26*
