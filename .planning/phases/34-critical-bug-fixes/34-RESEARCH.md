# Phase 34: Critical Bug Fixes - Research

**Researched:** 2026-01-26
**Domain:** Vue.js production bug fixing in scientific curation application
**Confidence:** HIGH

## Summary

Phase 34 addresses four critical bugs blocking basic curation functionality in SysNDD v7.0. Research reveals all four bugs have straightforward fixes using defensive programming patterns already demonstrated in the codebase (ManageUser.vue). The primary technical challenge is applying these patterns without breaking existing workflows, given 20.3% test coverage means regressions may go undetected.

The bugs share a common root cause: components assume data arrives in expected formats without defensive checks. ApproveUser crashes because it assumes `response.data` is an array without validating this. ModifyEntity status dropdown appears empty because the component renders before async options load completes. Component names were copy-pasted without updating, breaking Vue DevTools debugging. Modal forms retain stale data because reset logic runs on `@hide` instead of `@show`.

All four bugs can be fixed with patterns already working elsewhere in the codebase. The ManageUser.vue component demonstrates the correct approach: defensive API response handling with `Array.isArray()` checks, loading state guards for async operations, proper component naming, and form reset on modal open. The research confirms no new libraries or architectural changes are needed - just careful application of existing patterns to the broken components.

**Primary recommendation:** Fix bugs using defensive programming patterns from ManageUser.vue as reference implementation. Add error boundaries around table components to prevent full page crashes. Test fixes manually with real curator workflows before committing, given low automated test coverage.

## Standard Stack

No new dependencies required. All fixes use existing Vue 3 and Bootstrap-Vue-Next patterns.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue | 3.5.25 | Reactive framework | Already in use, provides error handling hooks |
| Bootstrap-Vue-Next | 0.42.0 | UI components | BFormSelect, BModal lifecycle events |
| TypeScript | 5.9.3 | Type safety | Catch data type mismatches at compile time |
| axios | 1.13.2 | HTTP client | API calls, error responses |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Vitest | 4.0.18 | Testing | Add integration tests before refactoring |
| Vue DevTools | Latest | Debugging | Verify component name fixes |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual defensive checks | TypeScript interfaces | Better long-term but requires backend API types first |
| Manual modal reset | VueUse useToggle | Adds dependency for simple logic |
| console.error | Sentry/LogRocket | Production monitoring not in scope for v7.0 bug fixes |

**Installation:**
```bash
# No new packages needed - use existing stack
npm install  # Ensure all dependencies current
```

## Architecture Patterns

### Recommended Bug Fix Structure
```
Component Defensive Pattern:
├── API Response Validation (before .map/.reduce)
├── Loading State Guards (before rendering options)
├── Modal Lifecycle Reset (@show, not @hide)
└── Error Boundaries (catch unexpected crashes)
```

### Pattern 1: Defensive API Response Handling
**What:** Validate data structure before accessing properties
**When to use:** Any component receiving API responses
**Example:**
```typescript
// Source: ManageUser.vue lines 1384-1394 (working pattern)
async loadUserTableData() {
  try {
    const response = await this.axios.get(apiUrl);
    const data = response.data;

    // Defensive check for pagination wrapper vs direct array
    if (data.data && Array.isArray(data.data)) {
      // Modern paginated response
      this.users = data.data;
      this.totalRows = data.meta?.[0]?.totalItems || data.data.length;
    } else if (Array.isArray(data)) {
      // Legacy direct array response
      this.users = data;
      this.totalRows = data.length;
    } else {
      // Unexpected format
      console.error('Unexpected API response format:', data);
      this.users = [];
      this.totalRows = 0;
    }
  } catch (e) {
    this.makeToast(e, 'Error', 'danger');
    this.users = [];
    this.totalRows = 0;
  }
}
```

### Pattern 2: Loading State Guard for Async Dropdowns
**What:** Prevent rendering dropdowns before options load
**When to use:** BFormSelect with options from API
**Example:**
```vue
<!-- Source: Bootstrap-Vue-Next Modal docs + defensive pattern -->
<template>
  <BModal @show="onModalShow">
    <BSpinner v-if="statusOptionsLoading" />
    <BFormSelect
      v-else-if="statusOptions.length > 0"
      v-model="statusInfo.category_id"
      :options="statusOptions"
    >
      <template #first>
        <BFormSelectOption :value="null">Select status...</BFormSelectOption>
      </template>
    </BFormSelect>
    <BAlert v-else variant="danger">Failed to load status options</BAlert>
  </BModal>
</template>

<script>
data() {
  return {
    statusOptions: null,  // null = not loaded, [] = loaded but empty
    statusOptionsLoading: false,
  };
},
async onModalShow() {
  // Load options BEFORE modal renders form
  if (!this.statusOptions) {
    this.statusOptionsLoading = true;
    try {
      const response = await this.axios.get(apiUrl);
      this.statusOptions = Array.isArray(response.data)
        ? response.data
        : response.data?.data || [];
    } catch (e) {
      this.statusOptions = [];
      this.makeToast('Failed to load options', 'Error', 'danger');
    } finally {
      this.statusOptionsLoading = false;
    }
  }
}
</script>
```

### Pattern 3: Modal Form Reset on Show
**What:** Reset form state when modal opens, not closes
**When to use:** Any modal with editable form data
**Example:**
```vue
<!-- Source: Bootstrap-Vue-Next Modal lifecycle events -->
<BModal
  id="modify-modal"
  @show="resetFormBeforeShow"
  @hide="resetFormAfterHide"
  @ok="handleSubmit"
>
  <!-- Form fields -->
</BModal>

<script>
methods: {
  resetFormBeforeShow() {
    // Primary reset: Clear stale data from previous open
    this.entity_info = new Entity();
    this.status_info = new Status();
    this.review_info = new Review();
    // Then load fresh data for this entity
    this.loadEntityData(this.modify_entity_input);
  },
  resetFormAfterHide() {
    // Secondary cleanup: Clear sensitive data after close
    this.entity_info = new Entity();
    this.user_approved = false;
  }
}
</script>
```

### Pattern 4: Component Name Matching Filename
**What:** Component `name` property matches file name for Vue DevTools
**When to use:** All Vue components
**Example:**
```javascript
// Source: Vue 3 DevTools best practices
// File: ApproveUser.vue
export default {
  name: 'ApproveUser',  // Match filename
  // ...
}

// File: ModifyEntity.vue
export default {
  name: 'ModifyEntity',  // Match filename
  // ...
}
```

### Anti-Patterns to Avoid
- **Direct array method calls without validation:** `response.data.map()` without `Array.isArray()` check
- **Empty array initialization for loading state:** Use `null` to distinguish "not loaded" from "loaded empty"
- **Reset only on modal `@hide`:** Stale data persists until next close
- **Generic component names:** Copy-paste `name: 'ApproveStatus'` to all files

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Modal lifecycle management | Custom show/hide tracking | Bootstrap-Vue-Next `@show/@hide` events | Handles transitions, escape key, backdrop clicks |
| Error message extraction from axios errors | String parsing | Existing pattern in ManageUser.vue | Already handles response.data.message/error fallbacks |
| Loading state for tables | Custom spinner logic | Existing `loadingUsersApprove` pattern | Consistent with other views |
| Data validation before array methods | Try/catch around operations | `Array.isArray()` checks | Clearer intent, better error messages |

**Key insight:** The codebase already has working implementations of all needed patterns. Bug fixes should copy from ManageUser.vue and CreateEntity.vue, not invent new approaches. Consistency across curation views reduces cognitive load for future maintenance.

## Common Pitfalls

### Pitfall 1: API Response Format Assumptions
**What goes wrong:** Component calls `.map()` or `.reduce()` on non-array response
**Why it happens:** SysNDD has two API response formats - legacy direct array and modern paginated wrapper. Components written for one format crash with the other.
**How to avoid:** Always validate with `Array.isArray()` before array methods. Extract data defensively with fallbacks.
**Warning signs:**
- `response.data.length` without prior type check
- `TypeError: X is not a function` in production
- Component works locally but crashes in production

**Prevention:**
```javascript
// WRONG: Assumes response.data is array
this.items = response.data;
this.totalRows = response.data.length;

// RIGHT: Handles both response formats
const data = response.data;
if (Array.isArray(data)) {
  this.items = data;
  this.totalRows = data.length;
} else if (data.data && Array.isArray(data.data)) {
  this.items = data.data;
  this.totalRows = data.meta?.[0]?.totalItems || data.data.length;
} else {
  console.error('Unexpected response format:', data);
  this.items = [];
  this.totalRows = 0;
}
```

### Pitfall 2: Race Condition Between Async Load and Render
**What goes wrong:** Dropdown renders with empty options before async load completes
**Why it happens:** Vue template renders immediately with empty array, then async load populates it. If reactivity breaks or v-if guard is wrong, dropdown stays empty.
**How to avoid:** Initialize options as `null` (not loaded) vs `[]` (loaded empty). Add loading state. Load options before showing modal.
**Warning signs:**
- Dropdown shows "Select..." but no options in list
- Options load in console.log but dropdown empty
- Works on page refresh but fails on modal reopen

**Prevention:**
```javascript
// WRONG: Empty array looks "loaded" to v-if
data() {
  return {
    statusOptions: [],  // Can't distinguish "loading" from "empty"
  };
}

// RIGHT: null means "not loaded yet"
data() {
  return {
    statusOptions: null,
    statusOptionsLoading: false,
  };
},
async showModal() {
  // Load BEFORE opening modal
  if (!this.statusOptions) {
    await this.loadStatusOptions();
  }
  this.$refs.modal.show();
}
```

### Pitfall 3: Modal Data Staleness
**What goes wrong:** User edits Entity A, cancels, opens modal for Entity B - sees Entity A's data
**Why it happens:** Form data persists in component state. Reset on `@hide` clears after close, but opening for new entity doesn't reset first.
**How to avoid:** Reset on modal `@show` before loading new data. Use factory functions for default state.
**Warning signs:**
- Bug reports: "Modal shows wrong data"
- Form fields prepopulated with previous entity
- Submit saves to wrong entity

**Prevention:**
```javascript
// WRONG: Reset after close
<BModal @hide="resetForm">

methods: {
  showModal(entity) {
    this.entity = entity;  // Overwrites without reset
    this.$refs.modal.show();
  },
  resetForm() {
    this.entity = null;  // Happens AFTER close
  }
}

// RIGHT: Reset before show
<BModal @show="resetFormBeforeShow">

methods: {
  showModal(entity) {
    this.selectedEntityId = entity.id;
    this.$refs.modal.show();  // Triggers @show
  },
  resetFormBeforeShow() {
    this.entity = null;  // Clear stale data
    this.loadEntity(this.selectedEntityId);  // Then load fresh
  }
}
```

### Pitfall 4: Breaking Existing Workflows During Bug Fixes
**What goes wrong:** Fix one bug, break other functionality. Example: Fix ApproveUser crash, break bulk approval.
**Why it happens:** 20.3% test coverage means regressions go undetected. Components have implicit dependencies not documented.
**How to avoid:** Document dependencies before changing. Test entire workflow manually. Make minimal changes.
**Warning signs:**
- PR touches 100+ lines for "simple bug fix"
- No integration tests for modified workflow
- "Works for single item but bulk fails"

**Prevention:**
```javascript
// Before fixing ApproveUser crash:
// 1. Document current workflow
//    - loadRoleList() must complete before loadUserTableData()
//    - infoApproveUser() depends on approve_user[] being populated
//    - handleUserApproveOk() depends on approve_user[0] existing
//
// 2. Test manually before changes:
//    - Can curators approve single user?
//    - Can curators change user role?
//    - Does pagination work?
//
// 3. Make minimal defensive changes
//    - Add Array.isArray() check
//    - Don't refactor entire component
//
// 4. Test again after changes
//    - Same manual test checklist
```

## Code Examples

Verified patterns from codebase and official documentation:

### Defensive Data Loading (ApproveUser Fix)
```javascript
// Source: ManageUser.vue pattern adapted for ApproveUser
async loadUserTableData() {
  this.loadingUsersApprove = true;
  const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/table`;

  try {
    const response = await this.axios.get(apiUrl, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    });

    // Defensive extraction handles both API formats
    const data = response.data;
    if (Array.isArray(data)) {
      this.items_UsersTable = data;
      this.totalRows_UsersTable = data.length;
    } else if (data?.data && Array.isArray(data.data)) {
      this.items_UsersTable = data.data;
      this.totalRows_UsersTable = data.meta?.[0]?.totalItems || data.data.length;
    } else {
      console.error('Unexpected user table response format:', data);
      this.items_UsersTable = [];
      this.totalRows_UsersTable = 0;
      this.makeToast('Failed to load user data', 'Error', 'danger');
    }

    const uiStore = useUiStore();
    uiStore.requestScrollbarUpdate();
  } catch (e) {
    this.makeToast(e, 'Error', 'danger');
    this.items_UsersTable = [];
    this.totalRows_UsersTable = 0;
  } finally {
    this.loadingUsersApprove = false;
  }
}
```

### Dropdown Loading State (ModifyEntity Status Fix)
```javascript
// Source: Bootstrap-Vue-Next Modal lifecycle + defensive pattern
data() {
  return {
    status_options: null,  // null = not loaded yet
    status_options_loading: false,
  };
},

async showStatusModify() {
  await this.getEntity();
  await this.getStatus();

  // Ensure options loaded before showing modal
  if (!this.status_options) {
    await this.loadStatusList();
  }

  // Guard against empty options
  if (!this.status_options || this.status_options.length === 0) {
    this.makeToast('Failed to load status options. Please refresh and try again.', 'Error', 'danger');
    return;  // Don't show modal with broken dropdown
  }

  this.$refs.modifyStatusModal.show();
},

async loadStatusList() {
  this.status_options_loading = true;
  const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/status?tree=true`;

  try {
    const response = await this.axios.get(apiUrl);
    this.status_options = Array.isArray(response.data)
      ? response.data
      : response.data?.data || [];
  } catch (e) {
    this.makeToast(e, 'Error', 'danger');
    this.status_options = [];
  } finally {
    this.status_options_loading = false;
  }
}
```

### Component Name Correction
```javascript
// Source: Vue DevTools best practices
// File: app/src/views/curate/ApproveUser.vue
export default {
  name: 'ApproveUser',  // FIXED: was 'ApproveStatus'
  setup() { /* ... */ },
  // ...
}

// File: app/src/views/curate/ModifyEntity.vue
export default {
  name: 'ModifyEntity',  // FIXED: was 'ApproveStatus'
  // ...
}

// File: app/src/views/curate/ManageReReview.vue
export default {
  name: 'ManageReReview',  // FIXED: was 'ApproveStatus'
  // ...
}
```

### Modal Reset Pattern
```vue
<!-- Source: Bootstrap-Vue-Next Modal docs -->
<template>
  <BModal
    id="approve-usermodal"
    @show="resetFormBeforeShow"
    @hide="resetFormAfterHide"
    @ok="handleUserApproveOk"
  >
    <template #modal-title>
      <h4>Manage application from: <BBadge>{{ modalTitle }}</BBadge></h4>
    </template>

    <div class="custom-control custom-switch">
      <input
        id="approveUserSwitch"
        v-model="user_approved"
        type="checkbox"
        class="custom-control-input"
      >
      <label class="custom-control-label" for="approveUserSwitch">
        <b>{{ user_approved ? 'Approve user' : 'Delete application' }}</b>
      </label>
    </div>
  </BModal>
</template>

<script>
export default {
  data() {
    return {
      modalTitle: '',
      approve_user: null,  // Single entity instead of array
      user_approved: false,
    };
  },
  methods: {
    infoApproveUser(item) {
      this.selectedUserId = item.user_id;
      this.$refs.approveUserModal.show();  // Triggers @show
    },

    resetFormBeforeShow() {
      // Primary reset: Clear stale data
      this.modalTitle = '';
      this.approve_user = null;
      this.user_approved = false;

      // Load fresh data for selected user
      if (this.selectedUserId) {
        const user = this.items_UsersTable.find(u => u.user_id === this.selectedUserId);
        if (user) {
          this.modalTitle = user.user_name;
          this.approve_user = user;
        }
      }
    },

    resetFormAfterHide() {
      // Secondary cleanup: Clear references
      this.selectedUserId = null;
      this.approve_user = null;
    },

    async handleUserApproveOk() {
      if (!this.approve_user) {
        this.makeToast('No user selected', 'Error', 'danger');
        return;
      }

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/approval?user_id=${this.approve_user.user_id}&status_approval=${this.user_approved}`;

      try {
        await this.axios.put(apiUrl, {}, {
          headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
        });
        this.makeToast('User approval updated successfully.', 'Success', 'success');
        this.loadUserTableData();  // Refresh table
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    }
  }
}
</script>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Assume response.data is array | Validate with Array.isArray() | Vue 3 era | Prevents production crashes |
| Reset forms on @hide | Reset on @show | Bootstrap-Vue-Next migration | Prevents stale data bugs |
| Mount-time option loading | Modal @show loading | Modern async patterns | Prevents empty dropdowns |
| Generic component names | Match filename | Vue DevTools improvements | Better debugging experience |

**Deprecated/outdated:**
- **Bootstrap-Vue (Vue 2):** Used `$root.$bvModal.show()` - now use ref-based `this.$refs.modal.show()`
- **Options API without setup():** Can't use composables - hybrid approach allows gradual migration
- **Direct error object in makeToast:** Now extract message string with fallback chain

## Open Questions

Things that couldn't be fully resolved:

1. **Test Coverage Strategy**
   - What we know: Current coverage at 20.3%, mainly unit tests
   - What's unclear: Which workflows need integration tests before refactoring?
   - Recommendation: Add integration tests for ApproveUser and ModifyEntity workflows before Phase 2 modernization. For Phase 1 bug fixes, manual testing with curator workflows sufficient.

2. **API Response Format Migration Plan**
   - What we know: Some endpoints return direct arrays, others paginated wrappers
   - What's unclear: Is there backend plan to standardize all endpoints?
   - Recommendation: Frontend should handle both formats defensively. If backend migrates, no frontend changes needed.

3. **Error Boundary Implementation**
   - What we know: Vue 3 supports error boundaries via errorCaptured hook
   - What's unclear: Should we add error boundaries around tables or full views?
   - Recommendation: Start with table-level boundaries (prevent full page crash), expand to view-level in Phase 2 if needed.

## Sources

### Primary (HIGH confidence)
- SysNDD Codebase Analysis:
  - `/app/src/views/curate/ApproveUser.vue` - Bug reproduction, crashed component
  - `/app/src/views/curate/ModifyEntity.vue` - Empty dropdown bug, incorrect component name
  - `/app/src/views/curate/ManageReReview.vue` - Incorrect component name
  - `/app/src/views/admin/ManageUser.vue` - Reference implementation for defensive patterns
  - `.planning/research/PITFALLS-curation-workflow.md` - Comprehensive pitfall documentation
- [Bootstrap-Vue-Next Modal Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/modal) - Official @show/@hide lifecycle events
- [Vue.js Error Handling](https://vuejs.org/api/options-lifecycle.html#errorcaptured) - errorCaptured hook documentation

### Secondary (MEDIUM confidence)
- [Vue DevTools](https://devtools.vuejs.org/) - Component name display and debugging
- [Reset form data in modal - Laracasts](https://laracasts.com/discuss/channels/vue/reset-form-data-of-a-modal) - Modal reset patterns
- [How to refresh/reset a modal - Bootstrap-Vue Issue #2053](https://github.com/bootstrap-vue/bootstrap-vue/issues/2053) - Community modal patterns
- [Error handling in Vue.js - LogRocket](https://blog.logrocket.com/error-handling-debugging-and-tracing-in-vue-js/) - Defensive programming patterns
- [Top Tips for Debugging Vue.js Applications - DEV Community](https://dev.to/avaisley/top-tips-for-debugging-vuejs-applications-like-a-pro-4d68) - Production debugging best practices
- [Vue 3 Best Practices - Medium](https://medium.com/@ignatovich.dm/vue-3-best-practices-cb0a6e281ef4) - Code quality patterns

### Tertiary (LOW confidence)
- [TypeError: reduce is not a function - bobbyhadz](https://bobbyhadz.com/blog/javascript-typeerror-reduce-is-not-a-function) - General JavaScript error pattern
- [Best Practices for Debugging Vue.js in Production - MoldStud](https://moldstud.com/articles/p-essential-best-practices-for-debugging-vuejs-applications-in-production) - Production monitoring approaches (out of scope for Phase 1)

## Metadata

**Confidence breakdown:**
- Bug identification: HIGH - Direct observation in codebase, reproducible issues
- Fix approaches: HIGH - Patterns verified in ManageUser.vue (working production code)
- Modal lifecycle: HIGH - Bootstrap-Vue-Next official documentation
- Component naming: HIGH - Vue DevTools standard practice

**Research date:** 2026-01-26
**Valid until:** 60 days (stable patterns, unlikely to change)
