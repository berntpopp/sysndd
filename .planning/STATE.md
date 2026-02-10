# Project State: SysNDD

**Last updated:** 2026-02-10
**Current milestone:** v10.6 Curation UX Fixes & Security

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-10)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v10.6 — Fix curation UX regressions, ghost entities, and axios vulnerability

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** Not started (defining requirements)
**Plan:** —
**Status:** Investigating issues
**Progress:** v10.6 [░░░░░░░░░░░░░░░░░░░░] 0%

**Last activity:** 2026-02-10 — Milestone v10.6 started

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 333 (from v1-v10.5)
- Milestones shipped: 15 (v1-v10.5)
- Phases completed: 82

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 789 + 11 E2E | Coverage 20.3% |
| **Frontend Tests** | 229 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Lintr Issues** | 0 | All clean |
| **ESLint Issues** | 0 | All clean |

---

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.

### Pending Todos

- Investigate "approve both" regression (code archaeology needed)
- Investigate unnecessary status approval requirement
- Identify and delete ghost entities (GAP43, FGF14)
- Diagnose HTTP 500 on ATOH1 status changes
- Update axios to fix DoS vulnerability (#181)

### Blockers/Concerns

- Christiane actively curating — regressions impacting her workflow daily

---

## Session Continuity

**Last session:** 2026-02-10
**Stopped at:** Starting deep investigation of curation UX regressions
**Resume file:** None

---
*State initialized: 2026-01-20*
*Last updated: 2026-02-10 — v10.6 milestone started*
