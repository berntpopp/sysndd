# Curation Workflow Modernization Pitfalls

**Domain:** Scientific database curation interface modernization
**Researched:** 2026-01-26
**Context:** SysNDD v7 milestone - curation views and re-review system
**Confidence:** HIGH (codebase analysis + domain patterns)

## Executive Summary

Modernizing curation workflows in an existing scientific database presents unique challenges distinct from building new features. The primary risks center around: (1) **data format mismatches** between legacy API responses and modern component expectations causing runtime crashes, (2) **third-party component incompatibilities** with Vue 3 (vue3-treeselect multi-select), and (3) **hardcoded business logic** in batch management preventing dynamic workflow evolution. The codebase already demonstrates both problematic patterns (ApproveUser's data assumptions) and good patterns (ManageUser's robust implementation) - the key is selectively applying modern patterns while not breaking working legacy code.

---

## Critical Pitfalls

Mistakes that cause page crashes, data corruption, or blocked workflows.

### Pitfall 1: API Response Format Mismatch (TypeError: reduce is not a function)

**What goes wrong:**
Component expects `response.data` to be an array but API returns:
- An object with nested data: `{ data: [...], meta: {...} }`
- An empty response: `null` or `undefined`
- A single object instead of array: `{ user_id: 1, ... }`

Calling `.map()`, `.reduce()`, `.length` on non-arrays causes `TypeError: X is not a function`.

**Why it happens:**
SysNDD has two API response patterns:
1. **Legacy pattern:** Direct array `response.data = [...]` (used by `/api/user/table`)
2. **Modern pattern:** Paginated wrapper `response.data = { data: [...], meta: {...] }` (used by `/api/entity`)

ApproveUser.vue (line 237) assumes legacy pattern:
```javascript
this.items_UsersTable = response.data;
this.totalRows_UsersTable = response.data.length;
```

If the API is updated to modern pattern or returns error object, this crashes.

**Real-world scenario (ApproveUser crash):**
1. User navigates to ApproveUser page
2. API returns `{ data: [], meta: { totalItems: 0 } }` (modern format after endpoint update)
3. `response.data.length` returns `undefined` (objects don't have `.length` property)
4. Page crashes with "TypeError: Cannot read properties of undefined"

**Evidence from codebase:**
- ApproveUser.vue (line 237-238): No defensive checks before accessing `.length`
- ManageUser.vue (line 1384-1388): Correct pattern with proper data extraction:
  ```javascript
  this.users = data.data;
  this.totalRows = data.meta[0].totalItems;
  ```

**Consequences:**
- Page completely fails to load (blank screen)
- Curators cannot approve users during critical periods
- Error message unhelpful for non-developers

**Prevention:**
1. **Always validate API response structure:**
   ```javascript
   const items = Array.isArray(response.data)
     ? response.data
     : response.data?.data || [];
   this.totalRows = items.length;
   ```

2. **Use TypeScript interfaces for API responses:**
   ```typescript
   interface LegacyResponse<T> { data: T[] }
   interface PaginatedResponse<T> { data: { data: T[], meta: PaginationMeta[] } }
   ```

3. **Add error boundary to catch and display errors gracefully:**
   ```vue
   <template>
     <ErrorBoundary :onError="handleError">
       <BTable :items="items" />
     </ErrorBoundary>
   </template>
   ```

4. **Create useApiResponse composable** - Normalize both response formats to consistent shape

**Detection (warning signs):**
- Direct `response.data.length` without `Array.isArray()` check
- No try/catch around API data transformation
- Component crashes when API endpoint is updated
- Error logs show "TypeError: X is not a function" on array methods

**Which phase should address this:** Phase 1 - Fix ApproveUser crash before any other curation modernization

---

### Pitfall 2: vue3-treeselect Multi-Select Initialization Bug

**What goes wrong:**
vue3-treeselect with `multiple="true"` crashes when v-model is initialized with non-null value:
- Setting `value: ['phenotype-1']` in data() throws: "TypeError: Cannot read property 'id' of undefined at Proxy.isSelected"
- Multi-select silently fails, component appears but selections don't work
- Downgrading to single-select loses functionality (curators can only select one phenotype)

**Why it happens:**
This is a [documented bug in vue3-treeselect](https://github.com/megafetis/vue3-treeselect/issues/4) where the internal `isSelected` function doesn't check for null before accessing node properties.

**Evidence from codebase:**
Multiple components have vue3-treeselect disabled with TODO comments:
- ModifyEntity.vue (line 39-49, 158-168, 250-260, 322-333, 355-365, 552-559): 6 instances commented out
- ApproveReview.vue (line 535-545, 567-577, 890-897): 3 instances commented out
- ApproveStatus.vue (line 461-468): 1 instance commented out

Current workaround uses BFormSelect with single selection:
```vue
<BFormSelect
  v-model="select_phenotype[0]"  <!-- Only first item, breaks multi-select -->
  :options="normalizePhenotypesOptions(phenotypes_options)"
/>
```

**Real-world scenario:**
1. Curator tries to add phenotypes to entity review
2. Originally could select "Intellectual disability" AND "Seizures" AND "Microcephaly"
3. Now can only select ONE phenotype (BFormSelect single mode)
4. Data quality degrades - entities missing phenotype associations

**Consequences:**
- Reduced curation accuracy (can't capture full phenotype spectrum)
- Workaround breaks scientific workflow (entities have multiple phenotypes)
- Technical debt: 10+ components need fixing when solution found

**Prevention:**
1. **Use @zanmato/vue3-treeselect fork** - May have fix:
   ```bash
   npm install @zanmato/vue3-treeselect
   ```

2. **Initialize v-model as null, not array:**
   ```javascript
   data() {
     return {
       value: null,  // NOT value: [] or value: ['initial']
     }
   }
   ```

3. **Consider PrimeVue TreeSelect alternative:**
   ```vue
   <TreeSelect
     v-model="selectedPhenotypes"
     :options="phenotypeTree"
     selectionMode="checkbox"
     :multiple="true"
   />
   ```

4. **Build custom multi-select component** - If no library works:
   ```vue
   <MultiSelectTree
     v-model="phenotypes"
     :options="phenotypeTree"
     :searchable="true"
     :max-selections="null"
   />
   ```

5. **Document workaround clearly:**
   ```javascript
   // WORKAROUND: vue3-treeselect multi-select broken
   // See: https://github.com/megafetis/vue3-treeselect/issues/4
   // Using BFormSelect single mode until fixed
   // TODO: Restore multi-select with PrimeVue TreeSelect
   ```

**Detection (warning signs):**
- TODO comments mentioning "treeselect" - search codebase
- Components using `select_phenotype[0]` instead of `select_phenotype`
- Console errors about "Cannot read property 'id' of undefined"
- Test: Can curator select multiple phenotypes for entity?

**Which phase should address this:** Phase 2 - Research tree-select alternatives, implement replacement before ModifyEntity improvements

---

### Pitfall 3: Empty Dropdown Options Due to Async Load Race Condition

**What goes wrong:**
Dropdown shows empty options list when:
1. Component mounts, immediately renders BFormSelect
2. API call to load options starts (async)
3. BFormSelect renders with empty `options` array
4. API response arrives but dropdown doesn't update (reactivity broken)
5. User sees "Select status..." but no options to choose

**Why it happens:**
Options are loaded in `mounted()` but template renders before data arrives. If `v-if` guard is missing or reactive binding breaks, dropdown stays empty.

**Evidence from codebase (ModifyStatus dropdown bug):**
ModifyEntity.vue loads status options:
```javascript
mounted() {
  this.loadStatusList();
  // ...
},
async loadStatusList() {
  const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/status?tree=true`;
  try {
    const response = await this.axios.get(apiUrl);
    this.status_options = response.data;  // Line 700
  } catch (e) {
    this.makeToast(e, 'Error', 'danger');
  }
}
```

Template has guard but it may fail:
```vue
<BFormSelect
  v-if="status_options && status_options.length > 0"
  id="status-select"
  v-model="status_info.category_id"
  :options="normalizeStatusOptions(status_options)"
/>
```

If `status_options` is initialized as `[]` (empty array), `v-if` check passes (`[].length > 0` is false) but component might render anyway if Vue batch updates.

**Real-world scenario:**
1. User opens ModifyEntity page
2. Clicks "Modify status" button
3. Modal opens with status dropdown
4. Dropdown shows "Select status..." but no options available
5. User cannot proceed with status modification

**Consequences:**
- Blocked workflow - curators cannot modify entity status
- Frustrating UX - dropdown appears functional but is empty
- Retry doesn't help if race condition is deterministic

**Prevention:**
1. **Add loading state for options:**
   ```javascript
   data() {
     return {
       status_options: [],
       status_options_loading: true,  // Add loading flag
     }
   },
   async loadStatusList() {
     this.status_options_loading = true;
     try {
       const response = await this.axios.get(apiUrl);
       this.status_options = response.data;
     } finally {
       this.status_options_loading = false;
     }
   }
   ```

2. **Show loading state in dropdown:**
   ```vue
   <BFormSelect v-if="!status_options_loading && status_options.length > 0" ...>
     ...
   </BFormSelect>
   <BSpinner v-else-if="status_options_loading" small />
   <div v-else class="text-danger">Failed to load options</div>
   ```

3. **Load options before showing modal:**
   ```javascript
   async showStatusModify() {
     await this.loadStatusList();  // Wait for options
     if (this.status_options.length === 0) {
       this.makeToast('Failed to load status options', 'Error', 'danger');
       return;  // Don't open modal with empty dropdown
     }
     this.$refs.modifyStatusModal.show();
   }
   ```

4. **Initialize with null, not empty array:**
   ```javascript
   data() {
     return {
       status_options: null,  // null = not loaded yet, [] = loaded but empty
     }
   }
   ```

**Detection (warning signs):**
- Dropdown with `v-if="options.length > 0"` where options initializes as `[]`
- No loading indicator while options are fetching
- Modal opens before its data is ready
- Bug reports: "dropdown is empty" that resolve on page refresh

**Which phase should address this:** Phase 1 - Fix ModifyStatus dropdown, establish pattern for all option dropdowns

---

### Pitfall 4: Hardcoded Re-Review Batch Configuration

**What goes wrong:**
Re-review batches are hardcoded in database/backend, preventing:
- Creating new batch definitions dynamically
- Adjusting batch criteria after system launch
- Custom batches for specific review campaigns

**Evidence from codebase:**
ManageReReview.vue (line 258-277) can only assign existing batches:
```javascript
async handleNewBatchAssignment() {
  const apiUrl = `${import.meta.env.VITE_API_URL}/api/re_review/batch/assign?user_id=${this.user_id_assignment}`;
  // Can assign to user, but cannot CREATE new batch types
}
```

No UI for:
- Defining batch criteria (which entities need re-review)
- Setting batch size
- Scheduling batch generation
- Assigning specific genes to specific users

**Why it happens:**
Initial system assumed fixed re-review workflows. As database grows (4000+ entities), need for dynamic batch management becomes apparent. Retrofitting flexibility is harder than designing it initially.

**Real-world scenario:**
1. Principal investigator wants to prioritize re-review of entities from 2020 (oldest data)
2. System only has batches organized by category, not by date
3. Admin must manually update database to create date-based batch
4. No way for curators to see batch criteria or suggest improvements

**Consequences:**
- Rigid workflow that can't adapt to research needs
- Admin overhead for simple batch adjustments
- Inability to run targeted re-review campaigns

**Prevention:**
1. **Add batch creation API and UI:**
   ```javascript
   // API: POST /api/re_review/batch/create
   {
     "name": "Pre-2021 Entities",
     "criteria": {
       "date_before": "2021-01-01",
       "categories": ["Definitive", "Moderate"]
     },
     "max_size": 100
   }
   ```

2. **Dynamic criteria builder in ManageReReview:**
   ```vue
   <BCard header="Create New Batch">
     <BFormSelect v-model="newBatch.dateFilter" :options="dateOptions" />
     <BFormCheckboxGroup v-model="newBatch.categories" :options="categoryOptions" />
     <BFormInput v-model="newBatch.maxSize" type="number" />
     <BButton @click="createBatch">Create Batch</BButton>
   </BCard>
   ```

3. **Gene-to-user assignment:**
   ```vue
   <BTable :items="unassignedGenes" selectable @row-selected="onGenesSelected">
     <template #cell(assign)="row">
       <BFormSelect v-model="row.item.assigned_user" :options="curators" />
     </template>
   </BTable>
   ```

4. **Batch recalculation trigger:**
   ```javascript
   // Allow admin to regenerate batch based on current criteria
   async recalculateBatch(batchId) {
     await this.axios.post(`/api/re_review/batch/${batchId}/recalculate`);
   }
   ```

**Detection (warning signs):**
- No "Create batch" button in ManageReReview
- Batch assignment only, no batch definition UI
- Feature requests for custom re-review campaigns
- Direct database edits to create new batches

**Which phase should address this:** Phase 3 - ManageReReview modernization with dynamic batch management

---

## Moderate Pitfalls

Mistakes that cause delays, reduced functionality, or technical debt.

### Pitfall 5: Inconsistent Pagination Options Across Curation Views

**What goes wrong:**
Different curation tables have different per-page options, causing UX inconsistency:
- ApproveUser: `[5, 10, 20, 50]` with default 10
- ApproveReview: `[10, 25, 50, 200]` with default 200
- ApproveStatus: `[10, 25, 50, 200]` with default 200
- ManageReReview: `[5, 10, 20, 50]` with default 50

**Evidence from codebase:**
ApproveUser.vue (line 214-219):
```javascript
pageOptions: [
  { value: 5, text: '5' },
  { value: 10, text: '10' },
  { value: 20, text: '20' },
  { value: 50, text: '50' },
],
```

ApproveReview.vue (line 1182):
```javascript
pageOptions: [10, 25, 50, 200],
```

**Why it happens:**
Each component was developed independently without shared configuration. Different developers had different preferences.

**Consequences:**
- Curators confused by different default page sizes
- Workflow disruption when switching between views
- "Why does this table show 200 items but that one shows 10?"

**Prevention:**
1. **Create shared pagination config:**
   ```javascript
   // config/table-defaults.js
   export const CURATION_PAGE_OPTIONS = [10, 25, 50, 100];
   export const DEFAULT_PAGE_SIZE = 25;
   ```

2. **Use consistent format (array, not array of objects):**
   ```javascript
   // ApproveReview style (simple)
   pageOptions: [10, 25, 50, 100]

   // NOT ApproveUser style (verbose)
   pageOptions: [{ value: 10, text: '10' }, ...]
   ```

3. **Add to PR checklist:**
   - [ ] Pagination options match CURATION_PAGE_OPTIONS
   - [ ] Default page size is DEFAULT_PAGE_SIZE

**Detection (warning signs):**
- Different `pageOptions` arrays across curation views
- Different default `perPage` values
- User complaints about inconsistent table behavior

**Which phase should address this:** Phase 2 - Standardize during curation table modernization

---

### Pitfall 6: Modal Data Staleness After Form Reset

**What goes wrong:**
User edits entity, cancels, reopens modal for different entity - sees previous entity's data:
1. Click "Edit" on Entity 123 - modal shows Entity 123 data
2. Click "Cancel" - modal closes
3. Click "Edit" on Entity 456 - modal still shows Entity 123 data
4. Submit - accidentally overwrites Entity 456 with Entity 123's values

**Why it happens:**
Modal data is stored in component state and not reset on close. Bootstrap-Vue-Next `@hide` handler may not clear all fields.

**Evidence from codebase:**
ApproveUser.vue (line 285-293):
```javascript
resetUserApproveModal() {
  this.approveUserModal = {
    id: 'approve-usermodal',
    title: '',
    content: [],
  };
  this.approve_user = [];
  this.user_approved = false;
}
```
This resets modal metadata but not the form fields themselves.

ModifyEntity.vue (line 1094-1107):
```javascript
resetForm() {
  this.modify_entity_input = null;
  this.entity_info = new Entity();
  // ... more resets
}
```
Good pattern - creates new instances of data objects.

**Consequences:**
- Data corruption if stale data is submitted
- User confusion ("Why does it show wrong entity?")
- Requires page refresh to clear stale state

**Prevention:**
1. **Reset on modal open, not close:**
   ```javascript
   showEditModal(item) {
     this.resetForm();  // Reset FIRST
     this.loadEntityData(item.id);  // Then load new data
     this.showModal('edit-modal');
   }
   ```

2. **Use factory functions for data objects:**
   ```javascript
   getDefaultFormState() {
     return {
       entity_id: null,
       synopsis: '',
       phenotypes: [],
       // ...
     };
   },
   resetForm() {
     this.formData = this.getDefaultFormState();
   }
   ```

3. **Clear vee-validate state:**
   ```javascript
   resetForm() {
     this.resetValidation();  // vee-validate reset
     this.setValues(this.getDefaultFormState());
   }
   ```

4. **Add modal @show handler:**
   ```vue
   <BModal @show="onModalShow" @hide="onModalHide">
   ```
   ```javascript
   onModalShow() {
     this.validateFormDataFreshness();
   }
   ```

**Detection (warning signs):**
- Form reset only in `@hide` handler, not `@show`
- No factory function for default state
- Bug reports about "wrong data in modal"
- Test: Edit item A, cancel, edit item B - does B's data show?

**Which phase should address this:** Phase 2 - Establish modal pattern during ApproveReview modernization

---

### Pitfall 7: Options API Pattern Inconsistency with Established Composables

**What goes wrong:**
Curation views use Options API (`data()`, `methods`, `mounted()`) while admin views use Composition API with composables. This creates:
- Two different patterns for same functionality
- Composable reuse blocked by API incompatibility
- Inconsistent developer experience

**Evidence from codebase:**
ApproveUser.vue (line 146-336): Uses Options API
```javascript
export default {
  name: 'ApproveStatus',
  setup() { /* minimal */ },
  data() { return { ... } },
  mounted() { /* lifecycle */ },
  methods: { /* all methods */ }
}
```

ManageUser.vue (line 755-900): Uses Composition API with setup
```javascript
export default {
  setup() {
    const { makeToast } = useToast();
    const tableData = useTableData({ ... });
    const bulkSelection = useBulkSelection(20);
    const filterPresets = useFilterPresets('sysndd-manage-user-presets');
    return { ...tableData, ...bulkSelection, filterPresets };
  }
}
```

**Why it happens:**
- Curation views are older, written before composable patterns established
- "If it works, don't touch it" mindset
- Migration effort seems large for working code

**Consequences:**
- Cannot use `useBulkSelection` in ApproveReview (API mismatch)
- Cannot use `useFilterPresets` in curation views
- Different mental models for different parts of app
- Composable improvements don't benefit curation views

**Prevention:**
1. **Incremental migration during feature work:**
   When adding features to curation view, migrate to Composition API:
   ```javascript
   // Before: Add feature in Options API
   // After: Migrate component to Composition API, add feature
   ```

2. **Keep Options API data/methods, add composables in setup:**
   ```javascript
   export default {
     setup() {
       // Add composables for new features
       const { isSelected, toggleSelection } = useBulkSelection(20);
       return { isSelected, toggleSelection };
     },
     data() {
       // Keep existing data
       return { items_ReviewTable: [] };
     },
     methods: {
       // Keep existing methods
       loadReviewTableData() { ... }
     }
   }
   ```

3. **Extract reusable logic to composables progressively:**
   - Phase 1: Keep Options API, add composable for new feature
   - Phase 2: Extract common patterns to composables
   - Phase 3: Full Composition API migration (optional)

4. **Document hybrid approach:**
   ```javascript
   // Component uses hybrid Options API + Composition API
   // - Legacy: data(), methods, mounted() for existing functionality
   // - Modern: setup() composables for new features (bulk selection, filter presets)
   // Full migration planned for v8
   ```

**Detection (warning signs):**
- Curation views don't use any composables from `/composables/`
- Feature request requires composable but component uses Options API
- "Can't use useX in ApproveReview" comments

**Which phase should address this:** Each phase - incrementally migrate during feature additions

---

### Pitfall 8: Accessibility Labels Missing on Action Buttons

**What goes wrong:**
Curation action buttons have icons but no accessible text:
```vue
<BButton @click="infoApproveUser(row.item)">
  <i class="bi bi-hand-thumbs-up" />
  <i class="bi bi-hand-thumbs-down" />
</BButton>
```
Screen readers announce: "Button" (no context)

**Evidence from codebase:**
ApproveUser.vue (line 78-89):
```vue
<BButton
  v-b-tooltip.hover.top
  title="Manage user approval"  <!-- Tooltip, not aria-label -->
  :variant="user_approval_style[row.item.approved]"
  @click="infoApproveUser(row.item, row.index, $event.target)"
>
  <i class="bi bi-hand-thumbs-up" />
  <i class="bi bi-hand-thumbs-down" />
</BButton>
```

ManageUser.vue (better pattern, line 257-266):
```vue
<BButton
  v-b-tooltip.hover.top
  title="Edit user"
  @click="editUser(row, $event.target)"
>
  <i class="bi bi-pen" />
</BButton>
```
Still missing `aria-label` but has descriptive tooltip.

**Why it happens:**
- Tooltips provide visual users enough context
- `aria-label` requires explicit addition
- Accessibility testing not part of PR checklist

**Consequences:**
- WCAG 2.2 AA violation (PROJECT.md claims compliance)
- Screen reader users cannot identify button purpose
- Fails automated accessibility audits

**Prevention:**
1. **Add aria-label to all icon-only buttons:**
   ```vue
   <BButton
     aria-label="Approve user application"
     v-b-tooltip.hover.top
     title="Approve user application"
   >
     <i class="bi bi-check-circle" />
   </BButton>
   ```

2. **Use consistent pattern:**
   ```vue
   <BButton
     :aria-label="`${action} ${entityType} ${identifier}`"
     v-b-tooltip.hover
     :title="`${action} ${entityType}`"
   >
   ```

3. **Add visually hidden text for complex buttons:**
   ```vue
   <BButton @click="infoApproveUser(row.item)">
     <i class="bi bi-hand-thumbs-up" />
     <i class="bi bi-hand-thumbs-down" />
     <span class="visually-hidden">Manage approval for {{ row.item.user_name }}</span>
   </BButton>
   ```

4. **Accessibility checklist for curation views:**
   - [ ] All buttons have `aria-label` or visible text
   - [ ] All form inputs have associated labels
   - [ ] All tables have `aria-describedby` for context

**Detection (warning signs):**
- Buttons with only `<i class="bi bi-*">` children
- `v-b-tooltip` without corresponding `aria-label`
- Lighthouse Accessibility score below 100
- axe-core violations for "Buttons must have discernible text"

**Which phase should address this:** Every phase - add aria-labels during each component update

---

## Minor Pitfalls

Mistakes that cause annoyance but are fixable.

### Pitfall 9: Component Name Mismatch in Curation Views

**What goes wrong:**
Components have wrong `name` property, causing confusion in Vue DevTools:
- ApproveUser.vue → `name: 'ApproveStatus'` (WRONG)
- ModifyEntity.vue → `name: 'ApproveStatus'` (WRONG)
- ManageReReview.vue → `name: 'ApproveStatus'` (WRONG)

**Evidence from codebase:**
ApproveUser.vue (line 147):
```javascript
export default {
  name: 'ApproveStatus',  // Should be 'ApproveUser'
```

ModifyEntity.vue (line 625):
```javascript
export default {
  name: 'ApproveStatus',  // Should be 'ModifyEntity'
```

ManageReReview.vue (line 142):
```javascript
export default {
  name: 'ApproveStatus',  // Should be 'ManageReReview'
```

**Why it happens:**
Copy-paste from ApproveStatus without updating component name.

**Consequences:**
- Vue DevTools shows wrong component names
- Debugging difficulty (three components named same thing)
- Potential issues with Vue warnings/errors

**Prevention:**
1. **Fix component names:**
   ```javascript
   // ApproveUser.vue
   name: 'ApproveUser',

   // ModifyEntity.vue
   name: 'ModifyEntity',

   // ManageReReview.vue
   name: 'ManageReReview',
   ```

2. **Add ESLint rule:**
   ```javascript
   // eslint.config.js
   'vue/match-component-file-name': ['error', { extensions: ['vue'] }]
   ```

3. **Use `<script setup>` to avoid issue:**
   ```vue
   <script setup>
   // Component name inferred from filename
   </script>
   ```

**Detection (warning signs):**
- Multiple components with same `name` property
- Vue DevTools shows unexpected component names
- ESLint errors if rule is enabled

**Which phase should address this:** Phase 1 - Quick fix during initial bug fixes

---

### Pitfall 10: Inconsistent Error Toast Messages

**What goes wrong:**
Error handling produces inconsistent toast messages:
- Some show full axios error object: `[object Object]`
- Some show HTTP status: "Error 500"
- Some show API message: "User not found"

**Evidence from codebase:**
ApproveUser.vue (line 243):
```javascript
this.makeToast(e, 'Error', 'danger');  // Passes error object directly
```

If `makeToast` doesn't extract message from error object, users see `[object Object]`.

ManageUser.vue (line 1163-1164):
```javascript
const errorMsg = error.response?.data?.message || error.response?.data?.error || 'Unknown error';
this.makeToast(errorMsg, 'Bulk Approve Failed', 'danger');
```
Better pattern - extracts message with fallback.

**Consequences:**
- Unhelpful error messages for users
- Debugging difficulty (what error actually occurred?)
- Inconsistent UX across curation views

**Prevention:**
1. **Create error message extractor:**
   ```javascript
   function getErrorMessage(error) {
     if (typeof error === 'string') return error;
     if (error.response?.data?.message) return error.response.data.message;
     if (error.response?.data?.error) return error.response.data.error;
     if (error.message) return error.message;
     return 'An unexpected error occurred';
   }
   ```

2. **Update makeToast to handle error objects:**
   ```javascript
   function makeToast(messageOrError, title, variant) {
     const message = getErrorMessage(messageOrError);
     // ... toast logic
   }
   ```

3. **Standardize catch blocks:**
   ```javascript
   } catch (error) {
     this.makeToast(
       getErrorMessage(error),
       'Failed to load data',
       'danger'
     );
   }
   ```

**Detection (warning signs):**
- Toast messages showing `[object Object]`
- `makeToast(e, ...)` where `e` is Error object
- Inconsistent error message formats across views

**Which phase should address this:** Phase 1 - Update useToast composable, apply consistently

---

## Integration Pitfalls with Existing System

### Pitfall 11: Breaking Working Legacy Code During Modernization

**What goes wrong:**
Modernization effort breaks existing functionality:
- Migrate ApproveReview to use composables → bulk approve stops working
- Add URL sync to ManageReReview → back button causes infinite loop
- Update pagination → existing bookmarked links 404

**Why it happens:**
Legacy code has implicit dependencies not documented. Changing one piece affects others in unexpected ways. Test coverage is 20.3%, so regressions may not be caught.

**Evidence from codebase:**
ApproveReview.vue has complex interdependencies:
- Review modal depends on `getEntity()` completing before `loadReviewInfo()`
- Status modal depends on both entity AND status data
- Approval flow has conditional status approval
- "Approve all" depends on table data being fully loaded

**Consequences:**
- Regressions in production
- Curator workflow blocked
- Emergency rollbacks

**Prevention:**
1. **Document implicit dependencies before changing:**
   ```javascript
   // DEPENDENCY MAP for ApproveReview
   // showReviewModal → getEntity() → loadReviewInfo() → THEN show modal
   // handleApproveOk → requires this.entity.review_id populated
   // handleAllReviewsOk → requires items_ReviewTable fully loaded
   ```

2. **Add integration tests before refactoring:**
   ```javascript
   describe('ApproveReview workflow', () => {
     it('opens review modal with entity data loaded', async () => {
       // Test the implicit dependency
     });
   });
   ```

3. **Incremental changes with feature flags:**
   ```javascript
   if (featureFlags.useNewReviewModal) {
     this.showNewReviewModal(item);
   } else {
     this.infoReview(item, index, button);
   }
   ```

4. **Test in staging with real curator workflows:**
   - Approve single review
   - Approve review + status
   - Approve all reviews
   - Modify then approve

**Detection (warning signs):**
- PR changes 500+ lines in working component
- No integration tests for modified workflows
- "Works on my machine" but fails in production
- Curator bug reports after modernization release

**Which phase should address this:** Every phase - defensive approach to legacy code changes

---

### Pitfall 12: API Response Pagination Mismatch

**What goes wrong:**
Some API endpoints return all data (legacy), others return paginated (modern). Components assume one format but receive other:
- Legacy: `{ data: [...all items...] }`
- Modern: `{ data: [...page items...], meta: { totalItems, currentPage, ... } }`

ApproveUser uses client-side pagination with `totalRows = response.data.length`, but if API adds server-side pagination, this breaks.

**Evidence from codebase:**
ApproveUser.vue (line 237-238):
```javascript
this.items_UsersTable = response.data;
this.totalRows_UsersTable = response.data.length;
```

ManageUser.vue (line 1384-1394):
```javascript
this.users = data.data;
this.totalRows = data.meta[0].totalItems;
this.currentPage = data.meta[0].currentPage;
this.totalPages = data.meta[0].totalPages;
```

**Consequences:**
- Incorrect total counts after API migration
- Pagination shows wrong page numbers
- "Load more" never shows because component thinks all data loaded

**Prevention:**
1. **Check for pagination metadata:**
   ```javascript
   if (response.data.meta) {
     // Modern paginated response
     this.items = response.data.data;
     this.totalRows = response.data.meta[0].totalItems;
   } else {
     // Legacy full response
     this.items = response.data;
     this.totalRows = response.data.length;
   }
   ```

2. **Use useTableData composable** that handles both formats:
   ```javascript
   const { items, totalRows, applyApiResponse } = useTableData();
   applyApiResponse(response.data);  // Composable detects format
   ```

3. **Coordinate with backend on API migration plan:**
   - Document which endpoints are legacy vs modern
   - Add deprecation warnings in legacy endpoints
   - Migrate frontend before backend changes

**Detection (warning signs):**
- `response.data.length` used for totalRows
- No check for `.meta` property
- Backend planning to add pagination to endpoint

**Which phase should address this:** Phase 2 - During table modernization, align with modern API patterns

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **Phase 1: Critical bug fixes** | ApproveUser crash (Pitfall 1), ModifyStatus dropdown (Pitfall 3), component names (Pitfall 9) | Add defensive data checks, loading states, fix copy-paste errors |
| **Phase 2: Curation table modernization** | Options API composable incompatibility (Pitfall 7), pagination inconsistency (Pitfall 5) | Hybrid API approach, standardize page options |
| **Phase 3: ManageReReview overhaul** | Hardcoded batches (Pitfall 4), breaking legacy code (Pitfall 11) | Add dynamic batch API, extensive testing |
| **Phase 4: ModifyEntity improvements** | vue3-treeselect multi-select (Pitfall 2), modal staleness (Pitfall 6) | Evaluate PrimeVue alternative, reset on show |
| **Phase 5: Review page modernization** | API pagination mismatch (Pitfall 12) | Coordinate with backend, use modern composables |
| **Phase 6: Accessibility pass** | Missing aria-labels (Pitfall 8) | Systematic audit, add labels to all action buttons |

---

## Quick Prevention Checklist

Before committing curation workflow changes:

- [ ] **Data safety:** Does code check `Array.isArray()` before array methods?
- [ ] **Loading states:** Are dropdowns guarded with loading state?
- [ ] **Modal resets:** Does modal reset on `@show`, not just `@hide`?
- [ ] **Accessibility:** Do all icon buttons have `aria-label`?
- [ ] **Component name:** Does `name` property match filename?
- [ ] **Error handling:** Does catch block extract message from error object?
- [ ] **Pagination:** Does component handle both legacy and modern API formats?
- [ ] **Testing:** Have implicit dependencies been documented and tested?

---

## Sources

**Web Research:**
- [TypeError: reduce is not a function - bobbyhadz](https://bobbyhadz.com/blog/javascript-typeerror-reduce-is-not-a-function)
- [vue3-treeselect multi-select issue #4](https://github.com/megafetis/vue3-treeselect/issues/4)
- [Vue 3 Breaking Changes](https://v3-migration.vuejs.org/breaking-changes/)
- [What is a Race Condition in Vue.js - Vue School](https://vueschool.io/articles/vuejs-tutorials/what-is-a-race-condition-in-vue-js/)
- [Bootstrap-Vue-Next Form Select docs](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/form-select.html)
- [Data Curation Best Practices 2026 - AIMultiple](https://research.aimultiple.com/data-curation/)
- [Database Design Patterns - Medium](https://medium.com/@artemkhrenov/database-design-patterns-the-complete-developers-guide-to-modern-data-architecture-8b4f06e646ce)

**Codebase Analysis:**
- ApproveUser.vue - API response handling, pagination options
- ModifyEntity.vue - vue3-treeselect workarounds, modal patterns
- ApproveReview.vue - Complex workflow dependencies
- ApproveStatus.vue - Status modification patterns
- ManageReReview.vue - Batch management limitations
- ManageUser.vue - Modern patterns reference (composables, error handling)
- PROJECT.md - Established patterns and known issues

**Confidence Assessment:**

| Area | Confidence | Rationale |
|------|------------|-----------|
| API response bugs | HIGH | Direct observation in codebase + documented error patterns |
| vue3-treeselect issues | HIGH | Official GitHub issue + code comments confirm |
| Batch management | MEDIUM | Observed API limitations, some inference on desired features |
| Accessibility gaps | HIGH | Direct audit of button implementations |
| Migration risks | MEDIUM | Based on codebase complexity, not tested empirically |
