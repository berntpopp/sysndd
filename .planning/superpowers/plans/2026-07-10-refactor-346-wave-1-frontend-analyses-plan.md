# Refactor #346 Wave 1 Frontend Analyses Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce every oversized frontend analysis/visualization source file to 600 lines or fewer through tested controller, presentation, and child-component seams.

**Architecture:** Existing route-level components remain stable shells. Stateful request/lifecycle logic moves to domain composables, pure labels/configuration move to typed helpers, and cohesive visual controls move with their styles into child components. CSS-only sidecars are forbidden as a line-count shortcut.

**Tech Stack:** Vue 3, TypeScript, BootstrapVueNext, Cytoscape, D3, Vitest, MSW, vue-tsc, ESLint.

**Spec:** `.planning/superpowers/specs/2026-07-10-refactor-346-complete-closure-design.md`

---

Each numbered implementation task is its own thematic PR. Before starting a task,
create its branch from freshly merged master using the names below:

```bash
git switch master
git pull --ff-only origin master
git switch -c "$TASK_BRANCH"
```

```text
Task 1  refactor/346-w1-functional-summary
Task 2  refactor/346-w1-network-visualization
Task 3  refactor/346-w1-publications-table
Task 4  refactor/346-w1-pubtator-table
Task 5  refactor/346-w1-pubtator-genes
Task 6  refactor/346-w1-gene-structure-controls
Task 7  refactor/346-w1-protein-lollipop-controls
```

After each task's targeted/full checks, push that branch, open a ready PR referencing
#346, obtain Claude and Codex reviews, resolve findings, and merge before branching the
next dependent task. Before each PR is reviewed, the integration owner runs
`--write-baseline`, proves no entry increased, and includes that task's downward
baseline change in the same PR; domain agents never edit the shared baseline.

### Task 1: Extract the functional-cluster summary panel

**Files:**
- Create: `app/src/components/analyses/FunctionalClusterSummaryPanel.vue`
- Create: `app/src/components/analyses/FunctionalClusterSummaryPanel.spec.ts`
- Modify: `app/src/components/analyses/AnalyseGeneClusters.vue:43-117`
- Modify: `app/src/components/analyses/AnalyseGeneClusters.spec.ts`

- [ ] **Step 1: Characterize the summary-state matrix**

Add child tests that mount these concrete states: validated summary renders
`LlmSummaryCard`; rejected renders `data-testid="ai-summary-unavailable"` and reason;
loading renders `Loading AI summary...`; show-all renders the selection cue and emits
`select-cluster` with `firstAvailableCluster`; unavailable single-cluster state renders
none of those panels.

- [ ] **Step 2: Run the new spec and prove the component is absent**

```bash
cd app && npx vitest run src/components/analyses/FunctionalClusterSummaryPanel.spec.ts
```

Expected: FAIL resolving `FunctionalClusterSummaryPanel.vue`.

- [ ] **Step 3: Create the focused child**

Define props named `currentSummary`, `summaryLoading`, `summaryRejected`,
`summaryRejectionReason`, `showAllClustersInTable`, `showAllClustersSummaryCue`,
`firstAvailableCluster`, and `activeParentCluster`; emit only
`select-cluster(clusterId: number)`. Move the current summary/card/cue template and its
four cue style rules into the child unchanged. Keep summary fetching and cluster
selection in the parent.

- [ ] **Step 4: Replace the parent template block and verify**

```bash
cd app
npx vitest run src/components/analyses/FunctionalClusterSummaryPanel.spec.ts \
  src/components/analyses/AnalyseGeneClusters.spec.ts
npm run type-check
npx eslint src/components/analyses/FunctionalClusterSummaryPanel.vue \
  src/components/analyses/AnalyseGeneClusters.vue
wc -l src/components/analyses/AnalyseGeneClusters.vue \
  src/components/analyses/FunctionalClusterSummaryPanel.vue
```

Expected: PASS; both production files are below 600 lines.

- [ ] **Step 5: Commit**

```bash
git add app/src/components/analyses/FunctionalClusterSummaryPanel* \
  app/src/components/analyses/AnalyseGeneClusters.vue \
  app/src/components/analyses/AnalyseGeneClusters.spec.ts
git commit -m "refactor(app): extract functional cluster summary panel (#346)"
```

### Task 2: Decompose NetworkVisualization without splitting lifecycle ownership

**Files:**
- Create: `app/src/components/analyses/NetworkVisualizationControls.vue`
- Create: `app/src/components/analyses/NetworkVisualizationLegend.vue`
- Create: `app/src/components/analyses/useNetworkVisualizationController.ts`
- Create: `app/src/components/analyses/networkVisualizationPresentation.ts`
- Create: `app/src/components/analyses/networkVisualizationPresentation.spec.ts`
- Modify: `app/src/components/analyses/NetworkVisualization.vue`
- Modify: `app/src/components/analyses/NetworkVisualization.spec.ts`

- [ ] **Step 1: Add pure presentation tests**

Test sparse clusters `2`, `7`, and `11`; assert ordering is count-descending then
ID-ascending and no synthetic cluster IDs appear. Test category counts with missing
category data, the STRING coverage tooltip, active-filter gene tooltip, and filtered
edge tooltip.

- [ ] **Step 2: Add lifecycle characterization tests**

Extend the component spec to assert node-only initial mount, exactly-once initial-edge
hydration after layout readiness, exactly-once full-graph mount after filter expansion,
`network-ready` timing, wildcard-search class updates and match-count emit,
`ResizeObserver.disconnect()` on unmount, PNG/SVG filenames, and object-URL revocation.

- [ ] **Step 3: Run tests before extraction**

```bash
cd app && npx vitest run \
  src/components/analyses/networkVisualizationPresentation.spec.ts \
  src/components/analyses/NetworkVisualization.spec.ts
```

Expected: the new helper spec FAILS to resolve; existing characterization cases pass.

- [ ] **Step 4: Extract pure presentation and cohesive controls**

Move current cluster/category labels and tooltip computations into typed pure exports.
Move the header/filter/export controls into `NetworkVisualizationControls.vue` with
their control styles and explicit value/update/action emits. Move the interactive
cluster legend into `NetworkVisualizationLegend.vue` with its own selection emits and
styles. Preserve all button labels, tooltips, Bootstrap variants, and accessible names.

- [ ] **Step 5: Extract exactly one Cytoscape controller**

`useNetworkVisualizationController()` owns network data/filter/search/highlight setup,
staged hydration, cluster mutation functions, fit/reset/zoom/export, watchers,
`ResizeObserver`, mount, retry, and cleanup. It returns the exact values consumed by
the two child components and preserves the parent’s five emits plus `defineExpose`
surface. Mutable Cytoscape state must remain inside this one composable; do not copy
or destructure handles into independently-lived modules.

- [ ] **Step 6: Verify behavior, types, and sizes**

```bash
cd app
npx vitest run src/components/analyses/networkVisualizationPresentation.spec.ts \
  src/components/analyses/NetworkVisualization.spec.ts \
  src/components/analyses/networkSelection.spec.ts
npm run type-check
npx eslint src/components/analyses/NetworkVisualization.vue \
  src/components/analyses/NetworkVisualizationControls.vue \
  src/components/analyses/NetworkVisualizationLegend.vue \
  src/components/analyses/useNetworkVisualizationController.ts \
  src/components/analyses/networkVisualizationPresentation.ts
wc -l src/components/analyses/NetworkVisualization.vue \
  src/components/analyses/NetworkVisualizationControls.vue \
  src/components/analyses/NetworkVisualizationLegend.vue \
  src/components/analyses/useNetworkVisualizationController.ts
```

Expected: PASS; every production file is below 600 lines and the shell is below 400.

- [ ] **Step 7: Commit**

```bash
git add app/src/components/analyses/NetworkVisualization* \
  app/src/components/analyses/useNetworkVisualizationController.ts \
  app/src/components/analyses/networkVisualizationPresentation*
git commit -m "refactor(app): decompose network visualization controller (#346)"
```

### Task 3: Extract PublicationsNDDTable request orchestration

**Files:**
- Create: `app/src/components/analyses/usePublicationsTable.ts`
- Create: `app/src/components/analyses/usePublicationsTable.spec.ts`
- Modify: `app/src/components/analyses/PublicationsNDDTable.vue`
- Modify: `app/src/components/analyses/publicationsTableFormatters.spec.ts`

- [ ] **Step 1: Add composable contract tests**

Assert URL state is applied before the single initial request; identical concurrent
requests deduplicate; an older different response cannot overwrite the current one;
first/last/next/previous cursors preserve string PMIDs; XLSX calls
`listPublicationsXlsx` with `page_size='all'` and downloads `publications.xlsx`; API
`fspec` retains the four visible fields and appends one non-sortable `details` field.

- [ ] **Step 2: Prove the missing composable fails**

```bash
cd app && npx vitest run src/components/analyses/usePublicationsTable.spec.ts
```

Expected: FAIL resolving `usePublicationsTable`.

- [ ] **Step 3: Move orchestration into the composable**

Move filter initialization, URL sync, request coordinator, response application,
cursor/page/sort/filter handlers, export, and link-copy state. Continue delegating
formatting to `publicationsTableFormatters.ts`. The SFC retains template, props, and
component registrations and consumes the returned refs/methods without renaming its
public surface.

- [ ] **Step 4: Verify and commit**

```bash
cd app
npx vitest run src/components/analyses/usePublicationsTable.spec.ts \
  src/components/analyses/publicationsTableFormatters.spec.ts
npm run type-check
npx eslint src/components/analyses/PublicationsNDDTable.vue \
  src/components/analyses/usePublicationsTable.ts
wc -l src/components/analyses/PublicationsNDDTable.vue \
  src/components/analyses/usePublicationsTable.ts
cd ..
git add app/src/components/analyses/PublicationsNDDTable.vue \
  app/src/components/analyses/usePublicationsTable*
git commit -m "refactor(app): extract publications table controller (#346)"
```

Expected: PASS; both production files are below 600 lines.

### Task 4: Extract PubTator publication-table orchestration

**Files:**
- Create: `app/src/components/analyses/usePubtatorPublicationTable.ts`
- Create: `app/src/components/analyses/usePubtatorPublicationTable.spec.ts`
- Create: `app/src/components/analyses/PubtatorNDDTable.spec.ts`
- Modify: `app/src/components/analyses/PubtatorNDDTable.vue`

- [ ] **Step 1: Add tests for request and cache behavior**

Assert exact query parameters, stale-response rejection, all four cursor transitions,
bounded annotated-publication parsing cache reuse, stable `actions`/`details` field
merge, XLSX filename, and copied URL.

The SFC characterization spec mounts `PubtatorNDDTable` through `GenericTable` and
asserts its publication, action, and detail slots render with the expected row props.

- [ ] **Step 2: Run the new spec before implementation**

```bash
cd app && npx vitest run src/components/analyses/usePubtatorPublicationTable.spec.ts
```

Expected: FAIL resolving the composable.

- [ ] **Step 3: Move stateful orchestration, retaining parser ownership**

Move state, watchers, loading, pagination, filter/sort, export, and copy methods into
the composable. Keep existing PubTator parser helpers and `createLruCache`; no parser
logic is duplicated in the SFC.

- [ ] **Step 4: Verify and commit**

```bash
cd app
npx vitest run src/components/analyses/usePubtatorPublicationTable.spec.ts \
  src/components/analyses/PubtatorNDDTable.spec.ts
npm run type-check
npx eslint src/components/analyses/PubtatorNDDTable.vue \
  src/components/analyses/usePubtatorPublicationTable.ts
wc -l src/components/analyses/PubtatorNDDTable.vue \
  src/components/analyses/usePubtatorPublicationTable.ts
cd ..
git add app/src/components/analyses/PubtatorNDDTable.vue \
  app/src/components/analyses/PubtatorNDDTable.spec.ts \
  app/src/components/analyses/usePubtatorPublicationTable*
git commit -m "refactor(app): extract PubTator publication controller (#346)"
```

Expected: PASS; both production files are below 600 lines.

### Task 5: Extract PubTator gene-table orchestration

**Files:**
- Create: `app/src/components/analyses/usePubtatorGenesTable.ts`
- Create: `app/src/components/analyses/usePubtatorGenesTable.spec.ts`
- Modify: `app/src/components/analyses/PubtatorNDDGenes.vue`
- Modify: `app/src/components/analyses/PubtatorNDDGenes.spec.ts`

- [ ] **Step 1: Extend characterization coverage**

Add tests proving a stale response cannot replace a newer filter result, unmount calls
`cancelAllPublicationFetches`, field merge appends exactly one `actions` column, and
Plumber scalar-array meta is normalized before pagination.

- [ ] **Step 2: Create the table controller**

Move filter/URL state, load, enrichment-notice formatting, page/sort handlers, export,
and field merge into the composable. Retain `pubtatorGeneFilters.ts`,
`pubtatorEnrichmentDisplay.ts`, and `usePubtatorGenePublications` as their existing
single-responsibility owners.

- [ ] **Step 3: Verify and commit**

```bash
cd app
npx vitest run src/components/analyses/PubtatorNDDGenes.spec.ts \
  src/components/analyses/usePubtatorGenesTable.spec.ts \
  src/components/analyses/pubtatorGeneFilters.spec.ts
npm run type-check
npx eslint src/components/analyses/PubtatorNDDGenes.vue \
  src/components/analyses/usePubtatorGenesTable.ts
wc -l src/components/analyses/PubtatorNDDGenes.vue \
  src/components/analyses/usePubtatorGenesTable.ts
cd ..
git add app/src/components/analyses/PubtatorNDDGenes* \
  app/src/components/analyses/usePubtatorGenesTable*
git commit -m "refactor(app): extract PubTator genes controller (#346)"
```

Expected: PASS; both production files are below 600 lines.

### Task 6: Extract gene-structure plot controls

**Files:**
- Create: `app/src/components/gene/GeneStructurePlotControls.vue`
- Create: `app/src/components/gene/GeneStructurePlotControls.spec.ts`
- Modify: `app/src/components/gene/GeneStructurePlotWithVariants.vue`

- [ ] **Step 1: Test the controls contract**

Assert classification/effect toggles, `only` and `all`, coloring-mode update,
show-variants update, SVG/PNG actions, and count labels. The child receives computed
legend rows and emits actions; it does not own D3.

- [ ] **Step 2: Move the complete controls responsibility**

Move the controls template plus its chip/button styles to the child. Keep
`useGeneStructurePlot`, `getInputs`, filter predicates/colors, render watch, and cleanup
in the parent. Wire explicit typed props/emits; preserve parent `variant-click`.

- [ ] **Step 3: Verify and commit**

```bash
cd app
npx vitest run src/components/gene/GeneStructurePlotControls.spec.ts \
  src/components/gene/geneStructureVariantPlotUtils.spec.ts
npm run type-check
npx eslint src/components/gene/GeneStructurePlotControls.vue \
  src/components/gene/GeneStructurePlotWithVariants.vue
wc -l src/components/gene/GeneStructurePlotWithVariants.vue \
  src/components/gene/GeneStructurePlotControls.vue
cd ..
git add app/src/components/gene/GeneStructurePlotControls* \
  app/src/components/gene/GeneStructurePlotWithVariants.vue
git commit -m "refactor(app): extract gene structure plot controls (#346)"
```

Expected: PASS; both production files are below 600 lines.

### Task 7: Extract protein-lollipop controls and export actions

**Files:**
- Create: `app/src/components/gene/ProteinLollipopControlsPanel.vue`
- Create: `app/src/components/gene/ProteinLollipopControlsPanel.spec.ts`
- Create: `app/src/components/gene/useProteinLollipopExport.ts`
- Create: `app/src/components/gene/useProteinLollipopExport.spec.ts`
- Modify: `app/src/components/gene/ProteinDomainLollipopPlot.vue`

- [ ] **Step 1: Characterize controls and downloads**

Test pathogenicity/effect/coloring emits and domain legend display. Test SVG filename
`${geneSymbol}_lollipop_plot.svg`, PNG filename `${geneSymbol}_lollipop_plot.png`,
object-URL revocation, and no filter-state mutation during export.

- [ ] **Step 2: Extract cohesive responsibilities**

Move all control/legend/filter template and styles to the child. Move DOM download
mechanics to `useProteinLollipopExport`; keep `useD3Lollipop`, reactive filter state,
legend computation, render watches, and variant emits in the parent.

- [ ] **Step 3: Verify and commit**

```bash
cd app
npx vitest run src/components/gene/ProteinLollipopControlsPanel.spec.ts \
  src/components/gene/useProteinLollipopExport.spec.ts \
  src/components/gene/proteinLollipopControls.spec.ts
npm run type-check
npx eslint src/components/gene/ProteinDomainLollipopPlot.vue \
  src/components/gene/ProteinLollipopControlsPanel.vue \
  src/components/gene/useProteinLollipopExport.ts
wc -l src/components/gene/ProteinDomainLollipopPlot.vue \
  src/components/gene/ProteinLollipopControlsPanel.vue \
  src/components/gene/useProteinLollipopExport.ts
cd ..
git add app/src/components/gene/ProteinDomainLollipopPlot.vue \
  app/src/components/gene/ProteinLollipopControlsPanel* \
  app/src/components/gene/useProteinLollipopExport*
git commit -m "refactor(app): extract protein lollipop controls (#346)"
```

Expected: PASS; every production file is below 600 lines.

### Task 8: Verify merged Wave 1 integration

After Tasks 1-7 are merged, pull fresh master. It contains every reviewed extraction and
each corresponding downward baseline update.

- [ ] **Step 1: Rewrite the baseline once after all accepted tasks**

```bash
bash scripts/code-quality-audit.sh --write-baseline
git diff --exit-code -- scripts/code-quality-file-size-baseline.tsv
```

Expected: `git diff --exit-code -- scripts/code-quality-file-size-baseline.tsv` is clean,
every Wave 1 target is already absent, and no entry increased in its domain PR.

- [ ] **Step 2: Run the full frontend gate**

```bash
make lint-app
cd app && npm run test:unit && npm run type-check && npm run type-check:strict
cd ..
make code-quality-audit
make pre-commit
git diff --check
```

Expected: all commands pass on merged master; no additional ratchet PR is necessary.
