# SysNDD Admin Forms UI/UX Review Report

**Review Date:** 2026-01-24
**Reviewer:** UI/UX Expert Review via Playwright Testing
**Reference Standard:** `/Entities` page (exemplary implementation)

---

## Executive Summary

This comprehensive review evaluates six admin pages against the reference implementation (`/Entities`) and industry best practices for medical curation applications. The review identifies **4 critical bugs**, **2 major issues**, and provides detailed debugging analysis with concrete code fixes.

### Overall Ratings Summary

| Page | Rating | Status | Critical Issues |
|------|--------|--------|-----------------|
| ManageUser | 1/10 | **BROKEN** | useModalControls bug + potential API data issue |
| ManageOntology | 4/10 | **PARTIALLY BROKEN** | useModalControls bug - edit buttons fail |
| ManageAbout | 2/10 | **EMPTY** | No content implemented |
| AdminStatistics | 6/10 | Functional | Missing form validation |
| ManageAnnotations | 7/10 | Functional | Minor UX improvements needed |
| ViewLogs | 4/10 | **PARTIALLY BROKEN** | Pagination broken - composable/methods conflict |

---

## Technology Stack

- **Vue.js 3.5.25** with Composition API
- **Bootstrap-Vue-Next 0.42.0** (Bootstrap 5 components)
- **Vite 7.3.1** (build tool)
- **TypeScript 5.9.3**
- **Pinia 2.0.14** (state management)
- **VeeValidate 4.15.1** (form validation)

---

## Critical Bug Analysis

### Bug #1: `useModalControls()` Called Outside Setup Context

**Affected Pages:** ManageUser.vue, ManageOntology.vue

**Error Message:**
```
Error: useModal() must be called within setup(), and BApp, useRegistry or plugin must be installed/provided.
    at useModal (bootstrap-vue-next.js:5211:11)
    at useModalControls (useModalControls.ts:3:17)
```

**Root Cause Analysis:**

The `useModalControls` composable at `src/composables/useModalControls.ts` calls `useModal()` from bootstrap-vue-next:

```typescript
// src/composables/useModalControls.ts (Line 9)
export default function useModalControls(): ModalControls {
  const modal = useModal();  // <-- This MUST be called in setup() context
  // ...
}
```

The problem is this composable is called **inside methods** instead of in `setup()`:

**ManageUser.vue (Lines 416, 435, 452):**
```javascript
promptDeleteUser(item, button) {
  // ...
  const { showModal } = useModalControls();  // BUG: Called in method!
  showModal(this.deleteUserModal.id);
}

editUser(item, button) {
  // ...
  const { showModal } = useModalControls();  // BUG: Called in method!
  showModal(this.updateUserModal.id);
}
```

**ManageOntology.vue (Lines 257, 289):**
```javascript
editOntology(item, button) {
  // ...
  const { showModal } = useModalControls();  // BUG: Called in method!
  showModal(this.updateOntologyModal.id);
}

async updateOntologyData() {
  // ...
  const { hideModal } = useModalControls();  // BUG: Called in method!
  hideModal(this.updateOntologyModal.id);
}
```

**Vue Composition API Rule:** Composables that use other composables (like `useModal`) must be called synchronously in `setup()`, not in event handlers or lifecycle hooks.

---

### Bug #2: ManageUser Table Render Failure

**Error Message:**
```
TypeError: (intermediate value)(intermediate value)(intermediate value).reduce is not a function
    at ComputedRefImpl.fn (bootstrap-vue-next.js:19309:84)
```

**Root Cause Analysis:**

This error occurs inside Bootstrap-Vue-Next's `BTable` component when it tries to process `items`. The `.reduce()` method fails because `items` is not an array.

**Possible causes:**
1. API returns non-array data (e.g., error object, null, or `{ data: [...] }` wrapper)
2. Race condition where template renders before `isLoading` is set
3. Error handling doesn't reset `users` to empty array

**Current code (ManageUser.vue lines 374-390):**
```javascript
async loadUserTableData() {
  this.isLoading = true;
  const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/table`;
  try {
    const response = await this.axios.get(apiUrl, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    });
    this.users = response.data;  // No validation that this is an array!
  } catch (e) {
    this.makeToast(e.message, 'Error', 'danger');
    // BUG: users is not reset to [] on error!
  }
  // ...
  this.isLoading = false;
}
```

---

### Bug #3: AdminStatistics Missing Form Validation

**Issue:** Form allows submission with empty `startDate`, causing API error.

**Current code (AdminStatistics.vue lines 163-194):**
```javascript
async fetchStatistics() {
  try {
    // No validation - startDate can be empty!
    const updatesResponse = await this.axios.get(
      `${import.meta.env.VITE_API_URL}/api/statistics/updates?start_date=${this.startDate}&end_date=${this.endDate}`
    );
    // ...
  } catch (error) {
    this.makeToast('Failed to fetch statistics', 'Error', 'danger');
    // Generic error message - not helpful
  }
}
```

**API Error:**
```
GET /api/statistics/updates?start_date=&end_date=2026-01-24 → 500 Error
```

---

### Bug #4: ViewLogs Pagination Not Triggering API Calls (CRITICAL)

**Affected Page:** ViewLogs (TablesLogs.vue)

**Symptoms:**
- Clicking pagination buttons (page 2, next, etc.) updates the pagination UI
- Table data remains unchanged (same IDs displayed)
- No new API request is made to fetch page 2 data
- Network shows only initial `page_after=0` request

**Root Cause Analysis:**

This is a **composable/methods shadowing conflict** with **missing dependency injection**.

**The Problem Chain:**

1. `useTableMethods` composable returns `handlePageChange` and `filtered` functions
2. `TablesLogs.vue` spreads these into setup return: `...tableMethods`
3. `TablesLogs.vue` ALSO defines `handlePageChange` and `filtered` in methods{}
4. The composable's `handlePageChange` internally calls the composable's `filtered()` (closure reference)
5. The composable's `filtered()` checks if `options.loadData` exists before calling it
6. **`loadData` was NOT passed** to `useTableMethods` options!
7. Result: `filtered()` never calls `loadData()` → no API request

**Code Evidence:**

`src/composables/useTableMethods.ts` (lines 65-82):
```typescript
const filtered = (): void => {
  if (!options.filterObjToStr || !options.filter) {
    console.warn('filterObjToStr or filter not provided to useTableMethods');
    return;
  }
  // ... filter string processing ...

  // Call loadData if provided
  if (options.loadData) {
    options.loadData();  // Only called if loadData was passed!
  }
};
```

`src/components/tables/TablesLogs.vue` (lines 313-319):
```javascript
// Table methods composable - loadData NOT passed!
const tableMethods = useTableMethods(tableData, {
  filter,
  filterObjToStr,
  apiEndpoint: props.apiEndpoint,
  axios,
  route,
  // MISSING: loadData is not passed here!
});
```

**Why the methods version isn't being used:**

When `handlePageChange` from the composable runs, it calls `filtered()` which is a closure reference to the composable's own `filtered` function - NOT the component's `methods.filtered()`. This is standard JavaScript closure behavior.

The event flow:
1. User clicks page 2
2. `TablePaginationControls` emits `page-change: 2`
3. Vue resolves `@page-change="handlePageChange"` to the setup-returned version (from `...tableMethods`)
4. Composable's `handlePageChange(2)` sets `currentItemID` correctly
5. Composable's `handlePageChange` calls composable's `filtered()` (closure)
6. Composable's `filtered()` checks `if (options.loadData)` → FALSE
7. `loadData()` is never called → no API request

---

## Detailed Solutions

### Solution #1: Fix useModalControls Usage Pattern

**Option A: Move composable call to setup() (Recommended)**

```javascript
// ManageUser.vue - FIXED VERSION
export default {
  name: 'ManageUser',
  components: { GenericTable },
  setup() {
    const { makeToast } = useToast();
    const { showModal, hideModal } = useModalControls();  // Call here!

    // ... other setup code ...

    return {
      makeToast,
      showModal,   // Expose to template/methods
      hideModal,   // Expose to template/methods
      // ... other returns
    };
  },
  methods: {
    promptDeleteUser(item, button) {
      this.userToDelete = item;
      this.showModal(this.deleteUserModal.id);  // Use via this
    },
    editUser(item, button) {
      this.userToUpdate = { ...item };
      this.showModal(this.updateUserModal.id);  // Use via this
    },
    async confirmDeleteUser() {
      // ... API call ...
      this.hideModal(this.deleteUserModal.id);  // Use via this
    },
  },
};
```

**Option B: Use v-model on BModal (Alternative)**

Bootstrap-Vue-Next modals support `v-model`:

```vue
<template>
  <BModal v-model="showDeleteModal" title="Confirm Deletion">
    <!-- content -->
  </BModal>
</template>

<script>
export default {
  data() {
    return {
      showDeleteModal: false,
    };
  },
  methods: {
    promptDeleteUser(item) {
      this.userToDelete = item;
      this.showDeleteModal = true;  // Simple boolean toggle
    },
  },
};
</script>
```

---

### Solution #2: Fix ManageUser Data Handling

```javascript
// ManageUser.vue - FIXED loadUserTableData
async loadUserTableData() {
  this.isLoading = true;
  this.users = [];  // Reset to empty array first

  const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/table`;
  try {
    const response = await this.axios.get(apiUrl, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    });

    // Defensive: ensure response.data is an array
    if (Array.isArray(response.data)) {
      this.users = response.data;
    } else if (response.data?.data && Array.isArray(response.data.data)) {
      // Handle wrapped response: { data: [...] }
      this.users = response.data.data;
    } else {
      console.error('Unexpected API response format:', response.data);
      this.users = [];
      this.makeToast('Invalid data format received', 'Warning', 'warning');
    }
  } catch (e) {
    console.error('Failed to load users:', e);
    this.users = [];  // Ensure users is always an array
    this.makeToast(e.response?.data?.message || e.message, 'Error', 'danger');
  }

  const uiStore = useUiStore();
  uiStore.requestScrollbarUpdate();
  this.isLoading = false;
}
```

---

### Solution #3: Fix AdminStatistics Validation

```vue
<template>
  <BForm @submit.prevent="fetchStatistics">
    <BFormGroup label="Start Date" :state="startDateState">
      <BFormInput
        v-model="startDate"
        type="date"
        :state="startDateState"
        required
      />
      <BFormInvalidFeedback>
        Start date is required
      </BFormInvalidFeedback>
    </BFormGroup>
    <BFormGroup label="End Date">
      <BFormInput
        v-model="endDate"
        type="date"
        required
      />
    </BFormGroup>
    <BButton
      type="submit"
      variant="primary"
      :disabled="!isFormValid"
    >
      Get Statistics
    </BButton>
  </BForm>
</template>

<script>
export default {
  data() {
    return {
      startDate: this.getDefaultStartDate(),  // Default to 30 days ago
      endDate: new Date().toISOString().split('T')[0],
      // ...
    };
  },
  computed: {
    startDateState() {
      return this.startDate ? true : false;
    },
    isFormValid() {
      return this.startDate && this.endDate;
    },
  },
  methods: {
    getDefaultStartDate() {
      const date = new Date();
      date.setDate(date.getDate() - 30);
      return date.toISOString().split('T')[0];
    },
    async fetchStatistics() {
      if (!this.isFormValid) {
        this.makeToast('Please fill in all required fields', 'Validation Error', 'warning');
        return;
      }
      // ... rest of the method
    },
  },
};
</script>
```

---

### Solution #4: Apply Same Pattern to ManageOntology

```javascript
// ManageOntology.vue - FIXED VERSION
export default {
  name: 'ManageOntology',
  components: { GenericTable },
  setup() {
    const { makeToast } = useToast();
    const { showModal, hideModal } = useModalControls();  // Call in setup!
    return { makeToast, showModal, hideModal };
  },
  // ... data, computed ...
  methods: {
    async loadOntologyTableData() {
      this.isLoading = true;
      this.ontologies = [];  // Reset first

      try {
        const response = await this.axios.get(apiUrl, { /* ... */ });
        this.ontologies = Array.isArray(response.data) ? response.data : [];
      } catch (e) {
        this.ontologies = [];
        this.makeToast(e.message, 'Error', 'danger');
      }
      this.isLoading = false;
    },
    editOntology(item, button) {
      this.ontologyToUpdate = { ...item };  // Clone to avoid mutation
      this.showModal(this.updateOntologyModal.id);  // Use via this
    },
    async updateOntologyData() {
      // ... API call ...
      this.hideModal(this.updateOntologyModal.id);  // Use via this
      this.ontologyToUpdate = {};
    },
  },
};
```

---

### Solution #5: Fix ViewLogs Pagination (Critical)

**Option A: Remove Duplicate Methods (Recommended)**

Remove the duplicate method definitions from `TablesLogs.vue` and rely solely on the composable methods. This ensures consistent behavior and avoids shadowing conflicts.

```javascript
// TablesLogs.vue - FIXED VERSION
export default {
  name: 'TablesLogs',
  // ... components, props ...
  setup(props) {
    // ... existing setup code ...

    // Define loadData as a function that can be passed to composable
    const loadData = async () => {
      tableData.isBusy.value = true;
      try {
        const response = await axios.get(`${import.meta.env.VITE_API_URL}/api/logs`, {
          params: {
            sort: tableData.sort.value,
            filter: tableData.filter_string.value,
            page_after: tableData.currentItemID.value,
            page_size: tableData.perPage.value,
          },
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        tableData.items.value = response.data.data;
        tableData.totalRows.value = response.data.meta[0].totalItems;
        tableData.currentPage.value = response.data.meta[0].currentPage;
        tableData.prevItemID.value = response.data.meta[0].prevItemID;
        tableData.currentItemID.value = response.data.meta[0].currentItemID;
        tableData.nextItemID.value = response.data.meta[0].nextItemID;
        tableData.lastItemID.value = response.data.meta[0].lastItemID;
        tableData.executionTime.value = response.data.meta[0].executionTime;
        // Handle fields from response
      } catch (error) {
        makeToast(`Error: ${error.message}`, 'Error loading logs', 'danger');
      } finally {
        tableData.isBusy.value = false;
      }
    };

    // Pass loadData to the composable
    const tableMethods = useTableMethods(tableData, {
      filter,
      filterObjToStr,
      loadData,  // NOW PASSED!
      apiEndpoint: props.apiEndpoint,
      axios,
      route,
    });

    return {
      // ... existing returns ...
      ...tableMethods,
      loadData,  // Also expose if needed
    };
  },
  // REMOVE duplicate method definitions:
  // - handlePageChange (use composable version)
  // - filtered (use composable version)
  // - handleSortByOrDescChange (use composable version)
  methods: {
    // Keep only component-specific methods:
    formatDate(dateStr) { /* ... */ },
    getMethodVariant(method) { /* ... */ },
    normalizeSelectOptions(options) { /* ... */ },
    // ... other unique methods
  },
};
```

**Option B: Keep Methods but Fix the Closure Issue**

If you prefer to keep the methods, ensure they're the ones being called by NOT spreading `...tableMethods` for functions that are also in methods:

```javascript
// TablesLogs.vue - Alternative Fix
setup(props) {
  // ... existing setup code ...

  const tableMethods = useTableMethods(tableData, {
    filter,
    filterObjToStr,
    apiEndpoint: props.apiEndpoint,
    axios,
    route,
  });

  // DON'T spread tableMethods for methods that are duplicated
  // Only return the reactive data, not the methods
  return {
    makeToast,
    filterObjToStr,
    filterStrToObj,
    sortStringToVariables,
    ...colorAndSymbols,
    ...text,
    ...tableData,  // Reactive state only
    filter,
    axios,
    // DON'T include ...tableMethods here if you have methods{} versions
  };
},
methods: {
  // These now have full control
  handlePageChange(value) {
    const totalPages = Math.ceil(this.totalRows / this.perPage);
    if (value === 1) {
      this.currentItemID = 0;
    } else if (value === totalPages) {
      this.currentItemID = this.lastItemID;
    } else if (value > this.currentPage) {
      this.currentItemID = this.nextItemID;
    } else if (value < this.currentPage) {
      this.currentItemID = this.prevItemID;
    }
    this.filtered();  // Calls methods.filtered()
  },
  filtered() {
    const filter_string_loc = this.filterObjToStr(this.filter);
    if (filter_string_loc !== this.filter_string) {
      this.filter_string = filter_string_loc;
    }
    this.loadData();  // Calls methods.loadData()
  },
  async loadData() {
    // ... existing implementation ...
  },
},
```

**Option C: Refactor to Full Composition API (Best Long-term)**

Convert `TablesLogs.vue` to use `<script setup>` syntax, eliminating the Options API methods entirely:

```vue
<script setup lang="ts">
import { ref, watch, onMounted } from 'vue';
// ... imports ...

const props = defineProps<{
  apiEndpoint?: string;
  // ... other props
}>();

// All logic in setup - no shadowing possible
const { makeToast } = useToast();
const tableData = useTableData({ /* ... */ });

const loadData = async () => {
  // ... implementation
};

const tableMethods = useTableMethods(tableData, {
  filter,
  filterObjToStr,
  loadData,  // Passed correctly
  // ...
});

// Use tableMethods.handlePageChange, tableMethods.filtered directly
// No methods{} block to cause conflicts

onMounted(() => {
  loadData();
});
</script>
```

---

## UI/UX Consistency Issues

### ManageOntology Missing Features (vs Entities Reference)

| Feature | Entities | ManageOntology | Fix Required |
|---------|----------|----------------|--------------|
| Global search | Yes | No | Add search input |
| Column filters | Yes | No | Add filter row |
| Pagination | Yes | No | Add pagination (495 rows!) |
| Per-page selector | Yes | No | Add dropdown |
| Export buttons | Yes | No | Add .xlsx export |

**Recommendation:** Refactor ManageOntology to use the same composable-based pattern as TablesLogs/TablesEntities for consistency.

---

## ViewLogs Testing Results

Tested functionality:
- **Global search:** Working - filtered 70,685 to 1,047 entries with "signin"
- **Column filters:** Working - Status=401 filtered to 58 entries
- **Pagination:** **BROKEN** - UI updates but table data doesn't change, no API call made
- **Sorting:** Working - column headers clickable

**Pagination Bug Evidence:**
- Initial load: Table shows IDs 777722-777713 with `page_after=0`
- Click page 2: Pagination button shows active, but table still shows same IDs
- Network: Only one API call made (initial), no second call for page 2
- Console: No errors logged

---

## Priority Implementation Order

### P0 - Critical (Fix Today)
1. Fix `useModalControls()` in ManageUser.vue setup()
2. Fix `useModalControls()` in ManageOntology.vue setup()
3. Add defensive array handling in loadUserTableData()
4. **Fix ViewLogs pagination** - remove duplicate methods or pass loadData to composable

### P1 - High (This Sprint)
4. Add defensive array handling in loadOntologyTableData()
5. Add form validation to AdminStatistics.vue
6. Add default date range to AdminStatistics.vue

### P2 - Medium (Next Sprint)
7. Add pagination to ManageOntology (495 rows is too many)
8. Add search/filter to ManageOntology
9. Implement or remove ManageAbout

### P3 - Low (Backlog)
10. Add loading states to ManageAnnotations buttons
11. Add status color coding to ViewLogs
12. Standardize card styling across admin pages

---

## Files Requiring Changes

| File | Changes Needed |
|------|----------------|
| `src/views/admin/ManageUser.vue` | Move useModalControls to setup(), add array validation |
| `src/views/admin/ManageOntology.vue` | Move useModalControls to setup(), add array validation |
| `src/views/admin/AdminStatistics.vue` | Add form validation, default dates |
| `src/views/admin/ManageAbout.vue` | Implement content or remove route |
| `src/composables/useModalControls.ts` | Consider adding JSDoc warning about setup() requirement |
| `src/components/tables/TablesLogs.vue` | **CRITICAL:** Fix pagination - pass loadData to useTableMethods OR remove duplicate methods |
| `src/composables/useTableMethods.ts` | Consider making loadData required OR add warning if not provided |

---

## Testing Checklist

After fixes, verify:

- [ ] ManageUser page loads without console errors
- [ ] ManageUser edit modal opens correctly
- [ ] ManageUser delete modal opens correctly
- [ ] ManageOntology page loads without console errors
- [ ] ManageOntology edit modal opens correctly
- [ ] AdminStatistics validates required start date
- [ ] AdminStatistics shows default date range
- [ ] **ViewLogs pagination navigates to page 2 correctly**
- [ ] **ViewLogs pagination makes new API call with correct page_after parameter**
- [ ] **ViewLogs table data updates when changing pages**
- [ ] All admin pages have consistent styling

---

## References

- [Bootstrap-Vue-Next Modal Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/components/modal.html)
- [Vue 3 Composition API - Composables](https://vuejs.org/guide/reusability/composables.html)
- [VeeValidate 4 Documentation](https://vee-validate.logaretm.com/v4/)
