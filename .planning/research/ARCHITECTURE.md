# Architecture Patterns: Vue 3 + TypeScript Migration

**Domain:** Vue 2.7 to Vue 3 + TypeScript + Bootstrap-Vue-Next migration
**Researched:** 2026-01-22
**Confidence:** HIGH

## Executive Summary

SysNDD's migration from Vue 2.7 (Options API with mixins) to Vue 3 (Composition API with composables and TypeScript) requires systematic architectural reorganization. The current structure with 7 mixins, Options API components, and global component registration needs transformation to align with Vue 3 best practices: `<script setup>`, composables, TypeScript integration, and Bootstrap-Vue-Next.

**Key architectural shifts:**
- **Mixins → Composables**: Convert 7 mixins to composable functions with `use*` naming
- **Options API → Composition API**: Migrate components to `<script setup lang="ts">`
- **Global registration → Explicit imports**: Replace global-components.js with local imports
- **Bootstrap-Vue → Bootstrap-Vue-Next**: Update component syntax and APIs

This migration enables type safety, better code organization, improved developer experience, and positions SysNDD for long-term maintainability with modern Vue 3 ecosystem tooling.

---

## Recommended Architecture

### Target Directory Structure

```
app/src/
├── main.ts                          # Entry point (main.js → main.ts)
├── App.vue
├── assets/
│   ├── scss/                        # Existing SCSS
│   ├── css/                         # Existing CSS
│   └── images/                      # Static assets
├── components/
│   ├── analyses/                    # Analysis components
│   ├── small/                       # Reusable UI components
│   ├── tables/                      # Table components
│   ├── Navbar.vue
│   └── Footer.vue
├── composables/                     # NEW: Migrated from mixins
│   ├── useColorAndSymbols.ts       # From colorAndSymbolsMixin.js
│   ├── useScrollbar.ts             # From scrollbarMixin.js
│   ├── useTableData.ts             # From tableDataMixin.js
│   ├── useTableMethods.ts          # From tableMethodsMixin.js
│   ├── useText.ts                  # From textMixin.js
│   ├── useToast.ts                 # From toastMixin.js
│   ├── useUrlParsing.ts            # From urlParsingMixin.js
│   └── index.ts                    # Re-export all composables
├── types/                           # NEW: TypeScript type definitions
│   ├── api.ts                       # API response types
│   ├── components.ts                # Component prop types
│   ├── constants.ts                 # Constants types
│   └── models.ts                    # Data model interfaces
├── constants/                       # Renamed from assets/js/constants/
│   ├── footerNav.ts                # From footer_nav_constants.js
│   ├── initObjects.ts              # From init_obj_constants.js
│   ├── mainNav.ts                  # From main_nav_constants.js
│   ├── roles.ts                    # From role_constants.js
│   └── urls.ts                     # From url_constants.js
├── services/                        # Enhanced from assets/js/services/
│   ├── api.ts                      # From apiService.js with TypeScript
│   └── index.ts                    # Re-export all services
├── utils/                           # NEW: Pure utility functions
│   ├── formatters.ts               # Date, number formatting
│   ├── validators.ts               # Validation helpers
│   └── helpers.ts                  # Generic helper functions
├── classes/                         # Enhanced from assets/js/classes/
│   ├── submission/                 # Existing submission classes
│   └── index.ts                    # Re-export with TypeScript
├── views/
│   ├── help/                       # Help pages
│   ├── curate/                     # Curation views
│   ├── analyses/                   # Analysis views
│   ├── tables/                     # Table views
│   ├── admin/                      # Admin views
│   ├── review/                     # Review views
│   └── pages/                      # Other pages
├── router/
│   └── index.ts                    # Vue Router 4 (from index.js)
├── stores/                          # Pinia stores (already using Pinia)
│   └── *.ts
├── plugins/
│   └── axios.ts                    # From axios.js
└── config/
    └── *.ts                        # Configuration files
```

### Key Structural Changes

| Current Location | New Location | Rationale |
|------------------|--------------|-----------|
| `assets/js/mixins/*.js` | `composables/use*.ts` | Composition API pattern, TypeScript |
| `assets/js/constants/*.js` | `constants/*.ts` | Flatter structure, TypeScript |
| `assets/js/services/*.js` | `services/*.ts` | TypeScript, explicit exports |
| `assets/js/classes/**/*.js` | `classes/**/*.ts` | TypeScript |
| `global-components.js` | Component-local imports | Explicit dependencies, tree-shaking |
| `*.vue` with Options API | `*.vue` with `<script setup>` | Composition API, TypeScript inference |
| `main.js` | `main.ts` | TypeScript entry point |

---

## Migration Patterns

### Pattern 1: Mixin → Composable Conversion

**Philosophy:** Mixins implicitly merge properties into components. Composables explicitly return reactive values.

#### Example: colorAndSymbolsMixin → useColorAndSymbols

**Before (Mixin):**
```javascript
// assets/js/mixins/colorAndSymbolsMixin.js
export default {
  data() {
    return {
      stoplights_style: {
        1: 'success',
        2: 'primary',
        // ...
      },
      ndd_icon: {
        No: 'x',
        Yes: 'check',
      },
      // ... more properties
    };
  },
};
```

**After (Composable):**
```typescript
// composables/useColorAndSymbols.ts
import { readonly } from 'vue'
import type { StoplightsStyle, NddIcon, UserIcon } from '@/types/components'

export function useColorAndSymbols() {
  const stoplightsStyle: Readonly<StoplightsStyle> = {
    1: 'success',
    2: 'primary',
    3: 'warning',
    4: 'danger',
    Definitive: 'success',
    Moderate: 'primary',
    Limited: 'warning',
    Refuted: 'danger',
  } as const

  const nddIcon: Readonly<NddIcon> = {
    No: 'x',
    Yes: 'check',
  } as const

  const userIcon: Readonly<UserIcon> = {
    Viewer: 'person-circle',
    Reviewer: 'emoji-smile',
    Curator: 'emoji-heart-eyes',
    Administrator: 'emoji-sunglasses',
  } as const

  // Helper function to get stoplight variant
  const getStoplightVariant = (category: keyof StoplightsStyle): string => {
    return stoplightsStyle[category] || 'secondary'
  }

  return {
    stoplightsStyle: readonly(stoplightsStyle),
    nddIcon: readonly(nddIcon),
    userIcon: readonly(userIcon),
    getStoplightVariant,
  }
}
```

**Component Usage:**
```vue
<!-- After: Composition API with composable -->
<script setup lang="ts">
import { ref } from 'vue'
import { useColorAndSymbols } from '@/composables/useColorAndSymbols'

const { userIcon, userStyle, getUserIcon } = useColorAndSymbols()
const role = ref<'Curator'>('Curator')
</script>

<template>
  <b-icon :icon="userIcon[role]" :variant="userStyle[role]" />
</template>
```

**Benefits:**
- **Type safety**: TypeScript knows the shape of all objects
- **Explicit dependencies**: Clear what data comes from composable
- **No namespace collisions**: No implicit property merging
- **Tree-shakable**: Only import what you use

---

### Pattern 2: Options API → Composition API with TypeScript

**Complete Component Transformation Example:**

**Before (Options API):**
```vue
<script>
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin'
import toastMixin from '@/assets/js/mixins/toastMixin'

export default {
  name: 'UserCard',
  mixins: [colorAndSymbolsMixin, toastMixin],
  props: {
    userId: {
      type: Number,
      required: true
    }
  },
  data() {
    return {
      user: null,
      loading: false,
      error: null
    }
  },
  computed: {
    userRoleBadge() {
      if (!this.user) return null
      return {
        icon: this.user_icon[this.user.role],
        variant: this.user_style[this.user.role]
      }
    }
  },
  watch: {
    userId: {
      immediate: true,
      handler(newId) {
        this.fetchUser(newId)
      }
    }
  },
  methods: {
    async fetchUser(id) {
      this.loading = true
      try {
        const response = await this.axios.get(`/api/users/${id}`)
        this.user = response.data
        this.makeToast('Success', 'User loaded', 'success')
      } catch (error) {
        this.makeToast('Error', 'Failed to load user', 'danger')
      } finally {
        this.loading = false
      }
    }
  }
}
</script>
```

**After (Composition API + TypeScript):**
```vue
<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useColorAndSymbols } from '@/composables/useColorAndSymbols'
import { useToast } from '@/composables/useToast'
import { useApi } from '@/composables/useApi'
import type { User } from '@/types/models'

// Props
interface Props {
  userId: number
}
const props = defineProps<Props>()

// Composables
const { userIcon, userStyle } = useColorAndSymbols()
const { showSuccess, showError } = useToast()
const { get } = useApi()

// State
const user = ref<User | null>(null)
const loading = ref(false)
const error = ref<string | null>(null)

// Computed
const userRoleBadge = computed(() => {
  if (!user.value) return null
  const role = user.value.role
  return {
    icon: userIcon[role],
    variant: userStyle[role]
  }
})

// Methods
const fetchUser = async (id: number) => {
  loading.value = true
  error.value = null
  try {
    const response = await get<User>(`/api/users/${id}`)
    user.value = response
    showSuccess('Success', 'User loaded')
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Unknown error'
    showError('Error', 'Failed to load user')
  } finally {
    loading.value = false
  }
}

// Watchers
watch(
  () => props.userId,
  (newId) => fetchUser(newId),
  { immediate: true }
)
</script>
```

---

### Pattern 3: Global Component Registration → Local Imports

**Before:**
```javascript
// global-components.js
import Vue from 'vue'

const components = {
  TablesEntities: () => import('@/components/tables/TablesEntities.vue'),
  HelperBadge: () => import('@/components/HelperBadge.vue'),
}

Object.entries(components).forEach(([name, component]) =>
  Vue.component(name, component)
)
```

**After:**
```vue
<script setup lang="ts">
import TablesEntities from '@/components/tables/TablesEntities.vue'
import HelperBadge from '@/components/HelperBadge.vue'
import type { FilterObject } from '@/types/components'

const filter = ref<FilterObject>({})
</script>

<template>
  <div>
    <TablesEntities :filter="filter" />
    <HelperBadge text="Help" />
  </div>
</template>
```

**Benefits:**
- **Tree-shaking**: Unused components removed from bundle
- **Clear dependencies**: Easy to see what a component uses
- **Better IDE support**: Jump to definition, find usages

---

### Pattern 4: Bootstrap-Vue → Bootstrap-Vue-Next

**v-model Changes:**
```vue
<!-- Before -->
<b-form-checkbox :indeterminate.sync="indeterminate" v-model="checked" />

<!-- After -->
<BFormCheckbox v-model:indeterminate="indeterminate" v-model="checked" />
```

**Directional Props:**
```vue
<!-- Before -->
<b-card img-left img-src="image.jpg" />

<!-- After -->
<BCard img-start img-src="image.jpg" />
```

**Global API → Composables:**
```vue
<!-- Before (Options API) -->
<script>
export default {
  methods: {
    showModal() {
      this.$bvModal.show('my-modal')
    }
  }
}
</script>

<!-- After (Composition API) -->
<script setup lang="ts">
import { ref } from 'vue'

const modalOpen = ref(false)
const showModal = () => { modalOpen.value = true }
</script>

<template>
  <BModal v-model="modalOpen" title="My Modal">Content</BModal>
</template>
```

---

## Component Organization Strategy

### Grouping Principles

**By Feature/Domain:**
```
components/
├── tables/           # All table-related components
│   ├── TablesEntities.vue
│   ├── TablesGenes.vue
│   └── TablesPhenotypes.vue
├── analyses/         # All analysis components
│   ├── AnalyseGeneClusters.vue
│   └── AnalysesPhenotypeClusters.vue
├── small/           # Reusable UI components
│   ├── GenericTable.vue
│   ├── SearchBar.vue
│   └── Banner.vue
```

### Component Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Views | PascalCase + descriptive | `UserProfile.vue`, `EntitiesOverTime.vue` |
| Components | PascalCase + context | `TablesEntities.vue`, `AnalyseGeneClusters.vue` |
| Composables | camelCase + "use" prefix | `useColorAndSymbols.ts`, `useToast.ts` |
| Utils | camelCase + descriptive | `formatDate.ts`, `validateEmail.ts` |
| Types | PascalCase + interface/type | `interface User`, `type FilterObject` |

---

## TypeScript Integration Patterns

### Type Definitions Structure

```typescript
// types/models.ts - Data models
export interface User {
  user_id: number
  user_name: string
  user_role: UserRole[]
  abbreviation: string[]
  active_reviews: number
  active_status: number
}

export type UserRole = 'Viewer' | 'Reviewer' | 'Curator' | 'Administrator'

export interface Entity {
  entity_id: number
  hgnc_id: string
  gene_symbol: string
  category: Category
  ndd_phenotype: boolean
}

export type Category = 'Definitive' | 'Moderate' | 'Limited' | 'Refuted'
```

```typescript
// types/components.ts - Component-specific types
export interface FilterObject {
  [key: string]: string | number | boolean | null
}

export interface SortConfig {
  field: string
  order: 'asc' | 'desc'
}

export type ToastVariant = 'primary' | 'secondary' | 'success' | 'danger' | 'warning' | 'info'
```

---

## Migration Order & Strategy

### Phase 1: Foundation Setup
**Goal:** Establish TypeScript infrastructure without breaking existing code

1. **Add TypeScript configuration**
   - Install `typescript`, `@types/node`, `vue-tsc`
   - Create `tsconfig.json` with strict mode
   - Configure path aliases (`@/*` → `src/*`)

2. **Create type definition files**
   - `types/models.ts` - Core data models
   - `types/components.ts` - Component prop types
   - `types/api.ts` - API response types

3. **Rename entry point**
   - `main.js` → `main.ts`
   - Update build configuration

**Dependencies:** None
**Risk:** LOW - Additive changes only

---

### Phase 2: Migrate Constants & Services
**Goal:** Convert pure JavaScript logic to TypeScript

1. **Convert constants**
   - `assets/js/constants/*.js` → `constants/*.ts`
   - Add type annotations
   - Export as const assertions

2. **Convert services**
   - `assets/js/services/apiService.js` → `services/api.ts`
   - Add generic type support

**Dependencies:** Phase 1 complete
**Risk:** LOW - No Vue-specific changes

---

### Phase 3: Convert Mixins to Composables
**Goal:** Create composables alongside mixins for gradual migration

**Order of conversion (by dependency):**

1. **useColorAndSymbols** (no dependencies)
2. **useText** (no dependencies)
3. **useScrollbar** (no dependencies)
4. **useToast** (depends on Bootstrap-Vue-Next)
5. **useTableData** (depends on useColorAndSymbols, useText)
6. **useTableMethods** (depends on useTableData)
7. **useUrlParsing** (depends on Vue Router)

**Dependencies:** Phase 2 complete
**Risk:** MEDIUM - Changes component behavior

---

### Phase 4: Migrate Bootstrap-Vue to Bootstrap-Vue-Next
**Goal:** Update component library while maintaining functionality

1. **Install Bootstrap-Vue-Next**
2. **Update main.ts** - Replace imports
3. **Create migration checklist** - Audit all components
4. **Migrate components by category** - Forms, layout, content, modals

**Component migration priority:**
1. Small, independent components first
2. Shared components (high reuse)
3. Form components (critical functionality)
4. View-specific components last

**Dependencies:** Phase 3 in progress (can overlap)
**Risk:** HIGH - Visual and functional changes

---

### Phase 5: Convert Components to Composition API + TypeScript
**Goal:** Modernize all Vue components

**Migration order:**

1. **Leaf components** - `components/small/*.vue`
2. **Shared components** - `components/tables/*.vue`, `components/analyses/*.vue`
3. **View components** - Simple views first, complex forms last
4. **Layout components** - `Navbar.vue`, `Footer.vue` (last)

**Per-component checklist:**
- [ ] Add `lang="ts"` to script tag
- [ ] Replace `export default` with `<script setup>`
- [ ] Convert props to `defineProps<Props>()`
- [ ] Convert data() to `ref()` or `reactive()`
- [ ] Convert computed to `computed()`
- [ ] Replace mixins with composables
- [ ] Add explicit component imports
- [ ] Test component

**Dependencies:** Phases 3 & 4 complete
**Risk:** MEDIUM to HIGH depending on component complexity

---

### Phase 6: Clean Up Legacy Code
**Goal:** Remove unused code and finalize migration

1. **Remove mixins** - Delete `assets/js/mixins/` directory
2. **Remove global-components.js**
3. **Remove old JavaScript files**
4. **Optimize bundle** - Remove unused dependencies

**Dependencies:** Phase 5 complete
**Risk:** LOW - Only deleting unused code

---

## Data Flow Patterns

### State Management Architecture

```
┌─────────────────────────────────────────────────────┐
│                   User Interaction                   │
│                  (View Component)                    │
└───────────────────┬─────────────────────────────────┘
                    │
                    ↓
        ┌──────────────────────────┐
        │  Local Component State   │
        │  (ref, reactive, computed)│
        └───────────┬──────────────┘
                    │
        ┌───────────┴────────────┐
        │                        │
        ↓                        ↓
┌───────────────┐      ┌────────────────┐
│  Composables  │      │  Pinia Stores  │
│  (use*.ts)    │      │  (Global State)│
└───────┬───────┘      └────────┬───────┘
        │                       │
        └──────────┬────────────┘
                   │
                   ↓
         ┌─────────────────┐
         │     Services     │
         │   (API calls)    │
         └─────────┬────────┘
                   │
                   ↓
         ┌─────────────────┐
         │   Backend API    │
         │  (Plumber REST)  │
         └──────────────────┘
```

### When to Use Each Pattern

| Pattern | Use Case | Example |
|---------|----------|---------|
| **Local ref/reactive** | Component-only state | Form input values, UI toggles |
| **Composable** | Reusable logic across components | Table filtering, toast notifications |
| **Pinia Store** | Global app state | User authentication, app configuration |
| **Service** | API communication | HTTP requests, data transformation |
| **Utils** | Pure functions, no state | Date formatting, validation |

---

## Integration Points

### Vue Router 4 Integration

```typescript
// router/index.ts
import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'Home',
    component: () => import('@/views/Home.vue')
  },
  {
    path: '/entities',
    name: 'Entities',
    component: () => import('@/views/tables/EntitiesTable.vue'),
    meta: {
      requiresAuth: false,
      title: 'Gene-Disease Entities'
    }
  }
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
})

export default router
```

---

## Common Pitfalls & Solutions

### Pitfall 1: Forgetting .value with refs

**Problem:**
```typescript
const count = ref(0)
console.log(count) // { value: 0 } - not the number!
```

**Solution:**
```typescript
const count = ref(0)
console.log(count.value) // 0 - correct
```

### Pitfall 2: Bootstrap-Vue-Next v-model syntax

**Problem:**
```vue
<!-- Old Bootstrap-Vue -->
<b-form-input v-model="value" :state.sync="valid" />
```

**Solution:**
```vue
<!-- New Bootstrap-Vue-Next -->
<BFormInput v-model="value" v-model:state="valid" />
```

### Pitfall 3: Incorrect composable usage timing

**Problem:**
```typescript
export default {
  mounted() {
    const router = useRouter() // Error!
  }
}
```

**Solution:**
```vue
<script setup>
// Correct: at top level of script setup
const router = useRouter()

onMounted(() => {
  router.push('/')
})
</script>
```

---

## Performance Considerations

### Code Splitting Strategy

```typescript
// router/index.ts - Lazy load views
const routes = [
  {
    path: '/entities',
    component: () => import('@/views/tables/EntitiesTable.vue')
  }
]

// Component - Lazy load heavy components
const AnalyseGeneClusters = defineAsyncComponent(() =>
  import('@/components/analyses/AnalyseGeneClusters.vue')
)
```

---

## Migration Success Criteria

### Phase Completion Checklist

**Phase 1: Foundation**
- [ ] TypeScript compiles without errors
- [ ] All type definition files created
- [ ] Path aliases configured and working

**Phase 2: Constants & Services**
- [ ] All `.js` files converted to `.ts`
- [ ] Type annotations added
- [ ] No runtime errors

**Phase 3: Composables**
- [ ] All 7 composables created
- [ ] At least one component using each composable
- [ ] Tests written for each composable

**Phase 4: Bootstrap-Vue-Next**
- [ ] Bootstrap-Vue-Next installed
- [ ] All Bootstrap components rendering
- [ ] Forms functional with new v-model syntax

**Phase 5: Component Migration**
- [ ] 100% of components using `<script setup lang="ts">`
- [ ] No mixins in use
- [ ] All components have explicit imports

**Phase 6: Cleanup**
- [ ] Mixins directory deleted
- [ ] global-components.js deleted
- [ ] Old `.js` files removed

---

## References & Resources

### Official Documentation (HIGH Confidence)
- [Vue 3 Documentation](https://vuejs.org/)
- [Vue 3 Migration Guide](https://v3-migration.vuejs.org/)
- [Vue 3 Composition API](https://vuejs.org/guide/extras/composition-api-faq)
- [Vue 3 TypeScript](https://vuejs.org/guide/typescript/overview)
- [Vue 3 Composables](https://vuejs.org/guide/reusability/composables)
- [Bootstrap-Vue-Next Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/)
- [Bootstrap-Vue-Next Migration Guide](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/migration-guide)

### Migration Resources (HIGH-MEDIUM Confidence)
- [The Ultimate Guide to Vue 3 Composition API](https://www.oreateai.com/blog/the-ultimate-guide-to-vue-3-composition-api-from-principles-to-enterpriselevel-practices/4432f14c4e7be8398acde6d5d5762d58)
- [Vue 3 Best Practices](https://enterprisevue.dev/blog/vue-3-best-practices/)
- [Converting Mixins to Composables](https://www.thisdot.co/blog/converting-your-vue-2-mixins-into-composables-using-the-composition-api)
- [Vue 3 Migration Guide - Simform](https://medium.com/simform-engineering/a-comprehensive-vue-2-to-vue-3-migration-guide-a00501bbc3f0)
- [Migrating from Vue 2 to Vue3](https://medium.com/@dwgray/migrating-from-vue-2-to-vue3-and-why-im-sticking-with-bootstrap-vue-next-8609baa99c3a)

### Architecture & Best Practices
- [How to Efficiently Structure a Medium-Sized Vue 3 Project](https://medium.com/@mohandabdiche/building-efficient-frontends-a-vue-3-blueprint-for-modern-medium-sized-applications-671dd403ca62)
- [Vue 3 Project Structure](https://vue-faq.org/en/development/project-structure.html)
- [7 Best Practices for Structuring Large-Scale Vue.js Applications](https://medium.com/@alemrandev/7-best-practices-for-structuring-large-scale-vue-js-applications-cbf47beedb99)

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Vue 3 Architecture | HIGH | Official documentation verified, multiple authoritative sources |
| TypeScript Integration | HIGH | Official Vue TypeScript guide, established patterns |
| Composable Patterns | HIGH | Official composables guide, real-world examples |
| Bootstrap-Vue-Next | HIGH | Official migration guide, component-by-component mapping |
| Migration Strategy | HIGH | Multiple case studies, proven incremental approach |
| Directory Structure | MEDIUM | Community conventions vary, adapted to SysNDD context |

**Overall Migration Confidence:** HIGH

The architecture recommendations are based on official Vue.js documentation, Bootstrap-Vue-Next migration guides, and verified community best practices. The phased migration approach is proven in production environments and allows for incremental risk mitigation.
