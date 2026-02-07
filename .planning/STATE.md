# Project State: SysNDD

**Last updated:** 2026-02-07
**Current milestone:** v10.4 OMIM Optimization & Refactor

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-07)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** Phase 79 - Configuration & Cleanup

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** 79 of 79 (Configuration & Cleanup)
**Plan:** 01 of 01
**Status:** Plan 79-01 complete
**Progress:** v10.4 [████████████████████] 100% (Phase 79-01 complete)

**Last completed:** Phase 79-01 (OMIM Config Externalization) — 2026-02-07
**Last activity:** 2026-02-07 — Completed 79-01-PLAN.md
**Next action:** v10.4 milestone complete - ready for release

---

## Current Milestone: v10.4

**Goal:** Replace slow JAX API with genemap2.txt for OMIM disease names, unify OMIM data sources, add download caching, and move credentials to env vars

**Key deliverables:**
- Shared genemap2 infrastructure with download caching and robust parsing (Phase 76) ✅
- Ontology system migration to genemap2 with mode of inheritance data (Phase 77) ✅
- Unified cache between ontology and comparisons systems (Phase 78-01) ✅
- Comparisons config cleanup and testing (Phase 78-02) ✅
- Environment variable configuration for OMIM download key (Phase 79-01) ✅

**Expected performance:** Ontology update time drops from ~8 minutes to ~30 seconds

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 322 (from v1-v10.3 + Phase 76-79)
- Milestones shipped: 13 (v1-v10.3)
- Phases completed: 79

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 744 + 11 E2E | Coverage 20.3% |
| **Frontend Tests** | 190 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Vue Composables** | 32 | Including useColumnTooltip, useLlmAdmin, useExcelExport |
| **Migrations** | 14 files + runner | Schema version 14 (pending) |
| **Lintr Issues** | 0 | All clean |
| **ESLint Issues** | 0 | All clean |
| **Total Tests** | 1,430+ | Passing |

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
- **77-01:** disease_ontology_source MUST remain 'mim2gene' (not 'genemap2') to preserve MONDO SSSOM mapping compatibility
- **77-01:** Versioning occurs AFTER inheritance expansion and deduplication to prevent spurious versions
- **77-01:** Unknown inheritance modes trigger warnings (not errors) for graceful handling of new OMIM terms
- **77-02:** Achieved <60 second ontology updates via genemap2 (eliminated 7-minute JAX API bottleneck)
- **77-02:** mim2gene.txt still downloaded as Step 4 for deprecation tracking (moved/removed MIM entries)
- **77-02:** Progress callback updated to four-step workflow (download genemap2 / parse / build / deprecation)
- **78-01:** download_hpoa() uses URL parameter from comparisons_config rather than reading config directly (pure utility pattern)
- **78-01:** adapt_genemap2_for_comparisons() is adapter (not parser) - receives pre-parsed data from shared parse_genemap2()
- **78-01:** NDD_HPO_TERMS hardcoded as named constant - stable domain definition, no admin UI exists, YAGNI for database storage
- **78-01:** Version field changed from filename-based to date-based for consistency with ontology system
- **78-01:** omim_genemap2 removed from comparisons_config (security: eliminates plaintext API key from database)
- **79-01:** OMIM_DOWNLOAD_KEY passed via Docker Compose environment (no default value, required secret)
- **79-01:** api/config.yml not modified (gitignored local file, not in version control)
- **79-01:** Migration 007 uses DEPRECATED placeholder to preserve idempotency (row removed by migration 014)

### Pending Todos

None.

### Blockers/Concerns

**Known risks from research:**
- OMIM IP blocking from excessive downloads (mitigated: file-based 1-day TTL caching in Phase 76)
- genemap2.txt column name changes (mitigated: defensive column mapping in Phase 76)
- Phenotypes column regex fragility (mitigated: robust field-based parsing in Phase 76)
- Inheritance mode mapping completeness (validated in 77-01: 15-entry mapping with warning on unmapped terms)
- Deprecation tracking gap (decision needed in Phase 79: keep mim2gene vs diff-based approach)

---

## Session Continuity

**Last session:** 2026-02-07
**Stopped at:** Phase 79-01 complete (v10.4 milestone 100%)
**Next action:** v10.4 milestone complete - ready for testing and release
**Resume file:** None

---
*State initialized: 2026-01-20*
*Last updated: 2026-02-07 — Phase 79-01 (OMIM Config Externalization) complete - v10.4 milestone 100%*
