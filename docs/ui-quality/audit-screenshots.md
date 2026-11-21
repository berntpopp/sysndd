# Screenshot audit: documentation/static/img/generated (82 PNGs, v0.38.4)

Scope: every PNG in `documentation/static/img/generated/` was read and reviewed for
overflow, cut-off, truncation without a tooltip, misalignment, spacing, unreadable text,
empty states, wrong counts and labels, raw values (undefined, NA, ISO dates, raw field
names), and visual noise. Each finding was then checked on the audit stack
(http://localhost:8091, worktree `ui/quality-2026-11` at dcbf1fe3) with a Playwright
script, and traced to its cause in the source. Protocol: `docs/ui-quality/protocol.md`.

Method notes
- The docs screenshots were captured on a docs stack (:8088, small fixture dataset plus
  Playwright route mocks in `app/tests/docs-screenshots/helpers.ts`). A finding is
  marked **live** if it reproduces on :8091 with the full sanitized database, and
  **docs-only** if it comes from a fixture or mock. Docs-only findings still matter,
  because those images are what users of the documentation see.
- Measurements come from the parallel browser shards of `tools/ui-audit/run.mjs`
  (`out/public-s0..s5`, `out/curation-a,b`, `out/admin-a,b`; merged in
  `out/shots-repro/summary-browser.md`). The reproduction script output is in
  `tools/ui-audit/out/shots-repro/repro.json`, `repro2.json` and `*.png` (out/ is
  git-ignored). Lighthouse runs serially in `out/public-lh`, `out/curation-lh` and
  `out/admin-lh`, owned by the Lighthouse shard. They were still running when this
  report was written, so the Lighthouse columns are left to that summary rather than
  copied in.
- impeccable: `context` loaded with no PRODUCT.md or DESIGN.md, so the incumbent
  implementation is the design authority. `detect` ran per page through the runner (the
  "impeccable" column). The critique was a single-context pass because this subagent
  has no sub-agent tool, so the design review (A) and the detector evidence (B) were not
  isolated from each other.
- Annotation callouts (numbered blue dots, "1. Panel controls" pills) belong to the docs
  capture overlay, not to the app. Where they hide app controls (Panels "Category"
  label, the phenotype-search AND/OR toggle, the Cancel buttons in the modals, the
  "Actions" headers), that is a docs-capture finding (S-40).

Evidence root: `tools/ui-audit/out/shots-repro/` (below, `R/`). Docs image root:
`documentation/static/img/generated/` (below, `D/`).

## 1. Known bugs from the screenshot review (verified)

| # | Known item | Status on :8091 | Root cause |
|---|---|---|---|
| 1 | Comparisons table "Genes: undefined" | docs-only. Live shows "Genes: 5147" | The docs mock returns `meta: [{ total_rows, execution_time }]` (`app/tests/docs-screenshots/helpers.ts:206`), but the component reads `data.meta[0].totalItems` (`app/src/components/analyses/AnalysesCurationComparisonsTable.vue:396`) and renders it unguarded at `:6`. The same mock gives "3 of 1 sources selected" (no `/comparisons/options` mock) and an empty SFARI circle (mock value `'S'`) in `D/curation-comparisons-*.png` |
| 2 | Panels "Loaded 10/5" | **live**: `/Panels/Refuted/All` shows "Loaded 10/4" with 4 rows (`R/panels-refuted.png`) | `app/src/views/tables/PanelsTable.vue:10` prints `perPage` instead of `items.length` |
| 3 | Modify Entity shows literal "NA" | **live**: the API returns `"comment":"NA"` for NULL comments on `/api/entity/{id}/status` and `/review` (entity 1848, 123 and 4; all 5,518 status and 6,258 review comments are NULL) | `api/endpoints/entity_endpoints.R:425,440`: `@serializer json list(na="string")` turns NULL into the string "NA". The form prefills it (`useStatusForm.ts:171`, `useEntityInfo.ts:210,238`) and **would save "NA" back** on submit |
| 4 | Data-release archive raw date | **live**: "Published 2026-07-18 20:01:55" (`R/data-releases.png`) | `app/src/components/analyses/ReleaseArchiveList.vue:23` prints `release.published_at` unformatted. The card beside it formats the same date as "November 3, 2026" |
| 5 | UpSet "unique to that intersection" contradicts the bars | **live**: the first bar is 3,217, which equals the whole SysNDD set (the Highlight SysNDD count is also 3,217), and the panelapp-only bar is 2,834, which equals the panelapp set size (`R/comparisons-upset.png`) | `render()` in `app/src/components/analyses/AnalysesCurationUpset.vue:329` passes no `combinations`, so UpSet.js draws inclusive `intersection` bars. The copy at `:17` describes exclusive (distinct) ones |

## 2. Findings

Severity: P1 = wrong, misleading or data-damaging, or a severe performance or
accessibility failure. P2 = clearly visible defect or WCAG AA failure. P3 = polish and
consistency. Lines are in `app/src/` unless a path says otherwise.

| id | page | component (file:line) | sev | finding | evidence | proposed fix |
|---|---|---|---|---|---|---|
| S-01 | comparisons | `components/analyses/AnalysesCurationUpset.vue:17,329` | P1 | The description says each bar is "unique to that intersection", but the bars are inclusive (first bar 3,217 = all of SysNDD). Readers will misread the overlap figures | `R/comparisons-upset.png`, `D/curation-comparisons-overview.png` | Pass `combinations: { type: 'distinctIntersection' }` to `render()`, which keeps the copy true and makes the bars sum to the union. Add a spec asserting that the bar sum equals the number of unique genes |
| S-02 | modify-entity (also review/status forms) | `api/endpoints/entity_endpoints.R:425,440`; `views/curate/composables/useStatusForm.ts:171`; `useEntityInfo.ts:210,238`; `views/curate/components/CombinedStatusReviewWorkflow.vue:64,199` | P1 | Empty comments show "NA" in the Status comment and Review comment textareas. Submitting unchanged would write the string "NA" to the database | `D/curator-modify-entity-combined.png`; `curl :8091/api/entity/1848/status` → `"comment":"NA"` | API: use `na="null"` on the entity status and review endpoints (grep the other `na="string"` endpoints that return free text). App: treat `'NA'` as empty when loading the form (one helper in `useEntityInfo`) as defence in depth. Test both |
| S-03 | panels | `views/tables/PanelsTable.vue:10` | P2 | "Loaded 10/4" with only 4 rows | `R/panels-refuted.png` | Use `items.length`. Match the entities wording: "Showing 1–4 of 4" |
| S-04 | data-releases | `components/analyses/ReleaseArchiveList.vue:23` | P2 | Raw timestamp "Published 2026-07-18 20:01:55" next to the formatted "November 3, 2026" | `R/data-releases.png`, `D/data-releases-page.png` | Format with the same date helper as the release summary card |
| S-05 | app-wide (home, comparisons, entity, ontology, approve-*, refused panel, publications, profile) | `views/HomeView.vue:149`, `views/analyses/CurationComparisons.vue:106` (`toLocaleDateString()`, locale-dependent "11/12/2025"); `components/ui/EntityFreshnessPills.vue:21` ("Entered 2016-08-05"); `views/pages/components/ClinicalSynopsisCard.vue:24` ("Last reviewed 2022-06-25 19:40:30"); `views/pages/components/OntologyHero.vue:131`; approve/re-review tables ("2026-11-18"); ApproveUser ("Nov 17, 2026"); publications ("Sep 1, 1979" in a monospace chip) | P2 | At least five date formats coexist, including raw ISO timestamps with seconds and US-locale numeric dates that are ambiguous for an international audience | `R/entity-1848.png`, `D/home.png`, `D/curation-comparisons-*.png`, `D/curator-approve-*.png`, `D/curator-rereview-refused-panel.png` | One `formatDate(value, 'date' or 'datetime')` utility (`Intl.DateTimeFormat('en', { dateStyle: 'medium' })`, giving "Jul 18, 2026"), with the ISO value in `title` and a `<time datetime>` element. Replace every call site. Add a lint or test guard against `toLocaleDateString()` without options |
| S-06 | comparisons-table (docs) | `app/tests/docs-screenshots/helpers.ts:176-210`; `components/analyses/AnalysesCurationComparisonsTable.vue:6,396` | P3 | Docs show "Genes: undefined", "3 of 1 sources selected", and SFARI as an empty circle | `D/curation-comparisons-table.png`, `D/curation-comparisons-overview.png` | Make the mock match the API (`totalItems`, `currentPage`, …, an `/comparisons/options` mock, real SFARI values). Guard the meta in the component (`?? 0`). Regenerate the images |
| S-07 | panels | `views/tables/PanelsTable.vue:107-114`; column labels from the API fspec | P2 | The inheritance chip is clipped mid-word ("Autosomal dominant inh") with no ellipsis. The full value appears only in a hover tooltip, which touch users cannot reach. Headers show raw field names: "Hgnc id", "Entrez id", "Ensembl g…", "Ucsc id", "Bed hg19", "Bed hg38" | `R/panels-all.png`, `D/panels-filters.png`; runner: 21 cut-offs at 1366 | Show the short form (AD, AR, XL…) as on every other table, with the full term in `title`. Map labels to "HGNC ID", "Entrez ID", "Ensembl ID", "UCSC ID", "hg19 locus", "hg38 locus" |
| S-08 | approve-review | `components/review/ReviewRowCells.vue:15` (class used); `views/curate/ApproveReview.vue:383` (scoped style that cannot reach the child) | P2 | The Synopsis cell overflows its 112 px box by up to 2,220 px and is hard-clipped ("de novo truncatir"), with no ellipsis or dotted popover affordance. The line clamp never applies. The entity badge "sysndd: 2312" is clipped at the cell edge, and the "Comment" header is cut to "Commen" | `R/approve-review.png`; impeccable text-overflow `#synopsis-304` +2220px | Move the `.text-truncate-multiline` and `.text-popover-trigger` rules into `ReviewRowCells.vue`. Set the entity column to `min-width` fit-content. Add `title` to clipped headers |
| S-09 | approve-user | `views/curate/ApproveUser.vue:60` (`style="width: 70px"`) | P2 | The per-page select shows "1(" because 70 px is too narrow for "10" plus the chevron | `R/approve-user.png`, `D/curator-approve-user-table.png` | Reuse `components/small/TablePaginationControls.vue` like the other tables, or use `width: auto; min-width: 5rem` |
| S-10 | review, curator re-review | `views/review/components/ReviewQueueTable.vue:161` + `components/accessibility/IconLegend.vue:4` | P2 | `title="Category and review status"` is not a declared prop. It falls through to `BCard`, which renders it as a large centred `<h4>`: the heaviest text on the page, and a skipped heading level (h2 → h4) | `D/reviewer-review-page.png`; impeccable skipped-heading on review | Declare a `title` prop in IconLegend and render it as the inline `<strong>` label, or drop the attribute |
| S-11 | review | `views/review/components/ReviewQueueTable.vue` (actions cell; fields) | P2 | The four action buttons do not fit in the Actions column, so the flag button wraps to a second line (button tops 521/521/521/552, row height 72 px). The "Review d…" header is truncated | `R/review.png`, `D/reviewer-re-review-table.png`; runner overflow 11 at 1366 | Give Actions a fixed width of 4 × 32 px + gaps and `white-space: nowrap`, or move the less-used flag action into an overflow menu. Shorten the header to "Reviewed" |
| S-12 | review (empty queue) | `views/review/components/ReviewQueueTable.vue:170-181` | P2 | An empty queue says "There are no records matching your request" (BTable's filtered-empty text, because `:filter` is set) even when no filter is active | `D/reviewer-after-submit-page.png` | Pass `empty-filtered-text` and an explicit empty state: "No entities assigned to you. Ask a curator for a new batch." |
| S-13 | review | `views/review/components/ReviewQueueTable.vue:139` | P2 | axe critical `select-name`: `#per-page-select` has no accessible name. The id is also duplicated across four components | runner `curation-*` axe | Add `aria-label="Rows per page"` or a `<label for>`, and make the ids unique |
| S-14 | login | `views/LoginView.vue:61,80` | P2 | After a failed sign-in both fields show a green valid check, while the only error is a toast in the top-right corner, away from the form | `R/login-error.png`, `D/login-auth-error-toast.png` | Validate format only on blur. After an auth failure, clear the `:state` and show an inline `BAlert` above the buttons: "Username or password is incorrect." |
| S-15 | password-reset | `views/PasswordResetView.vue:51-54` | P2 | The email input has no label (placeholder only; "Enter your mail account" is helper text). The page uses a dark-header card that matches neither Login nor Register, and there is no way back to sign-in | `D/password-reset-page.png`; repro `passwordReset` (label null) | Use the Login/Register two-column layout with a "Email address" label and a "Back to sign in" link |
| S-16 | user profile | `views/user/UserSecurityPanel.vue:10-14` | P3 | Reads "Auto-logout in59m 55s" because the label and timer have no space or gap between them | `R/user-profile.png`, `D/account-user-profile.png` | Add `gap` or a space and render "Signs out in 59 min". Note the avatar initials are white on #0dcaf0 at 2.0:1 (axe serious) |
| S-17 | gene-networks | `components/analyses/FunctionalClusterTablePanel.vue:19-23,118-166`; `components/filters/ScoreSlider.vue:11`; `components/analyses/geneClusterTableData.ts:178` | P1 (perf) / P2 | Time to usable is 14.7 s at 1366 and 10.1 s at 1920. There are 10 long tasks totalling 8.0 s, and pagination takes 248 ms. Selects and placeholders are cut ("All FDR va", "Filter Descriptio"), descriptions are truncated without `title`, a raw category label "Networkneighboral" is shown, FDR displays "0" for underflow, and a bare warning-triangle badge has no text | `R/gene-networks.png`, `D/functional-clusters.png`, runner `public-s4` | Defer the network layout until the panel is visible and move it to a worker. Render the table first. Set min-widths on the filter controls. Add `title` on descriptions. Map `NetworkNeighborAL` to "Network neighbourhood". Show "< 1e-300" instead of 0. Label the warning badge |
| S-18 | entity | `views/pages/components/ClinicalSynopsisCard.vue:10`, `views/pages/components/EntityEvidenceGrid.vue` | P2 | Load CLS is 0.175 at 390 px and 0.053 at 1366 as the clinical and evidence grids reflow. Publications, GeneReviews, Phenotypes and Variation cards have mismatched heights. The Variation card title wraps ("Variation / Ontology") with "provenance" squeezed beside it, and long VariO chips wrap to two lines | runner `public-s5` entity; `D/entity-detail-123.png`, `D/find-gene-entity-page-fbxo11.png` | Reserve height with skeletons sized to the final cards. Use `align-items: stretch` on the grid. Give the Variation card a one-line title ("Variation") with provenance as an icon button |
| S-19 | ontology | `views/pages/components/OntologyHero.vue`; `views/pages/OntologyView.vue:45` (`#associated-entities-table`) | P2 | Load CLS is 0.334 at 390 px (`#associated-entities-table` shifts). axe reports 7 color-contrast failures on unit labels and target-size failures on the copy and open buttons. The primary label is truncated with an ellipsis | runner `public-s2` ontology; `D/find-gene-disease-page.png` | Reserve the table height while loading. Darken the label colour to ≥ 4.5:1. Give the 16 px icon buttons ≥ 24 px targets. Wrap the label instead of truncating |
| S-20 | phenotype-clusters | `components/analyses/AnalysesPhenotypeClusters.vue:62,135` | P2 | A "Loading AI summary..." block flashes for 160–1020 ms (flicker) and causes CLS 0.095 at 1366 and 0.234 at 390. The multi-line provenance note is centre-aligned. The legend "● = fewer entities \| ● = more entities" is cryptic | runner `public-s4`; `D/phenotype-correlations-clusters.png` | Use a fixed-height skeleton for the summary card. Left-align the note. Draw a size legend with two labelled circles |
| S-21 | comparisons, data-releases, phenotypes | upset container; `release-archive-list`; `table-shell__toolbar` | P2 | Load CLS at 390 px: comparisons 0.141, data-releases 0.145, phenotypes 0.135 | runner shards | Reserve container heights (`min-height` or `aspect-ratio`) before data arrives |
| S-22 | entities, tables, ontology | `views/tables/EntitiesTable.vue:3` + `components/tables/TablesEntities.vue:3` (nested `container-fluid`) | P2 | Doubled gutters: at 390 px the entities card starts 36 px in (72 of 390 px lost). Card left edges differ between pages: 16 (comparisons), 24 (entity, phenotypes), 36 (entities, genes), 48 (ontology "Associated") | `R/mobile-entities.png`, `D/mobile-entities-table.png`, `D/find-gene-disease-page.png` | Drop the inner `container-fluid` and `BRow`/`BCol md=12` wrappers in the table components, and let the view own the gutter |
| S-23 | mobile (390, 844x390) | `components/AppFooter.vue:7,38`; `components/AppNavbar.vue:32` | P2 | Two identical hamburger buttons ("Open navigation menu" at the top, "Toggle navigation" in the fixed footer). In landscape the fixed navbar (60 px) and fixed footer (48 px) take 108 of 390 px (28 %) | `R/landscape-844x390.png`, `D/mobile-home.png`, `D/mobile-landscape-analysis.png` | Make the footer static (not fixed) below `md` or at `max-height: 500px`, and replace its toggler with a labelled "Partners & policy" disclosure |
| S-24 | navbar menus | `components/small/IconPairDropdownMenu.vue:6,12,115-120` | P3 | Dropdown items are centre-aligned, which is hard to scan. The Review menu shows a stray check icon before the book icon ("✓📖 Instructions"). The user menu labels a session timer as "Token 59m 58s" | `D/nav-*-dropdown.png`, `D/reviewer-review-link-menu.png`, `D/reviewer-authenticated-navigation.png` | Left-align the items with icons in a fixed 1.25 rem column. Keep one icon per item. Rename to "Session: 59 min left" |
| S-25 | all tables with gene badges | gene badge component (`span.gene-badge`) | P2 | White text on the green gradient measures 3.7–3.8:1 at 11–12 px bold, below AA 4.5:1 (impeccable, every table page) | runner impeccable on home, entities, genes, phenotypes… | Darken the gradient stops to ≥ #11743a, or use a solid fill |
| S-26 | entities, phenotypes, approve-*, entity | disease badge links, HPO chips | P2 | axe `label-content-name-mismatch` (serious): `aria-label` does not contain the visible text (truncated disease names; "HPO term: present \| HP:0000478") | runner axe | Start the aria-label with the visible text ("Macrocephaly, present, HP:0000256"), or drop the aria-label and rely on text plus `title` |
| S-27 | publications | `components/analyses/PublicationsNDDTable.vue:101,124`; journal badge | P3 | Select-type filters show ".. Journal .."-style placeholders, while other tables use "Any X" or "Filter X". Journal badges are truncated with no tooltip (8 cut-offs at 1366, 18 at 390, including titles) | `D/publications-ndd.png`, runner `public-s4` | Use the shared "Any {label}" wording (the same pattern also appears in `nddScoreGeneTableFilterUi.ts:21`, `TablesLogs.vue:88`, `PubtatorNDDGenes.vue:165`). Add `title` to truncated badges and titles |
| S-28 | modals (all) | `App.vue:123-124` (font-family on `#app` only) | P2 | `BModal` teleports to `<body>`, outside `#app`, so every modal renders in the Bootstrap system font (Noto Sans on Linux) instead of the app font. This is visible in Edit Review, Edit Status, Refuse and Submit | `D/reviewer-*-modal.png` vs any page | Move the font-family to `body` (or `:root`) |
| S-29 | review (Edit Review modal) | Edit Review modal form (labels and help badges) | P3 | Unlike Edit Status, labels are regular weight and each help "?" badge sits on its own line. The same terms appear three times (confirmed list, "3 items selected" dropdown, removable chips). "Remove" and "Dismiss" are used for the same action, and the source shows lowercase "clinvar" | `D/reviewer-edit-review-modal.png`, `D/reviewer-variation-zones.png` | Reuse the Edit Status label pattern (bold label + inline help). Show the selected terms once. Use one verb. Write "ClinVar" |
| S-30 | entity detail chips, refuse/submit modals | entity badge variants | P3 | The entity id appears as "sysndd: 123" (dark badge), "sysndd:123" (bright blue pill) and plain monospace "sysndd:9103" in the refused panel. Gene and disease are badges in tables but plain text in the refused panel and GeneReviews coverage | `D/reviewer-refuse-modal.png`, `D/curator-rereview-refused-panel.png`, `D/curator-genereviews-coverage.png` | One `EntityBadge`, `GeneBadge` and `DiseaseBadge` everywhere |
| S-31 | inheritance labels | inheritance badge mapping | P3 | One concept, several labels: "AD/AR/XL" (tables), "Dom" (docs home "Inh."), "X-l" (re-review), "XLR", "Autosomal dominant inheritance" (panels). "X-l" reads like a typo | `R/review.png`, `D/home.png`, `D/phenotype-search-and-or.png` | Map HPO inheritance terms to one short-code table (AD, AR, XLD, XLR, XL, MT, …) shared by all badges |
| S-32 | approve-review, approve-status | `components/review/ReviewTable.vue:8-15` | P3 | "Approve All" is the most prominent control (solid red) in a queue where per-row review is the normal path. A confirm modal exists | `D/curator-approve-*-table.png` | Make it `outline-danger`, put the count in the label ("Approve all 6…"), and place it after the table toolbar |
| S-33 | manage-rereview | `components/forms/BatchCriteriaForm.vue:229-235,511` | P3 | The batch summary list is centre-aligned with its bullets left at the box edge, so each bullet floats far from its text. Section headings ("Scope", "Batch details") are centred over left-aligned fields. Date inputs show 01/01/2020 while the summary shows 2020-01-01 | `D/curator-rereview-batch-criteria.png` | Left-align the headings and summary. Format dates with S-05's helper |
| S-34 | gene-reviews | `views/curate/GeneReviewsCoverage.vue:106,124` | P3 | "Available, not linked" is a red danger badge, but it is an opportunity, not an error. The intro and card subtitle are centred while the card title is left-aligned | `D/curator-genereviews-coverage.png` | Use a warning or info badge. Left-align the text |
| S-35 | create-entity evidence step | step 2 form | P3 | Centred section headings and helper text over left-aligned inputs. The "Add" button is shorter than its input (38 vs 42 px) | `D/curation-research-evidence-step.png`, `D/curator-create-entity-evidence.png` | Left-align. Use `BInputGroup` so the button matches the input height |
| S-36 | modify-entity | `views/curate/ModifyEntity.vue:22` and reactivate block | P3 | "1 results" (plural bug). The reactivate section uses a centred heading and label and a number spinner for an ID, unlike the card pattern above it. Cancel appears twice in the Status & Review form | `D/curator-modify-entity-selected.png`, `D/curator-modify-entity-reactivate.png`, `D/curator-modify-entity-combined.png` | Pluralise. Use a card and a text input with an "sysndd:" prefix. Keep a single footer Cancel |
| S-37 | phenotype-counts, variant-counts, entries-over-time, similarity | chart components (d3) | P3 | Integer counts get fractional ticks (0.5, 1.5) when values are small. Variant counts show 40+ category labels at 45° with a long tail of near-zero bars. Axis titles are missing. Entries-over-time draws its legend as floating text inside the plot. Similarity omits cell values and uses raw source keys ("sfari", "panelapp") next to "SysNDD". Tick labels are 10 px (impeccable tiny-text, 35 on phenotype-counts, 68 on correlations) | `D/phenotype-correlations-counts.png`, `D/phenotype-search-variant-counts.png`, `D/entries-over-time.png`, `D/curation-comparisons-similarity.png` | Integer `tickFormat` and `ticks(Math.min(max, 5))`. Horizontal bars for variant counts. Add axis titles. Use a proper legend. Print values in heatmap cells. Use curated source labels (the comparisons table already has `withCuratedComparisonLabels`). Raise tick text to ≥ 11 px |
| S-38 | gene pages | gene hero, constraint card, model organisms | P3 | "CHD8" is shown twice (title and badge). Constraint labels are 9.6 px (impeccable). "hm 10 / ht 26 / cn 17" are unexplained abbreviations. Variant counts disagree in format ("1.9K variants" vs "ClinVar Variants (1934)"). An empty grey toolbar band sits above the Associated table. FBXO11 and ARID1B time to usable is up to 15.7 s at 1366 (ARID1B) | `D/gene-detail-chd8.png`, `D/find-gene-gene-page-fbxo11.png`, `D/curation-research-gene-page.png`; runner `public-s0,s1` | Drop the duplicate badge. Use ≥ 11 px labels. Spell out "homozygous / heterozygous / conditional" with a tooltip. Use one number format. Hide the empty toolbar. Lazy-load the genomic visualisation below the fold |
| S-39 | mcp | MCP page code blocks | P3 | Code blocks scroll horizontally and cut the server URL at 1440 px ("https://sysndd.dbmr.unibe.ch/m"). The page has to explain this ("Focus a code region, then use the arrow keys…") | `D/mcp-info-page.png` | Wrap long lines (`white-space: pre-wrap`) and add a copy button per block |
| S-40 | docs screenshots | `app/tests/docs-screenshots/overlays.ts` | P3 | Callout pills sit on the controls they explain: the Panels "Category" label, the phenotype-search AND/OR toggle, the modal Cancel buttons and the "Actions" headers. The Edit Review modal capture (`D/reviewer-modify-review-modal.png`) is cut off with an empty footer | listed images | Offset the callouts outside the target box. Capture modals as locators after scrolling the footer into view |

Not reproduced, or false positives
- The Genes-table header and cell misalignment in `D/genes-table.png` does not reproduce at 1366 (centres match: 161, 370, 579, 787, 996, 1205).
- The correlogram x-labels cut off in `D/phenotype-correlations-correlogram.png` come from the viewport capture, not the SVG (no text outside the SVG bounds live).
- The blue top progress bar in `D/mobile-home.png` and `D/pwa-mobile-shell.png` is a capture taken mid-navigation (no thin bar after settle).
- Runner "obscured by footer" hits on home, entities, comparisons-table and others are content under the fixed footer at the initial fold. They are expected, apart from S-23 on short viewports.
- Dropdown translucency suspected from `D/nav-analyses-dropdown.png` / `D/nav-authenticated-admin.png`: the live menu is opaque (`rgb(255,255,255)`, no backdrop-filter). It looks see-through in the docs captures only because of the overlay's highlight box.

## 3. Measurements (browser shards, 1366x768 unless noted)

The "load CLS" column is the 1366 value. Worst-viewport values are in the findings
(entity 0.175, ontology 0.334, phenotype-clusters 0.234, comparisons 0.141, data-releases
0.145, phenotypes 0.135 at 390 px). Lighthouse scores: see `out/public-lh`,
`out/curation-lh` and `out/admin-lh`, summarised by the Lighthouse shard.

| page | usable ms | load CLS | long tasks n / ms | max event ms | flicker | overflow 1366 / 390 | axe serious+crit / other | impeccable | protocol result |
|---|---|---|---|---|---|---|---|---|---|
| `home` | 466 | 0 | 2 / 235 | 24 | 0 | 3 / 0 | 0 / 0 | 6 | FAIL (2) |
| `search` | 2682 | 0.045 | 3 / 216 | 72 | 0 | 1 / 0 | 0 / 0 | 31 | FAIL (6) |
| `entities` | 1053 | 0.0002 | 2 / 464 | 24 | 0 | 13 / 0 | 1 / 0 | 3 | FAIL (2) |
| `genes` | 1067 | 0.0001 | 2 / 479 | 32 | 0 | 0 / 0 | 0 / 0 | 3 | FAIL (2) |
| `phenotypes` | 1106 | 0.0002 | 2 / 407 | 24 | 0 | 9 / 3 | 1 / 0 | 3 | FAIL (5) |
| `panels` | 2482 | 0.0001 | 2 / 498 | 104 | 0 | 21 / 0 | 0 / 0 | 0 | FAIL (1) |
| `entity` | 213 | 0.0528 | 1 / 112 | 32 | 0 | 0 / 1 | 2 / 0 | 5 | FAIL (5) |
| `gene-fbxo11` | 573 | 0.048 | 2 / 139 | 48 | 1 | 1 / 0 | 0 / 0 | 31 | FAIL (5) |
| `gene-arid1b` | 15674 | 0.0367 | 5 / 393 | 72 | 1 | 0 / 2 | 0 / 0 | 31 | FAIL (4) |
| `ontology` | 2382 | 0.0494 | 2 / 184 | 24 | 0 | 1 / 2 | 2 / 0 | 4 | FAIL (4) |
| `comparisons` | 1129 | 0.0289 | 2 / 186 | 24 | 0 | 0 / 0 | 0 / 3 | 3 | FAIL (3) |
| `comparisons-similarity` | 1698 | 0.0257 | 1 / 79 | 24 | 0 | 0 / 0 | 0 / 3 | 1 | FAIL (1) |
| `comparisons-table` | 2049 | 0.0154 | 2 / 197 | 80 | 0 | 1 / 0 | 0 / 3 | 6 | FAIL (3) |
| `phenotype-correlations` | 1612 | 0.0315 | 1 / 103 | 24 | 0 | 152 / 0 | 0 / 0 | 68 | FAIL (2) |
| `phenotype-counts` | 2931 | 0.0315 | 1 / 87 | 24 | 0 | 0 / 0 | 0 / 0 | 35 | FAIL (2) |
| `phenotype-clusters` | 3547 | 0.0947 | 1 / 115 | 48 | 3 | 0 / 0 | 0 / 0 | 13 | FAIL (7) |
| `variant-counts` | 1047 | 0.0315 | 1 / 116 | 16 | 0 | 0 / 0 | 0 / 0 | 1 | FAIL (2) |
| `entries-over-time` | 3306 | 0.0288 | 1 / 105 | 32 | 0 | 0 / 0 | 1 / 0 | 1 | FAIL (2) |
| `publications` | 716 | 0.0001 | 2 / 207 | 48 | 0 | 8 / 18 | 0 / 0 | 1 | FAIL (2) |
| `gene-networks` | 14683 | 0.0343 | 10 / 8023 | 248 | 0 | 11 / 12 | 2 / 0 | 18 | FAIL (8) |
| `data-releases` | 172 | 0 | 1 / 85 | 40 | 0 | 0 / 1 | 1 / 0 | 1 | FAIL (3) |
| `about` | 479 | 0 | 1 / 91 | 32 | 0 | 0 / 0 | 0 / 1 | 13 | PASS |
| `mcp` | 156 | 0 | 1 / 72 | 24 | 0 | 0 / 0 | 0 / 0 | 11 | PASS |
| `api` | 4301 | 0.0161 | 2 / 263 | 16 | 0 | 0 / 0 | 0 / 4 | 3 | FAIL (1) |
| `login` | 118 | 0 | 1 / 66 | 24 | 0 | 0 / 0 | 0 / 0 | 0 | PASS |
| `register` | 206 | 0 | 1 / 104 | 24 | 0 | 1 / 0 | 0 / 0 | 0 | FAIL (1) |
| `password-reset` | 186 | 0 | 1 / 100 | 24 | 0 | 0 / 0 | 0 / 1 | 0 | PASS |
| `user` | 172 | 0 | 1 / 101 | 40 | 0 | 0 / 0 | 1 / 0 | 7 | FAIL (1) |
| `review` | 966 | 0 | 3 / 400 | 24 | 0 | 11 / 1 | 2 / 1 | 7 | FAIL (4) |
| `create-entity` | 258 | 0 | 1 / 96 | 16 | 0 | 2 / 2 | 0 / 0 | 1 | FAIL (2) |
| `modify-entity` | 686 | 0 | 2 / 469 | 40 | 0 | 0 / 0 | 0 / 0 | 3 | PASS |
| `approve-review` | 1838 | 0.0001 | 2 / 514 | 32 | 0 | 2 / 0 | 1 / 0 | 12 | FAIL (3) |
| `approve-status` | 1016 | 0.0001 | 2 / 384 | 32 | 0 | 4 / 0 | 1 / 0 | 6 | FAIL (3) |
| `approve-user` | 373 | 0 | 1 / 133 | 32 | 0 | 0 / 0 | 1 / 0 | 2 | FAIL (1) |
| `manage-rereview` | 937 | 0.0074 | 1 / 144 | 24 | 2 | 1 / 0 | 0 / 0 | 4 | FAIL (4) |
| `variation-suggestions` | 313 | 0 | 1 / 151 | 24 | 0 | 0 / 0 | 0 / 0 | 1 | PASS |

`modify-entity` passes the automatic thresholds, but the protocol's static load does not
open the edit form, so it misses S-02. `gene-reviews` is not in the finished browser
shards (curation-c was still running).

## 4. Ratings (1-5, protocol section 5)

H hierarchy · C clarity of labels · Co consistency · R responsiveness · F feedback
(loading, empty, error) · S snappiness · A accessibility. Ratings combine the
screenshots, the live check at 1366x768 and 390x844, and the measurements above.

| page | H | C | Co | R | F | S | A | main reasons |
|---|---|---|---|---|---|---|---|---|
| home | 4 | 3 | 3 | 4 | 4 | 5 | 3 | US-locale date, gene-badge contrast |
| entities / genes | 4 | 4 | 3 | 3 | 4 | 4 | 3 | nested gutters at 390, disease aria mismatch, badge contrast |
| phenotypes | 4 | 4 | 3 | 3 | 3 | 4 | 3 | CLS 0.135 at 390, clipped disease names |
| panels | 3 | 2 | 2 | 3 | 4 | 4 | 4 | "Loaded 10/4", raw headers, clipped inheritance |
| entity | 4 | 3 | 3 | 3 | 3 | 4 | 3 | ISO timestamps, CLS 0.175 at 390, uneven cards |
| gene (FBXO11, ARID1B, CHD8) | 3 | 3 | 3 | 4 | 3 | 2 | 3 | 15.7 s usable (ARID1B), 9.6 px labels, duplicated symbol |
| ontology | 4 | 4 | 3 | 2 | 3 | 4 | 2 | CLS 0.334 at 390, contrast, target size |
| comparisons (overlap) | 3 | 1 | 4 | 3 | 4 | 4 | 4 | the bar copy is false (S-01) |
| comparisons-similarity | 3 | 3 | 3 | 4 | 4 | 4 | 4 | raw source keys, no cell values |
| comparisons-table | 4 | 3 | 3 | 3 | 4 | 4 | 4 | docs "Genes: undefined" |
| phenotype-correlations / counts | 3 | 3 | 4 | 4 | 4 | 4 | 3 | 10 px ticks, fractional ticks |
| phenotype-clusters | 3 | 3 | 3 | 3 | 2 | 3 | 4 | AI-summary flicker, CLS 0.234 at 390 |
| variant-counts / entries-over-time | 3 | 3 | 4 | 4 | 4 | 4 | 4 | label density, floating legend |
| publications | 4 | 3 | 2 | 3 | 4 | 4 | 4 | ".. X .." placeholders, untitled truncation |
| gene-networks | 3 | 2 | 3 | 3 | 2 | 1 | 3 | 14.7 s usable, 8 s long tasks, clipped controls |
| data-releases | 4 | 3 | 3 | 3 | 4 | 5 | 3 | raw timestamp, CLS 0.145 at 390 |
| about / mcp / api | 4 | 4 | 4 | 4 | 4 | 4 | 4 | MCP code blocks cut, duplicate API title |
| login | 4 | 3 | 4 | 4 | 2 | 5 | 4 | wrong creds marked valid |
| register | 4 | 4 | 4 | 4 | 4 | 5 | 4 | empty left column |
| password-reset | 3 | 3 | 1 | 4 | 3 | 5 | 2 | no label, off-pattern card |
| user | 3 | 3 | 3 | 4 | 4 | 5 | 2 | "in59m", avatar 2.0:1 |
| review | 2 | 3 | 3 | 3 | 2 | 4 | 2 | legend h4, wrapping actions, misleading empty state, select-name |
| create-entity | 4 | 4 | 3 | 4 | 4 | 5 | 4 | centred headings |
| modify-entity | 3 | 2 | 3 | 4 | 4 | 4 | 4 | "NA" prefill that saves back (S-02) |
| approve-review / approve-status | 3 | 3 | 3 | 3 | 4 | 4 | 3 | synopsis overflow, clipped entity badge, loud Approve All |
| approve-user | 4 | 3 | 3 | 4 | 5 | 5 | 3 | per-page "1(" |
| manage-rereview | 3 | 3 | 2 | 4 | 3 | 4 | 4 | centred summary list, timestamp formats, table flicker |
| variation-suggestions / gene-reviews | 4 | 4 | 3 | 4 | 4 | 5 | 4 | red badge for an opportunity |
| global shell (nav, footer, modals) | 3 | 3 | 2 | 2 | 4 | 4 | 3 | two hamburgers, fixed footer in landscape, centred menus, modal font |

No page reaches the protocol's done state (≥ 4 on every aspect). The fastest wins are
S-01, S-02, S-03, S-04, S-08, S-09, S-10, S-12, S-16 and S-28: each is one or two lines
at a known location.
