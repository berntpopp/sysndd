# Phase 28: Table Foundation - Research

**Researched:** 2026-01-25
**Domain:** Vue 3 admin tables with search, filtering, pagination, and URL state sync
**Confidence:** HIGH

## Summary

Phase 28 modernizes ManageUser and ManageOntology admin tables using the established TablesEntities pattern. The codebase already implements this pattern successfully in `/Entities` with VueUse's `useUrlSearchParams`, Bootstrap-Vue-Next 0.42.0 BTable, and module-level caching to prevent duplicate API calls.

**Key architectural decisions already in place:**
- URL state management via VueUse `useUrlSearchParams` with history mode
- Module-level API call tracking to survive component remounts (prevents duplicate calls)
- History.replaceState pattern to update URLs without triggering router navigation
- Composable-based architecture: `useTableData`, `useTableMethods`, `useFilterSync`
- Server-side pagination with keyset cursor (page_after ID, not offset-based)
- Excel/CSV export via existing xlsx library (already installed)

**Primary recommendation:** Follow the TablesEntities.vue pattern exactly—it solves all the tricky edge cases (component remount on URL change, duplicate API calls, URL state sync timing). Adapt the existing composables rather than building from scratch.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| VueUse | 14.1.0 | URL state sync via `useUrlSearchParams` | Official Vue ecosystem utility library, already used in codebase for URL state sync |
| Bootstrap-Vue-Next | 0.42.0 | BTable, BCard, BModal, BForm components | Vue 3 port of Bootstrap-Vue, all needed components available |
| xlsx | 0.18.5 | CSV/Excel export | SheetJS industry standard, already installed and used |
| file-saver | 2.0.5 | File download helper | Works with xlsx for client-side downloads |
| vee-validate | 4.15.1 | Form validation | Already used in ManageUser for edit modals |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| lodash/debounce | (via lodash) | Search input debouncing | If custom debounce needed (not required—VueUse provides useDebounceFn) |
| @zanmato/vue3-treeselect | 0.4.2 | Multi-select dropdowns | Already in package.json for complex filters |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| useUrlSearchParams | vue-query-synchronizer | VueUse is already installed, officially maintained, better docs |
| xlsx | vue3-json-excel | xlsx more flexible, supports both client and server export |
| BFormSelect | vue-multiselect | BFormSelect simpler, already styled consistently |

**Installation:**
No new packages needed—all dependencies already installed.

## Architecture Patterns

### Recommended Project Structure
Based on existing codebase structure:
```
src/
├── views/admin/
│   ├── ManageUser.vue           # Modernize with TablesEntities pattern
│   └── ManageOntology.vue       # Modernize with TablesEntities pattern
├── composables/
│   ├── useTableData.ts          # REUSE: Reactive table state
│   ├── useTableMethods.ts       # REUSE: Filter, sort, pagination handlers
│   ├── useFilterSync.ts         # REFERENCE: Singleton URL sync pattern (analysis-specific)
│   ├── useUrlParsing.ts         # REUSE: filterObjToStr, filterStrToObj utilities
│   └── useExcelExport.ts        # REUSE: Client-side Excel export
├── components/small/
│   ├── TableSearchInput.vue     # REUSE: Debounced search input
│   ├── TablePaginationControls.vue  # REUSE: Page size & navigation
│   └── GenericTable.vue         # REUSE: Sortable table with slots
└── components/ui/
    └── (badge components)       # Use for status/role display
```

### Pattern 1: Module-Level API Call Tracking
**What:** Prevent duplicate API calls when component remounts due to URL changes
**When to use:** Any table with URL state sync (critical for preventing race conditions)
**Example:**
```typescript
// Source: /home/bernt-popp/development/sysndd/app/src/components/tables/TablesEntities.vue (lines 266-272)
// Module-level variables to track API calls across component remounts
// This survives when Vue Router remounts the component on URL changes
let moduleLastApiParams = null;
let moduleApiCallInProgress = false;
let moduleLastApiCallTime = 0;
let moduleLastApiResponse = null; // Cache last API response for remounted components

// In doLoadData():
if (moduleLastApiParams === urlParam && (now - moduleLastApiCallTime) < 500) {
  if (moduleLastApiResponse) {
    this.applyApiResponse(moduleLastApiResponse);
    this.isBusy = false;
  }
  return;
}
```

### Pattern 2: URL Update Timing (Prevent Remount During API Call)
**What:** Update URL AFTER API success to prevent component remount mid-request
**When to use:** All URL-synced tables
**Example:**
```typescript
// Source: /home/bernt-popp/development/sysndd/app/src/components/tables/TablesEntities.vue (lines 583-634)
async doLoadData() {
  // ... API call ...
  const response = await this.axios.get(apiUrl);
  moduleApiCallInProgress = false;
  moduleLastApiResponse = response.data;
  this.applyApiResponse(response.data);

  // Update URL AFTER API success to prevent component remount during API call
  this.updateBrowserUrl();

  this.isBusy = false;
}

// Use history.replaceState instead of router.replace
updateBrowserUrl() {
  if (this.isInitializing) return;
  const searchParams = new URLSearchParams();
  // ... set params ...
  const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
  window.history.replaceState({ ...window.history.state }, '', newUrl);
}
```

### Pattern 3: VueUse URL State Sync
**What:** Reactive URL parameters that automatically sync with browser history
**When to use:** Bookmarkable filter/search/pagination state
**Example:**
```typescript
// Source: /home/bernt-popp/development/sysndd/app/src/composables/useFilterSync.ts (lines 122-151)
import { useUrlSearchParams } from '@vueuse/core';

const params = useUrlSearchParams('history', {
  removeNullishValues: true,  // Clean URLs: omit null/undefined
  removeFalsyValues: false,   // Keep empty strings if needed
  write: true,                // Auto-sync changes to URL
});

const filterState = computed<FilterState>(() => {
  const tabParam = Array.isArray(params.tab) ? params.tab[0] : params.tab;
  return {
    tab: isValidTab(tabParam) ? tabParam : 'clusters',
    search: searchParam || '',
    fdr: parseFloatSafe(fdrParam),
  };
});

// Update filter
const setSearch = (search: string): void => {
  params.search = search || undefined; // undefined removes from URL
};
```

### Pattern 4: Initialization Guard (Prevent Watcher Loops)
**What:** Prevent watchers from triggering during component initialization
**When to use:** All components with URL state that initialize from URL params
**Example:**
```typescript
// Source: /home/bernt-popp/development/sysndd/app/src/components/tables/TablesEntities.vue (lines 430-487)
data() {
  return {
    isInitializing: true, // Flag to prevent watchers from triggering during initialization
  };
},
watch: {
  filter: {
    handler() {
      if (this.isInitializing) return; // Skip during initialization
      this.filtered();
    },
    deep: true,
  },
},
mounted() {
  // ... parse URL params and set initial state ...
  this.loadData();
  // Delay marking initialization complete
  this.$nextTick(() => {
    this.isInitializing = false;
  });
}
```

### Pattern 5: Debounced Search Input
**What:** Delay API calls until user stops typing (300ms standard)
**When to use:** Global search and per-column filters
**Example:**
```typescript
// Source: Bootstrap-Vue-Next BFormInput supports debounce prop natively
<BFormInput
  v-model="filter.any.content"
  debounce="300"
  type="search"
  autocomplete="off"
  @update:model-value="filtered()"
/>

// For custom debounce (VueUse):
import { useDebounceFn } from '@vueuse/core';
const debouncedSearch = useDebounceFn(() => {
  filtered();
}, 300);
```

### Pattern 6: Filter Object Structure
**What:** Standardized filter object with content, operator, join_char
**When to use:** All table filters (enables complex queries)
**Example:**
```typescript
// Source: /home/bernt-popp/development/sysndd/app/src/components/tables/TablesEntities.vue (lines 313-325)
const filter = ref({
  any: { content: null, join_char: null, operator: 'contains' },
  user_name: { content: null, join_char: null, operator: 'contains' },
  email: { content: null, join_char: null, operator: 'contains' },
  user_role: { content: null, join_char: ',', operator: 'any' }, // Multi-select
  approved: { content: null, join_char: null, operator: 'equals' },
});

// Serialization via useUrlParsing composable
const filter_string = filterObjToStr(filter);
// Result: "user_name:contains:john,email:contains:@example.com"
```

### Anti-Patterns to Avoid
- **Using router.push/replace for URL updates:** Causes component remount and duplicate API calls. Use `history.replaceState` instead.
- **Updating URL before API call completes:** Triggers remount mid-request. Always update URL AFTER response.
- **Offset-based pagination:** API uses keyset cursor (page_after ID). Don't implement page number offsets.
- **Client-side filtering on large datasets:** API handles all filtering. Table only displays current page.
- **Watchers without initialization guard:** Causes duplicate API calls on mount. Always use `isInitializing` flag.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| URL state sync | Custom query param serialization | `useUrlSearchParams` (VueUse) | Handles arrays, nulls, history modes, edge cases automatically |
| Debounced search | Custom setTimeout logic | BFormInput `debounce` prop or `useDebounceFn` | Cleanup on unmount, proper cancellation, tested |
| Excel export | Custom CSV generation | `xlsx` + `useExcelExport` composable | Handles encoding, multi-sheet, formatting, already integrated |
| Filter serialization | Ad-hoc string building | `filterObjToStr` from `useUrlParsing` | Supports operators, join chars, escaping, tested |
| Pagination controls | Custom button logic | `TablePaginationControls.vue` component | Handles edge cases (first/last page), consistent UI |
| Module-level caching | Pinia store | Module-level variables (TablesEntities pattern) | Survives component remount without store overhead |
| Search text highlighting | v-html with regex | Computed property with safe escaping | Prevents XSS, handles special chars, consistent styling |

**Key insight:** The TablesEntities pattern already handles the tricky URL state sync timing issues. Component remount on URL change is the #1 source of bugs—the module-level caching pattern prevents duplicate API calls across remounts.

## Common Pitfalls

### Pitfall 1: Component Remount Causing Duplicate API Calls
**What goes wrong:** Changing URL params with `router.replace()` triggers component remount, causing duplicate API calls and race conditions.
**Why it happens:** Vue Router sees URL change and decides to remount the component, even if it's the same route.
**How to avoid:**
1. Use `history.replaceState()` instead of `router.replace()`
2. Implement module-level API call tracking (see TablesEntities pattern)
3. Update URL AFTER API success, not before
**Warning signs:**
- Double API calls in network tab when changing filters
- Stale data appearing briefly before refresh
- Console warnings about cancelled requests

### Pitfall 2: Watchers Triggering on Mount
**What goes wrong:** Setting initial filter state from URL triggers watchers, causing duplicate API call (once from `mounted()`, once from watcher).
**Why it happens:** Vue 3 watchers fire immediately when reactive data changes, including during initialization.
**How to avoid:** Use `isInitializing` flag pattern (see TablesEntities.vue lines 430-487)
**Warning signs:**
- Two API calls on page load
- Network tab shows identical requests within 50ms
- `loadData()` called twice in Vue DevTools timeline

### Pitfall 3: Missing primary-key on BTable
**What goes wrong:** BTable re-renders all rows on any data change, causing performance issues with >100 rows.
**Why it happens:** Without `primary-key`, Vue can't track which rows changed and re-renders everything.
**How to avoid:** Always set `:primary-key="user_id"` on BTable (or appropriate unique field)
**Warning signs:**
- Sluggish UI when filtering
- Entire table flickers on data update
- High CPU usage during table updates

### Pitfall 4: Debounce on Component Instead of Module Level
**What goes wrong:** Creating new debounced function in component `setup()` breaks on remount—debounce timer is lost.
**Why it happens:** Component remount creates new component instance with new debounce timer.
**How to avoid:** Use BFormInput's built-in `debounce` prop or put debounce logic in composable/module scope
**Warning signs:**
- Search doesn't debounce after navigating back via browser button
- Rapid API calls after history navigation

### Pitfall 5: Incorrect Pagination Reset
**What goes wrong:** Changing filters doesn't reset to page 1, showing "No results" even when results exist.
**Why it happens:** Forgot to set `currentItemID = 0` when filters change.
**How to avoid:** Always reset pagination in `filtered()` method before calling API
**Warning signs:**
- Empty table after applying filter that should match data
- Page 2+ shown but no data visible
- Total count > 0 but items array empty

### Pitfall 6: URL State Sync Disabled on Initialization
**What goes wrong:** Initial URL params aren't applied, page loads with defaults instead of URL state.
**Why it happens:** `updateBrowserUrl()` checks `isInitializing` and returns early.
**How to avoid:** Parse URL params in `mounted()` BEFORE calling `loadData()`, only block URL updates during init
**Warning signs:**
- Bookmarked URL loads with default filters instead of saved filters
- Refresh clears active filters
- Browser back button doesn't restore previous state

## Code Examples

Verified patterns from official sources and existing codebase:

### Debounced Search Input
```vue
<!-- Source: /home/bernt-popp/development/sysndd/app/src/components/tables/TablesEntities.vue -->
<BFormInput
  v-model="filter.any.content"
  placeholder="Search any field by typing here"
  debounce="300"
  type="search"
  autocomplete="off"
  @update:model-value="filtered()"
/>
```

### Multi-Select Filter (Role/Status)
```vue
<!-- Source: Bootstrap-Vue-Next BFormSelect with multiple option -->
<BFormSelect
  v-model="filter.user_role.content"
  :options="roleOptions"
  size="sm"
  multiple
  @update:model-value="filtered()"
>
  <template #first>
    <BFormSelectOption :value="null">
      All Roles
    </BFormSelectOption>
  </template>
</BFormSelect>
```

### Search Text Highlighting
```typescript
// Safe highlighting with computed property (prevents XSS)
const highlightMatch = (text: string, search: string): string => {
  if (!search || !text) return text;
  const escapedSearch = search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex = new RegExp(`(${escapedSearch})`, 'gi');
  return text.replace(regex, '<mark>$1</mark>');
};

// In template:
<td v-html="highlightMatch(row.user_name, filter.any.content)" />

// Or CSS-based (safer):
<style scoped>
.table-row:has(.search-match) {
  background-color: #fff3cd;
}
</style>
```

### CSV Export (Client-Side)
```typescript
// Source: /home/bernt-popp/development/sysndd/app/src/composables/useExcelExport.ts
import { useExcelExport } from '@/composables';

const { isExporting, exportToExcel } = useExcelExport();

const handleExport = () => {
  exportToExcel(filteredUsers.value, {
    filename: 'users_export',
    sheetName: 'Users',
    headers: {
      user_name: 'Name',
      email: 'Email',
      user_role: 'Role',
      approved: 'Approved',
    },
  });
};
```

### Server-Side Paginated API Call
```typescript
// Source: /home/bernt-popp/development/sysndd/app/src/components/tables/TablesEntities.vue (lines 583-634)
async loadUserTableData() {
  const urlParam = `sort=${this.sort}&filter=${this.filter_string}&page_after=${this.currentItemID}&page_size=${this.perPage}`;
  const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/table?${urlParam}`;

  const response = await this.axios.get(apiUrl, {
    headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
  });

  // API returns: { data: [...], meta: [{ totalItems, currentPage, totalPages, prevItemID, nextItemID, lastItemID }] }
  this.items = response.data.data;
  this.totalRows = response.data.meta[0].totalItems;
  this.currentPage = response.data.meta[0].currentPage;
  this.nextItemID = response.data.meta[0].nextItemID;
  this.prevItemID = response.data.meta[0].prevItemID;
  this.lastItemID = response.data.meta[0].lastItemID;
}
```

### Filter Pills Display
```vue
<!-- Active filter pills with remove buttons -->
<div v-if="activeFilters.length" class="mb-2">
  <BBadge
    v-for="(filter, index) in activeFilters"
    :key="index"
    variant="secondary"
    class="me-2"
  >
    {{ filter.label }}: {{ filter.value }}
    <BButton
      size="sm"
      variant="link"
      class="p-0 ms-1"
      @click="removeFilter(filter.key)"
    >
      <i class="bi bi-x" />
    </BButton>
  </BBadge>
</div>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Bootstrap-Vue (Vue 2) | Bootstrap-Vue-Next 0.42.0 (Vue 3) | 2024-2025 migration | New array-based `sortBy` format, v-model changes |
| Offset pagination (page*size) | Keyset cursor (page_after ID) | Pre-existing | Better performance, consistent results during concurrent writes |
| router.push/replace for URL | history.replaceState | TablesEntities implementation | Prevents component remount, eliminates duplicate API calls |
| Component-level state | Module-level API tracking | TablesEntities pattern | Survives component remount, caches responses |
| Manual debounce with setTimeout | BFormInput `debounce` prop | Bootstrap-Vue-Next 0.42.0 | Simpler, automatic cleanup, fewer bugs |
| vue-treeselect (Vue 2) | @zanmato/vue3-treeselect 0.4.2 | Vue 3 migration | Vue 3 compatible multi-select |

**Deprecated/outdated:**
- `router.replace()` for URL updates: Causes component remount and duplicate API calls. Use `history.replaceState()`.
- Offset-based pagination: API doesn't support `page=2&size=20`. Use keyset cursor `page_after=ID`.
- `sortBy` as string: Bootstrap-Vue-Next uses array format `[{ key: 'column', order: 'asc' }]`.
- Accessing `$route.query` directly in component: Causes remount issues. Use `useUrlSearchParams` or manual `URLSearchParams`.

## Open Questions

Things that couldn't be fully resolved:

1. **ManageOntology specific columns**
   - What we know: ManageUser has defined columns (Name, Email, Role, Status, Institution, Last Login)
   - What's unclear: ManageOntology table structure not specified in context
   - Recommendation: Follow similar pattern—6-8 core columns, sortable, no column toggle menu

2. **Backend API endpoint support**
   - What we know: `/api/user/table` exists (used in current ManageUser), likely returns all users
   - What's unclear: Does backend support pagination parameters (`page_after`, `page_size`, `filter`, `sort`)?
   - Recommendation: Check backend API or add pagination support in Phase 28 scope. TablesEntities uses `/api/entity/` with full pagination.

3. **Highlight styling preference**
   - What we know: Context says "bold or background-color"
   - What's unclear: Which is preferred for this specific UI
   - Recommendation: Use `<mark>` tag (yellow background) for accessibility and consistency with browser find-in-page

4. **Multi-select filter UI library**
   - What we know: Context specifies multi-select dropdown for roles
   - What's unclear: Use Bootstrap-Vue-Next native `<BFormSelect multiple>` or vue3-treeselect?
   - Recommendation: Start with BFormSelect (simpler, consistent styling). Upgrade to vue3-treeselect only if search-in-dropdown needed.

## Sources

### Primary (HIGH confidence)
- VueUse useUrlSearchParams: https://vueuse.org/core/useurlsearchparams/
- Bootstrap-Vue-Next BTable: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/table
- Existing codebase: `/home/bernt-popp/development/sysndd/app/src/components/tables/TablesEntities.vue` (production pattern)
- Existing composables: `/home/bernt-popp/development/sysndd/app/src/composables/useFilterSync.ts`, `useTableData.ts`, `useTableMethods.ts`
- Package.json: Verified all library versions

### Secondary (MEDIUM confidence)
- Vue 3 debounce best practices: https://blog.logrocket.com/debounce-throttle-vue/ (2024 article, verified with codebase patterns)
- Bootstrap-Vue-Next performance: https://github.com/bootstrap-vue/bootstrap-vue/issues/4155 (legacy Bootstrap-Vue, likely still relevant)
- Excel export libraries: https://github.com/pratik227/vue3-json-excel (verified xlsx is better choice)

### Tertiary (LOW confidence)
- Search highlighting libraries: https://www.npmjs.com/package/vue-highlight-words (not needed—simple regex sufficient)
- URL state sync alternatives: https://github.com/chronicstone/vue-route-query (VueUse is better choice)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already installed and in use
- Architecture: HIGH - TablesEntities pattern is production-tested and handles edge cases
- Pitfalls: HIGH - Documented from existing codebase issues (module-level caching added to fix remount bug)
- Code examples: HIGH - All examples from existing production code or official docs

**Research date:** 2026-01-25
**Valid until:** 2026-02-25 (30 days for stable ecosystem—VueUse, Bootstrap-Vue-Next are mature)
