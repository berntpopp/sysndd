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

**Plans:** 5 plans (10-02 through 10-06)

Plans:
- [x] 10-01-PLAN.md — Pre-Migration Audit (COMPLETE - done as RESEARCH.md)
- [ ] 10-02-PLAN.md — Install Vue 3 with @vue/compat
- [ ] 10-03-PLAN.md — Vue Router 4 Migration
- [ ] 10-04-PLAN.md — Event Bus Pattern Removal
- [ ] 10-05-PLAN.md — Lifecycle and Reactivity Updates
- [ ] 10-06-PLAN.md — Pinia Verification

### Success Criteria
- App runs on Vue 3 with @vue/compat
- All @vue/compat warnings documented
- Vue Router 4 functional
- No event bus patterns remaining
- All existing features work

---

## Phase 11: Bootstrap-Vue-Next Migration ✓

**Goal:** All components using Bootstrap-Vue-Next with Bootstrap 5

**Requirements:** FR-02 (all), NFR-01 (Modularization)

**Status:** COMPLETE (2026-01-23)

**Plans:** 6 plans in 4 waves

Plans:
- [x] 11-01-PLAN.md — Install Bootstrap-Vue-Next foundation (Wave 1)
- [x] 11-02-PLAN.md — Modal and Toast Migration (Wave 2)
- [x] 11-03-PLAN.md — Table Component Migration (Wave 2)
- [x] 11-04-PLAN.md — Form Component Migration (Wave 2)
- [x] 11-05-PLAN.md — Bootstrap 5 CSS Class Updates (Wave 3)
- [x] 11-06-PLAN.md — Third-Party Component Migration (Wave 4)

### Wave Structure

| Wave | Plans | Dependencies |
|------|-------|--------------|
| 1 | 11-01 | None (foundation) |
| 2 | 11-02, 11-03, 11-04 | 11-01 (parallel execution) |
| 3 | 11-05 | 11-02, 11-03, 11-04 |
| 4 | 11-06 | 11-05 |

### Success Criteria
- All Bootstrap-Vue-Next components render correctly
- Visual parity with current design
- All forms functional
- All tables functional
- No Bootstrap-Vue imports remaining
- All third-party libraries Vue 3 compatible

---

## Phase 12: Build Tool Migration (Vite) ✓

**Goal:** Vite build with instant HMR

**Requirements:** FR-03 (all), NFR-02 (Performance), NFR-01 (SOLID SRP)

**Status:** COMPLETE (2026-01-23)

**Plans:** 6 plans in 4 waves

Plans:
- [x] 12-01-PLAN.md — Vite installation and configuration (Wave 1)
- [x] 12-02-PLAN.md — Index.html migration (Wave 2)
- [x] 12-03-PLAN.md — Environment variable migration (Wave 2)
- [x] 12-04-PLAN.md — Import updates and webpack removal (Wave 2)
- [x] 12-05-PLAN.md — Docker integration (Wave 3)
- [x] 12-06-PLAN.md — Verification and testing (Wave 4)

### Wave Structure

| Wave | Plans | Dependencies |
|------|-------|--------------|
| 1 | 12-01 | None (foundation) |
| 2 | 12-02, 12-03, 12-04 | 12-01 (parallel execution) |
| 3 | 12-05 | 12-01, 12-02, 12-03, 12-04 |
| 4 | 12-06 | 12-05 |

### Success Criteria
- Vite dev server starts < 5 seconds ✓ (164ms)
- HMR works correctly in Docker ✓
- Production build succeeds ✓
- Docker builds work ✓
- All environment variables work ✓

---

## Phase 13: Mixin → Composable Conversion

**Goal:** All 7 mixins converted to Vue 3 composables

**Requirements:** FR-04 (all), NFR-01 (DRY, SOLID)

**Plans:** 6 plans in 5 waves

Plans:
- [ ] 13-01-PLAN.md — Foundation + Independent Composables (Wave 1)
- [ ] 13-02-PLAN.md — Toast Composable + Toast-Only Component Updates (Wave 2)
- [ ] 13-03-PLAN.md — URL Parsing Composable (Wave 2)
- [ ] 13-04-PLAN.md — Table Composables (useTableData + useTableMethods) (Wave 3)
- [ ] 13-05-PLAN.md — Multi-Mixin Component Migration (Wave 4)
- [ ] 13-06-PLAN.md — Cleanup and Verification (Wave 5)

### Wave Structure

| Wave | Plans | Dependencies |
|------|-------|--------------|
| 1 | 13-01 | None (foundation) |
| 2 | 13-02, 13-03 | 13-01 (parallel execution) |
| 3 | 13-04 | 13-02, 13-03 |
| 4 | 13-05 | 13-01, 13-02, 13-03, 13-04 |
| 5 | 13-06 | 13-05 |

### Success Criteria
- All 7 composables created (useColorAndSymbols, useText, useScrollbar, useToast, useUrlParsing, useTableData, useTableMethods)
- All 50+ components using composables
- No mixin imports in codebase
- Mixins directory deleted

---

## Phase 14: TypeScript Introduction

**Goal:** TypeScript enabled with type safety for API responses, props, stores

**Requirements:** FR-05 (all), NFR-01 (SOLID LSP, ISP), NFR-04 (DX)

**Plans:** 7 plans in 3 waves

Plans:
- [ ] 14-01-PLAN.md — TypeScript Setup (Wave 1)
- [ ] 14-02-PLAN.md — Type Definitions (Wave 1)
- [ ] 14-03-PLAN.md — Constants Conversion (Wave 2)
- [ ] 14-04-PLAN.md — Services and Router Conversion (Wave 2)
- [ ] 14-05-PLAN.md — Store and Composables Conversion (Wave 2)
- [ ] 14-06-PLAN.md — ESLint and Prettier Setup (Wave 3)
- [ ] 14-07-PLAN.md — Pre-commit Hooks Setup (Wave 3)

### Wave Structure

| Wave | Plans | Dependencies |
|------|-------|--------------|
| 1 | 14-01, 14-02 | None (foundation, parallel) |
| 2 | 14-03, 14-04, 14-05 | 14-01, 14-02 (parallel) |
| 3 | 14-06, 14-07 | Wave 2 complete |

### Success Criteria
- TypeScript compiles without errors
- All infrastructure files converted (main, router, stores, services, composables, constants)
- Type definitions for models and API responses
- Branded types for domain IDs (GeneId, EntityId)
- ESLint 9 flat config with TypeScript support
- Prettier formatting configured
- Pre-commit hooks with lint-staged

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

*Last updated: 2026-01-23*
