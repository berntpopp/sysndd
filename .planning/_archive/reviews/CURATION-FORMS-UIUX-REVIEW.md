# Curation Forms UI/UX Review Report

**Date:** 2026-01-24
**Reviewer:** Claude (UI/UX Analysis)
**Scope:** ModifyEntity, ApproveReview, ApproveStatus, ApproveUser, ManageReReview
**Reference:** CreateEntity (refactored), Entities table

---

## Executive Summary

This report provides a comprehensive UI/UX evaluation of SysNDD's curation forms. The review identifies critical bugs, accessibility issues, and inconsistencies across the application. The refactored **CreateEntity** page serves as an excellent benchmark, demonstrating modern UX patterns that should be applied to other curation views.

### Overall Ratings

| Page | Functionality | UX/UI Design | Accessibility | Consistency | Overall |
|------|--------------|--------------|---------------|-------------|---------|
| CreateEntity (Reference) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | **A** |
| Entities Table (Reference) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | **A-** |
| ModifyEntity | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐ | **C** |
| ApproveReview | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | **B-** |
| ApproveStatus | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | **B-** |
| ApproveUser | ⭐ | ⭐ | ⭐ | ⭐ | **F** |
| ManageReReview | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | **B-** |

---

## Reference Standards

### CreateEntity (Gold Standard) ✅

The refactored CreateEntity page demonstrates excellent UX patterns:

**Strengths:**
- ✅ Multi-step wizard with clear progress indicator (5 numbered steps)
- ✅ Clear visual hierarchy with step titles and descriptions
- ✅ Required field indicators (red asterisks)
- ✅ Helpful inline descriptions for each field
- ✅ Auto-save draft functionality with restoration option
- ✅ Clear navigation with "Next: [Step Name]" button
- ✅ Disabled state for incomplete forms
- ✅ Radio buttons with explanatory text for binary choices

**Key UX Patterns to Replicate:**
1. Step-by-step wizards for complex workflows
2. Required field indicators
3. Inline help text
4. Draft auto-save
5. Clear form validation feedback

### Entities Table (Reference for Tables) ✅

**Strengths:**
- ✅ Full pagination (first, prev, page numbers, next, last)
- ✅ Per-page selector (10, 25, 50, 100)
- ✅ Global search box
- ✅ Column-specific filters (text inputs and dropdowns)
- ✅ Sortable columns with visual indicators
- ✅ Export functionality (.xlsx)
- ✅ Total count displayed ("Entities: 4116")

---

## Page-by-Page Review

### 1. ModifyEntity

**URL:** `/ModifyEntity`
**Rating:** C (Needs Significant Improvement)

#### Screenshots
- `modifyentity-initial.png` - Initial state
- `modifyentity-with-entity.png` - After selecting entity
- `modifyentity-modify-review-modal.png` - Modify Review modal
- `modifyentity-rename-disease-modal.png` - Rename Disease modal
- `modifyentity-deactivate-modal.png` - Deactivate modal
- `modifyentity-modify-status-modal.png` - Modify Status modal

#### Current State
- Two-step workflow: Select entity ID → Choose modification action
- Four action buttons: Rename disease, Deactivate entity, Modify review, Modify status

#### Issues Found

| Issue | Severity | Description |
|-------|----------|-------------|
| 🔴 **Critical Bug** | High | Modify Status dropdown shows empty options - status values not displaying |
| 🟠 **UX Issue** | Medium | Deactivate dialog has confusing checkbox labeled "No" instead of confirmation buttons |
| 🟠 **UX Issue** | Medium | No visual feedback showing current entity details before modification |
| 🟡 **Consistency** | Low | Step numbering ("1.", "2.") inconsistent with CreateEntity wizard style |
| 🟡 **UX Issue** | Low | Entity ID input is a spinbutton - no autocomplete/search functionality |
| 🟡 **Accessibility** | Low | Modal headers are empty (no title) |

#### Recommendations

1. **Fix Critical Bug:** Debug the status dropdown to ensure options are populated correctly
2. **Improve Deactivate Dialog:** Replace checkbox with clear Yes/No buttons or a confirmation pattern
3. **Add Entity Preview:** Show entity details (Gene, Disease, Inheritance) after ID is entered
4. **Implement Search:** Add entity search/autocomplete instead of just ID input
5. **Add Modal Titles:** Include descriptive titles like "Modify Review for sysndd:4"
6. **Consider Wizard Pattern:** Align with CreateEntity's multi-step approach

---

### 2. ApproveReview

**URL:** `/ApproveReview`
**Rating:** B- (Good Foundation, Needs Polish)

#### Screenshots
- `approvereview-main.png` - Main table view
- `approvereview-expanded.png` - Expanded row detail

#### Current State
- Table with bulk "Approve all reviews" action
- Global search, per-page selector, pagination
- Expandable rows showing review details
- Inline editable Synopsis and Comment fields
- Action buttons for each row

#### Issues Found

| Issue | Severity | Description |
|-------|----------|-------------|
| 🟠 **Accessibility** | High | Action buttons have no accessible labels (empty aria-label/text) |
| 🟠 **UX Issue** | Medium | Missing "Go to last page" pagination button |
| 🟠 **Consistency** | Medium | No column-specific filters (unlike Entities table) |
| 🟡 **UX Issue** | Low | Action icons require hovering to understand function |
| 🟡 **Consistency** | Low | Per-page options (10, 25, 50, 200) differ from Entities (10, 25, 50, 100) |
| 🟡 **UX Issue** | Low | Column headers truncated with "..." |

#### Positive Aspects
- ✅ Expandable row detail pattern works well
- ✅ Inline editing for Synopsis and Comment
- ✅ Clear visual distinction for status badges
- ✅ Bulk action button for efficiency

#### Recommendations

1. **Add Button Labels:** Include text or tooltips on action buttons (View, Edit, Approve, Reject)
2. **Add Column Filters:** Match Entities table filtering capability
3. **Standardize Pagination:** Add "Go to last page" button
4. **Button Tooltips:** Add title attributes for icon-only buttons
5. **Consistent Per-Page Options:** Use same options as Entities table

---

### 3. ApproveStatus

**URL:** `/ApproveStatus`
**Rating:** B- (Similar to ApproveReview)

#### Screenshots
- `approvestatus-main.png` - Main table view

#### Current State
- Very similar layout to ApproveReview
- Columns: Entity, Gene, Disease, Inheritance, Category, Comment, Problematic, Status date, User, Actions
- Category and Problematic columns show icon indicators

#### Issues Found

| Issue | Severity | Description |
|-------|----------|-------------|
| 🟠 **Accessibility** | High | Action buttons have no accessible labels |
| 🟠 **UX Issue** | Medium | Category column shows only icon, no text label |
| 🟠 **UX Issue** | Medium | Problematic column shows green dot without explanation |
| 🟠 **Consistency** | Medium | No column-specific filters |
| 🟡 **UX Issue** | Low | Icon-only columns may confuse new users |

#### Recommendations

1. **Add Icon Legends:** Include tooltips or a legend explaining category/status icons
2. **Add Accessible Labels:** Provide aria-labels for all icon buttons
3. **Column Filters:** Add filtering capability matching Entities table
4. **Consider Text + Icon:** Show both icon and text label for clarity

---

### 4. ApproveUser

**URL:** `/ApproveUser`
**Rating:** F (Critical - Non-Functional)

#### Screenshots
- `approveuser-main.png` - Empty page with error

#### Console Errors
```
TypeError: (intermediate value)(intermediate value)(intermediate value).reduce is not a function
    at ComputedRefImpl.fn (bootstrap-vue-next.js:19309:84)
```

#### Issues Found

| Issue | Severity | Description |
|-------|----------|-------------|
| 🔴 **Critical Bug** | Critical | JavaScript error prevents table from rendering |
| 🔴 **Critical Bug** | Critical | Page shows only pagination controls, no data/table content |
| 🟠 **UX Issue** | High | No loading indicator or error message shown to user |

#### Root Cause Analysis
The error appears to be in bootstrap-vue-next's computed properties, likely due to:
- Data not being returned as expected array format
- Null/undefined data being passed to .reduce() function

#### Immediate Actions Required

1. **Debug Data Fetching:** Check API response format for user applications
2. **Add Error Boundaries:** Implement try-catch and user-friendly error messages
3. **Add Loading States:** Show proper loading indicator while data fetches
4. **Verify API Contract:** Ensure response matches expected format

---

### 5. ManageReReview

**URL:** `/ManageReReview`
**Rating:** B- (Good Functionality, Needs UX Polish)

#### Screenshots
- `managerereview-main.png` - Main view with data

#### Current State
- User assignment form with dropdown
- "Assign new batch" action button
- Table showing re-review batch statistics
- Full pagination (first, prev, page #, next, last)
- Per-page selector

#### Issues Found

| Issue | Severity | Description |
|-------|----------|-------------|
| 🟠 **Accessibility** | Medium | Action button (red document icon) has no accessible label |
| 🟠 **UX Issue** | Medium | No search functionality |
| 🟡 **Consistency** | Low | Column headers truncated with "..." |
| 🟡 **UX Issue** | Low | User badges are small and may be hard to distinguish |
| 🟡 **Consistency** | Low | Per-page options (5, 10, 20, 50) differ from other tables |

#### Positive Aspects
- ✅ Clear user assignment workflow
- ✅ Good helper text explaining the action
- ✅ Comprehensive statistics columns
- ✅ Working pagination

#### Recommendations

1. **Add Search:** Include global search functionality
2. **Button Labels:** Add tooltip or text to action button
3. **Standardize Per-Page:** Align with other tables (10, 25, 50, 100)
4. **Expandable Column Names:** Use horizontal scroll or responsive design

---

## Consistency Analysis

### Pagination Patterns

| Page | First | Prev | Page # | Next | Last | Per-Page Options |
|------|-------|------|--------|------|------|------------------|
| Entities (Reference) | ✅ | ✅ | ✅ | ✅ | ✅ | 10, 25, 50, 100 |
| ApproveReview | ✅ | ✅ | ✅ | ✅ | ❌ | 10, 25, 50, 200 |
| ApproveStatus | ✅ | ✅ | ✅ | ✅ | ❌ | 10, 25, 50, 200 |
| ApproveUser | ✅ | ✅ | ❌ | ✅ | ✅ | 5, 10, 20, 50 |
| ManageReReview | ✅ | ✅ | ✅ | ✅ | ✅ | 5, 10, 20, 50 |

### Table Features

| Page | Search | Column Filter | Sorting | Export | Bulk Actions |
|------|--------|---------------|---------|--------|--------------|
| Entities (Reference) | ✅ | ✅ | ✅ | ✅ | ❌ |
| ApproveReview | ✅ | ❌ | ✅ | ❌ | ✅ |
| ApproveStatus | ✅ | ❌ | ✅ | ❌ | ✅ |
| ApproveUser | ❌ | ❌ | ? | ❌ | ❌ |
| ManageReReview | ❌ | ❌ | ✅ | ❌ | ✅ |

---

## Accessibility Issues Summary

### Critical (Must Fix)

1. **Icon-only buttons without labels** - All curation tables have action buttons with no accessible text
2. **Empty modal headers** - ModifyEntity modals lack title attributes

### High Priority

1. **Missing ARIA labels** - Action buttons need aria-label attributes
2. **Color-only indicators** - Category/Problematic icons need text alternatives
3. **Keyboard navigation** - Verify all interactive elements are keyboard accessible

### Recommendations for Accessibility

Following [WCAG 2.1 guidelines](https://www.w3.org/WAI/WCAG21/quickref/):

1. Add `aria-label` to all icon-only buttons:
```html
<button aria-label="Approve this review">
  <i class="bi-check-circle"></i>
</button>
```

2. Add tooltips with title attributes:
```html
<button title="View details" aria-label="View details">
  <i class="bi-eye"></i>
</button>
```

3. Use semantic HTML table elements with proper headers

4. Ensure color is not the only means of conveying information

---

## Best Practices from Research

### Healthcare UX Design ([Webstacks](https://www.webstacks.com/blog/healthcare-ux-design), [Eleken](https://www.eleken.co/blog-posts/user-interface-design-for-healthcare-applications))

- **User-Centered Design:** Design for different user roles (curators, reviewers, admins)
- **Simplicity:** Critical actions accessible within few clicks
- **Trust & Transparency:** Explain what actions do before executing
- **Visual Hierarchy:** Use whitespace and typography to reduce cognitive load

### Data Table UX ([LogRocket](https://blog.logrocket.com/ux-design/data-table-design-best-practices/), [Pencil & Paper](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables))

- **Sorting & Filtering:** Essential for managing large datasets
- **Pagination:** Default 25-50 rows; include total count indicator
- **Fixed Columns:** Keep identifying columns (Entity ID) fixed when scrolling
- **Row Feedback:** Add hover effects for clarity

---

## Recommended Action Plan

### Phase 1: Critical Fixes (Immediate)

1. **Fix ApproveUser page crash** - Debug .reduce() error
2. **Fix ModifyStatus dropdown** - Ensure options are populated
3. **Add accessible labels** - All icon buttons across all tables

### Phase 2: Consistency Improvements (Short-term)

1. **Standardize pagination** - Same controls across all tables
2. **Standardize per-page options** - Use 10, 25, 50, 100 everywhere
3. **Add column filters** - Match Entities table functionality
4. **Add search** - Global search for ManageReReview

### Phase 3: UX Enhancements (Medium-term)

1. **Improve ModifyEntity workflow** - Add entity preview, search
2. **Add export functionality** - Allow data export from approval tables
3. **Add icon legends** - Explain status/category icons
4. **Implement tooltips** - For all icon-only buttons

### Phase 4: Design System Alignment (Long-term)

1. **Create shared table component** - With consistent features
2. **Implement CreateEntity patterns** - Wizards, help text, validation
3. **Design system documentation** - Standard patterns for forms and tables

---

## Component Reuse Opportunities

### Create Shared Table Component

```vue
<template>
  <GenericCurationTable
    :columns="columns"
    :data="data"
    :searchable="true"
    :filterable="true"
    :sortable="true"
    :exportable="true"
    :per-page-options="[10, 25, 50, 100]"
    :bulk-actions="bulkActions"
  >
    <template #actions="{ row }">
      <ActionButton icon="eye" label="View" @click="view(row)" />
      <ActionButton icon="pencil" label="Edit" @click="edit(row)" />
      <ActionButton icon="check" label="Approve" @click="approve(row)" />
    </template>
  </GenericCurationTable>
</template>
```

### Shared Features
- Standard pagination with all controls
- Consistent per-page options
- Column filtering capability
- Export functionality
- Accessible action buttons

---

## Conclusion

The SysNDD curation forms have a solid foundation but require attention to:

1. **Critical bugs** - ApproveUser crash, ModifyStatus dropdown
2. **Accessibility** - Icon-only buttons need labels
3. **Consistency** - Pagination, filtering, per-page options should match
4. **User Experience** - Follow CreateEntity patterns for better workflows

The refactored CreateEntity page provides an excellent template for improving other forms. Implementing the recommended changes will significantly improve curator efficiency and reduce errors.

---

## Screenshots Reference

All screenshots captured during this review are stored in:
`.playwright-mcp/`

| Filename | Description |
|----------|-------------|
| modifyentity-initial.png | ModifyEntity initial state |
| modifyentity-with-entity.png | ModifyEntity with entity selected |
| modifyentity-modify-review-modal.png | Modify Review modal |
| modifyentity-rename-disease-modal.png | Rename Disease modal |
| modifyentity-deactivate-modal.png | Deactivate entity modal |
| modifyentity-modify-status-modal.png | Modify Status modal (shows bug) |
| modifyentity-status-dropdown-empty.png | Status dropdown with empty options |
| approvereview-main.png | ApproveReview main view |
| approvereview-expanded.png | ApproveReview with expanded row |
| approvestatus-main.png | ApproveStatus main view |
| approveuser-main.png | ApproveUser (showing crash) |
| managerereview-main.png | ManageReReview main view |
| createentity-refactored.png | CreateEntity (reference) |

---

*Report generated by automated UI/UX analysis using Playwright browser automation*
