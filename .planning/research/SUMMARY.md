# Research Summary: v3 Frontend Modernization

**Project:** SysNDD Vue 3 + TypeScript Migration
**Synthesized:** 2026-01-22
**Overall Confidence:** HIGH

---

## Executive Summary

SysNDD's frontend requires modernization from Vue 2.7 + JavaScript to Vue 3 + TypeScript with Bootstrap-Vue-Next. Research across four domains (stack, features, architecture, pitfalls) converges on a clear approach: **incremental migration using @vue/compat**, **Vite for build tooling**, **Bootstrap-Vue-Next for minimal visual disruption**, and **composables over mixins for TypeScript compatibility**.

The user requirement to "refactor effectively and fix any antipatterns and deviations from DRY, KISS, SOLID and modularisation on the go" means code quality improvements should be integrated into each migration phase rather than treated as a separate effort.

**Key insight from pitfall research:** Do NOT attempt Vue 3 + Bootstrap-Vue-Next + TypeScript simultaneously. Each layer has breaking changes that interact. The correct order is: Vue 3 core → Bootstrap-Vue-Next → Mixin→Composable → TypeScript.

**Critical decisions:**
- Bootstrap-Vue-Next (minimize visual disruption for medical users)
- Vite + ESM (10-100x faster dev server, modern tooling)
- TypeScript with gradual adoption (`strict: false` initially)
- Vitest + Vue Test Utils for testing infrastructure
- @vue/compat migration build for safe incremental migration

---

## Key Findings

### From STACK.md: Technology Recommendations

**Core Migration Stack (HIGH confidence):**

| Package | Current | Target | Purpose |
|---------|---------|--------|---------|
| Vue | 2.7.8 | 3.5+ | Core framework |
| TypeScript | — | 5.7+ | Type safety |
| vue-tsc | — | 3.2.2+ | Vue SFC type checking |
| Bootstrap | 4.6.0 | 5.3.8 | CSS framework |
| Bootstrap-Vue | 2.21.2 | bootstrap-vue-next 0.42+ | Component library |
| Build tool | Vue CLI 5 + Webpack | Vite 7.3+ | 10-100x faster |
| Vue Router | 3.5.3 | 4.6.4+ | Routing |
| Pinia | 2.0.14 | 2.0.14 (keep) | State management |
| VeeValidate | 3.4.14 | 4.x | Form validation |
| vue-meta | 2.4.0 | @unhead/vue | Head management |

**Testing Stack (NEW):**

| Package | Version | Purpose |
|---------|---------|---------|
| Vitest | 4.0.17+ | Test framework (Vite-native) |
| @vue/test-utils | 2.x | Vue component testing |
| @testing-library/vue | 8.x | User-centric testing |
| vitest-axe | Latest | Accessibility testing (WCAG 2.2) |

**Linting Stack:**

| Package | Current | Target | Purpose |
|---------|---------|--------|---------|
| ESLint | 6.8.0 | 9+ | Linting with flat config |
| Prettier | — | 3.x | Code formatting |

**What NOT to use:**
- Vue CLI (maintenance mode, use Vite)
- @vue/composition-api (built into Vue 3)
- bootstrap-vue (Vue 2 only)
- vue-meta (Vue 2 only, use @unhead/vue)
- vue-template-compiler (built into Vue 3)

### From FEATURES.md: Migration Feature Landscape

**Table Stakes (MUST have for migration to work):**

1. **Vue 3 Breaking Changes Resolution** - $on/$off removal, v-model changes, filters removal
2. **Vue Router 4 Migration** - createRouter(), async navigation, scroll behavior
3. **Bootstrap-Vue → Bootstrap-Vue-Next** - Different import paths, API changes
4. **Deprecated Dependencies Replacement** - vue-meta, vee-validate, vue-treeselect
5. **Build Tool Modernization** - Vue CLI → Vite, VUE_APP_* → VITE_*
6. **Pinia Updates** - Minor, already Vue 3 compatible

**Differentiators (quality improvements):**

1. **Composition API + `<script setup>`** - Better TypeScript inference, reduced boilerplate
2. **Mixin → Composable Refactoring** - Eliminate mixin pain points (7 mixins to convert)
3. **TypeScript Adoption** - Incremental, start with `strict: false`
4. **Vitest Testing Infrastructure** - 70% integration, 20% unit, 10% accessibility
5. **D3/GSAP Integration Modernization** - Composition API patterns
6. **UI/UX Modernization** - CSS variables, shadows, loading states, accessibility

**Anti-Features (AVOID):**

1. **Big Bang Rewrite** - Use incremental migration with @vue/compat
2. **Forcing Composition API Everywhere** - Hybrid approach acceptable
3. **TypeScript Strict Mode from Day 1** - Gradual adoption
4. **Premature Component Library Switch** - Start with Bootstrap-Vue-Next
5. **Testing Everything Before Shipping** - Test-driven migration, not TDD
6. **Ignoring @vue/compat** - Use migration build for warnings

**MVP Timeline Estimates:**
- Phase 1-2 (Core + Build): 4-5 weeks
- Phase 1-3 (+ Code Modernization): 6-8 weeks
- Phase 1-4 (+ Polish): 9-12 weeks

### From ARCHITECTURE.md: Migration Patterns

**Target Directory Structure:**

```
app/src/
├── main.ts                     # Entry point
├── App.vue
├── composables/                # NEW: From mixins
│   ├── useColorAndSymbols.ts
│   ├── useScrollbar.ts
│   ├── useTableData.ts
│   ├── useTableMethods.ts
│   ├── useText.ts
│   ├── useToast.ts
│   ├── useUrlParsing.ts
│   └── index.ts
├── types/                      # NEW: TypeScript definitions
│   ├── api.ts
│   ├── components.ts
│   ├── constants.ts
│   └── models.ts
├── constants/                  # Renamed from assets/js/constants/
├── services/                   # Enhanced from assets/js/services/
├── utils/                      # NEW: Pure utility functions
├── components/
├── views/
├── router/
│   └── index.ts               # Vue Router 4
├── stores/                     # Pinia (keep)
└── plugins/
```

**Migration Order (from ARCHITECTURE.md):**

1. **Foundation Setup** - TypeScript config, type definitions, path aliases
2. **Constants & Services** - Convert pure JS to TS
3. **Mixins to Composables** - Convert 7 mixins (order by dependency)
4. **Bootstrap-Vue-Next** - Component library migration
5. **Components to Composition API + TS** - Leaf → Shared → Views → Layout
6. **Cleanup** - Remove legacy code

**Composable Conversion Order (by dependency):**

1. useColorAndSymbols (no dependencies)
2. useText (no dependencies)
3. useScrollbar (no dependencies)
4. useToast (depends on Bootstrap-Vue-Next)
5. useTableData (depends on useColorAndSymbols, useText)
6. useTableMethods (depends on useTableData)
7. useUrlParsing (depends on Vue Router)

### From PITFALLS-vue-migration.md: Critical Issues to Prevent

**Top 5 Critical Pitfalls:**

1. **Silent failures from removed event bus ($on, $off, $once)** - Phase 1
   - Events don't fire, no errors thrown
   - Prevention: Audit for `$root.$emit`, use Pinia/provide-inject/mitt

2. **Bootstrap-Vue global methods removed ($bvModal, $bvToast)** - Phase 2
   - Runtime crashes when showing modals/toasts
   - Prevention: Use composables (useModal, useToast)

3. **Array mutation watchers fail without `deep: true`** - Phase 1
   - UI doesn't update on array.push()/splice()
   - Prevention: Add `deep: true` to array watchers

4. **TypeScript mixin hell** - Phase 3-5
   - Type conflicts, loss of `this` context
   - Prevention: Convert mixins to composables BEFORE adding TypeScript

5. **b-table API breaking changes** - Phase 2
   - Filtering, sorting, selection events changed
   - Prevention: Audit all b-table instances, migrate per breaking changes table

**Additional Critical Pitfalls:**

6. **Vue Router 4 async navigation trap** - Route params undefined in created()
7. **Bootstrap 5 utility class renames** - ml-* → ms-*, text-left → text-start
8. **@vue/compat false confidence** - Don't ship with compat layer
9. **TypeScript defineComponent edge cases** - Use arrow functions for prop options
10. **Vue Test Utils v2 breaking changes** - destroy → unmount, propsData → props

**Pre-Migration Audit Commands:**

```bash
# Event bus patterns
git grep "\$root\.\$emit"
git grep "\$root\.\$on"

# Bootstrap-Vue global methods
git grep "\$bvModal"
git grep "\$bvToast"

# Lifecycle hooks to rename
git grep "destroyed"
git grep "beforeDestroy"

# Bootstrap 5 class changes
git grep "\\bm[lr]-[0-9]"
git grep "text-left\|text-right"

# b-table breaking changes
git grep "<b-table"
git grep "filter-included-fields"
```

---

## Code Quality Integration (DRY, KISS, SOLID, Modularization)

Per user requirement: "refactor effectively and fix any antipatterns and deviations from DRY, KISS, SOLID and modularisation on the go"

**Quality improvements integrated into each phase:**

| Phase | Quality Focus | Specific Actions |
|-------|---------------|------------------|
| Phase 1 (Vue 3 Core) | DRY, KISS | Remove duplicate event handling patterns, simplify lifecycle logic |
| Phase 2 (Bootstrap-Vue-Next) | Modularization | Extract repeated modal/toast patterns into composables |
| Phase 3 (Build Tool) | SOLID (SRP) | Separate concerns: config, routes, stores |
| Phase 4 (Mixin→Composable) | DRY, SOLID (OCP, DIP) | Single responsibility composables, dependency injection |
| Phase 5 (TypeScript) | SOLID (LSP, ISP) | Interface segregation, proper type hierarchies |
| Phase 6 (Testing) | KISS | Simple test patterns, avoid over-mocking |
| Phase 7 (UI/UX) | DRY | CSS variables, design tokens, shared styles |

**Anti-patterns to fix during migration:**

1. **Props drilling** → Use provide/inject or Pinia for deep state
2. **Mixin property collisions** → Explicit composable returns
3. **God components** → Extract into smaller, focused components
4. **Implicit dependencies** → Explicit imports and injection
5. **Repeated API call patterns** → Shared API composable
6. **Inline styles** → CSS classes and variables
7. **Magic strings** → TypeScript enums or const objects

---

## Implications for Roadmap

### Recommended Phase Structure

**Phase 1: Vue 3 Core Migration** (Week 1-2)
| Aspect | Detail |
|--------|--------|
| Goal | Working Vue 3 app with @vue/compat |
| Delivers | App running on Vue 3 with deprecation warnings |
| Features | Vue Router 4, lifecycle renames, v-model updates |
| Pitfalls | #1 (event bus), #3 (array watchers), #6 (router async) |
| Quality | Remove event bus patterns (DRY), simplify lifecycle (KISS) |

**Phase 2: Bootstrap-Vue-Next Migration** (Week 3-4)
| Aspect | Detail |
|--------|--------|
| Goal | All components using Bootstrap-Vue-Next |
| Delivers | Visual parity with Bootstrap 5 |
| Features | Component API updates, Bootstrap 5 CSS classes |
| Pitfalls | #2 ($bvModal), #5 (b-table), #7 (CSS renames) |
| Quality | Extract modal/toast composables (Modularization) |

**Phase 3: Build Tool Migration (Vite)** (Week 5)
| Aspect | Detail |
|--------|--------|
| Goal | Vite build with instant HMR |
| Delivers | 10-100x faster dev server |
| Features | vite.config.ts, env variable migration |
| Pitfalls | Webpack-specific code removal |
| Quality | Separate config concerns (SOLID SRP) |

**Phase 4: Mixin → Composable Conversion** (Week 6-7)
| Aspect | Detail |
|--------|--------|
| Goal | All 7 mixins converted to composables |
| Delivers | Explicit dependencies, no namespace collisions |
| Features | useColorAndSymbols, useTableData, useToast, etc. |
| Pitfalls | #4 (TypeScript mixin hell prevention) |
| Quality | Single responsibility (SOLID), dependency injection (DIP) |

**Phase 5: TypeScript Introduction** (Week 8-9)
| Aspect | Detail |
|--------|--------|
| Goal | TypeScript enabled with gradual strict adoption |
| Delivers | Type safety for API responses, props, stores |
| Features | tsconfig.json, type definitions, component typing |
| Pitfalls | #9 (defineComponent edge cases) |
| Quality | Interface segregation (ISP), proper hierarchies (LSP) |

**Phase 6: Testing Infrastructure** (Week 10-11)
| Aspect | Detail |
|--------|--------|
| Goal | Vitest + Vue Test Utils foundation |
| Delivers | Test infrastructure, example tests |
| Features | vitest.config.ts, component tests, accessibility tests |
| Pitfalls | #10 (Vue Test Utils v2 changes) |
| Quality | Simple test patterns (KISS), avoid over-mocking |

**Phase 7: UI/UX Modernization** (Week 12-13)
| Aspect | Detail |
|--------|--------|
| Goal | Visual refresh with modern medical web app aesthetics |
| Delivers | CSS variables, shadows, loading states, WCAG 2.2 |
| Features | Color palette, card styling, tables, mobile refinements |
| Pitfalls | Visual regression (test with screenshots) |
| Quality | CSS variables (DRY), design tokens |

**Phase 8: Cleanup & Polish** (Week 14)
| Aspect | Detail |
|--------|--------|
| Goal | Remove @vue/compat, legacy code, final optimizations |
| Delivers | Production-ready Vue 3 + TypeScript app |
| Features | Bundle optimization, performance audit |
| Pitfalls | #8 (@vue/compat removal) |
| Quality | Final anti-pattern sweep |

### Dependency Chain

```
Phase 1 (Vue 3 Core)
    │
    ├─> Phase 2 (Bootstrap-Vue-Next) ─┐
    │                                  │
    └─> Phase 3 (Vite) ───────────────┼─> Phase 4 (Composables)
                                       │         │
                                       │         v
                                       │   Phase 5 (TypeScript)
                                       │         │
                                       │         v
                                       └─> Phase 6 (Testing)
                                                 │
                                                 v
                                           Phase 7 (UI/UX)
                                                 │
                                                 v
                                           Phase 8 (Cleanup)
```

**Critical path:** 1 → 2 → 4 → 5 (must be sequential)
**Parallel work:** Phase 3 can run alongside Phase 2

---

## Critical Decisions Required

### Decision 1: Migration Strategy
**Recommendation:** Incremental with @vue/compat

Use @vue/compat migration build for safe, warning-guided migration. Do NOT attempt big-bang rewrite. Fix warnings systematically, then remove compat layer.

### Decision 2: Component Library
**Recommendation:** Bootstrap-Vue-Next (already decided by user)

Minimize visual disruption for medical researchers/clinicians. Bootstrap-Vue-Next 0.42+ is stable enough for production. Pin version and contribute fixes upstream if needed.

### Decision 3: TypeScript Strictness
**Recommendation:** Gradual adoption

Start with `strict: false`, enable incrementally:
1. Add `.ts` extensions and basic types
2. Type API responses (21 endpoints)
3. Type component props
4. Enable `noImplicitAny`
5. Enable `strict: true` (optional, final step)

### Decision 4: Composition API Adoption
**Recommendation:** Hybrid approach

- Convert all mixins to composables (required for TypeScript)
- Convert complex components to `<script setup>`
- Keep simple view components as Options API if preferred
- New components use Composition API

### Decision 5: Testing Strategy
**Recommendation:** Test-driven migration (not TDD)

1. Migrate component
2. Manually test critical paths
3. Write tests for bugs found (regression prevention)
4. Write tests for complex logic (composables)
5. Skip tests for simple presentational components

Target: 70% integration tests, 20% composable unit tests, 10% accessibility

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Vue 3 Core Migration | HIGH | Official migration guide, @vue/compat well-documented |
| Bootstrap-Vue-Next | MEDIUM-HIGH | Active development, 35+ components, but 0.x version |
| Vite Migration | HIGH | Official Vue recommendation, many migration guides |
| TypeScript Integration | HIGH | First-class Vue 3 support, official guide |
| Composable Patterns | HIGH | Official Vue composables guide |
| Testing (Vitest) | HIGH | Official Vite testing framework, Vue 3 native |
| UI/UX Modernization | HIGH | Bootstrap 5 mature, design patterns established |

### Gaps to Address During Implementation

1. **TreeSelect replacement** - @riophae/vue-treeselect is Vue 2 only. Evaluate @zanmato/vue3-treeselect vs PrimeVue TreeSelect.

2. **@upsetjs/vue compatibility** - Verify Vue 3 support before Phase 2.

3. **Vue-perfect-scrollbar replacement** - Find Vue 3 alternative or use CSS-only solution.

4. **Existing animation patterns** - Audit D3/GSAP usage for cleanup needs during migration.

---

## Sources

### Official Documentation (HIGH Confidence)
- [Vue 3 Migration Guide](https://v3-migration.vuejs.org/)
- [Vue 3 Composition API](https://vuejs.org/guide/reusability/composables.html)
- [Vue 3 TypeScript Guide](https://vuejs.org/guide/typescript/overview.html)
- [Vue Router 4 Migration](https://router.vuejs.org/guide/migration/)
- [Bootstrap-Vue-Next Migration Guide](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/migration-guide)
- [Vite Guide](https://vite.dev/guide/)
- [Vitest Documentation](https://vitest.dev/)
- [Bootstrap 5 Migration](https://getbootstrap.com/docs/5.0/migration/)

### Community Resources (MEDIUM-HIGH Confidence)
- [Vue 2 to Vue 3 Migration Guide (Simform)](https://medium.com/simform-engineering/a-comprehensive-vue-2-to-vue-3-migration-guide-a00501bbc3f0)
- [How to Migrate from Vue CLI to Vite](https://vueschool.io/articles/vuejs-tutorials/how-to-migrate-from-vue-cli-to-vite/)
- [Converting Mixins to Composables](https://www.thisdot.co/blog/converting-your-vue-2-mixins-into-composables-using-the-composition-api)
- [Vue 3 Testing Pyramid](https://alexop.dev/posts/vue3_testing_pyramid_vitest_browser_mode/)

---

## Next Steps

1. **Create REQUIREMENTS.md** - Define specific requirements from this research
2. **Create ROADMAP.md** - Phase breakdown with deliverables
3. **Get user approval** on roadmap
4. **Begin Phase 1** - Vue 3 core migration with @vue/compat
