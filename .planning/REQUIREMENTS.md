# Requirements: v3 Frontend Modernization

**Milestone:** v3 Frontend Modernization
**Created:** 2026-01-22
**Based on:** Research synthesis (SUMMARY.md), FRONTEND-REVIEW-REPORT.md, user requirements

---

## Milestone Goal

Modernize the SysNDD frontend from Vue 2.7 + JavaScript to Vue 3 + TypeScript with Bootstrap-Vue-Next, including comprehensive UI/UX improvements based on medical web application best practices, while maintaining DRY, KISS, SOLID principles throughout.

---

## Functional Requirements

### FR-01: Vue 3 Core Migration
**Priority:** Critical
**Phase:** 1

- FR-01.1: Migrate from Vue 2.7.8 to Vue 3.5+
- FR-01.2: Replace Vue Router 3.5.3 with Vue Router 4.6+
- FR-01.3: Remove event bus patterns ($on, $off, $once, $root.$emit)
- FR-01.4: Update v-model bindings to Vue 3 syntax
- FR-01.5: Rename lifecycle hooks (destroyed → unmounted, beforeDestroy → beforeUnmount)
- FR-01.6: Convert filters to methods/computed properties
- FR-01.7: Add `deep: true` to array watchers where needed
- FR-01.8: Update async component loading to defineAsyncComponent()
- FR-01.9: Verify Pinia 2.0.14 works with Vue 3 (remove @vue/composition-api)

**Success criteria:** App runs on Vue 3 with @vue/compat, all deprecation warnings addressed

---

### FR-02: Bootstrap-Vue-Next Migration
**Priority:** Critical
**Phase:** 2

- FR-02.1: Replace Bootstrap-Vue 2.21.2 with Bootstrap-Vue-Next 0.42+
- FR-02.2: Replace Bootstrap 4.6.0 CSS with Bootstrap 5.3.8
- FR-02.3: Update all b-table components to new API (filter, sort, selection events)
- FR-02.4: Replace $bvModal.show()/$bvModal.hide() with composable or v-model
- FR-02.5: Replace $bvToast.toast() with composable pattern
- FR-02.6: Update Bootstrap 5 utility classes (ml-* → ms-*, etc.)
- FR-02.7: Update data-* attributes to data-bs-*
- FR-02.8: Update form validation classes for Bootstrap 5
- FR-02.9: Verify all 50+ components render correctly with Bootstrap-Vue-Next

**Success criteria:** Visual parity with current design, all components functional

---

### FR-03: Build Tool Migration (Vite)
**Priority:** High
**Phase:** 3

- FR-03.1: Replace Vue CLI 5.0.8 + Webpack with Vite 7.3+
- FR-03.2: Create vite.config.ts with appropriate configuration
- FR-03.3: Migrate environment variables (VUE_APP_* → VITE_*)
- FR-03.4: Move index.html to project root with Vite script tags
- FR-03.5: Add .vue extensions to all component imports
- FR-03.6: Remove webpack-specific code (magic comments, require.context)
- FR-03.7: Configure API proxy for development
- FR-03.8: Configure code splitting (manual chunks for vendor, bootstrap-vue)
- FR-03.9: Update Docker build process for Vite

**Success criteria:** Dev server starts instantly, production build works

---

### FR-04: Mixin to Composable Conversion
**Priority:** High
**Phase:** 4

- FR-04.1: Convert colorAndSymbolsMixin.js → useColorAndSymbols.ts
- FR-04.2: Convert textMixin.js → useText.ts
- FR-04.3: Convert scrollbarMixin.js → useScrollbar.ts
- FR-04.4: Convert toastMixin.js → useToast.ts
- FR-04.5: Convert tableDataMixin.js → useTableData.ts
- FR-04.6: Convert tableMethodsMixin.js → useTableMethods.ts
- FR-04.7: Convert urlParsingMixin.js → useUrlParsing.ts
- FR-04.8: Create composables/index.ts for re-exports
- FR-04.9: Update all components to use composables instead of mixins
- FR-04.10: Remove mixins directory after all conversions verified

**Success criteria:** All 7 mixins converted, no mixin usage remains

---

### FR-05: TypeScript Integration
**Priority:** High
**Phase:** 5

- FR-05.1: Add TypeScript 5.7+ and vue-tsc 3.2.2+
- FR-05.2: Create tsconfig.json with appropriate settings (start with strict: false)
- FR-05.3: Rename main.js → main.ts
- FR-05.4: Create types/models.ts with data model interfaces (Entity, User, Gene, etc.)
- FR-05.5: Create types/api.ts with API response types for 21 endpoints
- FR-05.6: Create types/components.ts with component prop types
- FR-05.7: Add TypeScript to all composables
- FR-05.8: Convert constants from .js to .ts with proper typing
- FR-05.9: Convert services from .js to .ts with generic type support
- FR-05.10: Update ESLint to ESLint 9 flat config with TypeScript support
- FR-05.11: Add Prettier 3.x for code formatting

**Success criteria:** TypeScript compiles without errors, basic type safety achieved

---

### FR-06: Testing Infrastructure
**Priority:** Medium
**Phase:** 6

- FR-06.1: Install Vitest 4.0.17+ as test framework
- FR-06.2: Install @vue/test-utils 2.x for Vue component testing
- FR-06.3: Install @testing-library/vue 8.x for user-centric testing
- FR-06.4: Install vitest-axe for accessibility testing (WCAG 2.2)
- FR-06.5: Create vitest.config.ts with jsdom environment
- FR-06.6: Create example component tests (3-5 components)
- FR-06.7: Create example composable unit tests (3-5 composables)
- FR-06.8: Create example accessibility tests (3-5 components)
- FR-06.9: Add test:unit and test:coverage npm scripts
- FR-06.10: Configure coverage reporting (target: 40-50% initial)

**Success criteria:** Test infrastructure works, example tests pass

---

### FR-07: UI/UX Modernization
**Priority:** Medium
**Phase:** 7

- FR-07.1: Define CSS custom properties for color palette (medical-appropriate blues/teals)
- FR-07.2: Implement shadow depth system (subtle elevation)
- FR-07.3: Improve card styling (softer shadows, rounded corners)
- FR-07.4: Enhance table styling (hover states, better borders)
- FR-07.5: Add loading skeleton states for data-heavy views
- FR-07.6: Add empty state illustrations/messages
- FR-07.7: Improve form styling (consistent spacing, focus states)
- FR-07.8: Enhance search/filter UX (instant feedback, clear buttons)
- FR-07.9: Improve mobile responsive behavior (table → card on small screens)
- FR-07.10: Ensure WCAG 2.2 Level AA compliance (contrast, focus indicators)
- FR-07.11: Add smooth page transitions

**Success criteria:** Visual refresh complete, WCAG 2.2 AA compliant

---

### FR-08: Cleanup and Polish
**Priority:** Medium
**Phase:** 8

- FR-08.1: Remove @vue/compat dependency
- FR-08.2: Delete legacy mixin files
- FR-08.3: Delete global-components.js
- FR-08.4: Remove unused dependencies from package.json
- FR-08.5: Optimize bundle size (analyze and reduce)
- FR-08.6: Performance audit (Lighthouse score targets)
- FR-08.7: Final anti-pattern sweep (DRY, KISS, SOLID)
- FR-08.8: Update developer documentation (README)

**Success criteria:** Production-ready, clean codebase, no legacy code

---

## Non-Functional Requirements

### NFR-01: Code Quality (DRY, KISS, SOLID)
**Priority:** High
**Phase:** All phases

- NFR-01.1: Apply DRY principle - no duplicate code patterns across components
- NFR-01.2: Apply KISS principle - simplest solution that works
- NFR-01.3: Apply SOLID SRP - each composable/component has single responsibility
- NFR-01.4: Apply SOLID OCP - composables open for extension, closed for modification
- NFR-01.5: Apply SOLID DIP - depend on abstractions (types/interfaces), not implementations
- NFR-01.6: Eliminate props drilling (use provide/inject or Pinia)
- NFR-01.7: No god components (max ~300 lines per component)
- NFR-01.8: Explicit imports (no global component registration)
- NFR-01.9: No magic strings (use TypeScript enums or const objects)
- NFR-01.10: CSS classes over inline styles

**Verification:** Code review checklist applied to each phase PR

---

### NFR-02: Performance
**Priority:** Medium
**Phase:** 3, 8

- NFR-02.1: Dev server startup time < 2 seconds (Vite)
- NFR-02.2: HMR update time < 100ms
- NFR-02.3: Production bundle size < 2MB gzipped
- NFR-02.4: Lighthouse Performance score > 80
- NFR-02.5: First Contentful Paint < 2 seconds

**Verification:** Lighthouse audit after Phase 8

---

### NFR-03: Accessibility
**Priority:** Medium
**Phase:** 7

- NFR-03.1: WCAG 2.2 Level AA compliance
- NFR-03.2: Keyboard navigation for all interactive elements
- NFR-03.3: Screen reader compatible (proper ARIA labels)
- NFR-03.4: Sufficient color contrast (4.5:1 minimum)
- NFR-03.5: Focus indicators visible on all interactive elements
- NFR-03.6: No motion without reduced-motion media query support

**Verification:** vitest-axe tests, manual screen reader testing

---

### NFR-04: Developer Experience
**Priority:** Medium
**Phase:** 3, 5

- NFR-04.1: TypeScript autocompletion in IDE for all components
- NFR-04.2: Type-safe API responses
- NFR-04.3: ESLint catches common errors
- NFR-04.4: Prettier ensures consistent formatting
- NFR-04.5: Clear error messages from type system

**Verification:** Developer feedback during implementation

---

### NFR-05: Maintainability
**Priority:** Medium
**Phase:** All

- NFR-05.1: Components organized by feature/domain
- NFR-05.2: Clear naming conventions (use* for composables, Types for interfaces)
- NFR-05.3: Documentation in complex logic (JSDoc comments)
- NFR-05.4: No commented-out code
- NFR-05.5: No TODO comments without GitHub issue reference

**Verification:** Code review

---

### NFR-06: Browser Compatibility
**Priority:** Medium
**Phase:** 8

- NFR-06.1: Chrome (last 2 versions)
- NFR-06.2: Firefox (last 2 versions)
- NFR-06.3: Safari (last 2 versions)
- NFR-06.4: Edge (last 2 versions)

**Verification:** Manual testing or BrowserStack

---

## Dependencies and Replacements

### Package Migrations

| Current | Target | Phase |
|---------|--------|-------|
| vue 2.7.8 | vue 3.5+ | 1 |
| vue-router 3.5.3 | vue-router 4.6+ | 1 |
| bootstrap-vue 2.21.2 | bootstrap-vue-next 0.42+ | 2 |
| bootstrap 4.6.0 | bootstrap 5.3.8 | 2 |
| Vue CLI 5.0.8 | vite 7.3+ | 3 |
| — | typescript 5.7+ | 5 |
| — | vitest 4.0.17+ | 6 |
| vue-meta 2.4.0 | @unhead/vue | 2 |
| vee-validate 3.4.14 | vee-validate 4.x | 2 |
| @riophae/vue-treeselect 0.4.0 | TBD (Vue 3 alternative) | 2 |
| vue2-perfect-scrollbar 1.5.56 | TBD or CSS-only | 2 |
| eslint 6.8.0 | eslint 9+ | 5 |
| @vue/composition-api 1.7.0 | (remove - built into Vue 3) | 1 |

### Packages to Remove

| Package | Reason |
|---------|--------|
| @vue/composition-api | Built into Vue 3 |
| vue-template-compiler | Built into Vue 3 |
| @vue/cli-service | Replaced by Vite |
| @vue/cli-plugin-* | Replaced by Vite plugins |

---

## Constraints

- Must maintain visual similarity for medical researchers/clinicians
- Must work on Windows (WSL2), macOS, and Linux
- Must use Node.js 20 LTS
- Must not change backend API (R/Plumber)
- Must maintain all existing functionality during migration

---

## Out of Scope

- Backend changes (R/Plumber API unchanged)
- Database changes
- CI/CD pipeline (deferred to v4)
- Server-side rendering
- PWA features (keep existing)

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Bootstrap-Vue-Next 0.x stability | Pin version, contribute fixes upstream |
| TreeSelect Vue 3 compatibility | Research alternatives before Phase 2, fallback to PrimeVue TreeSelect |
| @upsetjs/vue Vue 3 compatibility | Verify early, find alternative if needed |
| Large migration scope | Incremental phases, @vue/compat for safety |
| Visual regressions | Screenshot comparison testing |

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Vue version | 3.5+ |
| TypeScript coverage | 100% of files |
| Test coverage | 40-50% |
| Bundle size | < 2MB gzipped |
| Lighthouse Performance | > 80 |
| WCAG compliance | Level AA |
| Breaking changes | 0 (all existing features work) |

---

*Last updated: 2026-01-22*
