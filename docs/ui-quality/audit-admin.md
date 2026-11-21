# UI quality audit: Administrator pages (2026-11-21)

Method: degraded single-context run. The impeccable critique normally runs two
isolated assessments; this subagent has no sub-agent tool. Design review (A) was
written from the screenshots and the source before the detector output (B) was
read. B is the `impeccable detect` output the runner collected over CDP on the
signed-in tab.

Scope: the 13 `ADMIN` pages in `tools/ui-audit/pages.mjs`, signed in as the admin
demo user on `sysndd_uiaudit` (http://localhost:8091, branch `ui/quality-2026-11`
at 7a0d599b). The task also names a "data releases archive". There is no separate
admin archive page: the admin releases table is on `/ManageAnalysisReleases`, and
the public archive on `/DataReleases` was checked as well (known item 4).

## Runs and evidence (all under `tools/ui-audit/out/`, git-ignored)

| Run | What | Command |
|---|---|---|
| `admin-a/`, `admin-b/` | browser metrics, 3 viewports, axe, impeccable detect; two parallel shards | `run.mjs --pages … --no-lighthouse --cdp-port 9461/9462` |
| `admin-lh/` | Lighthouse 12.8.2 desktop + mobile | `run.mjs --roles ADMIN --lighthouse-only --cdp-port 9463` |
| `admin-summary.md` | merged summary with the ratings | `summarize.mjs admin-a/… admin-b/… admin-lh/…` |
| `admin-probe/` | full-length shots, shots scrolled to the bottom of the inner scroller, raw-value text scan (`NA`, `NaN`, `undefined`, ISO timestamps), modal shots | scratch scripts `admin-probe.mjs`, `admin-dom.mjs`, `admin-modal.mjs`, `admin-time.mjs`, `admin-poll.mjs` (in `out/`) |
| `admin-a/ratings.json` | the 1–5 ratings below | written by hand |

Caveats:
- Three other Lighthouse and shard runs used the same single-process R API and the
  same CPU at the same time. Lighthouse Performance and the time-to-usable outliers
  are therefore pessimistic. Each outlier was re-timed in isolation (ADM-28).
- The runner's `filter` interaction on `/ManageAbout` typed into a section editor,
  and the page autosaved a CMS draft on the audit database (the 390 px shot shows
  "Draft · Last saved 02:06 PM"). `stack/reset.sh` restores it.

## Measurements

Lighthouse is P/A/BP/SEO. The browser metrics are at 1366x768 unless marked.
"Usable" is ms to the ready state. The outliers marked † were not reproduced in
isolation (ADM-28). "Max shift" is the largest interaction shift including the
shift right after input.

| page | LH desktop | LH mobile | usable 1920 / 1366 / 390 | load CLS 1920 / 1366 / 390 | long tasks (ms) | max event ms | max shift | flicker | overflow 1366 / 390 | axe serious+crit | impeccable |
|---|---|---|---|---|---|---|---|---|---|---|---|
| manage-user | 100/92/100/100 | 98/91/100/100 | 619 / 317 / 253 | 0 / 0 / 0 | 168 | 24 | 0 | 0 | 0 / 0 | 2 | 5 |
| manage-annotations | 100/99/100/100 | 92/99/100/100 | 3486† / 2063 / 2338 | .016 / .015 / **.126** | 179 | 24 | 0 | 0 | 0 / 1 | 0 | 8 |
| manage-ontology | 100/93/100/100 | 95/91/100/100 | 484 / 653 / 277 | .008 / .009 / .041 | 389 | 32 | .041 (paginate) | 0 | 0 / 4 | 2 | 2 |
| manage-about | 100/91/100/100 | 96/90/100/100 | 526 / 1742 / 1256 | .013 / .026 / **.114** | 362 | 32 | 0 | 2 | 0 / 0 | 2 | 10 |
| view-logs | 100/96/100/100 | 86/91/100/100 | 1227 / 210 / 647 | 0 / 0 / .014 | 359 | 32 | 0 | 0 | 5 / 1 | 1 | 2 |
| admin-statistics | 100/95/100/100 | 95/94/100/100 | 1296 / 1394 / 12071† | 0 / 0 / 0 | 149 | 32 | 0 | 0 | 12 / 0 | 1 | 12 |
| manage-backups | 100/97/100/100 | 100/96/100/100 | 551 / 333 / 415 | .001 / .002 / **.059** | 147 | 40 | 0 | 3 | 0 / 0 | 1 | 3 |
| manage-pubtator | 100/100/100/100 | 100/100/100/100 | 511 / 325 / 199 | 0 / 0 / 0 | 157 | 24 | 0 | 0 | 2 / 1 | 0 | 4 |
| manage-llm | 100/97/100/100 | 98/100/100/100 | 2341 / 1728 / 751 | 0 / 0 / **.081** | 259 | 48 | 0 | 0 | 0 / 0 | 1 | 4 |
| manage-nddscore | 94/96/100/100 | 80/95/100/100 | 1748 / 438 / 305 | **.106 / .130 / .466** | 123 | 24 | 0 | 0 | 0 / 0 | 1 | 8 |
| manage-metadata | 100/100/100/100 | 100/100/100/100 | 1341 / 3295† / 1046 | 0 / 0 / 0 | 114 | 40 | .004 | 0 | 0 / 0 | 0 | 2 |
| manage-ontology-mappings | 97/96/100/100 | 86/95/100/100 | 709 / 18334† / 276 | **.063 / .092 / .501** | 91 | 32 | 0 | 0 | 0 / 0 | 1 | 7 |
| manage-analysis-releases | 100/100/100/100 | 100/100/100/100 | 1674 / 884 / 3550† | .011 / .019 / .036 | 147 | 24 | 0 | 0 | 2 / 0 | 0 | 10 |

Console errors and failed same-origin requests: none on any page. Slowest event
everywhere is 48 ms or less. Every page fails at least one threshold in protocol
section 4.

Overflow counts from the runner include two kinds of false positive:
- Controls "obscured" by the fixed footer. When the inner `.scrollable-content`
  scroller is scrolled to the end, no control on any admin page is covered
  (`admin-probe/probe.json`, `covered: []` everywhere).
- Bootstrap's visually hidden `.btn-check` radios on AdminStatistics. That page's
  12 counted overflows at 1366 are all this case.

The real overflow is ADM-01. The tool fixes are listed under "Tool notes".

## Ratings (1–5, protocol section 5)

| page | hierarchy | clarity | consistency | responsive | feedback | snappiness | a11y | min |
|---|---|---|---|---|---|---|---|---|
| manage-user | 4 | 3 | 3 | 3 | 4 | 5 | 2 | 2 |
| manage-annotations | 4 | 2 | 3 | 3 | 3 | 4 | 4 | 2 |
| manage-ontology | 4 | 3 | 3 | 3 | 4 | 4 | 2 | 2 |
| manage-about | 3 | 3 | 3 | 2 | 3 | 4 | 2 | 2 |
| view-logs | 4 | 2 | 3 | 3 | 4 | 5 | 2 | 2 |
| admin-statistics | 3 | 3 | 2 | 3 | 4 | 4 | 3 | 2 |
| manage-backups | 4 | 3 | 4 | 3 | 3 | 5 | 3 | 3 |
| manage-pubtator | 4 | 4 | 4 | 4 | 4 | 5 | 4 | 4 |
| manage-llm | 3 | 2 | 3 | 3 | 3 | 4 | 3 | 2 |
| manage-nddscore | 4 | 3 | 3 | 3 | 2 | 4 | 3 | 2 |
| manage-metadata | 4 | 4 | 4 | 4 | 4 | 4 | 5 | 4 |
| manage-ontology-mappings | 4 | 3 | 3 | 3 | 2 | 4 | 3 | 2 |
| manage-analysis-releases | 3 | 2 | 3 | 2 | 3 | 4 | 4 | 2 |

No admin page meets the "done" bar (passes section 4 and scores at least 4
everywhere). ManageMetadata and ManagePubtator are closest and are the house
pattern to converge on.

Nielsen heuristic scores (0–4) for the admin area as a whole:
- Visibility of status: 2 (log times 1 h off, durations wrong, loaders flash)
- Match with the real world: 2 (NA/NaN, digests, developer copy)
- User control: 3 (one-click preset delete)
- Consistency: 1 (five date formats, three count patterns, three page-inset widths)
- Error prevention: 3
- Recognition over recall: 3
- Flexibility: 2 (bulk actions unreachable on desktop)
- Aesthetic and minimalist design: 2 (cards nested three deep)
- Error recovery: 3
- Help: 3

Total 24/40.

## Findings

Severity: P1 = wrong or unreadable data, a broken feature, or a critical a11y
blocker. P2 = clear defect or confusion. P3 = polish. Evidence paths are relative
to `tools/ui-audit/out/`. Every finding was reproduced on :8091.

### P1

- **ADM-01 · manage-analysis-releases.** The 64-character source-data digest
  overflows its fixed-width cell and prints over the Created, Published and Files
  columns, so all three are illegible. The release id also runs into the Status
  badge. The table uses `table-layout: fixed` and 8 equal 157 px columns, and the
  cell has `overflow: visible` (td scrollWidth 536 vs clientWidth 157).
  - Cause: `app/src/views/admin/ManageAnalysisReleases.vue:281-290` (field list)
    and `:315-325` (row mapping).
  - Evidence: `admin-probe/releases-table-1366.png`; impeccable text-overflow,
    379 px.
  - Fix: show a short digest (first 12 characters) with the full value in
    `title` and a copy button, give release id and digest a mono class with
    `text-truncate`, and set widths on the key columns.
- **ADM-02 · manage-user.** On desktop (≥ md) the row checkboxes and the
  select-all checkbox never render, so bulk approve, role change and delete are
  unreachable. They work only in the mobile list. `ManageUser.vue:203-216`
  supplies `#head-select` and `#cell-select`, but `GenericDesktopTable.vue`
  forwards only a hardcoded list of cell slots and no `head(select)` or
  `cell(select)`. Its `#head()` at `:31` routes every header to `column-header`.
  This is the same gotcha the `ManageAnalysisReleases.vue:293-301` comment
  documents.
  - Cause: `app/src/components/small/GenericDesktopTable.vue:31` and `:47-250`.
  - Evidence: `admin-a/manage-user/1366x768.png` shows an empty 40 px first
    column. The DOM has no checkbox in `tbody`, and axe reports
    `empty-table-header`.
  - Fix: forward slots generically (`v-for` over `fields` producing
    `#cell(key)` → `cell-<key>`, and `#head(key)` → `head-<key>` when that slot
    exists), with a unit test that a `cell-select` slot renders.
- **ADM-03 · view-logs.** Request durations are shown in the wrong unit. The API
  stores tictoc seconds (`api/bootstrap/mount_endpoints.R:224`, `end$toc - end$tic`)
  and the UI formats the value as milliseconds. Every row therefore reads "<1ms"
  in green, the detail dialog says "0.039ms" for a 39 ms request, and slow
  requests never turn amber or red.
  - Cause: `app/src/components/tables/logTableFormatters.ts:59-72`,
    `TablesLogs.vue:185`, `components/small/LogDetailDrawer.vue:56`.
  - Evidence: `admin-a/view-logs/1366x768.png`,
    `admin-probe/modal-ViewLogs.png`.
  - Fix: multiply by 1000 in the formatter and the duration-class helper (or
    store ms in the API), and add a unit test with 0.039 → "39ms".
- **ADM-04 · manage-user, manage-ontology, view-logs, manage-about.** Icon-only
  buttons have no accessible name (axe critical `button-name`): Users 2,
  Ontology 27, Logs 11, About 7. `v-b-tooltip` moves `title` to
  `data-original-title`, which leaves the button nameless. Some buttons have no
  label at all: the About chevron and preview "eye" (axe `link-name`), and the
  Logs trash button. Two Ontology filter selects also lack names (axe critical
  `select-name`).
  - Cause: `views/admin/ManageUser.vue:35,45`, `views/admin/ManageOntology.vue:30`
    and its filter selects (`:80-104`), `components/tables/TablesLogs.vue`
    (view-details and delete buttons), `components/cms/SectionEditor.vue:27-32`.
  - Evidence: `admin-a/results.json` (axe), and the LH accessibility scores of
    90–93 in `admin-lh/lighthouse/*.json`.
  - Fix: give every icon-only button an `aria-label` equal to its tooltip text,
    and give the selects `aria-label`s ("Filter by status" and "Filter by term
    type").

### P2

- **ADM-05 · manage-annotations, manage-backups.** R `NA` reaches the screen as
  text, the same class as known item 3.
  - "Last: NA" appears on the Ontology and HGNC cards. The API returns
    `{"omim_update":["NA"],"hgnc_update":["NA"]}`, and `formatDate` returns any
    unparsable string as-is.
  - The mobile backup row shows "NaN tables": `table_count: "NA"` becomes
    `Number("NA")`.
  - Cause: `composables/annotations/useAnnotationsApi.ts:50-53`,
    `composables/annotations/useAnnotationFormatters.ts:22-26`,
    `views/admin/composables/useBackupInventory.ts:252`.
  - Evidence: `admin-a/manage-annotations/1366x768.png`,
    `admin-probe/ManageBackups-390-full.png`, `admin-probe/probe.json`.
  - Fix: at the root, serialize missing values as JSON `null` in the API
    (`na = "null"`). In the UI, make the shared `unwrapValue` map `"NA"` and
    `"NaN"` to `null`. Render "Never" or "—" for missing values and hide the
    chip when the count is missing.
- **ADM-06 · view-logs.** Log times are off by the client's UTC offset. The API
  returns naive UTC (`"2026-11-21 13:19:00"`) and `new Date()` parses it as local
  time, so a request made seconds earlier reads "1 hour ago" in CET. The detail
  dialog shows the UTC wall time with no zone.
  - Cause: `components/tables/logTableFormatters.ts:15` (and the absolute-time
    formatter next to it).
  - Evidence: `admin-a/view-logs/1366x768.png`; compare the API response with
    `date -u`.
  - Fix: parse as UTC (append `Z` or replace the space with `T` and add `Z`), or
    have the API emit ISO 8601 with `Z`.
- **ADM-07 · view-logs.** "Loaded 10/944 in 0.03 secs" uses `perPage` instead of
  the rows actually shown, and an unformatted total next to the badge
  "1,051 log entries". This is the same pattern as known item 2 (Panels).
  - Cause: `components/tables/TablesLogs.vue:11`; siblings
    `views/tables/PanelsTable.vue:10`, `TablesEntities.vue:14`,
    `TablesPhenotypes.vue:10`.
  - Evidence: `admin-a/view-logs/1366x768.png`.
  - Fix: use one helper that produces "Showing 1–10 of 1,051 · 0.03 s" from
    `items.length` and `toLocaleString`. Fix all four call sites together.
- **ADM-08 · manage-nddscore, manage-ontology-mappings.** Load CLS is 0.13 and
  0.47 on NDDScore (1366 / 390) and 0.09 and 0.50 on Mappings, the worst values
  in the admin area. A one-line "Loading … status" spinner is swapped for a
  roughly 600 px KPI block, which pushes the following panels down.
  - Smaller shifts: ManageAbout 0.114 on mobile (the `aside.cms-editor-tip`
    appears late), ManageAnnotations 0.126 on mobile, ManageLLM 0.081 on mobile,
    ManageBackups 0.059 on mobile.
  - Cause: `views/admin/ManageNDDScore.vue:21-24`,
    `views/admin/ManageOntologyMappings.vue:22-26`.
  - Evidence: `admin-b/results.json` shift sources `section.admin-operation-panel`.
  - Fix: replace the spinner with a skeleton of the KPI grid at its final size,
    or give the loading block a `min-height`. Render the About tip in the
    initial template.
- **ADM-09 · manage-user.** On desktop, e-mail addresses run into the Role
  column and sit under the role badges ("admin.demo@example." under
  "Administrator"). All 8 columns are 167 px wide and the e-mail field has no
  truncation. On mobile the address breaks mid-word ("exampl / e.org").
  - Cause: `views/admin/composables/useUserTablePresentation.ts:38-45` and
    `components/UserAdminMobileRows.vue`.
  - Evidence: `admin-a/manage-user/1366x768.png`, `390x844.png`; impeccable
    text-overflow of 33–49 px.
  - Fix: give the e-mail column `text-truncate` with a `title` and a wider
    `thStyle`, and use `overflow-wrap: anywhere` on mobile.
- **ADM-10 · view-logs, manage-ontology (390 px).** The mobile pager hides the
  current page: it shows "« ‹ 2 › »" without "1", and on Logs the "»" wraps onto
  its own line.
  - Cause: `components/small/TablePaginationControls.vue:28` (`limit="2"`).
  - Evidence: `admin-a/view-logs/390x844.png`,
    `admin-a/manage-ontology/390x844.png`.
  - Fix: use `limit="3"` (or a "Page 1 of 20" text pager below md) and
    `flex-wrap: nowrap`.
- **ADM-11 · all admin pages.** Date and time formats are inconsistent. Seen in
  this pass:
  - ISO with seconds: "2026-11-21 12:10:50" (Users)
  - raw ISO with `Z`: "2026-11-21T12:12:53Z" (Annotations)
  - US short date: "7/12/2026" (Annotations)
  - US date and time: "5/17/2026, 7:31:47 PM" (NDDScore, Mappings, Releases,
    Statistics)
  - 12-hour clock: "02:06 PM" (About)
  - long form: "Nov 21, 2026, 01:25:42 PM" (Log detail)
  - Mappings shows ISO "2026-09-01" next to "10/4/2026, 4:33:02 AM" on the same
    line.
  - Durations are written four ways: "0.03 secs", "<1ms", "160.0 s", "~2 min".
  - Cause: `views/admin/nddScoreAdminFormatters.ts:58`,
    `ManageAnalysisReleases.vue:363`, `AdminStatistics.vue:422`,
    `ManageOntologyMappings.vue:303`, `useAnnotationFormatters.ts:26,36`,
    `useUserTablePresentation.ts:70`.
  - Evidence: `admin-probe/probe.json` (raw scan) and the screenshots.
  - Fix: one shared `formatDateTime` with an explicit locale and 24-hour time
    ("21 Nov 2026, 14:08"), a date-only variant, and a `formatDuration`.
- **ADM-12 · manage-user.** The quick-filter preset chips ("Pending ×",
  "Curators ×") look like active filters while the table is unfiltered. The ×
  is an `<i @click.stop>` inside the button, so it deletes a saved preset with
  one click, without confirmation, and cannot be reached by keyboard.
  - Cause: `views/admin/ManageUser.vue:58-67`.
  - Evidence: `admin-a/manage-user/1366x768.png`.
  - Fix: render presets as plain toggle buttons (`aria-pressed`) and put a
    separate labelled delete button (or a "Manage presets" menu) next to them.
- **ADM-13 · manage-about.** Each collapsed section card keeps an empty 30 px
  body band, because `BCard` wraps the `BCollapse` in a padded `.card-body`. At
  390 px the header stacks the drag handle, icon, title and buttons into five
  rows, about 230 px per section.
  - Cause: `components/cms/SectionEditor.vue:2` (add `no-body`) and `:4` (header
    row; keep it on one line with `flex-wrap: nowrap` and a truncated title).
  - Evidence: `admin-a/manage-about/1366x768.png`, `390x844.png`.
- **ADM-14 · all admin pages, 390 px.** Cards nested three deep and stacked
  containers waste about 60 px per side. The usable column on ManageLLM is about
  240 of 390 px. The wrapper chain is `container-fluid` > `BContainer fluid` >
  `BRow` > `BCol`, all 12 px padded, inside `AuthenticatedPageShell`'s padded
  card, then the panel card. impeccable reports `nested-cards` on 12 of 13 pages.
  - Cause: `views/admin/ManageUser.vue:8-11`, `ManageBackups.vue:8-11`,
    `ViewLogs.vue:3-6`, `ManageOntology.vue:18-21`; ManageLLM has the same chain.
  - Evidence: `admin-b/manage-llm/390x844.png`; the computed padding chain was
    read in the DOM.
  - Fix: drop the outer `div.container-fluid` and `BRow`/`BCol` wrappers,
    matching the ManageMetadata and ManagePubtator pattern. That also makes the
    panel inset the same on every page (it is now 34 px on NDDScore and Mappings
    and 58 px elsewhere).
- **ADM-15 · admin-statistics.** The KPI row mixes scopes and uses inconsistent
  styling.
  - "Contributors 2" is an all-time count (leaderboard `scope=all_time`) next to
    "New this period 0" and "Avg per day 0". The average rounds to 0 instead of
    showing 0.0x.
  - "↓ 100%" in #d55e00 has 3.9:1 contrast.
  - Inside each StatCard the label is left-aligned, the value indented and the
    caption centred.
  - Active toggles are blue in one group (Monthly) and dark grey in the other
    (NDD, Combined), and the grey category buttons look disabled.
  - Cause: `views/admin/AdminStatistics.vue:53-60`, `:65-124`;
    `views/admin/components/statistics/StatCard.vue`.
  - Evidence: `admin-a/admin-statistics/1366x768.png`.
  - Fix: label the contributors card "all time" or compute it for the period,
    show one decimal, use one alignment (left), and use one active-state style
    (`btn-primary` / `outline-primary`).
- **ADM-16 · manage-llm.** The overview uses developer-facing or misleading
  copy:
  - "Model Not configured. Cache and regeneration controls use the same compact
    table layout as public data views."
  - The orange "Needs review" chip shows when 0 summaries are pending, and a
    "USD" chip sits in the Status column.
  - The Regenerate buttons stay offered while the provider is not configured.
  - Cause: `views/admin/useLlmCacheOverview.ts:29`, `:59`;
    `views/admin/LlmOverviewPanel.vue:79,95`.
  - Evidence: `admin-b/manage-llm/1366x768.png`.
  - Fix: copy "No model configured. Set a provider under Configuration to
    regenerate summaries.", a neutral "None pending" chip when the count is 0,
    no chip for cost, and disable Regenerate with that reason inline.
- **ADM-17 · llm, nddscore, mappings, backups, users, metadata.** Text contrast
  fails WCAG AA (axe serious):
  - LLM warning and info chips: 2.5:1, #f57c00 on #fef2e6
    (`LlmOverviewPanel.vue:361-390`)
  - NDDScore and Mappings KPI labels (`.ndd-kpi span`, `.ont-kpi span`)
  - Backups toolbar labels and filter chips
  - Users quick-filter chips (`btn-outline-secondary` at reduced opacity)
  - the yellow archive and restore icon buttons on Metadata and Backups
  - Evidence: `admin-a/results.json`, `admin-b/results.json`.
  - Fix: use the token text colours (`--text-secondary` ≥ 4.5:1) and darker
    warning tones (#b45309).
- **ADM-18 · manage-backups.** The badge reads "1 backups". The desktop table
  fills only the left 650 of 1230 px, leaving Actions mid-panel.
  - Cause: `views/admin/ManageBackups.vue:14`.
  - Evidence: `admin-a/manage-backups/1366x768.png`.
  - Fix: pluralize, and set the table to `w-100` with the filename column
    flexible.
- **ADM-19 · manage-ontology.** On desktop, Obsolete and Active show raw 0/1,
  while the mobile cards show "Active"/"Current" badges. The Definition column
  is about 130 px, so definitions wrap to 3–4 lines while Name and Sort are
  wide. "Sort" means sort order.
  - Cause: `views/admin/ontologyTableConfig.ts`.
  - Evidence: `admin-a/manage-ontology/1366x768.png`.
  - Fix: use badge cells like mobile, give Definition the flexible width, and
    rename the column to "Order".
- **ADM-20 · manage-analysis-releases.** While the release list loads, the table
  renders headers only: no busy row, and "No releases yet" is suppressed. Under
  load this looked like an empty archive for several seconds. The long header
  "Source data ver…" is ellipsized without a `title`.
  - Cause: `views/admin/ManageAnalysisReleases.vue:156`, `:261-263`.
  - Evidence: `admin-probe/ManageAnalysisReleases-1366-bottom.png`.
  - Fix: pass a busy or skeleton row, and rename the header to "Data version".

### P3

- **ADM-21 · manage-about, manage-backups.** Loaders flash: "Loading content…"
  is on screen for 271 ms, and "Loading backups…" for 158–272 ms at each
  viewport. Cause: `ManageAbout.vue:87` and the BTable busy
  slot in `ManageBackups.vue`. Fix: show the loader only after 300 ms, or a
  stable skeleton.
- **ADM-22 · admin-statistics, manage-annotations.** Duplicate requests on load:
  `/api/statistics/updates` ×2, although `useKPIStats.ts:67` says it avoids this,
  and `/api/publication/pubtator/genes` ×2. Evidence: `admin-poll.mjs` output.
  Fix: share the first promise.
- **ADM-23 · all admin pages.** Heading levels skip, for example h2 → h5 modal
  titles ("Confirm Deletion", "Restore Database") and h2 → h6 "Markdown Quick
  Reference". Lighthouse `heading-order` fails on Annotations and Statistics.
  Fix: modal titles as h2 inside the dialog, and section titles as h3.
- **ADM-24 · all admin pages.** Page headers are inconsistent.
  - Only Pubtator, NDDScore, Mappings, Metadata and Releases carry a description.
  - The Releases description runs about 144 characters per line (impeccable
    line-length).
  - "PubTator" and "Pubtator" are both used on Annotations.
  - Fix: give every admin page a one-sentence description capped at `58rem`
    (already set in `AuthenticatedPageShell.vue:98`; Releases overrides it).
- **ADM-25 · manage-nddscore.** "Release update" offers Check Zenodo, Download &
  validate, and the filled primary "Import & activate latest release" side by
  side, so the irreversible step is the most prominent before validation has
  run. The "active" badge also appears twice. Fix: make the steps sequential
  (enable each after the previous succeeds) and drop the duplicate badge.
- **ADM-26 · manage-user.** The Edit User dialog is 1,165 px tall in a 768 px
  viewport, so Save is two screens down. Fix: use a scrollable body
  (`modal-dialog-scrollable`) with a sticky footer.
- **ADM-27 · view-logs.** "Delete logs" is an unlabelled trash icon in the filter
  row, next to the "10 of 944" count. The ID column header has a stray ▾ caret,
  and the sort arrows sit far from the centred labels (the same applies on
  Users). Fix: a labelled "Delete logs…" button in the header actions, and
  left-aligned headers with the sort icon after the label.
- **ADM-28 · manage-ontology-mappings, admin-statistics, manage-metadata,
  manage-annotations.** The time-to-usable outliers (18.3 s, 12.1 s, 3.3 s,
  3.5 s) did not reproduce: three isolated runs each gave 206–252 ms, 912–1082 ms,
  358–1472 ms and 349–479 ms. They came from queueing in the single-process R API
  while four other audit shards ran (the first `/admin/ontology/mappings/status`
  call took 1.38 s, the next ones 0.06 s). There is no app defect, but it is a
  real snappiness risk under concurrent admin use.

## Known screenshot items checked from this scope

- Item 2 ("Loaded 10/5"): the same bug is present in `TablesLogs.vue:11` (ADM-07).
- Item 3 (literal "NA"): the same class is present on Annotations and Backups
  (ADM-05). Fixing it at the API serializer would cover Modify Entity as well.
- Item 4 (raw date in the archive): reproduced on `/DataReleases` at 390 px,
  "Published 2026-07-18 20:01:55". Cause:
  `app/src/components/analyses/ReleaseArchiveList.vue:23` prints `published_at`
  unformatted. At 1366 px this list is not in the rendered text.

## Modal check (manual, 1366x768)

Five dialogs were checked: Edit user, Edit ontology term, Log entry, Restore
backup, Edit metadata. Each opened in 68–130 ms with no layout shift. Focus moved
into the dialog, page scroll was locked, and Escape closed it and returned focus
to the trigger. Shots are `admin-probe/modal-*.png`. The only finding is ADM-26.

## Tool notes (for `tools/ui-audit`)

- `probes.js` obscured check (lines 80-90): it should skip elements whose centre
  lies outside their scroll container's visible rect, and skip `.btn-check`. Both
  produced all the false "under footer" and "under label" hits here.
- `pages.mjs`: no `modal` interaction is configured for any admin page. Suggested
  selectors: Users "Edit user", Ontology "Edit ontology", Logs "View details",
  Backups "Restore from this backup", Metadata "Edit entry".
- `/ManageAnnotations` never reaches `networkidle` within 30 s (Playwright
  `goto` timed out). Use `load` plus the ready selector there.
- Screenshots are viewport-sized even though the protocol says full page. The app
  scrolls inside `.scrollable-content`, so Playwright's `fullPage` captures only
  the viewport. Add a bottom-of-scroller shot.
