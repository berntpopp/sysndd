# Manage Re-Review Manual Assignment Panel Design

## Problem

`app/src/views/curate/ManageReReview.vue` is 1708 lines and still owns several distinct workflows in one file. The typed re-review API boundary and table filter helpers are already extracted, so the next useful refactor should not be another small utility move. The highest-value cohesive slice is the manual entity assignment workflow inside the batch setup section.

That workflow currently mixes UI rendering, selected-entity display state, assignment form fields, entity list controls, loading/assigning state, and boundary-gene alert presentation directly into the parent view. The parent also owns the actual API calls, toast/aria side effects, and refresh orchestration. The first split should preserve that ownership to avoid broad behavior changes while reducing the parent template and creating a clear UI component boundary.

## Goals

1. Extract the manual-pick UI from `ManageReReview.vue` into `app/src/views/curate/components/ManualEntityAssignmentPanel.vue`.
2. Preserve current visible behavior:
   - assign-to select and disabled first option
   - optional batch name input
   - selected-count display
   - assign button disabled state and spinner behavior
   - close setup behavior
   - refresh and clear actions
   - search input update/clear behavior
   - available entity table fields and checkbox selection
   - selected-row class
   - available entity count copy
   - boundary-gene alert copy and visibility
3. Keep re-review data loading, mutation calls, toast copy, aria announcements, validation, modal state, and refresh orchestration in `ManageReReview.vue` for this slice.
4. Strengthen focused tests before extraction so parent behavior and the child component contract are pinned.
5. Lower `scripts/code-quality-file-size-baseline.tsv` for `ManageReReview.vue` only if the production file shrinks below the current baseline.

## Non-Goals

- Do not change public routes, typed API-client signatures, backend endpoints, or request payloads.
- Do not move `assignReReviewEntities()`, `listAvailableReReviewEntities()`, or refresh orchestration into a composable in this PR.
- Do not extract the reassign/recalculate modals in this PR.
- Do not redesign the Manage Re-review page or change visible copy.
- Do not split unrelated table, filter, or legacy-batch assignment behavior.

## Current Architecture

`ManageReReview.vue` is an Options API view that mounts four loaders:

- `loadUserList()`
- `loadReReviewTableData()`
- `loadAvailableEntities()`
- `loadStatusOptions()`

It already uses typed clients from `app/src/api/re_review.ts`, `app/src/api/user.ts`, and `app/src/api/list.ts`. It also uses `filterReReviewBatches()` and `sortReReviewBatches()` from `app/src/views/curate/utils/reReviewFilters.ts`.

The manual assignment block is template-heavy. Its data and methods live in the parent:

- state: `availableEntities`, `availableEntityTotal`, `selectedEntityIds`, `manualEntityFilter`, `entityAssignUserId`, `entityAssignBatchName`, `isLoadingEntities`, `isAssigningEntities`, `entitySelectFields`
- boundary alert state: `previewBoundaryGene`, `previewGeneCount`, `previewEntityCount`, `boundaryGeneAlertVisible`, `boundaryGeneAlertMessage`
- methods: `loadAvailableEntities()`, `isEntitySelected()`, `toggleEntitySelection()`, `clearManualSelection()`, `manualEntityRowClass()`, `handleEntityAssignment()`

## Proposed Architecture

Create `ManualEntityAssignmentPanel.vue` as a presentational child component. It receives all state through props and reports all user actions through emits.

The child component owns:

- rendering the manual controls and entity table
- computing whether an entity row is selected from `selectedEntityIds`
- computing the selected-row class for `BTable`
- forwarding search update/clear events as `refresh-entities`
- forwarding checkbox changes as `toggle-entity-selection`
- forwarding Assign, Refresh, Clear, and Close button clicks
- rendering the boundary-gene alert when `boundaryGeneAlertVisible` is true

`ManageReReview.vue` owns:

- data loading and mutation methods
- validation and toast/aria copy
- refreshing the assignment table and entity list
- existing API-client calls
- parent-level mode switching and summary metrics

This keeps the first split low-risk: the new component is a controlled UI surface, and the existing parent methods remain the source of behavior.

## Component Contract

`ManualEntityAssignmentPanel.vue` props:

- `userOptions`
- `entityAssignUserId`
- `entityAssignBatchName`
- `selectedEntityIds`
- `availableEntities`
- `availableEntityTotal`
- `entitySelectFields`
- `manualEntityFilter`
- `isLoadingEntities`
- `isAssigningEntities`
- `boundaryGeneAlertVisible`
- `boundaryGeneAlertMessage`

Emits:

- `update:entityAssignUserId`
- `update:entityAssignBatchName`
- `update:manualEntityFilter`
- `assign-entities`
- `refresh-entities`
- `clear-selection`
- `toggle-entity-selection`
- `close`

The parent uses `v-model:entity-assign-user-id`, `v-model:entity-assign-batch-name`, and `v-model:manual-entity-filter` to preserve its existing state names.

## Test Design

Add a new child component spec:

- renders assign controls, selected count, and available entity count
- disables Assign when no entity or no user is selected
- emits model updates for user, batch name, and search text
- emits `toggle-entity-selection` for checkbox changes
- emits `assign-entities`, `refresh-entities`, `clear-selection`, and `close`
- preserves disabled states for Assign and Clear
- applies the selected-row class through the table row-class callback
- renders the existing boundary-gene alert copy when requested

Strengthen `ManageReReview.spec.ts` before production extraction:

- assert the manual assignment panel receives loaded entities and total count through rendered output
- assert successful assignment still sends the same typed-client payload, clears parent state, and refreshes table plus entity list
- assert missing-selection validation still avoids the API call and keeps the current warning toast
- assert boundary-gene alert visibility/copy still works through the extracted panel

Run the parent spec against unchanged production code first where assertions target current behavior. The child component spec is introduced with the component implementation because the file does not exist yet.

## Verification

Focused checks:

```bash
cd app && npx vitest run src/views/curate/ManageReReview.spec.ts src/views/curate/components/ManualEntityAssignmentPanel.spec.ts
cd app && npm run type-check
git diff --check
make code-quality-audit
```

Before handoff, run:

```bash
make pre-commit
```

Run `make ci-local` if the environment permits and record the exact blocker if it does not.

## Follow-Ups

- Extract reassign/recalculate modals after this panel split lands.
- Consider a later composable for manual assignment API orchestration only after the UI boundary is stable.
- Continue reducing `ManageReReview.vue` by workflow sections rather than tiny helper movement.
