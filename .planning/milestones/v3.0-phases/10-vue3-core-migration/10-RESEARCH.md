# Phase 10: Vue 3 Core Migration - Research

**Researched:** 2026-01-22
**Domain:** Vue 3 migration with @vue/compat, Vue Router 4, Pinia event bus replacement
**Confidence:** HIGH

## Summary

This research covers the technical requirements for migrating SysNDD from Vue 2.7.8 to Vue 3.5+ using the @vue/compat migration build. The audit identified 77 Vue components, 14 EventBus usages, 15 $root.$emit modal control patterns, 3 beforeDestroy lifecycle hooks, and several third-party library dependencies requiring attention.

The standard approach for Vue 3 migration is the "compat mode first" strategy: install Vue 3 with @vue/compat, get the application booting (ignore warnings initially), then systematically fix warnings API-by-API until zero compat warnings remain. This strategy is validated by Vue team documentation and real-world migrations of 250K+ LOC codebases.

**Primary recommendation:** Install Vue 3 + @vue/compat in MODE: 2 (Vue 2 compatibility mode), configure Vue CLI, verify app boots with warnings, then fix warnings by frequency. Complete all compat warning fixes before removing @vue/compat and proceeding to Phase 11.

## Standard Stack

The established libraries/tools for Vue 3 migration:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| vue | ^3.5.25 | Core framework | Current stable, required for Vue 3 features |
| @vue/compat | ^3.5.25 | Migration build | Official Vue team migration tool |
| vue-router | ^4.6+ | Routing | Vue Router 4 is required for Vue 3 |
| pinia | ^2.0.14 (existing) | State management | Already in use, verify compatibility |
| @vue/compiler-sfc | ^3.5.25 | SFC compiler | Replaces vue-template-compiler |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| vue3-perfect-scrollbar | ^2.0.0 | Scrollbar component | Replaces vue2-perfect-scrollbar |
| @unhead/vue | ^2.x | Head management | Replaces vue-meta in Vue 3 (defer to later phase) |
| @zanmato/vue3-treeselect or megafetis/vue3-treeselect | latest | Tree select | Replaces @riophae/vue-treeselect (defer to Phase 11) |

### Packages to Remove
| Package | Reason |
|---------|--------|
| @vue/composition-api | Built into Vue 3 |
| vue-template-compiler | Replaced by @vue/compiler-sfc |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Pinia for events | mitt library | mitt is simpler but loses traceability; Pinia aligns with CONTEXT.md decision |
| @vue/compat | Direct Vue 3 | Direct would require fixing all issues upfront; compat enables incremental migration |

**Installation:**
```bash
npm install vue@^3.5.25 @vue/compat@^3.5.25 vue-router@^4.6
npm install -D @vue/compiler-sfc@^3.5.25
npm uninstall vue-template-compiler @vue/composition-api
```

## Architecture Patterns

### Vue 3 Initialization Pattern (main.js)

```javascript
// NEW: Vue 3 with @vue/compat
import { createApp, configureCompat } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'

// Configure compat mode globally
configureCompat({
  MODE: 2  // Vue 2 compatibility mode - shows all warnings
})

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.mount('#app')
```

### Vue Router 4 Migration Pattern

```javascript
// OLD (Vue Router 3)
import Vue from 'vue'
import VueRouter from 'vue-router'
Vue.use(VueRouter)

const router = new VueRouter({
  mode: 'history',
  base: process.env.BASE_URL,
  routes
})

// NEW (Vue Router 4)
import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(process.env.BASE_URL),
  routes
})
```

### Event Bus Replacement with Pinia

The codebase uses two event patterns that need replacement:

**Pattern 1: Custom EventBus for scrollbar updates (14 usages)**
```javascript
// OLD: EventBus pattern
// src/assets/js/eventBus.js
import Vue from 'vue'
const EventBus = new Vue()
export default EventBus

// Emitting component
EventBus.$emit('update-scrollbar')

// Listening component (App.vue)
created() {
  EventBus.$on('update-scrollbar', this.updateScrollbar)
},
beforeDestroy() {
  EventBus.$off('update-scrollbar', this.updateScrollbar)
}

// NEW: Pinia store for UI state
// src/stores/ui.js
import { defineStore } from 'pinia'

export const useUiStore = defineStore('ui', {
  state: () => ({
    scrollbarUpdateTrigger: 0  // Increment to trigger update
  }),
  actions: {
    requestScrollbarUpdate() {
      this.scrollbarUpdateTrigger++
    }
  }
})

// Emitting component
import { useUiStore } from '@/stores/ui'
const uiStore = useUiStore()
uiStore.requestScrollbarUpdate()

// Listening component (App.vue) - Options API
import { useUiStore } from '@/stores/ui'
import { mapState } from 'pinia'

export default {
  computed: {
    ...mapState(useUiStore, ['scrollbarUpdateTrigger'])
  },
  watch: {
    scrollbarUpdateTrigger() {
      this.updateScrollbar()
    }
  }
}
```

**Pattern 2: $root.$emit for Bootstrap-Vue modal control (15 usages)**
```javascript
// OLD: $root.$emit pattern
this.$root.$emit('bv::show::modal', 'modal-id', button)
this.$root.$emit('bv::hide::modal', 'modal-id')

// TEMPORARY: Keep during Phase 10 (Bootstrap-Vue still in use)
// These patterns work with @vue/compat INSTANCE_EVENT_EMITTER flag
// Will be replaced in Phase 11 with Bootstrap-Vue-Next v-model pattern

// Phase 11 replacement pattern:
const modalVisible = ref(false)
modalVisible.value = true  // Show modal
modalVisible.value = false // Hide modal
```

### Lifecycle Hook Rename Pattern

```javascript
// OLD
export default {
  beforeDestroy() {
    clearInterval(this.interval)
  }
}

// NEW
export default {
  beforeUnmount() {
    clearInterval(this.interval)
  }
}
```

### Watcher Deep Option Pattern

```javascript
// OLD - may not trigger on array mutations in Vue 3
watch: {
  tableData(newVal) {
    this.processData(newVal)
  }
}

// NEW - explicit deep watching for arrays
watch: {
  tableData: {
    handler(newVal) {
      this.processData(newVal)
    },
    deep: true  // REQUIRED for mutation detection
  }
}
```

### Anti-Patterns to Avoid
- **Skipping compat mode:** Direct Vue 3 migration without @vue/compat leads to fixing everything at once
- **Suppressing warnings too early:** Keep all warnings visible until systematically fixed
- **Shipping with @vue/compat:** It adds ~40-50KB bundle size; must be removed before Phase 11
- **Mixing mitt and Pinia:** Per CONTEXT.md, use Pinia stores only for event replacement

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Event bus replacement | Custom event emitter | Pinia stores | Better debugging, traceability, per CONTEXT.md |
| Router async param access | Synchronous created() access | Watch with immediate: true | Router 4 navigation is always async |
| Modal state management | Manual show/hide tracking | Vue 3 v-model on modals | Native Vue 3 pattern, will use in Phase 11 |
| Scrollbar communication | Direct DOM manipulation | Pinia state + watcher | Declarative, works with Vue reactivity |

**Key insight:** The @vue/compat migration build handles most compatibility automatically. Let it do its job rather than trying to fix everything manually before installation.

## Common Pitfalls

### Pitfall 1: Event Bus Silent Failures
**What goes wrong:** Components using `EventBus.$on()` or `this.$root.$on()` fail silently - events don't fire, no errors thrown.
**Why it happens:** Vue 3 completely removed `$on`, `$off`, `$once` instance methods.
**How to avoid:** The @vue/compat migration build provides INSTANCE_EVENT_EMITTER compatibility flag. Events will work but emit warnings. Replace with Pinia before removing @vue/compat.
**Warning signs:** Scrollbar doesn't update after data load, modals don't open.

### Pitfall 2: Array Watcher Not Triggering
**What goes wrong:** Watchers on arrays stop triggering when items are mutated via push(), splice(), etc.
**Why it happens:** Vue 3 watchers only trigger on array replacement by default, not mutation.
**How to avoid:** Add `deep: true` to all array watchers identified in audit (21 watchers to review).
**Warning signs:** Tables don't update after data modification, @vue/compat WATCH_ARRAY warning.

### Pitfall 3: Vue Router Async Navigation
**What goes wrong:** `this.$route.params.id` is undefined in `created()` hook.
**Why it happens:** Vue Router 4 navigation is fully asynchronous.
**How to avoid:** Use watcher with `immediate: true` or route guards.
**Warning signs:** Data fetching fails on direct URL access or page refresh.

### Pitfall 4: @vue/compat False Confidence
**What goes wrong:** App runs in compat mode, team thinks migration is complete, ships with @vue/compat.
**Why it happens:** @vue/compat makes Vue 2 code "just work" by hiding incompatibilities.
**How to avoid:** Track warning count, fix all warnings to zero, remove @vue/compat before Phase 11.
**Warning signs:** Bundle size 40-50KB larger than expected, console still shows compat warnings.

### Pitfall 5: Third-Party Library Warnings
**What goes wrong:** Console flooded with warnings from Bootstrap-Vue, vue-treeselect, vue-meta.
**Why it happens:** These libraries use Vue 2 internal APIs that @vue/compat flags.
**How to avoid:** Per CONTEXT.md, document these warnings but don't fix until their respective phases. Focus on fixing SysNDD code warnings first.
**Warning signs:** Hard to track progress when third-party warnings dominate console.

### Pitfall 6: Transition Class Names (No Runtime Warning!)
**What goes wrong:** CSS transitions stop working.
**Why it happens:** Class names changed from `v-enter`/`v-leave` to `v-enter-from`/`v-leave-from`. This is the ONLY breaking change with no @vue/compat runtime warning.
**How to avoid:** Search CSS/SCSS for `.v-enter`, `.v-leave` patterns; update to `-from` suffix.
**Warning signs:** Visual transitions don't animate.

## Code Examples

### Vue CLI Configuration for @vue/compat

```javascript
// vue.config.js
module.exports = {
  chainWebpack: (config) => {
    config.resolve.alias.set('vue', '@vue/compat')
    config.module
      .rule('vue')
      .use('vue-loader')
      .tap((options) => {
        return {
          ...options,
          compilerOptions: {
            compatConfig: {
              MODE: 2  // Vue 2 mode - maximum compatibility
            }
          }
        }
      })
  }
}
```

### Pinia UI Store for Scrollbar Events

```javascript
// src/stores/ui.js
import { defineStore } from 'pinia'

export const useUiStore = defineStore('ui', {
  state: () => ({
    // Counter pattern: increment triggers watchers
    scrollbarUpdateTrigger: 0
  }),

  actions: {
    /**
     * Request scrollbar update across the application
     * Replaces EventBus.$emit('update-scrollbar')
     */
    requestScrollbarUpdate() {
      this.scrollbarUpdateTrigger++
    }
  }
})
```

### App.vue Scrollbar Listener Migration

```javascript
// OLD
import EventBus from '@/assets/js/eventBus'

export default {
  created() {
    EventBus.$on('update-scrollbar', this.updateScrollbar)
  },
  beforeDestroy() {
    EventBus.$off('update-scrollbar', this.updateScrollbar)
  }
}

// NEW
import { useUiStore } from '@/stores/ui'
import { mapState } from 'pinia'

export default {
  computed: {
    ...mapState(useUiStore, ['scrollbarUpdateTrigger'])
  },
  watch: {
    scrollbarUpdateTrigger: {
      handler() {
        this.updateScrollbar()
      }
      // No need for immediate: true - only react to changes
    }
  },
  beforeUnmount() {
    // No manual cleanup needed - Pinia handles this
  }
}
```

### Component Emitting Scrollbar Update

```javascript
// OLD
import EventBus from '@/assets/js/eventBus'

methods: {
  async loadData() {
    await this.fetchFromApi()
    EventBus.$emit('update-scrollbar')
  }
}

// NEW
import { useUiStore } from '@/stores/ui'

methods: {
  async loadData() {
    await this.fetchFromApi()
    const uiStore = useUiStore()
    uiStore.requestScrollbarUpdate()
  }
}
```

### Vue Router 4 Migration (router/index.js)

```javascript
// OLD
import Vue from 'vue'
import VueRouter from 'vue-router'

Vue.use(VueRouter)

const { routes } = require('./routes')

const router = new VueRouter({
  mode: 'history',
  base: process.env.BASE_URL,
  routes,
})

export default router

// NEW
import { createRouter, createWebHistory } from 'vue-router'
import { routes } from './routes'

const router = createRouter({
  history: createWebHistory(process.env.BASE_URL),
  routes
})

export default router
```

### Catch-All Route Update (routes.js)

```javascript
// OLD
{
  path: '*',
  component: () => import('@/views/PageNotFound.vue'),
}

// NEW
{
  path: '/:pathMatch(.*)*',
  name: 'NotFound',
  component: () => import('@/views/PageNotFound.vue'),
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `new Vue()` for event bus | Pinia stores or mitt | Vue 3.0 (2020) | Must replace all event bus patterns |
| `new VueRouter()` | `createRouter()` | Vue Router 4 (2020) | API change only, same concepts |
| `mode: 'history'` | `createWebHistory()` | Vue Router 4 (2020) | Function-based history modes |
| `destroyed` lifecycle | `unmounted` lifecycle | Vue 3.0 (2020) | Simple rename |
| vue-template-compiler | @vue/compiler-sfc | Vue 3.0 (2020) | Different package, auto-handled |
| @vue/composition-api | Built into Vue 3 | Vue 3.0 (2020) | Remove dependency |
| PiniaVuePlugin | createPinia() | Pinia 2.0 (Vue 3) | Different initialization |

**Deprecated/outdated:**
- **vue-meta:** Replaced by @unhead/vue (defer migration to later phase, vue-meta may work with @vue/compat)
- **@riophae/vue-treeselect:** Use @zanmato/vue3-treeselect or megafetis/vue3-treeselect (defer to Phase 11)
- **vue2-perfect-scrollbar:** Use vue3-perfect-scrollbar (migrate in Phase 10)

## Open Questions

Things that couldn't be fully resolved:

1. **vue-meta compatibility with @vue/compat**
   - What we know: vue-meta is designed for Vue 2, @unhead/vue is the Vue 3 replacement
   - What's unclear: Whether vue-meta works at all with @vue/compat or fails immediately
   - Recommendation: Try keeping vue-meta initially; if it fails, stub it out and defer to Phase 14 or later

2. **vue-treeselect behavior with @vue/compat**
   - What we know: @riophae/vue-treeselect is Vue 2 only, several Vue 3 forks exist
   - What's unclear: Whether it will work at all during @vue/compat phase
   - Recommendation: Test during 10-02; if broken, either stub or replace immediately

3. **Bootstrap-Vue modal $root.$emit during compat**
   - What we know: INSTANCE_EVENT_EMITTER flag should enable these
   - What's unclear: Whether Bootstrap-Vue internal event handling works correctly
   - Recommendation: Verify modals work after initial boot; these stay until Phase 11

4. **vee-validate 3.x compatibility**
   - What we know: vee-validate 3.x was designed for Vue 2, version 4.x supports Vue 3
   - What's unclear: Whether vee-validate 3.4.14 works with @vue/compat
   - Recommendation: Test during 10-02; may need update to vee-validate 4.x

## Sources

### Primary (HIGH confidence)
- [Vue 3 Migration Build Official Guide](https://v3-migration.vuejs.org/migration-build) - @vue/compat configuration, feature flags
- [Vue 3 Breaking Changes](https://v3-migration.vuejs.org/breaking-changes/) - Complete list of breaking changes
- [Vue Router 4 Migration Guide](https://router.vuejs.org/guide/migration/) - Router API changes
- [Vue 3 Events API Migration](https://v3-migration.vuejs.org/breaking-changes/events-api) - $on/$off/$once removal

### Secondary (MEDIUM confidence)
- [Vue 3 v-model Changes](https://v3-migration.vuejs.org/breaking-changes/v-model) - Component v-model migration
- [Replacing Event Bus with Pinia](https://ryansereno.com/vue-event-bus) - Pinia event replacement pattern
- [vue3-perfect-scrollbar GitHub](https://github.com/mercs600/vue3-perfect-scrollbar) - Scrollbar replacement
- [Pinia Official Documentation](https://pinia.vuejs.org/) - Store patterns

### Tertiary (LOW confidence - verify during implementation)
- vue-meta compatibility with @vue/compat - needs runtime testing
- vue-treeselect alternatives - multiple forks with varying maintenance
- vee-validate 3.x compat mode support - needs runtime testing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Vue documentation covers all core libraries
- Architecture patterns: HIGH - Patterns verified with Vue 3 Migration Guide
- Event bus replacement: HIGH - Official Vue guidance plus Pinia docs
- Third-party libraries: MEDIUM - vue-meta, vue-treeselect need runtime verification
- Pitfalls: HIGH - Documented in official migration guide and real-world case studies

**Research date:** 2026-01-22
**Valid until:** 2026-03-22 (60 days - Vue 3 migration patterns are stable)

---

## Phase 10 Specific Migration Targets

Based on the pre-migration audit (10-01-PLAN.md):

### Files Requiring Immediate Attention (Phase 10)

| File | Changes Required |
|------|------------------|
| `src/assets/js/eventBus.js` | Delete entirely, replace with Pinia store |
| `src/main.js` | Vue 3 createApp, createPinia, remove PiniaVuePlugin |
| `src/router/index.js` | createRouter, createWebHistory |
| `src/router/routes.js` | Remove Vue.use(), update catch-all route |
| `src/App.vue` | Replace EventBus listener with Pinia watcher, rename beforeDestroy |
| `src/views/User.vue` | Rename beforeDestroy to beforeUnmount |
| `src/components/small/LogoutCountdownBadge.vue` | Rename beforeDestroy to beforeUnmount |

### Files with EventBus.$emit (replace with Pinia action call)

13 files total - see 10-01-PLAN.md for complete list. All emit single event `update-scrollbar`.

### Files with $root.$emit (keep until Phase 11)

6 files with 15 usages for Bootstrap-Vue modal control. These will work with @vue/compat INSTANCE_EVENT_EMITTER flag and will be replaced during Bootstrap-Vue-Next migration in Phase 11.

### Configuration Files to Create/Modify

| File | Purpose |
|------|---------|
| `vue.config.js` | Add @vue/compat alias and compilerOptions |
| `package.json` | Update dependencies |
| `src/stores/ui.js` | New Pinia store for UI state/events |
