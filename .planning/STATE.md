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

**Phase:** 84 — Status Change Detection (In progress)
**Plan:** 1/4 complete (84-01-SUMMARY.md)
**Status:** Composable change detection complete
**Progress:** v10.6 [████████░░░░░░░░░░░░] 38%

**Last activity:** 2026-02-10 — Completed 84-01: hasChanges added to useStatusForm and useReviewForm

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 335 (from v1-v10.6)
- Milestones shipped: 15 (v1-v10.5)
- Phases completed: 83 (84 in progress)

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 789 + 11 E2E | Coverage 20.3% |
| **Frontend Tests** | 243 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
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

### Investigation Results (2026-02-10)

| Bug | Root Cause | Fix Complexity | Status |
|-----|-----------|----------------|--------|
| HTTP 500 status change | Modal `@show` resets formData AFTER load + backend NULL→tibble crash | Frontend + backend fix | ✅ Fixed |
| "Approve both" missing | SYMPTOM of 500 bug — `status_change` always 0 because status creation fails | None — fixes itself | ✅ Fixed |
| Status always created | `submitStatusForm(false, false)` — no change detection | Medium — add hasChanges() | Phase 84 |
| Ghost entities | entities 4469, 4474 have `is_active=1` but no status record | Simple — deactivate + prevention | Phase 85 |
| Axios DoS | CVE-2026-25639 in 1.13.4 | Trivial — npm update | ✅ Fixed |

### Blockers/Concerns

- ~~Christiane actively curating — regressions impacting her workflow daily~~ **RESOLVED** (Phase 83 complete)
- Remaining work: Status change detection (84), Ghost entity cleanup (85)

---

## Session Continuity

**Last session:** 2026-02-10
**Stopped at:** Completed 84-01 (composable change detection)
**Resume file:** .planning/phases/84-status-change-detection/84-01-SUMMARY.md

---
*State initialized: 2026-01-20*
*Last updated: 2026-02-10 — Completed 84-01: hasChanges added to useStatusForm and useReviewForm with comprehensive tests*
