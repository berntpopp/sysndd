# Roadmap: SysNDD v7.0 Curation Workflow Modernization

## Overview

This roadmap transforms curation views from basic forms into modern, accessible interfaces. Starting with critical bug fixes that unblock basic functionality, we progress through restoring multi-select capabilities, modernizing tables with the TablesEntities pattern established in v6, extracting reusable form components, overhauling the re-review system with dynamic batch management, and completing an accessibility pass. Each phase delivers observable improvements curators can use immediately.

## Milestones

- v1.0 Developer Experience (Phases 1-5) -- shipped 2026-01-21
- v2.0 Docker Infrastructure (Phases 6-9) -- shipped 2026-01-22
- v3.0 Frontend Modernization (Phases 10-17) -- shipped 2026-01-23
- v4.0 Backend Overhaul (Phases 18-24) -- shipped 2026-01-24
- v5.0 Analysis Modernization (Phases 25-27) -- shipped 2026-01-25
- v6.0 Admin Panel Modernization (Phases 28-33) -- shipped 2026-01-26
- **v7.0 Curation Workflow Modernization (Phases 34-39)** -- in progress

## Phases

- [x] **Phase 34: Critical Bug Fixes** - Fix blocking bugs that prevent basic curation operations
- [x] **Phase 35: Multi-Select Restoration** - Restore multi-select for phenotypes and variations using custom Bootstrap-Vue-Next TreeMultiSelect component
- [ ] **Phase 36: Curation Table Modernization** - Add filtering, pagination, and accessibility to curation tables
- [ ] **Phase 37: Form Modernization** - Extract reusable form composables and improve form UX
- [ ] **Phase 38: Re-Review System Overhaul** - Add dynamic batch management and gene-specific assignment
- [ ] **Phase 39: Accessibility Pass** - Ensure WCAG 2.2 AA compliance across all curation views

## Phase Details

### Phase 34: Critical Bug Fixes
**Goal**: Restore basic curation functionality by fixing blocking bugs
**Depends on**: Nothing (first phase of v7.0)
**Requirements**: BUG-01, BUG-02, BUG-03, BUG-04
**Success Criteria** (what must be TRUE):
  1. ApproveUser page loads without JavaScript errors and displays user list
  2. ModifyEntity status dropdown shows all status options when opened
  3. Component names in Vue DevTools match file names (no "ApproveStatus" for ManageReReview)
  4. Opening modal for different entity shows fresh data (not stale data from previous entity)
**Plans**: 2 plans

Plans:
- [x] 34-01-PLAN.md - Fix ApproveUser crash, component name, modal staleness (BUG-01, BUG-03, BUG-04)
- [x] 34-02-PLAN.md - Fix ModifyEntity dropdown, component names (BUG-02, BUG-03)

### Phase 35: Multi-Select Restoration
**Goal**: Restore multi-select capability for phenotypes and variations using custom TreeMultiSelect component built with Bootstrap-Vue-Next primitives (BFormTags, BDropdown, BCollapse, BFormCheckbox)
**Depends on**: Phase 34
**Requirements**: MSEL-01, MSEL-02, MSEL-03, MSEL-04
**Success Criteria** (what must be TRUE):
  1. User can select multiple phenotypes from hierarchical list in Review form
  2. User can select multiple variations from hierarchical list in Review form
  3. ModifyEntity and ApproveReview use same multi-select pattern
  4. vue3-treeselect is removed from package.json
**Plans**: 3 plans

Plans:
- [x] 35-01-PLAN.md - Create TreeMultiSelect component foundation (composables, TreeNode, TreeMultiSelect wrapper)
- [x] 35-02-PLAN.md - Integrate TreeMultiSelect into curation views (Review, ModifyEntity, ApproveReview)
- [x] 35-03-PLAN.md - Remove vue3-treeselect dependency and verify functionality

### Phase 36: Curation Table Modernization
**Goal**: Apply TablesEntities pattern to curation tables for consistent UX
**Depends on**: Phase 35
**Requirements**: TBL-01, TBL-02, TBL-03, TBL-04, TBL-05, TBL-06
**Success Criteria** (what must be TRUE):
  1. ApproveReview table has column filters (status, user, date range)
  2. ApproveStatus table has column filters (category, user, date range)
  3. All curation views use standardized pagination (10, 25, 50, 100 options)
  4. ManageReReview table has search functionality
  5. All curation action buttons have aria-label attributes and tooltips
**Plans**: TBD

Plans:
- [ ] 36-01: TBD

### Phase 37: Form Modernization
**Goal**: Extract reusable form patterns and improve form UX
**Depends on**: Phase 36
**Requirements**: FORM-01, FORM-02, FORM-03, FORM-04, FORM-05, FORM-06, FORM-07
**Success Criteria** (what must be TRUE):
  1. ModifyEntity shows entity preview (Gene, Disease, Inheritance) after ID entered
  2. ModifyEntity has search/autocomplete instead of numeric ID input
  3. Modification forms can save draft and resume later
  4. useReviewForm composable exists and is used in Review.vue
  5. ReviewFormFields component exists and renders synopsis, phenotypes, publications, variations
**Plans**: TBD

Plans:
- [ ] 37-01: TBD

### Phase 38: Re-Review System Overhaul
**Goal**: Enable dynamic batch creation and gene-specific assignment for re-review workflow
**Depends on**: Phase 37
**Requirements**: RRV-01, RRV-02, RRV-03, RRV-04, RRV-05, RRV-06, RRV-07
**Success Criteria** (what must be TRUE):
  1. Admin can create new re-review batches via UI with custom criteria (date range, gene list, status)
  2. Admin can assign specific genes to specific users for re-review
  3. Admin can recalculate/reassign batch contents based on updated criteria
  4. ManageReReview no longer filters by hardcoded 2020-01-01 date
  5. POST /api/re_review/batch/create endpoint works and creates batches
**Plans**: TBD

Plans:
- [ ] 38-01: TBD

### Phase 39: Accessibility Pass
**Goal**: Ensure WCAG 2.2 AA compliance across all curation interfaces
**Depends on**: Phase 38
**Requirements**: A11Y-01, A11Y-02, A11Y-03, A11Y-04, A11Y-05
**Success Criteria** (what must be TRUE):
  1. All icon-only action buttons in curation views have aria-label describing their action
  2. All action buttons have tooltips with title attributes
  3. All curation modals have proper header/title announcing their purpose
  4. Category and status icons have legend explaining what each icon means
  5. User can complete entire curation workflow using only keyboard (no mouse required)
**Plans**: TBD

Plans:
- [ ] 39-01: TBD

## Progress

**Execution Order:** Phases execute in numeric order: 34 -> 35 -> 36 -> 37 -> 38 -> 39

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 34. Critical Bug Fixes | v7.0 | 2/2 | Complete | 2026-01-26 |
| 35. Multi-Select Restoration | v7.0 | 3/3 | Complete | 2026-01-26 |
| 36. Curation Table Modernization | v7.0 | 0/TBD | Not started | - |
| 37. Form Modernization | v7.0 | 0/TBD | Not started | - |
| 38. Re-Review System Overhaul | v7.0 | 0/TBD | Not started | - |
| 39. Accessibility Pass | v7.0 | 0/TBD | Not started | - |

---
*Roadmap created: 2026-01-26*
*Last updated: 2026-01-26 -- Phase 35 plans revised for Bootstrap-Vue-Next only (no PrimeVue)*
