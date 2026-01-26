# Project Research Summary

**Project:** SysNDD v7.0 Curation Workflow Modernization
**Domain:** Scientific database curation interface for neurodevelopmental disorders
**Researched:** 2026-01-26
**Confidence:** HIGH

## Executive Summary

SysNDD v7.0 targets modernization of curation workflows for a gene-disease database. The research reveals that the existing stack (Vue 3.5.25, Bootstrap-Vue-Next, TypeScript) is solid and requires only one addition: PrimeVue TreeSelect in unstyled mode to replace the broken vue3-treeselect multi-select functionality. The codebase already contains excellent patterns (FormWizard, useEntityForm, provide/inject state management) that should be extracted and reused rather than introducing new libraries. Critical bugs in ApproveUser and ModifyEntity status dropdown must be fixed before any other modernization work proceeds.

The recommended approach centers on incremental modernization: fix broken functionality first, then extract reusable form components from existing patterns, and finally overhaul the re-review batch system with dynamic management capabilities. The architecture research identified that re-review batches are currently hardcoded via R scripts with fixed 20-gene groupings, preventing dynamic batch creation and gene-specific assignment. Form logic is duplicated across Review.vue, ModifyEntity.vue, and CreateEntity, presenting an opportunity for extraction into shared composables and components.

Key risks center on API response format mismatches causing TypeErrors, modal state staleness after form cancellation, and breaking working legacy code during modernization. The pitfalls research identified specific defensive patterns already working in ManageUser.vue that should be applied to curation views. Test coverage at 20.3% means regressions may go undetected, requiring careful incremental changes with thorough manual testing.

## Key Findings

### Recommended Stack

The existing stack requires minimal additions. Vue 3.5.25 with Composition API, Bootstrap-Vue-Next 0.42.0, TypeScript 5.9.3, and VeeValidate 4.15.1 provide all necessary capabilities. The only new dependency is PrimeVue 4.5.4 for TreeSelect component.

**Core technologies:**
- **PrimeVue TreeSelect (NEW):** Hierarchical multi-select for phenotypes/variations -- replaces broken vue3-treeselect with ARIA-compliant, unstyled mode component (~20KB gzipped)
- **Existing FormWizard pattern:** Extract to generic useFormWizard composable -- no new wizard library needed
- **Existing AutocompleteInput:** Extend with preview slot and clear button -- no new autocomplete library needed
- **Bootstrap-Vue-Next BFormSelect:** Use native optgroups for hierarchical single-select -- already working

### Expected Features

**Must have (table stakes):**
- Working ApproveUser view -- currently crashes, blocks curator onboarding
- Working ModifyEntity status dropdown -- currently empty, blocks status changes
- Accessibility labels on all action buttons -- WCAG 2.2 AA requirement
- Column filters on approval tables -- expected UX pattern
- Consistent pagination across all curation views (10, 25, 50, 100)

**Should have (competitive):**
- Restore multi-select for phenotypes/variations -- currently degraded to single-select
- Dynamic re-review batch creation -- currently hardcoded
- Gene-specific assignment for re-review -- currently batch-level only
- Draft save/resume for modification forms -- pattern exists in CreateEntity

**Defer (v2+):**
- Inline editing in tables -- high complexity, moderate benefit
- Server-side pagination -- requires backend changes
- Revision tracking and version comparison -- major feature addition
- Batch undo operations -- complex implementation

### Architecture Approach

The architecture should add dynamic batch management at the backend while extracting reusable form components at the frontend. The CreateEntity wizard already demonstrates the target pattern: provide/inject for form state sharing, composables for validation logic, and step components for modular UI. This pattern should be extended to Review.vue and ModifyEntity.vue through new composables (useReviewForm, useStatusForm) and components (ReviewFormFields, StatusFormFields, CurationFormProvider).

**Major components:**

1. **re-review-service.R (NEW)** -- Dynamic batch creation, gene-specific assignment, batch recalculation
2. **useReviewForm.ts (NEW)** -- Extracted review form state/validation from Review.vue
3. **useStatusForm.ts (NEW)** -- Extracted status form state/validation
4. **CurationFormProvider.vue (NEW)** -- Provide/inject wrapper for curation form state
5. **ReviewFormFields.vue (NEW)** -- Reusable review form UI (synopsis, phenotypes, publications)
6. **TreeMultiSelect.vue (NEW)** -- PrimeVue TreeSelect wrapper with Bootstrap styling

### Critical Pitfalls

1. **API Response Format Mismatch** -- ApproveUser assumes `response.data` is array, crashes if API returns paginated wrapper. Fix: Add `Array.isArray()` check, use defensive data extraction pattern from ManageUser.vue.

2. **vue3-treeselect Multi-Select Bug** -- Documented issue #4 where multi-select crashes on v-model initialization. Fix: Replace with PrimeVue TreeSelect in unstyled mode.

3. **Empty Dropdown Race Condition** -- ModifyStatus dropdown empty because options load after modal renders. Fix: Load options before showing modal, add loading state guard.

4. **Hardcoded Re-Review Batches** -- Batches created via R script with fixed 20-gene groupings, no dynamic creation. Fix: Add batch creation API endpoints and UI.

5. **Modal Data Staleness** -- Form data not reset when modal opens for different entity, causing data corruption. Fix: Reset on modal `@show`, not just `@hide`.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Critical Bug Fixes
**Rationale:** Broken functionality blocks all other work. ApproveUser prevents curator onboarding, ModifyStatus dropdown prevents status changes.
**Delivers:** Working ApproveUser page, working ModifyEntity status dropdown, correct component names
**Addresses:** P0 broken functionality from FEATURES.md
**Avoids:** Pitfall 1 (API response mismatch), Pitfall 3 (empty dropdown), Pitfall 9 (component names)
**Complexity:** Low-Medium
**Suggested tasks:**
- Add defensive data checks to ApproveUser API response handling
- Fix loadStatusList() race condition with loading state
- Fix component names (ApproveUser, ModifyEntity, ManageReReview)

### Phase 2: PrimeVue TreeSelect Integration
**Rationale:** Restoring multi-select is prerequisite for proper curation workflow. Current single-select workaround degrades data quality.
**Delivers:** Working multi-select for phenotypes and variations
**Uses:** PrimeVue TreeSelect (unstyled mode), Bootstrap PT props
**Implements:** TreeMultiSelect.vue wrapper component
**Avoids:** Pitfall 2 (vue3-treeselect bug)
**Complexity:** Medium
**Suggested tasks:**
- Install PrimeVue, configure unstyled mode
- Create TreeMultiSelect.vue with Bootstrap styling
- Update StepPhenotypeVariation to use TreeMultiSelect
- Update ModifyEntity phenotype/variation selects

### Phase 3: Curation Table Modernization
**Rationale:** Approval tables need consistent UX patterns (filtering, pagination, accessibility) before form modernization.
**Delivers:** Consistent ApproveUser, ApproveReview, ApproveStatus with TablesEntities pattern
**Addresses:** Column filters, pagination consistency, accessibility labels from FEATURES.md
**Avoids:** Pitfall 5 (pagination inconsistency), Pitfall 8 (missing aria-labels)
**Complexity:** Medium
**Suggested tasks:**
- Standardize pagination options (10, 25, 50, 100)
- Add column filters to approval tables
- Add aria-labels to all action buttons
- Consider hybrid Options API + Composition API with composables

### Phase 4: Reusable Form Components
**Rationale:** Extract common patterns before ModifyEntity and Review modernization to avoid duplication.
**Delivers:** useReviewForm, useStatusForm composables; ReviewFormFields, StatusFormFields components
**Implements:** CurationFormProvider with provide/inject pattern
**Avoids:** Pitfall 7 (Options API incompatibility with composables)
**Complexity:** Medium-High
**Suggested tasks:**
- Extract useReviewForm from Review.vue patterns
- Extract useStatusForm from ModifyEntity patterns
- Create ReviewFormFields with synopsis, phenotypes, publications
- Create CurationFormProvider wrapper

### Phase 5: ModifyEntity and Review Modernization
**Rationale:** Apply reusable components to existing views, fix modal staleness issues.
**Delivers:** Modernized ModifyEntity with TreeMultiSelect, modernized Review with reusable components
**Uses:** Components from Phase 4
**Avoids:** Pitfall 6 (modal staleness), Pitfall 11 (breaking legacy code)
**Complexity:** High
**Suggested tasks:**
- Refactor ModifyEntity modals to use CurationFormProvider
- Refactor Review modals to use ReviewFormFields
- Reset forms on modal @show
- Add integration tests before refactoring

### Phase 6: Re-Review System Overhaul
**Rationale:** Dynamic batch management is differentiator feature, requires backend and frontend work.
**Delivers:** Dynamic batch creation, gene-specific assignment, batch criteria UI
**Implements:** re-review-service.R, ManageReReview batch creation UI
**Avoids:** Pitfall 4 (hardcoded batches)
**Complexity:** High
**Suggested tasks:**
- Add re-review-service.R with svc_re_review_create_batch
- Add POST /batch/create endpoint
- Add PUT /entities/assign endpoint for gene-specific assignment
- Add batch criteria builder UI to ManageReReview

### Phase 7: Accessibility Pass
**Rationale:** Final audit to ensure WCAG 2.2 AA compliance across all modernized curation views.
**Delivers:** Full accessibility compliance, Lighthouse 100 score
**Addresses:** All accessibility gaps from FEATURES.md
**Complexity:** Low-Medium
**Suggested tasks:**
- Systematic audit of all buttons for aria-labels
- Verify live region announcements
- Test keyboard navigation
- Run axe-core validation

### Phase Ordering Rationale

- **Critical bugs first (Phase 1):** Cannot test modernization if basic functionality is broken
- **TreeSelect before forms (Phase 2):** Multi-select is used throughout form components
- **Tables before forms (Phase 3):** Establishes consistent UX patterns
- **Reusable components before view updates (Phase 4):** Avoids duplication during modernization
- **ModifyEntity/Review together (Phase 5):** Share same form components
- **Re-review system last for new features (Phase 6):** Most complex, builds on all prior work
- **Accessibility as final pass (Phase 7):** Ensures nothing was missed

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** PrimeVue TreeSelect PT props may need experimentation for Bootstrap integration
- **Phase 6:** Backend batch management requires understanding R/Plumber patterns and database constraints

Phases with standard patterns (skip research-phase):
- **Phase 1:** Bug fixes with clear cause and solution from pitfalls analysis
- **Phase 3:** Standard table modernization following established TablesEntities pattern
- **Phase 4:** Direct extraction from existing CreateEntity patterns
- **Phase 7:** Standard accessibility audit procedures

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | PrimeVue verified via npm (331K weekly downloads), unstyled mode documented |
| Features | HIGH | Based on ClinGen VCI patterns and direct codebase analysis |
| Architecture | HIGH | Based on extensive codebase examination, existing patterns identified |
| Pitfalls | HIGH | Direct observation in code, documented bugs (vue3-treeselect #4) |

**Overall confidence:** HIGH

### Gaps to Address

- **Test coverage:** At 20.3%, regressions may not be caught automatically. Add integration tests for critical workflows before refactoring.
- **Backend batch API:** Exact endpoint signatures need validation during Phase 6 implementation.
- **PrimeVue TreeSelect PT customization:** May require iteration to achieve exact Bootstrap styling match.

## Sources

### Primary (HIGH confidence)
- SysNDD codebase analysis -- ApproveUser.vue, ModifyEntity.vue, Review.vue, ManageReReview.vue, CreateEntity.vue, useEntityForm.ts
- [PrimeVue TreeSelect](https://primevue.org/treeselect/) -- Official documentation for component API and accessibility
- [PrimeVue Pass Through](https://primevue.org/passthrough/) -- Custom class styling approach
- [vue3-treeselect Issue #4](https://github.com/megafetis/vue3-treeselect/issues/4) -- Documented multi-select bug
- [ClinGen VCI](https://genomemedicine.biomedcentral.com/articles/10.1186/s13073-021-01004-8) -- FDA-recognized curation platform patterns

### Secondary (MEDIUM confidence)
- [Data Table UX Patterns](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables) -- Table filtering and sorting standards
- [WCAG Tables Accessibility](https://testparty.ai/blog/wcag-tables-accessibility) -- Accessibility requirements
- [Multi-step Form Best Practices](https://www.growform.co/must-follow-ux-best-practices-when-designing-a-multi-step-form/) -- Wizard patterns

### Tertiary (LOW confidence)
- [LLM-assisted Curation Tools](https://www.tandfonline.com/doi/full/10.1080/27660400.2025.2590811) -- AI curation considerations (anti-feature validation)

---
*Research completed: 2026-01-26*
*Ready for roadmap: yes*
