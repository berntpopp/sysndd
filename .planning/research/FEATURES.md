# Feature Landscape: Curation Workflow Modernization

**Domain:** Gene-disease entity curation for neurodevelopmental disorders database
**Milestone:** Curation Views Improvement (subsequent milestone)
**Researched:** 2026-01-26
**Confidence:** HIGH (based on ClinGen/ClinVar patterns + existing codebase analysis)

---

## Executive Summary

Scientific data curation interfaces require a balance between rigorous data quality controls and curator productivity. Based on analysis of ClinGen's Variant Curation Interface (the FDA-recognized standard for clinical genomics curation), general data curation best practices, and assessment of SysNDD's existing implementation, this document categorizes features for the curation workflow modernization milestone.

The existing SysNDD curation views include:
- **CreateEntity**: 5-step wizard (Gene, Disease, Inheritance, NDD, Evidence) with draft save/restore
- **ModifyEntity**: 4 actions (Rename, Deactivate, Modify review, Modify status)
- **ApproveReview**: Table with bulk approve, expandable rows, global search
- **ApproveStatus**: Status approval workflow table
- **ApproveUser**: User registration approval (BROKEN)
- **ManageReReview**: Batch assignment table for re-review workflow

---

## Table Stakes

Features users expect. Missing = product feels incomplete or unprofessional.

### 1. Form Validation and Error Handling

| Feature | Why Expected | Complexity | Current State | Notes |
|---------|--------------|------------|---------------|-------|
| Real-time field validation | Prevents submission errors, immediate feedback | Low | Partial - exists in CreateEntity wizard | Must validate on step transition and before submission |
| Clear error messages | Users need actionable guidance | Low | Basic - toast notifications only | Position errors near fields, not just in toasts |
| Required field indicators | Standard form pattern | Low | Missing in many places | Asterisks or visual cues for mandatory fields |
| Dropdown population | Empty dropdowns = broken UX | Low | **BROKEN** - ModifyEntity status dropdown empty | Critical fix needed - status_options not loading correctly |

**Reference:** [Multi-step form best practices](https://www.growform.co/must-follow-ux-best-practices-when-designing-a-multi-step-form/) - "Validate each step before proceeding to prevent users from encountering issues later."

### 2. Table Filtering and Sorting

| Feature | Why Expected | Complexity | Current State | Notes |
|---------|--------------|------------|---------------|-------|
| Column-specific filters | Standard for data tables | Medium | Missing on approval tables | ApproveReview only has global search |
| Sortable columns | Users expect to reorder data | Low | Partial - some tables have it | Needs consistent implementation |
| Clear sort indicators | Users need visual feedback | Low | Exists via Bootstrap-Vue | Ensure aria-sort for accessibility |
| Filter persistence | Don't lose filters on navigation | Medium | Missing | Store in URL params or session |

**Reference:** [Data Table Design UX Patterns](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables) - "Filtering and sorting are fundamental table interactions that users expect."

### 3. Pagination Controls

| Feature | Why Expected | Complexity | Current State | Notes |
|---------|--------------|------------|---------------|-------|
| Consistent pagination | Same pattern across all tables | Low | **INCONSISTENT** - varies by view | ApproveUser top, ApproveReview bottom |
| Page size selector | User preference accommodation | Low | Exists but inconsistent options | Standardize: 10, 25, 50, 100 |
| Total count display | Users need context | Low | Partial | "Showing 1-10 of 150 items" pattern |
| Server-side pagination | Required for large datasets | High | Missing - client-side only | TODO noted in ApproveReview code |

**Reference:** [ClinGen VCI](https://genomemedicine.biomedcentral.com/articles/10.1186/s13073-021-01004-8) uses server-side pagination for variant lists.

### 4. Accessibility Compliance

| Feature | Why Expected | Complexity | Current State | Notes |
|---------|--------------|------------|---------------|-------|
| ARIA labels on buttons | Screen reader support | Low | **MISSING** on action buttons | UX review finding |
| Focus indicators | Keyboard navigation | Low | Partial - Bootstrap defaults | Verify on all interactive elements |
| Accessible table structure | WCAG 2.2 compliance | Medium | Needs audit | Proper th/td scoping |
| Live region announcements | Dynamic content updates | Medium | Missing | Announce filter results, approvals |

**Reference:** [WCAG Tables Accessibility](https://testparty.ai/blog/wcag-tables-accessibility) - "Sortable columns need aria-sort attributes and button controls."

### 5. Loading States and Feedback

| Feature | Why Expected | Complexity | Current State | Notes |
|---------|--------------|------------|---------------|-------|
| Loading spinners | User knows action is processing | Low | Exists - BSpinner | Consistent across all async operations |
| Success/error feedback | Clear outcome communication | Low | Exists - toast system | Continue using |
| Disabled buttons during submit | Prevent double-submission | Low | Partial | Add to all submit actions |
| Optimistic updates | Responsive feel | Medium | Missing | Optional enhancement |

### 6. Working Approval Workflows

| Feature | Why Expected | Complexity | Current State | Notes |
|---------|--------------|------------|---------------|-------|
| User approval | Administrators approve new users | Low | **BROKEN** - ApproveUser F rating | Critical - blocks new curator onboarding |
| Role assignment during approval | Set user role on approval | Low | Exists but may not persist | Verify API call works |
| Review approval | Approve submitted reviews | Low | Works - ApproveReview | Keep working |
| Status approval | Approve status changes | Low | Works - ApproveStatus | Keep working |

---

## Differentiators

Features that set product apart. Not expected, but valued by curators.

### 1. Batch Operations

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| Bulk approve reviews | Massive time savings for curators | Medium | Exists in ApproveReview | "Approve all reviews" button works |
| Bulk status changes | Batch classification updates | High | Missing | ClinGen supports batch classification |
| Select-all with conditions | Smart batch selection | Medium | Missing | "Select all matching filter" pattern |
| Undo batch operations | Error recovery | High | Missing | Toast with undo button |

**Reference:** [Bulk Actions UX](https://www.eleken.co/blog-posts/bulk-actions-ux) - "Immediately offer a way to revert bulk actions with undo."

### 2. Advanced Workflow States

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| In-progress / Provisional / Approved states | ClinGen-style workflow tracking | Medium | Partial - review_approved flag | ClinGen VCI has 4 states |
| Status change indicators | Visual alerts for pending changes | Low | Exists - exclamation icon | Good implementation |
| Revision tracking | See what changed between versions | High | Missing | "New-Provisional" state in ClinGen |
| Conflict detection | Multiple curators on same entity | High | Exists - duplicate warning | Good implementation |

**Reference:** [ClinGen VCI Workflow](https://clinicalgenome.org/docs/variant-curation-standard-operating-procedure/) - "In-progress, Provisional, Approved, New-Provisional status progression."

### 3. Draft Save and Resume

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| Auto-save drafts | Never lose work | Medium | **EXISTS** in CreateEntity | useFormDraft composable |
| Draft recovery prompt | Seamless session recovery | Low | **EXISTS** in CreateEntity | Well implemented |
| Draft indicators | Know when data is saved | Low | **EXISTS** - last saved timestamp | Good implementation |
| Cross-session persistence | Long-form curation support | Low | Exists via localStorage | Good approach |

**This is a strength of the current implementation - preserve and extend to other forms.**

### 4. Dynamic Re-review Batch Creation

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| Create custom batches | Flexibility for administrators | High | **MISSING** - batches hardcoded | UX review finding |
| Batch criteria definition | Select entities by filter | High | Missing | Could use existing filter system |
| Batch size configuration | Control workload distribution | Medium | Missing | Fixed batch sizes currently |
| Batch progress tracking | Monitor completion | Low | Exists - counts in table | Good implementation |

### 5. Inline Editing

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| Quick status edits in table | Reduce modal interactions | Medium | Missing | Could reduce clicks significantly |
| Inline comments | Fast annotation | Medium | Missing | Hover to edit pattern |
| Cell-level editing | Direct manipulation | High | Missing | Complex but powerful |

**Reference:** [DataTables Bulk Editing](https://datatables.net/blog/2015-09-11) - "Allow some fields to retain individual values while others are batch-updated."

### 6. Advanced Search and Autocomplete

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| Async entity search | Find entities by gene/disease | Medium | **DISABLED** - treeselect issues | TODO comments throughout code |
| Typeahead suggestions | Fast data entry | Medium | Disabled | Was working, Vue 3 migration issue |
| Recent searches | Productivity boost | Low | Missing | Store last 5-10 searches |
| Saved searches/filters | Workflow personalization | Medium | Missing | URL-based filters would enable this |

### 7. Audit Trail Visibility

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| View change history | Accountability and traceability | Medium | Backend exists, UI missing | Show who changed what when |
| Compare versions | See what changed | High | Missing | Side-by-side diff |
| Revert capability | Error correction | High | Missing | Controlled rollback |

**Reference:** [Audit Trail Best Practices](https://www.openclinica.com/blog/audit-trails-transparency-tracking-changes-in-clinical-data/) - "Audit trails ensure data integrity and regulatory compliance."

---

## Anti-Features

Features to explicitly NOT build. Common mistakes in this domain.

### 1. Overly Complex Approval Chains

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Multi-level approval hierarchies | Adds friction, slows curation | Single reviewer + curator approval model (current approach is correct) |
| Approval by committee votes | Scheduling nightmare | Expert panel model with designated approvers |
| Automated approval | Loses human judgment value | Keep human-in-the-loop for all classifications |

**Rationale:** ClinGen found that streamlined approval with clear accountability produces better outcomes than bureaucratic chains.

### 2. Real-time Collaborative Editing

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Google Docs-style co-editing | Complexity > benefit for curation | Sequential editing with conflict detection |
| Live cursor positions | Distracting for focused work | Show who's currently viewing/editing |
| Instant sync | Race conditions in data integrity | Save-and-refresh model |

**Rationale:** Scientific curation requires focused attention, not collaborative chaos. Current conflict detection (duplicate warning) is the right approach.

### 3. AI-Automated Classification

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| ML-driven status assignment | Accountability and reproducibility | AI can suggest, humans must approve |
| Automated literature extraction | Error-prone for edge cases | AI-assisted with curator verification |
| Black-box recommendations | Regulatory compliance requires traceability | Transparent evidence-based classification |

**Reference:** [LLM-assisted curation tools](https://www.tandfonline.com/doi/full/10.1080/27660400.2025.2590811) - "LLMs cannot yet replace the flexible judgment of human curators."

### 4. Complex Permission Matrices

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Field-level permissions | Maintenance nightmare | Role-based access (Curator, Reviewer, Admin) |
| Custom permission sets | Configuration debt | Predefined roles with clear capabilities |
| Per-entity permissions | Unmanageable at scale | Collection-level access controls |

**Rationale:** SysNDD's simple role model (Curator, Reviewer, Administrator) is appropriate for team size and use case.

### 5. Excessive Customization

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Customizable form fields | Data inconsistency | Standardized curation schema |
| User-defined workflows | Training overhead | Consistent workflow for all curators |
| Theme customization | Distraction from curation | Professional, accessible defaults |

### 6. Over-Engineering the Treeselect Replacement

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Custom multi-level tree component | High complexity, maintenance burden | Use existing BFormSelect with optgroups |
| Virtual scrolling tree | Overkill for current data volume | Standard select is sufficient |
| Drag-and-drop tree editing | Feature creep | Not needed for selection use case |

**Rationale:** The treeselect was disabled due to Vue 3 compatibility issues. A simpler BFormSelect approach already works in the codebase - extend this pattern rather than rebuilding treeselect.

---

## Feature Dependencies

```
Authentication & Roles (EXISTS)
    |
    v
User Approval (BROKEN - must fix first)
    |
    v
Entity Creation (EXISTS - CreateEntity wizard)
    |
    +---> Review Submission (EXISTS)
    |         |
    |         v
    +---> Review Approval (EXISTS - ApproveReview)
    |         |
    |         +---> Status Assignment
    |         |         |
    |         |         v
    |         +---> Status Approval (EXISTS - ApproveStatus)
    |
    +---> Entity Modification (EXISTS - ModifyEntity)
              |
              +---> Disease Rename
              +---> Deactivation
              +---> Review Modification
              +---> Status Modification (BROKEN - empty dropdown)

Re-review Workflow (EXISTS - ManageReReview)
    |
    +---> Batch Assignment (EXISTS)
    +---> Batch Creation (MISSING - hardcoded)
```

### Critical Dependencies for Fixes

1. **ApproveUser** depends on:
   - API endpoint `/api/user/table` returning pending users
   - Role options loading from `/api/user/role_list`
   - Correct modal behavior for approval

2. **ModifyEntity status dropdown** depends on:
   - `loadStatusList()` being called on mount
   - `status_options` array populating before modal opens
   - `normalizeStatusOptions()` returning correct format

3. **Column filters** depend on:
   - Bootstrap-Vue-Next filter capabilities
   - Field configuration with `filterable: true`

---

## MVP Recommendation

For the curation modernization milestone, prioritize:

### Must Fix (Broken Functionality) - P0

| Priority | Feature | Complexity | Impact |
|----------|---------|------------|--------|
| P0 | **ApproveUser view** | Medium | Cannot approve new users - blocks curator onboarding |
| P0 | **ModifyEntity status dropdown** | Low | Empty dropdown prevents status changes |
| P0 | **Accessibility labels** | Low | WCAG compliance requirement |

### Should Improve (Table Stakes Gaps) - P1

| Priority | Feature | Complexity | Impact |
|----------|---------|------------|--------|
| P1 | Column filters on approval tables | Medium | Expected UX, improves curator efficiency |
| P1 | Consistent pagination | Low | Professional UX, reduces confusion |
| P1 | Restore async search | Medium | Treeselect replacement needed for entity/disease search |

### Nice to Have (Differentiators) - P2

| Priority | Feature | Complexity | Impact |
|----------|---------|------------|--------|
| P2 | Dynamic batch creation | High | ManageReReview enhancement |
| P2 | Batch undo operations | High | Error recovery for bulk actions |
| P2 | Filter persistence | Medium | Productivity enhancement |
| P2 | Audit trail UI | Medium | Accountability visibility |

### Defer to Post-MVP

- **Inline editing** - High complexity, moderate benefit
- **Server-side pagination** - Requires backend changes
- **Revision tracking** - Major feature addition
- **Compare versions** - Complex UI/UX

---

## Implementation Notes from Codebase Analysis

### ApproveUser Issues Identified

```vue
// Line 146: Component name is wrong
name: 'ApproveStatus',  // Should be 'ApproveUser'

// Line 232: API call to approve user
const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/approval?user_id=${this.approve_user[0].user_id}&status_approval=${this.user_approved}`;
// Need to verify this endpoint works and handles role assignment
```

### ModifyEntity Status Dropdown Issue

```vue
// Line 696-703: loadStatusList() exists and is called
async loadStatusList() {
  const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/status?tree=true`;
  // ...
  this.status_options = response.data;
}

// Line 560-572: BFormSelect expects normalizeStatusOptions()
<BFormSelect
  v-if="status_options && status_options.length > 0"
  id="status-select"
  v-model="status_info.category_id"
  :options="normalizeStatusOptions(status_options)"
  size="sm"
>
// Issue: status_options may be empty or normalizeStatusOptions may fail
```

### Treeselect Replacement Pattern (already working in CreateEntity)

```vue
// CreateEntity uses BFormSelect with optgroups successfully
// Pattern to follow for ModifyEntity and ApproveReview
<BFormSelect
  v-if="phenotypeOptions && phenotypeOptions.length > 0"
  id="review-phenotype-select"
  v-model="select_phenotype[0]"
  :options="normalizePhenotypesOptions(phenotypes_options)"
  size="sm"
>
```

---

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| Table Stakes | HIGH | Based on established UX patterns, WCAG standards, ClinGen VCI |
| Differentiators | HIGH | Based on ClinGen documentation, curation tool research |
| Anti-Features | MEDIUM | Based on domain knowledge, some inference |
| Dependencies | HIGH | Based on codebase analysis of existing views |
| MVP Priorities | HIGH | Based on UX review findings + severity assessment |
| Implementation Notes | HIGH | Based on direct code reading |

---

## Sources

### Primary (HIGH confidence)
- [ClinGen Variant Curation Interface](https://genomemedicine.biomedcentral.com/articles/10.1186/s13073-021-01004-8) - FDA-recognized curation platform
- [ClinGen Variant Curation SOP](https://clinicalgenome.org/docs/variant-curation-standard-operating-procedure/)
- [ClinGen Overview](https://pmc.ncbi.nlm.nih.gov/articles/PMC11984750/)
- SysNDD codebase analysis (existing views: ApproveUser.vue, ApproveReview.vue, ApproveStatus.vue, CreateEntity.vue, ModifyEntity.vue, ManageReReview.vue)

### Secondary (MEDIUM confidence)
- [Data Table Design UX Patterns](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables)
- [Bulk Actions UX Guidelines](https://www.eleken.co/blog-posts/bulk-actions-ux)
- [Multi-step Form Best Practices](https://www.growform.co/must-follow-ux-best-practices-when-designing-a-multi-step-form/)
- [WCAG Tables Accessibility](https://testparty.ai/blog/wcag-tables-accessibility)
- [Adrian Roselli: Sortable Table Columns](https://adrianroselli.com/2021/04/sortable-table-columns.html)
- [Audit Trail Best Practices](https://www.openclinica.com/blog/audit-trails-transparency-tracking-changes-in-clinical-data/)

### Tertiary (LOW confidence - general patterns)
- [Data Curation Best Practices](https://research.aimultiple.com/data-curation/)
- [LLM-assisted Curation Tools Study](https://www.tandfonline.com/doi/full/10.1080/27660400.2025.2590811)
- [DAQCORD Guidelines](https://pmc.ncbi.nlm.nih.gov/articles/PMC7681114/)

---

*Research completed: 2026-01-26*
*Confidence: HIGH (ClinGen patterns verified, codebase analyzed)*
*Researcher: GSD Project Researcher (Features dimension - Curation Workflow)*
