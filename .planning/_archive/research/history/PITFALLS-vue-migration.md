# Domain Pitfalls: Vue 2.7 → Vue 3 + TypeScript + Bootstrap-Vue-Next Migration

**Domain:** Medical/Scientific Database Frontend Migration
**Project:** SysNDD (50+ components, 7 mixins, Bootstrap-Vue, Vue Router 3, Pinia)
**Researched:** 2026-01-22
**Confidence:** HIGH (verified with official docs and real-world migration case studies)

---

## Critical Pitfalls

Mistakes that cause rewrites, silent failures, or major production issues.

### Pitfall 1: Silent Failures from Removed Event Bus ($on, $off, $once)

**What goes wrong:** Components using `this.$root.$on()`, `this.$root.$emit()`, or custom event bus instances will fail silently at runtime. Events will not fire, leading to broken inter-component communication.

**Why it happens:** Vue 3 completely removed the `$on`, `$off`, and `$once` instance methods. Event bus patterns that worked in Vue 2 no longer exist in Vue 3's API.

**Consequences:**
- Modal dialogs don't open when triggered from other components
- Form submissions don't trigger validation in parent components
- Cross-component notifications silently fail
- Hard to debug because no errors are thrown, events just don't fire

**Prevention:**
1. **Audit phase:** Before migration, search codebase for `$on`, `$off`, `$once`, `$root.$emit` patterns
2. **Refactor options:**
   - Use props/emits for parent-child communication
   - Use Pinia stores for state-based coordination (you already have Pinia)
   - Use provide/inject for dependency injection
   - For rare cases needing event bus, use mitt or tiny-emitter library
3. **Test thoroughly:** Event-based communication is often in critical user flows (modals, forms, notifications)

**Detection:**
- Search for `\$root\.\$emit`, `\$root\.\$on`, `new Vue()` (event bus pattern)
- Console warnings in @vue/compat migration build
- Integration tests will fail if event-driven flows are covered

**Phase mapping:** Address in **Phase 1: Core Vue 3 Migration** - must fix before Bootstrap-Vue migration.

---

### Pitfall 2: Bootstrap-Vue Global Methods ($bvModal, $bvToast) Removed

**What goes wrong:** Calling `this.$bvModal.show()`, `this.$bvModal.hide()`, `this.$bvToast.toast()` will throw runtime errors. These global methods don't exist in Bootstrap-Vue-Next.

**Why it happens:** Bootstrap-Vue-Next follows Vue 3 patterns and replaces global instance methods with composables (`useModal()`, `useToast()`).

**Consequences:**
- Application crashes when trying to show modals programmatically
- Toast notifications fail completely
- Message boxes (msgBoxOk, msgBoxConfirm) throw errors

**Prevention:**
1. **Audit phase:** Search for `this.$bvModal`, `this.$bvToast`, `this.$bvToaster`
2. **Migration pattern:**
   ```vue
   <!-- OLD (Bootstrap-Vue) -->
   <script>
   export default {
     methods: {
       openModal() {
         this.$bvModal.show('my-modal')
       }
     }
   }
   </script>

   <!-- NEW (Bootstrap-Vue-Next with Options API) -->
   <script>
   import { useModal } from 'bootstrap-vue-next'

   export default {
     setup() {
       const { show, hide } = useModal()
       return { show, hide }
     },
     methods: {
       openModal() {
         this.show('my-modal')
       }
     }
   }
   </script>
   ```
3. **Note:** If staying with Options API, you'll need to mix `setup()` function with options - this is a valid Vue 3 pattern but requires understanding how to expose setup() returns to this context

**Detection:**
- Grep for `\$bvModal`, `\$bvToast`
- Runtime errors in browser console when modal/toast actions trigger
- Component-level smoke tests will catch these

**Phase mapping:** Address in **Phase 2: Bootstrap-Vue-Next Migration** - after Vue 3 core is stable.

---

### Pitfall 3: Array Mutation Watchers Silently Fail Without `deep: true`

**What goes wrong:** Watchers on arrays that worked in Vue 2 stop triggering when array items are mutated. Array.push(), .splice(), etc. will not trigger the watcher unless `deep: true` is set.

**Why it happens:** Vue 3 changed array watching behavior. The watcher callback only triggers when the entire array is replaced, not when items are mutated.

**Consequences:**
- UI doesn't update when table data is modified
- Computed properties depending on array state become stale
- Silent data inconsistencies between model and view
- Particularly problematic for `b-table` data arrays with in-place edits

**Prevention:**
1. **Audit phase:** Review all watchers on array properties
2. **Fix pattern:**
   ```javascript
   // OLD - may not work as expected in Vue 3
   watch: {
     tableData(newVal) {
       this.processData(newVal)
     }
   }

   // NEW - explicit deep watching
   watch: {
     tableData: {
       handler(newVal) {
         this.processData(newVal)
       },
       deep: true  // REQUIRED for mutation detection
     }
   }
   ```
3. **Alternative:** Use computed properties or switch to reactive() with Vue 3's fine-grained reactivity

**Detection:**
- Find all `watch:` declarations in components
- Test interactive features that modify arrays (table row edits, list management)
- Console warnings in @vue/compat with WATCH_ARRAY compatibility flag

**Phase mapping:** Address in **Phase 1: Core Vue 3 Migration** - reactivity system changes must be fixed early.

---

### Pitfall 4: TypeScript Mixin Hell - Type Conflicts and `this` Context Loss

**What goes wrong:** Adding TypeScript to 7 existing mixins creates type conflicts where properties from different mixins have incompatible types. The `this` context in components becomes untyped or incorrectly typed.

**Why it happens:** TypeScript can't properly infer types when multiple mixins merge into a component. The type system doesn't know which mixin properties exist on `this` at any given point.

**Consequences:**
- TypeScript errors on every `this.mixinProperty` access
- Loss of autocomplete and type safety
- Developers add `@ts-ignore` everywhere, defeating the purpose of TypeScript
- Refactoring becomes impossible due to lack of type tracking

**Prevention:**
1. **Don't add TypeScript to mixins directly** - this is a trap
2. **Migration strategy:**
   - **Phase A:** Migrate to Vue 3 first, keep mixins as plain JS
   - **Phase B:** Convert mixins to composables one-by-one
   - **Phase C:** Add TypeScript to composables (excellent TS support)

3. **Composable conversion pattern:**
   ```typescript
   // OLD: Mixin (poor TypeScript support)
   export default {
     data() {
       return { loading: false }
     },
     methods: {
       async fetchData(id) { ... }
     }
   }

   // NEW: Composable (excellent TypeScript support)
   export function useDataFetcher() {
     const loading = ref(false)

     async function fetchData(id: string): Promise<Data> {
       loading.value = true
       try {
         return await api.get(id)
       } finally {
         loading.value = false
       }
     }

     return { loading, fetchData }
   }
   ```

**Detection:**
- Count of `@ts-ignore` comments increases rapidly
- TypeScript compilation takes unusually long
- "Type 'X' is not assignable to type 'Y'" errors in mixin usage

**Phase mapping:**
- **Phase 1:** Migrate mixins as-is to Vue 3 (keep as JS)
- **Phase 3 or 4:** Convert mixins to composables (prerequisite for TypeScript)
- **Phase 5:** Add TypeScript incrementally

---

### Pitfall 5: b-table Filtering and Sorting Breaking Changes

**What goes wrong:** Custom filtering logic using `filter-included-fields` breaks. Sort events don't fire. Row selection emits different data structure.

**Why it happens:** Bootstrap-Vue-Next redesigned the b-table API with breaking changes to filtering, sorting, and selection events.

**Consequences:**
- Search/filter functionality stops working
- Sortable columns don't respond to clicks
- Row selection features break (multi-select, row actions)
- Medical data tables become unusable (critical for SysNDD)

**Prevention:**
1. **Audit all b-table instances** - you likely have many in a database app
2. **Breaking changes to address:**

   | Old (Bootstrap-Vue) | New (Bootstrap-Vue-Next) | Impact |
   |---------------------|--------------------------|--------|
   | `filter-included-fields` | Single `filterable` prop | Filtering logic rewrite |
   | `@sort-changed` | `@update:sort-by` | Event handler rename |
   | Primary `v-model` for items | Exposed `displayedItems()` function | Pagination/filtering data access |
   | `row-selected` event | New data structure + `row-unselected` | Selection handling rewrite |
   | `emptyfiltered` slot | `empty-filtered` slot | Template updates |

3. **Migration checklist per table:**
   - [ ] Update filter logic to new `filterable` prop
   - [ ] Rename sort event handlers
   - [ ] Replace v-model usage with displayedItems() if needed
   - [ ] Update row selection handlers for new event structure
   - [ ] Rename slots (emptyfiltered → empty-filtered)
   - [ ] Test with real data: filtering, sorting, selection, pagination

**Detection:**
- Grep for `<b-table` in codebase
- Inspect props/events on each instance
- Functional testing of all table features

**Phase mapping:** Address in **Phase 2: Bootstrap-Vue-Next Migration** - table migration is complex enough to be its own sub-phase.

---

## Moderate Pitfalls

Mistakes that cause delays, technical debt, or require significant rework.

### Pitfall 6: Vue Router 4 Asynchronous Navigation Trap

**What goes wrong:** Route parameters accessed in `created()` or `setup()` are sometimes undefined because navigation is now fully asynchronous. Code that worked synchronously in Vue Router 3 has race conditions in Vue Router 4.

**Why it happens:** Vue Router 4 made all navigation asynchronous (even synchronous-looking navigations). Components may render before route params are fully available.

**Consequences:**
- `this.$route.params.id` is undefined in created()
- Data fetching based on route params fails
- Race conditions in route-dependent component initialization

**Prevention:**
1. **Use watchers or onBeforeRouteUpdate:**
   ```javascript
   // PROBLEMATIC
   created() {
     this.loadData(this.$route.params.id)  // May be undefined
   }

   // SAFER
   watch: {
     '$route.params.id': {
       immediate: true,
       handler(id) {
         if (id) this.loadData(id)
       }
     }
   }
   ```

2. **Or use route guards:**
   ```javascript
   beforeRouteEnter(to, from, next) {
     next(vm => {
       vm.loadData(to.params.id)  // Guaranteed to have params
     })
   }
   ```

**Detection:**
- Search for `created()` + `this.$route.params`
- Test all routes with parameters (especially deep links)
- Console errors about undefined properties

**Phase mapping:** Address in **Phase 1: Core Vue 3 Migration** when upgrading Vue Router 3→4.

---

### Pitfall 7: Bootstrap 5 Utility Class Renames Breaking Styles

**What goes wrong:** Layout breaks because utility classes were renamed in Bootstrap 5. Left/right becomes start/end, card-deck is removed, form input groups have different structure.

**Why it happens:** Bootstrap 5 made breaking changes to utility classes for better internationalization (LTR/RTL support) and modern CSS patterns.

**Consequences:**
- Visual layout breaks across the app
- Forms look incorrect
- Cards/grid layouts misaligned
- Right-to-left language support issues

**Prevention:**
1. **Audit Bootstrap 4 class usage:**

   | Old (Bootstrap 4) | New (Bootstrap 5) | Search Pattern |
   |-------------------|-------------------|----------------|
   | `.ml-*`, `.mr-*` | `.ms-*`, `.me-*` (start/end) | `\bm[lr]-\d` |
   | `.pl-*`, `.pr-*` | `.ps-*`, `.pe-*` | `\bp[lr]-\d` |
   | `.text-left`, `.text-right` | `.text-start`, `.text-end` | `text-(left\|right)` |
   | `.float-left`, `.float-right` | `.float-start`, `.float-end` | `float-(left\|right)` |
   | `.no-gutters` | `.g-0` | `no-gutters` |
   | `.input-group-append` | Direct children | `input-group-append` |
   | `.close` | `.btn-close` | `\bclose\b` |
   | `data-*` attributes | `data-bs-*` | `data-toggle`, `data-dismiss` |

2. **Systematic replacement:**
   - Use find-replace with regex
   - Test visual appearance on every page
   - Check responsive breakpoints (xs/sm/md/lg/xl)

3. **Form validation changes:**
   - Review all forms using Bootstrap validation classes
   - Update `.was-validated` / `.needs-validation` usage
   - Test validation feedback display

**Detection:**
- Visual regression testing (screenshot comparison)
- Grep for old Bootstrap 4 class patterns
- Browser dev tools showing missing CSS classes

**Phase mapping:** Address in **Phase 2: Bootstrap-Vue-Next Migration** alongside component updates.

---

### Pitfall 8: @vue/compat Migration Build False Confidence

**What goes wrong:** Developers think migration is complete because app runs in @vue/compat mode, but @vue/compat masks problems that will break in production Vue 3.

**Why it happens:** @vue/compat is designed to make Vue 2 code "just work" temporarily, hiding breaking changes behind compatibility flags. Teams ship with @vue/compat still enabled.

**Consequences:**
- Larger bundle size (compat layer adds overhead)
- Runtime performance penalty
- Delayed discovery of real incompatibilities
- False sense of migration completion

**Prevention:**
1. **Treat @vue/compat as temporary scaffolding:**
   - Install → Fix errors → Fix warnings → Uninstall
   - Never ship to production with @vue/compat

2. **Systematic warning resolution:**
   ```javascript
   // Step 1: See all warnings
   app.config.compilerOptions.compatConfig = {
     MODE: 2  // Warn for all Vue 2 compatibility usage
   }

   // Step 2: Suppress fixed warnings to track progress
   app.config.compilerOptions.compatConfig = {
     MODE: 2,
     COMPONENT_V_MODEL: 'suppress-warning',  // After fixing all v-model
     INSTANCE_EVENT_EMITTER: 'suppress-warning'  // After fixing $on/$off
   }

   // Step 3: Remove @vue/compat entirely
   ```

3. **One exception with NO runtime warning:**
   - `<transition>` class names changed (v-enter → v-enter-from, etc.)
   - Must manually search for transition CSS classes
   - Search for: `.v-enter`, `.v-leave`, `.v-enter-active`, `.v-leave-active`

**Detection:**
- Check package.json for `@vue/compat` in dependencies
- Monitor bundle size (compat adds ~40-50KB)
- Console warning count

**Phase mapping:** Use in **Phase 1: Core Vue 3 Migration**, remove before Phase 2 starts.

---

### Pitfall 9: TypeScript defineComponent with Options API Edge Cases

**What goes wrong:** TypeScript types break when using `defineComponent()` with Options API, especially with TypeScript < 4.7. Arrow functions required in unexpected places, `this` context loses types.

**Why it happens:** TypeScript's type inference for `this` inside object methods is complex. Older TypeScript versions can't infer types correctly in prop validators/defaults with regular functions.

**Consequences:**
- Props validation functions have incorrect types
- Default prop values cause type errors
- Loss of autocomplete in component methods
- Developers disable TypeScript checking with `@ts-ignore`

**Prevention:**
1. **Require TypeScript 4.7+ minimum** - solves most inference issues

2. **Use arrow functions for prop options:**
   ```typescript
   // WRONG - may break type inference in TS < 4.7
   props: {
     book: {
       type: Object as PropType<Book>,
       default() {  // Regular function
         return { title: 'Default' }
       },
       validator(val) {  // Regular function
         return val.title.length > 0
       }
     }
   }

   // CORRECT - arrow functions for type safety
   props: {
     book: {
       type: Object as PropType<Book>,
       default: () => ({  // Arrow function
         title: 'Default'
       }),
       validator: (val: Book) => val.title.length > 0  // Arrow function
     }
   }
   ```

3. **Explicitly type event handlers:**
   ```typescript
   methods: {
     // WRONG - implicit any
     handleInput(event) {
       console.log(event.target.value)
     }

     // CORRECT - explicit type
     handleInput(event: Event) {
       console.log((event.target as HTMLInputElement).value)
     }
   }
   ```

4. **Consider Composition API for complex types:**
   - Options API has inherent TypeScript limitations
   - If TypeScript types are complex, Composition API is much better

**Detection:**
- TypeScript compilation errors in components
- Missing autocomplete in IDE
- Implicit `any` warnings if `noImplicitAny: true`

**Phase mapping:** Address in **Phase 5: TypeScript Introduction** - only after Vue 3 + Bootstrap-Vue-Next are stable.

---

### Pitfall 10: Vue Test Utils v2 Breaking Changes (destroy → unmount, localVue removed)

**What goes wrong:** All component tests break after upgrading to Vue Test Utils v2. `wrapper.destroy()` doesn't exist, `localVue` is removed, mounting options structure changed.

**Why it happens:** Vue Test Utils v2 was rewritten for Vue 3 with breaking API changes aligned to Vue 3's architecture.

**Consequences:**
- Entire test suite fails to run
- False confidence if tests aren't run during migration
- Delays in shipping due to test rewrites

**Prevention:**
1. **Key API migrations:**

   | Vue Test Utils v1 | Vue Test Utils v2 | Change Type |
   |-------------------|-------------------|-------------|
   | `wrapper.destroy()` | `wrapper.unmount()` | Method rename |
   | `propsData` option | `props` option | Mounting option rename |
   | `scopedSlots` option | `slots` option | Consolidation |
   | `stubs`, `mocks` at root | `global: { stubs, mocks }` | Structure change |
   | `createLocalVue()` | Removed (not needed) | API removal |

2. **Migration pattern:**
   ```javascript
   // OLD
   import { mount, createLocalVue } from '@vue/test-utils'
   const localVue = createLocalVue()

   const wrapper = mount(Component, {
     localVue,
     propsData: { id: '123' },
     stubs: { BModal: true },
     mocks: { $route: mockRoute }
   })
   wrapper.destroy()

   // NEW
   import { mount } from '@vue/test-utils'

   const wrapper = mount(Component, {
     props: { id: '123' },  // propsData → props
     global: {               // global wrapper
       stubs: { BModal: true },
       mocks: { $route: mockRoute }
     }
   })
   wrapper.unmount()  // destroy → unmount
   ```

3. **Test migration workflow:**
   - Update Vue Test Utils to v2
   - Fix mounting API changes (global wrapper)
   - Rename destroy → unmount
   - Remove createLocalVue usage
   - Run full test suite to catch edge cases

**Detection:**
- Run test suite - errors will be obvious
- Grep for `createLocalVue`, `.destroy()`, `propsData`
- Check package.json for @vue/test-utils version

**Phase mapping:** Address in **Phase 1: Core Vue 3 Migration** - fix tests immediately to maintain confidence during migration.

---

## Minor Pitfalls

Mistakes that cause annoyance but are fixable with low effort.

### Pitfall 11: Lifecycle Hook Renames (destroyed → unmounted)

**What goes wrong:** Cleanup code in `destroyed()` and `beforeDestroy()` hooks silently doesn't run because Vue 3 renamed them to `unmounted()` and `beforeUnmount()`.

**Why it happens:** Vue 3 aligned lifecycle hook names with mount/unmount terminology for consistency.

**Prevention:**
1. Search and replace:
   - `destroyed` → `unmounted`
   - `beforeDestroy` → `beforeUnmount`
2. Verify cleanup logic still runs (event listeners removed, timers cleared, etc.)

**Detection:**
- Grep for `destroyed`, `beforeDestroy`
- @vue/compat warnings (INSTANCE_DESTROYED flag)

**Phase mapping:** Quick fix in **Phase 1: Core Vue 3 Migration**.

---

### Pitfall 12: data Option Must Be a Function

**What goes wrong:** Components with `data: { ... }` (object syntax) throw runtime errors in Vue 3.

**Why it happens:** Vue 3 enforces the rule that `data` must be a function returning an object (was allowed but discouraged in Vue 2).

**Prevention:**
```javascript
// WRONG
data: {
  count: 0
}

// CORRECT
data() {
  return {
    count: 0
  }
}
```

**Detection:**
- Grep for `data:\s*{` (object after data:)
- Runtime errors during component initialization

**Phase mapping:** Quick fix in **Phase 1: Core Vue 3 Migration**.

---

### Pitfall 13: Transition Class Name Changes (No Runtime Warning!)

**What goes wrong:** CSS transitions stop working because class names changed from `v-enter`/`v-leave` to `v-enter-from`/`v-leave-from`.

**Why it happens:** Vue 3 made transition class names more explicit and consistent.

**Prevention:**
1. **This is the ONLY breaking change with NO runtime warning in @vue/compat**
2. Search and replace in CSS/SCSS:
   - `.v-enter` → `.v-enter-from`
   - `.v-leave` → `.v-leave-from`
   - `.v-enter-active`, `.v-leave-active` unchanged

**Detection:**
- Visual testing of all transitions
- Grep for `\.v-enter\b`, `\.v-leave\b` in stylesheets

**Phase mapping:** Fix in **Phase 1: Core Vue 3 Migration** alongside other CSS updates.

---

### Pitfall 14: Filters Removed ({{ value | filter }} no longer works)

**What goes wrong:** Template filters using pipe syntax (`{{ date | formatDate }}`) throw compilation errors.

**Why it happens:** Vue 3 removed the filter feature entirely in favor of methods or computed properties.

**Prevention:**
```vue
<!-- OLD -->
<template>
  {{ date | formatDate }}
</template>

<!-- NEW Option 1: Method -->
<template>
  {{ formatDate(date) }}
</template>
<script>
export default {
  methods: {
    formatDate(date) { ... }
  }
}
</script>

<!-- NEW Option 2: Computed -->
<template>
  {{ formattedDate }}
</template>
<script>
export default {
  computed: {
    formattedDate() {
      return this.formatDate(this.date)
    }
  }
}
</script>
```

**Detection:**
- Grep for `\|` in templates (watch for false positives)
- Compilation errors when running Vite/Webpack
- @vue/compat warnings (COMPILER_FILTERS flag)

**Phase mapping:** Fix in **Phase 1: Core Vue 3 Migration** - compiler will catch these.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **Phase 1: Core Vue 3 Migration** | Event bus removal, array watchers, router async navigation | Use @vue/compat to identify all issues, fix before proceeding |
| **Phase 2: Bootstrap-Vue-Next** | b-table API changes, $bvModal removal, Bootstrap 5 utility classes | Migrate one component type at a time (tables, modals, forms) |
| **Phase 3: Mixin to Composable** | TypeScript type conflicts if attempted too early | Keep as JS, convert to composables BEFORE adding TypeScript |
| **Phase 4: Testing Updates** | Vue Test Utils v2 API changes breaking all tests | Fix tests immediately in Phase 1 to maintain confidence |
| **Phase 5: TypeScript Introduction** | defineComponent() edge cases, Options API limitations | Use TypeScript 4.7+, consider Composition API for complex types |

---

## Pre-Migration Audit Checklist

Before starting the migration, run these searches to quantify risk:

### Event System
- [ ] `git grep "\$root\.\$emit"` - Event bus usage
- [ ] `git grep "\$root\.\$on"` - Event listeners
- [ ] `git grep "new Vue()" | grep -v node_modules` - Custom event buses

### Bootstrap-Vue Global Methods
- [ ] `git grep "\$bvModal"` - Modal global access
- [ ] `git grep "\$bvToast"` - Toast global access

### Vue 3 Breaking Changes
- [ ] `git grep "destroyed"` - Lifecycle hooks to rename
- [ ] `git grep "beforeDestroy"` - Lifecycle hooks to rename
- [ ] `git grep "data:\s*{"` - data objects to convert
- [ ] `git grep "\\\|" src/` - Template filters to remove

### Bootstrap 5 Class Changes
- [ ] `git grep "\\bm[lr]-[0-9]"` - Margin left/right classes
- [ ] `git grep "\\bp[lr]-[0-9]"` - Padding left/right classes
- [ ] `git grep "text-left\|text-right"` - Text alignment classes
- [ ] `git grep "float-left\|float-right"` - Float classes
- [ ] `git grep "data-toggle\|data-dismiss"` - Bootstrap 4 data attributes

### Bootstrap-Vue-Next Component Changes
- [ ] `git grep "<b-table"` - Tables needing API updates
- [ ] `git grep "<b-modal"` - Modals needing API updates
- [ ] `git grep "filter-included-fields"` - Table filter prop to update
- [ ] `git grep "@sort-changed"` - Sort event to update

### Router/State
- [ ] `git grep "created().*\$route.params"` - Async navigation risks
- [ ] `git grep "watch:.*{$"` - Array watchers needing deep: true

### Testing
- [ ] `git grep "createLocalVue"` - Vue Test Utils v1 API
- [ ] `git grep "wrapper.destroy()"` - Test teardown to update
- [ ] `git grep "propsData:"` - Mounting option to rename

---

## Confidence Assessment

| Pitfall Category | Confidence | Source |
|------------------|------------|--------|
| Vue 3 Core Breaking Changes | HIGH | Official Vue 3 Migration Guide, @vue/compat docs |
| Bootstrap-Vue-Next Changes | HIGH | Official Bootstrap-Vue-Next Migration Guide |
| TypeScript + Options API | HIGH | Official Vue TypeScript docs, real-world case studies |
| Vue Router 4 Changes | HIGH | Official Vue Router migration guide |
| Bootstrap 5 Changes | HIGH | Official Bootstrap 5 migration guide |
| Testing Changes | HIGH | Official Vue Test Utils v2 migration guide |

---

## Sources

**Vue 3 Migration:**
- [Vue 3 Migration Guide - Breaking Changes](https://v3-migration.vuejs.org/breaking-changes/)
- [Migration Build (@vue/compat) Official Guide](https://v3-migration.vuejs.org/migration-build.html)
- [Vue 3 Migration: Risks & Key Benefits](https://epicmax.co/vue-3-migration-guide)
- [Real-World Vue 3 Migration Challenges](https://medium.com/@karangandhi.dev/vue-2-to-vue-3-migration-real-world-challenges-and-fixes-952546966aff)
- [Vue 2 to 3 Migration: Lessons Learned](https://medium.com/@yeteryavan/vue-2-to-vue-3-migration-lessons-learned-and-strategies-implemented-cbeb40942b16)

**Bootstrap-Vue-Next:**
- [Bootstrap-Vue-Next Official Migration Guide](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/migration-guide)
- [Migrating to Bootstrap-Vue-Next (Medium)](https://medium.com/@dwgray/migrating-from-vue-2-to-vue3-and-why-im-sticking-with-bootstrap-vue-next-8609baa99c3a)

**TypeScript Integration:**
- [Vue.js Official TypeScript with Options API Guide](https://vuejs.org/guide/typescript/options-api)
- [Using Vue with TypeScript Official Guide](https://vuejs.org/guide/typescript/overview)
- [Vue 3 TypeScript Migration Pitfalls](https://dev.to/nikhilverma/from-vue-2-to-3-a-long-journey-58ff)

**Vue Router:**
- [Vue Router 4 Migration Guide](https://router.vuejs.org/guide/migration/)
- [Vue Router 4: Route Params Not Available Issue](https://www.vuemastery.com/blog/vue-router-4-route-params-not-available-on-created-setup/)

**Bootstrap 5:**
- [Bootstrap 5 vs Bootstrap 4 Breaking Changes](https://superdevresources.com/bootstrap5-vs-bootstrap4-whats-new/)
- [Official Bootstrap 5 Migration Guide](https://getbootstrap.com/docs/5.0/migration/)

**Testing:**
- [Vue Test Utils v2 Migration Guide](https://test-utils.vuejs.org/migration/)

**Mixins & Composition API:**
- [Vue 3 Options to Composition API Migration](https://dev.to/mikehtmlallthethings/vue-3-options-to-composition-api-migration-3567)
- [Composition API FAQ](https://vuejs.org/guide/extras/composition-api-faq.html)

---

## Summary

**Most Critical Risks for SysNDD Migration:**

1. **Silent failures** from removed event bus ($on/$off) - audit before starting
2. **b-table breakage** - database tables are core to medical apps, expect significant work
3. **$bvModal/$bvToast removal** - likely used throughout for user interactions
4. **TypeScript + mixins = pain** - convert mixins to composables BEFORE adding TypeScript
5. **@vue/compat false confidence** - use it to find problems, not to ship to production

**Recommended Phase Order Based on Pitfalls:**
1. Vue 3 core + Vue Router 4 + test suite fixes
2. Bootstrap-Vue-Next migration (tables, modals, forms separately)
3. Mixin to composable conversion
4. CSS/Bootstrap 5 utility class updates
5. TypeScript introduction (only after all above are stable)

**Do NOT attempt all at once.** The combination of Vue 3 + Bootstrap-Vue-Next + TypeScript simultaneously is a recipe for getting stuck debugging 3 different migration issues at the same time.
