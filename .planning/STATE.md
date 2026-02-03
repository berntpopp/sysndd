# Project State: SysNDD

**Last updated:** 2026-02-03
**Current milestone:** v10.2 Performance & Memory Optimization

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-03)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** Phase 72 - Documentation & Testing

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** 72 of 72 (Documentation & Testing)
**Plan:** 3 of 3 complete (72-01, 72-02, 72-03)
**Status:** Phase 72 complete
**Progress:** v10.2 [####################] 100%

**Last completed:** 72-02-PLAN.md (Integration Tests)
**Last activity:** 2026-02-03 — Completed 72-02-PLAN.md
**Next action:** Phase 72 complete - milestone v10.2 finished

---

## Milestone Context

**v10.2 Scope (4 phases, 39 requirements):**
- Phase 69: Configurable Workers (5 requirements) - COMPLETE
- Phase 70: Analysis Optimization (9 requirements) - COMPLETE ✓
- Phase 71: ViewLogs Database Filtering (13 requirements) - COMPLETE ✓
- Phase 72: Documentation & Testing (12 requirements) - COMPLETE

**Target Issues:**
- #150: Optimize mirai worker configuration for memory-constrained servers - ADDRESSED (Phase 69)
- #152: ViewLogs endpoint loads entire table into memory before filtering - RESOLVED (Phase 71)

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
| LAYOUT_DRL | DrL for graphs >1000 nodes | Designed for large-scale networks, production has ~2259 nodes | 70-02 |
| LAYOUT_GRID | FR-grid for graphs 500-1000 nodes | Faster computation with acceptable quality tradeoff | 70-02 |
| LAYOUT_FR | Standard FR for graphs <500 nodes | Preserves current visual quality for small networks | 70-02 |
| LOGGING_COLUMNS | 13 columns in whitelist matching logging table | Full table schema for flexibility; TEXT columns excluded from sort | 71-02 |
| ERROR_CLASS | invalid_filter_error for validation failures | Allows endpoint to catch and return 400 instead of 500 | 71-02 |
| CURSOR_PAG | Use existing cursor-based pagination | API consistency; page_after/page_size preserved, not offset-based | 71-03 |
| MAX_ROWS | 100k row safety limit in get_logs_filtered | Prevents memory issues even with very broad filters | 71-03 |
| NO_COLLECT | Never use collect() for logging queries | Database-side filtering prevents memory explosion on large tables | 71-04 |
| EXPLICIT_SELECT | Use dplyr::select() in endpoint | Avoids masking issues from other packages | 71-04 |
| FILTER_FORMAT | Use contains(col,val) format for filters | Matches frontend conventions used by all other tables | 71-fix |
| ANY_SEARCH | Search across path/agent/query/host for any column | Provides full-text search matching frontend expectations | 71-fix |
| CLAUDE_LOCAL | CLAUDE.md is gitignored (local-only) | Intentional project design for local developer reference | 72-03 |
| SERVER_PROFILES | 4-8GB/16GB/32GB+ RAM categories | Matches Phase 69 worker defaults (1/2/4 workers) | 72-03 |
| MEMORY_FORMULA | Peak = Base (500MB) + Workers x 2GB | Based on production observations from cluster analysis | 72-03 |
| TEST_HELPER | Replicate MIRAI_WORKERS parsing in test helper | Original logic is inline in start_sysndd_api.R, need testable function | 72-01 |
| PARAM_VERIFY | Test parameterization by checking ? in clause | Verifies SQL injection safety - values in params, not SQL string | 72-01 |
| LOGS_TEST_PATTERN | Use describe/it style with skip helpers | Matches existing test-integration-pagination.R for consistency | 72-02 |
| SMALL_PAGESIZE | Test with page_size 2-3 in integration tests | Ensures pagination works with minimal test data | 72-02 |

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 296
- Milestones shipped: 12 (v1-v10.1)
- Phases completed: 76

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 687 + 11 E2E | 20.3% coverage |
| **Frontend Tests** | 190 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Vue Composables** | 31 | Including useLlmAdmin, useExcelExport |
| **Migrations** | 9 files + runner | Schema version 9 (logging_indexes) |
| **Lintr Issues** | 0 | All clean |
| **ESLint Issues** | 0 | All clean |
| **Total Tests** | 1,381 | Passing |
| **Bundle Size** | ~600 KB gzipped | Vite 7.3.1, 164ms dev startup |

---

## Session Continuity

**Last session:** 2026-02-03
**Stopped at:** Completed 72-02-PLAN.md (Integration Tests)
**Next action:** Phase 72 complete - v10.2 milestone finished
**Resume file:** None

---

*State initialized: 2026-01-20*
*Last updated: 2026-02-03 — Completed 72-02-PLAN.md (Integration Tests for Logs Endpoint Pagination)*
