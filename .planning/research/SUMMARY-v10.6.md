# Research Summary: SysNDD v10.6 — Curation UX Fixes & Security

**Researched:** 2026-02-10
**Method:** Code archaeology (5 parallel agents) + Playwright live testing
**Confidence:** HIGH — all 5 bugs reproduced and root-caused

---

## Bug Investigations

### Bug 1: HTTP 500 on Status Change (ATOH1)

**Reported:** Christiane gets 500 error changing status on ATOH1 deafness/intellectual disability entities.

**Root Cause:** Modal `@show` event handler destroys loaded data.

**Sequence:**
1. `showStatusModify()` calls `await loadStatusByEntity(4064)` → sets `formData.entity_id = 4064`
2. Then calls `modifyStatusModal.show()` which fires `@show` event
3. `onModifyStatusModalShow()` calls `resetStatusForm()`
4. `resetStatusForm()` runs `delete formData.entity_id` and `delete formData.status_id`
5. User submits → `entity_id` is undefined → JSON.stringify strips it → backend rejects with "entity_id is required"

**Evidence:**
- Playwright intercepted request body: `{"status_json":{"category_id":1,"comment":"...","problematic":false}}` — NO entity_id
- Live Vue component inspection: `statusFormData` has only 3 keys `[category_id, comment, problematic]`
- Direct curl with entity_id succeeds: `{"status":[200],"message":["OK. Status created."],"entry":[5513]}`

**Files:**
- `app/src/views/curate/ModifyEntity.vue:1450-1453` — `onModifyStatusModalShow()` resets after load
- `app/src/views/curate/ModifyEntity.vue:1215-1242` — `showStatusModify()` loads then shows
- `app/src/views/curate/composables/useStatusForm.ts:282-297` — `resetForm()` deletes entity_id

**Fix:** Move `resetStatusForm()` to the beginning of `showStatusModify()` BEFORE `loadStatusByEntity()`.

---

### Bug 2: "Approve Both" Missing

**Reported:** Christiane can no longer approve status + review together from ApproveReview view.

**Root Cause:** Feature STILL EXISTS. The "Also approve new status" checkbox in `ApproveReview.vue:521-534` only shows when `entity.status_change === 1`, which is computed as `active_status != newest_status` in `review_endpoints.R:164`. All current pending reviews have `status_change = 0`.

**Why status_change is always 0:** The status creation flow is broken (Bug 1). When curators edit an entity via ModifyEntity and try to change both review + status, the status creation fails with 500. So no pending status change exists alongside the review, and the checkbox never appears.

**Evidence:**
- Code archaeology confirmed feature exists at `ApproveReview.vue:521-534`
- Playwright confirmed: modal for entity 1172 (TTN) shows NO checkbox because `status_change = 0`
- `review_endpoints.R:164`: `mutate(status_change = as.numeric(!(active_status == newest_status)))`

**Fix:** This is a SYMPTOM of Bug 1. Fixing the status creation flow will restore the feature. May also need UX improvement to make the review+status workflow clearer.

---

### Bug 3: Status Approval Required When Unchanged

**Reported:** When editing only a review (e.g., renaming disease), status still needs separate approval.

**Root Cause:** `ModifyEntity.vue:1387` always calls `submitStatusForm(false, false)` with `isUpdate=false`, unconditionally creating a new status record. There is no change detection.

**Flow:**
1. User opens ModifyEntity, selects entity, clicks "Modify review"
2. User edits review data (e.g., changes disease name)
3. `submitReviewChange()` submits the review
4. Separately, `submitStatusChange()` always creates a NEW status via POST `/api/status/create`
5. New status needs separate approval even though nothing changed

**Evidence:**
- `ModifyEntity.vue:1387`: `await this.submitStatusForm(false, false)` — isUpdate is ALWAYS false
- `useStatusForm.ts:239-240`: isUpdate=false routes to `/api/status/create` (POST)

**Fix:** Add change detection — compare submitted `category_id`/`problematic` with loaded values and skip status creation if unchanged. Also consider using PUT `/api/status/update` for modifications instead of always creating new records.

---

### Bug 4: Ghost Entities (GAP43, FGF14)

**Reported:** GAP43 and third FGF14 entity are invisible but block new entity creation.

**Root Cause:** Entities created with `is_active = 1` but no status record. The duplicate check (`svc_entity_check_duplicate()`) only checks `is_active = 1`, while the entity view (`ndd_entity_view`) requires INNER JOIN with `ndd_entity_status_approved_view` (needs `status_approved = 1`).

**Database Evidence:**
```
GAP43 (entity_id 4469): is_active=1, status_id=NA (NO status record)
FGF14 (entity_id 4474): is_active=1, status_id=NA (NO status record)
```

**Fix:**
1. **Immediate:** Deactivate ghost entities (`UPDATE ndd_entity SET is_active = 0 WHERE entity_id IN (4469, 4474)`)
2. **Prevention:** Integrate `svc_entity_create_with_review_status()` (atomic creation from Phase 55) into the main creation endpoint, or add status existence check to duplicate check query

---

### Bug 5: Axios DoS Vulnerability

**Reported:** GitHub Dependabot alert #136 (issue #181).

**Root Cause:** axios 1.13.4 has CVE-2026-25639 — prototype pollution via `__proto__` key in `mergeConfig`.

**Evidence:**
- `app/package.json` line 71: `"axios": "^1.13.4"` in devDependencies
- 218 calls across 47 files use the custom axios instance

**Fix:** `npm update axios` → 1.13.5 (patch bump, zero risk).

---

## Cross-Bug Relationships

```
Bug 1 (500 on status change) ──causes──> Bug 2 (approve both missing)
                                          └── status changes fail, so status_change always 0
Bug 3 (status always created) ──causes──> unnecessary approval work
Bug 4 (ghost entities) ──independent──> entity creation workflow
Bug 5 (axios vuln) ──independent──> security
```

## Fix Priority

1. **Bug 1** (HTTP 500) — Highest impact, blocks Bug 2, simple fix
2. **Bug 5** (Axios) — Security, one command
3. **Bug 4** (Ghost entities) — Database fix + prevention
4. **Bug 3** (Status change detection) — UX improvement
5. **Bug 2** (Approve both) — Resolves automatically when Bug 1 is fixed; verify with Playwright

---
*Research completed: 2026-02-10*
