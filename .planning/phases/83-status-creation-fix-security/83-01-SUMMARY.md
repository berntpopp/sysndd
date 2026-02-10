---
phase: 83-status-creation-fix-security
plan: 01
status: complete
subsystem: frontend-curation
tags: [vue, axios, security, bug-fix, modal-lifecycle]

# Dependency graph
requires: [research-v10.6]
provides: [working-status-creation, secure-axios]
affects: [84-status-change-detection, 85-ghost-entity-cleanup]

# Tech tracking
tech-stack:
  added: []
  patterns: [modal-lifecycle-management]

# Files
key-files:
  created: []
  modified:
    - app/src/views/curate/ModifyEntity.vue
    - app/package.json
    - app/package-lock.json
    - api/functions/status-repository.R

# Decisions
decisions:
  - id: D83-01
    what: "Reset status form BEFORE data load instead of on modal @show event"
    why: "Modal @show fires asynchronously after data load, destroying entity_id"
    alternatives: ["Remove @show handler", "Use different modal lifecycle event"]
    chosen: "Move reset to start of showStatusModify() before getEntity()"
    trade-offs: "More explicit ordering, clearer intent, prevents race conditions"

# Metrics
duration: "2 minutes"
completed: "2026-02-10"
---

# Phase 83 Plan 01: Status Creation Fix & Security

**One-liner:** Fixed modal lifecycle bug causing HTTP 500 on status changes + patched axios CVE-2026-25639

## What Was Built

Fixed critical regression in entity status modification workflow where form reset happened AFTER data load, causing HTTP 500 errors on every status change attempt. Also patched axios DoS vulnerability.

### Root Cause

The `ModifyEntity.vue` component had incorrect modal lifecycle ordering:
1. `showStatusModify()` called `loadStatusByEntity()` which set `formData.entity_id`
2. `this.$refs.modifyStatusModal.show()` triggered modal render
3. Modal's `@show="onModifyStatusModalShow"` fired asynchronously
4. `onModifyStatusModalShow()` called `resetStatusForm()` which deleted `entity_id`
5. User submitted form with no `entity_id` → HTTP 500

### The Fix

**Task 1: Reorder reset/load sequence**
- Move `resetStatusForm()` to START of `showStatusModify()` before data load
- Remove `resetStatusForm()` from `onModifyStatusModalShow()`
- Result: Clean state → load data → preserve data through modal show → successful submit

**Task 2: Security patch**
- Update axios 1.13.4 → 1.13.5
- Fixes CVE-2026-25639 (DoS via prototype pollution in mergeConfig)

**Task 3: Verification**
- Confirmed "approve both" checkbox restoration requires no code changes
- It's a symptom of the status creation failure (status_change flag never set)
- Will restore automatically once status creation works

## Deliverables

| Artifact | What it does |
|----------|-------------|
| `app/src/views/curate/ModifyEntity.vue` | Fixed form reset ordering, preserves entity_id through modal lifecycle |
| `app/package.json` | Updated axios dependency to secure version |
| `app/package-lock.json` | Locked axios 1.13.5 |
| `api/functions/status-repository.R` | Compact NULLs before tibble conversion in status_create |

## Commits

| Hash | Message |
|------|---------|
| d314313b | fix(83-01): fix status form reset ordering |
| 8a2dd8d7 | fix(83-01): update axios to 1.13.5 |
| b861fc11 | fix(83-01): compact NULL values in status_create before tibble conversion |

## Technical Details

### Modal Lifecycle Pattern

**Problem:** Bootstrap-Vue-Next modal events fire asynchronously after show() call.

**Solution:** Initialize data BEFORE show(), not in @show handler.

```typescript
// BEFORE (buggy):
async showStatusModify() {
  await loadData();        // Sets formData.entity_id
  this.$refs.modal.show(); // Triggers @show event
}
onModifyStatusModalShow() {
  resetForm();             // DELETES entity_id (async timing!)
}

// AFTER (fixed):
async showStatusModify() {
  resetForm();             // Clean slate FIRST
  await loadData();        // Sets formData.entity_id
  this.$refs.modal.show(); // Data already loaded, preserved
}
onModifyStatusModalShow() {
  // Intentionally empty - reset moved to showStatusModify()
}
```

### Data Flow Verification

Traced entity_id through submission path:
1. `showStatusModify()` → `loadStatusByEntity()` sets `formData.entity_id` (useStatusForm.ts:157)
2. Form data preserved through modal show
3. `submitForm()` includes `entity_id` in POST body (useStatusForm.ts:222)
4. API receives entity_id → status creation succeeds
5. DB sets `status_change=1` on entity
6. `ApproveReview.vue` shows "approve both" checkbox (line 521: `v-if="entity.status_change"`)

## Deviations from Plan

**Backend fix required:** Playwright E2E testing revealed a pre-existing backend bug in `status_create()` — JSON `null` values from the frontend become R `NULL` which `tibble::as_tibble()` rejects with "All columns in a tibble must be vectors". Fixed by adding `purrr::compact()` before tibble conversion. This bug was hidden because the old broken form never reached this code path.

## Issues Encountered

Pre-existing backend bug in `api/functions/status-repository.R` — see Deviations above.

## Test Results

- ✅ `npm run type-check` — 0 errors
- ✅ `npm run lint` — 0 new errors
- ✅ axios 1.13.5 installed, no axios vulnerabilities
- ✅ Code review: reset → load → show ordering verified
- ✅ Data flow trace: entity_id preserved through modal lifecycle
- ✅ **E2E Playwright:** Status change POST returns HTTP 200 with entity_id in body
- ✅ **E2E Playwright:** "Approve both" checkbox visible on ApproveReview for entity with status_change

## Next Phase Readiness

**Ready for Phase 84 (Status Change Detection)**

The status creation flow now works correctly. Phase 84 can implement change detection to prevent unnecessary status record creation when no changes were made.

**Blocker removed:** Christiane can now change entity statuses without HTTP 500 errors.

## Impact

- **User impact:** Unblocks daily curation workflow for Christiane and other curators
- **Security impact:** Closes axios DoS vulnerability (CVE-2026-25639)
- **System impact:** "Approve both" checkbox will automatically restore once curators create new status records
- **Technical debt:** None introduced, actually improved code clarity with explicit ordering

## Lessons Learned

1. **Modal lifecycle timing:** Bootstrap-Vue-Next @show events fire asynchronously — never rely on them for data initialization
2. **Async race conditions:** Even "obvious" orderings can break when events fire asynchronously
3. **Symptom vs root cause:** "Approve both" missing was a symptom of the status creation bug, not a separate issue

---

**Summary:** Fixed critical modal lifecycle bug in status modification flow + patched axios DoS vulnerability. Status changes now work, unblocking curation workflow.
