# UI quality fix plan (after v0.38.5)

Inputs: `audit-public.md` (PUB-*), `audit-curation.md` (CUR-*), `audit-admin.md` (ADM-*),
`audit-screenshots.md` (S-*), thresholds and rubric in `protocol.md` sections 4-5.
Six packages with disjoint file sets, each fixed in its own worktree under
`/home/bernt-popp/development/sysndd-worktrees/` on branch `fix/ui-<name>` from the
v0.38.5 master. Release them together as the next patch release.

## Root causes behind most findings

| Root cause | Findings it explains | Fixed once in |
|---|---|---|
| R serializers `@serializer json list(na="string")` send missing values as the string "NA" | known 3, PUB-04, ADM-05, S-02, CUR-02 | API per endpoint file (`na="null"`) + `isMissing` in the foundation |
| No shared date/count/duration formatter | known 4, PUB-05, PUB-06, PUB-07, ADM-06, ADM-11, S-04, S-05, S-33 | foundation (below) |
| "Loaded ${perPage}/${total} in t" header text copied into every table | known 2, PUB-07, ADM-07, S-03, CUR-09 | `formatShowingRange` + each table |
| `TablePaginationControls` `limit="2"` | PUB-03, ADM-10 | package 2 (+ the two review tables in package 5) |
| Generic table: fixed equal columns, `td{overflow:hidden}`, slots not forwarded | CUR-05, PUB-11, PUB-12, ADM-02, S-08 | package 2 |
| `#app {text-align:center}` and font only on `#app` | CUR-03, S-28, S-33..S-36 | package 1 (`App.vue`) |
| One-line spinners/skeletons swapped for tall content | PUB-14, PUB-15, ADM-08, ADM-21, CUR-26, S-18..S-21 | each owning page (stable-size placeholder) |
| Server-built column labels overwrite curated ones; raw keys in charts | PUB-09, PUB-10, S-07, S-17 | packages 2, 3, 4 |
| Badge colours below AA (gene green, cluster orange, info cyan, KPI labels) | PUB-19, CUR-12, CUR-32, ADM-17, S-25 | owning badge/component |
| Accessible-name gaps (tooltip moves `title`, prepend-only inputs, aria-label != text) | PUB-18, PUB-21, CUR-08, CUR-13, ADM-04, S-13, S-26 | owning component |

## Foundation commit (F0) — do this once before fan-out

Commit F0 is the first commit of package 1 (`fix/ui-shell-pages`). The other five
branches are created from F0, so every package can import the helpers; after the first
PR merges, the others rebase and F0 drops out as already applied. Only package 1 may
edit these files; a package that needs another helper writes it locally and notes it
in its PR.

- `app/src/utils/dateUtils.ts`: `parseApiDate(v)` (naive `YYYY-MM-DD HH:MM:SS` is UTC),
  `formatLongDate(v)` ("July 18, 2026", en-US, UTC; moved from
  `ReleaseDeskSummary.vue:100`), `formatDateTime(v)` ("July 18, 2026, 20:01 UTC",
  24-hour), `formatDuration(seconds)` ("39 ms", "2.4 s", "3 min"). All return "—" for a
  missing value.
- `app/src/utils/displayFormat.ts` (new): `isMissing(v)` (`null`, `undefined`, `''`,
  `'NA'`, `'NaN'`), `displayValue(v)` ("—" when missing), `formatCount(n)`
  (`toLocaleString('en-US')`), `formatShowingRange(first, last, total)`
  ("Showing 1–10 of 4,200"; "No results" for 0).
- Unit tests for both files (`app/src/utils/__tests__/`), including the mutation check
  (break the UTC parse or the 'NA' branch and see the test fail).

## Shared conventions (all packages)

- Dates: `formatLongDate` for dates, `formatDateTime` for timestamps; the full ISO
  value goes in `title`. No `toLocaleDateString()` without a locale.
- Counts: thousands separator everywhere. Table headers read
  `formatShowingRange(...)`; execution time moves to the element's `title`.
- Missing values: "—", never "NA", "NaN", "undefined".
- Select placeholders: "Any {label}"; never ".. X ..".
- Contrast: text >= 4.5:1; use the existing `--text-secondary` / `-emphasis` tokens and
  warning tone `#b45309`.
- Every icon-only button gets `aria-label` equal to its tooltip; every input/select a
  `<label for>` or `aria-label`.
- Loading: a placeholder with the final content's size (no one-line spinner in place
  of a tall block); show a loader only after 300 ms.
- Packages that change user-facing copy update the matching unit spec.

## Packages

### 1. shell-pages — `fix/ui-shell-pages`

App shell, auth pages and the public detail pages (entity, gene, ontology, home).

Files:
- F0: `app/src/utils/dateUtils.ts`, `app/src/utils/displayFormat.ts`,
  `app/src/utils/__tests__/dateUtils.spec.ts`, `app/src/utils/__tests__/displayFormat.spec.ts`
- `app/src/App.vue`, `app/src/components/layout/AuthenticatedPageShell.vue`
- `app/src/components/accessibility/SkipLink.vue`, `app/src/assets/scss/utilities/_accessibility.scss`
- `app/src/components/AppNavbar.vue`, `app/src/components/AppFooter.vue`
- `app/src/components/small/IconPairDropdownMenu.vue`, `app/src/components/small/InlineHelpBadge.vue`
- `app/src/assets/scss/components/_public-pages.scss`, `app/src/assets/scss/components/_loading.scss`
- `app/src/router/guards.ts`
- `app/src/views/HomeView.vue`, `app/src/views/PageNotFoundView.vue`, `app/src/views/LoginView.vue`,
  `app/src/views/PasswordResetView.vue`, `app/src/views/ApiView.vue`, `app/src/views/help/McpInfoView.vue`
- `app/src/views/pages/EntityView.vue`, `app/src/views/pages/components/EntityViewHero.vue`,
  `app/src/views/pages/components/ClinicalSynopsisCard.vue`,
  `app/src/views/pages/components/EntityEvidenceGrid.vue`, `app/src/components/ui/EntityFreshnessPills.vue`
- `app/src/views/pages/OntologyView.vue`, `app/src/views/pages/components/OntologyHero.vue`
- `app/src/views/pages/GeneView.vue`, `app/src/components/gene/GeneHero.vue`,
  `app/src/components/gene/GeneConstraintCard.vue`, `app/src/components/gene/ModelOrganismsCard.vue`,
  `app/src/components/gene/GenomicVisualizationTabs.vue`
- matching `*.spec.ts` files

Findings: CUR-03, CUR-18, CUR-23, S-14, S-15, S-23, S-24, S-28, S-38, S-39, PUB-13,
PUB-15 (entity, ontology, gene), PUB-19 (hero unit labels), PUB-20 (ontology icons),
PUB-21 (HPO chips), PUB-24, PUB-25, PUB-32, PUB-33, PUB-34, PUB-06 / S-05 (home, entity,
ontology dates), S-18, S-19, ADM-24 (shell description width), ADM-23 (shell heading level).

Criteria:
- F0 helpers merged with tests; `#app` no longer centres text; modals use the app font.
- Entity, ontology, gene pages: load CLS < 0.05 at 390, 1366 and 1920; no flicker on
  the genomic-visualisation tab switch; entity disease chip stays inside its card at 1366.
- `/API` hero stacks at 390; skip link invisible until focused at 390; one hamburger on phones.
- Login: no green "valid" state after a failed sign-in, inline error. Password reset has
  a label and a "Back to sign in" link. 404 links home.
- axe: no serious/critical on home, entity, ontology, gene, login, password-reset, api, mcp.
- Ratings >= 4 on all seven aspects for these pages.

### 2. tables — `fix/ui-tables`

Shared table stack, the public data tables, the admin log table, shared badges, API
field labels.

Files:
- `app/src/components/small/TablePaginationControls.vue`, `app/src/components/small/GenericDesktopTable.vue`,
  `app/src/components/small/GenericTable.vue`, `app/src/assets/scss/components/_tables.scss`
- `app/src/components/tables/TablesEntities.vue`, `TablesGenes.vue`, `TablesPhenotypes.vue`,
  `PhenotypesMobileRows.vue`, `TablesLogs.vue`, `logTableFormatters.ts`
- `app/src/components/small/LogDetailDrawer.vue`, `app/src/views/admin/ViewLogs.vue`
- `app/src/views/tables/EntitiesTable.vue`, `GenesTable.vue`, `PhenotypesTable.vue`,
  `PanelsTable.vue`, `PanelsMobileRows.vue`, `PanelsTableControls.vue`
- `app/src/components/ui/GeneBadge.vue`, `DiseaseBadge.vue`, `EntityBadge.vue`, `InheritanceBadge.vue`
- `api/functions/response-fields-helpers.R`, `api/functions/panels-endpoint-functions.R`
- matching specs and `api/tests/testthat` tests for the label helper

Findings: known 2, S-03, PUB-03 (shared control), ADM-10, PUB-07 (tables), ADM-07,
PUB-09 (Panels + API acronyms), S-07, PUB-11 (generic header wrap), PUB-12 (Panels,
entities, phenotypes), CUR-05 (GenericTable/_tables part), ADM-02, ADM-03, ADM-04 (logs
buttons), ADM-06, ADM-14 (ViewLogs), ADM-27, S-22, S-27 (logs placeholder), PUB-31,
PUB-15 / S-21 (phenotypes toolbar CLS), PUB-19 / S-25 / CUR-32 (gene badge), CUR-13 /
S-26 / PUB-21 (disease badge), S-30, S-31.

Criteria:
- Panels `/Panels/Refuted/Other` reads "Showing 1–n of n" with n = rows shown; no table
  shows "Loaded x/y"; all counts have separators.
- Pager shows the active page and a "Page x of y" text at 390 and 1366, no wrap.
- ManageUser desktop renders row and select-all checkboxes (unit test: a `cell-select`
  slot renders through GenericDesktopTable).
- Logs: 0.039 s shows "39 ms" (unit test), times parsed as UTC, every icon button named.
- Panels headers "HGNC ID", "UCSC ID", "BED (hg19)"; inheritance uses AD/AR/XLR codes;
  clipped cells carry `title`; overflow detector reports none at 1366 and 390 for
  entities, genes, phenotypes, panels, view-logs.
- Gene badge >= 4.5:1; DiseaseBadge passes axe `label-content-name-mismatch`.
- Phenotypes load CLS < 0.05 at 390; axe none serious/critical on these pages.

### 3. analyses-clusters — `fix/ui-analyses-clusters`

Comparisons (UpSet, similarity, table), phenotype-functional, phenotype clusters, gene
networks, docs screenshots.

Files:
- `app/src/views/analyses/CurationComparisons.vue`, `app/src/components/analyses/AnalysesCurationUpset.vue`,
  `AnalysesCurationComparisonsTable.vue`, `curationComparisonsTableConfig.ts`, `AnalysesCurationMatrixPlot.vue`
- `app/src/components/analyses/AnalysesPhenotypeFunctionalCorrelation.vue`
- `app/src/components/accessibility/AccessibleSplitter.vue`, `app/src/components/analyses/AnalysesPhenotypeClusters.vue`,
  `AnalyseGeneClusters.vue`, `NetworkVisualization.vue`, `FunctionalClusterTablePanel.vue`,
  `geneClusterTableData.ts`, `app/src/components/filters/ScoreSlider.vue`, `app/src/utils/clusterColors.ts`,
  `app/src/views/analyses/GeneNetworks.vue`, `app/src/views/AnalysisView.vue`
- `app/tests/docs-screenshots/helpers.ts`, `app/tests/docs-screenshots/overlays.ts`,
  `documentation/static/img/generated/curation-comparisons-*.png` (recaptured)
- matching specs

Findings: known 1, known 5, PUB-01, PUB-02, PUB-08, PUB-10, PUB-11 (comparison filters),
PUB-14, PUB-17, PUB-19 (cluster badges), PUB-27, PUB-06 (comparisons date), S-01, S-06,
S-17, S-20, S-21 (comparisons), S-37 (similarity), S-40.

Criteria:
- UpSet text matches the inclusive bars (keep upsetjs default counting, change copy and
  the axis title); a spec asserts each single-set bar equals its set size.
- Docs mock uses the real `meta` shape; the recaptured image shows "Genes: 5,147"-style
  text; the component guards `totalItems ?? 0`.
- At 390 the splitter stacks (analysis, phenotype-clusters, gene-networks): no
  per-character wrapping, overflow detector clean.
- Similarity and UpSet labels use curated source names; heatmap x labels not clipped at
  1366; FC/PC axes sorted numerically and labelled "FC 1".
- Phenotype clusters: no "Loading AI summary" flicker, load CLS < 0.05 at all viewports.
- Gene networks: LH performance >= 90 desktop / >= 70 mobile measured on a quiet host;
  table paging <= 200 ms with <= 300 ms long tasks; no raw "Networkneighboral" label.
- Cluster badges >= 4.5:1; axe none serious/critical; ratings >= 4.

### 4. analyses-data — `fix/ui-analyses-data`

Publications, PubTator, the D3 count/correlation/time charts, data releases, public NDDScore.

Files:
- `app/src/components/analyses/PublicationsNDDStats.vue`, `PublicationsNDDTable.vue`,
  `PublicationsNDDTimePlot.vue`, `PubtatorNDDStats.vue`, `PubtatorNDDTable.vue`, `PubtatorNDDGenes.vue`,
  `usePubtatorPublicationTable.ts`, `usePubtatorGenesTable.ts`, `AnalysesTimePlot.vue`,
  `AnalysesPhenotypeCounts.vue`, `AnalysesVariantCounts.vue`, `AnalysesPhenotypeCorrelogram.vue`,
  `AnalysesVariantCorrelogram.vue`
- `app/src/views/analyses/EntriesOverTime.vue`, `PublicationsNDD.vue`, `PubtatorNDD.vue`,
  `PhenotypeCorrelations.vue`, `VariantCorrelations.vue`, `DataReleases.vue`
- `app/src/components/navigation/AnalysisTabs.vue`
- `app/src/components/analyses/ReleaseArchiveList.vue`, `ReleaseManifestPanel.vue`, `ReleaseDeskSummary.vue`
- `app/src/components/nddscore/NddScoreModelCard.vue`, `nddScoreGeneTableFilterUi.ts`,
  `NddScoreGeneDetail.vue`, `app/src/views/nddscore/NDDScore.vue`
- `api/endpoints/analysis_endpoints.R` (release payload `na="null"`)
- matching specs

Findings: known 4, S-04, PUB-04, PUB-05, PUB-06 (publication stats), PUB-07 (model card,
publication/PubTator table text), PUB-09 (PubTator label merges), PUB-11 (PubTator genes,
NDDScore placeholders), PUB-12 (journal badges), PUB-15 / S-21 (data-releases, NDDScore
CLS), PUB-16, PUB-18, PUB-19 (PubTator cyan, NDDScore unit labels), PUB-20 (PMID chips),
PUB-21 (release buttons), PUB-22, PUB-23, PUB-26, PUB-28, PUB-29, PUB-30, S-27, S-37.

Criteria:
- Archive and manifest show "July 18, 2026"-style dates; no "NA" on the manifest or
  model card ("—"); model card counts separated; "is not a curated classification".
- PubTator headers use curated labels ("PMID", "FDR (BH)"); paging shift < 0.05.
- axe: no `select-name`/`label` critical on publications-stats, timeplot,
  entries-over-time, PubTator stats/genes; no `definition-list`/`list` on nddscore-gene.
- Charts readable at 390 (horizontal scroll container or min drawing width, >= 11 px
  ticks), integer ticks for counts, axis titles.
- Stats cards show unfiltered totals; no empty "2026 YTD 0" card; headings in order.
- Data releases and NDDScore load CLS < 0.05 at 390; tab strip usable at 390; ratings >= 4.

### 5. curation — `fix/ui-curation`

Reviewer and Curator pages, the review/approval table family, user profile, the entity
status/review API.

Files:
- `app/src/views/curate/composables/useStatusForm.ts`, `useReviewForm.ts`, `useEntityInfo.ts`,
  `useEntityAutocomplete.ts`, `useManageReReview.ts`
- `app/src/views/curate/components/CombinedStatusReviewWorkflow.vue`, `ReviewFormFields.vue`,
  `StatusModifyModal.vue`, `EntitySearchPanel.vue`, `RefusedReReviewPanel.vue`, `ApprovalMobileRows.vue`
- `app/src/views/curate/ApproveReview.vue`, `ApproveStatus.vue`, `ApproveUser.vue`, `ManageReReview.vue`,
  `GeneReviewsCoverage.vue`, `ModifyEntity.vue`, `CreateEntity.vue`, `VariationSuggestions.vue`
- `app/src/components/review/ReviewRowCells.vue`, `app/src/components/review/ReviewTable.vue`,
  `app/src/components/ApprovalTableView.vue`, `app/src/composables/approval/useStatusHelpers.ts`,
  `app/src/components/ui/CategoryIcon.vue`, `app/src/components/accessibility/IconLegend.vue`
- `app/src/views/review/Review.vue`, `app/src/views/review/components/ReviewQueueTable.vue`,
  `ReviewEditModal.vue`, `StatusEditModal.vue`, `app/src/views/review/reviewTableConfig.ts`
- `app/src/views/user/UserProfileHeader.vue`, `app/src/views/user/UserSecurityPanel.vue`
- `app/src/composables/useFormDraft.ts`, `app/src/components/forms/wizard/FormWizard.vue`,
  `app/src/components/forms/BatchCriteriaForm.vue`
- `api/endpoints/entity_endpoints.R` (status/review GET `na="null"`)
- matching specs and an API test

Findings: known 3, CUR-01, CUR-02, CUR-04..CUR-12, CUR-14..CUR-17, CUR-19..CUR-22,
CUR-24..CUR-31, PUB-03 (`ReviewTable.vue:71`, `ReviewQueueTable.vue:153`), S-02, S-08..S-13,
S-16, S-29, S-32..S-36.

Criteria:
- `/api/entity/1848/status` returns `"comment": null`; Modify Entity shows an empty
  textarea; saving unchanged posts no "NA" (unit test on both form composables).
- GeneReviews: paginated + 300 ms debounce; time to usable <= 2,500 ms, keystroke
  <= 200 ms, long tasks <= 300 ms; mobile layout without horizontal page scroll; single
  NCBI-failure alert.
- Approve Review synopsis clamps with ellipsis and is keyboard-openable; action buttons
  inside the card at 1366; Approve green, Dismiss outline red, Approve All outline.
- Legend icons match the cell icons; IconLegend title is not an h4.
- Manage Re-review tile shows 4,196; per-page selects named and not clipped.
- Escape closes untouched edit modals; no stray tooltip over modals.
- axe none serious/critical and ratings >= 4 on all 11 curation pages.

### 6. admin — `fix/ui-admin`

The Administrator pages (except View Logs, which is in package 2) and their API endpoints.

Files:
- `app/src/views/admin/ManageUser.vue`, `composables/useUserTablePresentation.ts`, `components/UserAdminMobileRows.vue`
- `app/src/views/admin/ManageOntology.vue`, `ontologyTableConfig.ts`
- `app/src/views/admin/ManageAbout.vue`, `app/src/components/cms/SectionEditor.vue`
- `app/src/views/admin/ManageAnnotations.vue`, `app/src/composables/annotations/useAnnotationsApi.ts`,
  `app/src/composables/annotations/useAnnotationFormatters.ts`
- `app/src/views/admin/ManageBackups.vue`, `composables/useBackupInventory.ts`
- `app/src/views/admin/ManageNDDScore.vue`, `nddScoreAdminFormatters.ts`, `ManageOntologyMappings.vue`
- `app/src/views/admin/AdminStatistics.vue`, `components/statistics/StatCard.vue`, `composables/useKPIStats.ts`
- `app/src/views/admin/ManageLLM.vue`, `useLlmCacheOverview.ts`, `LlmOverviewPanel.vue`
- `app/src/views/admin/ManageAnalysisReleases.vue`, `ManageMetadata.vue`
- `api/endpoints/admin_endpoints.R`, `api/endpoints/backup_endpoints.R` (`na="null"`)
- matching specs

Findings: ADM-01, ADM-04 (users, ontology, about), ADM-05, ADM-08, ADM-09, ADM-11,
ADM-12, ADM-13, ADM-14 (except ViewLogs), ADM-15..ADM-26, ADM-28 (document; no code
change unless the duplicate requests in ADM-22 are the cause).

Criteria:
- Releases digest shortened with full value in `title` + copy; no overlapping text at 1366.
- No "NA"/"NaN" anywhere in admin (annotations "Never", backups chip hidden); one date
  format via F0 helpers; durations via `formatDuration`.
- NDDScore and Mappings load CLS < 0.05 at all viewports; no loader flash < 300 ms.
- axe none serious/critical on all 13 admin pages (icon buttons and selects named,
  contrast >= 4.5:1).
- Preset chips are toggles with a separate labelled delete; Edit User dialog scrolls with
  a visible Save at 768 px height; no duplicate `/statistics/updates` request.
- Ratings >= 4 on all aspects.

## Disjointness check

Every file above appears in exactly one package. Notable splits:
- `DiseaseBadge.vue` is package 2; the entity-hero wrap (PUB-13) is a scoped `:deep()`
  rule in `EntityViewHero.vue` (package 1), so neither edits the other's file.
- `TablePaginationControls.vue` is package 2; the two review tables that pass
  `limit="2"` themselves are package 5.
- `ViewLogs.vue`/`TablesLogs.vue` are package 2 (they share the table fix); the other
  admin pages are package 6.
- `CurationComparisons.vue` (date on comparisons) is package 3; `HomeView.vue` is package 1.
- Each R endpoint file belongs to one package: `entity_endpoints.R` (5),
  `analysis_endpoints.R` (4), `admin_endpoints.R` + `backup_endpoints.R` (6),
  field-label helpers (2). The other `na="string"` endpoints stay as they are.

## Per-package workflow

1. Worktree from F0, run impeccable's context step once with cwd = the worktree's `app/`.
2. Fix with ponytail (smallest complete change; tests for new logic).
3. `npm run lint`, `npm run type-check`, `npm run test:unit` in `app/`; R tests for API changes.
4. Rebuild on the `sysndd_uiaudit` stack (:8091) and re-run
   `tools/ui-audit/run.mjs` for the package's pages (+ `--lighthouse-only`), compare
   with the before runs under `tools/ui-audit/out/`.
5. Review, PR, merge; next package rebases. Release as one patch after v0.38.5.
