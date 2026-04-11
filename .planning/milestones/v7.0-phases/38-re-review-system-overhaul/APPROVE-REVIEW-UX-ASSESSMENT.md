# ApproveReview Page UX Assessment Report

**Date:** 2026-01-26
**Page URL:** http://localhost:5173/ApproveReview
**Reference Page:** http://localhost:5173/Review (modernized)

## Executive Summary

The ApproveReview page has critical JavaScript errors preventing modal functionality and uses outdated UI patterns compared to the modernized Review.vue page. This document details all issues found during Playwright-based testing and provides a plan for modernization.

---

## 1. Critical Bugs (Blocking)

### 1.1 useModal() Called Outside setup() Context

**Severity:** Critical - Modals completely non-functional

**Error Message:**
```
Error: useModal() must be called within setup(), and BApp, useRegistry or plugin must be installed/provided.
    at useModal (bootstrap-vue-next.js:5212:11)
    at useModalControls (useModalControls.ts:3:17)
    at Proxy.infoReview (ApproveReview.vue:648:29)
```

**Affected Functions (ApproveReview.vue):**
- `infoReview()` - Line 1689: Opens Edit Review modal
- `infoApproveReview()` - Line 1696: Opens Approve modal
- `infoStatus()` - Line 1802: Opens Edit Status modal

**Root Cause:**
The `useModalControls()` composable is being called inside click handler methods rather than in the `setup()` function. Vue composables that use `inject()` (like `useModal` from bootstrap-vue-next) must be called during component setup, not during event handlers.

**Current Code (Broken):**
```javascript
infoReview(item, index, button) {
  this.reviewModal.title = `sysndd:${item.entity_id}`;
  this.getEntity(item.entity_id);
  this.loadReviewInfo(item.review_id);
  const { showModal } = useModalControls();  // WRONG - called in handler
  showModal(this.reviewModal.id);
}
```

**Fix Required:**
Use template refs to show modals (same pattern as Review.vue):
```javascript
infoReview(item, index, button) {
  this.reviewModal.title = `sysndd:${item.entity_id}`;
  this.getEntity(item.entity_id);
  this.loadReviewInfo(item.review_id);
  this.$refs[this.reviewModal.id].show();  // CORRECT - use template ref
}
```

---

## 2. Console Warnings

### 2.1 Vue inject() Warning
```
[Vue warn]: inject() can only be used inside setup() or functional components.
```
This is a consequence of the useModal() bug above.

### 2.2 Unhandled Error Warnings
Multiple Vue warnings about unhandled errors during event handler execution - all related to the useModal() bug.

---

## 3. UI/UX Issues (Compared to Review.vue)

### 3.1 Header Section

| Aspect | ApproveReview (Current) | Review.vue (Modern) |
|--------|------------------------|---------------------|
| Header style | Plain `<h6>` text | Dark background with badge count |
| Entity count | Not shown | Badge showing "26 entities" |
| User info | Not shown | User name/role displayed |
| Refresh button | Not present | Available in header |

### 3.2 Table Display

| Aspect | ApproveReview (Current) | Review.vue (Modern) |
|--------|------------------------|---------------------|
| Entity ID | Plain BBadge | `<EntityBadge>` component |
| Gene symbol | Plain BBadge | `<GeneBadge>` component |
| Disease name | Inline truncate logic | `<DiseaseBadge>` component |
| Inheritance | Manual abbreviation map | `<InheritanceBadge>` component |
| Category | Not shown as icon | `<CategoryIcon>` component |
| Date display | Plain date substring | Styled with age indicator |
| User display | Plain badge | Styled with role icon |

### 3.3 Filter Controls

| Aspect | ApproveReview (Current) | Review.vue (Modern) |
|--------|------------------------|---------------------|
| Search icon | Text "Search" prepend | Icon-based search |
| Quick filters | Not available | Tag-style removable filters |
| Filter clear | Not available | Click tag to remove |
| Category filter | Basic dropdown | Dropdown with "All" option |
| Date range | Two separate inputs | Not present (simpler) |

### 3.4 Modal Design

| Aspect | ApproveReview (Current) | Review.vue (Modern) |
|--------|------------------------|---------------------|
| Title style | `<h4>` with inline badges | Icon + semibold text |
| Header styling | `header-bg-variant="dark"` | Clean with no border |
| Entity context | In modal title (cramped) | Separate context section |
| Footer layout | Basic ok/cancel | Full-width with metadata |
| Status indicator | Plain text | Icon with role badge |
| Form sections | No visual separation | Section headers with icons |

### 3.5 Action Buttons

| Aspect | ApproveReview (Current) | Review.vue (Modern) |
|--------|------------------------|---------------------|
| Icons | Mixed styles | Consistent Bootstrap Icons |
| "Toggle details" | Present | Not present (removed) |
| Approve button | Present | Present (curation mode) |
| Submit button | Not present | Present (review mode) |
| Button variants | Various solid colors | Outline variants |

---

## 4. Code Architecture Issues

### 4.1 Component Structure
- **ApproveReview:** Options API with minimal setup()
- **Review.vue:** Options API with composables in setup()

### 4.2 Form Handling
- **ApproveReview:** Manual form state management with class instances
- **Review.vue:** Uses `useStatusForm` and `useReviewForm` composables

### 4.3 Modal Management
- **ApproveReview:** Tries to use `useModalControls()` in handlers (broken)
- **Review.vue:** Uses `this.$refs[modalId].show()` pattern

### 4.4 Reusable Components
- **ApproveReview:** Inline badge/icon rendering
- **Review.vue:** Uses `EntityBadge`, `GeneBadge`, `DiseaseBadge`, `InheritanceBadge`, `CategoryIcon`, `NddIcon`

---

## 5. Functional Observations

### 5.1 Working Features
- Table loading and display
- Pagination
- Column filters (Category, User, Date range)
- Search filter
- Toggle details button
- Approve all reviews button (opens modal)

### 5.2 Non-Working Features
- Edit Review button (useModal error)
- Edit Status button (useModal error)
- Approve button (likely same error)

---

## 6. Modernization Plan

### Phase 1: Critical Bug Fixes (Immediate)
1. Remove `useModalControls()` calls from click handlers
2. Replace with `this.$refs[modalId].show()` pattern
3. Test all modal functionality

### Phase 2: Component Modernization
1. Import and use reusable badge components:
   - `EntityBadge`
   - `GeneBadge`
   - `DiseaseBadge`
   - `InheritanceBadge`
2. Import and use icon components:
   - `CategoryIcon` (if category column added)

### Phase 3: Header/Toolbar Modernization
1. Add dark header with entity count badge
2. Add refresh button
3. Add user info display
4. Modernize search input with icon prepend

### Phase 4: Modal UI Refresh
1. Update modal titles to icon + text pattern
2. Add entity context section at top of modals
3. Add section headers with icons
4. Modernize footer with metadata and button layout

### Phase 5: Form Composable Integration (Optional)
1. Create or reuse form composables for consistent state management
2. Integrate `useStatusForm` if applicable
3. Add draft persistence if needed

---

## 7. Files to Modify

### Frontend
- `app/src/views/curate/ApproveReview.vue` - Main page component

### Potentially New Files
- None required - can reuse existing components

### Components to Import
- `@/components/ui/EntityBadge.vue`
- `@/components/ui/GeneBadge.vue`
- `@/components/ui/DiseaseBadge.vue`
- `@/components/ui/InheritanceBadge.vue`
- `@/components/ui/CategoryIcon.vue` (optional)

---

## 8. Testing Checklist

After fixes (verified 2026-01-26):
- [x] Edit Review modal opens without error
- [ ] Edit Review modal saves changes
- [x] Edit Status modal opens without error
- [ ] Edit Status modal saves changes
- [x] Approve modal opens without error
- [ ] Approve single review works
- [ ] Approve all reviews works
- [x] Table filtering works
- [x] Pagination works
- [x] No console errors/warnings

**Critical Bug Fix Verified:** The `useModal()` error has been resolved. All three modals (Edit Review, Edit Status, Approve) now open correctly without any JavaScript errors.

---

## 11. UI/UX Modernization Completed (2026-01-26)

### Changes Implemented

**1. Component Imports Added:**
- `EntityBadge` - Consistent entity ID display
- `GeneBadge` - Consistent gene symbol display
- `DiseaseBadge` - Consistent disease name display
- `InheritanceBadge` - Consistent inheritance pattern display
- `CategoryIcon` - Consistent category icon display

**2. Header Modernization:**
- Dark background header (`header-bg-variant="dark"`)
- Entity count badge showing "X reviews"
- Refresh button with icon (`bi-arrow-clockwise`)
- Modern h5 heading with `fw-bold` class

**3. Search/Filter Controls:**
- Icon-based search input (`bi-search` prepend)
- Dropdown-based Category filter with "All Categories" option
- Dropdown-based User filter with "All Users" option
- Date range inputs with "From"/"To" labels
- Removable filter tags (click badge to clear filter)
- Responsive layout with BCol breakpoints

**4. Table Cell Templates:**
- Entity column: Uses `<EntityBadge>` component
- Gene column: Uses `<GeneBadge>` component
- Disease column: Uses `<DiseaseBadge>` component
- Inheritance column: Uses `<InheritanceBadge>` component
- Date column: Circular icon with muted date text
- User column: Circular role icon with user name

**5. Modal Modernization (All 4 modals):**
- Removed dark header backgrounds
- Added `header-class="border-bottom-0 pb-0"`
- Added `footer-class="border-top-0 pt-0"`
- Icon + semibold text titles (e.g., `<i class="bi bi-pencil-square">` + "Edit Review")
- Entity context header section with `bg-light rounded-3 p-3`
- Section headers with icons throughout forms
- Modern footer with metadata display and aligned buttons
- Bootstrap switches instead of custom checkbox styling

**6. Form Field Organization:**
- Wrapped fields in `<BFormGroup>` components
- Added `fw-semibold` labels
- Section headers: "Review Information", "Phenotypes & Variation", "Literature References", "Notes"
- Section headers: "Classification", "Entity Flags", "Notes" (Status modal)
- Help badges with popovers for complex fields

**7. Approve All Modal:**
- Warning icon in centered layout
- Danger-themed confirmation UI
- Checkbox confirmation switch
- Shows count of reviews to be approved

### Files Modified
- `app/src/views/curate/ApproveReview.vue` - Complete UI/UX modernization

### Verification
- All modals tested with Playwright
- No console errors
- Consistent with Review.vue patterns
- DRY principle applied via reusable badge components

---

## 9. Screenshots

*Full-page screenshot captured during Playwright testing showing current ApproveReview UI*

---

## 10. Priority Recommendation

**Immediate (P0):** Fix useModal() bug - modals are completely broken
**High (P1):** Import reusable badge components for consistency
**Medium (P2):** Modernize header and filter UI
**Low (P3):** Form composable integration
