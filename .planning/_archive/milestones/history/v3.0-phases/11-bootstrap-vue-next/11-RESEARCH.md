# Phase 11: Bootstrap-Vue-Next Migration - Research

**Researched:** 2026-01-22
**Domain:** Bootstrap-Vue-Next, Bootstrap 5, Vue 3 UI Component Migration
**Confidence:** MEDIUM-HIGH

## Summary

This research investigates the migration from Bootstrap-Vue (Vue 2, Bootstrap 4) to Bootstrap-Vue-Next (Vue 3, Bootstrap 5). The migration involves significant API changes across components, CSS class renaming for RTL support, and replacing deprecated global patterns ($bvModal, $bvToast) with composables.

Key findings:
- Bootstrap-Vue-Next is a complete rewrite, not a drop-in replacement
- The `BApp` component approach is recommended for modal/toast orchestration
- Tables use new sorting model (`update:sort-by` event with array-based sortBy)
- All `.sync` modifiers must become `v-model:` syntax
- 396 instances of Bootstrap 4 spacing/alignment classes need updating
- Third-party library replacements are well-defined except @upsetjs/vue (Vue 2 only)

**Primary recommendation:** Use the `BApp` wrapper component pattern for the migration, which provides built-in modal/toast orchestrator support and simplifies the transition from global $bvModal/$bvToast patterns.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bootstrap-vue-next | 0.42+ | Vue 3 Bootstrap components | Official successor to Bootstrap-Vue |
| bootstrap | 5.3.8 | CSS framework | Required by Bootstrap-Vue-Next |
| @unhead/vue | 2.x | Head/meta management | Official successor to vue-meta for Vue 3 |
| vee-validate | 4.x | Form validation | Vue 3 compatible, composition API based |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @r2rka/vue3-treeselect | 0.2.4 | Multi-select tree component | Direct replacement for @riophae/vue-treeselect |
| @vee-validate/rules | 4.x | Validation rules | Laravel-style string expressions |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| @upsetjs/vue | @upsetjs/bundle (vanilla) | Manual DOM integration, no Vue wrapper but works with Vue 3 |
| vue2-perfect-scrollbar | Native CSS | User decision: remove entirely, use `overflow: auto` |

**Installation:**
```bash
# Already installed in Phase 10-02:
# npm install bootstrap@5.3.8 bootstrap-vue-next@0.42+

# New dependencies for this phase:
npm install @unhead/vue@^2 vee-validate@^4 @vee-validate/rules@^4
npm install @r2rka/vue3-treeselect@^0.2.4

# Remove old packages after migration:
npm uninstall bootstrap-vue vue-meta @riophae/vue-treeselect vue2-perfect-scrollbar
```

## Architecture Patterns

### Recommended Project Structure
```
src/
├── main.js              # BApp wrapper setup, remove Vue.use() patterns
├── App.vue              # Wrapped with BApp component
├── composables/
│   ├── useToastNotifications.js  # Wrapper around useToast
│   └── useModalControls.js       # Wrapper around useModal
├── components/          # All b-* components updated
└── views/               # All views updated
```

### Pattern 1: BApp Component Setup
**What:** Wrap application with BApp for orchestrator support
**When to use:** At application root (App.vue or main.js)
**Example:**
```vue
<!-- App.vue -->
<template>
  <BApp>
    <div id="app">
      <Navbar />
      <router-view :key="$route.fullPath" />
      <Footer />
    </div>
  </BApp>
</template>

<script setup>
import { BApp } from 'bootstrap-vue-next'
</script>
```
Source: [BApp Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/app.html)

### Pattern 2: useToast Composable (Replaces $bvToast)
**What:** Programmatic toast creation
**When to use:** Replacing all `this.$bvToast.toast()` calls
**Example:**
```javascript
// composables/useToastNotifications.js
import { useToast } from 'bootstrap-vue-next'

export function useToastNotifications() {
  const { create } = useToast()

  const makeToast = (message, title = null, variant = null, autoHide = true, autoHideDelay = 3000) => {
    create({
      title,
      body: typeof message === 'object' && message.message ? message.message : message,
      variant,
      pos: 'top-end',  // Bootstrap-Vue-Next position format
      value: autoHide ? autoHideDelay : 0,  // 0 means no auto-hide
    })
  }

  return { makeToast }
}
```
Source: [useToast Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/composables/useToast.html)

### Pattern 3: useModal Composable (Replaces $bvModal and $root.$emit)
**What:** Programmatic modal control
**When to use:** Replacing `this.$bvModal.show()`, `this.$root.$emit('bv::show::modal')`
**Example:**
```javascript
// Inline usage in component
import { useModal } from 'bootstrap-vue-next'

const { show, hide } = useModal()

// Show modal by ID
const openModal = () => show('my-modal-id')

// Or use v-model on BModal directly
const modalVisible = ref(false)
// <BModal v-model="modalVisible" id="my-modal-id">
```
Source: [useModal Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/composables/useModal.html)

### Pattern 4: Table Sorting Migration
**What:** New array-based sorting with v-model
**When to use:** All b-table components with sorting
**Example:**
```vue
<!-- Before (Bootstrap-Vue) -->
<b-table
  :sort-by.sync="sortBy"
  :sort-desc.sync="sortDesc"
  @sort-changed="handleSortChanged"
/>

<!-- After (Bootstrap-Vue-Next) -->
<BTable
  v-model:sort-by="sortBy"
  @update:sort-by="handleSortChanged"
/>

<script setup>
// sortBy is now an array of objects
const sortBy = ref([{ key: 'entity_id', order: 'asc' }])

const handleSortChanged = (newSortBy) => {
  // newSortBy is array: [{ key: 'column', order: 'asc'|'desc' }]
}
</script>
```
Source: [BTable Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/table)

### Pattern 5: VeeValidate 4 Migration
**What:** Composition API based form validation
**When to use:** Replacing ValidationObserver/ValidationProvider
**Example:**
```vue
<!-- Before (vee-validate 3) -->
<validation-observer ref="observer" v-slot="{ handleSubmit }">
  <b-form @submit.prevent="handleSubmit(onSubmit)">
    <validation-provider v-slot="{ errors }" name="email" rules="required|email">
      <b-form-input v-model="email" :state="errors.length ? false : null" />
    </validation-provider>
  </b-form>
</validation-observer>

<!-- After (vee-validate 4) -->
<form @submit="onSubmit">
  <BFormInput v-model="email" :state="emailMeta.valid === false ? false : null" />
  <span v-if="emailError">{{ emailError }}</span>
</form>

<script setup>
import { useForm, useField } from 'vee-validate'
import * as yup from 'yup'

const schema = yup.object({
  email: yup.string().required().email()
})

const { handleSubmit } = useForm({ validationSchema: schema })
const { value: email, errorMessage: emailError, meta: emailMeta } = useField('email')

const onSubmit = handleSubmit((values) => {
  // Handle submission
})
</script>
```
Source: [VeeValidate 4 Getting Started](https://vee-validate.logaretm.com/v4/guide/composition-api/getting-started/)

### Anti-Patterns to Avoid
- **Using $root.$emit for modals:** Replace with useModal() composable or v-model
- **Using .sync modifier:** Replace with v-model: syntax (e.g., `:sort-by.sync` -> `v-model:sort-by`)
- **Using Vue.use() for Bootstrap-Vue-Next:** Use BApp component instead
- **Manual Bootstrap 4 class usage:** Use Bootstrap 5 equivalents (ms-/me- instead of ml-/mr-)

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Toast notifications | Custom toast system | useToast() composable | Built-in positioning, stacking, auto-dismiss |
| Modal dialogs | Manual show/hide logic | useModal() + BModal v-model | Focus trapping, accessibility, animations |
| Form validation | Custom validation | vee-validate 4 | Schema support, error handling, field states |
| Table sorting | Custom sort implementation | BTable v-model:sort-by | Multi-column support, sort icons |
| Head/meta tags | Manual document.title | @unhead/vue | SSR support, deduplication |

**Key insight:** Bootstrap-Vue-Next composables handle complex browser behaviors (focus management, keyboard navigation, ARIA attributes) that are easy to get wrong when building custom solutions.

## Common Pitfalls

### Pitfall 1: .sync Modifier Still in Code
**What goes wrong:** Vue 3 removed .sync modifier, causes compilation errors
**Why it happens:** Bootstrap-Vue used .sync extensively for two-way binding
**How to avoid:** Search and replace all `.sync` with `v-model:` syntax
**Warning signs:** 18 instances found in codebase: `grep -r "\.sync" app/src --include="*.vue"`

### Pitfall 2: $root.$emit for Modal Control
**What goes wrong:** Vue 3 removed instance event system
**Why it happens:** Bootstrap-Vue used `$root.$emit('bv::show::modal', id)` pattern
**How to avoid:** Use useModal() composable or v-model on BModal
**Warning signs:** 15 instances found using this pattern

### Pitfall 3: sortBy Type Change
**What goes wrong:** Sorting breaks because sortBy expects array, not string
**Why it happens:** Bootstrap-Vue used string sortBy, Bootstrap-Vue-Next uses array
**How to avoid:** Change `sortBy: 'column'` to `sortBy: [{ key: 'column', order: 'asc' }]`
**Warning signs:** All tables with sorting affected

### Pitfall 4: Bootstrap 4 Class Names
**What goes wrong:** Spacing and alignment broken
**Why it happens:** Bootstrap 5 renamed classes for RTL support
**How to avoid:** Systematic search and replace of class names
**Warning signs:** 396 occurrences of ml-/mr-/text-left/text-right found

### Pitfall 5: filter-included-fields Prop Removed
**What goes wrong:** Table filtering stops working
**Why it happens:** Bootstrap-Vue-Next handles filtering differently
**How to avoid:** Use external filtering (filter data before passing to items prop) or field-level `filterable` property
**Warning signs:** 8 tables use `filter-included-fields` prop

### Pitfall 6: @upsetjs/vue Vue 2 Only
**What goes wrong:** UpSet.js chart component doesn't work in Vue 3
**Why it happens:** @upsetjs/vue requires Vue 2 (peer dependency: ^2.6.14)
**How to avoid:** Use @upsetjs/bundle directly with vanilla JS in Vue 3 component
**Warning signs:** AnalysesCurationUpset.vue imports from @upsetjs/vue

### Pitfall 7: metaInfo Option Replaced
**What goes wrong:** Page titles and meta tags stop working
**Why it happens:** vue-meta uses Options API pattern not supported in Vue 3
**How to avoid:** Migrate to @unhead/vue with useHead() composable
**Warning signs:** 23 files use metaInfo option

## Code Examples

Verified patterns from official sources:

### Bootstrap 5 CSS Class Migration
```html
<!-- Margin classes -->
ml-* -> ms-*  (margin-start)
mr-* -> me-*  (margin-end)
pl-* -> ps-*  (padding-start)
pr-* -> pe-*  (padding-end)

<!-- Text alignment -->
text-left -> text-start
text-right -> text-end

<!-- Float -->
float-left -> float-start
float-right -> float-end

<!-- Data attributes (if any raw Bootstrap JS used) -->
data-toggle -> data-bs-toggle
data-target -> data-bs-target
data-dismiss -> data-bs-dismiss

<!-- Close button -->
.close -> .btn-close

<!-- Screen reader -->
.sr-only -> .visually-hidden
```
Source: [Bootstrap 5 Migration Guide](https://getbootstrap.com/docs/5.0/migration/)

### @unhead/vue Setup (Replaces vue-meta)
```javascript
// main.js
import { createHead } from '@unhead/vue/client'

const head = createHead()
const app = createApp(App)
app.use(head)

// In components (Composition API)
import { useHead } from '@unhead/vue'

useHead({
  title: 'Page Title',
  meta: [
    { name: 'description', content: 'Page description' }
  ]
})

// Or with Options API compatibility
export default {
  setup() {
    useHead({
      title: computed(() => 'Dynamic Title'),
    })
  }
}
```
Source: [Unhead Vue Installation](https://unhead.unjs.io/docs/vue/head/guides/get-started/installation/)

### @r2rka/vue3-treeselect Migration
```vue
<!-- Before -->
<treeselect
  v-model="value"
  :multiple="true"
  :options="options"
  :normalizer="normalizer"
/>
<script>
import Treeselect from '@riophae/vue-treeselect'
import '@riophae/vue-treeselect/dist/vue-treeselect.css'
</script>

<!-- After (minimal changes) -->
<TreeSelect
  v-model="value"
  :multiple="true"
  :options="options"
  :normalizer="normalizer"
/>
<script>
import { TreeSelect } from '@r2rka/vue3-treeselect'
import '@r2rka/vue3-treeselect/dist/style.css'
</script>
```
Source: [vue3-treeselect npm](https://www.npmjs.com/package/@r2rka/vue3-treeselect)

### @upsetjs/bundle Integration (Vanilla JS for Vue 3)
```vue
<template>
  <div ref="upsetContainer" class="upset-container"></div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { render, extractSets } from '@upsetjs/bundle'

const upsetContainer = ref(null)
const props = defineProps(['elems', 'width', 'height'])
const emit = defineEmits(['hover'])

const renderChart = () => {
  if (!upsetContainer.value || !props.elems.length) return

  const sets = extractSets(props.elems)
  render(upsetContainer.value, {
    sets,
    width: props.width,
    height: props.height,
    onHover: (s) => emit('hover', s),
    theme: 'vega'
  })
}

onMounted(renderChart)
watch(() => props.elems, renderChart)
</script>
```
Note: This is a workaround pattern since @upsetjs/vue doesn't support Vue 3

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Bootstrap-Vue 2.21 | Bootstrap-Vue-Next 0.42+ | 2023+ | Complete API rewrite |
| $bvModal.show() | useModal() composable | Vue 3 migration | All programmatic modals |
| $bvToast.toast() | useToast() composable | Vue 3 migration | All toast notifications |
| .sync modifier | v-model: syntax | Vue 3 | All two-way bindings |
| Vue.use() plugins | BApp component | Bootstrap-Vue-Next | App initialization |
| vue-meta | @unhead/vue | Vue 3 | All metaInfo usages |
| vee-validate 3 | vee-validate 4 | Vue 3 | Form validation patterns |

**Deprecated/outdated:**
- `$root.$emit('bv::show::modal')`: Use useModal() composable
- `filter-included-fields` prop: Handle filtering externally
- `html` props on components: Use slots instead
- Bootstrap 4 utility classes: Update to Bootstrap 5 equivalents

## Open Questions

Things that couldn't be fully resolved:

1. **@upsetjs/vue Vue 3 Support**
   - What we know: Package explicitly requires Vue ^2.6.14 as peer dependency
   - What's unclear: Whether maintainer will add Vue 3 support (open issue since May 2022)
   - Recommendation: Use @upsetjs/bundle with vanilla JS integration as documented in Code Examples

2. **Bootstrap-Vue-Next Alpha Status**
   - What we know: Library is in "late stages of alpha" per official docs
   - What's unclear: Timeline for stable release, potential breaking changes
   - Recommendation: Pin to specific version (0.42+), test thoroughly, monitor releases

3. **Table Provider Function Changes**
   - What we know: Provider function context changed (`ctx.sortBy` is now array)
   - What's unclear: Full API compatibility with current server-side pagination
   - Recommendation: Test current loadData methods with new BTable API

## Sources

### Primary (HIGH confidence)
- [Bootstrap-Vue-Next Migration Guide](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/migration-guide) - Complete migration documentation
- [Bootstrap-Vue-Next BApp Component](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/app.html) - BApp setup
- [Bootstrap-Vue-Next BTable](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/table) - Table API
- [Bootstrap-Vue-Next useModal](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/composables/useModal.html) - Modal composable
- [Bootstrap-Vue-Next useToast](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/composables/useToast.html) - Toast composable
- [Bootstrap 5 Migration Guide](https://getbootstrap.com/docs/5.0/migration/) - CSS class changes

### Secondary (MEDIUM confidence)
- [VeeValidate 4 Composition API](https://vee-validate.logaretm.com/v4/guide/composition-api/getting-started/) - Validation migration
- [Unhead Vue Installation](https://unhead.unjs.io/docs/vue/head/guides/get-started/installation/) - vue-meta replacement
- [@r2rka/vue3-treeselect npm](https://www.npmjs.com/package/@r2rka/vue3-treeselect) - Treeselect replacement

### Tertiary (LOW confidence)
- @upsetjs/vue Vue 3 status - Based on GitHub issue, npm peer deps check
- Bootstrap-Vue-Next stability - Based on documentation self-description as "alpha"

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official documentation verified
- Architecture patterns: HIGH - Based on official examples
- Pitfalls: HIGH - Verified against codebase grep searches
- Third-party migrations: MEDIUM - Some packages lack detailed Vue 3 guides

**Migration scope from codebase analysis:**
- Files with Bootstrap-Vue components: 70+ Vue files
- .sync modifier usages: 18 instances
- $root.$emit modal patterns: 15 instances
- Bootstrap 4 CSS classes: 396 occurrences
- vue-meta/metaInfo usages: 23 files
- vee-validate usages: 3 files (Login, Register, PasswordReset)
- vue-treeselect usages: 12 files
- perfect-scrollbar usages: 2 files (main.js, App.vue)
- @upsetjs/vue usage: 1 file (AnalysesCurationUpset.vue)

**Research date:** 2026-01-22
**Valid until:** 2026-02-22 (30 days - library in alpha, check for updates)
