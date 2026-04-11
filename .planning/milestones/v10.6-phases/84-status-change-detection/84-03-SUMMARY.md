# Phase 84 Plan 03: ApproveReview & ApproveStatus Change Detection Summary

**Phase:** 84-status-change-detection
**Plan:** 03
**Type:** execute
**Completed:** 2026-02-10
**Duration:** 3 minutes

---

## One-Liner

Add change detection to ApproveReview and ApproveStatus raw Status/Review forms with silent skip on save, unsaved-changes warnings, and fix missing review_change indicator in ApproveStatus.

---

## What Was Delivered

### Artifacts Created/Modified

**Modified:**
- `app/src/views/curate/ApproveReview.vue` — Added change detection to both status and review edit modals
- `app/src/views/curate/ApproveStatus.vue` — Added change detection to status edit modal and review_change indicator

### Key Features

1. **ApproveReview Change Detection:**
   - Tracks status form changes (category_id, comment, problematic)
   - Tracks review form changes (synopsis, comment, phenotypes, variation, publications, genereviews)
   - Silent skip when submitting without changes (no API call)
   - Unsaved-changes confirmation on modal close
   - Uses `arraysAreEqual` helper for array comparisons

2. **ApproveStatus Change Detection:**
   - Tracks status form changes (category_id, comment, problematic)
   - Silent skip when submitting without changes
   - Unsaved-changes confirmation on modal close

3. **Review Change Indicator:**
   - Added `review_change` exclamation-triangle overlay on ApproveStatus edit button
   - Matches pattern from ApproveReview's `status_change` indicator
   - Added to legend items for discoverability

---

## Technical Approach

### Implementation Pattern

Both views use raw `Status` and `Review` class instances (not composables), so change detection is implemented locally:

1. **Snapshot loaded data** in `loadStatusInfo()` / `loadReviewInfo()`
2. **Computed properties** compare current values to snapshot
3. **Silent skip** in submit methods when `!hasChanges`
4. **Modal @hide handlers** prevent close with unsaved changes
5. **Reset snapshots** in `resetForm()`

### Status Form Tracking
```javascript
statusLoadedData: {
  category_id: this.status_info.category_id,
  comment: this.status_info.comment || '',
  problematic: this.status_info.problematic || false,
}
```

### Review Form Tracking
```javascript
reviewLoadedData: {
  synopsis: this.review_info.synopsis || '',
  comment: this.review_info.comment || '',
  phenotypes: [...this.select_phenotype],
  variationOntology: [...this.select_variation],
  publications: [...this.select_additional_references],
  genereviews: [...this.select_gene_reviews],
}
```

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Decisions Made

| ID | Decision | Rationale | Impact |
|----|----------|-----------|--------|
| D84-03-01 | Store loaded data snapshots in component state | ApproveReview/ApproveStatus use raw classes, not composables | Local change detection per view |
| D84-03-02 | Use exact array comparison (sorted) | Phenotype/variation order shouldn't matter | Avoids false positives |
| D84-03-03 | Check `!isBusy` in modal hide handler | Prevent warning during successful submit | Better UX |

---

## Verification Results

### Type-Check
✅ `npm run type-check` — No TypeScript errors

### Linting
✅ `npm run lint` — No ESLint errors

### Tests
✅ All 244 tests pass (including 22 test files, 6 a11y suites)

---

## Commit History

| Commit | Type | Description |
|--------|------|-------------|
| 621e43d3 | feat | Add change detection to ApproveReview status and review forms |
| fd784df8 | feat | Add change detection to ApproveStatus and fix missing review_change indicator |

---

## Integration Points

### Upstream Dependencies
- Phase 84 Plan 01 — Composable patterns (reference only, not used here)
- Phase 84 Plan 02 — ModifyEntity implementation (different pattern)

### Downstream Impact
- Completes change detection across all three curation views
- Backend `review_change` flag now visible in ApproveStatus UI
- Consistent user experience across ModifyEntity, ApproveReview, ApproveStatus

---

## Follow-Up Items

### For Phase 85
None — change detection complete for v10.6

### Technical Debt
- ApproveReview/ApproveStatus still use raw classes instead of composables (by design, approved pattern)
- Modal `@hide` uses `window.confirm` (could be upgraded to custom modal in future)

---

## Success Metrics

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Tasks completed | 2/2 | 2/2 | ✅ |
| Files modified | 2 | 2 | ✅ |
| Type errors | 0 | 0 | ✅ |
| Lint errors | 0 | 0 | ✅ |
| Tests passing | 100% | 100% (244/244) | ✅ |
| Change indicators | All views | ApproveReview + ApproveStatus | ✅ |

---

## Knowledge Captured

### Pattern: Change Detection Without Composables

When using raw class instances in Options API components:
1. Store snapshot after data load
2. Compare in computed property
3. Guard submit methods with silent skip
4. Prevent modal close with `event.preventDefault()`
5. Reset snapshot on form reset

### Review Change Indicator Pattern

Overlay small warning icon on action button:
```vue
<span class="position-relative d-inline-block">
  <i class="bi bi-pen" />
  <i v-if="row.item.review_change"
     class="bi bi-exclamation-triangle-fill position-absolute text-warning"
     style="top: -0.3em; right: -0.5em; font-size: 0.7em" />
</span>
```

---

*Phase: 84-status-change-detection*
*Plan: 03*
*Completed: 2026-02-10*
*Duration: 3 minutes*
