# SysNDD documentation quality protocol

Date: 2026-11-20. Applies to the documentation refresh on branch `docs/refresh-2026-11`
(design: `2026-11-20-documentation-and-educational-videos-design.md`).
Scope: every user-facing chapter in `documentation/*.qmd`. Developer chapters 08 and 09
are scored for the record but are out of the refresh's content scope.

## Purpose

One shared yardstick for writers, designers and reviewers. A chapter passes when every
applicable criterion meets its threshold. The baseline at the end records the state of
`master` before the refresh so that improvement can be measured, not asserted.

## Sources of truth

| Topic | Authority |
| --- | --- |
| Curation rules, thresholds, numbers | `git show master:documentation/05-curation-criteria.qmd` |
| Re-review rules | `git show master:documentation/06-re-review-instructions.qmd` |
| UI labels, routes, roles | `app/src/router/routes.ts`, `app/src/assets/js/constants/main_nav_constants.ts`, `app/src/views/{curate,review,pages}`, `app/src/components` |
| Terminology | SysNDD AJHG manuscript: `sysndd-manuscript/manuscript/manuscript.qmd` and `supplementary.qmd` (Table S1 evidence categories, Table S2 pages and roles) |
| Counts | Live public API, with the access date written next to the number |

Terminology the manuscript fixes, which the docs must use the same way:

- **entity**: one gene, one mode of inheritance, one disease (HGNC, HPO inheritance,
  OMIM or MONDO).
- **evidence category**: Definitive, Moderate, Limited, Refuted. The legacy numbers
  (Category 1, 2, 3) may appear only beside the name, never alone.
- **Not applicable** (`n.a.` in the app): a non-NDD entity kept for gene context; not an
  evidence category and not a lower tier.
- **roles**: public (no login), Reviewer, Curator, Administrator. "Reviewer+" and
  "Curator+" as in Table S2.
- **re-review**, **review**, **status**, **approval**: a submitted review or status
  becomes public only after a Curator or Administrator approves it.
- **refused / needs specialist**: a re-review state, neither approved nor rejected.

## Criteria

Score each criterion 1-5. Anchors are given for 1, 3 and 5; 2 and 4 lie between.
"N/A" is allowed only where stated.

### C1. Task orientation and findability (pass >= 4)

- **1**: Page-by-page or feature tour. A reader with a goal ("download a gene panel",
  "approve a review") cannot tell where to start. No task headings.
- **3**: Some sections name a task, but steps are prose paragraphs or are mixed with
  description. The book outline shows features, not jobs.
- **5**: Headings name the reader's goal ("Download a virtual gene panel"). Each task
  states who may do it, then gives numbered steps, the expected result and what to do
  next. The table of contents lets each audience find its tasks in one click.

### C2. Clarity and readability (pass >= 4)

- **1**: Mean sentence length > 28 words or several sentences > 60 words; undefined
  jargon (MCA, JWT, v-test, pLI) for a clinical reader; implementation detail mixed
  into user text.
- **3**: Mostly plain, but some long compound sentences, occasional undefined
  abbreviations, a few paragraphs carrying several ideas.
- **5**: Plain, precise English. One idea per paragraph. Mean sentence length <= 20
  words, none > 40 outside quoted rules. Every abbreviation expanded on first use or
  linked to the glossary. Correct spelling and grammar ("criterion", not "criterium").

### C3. Accuracy against the app source (pass >= 4; hard gate)

- **1**: Two or more described labels, routes, buttons, fields or roles do not exist or
  have been renamed; or a missing feature is described as present.
- **3**: Everything described exists, but labels are paraphrased or out of date (e.g.
  a menu item renamed), or a current menu entry is omitted from an exhaustive list.
- **5**: Every UI string quoted in the text matches the source verbatim; every route
  and role gate checks out; every exhaustive list (menus, fields, buttons) is complete
  for the current release; the release or check date is recorded.

### C4. Consistency with curation rules and the manuscript (pass >= 4; hard gate)

- **1**: Contradicts the criteria or re-review rules, or uses a term in a different
  sense from the manuscript (e.g. treats Not applicable as a tier).
- **3**: No contradiction, but terminology drifts: category numbers without names,
  `n.a.` vs "Not applicable" vs "non-ID", "candidate genes" vs Moderate/Limited, rules
  restated in two places with different wording.
- **5**: Terms match the manuscript glossary above. Rules appear once, in 05/06; other
  chapters link to them instead of restating them. Worked examples follow the rules
  exactly.

### C5. Completeness for each role (pass >= 4 for the book; per chapter: its audience)

- **1**: A role's main tasks are absent (e.g. no Curator workflow documented).
- **3**: Each role has some coverage, but key tasks are missing or only described as
  implementation notes (for example in the deployment chapter).
- **5**: Public: search, tables, entity/gene/disease pages, panels, analyses, API and
  MCP. Reviewer: account, login, re-review, refuse. Curator: every Curation menu entry
  (Create entity, Modify entity, Approve review, Approve status, Approve user, Manage
  re-review, Variation suggestions, GeneReviews coverage). Administrator: at least an
  overview of each Administration menu entry and who to contact. Each page states its
  role at the top.

### C6. Visual support (pass >= 4 for task chapters; N/A for reference-only text)

- **1**: Tasks with UI steps have no screenshots, or screenshots show a different UI.
- **3**: Screenshots exist and are current, but markers are missing, inconsistent with
  the text, or obscure the control they point to; captions are absent; screenshots
  show fixture text that confuses the reader.
- **5**: One screenshot per non-trivial step, regenerated by `make docs-screenshots`.
  Numbered markers sit beside (not on top of) the control, and the same numbers appear
  in the steps. Each figure has a caption and a cross-reference label. Fixture content
  is realistic or neutral.

### C7. Structure and navigation (pass >= 4)

- **1**: Flat or arbitrary order, no cross-links, dead ends, broken links.
- **3**: Logical headings but few links between related chapters; no "next step".
- **5**: Book parts follow the audience path (Getting started, Using, Curating, Curator
  guide, Reference, For developers). Each chapter opens with a one-paragraph purpose and
  "Who this is for", links to the rules it depends on, and ends with next steps. No
  broken links (`quarto render` clean, link check clean).

### C8. Accessibility (pass >= 4)

- **1**: Images without alt text; link text such as "here" or bare URLs; skipped
  heading levels; meaning carried by colour or `<mark>` alone; layout via `<p>` or
  `<br/>` hacks.
- **3**: Alt text present but generic; some bare URLs; minor heading or emphasis
  misuse.
- **5**: Alt text states what the image shows and why it matters; descriptive link
  text; heading levels in order; no raw-HTML layout; tables have headers; videos have
  captions or a transcript.

### C9. Maintainability (pass >= 4)

- **1**: Hard-coded volatile facts (counts, versions, tool lists, protocol dates)
  without a date or source; rules copied into several chapters.
- **3**: Some volatile facts are dated; some duplication remains.
- **5**: No undated counts or versions. Rules have a single home. Screenshots are
  generated, not hand-captured. Long reference lists (endpoint groups, MCP tools) are
  generated or point to the live catalogue.

### C10. Rule fidelity (05 and 06 only; pass = 5; N/A elsewhere)

- **1**: A rule, threshold, number, inclusion/exclusion condition or logical connector
  (AND/OR/PLUS) was dropped or changed.
- **3**: All rules present, but rewording shifts meaning (e.g. ">= (2-)3" simplified to
  ">= 3"; "approximately >= 20%" made exact).
- **5**: Every rule, threshold, number and connector in the `master` version survives
  with the same meaning. New summaries and worked examples are consistent with it.

## Scoring procedure

1. Read the whole chapter as rendered (`quarto preview documentation`) and as source.
2. For 05/06, diff against `git show master:documentation/<file>` and list every rule,
   threshold and connector; tick each off in the new text (C10).
3. For each UI string, route or role in the text, find it in `app/src` (`rg -n`) and
   note the file:line (C3).
4. Check terminology against the manuscript list above (C4).
5. Score each criterion. For every score, cite at least one evidence line
   (`file:line` plus a short quote or finding). A score without evidence is invalid.
6. Overall chapter score = mean of applicable criteria, one decimal. A chapter passes
   only if every applicable criterion meets its threshold; the overall score does not
   compensate for a failed hard gate (C3, C4, C10).
7. Record the worst criterion and the one change that would most improve it.
8. A second reviewer re-scores any chapter where the first reviewer gave a 5 on C3, C4
   or C10.

## Baseline (master as of 2026-11-20)

Sentence statistics are approximate (list items merged into prose).
Scores: C1..C10; "-" = N/A.

| Chapter | C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8 | C9 | C10 | Overall |
| --- | - | - | - | - | - | - | - | - | - | - | - |
| index.qmd | 2 | 3 | 4 | 3 | 2 | - | 2 | 3 | 2 | - | 2.6 |
| 01-intro.qmd | 1 | 3 | 3 | 3 | 1 | 1 | 2 | 2 | 3 | - | 2.1 |
| 02-web-tool.qmd | 2 | 2 | 2 | 3 | 2 | 3 | 2 | 3 | 2 | - | 2.3 |
| 03-api.qmd | 2 | 1 | 4 | 4 | 2 | 3 | 2 | 3 | 2 | - | 2.6 |
| 04-database-structure.qmd | 1 | 3 | 3 | 3 | 1 | 2 | 2 | 3 | 3 | - | 2.3 |
| 05-curation-criteria.qmd | 2 | 2 | 5 | 3 | 3 | - | 2 | 1 | 4 | 5 | 3.0 |
| 06-re-review-instructions.qmd | 3 | 2 | 3 | 3 | 2 | 3 | 2 | 2 | 3 | 5 | 2.8 |
| 07-tutorial-videos.qmd | 2 | 3 | 3 | 3 | 1 | 2 | 1 | 2 | 2 | - | 2.1 |
| 08-development.qmd | 3 | 2 | 4 | - | - | - | 3 | 3 | 3 | - | 3.0 |
| 09-deployment.qmd | 2 | 2 | 4 | 3 | - | - | 2 | 3 | 2 | - | 2.6 |
| references.qmd | - | 5 | 5 | - | - | - | 3 | 4 | 5 | - | 4.4 |

No user-facing chapter passes. The book as a whole fails C5: there is no Curator guide.

### Evidence

**index.qmd**
- C1/C7: one sentence of purpose (l.9), then history and funding; no "start here" by
  audience.
- C4: categories are named (l.31) but Not applicable is missing.
- C9: "updated every 3-4 months" (l.33) is an undated, unverifiable cadence claim.
- C5: no pointer to the Reviewer or Curator material.

**01-intro.qmd**
- C1/C5: background essay; no task, no role, no link to using the tool.
- C3: broken link `https://id-genes.orphanet.app/ithaca])` (l.42, stray `]`).
- C8: meaning carried by `<mark>` on 13 phrases (l.7-16); decorative, not semantic.
- C2: "affect about 2% of children" (l.16) has no citation; "great chance" (l.42) is
  tone, not content.
- C6: no figure explaining the entity concept, the core idea of the book.

**02-web-tool.qmd** (worst user chapter)
- C3: Analyses menu list (l.48-57) is stale. Source
  (`main_nav_constants.ts:61-69`) has "Data releases" and labels the last item
  "Phenotype–function correlation", not "Pheno-Func Correlation". The NDDScore menu
  (`main_nav_constants.ts:78-79`) and the Help menu item "MCP" (l.90) are missing.
- C3: the role-dependent menus (Curation, Administration, Review) are shown in a
  screenshot (l.84) but never named.
- C2: methods paragraph of 200+ words (l.257) with MCA, v-test, W(k)/W(k-1), k-means
  starts: manuscript-methods depth in a user chapter; mean sentence 26 words, 23
  sentences > 30 words, max 105.
- C1: page-by-page tour ("Landing page", "Footer navigation menu"); no task such as
  "find all Definitive genes for a panel".
- C9: build stack (l.7) and performance/security sections (l.426-445) are product
  claims that age; no access date on any content.
- C6: 35 screenshots with alt text, but only the login and register sections refer to
  numbered markers; no captions or figure labels.

**03-api.qmd**
- C2: worst readability in the book; MCP paragraphs of 100+ words (l.41, 43, 66, 72)
  written for operators and agent developers (`mcptools`, Traefik, `405`, `sepoch`
  style detail), not for researchers.
- C9: hand-maintained list of 18 MCP tools (l.47-64) and a protocol date ("as of
  2026-08-27", l.43) will drift; developer facts duplicated from 09.
- C1: no task "download data with the API" or "connect an AI assistant"; no example
  request.
- C3: endpoint groups and auth flow match the API (`config.yml.example` token_expiry
  3600 = "60 minutes", l.118).

**04-database-structure.qmd**
- C5/C1: reference chapter of ~240 words; no explanation of entity, review, status,
  history or categories (the design's "Reference" scope).
- C3: dbdesigner short link (l.14) uses the discontinued `page.link` service;
  "MysQL" typo in alt text (l.20).
- C9: pins `mysql:8.4.9` (l.7) without date.

**05-curation-criteria.qmd**
- C10 = 5 (baseline is the reference text).
- C3 = 5: no UI described.
- C4: rules use "Category 1/2/3" alone in several places (l.16, 99, 152-163); `n.a.`
  (l.167) where the manuscript uses "Not applicable"; "candidate genes" (l.99) is a
  legacy term.
- C8: layout by raw `<p style="text-align: center;">` blocks (l.20-52, 104-145) for
  AND/OR connectors; screen readers read them as stray words.
- C2: "criterium" (l.36, 42); nested AND/OR/PLUS logic is hard to parse without a
  summary table or decision flow; no worked example.
- C7: no link to 06 or to where a Curator applies the category in the app.

**06-re-review-instructions.qmd**
- C10 = 5 (baseline).
- C3: "Click the 'Review' link" (l.42) — the menu is "Review" with items "Instructions"
  and "Re-Review" (`main_nav_constants.ts:158-159`). The status window is called
  "New Status edit" (l.145) and the submit button is "Submit Review"
  (`SubmitConfirmModal.vue:17`), not named in text. Edit Review modal has a
  "Variation ontology" field that the numbered list (l.75-80) skips.
- C3 (ok): refuse flow labels match (`ReviewQueueTable.vue:224`,
  `RefusedReReviewPanel.vue:13,78`); 5/3/1-minute warnings match
  `LogoutCountdownBadge.vue:83`.
- C6: markers exist but cover field labels and help icons (reviewer-modify-review-modal
  screenshot: "1. Synopsis" over the help icon, "5. Comment" over the label); fixture
  text "Playwright-only documentation fixture" visible.
- C4: synopsis guidance and examples duplicated (l.91-97 and l.207-220); Curator
  section (l.191-244) mixed into Reviewer instructions.
- C8: `<br/>` and `&nbsp;` layout hacks (l.21, 48, 93, 174-175, 188-189).

**07-tutorial-videos.qmd**
- C5/C1: one video, Reviewer only; no Curator or public content.
- C6/C8: embedded YouTube video with no transcript, no stated app version or date
  (anti-goal "videos that go stale silently").
- C7: not linked from 06, where it belongs.

**08-development.qmd** (content out of refresh scope)
- C2: 40 sentences > 30 words; issue numbers (#22, #573) in headings.
- C7: reasonable developer outline; sits in "Project" part beside user chapters.

**09-deployment.qmd** (content out of refresh scope)
- C5 note: only place that describes Curator features (GeneReviews coverage l.183,
  Variation suggestions l.499-504), confirming the missing Curator guide.
- C9: embeds counts and dates ("182 + 5,763 + 2,166 = 8,111", l.469).

**references.qmd**
- Minimal and correct; C7 = 3 because nothing links back to cited chapters.
