---
phase: 11-bootstrap-vue-next
plan: 05
subsystem: ui
tags: [bootstrap-5, css, utility-classes, rtl, vue]

# Dependency graph
requires:
  - phase: 11-04
    provides: Bootstrap-Vue-Next form components
provides:
  - Bootstrap 5 RTL-compatible utility classes across all Vue components
  - Updated margin classes (ms-*/me-* instead of ml-*/mr-*)
  - Updated padding classes (ps-*/pe-* instead of pl-*/pr-*)
  - Updated text alignment classes (text-start/text-end instead of text-left/text-right)
  - Updated float classes (float-start/float-end instead of float-left/float-right)
affects: [11-06, ui-consistency, rtl-support]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Bootstrap 5 RTL-first utility class naming convention

key-files:
  created: []
  modified:
    - app/src/components/Navbar.vue
    - app/src/components/tables/TablesPhenotypes.vue
    - app/src/components/tables/TablesEntities.vue
    - app/src/components/tables/TablesGenes.vue
    - app/src/components/analyses/AnalysesCurationComparisonsTable.vue
    - app/src/views/Home.vue
    - app/src/views/pages/Gene.vue
    - app/src/views/curate/*.vue
    - app/src/views/admin/*.vue
    - app/src/views/review/Review.vue

key-decisions:
  - "Bulk sed replacement for text-left/text-right across 43 files"
  - "No changes needed for sr-only, .close, or data-* attributes (not used in codebase)"

patterns-established:
  - "Bootstrap 5 RTL-first naming: ms-*/me-* for margin, ps-*/pe-* for padding"
  - "text-start/text-end for alignment, float-start/float-end for positioning"

# Metrics
duration: 8min
completed: 2025-01-23
---

# Phase 11 Plan 05: CSS Class Updates Summary

**Bootstrap 4 utility classes migrated to Bootstrap 5 RTL-compatible equivalents across 43 Vue components**

## Performance

- **Duration:** 8 min
- **Started:** 2025-01-23T14:40:00Z
- **Completed:** 2025-01-23T14:48:00Z
- **Tasks:** 3
- **Files modified:** 54 (11 in Task 1, 43 in Task 2)

## Accomplishments

- Replaced all ml-*/mr-* classes with ms-*/me-* (margin-start/margin-end)
- Replaced all text-left/text-right with text-start/text-end
- Replaced all float-left/float-right with float-start/float-end
- Verified no sr-only, .close, or data-toggle/target/dismiss attributes exist (Bootstrap-Vue-Next handles these via Vue props)

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace margin and padding directional classes** - `5f854a8` (feat)
   - 11 files: ml-*/mr-* to ms-*/me-*, ml-auto to ms-auto
2. **Task 2: Replace text alignment and float classes** - `7c56032` (feat)
   - 43 files: text-left/right to text-start/end, float-left/right to float-start/end
3. **Task 3: Replace close button, sr-only, and data attributes** - No commit (no changes needed)

## Files Created/Modified

### Margin class updates (11 files)
- `app/src/components/Navbar.vue` - ms-auto for navbar alignment
- `app/src/components/tables/TablesPhenotypes.vue` - me-1 for button spacing
- `app/src/components/analyses/AnalysesCurationComparisonsTable.vue` - me-1 for button spacing
- `app/src/views/admin/ManageOntology.vue` - me-1 btn-xs for action buttons
- `app/src/views/admin/ManageUser.vue` - me-1 btn-xs for action buttons
- `app/src/views/curate/ApproveReview.vue` - float-end me-2 for modal buttons
- `app/src/views/curate/ApproveStatus.vue` - float-end me-2 for modal buttons
- `app/src/views/curate/ApproveUser.vue` - me-1 btn-xs for action buttons
- `app/src/views/curate/CreateEntity.vue` - float-end me-2 for modal buttons
- `app/src/views/curate/ManageReReview.vue` - me-1 btn-xs for action buttons
- `app/src/views/review/Review.vue` - ms-1, me-1 btn-xs, float-end me-2

### Text and float alignment updates (43 files)
- All component field definitions updated from `class: 'text-left'` to `class: 'text-start'`
- All header/title elements updated from `text-left` to `text-start`
- All action columns updated from `text-right` to `text-end`
- All float positioning updated from `float-left/right` to `float-start/end`

## Decisions Made

1. **Bulk sed replacement approach** - Used sed for efficient replacement across all 43 files with text alignment classes
2. **Task 3 no changes needed** - Bootstrap-Vue-Next handles close buttons, screen reader text, and data attributes via Vue component props (e.g., `@close`, `aria-label` prop), so raw HTML classes/attributes weren't used

## Deviations from Plan

None - plan executed exactly as written.

The plan mentioned 396 occurrences but actual count was lower (~80 Bootstrap 4 directional classes):
- 58 margin left/right (ml-*/mr-*) occurrences
- 22 float-left/float-right occurrences
- 0 padding left/right (pl-*/pr-*) occurrences
- 0 sr-only occurrences
- 0 .close class occurrences
- 0 data-toggle/target/dismiss attribute occurrences
- ~246 text-left/text-right occurrences (in field definitions and headers)

## Issues Encountered

None - replacements were straightforward pattern substitutions.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All Bootstrap 4 utility classes migrated to Bootstrap 5 equivalents
- Visual layout should be unchanged (RTL-compatible naming, same LTR behavior)
- Ready for Wave 4 plans (11-06, 11-07) that handle data attributes and custom CSS
- No blockers or concerns

---
*Phase: 11-bootstrap-vue-next*
*Completed: 2025-01-23*
