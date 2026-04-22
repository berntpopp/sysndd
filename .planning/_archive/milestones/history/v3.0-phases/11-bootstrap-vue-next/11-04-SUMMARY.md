---
phase: 11-bootstrap-vue-next
plan: 04
subsystem: ui
tags: [bootstrap-vue-next, forms, BFormInput, BFormSelect, BFormTextarea, vue-3]

# Dependency graph
requires:
  - phase: 11-bootstrap-vue-next
    plan: 01
    provides: Bootstrap-Vue-Next foundation with BApp wrapper
provides:
  - Form components migrated to Bootstrap-Vue-Next BForm* naming
  - Authentication forms (Login, Register, PasswordReset) functional
  - User profile forms functional
  - Small form-related components (SearchBar, TableSearchInput, etc.) updated
affects: [11-05, 11-06, form-validation, vee-validate-migration]

# Tech tracking
tech-stack:
  added: []
  patterns: [PascalCase component naming, v-model instead of :value.sync, Bootstrap 5 utility classes]

key-files:
  modified:
    - app/src/views/Login.vue
    - app/src/views/Register.vue
    - app/src/views/PasswordReset.vue
    - app/src/views/User.vue
    - app/src/views/curate/CreateEntity.vue
    - app/src/views/curate/ApproveUser.vue
    - app/src/components/small/TableSearchInput.vue
    - app/src/components/small/TablePaginationControls.vue
    - app/src/components/small/TableFilterControls.vue
    - app/src/components/small/SearchBar.vue

key-decisions:
  - "Bootstrap 5 CSS class migration: ml-* -> ms-*, mr-* -> me-*, text-right -> text-end"
  - "Remove .native modifier from v-on events (deprecated in Vue 3)"
  - "Use @update:model-value instead of @input for BFormInput in wrapper components"

patterns-established:
  - "PascalCase for all Bootstrap-Vue-Next components (BFormInput not b-form-input)"
  - "v-model works with Bootstrap-Vue-Next form components same as Bootstrap-Vue"

# Metrics
duration: 8min
completed: 2026-01-23
---

# Phase 11 Plan 04: Form Components Migration Summary

**Form components migrated to Bootstrap-Vue-Next BForm API with PascalCase naming, Bootstrap 5 CSS classes updated**

## Performance

- **Duration:** 8 min
- **Started:** 2026-01-22T23:35:48Z
- **Completed:** 2026-01-22T23:44:24Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments

- Authentication forms (Login, Register, PasswordReset) migrated to BForm* components
- User profile view migrated with password change form
- CreateEntity curation form migrated (BFormSelect, BFormTextarea, BFormTags)
- Small reusable components migrated (SearchBar, TableSearchInput, TablePaginationControls, TableFilterControls)
- Bootstrap 5 utility classes applied (ms-*, me-*, text-end)
- Removed deprecated .native modifier from SearchBar.vue

## Task Commits

Each task was committed atomically:

1. **Task 1: Update Login, Register, PasswordReset form components** - `6c03d81` (feat)
2. **Task 2: Update form inputs in Curate and User views** - `1400145` (feat)
3. **Task 3: Update small form-related components** - `2f3c9b6` (feat)

## Files Modified

### Authentication Forms (Task 1)
- `app/src/views/Login.vue` - BFormInput, BFormGroup, BFormInvalidFeedback, BButton
- `app/src/views/Register.vue` - BFormInput, BFormGroup, BFormCheckbox, BOverlay
- `app/src/views/PasswordReset.vue` - BFormInput, BFormGroup, BButton

### User and Curate Views (Task 2)
- `app/src/views/User.vue` - BFormInput, BFormGroup, BCollapse, BListGroup, BAvatar
- `app/src/views/curate/CreateEntity.vue` - BFormSelect, BFormTextarea, BFormTags, BInputGroup
- `app/src/views/curate/ApproveUser.vue` - BFormSelect

### Small Components (Task 3)
- `app/src/components/small/TableSearchInput.vue` - BFormInput with model-value syntax
- `app/src/components/small/TablePaginationControls.vue` - BInputGroup, BFormSelect, BPagination
- `app/src/components/small/TableFilterControls.vue` - BFormInput
- `app/src/components/small/SearchBar.vue` - BFormInput, BFormDatalist, BInputGroup, removed .native

## Decisions Made

1. **Bootstrap 5 utility class migration** - Consistently updated Bootstrap 4 classes to Bootstrap 5 equivalents (ml-* to ms-*, mr-* to me-*, text-right to text-end)
2. **Event handler syntax** - Used @update:model-value for wrapper components that emit to parent
3. **Preserved vee-validate wrappers** - ValidationObserver and ValidationProvider kept for now (migration in 11-06)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed TablesGenes.vue closing tag mismatch**
- **Found during:** Task 1 verification (concurrent migration issue)
- **Issue:** Opening `<BTable>` but closing `</b-table>` caused Vue compiler error
- **Fix:** Changed closing tag to `</BTable>`; linter auto-added BTable import
- **Files modified:** app/src/components/tables/TablesGenes.vue
- **Note:** This was a side effect of concurrent 11-02/11-03 migrations

---

**Total deviations:** 1 auto-fixed (blocking issue from concurrent migration)
**Impact on plan:** No scope creep. Fix was necessary for build to succeed.

## Remaining Work

The plan focused on specific files (auth forms, User, curate views, small components). There are still ~23 files with lowercase b-form-* components:
- Table components (TablesGenes, TablesEntities, TablesLogs, TablesPhenotypes)
- Analysis components (8 files)
- Additional curate/admin views

These will be migrated in subsequent plans or as part of ongoing component-by-component migration.

## Verification Results

- [x] Login, Register, PasswordReset forms use BForm* components and submit correctly
- [x] Curate and User views use BForm* components
- [x] All small components with forms updated (SearchInputGroup -> SearchBar, etc.)
- [x] No .sync modifiers on form input values (verified: 0 found)
- [ ] No b-form-* lowercase component names remaining (partial: ~23 files still have lowercase, outside plan scope)

## Next Phase Readiness

- Form components in targeted files migrated to Bootstrap-Vue-Next
- vee-validate wrappers preserved (migration handled in 11-06)
- Build compiles successfully
- Forms functional (validation states, input binding, form submission)

---
*Phase: 11-bootstrap-vue-next*
*Completed: 2026-01-23*
