# SysNDD UI quality protocol (2026-11)

Purpose: one repeatable measurement of every page of the SysNDD app, so that
design flaws, overflows, cut-offs, flicker, layout shifts and slow interactions
are found by a tool rather than by eye, fixed, and re-measured. The runner in
`tools/ui-audit/` implements sections 2-4; section 5 is the human pass.

## 1. Environment

- Instance: dedicated compose stack `sysndd_uiaudit` at http://localhost:8091
  (API under `/api`), built from this worktree (`stack/up.sh`, `stack/reset.sh`;
  `stack/` is a local copy of the fixdev stack scripts and is not committed).
  Database: the pinned production dump, sanitized exactly like the fixdev and
  recording stacks; only the three demo accounts exist (`stack/verify.sh` proves it).
  Credentials: `stack/.env` (local only, never printed).
- Analysis snapshots: the restored dump's snapshots report `snapshot_stale`. The
  stack runs an async `worker`, and the documented operator entry point
  (`api/scripts/refresh-analysis-snapshots.R`, piped into the API container)
  rebuilds and activates all five presets, so the analysis pages serve real data.
- Browser: Playwright Chromium from `app/node_modules` (also `CHROME_PATH` for
  Lighthouse). Headless, no network throttling except Lighthouse's own presets.
- Viewports: 1920x1080 (desktop), 1366x768 (laptop, the reference viewport),
  390x844 (phone).
- State: the usage-policy dialog is acknowledged in storage for every page except
  `home-first-visit`, which audits the dialog itself. Authenticated pages sign in
  per role through the API and store the token as the app does.

## 2. Pages

Every route in `app/src/router/routes.ts`. Parameterised routes use a
representative record: entity 1848 (FBXO11, OMIM:618089), genes FBXO11 and
ARID1B, ontology OMIM:618089, search "FBXO11", NDDScore gene FBXO11, panels
All/All. Roles: a page is audited with the least-privileged role its route guard
admits. Source of truth for the list: `tools/ui-audit/pages.mjs`.

| id | role | URL path |
|---|---|---|
| `home` | public | `/` |
| `home-first-visit` | public | `/` |
| `entities` | public | `/Entities` |
| `genes` | public | `/Genes` |
| `phenotypes` | public | `/Phenotypes` |
| `comparisons` | public | `/CurationComparisons` |
| `comparisons-similarity` | public | `/CurationComparisons/Similarity` |
| `comparisons-table` | public | `/CurationComparisons/Table` |
| `phenotype-correlations` | public | `/PhenotypeCorrelations` |
| `phenotype-counts` | public | `/PhenotypeCorrelations/PhenotypeCounts` |
| `phenotype-clusters` | public | `/PhenotypeCorrelations/PhenotypeClusters` |
| `analysis` | public | `/Analysis` |
| `phenotype-functional` | public | `/PhenotypeFunctionalCorrelation` |
| `variant-correlations` | public | `/VariantCorrelations` |
| `variant-counts` | public | `/VariantCorrelations/VariantCounts` |
| `entries-over-time` | public | `/EntriesOverTime` |
| `publications` | public | `/PublicationsNDD` |
| `publications-timeplot` | public | `/PublicationsNDD/TimePlot` |
| `publications-stats` | public | `/PublicationsNDD/Stats` |
| `pubtator` | public | `/PubtatorNDD` |
| `pubtator-genes` | public | `/PubtatorNDD/PubtatorNDDGenes` |
| `pubtator-stats` | public | `/PubtatorNDD/Stats` |
| `gene-networks` | public | `/GeneNetworks` |
| `data-releases` | public | `/DataReleases` |
| `nddscore` | public | `/NDDScore` |
| `nddscore-modelcard` | public | `/NDDScore/ModelCard` |
| `nddscore-gene` | public | `/NDDScore/Gene/FBXO11` |
| `panels` | public | `/Panels/All/All` |
| `about` | public | `/About` |
| `documentation` | public | `/Documentation` |
| `mcp` | public | `/mcp` |
| `api` | public | `/API` |
| `login` | public | `/Login` |
| `register` | public | `/Register` |
| `password-reset` | public | `/PasswordReset` |
| `entity` | public | `/Entities/1848` |
| `gene-fbxo11` | public | `/Genes/FBXO11` |
| `gene-arid1b` | public | `/Genes/ARID1B` |
| `ontology` | public | `/Ontology/OMIM:618089` |
| `search` | public | `/Search/FBXO11` |
| `not-found` | public | `/this-page-does-not-exist` |
| `user` | Reviewer | `/User` |
| `review` | Reviewer | `/Review` |
| `review-instructions` | Reviewer | `/ReviewInstructions` |
| `create-entity` | Curator | `/CreateEntity` |
| `modify-entity` | Curator | `/ModifyEntity` |
| `approve-review` | Curator | `/ApproveReview` |
| `approve-status` | Curator | `/ApproveStatus` |
| `approve-user` | Curator | `/ApproveUser` |
| `manage-rereview` | Curator | `/ManageReReview` |
| `variation-suggestions` | Curator | `/curate/variation-suggestions` |
| `gene-reviews` | Curator | `/GeneReviews` |
| `manage-user` | Administrator | `/ManageUser` |
| `manage-annotations` | Administrator | `/ManageAnnotations` |
| `manage-ontology` | Administrator | `/ManageOntology` |
| `manage-about` | Administrator | `/ManageAbout` |
| `view-logs` | Administrator | `/ViewLogs` |
| `admin-statistics` | Administrator | `/AdminStatistics` |
| `manage-backups` | Administrator | `/ManageBackups` |
| `manage-pubtator` | Administrator | `/ManagePubtator` |
| `manage-llm` | Administrator | `/ManageLLM` |
| `manage-nddscore` | Administrator | `/ManageNDDScore` |
| `manage-metadata` | Administrator | `/ManageMetadata` |
| `manage-ontology-mappings` | Administrator | `/ManageOntologyMappings` |
| `manage-analysis-releases` | Administrator | `/ManageAnalysisReleases` |

## 3. Measurements per page

Load phase, at each of the three viewports:

| Measurement | How | Recorded as |
|---|---|---|
| Time to usable | ms from navigation start until the page's ready selector (table rows, mobile record rows, heading or card body) is visible and no spinner, skeleton, placeholder or `aria-busy` element is visible | `usableMs`; `stuckLoaders` when never usable within 30 s |
| LCP | `largest-contentful-paint` PerformanceObserver | `lcpMs` |
| CLS during load | sum of `layout-shift` entries without recent input; up to three source nodes per shift | `load.cls`, `load.shiftSources` |
| Long tasks | `longtask` PerformanceObserver | count and total ms |
| Flicker | a rendered, visible element that leaves the DOM within 1.5 s of appearing (content that appears then disappears or reflows). Loaders are counted separately and only when they flash for under 300 ms | `load.flicker[]`, `loaderFlashes` |
| Overflow / cut-off | page wider than the viewport; leaf elements past the right edge outside a scroll container; text clipped by `overflow:hidden`/`clip`, ellipsis or line clamp without a `title` or `aria-label`; interactive elements covered by another element at their centre (dialogs excluded); horizontal scroll regions (informational) | `overflow.{pageOverflowX, pastViewport, clipped, obscured, scrollRegions}` |
| Console errors, failed same-origin requests (>= 400) | Playwright events | `errors`, `failedRequests` |
| Screenshot | full page | `out/<run>/<page>/<viewport>.png` |

Interaction phase, at 1366x768, each measured from its own baseline and
settled for 1.5 s plus network idle:

| Interaction | Action |
|---|---|
| filter | type "FBX" into the first column filter or table search |
| paginate | click "Go to next page" |
| tab | click the first unselected `role="tab"` |
| modal | open the page's configured non-destructive dialog, then Escape |

For each: layout shift including shifts right after input (`shiftAll`; CLS by
definition ignores them, a user does not), long tasks, the slowest event-timing
entry (an INP proxy, `maxEventMs`) and flicker. Interactions a page does not
offer are recorded as skipped.

Static checks, at 1366x768 on a fresh load:

- axe-core (WCAG 2.0/2.1/2.2 A and AA plus best-practice), violations by impact.
- impeccable `detect` over CDP on the live, signed-in tab (contrast, overflow,
  line length, heading order, nested cards, palette tells).

Lighthouse 12 (`npx lighthouse@12.8.2`, attached to the same signed-in browser,
storage reset disabled), desktop preset and default mobile preset: Performance,
Accessibility, Best Practices, SEO scores; LCP, CLS, TBT.

## 4. Pass thresholds

A page passes when all of these hold (encoded in `tools/ui-audit/summarize.mjs`):

| Aspect | Threshold |
|---|---|
| Lighthouse Accessibility, Best Practices | >= 95 (desktop and mobile) |
| Lighthouse Performance | >= 90 desktop, >= 70 mobile |
| Lighthouse SEO | >= 90 on public pages (not judged on signed-in pages) |
| CLS during load | < 0.05 at every viewport |
| Layout shift per interaction (incl. post-input) | < 0.05 |
| Time to usable | <= 2500 ms at every viewport |
| Slowest interaction event | <= 200 ms |
| Long tasks per interaction | <= 300 ms total |
| Flicker | none (load and interactions) |
| axe | no serious or critical violation |
| Overflow / cut-off | none at 1366x768 and 390x844 (1920 reported only) |
| Console errors | none |

Impeccable findings and horizontal scroll regions are reviewed, not
auto-failed: a wide data table that scrolls inside its own container at 390 px is
correct; one that pushes the page wider is not.

## 5. Human pass and rating rubric

For every page, a reviewer reads the three screenshots and the run's evidence,
exercises the page once at 1366x768 and once at 390x844, and rates each aspect
1-5 in `out/<run>/ratings.json` (`{"<page id>": {"hierarchy": 4, ..., "note": "..."}}`).
The summary prints the ratings table.

| Aspect | 5 | 3 | 1 |
|---|---|---|---|
| Visual hierarchy | the page's main task and content are obvious at a glance; one primary action | readable but competing emphasis | no clear entry point |
| Clarity of labels and understanding | every label, count and status says what it means ("Genes: 12", not "Genes: undefined"; "Loaded 10 of 5,000", not "Loaded 10/5"); empty values shown as a dash or "none", never "NA" | some jargon or raw values | raw keys, undefined, NA, ISO timestamps |
| Consistency | same components, spacing, date and number formats as sibling pages | minor drift | each page different |
| Responsiveness | fully usable at 390 px, nothing cut or overlapping | usable with horizontal scrolling | broken |
| Feedback (loading, empty, error) | stable-size placeholder, clear empty and error states | spinner only | blank or misleading |
| Snappiness | content and interactions feel instant (< 100 ms response, no jank) | noticeable waits | sluggish |
| Accessibility | keyboard path, focus visible, names and contrast correct | minor gaps | blocking gaps |

A page is done when it passes section 4 and scores >= 4 on every aspect.

Known items from the screenshot review (verify each in the run, fix, re-measure):

1. Curation comparisons table shows "Genes: undefined".
2. Panels shows "Loaded 10/5".
3. Modify Entity shows a literal "NA" for empty comments.
4. Data releases archive shows a raw date format.
5. The comparison panel text "unique to that intersection" contradicts its bars.

## 6. Procedure

1. `stack/up.sh`, then `stack/reset.sh` (restore, sanitize, verify), then the
   snapshot refresh (`stack/README.md`).
2. Browser metrics in parallel shards (distinct `--cdp-port` and `--out`),
   Lighthouse serially with `--lighthouse-only`, so CPU contention does not
   distort the scores.
3. `node tools/ui-audit/summarize.mjs out/<run>/results.json [...]` merges the
   shards into `summary.md`.
4. Fix, rebuild the app (`stack/up.sh`), re-run the affected pages, and attach
   the before and after summaries to the pull request.
