# Review Page UI/UX Assessment & Modernization Plan

**Created:** 2026-01-26
**Author:** Senior UI/UX Assessment
**Status:** Ready for Implementation

---

## Executive Summary

The Review page (`/Review`) is a critical workflow component for curators and reviewers, but it significantly lags behind the modernized tables (Entities, ManageUser) in terms of visual consistency, user experience, and functionality. This assessment identifies key gaps and provides a prioritized refactoring plan.

**Overall Design Rating: 5/10** (compared to 8.5/10 for modernized tables)

---

## 1. Comparative Analysis

### Reference Designs (Modernized Tables)

#### Entities Table (`/Entities`) - Score: 8.5/10
**Strengths:**
- Clean header with title + count badge
- Action buttons in top-right (download xlsx, link, filter icons)
- Full-width search bar with placeholder text
- Per page dropdown + pagination on right
- Column filter row below headers
- Semantic icons with tooltips (stoplight for category, checkmark for NDD)
- "Show" button for details - clear, consistent action
- Excellent visual hierarchy and spacing

#### ManageUser Table (`/ManageUser`) - Score: 8.5/10
**Strengths:**
- Header with title + count badge + action icons (refresh, filter)
- Quick filter tags (Pending, Curators) - removable with X
- Full-width search with icon and placeholder
- Dropdown filters (Role, Status) inline with search
- "Showing X-Y of Z" counter
- Colored role badges (Viewer, Administrator, Reviewer, Curator)
- Status badges (Pending = yellow, Approved = green)
- Consistent action buttons in Actions column (edit, view, delete icons)
- Proper aria-labels for accessibility

### Review Page Current State - Score: 5/10

**Critical Issues Identified:**

| Issue | Severity | Impact |
|-------|----------|--------|
| Inconsistent header layout | High | Visual discord with other pages |
| Missing action icons in header | Medium | Reduced functionality discoverability |
| No quick filter tags | High | Poor workflow efficiency |
| Deprecated CSS (custom-control-switch) | Medium | Bootstrap-Vue-Next incompatibility |
| Icon-only buttons without clear labels | High | Poor accessibility |
| Missing "Showing X-Y of Z" counter | Low | Reduced pagination context |
| Pagination options include 200 (non-standard) | Low | Inconsistency |
| No column filters | Medium | Reduced filtering capability |
| Empty columns in search row (wasted space) | Medium | Inefficient layout |
| Action buttons lack semantic consistency | High | Confusing UX |

---

## 2. Detailed Gap Analysis

### 2.1 Header Section

**Current:**
```
+--------------------------------------------------+
| Re-review table [Entities: 25]  | User Badge Role |
|                                 | [Switch toggle] |
+--------------------------------------------------+
```

**Target (ManageUser pattern):**
```
+--------------------------------------------------+
| Re-review table [25 entities]   | [Refresh][Filter]|
+--------------------------------------------------+
| Quick filters: [Pending x] [Submitted x]          |
+--------------------------------------------------+
```

**Changes Required:**
1. Move user info to a less prominent position (or remove - already in nav)
2. Add action icon buttons (refresh, filter toggle)
3. Add quick filter tags for common workflows:
   - "Pending Review" - entities not yet reviewed
   - "Submitted" - entities submitted but not approved
   - "Needs Status" - entities missing status updates
4. Replace deprecated `custom-control-switch` with `<BFormCheckbox switch>`

### 2.2 Search & Filter Row

**Current:**
```
| Search [input] | [empty] | [empty] | Per page [10v] |
|                |         |         | [Pagination]   |
```

**Target (ManageUser pattern):**
```
| 🔍 Search by entity, gene, disease... | [Category v] [User v] | Showing 1-25 of 649 |
| Per page [25 v]  | [« ‹ 1 2 3 › »]                                                |
```

**Changes Required:**
1. Add search icon prefix
2. Expand search placeholder to be more descriptive
3. Add dropdown filters:
   - Category filter (Definitive, Moderate, Limited, etc.)
   - User filter (filter by reviewer)
   - Date range filter (review date)
4. Add "Showing X-Y of Z" counter
5. Standardize pagination options: `[10, 25, 50, 100]` (remove 200)

### 2.3 Action Buttons

**Current:**
```
| [🖊] [🚦] [✓] |  <- Icon-only, cryptic
```

**Target (consistent with ManageUser):**
```
| [📝 Edit Review] [🚦 Edit Status] [✓ Submit] |
```

**OR keep icons but with proper styling:**
```
| [📝][🚦][✓] |  <- With colored backgrounds matching action type
```

**Changes Required:**
1. Add aria-labels with entity context: `aria-label="Edit review for sysndd:${entity_id}"`
2. Consistent icon styling:
   - Edit Review: `bi-pencil-square` (or `bi-pen`) - secondary variant
   - Edit Status: `bi-stoplights` - matches category color
   - Submit: `bi-check2-circle` - success variant when ready
   - Approve: `bi-check-circle-fill` - danger/warning variant
3. Add loading spinner during action (already partially implemented)

### 2.4 Table Columns

**Current columns:**
| Entity | Gene | Disease | Inheritance | NDD | Review date | User | Actions |

**Observations:**
- NDD column uses icon but inconsistent with Entities table styling
- Review date formatting is good (badge with age indicator)
- User column has role icon + name - good

**Recommended enhancements:**
1. Add Category column (missing - important for curation context)
2. Use consistent badge styling for inheritance (match Entities table)
3. Add Status column showing current entity status
4. Consider adding "Last Updated" indicator

### 2.5 Visual Styling

**Current Issues:**
- Header uses `header_style[curation_selected]` which creates jarring color changes
- Deprecated `custom-control-switch` CSS classes
- Inconsistent badge variants

**Target:**
- Consistent header styling (dark bg, light text - matches other tables)
- Modern Bootstrap-Vue-Next switch component
- Unified color palette for badges

---

## 3. Accessibility Audit

| Element | Current State | Required Fix |
|---------|---------------|--------------|
| Action buttons | Missing aria-labels | Add `aria-label="Edit review for sysndd:${id}"` |
| Icon-only buttons | No text alternative | Add `sr-only` text or proper aria-label |
| Table headers | Good | Maintain |
| Pagination | Good | Maintain |
| Focus indicators | Default | Verify visible focus rings |
| Color contrast | Good | Maintain |

---

## 4. Modernization Plan

### Phase 1: Header & Layout Alignment (Priority: High)

**Files:** `Review.vue`

**Tasks:**
1. Refactor header to match ManageUser pattern
   - Title + count badge on left
   - Action icons (refresh, filter toggle) on right
2. Add quick filter tags section
3. Replace deprecated switch with `<BFormCheckbox switch>`
4. Move user info badge to less prominent position

### Phase 2: Search & Filter Enhancement (Priority: High)

**Files:** `Review.vue`

**Tasks:**
1. Add search icon prefix to search input
2. Update placeholder text: "Search by entity, gene, disease, user..."
3. Add dropdown filters (Category, User)
4. Add "Showing X-Y of Z" counter
5. Standardize pagination options to `[10, 25, 50, 100]`

### Phase 3: Action Button Modernization (Priority: High)

**Files:** `Review.vue`

**Tasks:**
1. Add aria-labels with entity context to all action buttons
2. Standardize icon usage:
   - Edit Review: `bi-pencil-square`
   - Edit Status: `bi-stoplights`
   - Submit: `bi-send-check`
   - Approve: `bi-check-circle-fill`
3. Add tooltips with action descriptions
4. Implement consistent button variants

### Phase 4: Table Column Enhancement (Priority: Medium)

**Files:** `Review.vue`

**Tasks:**
1. Add Category column with stoplight icon (match Entities table)
2. Add Status column showing current approval status
3. Standardize inheritance badge styling
4. Consider adding "Submitted" status indicator

### Phase 5: Visual Polish (Priority: Low)

**Files:** `Review.vue`

**Tasks:**
1. Unify header styling (remove jarring color switches)
2. Ensure consistent badge variants
3. Add subtle row hover states
4. Polish empty state message

---

## 5. Icon Mapping Reference

| Action | Current Icon | Recommended Icon | Bootstrap Icon Class |
|--------|--------------|------------------|---------------------|
| Edit Review | bi-pen | bi-pencil-square | `bi-pencil-square` |
| Edit Status | bi-stoplights | bi-stoplights | `bi-stoplights` |
| Submit Review | bi-check2-circle | bi-send-check | `bi-send-check` |
| Approve | bi-check2-circle | bi-check-circle-fill | `bi-check-circle-fill` |
| Refresh | (none) | bi-arrow-clockwise | `bi-arrow-clockwise` |
| Filter Toggle | (none) | bi-funnel | `bi-funnel` or `bi-filter` |
| Remove Filter | (none) | bi-x | `bi-x` |

---

## 6. Component Patterns to Follow

### Quick Filter Tags (from ManageUser)
```vue
<div class="d-flex gap-2 mb-2">
  <span class="text-muted">Quick filters:</span>
  <BBadge
    v-for="filter in activeFilters"
    :key="filter.key"
    variant="secondary"
    class="d-flex align-items-center gap-1"
    style="cursor: pointer"
    @click="removeFilter(filter.key)"
  >
    {{ filter.label }}
    <i class="bi bi-x" />
  </BBadge>
</div>
```

### Search with Icon (from ManageUser)
```vue
<BInputGroup size="sm">
  <template #prepend>
    <BInputGroupText>
      <i class="bi bi-search" />
    </BInputGroupText>
  </template>
  <BFormInput
    v-model="filter"
    type="search"
    placeholder="Search by entity, gene, disease, user..."
    debounce="500"
  />
</BInputGroup>
```

### Action Button with Accessibility
```vue
<BButton
  v-b-tooltip.hover.left
  size="sm"
  class="btn-xs"
  variant="outline-secondary"
  :aria-label="`Edit review for sysndd:${row.item.entity_id}`"
  @click="infoReview(row.item)"
>
  <i class="bi bi-pencil-square" />
</BButton>
```

---

## 7. Estimated Effort

| Phase | Effort | Complexity |
|-------|--------|------------|
| Phase 1: Header & Layout | 2-3 hours | Medium |
| Phase 2: Search & Filters | 2-3 hours | Medium |
| Phase 3: Action Buttons | 1-2 hours | Low |
| Phase 4: Table Columns | 2-3 hours | Medium |
| Phase 5: Visual Polish | 1-2 hours | Low |
| **Total** | **8-13 hours** | **Medium** |

---

## 8. Success Criteria

- [ ] Header matches ManageUser pattern
- [ ] Quick filter tags implemented
- [ ] Search has icon and improved placeholder
- [ ] Dropdown filters for Category and User
- [ ] "Showing X-Y of Z" counter visible
- [ ] Pagination standardized to [10, 25, 50, 100]
- [ ] All action buttons have aria-labels
- [ ] Icons consistent with Entities table
- [ ] No deprecated CSS classes
- [ ] No console warnings/errors
- [ ] Visual score improves from 5/10 to 8+/10

---

## 9. Files to Modify

| File | Changes |
|------|---------|
| `app/src/views/review/Review.vue` | All UI changes |
| `app/src/views/review/Review.vue` | Add filter state management |
| `app/src/composables/useReviewFilters.ts` | (Optional) Extract filter logic |

---

*Assessment completed by Claude Code - Senior UI/UX Analysis*
