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

**Phase:** 83 — Status Creation Fix & Security
**Plan:** 01 of 3 complete
**Status:** In progress — Phase 83 executing
**Progress:** v10.6 [███░░░░░░░░░░░░░░░░░] 15%

**Last activity:** 2026-02-10 — Completed 83-01 (status creation fix + axios security patch)

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

| ID | Decision | Rationale | Phase |
|----|----------|-----------|-------|
| D83-01 | Reset status form BEFORE data load instead of on modal @show event | Modal @show fires asynchronously after data load, destroying entity_id. Moving reset before load prevents race condition. | 83-01 |

### Investigation Results (2026-02-10)

| Bug | Root Cause | Fix Complexity |
|-----|-----------|----------------|
| HTTP 500 status change | Modal `@show` resets formData AFTER load deletes `entity_id` | Simple — reorder reset/load |
| "Approve both" missing | SYMPTOM of 500 bug — `status_change` always 0 because status creation fails | None — fixes itself |
| Status always created | `submitStatusForm(false, false)` — no change detection | Medium — add hasChanges() |
| Ghost entities | entities 4469, 4474 have `is_active=1` but no status record | Simple — deactivate + prevention |
| Axios DoS | CVE-2026-25639 in 1.13.4 | Trivial — npm update |

### Blockers/Concerns

- ~~Christiane actively curating — regressions impacting her workflow daily~~ **RESOLVED** (83-01: status change HTTP 500 fixed)
- Remaining work: Status change detection (84), Ghost entity cleanup (85)

---

## Session Continuity

**Last session:** 2026-02-10
**Stopped at:** Completed 83-01-PLAN.md execution
**Resume file:** .planning/phases/83-status-creation-fix-security/83-01-SUMMARY.md

---
*State initialized: 2026-01-20*
*Last updated: 2026-02-10 — Phase 83 Plan 01 complete (status creation fix + axios security)*
