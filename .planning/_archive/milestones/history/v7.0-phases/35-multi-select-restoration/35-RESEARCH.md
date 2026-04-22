# Phase 35: Multi-Select Restoration - Research

**Researched:** 2026-01-26 (Updated)
**Domain:** Bootstrap-Vue-Next hierarchical multi-select UI patterns
**Confidence:** HIGH

## Summary

**USER REQUIREMENT:** Implement hierarchical multi-select using ONLY Bootstrap-Vue-Next components. User explicitly rejected PrimeVue and external tree libraries, requiring native Bootstrap-Vue-Next patterns only.

Research focused on implementing hierarchical multi-select for HPO phenotypes and variant types using ONLY Bootstrap-Vue-Next components (version 0.42.0 in codebase).

**Current State:** The codebase currently uses `@zanmato/vue3-treeselect` which is commented out pending Bootstrap-Vue-Next migration. It's been temporarily replaced with single-select `BFormSelect` dropdowns. Three views need restoration: Review.vue, ModifyEntity.vue, and ApproveReview.vue. The API returns hierarchical tree data with `{id, label, children[]}` structure.

**Critical Finding:** Bootstrap-Vue-Next does NOT provide a built-in tree select or hierarchical checkbox component. The framework includes only standard form components (BFormCheckbox, BFormSelect, BFormTags), layout components (BCollapse, BListGroup), and dropdowns (BDropdown). **A custom component must be built.**

**Key findings:**
1. **No Tree Component:** Bootstrap-Vue-Next has no tree component - must combine primitives
2. **Proven Pattern Exists:** BFormTags already used successfully for PMID publications in Review.vue (lines 659-712)
3. **Component Building Blocks Available:** BFormTags (chips), BDropdown (selector), BCollapse (hierarchy), BFormCheckbox (multi-select)
4. **Hierarchical Data Ready:** API returns tree structure with `id`, `label`, `children[]` format (lines 1361-1378 in Review.vue)

**Primary recommendation:** Build custom TreeMultiSelect component combining BFormTags (for chip display) + BDropdown (for selection interface with `auto-close="false"`) + recursive TreeNode component using BCollapse (for hierarchy) + BFormCheckbox (for selections). This matches the existing BFormTags pattern and uses only Bootstrap-Vue-Next components.

## Standard Stack

### Core (Bootstrap-Vue-Next 0.42.0 - Already Installed)

All components are already registered in the codebase via `/app/src/bootstrap-vue-next-components.js`:

| Component | Purpose | Why Standard |
|-----------|---------|--------------|
| BFormTags + BFormTag | Display selected items as removable chips | Already used for PMID tags in Review.vue lines 659-712, proven pattern |
| BDropdown + BDropdownItemButton | Selection interface container | Supports `auto-close="false"` for multi-select, keyboard navigation, ARIA compliant |
| BCollapse | Expandable hierarchy sections | Native Bootstrap 5 animation, ARIA support, v-model reactive, lazy loading |
| BFormCheckbox | Individual item selection | Multi-select via v-model array binding, accessible, indeterminate state support |
| BFormInput | Search/filter input | Built-in `debounce` prop (line 1362 in Review.vue uses 300ms), accessible |
| BButton | Collapse toggles, action buttons | v-b-toggle directive for BCollapse integration |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Bootstrap Icons | 1.13.1 | Chevron icons for expand/collapse | Already in stack, used throughout codebase |
| Vue 3 | 3.5.25 | Recursive components, computed properties | Already in stack |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| BFormTags + BDropdown custom | PrimeVue TreeSelect | **User explicitly rejected** - wants Bootstrap-Vue-Next only |
| Custom recursive component | @zanmato/vue3-treeselect | Has v-model init bug (documented Issue #4), commented out in codebase |
| BCollapse hierarchy | BFormCheckboxGroup (flat) | Loses hierarchy display, doesn't meet requirements |
| BCollapse hierarchy | Nested BListGroup | Less clear parent/child relationship, no animation |

**Installation:**
```bash
# No new dependencies needed
# All components available in existing bootstrap-vue-next@0.42.0
```

## Architecture Patterns

### Recommended Component Structure
```
src/components/forms/
├── TreeMultiSelect.vue           # Main wrapper component
│   ├── BFormTags (chip display)
│   └── BDropdown (tree selector)
│       ├── BFormInput (search)
│       └── TreeNode.vue (recursive)
│           ├── BButton (parent toggle)
│           ├── BCollapse (children wrapper)
│           └── BFormCheckbox (leaf selection)
```

### Pattern 1: TreeMultiSelect Wrapper Component

**What:** Reusable component wrapping BFormTags + BDropdown with tree inside
**When to use:** Phenotypes and variations multi-select in Review, ModifyEntity, ApproveReview
**Matches:** Existing PMID tags pattern in Review.vue (lines 659-712)

**Example:**
```vue
<!-- TreeMultiSelect.vue -->
<template>
  <div class="tree-multi-select">
    <!-- Selected items as chips (matches PMID pattern) -->
    <div v-if="modelValue?.length" class="mb-2">
      <BFormTag
        v-for="id in modelValue"
        :key="id"
        variant="secondary"
        class="me-1 mb-1"
        v-b-tooltip.hover
        :title="getFullPath(id)"
        @remove="removeSelection(id)"
      >
        {{ getLabel(id) }}
      </BFormTag>
    </div>

    <!-- Dropdown selector -->
    <BDropdown
      v-model="dropdownOpen"
      :auto-close="false"
      variant="outline-secondary"
      size="sm"
      block
      text="Select items"
    >
      <!-- Search input -->
      <BDropdownForm @submit.prevent>
        <BFormInput
          v-model="searchQuery"
          placeholder="Search by name or code..."
          size="sm"
          debounce="300"
        />
      </BDropdownForm>
      <BDropdownDivider />

      <!-- Scrollable tree area -->
      <div style="max-height: 300px; overflow-y: auto;">
        <TreeNode
          v-for="node in filteredTree"
          :key="node.id"
          :node="node"
          :selected="modelValue || []"
          @toggle="toggleSelection"
        />
      </div>

      <BDropdownDivider />

      <!-- Actions -->
      <BDropdownItemButton @click="clearAll" variant="link">
        Clear All
      </BDropdownItemButton>
      <BDropdownItemButton @click="dropdownOpen = false" variant="primary">
        Done ({{ modelValue?.length || 0 }} selected)
      </BDropdownItemButton>
    </BDropdown>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import TreeNode from './TreeNode.vue'

interface TreeNode {
  id: string
  label: string
  children?: TreeNode[]
}

interface Props {
  modelValue: string[] | null
  options: TreeNode[]
  placeholder?: string
}

const props = defineProps<Props>()
const emit = defineEmits<{
  (e: 'update:modelValue', value: string[]): void
}>()

const dropdownOpen = ref(false)
const searchQuery = ref('')

const filteredTree = computed(() => {
  if (!searchQuery.value) return props.options
  return filterTreeWithContext(props.options, searchQuery.value)
})

function filterTreeWithContext(nodes: TreeNode[], query: string): TreeNode[] {
  const lowerQuery = query.toLowerCase()

  return nodes.reduce((acc, node) => {
    const nodeMatches =
      node.label.toLowerCase().includes(lowerQuery) ||
      node.id.toLowerCase().includes(lowerQuery)

    const filteredChildren = node.children
      ? filterTreeWithContext(node.children, query)
      : []

    if (nodeMatches || filteredChildren.length > 0) {
      acc.push({
        ...node,
        children: filteredChildren.length > 0 ? filteredChildren : node.children
      })
    }

    return acc
  }, [] as TreeNode[])
}

function getLabel(id: string): string {
  const node = findNodeById(props.options, id)
  return node?.label || id
}

function getFullPath(id: string): string {
  const path = getNodePath(props.options, id)
  return path.map(n => n.label).join(' > ')
}

function findNodeById(nodes: TreeNode[], id: string): TreeNode | null {
  for (const node of nodes) {
    if (node.id === id) return node
    if (node.children) {
      const found = findNodeById(node.children, id)
      if (found) return found
    }
  }
  return null
}

function getNodePath(nodes: TreeNode[], id: string, path: TreeNode[] = []): TreeNode[] {
  for (const node of nodes) {
    if (node.id === id) return [...path, node]
    if (node.children) {
      const found = getNodePath(node.children, id, [...path, node])
      if (found.length > 0) return found
    }
  }
  return []
}

function toggleSelection(id: string) {
  const current = props.modelValue || []
  const updated = current.includes(id)
    ? current.filter(v => v !== id)
    : [...current, id]
  emit('update:modelValue', updated)
}

function removeSelection(id: string) {
  const updated = (props.modelValue || []).filter(v => v !== id)
  emit('update:modelValue', updated)
}

function clearAll() {
  emit('update:modelValue', [])
}
</script>
```

**Source:** Bootstrap-Vue-Next components documentation + existing PMID pattern

### Pattern 2: Recursive TreeNode Component

**What:** Self-referencing component for hierarchical display with BCollapse
**When to use:** Unknown depth of nesting, parent/child relationships
**Critical:** Must register self via `name` property for recursion

```vue
<!-- TreeNode.vue -->
<template>
  <div class="tree-node">
    <!-- Parent node with collapse (navigation only per user requirements) -->
    <div v-if="hasChildren" class="parent-node">
      <BButton
        v-b-toggle="`collapse-${node.id}`"
        variant="link"
        size="sm"
        class="text-start w-100 d-flex align-items-center px-2 py-1"
      >
        <i class="bi bi-chevron-right me-2 collapse-icon"></i>
        <span class="flex-grow-1">{{ node.label }}</span>
        <span class="badge bg-secondary">{{ node.children.length }}</span>
      </BButton>

      <BCollapse
        :id="`collapse-${node.id}`"
        :lazy="true"
        class="ms-3"
      >
        <TreeNode
          v-for="child in node.children"
          :key="child.id"
          :node="child"
          :selected="selected"
          @toggle="$emit('toggle', $event)"
        />
      </BCollapse>
    </div>

    <!-- Leaf node with checkbox (selectable per user requirements) -->
    <div v-else class="leaf-node ps-4 py-1">
      <BFormCheckbox
        :model-value="selected.includes(node.id)"
        @update:model-value="$emit('toggle', node.id)"
        :id="`checkbox-${node.id}`"
      >
        <span>{{ node.label }}</span>
        <small class="text-muted ms-2">{{ node.id }}</small>
      </BFormCheckbox>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, type PropType } from 'vue'

interface TreeNode {
  id: string
  label: string
  children?: TreeNode[]
}

export default defineComponent({
  name: 'TreeNode', // Critical: enables self-reference
  props: {
    node: {
      type: Object as PropType<TreeNode>,
      required: true
    },
    selected: {
      type: Array as PropType<string[]>,
      default: () => []
    }
  },
  emits: ['toggle'],
  computed: {
    hasChildren() {
      return this.node.children && this.node.children.length > 0
    }
  }
})
</script>

<style scoped>
/* Rotate chevron when expanded */
.collapse-icon {
  transition: transform 0.2s ease;
}
.not-collapsed .collapse-icon {
  transform: rotate(90deg);
}
</style>
```

**Source:** Vue 3 component patterns + Bootstrap-Vue-Next BCollapse documentation

### Pattern 3: Form Integration with Validation

**What:** Integrate TreeMultiSelect with existing form validation
**When to use:** All curation forms (Review, ModifyEntity, ApproveReview)

```vue
<template>
  <BForm @submit="handleSubmit">
    <label for="phenotype-select" class="form-label">
      Phenotypes
      <span class="text-danger">*</span>
    </label>

    <BBadge
      id="popover-badge-help-phenotypes"
      pill
      href="#"
      variant="info"
    >
      <i class="bi bi-question-circle-fill" />
    </BBadge>

    <BPopover
      target="popover-badge-help-phenotypes"
      variant="info"
      triggers="focus"
    >
      <template #title>Phenotypes instructions</template>
      Add or remove associated phenotypes. Only phenotypes that occur in
      20% or more of affected individuals should be included.
    </BPopover>

    <TreeMultiSelect
      id="phenotype-select"
      v-model="select_phenotype"
      :options="phenotypes_options"
      placeholder="Select phenotypes..."
    />

    <div v-if="validationError" class="invalid-feedback d-block">
      {{ validationError }}
    </div>

    <BButton type="submit" variant="primary">
      Submit
    </BButton>
  </BForm>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

const select_phenotype = ref<string[]>([])
const phenotypes_options = ref([])

const validationError = computed(() => {
  // Validation on submit only per user requirements
  return submitted.value && select_phenotype.value.length === 0
    ? 'This field is required'
    : null
})
</script>
```

**Source:** Existing pattern in Review.vue lines 514-565

### Anti-Patterns to Avoid

- **Using BFormSelect with multiple:** Cannot display hierarchical trees, only flat option groups
- **Not setting `auto-close="false"` on BDropdown:** Dropdown closes on first checkbox click, breaking multi-select UX
- **Forgetting `name` property on TreeNode:** Component cannot self-reference without explicit name
- **Flattening tree with `flattenTreeOptions()`:** Loses hierarchy context that requirements mandate
- **Missing `:key="node.id"` on recursive components:** Vue reconciliation breaks, causes render bugs
- **Not using `lazy` prop on BCollapse:** Performance degrades with large trees (HPO has 1000+ terms)

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tag input with validation | Custom input + chip rendering | BFormTags with scoped slot | Built-in duplicate detection, removal handlers, validation pipeline, accessible, already used in codebase |
| Collapsible sections | Custom show/hide with CSS transitions | BCollapse with v-b-toggle | ARIA attributes (aria-expanded, aria-controls), animation management, keyboard support (Enter, Space), focus management, lazy loading |
| Dropdown menus with forms | Custom positioned div | BDropdown with auto-close prop | Positioning (Popper.js integration), focus trap, keyboard nav (Arrow keys, Esc, Tab), click-outside handling, ARIA menus |
| Checkbox groups | Manual array manipulation | BFormCheckbox with array v-model | Array binding, indeterminate states, name grouping for keyboard nav, accessible labels |
| Input debouncing | Custom setTimeout logic | BFormInput debounce prop | Built-in, cleanup on unmount, no memory leaks |
| Tree filtering | Manual recursion | Computed property with reduce pattern | Performance memoization, context preservation logic tested |

**Key insight:** Bootstrap-Vue-Next components handle accessibility (ARIA, keyboard nav, focus management) that's easy to miss in custom implementations. WCAG 2.1 AA compliance requires:
- `aria-expanded` on collapsible triggers (BCollapse handles this)
- `aria-controls` linking trigger to target (v-b-toggle handles this)
- Keyboard navigation (Arrow, Enter, Space, Esc) (BDropdown handles this)
- Focus management when opening/closing (BDropdown handles this)
- Screen reader announcements on state changes (Bootstrap components handle this)

Building these from scratch = 40+ hours of accessibility work.

## Common Pitfalls

### Pitfall 1: BDropdown Closes on Checkbox Click

**What goes wrong:** Dropdown closes immediately when clicking checkboxes, user can only select one item before dropdown disappears

**Why it happens:** Default `auto-close` behavior is `true` (closes on any inside click)

**How to avoid:** Set `:auto-close="false"` on BDropdown, provide explicit "Done" button to close

**Warning signs:**
- Multi-select feels broken
- Can only select one item per dropdown open
- User frustration trying to select multiple items

```vue
<!-- BAD: Closes on every click -->
<BDropdown>
  <BFormCheckbox v-for="item in items" />
</BDropdown>

<!-- GOOD: Stays open until Done clicked -->
<BDropdown v-model="isOpen" :auto-close="false">
  <BFormCheckbox v-for="item in items" />
  <BDropdownDivider />
  <BDropdownItemButton @click="isOpen = false">
    Done
  </BDropdownItemButton>
</BDropdown>
```

**Source:** Bootstrap-Vue-Next BDropdown documentation - auto-close prop

### Pitfall 2: BFormTags v-model Type Mismatch

**What goes wrong:** BFormTags expects array of strings, but selections are objects with `{id, label, children}`, chips display "[object Object]"

**Why it happens:** The API returns nested objects, v-model binding tries to display objects as strings

**How to avoid:**
- Store only IDs in the v-model array: `selectedIds: string[]`
- Create lookup functions: `getLabel(id)` and `getFullPath(id)`
- Keep original tree data separate from selections

**Warning signs:**
- Chips show "[object Object]"
- Console error: "Cannot convert object to primitive value"
- Chips are blank

```vue
<!-- BAD: Will show "[object Object]" -->
<BFormTags v-model="selectedObjects" />

<!-- GOOD: Shows labels via lookup in scoped slot -->
<BFormTags v-model="selectedIds" no-outer-focus>
  <template #default="{ tags, removeTag }">
    <BFormTag
      v-for="id in tags"
      :key="id"
      @remove="removeTag(id)"
    >
      {{ getLabel(id) }}
    </BFormTag>
  </template>
</BFormTags>
```

**Source:** Review.vue lines 659-712 existing pattern, BFormTags documentation

### Pitfall 3: Recursive Component Without Proper Registration

**What goes wrong:** `TreeNode` component references itself recursively, but Vue can't find it, console error "Failed to resolve component: TreeNode"

**Why it happens:** Component must be explicitly registered with `name` property before it can reference itself

**How to avoid:** Use `export default defineComponent({ name: 'TreeNode' })` pattern, NOT `<script setup>` without name

**Warning signs:**
- Console error: "Failed to resolve component: TreeNode"
- Tree only renders first level, no children
- Template fails to compile

```vue
<!-- BAD: Self-reference without name -->
<script setup>
// No name defined - Vue doesn't know TreeNode refers to self
</script>

<!-- GOOD: Named for self-reference -->
<script lang="ts">
import { defineComponent } from 'vue'

export default defineComponent({
  name: 'TreeNode', // Critical: enables <TreeNode> tag to reference self
  props: { /* ... */ },
  // ...
})
</script>
```

**Source:** Vue 3 component registration docs, recursive component pattern

### Pitfall 4: Missing Context in Search Results

**What goes wrong:** User searches "seizures", tree shows only leaf nodes matching "seizures" without parent categories, unclear if it's under "Neurological" or "Developmental"

**Why it happens:** Naive search filters by node label only, removing non-matching ancestors

**How to avoid:** Keep ancestor nodes visible when child matches, expand matched branches automatically

**Warning signs:**
- Search results look disconnected, no hierarchy visible
- User confusion: "Where does this option belong?"
- Test: Search for child term, parent category should still show

```javascript
// BAD: Only returns matching nodes
function filterTree(nodes, query) {
  return nodes.filter(node =>
    node.label.includes(query)
  )
}

// GOOD: Returns matches WITH ancestors for context
function filterTreeWithContext(nodes, query) {
  const lowerQuery = query.toLowerCase()

  return nodes.reduce((acc, node) => {
    const nodeMatches =
      node.label.toLowerCase().includes(lowerQuery) ||
      node.id.toLowerCase().includes(lowerQuery)

    const filteredChildren = node.children
      ? filterTreeWithContext(node.children, query)
      : []

    // Include node if IT matches OR children match
    if (nodeMatches || filteredChildren.length > 0) {
      acc.push({
        ...node,
        children: filteredChildren.length > 0 ? filteredChildren : node.children
      })
    }

    return acc
  }, [])
}
```

**Source:** User requirements - "Keep ancestor nodes visible so user sees where match sits in hierarchy"

### Pitfall 5: Performance with Large Trees

**What goes wrong:** Rendering 1000+ HPO terms causes slow initial load, laggy search, UI freezes when opening dropdown

**Why it happens:** Rendering all nodes at once, no virtualization, reactive overhead on deep trees

**How to avoid:**
- Use BCollapse `lazy` prop (defers rendering until expanded)
- Implement search debouncing (BFormInput `debounce="300"`)
- Consider `v-show` instead of `v-if` for frequently toggled nodes
- Limit initial tree depth (show top 2 levels, expand on demand)

**Warning signs:**
- UI freezes when opening dropdown
- Search feels laggy despite debounce
- Browser console warning: "Long task detected"
- Test with full HPO tree (16,000+ terms)

```vue
<!-- BAD: Renders all nodes immediately -->
<BCollapse :id="collapseId">
  <TreeNode v-for="child in node.children" />
</BCollapse>

<!-- GOOD: Defers render until expanded -->
<BCollapse :id="collapseId" :lazy="true">
  <TreeNode v-for="child in node.children" />
</BCollapse>
```

**Source:** Bootstrap-Vue-Next BCollapse documentation - lazy prop

## Code Examples

Verified patterns from official sources and codebase:

### BFormTags with Custom Chips (Existing Pattern from Codebase)
```vue
<!-- Source: /app/src/views/review/Review.vue lines 659-712 -->
<!-- This pattern already works for PMID tags -->
<BFormTags
  v-model="select_additional_references"
  input-id="review-literature-select"
  no-outer-focus
  class="my-0"
  separator=",;"
  :tag-validator="tagValidatorPMID"
  remove-on-delete
>
  <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
    <BInputGroup class="my-0">
      <BFormInput
        v-bind="inputAttrs"
        placeholder="Enter PMIDs separated by comma or semicolon"
        class="form-control"
        size="sm"
        v-on="inputHandlers"
      />
      <BButton
        variant="secondary"
        size="sm"
        @click="addTag()"
      >
        Add
      </BButton>
    </BInputGroup>

    <div class="d-inline-block">
      <h6>
        <BFormTag
          v-for="tag in tags"
          :key="tag"
          :title="tag"
          variant="secondary"
          @remove="removeTag(tag)"
        >
          <BLink
            :href="'https://pubmed.ncbi.nlm.nih.gov/' + tag.replace('PMID:', '')"
            target="_blank"
            class="text-light"
          >
            <i class="bi bi-box-arrow-up-right" />
            {{ tag }}
          </BLink>
        </BFormTag>
      </h6>
    </div>
  </template>
</BFormTags>
```

### BDropdown with Search and Multi-Select (Bootstrap-Vue-Next Pattern)
```vue
<!-- Source: Bootstrap-Vue-Next BDropdown documentation -->
<BDropdown
  v-model="dropdownOpen"
  :auto-close="false"
  variant="outline-secondary"
  size="sm"
  text="Select Phenotypes"
  block
>
  <!-- Search input stays at top -->
  <BDropdownForm @submit.prevent>
    <BFormInput
      v-model="searchQuery"
      placeholder="Search HPO terms..."
      size="sm"
      debounce="300"
    />
    <small v-if="searchQuery" class="text-muted d-block px-3">
      {{ filteredCount }} results
    </small>
  </BDropdownForm>

  <BDropdownDivider />

  <!-- Scrollable content area -->
  <div style="max-height: 300px; overflow-y: auto;">
    <TreeNode
      v-for="node in filteredTree"
      :key="node.id"
      :node="node"
      :selected="selectedPhenotypes"
      @toggle="toggleSelection"
    />
  </div>

  <BDropdownDivider />

  <!-- Action buttons -->
  <BDropdownItemButton @click="clearAll" variant="link" class="text-start">
    <i class="bi bi-x-circle me-2"></i>
    Clear All
  </BDropdownItemButton>
  <BDropdownItemButton @click="dropdownOpen = false" variant="primary">
    Done ({{ selectedPhenotypes.length }} selected)
  </BDropdownItemButton>
</BDropdown>
```

### BCollapse for Hierarchy with Bootstrap Icons
```vue
<!-- Source: Bootstrap-Vue-Next BCollapse documentation + codebase Bootstrap Icons -->
<template>
  <div class="tree-node">
    <!-- Parent with children (navigation only per user requirements) -->
    <div v-if="hasChildren" class="parent-node">
      <BButton
        v-b-toggle="`collapse-${node.id}`"
        variant="link"
        size="sm"
        class="text-start w-100 d-flex align-items-center px-2 py-1"
      >
        <i class="bi bi-chevron-right me-2 collapse-icon"></i>
        <span class="flex-grow-1">{{ node.label }}</span>
        <span class="badge bg-secondary">{{ node.children.length }}</span>
      </BButton>

      <BCollapse
        :id="`collapse-${node.id}`"
        :lazy="true"
        class="ms-3"
      >
        <TreeNode
          v-for="child in node.children"
          :key="child.id"
          :node="child"
          :selected="selected"
          @toggle="$emit('toggle', $event)"
        />
      </BCollapse>
    </div>

    <!-- Leaf node with checkbox (selectable per user requirements) -->
    <div v-else class="leaf-node ps-4 py-1">
      <BFormCheckbox
        :model-value="selected.includes(node.id)"
        @update:model-value="$emit('toggle', node.id)"
        :id="`checkbox-${node.id}`"
      >
        <span>{{ node.label }}</span>
        <small class="text-muted ms-2">{{ node.id }}</small>
      </BFormCheckbox>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, type PropType } from 'vue'

interface TreeNode {
  id: string
  label: string
  children?: TreeNode[]
}

export default defineComponent({
  name: 'TreeNode', // Critical: enables self-reference
  props: {
    node: {
      type: Object as PropType<TreeNode>,
      required: true
    },
    selected: {
      type: Array as PropType<string[]>,
      default: () => []
    }
  },
  emits: ['toggle'],
  computed: {
    hasChildren() {
      return this.node.children && this.node.children.length > 0
    }
  }
})
</script>

<style scoped>
/* Rotate chevron when expanded */
.collapse-icon {
  transition: transform 0.2s ease;
}
.not-collapsed .collapse-icon {
  transform: rotate(90deg);
}
</style>
```

### Data Integration with Existing API
```javascript
// Source: /app/src/views/review/Review.vue lines 1361-1378, 1523-1534
// API returns tree structure with {id, label, children[]}

async loadPhenotypesList() {
  const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/phenotype?tree=true`;
  try {
    const response = await this.axios.get(apiUrl);
    this.phenotypes_options = response.data; // Already tree structure
  } catch (e) {
    this.makeToast(e, 'Error', 'danger');
  }
}

// Loading existing selections (currently uses modifier-id compound keys)
async loadReviewInfo(review_id) {
  const apiGetPhenotypesURL = `${import.meta.env.VITE_API_URL}/api/review/${review_id}/phenotypes`;

  const response = await this.axios.get(apiGetPhenotypesURL);

  // Current format: [{phenotype_id: "HP:0001250", modifier_id: "present"}]
  // Extract IDs for multi-select (may need modifier handling)
  this.select_phenotype = response.data.map(
    item => `${item.modifier_id}-${item.phenotype_id}`
  );
}

// Saving selections
submitReviewChange() {
  // Convert selected IDs back to Phenotype objects
  const replace_phenotype = this.select_phenotype.map(
    item => new Phenotype(
      item.split('-')[1], // phenotype_id
      item.split('-')[0]  // modifier_id
    )
  );

  this.review_info.phenotypes = replace_phenotype;
  // Submit to API...
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| @zanmato/vue3-treeselect | Single-select BFormSelect workaround | Phase 11 (Bootstrap-Vue-Next migration) | Treeselect incompatible, temporarily lost multi-select |
| Multiple select dropdowns | Custom TreeMultiSelect component | Phase 35 (this phase) | Restores multi-select with Bootstrap-Vue-Next only |
| Flat optgroups | Hierarchical tree with BCollapse | Phase 35 (this phase) | Better UX for HPO (1000+ terms with 5+ levels) |
| Bootstrap-Vue (Vue 2) | Bootstrap-Vue-Next (Vue 3) | Phase 11 | Component API changes, patterns updated |

**Deprecated/outdated:**
- **@zanmato/vue3-treeselect 0.4.2:** Has v-model init bug, commented out in codebase (lines 542-552 in Review.vue)
- **Flattening tree to flat list:** Current workaround uses `flattenTreeOptions()` (line 1419 Review.vue), loses hierarchy
- **BFormSelect with optgroups:** Cannot show hierarchical trees, only 1-level grouping
- **PrimeVue components:** User explicitly rejected, wants Bootstrap-Vue-Next only

**Current state (2026):**
- Bootstrap-Vue-Next v0.42.0 is actively maintained, stable
- No official tree select component exists or is planned for Bootstrap-Vue-Next
- Community consensus: Build custom components using BCollapse + BFormCheckbox primitives
- This matches Bootstrap 5 philosophy: provide primitives, not complex widgets

## Open Questions

1. **Modifier Handling for Phenotypes**
   - What we know: Current code stores `modifier_id-phenotype_id` compound keys (line 1530 in Review.vue)
   - What's unclear: What are valid modifiers? How should UI expose them? (present/absent/severity?)
   - Recommendation: Start with simple ID selection (no modifier UI), preserve existing modifier logic in data layer, add modifier UI in follow-up if needed

2. **Parent Node Selection Behavior**
   - What we know: User specified "Parent selection is for navigation only — must explicitly select individual children"
   - What's unclear: Should parent nodes show disabled checkboxes or no checkboxes at all?
   - Recommendation: Show parent nodes as BButton toggles only (no checkbox), only leaf nodes get BFormCheckbox

3. **Performance with Full HPO Tree**
   - What we know: HPO has 16,000+ terms with 5+ levels of nesting
   - What's unclear: Whether rendering full tree causes performance issues, or if lazy loading required
   - Recommendation: Start with full tree load (API already returns tree), use BCollapse `lazy` prop, add virtual scrolling only if testing shows issues

4. **Keyboard Navigation Depth**
   - What we know: BDropdown supports arrow key navigation between items
   - What's unclear: How should Tab/Arrow keys work with collapsed/expanded nodes and checkboxes?
   - Recommendation: Use default browser behavior (Tab moves between focusable elements), Space/Enter toggle checkboxes, collapse/expand handled by v-b-toggle directive

## Sources

### Primary (HIGH confidence)
- [Bootstrap-Vue-Next Components Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components) - Official component reference
- [Bootstrap-Vue-Next BCollapse](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/collapse) - Collapsible sections API, lazy prop
- [Bootstrap-Vue-Next BFormCheckbox](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/form-checkbox) - Checkbox array binding, indeterminate state
- [Bootstrap-Vue-Next BFormTags](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/form-tags) - Tag input with scoped slot pattern
- [Bootstrap-Vue-Next BDropdown](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/dropdown) - Dropdown menus with auto-close prop
- [Bootstrap-Vue-Next BListGroup](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/list-group) - List display with button mode
- Codebase: `/app/src/views/review/Review.vue` - Existing patterns (BFormTags with PMIDs lines 659-712, data loading)
- Codebase: `/app/src/views/curate/ModifyEntity.vue` - Tree data handling patterns
- Codebase: `/app/package.json` - Bootstrap-Vue-Next version 0.42.0 confirmed

### Secondary (MEDIUM confidence)
- [Bootstrap-Vue-Next NPM page](https://www.npmjs.com/package/bootstrap-vue-next) - Version history, weekly downloads (331K+)
- [Bootstrap-Vue-Next GitHub releases](https://github.com/bootstrap-vue-next/bootstrap-vue-next/releases) - Recent updates and changelog
- [Bootstrap Icons](https://icons.getbootstrap.com/) - Chevron icons for expand/collapse

### Tertiary (LOW confidence)
- [MDB Bootstrap Vue Tree View](https://mdbootstrap.com/docs/vue/plugins/tree-view/) - Requires Material Design for Bootstrap (different framework, not applicable)
- [Syncfusion Vue Dropdown Tree](https://www.syncfusion.com/vue-components/vue-dropdown-tree) - Commercial library (not applicable)
- [PrimeVue TreeSelect](https://primevue.org/treeselect/) - **User explicitly rejected** PrimeVue

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All components verified in official Bootstrap-Vue-Next docs v0.42.0 and confirmed in codebase
- Architecture: HIGH - Patterns based on official documentation and existing working pattern (BFormTags for PMIDs)
- Pitfalls: HIGH - Based on documentation warnings, codebase analysis (commented-out treeselect issues), and common Vue 3 patterns

**Research date:** 2026-01-26
**Valid until:** ~2026-02-26 (30 days - Bootstrap-Vue-Next is stable framework, unlikely breaking changes)

**Bootstrap-Vue-Next specifics:**
- Version in codebase: 0.42.0
- Last checked: 2026-01-26
- No tree select component in official roadmap
- Framework philosophy: Provide primitives (BCollapse, BFormCheckbox), not complex widgets
- Custom component required for hierarchical multi-select (confirmed by community and docs)
