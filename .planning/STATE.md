# Project State: SysNDD

**Last updated:** 2026-02-03
**Current milestone:** v10.2 Performance & Memory Optimization

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-03)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** Phase 71 - ViewLogs Database Filtering (Plan 01 complete)

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** 71 of 72 (ViewLogs Database Filtering)
**Plan:** 01 of 04 complete
**Status:** In progress
**Progress:** v10.2 [##########----------] 50%

**Last completed:** Phase 71 Plan 01 (Logging Database Indexes)
**Last activity:** 2026-02-03 - Completed 71-01-PLAN.md
**Next action:** Execute Phase 71 Plan 02 (Query Builder Functions)

---

## Milestone Context

**v10.2 Scope (4 phases, 39 requirements):**
- Phase 69: Configurable Workers (5 requirements) - COMPLETE
- Phase 70: Analysis Optimization (9 requirements) - Plans 01+03 complete, Plan 02 pending
- Phase 71: ViewLogs Database Filtering (13 requirements) - Plan 01 complete (indexes)
- Phase 72: Documentation & Testing (12 requirements) - Docs and test coverage

**Target Issues:**
- #150: Optimize mirai worker configuration for memory-constrained servers - ADDRESSED (Phase 69)
- #152: ViewLogs endpoint loads entire table into memory before filtering

**Principles:**
- DRY, KISS, SOLID
- Full test coverage (unit + integration)
- No regressions, no antipatterns
- Optimized for speed and memory

---

## Decisions Made

| ID | Decision | Rationale | Phase |
|----|----------|-----------|-------|
| MIRAI_BOUNDS | Worker count bounds 1-8 | Minimum 1 ensures at least one worker; maximum 8 prevents resource exhaustion | 69-01 |
| MIRAI_DEFAULT | Default 2 workers for production | Right-sized for 4-core VPS with 8GB RAM | 69-01 |
| DEV_DEFAULT | Default 1 worker for development | Memory-constrained local machines benefit from lower worker count | 69-01 |
| STRING_THRESH | Default threshold 400 (medium confidence) | Balances edge coverage and precision; configurable for operator override | 70-01 |
| GC_INTERVAL | gc() every 10 clusters | Balance between memory benefits (~100ms overhead) and processing speed | 70-03 |
| PATH_PREFIX_LENGTH | 100 characters for path index | Sufficient for typical API paths while avoiding key length limits | 71-01 |
| COMPOSITE_ORDER | timestamp before status | Higher cardinality column first for better selectivity | 71-01 |

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 296
- Milestones shipped: 12 (v1-v10.1)
- Phases completed: 73

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 691 + 11 E2E | 20.3% coverage (+4 gc() tests) |
| **Frontend Tests** | 190 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Vue Composables** | 31 | Including useLlmAdmin, useExcelExport |
| **Migrations** | 9 files + runner | Schema version 8 + logging indexes |
| **Lintr Issues** | 0 | All clean |
| **ESLint Issues** | 0 | All clean |
| **Total Tests** | 1,385 | Passing (+4) |
| **Bundle Size** | ~600 KB gzipped | Vite 7.3.1, 164ms dev startup |

---

## Session Continuity

**Last session:** 2026-02-03
**Stopped at:** Completed 71-01-PLAN.md
**Next action:** Execute Phase 71 Plan 02 (Query Builder Functions)
**Resume file:** None

---

*State initialized: 2026-01-20*
*Last updated: 2026-02-03 - Completed Phase 71 Plan 01*
