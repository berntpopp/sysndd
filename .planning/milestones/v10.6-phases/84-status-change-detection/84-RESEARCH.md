# Phase 84: Status Change Detection - Research

**Researched:** 2026-02-10
**Domain:** Vue 3 frontend form change detection, Bootstrap-Vue-Next modal events
**Confidence:** HIGH

## Summary

This phase adds change detection to status and review forms to prevent unnecessary database records when curators save without making changes. The research reveals a mature codebase with existing patterns for both form management and change detection that can be extended.

**Key findings:**
- `useStatusForm` and `useReviewForm` composables already manage form state but lack change detection
- `LlmPromptEditor.vue` provides the exact `hasChanges` computed property pattern to replicate
- Bootstrap-Vue-Next BModal supports `@hide` event with `preventDefault()` for unsaved changes warnings
- Backend already calculates `status_change` and `review_change` flags in review/status endpoints
- ApproveReview correctly displays status change indicators, but ApproveStatus doesn't display review change indicators

**Primary recommendation:** Extend both composables with `hasChanges` computed properties comparing current form data to loaded data, implement silent skip on save when unchanged, add @hide handlers for unsaved changes warnings, and fix missing review_change indicator in ApproveStatus.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.5.25 | Reactive framework | Project standard |
| TypeScript | 5.7.3 | Type safety | Project standard |
| Bootstrap-Vue-Next | 0.42.0 | UI components including BModal | Project standard |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @vue/test-utils | - | Component testing | Testing change detection logic |
| Vitest | - | Test runner | Unit tests for composables |

### Alternatives Considered
None — this phase works within existing stack.

## Architecture Patterns

### Recommended Implementation Structure

```
app/src/views/curate/
├── composables/
│   ├── useStatusForm.ts          # Add hasChanges computed
│   ├── useReviewForm.ts          # Add hasChanges computed (may already have pattern)
│   └── __tests__/
│       ├── useStatusForm.spec.ts # Add change detection tests
│       └── useReviewForm.spec.ts # Already exists with BUG-05 tests
├── ModifyEntity.vue              # Add @hide handler, skip save logic
├── ApproveReview.vue             # Add @hide handler, skip save logic
└── ApproveStatus.vue             # Add @hide handler, skip save logic, FIX review_change indicator
```

### Pattern 1: Change Detection with Computed Property

**What:** Track loaded data separately from edited data, use computed to detect differences
**When to use:** Any form that loads existing data and allows edits
**Example from LlmPromptEditor.vue:**

```typescript
// Source: /home/bernt-popp/development/sysndd/app/src/components/llm/LlmPromptEditor.vue

// Loaded data (comes from API)
const currentPrompt = computed(() => props.prompts?.[selectedPrompt.value]);

// Edited data (user changes)
const editedTemplate = ref('');
const editedVersion = ref('');

// Watch to sync loaded → edited when data changes
watch(
  [selectedPrompt, () => props.prompts],
  () => {
    if (currentPrompt.value) {
      editedTemplate.value = currentPrompt.value.template_text;
      editedVersion.value = currentPrompt.value.version;
    }
  },
  { immediate: true }
);

// Change detection
const hasChanges = computed(() => {
  if (!currentPrompt.value) return false;
  return (
    editedTemplate.value !== currentPrompt.value.template_text ||
    editedVersion.value !== currentPrompt.value.version
  );
});
```

**Application to useStatusForm:**
```typescript
// Add to useStatusForm.ts composable

// Store original loaded data
const loadedData = ref<Pick<StatusFormData, 'category_id' | 'comment' | 'problematic'> | null>(null);

// In loadStatusData() and loadStatusByEntity(), after setting formData:
loadedData.value = {
  category_id: formData.category_id,
  comment: formData.comment,
  problematic: formData.problematic,
};

// Export hasChanges computed
const hasChanges = computed(() => {
  if (!loadedData.value) return false;
  return (
    formData.category_id !== loadedData.value.category_id ||
    formData.comment !== loadedData.value.comment ||
    formData.problematic !== loadedData.value.problematic
  );
});

// Reset loadedData in resetForm()
loadedData.value = null;

// Return hasChanges
return {
  // ... existing exports
  hasChanges,
};
```

### Pattern 2: Modal Close Prevention with Unsaved Changes

**What:** Intercept modal close events and show confirmation if user has unsaved changes
**When to use:** Any modal with forms that track changes
**Bootstrap-Vue-Next event documentation:**

```typescript
// Source: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/modal

// BModal emits 'hide' event before closing
// Event object has preventDefault() method

<BModal @hide="onModalHide">
  <!-- form content -->
</BModal>

const onModalHide = (event: BvTriggerableEvent) => {
  if (hasChanges.value) {
    const confirmed = window.confirm('You have unsaved changes. Discard?');
    if (!confirmed) {
      event.preventDefault(); // Prevents modal from closing
    }
  }
};
```

**Application to ModifyEntity.vue:**
```vue
<BModal
  id="modifyStatusModal"
  @hide="onStatusModalHide"
  @ok="submitStatusChange"
>
  <!-- status form -->
</BModal>

<script>
const onStatusModalHide = (event) => {
  if (hasStatusChanges.value) {
    const confirmed = window.confirm('You have unsaved status changes. Discard them?');
    if (!confirmed) {
      event.preventDefault();
    }
  }
};

const submitStatusChange = async () => {
  // Skip submission if no changes
  if (!hasStatusChanges.value) {
    // Silent skip - close modal without API call
    return;
  }

  // Normal submission flow
  await submitStatusForm(false, false);
  // ... existing success handling
};
</script>
```

### Pattern 3: Silent Skip on Save

**What:** When user clicks Save but hasChanges is false, close modal without API call or toast
**When to use:** Forms with change detection that shouldn't penalize users for clicking save
**Implementation:**

```typescript
// In submitStatusChange(), submitReviewChange() methods

async submitStatusChange() {
  // Check for changes FIRST
  if (!this.hasStatusChanges) {
    // Silent skip - just close modal
    this.$refs.modifyStatusModal.hide();
    return;
  }

  // Existing submission logic
  this.submitting = 'status';
  try {
    await this.submitStatusForm(false, false);
    this.makeToast('Status submitted successfully', 'Success', 'success');
    // ... rest of success handling
  } catch (e) {
    // ... error handling
  } finally {
    this.submitting = null;
  }
}
```

### Pattern 4: Change Indicator Icons

**What:** Show exclamation-triangle-fill overlay on stoplights/action icons when pending changes exist
**When to use:** Table rows where backend provides status_change or review_change flags
**Example from ApproveReview.vue:**

```vue
<!-- Source: app/src/views/curate/ApproveReview.vue lines 385-393 -->

<BButton
  v-b-tooltip.hover.right
  size="sm"
  class="me-1 btn-xs"
  :variant="stoplights_style[row.item.active_category]"
  @click="infoStatus(row.item, row.index, $event.target)"
>
  <span class="position-relative d-inline-block" style="font-size: 0.9em">
    <i class="bi bi-stoplights" aria-hidden="true" />
    <i
      v-if="row.item.status_change"
      class="bi bi-exclamation-triangle-fill position-absolute"
      style="top: -0.3em; right: -0.5em; font-size: 0.7em"
      aria-hidden="true"
    />
  </span>
</BButton>
```

**Missing in ApproveStatus.vue:**
- Backend provides `review_change` field (api/endpoints/status_endpoints.R:142)
- Frontend receives it but doesn't render indicator
- Need to add similar pattern for review edit button

### Anti-Patterns to Avoid

- **Don't compare formData directly with itself:** `formData !== formData` is always false due to Vue reactivity proxies
- **Don't store loaded data in formData itself:** Separate `loadedData` ref is cleaner than tracking initial values within reactive formData
- **Don't show toasts for skipped saves:** Silent skip maintains seamless UX
- **Don't use deepEqual for change detection:** Exact field comparison is clearer and avoids whitespace normalization issues per requirements

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Object comparison | Custom deep equality function | Direct field comparison | Only 3 fields (category_id, comment, problematic), explicit comparison is clearer and matches requirement for exact comparison including whitespace |
| Confirmation dialogs | Custom modal component | Browser `window.confirm()` | Simple use case, browser native is sufficient and already used in codebase |
| Form state tracking | Complex undo/redo system | Simple loadedData ref + computed | Only need to detect "changed vs loaded", not full history |

**Key insight:** The composables are already well-structured. Adding `hasChanges` is a small extension, not a rewrite.

## Common Pitfalls

### Pitfall 1: Forgetting to Reset loadedData

**What goes wrong:** After form reset, hasChanges might incorrectly return true because loadedData still has old values
**Why it happens:** resetForm() clears formData but developer forgets to clear loadedData
**How to avoid:** Always set `loadedData.value = null` in resetForm()
**Warning signs:** hasChanges is true immediately after opening modal on fresh entity

### Pitfall 2: Modal @show Event Timing

**What goes wrong:** ModifyEntity.vue already has `onModifyStatusModalShow` handler that's intentionally empty (lines 1453-1456). Reset was moved to `showStatusModify()` before modal opens because @show fires asynchronously after data load, causing race conditions.
**Why it happens:** Bootstrap-Vue-Next @show event fires after modal renders, which is AFTER showStatusModify() loads data
**How to avoid:** Keep reset in showStatusModify() before loadStatusByEntity(), don't add reset to @show handler
**Warning signs:** entity_id gets destroyed, form shows empty after loading

### Pitfall 3: Comparing Reactive Proxies

**What goes wrong:** `formData === loadedData` always false even when values match
**Why it happens:** Vue wraps objects in Proxy for reactivity tracking
**How to avoid:** Compare individual fields, not objects
**Warning signs:** hasChanges always returns true

### Pitfall 4: BModal @ok vs @hide Event Order

**What goes wrong:** @ok fires before @hide, so if submitForm throws error, @hide still fires and prompts "discard changes?"
**Why it happens:** Bootstrap-Vue-Next event lifecycle: ok → hide → hidden
**How to avoid:** Only check hasChanges in @hide if NOT currently submitting
**Warning signs:** User sees "discard changes?" after failed submission

### Pitfall 5: Missing review_change Indicator in ApproveStatus

**What goes wrong:** Backend calculates review_change (status_endpoints.R:142) but ApproveStatus.vue doesn't display it
**Why it happens:** Feature gap — status_change indicator was added to ApproveReview, but reciprocal review_change not added to ApproveStatus
**How to avoid:** Add same exclamation-triangle-fill pattern to review edit button in ApproveStatus
**Warning signs:** Curators miss pending review changes when approving statuses

## Code Examples

### Example 1: Extending useStatusForm with hasChanges

```typescript
// File: app/src/views/curate/composables/useStatusForm.ts
// Add after line 67 (after formData reactive definition)

// Store original loaded data for change detection
const loadedData = ref<Pick<StatusFormData, 'category_id' | 'comment' | 'problematic'> | null>(null);

// Change detection computed property
const hasChanges = computed(() => {
  if (!loadedData.value) return false;

  return (
    formData.category_id !== loadedData.value.category_id ||
    formData.comment !== loadedData.value.comment ||
    formData.problematic !== loadedData.value.problematic
  );
});

// Modify loadStatusData (line 137) - after setting formData (line 151-153):
loadedData.value = {
  category_id: formData.category_id,
  comment: formData.comment,
  problematic: formData.problematic,
};

// Modify loadStatusByEntity (line 173) - after setting formData (line 187-189):
loadedData.value = {
  category_id: formData.category_id,
  comment: formData.comment,
  problematic: formData.problematic,
};

// Modify resetForm (line 282) - add after deleting metadata:
loadedData.value = null;

// Add to return statement (line 311):
return {
  // ... existing exports
  hasChanges,
};
```

### Example 2: Modal Close Warning in ModifyEntity

```vue
<!-- File: app/src/views/curate/ModifyEntity.vue -->
<!-- Modify line 640-654 modal definition -->

<BModal
  id="modifyStatusModal"
  ref="modifyStatusModal"
  size="lg"
  centered
  ok-title="Submit"
  no-close-on-esc
  no-close-on-backdrop
  header-bg-variant="dark"
  header-text-variant="light"
  header-close-label="Close"
  :busy="statusFormLoading"
  @show="onModifyStatusModalShow"
  @hide="onModifyStatusModalHide"  <!-- ADD THIS -->
  @ok="submitStatusChange"
>
  <!-- ... form content ... -->
</BModal>

<script>
// Add to setup() return (line 787-798):
return {
  makeToast,
  ...colorAndSymbols,
  statusFormData,
  statusFormLoading,
  loadStatusByEntity,
  submitStatusForm,
  resetStatusForm,
  hasStatusChanges: statusForm.hasChanges,  // ADD THIS
  a11yMessage,
  a11yPoliteness,
  announce,
};

// Add method in methods section (after line 1456):
onModifyStatusModalHide(event) {
  if (this.hasStatusChanges && !this.submitting) {
    const confirmed = window.confirm(
      'You have unsaved status changes. Discard them?'
    );
    if (!confirmed) {
      event.preventDefault();
    }
  }
},

// Modify submitStatusChange (line 1387-1401):
async submitStatusChange() {
  // Skip if no changes
  if (!this.hasStatusChanges) {
    this.$refs.modifyStatusModal.hide();
    return;
  }

  this.submitting = 'status';
  try {
    await this.submitStatusForm(false, false);
    this.makeToast('Status submitted successfully', 'Success', 'success');
    this.announce('Status submitted successfully');
    this.resetStatusForm();
    this.resetForm(); // Also reset entity selection
  } catch (e) {
    this.makeToast(e, 'Error', 'danger');
    this.announce('Failed to submit status', 'assertive');
  } finally {
    this.submitting = null;
  }
},
</script>
```

### Example 3: Missing review_change Indicator in ApproveStatus

```vue
<!-- File: app/src/views/curate/ApproveStatus.vue -->
<!-- Add review_change indicator to review edit button (find review edit button in table cell) -->

<BButton
  v-b-tooltip.hover.right
  size="sm"
  class="me-1 btn-xs"
  variant="secondary"
  title="Edit review"
  @click="infoReview(row.item, row.index, $event.target)"
>
  <span class="position-relative d-inline-block" style="font-size: 0.9em">
    <i class="bi bi-pen" aria-hidden="true" />
    <i
      v-if="row.item.review_change"
      class="bi bi-exclamation-triangle-fill position-absolute"
      style="top: -0.3em; right: -0.5em; font-size: 0.7em"
      aria-hidden="true"
    />
  </span>
</BButton>

<!-- Add to icon legend in data() return (similar to ApproveReview line 1071-1084) -->
legendItems: [
  // ... existing status items
  {
    icon: 'bi bi-exclamation-triangle-fill',
    color: '#dc3545',
    label: 'Review change pending',
  },
  // ... other items
],
```

### Example 4: Test Pattern for Change Detection

```typescript
// File: app/src/views/curate/composables/__tests__/useStatusForm.spec.ts
// Based on existing useReviewForm.spec.ts pattern

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import useStatusForm from '../useStatusForm';

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
  },
}));

vi.mock('@/composables/useFormDraft', () => ({
  default: vi.fn(() => ({
    hasDraft: { value: false },
    lastSavedFormatted: { value: '' },
    isSaving: { value: false },
    loadDraft: vi.fn(() => null),
    clearDraft: vi.fn(),
    checkForDraft: vi.fn(() => false),
    scheduleSave: vi.fn(),
  })),
}));

describe('useStatusForm change detection', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('hasChanges is false immediately after loading', async () => {
    const axios = await import('axios');
    const mockAxios = axios.default as unknown as {
      get: ReturnType<typeof vi.fn>;
    };

    mockAxios.get.mockResolvedValue({
      data: [{
        category_id: 2,
        comment: 'Original comment',
        problematic: false,
        status_id: 123,
        entity_id: 456,
      }],
    });

    const { loadStatusByEntity, hasChanges } = useStatusForm();

    await loadStatusByEntity(456);
    await flushPromises();

    expect(hasChanges.value).toBe(false);
  });

  it('hasChanges is true when category changes', async () => {
    const axios = await import('axios');
    const mockAxios = axios.default as unknown as {
      get: ReturnType<typeof vi.fn>;
    };

    mockAxios.get.mockResolvedValue({
      data: [{
        category_id: 2,
        comment: 'Original comment',
        problematic: false,
      }],
    });

    const { loadStatusByEntity, formData, hasChanges } = useStatusForm();

    await loadStatusByEntity(456);
    await flushPromises();

    formData.category_id = 3; // Change category

    expect(hasChanges.value).toBe(true);
  });

  it('hasChanges detects comment whitespace changes (exact comparison)', async () => {
    const axios = await import('axios');
    const mockAxios = axios.default as unknown as {
      get: ReturnType<typeof vi.fn>;
    };

    mockAxios.get.mockResolvedValue({
      data: [{
        category_id: 2,
        comment: 'Original comment',
        problematic: false,
      }],
    });

    const { loadStatusByEntity, formData, hasChanges } = useStatusForm();

    await loadStatusByEntity(456);
    await flushPromises();

    formData.comment = 'Original comment '; // Added trailing space

    expect(hasChanges.value).toBe(true); // Per requirements: exact comparison
  });

  it('hasChanges resets to false after resetForm', async () => {
    const axios = await import('axios');
    const mockAxios = axios.default as unknown as {
      get: ReturnType<typeof vi.fn>;
    };

    mockAxios.get.mockResolvedValue({
      data: [{
        category_id: 2,
        comment: 'Original',
        problematic: false,
      }],
    });

    const { loadStatusByEntity, formData, hasChanges, resetForm } = useStatusForm();

    await loadStatusByEntity(456);
    await flushPromises();

    formData.category_id = 3;
    expect(hasChanges.value).toBe(true);

    resetForm();
    expect(hasChanges.value).toBe(false);
  });
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No change detection | Always create status/review record on save | Current behavior (bug) | Unnecessary database records, requires approval even when unchanged |
| Manual tracking of original values | Composable with hasChanges computed | This phase | Clean separation of concerns, testable |
| Alert on modal close | window.confirm() on @hide with preventDefault | Bootstrap-Vue-Next pattern | Standard browser native dialog |

**Deprecated/outdated:**
- None found — composables are modern Vue 3 Composition API

## Open Questions

1. **Should review form also get hasChanges if it doesn't have one?**
   - What we know: useReviewForm.spec.ts tests exist but no mention of hasChanges in current code
   - What's unclear: Whether review form already has similar pattern or needs same addition
   - Recommendation: Check useReviewForm implementation; if missing, add same pattern as status form

2. **Exact wording for confirmation dialog?**
   - What we know: Requirements say "Show confirmation dialog if user tries to close modal with unsaved changes"
   - What's unclear: Exact wording not specified
   - Recommendation: Use pattern "You have unsaved [status/review] changes. Discard them?" for consistency

3. **Should save button be disabled when no changes?**
   - What we know: Requirements say "Save button stays enabled" and "Silent skip"
   - What's unclear: Visually it might confuse users why button is enabled if nothing to save
   - Recommendation: Keep enabled per requirements, rely on silent skip behavior

## Sources

### Primary (HIGH confidence)
- `/home/bernt-popp/development/sysndd/app/src/views/curate/composables/useStatusForm.ts` - Current implementation, 340 lines
- `/home/bernt-popp/development/sysndd/app/src/views/curate/composables/useReviewForm.ts` - Current implementation with originalPublications pattern (lines 126-129, 255-259, 282-288)
- `/home/bernt-popp/development/sysndd/app/src/components/llm/LlmPromptEditor.vue` - hasChanges pattern (lines 146-152)
- `/home/bernt-popp/development/sysndd/app/src/views/curate/ModifyEntity.vue` - Status form usage, submitStatusChange (lines 1387-1401), showStatusModify (lines 1215-1239)
- `/home/bernt-popp/development/sysndd/app/src/views/curate/ApproveReview.vue` - Status change indicator pattern (lines 385-393), icon legend (lines 1071-1084)
- `/home/bernt-popp/development/sysndd/app/src/views/curate/ApproveStatus.vue` - Missing review_change indicator
- `/home/bernt-popp/development/sysndd/app/src/views/curate/composables/__tests__/useReviewForm.spec.ts` - Test patterns for composables
- `/home/bernt-popp/development/sysndd/api/endpoints/review_endpoints.R` - Backend status_change calculation (line 164)
- `/home/bernt-popp/development/sysndd/api/endpoints/status_endpoints.R` - Backend review_change calculation (line 142)
- WebFetch: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/modal - BModal events documentation

### Secondary (MEDIUM confidence)
- [Modal | BootstrapVueNext](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/modal) - Official modal component documentation
- [Computed Properties | Vue.js](https://vuejs.org/guide/essentials/computed.html) - Vue 3 computed properties guide
- [Composition API FAQ | Vue.js](https://vuejs.org/guide/extras/composition-api-faq.html) - Composition API patterns

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Existing codebase analysis, no new dependencies
- Architecture: HIGH - Clear existing patterns (LlmPromptEditor hasChanges, useReviewForm originalPublications)
- Pitfalls: HIGH - Identified from codebase comments (onModifyStatusModalShow race condition) and code review
- Change indicators: HIGH - Backend endpoints verified, ApproveReview pattern confirmed, ApproveStatus gap identified

**Research date:** 2026-02-10
**Valid until:** 2026-03-12 (30 days — stable patterns, no fast-moving dependencies)
