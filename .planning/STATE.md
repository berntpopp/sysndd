# Project State: SysNDD

**Last updated:** 2026-02-07
**Current milestone:** v10.4 OMIM Optimization & Refactor

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-07)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** Phase 77 - Ontology Migration

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** 77 of 79 (Ontology Migration)
**Plan:** Ready to plan
**Status:** Ready to plan
**Progress:** v10.4 [█████░░░░░░░░░░░░░░░] 25% (Phase 76 complete)

**Last completed:** Phase 76 (Shared Infrastructure) — 2026-02-07
**Last activity:** 2026-02-07 — Phase 76 verified and complete
**Next action:** `/gsd:plan-phase 77`

---

## Current Milestone: v10.4

**Goal:** Replace slow JAX API with genemap2.txt for OMIM disease names, unify OMIM data sources, add download caching, and move credentials to env vars

**Key deliverables:**
- Shared genemap2 infrastructure with download caching and robust parsing (Phase 76)
- Ontology system migration to genemap2 with mode of inheritance data (Phase 77)
- Unified cache between ontology and comparisons systems (Phase 78)
- Environment variable configuration for OMIM download key (Phase 79)

**Expected performance:** Ontology update time drops from ~8 minutes to ~30 seconds

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 317 (from v1-v10.3 + Phase 76)
- Milestones shipped: 13 (v1-v10.3)
- Phases completed: 76

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 716 + 11 E2E | Coverage 20.3% |
| **Frontend Tests** | 190 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Vue Composables** | 32 | Including useColumnTooltip, useLlmAdmin, useExcelExport |
| **Migrations** | 13 files + runner | Schema version 13 |
| **Lintr Issues** | 0 | All clean |
| **ESLint Issues** | 0 | All clean |
| **Total Tests** | 1,402+ | Passing |

---

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- v10.4 OMIM approach: Replace JAX API with genemap2.txt for 50x+ performance improvement (8min → 30sec)
- Existing packages (httr2, fs, lubridate) provide all needed functionality for file caching with 1-day TTL
- Phased migration with feature flags allows rollback if needed during transition
- Defensive column mapping handles genemap2.txt historical field name changes
- **76-01:** Use OMIM_DOWNLOAD_KEY environment variable instead of hardcoded API key for security
- **76-01:** Implement 1-day TTL for genemap2.txt caching (vs month-based for mim2gene.txt)
- **76-01:** Use day-precision TTL checking via difftime() instead of lubridate intervals
- **76-02:** Parse genemap2.txt using position-based column mapping (X1-X14) for defensive handling of OMIM format changes
- **76-02:** Normalize 14 OMIM inheritance terms to HPO vocabulary for consistency with existing database
- **76-02:** Use synthetic fixture data instead of real OMIM data to avoid licensing issues in tests
- **76-02:** Extract parse_genemap2() from comparisons-functions.R for reuse by both ontology and comparisons systems

### Pending Todos

None.

### Blockers/Concerns

**Known risks from research:**
- OMIM IP blocking from excessive downloads (mitigated: file-based 1-day TTL caching in Phase 76)
- genemap2.txt column name changes (mitigated: defensive column mapping in Phase 76)
- Phenotypes column regex fragility (mitigated: robust field-based parsing in Phase 76)
- Inheritance mode mapping completeness (validation during Phase 77 implementation)
- Deprecation tracking gap (decision needed in Phase 79: keep mim2gene vs diff-based approach)

---

## Session Continuity

**Last session:** 2026-02-07
**Stopped at:** Phase 76 complete, verified, ready for Phase 77
**Next action:** `/gsd:plan-phase 77`
**Resume file:** None

---
*State initialized: 2026-01-20*
*Last updated: 2026-02-07 — Phase 76 (Shared Infrastructure) complete and verified*
