# Phase 36: Curation Table Modernization - Research

**Researched:** 2026-01-26
**Domain:** Curation table filtering, pagination, search, and accessibility patterns
**Confidence:** HIGH

## Summary

Phase 36 applies the TablesEntities pattern to curation tables (ApproveReview, ApproveStatus, ManageReReview) for consistent UX with column filters, standardized pagination, search functionality, and accessibility improvements. The codebase has a proven pattern from Phase 28 with composables (useTableData, useTableMethods), components (TablePaginationControls, TableSearchInput), and Bootstrap-Vue-Next 0.42.0 primitives.

**Current state:**
- ApproveReview: Has basic search (line 49-56) and pagination (lines 70-86), but uses legacy pageOptions [10, 25, 50, 200]
- ApproveStatus: Has basic search (line 49-56) and pagination (lines 69-86), same legacy pageOptions
- ManageReReview: Has pagination but NO search functionality, uses pageOptions [5, 10, 20, 50]
- All three lack column-specific filters (status, user, date range)
- All action buttons have tooltips (v-b-tooltip) but many lack aria-label attributes

**Primary recommendation:** Apply the TablesEntities composable pattern selectively—use the established pagination and search components, but keep client-side filtering for curation tables since they display <200 rows (server-side pagination would over-engineer these views).

## Standard Stack

The established libraries/tools for curation table modernization:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Bootstrap-Vue-Next | 0.42.0 | BTable, BFormInput, BFormSelect, BPagination | Already used in all curation views, v-b-tooltip directive available |
| @vueuse/core | 14.1.0 | useDebounceFn for search debouncing | Official Vue ecosystem utility, lighter than custom setTimeout logic |
| Native BFormInput | 0.42.0 | Date inputs with type="date" | Built-in HTML5 date picker, no external dependency needed |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| useTableData composable | (codebase) | Reactive table state (pagination, sort, filters) | Reuse for pagination state management |
| TablePaginationControls | (codebase) | Standardized pagination UI | Drop-in replacement for current per-page selectors |
| TableSearchInput | (codebase) | Debounced search input component | Reuse for global search functionality |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Native date input | vue2-daterange-picker | date picker library unmaintained (4 years), native input simpler and accessible |
| Client-side filtering | Server-side pagination + filters | Server-side over-engineered for <200 row curation tables |
| Custom search debounce | BFormInput debounce prop | BFormInput native debounce is simpler but less flexible than useDebounceFn |

**Installation:**
No new packages needed—all dependencies already installed.

## Architecture Patterns

### Recommended Project Structure
```
src/
├── views/curate/
│   ├── ApproveReview.vue        # Add column filters, standardize pagination
│   ├── ApproveStatus.vue        # Add column filters, standardize pagination
│   └── ManageReReview.vue       # Add search, standardize pagination
├── composables/
│   ├── useTableData.ts          # REUSE: Reactive table state for pagination
│   └── useDebounceFn (VueUse)   # USE: Search input debouncing
└── components/small/
    ├── TablePaginationControls.vue  # REUSE: Standardized pagination component
    └── TableSearchInput.vue         # REUSE: Debounced search input
```

### Pattern 1: Client-Side Column Filtering
**What:** Filter table rows by specific columns (status, user, date range) without API calls
**When to use:** Small datasets (<200 rows) where all data loads on mount
**Example:**
```typescript
// Source: Bootstrap-Vue-Next BTable filter function pattern
// https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/table

// Data
const statusFilter = ref<string | null>(null);
const userFilter = ref<string | null>(null);
const dateRangeStart = ref<string | null>(null);
const dateRangeEnd = ref<string | null>(null);

// Computed filtered items
const filteredItems = computed(() => {
  let result = items_ReviewTable.value;

  if (statusFilter.value) {
    result = result.filter(item => item.status === statusFilter.value);
  }

  if (userFilter.value) {
    result = result.filter(item =>
      item.review_user_name.toLowerCase().includes(userFilter.value.toLowerCase())
    );
  }

  if (dateRangeStart.value) {
    result = result.filter(item =>
      new Date(item.review_date) >= new Date(dateRangeStart.value)
    );
  }

  if (dateRangeEnd.value) {
    result = result.filter(item =>
      new Date(item.review_date) <= new Date(dateRangeEnd.value)
    );
  }

  return result;
});
```

### Pattern 2: Standardized Pagination Options
**What:** Consistent [10, 25, 50, 100] page size options across all curation views
**When to use:** All table pagination controls (requirement TBL-03)
**Example:**
```typescript
// Source: /home/bernt-popp/development/sysndd/app/src/composables/useTableData.ts (line 63)
// Current ApproveReview/ApproveStatus use [10, 25, 50, 200] - change to standard

// Before (ApproveReview.vue line 1138)
pageOptions: [10, 25, 50, 200],

// After (TBL-03 requirement)
pageOptions: [10, 25, 50, 100],

// Or reuse TablePaginationControls component which defaults to [10, 25, 50, 100]
// Source: /home/bernt-popp/development/sysndd/app/src/components/small/TablePaginationControls.vue (line 60)
```

### Pattern 3: Accessible Action Buttons
**What:** Every icon-only button has both aria-label and v-b-tooltip
**When to use:** All action buttons without visible text labels (requirement TBL-05, TBL-06)
**Example:**
```vue
<!-- Source: Bootstrap-Vue-Next accessibility best practices -->
<!-- Current pattern (ApproveReview.vue line 252-260) has tooltip but no aria-label -->
<BButton
  v-b-tooltip.hover.left
  size="sm"
  class="me-1 btn-xs"
  variant="outline-primary"
  title="Toggle details"
  aria-label="Toggle details for entity"
  @click="row.toggleDetails"
>
  <i :class="'bi bi-' + (row.detailsShowing ? 'eye-slash' : 'eye')" />
</BButton>

<BButton
  v-b-tooltip.hover.left
  size="sm"
  class="me-1 btn-xs"
  variant="secondary"
  title="Edit review"
  aria-label="Edit review for entity"
  @click="infoReview(row.item, row.index, $event.target)"
>
  <i class="bi bi-pen" />
</BButton>
```

### Pattern 4: Date Range Filter Implementation
**What:** Two date inputs (From/To) with computed filtering
**When to use:** Filtering by date columns (review_date, status_date)
**Example:**
```vue
<!-- Source: /home/bernt-popp/development/sysndd/app/src/views/admin/AdminStatistics.vue (lines 16-21) -->
<BFormGroup label="From" label-class="small" class="mb-0 me-2">
  <BFormInput v-model="dateRangeStart" type="date" size="sm" />
</BFormGroup>
<BFormGroup label="To" label-class="small" class="mb-0 me-2">
  <BFormInput v-model="dateRangeEnd" type="date" size="sm" />
</BFormGroup>

<!-- Filtering logic in computed property -->
<script>
const filteredByDate = computed(() => {
  if (!dateRangeStart.value && !dateRangeEnd.value) return items.value;

  return items.value.filter(item => {
    const itemDate = new Date(item.review_date);
    const startOk = !dateRangeStart.value || itemDate >= new Date(dateRangeStart.value);
    const endOk = !dateRangeEnd.value || itemDate <= new Date(dateRangeEnd.value);
    return startOk && endOk;
  });
});
</script>
```

### Pattern 5: Multi-Select Status/Category Filter
**What:** BFormSelect with multiple prop for filtering by multiple statuses/categories
**When to use:** Filtering by enums (category, user_role, status)
**Example:**
```vue
<!-- Source: Bootstrap-Vue-Next BFormSelect multiple option -->
<BFormGroup label="Filter by Status" class="mb-2">
  <BFormSelect
    v-model="statusFilter"
    :options="statusOptions"
    multiple
    size="sm"
  >
    <template #first>
      <BFormSelectOption :value="null">All Statuses</BFormSelectOption>
    </template>
  </BFormSelect>
</BFormGroup>

<script>
// Filter logic for multi-select
const filteredByStatus = computed(() => {
  if (!statusFilter.value || statusFilter.value.length === 0) {
    return items.value;
  }
  return items.value.filter(item =>
    statusFilter.value.includes(item.status)
  );
});
</script>
```

### Pattern 6: Global Search Implementation
**What:** Debounced search across all table columns
**When to use:** ManageReReview table (requirement TBL-04), already exists in ApproveReview/ApproveStatus
**Example:**
```vue
<!-- Source: /home/bernt-popp/development/sysndd/app/src/views/curate/ApproveReview.vue (lines 49-56) -->
<BFormInput
  id="filter-input"
  v-model="filter"
  type="search"
  placeholder="any field by typing here"
  debounce="500"
/>

<!-- Pass filter to BTable -->
<BTable
  :items="items_ReviewTable"
  :fields="fields_ReviewTable"
  :filter="filter"
  @filtered="onFiltered"
/>

<!-- Update totalRows when filtered -->
<script>
function onFiltered(filteredItems) {
  totalRows.value = filteredItems.length;
  currentPage.value = 1;
}
</script>
```

### Anti-Patterns to Avoid
- **Server-side pagination for small datasets:** ApproveReview/ApproveStatus have <200 rows. Client-side filtering is simpler and faster.
- **Custom date range picker libraries:** Native HTML5 date inputs are accessible, mobile-friendly, and zero-dependency.
- **Removing existing search:** ApproveReview/ApproveStatus already have working search (lines 49-56). Enhance, don't replace.
- **Breaking BTable filter prop:** BTable's :filter prop works for global search. Don't override—add column filters as additional computed filters.
- **Inconsistent pagination options:** All tables must use [10, 25, 50, 100] per TBL-03. Don't keep [5, 10, 20, 50] or [10, 25, 50, 200].

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Pagination controls | Custom prev/next buttons | `TablePaginationControls.vue` component | Handles edge cases (first/last page), consistent UI, already tested |
| Search debouncing | Custom setTimeout logic | `useDebounceFn` from VueUse or BFormInput `debounce` prop | Proper cleanup, cancellation, memory leak prevention |
| Date range validation | Manual date comparison | Native date input min/max attributes | Browser validates automatically, prevents invalid ranges |
| Filtered row count | Manual array length tracking | BTable `@filtered` event | BTable emits filtered items automatically, handles search + filters |
| Tooltip positioning | Manual CSS | Bootstrap-Vue-Next `v-b-tooltip` directive | Handles viewport boundaries, mobile touch, already in use |
| Accessible labels | Manual aria setup | Combine `aria-label` + `v-b-tooltip` | Screen readers get aria-label, visual users get tooltip on hover |

**Key insight:** ApproveReview and ApproveStatus already have search + pagination structure. The task is enhancement (add column filters, fix pagination options, add aria-labels), not rebuilding. Don't throw away working patterns.

## Common Pitfalls

### Pitfall 1: Breaking BTable's Built-In Filter
**What goes wrong:** Adding custom column filters breaks the global search (:filter prop)
**Why it happens:** Passing computed filtered items to :items bypasses BTable's :filter prop
**How to avoid:**
1. Keep :filter prop for global search (existing pattern works)
2. Apply column filters in computed property BEFORE passing to :items
3. Both filters work together: computed filters → :items → BTable :filter → displayed rows
**Warning signs:**
- Global search stops working after adding column filters
- @filtered event fires with wrong item count
- totalRows desync with displayed rows

### Pitfall 2: Date Range Filter Without Null Checks
**What goes wrong:** Filter breaks when date inputs are empty (null or empty string)
**Why it happens:** new Date(null) returns invalid date, causes filter to exclude all rows
**How to avoid:** Always check if date value exists before creating Date object
**Warning signs:**
```javascript
// BAD: Breaks when dateRangeStart is null
if (new Date(item.date) >= new Date(dateRangeStart.value)) { ... }

// GOOD: Checks for null first
if (!dateRangeStart.value || new Date(item.date) >= new Date(dateRangeStart.value)) { ... }
```

### Pitfall 3: Inconsistent Pagination Options Across Tables
**What goes wrong:** ApproveReview uses [10, 25, 50, 200], ManageReReview uses [5, 10, 20, 50]
**Why it happens:** Each view defined pageOptions independently
**How to avoid:** Use standard [10, 25, 50, 100] from requirement TBL-03
**Warning signs:**
- User confusion switching between curation views
- Different default page sizes per view
- Code duplication of pageOptions array

### Pitfall 4: Missing aria-label on Dynamically Titled Buttons
**What goes wrong:** aria-label is static but tooltip changes based on item state
**Why it happens:** Forgot to make aria-label dynamic like :title
**How to avoid:** Use template strings in aria-label to include item context
**Warning signs:**
```vue
<!-- BAD: aria-label doesn't match tooltip -->
<BButton
  :title="row.item.status_change ? 'edit new status' : 'edit status'"
  aria-label="Edit status"
>

<!-- GOOD: Both are dynamic -->
<BButton
  :title="row.item.status_change ? 'edit new status' : 'edit status'"
  :aria-label="`${row.item.status_change ? 'Edit new status' : 'Edit status'} for entity ${row.item.entity_id}`"
>
```

### Pitfall 5: Date Filter String Comparison Instead of Date Objects
**What goes wrong:** String comparison "2024-12-01" >= "2024-02-15" gives wrong result
**Why it happens:** JavaScript string comparison is lexicographic, not chronological
**How to avoid:** Always convert to Date objects before comparing
**Warning signs:**
```javascript
// BAD: String comparison - December appears "less than" February
item.review_date >= dateRangeStart.value

// GOOD: Date object comparison
new Date(item.review_date) >= new Date(dateRangeStart.value)
```

### Pitfall 6: Forgetting onFiltered Handler
**What goes wrong:** Pagination shows wrong page count when filters active
**Why it happens:** totalRows not updated when BTable filters items
**How to avoid:** Always add @filtered event handler that updates totalRows
**Warning signs:**
- Pagination shows "Page 1 of 5" but only 1 page of filtered results exists
- Can't navigate to page 2+ because no data exists
- totalRows doesn't decrease when search/filter applied

## Code Examples

Verified patterns from official sources and existing codebase:

### Complete Column Filter Row
```vue
<!-- Add below existing search row in ApproveReview.vue -->
<BRow class="mb-2">
  <BCol md="3">
    <BFormGroup label="Status" label-size="sm" class="mb-0">
      <BFormSelect
        v-model="statusFilter"
        :options="statusOptions"
        size="sm"
      >
        <template #first>
          <BFormSelectOption :value="null">All Statuses</BFormSelectOption>
        </template>
      </BFormSelect>
    </BFormGroup>
  </BCol>

  <BCol md="3">
    <BFormGroup label="User" label-size="sm" class="mb-0">
      <BFormInput
        v-model="userFilter"
        type="search"
        placeholder="Filter by user..."
        size="sm"
        debounce="300"
      />
    </BFormGroup>
  </BCol>

  <BCol md="3">
    <BFormGroup label="From Date" label-size="sm" class="mb-0">
      <BFormInput
        v-model="dateRangeStart"
        type="date"
        size="sm"
      />
    </BFormGroup>
  </BCol>

  <BCol md="3">
    <BFormGroup label="To Date" label-size="sm" class="mb-0">
      <BFormInput
        v-model="dateRangeEnd"
        type="date"
        size="sm"
      />
    </BFormGroup>
  </BCol>
</BRow>
```

### Column Filtering Computed Property
```typescript
// Source: Client-side filtering pattern
const columnFilteredItems = computed(() => {
  let result = items_ReviewTable.value;

  // Status filter
  if (statusFilter.value) {
    result = result.filter(item => item.status === statusFilter.value);
  }

  // User filter (case-insensitive partial match)
  if (userFilter.value && userFilter.value.trim() !== '') {
    const searchTerm = userFilter.value.toLowerCase();
    result = result.filter(item =>
      item.review_user_name.toLowerCase().includes(searchTerm)
    );
  }

  // Date range filter
  if (dateRangeStart.value || dateRangeEnd.value) {
    result = result.filter(item => {
      const itemDate = new Date(item.review_date);

      if (dateRangeStart.value) {
        const startDate = new Date(dateRangeStart.value);
        if (itemDate < startDate) return false;
      }

      if (dateRangeEnd.value) {
        const endDate = new Date(dateRangeEnd.value);
        // Set time to end of day for inclusive range
        endDate.setHours(23, 59, 59, 999);
        if (itemDate > endDate) return false;
      }

      return true;
    });
  }

  return result;
});

// Pass to BTable
<BTable
  :items="columnFilteredItems"
  :filter="filter"
  @filtered="onFiltered"
/>
```

### Standardized Pagination Integration
```vue
<!-- Source: /home/bernt-popp/development/sysndd/app/src/components/small/TablePaginationControls.vue -->
<!-- Replace existing per-page + pagination blocks (lines 64-87 in ApproveReview.vue) -->
<BCol class="my-1">
  <TablePaginationControls
    :total-rows="totalRows"
    :initial-per-page="perPage"
    :page-options="[10, 25, 50, 100]"
    :current-page="currentPage"
    @page-change="handlePageChange"
    @per-page-change="handlePerPageChange"
  />
</BCol>

<script>
// Import component
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';

// Handlers
function handlePageChange(page: number) {
  currentPage.value = page;
}

function handlePerPageChange(newPerPage: number) {
  perPage.value = newPerPage;
  currentPage.value = 1; // Reset to page 1
}
</script>
```

### Accessible Action Buttons
```vue
<!-- Source: Accessibility best practices + existing v-b-tooltip pattern -->
<!-- ApproveReview.vue actions column (lines 251-313) with aria-labels -->
<template #cell(actions)="row">
  <BButton
    v-b-tooltip.hover.left
    size="sm"
    class="me-1 btn-xs"
    variant="outline-primary"
    title="Toggle details"
    :aria-label="`Toggle details for entity ${row.item.entity_id}`"
    @click="row.toggleDetails"
  >
    <i :class="'bi bi-' + (row.detailsShowing ? 'eye-slash' : 'eye')" />
  </BButton>

  <BButton
    v-b-tooltip.hover.left
    size="sm"
    class="me-1 btn-xs"
    variant="secondary"
    title="Edit review"
    :aria-label="`Edit review for entity ${row.item.entity_id}`"
    @click="infoReview(row.item, row.index, $event.target)"
  >
    <i class="bi bi-pen" />
  </BButton>

  <BButton
    v-b-tooltip.hover.top
    size="sm"
    class="me-1 btn-xs"
    :variant="stoplights_style[row.item.active_category]"
    :title="row.item.status_change ? 'Edit new status' : 'Edit status'"
    :aria-label="`${row.item.status_change ? 'Edit new status' : 'Edit status'} for entity ${row.item.entity_id}`"
    @click="infoStatus(row.item, row.index, $event.target)"
  >
    <span class="position-relative d-inline-block" style="font-size: 0.9em;">
      <i class="bi bi-stoplights" />
      <i
        v-if="row.item.status_change"
        class="bi bi-exclamation-triangle-fill position-absolute"
        style="top: -0.3em; right: -0.5em; font-size: 0.7em;"
      />
    </span>
  </BButton>

  <BButton
    v-b-tooltip.hover.right
    size="sm"
    class="me-1 btn-xs"
    variant="danger"
    title="Approve review"
    :aria-label="`Approve review for entity ${row.item.entity_id}`"
    @click="infoApproveReview(row.item, row.index, $event.target)"
  >
    <i class="bi bi-check2-circle" />
  </BButton>
</template>
```

### ManageReReview Search Addition
```vue
<!-- Source: /home/bernt-popp/development/sysndd/app/src/views/curate/ApproveReview.vue (lines 49-56) -->
<!-- Add after line 72 in ManageReReview.vue (before pagination row) -->
<BRow class="mb-2">
  <BCol>
    <BFormGroup class="mb-1">
      <BInputGroup prepend="Search" size="sm">
        <BFormInput
          id="filter-input"
          v-model="filter"
          type="search"
          placeholder="Search batches, users, or counts..."
          debounce="500"
        />
      </BInputGroup>
    </BFormGroup>
  </BCol>
</BRow>

<!-- Update BTable to use filter -->
<BTable
  :items="items_ReReviewTable"
  :fields="fields_ReReviewTable"
  :filter="filter"
  :per-page="perPage"
  :current-page="currentPage"
  @filtered="onFiltered"
/>

<!-- Add data property -->
<script>
data() {
  return {
    filter: null,
    // ... existing properties
  };
},
methods: {
  onFiltered(filteredItems) {
    this.totalRows = filteredItems.length;
    this.currentPage = 1;
  },
}
</script>
```

### Clear Filters Button
```vue
<!-- Optional: Add button to clear all column filters -->
<BButton
  v-if="hasActiveFilters"
  size="sm"
  variant="outline-secondary"
  class="ms-2"
  @click="clearFilters"
>
  <i class="bi bi-x-circle me-1" />
  Clear Filters
</BButton>

<script>
const hasActiveFilters = computed(() => {
  return statusFilter.value !== null ||
         userFilter.value !== null ||
         dateRangeStart.value !== null ||
         dateRangeEnd.value !== null;
});

function clearFilters() {
  statusFilter.value = null;
  userFilter.value = null;
  dateRangeStart.value = null;
  dateRangeEnd.value = null;
}
</script>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No column filters | Column-specific filters (status, user, date) | Phase 36 | TBL-01, TBL-02: Curators can filter without scrolling through all rows |
| Inconsistent pagination | Standardized [10, 25, 50, 100] options | Phase 36 | TBL-03: Consistent UX across all curation views |
| Icon buttons without labels | aria-label + v-b-tooltip on all buttons | Phase 36 | TBL-05, TBL-06: Screen reader accessible, visual tooltips |
| ManageReReview no search | Global search across all columns | Phase 36 | TBL-04: Find specific batches/users quickly |
| Custom pagination markup | TablePaginationControls component | Phase 28 (reuse) | Consistent UI, less code duplication |

**Deprecated/outdated:**
- `pageOptions: [10, 25, 50, 200]`: Change 200 to 100 per TBL-03 requirement
- `pageOptions: [5, 10, 20, 50]`: ManageReReview should use standard [10, 25, 50, 100]
- Icon buttons without aria-label: All action buttons need aria-label for accessibility (TBL-05)

## Open Questions

Things that couldn't be fully resolved:

1. **Status filter options for ApproveReview**
   - What we know: ApproveReview shows unapproved reviews, status may refer to category or review_approved
   - What's unclear: What statuses to offer in dropdown? (Approved/Unapproved, or category names?)
   - Recommendation: Check API response structure—if no status enum, use category filter (already in stoplights_style mapping)

2. **Date range filter persistence**
   - What we know: Date filters add temporary state (dateRangeStart, dateRangeEnd)
   - What's unclear: Should date range persist across page refresh? (URL state sync like TablesEntities?)
   - Recommendation: Start with transient state (no URL sync). If users request bookmarkable filters, add URL state in follow-up phase

3. **Category filter for ApproveStatus**
   - What we know: ApproveStatus has category column (line 624-628), uses stoplights_style for variants
   - What's unclear: Should filter show category names or stoplight colors?
   - Recommendation: Use category names (textual) in dropdown for accessibility. Stoplight icons are visual aids only.

4. **User filter implementation**
   - What we know: TBL-01 and TBL-02 require "user" filter
   - What's unclear: Dropdown (select from loaded users) or text input (search by name)?
   - Recommendation: Text input with debounce—simpler, works for partial names, no need to load user list

## Sources

### Primary (HIGH confidence)
- Bootstrap-Vue-Next BTable filtering: [Table | BootstrapVueNext](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/table)
- VueUse useDebounceFn: [useDebounceFn | VueUse](https://vueuse.org/shared/useDebounceFn/)
- Existing codebase:
  - `/home/bernt-popp/development/sysndd/app/src/views/curate/ApproveReview.vue` (search + pagination pattern)
  - `/home/bernt-popp/development/sysndd/app/src/views/curate/ApproveStatus.vue` (similar pattern)
  - `/home/bernt-popp/development/sysndd/app/src/views/curate/ManageReReview.vue` (needs search)
  - `/home/bernt-popp/development/sysndd/app/src/components/small/TablePaginationControls.vue` (reusable component)
  - `/home/bernt-popp/development/sysndd/app/src/views/admin/AdminStatistics.vue` (date range pattern, lines 16-21)
- Requirements: `.planning/REQUIREMENTS.md` (TBL-01 through TBL-06)

### Secondary (MEDIUM confidence)
- [Build a data table in vue 3: Part 4 — With Filter Feature | by Edward Alozieuwa | Jan, 2026 | Medium](https://medium.com/@teddymczieuwa/build-a-data-table-in-vue-3-part-4-with-filter-feature-a92de8505fba) - Recent Vue 3 filtering patterns
- [Filtering | vue3-easy-data-table](https://hc200ok.github.io/vue3-easy-data-table-doc/features/filtering.html) - Client-side filtering approaches

### Tertiary (LOW confidence)
- [vue2-daterange-picker - npm](https://www.npmjs.com/package/vue2-daterange-picker) - Unmaintained (4 years), native date input preferred

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already installed, patterns proven in codebase
- Architecture: HIGH - Client-side filtering appropriate for small datasets, existing patterns work
- Pitfalls: HIGH - Documented from common filtering bugs (null checks, string comparison, sync issues)
- Code examples: HIGH - All examples from existing codebase or official docs

**Research date:** 2026-01-26
**Valid until:** 2026-02-26 (30 days for stable ecosystem—Bootstrap-Vue-Next, VueUse are mature)
