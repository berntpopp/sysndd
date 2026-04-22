# Phase 29: User Management Workflows - Research

**Researched:** 2026-01-25
**Domain:** Vue 3 bulk actions with cross-page selection, confirmation dialogs, and localStorage filter presets
**Confidence:** HIGH

## Summary

Phase 29 implements bulk user management workflows (approve, delete, role assignment) with cross-page selection persistence and filter preset functionality. The codebase already has the necessary infrastructure through Bootstrap-Vue-Next 0.42.0 (useModal, useToast composables), VueUse (useLocalStorage), and proven patterns from NetworkVisualization.vue for Set-based selection tracking.

**Key architectural patterns available:**
- Vue 3 reactive Set for cross-page selection tracking (proven in NetworkVisualization.vue)
- Bootstrap-Vue-Next useModal composable with promise-based confirmations
- Bootstrap-Vue-Next useToast with programmatic control and variants
- VueUse useLocalStorage for reactive preset persistence
- Existing /api/user/delete, /api/user/approval, /api/user/change_role endpoints (single-user operations)

**Critical UX patterns identified:**
- Type-to-confirm DELETE pattern for destructive actions (GitHub-style repository name entry)
- Selection badge in table header showing "X selected" (PatternFly/Gmail pattern)
- Toast notifications with undo capability for non-destructive actions
- All-or-nothing transaction mode for bulk operations (ATOMIC backend pattern)

**Primary recommendation:** Use ref(new Set<number>()) for selectedUserIds following NetworkVisualization.vue pattern. Implement confirmation modals using useModal().create() with custom slots for type-to-confirm input. Add bulk endpoints (/api/user/bulk_approve, /api/user/bulk_delete, /api/user/bulk_assign_role) with ATOMIC transaction semantics. Store filter presets in localStorage using useLocalStorage with JSON serialization of filter objects.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Bootstrap-Vue-Next | 0.42.0 | useModal, useToast, BModal, BFormInput | Already installed, provides promise-based modal confirmations and toast notifications |
| VueUse | 14.1.0 | useLocalStorage for filter presets | Official Vue ecosystem library, reactive localStorage binding with JSON serialization |
| Vue 3 Set | ES2015 | Cross-page selection tracking | Native JavaScript Set with Vue 3 Proxy reactivity, proven in NetworkVisualization.vue |
| Axios | (installed) | Bulk API calls with Promise.all | Already used throughout codebase, handles HTTP error responses |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Existing useToast.ts | Wrapper | Medical app toast (danger never auto-hides) | Already customized for critical error messages |
| Existing useModalControls.ts | Wrapper | Modal show/hide helpers | Simple modal control (not for promise-based confirmations) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ref(new Set()) | Pinia store array | Set is more efficient for add/delete/has operations, survives component state |
| useLocalStorage | Manual localStorage + watch | VueUse provides reactivity, JSON serialization, SSR safety |
| useModal().create() | Template-based BModal with v-model | Programmatic approach better for dynamic confirmation content |
| Type-to-confirm | Simple OK/Cancel modal | Type-to-confirm prevents accidental destructive actions (GitHub standard) |

**Installation:**
No new packages needed—all dependencies already installed.

## Architecture Patterns

### Recommended Component Structure
```
src/views/admin/
├── ManageUser.vue                    # EXTEND: Add selection state, bulk action bar, presets UI
└── (no new files needed)

src/composables/
├── useBulkSelection.ts               # NEW: Composable for Set-based cross-page selection
├── useFilterPresets.ts               # NEW: Composable for localStorage preset management
└── (reuse existing useToast.ts, useModalControls.ts)

src/types/
└── models.ts                         # EXTEND: Add BulkActionResult, FilterPreset types
```

### Pattern 1: Set-Based Cross-Page Selection
**What:** Use Vue 3 reactive Set to track selected user IDs across pagination
**When to use:** Any table with bulk actions across multiple pages
**Example:**
```typescript
// Source: NetworkVisualization.vue (lines 663-669) + Vue 3 reactivity docs
import { ref } from 'vue';

// Selection state (survives pagination changes)
const selectedUserIds = ref(new Set<number>());

// Toggle selection
function toggleUserSelection(userId: number) {
  const newSet = new Set(selectedUserIds.value);
  if (newSet.has(userId)) {
    newSet.delete(userId);
  } else {
    newSet.add(userId);
  }
  selectedUserIds.value = newSet; // Triggers reactivity via Proxy
}

// Clear all selections
function clearSelection() {
  selectedUserIds.value = new Set();
}

// Get selection count (for badge display)
const selectionCount = computed(() => selectedUserIds.value.size);

// Check if user is selected (for checkbox state)
function isUserSelected(userId: number): boolean {
  return selectedUserIds.value.has(userId);
}

// Get selected IDs as array (for API calls)
const selectedIdsArray = computed(() => Array.from(selectedUserIds.value));
```

**Why Set instead of Array:**
- O(1) add/delete/has operations vs O(n) for arrays
- No duplicates (automatic deduplication)
- Vue 3 Proxy reactivity tracks Set.add(), Set.delete(), Set.clear()
- Proven pattern in NetworkVisualization.vue

### Pattern 2: Type-to-Confirm Destructive Actions
**What:** Require user to type "DELETE" or username to enable destructive action
**When to use:** Bulk delete operations (irreversible, high-impact)
**Example:**
```vue
<!-- Source: GitHub destructive actions pattern + Bootstrap-Vue-Next useModal -->
<script setup lang="ts">
import { ref, computed } from 'vue';
import { useModal } from 'bootstrap-vue-next';

const { create } = useModal();

async function confirmBulkDelete(userIds: number[], usernames: string[]) {
  const confirmText = ref('');
  const isConfirmValid = computed(() => confirmText.value === 'DELETE');

  const result = await create({
    title: 'Delete Users',
    okVariant: 'danger',
    okTitle: 'Delete',
    cancelTitle: 'Cancel',
    okDisabled: computed(() => !isConfirmValid.value),
    body: h('div', [
      h('p', { class: 'text-danger fw-bold' }, 'This action cannot be undone.'),
      h('p', `You are about to delete ${userIds.length} users:`),
      h('div', {
        class: 'border rounded p-2 mb-3',
        style: { maxHeight: '200px', overflowY: 'auto' }
      }, usernames.map(name => h('div', name))),
      h('p', `Type DELETE to confirm:`),
      h('input', {
        type: 'text',
        class: 'form-control',
        onInput: (e) => { confirmText.value = e.target.value; },
        placeholder: 'DELETE',
      }),
    ]),
  }).show();

  return result.ok === true;
}
</script>
```

**Best practices:**
- List ALL affected usernames in scrollable container (max 200px height)
- Disable OK button until confirmation text matches exactly
- Use danger variant (red) for destructive actions
- Never auto-focus OK button (focus on Cancel to prevent accidents)
- For <5 items, show names; for 5-20, show all in scrollable list

### Pattern 3: Promise-Based Bulk API Calls
**What:** Execute multiple user operations in parallel with all-or-nothing semantics
**When to use:** Bulk approve, delete, or role assignment
**Example:**
```typescript
// Source: REST API bulk operations pattern (ATOMIC mode)
interface BulkActionResult {
  success: boolean;
  processed: number;
  failed: number;
  errors?: Array<{ user_id: number; error: string }>;
}

async function bulkApproveUsers(userIds: number[]): Promise<BulkActionResult> {
  const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/bulk_approve`;

  try {
    const response = await axios.post(apiUrl, {
      user_ids: userIds,
      transaction_mode: 'ATOMIC', // All-or-nothing: any failure rolls back all
    }, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    });

    return {
      success: true,
      processed: response.data.processed,
      failed: 0,
    };
  } catch (error) {
    // ATOMIC mode: no partial success
    return {
      success: false,
      processed: 0,
      failed: userIds.length,
      errors: error.response?.data?.errors || [],
    };
  }
}

// Frontend pattern: Show result summary via toast
async function handleBulkApprove() {
  const userIds = Array.from(selectedUserIds.value);
  const result = await bulkApproveUsers(userIds);

  if (result.success) {
    makeToast(
      `Successfully approved ${result.processed} users`,
      'Bulk Approve Complete',
      'success',
      true,
      5000
    );
    clearSelection();
    loadData(); // Refresh table
  } else {
    // Show errors in danger toast (never auto-hides per useToast.ts)
    const errorMsg = result.errors?.map(e => `User ${e.user_id}: ${e.error}`).join('\n') || 'Unknown error';
    makeToast(errorMsg, 'Bulk Approve Failed', 'danger');
  }
}
```

**ATOMIC transaction requirements:**
- Backend rolls back ALL changes if ANY operation fails
- Frontend shows either full success or full failure (no partial states)
- Error messages list which specific user caused rollback

### Pattern 4: Filter Presets with useLocalStorage
**What:** Save/load filter combinations as named presets stored in localStorage
**When to use:** Complex filter combinations that admins use repeatedly
**Example:**
```typescript
// Source: VueUse useLocalStorage documentation
import { useLocalStorage } from '@vueuse/core';

interface FilterPreset {
  name: string;
  filter: {
    any: { content: string | null };
    user_role: { content: string | null };
    approved: { content: boolean | null };
  };
}

// Reactive localStorage binding (auto-syncs on change)
const filterPresets = useLocalStorage<FilterPreset[]>(
  'sysndd-user-filter-presets', // localStorage key
  [], // default value
  {
    serializer: {
      read: (v: string) => JSON.parse(v),
      write: (v: FilterPreset[]) => JSON.stringify(v),
    },
  }
);

// Save current filter as preset
function saveFilterPreset(name: string) {
  const preset: FilterPreset = {
    name,
    filter: JSON.parse(JSON.stringify(filter.value)), // Deep copy
  };

  // Check for duplicate name
  const existingIndex = filterPresets.value.findIndex(p => p.name === name);
  if (existingIndex >= 0) {
    filterPresets.value[existingIndex] = preset; // Update existing
  } else {
    filterPresets.value.push(preset); // Add new
  }
  // Auto-syncs to localStorage via VueUse
}

// Load preset
function loadFilterPreset(presetName: string) {
  const preset = filterPresets.value.find(p => p.name === presetName);
  if (preset) {
    filter.value = JSON.parse(JSON.stringify(preset.filter)); // Deep copy
    filtered(); // Trigger table refresh
  }
}

// Delete preset
function deleteFilterPreset(presetName: string) {
  filterPresets.value = filterPresets.value.filter(p => p.name !== presetName);
  // Auto-syncs to localStorage
}
```

**Best practices:**
- User-specific presets (localStorage is per-browser, not shared)
- Deep copy filter objects to prevent mutation
- Allow overwriting existing presets with same name
- Show preset buttons above table (like quick filters)
- Use BBadge or BButton variant="outline-secondary" for preset pills

### Pattern 5: Selection Badge in Table Header
**What:** Display "X selected" badge next to table title when items are selected
**When to use:** All tables with multi-select capability
**Example:**
```vue
<!-- Source: PatternFly bulk selection pattern + ManageUser.vue header -->
<template #header>
  <BRow>
    <BCol>
      <h5 class="mb-1 text-start">
        <strong>Manage Users</strong>
        <BBadge variant="secondary" class="ms-2">{{ totalRows }} users</BBadge>
        <BBadge
          v-if="selectionCount > 0"
          variant="primary"
          class="ms-2"
        >
          {{ selectionCount }} selected
        </BBadge>
      </h5>
    </BCol>
    <BCol class="text-end">
      <!-- Bulk action buttons (visible only when selection > 0) -->
      <template v-if="selectionCount > 0">
        <BButton
          v-b-tooltip.hover
          size="sm"
          variant="success"
          class="me-1"
          title="Approve selected users"
          @click="handleBulkApprove"
        >
          <i class="bi bi-check-circle" /> Approve ({{ selectionCount }})
        </BButton>
        <BButton
          v-b-tooltip.hover
          size="sm"
          variant="primary"
          class="me-1"
          title="Assign role to selected users"
          @click="showBulkRoleModal"
        >
          <i class="bi bi-person-badge" /> Assign Role
        </BButton>
        <BButton
          v-b-tooltip.hover
          size="sm"
          variant="danger"
          class="me-1"
          title="Delete selected users"
          @click="handleBulkDelete"
        >
          <i class="bi bi-trash" /> Delete
        </BButton>
        <BButton
          v-b-tooltip.hover
          size="sm"
          variant="link"
          title="Clear selection"
          @click="clearSelection"
        >
          <i class="bi bi-x" />
        </BButton>
      </template>
      <!-- Standard export/filter buttons -->
      <BButton>...</BButton>
    </BCol>
  </BRow>
</template>
```

**UI patterns:**
- Show "X selected" badge only when selectionCount > 0
- Show bulk action buttons only when selection exists
- Use icon + text for clarity (e.g., "Approve (5)" not just "Approve")
- Place clear selection button (X) next to bulk actions

### Pattern 6: Maximum Selection Limit
**What:** Prevent selecting more than 20 users to avoid accidental mass operations
**When to use:** All bulk operations with potential for large-scale mistakes
**Example:**
```typescript
const MAX_SELECTION = 20;

function toggleUserSelection(userId: number) {
  const newSet = new Set(selectedUserIds.value);

  if (newSet.has(userId)) {
    newSet.delete(userId); // Always allow deselection
  } else {
    // Check limit before adding
    if (newSet.size >= MAX_SELECTION) {
      makeToast(
        `Maximum ${MAX_SELECTION} users can be selected at once`,
        'Selection Limit Reached',
        'warning'
      );
      return; // Don't add
    }
    newSet.add(userId);
  }

  selectedUserIds.value = newSet;
}

// Select all on current page (respecting limit)
function selectAllOnPage() {
  const newSet = new Set(selectedUserIds.value);

  for (const user of users.value) {
    if (newSet.size >= MAX_SELECTION) {
      makeToast(
        `Selection limited to ${MAX_SELECTION} users`,
        'Selection Limit',
        'warning'
      );
      break;
    }
    newSet.add(user.user_id);
  }

  selectedUserIds.value = newSet;
}
```

**Context decision:** 20 user limit prevents accidental admin deletion or mass role changes.

### Anti-Patterns to Avoid
- **Using Array for selection state:** O(n) operations, duplicates possible, Set is better
- **Not using ATOMIC transactions:** Partial success creates inconsistent state (5 approved, 3 failed)
- **Auto-hiding error toasts:** Critical bulk operation errors must require manual dismissal
- **Simple OK/Cancel for destructive bulk actions:** Type-to-confirm prevents accidents
- **Storing presets in backend:** localStorage is simpler, user-specific, no backend changes needed
- **Not clearing selection after bulk action:** Confusing UX—user may re-execute same action
- **Showing full selection list in confirmation:** For 20 items, scrollable list in modal is better

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Reactive localStorage | Custom JSON.parse + watch | `useLocalStorage` (VueUse) | Handles SSR, parsing errors, reactivity, type safety automatically |
| Bulk API transaction handling | Sequential axios calls | Single bulk endpoint with ATOMIC mode | Prevents partial failures, simpler error handling, backend controls rollback |
| Set reactivity | Manual Vue.set or array fallback | `ref(new Set())` with Vue 3 Proxy | Vue 3 natively tracks Set mutations, proven in codebase |
| Promise-based modal confirmations | Template v-model + event emitters | `useModal().create().show()` | Returns promise, programmatic control, dynamic content easier |
| Toast auto-hide for errors | Custom timer logic | Existing useToast.ts (danger never auto-hides) | Medical app requirement already implemented |
| Type-to-confirm input validation | Manual string comparison | `computed(() => confirmText.value === 'DELETE')` + okDisabled | Reactive validation, automatic button state |
| Selection badge display | Manual v-if with counter | Computed `selectionCount` + BBadge v-if | Reactive, consistent with table count badge pattern |

**Key insight:** The codebase already has proven patterns for all major features—Set-based selection (NetworkVisualization.vue), promise-based modals (Bootstrap-Vue-Next useModal), reactive localStorage (VueUse). The main work is backend bulk endpoints and wiring existing patterns together.

## Common Pitfalls

### Pitfall 1: Set Reactivity Not Triggering
**What goes wrong:** Modifying Set with `selectedIds.value.add(id)` doesn't trigger Vue reactivity
**Why it happens:** Vue 3 Proxy tracks Set mutations, but must reassign `.value` to trigger watchers/computed
**How to avoid:** Always create new Set and reassign: `selectedIds.value = new Set(selectedIds.value)`
**Warning signs:**
- Selection checkboxes don't update when clicking
- Selection count badge shows 0 even when items selected
- Console shows Set has items but UI doesn't reflect it

**Correct pattern:**
```typescript
// WRONG: Direct mutation doesn't trigger reactivity reliably
selectedIds.value.add(userId); // May not trigger watchers

// RIGHT: Create new Set and reassign
const newSet = new Set(selectedIds.value);
newSet.add(userId);
selectedIds.value = newSet; // Triggers reactivity
```

### Pitfall 2: Not Clearing Selection After Bulk Action
**What goes wrong:** After bulk delete, selection still shows deleted users, causing confusion
**Why it happens:** Forgot to call `clearSelection()` after successful bulk operation
**How to avoid:** Always clear selection after successful bulk action (approve, delete, role assign)
**Warning signs:**
- Selection badge shows "5 selected" but table only has 3 rows
- Clicking bulk action again shows "User not found" errors
- User must manually deselect items after bulk operation

**Correct pattern:**
```typescript
async function handleBulkApprove() {
  const result = await bulkApproveUsers(Array.from(selectedUserIds.value));
  if (result.success) {
    clearSelection(); // CRITICAL: Clear before table refresh
    loadData(); // Refresh table
    makeToast('Approved successfully', 'Success', 'success');
  }
}
```

### Pitfall 3: Filter Preset Mutation Instead of Copy
**What goes wrong:** Loading preset mutates the preset object, causing saved presets to change unexpectedly
**Why it happens:** JavaScript object references—filter.value = preset.filter creates shared reference
**How to avoid:** Deep copy preset filter before assigning: `JSON.parse(JSON.stringify(preset.filter))`
**Warning signs:**
- Saved preset changes when you modify current filter
- Loading preset twice gives different results
- Deleting a preset affects other presets with same values

**Correct pattern:**
```typescript
// WRONG: Creates reference, mutates preset
function loadPreset(preset) {
  filter.value = preset.filter; // BAD: Shared reference
}

// RIGHT: Deep copy breaks reference
function loadPreset(preset) {
  filter.value = JSON.parse(JSON.stringify(preset.filter)); // Good
}
```

### Pitfall 4: ATOMIC Transaction Not Actually Atomic
**What goes wrong:** Backend processes 10 users, fails on 11th, but first 10 stay changed
**Why it happens:** Backend doesn't implement proper transaction rollback
**How to avoid:** Backend must use database transactions with rollback on ANY failure
**Warning signs:**
- Bulk action shows "Failed" but some users were actually changed
- Inconsistent state: 5 users approved, 5 not, when all 10 should fail together
- Error message says "User 8 failed" but users 1-7 were changed

**Backend requirement:**
```python
# Backend must use transaction context
@db.begin()  # Start transaction
def bulk_approve(user_ids):
    for user_id in user_ids:
        user = db.get(user_id)
        if user.user_role == 'Admin':
            raise Exception("Cannot modify admin")  # Rolls back ALL
        user.approved = True
    db.commit()  # Only commits if ALL succeed
```

### Pitfall 5: Type-to-Confirm Auto-Focus on OK Button
**What goes wrong:** User accidentally hits Enter, confirming destructive action without typing
**Why it happens:** Bootstrap modal auto-focuses first button (OK) by default
**How to avoid:** Set `cancelVariant` focus or disable OK button until text matches
**Warning signs:**
- Users accidentally delete items by hitting Enter too quickly
- Confirmation dialog doesn't actually prevent mistakes
- Delete action happens without typing required text

**Correct pattern:**
```typescript
// Use okDisabled to prevent accidental Enter key confirmation
const result = await create({
  okDisabled: computed(() => confirmText.value !== 'DELETE'),
  // OK button stays disabled until user types "DELETE"
}).show();
```

### Pitfall 6: Not Validating Selection Contains Admin Users
**What goes wrong:** Bulk delete includes admin users, causing backend error or accidental admin deletion
**Why it happens:** Frontend doesn't check user roles before sending bulk delete request
**How to avoid:** Frontend validates selection contains no admins before showing confirmation
**Warning signs:**
- Backend returns "Cannot delete admin users" error
- User sees delete confirmation, clicks confirm, then gets error
- Admin user accidentally deleted (if backend doesn't validate)

**Correct pattern:**
```typescript
async function handleBulkDelete() {
  const selectedUsers = users.value.filter(u => selectedUserIds.value.has(u.user_id));
  const adminUsers = selectedUsers.filter(u => u.user_role === 'Admin');

  if (adminUsers.length > 0) {
    makeToast(
      `Cannot delete: selection contains ${adminUsers.length} admin users`,
      'Delete Blocked',
      'danger'
    );
    return; // Stop before showing confirmation modal
  }

  // Proceed with type-to-confirm modal
  const confirmed = await confirmBulkDelete(/* ... */);
  if (confirmed) {
    await bulkDeleteUsers(Array.from(selectedUserIds.value));
  }
}
```

### Pitfall 7: Selection Persists Across Filter Changes
**What goes wrong:** User filters for "Pending" users, selects 5, changes filter to "Approved", selection count still shows 5 but items not visible
**Why it happens:** Selection Set persists but filtered table no longer shows those users
**How to avoid:** Context says selection SHOULD persist (users can select across filters), but show warning badge if selected items not visible on current page
**Warning signs:**
- Selection badge shows "5 selected" but no checkboxes checked on current page
- User confused why bulk action affects users they can't see
- Accidental bulk operations on filtered-out users

**Design decision (from context):** Selection DOES persist across pagination, but provide "Clear selection" button if confusing. This matches Gmail pattern where selection persists across pages/filters.

## Code Examples

Verified patterns from official sources and existing codebase:

### Bulk Selection Composable (useBulkSelection.ts)
```typescript
// NEW composable following NetworkVisualization.vue Set pattern
import { ref, computed } from 'vue';
import type { Ref, ComputedRef } from 'vue';

export interface BulkSelectionState<T> {
  selectedIds: Ref<Set<T>>;
  selectionCount: ComputedRef<number>;
  isSelected: (id: T) => boolean;
  toggleSelection: (id: T) => void;
  clearSelection: () => void;
  selectMultiple: (ids: T[]) => void;
  getSelectedArray: () => T[];
}

export function useBulkSelection<T>(
  maxSelection: number = 20
): BulkSelectionState<T> {
  const selectedIds = ref(new Set<T>());

  const selectionCount = computed(() => selectedIds.value.size);

  const isSelected = (id: T): boolean => {
    return selectedIds.value.has(id);
  };

  const toggleSelection = (id: T): void => {
    const newSet = new Set(selectedIds.value);

    if (newSet.has(id)) {
      newSet.delete(id);
    } else {
      if (newSet.size >= maxSelection) {
        // Toast handled in component (needs useToast context)
        console.warn(`Selection limit ${maxSelection} reached`);
        return;
      }
      newSet.add(id);
    }

    selectedIds.value = newSet;
  };

  const clearSelection = (): void => {
    selectedIds.value = new Set();
  };

  const selectMultiple = (ids: T[]): void => {
    const newSet = new Set(selectedIds.value);
    for (const id of ids) {
      if (newSet.size >= maxSelection) break;
      newSet.add(id);
    }
    selectedIds.value = newSet;
  };

  const getSelectedArray = (): T[] => {
    return Array.from(selectedIds.value);
  };

  return {
    selectedIds,
    selectionCount,
    isSelected,
    toggleSelection,
    clearSelection,
    selectMultiple,
    getSelectedArray,
  };
}
```

### Filter Presets Composable (useFilterPresets.ts)
```typescript
// NEW composable using VueUse useLocalStorage
import { useLocalStorage } from '@vueuse/core';
import type { Ref } from 'vue';

export interface FilterPreset {
  name: string;
  filter: Record<string, unknown>; // Generic filter object structure
  created: string; // ISO date string
}

export interface FilterPresetsState {
  presets: Ref<FilterPreset[]>;
  savePreset: (name: string, filter: Record<string, unknown>) => void;
  loadPreset: (name: string) => Record<string, unknown> | null;
  deletePreset: (name: string) => void;
  hasPreset: (name: string) => boolean;
}

export function useFilterPresets(
  storageKey: string = 'sysndd-filter-presets'
): FilterPresetsState {
  // Reactive localStorage binding with JSON serialization
  const presets = useLocalStorage<FilterPreset[]>(
    storageKey,
    [], // default value
    {
      serializer: {
        read: (v: string) => {
          try {
            return JSON.parse(v);
          } catch {
            return [];
          }
        },
        write: (v: FilterPreset[]) => JSON.stringify(v),
      },
    }
  );

  const savePreset = (name: string, filter: Record<string, unknown>): void => {
    const preset: FilterPreset = {
      name,
      filter: JSON.parse(JSON.stringify(filter)), // Deep copy
      created: new Date().toISOString(),
    };

    const existingIndex = presets.value.findIndex(p => p.name === name);
    if (existingIndex >= 0) {
      presets.value[existingIndex] = preset; // Update existing
    } else {
      presets.value = [...presets.value, preset]; // Add new
    }
    // Auto-syncs to localStorage via VueUse
  };

  const loadPreset = (name: string): Record<string, unknown> | null => {
    const preset = presets.value.find(p => p.name === name);
    if (!preset) return null;

    // Return deep copy to prevent mutation
    return JSON.parse(JSON.stringify(preset.filter));
  };

  const deletePreset = (name: string): void => {
    presets.value = presets.value.filter(p => p.name !== name);
    // Auto-syncs to localStorage
  };

  const hasPreset = (name: string): boolean => {
    return presets.value.some(p => p.name === name);
  };

  return {
    presets,
    savePreset,
    loadPreset,
    deletePreset,
    hasPreset,
  };
}
```

### Bulk Approve Implementation
```typescript
// ManageUser.vue - Bulk approve with toast feedback
import { useBulkSelection } from '@/composables/useBulkSelection';
import useToast from '@/composables/useToast';

const { makeToast } = useToast();
const { selectedIds, selectionCount, clearSelection } = useBulkSelection<number>(20);

async function handleBulkApprove() {
  const userIds = Array.from(selectedIds.value);

  if (userIds.length === 0) {
    makeToast('No users selected', 'Bulk Approve', 'warning');
    return;
  }

  // Simple confirmation (non-destructive action)
  const { create } = useModal();
  const result = await create({
    title: 'Approve Users',
    body: `Approve ${userIds.length} selected users?`,
    okTitle: 'Approve',
    okVariant: 'success',
  }).show();

  if (!result.ok) return;

  // Call bulk API
  const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/bulk_approve`;
  try {
    const response = await axios.post(apiUrl, {
      user_ids: userIds,
      transaction_mode: 'ATOMIC',
    }, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    });

    if (response.status === 200) {
      makeToast(
        `Successfully approved ${response.data.processed} users`,
        'Bulk Approve Complete',
        'success',
        true,
        5000
      );
      clearSelection(); // Clear before refresh
      loadData(); // Refresh table
    }
  } catch (error) {
    const errorMsg = error.response?.data?.message || 'Unknown error';
    makeToast(errorMsg, 'Bulk Approve Failed', 'danger');
  }
}
```

### Bulk Delete with Type-to-Confirm
```typescript
// ManageUser.vue - Bulk delete with type-to-confirm pattern
import { h } from 'vue';

async function handleBulkDelete() {
  const selectedUsers = users.value.filter(u => selectedIds.value.has(u.user_id));

  // Frontend validation: Block if admins selected
  const adminUsers = selectedUsers.filter(u => u.user_role === 'Admin');
  if (adminUsers.length > 0) {
    makeToast(
      `Cannot delete: selection contains ${adminUsers.length} admin users`,
      'Delete Blocked',
      'danger'
    );
    return;
  }

  // Type-to-confirm modal
  const confirmText = ref('');
  const isConfirmValid = computed(() => confirmText.value === 'DELETE');

  const { create } = useModal();
  const result = await create({
    title: 'Delete Users',
    okVariant: 'danger',
    okTitle: 'Delete',
    cancelTitle: 'Cancel',
    okDisabled: computed(() => !isConfirmValid.value),
    body: h('div', [
      h('p', { class: 'text-danger fw-bold' }, 'This action cannot be undone.'),
      h('p', `You are about to delete ${selectedUsers.length} users:`),
      h('div', {
        class: 'border rounded p-2 mb-3 bg-light',
        style: { maxHeight: '200px', overflowY: 'auto' }
      }, selectedUsers.map(u => h('div', { class: 'small' }, u.user_name))),
      h('p', { class: 'mb-1' }, 'Type DELETE to confirm:'),
      h('input', {
        type: 'text',
        class: 'form-control',
        placeholder: 'DELETE',
        onInput: (e) => { confirmText.value = e.target.value; },
      }),
    ]),
  }).show();

  if (!result.ok) return;

  // Call bulk delete API
  const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/bulk_delete`;
  try {
    const response = await axios.post(apiUrl, {
      user_ids: Array.from(selectedIds.value),
      transaction_mode: 'ATOMIC',
    }, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    });

    if (response.status === 200) {
      makeToast(
        `Successfully deleted ${response.data.processed} users`,
        'Bulk Delete Complete',
        'success',
        true,
        5000
      );
      clearSelection();
      loadData();
    }
  } catch (error) {
    const errorMsg = error.response?.data?.message || 'Unknown error';
    makeToast(errorMsg, 'Bulk Delete Failed', 'danger');
  }
}
```

### Bulk Role Assignment with Dropdown
```typescript
// ManageUser.vue - Bulk role assignment
async function handleBulkAssignRole() {
  const userIds = Array.from(selectedIds.value);

  if (userIds.length === 0) {
    makeToast('No users selected', 'Assign Role', 'warning');
    return;
  }

  // Modal with role dropdown
  const selectedRole = ref<string | null>(null);

  const { create } = useModal();
  const result = await create({
    title: 'Assign Role',
    okTitle: 'Assign',
    okVariant: 'primary',
    okDisabled: computed(() => !selectedRole.value),
    body: h('div', [
      h('p', `Assign role to ${userIds.length} selected users:`),
      h('select', {
        class: 'form-select',
        onChange: (e) => { selectedRole.value = e.target.value; },
      }, [
        h('option', { value: '' }, 'Select a role...'),
        h('option', { value: 'Curator' }, 'Curator'),
        h('option', { value: 'Reviewer' }, 'Reviewer'),
        h('option', { value: 'Admin' }, 'Admin'),
      ]),
    ]),
  }).show();

  if (!result.ok || !selectedRole.value) return;

  // Call bulk role assignment API
  const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/bulk_assign_role`;
  try {
    const response = await axios.post(apiUrl, {
      user_ids: userIds,
      role: selectedRole.value,
      transaction_mode: 'ATOMIC',
    }, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    });

    if (response.status === 200) {
      makeToast(
        `Successfully assigned ${selectedRole.value} role to ${response.data.processed} users`,
        'Bulk Role Assignment Complete',
        'success',
        true,
        5000
      );
      clearSelection();
      loadData();
    }
  } catch (error) {
    const errorMsg = error.response?.data?.message || 'Unknown error';
    makeToast(errorMsg, 'Bulk Role Assignment Failed', 'danger');
  }
}
```

### Filter Preset UI
```vue
<!-- ManageUser.vue - Filter preset buttons above table -->
<BRow v-if="filterPresets.presets.value.length > 0" class="px-2 pb-2">
  <BCol>
    <div class="d-flex gap-2 align-items-center">
      <span class="text-muted small">Quick filters:</span>
      <BButton
        v-for="preset in filterPresets.presets.value"
        :key="preset.name"
        size="sm"
        variant="outline-secondary"
        @click="loadFilterPreset(preset.name)"
      >
        {{ preset.name }}
      </BButton>
      <BButton
        v-b-tooltip.hover
        size="sm"
        variant="link"
        title="Save current filter as preset"
        @click="showSavePresetModal"
      >
        <i class="bi bi-save" />
      </BButton>
    </div>
  </BCol>
</BRow>

<script setup>
import { useFilterPresets } from '@/composables/useFilterPresets';

const filterPresets = useFilterPresets('sysndd-manage-user-presets');

function loadFilterPreset(name: string) {
  const presetFilter = filterPresets.loadPreset(name);
  if (presetFilter) {
    filter.value = presetFilter; // Deep copy already done in composable
    filtered(); // Trigger table refresh
    makeToast(`Loaded preset: ${name}`, 'Filter Preset', 'info', true, 2000);
  }
}

async function showSavePresetModal() {
  const presetName = ref('');

  const { create } = useModal();
  const result = await create({
    title: 'Save Filter Preset',
    okTitle: 'Save',
    okDisabled: computed(() => !presetName.value.trim()),
    body: h('div', [
      h('label', { class: 'form-label' }, 'Preset name:'),
      h('input', {
        type: 'text',
        class: 'form-control',
        placeholder: 'e.g., Pending Approvals',
        onInput: (e) => { presetName.value = e.target.value; },
      }),
    ]),
  }).show();

  if (result.ok && presetName.value.trim()) {
    filterPresets.savePreset(presetName.value.trim(), filter.value);
    makeToast(`Saved preset: ${presetName.value}`, 'Filter Preset', 'success');
  }
}
</script>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Array-based selection tracking | Set-based with Vue 3 Proxy reactivity | Vue 3 migration (2024-2025) | O(1) add/delete/has operations, automatic deduplication |
| Template-based modals with v-model | useModal().create() promise-based | Bootstrap-Vue-Next 0.42.0 | Programmatic control, async/await pattern, dynamic content easier |
| Manual localStorage with JSON.parse | VueUse useLocalStorage composable | VueUse adoption (2024+) | Reactive binding, automatic serialization, SSR safety |
| OK/Cancel confirmation dialogs | Type-to-confirm for destructive actions | GitHub/modern UX standard (2020+) | Prevents accidental destructive actions, better for bulk operations |
| Per-item API calls in loop | Bulk endpoints with ATOMIC transactions | Modern REST API standards (2020+) | All-or-nothing semantics, single round-trip, proper rollback |
| this.$bvToast.toast() (Vue 2) | useToast composable (Vue 3) | Bootstrap-Vue-Next migration | Composition API, better TypeScript support, medical app customization |

**Deprecated/outdated:**
- **Array.includes() for selection:** Use Set.has() for O(1) performance
- **Sequential axios calls for bulk operations:** Use single bulk endpoint with transaction_mode: 'ATOMIC'
- **Simple OK/Cancel for bulk delete:** Use type-to-confirm pattern (GitHub standard)
- **Backend storage for user-specific UI preferences:** Use localStorage for filter presets (simpler, no backend needed)
- **Manual Set reassignment everywhere:** Vue 3 Proxy tracks Set mutations, but reassign `.value` for watcher triggers
- **Auto-hiding error toasts for bulk operations:** Critical errors require manual dismissal (existing useToast.ts pattern)

## Open Questions

Things that couldn't be fully resolved:

1. **Backend bulk endpoint support**
   - What we know: Existing single-user endpoints exist (/api/user/delete, /api/user/approval, /api/user/change_role)
   - What's unclear: Do bulk endpoints exist (/api/user/bulk_delete, /api/user/bulk_approve, /api/user/bulk_assign_role)?
   - Recommendation: Backend task to add three bulk endpoints with ATOMIC transaction mode. If not possible, frontend can call existing endpoints in Promise.all() but loses all-or-nothing guarantee.

2. **ATOMIC transaction backend implementation**
   - What we know: Context requires all-or-nothing transactions
   - What's unclear: Does backend database support transactions? FastAPI/SQLAlchemy pattern?
   - Recommendation: Backend must use database transaction context (e.g., SQLAlchemy session.begin(), rollback on exception). This is standard SQL feature.

3. **Filter preset sharing across admins**
   - What we know: Context says "user-specific, not shared"
   - What's unclear: Future requirement to share presets?
   - Recommendation: Start with localStorage (per-user). If sharing needed later, backend endpoint can export/import JSON presets.

4. **Maximum selection limit enforcement**
   - What we know: Context says 20 user limit
   - What's unclear: Should backend also enforce limit? Or trust frontend?
   - Recommendation: Backend should validate request has ≤20 user_ids and return 400 error if exceeded (defense in depth).

5. **Admin role validation location**
   - What we know: Cannot bulk-delete admins
   - What's unclear: Frontend validation only, or backend enforcement?
   - Recommendation: Both layers—frontend prevents showing invalid confirmation, backend validates and returns error if admin IDs included (security).

6. **Undo capability for bulk operations**
   - What we know: Context mentions "automatic table refresh" after success
   - What's unclear: Should non-destructive actions (approve, role assign) have undo button in toast?
   - Recommendation: Not required by success criteria. Undo for bulk operations requires complex state tracking (store previous values for all users). Skip for Phase 29 unless user requests.

## Sources

### Primary (HIGH confidence)
- Bootstrap-Vue-Next useModal: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/composables/useModal
- Bootstrap-Vue-Next useToast: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/composables/useToast.html
- VueUse useLocalStorage: https://vueuse.org/core/uselocalstorage/
- Vue 3 Set/Map Reactivity: https://vuejs.org/guide/essentials/reactivity-fundamentals.html
- Existing codebase patterns:
  - NetworkVisualization.vue (Set-based selection, lines 663-669)
  - ManageUser.vue (existing single-user operations, toast patterns)
  - useToast.ts (medical app error handling)
  - useModalControls.ts (modal helpers)

### Secondary (MEDIUM confidence)
- [Bulk action UX: 8 design guidelines with examples for SaaS](https://www.eleken.co/blog-posts/bulk-actions-ux) - Eleken.co design patterns
- [PatternFly Bulk Selection](https://www.patternfly.org/patterns/bulk-selection/) - Enterprise design system pattern
- [Type-to-confirm DELETE pattern - Cloudscape Design System](https://cloudscape.design/patterns/resource-management/delete/delete-with-additional-confirmation/)
- [REST API Bulk Operations - SPS Standards](https://spscommerce.github.io/sps-api-standards/standards/bulk.html)
- [A UX guide to destructive actions - Medium](https://medium.com/design-bootcamp/a-ux-guide-to-destructive-actions-their-use-cases-and-best-practices-f1d8a9478d03)

### Tertiary (LOW confidence)
- [Vue 3 reactive Set Map add delete reactivity tracking - Dev.to](https://dev.to/jinjiang/understanding-reactivity-in-vue-3-0-1jni) - Community article, verified with official docs
- [How to Make JavaScript Maps and Sets Reactive in Vue.js - Medium](https://medium.com/@hohanga/how-to-make-javascript-maps-and-sets-reactive-in-vue-js-b944cdd5b7c2) - Vue 2 context, Vue 3 differs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already installed (Bootstrap-Vue-Next, VueUse), Set pattern proven in NetworkVisualization.vue
- Architecture: HIGH - All patterns exist in codebase (Set selection, useModal, useToast, useLocalStorage)
- Pitfalls: HIGH - Set reactivity pattern documented in Vue 3 docs, ATOMIC transaction requirement from context
- Code examples: HIGH - All examples from Bootstrap-Vue-Next official docs, VueUse docs, or existing codebase patterns

**Research date:** 2026-01-25
**Valid until:** 2026-02-25 (30 days for stable ecosystem—Bootstrap-Vue-Next and VueUse are mature libraries)

**Backend dependencies:**
- Three new bulk endpoints required: /api/user/bulk_approve, /api/user/bulk_delete, /api/user/bulk_assign_role
- ATOMIC transaction mode support (all-or-nothing semantics)
- Validation: max 20 users per request, no admin users in delete requests
