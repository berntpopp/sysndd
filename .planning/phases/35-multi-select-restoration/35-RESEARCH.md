# Phase 35: Multi-Select Restoration - Research

**Researched:** 2026-01-26
**Domain:** Vue 3 hierarchical multi-select for phenotypes and variations
**Confidence:** HIGH

## Summary

Phase 35 restores multi-select capability for phenotypes (HPO terms) and variations (variant types) in curation forms. The current workaround uses BFormSelect in single-select mode due to vue3-treeselect v-model initialization bugs. Research confirms that PrimeVue TreeSelect in unstyled mode is the optimal replacement, matching existing codebase standards from prior phases.

**Context from User Decisions:**
- Interface approach is Claude's discretion (research Bootstrap-Vue-Next capabilities and codebase patterns)
- Chips/tags display format is LOCKED (show item name only, full hierarchy on hover)
- Search behavior is LOCKED (filter tree in place, show matches in context)
- Validation is LOCKED (minimum 1 required, errors on submit only)

**Key findings:**
1. **Standard Stack Decision Already Made:** Phase 11 research established PrimeVue TreeSelect in unstyled mode as the official replacement for vue3-treeselect (STACK.md lines 45-138)
2. **Bootstrap-Vue-Next Has No Tree Component:** BFormSelect supports `multiple` and `optgroups` but cannot display hierarchical trees with expand/collapse (verified from official docs)
3. **Hierarchical Data Pattern:** API returns tree structure with `id`, `label`, `children[]` format (lines 1361-1378 in Review.vue)
4. **Existing Chip Display:** BFormTags component already used for publications (Review.vue lines 659-713) provides removal with X button

**Primary recommendation:** Use PrimeVue TreeSelect with checkbox selection mode, chip display, and Bootstrap PT (pass-through) styling. This follows the established pattern from v7 technology stack research.

## Standard Stack

The multi-select tree component stack has already been decided in prior v7 research:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PrimeVue TreeSelect | 4.5.4+ | Hierarchical multi-select with checkboxes | ARIA compliant, unstyled mode for Bootstrap integration, 331K weekly downloads, active maintenance |
| Bootstrap-Vue-Next BFormSelect | 0.42.0 | Single-select fallback | Already in stack, native `<select>` accessibility |
| Bootstrap-Vue-Next BFormTag | 0.42.0 | Chip display for selected items | Already in stack, used for PMID tags |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Bootstrap Icons | 1.13.1 | Icons for tree expand/collapse | Already in stack |
| @vueuse/core | 14.1.0 | useDebounce for search filtering | Already in stack |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| PrimeVue TreeSelect (unstyled) | @zanmato/vue3-treeselect | vue3-treeselect has v-model init bug breaking multi-select (documented Issue #4), inconsistent maintenance |
| PrimeVue TreeSelect (unstyled) | Bootstrap-Vue-Next BFormSelect multiple | BFormSelect cannot display hierarchical trees, only flat option groups |
| PrimeVue TreeSelect (unstyled) | Custom tree component | Would require building expand/collapse, keyboard nav, ARIA - 200+ hours effort |

**Installation:**
```bash
# Already added in Phase 11 stack decision
# No new dependencies needed
npm install primevue@^4.5.4
```

**Configuration (main.ts):**
```typescript
import PrimeVue from 'primevue/config'

app.use(PrimeVue, {
  unstyled: true  // Critical: no PrimeVue CSS, use Bootstrap classes via PT
})
```

## Architecture Patterns

### Recommended Component Structure
```
src/
├── components/
│   ├── forms/
│   │   ├── TreeMultiSelect.vue      # Wrapper with Bootstrap PT styling
│   │   ├── HierarchicalChips.vue    # Chip display with tooltips
│   │   └── TreeSearchFilter.vue     # Search input with clear button
├── composables/
│   ├── useTreeSelect.ts             # Tree selection state management
│   ├── useTreeSearch.ts             # Search filtering logic
│   └── useHierarchyPath.ts          # Compute ancestor paths for tooltips
```

### Pattern 1: TreeMultiSelect Wrapper Component

**What:** Reusable wrapper around PrimeVue TreeSelect with Bootstrap styling via PT props

**When to use:** Phenotypes and variations multi-select in Review, ModifyEntity, ApproveReview forms

**Example:**
```vue
<!-- TreeMultiSelect.vue -->
<template>
  <div class="tree-multi-select">
    <!-- Search input -->
    <BFormInput
      v-model="searchQuery"
      size="sm"
      placeholder="Search..."
      class="mb-2"
      aria-label="Search items"
    >
      <template #append>
        <BButton
          v-if="searchQuery"
          size="sm"
          variant="link"
          aria-label="Clear search"
          @click="searchQuery = ''"
        >
          <i class="bi bi-x-lg" />
        </BButton>
      </template>
    </BFormInput>

    <!-- Tree select with Bootstrap PT styling -->
    <TreeSelect
      v-model="model"
      :options="filteredOptions"
      selectionMode="checkbox"
      display="chip"
      :placeholder="placeholder"
      :pt="{
        root: { class: 'form-control form-control-sm' },
        label: { class: 'form-select-label' },
        trigger: { class: 'btn btn-sm btn-outline-secondary' },
        panel: { class: 'dropdown-menu show p-2' },
        tree: { class: 'list-unstyled' },
        node: { class: 'py-1' },
        checkbox: { class: 'form-check-input' },
        nodeLabel: { class: 'ms-2' },
        nodeToggler: { class: 'btn btn-link btn-sm p-0' },
        chipContainer: { class: 'd-flex flex-wrap gap-1 mt-2' },
        chip: { class: 'badge bg-secondary' },
        chipRemoveIcon: { class: 'bi bi-x ms-1' }
      }"
      @update:modelValue="handleChange"
    />

    <!-- Selected items as chips with full path tooltips -->
    <div v-if="modelValue?.length" class="mt-2">
      <BFormTag
        v-for="item in selectedItems"
        :key="item.id"
        variant="secondary"
        class="me-1 mb-1"
        v-b-tooltip.hover
        :title="getFullPath(item)"
        @remove="removeItem(item.id)"
      >
        {{ item.label }}
      </BFormTag>
    </div>

    <!-- Validation error -->
    <div v-if="error" class="invalid-feedback d-block">
      {{ error }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import TreeSelect from 'primevue/treeselect'
import { useTreeSearch } from '@/composables/useTreeSearch'
import { useHierarchyPath } from '@/composables/useHierarchyPath'

interface TreeNode {
  id: string
  label: string
  children?: TreeNode[]
}

interface Props {
  modelValue: string[] | null
  options: TreeNode[]
  placeholder?: string
  error?: string
}

const props = defineProps<Props>()
const emit = defineEmits<{
  (e: 'update:modelValue', value: string[]): void
}>()

const searchQuery = ref('')

// Search filtering - hide non-matching branches
const { filteredOptions } = useTreeSearch(
  computed(() => props.options),
  searchQuery,
  { matchFields: ['label', 'id'] }  // Match both name and code (HP:0001250)
)

// Compute full hierarchy path for tooltips
const { getPath } = useHierarchyPath(computed(() => props.options))

const selectedItems = computed(() => {
  if (!props.modelValue?.length) return []
  return findNodesByIds(props.options, props.modelValue)
})

const getFullPath = (item: TreeNode): string => {
  return getPath(item.id).map(n => n.label).join(' > ')
}

const handleChange = (value: string[]) => {
  emit('update:modelValue', value || [])
}

const removeItem = (id: string) => {
  const updated = props.modelValue?.filter(v => v !== id) || []
  emit('update:modelValue', updated)
}

function findNodesByIds(nodes: TreeNode[], ids: string[]): TreeNode[] {
  const result: TreeNode[] = []

  const search = (nodes: TreeNode[]) => {
    for (const node of nodes) {
      if (ids.includes(node.id)) {
        result.push(node)
      }
      if (node.children) {
        search(node.children)
      }
    }
  }

  search(nodes)
  return result
}
</script>
```

**Source:** PrimeVue TreeSelect official docs - [https://primevue.org/treeselect/](https://primevue.org/treeselect/)

### Pattern 2: Form Integration with Validation

**What:** Integrate TreeMultiSelect with VeeValidate form validation

**When to use:** All curation forms requiring validation (Review, ModifyEntity, ApproveReview)

**Example:**
```vue
<template>
  <BForm @submit="handleSubmit">
    <label for="phenotype-select" class="form-label">
      Phenotypes
      <span class="text-danger">*</span>
    </label>

    <TreeMultiSelect
      id="phenotype-select"
      v-model="phenotypeIds"
      :options="phenotypeOptions"
      placeholder="Select phenotypes..."
      :error="phenotypeError"
      aria-required="true"
      aria-describedby="phenotype-help"
      :aria-invalid="!!phenotypeError"
    />

    <small id="phenotype-help" class="form-text text-muted">
      Select HPO terms that occur in 20% or more of affected individuals
    </small>

    <BButton type="submit" variant="primary">
      Submit
    </BButton>
  </BForm>
</template>

<script setup lang="ts">
import { useForm, useField } from 'vee-validate'
import { object, array, string } from 'yup'

const schema = object({
  phenotypeIds: array()
    .of(string())
    .min(1, 'At least one phenotype is required')
    .required('This field is required')
})

const { handleSubmit } = useForm({ validationSchema: schema })

const { value: phenotypeIds, errorMessage: phenotypeError } = useField<string[]>(
  'phenotypeIds',
  undefined,
  { initialValue: [] }
)
</script>
```

**Source:** VeeValidate v4 composition API - [https://vee-validate.logaretm.com/v4/guide/composition-api/](https://vee-validate.logaretm.com/v4/guide/composition-api/)

### Pattern 3: Loading State Management

**What:** Handle async loading of tree options with defensive data handling

**When to use:** All components loading phenotype/variation data from API

**Example:**
```typescript
// useTreeOptions.ts
import { ref, onMounted } from 'vue'
import axios from 'axios'

export function useTreeOptions(endpoint: string) {
  const options = ref<TreeNode[] | null>(null)  // null = not loaded, [] = loaded but empty
  const loading = ref(false)
  const error = ref<string | null>(null)

  const loadOptions = async () => {
    loading.value = true
    error.value = null

    try {
      const response = await axios.get(endpoint)

      // Defensive: handle both array and object responses
      const data = Array.isArray(response.data)
        ? response.data
        : response.data?.data || []

      options.value = data
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to load options'
      options.value = []  // Set to empty array on error
    } finally {
      loading.value = false
    }
  }

  onMounted(() => {
    loadOptions()
  })

  return {
    options,
    loading,
    error,
    reload: loadOptions
  }
}
```

**Usage:**
```vue
<template>
  <BSpinner v-if="loading" label="Loading options..." />
  <BAlert v-else-if="error" variant="warning">
    {{ error }}
  </BAlert>
  <TreeMultiSelect
    v-else-if="options && options.length > 0"
    v-model="selected"
    :options="options"
  />
  <BAlert v-else variant="info">
    No options available
  </BAlert>
</template>

<script setup lang="ts">
const { options, loading, error } = useTreeOptions('/api/list/phenotype?tree=true')
</script>
```

**Source:** Phase 34 decisions - null vs [] for loading state pattern

### Anti-Patterns to Avoid

- **Flattening tree structure:** Don't use `flattenTreeOptions()` from ModifyEntity.vue (lines 1419-1430). This loses hierarchy and defeats purpose of tree component.
- **Mixed selection modes:** Don't mix chips with select dropdown. Use ONE display pattern: chips below tree selector.
- **Inline styles in PT props:** Use Bootstrap utility classes in PT props, not inline styles. Bad: `{ style: 'margin: 10px' }`. Good: `{ class: 'm-2' }`.
- **Direct v-model on PrimeVue component:** Always wrap PrimeVue TreeSelect in custom component to isolate PT styling logic.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hierarchical tree display with checkboxes | Custom tree with recursion, expand/collapse, keyboard nav | PrimeVue TreeSelect | 200+ hours to build: ARIA roles, keyboard nav (Arrow keys, Enter, Space, Home, End), focus management, async loading, search filtering, accessibility testing |
| Search filtering tree nodes | Custom filter that hides branches | `useTreeSearch` composable | Edge cases: preserve ancestor nodes, highlight matches, deep search, debouncing, clear button state |
| Full hierarchy path tooltips | String concatenation in template | `useHierarchyPath` composable | Performance: memoization needed for large trees, path caching, recursive ancestor lookup |
| Chip display with removal | Custom badge with click handlers | Bootstrap-Vue-Next BFormTag | Already tested, accessible removal button, keyboard support, screen reader labels |

**Key insight:** Tree components have 10+ accessibility requirements (WCAG 2.1 AA) that are easy to miss. PrimeVue TreeSelect handles all of them correctly:
- `role="tree"` on container
- `role="treeitem"` on each node
- `aria-expanded` on expandable nodes
- `aria-checked` in checkbox mode
- `aria-level`, `aria-setsize`, `aria-posinset` for hierarchy
- Keyboard navigation with arrow keys
- Focus management with `aria-activedescendant`

**Source:** [ARIA Authoring Practices Guide - Tree View Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treeview/)

## Common Pitfalls

### Pitfall 1: Loading Options After Modal Show

**What goes wrong:** Modal opens, TreeMultiSelect renders with `options: null`, user sees empty dropdown. Options load 500ms later but component doesn't update.

**Why it happens:** Options loaded in `loadReviewInfo()` (Review.vue line 1508) but modal shown immediately without awaiting data load.

**How to avoid:**
1. **Load options in component `mounted()`**, not in modal open handler
2. **Use `v-if` to prevent rendering until loaded:**
   ```vue
   <TreeMultiSelect
     v-if="phenotypeOptions && phenotypeOptions.length > 0"
     v-model="selectedPhenotypes"
     :options="phenotypeOptions"
   />
   ```
3. **Show loading state in modal:**
   ```vue
   <BOverlay :show="loading_review_modal">
     <TreeMultiSelect ... />
   </BOverlay>
   ```

**Warning signs:**
- Empty dropdown that populates after 1 second
- Console warning: "options is null"
- TreeSelect component doesn't respond to clicks

**Source:** Phase 34 bug fixes - defensive checks pattern (lines 755-760 in ModifyEntity.vue)

### Pitfall 2: Forgetting to Map Selected Values

**What goes wrong:** API returns `[{phenotype_id: 'HP:0001', modifier_id: 'present'}]` but TreeMultiSelect expects `['present-HP:0001']`. Values don't map, chips show nothing.

**Why it happens:** Current codebase uses compound keys `${modifier_id}-${phenotype_id}` (Review.vue line 1530) but tree nodes use `id` field. Mismatch breaks selection.

**How to avoid:**
1. **Normalize on data load:**
   ```typescript
   const phenotypeIds = response.data.map(
     item => `${item.modifier_id}-${item.phenotype_id}`
   )
   ```
2. **Normalize on submit:**
   ```typescript
   const phenotypes = selectedIds.map(id => {
     const [modifier_id, phenotype_id] = id.split('-')
     return new Phenotype(phenotype_id, modifier_id)
   })
   ```
3. **Document mapping in code:**
   ```typescript
   // Format: "${modifier_id}-${phenotype_id}"
   // Example: "present-HP:0001250"
   // Matches API response structure for phenotypes
   ```

**Warning signs:**
- Chips are blank or show undefined
- Console error: "Cannot read property 'label' of undefined"
- Selections don't save to database

**Source:** Review.vue lines 1529-1534 - existing phenotype mapping pattern

### Pitfall 3: Not Preserving Parent Node Context in Search

**What goes wrong:** User searches "seizures", tree shows only leaf nodes matching "seizures" without parent categories. User can't tell if it's under "Neurological" or "Developmental".

**Why it happens:** Naive search filters by node label only, removing non-matching ancestors.

**How to avoid:**
1. **Keep ancestor nodes visible when child matches:**
   ```typescript
   function filterTree(nodes: TreeNode[], query: string): TreeNode[] {
     return nodes.reduce<TreeNode[]>((acc, node) => {
       const matches = node.label.toLowerCase().includes(query.toLowerCase())
       const childMatches = node.children
         ? filterTree(node.children, query)
         : []

       if (matches || childMatches.length > 0) {
         acc.push({
           ...node,
           children: childMatches.length > 0 ? childMatches : node.children
         })
       }

       return acc
     }, [])
   }
   ```
2. **Expand all matching branches automatically:**
   ```typescript
   const expandedKeys = computed(() => {
     if (!searchQuery.value) return {}
     return getExpandedKeysForMatches(options.value, searchQuery.value)
   })
   ```

**Warning signs:**
- Search results look disconnected
- User confusion: "Where does this option belong?"
- Test: Search for child term, check if parent category visible

**Source:** User decisions - "Keep ancestor nodes visible so user sees where match sits in hierarchy"

### Pitfall 4: Chip Overflow Breaking Layout

**What goes wrong:** User selects 20 phenotypes, chips overflow container, form becomes 3 screens tall, submit button scrolls off page.

**Why it happens:** No `max-height` or `overflow-y: auto` on chip container.

**How to avoid:**
1. **Let field grow per requirements:**
   ```vue
   <!-- Per user decision: "Show all chips, field grows as needed (no truncation)" -->
   <div class="chip-container">
     <BFormTag
       v-for="item in selectedItems"
       :key="item.id"
       class="me-1 mb-1"
     >
       {{ item.label }}
     </BFormTag>
   </div>
   ```
2. **Ensure submit button always visible:**
   ```vue
   <BCard>
     <div class="modal-body" style="max-height: 70vh; overflow-y: auto;">
       <TreeMultiSelect ... />
     </div>
     <div class="modal-footer">
       <BButton type="submit">Submit</BButton>
     </div>
   </BCard>
   ```

**Warning signs:**
- Submit button below fold
- Horizontal scrollbar appears
- Test: Select 30 items, check usability

**Source:** User decisions - "Show all chips, field grows as needed (no truncation)"

## Code Examples

Verified patterns from official sources:

### PrimeVue TreeSelect with Checkbox Selection
```vue
<template>
  <TreeSelect
    v-model="selectedNodes"
    :options="nodes"
    selectionMode="checkbox"
    placeholder="Select Items"
  />
</template>

<script setup lang="ts">
import { ref } from 'vue'
import TreeSelect from 'primevue/treeselect'

const selectedNodes = ref<string[] | null>(null)
const nodes = ref([
  {
    key: '0',
    label: 'Neurological abnormality',
    children: [
      { key: '0-0', label: 'Seizure', data: 'HP:0001250' },
      { key: '0-1', label: 'Intellectual disability', data: 'HP:0001249' }
    ]
  }
])
</script>
```
**Source:** [PrimeVue TreeSelect Documentation](https://primevue.org/treeselect/)

### Bootstrap-Vue-Next BFormTag for Chips
```vue
<template>
  <BFormTags
    v-model="tags"
    no-outer-focus
    class="mb-2"
  >
    <template #default="{ tags, removeTag }">
      <div class="d-flex flex-wrap gap-1">
        <BFormTag
          v-for="tag in tags"
          :key="tag"
          variant="secondary"
          @remove="removeTag(tag)"
        >
          {{ tag }}
        </BFormTag>
      </div>
    </template>
  </BFormTags>
</template>
```
**Source:** Review.vue lines 659-713 - existing PMID tags pattern

### Tree Search with Context Preservation
```typescript
// composables/useTreeSearch.ts
import { computed, Ref } from 'vue'

interface TreeNode {
  id: string
  label: string
  children?: TreeNode[]
}

export function useTreeSearch(
  options: Ref<TreeNode[]>,
  query: Ref<string>,
  config: { matchFields: string[] }
) {
  const filteredOptions = computed(() => {
    if (!query.value) return options.value

    const lowerQuery = query.value.toLowerCase()

    function filterNode(node: TreeNode): TreeNode | null {
      // Check if node matches
      const nodeMatches = config.matchFields.some(field => {
        const value = node[field as keyof TreeNode]
        return typeof value === 'string' && value.toLowerCase().includes(lowerQuery)
      })

      // Recursively filter children
      const filteredChildren = node.children
        ?.map(filterNode)
        .filter((n): n is TreeNode => n !== null)

      // Include node if it matches OR if any children match
      if (nodeMatches || (filteredChildren && filteredChildren.length > 0)) {
        return {
          ...node,
          children: filteredChildren
        }
      }

      return null
    }

    return options.value
      .map(filterNode)
      .filter((n): n is TreeNode => n !== null)
  })

  return { filteredOptions }
}
```

### Full Hierarchy Path for Tooltips
```typescript
// composables/useHierarchyPath.ts
import { computed, Ref } from 'vue'

interface TreeNode {
  id: string
  label: string
  children?: TreeNode[]
}

export function useHierarchyPath(options: Ref<TreeNode[]>) {
  const pathCache = new Map<string, TreeNode[]>()

  // Build path cache on options change
  const buildCache = () => {
    pathCache.clear()

    function traverse(nodes: TreeNode[], ancestors: TreeNode[] = []) {
      for (const node of nodes) {
        const path = [...ancestors, node]
        pathCache.set(node.id, path)

        if (node.children) {
          traverse(node.children, path)
        }
      }
    }

    traverse(options.value)
  }

  const getPath = (nodeId: string): TreeNode[] => {
    if (pathCache.size === 0) buildCache()
    return pathCache.get(nodeId) || []
  }

  const getPathString = (nodeId: string): string => {
    return getPath(nodeId).map(n => n.label).join(' > ')
  }

  return { getPath, getPathString }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| vue3-treeselect with multiple | PrimeVue TreeSelect with checkbox mode | Phase 11 (Jan 2026) | Fixes v-model init bug, ARIA compliant, unstyled mode for Bootstrap |
| BFormSelect single mode workaround | TreeMultiSelect wrapper component | Phase 35 (this phase) | Restores multi-select functionality, consistent UX |
| Flat optgroups in BFormSelect | Hierarchical tree with expand/collapse | Phase 35 (this phase) | Better UX for large ontologies (HPO has 16,000+ terms) |
| Manual chip rendering | BFormTag component | Already done | Consistent with PMID tags pattern |

**Deprecated/outdated:**
- **@zanmato/vue3-treeselect 0.4.2:** Multi-select v-model initialization bug, community fork maintenance uncertain
- **Flattening tree to optgroups:** Loses hierarchy, poor UX for deep trees (HPO has 5+ levels)
- **Custom tree components without ARIA:** Fails accessibility audits, blocks screen reader users

## Open Questions

Things that couldn't be fully resolved:

1. **PrimeVue TreeSelect Performance with 16,000+ HPO Terms**
   - What we know: PrimeVue supports lazy loading via `loading` prop
   - What's unclear: Whether initial render of full HPO tree (16K nodes) causes lag
   - Recommendation: Start with full tree load (API already returns tree), add lazy loading if performance issues detected in Phase 35 testing

2. **Tooltip Positioning for Chips at Bottom of Modal**
   - What we know: Bootstrap tooltips can overflow modal bounds
   - What's unclear: Whether `boundary: 'window'` fixes this reliably
   - Recommendation: Test with 20+ selected items, adjust tooltip boundary if needed

3. **Search Highlighting Match Text**
   - What we know: User expects visual highlight of matched text (e.g., "Sei**zur**es")
   - What's unclear: Whether PrimeVue TreeSelect supports this natively or needs custom template
   - Recommendation: Use PrimeVue's `nodeTemplate` slot if highlight needed, otherwise accept non-highlighted search

## Sources

### Primary (HIGH confidence)
- [PrimeVue TreeSelect Component](https://primevue.org/treeselect/) - Official documentation
- [PrimeVue Pass Through](https://primevue.org/passthrough/) - Unstyled mode styling
- [Bootstrap-Vue-Next BFormSelect](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/form-select) - Native select capabilities
- [Bootstrap-Vue-Next BFormTag](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/form-tags) - Chip display
- SysNDD Codebase (HIGH confidence):
  - `/app/src/views/review/Review.vue` - Current workaround implementation
  - `/app/src/views/curate/ModifyEntity.vue` - Multi-select usage patterns
  - `/app/src/views/curate/ApproveReview.vue` - Form validation patterns
  - `.planning/research/STACK.md` - v7 technology decisions
  - `.planning/research/PITFALLS-curation-workflow.md` - Known issues

### Secondary (MEDIUM confidence)
- [ARIA Authoring Practices - Tree View](https://www.w3.org/WAI/ARIA/apg/patterns/treeview/) - Accessibility requirements
- [MDBootstrap Multiselect](https://mdbootstrap.com/docs/standard/extended/multiselect/) - UI patterns reference
- [Telerik MultiSelectTree Guidelines](https://www.telerik.com/design-system/docs/components/multiselecttree/usage/) - Best practices for hierarchical multi-select
- [HPO Browser Internationalization](https://academic.oup.com/nar/article/49/D1/D1207/6017351) - HPO interface design decisions

### Tertiary (LOW confidence)
- WebSearch results on "Bootstrap 5 hierarchical multi-select" - General patterns, not specific to Vue 3
- WebSearch results on "Vue 3 multi-select hierarchical tree chips" - Library comparisons

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - PrimeVue TreeSelect decision made in Phase 11, documented in STACK.md
- Architecture: HIGH - Patterns verified from PrimeVue docs and existing codebase (BFormTag usage)
- Pitfalls: HIGH - Derived from Phase 34 bug fixes and codebase analysis (10+ TODO comments documenting vue3-treeselect issues)

**Research date:** 2026-01-26
**Valid until:** 60 days (PrimeVue stable, Bootstrap-Vue-Next stable)

**Key constraints from CONTEXT.md:**
- Chips/tags display format: LOCKED (show item name, full path on hover)
- Search behavior: LOCKED (filter in place, show matches in context)
- Validation: LOCKED (minimum 1 required, errors on submit only)
- Interface pattern: RESEARCHED (PrimeVue TreeSelect wrapper with Bootstrap PT styling)
