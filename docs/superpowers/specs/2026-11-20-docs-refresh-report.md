# Documentation refresh report (2026-11-20)

Branch `docs/refresh-2026-11`, nothing committed. Integration editor pass after the
chapter writers, reviewers and the screenshot agent finished.

## Verification run

| Check | Result |
| --- | --- |
| `cd documentation && quarto render --to html` (full book, 25 chapters) | exit 0, no warnings |
| Local link, image and anchor check over `_book/*.html` | all resolve (only PDF/EPUB downloads, not built in an HTML-only render, and a font query string flagged) |
| `make verify-doc-screenshots` | passed, 81 generated assets; 5 orphaned legacy files reported (see below) |
| `git diff master -- 08-development.qmd 09-deployment.qmd` | empty: developer chapters unchanged |
| 05/06 rule fidelity | no number from master missing; spot-check of 24 rule phrases all present (wording modernised, e.g. "gray literature", "criterion") |
| Terminology sweep against style guide section 8 | no `<mark>`, `<br>` or `<p style>` layout, no "criterium", no bare "Category 1/2/3" outside the allowed "Definitive (Category 1)" form; `<br/>` only inside the Mermaid diagram in 04 |
| `git diff --check -- documentation` | clean |

## What the integration pass changed

- **06-re-review-instructions.qmd**: switched to the five regenerated captures that were
  produced but not wired in (`reviewer-re-review-table`, `reviewer-edit-review-modal`,
  `reviewer-edit-status-modal`, `reviewer-variation-zones`, `reviewer-refuse-modal`).
  Marker legends, step markers and alt text now match the new marker numbers (the table
  has 6 markers, the Edit Review window 6, Variation ontology field 3, refuse window 2).
  Steps that point at a row button now say "marker N in Figure 5" instead of reusing a
  marker number that belongs to another figure. Alt text of the two menu captures now
  states that they still carry old labelled pills.
- **_quarto.yml**: `crossref: chapters: false`. Figures were numbered "Figure 12.5" while
  chapter numbers are hidden on the web; they now number per chapter ("Figure 5").
- **using-account.qmd**: bare-URL link text replaced by "SysNDD".

## What changed per chapter (writers' work, summarised)

| Chapter | Change |
| --- | --- |
| index | "Start here" paths by audience, book map, how to cite, help; undated counts removed |
| 01-intro | rewritten around the entity (gene, inheritance, disease), evidence categories, Not applicable, roles; dated FBXO11 example table |
| 02-web-tool | now a short hub: menu table with role gates verified against `main_nav_constants.ts` (incl. Data releases, Phenotype–function correlation, NDDScore, Help › MCP); task content moved to `using-*` |
| using-find-gene, using-panels, using-phenotype-search, using-analyses, using-account | new task chapters with numbered steps and marked screenshots |
| 03-api | task-based (get data, page, authenticate, MCP); MCP tool list points to the live catalogue |
| 04-database-structure | explains entity, review, status, history, categories (Mermaid diagram); dead schema link removed |
| 05-curation-criteria | decision flow, summary table, worked examples; master rules kept, raw HTML connectors replaced |
| curation-research | new: how to research a gene before curating |
| 06-re-review-instructions | Reviewer-only guide with steps, rules as callouts, refuse flow; Curator content moved out |
| 07-tutorial-videos | dated legacy video, collapsed transcript, "coming soon" list |
| curator-* (6 chapters) | new Curator guide: create, modify, approve, manage re-review, users, GeneReviews/variation |
| reference-citing, reference-glossary | new |

## Scores (quality protocol; one reviewer, integration editor)

Evidence for C2 is the per-chapter sentence statistics (mean words per sentence, prose
only); C6/C8 from figure and alt-text counts; C7 from the clean link check. Overall =
mean of applicable criteria.

| File | Before | After | Worst criterion now |
| --- | --- | --- | --- |
| index.qmd | 2.6 | 4.3 | C2 (4): mean 19.7 words, 2 sentences > 40 in the history section |
| 01-intro.qmd | 2.1 | 4.2 | C6 (N/A-3): no figure; entity explained by table only |
| 02-web-tool.qmd | 2.3 | 4.3 | C9 (4): menu table must track `main_nav_constants.ts` by hand |
| 03-api.qmd | 2.6 | 4.2 | C9 (4): pagination workaround depends on a live API bug |
| 04-database-structure.qmd | 2.3 | 4.1 | C6 (4): diagram only, old schema image dropped |
| 05-curation-criteria.qmd | 3.0 | 4.3 | C2 (3): mean 24.7 words; long sentences are inside quoted master rules (exempt) |
| 06-re-review-instructions.qmd | 2.8 | 4.4 | C6 (4): 3 reused captures still carry old pills, two show a semi-transparent menu |
| 07-tutorial-videos.qmd | 2.1 | 3.9 | C5/C6 (3): one 2023 Reviewer video; no Curator video yet |
| using-find-gene.qmd | new | 4.4 | C6 (4): live Rat panel shows "Error" in the capture |
| using-panels.qmd | new | 4.3 | C4 (4): documents a likely filter bug instead of fixing it |
| using-phenotype-search.qmd | new | 4.4 | — |
| using-analyses.qmd | new | 4.2 | C6 (4): 3 figures for 10+ analysis pages |
| using-account.qmd | new | 4.5 | — |
| curation-research.qmd | new | 4.3 | C4 (4): worked examples need senior-curator confirmation |
| curator-create-entity.qmd | new | 4.4 | C3 (4): NDD Phenotype switch workaround documents an app quirk |
| curator-modify-entity.qmd | new | 4.3 | C5 (4): no reactivate path; advice is "contact an Administrator" |
| curator-approve.qmd | new | 4.4 | — |
| curator-manage-rereview.qmd | new | 4.4 | — |
| curator-users.qmd | new | 4.4 | — |
| curator-genereviews-variation.qmd | new | 4.3 | — |
| reference-citing.qmd | new | 4.2 | C6 (3): data-releases capture needs a published release |
| reference-glossary.qmd | new | 4.5 | — |
| references.qmd | 4.4 | 4.4 | C7 (3): no links back to citing chapters (unchanged) |
| 08/09 | 3.0 / 2.6 | unchanged | out of scope |

Per protocol step 8, the C10 = 5 given to 05 and 06 needs a second reviewer; my check
was a number diff plus a phrase spot-check, not a full rule-by-rule tick list.

## Remaining issues

1. Screenshots `reviewer-authenticated-navigation`, `reviewer-review-link-menu` and
   `reviewer-after-submit-page` were recaptured but still carry the old labelled pills
   ("Reviewer navigation", "1. Token menu", "Review menu", "1. Re-Review",
   "1. Queue updated", "2. New batch") sitting on the labels; the two menu captures also
   show the dropdown semi-transparent over the preprint banner (mid-fade or a z-index
   issue). Convert them to the numbered-marker style in `app/tests/docs-screenshots/manifest.ts`.
2. `screenshot-manifest.generated.json` `docRefs` are stale for 63 entries: old
   02-web-tool anchors, and curator figure ids that differ from the chapters
   (`fig-create-entity-core` vs `fig-curator-create-entity-core`). Fix in `manifest.ts`.
3. 30 generated screenshots are no longer used by any chapter (old 02 tour images such
   as `home`, `entities-table`, `gene-detail-chd8`, `mobile-*`, `pwa-mobile-shell`, and the
   old `reviewer-review-page` and `reviewer-modify-*-modal` captures now replaced). Decide whether to drop them from the
   manifest. Legacy `static/img/04_01-design-db-schema.png` is orphaned.
4. The PDF/EPUB downloads were not rebuilt in this pass (HTML only).

## Open questions for maintainers

Panels and API

- Panels: Category filters on the gene's highest category but Inheritance keeps a gene
  if any NDD entity has it (FBXO11 shows in Definitive + AR; checked 2026-11-20). Fix in
  code rather than document? Clinically relevant.
- Panel .xlsx always has all 9 columns and ignores the Columns choice. Intended?
- `GET /api/list/inheritance` returns HTTP 500 on production (2026-11-20). Open an issue?
- Pagination `links` in `/api/entity/` and `/api/gene/` omit the endpoint path; 03 tells
  readers to page with `meta[0].nextItemID`. Open an issue?
- No analysis release is published on production (`/api/analysis/releases` empty).

Curation rules (senior curator)

- Cumulative-evidence rule: are ">= two moderate criteria" and "2 further strong
  criteria" alternatives to the PLUS clause or standalone routes?
- Decision-flow step 6 reads the exclusion criteria as "does not qualify for Moderate or
  Limited". Correct?
- Master has no dedicated Refuted criteria; the summary points to the n.a. section and the
  negative criteria. Acceptable?
- Confirm the worked examples (especially PRSS12 as Moderate, PGA5 as Refuted).
- 06 now treats the app's Variation ontology help text (protein truncating / non-synonymous
  minimum) as a Rule callout; it was not in master 06. Confirm.
- Re-review submissions also appear in Approve review/status. Which path should curators
  prefer?

App copy and behaviour

- NDD Phenotype switch shows "No" but stores nothing until toggled (`useEntityForm.ts`).
- Re-review table tooltip says "Use 'Create New Batch' above"; no such button exists.
- No reactivate path for deactivated entities; docs say "contact an Administrator".
- Viewer role described only from `role_constants.ts`; what a Viewer sees is unchecked.

Scope

- NDDScore: hub mention plus glossary only, no chapter (manuscript dropped it). Keep it
  minimal? Link the glossary entry if a chapter is added.
- The live site shows 10 functional clusters; prose avoids counts on purpose.
- MAU2 is the Create entity example (not yet in SysNDD on 2026-11-20); evidence category
  left out on purpose.
- NDDScore video left out of 07 "Coming soon" on purpose.
- 07 transcript is the 2023 narration, lightly edited; YouTube captions not checked.
- Confirm the new chapter filenames are final; external links will depend on them.

## Verification round (2026-11-21)

Six review groups checked the chapters against the code, the live site and the demo
instance, and fix agents applied their findings. The integration editor then re-ran the
full checks.

### Findings per group

Severity counts come from the fix agents' reports. Where an agent gave only a total,
the split is not known.

| Group | Scope | Findings | Severity | Outcome |
| --- | --- | --- | --- | --- |
| G1 | find-gene, panels, phenotype search, analyses, account | 16 | at least 2 major, 1 minor, 1 improvement; rest not split | 15 applied, 1 no text change needed |
| G2 | 03 API, reference-citing, glossary, data model | 10 | at least 2 major | 7 applied, 3 declined (2 in files the group did not own, 1 already correct) |
| G3 | 05 curation criteria, curation-research, 07 videos | 11 | at least 1 major | all text findings applied; 2 declined (they need a screenshot recapture or an app fix) |
| G4 | 06 re-review instructions | 16 | not split | 13 applied, 2 left for screenshot recapture, 1 partly applied |
| G5 | curator guide (create, modify, approve, GeneReviews, users) | 11 | at least 1 major, 3 minor | all applied; the GeneReviews "Not checked" row was removed as a stopgap until the app bug below is fixed |
| G6 | 08 development, 09 deployment | 18 | 9 major, 7 minor, 2 improvements | all applied |

### What the integration pass fixed

- `using-account.qmd` still said SysNDD warns 5, 3 and 1 minutes before sign-out and
  offered a "refresh now" link in that warning. The warning never appears (see the app
  bugs below), and 06 already says so. The paragraph now says there is no warning and
  points to the Token badge.
- Lighthouse found three regressions, all fixed:
  - Preface CLS 0.001 (desktop) and 0.002 (mobile). Quarto's script adds the
    external-link icon after first paint, which reflowed the lead paragraph. The lead link
    to SysNDD now has `.no-external`.
  - Preface best practices 96 on mobile: the ORCID icon is a 16 px PNG. `_a11y-fixes.html`
    now swaps it for a vector iD.
  - 06 accessibility 96 on mobile (target-size): breadcrumb links were under 24 px.
    `styles.css` now gives them a 24 px minimum height.
- `_a11y-fixes.html` gave every ORCID link the names of all authors ("ORCID profile of
  Bernt Popp Melek Firat Altay ..."). It now uses only that author's line.
- Screenshots (separate agent): three reviewer screenshots recaptured on `/About` so the
  preprint banner no longer covers the open menus. 62 stale manifest links were pointed at
  the current `file#fig-id`. All 81 screenshots were regenerated, and
  `make verify-doc-screenshots` passes.

### Checks

- `quarto render --to html`: no errors and no warnings.
- Links, images and anchors in `_book/*.html`: all resolve. The only exceptions are the
  PDF and EPUB download links, because an HTML-only render does not build those files.
- Every image referenced in the `.qmd` sources exists. No `?@` cross-references are
  unresolved, and figure numbers run in sequence on every page.
- `impeccable detect --json` on index, 05, curator-create-entity and 06: no findings.

### Suspected app bugs (with reproduction)

Panels, search and data

1. Panels Inheritance filter ignores entity category. GET
   `/api/panels/browse?filter=equals(category,'Definitive'),any(inheritance_filter,'Autosomal recessive')&page_size=all`
   lists FBXO11 as Definitive and AR, although its AR entity 1998 is Refuted. The AD
   panel lists PPOX through not-applicable entity 577. This is clinically misleading.
2. Search: a numeric entity ID never opens the entity. `/api/search/1848?helper=false`
   returns 10 rows. `search_endpoints.R:78-79` keeps integers out of the exact-match
   shortcut.
3. `GET /api/list/inheritance` returns HTTP 500, while `?tree=true` returns 200.
   `pivot_wider()` drops `hpo_mode_of_inheritance_term`, and the cursor is then built on
   that column.
4. The pagination `links.self` is malformed. `/api/entity/` and `/api/gene/` leave out
   the endpoint path. `/api/list/status` returns only `&page_after=0&page_size=5`.
5. `meta.currentItemID` is a number on `/api/entity/` and a string on `/api/gene/`, and
   `nextItemID` is the string "null" when it is not set.
6. GeneReviews coverage shows "Available, not linked" and an "NA" link on every row while
   **Check NCBI availability** is off. `genereviews_endpoints.R:21` serialises NA as the
   string "NA", and `GeneReviewsCoverage.vue` tests `=== null`.

Gene page and labels

7. The gene page header reads "Loaded 10/2". `TablesEntities.vue:14` and
   `TablesGenes.vue:14` print perPage/totalRows. Seen at `/Genes/FBXO11` and
   `/Genes/TBL1XR1`.
8. The Model Organisms card shows a bare "Error" for Rat when the RGD circuit breaker is
   open (503). The card should say the source is temporarily unavailable.
9. Phenotype search labels show raw field names ("Any Hpo mode of inheritance term name",
   "Ndd phenotype").
10. The Edit review form labels the field "Genereviews" (`ReviewFormFields.vue:169`),
    while every other screen says "GeneReviews".
11. The Data releases page shows raw ISO timestamps and the label "Licence".

Re-review and session

12. The session-expiry warning never shows. `LogoutCountdownBadge.vue:99` uses
    `this.$createElement`, which Vue 3 does not have. This was found by reading the code
    and was not reproduced live.
13. A failed review save closes the modal and loses the input
    (`Review.vue:366-380`, `useReviewForm.ts:376-381`). Found in the code; not run,
    because the demo is read-only.
14. **Submit entity review** is never disabled (`ReviewQueueTable.vue:203-214`).
15. The quick filter "Submitted" tests `item.approved`, but the API returns
    `re_review_approved` (`useReviewFilters.ts:151`).
16. The **New batch** badge appears when filters hide all rows
    (`ReviewQueueTable.vue:118`).
17. The badge reads "1 entities" (`Review.vue:6`, `ReviewQueueTable.vue:21`).
18. Open navbar dropdowns draw under the preprint banner on `/`, and under the table
    toolbar on `/Entities` (z-index).

Create, modify and password reset

19. Create Entity: the NDD Phenotype switch shows "No" while its value is null, so
    **Next** stays disabled until the switch is toggled.
20. Deactivate entity: **Submit** is enabled without the confirmation checkbox, and the
    request then posts `is_active=1` (`useEntityMutations.ts:87-110`). Found in the code
    only.
21. The password reset form checks only the length (7 characters). The server also
    requires complexity, so "abcdefg" passes the client and is rejected by the server
    (`PasswordResetView.vue:114,120`).
22. Correlogram links are inconsistent. The variant correlogram uses `any(...)` on
    Definitive entities, while the phenotype correlogram uses `all(...)` on all
    categories.

Deployment

23. The `make docker-dev` banner advertises ports 7778 and 7655, which `make dev` does not
    publish. `package-analysis-release-zenodo.R:101` defaults to `localhost:7778`.
24. Live `/mcp` with `Accept: text/event-stream` returns the SPA (200 text/html) instead of
    405 from the sidecar. The deployed Traefik labels or the proxy differ from master.
25. The global `EXTERNAL_PROXY_*` values override the large MONDO and gnomAD budgets
    (`external-proxy-functions.R:248-260`).

### Rule questions for a senior curator

The groups changed no rule. The questions in "Open questions for maintainers" stay open.
The verification round adds none beyond them.

### Screenshot status

All 81 screenshots were regenerated, and `make verify-doc-screenshots` passes. Open:
`curation-research-gene-page.png` still shows "Rat: Error" and "Loaded 10/2" (app bugs
7 and 8). `data-releases-page.png` shows a mocked release on purpose, and its caption
says so.

### Final Lighthouse (local `_book`, 2026-11-21)

| Page | Desktop P / A / BP / SEO / CLS | Mobile P / A / BP / SEO / CLS |
| --- | --- | --- |
| index | 99 / 100 / 100 / 100 / 0 | 87 / 100 / 100 / 100 / 0 |
| 05-curation-criteria | 99 / 100 / 100 / 100 / 0 | 88 / 100 / 100 / 100 / 0 |
| curator-create-entity | 99 / 100 / 100 / 100 / 0 | 82 / 100 / 100 / 100 / 0 |
| 06-re-review-instructions | 97 / 100 / 100 / 100 / 0 | 75 / 100 / 100 / 100 / 0 |

## Bug fixes (2026-11-21)

The confirmed bugs were fixed on seven branches. All seven are merged without conflicts into
`fix/docs-verification-bugs` (from `master` `ca385dfc`; not pushed). Bugs deferred for a decision
are filed as issues. On the merged branch, the app unit suite passes (322 files, 2,601 tests),
ESLint reports 0 errors, `vue-tsc` is clean, and the MSW/OpenAPI drift check passes.
`make test-api-fast` passes (0 failures). The new API tests also pass in an offline
`sysndd-api` container, which includes the search test that the host skips because
`stringdist` is not installed there.

| Bug | Verdict | Fixed in branch / issue | Tests |
| --- | --- | --- | --- |
| B01 Panels Inheritance filter ignores entity category | confirmed | `fix/api-panels-pagination-links` | `test-unit-panels-endpoint.R` |
| B02 Numeric entity ID search never opens the entity | confirmed | `fix/api-endpoint-fixes` | `test-unit-search-endpoints.R` |
| B03 `GET /api/list/inheritance` returns 500 | confirmed | `fix/api-endpoint-fixes` | `test-unit-list-endpoints.R` |
| B04 Malformed pagination links | confirmed | `fix/api-panels-pagination-links` | `test-unit-entity-endpoint-services.R` |
| B05 Cursor ID types / string `"null"` | docs-only | no code change; document in 03-api | none |
| B06 GeneReviews coverage `"NA"` instead of null | confirmed | `fix/api-endpoint-fixes` | reviewed against `GeneReviewsCoverage.vue` null branches |
| B07 Gene page caption "Loaded 10/2" | confirmed | `fix/gene-page-and-tables` | `TablesPhenotypes.spec.ts` (2 rows of 12) |
| B08 Model Organisms card shows bare "Error" | confirmed | `fix/gene-page-and-tables` | `ModelOrganismsCard.spec.ts` |
| B09 Raw filter labels in tables | confirmed | `fix/gene-page-and-tables` | `TablesPhenotypes.spec.ts` |
| B10 "Genereviews" label | confirmed | `fix/copy-session-password` | trivial (none) |
| B11 Raw ISO dates and "Licence" on Data releases | confirmed | `fix/copy-session-password` | `ReleaseDeskSummary.spec.ts` |
| B12 Session-expiry warning never shows | confirmed | `fix/copy-session-password` | `LogoutCountdownBadge.spec.ts` |
| B13 Failed review/status save closes the modal | confirmed | `fix/review-queue` | `Review.modalOwnership.spec.ts`, `EditModals.ok.spec.ts` |
| B14 Submit entity review never disabled | confirmed (deferred) | [#708](https://github.com/berntpopp/sysndd/issues/708) | none |
| B15 "Submitted" quick filter reads wrong field | confirmed | `fix/review-queue` | `useReviewFilters.spec.ts` |
| B16 "New batch" badge ignores filters | confirmed | `fix/review-queue` | `ReviewQueueTable.spec.ts` |
| B17 "1 entities" | confirmed | `fix/review-queue` | `ReviewQueueTable.spec.ts` |
| B18 Navbar dropdown under banner (z-index) | cannot-reproduce | no app change; screenshot helper waits for the dropdown | none |
| B19 NDD Phenotype switch shows "No" while empty | confirmed | `fix/entity-create-modify` | `StepCoreEntity.spec.ts` |
| B20 Deactivate submits without confirmation | confirmed | `fix/entity-create-modify` | `InlineEntityWorkflow.spec.ts` |
| B21 Password reset checks only length | confirmed | `fix/copy-session-password` | `PasswordResetView.spec.ts` |
| B22 Correlogram drill-down links inconsistent | confirmed (deferred) | [#709](https://github.com/berntpopp/sysndd/issues/709) | none |
| B23 Dev banner/scripts advertise unpublished ports | confirmed | `fix/api-proxy-and-dev-tooling` | config only (none) |
| B24 Production `/mcp` GET/DELETE reach the SPA | confirmed (deferred, ops) | [#710](https://github.com/berntpopp/sysndd/issues/710) | none |
| B25 Global `EXTERNAL_PROXY_*` overrides per-call budgets | confirmed | `fix/api-proxy-and-dev-tooling` | `test-unit-external-proxy-budgets.R` |
| B26 No way to reactivate an entity | confirmed (deferred) | [#711](https://github.com/berntpopp/sysndd/issues/711) | none |
| B27 Panel .xlsx export ignores Columns | confirmed | `fix/gene-page-and-tables` | `PanelsTable.spec.ts` |
| B28 Tooltip names a non-existent button | confirmed | `fix/copy-session-password` | trivial (none) |

Follow-ups for the docs branch:
- Recapture `curation-research-gene-page.png` from a build of `fix/docs-verification-bugs` (B07, B08).
- Change **Licence** to **License** in `reference-citing.qmd` (B11).
- Document the cursor ID types (B05).
- Restore the GeneReviews "Not checked" row once B06 is released.

## Issues #708-#711 (2026-11-21)

All four fixes are on `fix/docs-verification-bugs` (worktree
`sysndd-worktrees/fix-docs-verification-bugs`), each with a focused test that fails
without the change. Each fix went through an adversarial review and a ponytail review;
the confirmed findings were fixed in a follow-up commit.

| Issue | Root cause | Fix (commits) | Adversarial review outcome |
| --- | --- | --- | --- |
| [#708](https://github.com/berntpopp/sysndd/issues/708) Submit entity review never disabled | The button only changed color (`outline-success` vs `success`) on `re_review_review_saved`; neither the app nor `PUT /api/re_review/submit` checked it. | `de1b65fc`, `5fb4b0da`: button disabled until the review is saved (saving unchanged is allowed); tooltip on a focusable wrapper; the API refuses an unsaved submit with 400 "Save the entity review before submitting it." | Confirmed and fixed: no server check, stale `:title` tooltip (bootstrap-vue-next re-renders only on value change; text moved into the directive value), keyboard access, a misleading wait in the screenshot helper. Not fixed: the "Review submitted successfully" toast on a plain save (pre-existing, quoted in 06), the submit route does not check that the reviewer is assigned (pre-existing). |
| [#709](https://github.com/berntpopp/sysndd/issues/709) Correlogram links inconsistent | Phenotype cells linked to all categories and any modifier; variant cells used `all(vario_id,…)`, but `extract_vario_filter` dropped the operator and treated it as `any`. Neither matched the set the coefficient is computed on. | `e8c9c129`, `e5603f3d`: shared link helper `correlogramLinks.ts` scopes both to the correlation endpoints' default (NDD phenotype Yes, Definitive) and requires both terms (present annotations for phenotypes); the API honors `all(vario_id,…)`; toolbar labels `1-HP:…` as "present: <term>". | Confirmed and fixed: empty `all()` match stripped the column specs, stray comma, diagonal cells, trailing slash broke `returnTo`, dropdown state for modifier ids, help text "either" → "both". Refuted: URL-encoding of ids, "NA" ids. Pre-existing, not fixed: `not()`/`or()` around `vario_id`, double URL-decoding, no visible `vario_id` chip on /Entities, no column allowlist on `/phenotype/entities/browse`. |
| [#710](https://github.com/berntpopp/sysndd/issues/710) Live `/mcp` GET/DELETE reach the website | The repository labels are correct. The production override replaces the three `web` routers with one POST-only `websecure` router, so GET and DELETE fall through to the SPA/nginx. That router also lacks the rate, body-size and in-flight limits and access logging. | `7bee2bde`, `cda51f85`: `make test-mcp-smoke` now requires 405 (not HTML) for GET with `Accept: text/event-stream` and for DELETE; Make help says to point `MCP_URL` at the public `/mcp` after a deploy. The production fix is an operator change to the override. | Confirmed: the default smoke run talks to the sidecar and cannot see #710 (now documented in 09); no CI runs the probe; production router has no middlewares (ops). Fixed: case-insensitive `text/html`, plain JSON Accept on DELETE, comment no longer claims the spec requires 405 for DELETE, tighter text guard (fails when the check is inverted). Refuted: Origin checks on GET/DELETE, the edge stub's DELETE content type. |
| [#711](https://github.com/berntpopp/sysndd/issues/711) No way to reactivate an entity | Deactivation was one-way; undoing it needed a manual database edit with no audit trail. | `fe2d1b6e`, `a7bad04d`: `POST /api/entity/reactivate` (Administrator only) sets `is_active` back to 1 and clears `replaced_by`, leaves reviews and statuses alone, logs entity and user id, clears statistics caches. Refuses with 404/409 when the entity is unknown, already active, or covered by an active entity (its replacement chain or the same gene, inheritance and disease). Modify Entity gets an Administrator-only panel. | Confirmed and fixed: role (issue asks for Administrator), chained replacements and the never-matching quadruple check, malformed ids (`1.5`, `TRUE`, `0`, non-list body → 400), NULL `is_active` → 409, concurrent reactivation → 409, log dropped the named ids, `role="alert"` on errors, API tests that passed without the endpoint. Refuted as harmless: response shape vs. TypeScript type. Out of scope: a reactivated entity without an approved status stays hidden. |

### Bugs found by the end-to-end run

The run on a fresh instance turned up three more bugs, each fixed with a test that failed
first:

- `9ce5c205` The session-expiry warning (B12) still did not show: the user menu names
  `LogoutCountdownBadge` as a string, and since the Vue 3 migration nothing registered it,
  so neither the countdown beside **Token** nor the "Session ending soon" toast rendered.
  Registered locally in `IconPairDropdownMenu`.
- `6deb7c45` Deactivating without a replacement failed with 500: `replaced_by: null`
  dropped the column and the UPDATE bound a zero-length parameter. This blocked the #711
  check in the UI.
- `90eff35c` Panels next/self links returned 500 when followed.

### End-to-end results

Fresh instance `sysndd_fixdev` at http://localhost:8090 (API under `/api`), driven with
Playwright Chromium (the Chrome extension tab could neither screenshot nor open modals).
Evidence in `sysndd-worktrees/fixdev-stack/evidence/`.

| Check | Result | Evidence |
| --- | --- | --- |
| Stack restore, sanitize, verify | PASS ("VERIFY OK": 3 demo accounts, no real identities) | `reset.log` |
| #708 nothing saved | PASS: every Submit disabled; tooltip "Save the entity review first (unchanged is fine), then submit" | `708-1-nothing-saved.png` |
| #708 status saved only | PASS (still disabled by design); direct API submit refused with 400 | `708-2b-status-saved.png`, `708-api-submit-unsaved.txt` |
| #708 review saved unchanged | PASS: Submit enabled, tooltip "Submit entity review" | `708-3b-review-saved-enabled.png` |
| #708 submitted | PASS: confirm window, row leaves the list, saved=1 / submitted=1 in the database | `708-4a/4b*.png`, `708-db-flags.txt` |
| #709 phenotype correlogram (3 cells) | PASS: 91 / 125 / 56 match an independent SQL count; "present:" chips shown | `709-results.txt`, `709-pheno-*.png` |
| #709 variant correlogram (3 cells) | PASS: 767 / 1186 / 2 match SQL | `709-results.txt`, `709-variant-*.png` |
| #710 through the local proxy | PASS: POST 200 JSON-RPC; GET (event-stream) 405 text/plain; DELETE 405; no SPA HTML; smoke probe passes through Traefik | `mcp-710-curl.txt`, `mcp-710-smoke.txt` |
| #710 live server (read-only) | Still FAILS: GET 200 text/html, DELETE 405 text/html. Needs the production override change; the probe now catches it | `mcp-710-live.txt` |
| #711 Curator deactivates in the UI | FAIL, then PASS after `6deb7c45` | `711-5-deactivated.png` |
| #711 reactivate and refusals | PASS: Reviewer 403, Curator 403, anonymous 401; Administrator refused with 409 while replacement 1501 is active (reason shown), 409 already active, 404 unknown, 400 malformed; Administrator reactivates 1502 in the UI | `711-api.txt`, `711-6/7/8*.png` |
| #711 visibility, history, audit | PASS: panel hidden from Curator, Reviewer redirected from Modify Entity; reviews and statuses unchanged; every attempt in the `logging` table | `711-1*.png`, `711-9*.png`, `711-state-audit.txt` |

### Documentation changes (this branch, uncommitted)

- `06-re-review-instructions.qmd`: **Submit entity review** is disabled until a review is
  saved (unchanged is fine), with the tooltip text; the warning now covers only the
  unchecked status; Common problems updated. Session warning (5, 3 and 1 minute) replaces
  "SysNDD does not warn you". The failed-save callout and the synopsis problem now say the
  window stays open (B13, `852cc591`), which the text still contradicted.
- `using-account.qmd`: session warning replaces "does not warn you".
- `using-analyses.qmd`, `using-phenotype-search.qmd`: correlogram cells open the
  Definitive NDD entities that carry *both* terms (present annotations for phenotypes);
  "either" removed.
- `curator-modify-entity.qmd`: new **Reactivate an entity** section (Administrators only),
  deactivation warning and lead updated, one Common problems entry. No screenshot yet;
  request `curator-modify-entity-reactivate.png` (route `/ModifyEntity`, Administrator,
  desktop, markers on **Entity ID (sysndd:)** and **Reactivate entity**).
- `03-api.qmd`: MCP is stateless; GET with `Accept: text/event-stream` and DELETE return 405;
  a browser shows the **MCP** help page.
- `09-deployment.qmd`: the three MCP routers, the production override requirement
  (all three routers with the checked-in middlewares and access logging), and the
  post-deploy probe `MCP_URL=https://sysndd.dbmr.unibe.ch/mcp make test-mcp-smoke`.

`quarto render --to html` is clean.

Open for maintainers: update the production Traefik override (#710); the toast "Review
submitted successfully" on a plain save; the submit route's missing assignment check.

## Refresh to SysNDD 0.38.4 (2026-11-21)

`docs/refresh-2026-11` rebased onto `master` at v0.38.4 (`51417d1f`; 0.38.4 is a dependency
and security release with no behaviour change, so the 0.38.3 review below applies). No
rebase conflicts.

**Screenshots.** All 82 manifest entries were recaptured with `make docs-screenshots` on a
fresh Playwright stack built from the rebased checkout (app and API 0.38.4), and every PNG
was inspected. Public pages keep the live origin and its data but are now served by the
checkout's app build (`DOCS_SCREENSHOTS_PUBLIC_APP_BASE_URL`), so all captures show v0.38.4
although the live site still runs 0.38.2. Changes:

- added `curator-modify-entity-reactivate.png` (Administrator, Reactivate panel with the
  deactivated overlay entity 9105), referenced in `curator-modify-entity.qmd`;
- removed the masks that hid B07/B08 (`curation-research-gene-page`) and B17 (the two
  re-review tables): the captions now read "Loaded 2/2" and Rat "Temporarily unavailable";
- `phenotype-correlations-clusters` was an empty fixture page whose caption described
  clusters; it now shows live clusters;
- `api-swagger-auth` waits for Swagger instead of capturing the loading state;
  `curator-modify-entity-combined` waits for the review to load;
- `reviewer-login-link` and `nav-authenticated-admin` lost their legacy labelled pills;
- helpers follow the 0.38.3 UI (NDD Phenotype Yes/No buttons, "GeneReviews" label); the
  two captures that save the CHD8 review run last, and the overlay is idempotent after them.

**Text (0.38.3 changes).** Panels inheritance filter now matches only top-category
entities (FBXO11 callout replaced) and the export honours **Columns**; an exact entity
number opens the entity; Model Organisms "Temporarily unavailable"; NDD Phenotype Yes/No;
GeneReviews "Not checked" row restored; New batch badge only without search or filters;
`links.next` can be followed; "GeneReviews" and "License" labels; profile marker order
fixed; version stamps 0.38.4.

**Verification.** `quarto render --to html`: exit 0, no warnings. Local link, image and
anchor check over `_book/*.html`: all resolve except the PDF/EPUB downloads (not built in an
HTML-only render). `make verify-doc-screenshots`: passed, 82 assets (same 5 orphaned legacy
files). `api/config.yml` byte-identical after teardown.

**App bugs seen in captures (not fixed here; the affected captures are not referenced by
any chapter except where noted):** the Curation comparisons table header reads
"Genes: undefined"; the Panels page reads "Loaded 10/5" on a 5-gene panel (B07 left
`PanelsTable`); Modify Entity's combined form shows the literal "NA" for empty status and
review comments (`curator-modify-entity-combined`, referenced); the Data releases archive
card shows a raw ISO timestamp.
