# Project State: SysNDD

**Last updated:** 2026-02-06
**Current milestone:** v10.3 Bug Fixes & Stabilization

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-05)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** Phase 75 complete — milestone ready for audit

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** 75 of 75 (Frontend Fixes & UX Improvements) — COMPLETE
**Plan:** 3/3 complete
**Status:** Phase verified, milestone ready for audit
**Progress:** v10.3 [████████████████████] 100% (All phases complete)

**Last completed:** Phase 75 - Frontend Fixes & UX Improvements (verified 2026-02-06)
**Last activity:** 2026-02-06 -- Phase 75 executed and verified (4/4 must-haves passed)
**Next action:** Audit milestone v10.3

---

## Current Milestone: v10.3

**Goal:** Fix 10 open bugs and UX issues to stabilize the production deployment

**Phases:**
- Phase 73: Data Infrastructure & Cache Fixes (DATA-01, DATA-02, DATA-03) ✓
- Phase 74: API Bug Fixes (API-01, API-02, API-03) ✓
- Phase 75: Frontend Fixes & UX Improvements (FE-01, FE-02, UX-01, UX-02) ✓

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 315
- Milestones shipped: 14 (v1-v10.2)
- Phases completed: 83

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 716 + 11 E2E | +29 tests in phase 74 (entity creation, panels, clustering) |
| **Frontend Tests** | 190 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Vue Composables** | 32 | Including useColumnTooltip, useLlmAdmin, useExcelExport |
| **Migrations** | 13 files + runner | Schema version 13 (widen_comparison_columns, update_gene2phenotype_source) |
| **Lintr Issues** | 0 | All clean |
| **ESLint Issues** | 0 | All clean |
| **Total Tests** | 1,402+ | Passing |

---

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.

**Phase 73-01 decisions:**
- Use VARCHAR(255) for version column (bounded data) vs TEXT (unbounded)
- Convert 7 columns to TEXT for concatenated data (publication_id, phenotype, etc.)
- Follow migration 009 pattern for DDL (stored procedure + INFORMATION_SCHEMA)
- Follow migration 010 pattern for DML (simple UPDATE with WHERE)

**Phase 73-02 decisions:**
- Use .cache_version marker file (dot-prefix) so cachem ignores it
- Default CACHE_VERSION to '1' for backward compatibility
- Only delete .rds files, preserve directory structure and version marker
- Clear cache BEFORE cachem::cache_disk() initialization

**Phase 74-01 decisions:**
- Use HTTP 201 Created for successful entity creation (REST semantics)
- Include approval responses in bind_rows aggregation (failures surface via max(status))
- Add debug logging for approval responses (troubleshooting without DB queries)

**Phase 74-02 decisions:**
- Replace category column after filtering, not before (filter uses max_category)
- Use curly braces {} for conditional column operations in dplyr pipelines

**Phase 74-03 decisions:**
- Use early return in gen_string_clust_obj when clusters_list is empty (no STRING interactions)
- Guard all rowwise operations with nrow checks to prevent subscript out of bounds errors
- Return 200 OK with empty structures instead of errors for valid queries with no results
- Don't cache empty results (fast enough without caching)

**Phase 75-01 decisions:**
- Use app/src/constants/docs.ts for URL constants (consistent with TypeScript patterns)
- Structure as DOCS_BASE_URL + DOCS_URLS object with named keys (DRY, autocomplete-friendly)
- Return constants from setup() in Options API components (follows Vue 3 composition pattern)
- Gene page order: info -> entities -> external data -> visualizations (entities most relevant)

**Phase 75-02 decisions:**
- Extract tooltip logic into reusable composable (TablesGenes and TablesPhenotypes had inline code)
- Add head() slot to GenericTable with column-header passthrough (allows header customization)
- Preserved label cleanup regex `/( word)|( name)/g` for consistent mobile display

**Phase 75-03 decisions:**
- Use TreeNode type from @/composables for type consistency (instead of defining local interface)
- Props use TreeNode[] | null (null = not loaded, [] = loaded but empty) for better loading state UX
- Updated StepReview to handle TreeNode[] format (necessary for correct label display after data format change)

### Blockers/Concerns

None.

---

## Session Continuity

**Last session:** 2026-02-06
**Stopped at:** Phase 75 executed and verified
**Next action:** Audit milestone v10.3
**Resume file:** None

---
*State initialized: 2026-01-20*
*Last updated: 2026-02-06 -- Phase 75 complete, verified, all v10.3 phases done*
