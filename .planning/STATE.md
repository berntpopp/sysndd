# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-26)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v7.0 Milestone Complete

## Current Position

**Milestone:** v7.0 Curation Workflow Modernization — COMPLETE
**Phase:** 39 of 39 (Accessibility Pass) - COMPLETE
**Plan:** 4 of 4 in phase 39
**Status:** All phases complete, milestone ready for audit
**Last activity:** 2026-01-27 -- Phase 39 verified and complete

```
v7.0 Curation Workflow Modernization: [██████████████████████████████] 100% (7/7 phases complete)
```

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 185
- Milestones shipped: 6 (v1-v6) + v7 complete
- Phases completed: 39

**By Milestone:**

| Milestone | Phases | Plans | Shipped |
|-----------|--------|-------|---------|
| v1 Developer Experience | 1-5 | 19 | 2026-01-21 |
| v2 Docker Infrastructure | 6-9 | 8 | 2026-01-22 |
| v3 Frontend Modernization | 10-17 | 53 | 2026-01-23 |
| v4 Backend Overhaul | 18-24 | 42 | 2026-01-24 |
| v5 Analysis Modernization | 25-27 | 16 | 2026-01-25 |
| v6 Admin Panel Modernization | 28-33 | 20 | 2026-01-26 |

*Updated after each plan completion*

## Accumulated Context

### Decisions

See PROJECT.md for full decisions table.

v7 key decisions (from research):
- **Bootstrap-Vue-Next BFormSelect with multiple**: Use for multi-select, not PrimeVue TreeSelect
- **Critical bugs first**: Fix ApproveUser crash and ModifyStatus dropdown before modernization
- **Extract composables before view modernization**: Reuse patterns from CreateEntity/FormWizard

Phase 34 decisions:
- **null vs [] for loading state**: Use null to represent "not yet loaded" and [] for "loaded but empty"
- **await before modal show**: Make async handlers await loadOptions() before showing modal
- **Defensive response handling**: Use Array.isArray(data) ? data : data?.data || []

Phase 35 decisions:
- **Options API for recursive components**: Use Options API with name property for self-reference (script setup doesn't support self-referencing)
- **Bootstrap-Vue-Next only**: No PrimeVue - use BDropdown, BFormTag, BCollapse for tree multi-select
- **Ancestor context in search**: Preserve parent nodes when children match to show hierarchy context
- **Hierarchy path caching**: Use Map for memoization to optimize tooltip rendering
- **Entity autocomplete in ModifyEntity**: Use AutocompleteInput for entity search by ID, gene, or disease
- **Transform modifier tree**: Restructure API data so all modifiers (present, uncertain, etc.) are selectable children

Phase 35.1 decisions:
- **Store full API response**: Store full entity API response instead of Entity class instance for rich preview data
- **Badge component composition**: Use GeneBadge, DiseaseBadge, EntityBadge for consistent visual styling
- **Rich modal headers**: All 4 modals show Gene | Disease | Inheritance | Category context
- **Submitting state pattern**: Use null | string union to track which action is submitting
- **BFormCheckbox switch**: Replace deprecated custom-control-switch CSS with native switch prop

Phase 36 decisions:
- **Client-side column filtering**: Use computed property for filtering category, user, date range
- **Follow ApproveReview.vue search pattern**: Use same search input structure and pagination layout for consistency
- **Default perPage 25**: Standard default for modernized curation views
- **Search input with 500ms debounce**: Standardized pattern for all curation tables
- **Standardized pagination [10, 25, 50, 100]**: Replace 200 with 100 across curation tables
- **Dynamic aria-labels with entity context**: Use template literals to include entity_id for unique button identification
- **Include batch and user context in ManageReReview**: aria-label includes batch ID and user name for richer context

Phase 37 decisions:
- **Composable-based form extraction**: Extract useReviewForm and useStatusForm following useEntityForm pattern
- **any type for Status class dynamic properties**: Use `any` annotation for JavaScript class instances with dynamic properties
- **Separate load methods per context**: loadStatusData (by status_id) for Review.vue, loadStatusByEntity for ModifyEntity.vue
- **isUpdate parameter for create/update logic**: Single composable handles both create and update via parameter
- **Review form pattern**: Follow useEntityForm structure - composable for state/logic, component for UI
- **Metadata handling**: Keep review_info separate from composable for modal presentation metadata
- **Component v-model pattern**: Use computed getter/setter for bidirectional data binding
- **Draft restoration via window.confirm**: Simple synchronous prompt for draft restoration
- **Reset form on @show event**: Form state reset happens immediately on modal show (FORM-07)

Phase 38-01 decisions:
- **Parameterized query approach**: build_batch_params() helper creates ordered parameter list matching WHERE clause placeholders
- **Entity overlap prevention**: All batch operations exclude entities in active batches via exclusion subquery
- **Recalculation restriction**: batch_recalculate() only allowed for unassigned batches
- **Soft delete pattern**: batch_archive() removes assignment but preserves entity_connect audit trail

Phase 38-02 decisions:
- **Minimal endpoint logic**: Endpoints extract params and delegate to service layer - no business logic in endpoints
- **Request validation at endpoint level**: Validate entity_ids and user_id before service call
- **Default filter change**: Changed from 2020-01-01 date filter to equals(re_review_approved,0) for all pending items

Phase 38-03 decisions:
- **BFormSelect multiple for genes**: Returns array of hgnc_ids directly, matching API expectations
- **Preview modal pattern**: Shows matching entities with count before creation
- **Composable/component separation**: State and logic in composable, UI rendering in component
- **Validation strategy**: Computed isFormValid requires at least one of: date range, gene list, status filter, or disease

Phase 38-04 decisions:
- **Legacy batch assignment preserved**: Keep existing assignment UI but label as "Legacy Batch" for backward compatibility
- **Collapsible form sections**: Batch creation visible by default, gene-specific assignment collapsed for cleaner initial view
- **Status options from API**: Reuse /api/list/status_categories endpoint for recalculate modal filter options
- **Combined commit for interdependent tasks**: All three tasks committed together due to modifying same file

Phase 39-01 decisions:
- **Bootstrap visually-hidden class**: Use Bootstrap's battle-tested screen-reader-only CSS instead of custom implementation
- **Icon legend always visible**: Not collapsible - legends are reference material for repeated consultation
- **Skip link focus reset on route change**: SPA navigation requires manual focus reset for keyboard users
- **Auto-clear announcements**: useAriaLive clears message after 1000ms to prevent stale announcement re-reading
- **Dynamic component support in IconLegend**: Accept both icon classes and Vue components (e.g., CategoryIcon) for flexible rendering

Phase 39-02 decisions:
- **Consistent close button labels**: All modals use header-close-label="Close" for uniform screen reader announcements

Phase 39-03 decisions:
- **IconLegend above tables**: Position icon legends above data tables (not below) for immediate visibility before scanning data
- **announce() politeness levels**: Use 'assertive' only for errors (immediate interruption), 'polite' for success/info (waits for current speech)
- **Dual feedback pattern**: All CRUD operations call both makeToast() (visual) and announce() (screen reader) in try/catch blocks

Phase 39-04 decisions:
- **Use vitest-axe with axe-core**: Industry-standard accessibility testing, detects ~57% of WCAG issues automatically
- **Mock composables for test isolation**: Prevents Bootstrap-Vue-Next plugin errors, provides predictable environment
- **Provide Pinia store**: Avoids "getActivePinia()" errors from views using useUiStore()
- **Stub Bootstrap components with accessible HTML**: Keep tests fast and focused on structural accessibility
- **Disable region rule**: Components tested in isolation without full page landmark structure
- **Lenient decorative icon assertions**: Allow 0 icons in empty state, verify existing icons have aria-hidden

### Roadmap Evolution

- Phase 35.1 inserted after Phase 35: ModifyEntity UX Overhaul (URGENT) - complete UX modernization started in Phase 35

### Pending Todos

None yet.

### Blockers/Concerns

Phase 34 bugs fixed:
- ~~ApproveUser page crashes (JavaScript reduce error)~~ [FIXED in 34-01]
- ~~ModifyStatus dropdown shows empty options~~ [FIXED in 34-02]
- Test coverage at 20.3% means careful incremental changes required

Phase 35 issues fixed:
- ~~ModifyEntity had no autocomplete for entity selection~~ [FIXED in 35-03]
- ~~Phenotype "present" modifier not selectable~~ [FIXED in 35-03 via tree transform]

Phase 35.1 improvements:
- ~~Entity preview shows only plain text~~ [ENHANCED in 35.1-01 with badge components]
- ~~Modal headers lack context~~ [ENHANCED in 35.1-02 with rich Gene | Disease | Inheritance | Category display]
- ~~Custom-control-switch deprecated CSS~~ [REPLACED in 35.1-02 with BFormCheckbox switch prop]
- ~~Action buttons lack loading feedback~~ [ADDED in 35.1-02 with BSpinner during submission]

Phase 36 improvements:
- ~~ApproveReview lacks column filters~~ [ADDED in 36-01 with category, user, date range filters]
- ~~ApproveStatus lacks column filters~~ [ADDED in 36-01 with category, user, date range filters]
- ~~ManageReReview lacks search/pagination~~ [ADDED in 36-02 with search and standardized pagination]
- ~~Action buttons lack accessibility labels~~ [ADDED in 36-03 with aria-labels and tooltips]

Phase 37 improvements:
- ~~Forms lack draft persistence~~ [ADDED in 37-03 with useFormDraft integration]
- ~~No draft restoration prompt~~ [ADDED in 37-03 with window.confirm before loading server data]
- ~~Stale data flash when opening modals~~ [FIXED in 37-03 with @show handlers resetting form state]

Phase 38 improvements:
- ~~Re-review batch creation hardcoded to 2020 filter~~ [FIXED in 38-02 with dynamic filter]
- ~~No dynamic batch creation~~ [ADDED in 38-01/38-02/38-03/38-04 with full batch management system]
- ~~No gene-specific assignment~~ [ADDED in 38-04 with RRV-06 implementation]
- ~~No batch recalculation~~ [ADDED in 38-04 with RRV-05 implementation]

Phase 39 improvements:
- ~~No screen reader announcements for form submissions~~ [ADDED in 39-03 with AriaLiveRegion and announce() calls]
- ~~Icon meanings not explained visually~~ [ADDED in 39-03 with IconLegend components]
- ~~Decorative icons double-announced~~ [FIXED in 39-03 with aria-hidden="true" on icons in labeled buttons]
- ~~No automated accessibility testing~~ [ADDED in 39-04 with vitest-axe tests for all 6 curation views]

## Session Continuity

**Last session:** 2026-01-27
**Stopped at:** Phase 39 complete, v7.0 milestone complete
**Resume file:** None
**Next action:** Audit milestone v7.0

---
*State initialized: 2026-01-20*
*Last updated: 2026-01-27 -- Phase 39 complete (Accessibility Pass) -- v7.0 milestone complete*
