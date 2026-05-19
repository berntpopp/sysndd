# Top 10 Code Quality Refactor Design

## Problem

SysNDD has a working code-quality ratchet, but the repository still contains a
large legacy oversized-file baseline. The current tree has 66 handwritten
production source files above the 600-line soft ceiling, with 18,438 excess
lines over the ceiling. The largest files are hard to review safely because each
one mixes several concerns: view layout, API access, state orchestration, data
normalization, rendering, export behavior, and error handling.

The goal is to reduce the top 10 oversized files through incremental,
behavior-preserving refactors. The work must happen on a normal git branch, not
in worktrees, and every refactor must add or strengthen tests before changing
production boundaries.

## Current Baseline

The committed baseline currently lists 70 oversized files in
`scripts/code-quality-file-size-baseline.tsv`, but the current source tree has
already improved:

- `api/services/mcp-tools.R`: baseline 903 lines, current 135 lines.
- `api/services/mcp-service.R`: baseline 1092 lines, current 372 lines.
- `api/endpoints/analysis_endpoints.R`: baseline 752 lines, current 379 lines.
- `api/functions/analyses-functions.R`: baseline 666 lines, current 296 lines.

The first planning/implementation task should therefore ratchet the baseline
downward before touching the remaining large files.

Current actual oversized debt by root:

- `app`: 38 files, 11,572 excess lines.
- `api`: 26 files, 6,673 excess lines.
- `db`: 2 files, 193 excess lines.

`make code-quality-audit` passes on the current tree. That confirms no
oversized file has grown beyond its committed baseline; it does not mean the
oversized-file problem is fixed.

## Scope

This milestone targets the current top 10 oversized production files:

| Rank | File | Lines | Excess | Primary concern |
| --- | --- | ---: | ---: | --- |
| 1 | `app/src/views/curate/ManageReReview.vue` | 1753 | 1153 | Re-review admin workflow view |
| 2 | `app/src/components/analyses/AnalyseGeneClusters.vue` | 1446 | 846 | Functional clustering analysis UI |
| 3 | `api/endpoints/admin_endpoints.R` | 1428 | 828 | Mixed admin/maintenance route file |
| 4 | `app/src/components/gene/GeneStructurePlotWithVariants.vue` | 1410 | 810 | D3 gene structure and variant plot |
| 5 | `app/src/components/tables/TablesLogs.vue` | 1300 | 700 | Admin audit log table |
| 6 | `app/src/components/analyses/NetworkVisualization.vue` | 1254 | 654 | Cytoscape network component |
| 7 | `app/src/components/nddscore/NddScoreGeneTable.vue` | 1236 | 636 | NDDScore gene prediction table |
| 8 | `api/endpoints/publication_endpoints.R` | 1217 | 617 | Publication and PubTator routes |
| 9 | `app/src/components/tables/TablesPhenotypes.vue` | 1182 | 582 | Public phenotype table |
| 10 | `app/src/components/analyses/PubtatorNDDGenes.vue` | 1180 | 580 | PubTator NDD gene analysis table |

Out of scope:

- Broad visual redesigns.
- API route contract changes.
- Public URL, sitemap, SEO, or deployment behavior changes unless a targeted
  refactor touches those surfaces accidentally and tests expose a needed fix.
- Switching test frameworks or adding large new dependencies.
- Refactoring files outside the top 10 except for shared helpers/components
  extracted directly from a top-10 file.

## Design Principles

1. Add tests before moving behavior.
2. Extract cohesive responsibilities only; do not split mechanically by line
   range.
3. Preserve public route/component contracts.
4. Keep frontend API access inside `app/src/api/*` or existing typed API client
   surfaces.
5. Keep API endpoint files thin by moving reusable logic into service,
   repository, helper, or domain modules while preserving Plumber decorators and
   mount paths.
6. Update `scripts/code-quality-file-size-baseline.tsv` downward after each
   successful refactor. Do not raise a baseline entry in this milestone.
7. Run the smallest useful test after each extraction, then run broader checks
   before each PR handoff.

## Community Testing Standards

The testing strategy follows current framework guidance:

- Vue component tests should assert public behavior from a user's perspective,
  using rendered DOM, emitted events, and network calls rather than private
  implementation details.
- Testing Library-style tests should resemble how the software is used; prefer
  roles, labels, text, and stable data-test hooks over method calls when
  practical.
- Playwright checks should focus on user-visible workflows with resilient
  locators and web-first assertions. SysNDD keeps Playwright local-only, so use
  it selectively for high-risk workflow regressions.
- testthat tests should be small, behavior-named, and deterministic. API
  integration tests that write DB state must use `with_test_db_transaction()` or
  document why rollback is not possible.
- R code should follow tidyverse-style file organization: files grouped around a
  clear domain, with related functions discoverable without requiring one
  overloaded catch-all file.

References:

- Vue testing guide: https://vuejs.org/guide/scaling-up/testing.html
- Testing Library principles: https://testing-library.com/docs/guiding-principles/
- Playwright best practices: https://playwright.dev/docs/best-practices
- testthat `test_that()`: https://testthat.r-lib.org/reference/test_that.html
- tidyverse file style: https://style.tidyverse.org/files.html

## Branch Workflow

All implementation work for this milestone should happen on one normal git
branch. Do not create git worktrees for this effort.

Recommended branch name:

```bash
plan/top-10-code-quality-refactor
```

The branch should be split into small commits and, if needed, small PRs by
target file. Each commit should leave the touched area testable.

## Refactor Tracks

### Track 0: Baseline And Guardrails

Before touching production files:

- Regenerate the oversized-file baseline downward.
- Add a small audit report artifact or issue comment content listing current top
  oversized files.
- Keep `make code-quality-audit` green.

This makes the ratchet reflect improvements already in the tree and prevents
future changes from accidentally re-growing files that have already been
reduced below their old baseline.

### Track 1: Re-Review Admin Workflow

Target: `app/src/views/curate/ManageReReview.vue`

Current shape:

- Template: 639 lines.
- Script: 561 lines.
- Style: 553 lines.
- Existing spec mostly guards authenticated API calls and one boundary-gene
  alert case.

Refactor direction:

- Extract table/action UI into child components under
  `app/src/views/curate/components/`.
- Extract API/state orchestration into composables under
  `app/src/views/curate/composables/`.
- Extract pure filtering, sorting, and payload-building helpers into a small
  local utility module if those helpers can be tested without Vue.
- Move view-specific CSS into focused component styles as child components are
  extracted.

Tests to add first:

- Filter/search and assignment-status filtering behavior through rendered UI.
- Manual entity selection and validation when no entity or no user is selected.
- Successful entity assignment resets selection and refreshes data.
- Batch reassignment and recalculation success/error behavior.
- Boundary-gene alert visible/hidden cases through rendered DOM.

Verification after each extraction:

```bash
cd app && npx vitest run src/views/curate/ManageReReview.spec.ts
cd app && npm run type-check
make code-quality-audit
```

### Track 2: Functional Gene Clustering View

Target: `app/src/components/analyses/AnalyseGeneClusters.vue`

Current shape:

- Script: 987 lines.
- Template: 336 lines.
- Style: 123 lines.
- Existing spec covers summary cue, cluster selection, cluster 0, and stale LLM
  summary responses.

Refactor direction:

- Extract async clustering job orchestration into
  `app/src/composables/analyses/useFunctionalClusteringJob.ts` or a
  colocated composable.
- Extract cluster table filtering/sorting/pagination into a pure utility module
  or composable.
- Extract LLM summary state into a composable that owns request IDs and stale
  response handling.
- Keep `AnalyseGeneClusters.vue` as the composition shell.

Tests to add first:

- Async submit success path maps job result into clusters/categories.
- 409 duplicate job path polls the existing job.
- Failed job and timeout paths clear loading and surface an error.
- Table filtering by wildcard gene search, category, FDR, and generic text.
- Excel export sends all filtered rows, not only the current page.

Verification after each extraction:

```bash
cd app && npx vitest run src/components/analyses/AnalyseGeneClusters.spec.ts
cd app && npm run type-check
make code-quality-audit
```

### Track 3: Admin Endpoint Split

Target: `api/endpoints/admin_endpoints.R`

Current shape:

- 13 admin route groups in one file.
- Direct DBI work remains inside ontology/HGNC/publication-refresh paths.
- No obvious direct `test-endpoint-admin.R` file exists.

Refactor direction:

- Add endpoint-surface tests before moving logic.
- Extract NDDScore admin route shaping into `api/services/nddscore-admin-service.R`
  or existing NDDScore service/repository helpers.
- Extract ontology update and force-apply orchestration into an admin ontology
  service module.
- Extract annotation-date/deprecated-entity read logic into repository/service
  helpers.
- Leave Plumber decorators and route handlers in `admin_endpoints.R`, but make
  them thin.

Tests to add first:

- Route decorator/surface tests for all admin routes, modeled after existing
  `test-endpoint-*.R` files.
- Permission checks for Administrator-only routes.
- Unit tests for extracted request-body normalization and NDDScore import
  submission payloads.
- DB-writing tests wrapped in `with_test_db_transaction()` where practical.

Verification after each extraction:

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-admin.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-nddscore-endpoints.R')"
make lint-api
make code-quality-audit
```

### Track 4: Gene Structure Plot With Variants

Target: `app/src/components/gene/GeneStructurePlotWithVariants.vue`

Current shape:

- Script: 1100 lines.
- It combines variant aggregation, filter state, SVG rendering, tooltip logic,
  brush/zoom behavior, and export.
- No obvious direct spec exists.

Refactor direction:

- Extract pure variant aggregation, filter predicates, color/opacity/radius
  calculations, and tooltip string builders into
  `app/src/components/gene/geneStructureVariantPlotUtils.ts`.
- Extract export helpers if they are shared with other SVG/PNG download
  components.
- Keep D3 DOM rendering in the component or a narrowly scoped rendering module
  until pure behavior is covered.

Tests to add first:

- Aggregation groups variants by genomic position and preserves classification
  counts.
- Rendering mode switches at the aggregation threshold.
- Filter predicates respect pathogenicity and effect selections.
- Dynamic radius and opacity calculations are deterministic.
- Tooltip content handles individual and aggregated markers.

Verification after each extraction:

```bash
cd app && npx vitest run src/components/gene/GeneStructurePlotWithVariants.spec.ts
cd app && npm run type-check
make code-quality-audit
```

### Track 5: Logs Table

Target: `app/src/components/tables/TablesLogs.vue`

Current shape:

- Template: 481 lines.
- Script: 736 lines.
- Existing spec protects API client authorization and loading state.

Refactor direction:

- Extract URL/query-string sync and duplicate-request cache into a composable or
  pure helper.
- Extract log formatting helpers (`formatDate`, `formatRelativeTime`,
  `formatDuration`, badge variants) into a tested utility module.
- Extract delete/export controls into child components if that reduces template
  weight without weakening table readability.

Tests to add first:

- API response mapping into pagination/detail state.
- URL update behavior without triggering router remount.
- Duplicate request suppression and cached response reuse.
- Duration/status/method formatting helpers.
- Delete mode payload and reload behavior.

Verification after each extraction:

```bash
cd app && npx vitest run src/components/tables/TablesLogs.spec.ts
cd app && npm run type-check
make code-quality-audit
```

### Track 6: Network Visualization

Target: `app/src/components/analyses/NetworkVisualization.vue`

Current shape:

- Script: 604 lines, just above the ceiling.
- Template/style together add substantial visual complexity.
- Existing spec covers cluster parent click, gene click routing, and background
  reset.

Refactor direction:

- Extract event normalization and cluster-selection decisions into testable
  helpers.
- Extract toolbar/legend controls into child components if that keeps the main
  network component focused on Cytoscape integration.
- Keep Cytoscape setup inside existing composables unless a specific duplicated
  responsibility appears.

Tests to add first:

- Cluster selection helper handles parent clusters, single clusters, multiple
  clusters, and reset.
- Search/highlight controls emit expected events.
- Existing click-routing behavior remains covered.

Verification after each extraction:

```bash
cd app && npx vitest run src/components/analyses/NetworkVisualization.spec.ts
cd app && npm run type-check
make code-quality-audit
```

### Track 7: NDDScore Gene Table

Target: `app/src/components/nddscore/NddScoreGeneTable.vue`

Current shape:

- Script: 808 lines.
- Existing spec is strong around ML prediction copy, filter controls, API
  filters, URL state, and error display.

Refactor direction:

- Extract URL filter parsing/building into a tested helper.
- Extract API filter payload construction into a tested helper.
- Extract mobile/desktop filter controls only if the split reduces template
  complexity without duplicating state.

Tests to add first:

- URL filter parser handles numeric ranges, HPO, inheritance, model split, and
  malformed clauses.
- API payload builder drops empty filters and preserves exact field names.
- Existing ML prediction copy tests remain green.

Verification after each extraction:

```bash
cd app && npx vitest run src/components/nddscore/NddScoreGeneTable.spec.ts
cd app && npm run type-check
make code-quality-audit
```

### Track 8: Publication Endpoint Split

Target: `api/endpoints/publication_endpoints.R`

Current shape:

- Multiple route families in one endpoint file: stats, PMID metadata,
  publication table, PubTator search/table/genes/cache/update/clear-cache.
- Direct DBI work remains in `clear-cache`.
- Some PubTator/publication function tests exist, but there is no obvious
  direct endpoint-surface test for all publication routes.

Refactor direction:

- Add `test-endpoint-publication.R` to pin route signatures and key response
  shapes.
- Extract PubTator cache status/clear/update submission logic into a service
  module.
- Extract publication table query setup into reusable helper/service functions.
- Leave Plumber decorators stable.

Tests to add first:

- Endpoint route/decorator surface for publication and PubTator routes.
- PubTator update validation for missing query and duplicate job paths.
- Clear-cache service uses parameterized/readable helpers and returns deleted
  counts.
- Publication table route keeps cursor pagination shape.

Verification after each extraction:

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-publication.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-pubtator-functions.R')"
make lint-api
make code-quality-audit
```

### Track 9: Phenotypes Table

Target: `app/src/components/tables/TablesPhenotypes.vue`

Current shape:

- Public table with filtering/sorting/pagination behavior.
- No obvious direct spec exists.

Refactor direction:

- Add a direct component spec before extraction.
- Extract phenotype-specific filter metadata and mobile row rendering if
  separate from generic table behavior.
- Reuse existing table composables where possible instead of adding another
  local table abstraction.

Tests to add first:

- Initial API query uses sort/filter/page params from props.
- Column filters update the API query.
- Mobile rows render key phenotype/entity fields.
- Empty/loading/error states render correctly.

Verification after each extraction:

```bash
cd app && npx vitest run src/components/tables/TablesPhenotypes.spec.ts
cd app && npm run type-check
make code-quality-audit
```

### Track 10: PubTator NDD Genes

Target: `app/src/components/analyses/PubtatorNDDGenes.vue`

Current shape:

- Analysis table component with API fetch, filters, publication stats, and
  export/navigation concerns.
- No obvious direct spec exists.

Refactor direction:

- Add direct component/composable tests before extraction.
- Extract API response normalization and filter/query construction into a
  tested helper.
- Extract publication stats loading into a composable if it is reusable with
  other PubTator analysis components.

Tests to add first:

- Loads gene rows and publication stats from typed API calls.
- Filter controls map to the expected API params.
- Error state is visible and does not leave stale rows.
- Export uses filtered data and stable headers.

Verification after each extraction:

```bash
cd app && npx vitest run src/components/analyses/PubtatorNDDGenes.spec.ts
cd app && npm run type-check
make code-quality-audit
```

## Cross-Cutting Quality Gates

For each target file:

1. Write or strengthen the target tests.
2. Run the target test and confirm it passes on unchanged behavior.
3. Extract one cohesive responsibility.
4. Run the target test again.
5. Run `make code-quality-audit`.
6. Update `scripts/code-quality-file-size-baseline.tsv` downward only when the
   touched production file shrinks.
7. Run the stack-specific gate before committing:
   - Frontend target: `cd app && npm run type-check` plus targeted Vitest.
   - API target: targeted R test plus `make lint-api`.
8. Run broader checks before handoff:
   - `make pre-commit` for fast repo-wide quality.
   - `make ci-local` before final merge if the branch touches API behavior or
     multiple frontend/API boundaries.

## Acceptance Criteria

- The top 10 files each have explicit safety-net tests that cover behavior, not
  only implementation details.
- At least the top 10 files are reduced directly or have a committed follow-up
  issue explaining why a file remains above 600 lines after cohesive extraction.
- No production route, public URL, table API contract, or authenticated workflow
  behavior changes unless tests and release notes document the change.
- `scripts/code-quality-file-size-baseline.tsv` is updated downward after each
  reduction and never upward in this milestone.
- `make code-quality-audit` passes after every commit.
- Targeted tests pass after each refactor.
- `make pre-commit` passes before branch handoff.
- `make ci-local` is run before final merge or explicitly documented if blocked
  by local environment constraints.

## Risks And Mitigations

- Risk: moving logic out of Vue Options API changes reactivity.
  Mitigation: add user-visible component tests first and migrate state in small
  steps, preferring composables with refs/computed values over broad rewrites.
- Risk: D3/Cytoscape tests become brittle.
  Mitigation: test pure data/decision helpers first; keep a small number of DOM
  assertions around rendered controls and emitted events.
- Risk: API endpoint splits change source order or Plumber route shape.
  Mitigation: keep decorators in endpoint files, add endpoint-surface tests, and
  source new service/helper modules through `api/bootstrap/load_modules.R`.
- Risk: baseline updates hide growth.
  Mitigation: baseline updates in this milestone must be downward-only and
  reviewed with `git diff scripts/code-quality-file-size-baseline.tsv`.
- Risk: one branch becomes too large to review.
  Mitigation: commit by target file and open reviewable PRs from the same branch
  sequence if needed; do not batch unrelated top-10 files into one commit.

## Documentation Updates

Update durable docs only if the refactor changes contributor workflow,
verification commands, route behavior, or runtime assumptions:

- `AGENTS.md`
- `documentation/08-development.qmd`
- `documentation/09-deployment.qmd`
- `README.md` or `CONTRIBUTING.md`

For this milestone, the expected documentation change is limited to issue
tracking and possibly `documentation/08-development.qmd` if a new refactor
workflow command or test gate is introduced.
