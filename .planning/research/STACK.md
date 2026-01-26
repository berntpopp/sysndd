# Technology Stack: Curation Workflow Modernization

**Project:** SysNDD v7.0 Curation Workflow
**Research Scope:** Stack additions for multi-select trees, wizards, entity search, accessible selects
**Researched:** 2026-01-26
**Overall Confidence:** HIGH

---

## Executive Summary

This document specifies stack additions needed for SysNDD v7.0 curation workflow modernization. The existing stack (Vue 3.5.25, Bootstrap-Vue-Next 0.42.0, TypeScript 5.9.3, VeeValidate 4.15.1) is solid. The focus is on solving specific component gaps:

1. **Multi-select tree** - Replace broken vue3-treeselect with PrimeVue TreeSelect (unstyled mode)
2. **Form wizard** - Extract existing CreateEntity pattern to reusable component (no new library)
3. **Entity search/autocomplete** - Extend existing AutocompleteInput component (no new library)
4. **Accessible selects** - Leverage Bootstrap-Vue-Next BFormSelect with ARIA enhancements (no new library)

**Key Decision:** Use PrimeVue TreeSelect in unstyled mode with Bootstrap classes for tree multi-select. This is the only new library addition. All other needs are met by extracting and enhancing existing patterns.

---

## Current Stack (Validated, No Changes Needed)

| Component | Version | Status | Notes |
|-----------|---------|--------|-------|
| Vue | 3.5.25 | KEEP | Composition API, 17 composables |
| TypeScript | 5.9.3 | KEEP | Branded domain types |
| Bootstrap-Vue-Next | 0.42.0 | KEEP | BFormSelect, BTable, BPagination working |
| Bootstrap | 5.3.8 | KEEP | Utility classes, forms |
| VeeValidate | 4.15.1 | KEEP | Form validation, useField/useForm |
| @vee-validate/rules | 4.15.1 | KEEP | Validation rules |
| VueUse | 14.1.0 | KEEP | URL sync, useIntervalFn |
| Vite | 7.3.1 | KEEP | Build tooling |

**Already Working:**
- FormWizard.vue component (5-step wizard pattern)
- useEntityForm composable (validation, step navigation)
- AutocompleteInput.vue (debounced search, keyboard navigation)
- StepPhenotypeVariation.vue (badge-based multi-select UI)
- TablesEntities pattern (search, pagination, URL sync)

---

## New Addition: PrimeVue TreeSelect

### Why PrimeVue TreeSelect

| Aspect | Details |
|--------|---------|
| **Problem** | @zanmato/vue3-treeselect 0.4.2 has broken multi-select (v-model init bug, known issue) |
| **Solution** | PrimeVue TreeSelect with checkbox selection mode |
| **Version** | PrimeVue 4.5.4 (latest stable, January 2026) |
| **Confidence** | HIGH (331K weekly downloads, active maintenance, PrimeTek 2026 roadmap published) |

**Why PrimeVue over alternatives:**

| Option | Verdict | Rationale |
|--------|---------|-----------|
| **PrimeVue TreeSelect** | RECOMMENDED | Best accessibility (ARIA compliant), TypeScript native, unstyled mode for Bootstrap integration, active maintenance |
| @zanmato/vue3-treeselect | AVOID | Multi-select v-model init bug, community maintained, inconsistent updates |
| @r2rka/vue3-treeselect | AVOID | Fork of megafetis, last published 2+ years ago |
| Element Plus TreeSelect | ALTERNATIVE | Would require adopting Element Plus styling, conflicts with Bootstrap |
| Headless UI Combobox | NOT SUITABLE | No built-in tree/hierarchical support |
| Reka UI Tree + Combobox | NOT SUITABLE | Would require custom composition, no ready-made TreeSelect |

### PrimeVue Unstyled Mode Integration

**Critical:** Use PrimeVue in **unstyled mode** to avoid CSS conflicts with Bootstrap.

**Setup (main.ts):**
```typescript
import { createApp } from 'vue'
import PrimeVue from 'primevue/config'

const app = createApp(App)

// Enable unstyled mode - no PrimeVue CSS applied
app.use(PrimeVue, {
  unstyled: true
})
```

**Component Import (selective, not full library):**
```typescript
// Only import TreeSelect, not entire PrimeVue
import TreeSelect from 'primevue/treeselect'

export default defineComponent({
  components: { TreeSelect }
})
```

**Pass Through Props for Bootstrap Styling:**
```typescript
// Apply Bootstrap classes via PT props
<TreeSelect
  v-model="selectedValues"
  :options="treeOptions"
  selectionMode="checkbox"
  display="chip"
  placeholder="Select phenotypes..."
  :pt="{
    root: { class: 'form-control form-control-sm' },
    label: { class: 'form-select-label' },
    trigger: { class: 'btn btn-sm btn-outline-secondary' },
    panel: { class: 'dropdown-menu show p-2' },
    tree: { class: 'list-unstyled' },
    node: { class: 'py-1' },
    checkbox: { class: 'form-check-input' }
  }"
/>
```

### TreeSelect Accessibility Features

PrimeVue TreeSelect has comprehensive ARIA support (verified from official docs):

- `combobox` role on root element with `aria-haspopup` and `aria-expanded`
- `tree` role on popup list
- `treeitem` role on each node with `aria-label`, `aria-selected`, `aria-expanded`
- `aria-checked` in checkbox selection mode
- Proper `aria-setsize`, `aria-posinset`, `aria-level` calculated automatically
- Keyboard navigation: Arrow keys, Enter, Escape, Tab

### Installation

```bash
npm install primevue@^4.5.4
```

**Bundle Impact:** ~15-20KB gzipped (TreeSelect only, unstyled mode, no CSS)

### Sources

- [PrimeVue TreeSelect Component](https://primevue.org/treeselect/) - Official documentation
- [PrimeVue Pass Through](https://primevue.org/passthrough/) - Custom class styling
- [primevue npm](https://www.npmjs.com/package/primevue) - Version 4.5.4, 331K weekly downloads

---

## No New Library: Form Wizard

### Why No New Library

The existing CreateEntity.vue already implements a complete wizard pattern:

**Existing Components:**
- `FormWizard.vue` - Progress indicator, step navigation, submit handling
- `StepCoreEntity.vue` - Step 1 content
- `StepEvidence.vue` - Step 2 content
- `StepPhenotypeVariation.vue` - Step 3 content
- `StepClassification.vue` - Step 4 content
- `StepReview.vue` - Step 5 content

**Existing Composable:**
- `useEntityForm.ts` - Form data, validation, step navigation, draft persistence

### Recommendation: Extract to Reusable Pattern

Instead of adding FormKit multi-step plugin (~25KB) or vue3-form-wizard, **extract the existing pattern**:

**1. Make FormWizard generic:**
```typescript
// Current: tightly coupled to entity form
// After: generic wizard accepting any step configuration

interface WizardStep {
  id: string
  label: string
  validation?: () => boolean
  component: Component
}

defineProps<{
  steps: WizardStep[]
  modelValue: Record<string, unknown>
}>()
```

**2. Create useFormWizard composable:**
```typescript
// Extract step navigation logic from useEntityForm
export function useFormWizard(steps: WizardStep[]) {
  const currentStepIndex = ref(0)
  const isCurrentStepValid = computed(() => /*...*/)
  const nextStep = () => /*...*/
  const previousStep = () => /*...*/
  const goToStep = (index: number) => /*...*/

  return { currentStepIndex, isCurrentStepValid, nextStep, previousStep, goToStep }
}
```

**Why not FormKit:**
- FormKit multi-step requires importing @formkit/vue + @formkit/addons (~40KB)
- Existing pattern already works, validated in production
- FormKit has its own styling system, would conflict with Bootstrap
- Cost of new dependency > cost of extraction

**Why not VeeValidate multi-step example:**
- Already using VeeValidate 4.15.1
- VeeValidate's multi-step is a documentation example, not a library feature
- Current implementation already uses VeeValidate patterns

### Sources

- [FormKit Multi-Step Plugin](https://formkit.com/plugins/multi-step) - Evaluated, not recommended
- [VeeValidate Multi-step Form Wizard](https://vee-validate.logaretm.com/v4/examples/multistep-form-wizard/) - Pattern reference
- `/app/src/components/forms/wizard/FormWizard.vue` - Existing working implementation

---

## No New Library: Entity Search/Autocomplete

### Why No New Library

The existing AutocompleteInput.vue already provides:

- Debounced search with configurable delay
- Keyboard navigation (Arrow keys, Enter, Escape)
- Loading state with spinner
- No results message
- Configurable item display (label, secondary, description)
- ARIA attributes (role="listbox", aria-selected, aria-label)
- Works with async search callbacks

### Recommendation: Extend Existing Component

**Add features to AutocompleteInput.vue:**

**1. Entity preview on selection:**
```vue
<template>
  <AutocompleteInput
    v-model="entityId"
    :results="searchResults"
    @select="handleSelect"
  >
    <!-- Add preview slot -->
    <template #preview="{ selected }">
      <EntityPreviewCard :entity="selected" />
    </template>
  </AutocompleteInput>
</template>
```

**2. Improve search result display:**
```typescript
// Add formatSearchResult prop for custom formatting
interface AutocompleteInputProps {
  // ...existing props
  formatResult?: (item: Record<string, unknown>) => {
    primary: string
    secondary?: string
    description?: string
    badge?: { text: string; variant: string }
  }
}
```

**3. Add clear button:**
```vue
<template>
  <div class="position-relative">
    <BFormInput ... />
    <button
      v-if="modelValue && !disabled"
      type="button"
      class="btn-close position-absolute"
      style="right: 0.75rem; top: 50%; transform: translateY(-50%);"
      aria-label="Clear selection"
      @click="clearSelection"
    />
  </div>
</template>
```

### Sources

- `/app/src/components/forms/AutocompleteInput.vue` - Existing implementation (395 lines)
- `/app/src/components/forms/wizard/StepCoreEntity.vue` - Current usage example

---

## No New Library: Accessible Selects

### Why No New Library

Bootstrap-Vue-Next BFormSelect already provides:

- Native `<select>` element (best accessibility by default)
- Keyboard navigation built-in
- Screen reader compatible
- Option groups support (`<optgroup>`)
- Validation state styling

### Current Issue and Solution

**Issue:** ModifyEntity uses flattened tree options in single BFormSelect, losing hierarchy.

**Solution:** Use Bootstrap's native `<optgroup>` which BFormSelect supports:

```typescript
// Current (flat)
const options = [
  { value: 'HP:0001-present', text: 'present: Seizures' },
  { value: 'HP:0001-absent', text: 'absent: Seizures' },
  { value: 'HP:0002-present', text: 'present: Hypotonia' }
]

// Better (grouped)
const options = [
  {
    label: 'Seizures',
    options: [
      { value: 'HP:0001-present', text: 'present' },
      { value: 'HP:0001-absent', text: 'absent' }
    ]
  },
  {
    label: 'Hypotonia',
    options: [
      { value: 'HP:0002-present', text: 'present' },
      { value: 'HP:0002-absent', text: 'absent' }
    ]
  }
]
```

**For multi-select:** Use PrimeVue TreeSelect (recommended above) when hierarchical multi-select is needed. For simple multi-select, BFormSelect with `multiple` attribute works.

### Accessibility Enhancements

Add to all selects:

```vue
<BFormSelect
  id="phenotype-select"
  v-model="selectedPhenotype"
  :options="phenotypeOptions"
  aria-label="Select phenotype modifier"
  aria-describedby="phenotype-help"
  :aria-invalid="!!error"
  :aria-errormessage="error ? 'phenotype-error' : undefined"
/>
<small id="phenotype-help" class="form-text">
  Select HPO terms describing this phenotype
</small>
<div v-if="error" id="phenotype-error" class="invalid-feedback">
  {{ error }}
</div>
```

### Sources

- [Bootstrap-Vue-Next BFormSelect](https://bootstrap-vue-next.github.io/bootstrap-vue-next/components/FormSelect.html)
- [MDN: select element accessibility](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/select#accessibility_concerns)

---

## What NOT to Add

### Libraries Evaluated and Rejected

| Library | Version | Why Rejected |
|---------|---------|--------------|
| **FormKit** | 2.x | Adds ~40KB, own styling system, existing wizard works |
| **vue3-form-wizard** | - | Adds unnecessary dependency, existing pattern sufficient |
| **@zanmato/vue3-treeselect** | 0.4.2 | Multi-select v-model init bug, inconsistent maintenance |
| **@r2rka/vue3-treeselect** | 0.2.4 | Last published 2+ years ago |
| **Element Plus** | - | Would require adopting entire design system |
| **Vuetify** | - | Would require adopting entire design system |
| **Headless UI** | 1.7.23 | No tree/hierarchical component |
| **Reka UI** | 2.7.0 | No ready-made TreeSelect, would require custom composition |
| **shadcn-vue** | - | No TreeSelect component |

### Patterns to Avoid

| Anti-Pattern | Why Avoid | Do Instead |
|--------------|-----------|------------|
| Add library for one component | Bundle bloat, maintenance burden | Extend existing patterns |
| Mix PrimeVue styling with Bootstrap | CSS conflicts, inconsistent UI | Use unstyled mode + PT props |
| Replace all selects with custom components | Worse accessibility than native | Use native `<select>` with ARIA |
| Add multiple tree-select libraries | API inconsistency | Pick one (PrimeVue) |

---

## Installation Summary

### Single Addition

```bash
# Only new dependency for v7.0
npm install primevue@^4.5.4
```

### Main.ts Update

```typescript
// Add after existing imports
import PrimeVue from 'primevue/config'

// Add after app.use(BootstrapVueNext)
app.use(PrimeVue, { unstyled: true })
```

### No Changes Needed

- package.json: Only primevue addition
- vite.config.ts: No changes
- tsconfig.json: No changes (PrimeVue has TypeScript types)
- ESLint config: No changes

---

## Component Plan

### New Components to Create

| Component | Purpose | Dependencies |
|-----------|---------|--------------|
| `TreeMultiSelect.vue` | Wrapper around PrimeVue TreeSelect with Bootstrap styling | PrimeVue TreeSelect |
| `useFormWizard.ts` | Generic wizard navigation composable | Vue 3 Composition API |

### Components to Extend

| Component | Changes |
|-----------|---------|
| `FormWizard.vue` | Make generic (accept any steps), add slot for custom actions |
| `AutocompleteInput.vue` | Add preview slot, clear button, custom result formatting |
| `StepPhenotypeVariation.vue` | Replace BFormSelect with TreeMultiSelect |

### Components to Refactor

| Component | Current State | Target State |
|-----------|---------------|--------------|
| `ModifyEntity.vue` | Options API, broken treeselect | Composition API, TreeMultiSelect |
| `ApproveReview.vue` | Basic table | TablesEntities pattern |
| `ApproveStatus.vue` | Basic table | TablesEntities pattern |

---

## Bundle Impact Assessment

| Addition | Size (gzipped) | Notes |
|----------|----------------|-------|
| primevue/treeselect (unstyled) | ~15-20KB | Tree-shaken, only TreeSelect |
| primevue/config | ~2KB | Required for PrimeVue setup |
| **Total New** | **~17-22KB** | Acceptable for functionality gain |

**Current bundle:** ~600KB gzipped
**After v7.0:** ~620KB gzipped (+3.5%)

---

## Migration Path

### Phase 1: Add PrimeVue TreeSelect

1. Install primevue
2. Configure unstyled mode in main.ts
3. Create TreeMultiSelect.vue wrapper with Bootstrap PT props
4. Test with phenotype options

### Phase 2: Extract Wizard Pattern

1. Create useFormWizard composable from useEntityForm
2. Make FormWizard.vue accept generic step configuration
3. Verify CreateEntity still works
4. Use pattern for ModifyEntity wizard

### Phase 3: Extend AutocompleteInput

1. Add preview slot
2. Add clear button
3. Add custom result formatting
4. Update ModifyEntity to use enhanced autocomplete

### Phase 4: Apply to Curation Views

1. Update StepPhenotypeVariation to use TreeMultiSelect
2. Update ModifyEntity with TreeMultiSelect
3. Verify ApproveReview/ApproveStatus tables
4. Accessibility audit

---

## Confidence Assessment

| Decision | Confidence | Basis |
|----------|------------|-------|
| PrimeVue TreeSelect | HIGH | 331K weekly downloads, ARIA compliant, unstyled mode documented |
| Unstyled mode integration | HIGH | Official PrimeVue feature, documented PT props |
| No FormKit | HIGH | Existing pattern works, cost > benefit |
| No new autocomplete library | HIGH | AutocompleteInput already comprehensive |
| Bootstrap-Vue-Next selects | HIGH | Native select accessibility, optgroup support |
| Bundle impact ~22KB | HIGH | Tree-shaking verified in PrimeVue docs |

---

## Sources

**PrimeVue (High Confidence):**
- [PrimeVue TreeSelect Component](https://primevue.org/treeselect/)
- [PrimeVue Pass Through](https://primevue.org/passthrough/)
- [PrimeVue Unstyled Mode](https://primevue.org/theming/styled/)
- [primevue npm](https://www.npmjs.com/package/primevue) - v4.5.4

**Vue Ecosystem (High Confidence):**
- [VeeValidate Multi-step Form Wizard](https://vee-validate.logaretm.com/v4/examples/multistep-form-wizard/)
- [FormKit Multi-Step Plugin](https://formkit.com/plugins/multi-step)
- [Bootstrap-Vue-Next Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/)

**vue3-treeselect Issues (Medium Confidence - GitHub):**
- [megafetis/vue3-treeselect Issue #4](https://github.com/megafetis/vue3-treeselect/issues/4) - v-model init bug

**Alternatives Evaluated (Medium Confidence):**
- [Headless UI Vue Combobox](https://headlessui.com/v1/vue/combobox)
- [Reka UI (formerly Radix Vue)](https://www.radix-vue.com/)
- [reka-ui npm](https://www.npmjs.com/package/reka-ui) - v2.7.0

---

**Document Version:** 1.0
**Last Updated:** 2026-01-26
**Next Review:** After Phase 1 completion (PrimeVue TreeSelect integration)
