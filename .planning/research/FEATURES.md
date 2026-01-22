# Feature Landscape: Vue 3 + TypeScript Migration

**Domain:** Vue 2.7 to Vue 3 + TypeScript + Bootstrap-Vue-Next migration
**Project:** SysNDD (medical/scientific database application)
**Researched:** 2026-01-22

---

## Executive Summary

Vue 3 migrations are characterized by **mandatory breaking changes** (table stakes) and **optional modernization opportunities** (differentiators). For SysNDD's 50+ component codebase with 7 mixins, Bootstrap-Vue dependency, and D3/GSAP visualizations, success depends on:

1. **Breaking change compatibility** - Handling removed APIs, v-model changes, router updates
2. **Component library migration** - Bootstrap-Vue → Bootstrap-Vue-Next (or alternative)
3. **Composition API adoption** - Converting Options API and mixins to composables
4. **TypeScript integration** - Adding type safety to untyped JavaScript codebase
5. **Testing infrastructure** - Establishing Vitest + Vue Test Utils foundation

**Key insight:** Migration features are NOT optional. The challenge is choosing *how* to implement them (incremental vs full rewrite, Options API vs Composition API, TypeScript strictness level).

---

## Table Stakes Features

Features that **must** be implemented for a Vue 3 migration to function. Missing these = broken application.

### 1. Vue 3 Core Breaking Changes Resolution

**Why expected:** Vue 3 removed/changed APIs that Vue 2 code depends on. Non-negotiable compatibility requirement.

| Breaking Change | Complexity | Migration Path | Notes |
|----------------|------------|----------------|-------|
| `this.$set` / `this.$delete` removed | Low | Use direct assignment with Vue 3 reactivity | Vue 3 reactivity auto-tracks deep changes |
| Event bus pattern (`$on`, `$off`, `$emit`) | Medium | Replace with mitt library or Pinia state | 7 mixins may use event bus |
| Filters removed (e.g. `{{ value \| filter }}`) | Low | Convert to methods or computed properties | Text formatting only |
| `v-model` behavior change | Medium | Update component bindings | Affects form components heavily |
| Functional components syntax change | Low | Rewrite as `<script setup>` | If any functional components exist |
| Async component API change | Low | Update `defineAsyncComponent()` syntax | Affects lazy-loaded routes |

**Sources:**
- [Vue 3 Migration Guide - Breaking Changes](https://v3-migration.vuejs.org/breaking-changes/)
- [Vue 3 Migration Build](https://v3-migration.vuejs.org/migration-build.html)

**Confidence:** HIGH (official documentation, well-documented)

---

### 2. Vue Router 4 Migration

**Why expected:** Vue Router 3 is incompatible with Vue 3. Router 4 is required.

| Breaking Change | Complexity | Migration Impact | Notes |
|----------------|------------|------------------|-------|
| `new Router()` → `createRouter()` | Low | Single file change (router/index.js) | Instantiation API change |
| `mode: 'history'` → `createWebHistory()` | Low | History mode API change | Hash mode: `createWebHashHistory()` |
| `router.currentRoute` returns Ref | Low | Access via `.value` if used directly | Rare in practice |
| `router.onReady()` → `router.isReady()` | Low | Returns Promise instead of callback | Affects App.vue initialization |
| All navigations async | Medium | Await navigation guards properly | May affect sequential routing logic |
| `router.go()` no return value | Low | Don't rely on return value | Rarely used |
| ScrollBehavior `x`/`y` → `left`/`top` | Low | Rename properties | If custom scroll behavior exists |
| `<router-view>` v-slot API change | Medium | Update scoped slot syntax | Affects nested routes |

**Sources:**
- [Vue Router 4 Migration Guide](https://router.vuejs.org/guide/migration/)
- [Vue Router 4 Breaking Changes Discussion](https://github.com/vuejs/router/discussions/1975)

**Confidence:** HIGH (official documentation)

**SysNDD Impact:** 708 lines in routes.js with lazy loading. Expect ~50 lines of changes.

---

### 3. Bootstrap-Vue → Bootstrap-Vue-Next Component Migration

**Why expected:** Bootstrap-Vue has NO Vue 3 support. Bootstrap-Vue-Next is the only Vue 3 port.

| Component | Change Required | Complexity | Notes |
|-----------|----------------|------------|-------|
| `<b-table>` | API changes in 0.42.0+ | High | Server-side provider function syntax updated |
| `<b-form-input>` | `v-model` prop changes | Medium | Vue 3 `modelValue` pattern |
| `<b-modal>` | Event name changes | Medium | `@show` → `@show.once` patterns |
| `<b-nav>` / `<b-navbar>` | Minimal changes | Low | Mostly compatible |
| `<b-button>` | Minimal changes | Low | Mostly compatible |
| `<b-badge>` | Minimal changes | Low | Mostly compatible |
| `<b-card>` | Minimal changes | Low | Mostly compatible |
| Directional props | `left`/`right` → `start`/`end` | Low | Bootstrap 5 RTL support |
| `BFormFile` | Complete rewrite (VueUse) | Medium | Modern file upload, new API |

**Sources:**
- [Bootstrap-Vue-Next Migration Guide](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/migration-guide)
- [Bootstrap-Vue-Next Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs)

**Confidence:** MEDIUM (bootstrap-vue-next still 0.x alpha, API changes ongoing)

**SysNDD Impact:** Heavy BTable usage in `TablesEntities.vue`, `TablesGenes.vue`, `TablesPhenotypes.vue`, `TablesLogs.vue`. Forms in `CreateEntity.vue`, `ModifyEntity.vue`.

**Risk:** Bootstrap-Vue-Next is alpha (0.42.0). Breaking changes may occur in future releases. Mitigation: pin version, contribute fixes upstream.

---

### 4. Deprecated Dependencies Replacement

**Why expected:** Vue 2 ecosystem packages are incompatible with Vue 3.

| Dependency | Vue 2 Version | Vue 3 Replacement | Complexity | Notes |
|------------|---------------|-------------------|------------|-------|
| `@vue/composition-api` | 1.7.0 | Remove (native in Vue 3) | Low | Backport no longer needed |
| `vue-meta` | 2.4.0 | `@unhead/vue` or native `useHead` | Medium | SEO/meta tags management |
| `vue-axios` | 3.4.1 | Native Axios + composables | Low | Wrapper not needed |
| `vue2-perfect-scrollbar` | 1.5.56 | Alternative (OverlayScrollbars-Vue) | Medium | Custom scrollbar styling |
| `vee-validate` | 3.4.14 | VeeValidate 4.x (Vue 3 compatible) | High | Form validation, major API change |
| `@riophae/vue-treeselect` | 0.4.0 | Check Vue 3 compatibility or replace | Medium | Ontology hierarchy selection |
| `bootstrap-vue` | 2.21.2 | `bootstrap-vue-next` 0.42+ | High | Component library (covered above) |

**Sources:**
- [Vue 3 Migration Guide - Deprecated Packages](https://v3-migration.vuejs.org/)
- [VeeValidate 4.x Migration](https://vee-validate.logaretm.com/v4/guide/migration/)

**Confidence:** HIGH (official package documentation)

**SysNDD Impact:** `vee-validate` used in forms (curation workflows). `vue-treeselect` used for phenotype/ontology selection.

---

### 5. Build Tooling Modernization

**Why expected:** Vue CLI is in maintenance mode. Vite is the recommended build tool for Vue 3.

| Tool | Current | Target | Complexity | Impact |
|------|---------|--------|------------|--------|
| Build tool | Vue CLI 5 + Webpack 5 | Vite 6 | Medium | 10x faster dev server, ESM-native |
| Config file | `vue.config.js` | `vite.config.ts` | Medium | Complete config rewrite |
| Environment variables | `VUE_APP_*` | `VITE_*` | Low | Rename in `.env` files |
| Public assets | `public/` | `public/` | Low | No change (compatible) |
| Static imports | Webpack loaders | Vite plugins | Medium | PurgeCSS, sitemap generation |
| Template compiler | `vue-template-compiler` | Built into Vue 3 | Low | Remove dependency |
| HMR (Hot Module Reload) | Webpack HMR | Vite HMR (faster) | Low | Automatic improvement |

**Sources:**
- [Vite Guide](https://vite.dev/guide/)
- [Vue CLI to Vite Migration](https://vitejs.dev/guide/migration.html)

**Confidence:** HIGH (official Vite documentation)

**SysNDD Impact:** Current Webpack config has PurgeCSS, PWA plugin, sitemap generation, bundle analyzer. Need Vite equivalents.

---

### 6. Pinia State Management Updates

**Why expected:** Pinia 2.0.14 is Vue 2 compatible but needs minor updates for Vue 3.

| Change | Complexity | Notes |
|--------|------------|-------|
| Import from `pinia` (not `@pinia/vue2`) | Low | Package name change |
| `createPinia()` in main.ts | Low | Instantiation unchanged |
| Store composition API compatibility | Low | Already using Composition API style |
| TypeScript support improvement | Low | Better inference in Vue 3 |

**Sources:**
- [Pinia Migration Guide](https://pinia.vuejs.org/cookbook/migration-vuex.html)

**Confidence:** HIGH (SysNDD already using Pinia, minimal changes needed)

**SysNDD Impact:** Pinia already adopted in v1. Migration is straightforward.

---

## Differentiators

Features that set a **modern, well-executed** Vue 3 migration apart from a minimal "just make it work" migration.

### 1. Composition API + `<script setup>` Adoption

**Value proposition:** Better code organization, improved TypeScript inference, reduced boilerplate.

| Feature | Complexity | When to Use | Notes |
|---------|------------|-------------|-------|
| Convert Options API → Composition API | Medium | All new components | Extract reusable logic |
| Use `<script setup>` syntax | Low | All new components | Reduces boilerplate (no return object) |
| Keep Options API | Low | Simple view components | Mixed approach acceptable |
| Hybrid approach (both APIs in codebase) | Low | During migration | Incremental adoption path |

**Sources:**
- [Vue 3 Composition API FAQ](https://vuejs.org/guide/extras/composition-api-faq.html)
- [Options API vs Composition API](https://vueschool.io/articles/vuejs-tutorials/options-api-vs-composition-api/)

**Confidence:** HIGH (official Vue recommendation for new code)

**SysNDD Recommendation:** Hybrid approach. Convert during component refactoring, not as separate pass. Prioritize components with shared logic first.

**Effort estimate:** ~30% of components benefit significantly (analyses, tables). ~70% can remain Options API without penalty.

---

### 2. Mixin → Composable Refactoring

**Value proposition:** Eliminate mixin pain points (unclear property sources, namespace collisions, implicit coupling).

| Pattern | Complexity | Benefit | Notes |
|---------|------------|---------|-------|
| Extract mixin logic to composable function | Medium | Explicit imports, no collisions | Return reactive values |
| Use `vue-mixable` for gradual migration | Low | Automated wrapper function | Temporary bridge |
| Convert to Composition API in consuming components | Medium | Full benefits of Composition API | Required for composable use |

**Sources:**
- [Vue Composables Guide](https://vuejs.org/guide/reusability/composables.html)
- [Converting Mixins to Composables](https://www.thisdot.co/blog/converting-your-vue-2-mixins-into-composables-using-the-composition-api)
- [vue-mixable library](https://github.com/LinusBorg/vue-mixable)

**Confidence:** HIGH (official Vue pattern, community consensus)

**SysNDD Impact:** 7 mixins currently. Likely candidates:
- Authentication state mixin
- Table pagination mixin
- Form validation mixin
- API request mixin

**Effort estimate:** ~1-2 days per mixin (extract → test → update consuming components).

---

### 3. TypeScript Adoption

**Value proposition:** Catch errors at compile time, improve IDE experience, document data shapes.

| Feature | Complexity | Strictness Level | Notes |
|---------|------------|------------------|-------|
| `.vue` files with TypeScript `<script lang="ts">` | Low | Baseline | SFC TypeScript support |
| Prop type definitions (`defineProps<T>()`) | Low | Component contracts | Better than PropTypes |
| API response type definitions | Medium | Data shape safety | 21 API endpoints to type |
| Store typing (Pinia) | Low | State management safety | Pinia has excellent TS support |
| `strict: true` in tsconfig | High | Maximum safety | Requires all types defined |
| `strict: false` with gradual adoption | Low | Incremental approach | Allow `any` during migration |

**Sources:**
- [Vue 3 TypeScript with Composition API](https://vuejs.org/guide/typescript/composition-api.html)
- [TypeScript with Vue 3 Best Practices](https://medium.com/@davisaac8/design-patterns-and-best-practices-with-the-composition-api-in-vue-3-77ba95cb4d63)

**Confidence:** HIGH (official Vue documentation, strong ecosystem support)

**SysNDD Recommendation:** Start with `strict: false`, incrementally tighten. Prioritize:
1. API response types (prevents runtime errors with database schemas)
2. Component props (component contracts)
3. Store types (state management safety)
4. Utility functions (pure logic, easy to type)

**Effort estimate:** ~2-3 weeks for baseline types, ~4-6 weeks for full strict mode.

---

### 4. Vitest + Vue Test Utils Testing Infrastructure

**Value proposition:** Catch regressions during migration, enable confident refactoring, establish testing culture.

| Feature | Complexity | Value | Notes |
|---------|------------|-------|-------|
| Vitest setup with Browser Mode | Medium | Most accurate testing (real browsers) | Playwright-based |
| Component testing with Vue Test Utils | Medium | Test user interactions | Focus on behavior, not internals |
| Composable testing | Low | Unit test extracted logic | Wrap in test component for lifecycle |
| Page Object pattern for tests | Medium | Reduce test duplication | Extract once 3+ tests use same pattern |
| API mocking with MSW | Medium | Isolate frontend from backend | Modern mock service worker approach |
| Snapshot testing (use sparingly) | Low | Catch unexpected changes | Avoid overuse, test behavior instead |

**Sources:**
- [Vue 3 Testing Pyramid with Vitest](https://alexop.dev/posts/vue3_testing_pyramid_vitest_browser_mode/)
- [Vitest Component Testing](https://vitest.dev/guide/browser/component-testing)
- [Testing Vue 3 Composables](https://dylanbritz.dev/writing/testing-vue-composables-lifecycle/)
- [Vue.js Testing Guide](https://vuejs.org/guide/scaling-up/testing)

**Confidence:** HIGH (Vitest is official recommendation for Vue 3 + Vite projects)

**SysNDD Recommendation:** Modern testing pyramid approach:
- 70% integration tests (component with mocked API)
- 20% composable unit tests
- 10% accessibility + visual regression

**Effort estimate:** ~3-4 weeks for infrastructure + example tests. Testing is ongoing, not one-time.

---

### 5. D3.js + GSAP Integration Modernization

**Value proposition:** Leverage Composition API for cleaner animation lifecycle, better reactivity integration.

| Feature | Complexity | Pattern | Notes |
|---------|------------|---------|-------|
| D3 with template refs + `onMounted` | Low | Vue 3 Composition API pattern | Cleaner than Options API |
| `watchEffect` for D3 re-rendering | Medium | Reactive data → D3 updates | Automatic re-render on data change |
| GSAP timeline in composable | Medium | Extract animation logic | Reusable, testable |
| Proper cleanup in `onBeforeUnmount` | Low | Prevent memory leaks | Kill timelines, remove event listeners |
| TypeScript types for D3/GSAP | Low | @types/d3, @types/gsap | Improve autocomplete |

**Sources:**
- [Using Vue 3 Composition API with D3](https://dev.to/muratkemaldar/using-vue-3-with-d3-composition-api-3h1g)
- [Building Charts in Vue with D3](https://dev.to/jacobandrewsky/building-charts-in-vue-with-d3-38gl)
- [GSAP with Vue 3 Composition API](https://gsap.com/community/forums/topic/27052-using-gsap-with-vuejs-3-composition-api/)
- [Modern Web Animations with GSAP and Vue 3](https://blog.openreplay.com/modern-web-animations-with-gsap-and-vue-3/)

**Confidence:** MEDIUM (community patterns, not official Vue guidance)

**SysNDD Impact:** 14 analysis components use D3 or GSAP:
- D3: `AnalysesCurationUpset.vue`, `AnalysesPhenotypeCorrelogram.vue`, `AnalysesTimePlot.vue`, etc.
- GSAP: Animation helpers for transitions

**Effort estimate:** ~1-2 days per visualization component to modernize patterns.

---

### 6. UI/UX Modernization (Bonus Differentiator)

**Value proposition:** Migration is the perfect time to address visual debt without fear of regressions (you're already touching everything).

| Feature | Complexity | Impact | Notes |
|---------|------------|--------|-------|
| CSS variables for theming | Low | High | Easy color palette updates |
| Shadow depth system | Low | High | Modern card/elevation feel |
| Loading skeleton states | Medium | Medium | Better perceived performance |
| Empty state illustrations | Low | Medium | User guidance, reduces confusion |
| Mobile responsive refinements | Medium | Medium | Table → card view on small screens |
| Accessibility improvements (WCAG 2.2) | Medium | High | Medical app requirement, legal compliance |

**Sources:**
- [Healthcare UX Best Practices 2026](https://www.eleken.co/blog-posts/user-interface-design-for-healthcare-applications)
- [Bootstrap 5 Design System](https://getbootstrap.com/docs/5.3/customize/overview/)

**Confidence:** HIGH (established design patterns, Bootstrap 5 foundation)

**SysNDD Context:** Frontend review identified dated gradient backgrounds, hard card borders, cramped spacing. Bootstrap-Vue-Next uses Bootstrap 5, already a visual upgrade.

**Effort estimate:** ~1-2 weeks for CSS refinements (parallel to migration work).

---

## Anti-Features

Features to **explicitly avoid** during migration. Common mistakes that waste time or create technical debt.

### 1. Big Bang Rewrite

**What:** Rewrite entire application from scratch in Vue 3 before deploying anything.

**Why bad:**
- Months without shipping value
- Higher risk (no incremental validation)
- Merge conflicts with ongoing Vue 2 development
- "Works on my machine" surprises at the end

**Instead:** Incremental migration using Vue 3 migration build (`@vue/compat`).

**Detection:** If migration plan has no intermediate deployable states, you're doing a big bang rewrite.

**Sources:**
- [Vue 3 Migration Build Guide](https://v3-migration.vuejs.org/migration-build.html)
- [Vue Mastery Migration Build Tutorial](https://www.vuemastery.com/blog/vue-3-migration-build/)

---

### 2. Forcing Composition API Everywhere

**What:** Rewrite all Options API components to Composition API as part of migration.

**Why bad:**
- Options API is NOT deprecated (official statement)
- Adds significant effort for little gain on simple components
- Delays migration completion
- Composition API only shines with complex logic or reuse

**Instead:** Hybrid approach. Keep Options API for simple view components. Convert only:
- Components with mixins (replace with composables)
- Components with complex state logic
- Components with reusable logic across multiple files

**Detection:** If migration timeline includes "Convert all components to Composition API" as a separate phase, you're forcing it.

**Sources:**
- [Composition API FAQ - Is Options API Deprecated?](https://vuejs.org/guide/extras/composition-api-faq.html)
- [When to Use Composition API](https://vueschool.io/articles/vuejs-tutorials/from-vue-js-options-api-to-composition-api-is-it-worth-it/)

---

### 3. TypeScript Strict Mode from Day 1

**What:** Enable `strict: true` in tsconfig.json immediately, forcing all code to be fully typed.

**Why bad:**
- Paralyzes migration progress (fighting compiler instead of migrating)
- Forces typing decisions before understanding data shapes
- Creates "any escape hatches" everywhere (defeats the purpose)
- TypeScript is incremental by design

**Instead:** Start with `strict: false`, incrementally tighten:
1. Add `.ts` extensions and basic types
2. Type API responses (prevents runtime errors)
3. Type component props (component contracts)
4. Enable `noImplicitAny` once comfortable
5. Enable `strict` as final step (optional)

**Detection:** If tsconfig has `strict: true` and codebase has 100+ `any` types or `@ts-ignore` comments, you jumped the gun.

**Sources:**
- [TypeScript Handbook - Strict Mode](https://www.typescriptlang.org/docs/handbook/2/basic-types.html#strictness)
- [Vue TypeScript Guide](https://vuejs.org/guide/typescript/overview.html)

---

### 4. Premature Component Library Switch

**What:** Switching from Bootstrap-Vue-Next to PrimeVue/Vuetify/Quasar without trying Bootstrap-Vue-Next first.

**Why bad:**
- Visual disruption confuses users (medical researchers expect consistency)
- Higher migration effort (rewrite all 50+ components)
- Unnecessary bundle size increase (Bootstrap-Vue-Next is smallest at ~150KB)
- "Grass is greener" trap (every library has tradeoffs)

**Instead:** Start with Bootstrap-Vue-Next (minimal visual change). Only switch if:
- Critical feature missing (e.g., virtual scrolling for 100K+ rows)
- Blocking bugs in Bootstrap-Vue-Next
- Bootstrap aesthetic fundamentally wrong (not the case for SysNDD)

**Detection:** If migration plan starts with "Evaluate component libraries" and doesn't prioritize visual consistency, you're premature.

**Sources:**
- [Bootstrap-Vue-Next Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs)
- [SysNDD Frontend Review](https://github.com/bernt-popp/sysndd/blob/master/.planning/FRONTEND-REVIEW-REPORT.md)

---

### 5. Testing Everything Before Shipping Anything

**What:** Writing comprehensive test suite (80%+ coverage) before deploying migrated components.

**Why bad:**
- Testing is infinite work (diminishing returns after ~70%)
- Blocks migration progress (waiting for perfect tests)
- Tests may need rewriting anyway (understanding evolves)
- Manual testing catches most migration issues

**Instead:** Test-Driven Migration (not Test-Driven Development):
1. Migrate component
2. Manually test critical paths
3. Write tests for **bugs found** (regression prevention)
4. Write tests for **complex logic** (composables, calculations)
5. Skip tests for simple presentational components

**Detection:** If "Write tests" is blocking "Deploy to production" in migration plan, you're over-testing.

**Sources:**
- [Vue Testing Guide - Testing Priorities](https://vuejs.org/guide/scaling-up/testing)
- [Testing Pyramid for Vue](https://alexop.dev/posts/vue3_testing_pyramid_vitest_browser_mode/)

---

### 6. Ignoring the Migration Build (`@vue/compat`)

**What:** Migrating without Vue 3's official migration build, going straight to Vue 3.

**Why bad:**
- No deprecation warnings (flying blind)
- All breaking changes hit at once
- Hard to isolate issues
- Migration build exists specifically for smooth migrations

**Instead:** Use `@vue/compat` for incremental migration:
1. Install `@vue/compat` (Vue 3 with Vue 2 compatibility layer)
2. Fix migration build errors (fatal issues)
3. Fix migration build warnings one by one
4. Disable compatibility mode per component/file
5. Remove `@vue/compat` when all warnings resolved

**Detection:** If migration plan doesn't mention `@vue/compat`, you're ignoring the migration build.

**Sources:**
- [Vue 3 Migration Build](https://v3-migration.vuejs.org/migration-build.html)
- [Migration Build Best Practices](https://medium.com/@kilian.j.2005/vue-2-to-vue-3-a-nearly-painless-approach-d46c13cca63a)

---

### 7. Relying on Vue 2 Internal APIs

**What:** Using undocumented Vue 2 internals (`this.$children`, `this._uid`, VNode private properties).

**Why bad:**
- Break silently in Vue 3 (no migration build warnings)
- Hard to debug (no error messages, just broken behavior)
- No migration path (internals changed completely)

**Instead:**
- Use refs (`this.$refs`) instead of `$children`
- Use Pinia or props/emits instead of `$parent` chains
- Use Vue DevTools instead of `_uid` for debugging
- Refactor before migrating

**Detection:** Search codebase for `$children`, `_uid`, `_vnode`. If found, you're using internals.

**Sources:**
- [Vue 3 Migration Guide - Removed Internal APIs](https://v3-migration.vuejs.org/breaking-changes/)
- [Vue 3 Breaking Changes](https://v3-migration.vuejs.org/breaking-changes/)

---

## Feature Dependencies

```
Vue 3 Core Migration
  ├─ Breaking Changes Resolution (REQUIRED FIRST)
  │   └─ Vue Router 4 (blocking: router.js changes)
  │   └─ Bootstrap-Vue-Next (blocking: component rewrites)
  │   └─ Deprecated Dependencies (blocking: build errors)
  │
  ├─ Build Tooling (Vite) (PARALLEL: independent of Vue 3)
  │   └─ TypeScript Setup (enables: .ts files in Vite config)
  │   └─ Vitest Setup (requires: Vite for native integration)
  │
  ├─ Composition API Adoption (AFTER CORE WORKING)
  │   └─ Mixin → Composable (requires: Composition API understanding)
  │
  └─ TypeScript Adoption (PARALLEL: can start in Vue 2.7)
      └─ Strict Mode (LAST: after all code typed)

D3/GSAP Modernization (AFTER COMPOSITION API)

UI/UX Polish (PARALLEL: CSS-only, no JavaScript changes)

Testing Infrastructure (AFTER CORE MIGRATION WORKING)
```

**Key insight:** Vue 3 core migration is blocking. Everything else can be done in parallel or deferred.

---

## MVP Migration Recommendation

For SysNDD's Vue 3 migration, prioritize getting **functionally equivalent** application running in Vue 3, then iterate.

### Phase 1: Core Migration (Must Have)
1. ✅ Install `@vue/compat` and resolve fatal errors
2. ✅ Migrate Vue Router 3 → 4
3. ✅ Migrate Bootstrap-Vue → Bootstrap-Vue-Next (pin 0.42.0)
4. ✅ Replace deprecated dependencies (`vue-meta`, `vue-axios`, `vee-validate`)
5. ✅ Fix all migration build warnings
6. ✅ Manual testing of critical paths (login, table view, create entity)

**Estimated effort:** 2-3 weeks

### Phase 2: Build Modernization (Should Have)
1. ✅ Migrate Vue CLI → Vite
2. ✅ Setup basic TypeScript (strict: false)
3. ✅ Type API responses (21 endpoints)
4. ✅ Convert environment variables (`VUE_APP_*` → `VITE_*`)

**Estimated effort:** 1-2 weeks

### Phase 3: Code Modernization (Nice to Have)
1. ✅ Convert 7 mixins → composables
2. ✅ Adopt `<script setup>` in new/refactored components
3. ✅ Setup Vitest with example tests
4. ✅ Modernize D3/GSAP patterns in 2-3 high-value components

**Estimated effort:** 2-3 weeks

### Phase 4: Polish (Can Defer to Later Milestone)
1. Enable TypeScript strict mode incrementally
2. UI/UX refinements (shadows, spacing, colors)
3. Accessibility improvements (WCAG 2.2)
4. Expand test coverage to 40-50%

**Estimated effort:** 3-4 weeks

---

## Effort Summary by Feature Category

| Category | Complexity | Time Estimate | Blocking? | Notes |
|----------|------------|---------------|-----------|-------|
| **Table Stakes** | | | | |
| Vue 3 Breaking Changes | Medium | 1 week | ✅ Yes | Migration build helps |
| Vue Router 4 | Low | 2-3 days | ✅ Yes | Well-documented |
| Bootstrap-Vue-Next | High | 2-3 weeks | ✅ Yes | 50+ components to update |
| Deprecated Dependencies | Medium | 1 week | ✅ Yes | VeeValidate most complex |
| Vite Migration | Medium | 1 week | ❌ No | Webpack still works |
| Pinia Updates | Low | 1 day | ❌ No | Already using Pinia |
| **Differentiators** | | | | |
| Composition API | Medium | 2-3 weeks | ❌ No | Hybrid approach |
| Mixin → Composable | Medium | 1-2 weeks | ❌ No | 7 mixins to convert |
| TypeScript Adoption | High | 4-6 weeks | ❌ No | Incremental approach |
| Vitest Testing | Medium | 3-4 weeks | ❌ No | Infrastructure + examples |
| D3/GSAP Modernization | Medium | 1-2 weeks | ❌ No | 14 components affected |
| UI/UX Modernization | Medium | 1-2 weeks | ❌ No | CSS-only, parallel work |

**Total MVP (Phase 1-2):** 4-5 weeks
**Total with Code Modernization (Phase 1-3):** 6-8 weeks
**Total with Polish (Phase 1-4):** 9-12 weeks

---

## SysNDD-Specific Considerations

### High-Risk Components (Test Thoroughly)

| Component | Why High-Risk | Migration Complexity |
|-----------|---------------|---------------------|
| `TablesEntities.vue` | Heavy BTable usage, 4200+ rows | High |
| `CreateEntity.vue` | Complex form, VeeValidate | High |
| `ModifyEntity.vue` | Complex form, VeeValidate | High |
| `AnalysesCurationUpset.vue` | D3 + @upsetjs/vue integration | Medium |
| `Login.vue` | Authentication critical path | Medium |
| `User.vue` | User profile, session management | Medium |

### Components with External Dependencies

| Component | External Dependency | Vue 3 Compatibility | Action Required |
|-----------|-------------------|---------------------|-----------------|
| `AnalysesCurationUpset.vue` | `@upsetjs/vue` 1.11.0 | ✅ Vue 3 compatible | Update to latest |
| Multiple forms | `vee-validate` 3.x | ❌ Use v4 | Major API change |
| Ontology selectors | `@riophae/vue-treeselect` 0.4.0 | ❓ Check compatibility | May need replacement |
| Multiple views | `vue-meta` 2.4.0 | ❌ Use @unhead/vue | Migration path exists |

### Migration Sequence Recommendation

**Order components by risk × impact:**

1. **Low-risk utilities first** (Banner, Footer, HelperBadge) — validate migration process
2. **Authentication next** (Login, Register, PasswordReset) — critical path
3. **Table views** (TablesEntities, TablesGenes) — high impact, high complexity
4. **Forms** (CreateEntity, ModifyEntity) — VeeValidate migration blocks these
5. **Analysis views** (D3/GSAP components) — lower priority, can defer
6. **Admin views last** (ManageUser, ViewLogs) — less frequently used

---

## Validation Checklist

Migration is complete when:

- [ ] All Vue 2 breaking changes resolved (no `@vue/compat` warnings)
- [ ] Vue Router 4 installed and routes working
- [ ] Bootstrap-Vue-Next components render correctly
- [ ] All deprecated dependencies replaced
- [ ] Forms submit successfully (VeeValidate 4)
- [ ] Tables paginate/sort/filter (BTable provider functions)
- [ ] D3 visualizations render and update reactively
- [ ] GSAP animations play without memory leaks
- [ ] Authentication flow works (login → protected route → logout)
- [ ] Build completes without errors (Vite or Webpack)
- [ ] Production bundle size reasonable (<2MB gzipped)
- [ ] Manual testing of all critical paths passes
- [ ] Browser console has no Vue warnings

---

## Sources

### Official Documentation
- [Vue 3 Migration Guide](https://v3-migration.vuejs.org/)
- [Vue Router 4 Migration Guide](https://router.vuejs.org/guide/migration/)
- [Pinia Migration from Vuex](https://pinia.vuejs.org/cookbook/migration-vuex.html)
- [Bootstrap-Vue-Next Migration Guide](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/migration-guide)
- [Vue 3 Composition API](https://vuejs.org/guide/extras/composition-api-faq.html)
- [Vue 3 TypeScript Guide](https://vuejs.org/guide/typescript/composition-api.html)
- [Vitest Component Testing](https://vitest.dev/guide/browser/component-testing)

### Community Resources
- [A Comprehensive Vue 2 to Vue 3 Migration Guide](https://medium.com/simform-engineering/a-comprehensive-vue-2-to-vue-3-migration-guide-a00501bbc3f0)
- [How to Migrate from Vue 2 to Vue 3: Risks & Key Benefits](https://epicmax.co/vue-3-migration-guide)
- [Options API vs Composition API](https://vueschool.io/articles/vuejs-tutorials/options-api-vs-composition-api/)
- [Converting Mixins to Composables](https://www.thisdot.co/blog/converting-your-vue-2-mixins-into-composables-using-the-composition-api)
- [Vue 3 Testing Pyramid with Vitest](https://alexop.dev/posts/vue3_testing_pyramid_vitest_browser_mode/)
- [Using Vue 3 Composition API with D3](https://dev.to/muratkemaldar/using-vue-3-with-d3-composition-api-3h1g)
- [GSAP with Vue 3 Composition API](https://gsap.com/community/forums/topic/27052-using-gsap-with-vuejs-3-composition-api/)
- [Common Vue 3 Migration Anti-Patterns](https://www.binarcode.com/blog/3-anti-patterns-to-avoid-in-vuejs)
- [A Guide to Smooth Vue 3 Migration](https://dev.to/vinsay11/a-guide-to-smooth-vue-3-migration-guide-mistakes-to-watch-out-for-57m1)

### SysNDD-Specific
- [SysNDD Frontend Review Report](file:///home/bernt-popp/development/sysndd/.planning/FRONTEND-REVIEW-REPORT.md)
- [SysNDD PROJECT.md](file:///home/bernt-popp/development/sysndd/.planning/PROJECT.md)

---

*Research completed: 2026-01-22*
*Confidence: HIGH (official sources verified with Context7 and official documentation where available)*
*Researcher: GSD Project Researcher (Features dimension)*
