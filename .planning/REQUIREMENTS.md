# Requirements: SysNDD v7.0 Curation Workflow Modernization

**Defined:** 2026-01-26
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v7 Requirements

Requirements for v7.0 milestone grouped by category. Each maps to roadmap phases.

### Bug Fixes

- [x] **BUG-01**: Fix ApproveUser page crash (TypeError: reduce is not a function)
- [x] **BUG-02**: Fix ModifyEntity status dropdown showing empty options
- [x] **BUG-03**: Fix component name mismatches (ManageReReview has name "ApproveStatus")
- [x] **BUG-04**: Fix modal data staleness (form not reset when opening for different entity)

### Multi-Select Restoration

- [ ] **MSEL-01**: Restore multi-select for phenotypes using custom TreeMultiSelect component (Bootstrap-Vue-Next primitives: BFormTags, BDropdown, BCollapse, BFormCheckbox)
- [ ] **MSEL-02**: Restore multi-select for variations using custom TreeMultiSelect component (Bootstrap-Vue-Next primitives: BFormTags, BDropdown, BCollapse, BFormCheckbox)
- [ ] **MSEL-03**: Update all curation views to use new multi-select pattern (Review, ModifyEntity, ApproveReview)
- [ ] **MSEL-04**: Remove vue3-treeselect dependency after migration complete

### Curation Table Improvements

- [ ] **TBL-01**: Add column filters to ApproveReview table (status, user, date range)
- [ ] **TBL-02**: Add column filters to ApproveStatus table (category, user, date range)
- [ ] **TBL-03**: Standardize pagination options across all curation views (10, 25, 50, 100)
- [ ] **TBL-04**: Add search functionality to ManageReReview table
- [ ] **TBL-05**: Add accessibility labels (aria-label) to all curation action buttons
- [ ] **TBL-06**: Add tooltips to icon-only buttons in curation tables

### Form Modernization

- [ ] **FORM-01**: Add entity preview in ModifyEntity (show Gene, Disease, Inheritance after ID entered)
- [ ] **FORM-02**: Add entity search/autocomplete in ModifyEntity (replace numeric ID input)
- [ ] **FORM-03**: Implement draft save/resume for modification forms (localStorage pattern from CreateEntity)
- [ ] **FORM-04**: Extract reusable useReviewForm composable from Review.vue
- [ ] **FORM-05**: Extract reusable useStatusForm composable from status modification logic
- [ ] **FORM-06**: Create ReviewFormFields component (synopsis, phenotypes, publications, variations)
- [ ] **FORM-07**: Reset forms on modal @show event (not just @hide)

### Re-Review System Overhaul

- [ ] **RRV-01**: Create re-review-service.R with batch management functions
- [ ] **RRV-02**: Add API endpoint POST /api/re_review/batch/create for dynamic batch creation
- [ ] **RRV-03**: Add API endpoint PUT /api/re_review/entities/assign for gene-specific user assignment
- [ ] **RRV-04**: Add batch criteria selection UI to ManageReReview (date range, gene list, status filter)
- [ ] **RRV-05**: Add batch recalculation capability (re-assign entities to batches based on criteria)
- [ ] **RRV-06**: Add gene-specific assignment UI (select specific genes for specific user)
- [ ] **RRV-07**: Remove hardcoded batch filter date (2020-01-01) from re_review_endpoints.R

### Accessibility

- [ ] **A11Y-01**: Add aria-label to all icon-only action buttons in curation views
- [ ] **A11Y-02**: Add tooltips with title attributes to all action buttons
- [ ] **A11Y-03**: Add modal headers/titles to all curation modals
- [ ] **A11Y-04**: Add legend/explanation for category and status icons
- [ ] **A11Y-05**: Verify keyboard navigation works in all curation forms

## Future Requirements (v8+)

### Advanced Features

- **ADV-01**: Inline editing in approval tables
- **ADV-02**: Server-side pagination for large datasets
- **ADV-03**: Revision tracking and version comparison for entities
- **ADV-04**: Batch undo operations
- **ADV-05**: LLM-assisted curation suggestions

## Out of Scope

| Feature | Reason |
|---------|--------|
| PrimeVue TreeSelect | User explicitly rejected; using Bootstrap-Vue-Next only to maintain consistency |
| External tree libraries | Building custom component with existing Bootstrap-Vue-Next primitives |
| Full Options API to Composition API migration | Incremental hybrid approach sufficient |
| Server-side pagination | Requires significant backend changes, defer to v8 |
| Real-time collaboration | Complex implementation, not needed for current user base |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUG-01 | Phase 34 | Complete |
| BUG-02 | Phase 34 | Complete |
| BUG-03 | Phase 34 | Complete |
| BUG-04 | Phase 34 | Complete |
| MSEL-01 | Phase 35 | Pending |
| MSEL-02 | Phase 35 | Pending |
| MSEL-03 | Phase 35 | Pending |
| MSEL-04 | Phase 35 | Pending |
| TBL-01 | Phase 36 | Pending |
| TBL-02 | Phase 36 | Pending |
| TBL-03 | Phase 36 | Pending |
| TBL-04 | Phase 36 | Pending |
| TBL-05 | Phase 36 | Pending |
| TBL-06 | Phase 36 | Pending |
| FORM-01 | Phase 37 | Pending |
| FORM-02 | Phase 37 | Pending |
| FORM-03 | Phase 37 | Pending |
| FORM-04 | Phase 37 | Pending |
| FORM-05 | Phase 37 | Pending |
| FORM-06 | Phase 37 | Pending |
| FORM-07 | Phase 37 | Pending |
| RRV-01 | Phase 38 | Pending |
| RRV-02 | Phase 38 | Pending |
| RRV-03 | Phase 38 | Pending |
| RRV-04 | Phase 38 | Pending |
| RRV-05 | Phase 38 | Pending |
| RRV-06 | Phase 38 | Pending |
| RRV-07 | Phase 38 | Pending |
| A11Y-01 | Phase 39 | Pending |
| A11Y-02 | Phase 39 | Pending |
| A11Y-03 | Phase 39 | Pending |
| A11Y-04 | Phase 39 | Pending |
| A11Y-05 | Phase 39 | Pending |

**Coverage:**
- v7 requirements: 32 total
- Mapped to phases: 32
- Unmapped: 0

---
*Requirements defined: 2026-01-26*
*Last updated: 2026-01-26 -- MSEL-01/MSEL-02 updated for Bootstrap-Vue-Next custom component approach*
