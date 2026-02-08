# Project State: SysNDD

**Last updated:** 2026-02-08
**Current milestone:** v10.5 Bug Fixes & Data Integrity

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-08)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** Defining requirements for v10.5

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** Not started (defining requirements)
**Plan:** —
**Status:** Defining requirements
**Progress:** v10.5 [░░░░░░░░░░░░░░░░░░░░] 0%

**Last completed:** v10.4 milestone (OMIM Optimization & Refactor)
**Last activity:** 2026-02-08 — Milestone v10.5 started
**Next action:** Research → Requirements → Roadmap

---

## Current Milestone: v10.5

**Goal:** Fix 6 open bugs across CurationComparisons, AdminStatistics, PubTator, Traefik, and entity data integrity

**Target issues:**
- #173: CurationComparisons cross-database max category bug
- #172: AdminStatistics multiple display/logic bugs (7 sub-bugs)
- #171: AdminStatistics entity trend chart aggregation
- #170: PubTator annotation storage failure
- #169: Traefik Host() matcher for TLS
- #167: Entity data integrity audit (13 suffix-gene misalignments + admin UI tool)

**Key deliverables:**
- Fix CurationComparisons per-source category display with shared normalization helper
- Fix all 7 AdminStatistics bugs (trend aggregation, re-review sync, hardcoded denominator, race condition, date off-by-one, null checks, stale data)
- Fix PubTator incremental update to only fetch annotations for new PMIDs
- Add Host() matcher to Traefik production config
- Build admin entity integrity audit UI for curator-driven misalignment resolution
- Add regression tests for all fixes

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 322 (from v1-v10.4)
- Milestones shipped: 14 (v1-v10.4)
- Phases completed: 79

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 744 + 11 E2E | Coverage 20.3% |
| **Frontend Tests** | 190 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Vue Composables** | 32 | Including useColumnTooltip, useLlmAdmin, useExcelExport |
| **Migrations** | 14 files + runner | Schema version 14 |
| **Lintr Issues** | 0 | All clean |
| **ESLint Issues** | 0 | All clean |
| **Total Tests** | 1,430+ | Passing |

---

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- v10.5 is a pure bug-fix milestone addressing 6 open GitHub issues
- Entity data integrity (#167) will include an admin UI tool for curator-driven resolution
- Traefik (#169) simple config fix included in this milestone
- Bug detail plans available in .planning/bugs/ directory

### Pending Todos

None.

### Blockers/Concerns

**Known risks:**
- Re-review approval sync (#172 Bug 1) requires backfill script tracked in berntpopp/sysndd-administration#1
- Entity integrity (#167) — 12 of 13 misalignments need curator review (only 1 auto-fixable)
- PubTator (#170) — backfill needed for ~2,900 publications missing annotations

---

## Session Continuity

**Last session:** 2026-02-08
**Stopped at:** Milestone v10.5 started, defining requirements
**Next action:** Research → Requirements → Roadmap
**Resume file:** None

---
*State initialized: 2026-01-20*
*Last updated: 2026-02-08 — Milestone v10.5 started*
