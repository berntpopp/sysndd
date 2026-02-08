# Project State: SysNDD

**Last updated:** 2026-02-08
**Current milestone:** v10.5 Bug Fixes & Data Integrity

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-08)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** Phase 80 -- Foundation Fixes (CurationComparisons, entity trend, Traefik TLS)

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** 80 of 83 (Foundation Fixes)
**Plan:** 02 of 02 complete
**Status:** Phase complete
**Progress:** v10.5 [██░░░░░░░░░░░░░░░░░░] 10%

**Last completed:** Phase 80 Plans 01 & 02 (CurationComparisons fix, entity trend, Traefik TLS)
**Last activity:** 2026-02-08 -- Completed 80-01-PLAN.md and 80-02-PLAN.md
**Next action:** Move to Phase 81 (AdminStatistics sub-bugs)

---

## Current Milestone: v10.5

**Goal:** Fix 6 open bugs (#173, #172, #171, #170, #169, #167) across data display, admin statistics, PubTator, Traefik, and entity integrity

**Phases:** 80 (Foundation) -> 81 (AdminStatistics) -> 82 (PubTator) -> 83 (Entity Integrity)

**Deadline awareness:** Traefik TLS cert renewal Feb 19, 2026 -- Phase 80 priority

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 322 (from v1-v10.4)
- Milestones shipped: 14 (v1-v10.4)
- Phases completed: 79

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 781 + 11 E2E | Coverage 20.3% (37 new category normalization tests) |
| **Frontend Tests** | 199 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Lintr Issues** | 0 | All clean |
| **ESLint Issues** | 0 | All clean |

---

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

| ID | Title | Phase | Impact |
|----|-------|-------|--------|
| DISP-02 | Extract category normalization into shared helper | 80-01 | Single source of truth for category mappings, DRY principle |
| DISP-01 | Remove cross-database max aggregation from CurationComparisons | 80-01 | Per-source categories preserved, definitive_only filter works correctly |
| DISP-04 | Use cumulative_count with forward-fill for sparse time-series | 80-02 | Entity trend chart produces correct monotonic totals |
| INFRA-01 | Add Host() matchers to Traefik production routers | 80-02 | Eliminates TLS cert warnings, deterministic routing |

**Earlier decisions:**
- v10.5 is a pure bug-fix milestone addressing 6 open GitHub issues
- 4 phases derived from requirement dependencies and risk ordering
- TEST-01/TEST-02 are cross-cutting; each phase delivers its own test coverage
- Phase 82 (PubTator) independent of 80-81; could run in parallel

### Pending Todos

None.

### Blockers/Concerns

**Known risks:**
- Traefik TLS cert renewal deadline: Feb 19, 2026 (Phase 80)
- Re-review backfill script (689 records) tracked in berntpopp/sysndd-administration#1
- Entity integrity: 12 of 13 misalignments need curator review (only 1 auto-fixable)
- PubTator backfill needed for ~2,900 PMIDs missing annotations

---

## Session Continuity

**Last session:** 2026-02-08
**Stopped at:** Completed Phase 80 (both plans 01 & 02)
**Resume file:** None

---
*State initialized: 2026-01-20*
*Last updated: 2026-02-08 -- Completed Phase 80 (CurationComparisons fix, entity trend, Traefik TLS)*
