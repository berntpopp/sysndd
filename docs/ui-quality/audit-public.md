# UI quality audit: public pages (anonymous)

Date: 2026-11-21. Instance: `sysndd_uiaudit` at http://localhost:8091, app v0.38.4 built from
`ui/quality-2026-11` (7a0d599b + the audit tool). Protocol: `docs/ui-quality/protocol.md`.
41 public page ids, role `public`, usage-policy acknowledged except `home-first-visit`.

## How this was measured

- Browser metrics: 6 parallel shards of `tools/ui-audit/run.mjs --no-lighthouse`
  (out dirs `tools/ui-audit/out/public-s0` … `public-s5`), 3 viewports, interactions at 1366x768,
  axe-core and impeccable `detect` over CDP.
- Lighthouse 12.8.2 desktop + mobile: `--lighthouse-only` in `public-lh`, `public-lh0..2` and a serial
  retry `public-lh-retry` for runs that hit "An internal Chrome error occurred".
- Screenshots were read page by page (1366 and 390 side by side in `tools/ui-audit/out/public-montage/`),
  and every finding below was reproduced on :8091 with a dedicated Playwright probe.
- impeccable critique: run single-context (no sub-agent tool available to this agent), so the design
  review and the detector evidence were not isolated from each other. The detector output is the
  `impeccable` column of the table; the design review is the ratings table and the findings.

Caveat on timing: other audit agents (curation, admin, their Lighthouse runs) were running at the same
time; load average was 40-80 on 32 cores. `usable ms` and Lighthouse Performance are therefore
pessimistic. A quiet single-page re-check gave networkidle 3.7 s for `/Genes/ARID1B` (15.7 s in the
shard) and 3.5 s for `/GeneNetworks` (14.7 s). Layout shift, overflow, axe and label findings do not
depend on load.

Tool artifacts (not findings): "obscured" hits whose cover is `nav.fixed-bottom` / `div.footer-shell` /
`footer-partners` are elements that merely sit under the fixed footer at the bottom of the viewport
screenshot; scrolling reveals them. `comparisons-table` "never usable @390x844" is a ready-selector
mismatch: the mobile cards render (see screenshot) but do not match `ROWS`. impeccable
`ai-color-palette` on the purple inheritance badge and most `nested-cards` hits are intentional
system styling, reviewed and left as P3 at most.

## Known screenshot bugs: verdicts

| # | Bug | Verdict | Cause | Fix |
|---|---|---|---|---|
| 1 | Comparisons table "Genes: undefined" | Not reproducible against the real API (Genes: 5147; 139 with Definitive Only; 0 for a no-hit filter). The docs screenshot came from a mocked response. | `app/tests/docs-screenshots/helpers.ts:209` mocks `meta: [{ total_rows, execution_time }]`; the API sends `totalItems`, `currentPage`, `totalPages`, `fspec`… The missing `fspec` is also why the docs image shows uncurated headers "Sys NDD / Panelapp / Sfari". The app reads `data.meta[0].totalItems` unguarded (`app/src/components/analyses/AnalysesCurationComparisonsTable.vue:396`, rendered at `:6`). | Make the mock use the real meta shape (copy one live `meta[0]`), then recapture `documentation/static/img/generated/curation-comparisons-table.png`. Defensive: `:meta="'Genes: ' + (totalRows ?? 0).toLocaleString()"` and `totalItems ?? 0`. |
| 2 | Panels "Loaded 10/5" | Confirmed; reproduced as "Loaded 10/0" at `/Panels/Refuted/Other`. | `app/src/views/tables/PanelsTable.vue:10` prints `perPage`, not the rows loaded. Same bug in `app/src/components/tables/TablesLogs.vue:11` (admin). | `Showing ${items.length} of ${totalRows.toLocaleString()}` (see PUB-07 for the shared wording). |
| 3 | Modify Entity literal "NA" for empty comments | Confirmed at API level: `GET /api/entity/1848/status` returns `"comment":"NA"`. | The R serializers use `@serializer json list(na="string")` (150 endpoint annotations; `api/endpoints/entity_endpoints.R:440` for status), so missing values arrive as the string "NA"; `app/src/views/curate/composables/useStatusForm.ts:171` and `:219` do `statusData.comment \|\| ''`, which keeps "NA". | Short term in the app: one `isMissing(v)` helper (`null`, `undefined`, `''`, `'NA'`) used where API text is shown or loaded into forms. Root: switch the read endpoints whose payload feeds forms to `na="null"` (jsonlite default). Same class of bug as PUB-04. |
| 4 | Data-releases archive raw date | Confirmed: "Published 2026-07-18 20:01:55" in the archive list, while the summary above says "July 18, 2026". | `app/src/components/analyses/ReleaseArchiveList.vue:23` renders `release.published_at` raw; `ReleaseManifestPanel.vue:63` (Created) and `:67` (Published) too. The long format exists only locally in `ReleaseDeskSummary.vue:100` (`formatReleaseDate`). | Move `formatReleaseDate` into `app/src/utils/dateUtils.ts` as `formatLongDate` (en-US, `month: 'long'`, `timeZone: 'UTC'`) and use it in all three places (and for PUB-06). |
| 5 | UpSet text "unique to that intersection" vs bars | Confirmed: the bars are inclusive. With SysNDD/PanelApp/Gene2Phenotype selected the single-set bars are 3,217 / 2,834 / 2,552, exactly the set sizes shown on the left, and the three-way bar is 1,694, which is also counted inside every pair bar. | `app/src/components/analyses/AnalysesCurationUpset.vue:329` calls `render()` without `combinations`; upsetjs then uses `DEFAULT_COMBINATIONS = { type: 'intersection' }` (`node_modules/@upsetjs/bundle/dist/upsetjs.umd.development.js:3518`), which is non-exclusive. The copy at `AnalysesCurationUpset.vue:17-18` describes `distinctIntersection`. | Change the text, not the chart: "Each bar counts the genes listed by every source marked with a dot below; a gene is counted in each bar whose sources all list it." The SysNDD and core-overlap highlight markers are defined on inclusive sets, so switching to `distinctIntersection` would also change what those markers mean. Also rename the axis "Intersection Size" to "Genes in all marked sources". |

## Findings

Severity: P1 = wrong information, broken layout or a blocking accessibility failure; P2 = clearly
visible defect or measurable threshold failure; P3 = polish. Evidence paths are relative to
`tools/ui-audit/out/`.

| id | page(s) | finding | cause (file:line) | sev | evidence | proposed fix |
|---|---|---|---|---|---|---|
| PUB-01 | analysis, phenotype-clusters, gene-networks | At 390 px the two resizable panes stay side by side: "Selecte d cluster 1 with" wraps per character, the organ-system card is cut ("Predomina…"), the network is 40 px wide, the gene-cluster table shows "Clus…". Unusable on a phone. | `app/src/components/analyses/AnalysesPhenotypeClusters.vue:41` and `AnalyseGeneClusters.vue:18` use `AccessibleSplitter orientation="vertical"` at every width; `app/src/components/accessibility/AccessibleSplitter.vue:5` has no breakpoint. | P1 | `public-s5/analysis/390x844.png`, `public-s4/phenotype-clusters/390x844.png`, `public-s4/gene-networks/390x844.png` | In `AccessibleSplitter`, below 992 px render the two slots stacked (plain column, no splitter handle, panes 100 % width). One change fixes both pages. |
| PUB-02 | comparisons | Known bug 5: UpSet copy says bars are exclusive, the chart is inclusive. | see table above | P1 | `public-s5/comparisons/1366x768.png` | see table above |
| PUB-03 | entities, genes, phenotypes, comparisons-table, publications, pubtator, pubtator-genes, panels, nddscore, ontology/gene "Associated" | Pagination shows only "1 2" for 515 pages, and at 390 px the current page button is hidden (`page-item active bv-d-sm-down-none`, `display:none`), so the pager reads "« ‹ 2 › »". No page count anywhere. | `app/src/components/small/TablePaginationControls.vue:28` `limit="2"`; bootstrap-vue-next hides non-edge numbers below sm and, with limit 2, that includes the active page. Same in `components/review/ReviewTable.vue:71`, `views/review/components/ReviewQueueTable.vue:153`. | P2 | `public-montage/genes.png` (right) | `limit="5"` (bvn then shows ellipses and keeps the active page) and a "Page 3 of 515" text next to the pager. |
| PUB-04 | nddscore-modelcard, data-releases | Literal "NA" shown as a value: model card "Version NA"; release manifest "Version: NA". | Model card: `app/src/components/nddscore/NddScoreModelCard.vue:46` + `displayValue()` returns `'NA'` for missing (`:192`, also `formatDecimal :181`, `formatCount :186`). Release: API sends `release_version: "NA"` (na="string"), `ReleaseManifestPanel.vue:35` `v-if="release.release_version"` lets the string through. | P2 | probe on `/DataReleases` (dt/dd dump); `public-montage/nddscore-modelcard.png` | Same `isMissing` helper as bug 3; render "—" (the manifest panel's own `displayValue` already uses "—"). Fix the model-card helpers to return "—". |
| PUB-05 | data-releases | Known bug 4 (raw timestamps) | see table above | P2 | `public-s5/data-releases/1366x768.png` | see table above |
| PUB-06 | home, comparisons*, entity, ontology, publications-stats, pubtator, gene pages | Dates come in five formats: "Updated 11/12/2025" (locale-dependent, ambiguous), "Data 7/12/2026", "Entered 2016-08-05", "Last reviewed 2022-06-25 19:40:30", "Mapping release: 2026-09-01", "Newest Publication 2025-11-05", PubTator "2024-03-11", Publications "Sep 1, 1979". | `app/src/views/HomeView.vue:149` and `views/analyses/CurationComparisons.vue:106` use `toLocaleDateString()` with no locale; `components/ui/EntityFreshnessPills.vue:21,30`, `views/pages/components/ClinicalSynopsisCard.vue:24`, `views/pages/components/OntologyHero.vue:131`, `components/analyses/PublicationsNDDStats.vue:179` print raw ISO. | P2 | `public-montage/home.png`, `entity.png`, `ontology.png`, `publications-stats.png` | One `formatLongDate` in `utils/dateUtils.ts` (PUB-05) for all user-facing dates; full ISO kept in `title` for precision. |
| PUB-07 | entities, genes, phenotypes, panels, publications, pubtator, gene/ontology "Associated", nddscore-modelcard, gene pages | Counts unformatted ("Entities: 4200", "Genes: 3214", "Associated entities: 3579", "ClinVar Variants (1259)", model card "Genes 19296") while home and charts use "1,997". Every table header carries developer text "Loaded 10/4200 in 0.27 secs". | `components/tables/TablesEntities.vue:14`, `TablesGenes.vue:14`, `TablesPhenotypes.vue:10`, `views/tables/PanelsTable.vue:6,10`; `NddScoreModelCard.vue:186` `String(Math.trunc())`. | P2 | `public-montage/entities.png`, `panels.png` | `toLocaleString('en-US')` on every count; replace "Loaded x/y in t" with "Showing 1–10 of 4,200" (drop the execution time or move it to a `title`). |
| PUB-08 | comparisons-table | Known bug 1 | see table above | P3 (docs only) | `documentation/static/img/generated/curation-comparisons-table.png` | see table above |
| PUB-09 | panels, pubtator, pubtator-genes | Column headers are raw keys: "Hgnc id", "Entrez id", "Ensembl gene id", "Ucsc id", "Bed hg19" (Panels, also the "Sort: symbol" select), "Search id", "Pmid", "Doi", "Text hl" (PubTator), "Gene name", "Hgnc id", "Is novel", "Npmi", "Fdr bh" (PubTator genes). | API builds labels with `str_to_sentence(key)`: `api/functions/response-fields-helpers.R:332`, `api/functions/panels-endpoint-functions.R:109`. The app already has curated labels ("Search ID", "Genes", "Text HL" at `components/analyses/usePubtatorPublicationTable.ts:88-96`) but `mergeFields` (`:177`, `...f`) and `mergePubtatorGeneFields` (`usePubtatorGenesTable.ts:104`) overwrite them with the server label; `PanelsTable.vue:406` takes `data.fields` as is. | P2 | `public-montage/panels.png`, `pubtator.png`, `pubtator-genes.png` | In both merges keep `label: existing?.label ?? f.label` (as `withCuratedComparisonLabels` does for comparisons); give Panels a curated field list; in the API helper upper-case known acronyms (HGNC, ID, PMID, DOI, UCSC, BED, FDR, NPMI). |
| PUB-10 | comparisons, comparisons-similarity, phenotype-functional | Chart labels are database keys: UpSet set names "panelapp", "gene2phenotype" next to chips "PanelApp", "Gene2Phenotype"; similarity axes "omim_ndd", "orphanet_id", "radboudumc_ID", "ndd_genehub"; x labels clipped at the bottom at 1366 ("_ID", "type"). Pheno-func heatmap axes "fc_1, fc_10, fc_13 … fc_296, pc_1" sorted as strings, with a second in-chart title duplicating the card title. | `components/analyses/AnalysesCurationMatrixPlot.vue:133` domain from raw `d.x`; `AnalysesCurationUpset.vue` sets from raw keys (`extractSets`, `:292`); `components/analyses/AnalysesPhenotypeFunctionalCorrelation.vue:172` domain `clusterNames` unsorted. | P2 | `public-montage/comparisons-similarity.png`, `phenotype-functional.png`, `comparisons.png` | Map keys through the curated source labels already used for the chips/table (`curationComparisonsTableConfig.ts`); add bottom margin for rotated labels; label clusters "FC 1"/"PC 1" and sort numerically. |
| PUB-11 | comparisons-table, pubtator-genes, nddscore | Truncated controls and headers: filter selects "Any Gene2Phe", "Any Radboudun", "Any NDD Gene", "Any OMIM NDE" with the caret over the text; headers "Gene2Phenoty", "NDD GeneHub" (overflow 26-47 px); PubTator genes headers overflow 40-102 px ("Gene nam", "Publicatio", "Backgrou"); NDDScore filter placeholders ".. Risk tier ..", ".. Confidence". | Fixed equal column widths in the generic table (`components/small/GenericDesktopTable.vue`) with long labels; NDDScore placeholder strings. | P2 | `public-s1/comparisons-table/1366x768.png`, `public-montage/pubtator-genes.png`, `nddscore.png` | Let header cells wrap (`white-space: normal`) and size filter selects to the column; shorter placeholders ("Any", "Risk tier"); fewer default columns on PubTator genes. |
| PUB-12 | panels, publications, entities, phenotypes | Content clipped without a way to read it: Panels Inheritance pill "Autosomal dominant inh", BED coordinates "chr12:8975068-9…" (21 clipped at 1366), journal badges "American journal of human g", disease badges cut at 35 chars while the column has room. | Panels pill inside a fixed-width cell (`views/tables/PanelsTable.vue` inheritance cell); `div.w-100.text-truncate` for coordinates; DiseaseBadge `:max-length="35"` (`TablesEntities.vue:199`). | P2 | `public-s3/panels/1366x768.png`, `public-montage/publications.png` | Use the inheritance abbreviations (AD/AR/XLR badges as on Entities) in Panels; `title` on truncated cells; let disease badges use the available width (truncate with CSS, not at 35 chars). |
| PUB-13 | entity | At 1366 the disease chip in the entity hero overflows its cell and the card (chip right edge 1362 px, card 1342 px). | `views/pages/components/EntityViewHero.vue:61` passes `:max-length="0"` to a badge that is `white-space: nowrap` with a fixed 24 px height (`components/ui/DiseaseBadge.vue:127-136`). | P2 | `public-montage/entity.png`; probe: badge `[802,1362]` vs container `[24,1342]` | Allow wrapping for this one usage (prop or `.entity-unit-disease :deep(.disease-badge){height:auto;max-height:none;white-space:normal}`) and `min-width:0` on the link. |
| PUB-14 | analysis, phenotype-clusters | Layout shift during load: CLS 0.12 @1366, 0.25 @390 (Lighthouse mobile 0.23); "Loading AI summary..." line appears for 163-1020 ms, then is replaced by a tall card (flicker). | `components/analyses/AnalysesPhenotypeClusters.vue:188-191` renders a one-line spinner where a ~300 px summary card will appear. | P2 | `public-s5/results.json` (analysis) | Render a summary-card skeleton with the card's height while loading. |
| PUB-15 | entity, ontology, data-releases, comparisons, nddscore, phenotypes, gene pages | Load CLS above 0.05 at 390 px: ontology 0.33 (LH mobile 0.35), entity 0.18 (LH 0.21), data-releases 0.15, comparisons 0.14, phenotypes 0.13, nddscore 0.13, nddscore-gene 0.13, gene pages 0.08-0.09 (0.05 @1920). | Skeleton sizes do not match content: gene external cards reserve `min-height="16rem"` (`views/pages/GeneView.vue:92,106,127`) but gnomAD/ClinVar content is ~8 rem; ontology `#associated-entities-table` mounts late; entity linked-ontology / synopsis skeletons are shorter than content. | P2 | summary table, shift sources | Size each skeleton to its real content per breakpoint (or reserve with `min-height` on the loaded card too). |
| PUB-16 | pubtator | Paginating shifts the table by 0.28 (rows change height page to page). | Variable-height cells (title, highlighted text, gene chips) in `components/analyses/PubtatorNDDTable.vue`. | P2 | `public-s1/results.json` interactions.paginate | Clamp title and text cells to 2 lines (`-webkit-line-clamp`) and cap gene chips at one row with "+N". |
| PUB-17 | gene-networks | Lighthouse Performance 63 desktop / 37 mobile, TBT 3.6 s / 19.8 s, mobile LCP 13 s; paginating the cluster table takes 248 ms with 215 ms of long tasks. `/api/analysis/functional_clustering?page_size=50` alone takes 2.0 s. | Cytoscape layout of 1,310 nodes / 4,110 edges on the main thread at load, plus re-render on table interactions (`components/analyses/AnalyseGeneClusters.vue`, `NetworkVisualization.vue`). | P2 | `public-lh*/lighthouse/gene-networks-*.json` | Defer the network until visible/requested (show the cluster table first), run layout in a worker or use a preset layout from the snapshot, and do not re-render the graph on table paging. |
| PUB-18 | publications-stats, publications-timeplot, entries-over-time, pubtator-stats, pubtator-genes | axe critical `select-name` / `label`: selects and number inputs inside `BInputGroup prepend="…"` have no accessible name (Lighthouse a11y 90-96). | e.g. `components/analyses/PublicationsNDDStats.vue:44-60`; same pattern in the timeplot, entries-over-time, PubTator stats/genes controls. | P1 | axe in summary | Give each control an `id` and a `<label for>` (visually the prepend text) or `aria-label`. |
| PUB-19 | all tables, gene-networks, pubtator-stats, entity, ontology, nddscore-gene | Contrast below AA: white on gene-badge green 3.7:1; white on cluster badge orange #ff7f0e 2.5:1; `h3.text-info` (#0dcaf0) 2.0:1 in PubTator stats; small uppercase unit labels in entity/ontology/NDDScore heroes (axe serious). | `components/ui/GeneBadge.vue` gradient; cluster badge colors in the gene-cluster table; `components/analyses/PubtatorNDDStats.vue:57`; `.entity-unit-label` (`EntityViewHero.vue:171`), `.ontology-unit-label`, `.ndd-gene-detail__unit-label`. | P2 | impeccable/axe lists in summary | Darken badge backgrounds (green ≤ #127a3a, orange → #b45309 or dark text), use `text-info-emphasis`, darken unit labels to neutral-700. |
| PUB-20 | pubtator-genes, ontology | axe serious `target-size`: PMID buttons and copy/open icons < 24 px. | PubTator genes PMID `btn-sm` chips; ontology hero copy/open icon buttons. | P2 | axe in summary | Min 24x24 hit area (padding), keep the visual size. |
| PUB-21 | entities, phenotypes, entity, data-releases, gene-networks | axe serious `label-content-name-mismatch`: visible text is not part of the accessible name (disease badges "Disease …" vs truncated text; HPO chips "HPO term: present \| HP:…"; release archive buttons). | `components/ui/DiseaseBadge.vue:11`; HPO chips in the entity phenotype card; `ReleaseArchiveList.vue` item buttons. | P3 | axe in summary | Start the accessible name with the visible text ("Intellectual developmental disorder…, disease") or drop the `aria-label` where visible text suffices. |
| PUB-22 | nddscore-gene | axe serious `definition-list` and `list`: `<dl>` and `<ul>` contain non-`dt/dd` / non-`li` children. | `.ndd-gene-detail__metrics`, `.ndd-gene-detail__compact-grid`, `.ndd-gene-detail__list` in the NDDScore gene detail component. | P3 | axe in summary | Wrap pairs in `<div>` (allowed) or use plain `div`s. |
| PUB-23 | variant-counts, phenotype-counts, variant-correlations, phenotype-correlations, entries-over-time, publications-timeplot, phenotype-functional | At 390 px every D3 chart is the desktop SVG scaled to ~300 px: tick labels ~4 px, unreadable. On desktop the charts are fixed width and left-centred inside a wider card. | Fixed-width SVG with `viewBox` scaling in the D3 analysis components. | P2 | `public-montage/variant-counts.png`, `phenotype-correlations.png`, `entries-over-time.png` | Give charts a minimum drawing width and put them in a horizontal scroll container on phones (or switch bar charts to horizontal bars); size to the card on desktop. |
| PUB-24 | api | At 390 px the hero keeps the version card beside the title; the title column is ~90 px wide and wraps word per line. | `app/src/assets/scss/components/_public-pages.scss:32` (`.public-hero` flex row); the mobile block at `:283` only changes padding. | P2 | `public-montage/api.png` | In the mobile block add `flex-direction: column`. |
| PUB-25 | gene-fbxo11, gene-arid1b, search | Layout: Model Organisms card sits alone, centred, at lg (2-up); the three cards have unequal heights; gnomAD constraint labels and CIs are 9.6 px; the Associated table shows an empty grey toolbar band and "Loaded 2/2 in 0.13 secs". On phones Resources/Identifiers rows are clipped ("OMI", "Ent") with no scroll hint. External cards wait 2.4-2.9 s (`/api/external/{rgd,mgi,uniprot,gnomad}`). | `views/pages/GeneView.vue:84` `justify-content-md-center`; gnomAD card font sizes; external proxy latency. | P2 | `public-montage/gene-arid1b.png`, `gene-fbxo11.png` | Left-align the row and `h-100` the cards; ≥ 11 px text; hide the empty toolbar for embedded tables; cache external proxy responses. |
| PUB-26 | pubtator-stats, publications-stats | Stats cards contradict their labels: "Total Genes 8 of 352 total" because a ≥5-publications filter, explained only below the cards, is applied to the cards; "Publications 2026 (YTD) 0" while the newest publication is 2025-11-05. Headings skip levels (h2 → h6, h4 → h6). | `components/analyses/PubtatorNDDStats.vue:44,60,77,89`; `PublicationsNDDStats.vue`. | P3 | `public-montage/pubtator-stats.png`, `publications-stats.png` | Show unfiltered totals in the cards and the filter caption on the chart; hide a YTD card with 0 or label it "No 2026 publications in SysNDD yet"; fix heading levels. |
| PUB-27 | comparisons-table | "Definitive Only" sets every source column to Definitive, i.e. genes definitive in all eight lists (139), while `definitive_only=false` is still sent. The label reads as "SysNDD definitive". Mobile cards use cryptic chips "+ S", "- G2P", "- SF", "- OR". | `components/analyses/AnalysesCurationComparisonsTable.vue:29-31,344-347`. | P3 | probe log (5147 → 139) | Rename to "Definitive in every source" or filter SysNDD only; full source names on mobile chips. |
| PUB-28 | data-releases | Phone: file names break mid-word ("payload.jso n"), sizes wrap ("13.8 / MB"); eyebrow labels ("CURRENT RELEASE", "ARCHIVE") are indented differently from their headings; "Need one file?" is centred over a left-aligned list. | `components/analyses/ReleaseDeskSummary.vue` file list, `ReleaseArchiveList.vue` header. | P3 | `public-montage/data-releases.png` | `overflow-wrap:anywhere` only on the path, `white-space:nowrap` on sizes; align eyebrows with headings. |
| PUB-29 | nddscore-modelcard | Copy: "is not an curated classification"; title centred while its icon is left. | `components/nddscore/NddScoreModelCard.vue:93-95`. | P3 | `public-montage/nddscore-modelcard.png` | "is not a curated classification". |
| PUB-30 | phenotype-correlations, pubtator, publications (phone) | Analysis tab strips overflow at 390 px ("Ph…" cut) with no scroll affordance. | `components/navigation/AnalysisTabs.vue`. | P3 | `public-montage/phenotype-correlations.png` | Fade edge or wrap tabs to two rows. |
| PUB-31 | phenotypes (phone) | Mobile record shows raw modifier codes "1-HP:0000077, 1-HP:0000707 +6". | `components/tables/PhenotypesMobileRows.vue`. | P3 | `public-montage/phenotypes.png` | Show phenotype names (as the desktop filter chips do) or a count ("8 phenotypes"). |
| PUB-32 | gene-fbxo11, gene-arid1b | Switching the genomic visualisation tab flashes a "Gene structure" SVG for 62-251 ms before the real render. | `components/gene/GenomicVisualizationTabs.vue:94-111` (KeepAlive panel mounts, then the D3 render replaces it). | P3 | interactions.tab.flicker | Keep the skeleton until the D3 render completes. |
| PUB-33 | not-found | 404 page offers no way on (no home link, no search). | `views/PageNotFoundView.vue`. | P3 | `public-montage/not-found.png` | Add "Go to home" and the search field. |
| PUB-34 | all (phone) | Two hamburger buttons (header and fixed footer) and a 50 px fixed footer on a 844 px screen; help badges use a cyan disc with a black "?" that matches nothing else (the UpSet header shows two different help badges side by side). | `components/AppNavbar.vue`, footer nav; `InlineHelpBadge`. | P3 | any 390 screenshot; `public-s5/comparisons/1366x768.png` | Collapse the footer into the header menu on phones; one help-badge style. |

## Summary for the fix release

- Fix together (smallest diffs, highest value): PUB-01 (one component), PUB-02 (copy), PUB-03 (one
  prop + text), bug 3 + PUB-04 (`isMissing`), bug 4 + PUB-05/06 (`formatLongDate`), PUB-07 (counts and
  "Showing x of y"), PUB-09 (keep curated labels in two merges), PUB-18 (labels on ~10 controls),
  PUB-13, PUB-24, PUB-29, bug 1 (mock shape + recapture).
- Next: PUB-14/15 skeleton heights, PUB-16, PUB-17 (gene networks performance), PUB-19 contrast tokens,
  PUB-23 mobile charts.
- Re-measure with the same commands; the before state is `tools/ui-audit/out/public-*`.

## Measurements per page

Generated by `node tools/ui-audit/summarize.mjs` over all public shards (browser metrics at the three viewports, interactions at 1366x768, Lighthouse desktop/mobile). `usable ms` is the worst viewport; it is inflated by the parallel load noted above. Full per-page evidence (shift sources, clipped elements, axe nodes, impeccable hits): `tools/ui-audit/out/public-summary.md`.

Base: http://localhost:8091 · generated 2026-11-21T14:06:35.550Z · 41 pages · 6 pass

| page | role | LH desktop P/A/BP/SEO | LH mobile P/A/BP/SEO | mobile LCP ms / CLS / TBT ms | usable ms | load CLS | max interaction shift | long tasks n / ms | max event ms | flicker | overflow 1366 / 390 | axe serious+crit / other | impeccable | result |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `home` | public | 100/100/100/100 | 99/100/100/100 | 295 / 0 / 116 | 466 | 0 | 0 | 2 / 235 | 24 | 0 | 3 / 0 | 0 / 0 | 6 | FAIL (2) |
| `comparisons-similarity` | public | 100/100/100/100 | 97/100/100/100 | 792 / 0.0693 / 90 | 1698 | 0.0257 | 0 | 1 / 79 | 24 | 0 | 0 / 0 | 0 / 3 | 1 | FAIL (1) |
| `phenotype-functional` | public | 100/100/100/100 | 100/100/100/100 | 232 / 0 / 40 | 3053 | 0 | 0 | 1 / 128 | 24 | 0 | 0 / 0 | 0 / 0 | 1 | FAIL (2) |
| `publications-stats` | public | 100/91/100/100 | 100/90/100/100 | 317 / 0.0419 / 54 | 2528 | 0.0062 | 0 | 1 / 86 | 24 | 0 | 0 / 0 | 2 / 1 | 8 | FAIL (4) |
| `nddscore` | public | 98/100/100/100 | 93/100/100/100 | 940 / 0 / 314 | 908 | 0.0364 | 0 | 2 / 371 | 80 | 0 | 2 / 3 | 0 / 0 | 5 | FAIL (3) |
| `mcp` | public | 100/100/100/100 | 96/100/100/100 | 662 / 0.1202 / 72 | 156 | 0 | 0 | 1 / 72 | 24 | 0 | 0 / 0 | 0 / 0 | 11 | PASS |
| `gene-fbxo11` | public | 98/100/100/100 | 97/96/100/100 | 756 / 0.0825 / 139 | 573 | 0.048 | 0.0011 | 2 / 139 | 48 | 1 | 1 / 0 | 0 / 0 | 31 | FAIL (5) |
| `home-first-visit` | public | 100/100/100/100 | 99/100/100/100 | 304 / 0 / 145 | 827 | 0 | 0 | 2 / 259 | 0 | 0 | 1 / 0 | 0 / 0 | 6 | FAIL (1) |
| `comparisons-table` | public | 96/100/100/100 | 96/97/100/100 | 307 / 0.0446 / 213 | 2049 | 0.0154 | 0 | 2 / 197 | 80 | 0 | 1 / 0 | 0 / 3 | 6 | FAIL (3) |
| `variant-correlations` | public | 100/100/100/100 | 99/100/96/100 | 794 / 0.033 / 110 | 803 | 0.0315 | 0 | 1 / 110 | 24 | 0 | 0 / 0 | 0 / 0 | 27 | FAIL (1) |
| `pubtator` | public | 100/100/100/100 | 97/100/100/100 | 336 / 0 / 208 | 680 | 0 | 0.2805 | 2 / 141 | 40 | 0 | 55 / 52 | 0 / 0 | 2 | FAIL (3) |
| `nddscore-modelcard` | public | 100/100/100/100 | 100/100/100/100 | 812 / 0 / 36 | 196 | 0.0001 | 0 | 1 / 93 | 24 | 0 | 0 / 1 | 0 / 0 | 8 | FAIL (1) |
| `api` | public | 100/98/100/92 | 99/98/100/92 | 330 / 0.0199 / 122 | 4301 | 0.0161 | 0 | 2 / 263 | 16 | 0 | 0 / 0 | 0 / 4 | 3 | FAIL (1) |
| `gene-arid1b` | public | 99/100/100/100 | 94/96/100/100 | 768 / 0.0935 / 219 | 15674 | 0.0367 | 0.0011 | 5 / 393 | 72 | 1 | 0 / 2 | 0 / 0 | 31 | FAIL (4) |
| `entities` | public | 98/100/100/100 | 86/100/96/100 | 311 / 0 / 542 | 1053 | 0.0002 | 0 | 2 / 464 | 24 | 0 | 13 / 0 | 1 / 0 | 3 | FAIL (2) |
| `phenotype-correlations` | public | 100/100/100/100 | 100/100/96/100 | 202 / 0.0401 / 30 | 1612 | 0.0315 | 0 | 1 / 103 | 24 | 0 | 152 / 0 | 0 / 0 | 68 | FAIL (2) |
| `variant-counts` | public | 100/100/100/100 | 100/100/100/100 | 439 / 0.0217 / 0 | 1047 | 0.0315 | 0 | 1 / 116 | 16 | 0 | 0 / 0 | 0 / 0 | 1 | FAIL (2) |
| `pubtator-genes` | public | 100/91/100/100 | 99/97/100/100 | 931 / 0.0015 / 148 | 2626 | 0.0108 | 0.0122 | 3 / 332 | 88 | 0 | 4 / 0 | 3 / 1 | 14 | FAIL (5) |
| `nddscore-gene` | public | 99/91/100/100 | 72/90/100/100 | 4353 / 0.1144 / 163 | 253 | 0.0357 | 0 | 2 / 257 | 24 | 0 | 0 / 0 | 3 / 0 | 23 | FAIL (4) |
| `login` | public | 99/100/100/100 | 78/100/100/100 | 4128 / 0.0204 / 140 | 118 | 0 | 0 | 1 / 66 | 24 | 0 | 0 / 0 | 0 / 0 | 0 | PASS |
| `ontology` | public | 97/94/100/100 | 52/94/100/100 | 5252 / 0.3524 / 176 | 2382 | 0.0494 | 0 | 2 / 184 | 24 | 0 | 1 / 2 | 2 / 0 | 4 | FAIL (7) |
| `genes` | public | 99/100/100/100 | 85/100/100/100 | 371 / 0.0009 / 586 | 1067 | 0.0001 | 0 | 2 / 479 | 32 | 0 | 0 / 0 | 0 / 0 | 3 | FAIL (2) |
| `phenotype-counts` | public | 100/100/100/100 | 99/100/96/100 | 249 / 0.0227 / 95 | 2931 | 0.0315 | 0 | 1 / 87 | 24 | 0 | 0 / 0 | 0 / 0 | 35 | FAIL (2) |
| `entries-over-time` | public | 100/96/100/100 | 97/96/100/100 | 563 / 0.0226 / 200 | 3306 | 0.0288 | 0 | 1 / 105 | 32 | 0 | 0 / 0 | 1 / 0 | 1 | FAIL (2) |
| `pubtator-stats` | public | 100/93/100/100 | 100/92/100/100 | 781 / 0 / 49 | 8404 | 0.0119 | 0 | 1 / 80 | 32 | 0 | 1 / 0 | 2 / 0 | 4 | FAIL (6) |
| `panels` | public | 100/100/100/100 | 89/100/100/100 | 255 / 0.0009 / 438 | 2482 | 0.0001 | 0.0005 | 2 / 498 | 104 | 0 | 21 / 0 | 0 / 0 | 0 | FAIL (1) |
| `register` | public | 100/100/100/100 | 100/100/100/100 | 659 / 0 / 0 | 206 | 0 | 0 | 1 / 104 | 24 | 0 | 1 / 0 | 0 / 0 | 0 | FAIL (1) |
| `search` | public | 98/100/100/100 | 96/96/100/100 | 1014 / 0.0825 / 186 | 2682 | 0.045 | 0 | 3 / 216 | 72 | 0 | 1 / 0 | 0 / 0 | 31 | FAIL (6) |
| `phenotypes` | public | 99/100/100/100 | 87/100/96/100 | 381 / 0.0012 / 535 | 1106 | 0.0002 | 0 | 2 / 407 | 24 | 0 | 9 / 3 | 1 / 0 | 3 | FAIL (5) |
| `phenotype-clusters` | public | 96/100/100/100 | 73/100/100/100 | 618 / 0.2272 / 630 | 3547 | 0.0947 | 0.022 | 1 / 115 | 48 | 3 | 0 / 0 | 0 / 0 | 13 | FAIL (7) |
| `publications` | public | 98/100/100/100 | 96/100/100/100 | 945 / 0 / 221 | 716 | 0.0001 | 0 | 2 / 207 | 48 | 0 | 8 / 18 | 0 / 0 | 1 | FAIL (2) |
| `gene-networks` | public | 63/100/100/100 | 37/100/100/100 | 13003 / 0.0483 / 19753 | 14683 | 0.0343 | 0 | 10 / 8023 | 248 | 0 | 11 / 12 | 2 / 0 | 18 | FAIL (10) |
| `about` | public | 100/98/100/100 | 96/98/100/100 | 771 / 0 / 222 | 479 | 0 | 0 | 1 / 91 | 32 | 0 | 0 / 0 | 0 / 1 | 13 | PASS |
| `password-reset` | public | 100/100/100/100 | 100/100/100/100 | 216 / 0 / 39 | 186 | 0 | 0 | 1 / 100 | 24 | 0 | 0 / 0 | 0 / 1 | 0 | PASS |
| `not-found` | public | 100/100/100/100 | 100/100/100/100 | 660 / 0 / 0 | 199 | 0 | 0 | 1 / 92 | 32 | 0 | 0 / 0 | 0 / 0 | 0 | PASS |
| `comparisons` | public | 100/100/100/100 | 100/100/100/100 | 221 / 0.0289 / 73 | 1129 | 0.0289 | 0 | 2 / 186 | 24 | 0 | 0 / 0 | 0 / 3 | 3 | FAIL (3) |
| `analysis` | public | 94/100/100/100 | 86/100/100/100 | 661 / 0.2534 / 120 | 4390 | 0.1209 | 0.0231 | 1 / 84 | 88 | 2 | 0 / 0 | 0 / 1 | 12 | FAIL (6) |
| `publications-timeplot` | public | 100/96/100/100 | 99/96/100/100 | 402 / 0.022 / 126 | 4714 | 0.0284 | 0 | 1 / 152 | 16 | 0 | 0 / 0 | 1 / 0 | 1 | FAIL (2) |
| `data-releases` | public | 100/100/100/100 | 92/100/100/100 | 344 / 0.1435 / 165 | 172 | 0 | 0 | 1 / 85 | 40 | 0 | 0 / 1 | 1 / 0 | 1 | FAIL (3) |
| `documentation` | public | 99/100/100/100 | 79/100/100/100 | 4127 / 0.0204 / 84 | 204 | 0 | 0 | 1 / 90 | 24 | 0 | 0 / 0 | 0 / 0 | 9 | PASS |
| `entity` | public | 88/97/100/100 | 64/96/100/100 | 4803 / 0.2111 / 80 | 213 | 0.0528 | 0 | 1 / 112 | 32 | 0 | 0 / 1 | 2 / 0 | 5 | FAIL (7) |

## Ratings (1-5)

| page | hierarchy | clarity | consistency | responsiveness | feedback | snappiness | accessibility | note |
|---|---|---|---|---|---|---|---|---|
| `home` | 4 | 3 | 3 | 4 | 4 | 4 | 4 | date 11/12/2025 locale-dependent |
| `home-first-visit` | 4 | 4 | 4 | 4 | 4 | 4 | 4 | dialog fine |
| `entities` | 4 | 3 | 3 | 3 | 4 | 4 | 3 | raw counts, Loaded x/y dev text, pager hides current page on phone |
| `genes` | 4 | 3 | 3 | 3 | 4 | 4 | 4 |  |
| `phenotypes` | 4 | 3 | 3 | 3 | 3 | 4 | 3 | CLS .13 @390, raw HP codes chip |
| `comparisons` | 4 | 2 | 3 | 3 | 4 | 4 | 4 | UpSet text contradicts bars; raw set labels |
| `comparisons-similarity` | 4 | 2 | 3 | 3 | 4 | 4 | 4 | raw keys, x labels clipped |
| `comparisons-table` | 4 | 3 | 3 | 3 | 4 | 4 | 4 | truncated filters/headers, cryptic mobile chips |
| `phenotype-correlations` | 4 | 3 | 4 | 2 | 4 | 4 | 4 | unreadable on phone, tab strip cut |
| `phenotype-counts` | 4 | 3 | 4 | 2 | 4 | 4 | 4 | chart unreadable on phone |
| `phenotype-clusters` | 3 | 3 | 3 | 1 | 3 | 3 | 4 | split panes never stack; AI summary flicker/CLS |
| `analysis` | 3 | 3 | 3 | 1 | 3 | 3 | 4 | same as phenotype-clusters |
| `phenotype-functional` | 4 | 2 | 4 | 2 | 4 | 4 | 4 | raw fc_/pc_ labels, lexicographic order |
| `variant-correlations` | 4 | 4 | 4 | 2 | 4 | 4 | 4 |  |
| `variant-counts` | 4 | 4 | 4 | 2 | 4 | 4 | 4 |  |
| `entries-over-time` | 4 | 4 | 4 | 2 | 4 | 4 | 2 | unnamed selects |
| `publications` | 4 | 4 | 3 | 3 | 4 | 4 | 4 | journal badge clipped |
| `publications-timeplot` | 4 | 4 | 4 | 2 | 4 | 4 | 2 | unnamed selects |
| `publications-stats` | 4 | 3 | 3 | 3 | 4 | 4 | 2 | unnamed select/label; 2026 YTD 0; ISO date |
| `pubtator` | 4 | 2 | 3 | 3 | 4 | 3 | 4 | raw headers, paginate CLS .28 |
| `pubtator-genes` | 3 | 2 | 3 | 3 | 4 | 4 | 2 | raw/clipped headers, contrast, unnamed selects |
| `pubtator-stats` | 3 | 3 | 3 | 3 | 4 | 4 | 2 | filtered counts confusing, cyan 2:1 |
| `gene-networks` | 3 | 3 | 3 | 1 | 3 | 3 | 3 | split panes never stack; 2.5:1 cluster badges |
| `data-releases` | 4 | 2 | 3 | 3 | 4 | 5 | 4 | raw archive timestamps, Version NA |
| `nddscore` | 4 | 3 | 3 | 3 | 4 | 4 | 4 | truncated .. filter placeholders |
| `nddscore-modelcard` | 4 | 2 | 3 | 4 | 5 | 5 | 4 | Version NA, 19296 unformatted, grammar |
| `nddscore-gene` | 4 | 4 | 4 | 3 | 4 | 4 | 3 | dl/ul structure, contrast |
| `panels` | 4 | 2 | 3 | 3 | 4 | 4 | 4 | Loaded 10/5, raw headers, clipped pills |
| `about` | 4 | 4 | 4 | 4 | 5 | 5 | 4 |  |
| `documentation` | 4 | 4 | 4 | 4 | 5 | 5 | 4 |  |
| `mcp` | 4 | 4 | 4 | 4 | 5 | 5 | 4 | shows http://localhost:8091/mcp (instance-derived, ok) |
| `api` | 4 | 4 | 3 | 2 | 3 | 3 | 4 | hero does not stack on phone |
| `login` | 4 | 4 | 4 | 4 | 5 | 5 | 4 |  |
| `register` | 4 | 4 | 4 | 4 | 5 | 5 | 4 |  |
| `password-reset` | 4 | 4 | 4 | 4 | 5 | 5 | 4 |  |
| `entity` | 4 | 3 | 3 | 3 | 3 | 4 | 3 | disease chip overflows hero; ISO dates; CLS .18 @390 |
| `gene-fbxo11` | 3 | 3 | 3 | 3 | 3 | 3 | 4 | orphan centered card; 9.6px labels; CLS |
| `gene-arid1b` | 3 | 3 | 3 | 3 | 3 | 3 | 4 | as fbxo11; slow external cards |
| `ontology` | 4 | 3 | 3 | 3 | 3 | 4 | 3 | CLS .33 @390, ISO date |
| `search` | 3 | 3 | 3 | 3 | 3 | 3 | 4 | redirects to gene page |
| `not-found` | 3 | 4 | 3 | 4 | 4 | 5 | 4 | no way back |
