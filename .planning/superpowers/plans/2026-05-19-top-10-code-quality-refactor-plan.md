# Top 10 Code Quality Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce the current top 10 oversized SysNDD production files through small, behavior-preserving, test-first extractions.

**Architecture:** Keep public Vue component props, emitted events, routes, API clients, and Plumber routes stable. Move cohesive responsibilities into colocated child components, composables, utility modules, R services, or repositories only when tests pin the behavior first. Update `scripts/code-quality-file-size-baseline.tsv` downward after each shrink and never raise an entry.

**Tech Stack:** Vue 3, TypeScript, Vitest, Vite type-checking, R/Plumber, testthat, lintr, SysNDD `make code-quality-audit`.

---

## Guardrails

- Work on branch `plan/top-10-code-quality-refactor`.
- Do not create git worktrees.
- Do not start broad rewrites or unrelated cleanup.
- Before each production extraction, strengthen or add focused tests and run them against unchanged behavior.
- After each cohesive extraction, run the target test, the relevant stack check, and `make code-quality-audit`.
- Commit after each cohesive extraction with a small, reviewable commit.
- Do not revert unrelated user changes.

## File Map

- Modify: `scripts/code-quality-file-size-baseline.tsv` for downward-only baseline ratchets.
- Modify: `app/src/views/curate/ManageReReview.vue`; possible creates under `app/src/views/curate/components/`, `app/src/views/curate/composables/`, and `app/src/views/curate/utils/`.
- Modify: `app/src/components/analyses/AnalyseGeneClusters.vue`; possible creates under `app/src/components/analyses/` or `app/src/composables/analyses/`.
- Modify: `api/endpoints/admin_endpoints.R`; possible creates under `api/services/` or `api/functions/`; tests in `api/tests/testthat/test-endpoint-admin.R`.
- Modify: `app/src/components/gene/GeneStructurePlotWithVariants.vue`; create `app/src/components/gene/geneStructureVariantPlotUtils.ts` and matching spec.
- Modify: `app/src/components/tables/TablesLogs.vue`; possible creates under `app/src/components/tables/` for log formatting or query helpers.
- Modify: `app/src/components/analyses/NetworkVisualization.vue`; possible creates under `app/src/components/analyses/` for selection helpers or child controls.
- Modify: `app/src/components/nddscore/NddScoreGeneTable.vue`; possible creates under `app/src/components/nddscore/` for URL/API filter helpers.
- Modify: `api/endpoints/publication_endpoints.R`; possible creates under `api/services/`; tests in `api/tests/testthat/test-endpoint-publication.R`.
- Modify: `app/src/components/tables/TablesPhenotypes.vue`; add `app/src/components/tables/TablesPhenotypes.spec.ts` before extraction.
- Modify: `app/src/components/analyses/PubtatorNDDGenes.vue`; add `app/src/components/analyses/PubtatorNDDGenes.spec.ts` before extraction.

---

### Task 0: Baseline Ratchet And Audit Snapshot

**Files:**
- Modify: `scripts/code-quality-file-size-baseline.tsv`
- Inspect: `.planning/superpowers/specs/2026-05-19-top-10-code-quality-refactor-design.md`

- [ ] **Step 1: Confirm current oversized file sizes**

Run:

```bash
wc -l app/src/views/curate/ManageReReview.vue app/src/components/analyses/AnalyseGeneClusters.vue api/endpoints/admin_endpoints.R app/src/components/gene/GeneStructurePlotWithVariants.vue app/src/components/tables/TablesLogs.vue app/src/components/analyses/NetworkVisualization.vue app/src/components/nddscore/NddScoreGeneTable.vue api/endpoints/publication_endpoints.R app/src/components/tables/TablesPhenotypes.vue app/src/components/analyses/PubtatorNDDGenes.vue
```

Expected: sizes match or are below the approved design snapshot.

- [ ] **Step 2: Ratchet stale baseline entries downward**

Only reduce entries where the current file is already smaller than the baseline, starting with:

```text
api/endpoints/analysis_endpoints.R
api/functions/analyses-functions.R
api/services/mcp-service.R
api/services/mcp-tools.R
```

- [ ] **Step 3: Verify the ratchet**

Run:

```bash
make code-quality-audit
git diff -- scripts/code-quality-file-size-baseline.tsv
```

Expected: audit exits 0 and baseline diff contains only lowered line counts or removed entries for files now under 600 lines.

- [ ] **Step 4: Commit**

Run:

```bash
git add scripts/code-quality-file-size-baseline.tsv
git commit -m "chore: ratchet code quality baseline"
```

---

### Task 1: Re-Review Admin Workflow

**Files:**
- Modify: `app/src/views/curate/ManageReReview.spec.ts`
- Modify: `app/src/views/curate/ManageReReview.vue`
- Possible create: `app/src/views/curate/components/ReReviewAssignmentPanel.vue`
- Possible create: `app/src/views/curate/components/ReReviewBatchActions.vue`
- Possible create: `app/src/views/curate/composables/useReReviewAssignments.ts`
- Possible create: `app/src/views/curate/utils/reReviewFilters.ts`

- [ ] **Step 1: Add or strengthen tests first**

Add user-visible tests in `ManageReReview.spec.ts` for filter/search behavior, assignment-status filtering, manual entity selection validation, successful assignment refresh/reset, batch action success/error, and boundary-gene alert visibility.

- [ ] **Step 2: Run tests on unchanged production code**

Run:

```bash
cd app && npx vitest run src/views/curate/ManageReReview.spec.ts
```

Expected: pass before production extraction.

- [ ] **Step 3: Extract one cohesive responsibility**

Extract only one responsibility from `ManageReReview.vue`, preferring the smallest high-value slice: pure filter/search helpers into `reReviewFilters.ts` or assignment controls into a child component.

- [ ] **Step 4: Verify target**

Run:

```bash
cd app && npx vitest run src/views/curate/ManageReReview.spec.ts
cd app && npm run type-check
make code-quality-audit
```

Expected: all commands exit 0.

- [ ] **Step 5: Ratchet and commit**

Lower the `ManageReReview.vue` baseline to the new current line count if it shrank.

Run:

```bash
git add app/src/views/curate/ManageReReview.spec.ts app/src/views/curate/ManageReReview.vue app/src/views/curate/components app/src/views/curate/composables app/src/views/curate/utils scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: extract re-review admin workflow slice"
```

---

### Task 2: Functional Gene Clustering View

**Files:**
- Modify: `app/src/components/analyses/AnalyseGeneClusters.spec.ts`
- Modify: `app/src/components/analyses/AnalyseGeneClusters.vue`
- Possible create: `app/src/composables/analyses/useFunctionalClusteringJob.ts`
- Possible create: `app/src/components/analyses/functionalClusterTable.ts`
- Possible create: `app/src/components/analyses/useFunctionalClusterSummary.ts`

- [ ] **Step 1: Add or strengthen tests first**

Add tests for async submit success mapping, duplicate-job polling, failed/timeout loading cleanup, wildcard gene/category/FDR/text filtering, and Excel export over all filtered rows.

- [ ] **Step 2: Run tests on unchanged production code**

Run:

```bash
cd app && npx vitest run src/components/analyses/AnalyseGeneClusters.spec.ts
```

Expected: pass before production extraction.

- [ ] **Step 3: Extract one cohesive responsibility**

Extract table filtering/sorting/pagination helpers or LLM summary stale-response state before moving job orchestration.

- [ ] **Step 4: Verify target**

Run:

```bash
cd app && npx vitest run src/components/analyses/AnalyseGeneClusters.spec.ts
cd app && npm run type-check
make code-quality-audit
```

Expected: all commands exit 0.

- [ ] **Step 5: Ratchet and commit**

Lower the `AnalyseGeneClusters.vue` baseline to the new current line count if it shrank, then commit:

```bash
git add app/src/components/analyses/AnalyseGeneClusters.spec.ts app/src/components/analyses app/src/composables/analyses scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: extract functional clustering slice"
```

---

### Task 3: Admin Endpoint Split

**Files:**
- Create/modify: `api/tests/testthat/test-endpoint-admin.R`
- Modify: `api/endpoints/admin_endpoints.R`
- Possible create: `api/services/admin-ontology-service.R`
- Possible create: `api/services/nddscore-admin-service.R`
- Possible create: `api/functions/admin-endpoint-helpers.R`

- [ ] **Step 1: Add or strengthen tests first**

Add endpoint-surface and helper tests for admin route decorators, Administrator-only authorization expectations, request-body normalization, and NDDScore import submission payloads.

- [ ] **Step 2: Run tests on unchanged production code**

Run:

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-admin.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-nddscore-endpoints.R')"
```

Expected: pass before production extraction.

- [ ] **Step 3: Extract one cohesive responsibility**

Move one admin route family helper, such as NDDScore admin payload shaping or ontology update orchestration, into a prefixed service/helper while leaving Plumber decorators and paths in `admin_endpoints.R`.

- [ ] **Step 4: Verify target**

Run:

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-admin.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-nddscore-endpoints.R')"
make lint-api
make code-quality-audit
```

Expected: all commands exit 0.

- [ ] **Step 5: Ratchet and commit**

Lower the `admin_endpoints.R` baseline to the new current line count if it shrank, then commit:

```bash
git add api/tests/testthat/test-endpoint-admin.R api/endpoints/admin_endpoints.R api/services api/functions scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: extract admin endpoint service slice"
```

---

### Task 4: Gene Structure Plot With Variants

**Files:**
- Create: `app/src/components/gene/GeneStructurePlotWithVariants.spec.ts`
- Create: `app/src/components/gene/geneStructureVariantPlotUtils.ts`
- Modify: `app/src/components/gene/GeneStructurePlotWithVariants.vue`

- [ ] **Step 1: Add tests first**

Add tests for aggregation by genomic position, classification counts, rendering-mode threshold decisions, pathogenicity/effect filters, deterministic radius/opacity, and individual/aggregated tooltip content.

- [ ] **Step 2: Run tests on unchanged production code**

Run:

```bash
cd app && npx vitest run src/components/gene/GeneStructurePlotWithVariants.spec.ts
```

Expected: fail only because extracted helpers do not exist yet, or pass if tests are component-level against unchanged behavior.

- [ ] **Step 3: Extract one cohesive responsibility**

Move pure variant aggregation/filter/tooltip/radius/opacity helpers into `geneStructureVariantPlotUtils.ts`; keep D3 DOM rendering in the component.

- [ ] **Step 4: Verify target**

Run:

```bash
cd app && npx vitest run src/components/gene/GeneStructurePlotWithVariants.spec.ts
cd app && npm run type-check
make code-quality-audit
```

Expected: all commands exit 0.

- [ ] **Step 5: Ratchet and commit**

Lower the `GeneStructurePlotWithVariants.vue` baseline to the new current line count if it shrank, then commit:

```bash
git add app/src/components/gene/GeneStructurePlotWithVariants.spec.ts app/src/components/gene/GeneStructurePlotWithVariants.vue app/src/components/gene/geneStructureVariantPlotUtils.ts scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: extract gene structure variant plot helpers"
```

---

### Task 5: Logs Table

**Files:**
- Modify: `app/src/components/tables/TablesLogs.spec.ts`
- Modify: `app/src/components/tables/TablesLogs.vue`
- Possible create: `app/src/components/tables/logTableFormatters.ts`
- Possible create: `app/src/components/tables/useLogTableRequests.ts`

- [ ] **Step 1: Add or strengthen tests first**

Add tests for API response mapping, URL updates without remount behavior, duplicate-request suppression/cache reuse, status/method/duration formatting, delete payload, and reload behavior.

- [ ] **Step 2: Run tests on unchanged production code**

Run:

```bash
cd app && npx vitest run src/components/tables/TablesLogs.spec.ts
```

Expected: pass before production extraction.

- [ ] **Step 3: Extract one cohesive responsibility**

Extract log formatting helpers first, then request/cache or URL sync helpers in a later commit if the first slice is clean.

- [ ] **Step 4: Verify target**

Run:

```bash
cd app && npx vitest run src/components/tables/TablesLogs.spec.ts
cd app && npm run type-check
make code-quality-audit
```

Expected: all commands exit 0.

- [ ] **Step 5: Ratchet and commit**

Lower the `TablesLogs.vue` baseline to the new current line count if it shrank, then commit:

```bash
git add app/src/components/tables/TablesLogs.spec.ts app/src/components/tables/TablesLogs.vue app/src/components/tables/logTableFormatters.ts app/src/components/tables/useLogTableRequests.ts scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: extract log table helper slice"
```

---

### Task 6: Network Visualization

**Files:**
- Modify: `app/src/components/analyses/NetworkVisualization.spec.ts`
- Modify: `app/src/components/analyses/NetworkVisualization.vue`
- Possible create: `app/src/components/analyses/networkSelection.ts`
- Possible create: `app/src/components/analyses/NetworkVisualizationToolbar.vue`

- [ ] **Step 1: Add or strengthen tests first**

Add helper or component tests for parent clusters, single clusters, multiple clusters, reset decisions, search/highlight emitted events, and existing click routing.

- [ ] **Step 2: Run tests on unchanged production code**

Run:

```bash
cd app && npx vitest run src/components/analyses/NetworkVisualization.spec.ts
```

Expected: pass before production extraction.

- [ ] **Step 3: Extract one cohesive responsibility**

Extract event normalization and cluster-selection decisions into a pure helper before extracting UI controls.

- [ ] **Step 4: Verify target**

Run:

```bash
cd app && npx vitest run src/components/analyses/NetworkVisualization.spec.ts
cd app && npm run type-check
make code-quality-audit
```

Expected: all commands exit 0.

- [ ] **Step 5: Ratchet and commit**

Lower the `NetworkVisualization.vue` baseline to the new current line count if it shrank, then commit:

```bash
git add app/src/components/analyses/NetworkVisualization.spec.ts app/src/components/analyses/NetworkVisualization.vue app/src/components/analyses/networkSelection.ts app/src/components/analyses/NetworkVisualizationToolbar.vue scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: extract network visualization selection slice"
```

---

### Task 7: NDDScore Gene Table

**Files:**
- Modify: `app/src/components/nddscore/NddScoreGeneTable.spec.ts`
- Modify: `app/src/components/nddscore/NddScoreGeneTable.vue`
- Possible create: `app/src/components/nddscore/nddScoreGeneTableFilters.ts`

- [ ] **Step 1: Add or strengthen tests first**

Add tests for URL filter parser numeric ranges, HPO, inheritance, model split, malformed clauses, API payload field names, empty-filter dropping, and existing ML prediction copy.

- [ ] **Step 2: Run tests on unchanged production code**

Run:

```bash
cd app && npx vitest run src/components/nddscore/NddScoreGeneTable.spec.ts
```

Expected: pass before production extraction.

- [ ] **Step 3: Extract one cohesive responsibility**

Extract URL parsing/building and API payload construction into a typed helper module.

- [ ] **Step 4: Verify target**

Run:

```bash
cd app && npx vitest run src/components/nddscore/NddScoreGeneTable.spec.ts
cd app && npm run type-check
make code-quality-audit
```

Expected: all commands exit 0.

- [ ] **Step 5: Ratchet and commit**

Lower the `NddScoreGeneTable.vue` baseline to the new current line count if it shrank, then commit:

```bash
git add app/src/components/nddscore/NddScoreGeneTable.spec.ts app/src/components/nddscore/NddScoreGeneTable.vue app/src/components/nddscore/nddScoreGeneTableFilters.ts scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: extract nddscore gene table filters"
```

---

### Task 8: Publication Endpoint Split

**Files:**
- Create/modify: `api/tests/testthat/test-endpoint-publication.R`
- Modify: `api/endpoints/publication_endpoints.R`
- Possible create: `api/services/pubtator-admin-service.R`
- Possible create: `api/services/publication-table-service.R`

- [ ] **Step 1: Add or strengthen tests first**

Add route/decorator surface tests, PubTator update validation tests for missing query and duplicate job paths, clear-cache service tests for deleted counts, and cursor pagination shape tests.

- [ ] **Step 2: Run tests on unchanged production code**

Run:

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-publication.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-pubtator-functions.R')"
```

Expected: pass before production extraction.

- [ ] **Step 3: Extract one cohesive responsibility**

Extract PubTator cache status/clear/update submission logic or publication table query setup while leaving Plumber decorators stable.

- [ ] **Step 4: Verify target**

Run:

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-publication.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-pubtator-functions.R')"
make lint-api
make code-quality-audit
```

Expected: all commands exit 0.

- [ ] **Step 5: Ratchet and commit**

Lower the `publication_endpoints.R` baseline to the new current line count if it shrank, then commit:

```bash
git add api/tests/testthat/test-endpoint-publication.R api/endpoints/publication_endpoints.R api/services scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: extract publication endpoint service slice"
```

---

### Task 9: Phenotypes Table

**Files:**
- Create: `app/src/components/tables/TablesPhenotypes.spec.ts`
- Modify: `app/src/components/tables/TablesPhenotypes.vue`
- Possible create: `app/src/components/tables/PhenotypeTableMobileRows.vue`
- Possible create: `app/src/components/tables/phenotypeTableFilters.ts`

- [ ] **Step 1: Add tests first**

Add component tests for initial API query params from props, column filter API updates, mobile row key fields, and empty/loading/error states.

- [ ] **Step 2: Run tests on unchanged production code**

Run:

```bash
cd app && npx vitest run src/components/tables/TablesPhenotypes.spec.ts
```

Expected: pass before production extraction.

- [ ] **Step 3: Extract one cohesive responsibility**

Extract phenotype-specific filter metadata or mobile row rendering only if it reduces template complexity without duplicating generic table state.

- [ ] **Step 4: Verify target**

Run:

```bash
cd app && npx vitest run src/components/tables/TablesPhenotypes.spec.ts
cd app && npm run type-check
make code-quality-audit
```

Expected: all commands exit 0.

- [ ] **Step 5: Ratchet and commit**

Lower the `TablesPhenotypes.vue` baseline to the new current line count if it shrank, then commit:

```bash
git add app/src/components/tables/TablesPhenotypes.spec.ts app/src/components/tables/TablesPhenotypes.vue app/src/components/tables/PhenotypeTableMobileRows.vue app/src/components/tables/phenotypeTableFilters.ts scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: extract phenotype table slice"
```

---

### Task 10: PubTator NDD Genes

**Files:**
- Create: `app/src/components/analyses/PubtatorNDDGenes.spec.ts`
- Modify: `app/src/components/analyses/PubtatorNDDGenes.vue`
- Possible create: `app/src/components/analyses/pubtatorNddGeneTable.ts`
- Possible create: `app/src/components/analyses/usePubtatorPublicationStats.ts`

- [ ] **Step 1: Add tests first**

Add tests for typed API loading of gene rows and publication stats, filter controls to API params, visible error state without stale rows, and export of filtered data with stable headers.

- [ ] **Step 2: Run tests on unchanged production code**

Run:

```bash
cd app && npx vitest run src/components/analyses/PubtatorNDDGenes.spec.ts
```

Expected: pass before production extraction.

- [ ] **Step 3: Extract one cohesive responsibility**

Extract API response normalization and filter/query construction before moving publication stats loading.

- [ ] **Step 4: Verify target**

Run:

```bash
cd app && npx vitest run src/components/analyses/PubtatorNDDGenes.spec.ts
cd app && npm run type-check
make code-quality-audit
```

Expected: all commands exit 0.

- [ ] **Step 5: Ratchet and commit**

Lower the `PubtatorNDDGenes.vue` baseline to the new current line count if it shrank, then commit:

```bash
git add app/src/components/analyses/PubtatorNDDGenes.spec.ts app/src/components/analyses/PubtatorNDDGenes.vue app/src/components/analyses/pubtatorNddGeneTable.ts app/src/components/analyses/usePubtatorPublicationStats.ts scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: extract pubtator ndd genes slice"
```

---

## Final Verification

- [ ] **Step 1: Inspect the diff for code-quality risks**

Run:

```bash
git diff --check
git diff --stat
```

- [ ] **Step 2: Run final fast gate**

Run:

```bash
make pre-commit
```

- [ ] **Step 3: Run local CI parity if environment permits**

Run:

```bash
make ci-local
```

If blocked, record the exact failing command, exit code, and blocker in the handoff.

- [ ] **Step 4: Final code-quality review**

Use `.agents/skills/sysndd-code-quality/SKILL.md` to review changed files for modularity, file-size ratchet, frontend typed API boundaries, API service prefixes/source order, tests, and docs impact.
