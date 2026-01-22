# Roadmap: v3 Frontend Modernization

**Milestone:** v3 Frontend Modernization
**Created:** 2026-01-22
**Based on:** REQUIREMENTS.md, SUMMARY.md

---

## Overview

Modernize SysNDD frontend from Vue 2.7 + JavaScript to Vue 3 + TypeScript with Bootstrap-Vue-Next over 8 phases.

**Guiding principles:**
- Incremental migration (no big-bang rewrite)
- Quality over speed
- Fix antipatterns on the go (DRY, KISS, SOLID)
- Minimize visual disruption for medical users

---

## Phase Summary

| Phase | Name | Duration | Requirements | Dependencies |
|-------|------|----------|--------------|--------------|
| 10 | Vue 3 Core Migration | ~2 weeks | FR-01 | — |
| 11 | Bootstrap-Vue-Next Migration | ~2 weeks | FR-02 | Phase 10 |
| 12 | Build Tool Migration (Vite) | ~1 week | FR-03 | Phase 10 |
| 13 | Mixin → Composable Conversion | ~2 weeks | FR-04 | Phase 11, 12 |
| 14 | TypeScript Introduction | ~2 weeks | FR-05 | Phase 13 |
| 15 | Testing Infrastructure | ~2 weeks | FR-06 | Phase 14 |
| 16 | UI/UX Modernization | ~2 weeks | FR-07 | Phase 11 |
| 17 | Cleanup & Polish | ~1 week | FR-08 | All previous |

**Total estimated duration:** 12-14 weeks

---

## Phase 10: Vue 3 Core Migration

**Goal:** Working Vue 3 app with @vue/compat migration build

**Requirements:** FR-01 (all), NFR-01 (DRY, KISS)

### Plans

#### 10-01: Pre-Migration Audit
- Run audit commands to identify breaking change locations
- Document event bus usage ($root.$emit, $root.$on)
- Document lifecycle hooks to rename
- Document filter usage
- Create migration tracking checklist

#### 10-02: Install Vue 3 with @vue/compat
- Install vue@3, @vue/compat
- Configure compat mode in main.js
- Resolve initial compilation errors
- Verify app boots with warnings

#### 10-03: Vue Router 4 Migration
- Install vue-router@4
- Migrate router/index.js to createRouter() API
- Update mode: 'history' → createWebHistory()
- Fix route parameter access issues
- Test all routes work

#### 10-04: Event Bus Pattern Removal
- Replace $root.$emit with Pinia stores
- Replace $root.$on with computed/watchers
- Remove $on/$off/$once usage
- Test inter-component communication

#### 10-05: Lifecycle and Reactivity Updates
- Rename destroyed → unmounted
- Rename beforeDestroy → beforeUnmount
- Add deep: true to array watchers
- Convert filters to methods
- Update v-model bindings

#### 10-06: Pinia Verification
- Remove @vue/composition-api dependency
- Update Pinia initialization for Vue 3
- Verify all stores work correctly

### Success Criteria
- App runs on Vue 3 with @vue/compat
- All @vue/compat warnings documented
- Vue Router 4 functional
- No event bus patterns remaining
- All existing features work

---

## Phase 11: Bootstrap-Vue-Next Migration

**Goal:** All components using Bootstrap-Vue-Next with Bootstrap 5

**Requirements:** FR-02 (all), NFR-01 (Modularization)

### Plans

#### 11-01: Install Bootstrap-Vue-Next
- Install bootstrap@5.3.8, bootstrap-vue-next@0.42+
- Update main.js imports
- Configure Bootstrap-Vue-Next plugin
- Verify basic components render

#### 11-02: Modal and Toast Migration
- Replace $bvModal with v-model or composable
- Replace $bvToast with composable pattern
- Create useModal and useToast composables
- Update all modal/toast usages

#### 11-03: Table Component Migration
- Audit all b-table usages
- Update filter props (filter-included-fields → filterable)
- Update sort events (@sort-changed → @update:sort-by)
- Update selection events
- Test filtering, sorting, pagination

#### 11-04: Form Component Migration
- Update form input v-model bindings
- Update form validation for Bootstrap 5
- Update checkbox/radio syntax
- Test all forms work

#### 11-05: Bootstrap 5 CSS Class Updates
- Replace ml-*/mr-* with ms-*/me-*
- Replace text-left/text-right with text-start/text-end
- Replace float-left/float-right
- Update data-* to data-bs-*
- Update .close to .btn-close

#### 11-06: Third-Party Component Verification
- Verify @upsetjs/vue Vue 3 compatibility
- Find vue-treeselect replacement
- Find vue2-perfect-scrollbar replacement or remove
- Replace vue-meta with @unhead/vue
- Migrate vee-validate 3 → 4

### Success Criteria
- All Bootstrap-Vue-Next components render correctly
- Visual parity with current design
- All forms functional
- All tables functional
- No Bootstrap-Vue imports remaining

---

## Phase 12: Build Tool Migration (Vite)

**Goal:** Vite build with instant HMR

**Requirements:** FR-03 (all), NFR-02 (Performance), NFR-01 (SOLID SRP)

### Plans

#### 12-01: Vite Installation and Configuration
- Install vite, @vitejs/plugin-vue
- Create vite.config.ts
- Configure path aliases (@/*)
- Configure dev server proxy

#### 12-02: Project Structure Updates
- Move index.html to project root
- Update script tags for Vite
- Add .vue extensions to all component imports
- Remove webpack magic comments

#### 12-03: Environment Variable Migration
- Rename VUE_APP_* to VITE_*
- Update .env files
- Update all Sys.getenv references
- Update Dockerfile for new env vars

#### 12-04: Build Configuration
- Configure production build
- Set up code splitting (vendor, bootstrap-vue chunks)
- Configure sourcemaps
- Test production build

#### 12-05: Docker Integration
- Update app/Dockerfile for Vite
- Update app/Dockerfile.dev for dev server
- Test docker-compose.dev.yml with Vite
- Verify hot reload works in Docker

### Success Criteria
- Vite dev server starts < 2 seconds
- HMR works correctly
- Production build succeeds
- Docker builds work
- All environment variables work

---

## Phase 13: Mixin → Composable Conversion

**Goal:** All 7 mixins converted to TypeScript composables

**Requirements:** FR-04 (all), NFR-01 (DRY, SOLID)

### Plans

#### 13-01: Composables Directory Setup
- Create src/composables/ directory
- Create composables/index.ts
- Set up composable file template

#### 13-02: Independent Composables
- Convert colorAndSymbolsMixin → useColorAndSymbols
- Convert textMixin → useText
- Convert scrollbarMixin → useScrollbar
- Update components using these mixins

#### 13-03: Toast Composable
- Convert toastMixin → useToast
- Integrate with Bootstrap-Vue-Next toast
- Update all toast usages

#### 13-04: Table Composables
- Convert tableDataMixin → useTableData
- Convert tableMethodsMixin → useTableMethods
- Update table components

#### 13-05: URL Parsing Composable
- Convert urlParsingMixin → useUrlParsing
- Integrate with Vue Router 4
- Update route-dependent components

#### 13-06: Mixin Cleanup
- Verify no mixin imports remain
- Delete mixins directory
- Remove global-components.js
- Update component imports to explicit

### Success Criteria
- All 7 composables created
- All components using composables
- No mixin imports in codebase
- Mixins directory deleted

---

## Phase 14: TypeScript Introduction

**Goal:** TypeScript enabled with type safety for API responses, props, stores

**Requirements:** FR-05 (all), NFR-01 (SOLID LSP, ISP), NFR-04 (DX)

### Plans

#### 14-01: TypeScript Setup
- Install typescript, vue-tsc
- Create tsconfig.json (strict: false initially)
- Rename main.js → main.ts
- Configure path aliases in tsconfig

#### 14-02: Type Definitions - Models
- Create types/models.ts
- Define Entity, User, Gene, Phenotype interfaces
- Define Category, UserRole types
- Export all from types/index.ts

#### 14-03: Type Definitions - API
- Create types/api.ts
- Define API response types for 21 endpoints
- Define request payload types
- Add generic API helper types

#### 14-04: Type Definitions - Components
- Create types/components.ts
- Define common prop types
- Define emit types
- Define slot types

#### 14-05: Convert Services and Constants
- Convert constants/*.js → constants/*.ts
- Convert services/*.js → services/*.ts
- Add type annotations
- Export as const assertions

#### 14-06: Composable Type Safety
- Add TypeScript to all composables
- Define return types
- Add generic type parameters where needed

#### 14-07: ESLint and Prettier Setup
- Install eslint@9, typescript-eslint
- Create eslint.config.js (flat config)
- Install prettier
- Create .prettierrc.json
- Configure IDE integration

### Success Criteria
- TypeScript compiles without errors
- All composables typed
- API responses have types
- ESLint and Prettier working

---

## Phase 15: Testing Infrastructure

**Goal:** Vitest + Vue Test Utils foundation with example tests

**Requirements:** FR-06 (all), NFR-01 (KISS), NFR-03 (Accessibility)

### Plans

#### 15-01: Vitest Setup
- Install vitest, @vitest/ui, @vitest/coverage-v8
- Install jsdom
- Create vitest.config.ts
- Add test scripts to package.json

#### 15-02: Vue Test Utils Setup
- Install @vue/test-utils@2
- Install @testing-library/vue@8
- Create test setup file
- Configure component mounting helpers

#### 15-03: Component Test Examples
- Write tests for 3-5 simple components
- Demonstrate mounting, props, events
- Demonstrate async testing

#### 15-04: Composable Test Examples
- Write tests for 3-5 composables
- Demonstrate reactive testing
- Demonstrate API mocking

#### 15-05: Accessibility Testing
- Install vitest-axe
- Create accessibility test helpers
- Write accessibility tests for 3-5 components
- Document WCAG 2.2 testing patterns

#### 15-06: Coverage Configuration
- Configure coverage reporting
- Set up coverage thresholds (40-50%)
- Generate coverage reports

### Success Criteria
- Vitest running successfully
- Example tests for components pass
- Example tests for composables pass
- Accessibility tests pass
- Coverage reporting works

---

## Phase 16: UI/UX Modernization

**Goal:** Visual refresh with modern medical web app aesthetics

**Requirements:** FR-07 (all), NFR-01 (DRY), NFR-03 (Accessibility)

### Plans

#### 16-01: CSS Custom Properties System
- Define color palette variables
- Define spacing scale
- Define shadow depth system
- Define typography scale

#### 16-02: Card and Container Styling
- Implement softer card shadows
- Add rounded corners
- Improve section spacing
- Add subtle background colors

#### 16-03: Table Enhancement
- Improve table hover states
- Add better border styling
- Improve header styling
- Add row selection indicators

#### 16-04: Form Styling
- Consistent input spacing
- Improved focus states
- Better label styling
- Form validation feedback

#### 16-05: Loading and Empty States
- Create loading skeleton components
- Create empty state components
- Add to data-heavy views

#### 16-06: Search and Filter UX
- Improve search feedback
- Add clear buttons
- Improve filter controls
- Add instant feedback

#### 16-07: Mobile Responsive Refinements
- Table → card view on small screens
- Improve navigation on mobile
- Test all breakpoints

#### 16-08: Accessibility Polish
- Verify color contrast (4.5:1)
- Add focus indicators
- Test keyboard navigation
- Add reduced motion support

### Success Criteria
- Visual refresh complete
- WCAG 2.2 AA compliant
- Mobile responsive
- Loading states implemented
- No visual regressions

---

## Phase 17: Cleanup & Polish

**Goal:** Production-ready Vue 3 + TypeScript app

**Requirements:** FR-08 (all), NFR-02 (Performance), NFR-06 (Browser)

### Plans

#### 17-01: Remove @vue/compat
- Remove @vue/compat dependency
- Remove compat configuration
- Fix any remaining Vue 3 issues
- Verify app works without compat

#### 17-02: Legacy Code Removal
- Delete mixins directory (if not done)
- Delete global-components.js (if not done)
- Remove commented-out code
- Remove unused imports

#### 17-03: Dependency Cleanup
- Remove unused packages from package.json
- Update outdated packages
- Run npm audit fix
- Verify no security vulnerabilities

#### 17-04: Bundle Optimization
- Analyze bundle with rollup-plugin-visualizer
- Optimize large dependencies
- Verify code splitting works
- Target < 2MB gzipped

#### 17-05: Performance Audit
- Run Lighthouse audit
- Fix performance issues
- Target Performance score > 80
- Document any remaining issues

#### 17-06: Browser Testing
- Test Chrome (last 2 versions)
- Test Firefox (last 2 versions)
- Test Safari (last 2 versions)
- Test Edge (last 2 versions)

#### 17-07: Documentation Update
- Update README with new stack
- Document new development workflow
- Document testing approach
- Update Docker documentation

### Success Criteria
- No @vue/compat dependency
- Bundle < 2MB gzipped
- Lighthouse Performance > 80
- All browsers work
- Documentation updated

---

## Dependency Graph

```
Phase 10 (Vue 3 Core)
    │
    ├───────────────────────┐
    │                       │
    v                       v
Phase 11 (Bootstrap-Vue)   Phase 12 (Vite)
    │                       │
    └─────────┬─────────────┘
              │
              v
        Phase 13 (Composables)
              │
              v
        Phase 14 (TypeScript)
              │
              v
        Phase 15 (Testing)
              │
              ├─────────────────┐
              │                 │
              v                 v
        Phase 16 (UI/UX)   (can run in parallel)
              │
              v
        Phase 17 (Cleanup)
```

---

## Milestone Definition of Done

- [ ] All FR-01 through FR-08 requirements met
- [ ] All NFR-01 through NFR-06 requirements met
- [ ] Vue 3.5+ running (no @vue/compat)
- [ ] TypeScript enabled across codebase
- [ ] Bootstrap-Vue-Next with Bootstrap 5
- [ ] Vite build working
- [ ] 40-50% test coverage
- [ ] WCAG 2.2 AA compliant
- [ ] Bundle < 2MB gzipped
- [ ] Lighthouse Performance > 80
- [ ] All existing functionality preserved
- [ ] Documentation updated

---

*Last updated: 2026-01-22*
