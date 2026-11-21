# UI quality audit: Reviewer and Curator pages (2026-11-21)

Scope: the 11 pages behind the Reviewer and Curator route guards, audited on the
`sysndd_uiaudit` stack (http://localhost:8091, app v0.38.4, branch
`ui/quality-2026-11` at dcbf1fe3) following `protocol.md`. Reviewer pages were
signed in as the Reviewer demo account, Curator pages as the Curator demo account;
`/Review` and `/User` were also opened as Curator, and the Curator URLs were opened as
Reviewer to check the guard.

No app code was changed.

## Method and caveats

- Browser metrics: `tools/ui-audit/run.mjs` in two parallel shards (`out/curation-a`,
  `out/curation-b`), 1920x1080, 1366x768 and 390x844. `gene-reviews` crashed the runner
  twice at 1366 (see CUR-01), so its 390 run is in `out/curation-c390` and its 1366
  numbers come from a targeted probe.
- Lighthouse 12.8.2, desktop and mobile presets: `out/curation-lh` and `out/curation-lh2`
  (re-run of four reports that failed with "internal Chrome error").
- Merged summary with ratings: `out/curation-a/summary.md`, `out/curation-a/ratings.json`.
- Reproductions: Playwright probes in `out/curation-evidence/probes/` (`probe.mjs ROLE PATH WxH probe-file`),
  screenshots in `out/curation-evidence/`. All `out/` paths are under `tools/ui-audit/`.
- impeccable: `detect` ran in-page through the runner on every page. `detect` on the source
  trees (`src/views/curate`, `src/views/review`, `src/views/user`) was clean
  (`out/curation-evidence/impeccable-detect-src.json`). The critique ran as a single-context
  pass because no sub-agent tool was available to this workflow step; no PRODUCT.md exists,
  so the incumbent visual system was used as the design authority.
- Load: the host ran at a load average of 70-95 during the first pass because other audit
  shards were running at the same time. Every time-to-usable value over 2.5 s was
  re-measured at a load average of about 19 (`out/curation-retime`, `out/curation-retime2`).
  Only `gene-reviews` stayed slow. Lighthouse performance scores share the same contention.
- Tool limits: full-page screenshots stop at the viewport, because the app scrolls inside
  `main.scrollable-content` rather than the document. Rows behind the fixed footer show up
  as `obscured` and are treated as informational. The `btn-check` radios on Create Entity
  show as `obscured` by their own labels; that is a false positive.

## Score table

LH = Lighthouse Performance/Accessibility/Best Practices/SEO. Usable = time to usable in ms,
worst viewport after re-timing. Ratings are 1-5 for hierarchy (H), clarity (Cl),
consistency (Co), responsiveness (R), feedback (F), snappiness (S) and accessibility (A).

| page | role | LH desktop | LH mobile | usable ms | load CLS | worst long task ms | axe serious+crit | H | Cl | Co | R | F | S | A | pass |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| user | Reviewer | 100/96/100/100 | 99/95/100/100 | 357 | 0 | 229 | 1 | 4 | 3 | 3 | 4 | 4 | 5 | 3 | FAIL |
| review | Reviewer | 99/93/100/100 | 84/92/100/100 | 985 | 0 | 453 | 2 (1 critical) | 3 | 3 | 3 | 3 | 3 | 4 | 3 | FAIL |
| review-instructions | Reviewer | 100/100/100/100 | 100/100/100/100 | 358 | 0 | 196 | 0 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | PASS |
| create-entity | Curator | 100/100/100/100 | 100/100/100/100 | 298 | 0 | 185 | 0 | 4 | 3 | 3 | 4 | 3 | 5 | 4 | FAIL (human pass) |
| modify-entity | Curator | 100/100/100/100 | 99/100/100/100 | 686 | 0 | 469 | 0 | 4 | 2 | 4 | 4 | 3 | 4 | 4 | FAIL (NA bug) |
| approve-review | Curator | 99/100/100/100 | 83/100/96/100 | 757 | 0.0009 | 896 | 1 | 3 | 2 | 3 | 3 | 4 | 4 | 3 | FAIL |
| approve-status | Curator | 100/100/100/100 | 95/100/96/100 | 593 | 0.0009 | 631 | 1 | 3 | 3 | 3 | 3 | 4 | 4 | 3 | FAIL |
| approve-user | Curator | 100/97/100/100 | 100/97/100/100 | 572 | 0 | 189 | 1 (critical) | 4 | 3 | 3 | 4 | 4 | 5 | 3 | FAIL |
| manage-rereview | Curator | 100/100/100/100 | 97/100/100/100 | 1025 | 0.0158 | 267 | 0 | 3 | 2 | 3 | 4 | 4 | 4 | 4 | FAIL (flicker) |
| variation-suggestions | Curator | 100/100/100/100 | 100/100/100/100 | 419 | 0 | 151 | 0 | 3 | 4 | 3 | 4 | 4 | 5 | 4 | PASS (auto), 3s in human pass |
| gene-reviews | Curator | 63/100/100/100 | 69/100/100/100 | **9519 (1366), 12242 (390)** | 0 | **8999-12225** | 0 | 3 | 3 | 3 | 2 | 3 | 1 | 4 | FAIL |

The slowest interaction event was 40 ms or less on every page except `gene-reviews`, where
the first keystroke in the filter took 7.1 s to paint. No page shifted on interaction:
`shiftAll` was 0 everywhere.

## Measurements per page

**user** (`/User`): usable 172-357 ms, CLS 0, one long task of 101-229 ms, no
overflow. axe: color-contrast (serious): `.avatar-initials` is white on `#0dcaf0`
(2.0:1), and the session pill is `#198754` on `#d1e7dd` (3.5:1). impeccable: five
nested cards and a flat type scale (h2 15.2 px is smaller than the 16 px body text).
Screenshots: `out/curation-a/user/*.png`.

**review** (`/Review`): usable 340-469 ms on re-time (985 ms at 1366 under load), CLS 0,
3 long tasks totalling 400-453 ms. Overflow at 1366: 5 clipped (disease badges, the
"Review date" header), 6 obscured behind the footer. axe: `select-name` (critical) on
`#per-page-select`, `color-contrast` (serious) on the "+ Filter" dropdown,
`heading-order`. LH mobile TBT 615 ms. Screenshots: `out/curation-a/review/*.png`;
edit modal: `out/curation-evidence/review-review-1366.png`.

**review-instructions**: passes every threshold. No findings.

**create-entity** (`/CreateEntity`): usable at most 298 ms, CLS 0, autocomplete about
790 ms after the last keystroke (300 ms debounce plus the API). Wizard steps 1-5 walked
without submitting: `out/curation-evidence/ce-*.png`.

**modify-entity** (`/ModifyEntity`): usable at most 686 ms. Entity search for "1848"
returns about 1.2 s after the last keystroke (two API calls of 200-400 ms). The status,
review and combined editors all open with the literal `NA`:
`out/curation-evidence/modify-{status,review,combined}.png`.

**approve-review** (`/ApproveReview`): usable 663-757 ms on re-time, CLS at most 0.0009, long
tasks up to 896 ms on load. Synopsis cells: `scrollWidth` 2,316 px against `clientWidth`
96 px, with `white-space: nowrap` and no line clamp. axe:
`label-content-name-mismatch` (serious) on DiseaseBadge. LH mobile BP 96 (font size).
impeccable: 5 text-overflow findings, white-on-green gene badges at 3.7:1, and a
skipped heading level. The keyboard path reaches every control, and focus is visible on all
but two date-input segments.

**approve-status** (`/ApproveStatus`): usable 497-593 ms on re-time. In the actions cell the last
button ends at x=1301, past the card edge at x=1288, at 1366. Entity badge cells: content
137 px in a 121 px cell. axe: `label-content-name-mismatch` (serious).

**approve-user** (`/ApproveUser`): usable at most 572 ms. `#per-page-select` is 68 px wide with
48 px right padding, so "10" renders as "1(", and it has no accessible name (axe
critical). The empty queue still shows four disabled pagination buttons.

**manage-rereview** (`/ManageReReview`): usable 454 ms on re-time at 1920, CLS 0.0158
(sources: `section.re-review-section--table` and `div.re-review-legend`), and flicker: the
busy `table` renders for 208-653 ms, then is replaced. The "Available entities" tile shows
100, while the API reports `total: 4196`.

**variation-suggestions** (`/curate/variation-suggestions`): usable at most 419 ms, nothing
over threshold. The queue holds 0 assertions on this dump. The 390 table scrolls 44 px
inside its own wrapper, which is acceptable.

**gene-reviews** (`/GeneReviews`): all 4,200 rows render with no pagination: 35-107k DOM
nodes, a single load long task of 9.0 s at 1366 (on re-time) and 12.2 s at 390, Lighthouse
TBT 5.5 s desktop and 11.8 s mobile. One keystroke in the filter causes a 7.0 s long task.
axe takes about 150 s on the full page and the runner crashed twice with "Execution context
was destroyed". After filtering, axe reports 0 violations. "Check NCBI availability" calls
`include_live=true`, which takes 19.5 s, with skeleton rows under a stale "8 of 4200"
count. In this stack (no NCBI egress) 4,144 rows come back `lookup_error`. Screenshots:
`out/curation-evidence/gr1366.png`, `gr-ncbi.png`,
`out/curation-c390/gene-reviews/390x844.png`.

## Known screenshot item

- Known item 3 ("Modify Entity shows a literal NA for empty comments") is confirmed and is
  worse than a display bug: see CUR-02. The other four known items are on public pages
  outside this audit's scope.

## Findings

Paths are relative to `app/src/` unless they start with `api/`. Evidence paths are relative
to `tools/ui-audit/out/`.

| id | page | cause (file:line) | sev | evidence | finding and proposed fix |
|---|---|---|---|---|---|
| CUR-01 | gene-reviews | `views/curate/GeneReviewsCoverage.vue:78` (BTable with no `per-page`), `:61` (BFormInput with no `debounce`) | P1 | `curation-c390/gene-reviews/390x844.png`, probe `grt.mjs` | All 4,200 rows render. Load blocks the main thread for 9-12 s, and every keystroke re-filters and re-renders them (7 s). Fix: add pagination through the house `TablePaginationControls` (25 per page) and `debounce="300"` on the search input. The existing `filteredRows` already feeds both. |
| CUR-02 | modify-entity (and approve/review editors) | `views/curate/composables/useStatusForm.ts:171,219`, `useReviewForm.ts:297` (`x.comment \|\| ''`); source: `api/endpoints/entity_endpoints.R:425,440` `@serializer json list(na="string")` | P1 | `curation-evidence/modify-status.png`, `modify-combined.png`; `GET /api/entity/1848/status` returns `"comment":"NA"` | Empty comments arrive as the string "NA" and appear in the textarea. Saving unchanged posts "NA" back, which turns a NULL into a literal. Fix at the boundary: map `'NA'` to `''` when loading the forms (one helper in both composables). The durable fix is `na="null"` on the entity status/review endpoints, after checking other consumers. |
| CUR-03 | user, manage-rereview, variation-suggestions, create-entity step 2, gene-reviews, review (sort headers, mobile description) | `App.vue:127` `#app { text-align: center }` inherited by everything below `AuthenticatedPageShell` (only `.authenticated-heading` resets it, `components/layout/AuthenticatedPageShell.vue:79`) | P2 | `curation-a/user/1366x768.png` (centred profile values, ORCID label left), `curation-b/manage-rereview/1920x1080.png` ("Batch setup" centred, description left), `curation-evidence/ce-step2-1366.png`, `gr1366.png` | One root cause behind most of the alignment drift: centred data values, filter labels centred over inputs, sort arrows detached from their centred header labels, and a description centred on mobile but left-aligned on desktop. Fix: `text-align: start` on `.authenticated-content` (or remove it from `#app` and keep the centring only where the public home needs it). Re-check the public pages after the change. |
| CUR-04 | approve-review | `views/curate/ApproveReview.vue:383` scoped `.text-truncate-multiline` does not reach `components/review/ReviewRowCells.vue:15` (child component) | P2 | probe `ar.mjs`: clamp `none`, nowrap, scrollWidth 2,316 vs 96; `curation-b/approve-review/1366x768.png` | Synopsis and comment text is cut mid-word ("de novo truncatir") with no ellipsis. Fix: move the clamp style into `ReviewRowCells.vue`, which owns the element. |
| CUR-05 | approve-review, approve-status, review | `components/small/GenericTable.vue:95-97` (`fixedLayout` defaults to true) and `assets/scss/components/_tables.scss:44` (`td { overflow: hidden }`) | P2 | `curation-b/approve-status/1366x768.png` (action buttons past the card edge, entity badges clipped), probe `ar.mjs` | Equal fixed columns clip the entity badge (120-137 px content in 96-121 px cells) and cut disease names to about 10 characters, while Comment/Flag columns hold a single "—". Fix: give the entity, actions and icon columns `thStyle` widths in `composables/approval/useStatusHelpers.ts` and the review field config, or pass `:fixed-layout="false"` from `components/review/ReviewTable.vue:180`. |
| CUR-06 | review, approve-review, approve-status | `views/review/reviewTableConfig.ts:42-49`, `composables/approval/useStatusHelpers.ts:98-108` (stoplight legend) vs `components/ui/CategoryIcon.vue:64-72` (check/dash/!/x icons in the cells) | P2 | `curation-a/review/1366x768.png` (legend stoplights, cells show "!") | The legend explains icons the table does not use. The cell's green check for "Definitive" is also the legend's "Re-review approved" / "No problems" icon. Fix: build the legend's category entries from `CategoryIcon` (the `component` slot `IconLegend` already supports). |
| CUR-07 | approve-review, approve-status | `components/ApprovalTableView.vue:213` (`variant="danger"` on Approve), `components/review/ReviewTable.vue:7` (Approve All danger) | P2 | `curation-b/approve-review/1366x768.png` | Approve (solid red) and Dismiss (outline red) share a colour, and the page's one primary action (Approve All) is red. Fix: Approve in `success` (row and bulk), Dismiss stays `outline-danger`. Approve All keeps its confirm modal. |
| CUR-08 | approve-user, review | `views/curate/ApproveUser.vue:56-60` (`style="width: 70px"`, no aria-label), `views/review/components/ReviewQueueTable.vue:139` (no aria-label) | P2 | `curation-b/approve-user/1366x768.png` ("1(" clipped), probe `au.mjs`, axe `select-name` critical | Fix: use the house `TablePaginationControls`, which already sets `aria-label` and a sane width, or drop the fixed width and add `aria-label="Rows per page"`. |
| CUR-09 | manage-rereview | `views/curate/ManageReReview.vue:27` renders `availableEntities.length` (one page, `useManageReReview.ts:255` `page_size: 100`) | P2 | `curation-b/manage-rereview/1920x1080.png`; API `meta.total = 4196` | The tile reports 100 available entities when 4,196 exist; this is the same class of bug as "Loaded 10/5". Fix: render `availableEntityTotal` (already computed at `useManageReReview.ts:259`) with a thousands separator. |
| CUR-10 | review | `views/review/components/ReviewQueueTable.vue:161` passes `title` to `components/accessibility/IconLegend.vue`, which has no such prop, so it falls through to `BCard` and renders a card-title `<h4>` | P2 | `curation-a/review/1366x768.png`, axe `heading-order` | The legend heading (22 px, centred) outranks the page title (18 px) and skips a heading level. Fix: add a `title` prop to IconLegend that renders as small text, or drop the attribute. |
| CUR-11 | approve-review | `components/review/ReviewRowCells.vue:12-25` (popover `triggers="hover focus"` on a non-focusable div) | P2 | probe `kb.mjs` tab sequence skips synopsis/comment cells | Keyboard and touch users cannot read a truncated synopsis or comment. Fix: `tabindex="0"` plus `role="button"` and an `aria-label`, or use the expandable row ("Toggle details") as the documented way to read the full text. |
| CUR-12 | user | `views/user/UserProfileHeader.vue:8` (`bg-info text-white` avatar for the Reviewer role), session pill styles | P2 | axe color-contrast serious, LH a11y 95-96 | White initials on `#0dcaf0` measure 2.0:1, and the session pill text 3.5:1. Fix: a darker role tint for the avatar (for example `--medical-blue-700`), and `#0f5132` text on the success-subtle pill. |
| CUR-13 | approve-review, approve-status (and every table with DiseaseBadge) | `components/ui/DiseaseBadge.vue:10-11` (`role="link"` + `aria-label="Disease <full name>"` while the visible text is truncated) | P2 | axe `label-content-name-mismatch` serious | Fix: drop the `aria-label` (the visible text plus `title` is enough), or start the label with the visible text. |
| CUR-14 | gene-reviews | `views/curate/GeneReviewsCoverage.vue:78-86` (BTable `responsive`, no stacked or mobile-row mode) | P2 | `curation-c390/gene-reviews/390x844.png` (536 px hidden horizontally, Attach off-screen) | It is the only curation table with no mobile layout. Fix: `stacked="md"`, or the `mobile-record-row` pattern the approval pages use. |
| CUR-15 | gene-reviews | `views/curate/GeneReviewsCoverage.vue:236` (`metaText` from stale rows during reload), `:115` per-row "Lookup failed" | P2 | `curation-evidence/gr-ncbi.png`; `include_live=true` takes 19.5 s, 4,144/4,200 rows have `lookup_error` | While the live check loads (19 s), the count shows the previous filter's "8 of 4200". When most lookups fail there is no summary, only thousands of row warnings. Fix: show "Checking NCBI…" in the meta while loading. When `lookup_error` covers most rows, show one alert ("NCBI unreachable, N lookups failed, retry") instead. The failures themselves likely come from this stack having no NCBI egress. |
| CUR-16 | review, approve-review (edit modals) | `views/curate/components/ReviewFormFields.vue:6-10` (Bootstrap 4 classes `mr-sm-2 font-weight-bold` do nothing under BS5; help `BBadge href="#"` with an icon only and `triggers="focus"`) | P2 | `curation-evidence/review-review-1366.png` | Labels are not bold, each "?" badge sits on its own line, and the help links have no accessible name. Fix: `form-label fw-semibold`, inline the badge in the label row with `aria-label="Help: Synopsis"`, and use `triggers="hover focus"`. |
| CUR-17 | review (edit modal) | `views/review/components/ReviewQueueTable.vue:187` (`v-b-tooltip.hover` on the button that opens the modal) | P3 | `curation-evidence/review-review-1366.png` ("Edit review" tooltip drawn over the modal) | The trigger's tooltip stays visible above the open modal. Fix: hide tooltips on click (`v-b-tooltip.hover` with `noninteractive` and a manual hide in `@click`), or rely on the aria-label alone. |
| CUR-18 | all pages at 390 px | `components/accessibility/SkipLink.vue:27` (`top: -40px`; the link wraps to 44 px on phones) | P3 | `curation-a/*/390x844.png` (4 px `#0d47a1` bar at the top-left) | The hidden skip link peeks 4 px onto every page on phones. Fix: `transform: translateY(-100%)` (or `top: -100%`) plus `white-space: nowrap`. The duplicate rule in `assets/scss/utilities/_accessibility.scss:19` should be removed. |
| CUR-19 | user | `views/user/UserSecurityPanel.vue:10-14` (inline-flex label followed by an inline timer span) | P3 | `curation-a/user/1366x768.png` ("Auto-logout in58m 46s") | Fix: `display: block` on `.session-timer` (stacked), or a space before the timer. |
| CUR-20 | create-entity | `composables/useFormDraft.ts:170` (`isSaving = true` at the start of the 2 s debounce) | P3 | `curation-evidence/ce-step2-1366.png` ("Saving..." while nothing is saving) | The indicator says "Saving..." for 2 s after every keystroke and flips with "Draft saved", so the text beside the primary button keeps changing. Fix: set `isSaving` only inside the timeout, or show "Draft saved" alone. |
| CUR-21 | create-entity | `components/forms/wizard/FormWizard.vue` (Next disabled with no reason given) | P3 | `curation-a/create-entity/1366x768.png` | Fix: a one-line hint under the button that lists the missing required fields. On phones the Yes/No group also stacks into two full-width buttons; keep it inline. |
| CUR-22 | modify-entity | `views/curate/components/EntitySearchPanel.vue:8-14`, `views/curate/ModifyEntity.vue` (empty selection) | P3 | `curation-a/modify-entity/1366x768.png` | Five messages say the same thing ("Ready", "No entity selected", "Waiting for selection", "No entity selected.", "Start typing…"). Fix: keep one empty-state line in the selection card and one helper under the input. |
| CUR-23 | curator URLs as Reviewer | `router/guards.ts:34` (unauthorised goes to Login, which forwards a signed-in user to Home) | P3 | probe `url.mjs` (Reviewer opening `/ApproveReview` ends on `/`) | A signed-in user who lacks the role lands on Home with no message. Fix: for an authenticated user without the role, redirect with a "You need the Curator role" toast. |
| CUR-24 | review (curator, empty) | `views/review/components/ReviewQueueTable.vue:170-181` (`filter` passed as `''`, so BTable shows its default empty-filtered text); `:118-131` "New batch" is a clickable `BBadge` | P3 | `curation-evidence/review-curator.png` | It says "There are no records matching your request" when nothing is filtered, and the intended "Apply for a new batch of entities." (`composables/useText.ts:88`) never shows. Fix: pass `null` for an empty filter or set `empty-filtered-text`, and render "New batch" as a `BButton`. |
| CUR-25 | review, approve-review (edit modals) | `views/review/components/ReviewEditModal.vue:20`, `StatusEditModal.vue:21` (`no-close-on-esc` always) | P3 | probe `rv.mjs` (`AfterEsc: 1`) | Escape does nothing even when the form is untouched. Fix: allow Escape when the form is not dirty; the discard guard already exists. |
| CUR-26 | manage-rereview | `views/curate/components/RefusedReReviewPanel.vue` (tall empty state), busy table render | P3 | `curation-b/manage-rereview/1920x1080.png`; flicker 208-653 ms, CLS 0.0158 | With 0 refusals the panel still takes about 280 px and pushes Submissions below the fold. The busy table renders, then is replaced (flicker). Fix: collapse the panel to one line when it is empty, and keep a fixed-height placeholder in place of the busy table. |
| CUR-27 | approve-review, approve-status | `components/review/ReviewTable.vue` toolbar | P3 | `curation-b/approve-review/1366x768.png`, `390x844.png` | The per-page select stretches to about 500 px while the search box is 300 px. Date filters use `mm/dd/yyyy` while the table shows ISO dates. On phones the date inputs clip ("mm/dc") and the chevron overlaps "All Categories". These are the only curation pages without a page description. Fix: a compact toolbar like `/Review`, a shared date format, and a shell description. |
| CUR-28 | variation-suggestions | `views/curate/VariationSuggestions.vue` (intro paragraph outside the shell description, filters stacked full-width) | P3 | `curation-b/variation-suggestions/1366x768.png` | Fix: move the intro into `AuthenticatedPageShell description`, and put the four filters on one row from `md` up. |
| CUR-29 | approve-review, approve-status (mobile cards) | `views/curate/components/ApprovalMobileRows.vue` (badge text under 12 px) | P3 | LH mobile BP 96 `font-size` | Fix: a minimum 12 px for chip text on phones. |
| CUR-30 | modify-entity | `views/curate/composables/useEntityAutocomplete.ts:67-80` (`contains(any,1848)` added after the exact match) | P3 | `curation-evidence/modify-suggest.png` | An exact ID query returns 5 unrelated entities under the match. Fix: when the query is all digits and the exact match exists, show it alone, or label the rest "Also mentions 1848". |
| CUR-31 | review | `views/review/reviewTableConfig.ts` (`User` column, `Review date` header) | P3 | `curation-a/review/1366x768.png` | "User" is the last reviewer, not the assignee, and "Review d…" is truncated at 1366. Fix: "Last reviewed by" and "Reviewed" as labels. |
| CUR-32 | all tables (shared) | `components/ui/GeneBadge.vue` gradient | P3 | impeccable low-contrast 3.7:1 on 6 pages | White text on the green gradient falls below 4.5:1 for 11-12 px text. Fix: darken the gradient end stop. This is shared with the public tables. |

Tool notes (not app defects): `run.mjs` should catch axe errors per page instead of exiting
(it aborted the shard on `gene-reviews`). Full-page screenshots need to capture
`main.scrollable-content`, for example by temporarily setting `height: auto`, to show
content below the fold.

## Fix order

1. CUR-01 and CUR-02 (P1).
2. CUR-03: one CSS line fixes most of the alignment findings. Re-screenshot all 11
   pages afterwards.
3. CUR-04 to CUR-16, grouped by file: ApprovalTableView/ReviewTable (05, 07, 27),
   ReviewQueueTable/IconLegend/config (06, 08, 10, 24, 31), GeneReviewsCoverage (01, 14, 15).
4. The P3 batch.

Re-measure with
`node tools/ui-audit/run.mjs --roles REVIEWER,CURATOR --no-lighthouse --out tools/ui-audit/out/curation-after`
and a serial `--lighthouse-only` pass, then compare with `out/curation-a/summary.md`.
