### `home` — 8/10

_A quiet, trustworthy, table-first landing surface that reads like an operations console rather than a marketing page; only minor heading-order and loading-state polish keep it from a 9._

**Findings:**
- (low/accessibility) heading-order Lighthouse audit (1) despite a clean-looking outline: the route h1 (#home-title 'SysNDD') is followed by panel h2s, but the hero eyebrow paragraph and high font-weight panel titles can read as out-of-order to AT; the audit flags a skipped/duplicated level somewhere in the global chrome (navbar) preceding the h1.
- (low/hierarchy) Hero is the one place the product flirts with marketing decoration: a bordered white hero card with eyebrow + 2rem/800-weight title + summary consumes the top fold before any data.
- (med/interaction_states) Loading/empty states are not designed: stats and news init from INIT_OBJ placeholders and animate counts in via GSAP, but there is no skeleton; a slow stats fetch shows zeroed/placeholder numbers, and a news error only surfaces as a toast.
- (low/color_contrast) Color discipline is strong but the 'Updated 11/12/2025' pill and concept chips lean on the same blue-grey family; the page is close to a near-monochrome blue/grey screen, saved only by the status CategoryIcon/NddIcon colors.

**Improvements:**
- [M·foundation-shared] Add a single global route-level h1 contract (e.g. visually-hidden h1 injected by the layout/TableShell) and audit the navbar/banner heading levels so every page including Home passes heading-order; resolve the chrome-level skip rather than the body. — _Clears heading-order(1) on all five pages at once and gives screen-reader users a consistent top-level landmark._
- [S·per-page] Consume the existing loadingStates.statistics/news flags: render the TableLoadingState skeleton (already used on table pages) inside HomeStatsPanel/HomeNewsPanel while fetching, and add a small inline 'No recent entities' empty state instead of relying on toasts. — _Removes the zeroed-placeholder flash on slow loads and makes failure states visible without a transient toast._
- [S·per-page] Trim the hero toward the clinical-tool intent: drop the title to ~20-22px semibold, demote the eyebrow, and consider merging the hero into the stats panel header so data sits higher in the fold. — _Reinforces the table-first, anti-marketing aesthetic and pushes coverage stats above the fold on laptops._
- [S·foundation-shared] Introduce one warmer accent (teal #00897b) for an action affordance (e.g. the 'Browse all' / action-link chips) to break the near-monochrome blue and signal interactivity without color-only status. — _Improves scanability and the 'never all-blue screens' token rule while keeping the quiet tone._

### `entities` — 7/10

_The reference table surface: dense, chip-driven, fast-feeling and mobile-thoughtful, but a cluster of header/select a11y gaps (no h1, td-has-header, 3 unlabeled selects) holds accessibility down._

**Findings:**
- (high/accessibility) No route-level h1: TableShell renders the page title as <h2 class="table-shell__title">, so the document has no h1 and headings start at h2 (Lighthouse heading-order(1)).
- (high/accessibility) select-name(3): the three filter dropdowns (Inheritance / Category / NDD) render as BFormSelect inside GenericTable's #filter-controls with only a visual placeholder option ('.. Inheritance ..'), no associated <label> or aria-label.
- (med/accessibility) td-has-header(1): the filter row is built as a <tr> of bare <td> cells in the table header region, with no header association, so AT cannot tie filter inputs to their column.
- (med/color_contrast) Status is conveyed by color-coded icons (green check / orange / blue / grey 'no-entry' for Category; orange/green for NDD) with tooltip-only labels; on a quick scan the Category column is icon-only with no inline text, leaning on color+shape alone.
- (low/interaction_states) Mobile rows are well-built (stacked cards with badges) but the desktop 'Details > Show' affordance and per-column filters disappear on mobile with no equivalent, so mobile users lose filtering entirely.

**Improvements:**
- [S·foundation-shared] Give every filter <BFormSelect> in the GenericTable filter row a real associated label: wrap in <label :for> + visually-hidden text or add :aria-label="field.label" (mirror the pattern TablesGenes already uses). — _Clears select-name(3) here and prevents the same defect on any table using GenericTable's filter-controls slot._
- [M·foundation-shared] Make the in-table filter row accessible at the renderer level: render filter cells with role/headers tied to the column (or move filters out of the thead into a labeled filter region) so td-has-header passes for every list table. — _Resolves td-has-header across entities/genes/phenotypes from one change in the shared table renderer._
- [S·foundation-shared] Add a visually-hidden route-level h1 inside TableShell (or promote the title to h1 and demote section heads) so all table pages have a single h1. — _Fixes heading-order on all four table pages with one shared-component edit._
- [S·foundation-shared] Pair the Category/NDD status icons with a short text label or at minimum an always-visible accessible name (aria-label on the icon, not just a hover tooltip) so status is never color/shape-only. — _Satisfies the never-color-alone rule and helps colour-blind users distinguish the orange/green status circles._
- [M·per-page] Expose at least category/inheritance filtering on mobile (e.g. a collapsible filter sheet reusing the same selects) so mobile parity is not lost. — _Restores core scan/filter capability for the large share of mobile clinical users._

### `genes` — 8/10

_A strong gene-aggregation table that smartly stacks per-entity inheritance/category/NDD chips per row and degrades to clean mobile cards; only the missing h1 and filter-row td-has-header keep a11y from excellent._

**Findings:**
- (high/accessibility) No route-level h1: same TableShell h2-as-title pattern, so heading hierarchy starts at h2 (Lighthouse heading-order(1)).
- (med/accessibility) td-has-header(1): the #thead-top filter row is a <tr> of bare <td> per field with no header association.
- (med/dataviz) Category / Inheritance / NDD columns each render a wrapped flex of multiple icon/badge chips per gene (one per child entity); for high-entity genes this can crowd the row and the icon-only Category/NDD remain color+shape only.
- (low/interaction_states) Sorting is enabled only on Symbol (Category/Inheritance/NDD have sortable:false), but all headers render with the same sort-icon-left affordance, so non-sortable columns still show a sort cue.
- (low/hierarchy) The 'Entities count' column uses a grey secondary pill ('1','2') that is visually identical to neutral chrome chips elsewhere, giving it low salience versus its analytical importance.

**Improvements:**
- [S·foundation-shared] Add the shared route-level h1 (via TableShell) so Genes passes heading-order alongside the other table pages. — _One shared edit clears heading-order(1) for Genes and siblings._
- [M·foundation-shared] Fix the filter-row markup in the shared table renderer so filter <td>s are associated with their column header (resolves td-has-header). — _Removes td-has-header across all in-table-filter pages._
- [S·per-page] Suppress the sort-icon affordance on sortable:false columns (conditional sort-icon-left or per-field class) so only Symbol shows the sort cue. — _Removes a false interactive affordance and clarifies what is sortable._
- [M·foundation-shared] Cap or summarize the per-entity chip stacks (e.g. show first N + '+k more') for high-entity genes and pair Category/NDD icons with accessible names. — _Keeps dense rows scannable and makes status non-color-only across all entity-chip tables._

### `phenotypes` — 6/10

_Functionally the richest table (HPO multi-select + AND/OR logic) but the weakest on accessibility: icon-only action buttons with no names, a low-contrast warning button, an unlabeled select, td-has-header and the missing h1 stack up to a88._

**Findings:**
- (high/accessibility) button-name(3): the three action buttons (.xlsx download, copy-link, filter-toggle) are icon-only BButtons with only a hover title attribute and no accessible name (aria-label / visible text).
- (high/color_contrast) color-contrast(1): the filter-state action button switches to variant 'warning' (amber) with an icon glyph on a near-white surface; the amber-on-white icon fails contrast.
- (high/accessibility) select-name(1) + td-has-header(1): the in-header filter row reuses the same bare <td> + unlabeled BFormSelect pattern (only the multi_selectable branch is wrapped in a labeled <label>; the plain selectable BFormSelect at lines 170-185 is unlabeled).
- (med/accessibility) No route-level h1 ('Phenotype search' is the TableShell h2), contributing to heading-order(1).
- (low/interaction_states) The custom AND/OR logic toggle is a pair of <button>s styled as a pill group but has no group label/role and the inactive state (#6c757d on #f8f9fa) is borderline for a control conveying boolean query logic.

**Improvements:**
- [S·foundation-shared] Add aria-label to all icon-only action buttons ('Download as Excel', 'Copy link to this view', 'Remove all filters') across TablesPhenotypes (and ideally a shared action-button component). — _Clears button-name(3) and standardizes accessible names for the table action row used on every table page._
- [S·foundation-shared] Replace the amber 'warning' filter button glyph with a token-compliant treatment (e.g. solid warning background with white icon, or a filled state with sufficient icon contrast) and verify against #f57c00 contrast. — _Resolves color-contrast(1) and aligns the active-filter affordance with the status-color tokens._
- [S·foundation-shared] Label the plain selectable BFormSelect filters (mirror the multi_selectable <label :aria-label> branch already present) to fix select-name(1). — _Removes select-name and makes the filter pattern consistent within the same component._
- [S·per-page] Wrap the AND/OR toggle in a labeled group (role=group + aria-label='Phenotype match logic', aria-pressed on each button) and raise inactive-text contrast. — _Makes the most product-specific control on the page operable and understandable by AT._
- [M·foundation-shared] Adopt the shared route-level h1 and shared filter-row header association (td-has-header) fixes from the table foundation work. — _Clears heading-order and td-has-header here as part of the cross-page table foundation fix._

### `panels` — 7/10

_A genuinely useful panel-builder with labeled selects, a column-visibility control and good mobile cards, but the 9-column wide-ID desktop table is cramped/dense and the page still lacks an h1._

**Findings:**
- (high/accessibility) No route-level h1: 'Panel compilation' is the TableShell h2 (heading-order(1)).
- (med/spacing_density) The desktop table packs 9 columns (Category, Inheritance, Symbol, HGNC ID, Entrez ID, Ensembl gene id, Ucsc id, Bed hg19, Bed hg38) into a fixed-layout table; the long ID/BED columns are text-truncated to fit, producing a dense, hard-to-scan grid where most values are clipped behind tooltips.
- (med/typography) Identifier columns (HGNC ID, Entrez ID, Ensembl, UCSC, BED coords) are rendered in the default proportional system font rather than the mono treatment the design intent reserves for IDs/coordinates.
- (low/hierarchy) The toolbar is control-dense (Category, Inheritance, Sort field + order, Columns toggle, Per page, pagination) and on desktop the controls row competes with the help (?) badge and .xlsx button for the header; the grid can feel busy before any data context.
- (low/interaction_states) Empty/zero-result state for a panel selection that returns no genes is not explicitly designed beyond BTable show-empty default text.

**Improvements:**
- [S·foundation-shared] Apply the mono token to identifier and coordinate columns (HGNC/Entrez/Ensembl/UCSC/BED) so IDs are aligned and scannable per the design intent. — _Improves ID legibility/alignment and aligns Panels with the gene-symbol/ID mono rule used elsewhere._
- [M·per-page] Reduce default desktop column load: ship a leaner default column set (Symbol, Category, Inheritance, HGNC, one coordinate set) and let the existing Columns control opt into BED/UCSC/Ensembl, instead of showing all 9 by default. — _Removes the cramped, mostly-truncated grid and lets users scan the panel before expanding to coordinate detail._
- [S·per-page] Add a custom empty-state slot ('No genes match this category/inheritance — adjust filters') to the panels BTable. — _Gives a clear, on-brand zero-result message instead of generic default text._
- [S·foundation-shared] Adopt the shared route-level h1 from TableShell so Panels passes heading-order. — _Clears heading-order(1) as part of the cross-table foundation fix._
- [S·per-page] Tighten the toolbar visual grouping (separate the data-shaping selects from pagination, and de-emphasize the help badge) to reduce header busyness. — _Improves header hierarchy and reduces cognitive load before the table is read._

### `curationcomparisons` — 7/10

_A genuinely well-built clinical-ops analysis shell with an excellent source-selection toolbar; the UpSet chart itself is monotone and gets clipped below the fold on desktop._

**Findings:**
- (med/dataviz) UpSet plot is overwhelmingly single medium-blue; the per-source set colors only show in the small left bars while the intersection matrix dots are also blue, so the chart reads as one hue and the SysNDD/Core-Overlap highlight lines (thin blue/orange rules) are easy to miss.
- (med/hierarchy) At 1440x900 the dot/matrix rows ('panelapp', 'gene2phenotype', 'SysNDD') and their connector dots are cut off at the viewport fold, so the defining feature of an UpSet plot (which sets each bar belongs to) is below the fold on first paint.
- (low/accessibility) heading-order Lighthouse fail (1): the page <h1> 'Curation comparisons' is followed by the panel <h2> 'Overlap', but the InlineHelpBadge renders as a <button> inside the <h2> and the only other landmark headings come from the shell — the audit flags a non-sequential heading somewhere in the rendered tree.
- (low/content_clarity) Two-line legend text above the plot ('SysNDD (This Database): 3,217  Core Overlap (3 sources): 1,575') is centered and visually detached from the toolbar toggles that control it, so the relationship between the 'Highlight SysNDD'/'Core Overlap' switches and the legend is not immediately obvious.

**Improvements:**
- [M·per-page] Constrain the UpSet render height to the available viewport (account for header+tabs+toolbar) or reduce default bar count so the intersection matrix dots are visible without scrolling on a 900px-tall viewport. — _The core comparative signal (set membership per bar) becomes legible on first paint instead of below the fold._
- [M·per-page] Increase chromatic separation in the plot: give the SysNDD highlight a filled bar treatment (not a thin rule) and the Core-Overlap a distinct fill/pattern, leveraging the existing Okabe-Ito tokens already defined in curationUpsetDisplay.ts. — _Eliminates the all-blue monotony flagged by the design intent and makes the two highlighted quantities scannable._
- [S·foundation-shared] Add a shared AnalysisShell/heading-level helper so analysis panel titles render at a guaranteed sequential level (h2) and help-badge buttons are siblings, not children, of the heading text — fixes the heading-order fail across all three comparison tabs at once. — _Resolves heading-order(1) on all three routes and any other analysis page using the same panel header pattern._
- [S·per-page] Move the dynamic legend ('SysNDD … / Core Overlap …') inline next to its controlling toggles, or render it as small chips matching the toggle color-dots. — _Ties the interactive controls to the values they reveal, improving comprehension for expert scanning._

### `curationcomparisons-similarity` — 5/10

_A bare D3 heatmap with no color legend, no value labels, and a dead half of its declared diverging scale — the weakest surface in the cluster and not yet decodable by an expert user._

**Findings:**
- (high/dataviz) No color legend / colorbar anywhere on the page, so the red-intensity squares cannot be mapped to similarity values without hovering each cell one at a time.
- (high/dataviz) The declared color scale is diverging (#000080 navy -> white -> #B22222 red over domain [-1,0,1]) but cosine similarity over gene-membership vectors is non-negative, so every rendered cell is red — the entire blue (negative) half of the legend and the popover's '-1 for dissimilar' explanation are dead/misleading.
- (med/dataviz) Cells carry no numeric value labels and the only tooltip is an unstyled default white box ('S(c): … (x & y)'), so comparing two near-identical pink cells is guesswork; the diagonal self-similarity (deep red) dominates attention but carries no information.
- (med/spacing_density) Massive horizontal whitespace: the 680px-max SVG sits left-of-center inside a 1480px frame with the panel-header download buttons far to the right, wasting roughly half the width and breaking the dense-but-balanced feel of the rest of the app.
- (low/typography) Axis tick font is hardcoded 16px and labels rotate -45deg, larger than the 12-14px table-header scale used elsewhere, so the chart typography is inconsistent with the design tokens.

**Improvements:**
- [M·per-page] Add a vertical colorbar legend with tick values next to the matrix and render the numeric similarity value inside each cell (or at least on the upper triangle), so values are decodable at a glance without hover. — _Turns an undecodable color wash into an actually readable similarity matrix — the single biggest fix for this page._
- [S·per-page] Match the color scale to the real data range: use a sequential 0->1 scale (e.g. white -> teal/medical-blue token) instead of the diverging -1..1 navy/red, and correct the popover copy so the explanation matches what renders. — _Removes the dead blue half and the misleading '-1 dissimilar' copy; aligns hue with SysNDD blue/teal tokens instead of an off-palette red._
- [S·per-page] Center and widen the SVG within the frame (or cap frame width to the chart) and align the download buttons to the chart, eliminating the large empty side bands. — _Restores the balanced, dense layout the rest of the cluster has and reduces wasted real estate._
- [S·foundation-shared] Replace the raw D3 default tooltip with the app's standard tooltip styling/token (rounded 6px, subtle border, mono for the pair labels) and drop the axis font to 13-14px. — _Brings chart tooltip + typography into the shared token system, consistent with table tooltips elsewhere._

### `curationcomparisons-table` — 7/10

_The strongest surface in the cluster — TableShell + mono gene chips + icon-and-color CategoryIcons — but unlabeled filter selects and unassociated filter-row <td>s drag accessibility down._

**Findings:**
- (high/accessibility) select-name Lighthouse fail (8): every per-column dropdown filter (Sysndd, Panelapp, Sfari, Geisinger dbd, Orphanet id, Omim ndd, etc.) is a BFormSelect whose only label is a placeholder option ('.. Sysndd ..'); there is no programmatic <label>/aria-label, so 8 selects are unnamed for AT.
- (med/accessibility) td-has-header Lighthouse fail (1): the filter-controls row is emitted via #thead-top as bare <td> cells (template lines 136-189) inside the table, so those data cells are not associated with any header, confusing table semantics for screen readers.
- (med/typography) Column header labels are clipped: 'Gene2phenoty|' and the filter input '.. Gene2phenotyp|' are cut mid-word, and 'Radboudumc i⌄' / 'Orphanet id ⌄' collide with their sort/dropdown carets — header truncate(label,20) plus narrow 8-column layout overflows.
- (low/interaction_states) Duplicated sort affordance: each header shows both a left up-arrow (BTable sort-icon-left) and the column label, and some headers additionally show a dropdown caret, producing visual noise and ambiguous click targets in the header row.
- (low/color_contrast) CategoryIcon mono glyphs are good but the 'not listed' open circle (#bdbdbd) and 'not applicable' slash sit at borderline contrast on white, and a grid of identical small circles across many columns reads as low-signal until decoded.

**Improvements:**
- [S·foundation-shared] Add an accessible name to every filter BFormSelect in the table renderer (aria-label bound to the column label, e.g. 'Filter Sysndd'), and add aria-label to the free-text BFormInput filters too. — _Resolves select-name(8) here and on every other GenericTable-based list page that reuses the same filter-controls slot pattern._
- [M·foundation-shared] In GenericTable's #thead-top filter row, give each filter cell role/scope or render it as <th scope=col> wrapping the input (or add headers/aria), so td-has-header passes without changing layout. — _Fixes td-has-header across all tables using the shared filter row and improves screen-reader table navigation app-wide._
- [M·per-page] Widen header truncation budget or wrap/abbreviate consistently and reserve space for the sort caret so 'Gene2phenotype', 'Radboudumc ID', 'Orphanet id' are not clipped or overlapped; consider a single sort affordance instead of left-icon + caret. — _Removes mid-word clipping and ambiguous header click targets, improving scannability of the 9-column comparison grid._
- [S·per-page] Add a compact category legend (icon + label) once above the table so the CategoryIcon glyph vocabulary (Definitive check, Moderate dash, Limited !, Refuted x, not listed open circle) is decodable without per-cell hover. — _Lets expert users read the icon grid directly instead of hovering, raising the signal of the dense comparison matrix._
- [S·foundation-shared] Bump the 'not listed' / 'not applicable' glyph contrast (darker gray token, e.g. #9aa3ad outline) so absent-in-source cells are distinguishable from empty without failing low-contrast. — _Improves legibility of the most common cell state while keeping the color-blind-safe icon-plus-color encoding._

### `phenotypecorrelations` — 6/10

_Clean shared shell and a genuinely well-handled loading/error/retry path, but the heatmap floats in the right two-thirds of the frame with tiny axis labels and color-only encoding, so the data reads as decorative rather than scannable._

**Findings:**
- (high/spacing_density) Heatmap is locked to a fixed 700x700 viewBox at max-width 800px, inline-block, so on the 1440px frame it sits in the right portion of the card leaving a large empty left margin; the displayed matrix is small relative to the available canvas.
- (med/dataviz) Correlation strength is conveyed by red/blue cell fill only; the numeric R value is exposed solely on hover, so a non-hovering or keyboard/AT user gets color-alone status encoding.
- (med/typography) Y-axis phenotype labels (e.g. 'Abnormality of nervous system morphology') are rendered at small d3 default axis size and crowd the long left margin, hurting legibility for an expert-scan task.
- (low/accessibility) Lighthouse heading-order(1): a heading level is skipped on the route. The page nests AnalysisShell h1 then AnalysisPanel h2, so the violation is likely a global chrome/skipped-level pattern shared app-wide.
- (med/interaction_states) Clickable cells carry role=button + aria-label but are SVG <rect> elements with no keyboard focusability or tabindex, so the click-to-filter affordance is mouse-only.

**Improvements:**
- [M·foundation-shared] Make the correlogram responsive: drive width/height and band size from the container width (or render in a centered max-width block) so the matrix fills the card and the empty left whitespace collapses. — _Removes the dominant 'floating chart' defect shared by all three correlation pages; larger cells and labels improve scan/compare for experts._
- [M·per-page] Expose the R value without hover: print the coefficient inside cells above an abs(R) threshold, or add a small sampled value overlay, so correlation strength is not color-only. — _Satisfies the never-color-alone rule and makes the matrix usable without a pointer device._
- [M·foundation-shared] Make heatmap cells keyboard-accessible: add tabindex=0, a keydown(Enter/Space) handler mirroring the click navigation, and a visible focus outline. — _Closes a real a11y gap on the primary interaction and applies to both correlograms which share the pattern._
- [S·foundation-shared] Audit and fix the app-wide heading-order(1) (likely a skipped level in global chrome or a chart caption), then verify all analysis routes report a clean heading tree. — _Clears the heading-order audit across all three correlation pages at once._
- [S·per-page] Increase axis label font-size and set a consistent tick text style in the d3 axes so long phenotype names stay legible at the rendered size. — _Improves legibility of the most label-dense axis without restructuring the chart._

### `phenotypefunctionalcorrelation` — 5/10

_The shell, tabs, and help affordance are consistent, but the heatmap is stranded in the right third of a 1480px card with an off-system large centered chart title and no visible legend, making this the weakest of the three correlation surfaces._

**Findings:**
- (high/spacing_density) The Pheno-Func heatmap occupies only the right ~third of the panel; roughly half the card width is empty, the single worst space-utilization case in the cluster.
- (med/typography) The chart title 'Pheno-Func Cluster Correlation' is a large, centered, bold SVG/Plotly text in a heavier/serif-leaning style that conflicts with the quiet system-sans panel h2 directly above it ('Phenotype & functional clusters correlation'), duplicating the title in two visual languages.
- (high/dataviz) No visible color legend on this matrix, so the red/blue intensity (and the fc/pc quadrant separators) carries meaning with no scale reference and no in-cell values.
- (med/content_clarity) Axis tick labels (fc_1..fc_8, pc_4..pc_5) are terse cluster codes with no expansion of what each cluster is, so an expert cannot interpret a quadrant without external context.
- (low/accessibility) Lighthouse heading-order(1): same skipped-heading-level pattern as the sibling correlation routes.

**Improvements:**
- [M·per-page] Constrain or left-align the heatmap to the panel content width (or center it in a tighter max-width column) so the large empty right/left band collapses and the matrix reads as the focus. — _Fixes the worst space-utilization case in the cluster and makes the matrix the visual subject of the card._
- [S·per-page] Remove the redundant in-chart title and instead style any needed caption to match the system type, letting the panel h2 own the heading; if the chart title must stay, downsize it to the body scale and use system-sans. — _Eliminates the duplicate, off-system heading and restores the quiet clinical-tool typography._
- [S·foundation-shared] Add the shared ColorLegend (as used by the phenotype correlogram) plus hover/in-cell R values so this matrix has a scale reference and is not color-only. — _Brings the matrix to parity with the sibling correlogram and satisfies the never-color-alone rule._
- [M·per-page] Add a brief cluster legend or tooltip expanding fc_/pc_ codes (membership size or representative term) so experts can interpret quadrants without leaving the page. — _Improves interpretability of the central artifact for the target expert audience._
- [S·foundation-shared] Resolve the shared heading-order(1) issue at the chrome/shell level and re-verify this route. — _Clears the a11y audit alongside the other correlation pages._

### `variantcorrelations` — 5/10

_A dense, information-rich consequence-class matrix that is undermined by truncated x-axis labels, a missing legend, and a regressed interaction model with no loading-error or empty state._

**Findings:**
- (high/typography) X-axis labels are clipped to fragments ('riation', 'caton', 'letion', 'I DNA') because the rotated tick text overflows the fixed bottom margin, so the columns are largely unreadable while the y-axis spells the same terms in full.
- (high/dataviz) No visible color legend on the variant matrix; the red/blue Pearson scale has no on-page reference and per-cell R values appear only on hover, so magnitude is color-only.
- (med/interaction_states) This component has no error or empty state: on a failed fetch it only fires a toast inside catch, sets loadingMatrix=false, and leaves a blank matrix area with no message or retry, a regression vs the phenotype correlogram's full error+retry block.
- (med/content_clarity) Cells are wrapped in real <a xlink:href> anchors (good for navigation) but raw R values are shown unrounded in the tooltip (e.g. long floats) and there is no diverging-strength label, reducing scan precision for an expert comparing many consequence classes.
- (low/accessibility) Lighthouse heading-order(1): same shared skipped-level heading pattern.

**Improvements:**
- [M·per-page] Fix the truncated x-axis: enlarge the bottom margin / chart height and use full rotated labels (or angled 45deg with tooltips), so column consequence classes are as legible as the rows. — _Restores readability of half the matrix axes, the single most damaging defect on this page._
- [S·foundation-shared] Add the shared ColorLegend and round the tooltip R to a fixed precision (toFixed(3)) with a strength interpretation, matching the phenotype correlogram. — _Gives the matrix a scale reference, removes color-only encoding, and unifies tooltip formatting across both correlograms._
- [S·foundation-shared] Add the same error + retry and empty states used by AnalysesPhenotypeCorrelogram so a failed or empty variant fetch shows an actionable message, not a silent blank. — _Closes the interaction-state regression and makes the two correlograms behave identically on failure._
- [M·foundation-shared] Make the matrix container responsive to use the full card width instead of the fixed 800px inline-block block, reducing the empty side margin. — _Shared with the other correlation matrices; larger cells improve dense-matrix comparison._
- [S·foundation-shared] Resolve the app-wide heading-order(1) at the shell/chrome level and re-verify this route. — _Clears the a11y audit across all three correlation pages._

### `entriesovertime` — 6/10

_Clean single-purpose timeline in the shared AnalysisShell, but the D3 chart uses an off-token pastel palette, leaks dead space on the left, and ships unlabeled aggregation/grouping selects._

**Findings:**
- (high/dataviz) Chart legend/series use d3.schemeSet2 pastels (mint, peach, lilac, pink, olive) instead of SysNDD status tokens; 'Definitive/Limited/Moderate/Refuted' are exactly the category vocabulary that has canonical colors elsewhere, so the timeline visually contradicts every other status surface.
- (high/accessibility) The two control selects (Aggregation, Grouping) have input-id set but no associated <label> element, only a BInputGroup prepend; Lighthouse flags select-name(2). Screen-reader users hear an unnamed combobox.
- (med/accessibility) Heading order skips a level: AnalysisShell renders the route <h1> ('NDD entities and genes over time') and AnalysisPanel renders the card title ('Curated Counts Timeline') at a non-sequential level, tripping heading-order(1).
- (med/spacing_density) Large dead band of whitespace to the left of the plot at 1440px; the 600x400 fixed viewBox sits in an inline-block svg-container capped at max-width:800px and floats left, leaving ~40% of the panel empty and weakening the data-first impression.
- (med/interaction_states) Legend doubles as the only filter affordance (click to toggle a series) with no visible cue, no focus state, and no keyboard path; it is plain SVG <text> with cursor:pointer.

**Improvements:**
- [M·foundation-shared] Map the D3 ordinal color scale to the SysNDD status tokens (Definitive teal/green, Limited warning #f57c00, Moderate info #0277bd, Refuted danger #c62828) via a shared category->color util rather than d3.schemeSet2, reusing the same map used by category badges elsewhere. — _Timeline color matches every other status surface, removing a jarring palette contradiction and improving recognizability/contrast._
- [S·foundation-shared] Add a real associated <label> (visually-hidden if needed) for each analysis BFormSelect, or wire aria-label, so select-name passes here and on every analysis page that reuses BInputGroup+BFormSelect. — _Clears select-name failures across EntriesOverTime and GeneNetworks; named comboboxes for SR users._
- [S·foundation-shared] Demote the AnalysisPanel card title to the correct sequential heading level (h2 under the shell h1) in the shared AnalysisPanel component. — _Fixes heading-order(1) on all four analysis pages at once with one component change._
- [M·per-page] Make the chart responsive-width (drop the 800px cap, use the container width as the viewBox basis or center the fixed plot) so it fills the panel and removes the left dead space. — _Larger, centered, more legible chart; stronger data-first feel matching the table pages._
- [M·per-page] Give the legend a real interactive treatment: render as keyboard-focusable toggle chips with a visible 'click to hide series' hint and aria-pressed state, or move filtering into a labeled control. — _Discoverable, accessible series filtering instead of an invisible click target._

### `publicationsndd` — 7/10

_The reference-quality analysis page: tabbed shell, per-column filter row, mono PMID chips and meaningful empty/expansion states; held back only by the pale-blue chip contrast and an unlabeled filter <td> row._

**Findings:**
- (high/color_contrast) PMID chip uses #0d6efd text on a #e7f1ff fill (~2.9:1) and the keyword tags repeat the same pale-blue-on-pale-blue; contributes to color-contrast(10). These are the load-bearing identifiers, so the failing contrast hits the most-scanned tokens.
- (med/accessibility) The per-column filter inputs are rendered as a row of <td> in the table body with no associated header cells, tripping td-has-header(1); the filter row has no scope/headers wiring so it reads as orphan data cells.
- (med/accessibility) Heading order skips a level (shell h1 -> AnalysisPanel card title) and the expansion-row detail labels are h6, so the heading tree jumps h1->h6, flagged as heading-order(1).
- (low/consistency) Three competing badge styles in one table (blue PMID pill, gray bordered journal pill, green date pill) plus pale-blue keyword pills in the expansion — visually busy for a clinical tool, and the green date badge is a one-off success-token reuse for neutral metadata.
- (low/content_clarity) Column-filter placeholders ('.. PMID ..', '.. Title ..') are a non-standard idiom and read oddly to first-time users; functional but unclear they are filters vs. examples.

**Improvements:**
- [M·foundation-shared] Introduce a shared chip/badge contrast token set (e.g. darken chip text to #0a58ca or shift fill to a darker tint) so the ID/keyword pills clear 4.5:1, and apply it to the shared chip components used by Publications, Pubtator and the table pages. — _Resolves the bulk of color-contrast failures across Publications (10) and Pubtator (29) in one token pass._
- [M·foundation-shared] In the GenericTable filter-row renderer, associate the filter <td> cells with their column headers (headers attribute or move filters into a <thead> row with scope), fixing td-has-header everywhere the renderer is used. — _Clears td-has-header on Publications, Pubtator and GeneNetworks tables together._
- [S·foundation-shared] Fix the heading cascade in AnalysisPanel (h2) and demote expansion detail labels from h6 to a styled non-heading or h3, so the heading order is sequential. — _Fixes heading-order(1) across all analysis pages._
- [S·per-page] Standardize date as neutral metadata (drop the green success-token date pill for plain mono text or a neutral chip) so color is reserved for status, per the design rule that status colors should not decorate neutral fields. — _Quieter, more clinical table; keeps green meaningful for actual status._
- [S·foundation-shared] Replace the '.. Label ..' filter placeholders with a clearer 'Filter Title' / 'Filter PMID' convention shared with other filterable tables. — _Clearer filter affordance across all GenericTable surfaces._

### `pubtatorndd` — 5/10

_Information-rich PubTator table with a thoughtful color-coded annotation legend, but color-contrast(29) is a real and severe defect: nearly every gene chip and entity-highlight span fails, and a 9-column layout is crammed at 1440px._

**Findings:**
- (high/color_contrast) Color-contrast(29) is genuinely severe and traceable to the PubTator entity palette: gene #0d6efd on #b4e3f9 (~2.6:1), disease #e65100 on #ffe0b2, variant #c2185b on #f8bbd9, chemical #7b1fa2 on #e1bee7 and match #f57f17 on #fff59d all fail 4.5:1, and these colors appear in every annotated cell, the expansion text, the legend, and the gene chips.
- (med/interaction_states) The search_id is a solid primary BBadge with cursor:pointer but no click handler/href — a misleading interactive affordance that does nothing.
- (med/spacing_density) Nine visible columns (Search ID, PMID, DOI, Title, Journal, Date, Score, Genes, Text HL, Details) are packed into 1440px; Title/DOI/Text HL all truncate hard and the table feels over-dense versus the calmer Publications table.
- (med/consistency) Identifier typography is inconsistent: PMID is an outline-primary <button> (interactive styling for a link), DOI is a bare underlined link, search_id is a solid pill, Score is plain text — four different identifier treatments in one row, and PMIDs/DOIs are not in mono despite being IDs.
- (low/accessibility) Heading order skips a level (shell h1 -> AnalysisPanel title) flagged as heading-order(1); same shared-component cause as the other pages.

**Improvements:**
- [M·foundation-shared] Re-tune the shared PubTator entity palette to keep the recognizable hue families but darken text or deepen the fill so each entity type clears 4.5:1 (e.g. gene text to #084298, disease text to #8a3a00), applied to chips, legend and annotation spans from one token source. — _Eliminates the 29 contrast failures (the single largest a11y defect in the cluster) while preserving the entity color coding._
- [S·per-page] Either make search_id a real link/action or remove cursor:pointer and the solid-primary styling so it reads as a static identifier (prefer mono text or a neutral chip). — _Removes a false affordance; aligns identifier styling with the rest of the table._
- [M·per-page] Reduce default visible columns (collapse DOI into the PMID/Details area, or hide Search ID/DOI behind the expansion) so the primary scan columns (PMID, Title, Date, Score, Genes) breathe at 1440px. — _Less truncation, calmer table closer to the Publications reference density._
- [S·foundation-shared] Apply the shared mono token to PMID/DOI/gene-symbol identifier cells and unify their styling (link vs chip) with the Publications page treatment. — _Consistent, scannable ID typography across both publication tables._
- [S·foundation-shared] Fix the shared AnalysisPanel heading level and route the filter row through the td-has-header fix to clear heading-order and any td-has-header on this table too. — _Clears heading-order(1) and aligns with the other tables' a11y fixes._

### `genenetworks` — 4/10

_The most ambitious and the weakest page: a powerful split-pane network+table, but a 17 perf score, 6 unlabeled icon buttons, heavy dark-bordered category badges, nested cards, an all-blue chip stack and an FDR column rendering '0' everywhere undermine both usability and trust._

**Findings:**
- (high/accessibility) Six network-toolbar controls (fit, refit, zoom-in, zoom-out, save-PNG, save-image) are icon-only with no accessible name, flagged as button-name(6); combined with select-name(3) the network controls are largely unusable by keyboard/SR users.
- (high/responsiveness) Performance is a genuine outlier, not a dev-build artifact: perf 17, TBT 2119ms, CLS 0.277, LCP 4087ms. preloadNetworkData() plus synchronous Cytoscape/D3 rendering of ~2258 nodes / 10000 interactions blocks the main thread and causes large layout shift as panes/network mount.
- (high/consistency) Category badges use border-width:medium dark borders on a light fill (GO/KEGG/MONDO/HPO/Process), directly violating the 'no heavy dark card borders' / quiet-chip rule and reading as heavy boxed labels rather than pills; some labels ('Networkneighboral') are also mislabeled.
- (med/hierarchy) Nested card stacking: AnalysisShell frame -> AnalysisPanel -> network panel + a cluster-summary cue card + a separate light-border BCard wrapping the table, producing card-in-card-in-card, which the design rules call out to avoid except for true disclosure/repeated records.
- (med/dataviz) The FDR column renders '0' for every visible row instead of scientific notation, and the network header stacks an all-blue chip cluster ('1359/2258 genes', '4097/10000 interactions', 'Definitive only', 'Clusters: All') creating a one-hue blue header that hides the actual numbers' meaning.
- (low/color_contrast) The 'All Clusters' indicator badge uses variant secondary (gray) and the orange cluster-number badges plus warning-yellow FDR badges introduce several saturated one-off colors that compete with the network's own cluster color legend.

**Improvements:**
- [M·foundation-shared] Add aria-label/title to every network icon button (fit, zoom, save) and a proper label to the three network selects; ideally expose them through a shared icon-button component that requires an accessible name. — _Clears button-name(6) and select-name(3); makes the network toolbar keyboard/SR usable — the biggest a11y win on the page._
- [L·per-page] Render the network from precomputed Cytoscape/fCoSE positions with preset layout and defer/virtualize heavy work off the main thread, and reserve fixed dimensions for the panes/network so CLS drops; gate full-resolution rendering until interaction. — _Targets the perf17/TBT2119/CLS0.277 outlier; faster first paint and stable layout._
- [S·foundation-shared] Replace the medium dark-bordered category badges with the standard quiet pill chips (subtle border or tinted fill) and reuse a single category-style token map; fix the 'Networkneighboral' label string. — _Removes the heavy-border token violation here and anywhere the category badge pattern is reused; quieter, on-brand chips._
- [M·per-page] Flatten the nesting: drop the inner light-border BCard around the table and let AnalysisPanel be the single container, so the page is shell -> panel -> content rather than three concentric cards. — _Cleaner hierarchy, less border noise, better fitness for a dense operations tool._
- [S·per-page] Format FDR with scientific notation / significant figures (e.g. 2.3e-7) instead of a rounded '0', and consider showing a single summary line for the genes/interactions counts instead of an all-blue chip stack. — _Restores meaning to the key statistic; quieter, less mono-hue header improves trust._
- [S·foundation-shared] Fix the shared AnalysisPanel heading level so heading-order(1) clears on this page along with the others. — _Sequential heading tree across all four analysis pages from one shared-component change._

### `nddscore` — 6/10

_A dense, table-first prediction surface with strong mobile reflow and good chip/mono discipline, but it stacks a decorative orange gradient disclosure card (duplicated across both tabs) ahead of the data and ships real a11y debt in its filter controls (5 unlabeled selects, td-has-header, mismatched labels)._

**Findings:**
- (med/consistency) Orange ML-disclosure card uses an expressive top-to-bottom gradient (#fff0db -> #fff) with a 5px orange accent border and sits as a decorative explanatory block ABOVE the data table, the exact 'decorative explanation before the data / expressive gradient' pattern the clinical-tool design intent warns against.
- (med/content_clarity) The prediction disclosure card is mounted in NDDScore.vue OUTSIDE the RouterView, so it renders on BOTH tabs and repeats Test AUC-ROC 0.888 + Brier Skill Score 0.444 that the Model card tab then shows again in its own metric grid (visible duplication on the modelcard route).
- (high/accessibility) Five column-filter <BFormSelect> controls (risk_tier, confidence_tier, known_sysndd_gene, model_split, top_inheritance_mode) have no aria-label, matching Lighthouse select-name(5); the range-operator selects are labeled but the filterType==='select' branch is not.
- (med/accessibility) Filter-control row renders bare <td> cells with no header association (td-has-header(1)), and column-header tooltips set a title that differs from visible label text, producing label-content-name-mismatch(4).
- (low/hierarchy) Heading order is broken (heading-order(1)): the route h1 'NDDScore' is followed by the TableShell title and the orange card's disclosure rendered as <span> (ndd-score-card__disclosure) rather than a heading, so the next real heading level is skipped.
- (low/color_contrast) Risk tier and confidence tier badges read as color-coded pills but the screenshot shows several near-identical green/red 'Low' chips with low label distinctiveness, and contrast on the secondary text/orange label is flagged color-contrast(3).

**Improvements:**
- [S·foundation-shared] Add :aria-label=`${field.label} filter` to the filterType==='select' BFormSelect branch (and confirm the per-page-size control is labeled), fixing select-name(5) in one place; ideally fold a labeled <select> wrapper into the GenericTable filter renderer so every column-filter table reuses it. — _Clears all 5 select-name failures and prevents recurrence across other filterable tables; lifts accessibility from 5 toward 7._
- [M·foundation-shared] In the GenericTable filter-controls row, give each filter <td> a header association (scope/headers or render the filter row inside the header as <th>-keyed cells) to resolve td-has-header for every table that uses this renderer. — _Resolves td-has-header(1) here and on all GenericTable pages; improves screen-reader column navigation._
- [S·foundation-shared] Stop the column-header tooltip from overriding the accessible name: keep visible {{ data.label }} as the accessible text and expose help via aria-describedby or a separate info affordance, eliminating label-content-name-mismatch(4). — _Removes 4 a11y violations and the same mismatch wherever column-help tooltips are used._
- [S·per-page] Replace the orange gradient + 5px accent on the disclosure card with a flat tinted token surface (single warning-tinted background, --border-subtle border, small icon+label), aligning it with the quiet clinical card language and the 'no gradients/heavy borders' rule. — _Removes the marketing-decoration look, reduces visual weight before the table, raises consistency and hierarchy fit-for-purpose._
- [S·per-page] Move NddScorePredictionCard inside the gene-predictions tab (or collapse it to a single compact disclaimer banner shared by both tabs) so AUC-ROC/BSS are not duplicated on the Model card route. — _Eliminates metric duplication on the modelcard route and shortens the path to the table; improves content clarity._
- [M·per-page] Tighten risk/confidence chip semantics: ensure each tier maps to a distinct token+label and pair color with an unambiguous text token (not two same-color 'Low' chips), and verify chip text contrast against the badge background. — _Improves scannability of the two most decision-relevant columns and addresses color-contrast(3)._

### `nddscore-modelcard` — 7/10

_A clean, well-structured metric/provenance model card with strong mono-numeric typography and a quiet tile grid that fits the clinical-tool intent, undercut by widespread 12px low-contrast labels (color-contrast(8)) and the same duplicated orange disclosure card stacked above it._

**Findings:**
- (high/color_contrast) Pervasive low-contrast labels: 12px #757575 metric/count/provenance labels on light #f8fafc tiles drive the heavy color-contrast(8) failure; small bold grey on near-white is the dominant text style across the card.
- (med/content_clarity) The orange gradient ML-disclosure card (from NDDScore.vue, outside RouterView) renders above the model card and repeats AUC-ROC 0.888 + Brier Skill Score 0.444 that the model card grid shows again, so the route opens with redundant metrics before the canonical model card.
- (low/hierarchy) Heading order is flagged (heading-order(1)): the route h1 'NDDScore' is followed by the orange card's non-heading <span> disclosure and then the model card's <h2>, leaving the intermediate disclosure block without a proper heading level.
- (low/consistency) Two visually similar but stylistically inconsistent metric tile systems share the screen: the orange card's bordered white metric boxes vs the model card's grey-fill #f8fafc tiles, plus an info-cyan release badge against the orange-tinted disclosure, creating mixed surface treatments for the same data class.
- (low/interaction_states) Loading and empty handling is minimal: the model card has only an error fallback string and no skeleton/loading state, so the metric grid pops in after fetchCurrentRelease resolves (a likely contributor to layout shift on slower fetches).

**Improvements:**
- [S·foundation-shared] Promote label text from #757575 to a token that meets 4.5:1 on the #f8fafc tile (e.g. --neutral-700/800) for metric, count, and provenance dt labels, or darken the tile background; this is the single fix that clears most of color-contrast(8). — _Resolves the bulk of 8 contrast failures and improves legibility of every label-led tile pattern reused elsewhere._
- [M·foundation-shared] Reuse the labelled-tile pattern from a shared component/token so metric and count tiles share one contrast-checked label/value style instead of local #757575 declarations. — _Single contrast-safe tile style across analysis pages; removes one-off grey label values._
- [S·per-page] Render the orange disclosure as a single compact shared banner (or move it inside the gene tab) so the Model card route is not preceded by duplicated AUC-ROC/BSS metrics. — _Removes metric duplication and lets the canonical model card lead the route; cleaner hierarchy and content clarity._
- [S·per-page] Add a lightweight loading skeleton (reserve grid height) for the metric/count tiles while fetchCurrentRelease resolves, so values do not pop in and shift surrounding layout. — _Reduces layout shift and gives a clear loading affordance; raises interaction_states._
- [S·foundation-shared] Make the disclosure-block label a real heading (or restructure so the next heading after h1 is the model card h2 with no skipped intermediate non-heading block) to clear heading-order(1). — _Fixes heading-order on both NDDScore routes that share the shell and disclosure card._
- [S·per-page] Unify the two metric-tile treatments (orange card white boxes vs grey #f8fafc tiles) onto one card surface language and avoid the cyan info badge on the orange-tinted header for visual coherence. — _Consistent surface treatment for the same ML-metric data class; quieter, more trustworthy clinical look._

### `about` — 7/10

_Clean, quiet, on-token shared-shell help page that reads like a trustworthy ops surface; let down only by a deep heading jump, an 8.7s dev LCP, and a few decorative inner cards._

**Findings:**
- (med/accessibility) Heading order skips levels: route h1 (public-title) is followed by an in-body <h6> 'Affiliations' (AboutView.vue:83) with no intervening h2-h5, which is the source of the Lighthouse heading-order(1) failure. Accordion item titles are <span class="fw-semibold">, not real headings, so screen-reader users get no structural map of the seven sections.
- (med/interaction_states) LCP 8.7s is the worst in the cluster. Even discounting the Vite dev baseline, this is a genuine outlier (the AppVersionInfo /api/version fetch plus accordion content), not just a dev-build artifact like the ~62 perf score.
- (low/consistency) Decorative inner cards inside accordion bodies dilute the 'quiet ops tool' intent: Contact uses a centered bg-light card with an fs-1 envelope icon and fs-5 colored email (AboutView.vue:320-327); Citation Policy uses a 4px primary left-border card (border-start border-primary border-4, :114). These are exactly the kind of expressive/marketing decoration the design intent says to avoid.
- (low/consistency) Hardcoded one-off colors and a custom timeline rule bypass the token system: timeline border #dee2e6 and CMS markdown code background #f4f4f4 are literal hex values instead of --border-subtle / a neutral token.
- (low/color_contrast) Status colors carry meaning by hue alone in places: News badges use variant primary vs secondary purely to distinguish 'native update' from lesser updates with no label, and funding uses bi-check-circle-fill text-success vs bi-check-circle text-secondary to encode current vs previous funding — the distinction is color/fill-weight only.

**Improvements:**
- [S·foundation-shared] Render accordion section titles as real headings (h2) and demote the in-body 'Affiliations' from h6 to h3 so the document outline is h1 > h2 > h3 with no skipped levels. This is the same accordion-title pattern used on Documentation, so fix it once in a shared accordion-title slot/component. — _Clears the heading-order Lighthouse failure on About AND Documentation, and gives screen-reader users a navigable section map across all help pages._
- [M·per-page] Lazy-defer or parallelize the AppVersionInfo /api/version call and ensure the hero/title text is the LCP element with no layout-shifting late content, to pull the 8.7s LCP toward the rest of the cluster. — _Removes the one genuine performance outlier on this page; faster perceived load of a frequently-linked institutional page._
- [S·per-page] Replace the decorative Contact and Citation inner cards with the quiet body styling used elsewhere (plain paragraph + monospace/link email, a simple bordered note rather than fs-1 icon + colored 4px border), and swap literal #dee2e6 / #f4f4f4 for --border-subtle and a neutral surface token. — _Brings the page in line with the 'compact, quiet, no marketing decoration' intent and removes one-off color drift._
- [S·per-page] Pair the color-coded News badges and funding check icons with a text label or aria-label (e.g. 'Major release' / 'Update', 'Current funding' / 'Previous funding') so the distinction is not hue/fill-weight alone. — _Meets the never-color-alone-for-status rule; clarifies the timeline and funding sections for colorblind and AT users._

### `documentation` — 7/10

_Well-structured FAQ with a strong action-card row and a single h1, but rainbow bg-opacity inner cards and an oversized entity 'badge of badges' lean decorative and undercut the quiet clinical tone._

**Findings:**
- (med/consistency) Rainbow decorative cards inside the FAQ: 'What makes SysNDD different' renders four big bg-success/bg-info/bg-warning/bg-danger bg-opacity-10 tiles with fs-2 colored icons (Genes/Diseases/Inheritance/Phenotypes), and the entity concept card is a large bg-primary-10 card wrapping a giant primary badge that itself contains three pill badges (badge-inside-badge inside a heading). This is expressive marketing-style decoration the design intent explicitly says to avoid, and it nests cards/badges in a non-data-record context.
- (med/accessibility) Heading-order(1): the route h1 is followed by an in-body <h4> inside the entity concept card (DocumentationView.vue:117) with no h2/h3 between, and accordion question titles are <span class="fw-semibold"> rather than headings, so the FAQ has no real heading outline.
- (low/interaction_states) Loading state is a no-op: data() hardcodes loading:false and there is no async fetch, so the v-if BSpinner branch (DocumentationView.vue:3) is dead code. Fine functionally (content is static) but inconsistent with About/API which model real loading/error, and it signals an unfinished state pattern.
- (low/spacing_density) Density skews loose for a reference doc: large py-4 hero-ish cards, fs-5 link cards (:246, :279), and generous accordion padding make the FAQ feel more landing-page than the compact table-first reference surfaces. A scanning expert sees a lot of vertical whitespace per answer.
- (low/consistency) Custom .bg-opacity-10 override (DocumentationView.vue:328-330) redefines a Bootstrap utility locally, a fragile one-off that can drift from the framework value and is only needed because of the decorative color tiles.

**Improvements:**
- [M·per-page] Replace the four rainbow bg-opacity tiles and the badge-in-badge entity card with a quiet definition layout: a single bordered panel listing Genes / Diseases / Inheritance / Phenotypes with monochrome icons, and an inline 'Gene + Inheritance + Disease' chip row at normal type size rather than a giant heading badge. — _Aligns the FAQ with the compact, non-marketing clinical tone, removes nested-card/nested-badge anti-patterns, and lets the .bg-opacity-10 override be deleted._
- [S·foundation-shared] Promote accordion question titles to real h2 headings and demote the in-card h4 to h3 via the shared accordion-title slot so the FAQ exposes a proper outline and the heading-order audit passes. — _Fixes heading-order on Documentation and About at once and makes the FAQ keyboard/screen-reader navigable section-by-section._
- [S·per-page] Tighten vertical rhythm: drop oversized py-4 / fs-5 on the link cards and entity card to the standard body scale, so each answer reads as a dense reference entry rather than a marketing block. — _More answers visible per viewport; matches the table-first 'scan and act' density target._
- [S·per-page] Remove the dead loading branch or wire it to a real (even trivial) ready flag, and document that this page is static, so the interaction-state pattern matches the rest of the cluster. — _Removes misleading dead UI state and keeps the loading/empty/error contract consistent across help pages._

### `mcp` — 8/10

_The strongest page in this cluster: disciplined two-column technical reference with clean h1>h2 outline, monospace code/URL, real <dl>/<pre> semantics, and zero decoration — exactly the quiet ops-tool tone the product wants._

**Findings:**
- (low/interaction_states) Configured MCP URL renders as a literal dev value 'http://localhost:5173/mcp' (resolveMcpUrl uses window.location.origin). In the captured dev build this leaks a localhost endpoint into the primary 'How to connect' instruction and the JSON config example; on a real deployment it resolves correctly, but there is no copy-to-clipboard affordance for either the URL or the code block, which a config-paste workflow needs.
- (low/accessibility) Heading-order(1) despite a clean local h1>h2 structure — the page uses one h1 (public-title) then all section h2s with no skips (McpInfoView.vue:7, :27,40,53,69,79), so the Lighthouse flag is almost certainly a global chrome issue (AppHeader/footer landmark heading) rather than this page's own content, but it still counts against the route.
- (low/consistency) Hardcoded hex palette throughout the scoped styles (#102033, #344054, #667085, #d9e1ec, #f6f8fb, #b7d4ee) instead of design tokens. The values are visually correct and close to the system, but they are one-off literals that duplicate the shared _public-pages.scss border (#d9e1ec) and can drift from --border-subtle #d9e0ea.
- (low/consistency) The page re-implements its own .mcp-section card grid and .mcp-code/.mcp-definition-list styling instead of reusing the shared public-action-card / panel primitives, so a future token change to the shared shell will not propagate here.

**Improvements:**
- [S·per-page] Add a small copy-to-clipboard icon-button (with aria-label) on the Configured MCP URL and the JSON config <pre>, and label the URL as environment-resolved so dev captures don't read as a shipped localhost endpoint. — _Removes friction in the core 'paste this config into your MCP client' task and avoids a localhost value looking like the production endpoint._
- [S·foundation-shared] Audit the shared AppHeader/footer for the heading-order source (e.g. a footer h-level that skips) since this page's own outline is clean; fixing it at the chrome level clears heading-order across the whole cluster. — _Likely resolves the heading-order(1) flag on all four help/static pages simultaneously rather than page-by-page._
- [M·foundation-shared] Swap the literal hex values for the existing design tokens (--border-subtle, neutral text/secondary tokens) and, where practical, build the section cards on the shared .public-panel primitive so shell token updates propagate. — _Stops palette drift, shrinks the bespoke CSS, and keeps the strongest page locked to the token system._
- [S·foundation-shared] Keep the page as the reference template for the other help surfaces: its h1>h2 discipline, monospace code/URL, <dl> and <pre> semantics, and decoration-free density are the model About/Documentation should converge toward. — _Codifies a quiet technical-reference pattern other help pages can reuse, raising cluster consistency._

### `api` — 5/10

_A bare third-party Swagger UI bolted onto the app with none of the SysNDD shell, tokens, or chrome — functional as an API explorer but the clear consistency and accessibility outlier of the cluster._

**Findings:**
- (high/consistency) No SysNDD shell or design-token alignment at all: ApiView is a raw SwaggerUIBundle mount (#swagger-ui) with no public-hero, no public-kicker, no route-level h1 wrapper, and Swagger's own typography/spacing/colors. It sits flush against the app header with no page padding container, so it visually reads as a different product than every sibling help page.
- (high/color_contrast) color-contrast(5): Swagger's default palette fails contrast on at least five elements — the gray version pill '0.21.6', muted /api/admin/openapi.json link, the section toggle chevrons, and low-contrast gray on white. The green 'OAS 3.0' badge and green 'Authorize' button also use Swagger green, not the SysNDD success token, and the green-on-light-green badge is borderline.
- (med/hierarchy) Heading hierarchy comes entirely from Swagger: the visible 'SysNDD API' is Swagger's <h2>, there is no app-owned route h1, and the tag sections (default/health/version/entity/review...) are Swagger's own heading structure, producing the heading-order(1) failure and breaking the 'exactly one route-level h1' invariant.
- (med/content_clarity) Mismatched version metadata erodes trust: the Swagger title shows API version '0.21.6' while the app header shows v0.21.7 in the same viewport, a visible inconsistency on a page whose whole purpose is authoritative API reference.
- (low/interaction_states) Loading/error states are minimal and unstyled: a plain 'Loading API documentation...' line and a Bootstrap alert-warning, but initSwagger sets loading=false synchronously after the call (ApiView.vue:38) so the spinner logic doesn't actually track Swagger's async fetch, and a slow/failed openapi.json fetch won't reliably surface the error branch.

**Improvements:**
- [M·per-page] Wrap Swagger in the shared public-page shell: add a public-hero with the SysNDD kicker, a single route-level <h1> ('SysNDD API'), and a one-line description, then mount #swagger-ui inside a public-panel so the page inherits the app's container, padding, and visual identity. — _Restores the one-h1 invariant, makes the page recognizably SysNDD, and likely resolves heading-order by giving the document a proper app-owned h1>h2 outline above Swagger's content._
- [M·per-page] Add a scoped Swagger theme overriding its palette to SysNDD tokens — primary medical-blue for links/headers, success #2e7d32 for Authorize/OAS badge, and darker neutral text for version pills/chevrons — targeting the five contrast-failing elements specifically. — _Clears color-contrast(5), lifts the a11y score from 95, and stops the page from looking like default Swagger green/gray inside a blue-tokened app._
- [S·foundation-shared] Source the Swagger info.version from the same release version the app header uses (or hide Swagger's version pill and show the unified AppVersionInfo) so API/app/db versions agree on screen. — _Removes the 0.21.6-vs-0.21.7 mismatch and reinforces trust on the canonical API reference; benefits anywhere version is shown._
- [S·per-page] Track Swagger's real onComplete/onFailure to drive loading and error, and style the loading and error states with the app's spinner and problem+json error treatment instead of bare text/alert. — _Accurate loading/error feedback when openapi.json is slow or unavailable, matching the interaction-state quality of the other help pages._

### `login` — 8/10

_A genuinely well-composed two-panel sign-in: quiet, trustworthy, brand-anchored context paired with a focused form — let down only by a heading-order slip and a duplicated 18px title token across both panels._

**Findings:**
- (med/accessibility) Heading-order violation: the page-title <h1> 'Curator sign in' lives in the left context panel, while the actual form heading 'Sign in' is an <h2 id=login-title> — but visually 'Sign in' reads as the dominant/primary action and both use the identical .login-title style, so the h1->h2 jump is arbitrary rather than semantic.
- (low/hierarchy) Two equally-weighted titles compete for the eye. 'Curator sign in' (left) and 'Sign in' (right) are the same size/weight, so neither clearly owns the page; the left kicker 'SYSNDD ACCOUNT' and right 'SECURE ACCESS' add a third and fourth label layer.
- (low/content_clarity) Field help text ('Enter your user name', 'Enter your user password') is redundant with the visible labels and adds vertical noise without informing the expert user.
- (low/interaction_states) Validation state is wired (vee-validate touched/error), but there is no visible inline error styling cue in the resting screenshot, and the only error feedback for failed auth is a transient toast plus a shake animation — easy to miss for keyboard/AT users.

**Improvements:**
- [S·per-page] Promote the form's 'Sign in' to the single route-level <h1> (or merge the two panels under one h1) and demote the left-panel 'Curator sign in' to an <h2>/styled <p>, so heading order matches visual weight and Lighthouse heading-order clears. — _Fixes the a11y heading-order audit and resolves the dual-title hierarchy ambiguity._
- [S·per-page] Drop the redundant BFormGroup description text on Username/Password (or replace with format hints only when non-obvious), keeping labels as the single source of field meaning. — _Reduces vertical noise; tightens the form to a clinical-tool density without losing clarity._
- [M·foundation-shared] Add a persistent inline auth-error region (aria-live polite) above or below the form instead of relying on a fleeting toast + shake, so failed logins are announced and remain visible. — _Improves accessibility and error recovery across all auth views that share the same toast pattern._
- [S·foundation-shared] Define a shared type-scale token for page vs section titles (e.g. .page-title 20px / .section-title 16px) and apply distinct tokens to the two panels so they are no longer byte-identical. — _Establishes reusable title hierarchy tokens that also help register and other shell pages._

### `register` — 5/10

_A clean Lighthouse score masks a dated, inconsistent form: a heavy near-black header bar, no <h1>, label-less inputs that rely on placeholders + below-field captions, and dark buttons that diverge sharply from the Login page's blue primary system._

**Findings:**
- (high/accessibility) Inputs have NO real <label> — every field relies on a placeholder for the name and a below-field BFormGroup description for the hint. Placeholders disappear on focus/typing, so the field identity is lost while filling, and the caption-below-input pattern is the inverse of conventional label-above.
- (high/accessibility) No route-level <h1>. The page's title is delivered as a BCard `header` ('Register new SysNDD account') rendered inside a dark bar — semantically not a heading, so the page has no h1 at all, unlike Login which at least has one.
- (high/consistency) Color/shape system diverges from the rest of Auth and the design tokens: a near-black (header-bg-variant='dark') header bar and `variant='dark'` Register button vs Login's medical-blue primary. This is decorative heavy chrome the brief explicitly warns against and breaks cross-page consistency.
- (med/interaction_states) The terms error 'You must accept the terms' is shown in red on initial render before any interaction, reading like a failure state on a pristine form.
- (med/spacing_density) Centered captions and an unchecked checkbox floating left of a centered 'I accept the terms' label create a misaligned, off-grid layout; the form lacks the left-aligned label rhythm of a data-entry tool.

**Improvements:**
- [M·per-page] Add explicit `label` + `label-for` to every BFormGroup (Username, Email, ORCID, First/Family name, Comment) and keep the existing description as a true hint below the label; never rely on placeholder-as-label. — _Fixes the most serious a11y/usability gap, keeps field identity visible while typing, and matches the Login form's labelled pattern._
- [S·per-page] Replace the BCard `header`/dark-bar title with a real route-level <h1> (e.g. 'Register a SysNDD account') above a borderless or --border-subtle card, removing header-bg-variant='dark'. — _Gives the page a genuine h1, removes heavy decorative chrome, and aligns visual weight with the rest of the app._
- [S·foundation-shared] Switch Reset/Register buttons to the shared outline-secondary / primary (medical-blue) variants used on Login so auth actions are visually identical across pages. — _Unifies primary-action color across all auth/form pages; eliminates the one-off dark variant._
- [S·foundation-shared] Suppress validation messages until a field is touched or the form is submitted (use the same touched-gated :state pattern Login already uses) so the terms error does not show on first paint. — _Removes the false-error first impression and aligns error-timing behavior across forms._
- [S·per-page] Left-align all field labels, descriptions, and the checkbox row to a single column grid (12px form-group gaps) to read as a data-entry tool rather than a centered marketing form. — _Restores the compact, scannable rhythm expected of the SysNDD design language._

### `gene-detail` — 6/10

_An excellent, dense, table-first clinical gene page — header chips, resource rail, ACMG ClinVar chips and a genomic lollipop all read as a serious research tool — but it is dragged down by a severe aria-prohibited-attr storm (636 nodes) rooted in the shared badge/identifier components._

**Findings:**
- (high/accessibility) Massive aria-prohibited-attr violation (636 nodes): the shared badge components put `role="link"`/`role="img"` on a <span> while ALSO wiring `v-b-tooltip` (which injects aria-describedby/title) and an `aria-label`. role=link/img with these combinations, repeated across every chip in the resource rail, identifier strip, and the ~57-entity associated table, multiplies into hundreds of identical prohibited-attribute nodes.
- (med/interaction_states) CLS 0.198 on a content-rich page: the header card, Associated table, and three external SectionCards hydrate asynchronously with min-heights set per-card, but the entities table mounts before its row count is known and external cards swap skeleton->content, causing visible layout shift.
- (low/consistency) Nested-card stacking: the header BCard wraps ClinicalResourcesCard + IdentifierCard, and below it three SectionCard-wrapped external cards sit in their own bordered frames, plus the genomic-viz card — a lot of competing card borders in one viewport that slightly muddies the single-surface intent.
- (med/color_contrast) One residual color-contrast failure plus several status chips lean on color: the ClinVar 'LP' chip uses orange #f97316 with dark #111827 text and 'VUS' uses #ffc107 — the short labels (P/LP/VUS/LB/B) carry meaning but the borderline-contrast orange/amber chips are the likely color-contrast(1) hit.
- (low/responsiveness) Mobile reflow is genuinely good (single column, full identifier list, chips wrap), but the brain-DNA logo + hamburger header consumes a tall band and the 'Associated' card shows a single entity rendered as a stacked chip cluster that is workable but visually loose.

**Improvements:**
- [M·foundation-shared] Refactor the shared badge components (GeneBadge, DiseaseBadge, InheritanceBadge, EntityBadge) to remove role='link'/role='img' from spans: when linked, let the wrapping anchor carry the name; for non-interactive labels drop the role and use plain text + aria-hidden icon. Move tooltips off the role-bearing element. — _Eliminates the 636-node aria-prohibited-attr storm here and proportional violations on every entity/gene/table page that reuses these badges — single highest-leverage a11y fix in the app._
- [M·foundation-shared] Reserve vertical space for the Associated table (skeleton with a fixed row-height * expected rows, or a min-height equal to the loaded state) so the largest async block stops shifting layout. — _Cuts CLS below 0.1 here and on entity-detail/other SWR detail pages that mount tables before counts are known._
- [S·foundation-shared] Retune the ClinVar chip palette to AA-compliant tokens: deepen LP/VUS (e.g. amber-on-dark or darker amber) and verify each chip's text/bg pair against 4.5:1, keeping the P/LP/VUS short labels as the icon-free color-independent signal. — _Clears the color-contrast(1) audit and hardens the pathogenicity legend used wherever ClinVar chips appear._
- [S·per-page] Reduce competing borders by making the header's child cards frameless (they already render inside the header BCard) and confirming the three external cards are the only --border-subtle frames in that band. — _Calms the stacked-border look and reinforces the single-surface clinical aesthetic._
- [S·foundation-shared] Audit and fix the remaining heading-order(1): ensure the gene-page <h1> (symbol) is the only h1 and that card titles use a consistent non-heading or stepped-heading token rather than skipping levels. — _Resolves the heading-order audit on every SectionCard-based detail page at once._

### `entity-detail` — 4/10

_The captured screenshot is a bare '404 Page Not Found' for /Entities/1, so the rich entity layout in source never rendered — scoring reflects the failed route plus the source-level header-order and chip-a11y patterns the page would inherit._

**Findings:**
- (high/content_clarity) The audited route returned 404. /Entities/1 redirected to /PageNotFound (the source watcher routes to /PageNotFound when the entity record resolves to null), meaning entity_id=1 has no approved public record, so the audit captured an empty error page instead of the intended entity-detail UI.
- (med/interaction_states) The 404 page itself is extremely sparse: two centered text lines, no recovery affordance (no search box focus, no 'back to Entities', no suggested links) — poor empty/error UX for what an expert will hit on any stale entity link.
- (med/accessibility) Heading-order(1) is reported for this route; the 404 view's '404' and 'Page Not Found' likely render as same-level or non-sequential headings, and (when the real page renders) EntityView wraps its <h1> 'Entity' inside a SectionCard header with multiple sibling card titles, risking order issues.
- (med/accessibility) Source-level inherited risk: the entity hero reuses the same role-bearing badges (GeneBadge/DiseaseBadge/InheritanceBadge) plus many anchor chips with `data-tooltip` CSS pseudo-tooltips and aria-labels — the same aria-prohibited-attr family that scored 636 on gene-detail would recur once the page renders with data.
- (low/dataviz) Cannot assess the actual entity dataviz/spacing because it did not render; the design in source (3-column gene/inheritance/disease unit grid, classification pill, chip panels) is promising but unverified in this audit pass.

**Improvements:**
- [S·per-page] Re-run the audit against a known-good public entity id (e.g. one returned by the entity table) so the real entity-detail layout is captured and can be scored; entity_id=1 is not a valid public record. — _Produces a meaningful audit of the actual page instead of the 404 fallback._
- [M·foundation-shared] Make the 404/PageNotFound view useful: add a route-level <h1>, a short message, a focused global search, and quick links (Entities table, Genes, Home) so stale entity/gene deep-links recover gracefully. — _Improves error recovery for every bad deep link across the app, not just entities._
- [S·foundation-shared] When the real page renders, hoist the entity <h1> out of the SectionCard header into a proper page-title slot and make the five evidence-card titles consistent non-heading or correctly-stepped headings to clear heading-order. — _Fixes heading-order on entity-detail and the shared SectionCard title pattern used across detail pages._
- [M·foundation-shared] Apply the shared badge a11y refactor (remove role from spans, move tooltips off the named element) so the entity hero and chip panels do not reproduce the aria-prohibited-attr storm once populated. — _Pre-empts the same 600+ node a11y violation on entity-detail that gene-detail exhibits._
- [S·per-page] Ensure the chip CSS pseudo-tooltip (data-tooltip ::before/::after) has a non-hover/focus equivalent or keep the aria-label as the sole accessible name, and verify chip background/text pairs (publication cyan #cffafe, genereview #dbeafe, variation #dcfce7) meet 4.5:1 with the #0f172a text. — _Keeps the entity evidence chips accessible and contrast-compliant when the page renders._

