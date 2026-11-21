# SysNDD documentation style guide

Date: 2026-11-20. Branch `docs/refresh-2026-11`.
Companion documents: `2026-11-20-documentation-and-educational-videos-design.md` (scope)
and `2026-11-20-docs-quality-protocol.md` (how chapters are scored). Where this guide
and the protocol disagree, the protocol wins and this guide is corrected.

The theme lives in `documentation/theme.scss` (Bootstrap variables) and
`documentation/styles.css` (components). Book structure lives in
`documentation/_quarto.yml`. Writers do not edit these files; ask the designer.

## 1. Readers and voice

Four readers, in this order of frequency:

1. **Clinicians and diagnostic labs**: look up a gene, check its evidence category,
   build a panel. Little time, no interest in implementation.
2. **Researchers**: download data, use the API, read analyses.
3. **Reviewers**: re-review assigned entities.
4. **Curators and Administrators**: create, modify and approve records, manage users
   and re-review work.

Voice:

- Plain, precise English. American spelling, as in the manuscript ("analyze",
  "color").
- One idea per paragraph. Mean sentence length 20 words or fewer; no sentence over
  40 words outside quoted rules.
- Address the reader as "you". Name the actor in role rules ("A Curator approves...").
- Present tense, active voice. "Select **Save**", not "The Save button should be
  clicked".
- No marketing tone: no "powerful", "seamless", "easily", "simply", "just",
  "cutting-edge", "comprehensive". Say what the feature does.
- No undated counts or versions. If a number is needed, take it from the live public
  API (`https://sysndd.dbmr.unibe.ch/api/...`) and write the access date beside it:
  "SysNDD lists 4,512 entities (accessed November 20, 2026)". Prefer no count.
- Dates in prose use the long form: "November 20, 2026".
- Expand every abbreviation on first use in each chapter, or link it to the glossary
  (`reference-glossary.qmd`).
- Do not narrate implementation (Vue, Plumber, MySQL, Traefik, job queues) in user
  chapters. That belongs in 08 and 09.
- Do not restate curation or review rules outside 05 and 06. Link to them.

## 2. Book structure

| Part | Chapters | Reader |
| --- | --- | --- |
| Getting started | `index.qmd`, `01-intro.qmd` | everyone |
| Using SysNDD | `02-web-tool.qmd` (hub), `using-find-gene.qmd`, `using-panels.qmd`, `using-phenotype-search.qmd`, `using-analyses.qmd`, `using-account.qmd`, `03-api.qmd` | public, researchers |
| Curation | `05-curation-criteria.qmd`, `curation-research.qmd`, `06-re-review-instructions.qmd`, `07-tutorial-videos.qmd` | Reviewers, Curators |
| Curator guide | `curator-create-entity.qmd`, `curator-modify-entity.qmd`, `curator-approve.qmd`, `curator-manage-rereview.qmd`, `curator-users.qmd`, `curator-genereviews-variation.qmd` | Curators, Administrators |
| Reference | `04-database-structure.qmd`, `reference-citing.qmd`, `reference-glossary.qmd`, `references.qmd` | everyone |
| For developers | `08-development.qmd`, `09-deployment.qmd` | developers |

Rules:

- Existing `NN-` filenames never change: their URLs are cited externally (the
  manuscript cites `05-curation-criteria.html`). New chapters use descriptive
  kebab-case names with a part prefix (`using-`, `curation-`, `curator-`,
  `reference-`).
- **Section numbering is off on the web.** After the restructure, chapter numbers no
  longer match the `NN-` filenames (05 is no longer chapter 5), so printed numbers
  would mislead readers who know the URLs. Numbers also add visual noise to short
  task pages. Link with descriptive text instead of "see section 3.2". The PDF and
  EPUB downloads keep numbering because print readers navigate by number.
- The sidebar shows the SysNDD logo, a persistent **Open SysNDD** link and a link to
  the API (Swagger). Do not add your own "go to the app" banners.

## 3. Page template

Every user-facing chapter follows this order. Omit a block only when it is empty.
The labels in the example below show the markup only; verify every real label in
`app/src` before use.

```markdown
---
title: "Download a gene panel"
---

::: {.lead}
Build a list of genes filtered by evidence category and inheritance, and download it
as a spreadsheet.
:::

::: {.callout-note .who-can title="Who can do this"}
Everyone. No account is needed.
:::

## Build a panel

::: {.steps}
1. Open **Tables › Panels**.
2. In **Category**, select [Definitive]{.cat .cat-definitive}.
3. Select **Download**.
:::

::: {.doc-screenshot}
![The Panels page with category and inheritance filters.](static/img/generated/panels-table.png){#fig-panels-filters fig-alt="Panels page. Marker 1 points to the category filter, marker 2 to the inheritance filter, marker 3 to the download button."}
:::

::: {.marker-legend}
1. **Category**: limits the panel to one or more evidence categories.
2. **Inheritance**: limits the panel to a mode of inheritance.
3. **Download**: saves the current panel as an Excel file.
:::

The file contains one row per entity. ...

## Common problems

- **The download is empty.** ...

## Related pages

- [Curation criteria](05-curation-criteria.qmd): what each evidence category means.
```

Block by block:

1. **Title**: the reader's goal or the object ("Find a gene", "Approve reviews and
   statuses"). Sentence case. No "How to".
2. **Purpose line** (`.lead`): one sentence, what the reader can do and why.
3. **Who can do this** (`.who-can` callout): the minimum role, in the words of
   section 7. Required on every task chapter, including public ones.
4. **Task sections** (`##`): one per task, headed by the goal in imperative form
   ("Build a panel", "Refuse a re-review"). Inside: a short context sentence if
   needed, the steps, the screenshot with its legend, the expected result.
5. **Common problems** (`##`): symptoms the reader sees, each with the fix. Use this
   heading name in every chapter.
6. **Related pages** (`##`): two to five links, each with a one-clause reason.

Headings: one `#` (the title, from YAML), then `##` and `###` only; never skip a
level. Do not add `{#fig-*}`-style IDs to headings; Quarto creates anchors.

## 4. Steps

- Use the `::: {.steps}` wrapper around a numbered list. The theme draws step numbers
  in circles.
- One action per step. Start with the verb: Open, Select, Type, Choose, Check.
- UI labels the reader clicks or reads are **bold**, copied verbatim from the app
  source, including capitalization ("**Approve review**", "**Re-Review**").
- Menu paths use ` › ` (U+203A with spaces): **Curation › Approve review**. Give the
  route only when it helps (bookmarking): "(`/ApproveReview`)".
- Use "Select" for clicking, tapping and keyboard alike. Use "Type" for text entry.
  Keyboard keys use `<kbd>Enter</kbd>`.
- End with the result: "The review moves to the approved list."

## 5. Callouts

Use only these. Never use a callout for ordinary content, and never stack two
callouts without text between them.

| Purpose | Markup | Use for |
| --- | --- | --- |
| Who can do this | `::: {.callout-note .who-can title="Who can do this"}` | the role line at the top of a task chapter or section; teal, person icon |
| Rule | `::: {.callout-important .rule title="Rule"}` | a curation or review rule quoted from 05/06; used **only** in 05 and 06 |
| Note | `::: {.callout-note}` | background a reader may need but can skip |
| Tip | `::: {.callout-tip}` | a faster or better way to do the task |
| Warning | `::: {.callout-warning}` | an action that is hard to undo, affects public data, or commonly fails |

`callout-caution` is reserved; use `callout-warning`. Titles are optional for note,
tip and warning; when given, make them say the point ("Approval publishes the
change"), not "Important".

## 6. Screenshots

Screenshots are generated by `make docs-screenshots` (app repository) into
`documentation/static/img/generated/`. Do not hand-capture or hand-edit them.

- **Naming**: kebab-case, `<area>-<subject>[-<state>].png`, e.g.
  `curator-approve-review-table.png`, `panels-filters.png`,
  `mobile-entities-table.png`. Reuse an existing name when the image fits. To request
  a new image, list its name, route, role, viewport, state and markers in your
  handoff; until it exists the image is missing in the render.
- **Markup**: always inside `::: {.doc-screenshot}`. Add `.mobile` for phone captures
  (`::: {.doc-screenshot .mobile}`), which caps the width at 360 px.
- **Figure ID**: `{#fig-<chapter-slug>-<subject>}`, unique across the book
  (e.g. `#fig-find-gene-gene-page`). Cross-reference with `@fig-...`. Figures are
  numbered by chapter ("Figure 4.1").
- **Caption**: one sentence, says what the screenshot shows. Gene symbols italic.
- **Alt text** (`fig-alt`): what is on the screen and where the markers point, for a
  reader who cannot see it. Not a repeat of the caption.
- **Markers**: numbered filled circles, white numeral on medical blue `#0d47a1`,
  with a 2 px white ring so they read on blue UI. Place each marker **beside** the
  control, never on top of a label or help icon; a 2 px `#0d47a1` outline may frame
  the control. Number in reading order (top-left to bottom-right) or in step order
  when a figure illustrates steps. No more than six markers per screenshot.
- **Marker legend**: directly below the figure, a `::: {.marker-legend}` numbered
  list. Each item: **bold label as in the app**, colon, what it does. Numbers in the
  legend, the image and any step text must match. Refer to a marker inline with
  `[1]{.marker}`.
- **Content**: realistic records only. No fixture text ("Playwright-only
  documentation fixture"), no personal data, no test usernames in view. Prefer the
  worked example *MAU2* where a gene is needed.
- One screenshot per non-trivial step, not one per click.

## 7. Roles

The app knows four account roles (`app/src/assets/js/constants/role_constants.ts`):
Administrator, Curator, Reviewer, Viewer. Visitors without an account are "public".

| Term in prose | Meaning |
| --- | --- |
| public / everyone | no login needed |
| Reviewer | Reviewer role or higher ("Reviewer+" in manuscript Table S2) |
| Curator | Curator role or higher ("Curator+" in Table S2) |
| Administrator | Administrator role only |
| Viewer | read-only account role; mention only where it changes what a reader sees |

- Capitalize role names. Write the minimum role and say "or higher" once in the
  `who-can` callout: "Curators and Administrators." or "Reviewer or higher."
- Role badges in running text, tables and the Related pages list:
  `[Curator]{.role}`. Do not use them in headings.
- Menus are role-gated: **Review** (Reviewer+), **Curation** (Curator+),
  **Administration** (Administrator). Verify against
  `main_nav_constants.ts` before naming an item.

## 8. Terminology

Aligned with the AJHG manuscript (`sysndd-manuscript/manuscript/manuscript.qmd`,
`supplementary.qmd`) and the app. Use the left column; avoid the right.

| Use | Meaning | Avoid |
| --- | --- | --- |
| entity | one gene, one mode of inheritance, one disease (HGNC gene, HPO inheritance term, OMIM or MONDO disease); never changes once created | gene entry, record (for the triple), association (as a noun for the triple) |
| gene-disease association | the biological relationship an entity asserts | gene–disease link |
| evidence category | Definitive, Moderate, Limited, Refuted | confidence level, tier, class, status (as a synonym) |
| Definitive / Moderate / Limited / Refuted | category names, capitalized | Category 1/2/3 alone; may appear in brackets after the name in 05: "Definitive (Category 1)" |
| Not applicable | non-NDD entity kept for gene context; not a category and not a tier. The app shows `n.a.` / "not applicable" | non-ID, n.a. in prose |
| mode of inheritance / inheritance | HPO inheritance term of an entity | inheritance pattern in UI text (fine in analyses prose) |
| NDD phenotype (yes/no) | whether the entity's disease is a neurodevelopmental disorder | ID flag |
| review | synopsis, phenotypes, variation, publications of an entity | annotation set |
| status | the evidence category record of an entity, with its approval state | category record |
| re-review | systematic reassessment of existing entities by Reviewers | rereview, re-evaluation |
| approve / approval | a Curator or Administrator makes a submitted review or status active and public | accept, publish |
| refuse ("needs specialist") | a Reviewer hands a re-review back; neither approved nor rejected | reject |
| deactivate | a duplicate or superseded entity is withdrawn from public views and linked to its replacement; entities are never deleted | delete, remove |
| phenotype | an HPO term annotated on an entity | symptom, feature |
| phenotype category | one of the HPO-based groups used in the Phenotypes table and analyses | phenotype class |
| variation / variant type | a Variation Ontology (VariO) term on an entity | mutation |
| functional cluster / phenotype cluster | derived analysis groups; present as hypotheses, not curated facts | module (outside analyses), subtype |
| panel | gene list from **Tables › Panels** | gene list download |
| curator | person; **Curator** with capital C means the role | |

Identifiers:

- **Gene symbols** are italic: `*MAU2*` renders *MAU2*. Proteins, pathways, databases
  and acronyms stay roman. In tables and code blocks, gene symbols stay as typed
  (no markdown emphasis inside code).
- Examples from the *MAU2* worked example: **HGNC** `HGNC:29140`; **OMIM**
  `OMIM:621570` (Cornelia de Lange syndrome 7); **MONDO** `MONDO:0016033`; **HPO**
  `HP:0000006` with the term name on first use: "Autosomal dominant inheritance
  (`HP:0000006`)"; **PMID** `PMID:32433956`; **VariO** `VariO:` plus the number. Prefix uppercase as shown, no space after the colon, identifiers in
  inline code when they stand alone; link to the source when the reader might follow
  it.
- **Database names**: OMIM, MONDO, HPO, HGNC, VariO, ClinGen, Gene2Phenotype (G2P on
  second use), PanelApp, SFARI, GeneReviews, PubMed, PubTator, gnomAD, ClinVar.
- **SysNDD** always written so; "SysID" only for the predecessor database.
- The site is "SysNDD" or "the SysNDD web app"; the docs are "this documentation".

Evidence-category badges, for tables, summaries and worked examples (not inside the
quoted rules):

```markdown
[Definitive]{.cat .cat-definitive} [Moderate]{.cat .cat-moderate}
[Limited]{.cat .cat-limited} [Refuted]{.cat .cat-refuted} [Not applicable]{.cat .cat-na}
```

The badges repeat the app's stoplight colors as a dot; the label text carries the
meaning, so color is never the only signal.

## 9. Links, tables, media

- Link text says where it goes: "[Curation criteria](05-curation-criteria.qmd)", never
  "here" or a bare URL. Link to `.qmd` files; Quarto rewrites them.
- External links open in a new tab and get an icon automatically; do not add "(external)".
- Tables need a header row and short cells. Put long explanations below the table.
  Keep columns to five or fewer.
- No raw HTML for layout (`<p style=...>`, `<br>`, `<center>`), no `<mark>` for
  emphasis. Use bold sparingly for UI labels and defined terms on first use.
- Videos: embed with a caption and the site version and capture date; legacy videos
  are labelled "recorded on the 2023 interface".
- Code samples (API chapter) are runnable, use `https://sysndd.dbmr.unibe.ch/api/...`,
  and show the response shape briefly.

## 10. Accuracy checks before handoff

1. Every UI label, route, menu item, button, field and role: `rg -n` it in
   `app/src` and note `file:line` in your handoff.
2. 05 and 06 only: diff against `git show master:documentation/<file>`; every rule,
   threshold, number and AND/OR/PLUS connector survives with the same meaning.
3. Terms match section 8. Counts carry an access date.
4. `cd documentation && quarto render --to html` renders without warnings for your
   files; images either exist or are listed as requested.
5. Hand off: task goal, files touched, checks run, screenshots requested, open risks.

## 11. Theme reference (for the designer)

- Palette from `documentation/10-visual-design-guide.md`: medical blue `#0d47a1`
  (links, primary, markers), `#1e88e5` (focus ring), teal `#00897b` for fills and
  `#00695c` for teal text (contrast), status colors for callouts and category badges.
- Type: system sans, 17 px body, line height 1.6, measure about 72 characters; mono
  only for identifiers and code. Headings 600 weight, h2 with a hairline rule.
- Callouts: 1 px tinted frame and tinted header, no thick colored left stripe.
- Screenshots: 1 px border, 6 px radius, soft offset shadow.
- Light mode only. A dark mode would need re-captured dark screenshots to avoid
  white glare panels; not worth it until the app has a dark theme.
