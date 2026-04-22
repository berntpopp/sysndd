# Phase 37: Form Modernization - Research

**Researched:** 2026-01-26
**Domain:** Vue 3 form patterns, autocomplete UX, draft persistence
**Confidence:** HIGH

## Summary

Form modernization requires established patterns in Vue 3 composables, entity search autocomplete, localStorage draft persistence, and skeleton loading states. The codebase already has strong foundations with `useEntityForm` and `useFormDraft` composables that demonstrate mature patterns for form lifecycle management and auto-save functionality.

The standard approach is:
1. **Composable-based architecture** - Extract form logic into focused composables following Vue 3 best practices
2. **AutocompleteInput pattern** - Existing component provides keyboard navigation, debouncing, and proper ARIA support
3. **localStorage with debouncing** - Auto-save with 2s debounce after changes, prompt for draft restoration
4. **Rich entity previews** - Reuse badge components (GeneBadge, DiseaseBadge) with skeleton placeholders during loading

**Primary recommendation:** Follow existing composable patterns in CreateEntity.vue (useEntityForm + useFormDraft) and AutocompleteInput.vue. Extract Review form logic using identical architecture, reuse skeleton pattern with CSS keyframe animations.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.5.25 | Framework | Composition API for reusable logic |
| Bootstrap-Vue-Next | 0.42.0 | UI Components | BFormInput, BFormSelect with v-model, validation states |
| VueUse | 14.1.0 | Utilities | Proven utility composables (if needed for debounce/storage) |
| TypeScript | 5.9.3 | Type Safety | Type-safe composables and form data |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| vee-validate | 4.15.1 | Validation | Already used in useEntityForm for field validation |
| Axios | 1.13.2 | HTTP Client | Entity search API calls |
| DOMPurify | 3.3.1 | Sanitization | If needed for user input sanitization |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom composables | VueUse useLocalStorage | Existing useFormDraft is more tailored, already working well |
| Bootstrap-Vue-Next | PrimeVue AutoComplete | User decided on Bootstrap-Vue-Next for consistency |
| CSS animations | GSAP library | CSS keyframes sufficient for skeleton loaders, GSAP overkill |

**Installation:**
No new packages required - all functionality achievable with existing dependencies.

## Architecture Patterns

### Recommended Project Structure
```
src/
├── views/
│   └── curate/
│       ├── composables/
│       │   ├── useReviewForm.ts      # NEW: Review form lifecycle
│       │   └── useStatusForm.ts      # NEW: Status form lifecycle
│       └── components/
│           └── ReviewFormFields.vue  # NEW: Reusable form fields
├── components/
│   └── forms/
│       └── AutocompleteInput.vue     # EXISTS: Reuse for entity search
└── composables/
    ├── useEntityForm.ts              # EXISTS: Pattern to follow
    └── useFormDraft.ts               # EXISTS: Reuse for drafts
```

### Pattern 1: Form Lifecycle Composable
**What:** Single composable manages form state, validation, submission, and draft integration
**When to use:** Any form with multiple fields, validation, and persistence needs

**Example:**
```typescript
// Source: Existing useEntityForm.ts pattern
export default function useReviewForm(reviewId: string) {
  // Form data state
  const formData = reactive<ReviewFormData>({
    synopsis: '',
    phenotypes: [],
    variationOntology: [],
    publications: [],
    genereviews: [],
    comment: '',
  });

  // Validation touched state
  const touched = reactive<Record<string, boolean>>({
    synopsis: false,
    publications: false,
  });

  // Draft integration
  const formDraft = useFormDraft<ReviewFormData>('review-form');
  const { scheduleSave, loadDraft, clearDraft } = formDraft;

  // Watch for auto-save
  watch(
    () => getFormSnapshot(),
    (newData) => scheduleSave(newData),
    { deep: true }
  );

  // Field validation
  const validateField = (fieldName: keyof ReviewFormData) => {
    // Validation logic
  };

  // Form submission
  const submitForm = async () => {
    // API call, then clearDraft() on success
  };

  return {
    formData,
    touched,
    validateField,
    submitForm,
    // Draft state from formDraft composable
    ...formDraft,
  };
}
```

### Pattern 2: Entity Autocomplete with Preview
**What:** AutocompleteInput component with entity API integration and preview display
**When to use:** Searching entities by ID, gene symbol, or disease name

**Example:**
```vue
<!-- Source: Existing AutocompleteInput.vue pattern -->
<template>
  <div>
    <AutocompleteInput
      v-model="entityId"
      v-model:display-value="entityDisplay"
      :results="searchResults"
      :loading="isSearching"
      :min-chars="2"
      :debounce="300"
      label="Entity"
      input-id="entity-search"
      @search="handleEntitySearch"
      @select="handleEntitySelected"
    >
      <template #item="{ item }">
        <div class="d-flex align-items-center">
          <GeneBadge :gene-symbol="item.gene_symbol" />
          <DiseaseBadge :disease-name="item.disease_name" class="ms-2" />
          <span class="ms-2 text-muted">{{ item.entity_id }}</span>
        </div>
      </template>
    </AutocompleteInput>

    <!-- Entity Preview Card -->
    <BCard v-if="selectedEntity" class="mt-3">
      <div v-if="loadingEntityData" class="skeleton-preview">
        <div class="skeleton-badge" />
        <div class="skeleton-badge" />
      </div>
      <div v-else class="d-flex align-items-center gap-2">
        <GeneBadge :gene-symbol="selectedEntity.gene_symbol" />
        <DiseaseBadge :disease-name="selectedEntity.disease_name" />
        <EntityBadge :entity-id="selectedEntity.entity_id" />
      </div>
    </BCard>
  </div>
</template>
```

### Pattern 3: Draft Persistence with Restoration
**What:** Auto-save form state with 2s debounce, prompt to restore on mount
**When to use:** Forms that take significant time to complete

**Example:**
```typescript
// Source: Existing CreateEntity.vue pattern
export default defineComponent({
  setup() {
    const formDraft = useFormDraft<FormData>('modify-entity');
    const showDraftRecovery = ref(false);

    onMounted(() => {
      if (formDraft.checkForDraft()) {
        showDraftRecovery.value = true;
      }
    });

    const restoreDraft = () => {
      const draft = formDraft.loadDraft();
      if (draft) {
        Object.assign(formData, draft);
        showDraftRecovery.value = false;
      }
    };

    const handleSubmit = async () => {
      await submitToAPI();
      formDraft.clearDraft(); // Clear only on success
    };

    return { showDraftRecovery, restoreDraft };
  }
});
```

### Pattern 4: Skeleton Loading States
**What:** CSS keyframe animation with gray boxes matching content layout
**When to use:** Loading entity preview data, waiting for API responses

**Example:**
```css
/* Source: CSS animation best practices */
.skeleton-preview {
  display: flex;
  gap: 0.5rem;
  padding: 1rem;
}

.skeleton-badge {
  height: 24px;
  width: 80px;
  background: linear-gradient(
    90deg,
    #e0e0e0 25%,
    #f0f0f0 50%,
    #e0e0e0 75%
  );
  background-size: 200% 100%;
  border-radius: 0.375rem;
  animation: skeleton-shimmer 1.5s ease-in-out infinite;
}

@keyframes skeleton-shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

/* Respect prefers-reduced-motion */
@media (prefers-reduced-motion: reduce) {
  .skeleton-badge {
    animation: none;
    background: #e0e0e0;
  }
}
```

### Anti-Patterns to Avoid
- **Mixing form logic in component** - Extract to composable, not in component setup()
- **Clearing draft on navigation** - Only clear on successful submission
- **Custom debounce implementations** - Use existing useFormDraft scheduleSave
- **Hardcoded validation messages** - Centralize in composable validation rules
- **Inline API calls** - Wrap in composable methods for testing/reuse

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Form state management | Custom reactive object | Composable pattern (useEntityForm) | Validation, touched state, lifecycle already solved |
| Autocomplete search | Custom dropdown | AutocompleteInput component | Keyboard nav, ARIA, debouncing, loading states built-in |
| Draft persistence | Custom localStorage | useFormDraft composable | Handles debouncing, stale drafts, metadata, formatting |
| Entity preview badges | Custom badge styling | GeneBadge, DiseaseBadge, EntityBadge | Consistent styling, tooltips, colors from Phase 35.1 |
| Skeleton loaders | JavaScript animation | CSS keyframes | Better performance, respects prefers-reduced-motion |
| Field validation | Inline validation | vee-validate rules (already in stack) | Centralized rules, error messages, touched state |
| PMID tag validation | Regex in component | validatePMID in useEntityForm | Already implemented, tested pattern |

**Key insight:** The codebase already has production-tested patterns for every requirement. Reuse > Rewrite. Custom solutions introduce bugs already solved in CreateEntity.vue, Review.vue, and AutocompleteInput.vue.

## Common Pitfalls

### Pitfall 1: Draft Cleared Too Early
**What goes wrong:** Draft gets cleared on modal close instead of successful submission, losing user work
**Why it happens:** Developers attach clearDraft() to @hide event, not checking submission success
**How to avoid:** Only call clearDraft() inside successful API response handler
**Warning signs:** User complains "I edited the form but my changes disappeared" - check draft clearing logic

### Pitfall 2: Missing Keyboard Navigation in Autocomplete
**What goes wrong:** Autocomplete works with mouse but not keyboard, accessibility failure
**Why it happens:** Forgetting to implement ArrowUp/Down, Enter, Escape handlers
**How to avoid:** Use existing AutocompleteInput component - already implements full keyboard nav
**Warning signs:** Tab through form, can't navigate search results with keyboard

### Pitfall 3: Race Conditions in Entity Preview
**What goes wrong:** User rapidly types in search, preview shows old entity or flickers
**Why it happens:** Multiple API calls in flight, last response overwrites correct one
**How to avoid:** Abort previous request or use request ID to ignore stale responses
**Warning signs:** Preview shows wrong entity briefly, then updates to correct one

### Pitfall 4: Debounce Not Cancelling on Unmount
**What goes wrong:** Component unmounts, debounce timer fires, tries to update unmounted component
**Why it happens:** Not clearing timeout in onUnmounted lifecycle hook
**How to avoid:** Use existing useFormDraft composable - handles cleanup in onUnmounted
**Warning signs:** Console warnings about updating unmounted component

### Pitfall 5: Form Reset Not Resetting Touched State
**What goes wrong:** Form fields show validation errors immediately after reset
**Why it happens:** Resetting formData but forgetting touched state object
**How to avoid:** Reset both formData and touched in resetForm() - see useEntityForm pattern
**Warning signs:** Validation errors appear on pristine form after reset

### Pitfall 6: Skeleton Animation Performance
**What goes wrong:** Skeleton loader causes jank on low-end devices
**Why it happens:** Complex gradients, too many animated elements, JavaScript animations
**How to avoid:** CSS keyframes only, limit animated elements, respect prefers-reduced-motion
**Warning signs:** Animation stutters on mobile, battery drains quickly

### Pitfall 7: Modal Not Resetting on @show
**What goes wrong:** Modal opens with data from previous entity
**Why it happens:** FORM-07 requirement - forms reset on @hide but not @show, stale state visible briefly
**How to avoid:** Add @show handler that resets form state before modal animates in
**Warning signs:** User sees previous entity's data flash before new data loads

## Code Examples

Verified patterns from official sources:

### Bootstrap-Vue-Next Form Validation States
```vue
<!-- Source: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/form-input -->
<BFormInput
  v-model="formData.synopsis"
  :state="getFieldState('synopsis')"
  :aria-describedby="'synopsis-feedback'"
  @blur="touchField('synopsis')"
/>
<BFormInvalidFeedback id="synopsis-feedback">
  {{ getFieldError('synopsis') }}
</BFormInvalidFeedback>
```

### Autocomplete Keyboard Navigation
```typescript
// Source: Existing AutocompleteInput.vue (lines 310-351)
const onKeydown = (event: KeyboardEvent) => {
  switch (event.key) {
    case 'ArrowDown':
      event.preventDefault();
      highlightedIndex.value = Math.min(
        highlightedIndex.value + 1,
        props.results.length - 1
      );
      break;
    case 'ArrowUp':
      event.preventDefault();
      highlightedIndex.value = Math.max(highlightedIndex.value - 1, 0);
      break;
    case 'Enter':
      event.preventDefault();
      if (highlightedIndex.value >= 0) {
        selectItem(props.results[highlightedIndex.value]);
      }
      break;
    case 'Escape':
      showDropdown.value = false;
      break;
  }
};
```

### Draft Auto-Save with Watch
```typescript
// Source: Existing CreateEntity.vue (lines 239-245)
watch(
  () => getFormSnapshot(),
  (newData) => {
    scheduleSave(newData); // 2s debounce in useFormDraft
  },
  { deep: true }
);
```

### Entity Search API Integration
```typescript
// Source: Existing CreateEntity.vue (lines 355-369)
const handleGeneSearch = async (
  query: string,
  callback: (results: Record<string, unknown>[]) => void
) => {
  try {
    const response = await axios.get(
      `${import.meta.env.VITE_API_URL}/api/search/gene/${query}?tree=true`
    );
    callback(response.data);
  } catch (e) {
    makeToast(e as Error, 'Error', 'danger');
    callback([]);
  }
};
```

### BFormSelect with Multiple (Decided Pattern)
```vue
<!-- Source: CONTEXT.md decision - Bootstrap-Vue-Next BFormSelect with multiple -->
<BFormSelect
  v-model="formData.phenotypes"
  :options="phenotypeOptions"
  multiple
  :select-size="6"
  size="sm"
/>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Options API with data() | Composition API with reactive() | Vue 3 (2020) | Composables enable logic reuse across Review, Status forms |
| Inline validation logic | Composable-based validation | CreateEntity refactor (recent) | Centralized rules, easier testing |
| Manual localStorage | useFormDraft composable | CreateEntity implementation | Auto-save, stale draft detection, metadata tracking |
| Bootstrap-Vue | Bootstrap-Vue-Next | Project migration | Vue 3 compatibility, Bootstrap 5 features |
| Numeric ID input | AutocompleteInput search | Phase 37 requirement | Better UX, search by gene/disease name, not just ID |

**Deprecated/outdated:**
- **Options API for new forms** - Use Composition API with composables
- **TreeMultiSelect for multi-select** - User decided on BFormSelect with multiple prop
- **Entity class instances in storage** - Store full API response for rich preview data
- **Form reset only on @hide** - FORM-07 requires reset on @show to prevent stale data flash

## Open Questions

Things that couldn't be fully resolved:

1. **Entity Search API Response Format**
   - What we know: Gene search returns gene data, disease search returns ontology data
   - What's unclear: Exact response shape for unified entity search endpoint (if one exists)
   - Recommendation: Check if `/api/entity/{id}` endpoint exists, or call gene/disease search in parallel

2. **Review Form Auto-Save Scope**
   - What we know: CreateEntity auto-saves with 2s debounce
   - What's unclear: Should Review modal auto-save while open, or only in CreateEntity workflow?
   - Recommendation: Start without auto-save in Review modal (simpler), add if users request it

3. **Skeleton Placeholder Sizing**
   - What we know: Skeletons should match badge dimensions
   - What's unclear: Exact pixel dimensions for GeneBadge, DiseaseBadge at different sizes
   - Recommendation: Measure in browser DevTools, or use approximate dimensions (80-100px width)

4. **Form Reset Event Timing**
   - What we know: FORM-07 requires reset on @show, not just @hide
   - What's unclear: Should reset happen before or after data loading in modal @show?
   - Recommendation: Reset immediately on @show (clear stale state), then load fresh data

## Sources

### Primary (HIGH confidence)
- Vue 3 Composables Official Documentation: https://vuejs.org/guide/reusability/composables
- Bootstrap-Vue-Next Form Components: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/form
- Bootstrap-Vue-Next Form Input: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/form-input
- Bootstrap-Vue-Next Form Select: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/form-select
- Existing codebase patterns: CreateEntity.vue, useEntityForm.ts, useFormDraft.ts, AutocompleteInput.vue

### Secondary (MEDIUM confidence)
- [Vue 3 Composables Best Practices](https://medium.com/@ignatovich.dm/vue-3-best-practices-cb0a6e281ef4)
- [Good practices and Design Patterns for Vue Composables](https://dev.to/jacobandrewsky/good-practices-and-design-patterns-for-vue-composables-24lk)
- [Mastering Vue 3 Composables: A Comprehensive Style Guide](https://alexop.dev/posts/mastering-vue-3-composables-a-comprehensive-style-guide/)
- [Autocomplete Pattern UX Best Practices](https://uxpatterns.dev/patterns/forms/autocomplete)
- [Five Simple Steps For Better Autocomplete UX](https://smart-interface-design-patterns.com/articles/autocomplete-ux/)
- [9 UX Best Practice Design Patterns for Autocomplete Suggestions](https://baymard.com/blog/autocomplete-design)
- [Debounce sources - Algolia](https://www.algolia.com/doc/ui-libraries/autocomplete/guides/debouncing-sources)
- [Using Local Storage to keep a draft of form data](https://www.raymondcamden.com/2011/09/11/Using-Local-Storage-to-keep-a-draft-of-form-data)
- [Saving Form Data in Client-Side Storage](https://www.raymondcamden.com/2022/03/27/saving-form-data-in-client-side-storage)
- [Save for Later Feature in Forms Using LocalStorage](https://www.telerik.com/blogs/save-for-later-feature-in-forms-using-localstorage)
- [Skeleton Loader Example - How to Build a Skeleton Screen with CSS](https://www.freecodecamp.org/news/how-to-build-skeleton-screens-using-css-for-better-user-experience/)
- [CSS skeleton loading screen animation](https://dev.to/michaelburrows/css-skeleton-loading-screen-animation-gj3)
- [Implementation Principles and Best Practices of Skeleton Screen Technology](https://www.oreateai.com/blog/implementation-principles-and-best-practices-of-skeleton-screen-technology-in-frontend-development/e160a0b9a5889b8455aa84e6bcda9afc)
- [Building Skeleton Screens with CSS Custom Properties](https://css-tricks.com/building-skeleton-screens-css-custom-properties/)

### Tertiary (LOW confidence)
- None - all findings verified with codebase inspection and official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All dependencies already in package.json, versions confirmed
- Architecture: HIGH - Existing patterns in CreateEntity.vue and AutocompleteInput.vue proven in production
- Pitfalls: HIGH - Based on actual code review of Review.vue (line 1690 form reset) and common Vue 3 issues
- Code examples: HIGH - All examples extracted from existing working code or official Bootstrap-Vue-Next docs
- Autocomplete UX: MEDIUM - Research from multiple UX sources, not codebase-specific
- Skeleton animations: MEDIUM - CSS patterns from community best practices, need adaptation

**Research date:** 2026-01-26
**Valid until:** 2026-02-26 (30 days) - Stack is stable, Vue 3 and Bootstrap-Vue-Next mature
