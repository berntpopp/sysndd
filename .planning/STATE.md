# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-26)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** Phase 38 - Re-Review System Overhaul (Phase 37 complete)

## Current Position

**Milestone:** v7.0 Curation Workflow Modernization
**Phase:** 37 of 39 (Form Modernization) - COMPLETE
**Plan:** 3 of 3 in phase 37
**Status:** Phase complete
**Last activity:** 2026-01-26 -- Completed 37-03-PLAN.md

```
v7.0 Curation Workflow Modernization: [████████████████████__________] 67% (4/6 phases)
```

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 176
- Milestones shipped: 6 (v1-v6)
- Phases completed: 37

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

Phase 37 improvements:
- ~~Forms lack draft persistence~~ [ADDED in 37-03 with useFormDraft integration]
- ~~No draft restoration prompt~~ [ADDED in 37-03 with window.confirm before loading server data]
- ~~Stale data flash when opening modals~~ [FIXED in 37-03 with @show handlers resetting form state]

## Session Continuity

**Last session:** 2026-01-26
**Stopped at:** Completed 37-03-PLAN.md (Phase 37 complete)
**Resume file:** None
**Next action:** Begin Phase 38 - Re-Review System Overhaul

---
*State initialized: 2026-01-20*
*Last updated: 2026-01-26 -- Phase 37 complete (Form Modernization) - Draft persistence and modal @show handlers added*
