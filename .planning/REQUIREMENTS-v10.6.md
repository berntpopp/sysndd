# Requirements: SysNDD v10.6 — Curation UX Fixes & Security

**Created:** 2026-02-10
**Based on:** Code archaeology + Playwright live investigation

---

## R1: Fix HTTP 500 on Status Change

**Priority:** Critical (blocks R2)
**Source:** Christiane report — ATOH1 entities throw 500 on status change

### Problem
`onModifyStatusModalShow()` calls `resetStatusForm()` which deletes `formData.entity_id` AFTER `showStatusModify()` has loaded it via `loadStatusByEntity()`. The Status object sent to the API is missing `entity_id`.

### Acceptance Criteria
- [ ] Status change from "not applicable" to "Definitive" on entity 4064 succeeds
- [ ] Status change on entity 1817 succeeds
- [ ] `entity_id` is present in the POST body sent to `/api/status/create`
- [ ] Existing status modification flows (re-review, etc.) still work
- [ ] Playwright verification confirms fix

### Files to Modify
- `app/src/views/curate/ModifyEntity.vue` — move `resetStatusForm()` before `loadStatusByEntity()` in `showStatusModify()`

---

## R2: Verify "Approve Both" Restores After R1

**Priority:** High
**Source:** Christiane report — can't approve status + review together

### Problem
The "Also approve new status" checkbox in ApproveReview exists but requires `status_change === 1`. Status changes currently fail (R1), so `status_change` is always 0.

### Acceptance Criteria
- [ ] After fixing R1, submit a review + status change for an entity
- [ ] On ApproveReview page, the "Also approve new status" checkbox appears
- [ ] Approving with checkbox checked approves both review AND status
- [ ] Playwright verification confirms the full workflow

### Files to Modify
- None expected (depends on R1 fix) — verify only

---

## R3: Add Status Change Detection

**Priority:** Medium
**Source:** Christiane report — status approval required even when unchanged

### Problem
`ModifyEntity.vue:1387` always calls `submitStatusForm(false, false)` creating a new status record regardless of whether the user actually changed the status.

### Acceptance Criteria
- [ ] When user opens ModifyEntity and changes ONLY the review (not status), no new status record is created
- [ ] When user actually changes status category or problematic flag, a new status record IS created
- [ ] No regression in the modify review workflow
- [ ] No regression in the modify status workflow

### Files to Modify
- `app/src/views/curate/ModifyEntity.vue` — add change detection before `submitStatusForm()`
- `app/src/views/curate/composables/useStatusForm.ts` — optionally expose `hasChanges()` method

---

## R4: Deactivate Ghost Entities

**Priority:** High
**Source:** Christiane report — GAP43 invisible but blocks creation, third FGF14 entity

### Problem
Entities 4469 (GAP43) and 4474 (FGF14) have `is_active = 1` but no status record. They're invisible in the UI but block duplicate check.

### Acceptance Criteria
- [ ] Ghost entities deactivated (`is_active = 0`)
- [ ] GAP43 can be created as a new entity
- [ ] FGF14 duplicate check no longer blocks for the orphaned entity
- [ ] Entity creation endpoint uses atomic creation to prevent future orphans

### Files to Modify
- Database migration or admin script to deactivate entities 4469, 4474
- `api/endpoints/entity_endpoints.R` — consider integrating `svc_entity_create_with_review_status()`
- `api/services/entity-service.R` — ensure atomic creation prevents future ghosts

---

## R5: Update Axios to Fix DoS Vulnerability

**Priority:** High (security)
**Source:** GitHub Dependabot alert #136, issue #181

### Problem
axios 1.13.4 has CVE-2026-25639 — prototype pollution via `__proto__` key in `mergeConfig`.

### Acceptance Criteria
- [ ] axios updated to >=1.13.5
- [ ] `npm audit` shows no axios vulnerabilities
- [ ] All API calls still work (login, entity CRUD, etc.)
- [ ] `npm run type-check` passes
- [ ] `npm run lint` passes

### Files to Modify
- `app/package.json`
- `app/package-lock.json`

---

## Phase Structure

| Phase | Requirements | Scope |
|-------|-------------|-------|
| 83 | R1, R2, R5 | Fix status 500, verify approve-both, update axios |
| 84 | R3 | Add status change detection |
| 85 | R4 | Ghost entity cleanup + prevention |

### Rationale
- **Phase 83** groups the critical fix (R1), its dependent verification (R2), and the trivial security patch (R5) together since R1+R2 test the same workflow
- **Phase 84** is separate because change detection is a UX improvement that touches the same files but is logically distinct
- **Phase 85** is last because ghost entity cleanup requires database changes and optionally refactoring the entity creation endpoint

---
*Requirements created: 2026-02-10*
