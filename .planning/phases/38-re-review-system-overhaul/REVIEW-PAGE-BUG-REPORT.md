# Review.vue End-to-End Testing Bug Report

**Date:** 2026-01-26
**Tester:** Automated Playwright testing with Claude
**Test Entity:** sysndd:4 (ABCD1 - Adrenoleukodystrophy)

## Summary

End-to-end testing of the Review page workflow revealed **4 critical bugs** that prevent the re-review workflow from functioning correctly. The bugs affect both the Edit Review and Edit Status modals.

---

## Bug #1: Incorrect `isUpdate` Logic in Review Submission

**Severity:** CRITICAL - Blocks core workflow
**File:** `app/src/views/review/Review.vue:1362`
**Error:** `400 Bad Request` when submitting Edit Review form

### Description
When submitting the Edit Review form for an existing review, the API returns a 400 error because the code attempts to CREATE a new review instead of UPDATE the existing one.

### Root Cause
The `submitReviewChange()` method incorrectly determines whether to create or update:

```javascript
async submitReviewChange() {
  try {
    const isUpdate = this.review_info.re_review_review_saved === 1;  // BUG: Wrong check
    await this.reviewForm.submitForm(isUpdate, true);
    // ...
  }
}
```

The `re_review_review_saved` flag indicates whether the user has ALREADY saved changes during this re-review cycle, not whether the review EXISTS. For entity 4:
- `review_id = 4` (review EXISTS)
- `re_review_review_saved = 0` (not yet saved in current re-review cycle)

This causes `isUpdate = false`, which calls:
- `POST /api/review/create?re_review=true` ❌

When it should call:
- `PUT /api/review/update?re_review=true` ✅

### Fix
Change the condition to check if the review exists:

```javascript
const isUpdate = this.review_info.review_id != null;
```

Or check the composable's internal state:

```javascript
const isUpdate = this.reviewForm.reviewId != null;
```

---

## Bug #2: Modal `@show` Handler Resets Data After Load

**Severity:** CRITICAL - Blocks both modals from showing data
**File:** `app/src/views/review/Review.vue:1506-1513`

### Description
Both Edit Review and Edit Status modals show empty forms even though data was loaded from the API. The Status Category dropdown shows "Select status..." instead of "Definitive".

### Root Cause
The modal event handlers execute in the wrong order:

1. `infoStatus()` / `infoReview()` loads data from API ✅
2. `this.$refs[modal.id].show()` is called
3. `@show="onStatusModalShow"` triggers `resetForm()` ❌
4. All loaded data is cleared!

```javascript
onStatusModalShow() {
  // This runs AFTER data was loaded, clearing it!
  this.statusForm.resetForm();
}

onReviewModalShow() {
  // Same issue
  this.reviewForm.resetForm();
}
```

### Fix
Option A: Move data loading AFTER modal show:
```javascript
async infoStatus(item, index, button) {
  this.$refs[this.statusModal.id].show();
  await this.statusForm.loadStatusData(item.status_id, item.re_review_status_saved);
}
```

Option B: Remove the `@show` handlers if reset is done elsewhere:
```javascript
// Remove @show handlers entirely if clearDraft() and data loading handle the reset
```

Option C: Use `@shown` instead of `@show` (triggers after modal is fully visible):
```html
<BModal @shown="onStatusModalShown">
```

---

## Bug #3: EntityBadge Missing in Status Modal Header

**Severity:** MINOR - UI issue, doesn't block workflow
**File:** `app/src/views/review/Review.vue:558-560`

### Description
The Status modal header shows Gene, Disease, and Inheritance badges but is missing the EntityBadge (sysndd:4).

### Root Cause
The `v-if` condition checks `statusFormData.entity_id`:

```html
<EntityBadge
  v-if="statusFormData.entity_id"  <!-- This may be undefined due to Bug #2 -->
  :entity-id="statusFormData.entity_id"
  ...
/>
```

Since Bug #2 resets the form data, `statusFormData.entity_id` becomes `undefined`.

### Fix
This will be fixed automatically when Bug #2 is resolved. Alternatively, use `entity_info.entity_id` which is loaded via `getEntity()`:

```html
<EntityBadge
  v-if="entity_info.entity_id"
  :entity-id="entity_info.entity_id"
  ...
/>
```

---

## Bug #4: Same `isUpdate` Logic Issue in Status Submission

**Severity:** CRITICAL - Blocks core workflow (likely)
**File:** `app/src/views/review/Review.vue:1349-1358`

### Description
The Status submission has the same flawed logic as Bug #1:

```javascript
async submitStatusChange() {
  try {
    const isUpdate = this.statusFormData.re_review_status_saved === 1;  // BUG
    await this.statusForm.submitForm(isUpdate, true);
    // ...
  }
}
```

### Fix
Same as Bug #1 - check if status exists:

```javascript
const isUpdate = this.statusFormData.status_id != null;
```

---

## Additional Observations

### Session/Authentication Issue (Non-blocking)
During testing, navigation between pages occasionally caused logout with error:
```
"undefined" is not valid JSON
```
This may be related to token handling but didn't consistently reproduce.

### Test Data Used
- Entity: sysndd:4 (ABCD1 - X-linked Adrenoleukodystrophy)
- Current Status: Definitive
- Current Category: Associated with NDD
- Review ID: 4
- Status ID: 2077

### Synopsis Entered During Testing
```
X-linked ALD caused by ABCD1 mutations affects nervous system white matter and adrenal cortex via VLCFA accumulation. Seven phenotypes recognized: childhood cerebral (4-8y onset, rapid progression to vegetative state), adolescent cerebral, adult cerebral, adrenomyeloneuropathy (AMN, most common at 65%, adult-onset spastic paraparesis), Addison-only (11%), asymptomatic, and female heterozygotes (mild spastic paraparesis). No genotype-phenotype correlation exists - identical mutations produce different phenotypes even in monozygotic twins. Elevated plasma C26:0 VLCFA diagnostic. PMID:20301491 provides comprehensive clinical overview.
```

---

## Recommended Fix Order

1. **Bug #2 (Modal @show handlers)** - Fix first, enables testing of other bugs
2. **Bug #1 (Review isUpdate)** - Critical for review submission
3. **Bug #4 (Status isUpdate)** - Critical for status submission
4. **Bug #3 (EntityBadge)** - Will likely auto-resolve with Bug #2

---

## Test Environment

- Browser: Chromium (via Playwright)
- URL: http://localhost:5173/Review
- User: Bernt (Administrator role)
- API: http://localhost/api/
