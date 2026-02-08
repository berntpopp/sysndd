# Project State: SysNDD

**Last updated:** 2026-02-08
**Current milestone:** v10.5 Bug Fixes & Data Integrity

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-08)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** All phases complete -- ready for milestone completion

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** 82 of 82 (PubTator Backend Fix)
**Plan:** 01 of 01 complete
**Status:** Milestone complete
**Progress:** v10.5 [████████████████████] 100%

**Last completed:** Phase 82 (PubTator Backend Fix) -- all 1 plan complete
**Last activity:** 2026-02-08 -- Phase 83 removed (entity integrity handled manually)
**Next action:** Complete milestone v10.5

---

## Current Milestone: v10.5

**Goal:** Fix 5 open bugs (#173, #172, #171, #170, #169) across data display, admin statistics, PubTator, and Traefik

**Phases:** 80 (Foundation) -> 81 (AdminStatistics) -> 82 (PubTator)

**Deadline awareness:** Traefik TLS cert renewal Feb 19, 2026 -- Phase 80 priority

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 326 (from v1-v10.4 + Phases 80-81)
- Milestones shipped: 14 (v1-v10.4)
- Phases completed: 81

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 789 + 11 E2E | Coverage 20.3% (8 new PubTator unit tests) |
| **Frontend Tests** | 225 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe (26 new date/API utils tests) |
| **Lintr Issues** | 0 | All clean |
| **ESLint Issues** | 0 | All clean |

---

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

| ID | Title | Phase | Impact |
|----|-------|-------|--------|
| RATE-LIMIT-01 | PUBTATOR_RATE_LIMIT_DELAY = 0.35s | 82-01 | 7x faster annotation fetching (~2.86 req/s, under NCBI 3 req/s limit) |
| LEFT-JOIN-01 | Filter unannotated PMIDs in SQL query | 82-01 | ~90% reduction in redundant NCBI API calls for incremental updates |
| INSERT-IGNORE-01 | Use INSERT IGNORE for annotation cache only | 82-01 | Idempotent inserts prevent duplicate key errors on retries |
| KPI-RACE-01 | Derive totalEntities inside fetchTrendData | 81-02 | Eliminates race condition where totalEntities = 0 on page load |
| DATE-CALC-01 | Use inclusive day counting | 81-02 | Jan 10-20 = 11 days (not 10); accurate KPI context strings |
| ABORT-01 | AbortController for granularity changes | 81-02 | Cancels stale requests, no memory leaks, accurate loading state |
| DEFENSIVE-01 | safeArray for API response arrays | 81-02 | UI never crashes on malformed API responses (null/undefined/error objects) |
| SYNC-01 | sync_rereview_approval() uses transaction-aware conn parameter | 81-01 | Atomic re-review flag updates within caller's transaction |
| SYNC-02 | Re-review endpoint delegates to repository functions | 81-01 | Single source of truth for approval logic, reduced from 80 to 30 lines |
| SYNC-04 | Leaderboard includes all assigned re-reviews | 81-01 | Shows complete workload: approved, pending, not yet submitted |
| DISP-02 | Extract category normalization into shared helper | 80-01 | Single source of truth for category mappings, DRY principle |
| DISP-01 | Remove cross-database max aggregation from CurationComparisons | 80-01 | Per-source categories preserved, definitive_only filter works correctly |
| DISP-04 | Use cumulative_count with forward-fill for sparse time-series | 80-02 | Entity trend chart produces correct monotonic totals |
| INFRA-01 | Add Host() matchers to Traefik production routers | 80-02 | Eliminates TLS cert warnings, deterministic routing |

**Earlier decisions:**
- v10.5 is a pure bug-fix milestone addressing 5 open GitHub issues (#167 entity integrity handled manually)
- 3 phases derived from requirement dependencies and risk ordering
- TEST-01/TEST-02 are cross-cutting; each phase delivers its own test coverage
- Phase 82 (PubTator) independent of 80-81; could run in parallel

### Pending Todos

None.

### Blockers/Concerns

**Known risks:**
- Traefik TLS cert renewal deadline: Feb 19, 2026 (Phase 80)
- Re-review backfill script (689 records) tracked in berntpopp/sysndd-administration#1
- Entity integrity: 12 of 13 misalignments need curator review (handled manually, not in v10.5)
- PubTator backfill needed for ~2,900 PMIDs missing annotations

---

## Session Continuity

**Last session:** 2026-02-08
**Stopped at:** Phase 82 complete (Plan 82-01)
**Resume file:** None

---
*State initialized: 2026-01-20*
*Last updated: 2026-02-08 -- Phase 83 removed, milestone ready for completion*
