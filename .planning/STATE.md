# Project State: SysNDD

**Last updated:** 2026-02-07
**Current milestone:** v10.4 OMIM Optimization & Refactor

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-07)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** Defining requirements for v10.4

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** Not started (defining requirements)
**Plan:** —
**Status:** Defining requirements
**Progress:** v10.4 [░░░░░░░░░░░░░░░░░░░░] 0%

**Last completed:** v10.3 milestone (all phases verified)
**Last activity:** 2026-02-07 — Milestone v10.4 started
**Next action:** Research OMIM best practices, define requirements

---

## Current Milestone: v10.4

**Goal:** Replace slow JAX API with genemap2.txt for OMIM disease names, unify OMIM data sources, add download caching, and move credentials to env vars

**Target features:**
- Replace JAX API sequential fetch (~20 min) with genemap2.txt parsing (~seconds)
- Unify OMIM data source between ontology system and comparisons system
- Disk-based cache with 1-day TTL for OMIM file downloads
- OMIM download key moved to OMIM_DOWNLOAD_KEY environment variable
- Research-informed best practices for OMIM phenotype mapping

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 315
- Milestones shipped: 15 (v1-v10.3)
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

(New milestone — decisions will be logged as phases complete)

### Blockers/Concerns

None.

---

## Session Continuity

**Last session:** 2026-02-07
**Stopped at:** Milestone v10.4 initialization
**Next action:** Research OMIM best practices, define requirements
**Resume file:** None

---
*State initialized: 2026-01-20*
*Last updated: 2026-02-07 — Milestone v10.4 started*
