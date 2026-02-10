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

**Phase:** 84 — Status Change Detection (Complete)
**Plan:** 3/3 complete (84-01, 84-02, 84-03)
**Status:** All curation views wired with change detection
**Progress:** v10.6 [███████████░░░░░░░░░] 55%

**Last activity:** 2026-02-10 — Completed 84-02: ModifyEntity change detection (status & review forms)

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 338 (from v1-v10.6)
- Milestones shipped: 15 (v1-v10.5)
- Phases completed: 84

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 789 + 11 E2E | Coverage 20.3% |
| **Frontend Tests** | 244 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Lintr Issues** | 0 | All clean |
| **ESLint Issues** | 0 | All clean |

---

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.

| ID | Decision | Rationale | Phase |
|----|----------|-----------|-------|
| D83-01 | Reset status form BEFORE data load instead of on modal @show event | Modal @show fires asynchronously after data load, destroying entity_id. Moving reset before load prevents race condition. | 83-01 |
| D83-02 | Compact NULLs in status_create before tibble conversion | JSON null becomes R NULL which tibble rejects. purrr::compact() strips them. | 83-01 |
| D84-01 | Use exact comparison for all fields including whitespace in comments | Users expect whitespace changes to count as modifications (trailing space should trigger hasChanges). | 84-01 |
| D84-02 | Snapshot loaded data immediately after API load completes | loadedData must reflect server state, not interim reactive state. | 84-01 |
| D84-02-01 | Wire composable-provided hasChanges for ModifyEntity status form | Status form uses useStatusForm composable (Plan 84-01 added hasChanges) | 84-02 |
| D84-02-02 | Implement local change detection for ModifyEntity review form | Review form does NOT use composable (raw Review class + direct API calls), requires local computed | 84-02 |
| D84-02-03 | Use sorted array comparison for review arrays in ModifyEntity | Order shouldn't matter for phenotype/variation/publication changes | 84-02 |
| D84-03-01 | Store loaded data snapshots in component state | ApproveReview/ApproveStatus use raw classes, not composables | 84-03 |
| D84-03-02 | Use exact array comparison (sorted) for phenotypes/variation | Order shouldn't matter for change detection | 84-03 |
| D84-03-03 | Check !isBusy in modal hide handler | Prevent unsaved-changes warning during successful submit | 84-03 |

### Investigation Results (2026-02-10)

| Bug | Root Cause | Fix Complexity | Status |
|-----|-----------|----------------|--------|
| HTTP 500 status change | Modal `@show` resets formData AFTER load + backend NULL→tibble crash | Frontend + backend fix | ✅ Fixed |
| "Approve both" missing | SYMPTOM of 500 bug — `status_change` always 0 because status creation fails | None — fixes itself | ✅ Fixed |
| Status always created | `submitStatusForm(false, false)` — no change detection | Medium — add hasChanges() | ✅ Fixed (Phase 84) |
| Ghost entities | entities 4469, 4474 have `is_active=1` but no status record | Simple — deactivate + prevention | Phase 85 |
| Axios DoS | CVE-2026-25639 in 1.13.4 | Trivial — npm update | ✅ Fixed |

### Blockers/Concerns

- ~~Christiane actively curating — regressions impacting her workflow daily~~ **RESOLVED** (Phase 83 complete)
- ~~Status change detection~~ **COMPLETE** (Phase 84)
- Remaining work: Ghost entity cleanup (85)

---

## Session Continuity

**Last session:** 2026-02-10
**Stopped at:** Completed Phase 84 (all 3 plans complete)
**Resume file:** .planning/phases/84-status-change-detection/84-02-SUMMARY.md

---
*State initialized: 2026-01-20*
*Last updated: 2026-02-10 — Completed Phase 84: Status change detection across all curation views (composables + ModifyEntity + table views)*
