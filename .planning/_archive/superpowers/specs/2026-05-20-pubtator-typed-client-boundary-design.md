# PubTator Typed Client Boundary Design

## Problem

The completed top-10 refactor pass is historical work. PR #355 and PR #359
closed the original checklist, and the current follow-up should not repeat that
sweep. The next refactor pass needs a narrower risk profile: add missing
safety-net specs first, then remove the clearest remaining frontend API-boundary
violation.

`app/src/components/analyses/PubtatorNDDGenes.vue` still injects Axios and
constructs `VITE_API_URL` request URLs directly for:

- `GET /api/publication/pubtator/genes`
- `GET /api/publication/pubtator/table`

That violates the repository rule that frontend API access goes through typed
clients under `app/src/api/*`. The component already has extracted filter
helpers, and `app/src/api/publication.ts` already exposes typed PubTator helpers,
but the component has no component-level spec to protect visible behavior before
the migration.

Two adjacent large targets also lack the right safety nets:

- `app/src/components/tables/TablesPhenotypes.vue` has helper-level tests but no
  component-level coverage for request, filter, pagination, empty, or export
  behavior.
- `api/endpoints/admin_endpoints.R` and
  `api/endpoints/publication_endpoints.R` have helper-level tests, but endpoint
  surface coverage is not broad enough to justify further splitting.

## Goals

1. Add focused safety-net specs before production changes:
   - `app/src/components/analyses/PubtatorNDDGenes.spec.ts`
   - `app/src/components/tables/TablesPhenotypes.spec.ts`
   - `api/tests/testthat/test-endpoint-admin.R`
   - `api/tests/testthat/test-endpoint-publication.R`
2. Migrate PubTator gene loading and expanded publication loading in
   `PubtatorNDDGenes.vue` to typed clients in `app/src/api/publication.ts`.
3. Preserve visible PubTator table behavior:
- initial loading state and loaded row rendering
- total-row count and emitted novel-count value
- prioritization filters
- search/filter pagination request parameters
- expanded publication loading and PubMed links
- export data shape, headers, filename prefix, and success/error toasts
- typed-client `format=json` request parameters after the migration
4. Strengthen `app/src/api/publication.spec.ts` where typed-client parameter
   coverage is missing.
5. Keep `TablesPhenotypes.vue` extraction as a later phase unless the new spec
   proves a small, independent follow-up.

## Non-Goals

- Do not split `admin_endpoints.R` or `publication_endpoints.R` in the first PR.
- Do not refactor `TablesPhenotypes.vue` production code in the first PR.
- Do not change public API routes, route decorators, auth expectations, or
  response envelopes.
- Do not change visible frontend behavior, public URLs, SEO behavior, or table
  copy.
- Do not add new dependencies.
- Do not raise `scripts/code-quality-file-size-baseline.tsv`; only lower entries
  if the implementation shrinks a tracked production file.

## Current Architecture

`PubtatorNDDGenes.vue` is a Vue 3 `<script setup>` component. It uses
`useTableData()` for table state, `useUrlParsing()` for filter strings,
`useExcelExport()` for the client-side XLSX export, Pinia `uiStore` for
scrollbar refreshes, and `useRoute()` for copy-link behavior.

`app/src/api/publication.ts` already exposes:

- `listPubtatorGenes(params, config)`
- `listPubtatorGenesXlsx(params, config)`
- `listPubtatorTable(params, config)`
- `listPubtatorTableXlsx(params, config)`

The component should call `listPubtatorGenes()` for the gene list and
`listPubtatorTable()` for expanded PMID details. It should pass `AbortSignal`
through the typed helper config for expanded publication requests.

`TablesPhenotypes.vue` already uses typed phenotype helpers for its production
requests, so this pass only adds component coverage for the existing behavior.

R endpoint safety nets should follow the existing endpoint-test style used by
`test-endpoint-phenotype.R`, `test-endpoint-review.R`, and
`test-endpoint-auth.R`: structural route assertions plus extracted-handler or
body-slice checks where deterministic and cheap. Tests that write database
state must use `with_test_db_transaction()` or explicitly document why they do
not touch the database.

## Recommended Approach

Use a coverage-first, typed-client migration.

1. Write component and endpoint safety-net specs against unchanged production
   code. These specs should fail only because files/tests are missing or because
   a requested assertion exposes an already-existing uncovered contract; they
   should not require production changes.
2. Add missing publication client assertions for query parameters and Blob
   helpers.
3. Replace raw Axios and `VITE_API_URL` construction in
   `PubtatorNDDGenes.vue` with `listPubtatorGenes()` and
   `listPubtatorTable()`.
4. Re-run focused tests after each change.

Rejected alternatives:

- A broad component split before tests: higher risk because current component
  behavior is not pinned.
- Moving PubTator behavior into a new composable in the first PR: possible, but
  not required to remove the API-boundary violation. Do this later only if
  tests show a cohesive, low-risk extraction.
- Splitting backend endpoint files in the first PR: explicitly blocked until
  endpoint-level tests exist and pass.

## Test Design

### PubtatorNDDGenes Component

The component spec should mock only unavoidable boundaries:

- `useToast()` to assert toast calls.
- `useExcelExport()` to assert exported rows and headers without writing files.
- `useUrlParsing()` if needed to keep filter-string behavior deterministic.
- Bootstrap/table child components as simple stubs to keep the spec focused.
- MSW handlers for typed API requests.

The spec should cover:

- Initial gene loading calls `/api/publication/pubtator/genes` with `sort`,
  `filter`, `page_after`, `page_size`, and `fields`. The unchanged component
  does not append `format=json`; that assertion belongs to the typed-client
  migration and client-helper tests.
- Loaded rows render gene/source/PMID content and update the description count.
- `novel-count` emits the count of rows where `is_novel === 1`.
- Prioritization controls update request filters for minimum publications and
  recent date range.
- Pagination and per-page events update request params.
- Expanding a row calls `/api/publication/pubtator/table` with PMID filter,
  requested fields, and `page_size`, then renders publication metadata. The
  migration step should add `format=json` expectations once the component uses
  `listPubtatorTable()`.
- Export maps visible rows to the current headers and success/error toasts.

### TablesPhenotypes Component

The first spec should pin existing behavior only:

- Loads phenotype options through `listPhenotypes()`.
- Loads selected phenotype entities through `browsePhenotypeEntities()`.
- Applies URL-derived filter state on mount.
- Changing phenotype logic between AND/OR changes the outgoing filter operator.
- Empty selected phenotypes clear rows and avoid a browse request.
- Export calls `browsePhenotypeEntitiesXlsx()` with all rows and downloads
  `phenotype_search.xlsx`.

No production extraction belongs in this first PR unless this spec reveals a
small, independent request-wrapper cleanup.

### R Endpoint Specs

`test-endpoint-admin.R` should first cover stable route surface and admin auth
expectations for high-risk route families, especially ontology and async job
submission paths. It should assert route decorators, `require_role(...,
"Administrator")`, duplicate-job handling where present, and validation shape
for required inputs.

`test-endpoint-publication.R` should cover publication stats/list/PubTator route
surface, public read routes, cursor pagination signatures, `format=xlsx`
branches, required-query validation, and duplicate-job behavior for
`/pubtator/update/submit`.

The current `publication_endpoints.R` state has two important backend risks that
should be documented but not folded into this first typed-client PR:

- PubTator mutation handlers are documented as admin endpoints but currently
  have no in-handler `require_role()` guard. Treat this as a separate security
  follow-up before future endpoint splitting; do not write a safety-net
  assertion that fails on unchanged code in this plan.
- `@get <pmid>` appears twice. Treat the route collision as a backend follow-up
  unless the backend security/route cleanup becomes the next planned slice.

## Execution And Review

Implementation should happen on a normal branch in this workspace. Do not create
git worktrees. Commit each cohesive slice separately:

1. Safety-net specs.
2. Publication typed-client coverage.
3. PubTator component typed-client migration.

Independent review tasks are useful after implementation, not during this
planning-only pass. When executing the plan, use subagent-driven development or
inline plan execution according to the active session constraints, but do not
dispatch parallel writers to the same files.

## Verification

Targeted verification for the first PR:

```bash
cd app && npx vitest run src/components/analyses/PubtatorNDDGenes.spec.ts src/components/tables/TablesPhenotypes.spec.ts src/api/publication.spec.ts
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-admin.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-publication.R')"
cd app && npm run type-check
git diff --check
make code-quality-audit
make pre-commit
make ci-local
```

If host R cannot load required packages or connect to the configured test
database, record the exact command, error, and fallback command used. If
`make ci-local` cannot run in the environment, record the blocker and still run
the targeted frontend, R, `git diff --check`, and `make code-quality-audit`
checks.
