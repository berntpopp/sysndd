# Refactor #346 Wave 2 Frontend Workflows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce every remaining oversized frontend table, curation, admin, form, and entity-view source file to 600 lines or fewer without changing visible or API behavior.

**Architecture:** Establish `GenericTable`’s composition seam first, then extract domain-specific table controllers rather than a speculative universal controller. High-risk curation pages keep typed API clients and move complete workflow responsibilities into tested composables or child panels; styles travel only with extracted UI ownership.

**Tech Stack:** Vue 3, TypeScript, BootstrapVueNext, Vitest/MSW, typed API clients, Playwright, vue-tsc, ESLint.

**Spec:** `.planning/superpowers/specs/2026-07-10-refactor-346-complete-closure-design.md`

---

Wave 2 starts only after Wave 1 is merged. Each domain below is a separate thematic PR;
set `TASK_BRANCH` to the listed value and create it from freshly merged master:

```bash
git switch master
git pull --ff-only origin master
git switch -c "$TASK_BRANCH"
```

```text
Task 1             refactor/346-w2-generic-table
Task 2 entities    refactor/346-w2-entities-table
Task 2 genes       refactor/346-w2-genes-table
Task 2 phenotypes  refactor/346-w2-phenotypes-table
Task 3             refactor/346-w2-nddscore-table
Task 4             refactor/346-w2-batch-criteria
Task 5             refactor/346-w2-approval-modals
Task 6 ontology    refactor/346-w2-manage-ontology
Task 6 users       refactor/346-w2-manage-users
Task 7             refactor/346-w2-approve-user
Task 8             refactor/346-w2-approve-review
Task 9             refactor/346-w2-manage-rereview
Task 10            refactor/346-w2-entity-view
```

Task 1 merges before the table-family PRs. Every domain PR runs its exact targeted and
full relevant checks, receives Claude and Codex review, resolves findings, and merges
before any dependent branch is cut. Before review, the integration owner regenerates
the baseline, proves no entry increased, and includes the task's downward baseline
change in that same domain PR; domain agents do not edit the shared file.

### Task 1: Decompose GenericTable’s details and sorting responsibilities

**Files:**
- Create: `app/src/components/small/GenericTableDetails.vue`
- Create: `app/src/components/small/GenericDesktopTable.vue`
- Create: `app/src/components/small/useGenericTableSorting.ts`
- Create: `app/src/components/small/useGenericTableSorting.spec.ts`
- Modify: `app/src/components/small/GenericTable.vue`
- Modify: `app/src/components/small/GenericTable.spec.ts`

- [ ] Add tests for same-column asc→desc toggle, new-column asc start,
  `sortable:false` no-op, array/legacy string normalization, both
  `update:sort-by` and `update-sort`, detail-copy success/failure, and clipboard timer
  cleanup.
- [ ] Run the new spec and observe the missing composable failure.
- [ ] Move only fallback row details and clipboard lifecycle to
  `GenericTableDetails.vue`; retain the outer `row-expansion` and
  `row-expansion-extra` slots in the parent.
- [ ] Move the complete desktop `BTable` responsibility—including all current cell-slot
  forwarding blocks, the `filter-controls`/`thead-top` slot, busy/empty/table attributes,
  details-toggle wiring, and sort events—to `GenericDesktopTable.vue`. `GenericTable.vue`
  becomes a thin wrapper that forwards all consumer slots/props/emits to the desktop
  child and uses `GenericTableDetails.vue` for the row-expansion default. Mobile rows,
  pagination, and surrounding toolbar chrome belong to parent consumer SFCs and remain
  out of scope; do not add them to `GenericTable.vue`. Do not rename slot props or
  replace domain slots with a generic if/else renderer.
- [ ] Move local sort normalization and header/sorted handlers to the composable.
  Preserve every prop, emit, slot, responsive row, tooltip, and imperative behavior.
- [ ] Verify:

```bash
cd app
npx vitest run src/components/small/useGenericTableSorting.spec.ts \
  src/components/small/GenericTable.spec.ts \
  src/components/analyses/PublicationsNDDTable.spec.ts \
  src/components/analyses/PubtatorNDDTable.spec.ts \
  src/components/analyses/PubtatorNDDGenes.spec.ts \
  src/components/tables/TablesEntities.spec.ts \
  src/components/tables/TablesPhenotypes.spec.ts \
  src/components/nddscore/NddScoreGeneTable.spec.ts \
  src/views/curate/ApproveReview.spec.ts
npm run type-check
npx eslint src/components/small/GenericTable.vue \
  src/components/small/GenericDesktopTable.vue \
  src/components/small/GenericTableDetails.vue \
  src/components/small/useGenericTableSorting.ts
wc -l src/components/small/GenericTable.vue \
  src/components/small/GenericDesktopTable.vue \
  src/components/small/GenericTableDetails.vue \
  src/components/small/useGenericTableSorting.ts
```

Expected: PASS and every production file below 600. Commit as
`refactor(app): decompose GenericTable details and sorting (#346)`.

### Task 2: Extract entity, gene, and phenotype table controllers

**Files:**
- Create: `app/src/components/tables/useEntitiesTable.ts`
- Create: `app/src/components/tables/entityTableConfig.ts`
- Modify: `app/src/components/tables/TablesEntities.vue`
- Modify: `app/src/components/tables/TablesEntities.spec.ts`
- Create: `app/src/components/tables/useGenesTable.ts`
- Create: `app/src/components/tables/geneTableConfig.ts`
- Create: `app/src/components/tables/TablesGenes.spec.ts`
- Modify: `app/src/components/tables/TablesGenes.vue`
- Modify: `app/src/api/genes.ts`
- Modify: `app/src/api/genes.spec.ts`
- Create: `app/src/components/tables/usePhenotypeEntitiesTable.ts`
- Modify: `app/src/components/tables/TablesPhenotypes.vue`
- Modify: `app/src/components/tables/TablesPhenotypes.spec.ts`

- [ ] Add domain tests for initial URL state, exactly-one initial request,
  stale-response rejection, cursor transitions, API `fspec` merge, URL-disabled mode,
  return links, and XLSX filenames. Preserve the entity mapping one-fetch-per-entity
  contract and phenotype in-place filter identity.
- [ ] Use the existing typed `listEntities`/`listEntitiesXlsx` from `api/entity.ts`
  and `browsePhenotypeEntities`/`browsePhenotypeEntitiesXlsx` from
  `api/phenotype.ts`. Add typed `listGenesXlsx(params, config): Promise<Blob>` using
  `format='xlsx'` and `responseType='blob'`; prove symbol cursors remain strings and
  filename remains `sysndd_gene_table.xlsx`.
- [ ] Move each domain’s field/filter/detail configuration to its own config module
  and its URL/request/response/pagination orchestration to its own composable. Remove
  injected Axios from entities, genes, and phenotypes; none of the migrated controllers
  may call or pass an Axios instance to `useTableMethods`. Leave `useTableMethods.ts`
  intact for unrelated legacy consumers and prove these SFCs use typed `app/src/api/*`
  functions only.
- [ ] Verify:

```bash
cd app
npx vitest run src/components/tables/TablesEntities.spec.ts \
  src/components/tables/TablesGenes.spec.ts \
  src/components/tables/TablesPhenotypes.spec.ts \
  src/api/entity.spec.ts src/api/genes.spec.ts src/api/phenotype.spec.ts
npm run type-check
npm run type-check:strict
npx eslint src/components/tables/TablesEntities.vue \
  src/components/tables/TablesGenes.vue \
  src/components/tables/TablesPhenotypes.vue \
  src/components/tables/useEntitiesTable.ts \
  src/components/tables/useGenesTable.ts \
  src/components/tables/usePhenotypeEntitiesTable.ts src/api/genes.ts
wc -l src/components/tables/{TablesEntities,TablesGenes,TablesPhenotypes}.vue \
  src/components/tables/{useEntitiesTable,useGenesTable,usePhenotypeEntitiesTable}.ts
```

Expected: PASS; all six production modules below 600. Commit each domain separately.

### Task 3: Extract the NDDScore gene-table controller

**Files:**
- Create: `app/src/components/nddscore/useNddScoreGeneTable.ts`
- Create: `app/src/components/nddscore/useNddScoreGeneTable.spec.ts`
- Modify: `app/src/components/nddscore/NddScoreGeneTable.vue`
- Modify: `app/src/components/nddscore/NddScoreGeneTable.spec.ts`

- [ ] Test URL hydration of range/HPO/search/sort/page/page-size, request-serial
  stale success/error rejection, full filter reset, and HPO-load graceful degradation.
- [ ] Move load, URL, state, and action functions into the composable; continue using
  existing filter construction, filter UI, and column modules without duplication.
- [ ] Run component/composable/filter tests, type-check, lint, and `wc -l`; require
  every production module below 600. Commit as
  `refactor(app): extract NDDScore table controller (#346)`.

### Task 4: Extract BatchCriteriaForm option/search orchestration

**Files:**
- Create: `app/src/components/forms/useBatchCriteriaOptions.ts`
- Create: `app/src/components/forms/useBatchCriteriaOptions.spec.ts`
- Create: `app/src/components/forms/BatchCriteriaEntityPicker.vue`
- Modify: `app/src/components/forms/BatchCriteriaForm.vue`
- Create: `app/src/components/forms/BatchCriteriaForm.spec.ts`

- [ ] Test mount option loading, 300 ms entity-search debounce, stale-search rejection,
  successful `batch-created` emit, failed-submit no emit, and reset delegation.
- [ ] Move option loading/search state to the composable and the complete entity picker
  template/styles to the child. Retain `useBatchForm`, form schema, validation, and
  public emits in the parent.
- [ ] Run both new specs, type-check, lint, and require all production files below 600.
  Commit as `refactor(app): extract batch criteria entity picker (#346)`.

### Task 5: Extract ApprovalTable modal ownership

**Files:**
- Create: `app/src/components/review/StatusApprovalModals.vue`
- Create: `app/src/components/review/StatusApprovalModals.spec.ts`
- Modify: `app/src/components/ApprovalTableView.vue`
- Create: `app/src/components/ApprovalTableView.spec.ts`
- Verify: `app/src/views/curate/ApproveStatus.spec.ts`

- [ ] Test modal prop/emit forwarding, parent `showModal`/`hideModal`, item sync,
  filtered total/page reset, and busy mirroring.
- [ ] Move all four status-specific modal blocks plus their modal styles to the child.
  Preserve table/cell/row/mobile slots and the parent imperative exposure.
- [ ] Run the three specs, type-check, lint, and require both production components
  below 600. Commit as `refactor(app): extract status approval modals (#346)`.

### Task 6: Extract ontology and user admin page controllers

**Files:**
- Create: `app/src/views/admin/composables/useOntologyAdminTable.ts`
- Create: `app/src/views/admin/ontologyTableConfig.ts`
- Modify: `app/src/views/admin/ManageOntology.vue`
- Modify: `app/src/views/admin/ManageOntology.spec.ts`
- Create: `app/src/views/admin/composables/useManageUserPage.ts`
- Modify: `app/src/views/admin/ManageUser.vue`
- Modify: `app/src/views/admin/ManageUser.spec.ts`

- [ ] Add ontology tests for active chips, cursor transitions, stale response, edit
  payload/update refresh, and export filename. Add user tests for preset seeding once,
  selection cap 20, last-admin behavior, and every legacy exposed alias.
- [ ] Move ontology filter/watch/URL/load/edit/update/export responsibility to the
  composable and static fields to config. Move only ManageUser page-level composition,
  while retaining `useUserData`, `useUserMutations`, `useBulkUserActions`,
  `useUserModals`, and `useUserTablePresentation` as owners.
- [ ] Run both component specs, type-check, strict type-check, lint, and require all
  production files below 600. Commit each admin domain separately.

### Task 7: Extract ApproveUser queue orchestration

**Files:**
- Create: `app/src/views/curate/composables/useUserApprovalQueue.ts`
- Create: `app/src/views/curate/composables/useUserApprovalQueue.spec.ts`
- Modify: `app/src/views/curate/ApproveUser.vue`
- Modify: `app/src/views/curate/ApproveUser.spec.ts`

- [ ] Test pending-only filtering, combined search/role filter, page reset, review→reject
  modal transition, toast/announcement behavior, and role-before-approval ordering.
- [ ] Move queue/filter/pagination/modal/load/mutation state to the composable. Replace
  raw calls with existing typed user clients while preserving array/`{data}` unwrap.
- [ ] Run specs, type-check, lint, and require files below 600. Commit as
  `refactor(app): extract user approval queue (#346)`.

### Task 8: Extract ApproveReview controller and snapshot comparisons

**Files:**
- Create: `app/src/views/curate/composables/useApproveReviewController.ts`
- Create: `app/src/views/curate/utils/reviewApprovalSnapshots.ts`
- Create: `app/src/views/curate/utils/reviewApprovalSnapshots.spec.ts`
- Modify: `app/src/views/curate/ApproveReview.vue`
- Modify: `app/src/views/curate/ApproveReview.spec.ts`
- Verify: `app/src/views/curate/ApproveReview.a11y.spec.ts`

- [ ] Test order-insensitive selected-array snapshots and sensitivity to synopsis,
  comment, category, and problematic changes. Add dirty-modal preventDefault/confirm
  and status update-vs-create tests.
- [ ] Move state/load/modal/submission/reset/discard orchestration to the controller;
  keep `useReviewApprovalActions`, `useReviewHelpers`, lazy injected compatibility,
  and every exposed name unchanged.
- [ ] Run helper, functional, and a11y specs, type-check, lint, and require production
  files below 600. Commit as `refactor(app): extract review approval controller (#346)`.

### Task 9: Decompose ManageReReview by workflow

**Files:**
- Create: `app/src/views/curate/composables/useManageReReview.ts`
- Create: `app/src/views/curate/composables/useManageReReview.spec.ts`
- Create: `app/src/views/curate/components/ReReviewAssignmentTable.vue`
- Create: `app/src/views/curate/components/ReReviewBatchDialogs.vue`
- Modify: `app/src/views/curate/ManageReReview.vue`
- Modify: `app/src/views/curate/ManageReReview.spec.ts`
- Verify: `app/src/views/curate/ManageReReview.a11y.spec.ts`

- [ ] Add controller tests proving all four mount loaders start concurrently and
  recalculation omits incomplete date/status fields. Preserve nine endpoint calls,
  scalar unwrap, selection validation, fallback copy, refresh side effects, and
  boundary alert tests.
- [ ] Move shared state/counts/filter options/loaders/assignment actions/reassignment/
  recalculation to the composable. Move the complete table/toolbar responsibility to
  `ReReviewAssignmentTable`; move reassign/recalculate modal ownership to
  `ReReviewBatchDialogs`. Existing manual/refused panels remain unchanged.
- [ ] Move styles only with the child markup they style; keep page-level layout styles
  in the shell. No standalone CSS-size split is permitted.
- [ ] Run controller/component/a11y specs, type-check, strict type-check, lint, and
  require every production file below 600. Commit in controller, table, and dialogs
  increments with green tests after each.

### Task 10: Extract EntityView hero and resource presentation

**Files:**
- Create: `app/src/views/pages/components/EntityViewHero.vue`
- Create: `app/src/views/pages/components/ClinicalSynopsisCard.vue`
- Create: `app/src/views/pages/components/EntityEvidenceGrid.vue`
- Modify: `app/src/views/pages/EntityView.vue`
- Modify: `app/src/views/pages/__tests__/EntityView.spec.ts`

- [ ] Add child-contract assertions for hero metadata/source links, synopsis copy and
  loading/error/empty/data states, and the publications/gene-reviews/phenotypes/variation
  evidence-grid states.
- [ ] Move the hero template/styles to `EntityViewHero`, synopsis presentation to
  `ClinicalSynopsisCard`, and the four chip-grid resources to `EntityEvidenceGrid`.
  Keep all seven resource composables, parallel fetching, route redirect, `useHead`, and
  copy implementation in the parent. Each child receives one focused display model and
  focused action emits instead of a wide collection of independent state props.
- [ ] Run the existing comprehensive spec plus new child cases, type-check, lint, and
  require all production components below 600. Commit as
  `refactor(app): decompose entity view presentation (#346)`.

### Task 11: Verify merged Wave 2 integration

After all domain PRs merge, pull fresh master and verify its already-ratcheted state.

- [ ] Regenerate the baseline once; prove every Wave 2 frontend row disappears and no
  value increases.

```bash
bash scripts/code-quality-audit.sh --write-baseline
git diff --exit-code -- scripts/code-quality-file-size-baseline.tsv
```

- [ ] Run:

```bash
make lint-app
cd app && npm run test:unit && npm run type-check && npm run type-check:strict
cd ..
make code-quality-audit
make pre-commit
git diff --check
```

- [ ] Run authenticated local regression:

```bash
make playwright-stack
cd app && PLAYWRIGHT_BASE_URL=http://localhost:8088 \
  npx playwright test tests/e2e/authenticated-admin-curation-design.spec.ts \
  --project=chromium-desktop
cd .. && make playwright-stack-down
```

- [ ] Require `git diff --exit-code -- scripts/code-quality-file-size-baseline.tsv` after
  `--write-baseline`; every Wave 2 row must already have been removed in its domain PR.
