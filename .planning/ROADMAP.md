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

## Phase 14: TypeScript Introduction ✓

**Goal:** TypeScript enabled with type safety for API responses, props, stores

**Requirements:** FR-05 (all), NFR-01 (SOLID LSP, ISP), NFR-04 (DX)

**Status:** COMPLETE (2026-01-23)

**Plans:** 10 plans in 4 waves

Plans:
- [x] 14-01-PLAN.md — TypeScript Setup (Wave 1)
- [x] 14-02-PLAN.md — Type Definitions (Wave 1)
- [x] 14-03-PLAN.md — Constants Conversion (Wave 2)
- [x] 14-04-PLAN.md — Services and Router Conversion (Wave 2)
- [x] 14-05-PLAN.md — Store and Composables Conversion (Wave 2)
- [x] 14-06-PLAN.md — ESLint and Prettier Setup (Wave 3)
- [x] 14-07-PLAN.md — Pre-commit Hooks Setup (Wave 3)
- [x] 14-08-PLAN.md — Fix TypeScript Compilation Error (Wave 4, gap closure)
- [x] 14-09-PLAN.md — Convert Remaining Composables to TypeScript (Wave 4, gap closure)
- [x] 14-10-PLAN.md — Fix API URL Double Prefix (Wave 4, gap closure)

### Wave Structure

| Wave | Plans | Dependencies |
|------|-------|--------------|
| 1 | 14-01, 14-02 | None (foundation, parallel) |
| 2 | 14-03, 14-04, 14-05 | 14-01, 14-02 (parallel) |
| 3 | 14-06, 14-07 | Wave 2 complete |
| 4 | 14-08, 14-09, 14-10 | Wave 3 complete (gap closure, parallel) |

### Success Criteria
- TypeScript compiles without errors ✓
- All infrastructure files converted (main, router, stores, services, composables, constants) ✓
- Type definitions for models and API responses ✓
- Branded types for domain IDs (GeneId, EntityId) ✓
- ESLint 9 flat config with TypeScript support ✓
- Prettier formatting configured ✓
- Pre-commit hooks with lint-staged ✓

---

## Phase 15: Testing Infrastructure ✓

**Goal:** Vitest + Vue Test Utils foundation with example tests

**Requirements:** FR-06 (all), NFR-01 (KISS), NFR-03 (Accessibility)

**Status:** COMPLETE (2026-01-23)

**Plans:** 6 plans in 2 waves

Plans:
- [x] 15-01-PLAN.md — Vitest Setup (Wave 1)
- [x] 15-02-PLAN.md — Vue Test Utils Setup (Wave 1)
- [x] 15-03-PLAN.md — MSW API Mocking Setup (Wave 1)
- [x] 15-04-PLAN.md — Composable Test Examples (Wave 2)
- [x] 15-05-PLAN.md — Component Test Examples (Wave 2)
- [x] 15-06-PLAN.md — Accessibility Testing (Wave 2)

### Wave Structure

| Wave | Plans | Dependencies |
|------|-------|--------------|
| 1 | 15-01, 15-02, 15-03 | None (foundation, parallel) |
| 2 | 15-04, 15-05, 15-06 | Wave 1 complete (parallel) |

### Success Criteria
- Vitest running successfully ✓ (144 tests pass)
- Example tests for components pass ✓ (45 tests)
- Example tests for composables pass ✓ (88 tests)
- Accessibility tests pass ✓ (11 tests)
- Coverage reporting works ✓

---

## Phase 16: UI/UX Modernization

**Goal:** Visual refresh with modern medical web app aesthetics

**Requirements:** FR-07 (all), NFR-01 (DRY), NFR-03 (Accessibility)

**Plans:** 8 plans in 4 waves

Plans:
- [ ] 16-01-PLAN.md — CSS Custom Properties System (Wave 1)
- [ ] 16-02-PLAN.md — Card and Container Styling (Wave 2)
- [ ] 16-03-PLAN.md — Table Enhancement (Wave 2)
- [ ] 16-04-PLAN.md — Form Styling (Wave 2)
- [ ] 16-05-PLAN.md — Loading and Empty States (Wave 3)
- [ ] 16-06-PLAN.md — Search and Filter UX (Wave 3)
- [ ] 16-07-PLAN.md — Mobile Responsive Refinements (Wave 4)
- [ ] 16-08-PLAN.md — Accessibility Polish (Wave 4)

### Wave Structure

| Wave | Plans | Dependencies |
|------|-------|--------------|
| 1 | 16-01 | None (foundation) |
| 2 | 16-02, 16-03, 16-04 | 16-01 (parallel execution) |
| 3 | 16-05, 16-06 | 16-01, 16-02/16-04 (parallel execution) |
| 4 | 16-07, 16-08 | 16-03/all previous (parallel execution) |

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

**Plans:** 8 plans in 6 waves

Plans:
- [ ] 17-01-PLAN.md — Bundle Analysis Baseline (Wave 1)
- [ ] 17-02-PLAN.md — Remove @vue/compat (Wave 2)
- [ ] 17-03-PLAN.md — Legacy Code Removal (Wave 2)
- [ ] 17-04-PLAN.md — Dependency Cleanup (Wave 3)
- [ ] 17-05-PLAN.md — Bundle Optimization (Wave 4)
- [ ] 17-06-PLAN.md — Performance Audit (Wave 5)
- [ ] 17-07-PLAN.md — Browser Testing (Wave 5)
- [ ] 17-08-PLAN.md — Documentation Update (Wave 6)

### Wave Structure

| Wave | Plans | Dependencies |
|------|-------|--------------|
| 1 | 17-01 | None (baseline measurement) |
| 2 | 17-02, 17-03 | 17-01 (parallel - compat removal and legacy cleanup) |
| 3 | 17-04 | 17-02, 17-03 (dependency cleanup after code changes) |
| 4 | 17-05 | 17-04 (bundle optimization after deps removed) |
| 5 | 17-06, 17-07 | 17-05 (parallel - performance audit and browser testing) |
| 6 | 17-08 | 17-06, 17-07 (documentation after all verified) |

### Success Criteria
- No @vue/compat dependency
- global-components.js deleted
- Bundle < 2MB gzipped (or documented exception)
- Lighthouse target: 100 all categories (or documented issues)
- All browsers work (Chrome, Firefox, Safari, Edge)
- README, CHANGELOG, developer docs updated

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
