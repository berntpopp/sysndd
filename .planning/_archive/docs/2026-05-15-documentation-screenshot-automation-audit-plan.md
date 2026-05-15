# SysNDD Documentation And Screenshot Automation Audit

Date: 2026-05-15

Scope: GitHub issues [#49](https://github.com/berntpopp/sysndd/issues/49), [#50](https://github.com/berntpopp/sysndd/issues/50), [#51](https://github.com/berntpopp/sysndd/issues/51), [#52](https://github.com/berntpopp/sysndd/issues/52), [#140](https://github.com/berntpopp/sysndd/issues/140), `documentation/`, current documentation screenshot assets, existing SysNDD Playwright infrastructure, and the sibling `../VarLens` documentation screenshot workflow.

Status: Completed and archived on 2026-05-15 after PR #340 merged as `e08550fd`. This audit informed the approved spec and implementation plan; Phases 1-5 were implemented, and Phase 6 optional CI integration was deferred pending explicit approval.

Completion notes:

- Implemented by PR #340.
- Issues #49, #50, #51, #52, and #140 were closed after the merge.
- No documentation curation principles, thresholds, category meanings, ontology terms, or NDD scope were changed.

## Executive Summary

SysNDD has two separate documentation problems that should be fixed together but not conflated:

1. The documentation screenshot process is manual, unversioned in intent, and already stale against the current Vue 3 / Bootstrap 5 design.
2. Several documentation chapters contain outdated runtime, tooling, UI, and analysis descriptions that make the Quarto book feel older than the product.
3. Several open documentation issues request small but important curation/user-support additions that should be planned with the same guardrails: explain "n.a." without changing classification policy, document variant ontology curation without changing variant terms, describe how to find GeneReviews PMIDs, and give users a minimal reproducible bug-report workflow.

Issue #140 correctly identifies the screenshot maintenance problem: `documentation/static/img/` contains a bulk set of manually annotated screenshots, all without source-route provenance, capture commands, viewport standards, fixture state, or regeneration metadata. The issue's proposed Playwright + Sharp manifest architecture is directionally sound, but the implementation should be adapted to SysNDD's Docker-backed app/API/DB stack rather than copied from a static-docs or single-app screenshot workflow.

The recommended path is:

- Keep Quarto as the documentation framework for now.
- Add a dedicated documentation screenshot lane separate from failure screenshots and visual regression tests.
- Generate clean reproducible base screenshots first, then generate optional callout overlays from manifest metadata.
- Update stale tool/runtime content and add the missing NDD Publications analysis section in the existing chapter style.
- Modernize the docs visual design using the current SysNDD visual guide, without turning the docs into a marketing site.
- Preserve curation criteria substance. Changes to curation chapters should be limited to wording, grammar, formatting, and cross-reference clarity unless domain owners explicitly approve criteria changes.
- Address the small documentation issues before or alongside the larger screenshot/design work, because they are low-risk, user-facing, and improve reviewer support immediately.

## Constraints

- Do not change curation principles or thresholds in `05-curation-criteria.qmd`.
- Do not alter the re-review principles beyond linguistic cleanup and clearer tool usage.
- Add new analysis descriptions in the same style and structure as existing analysis sections.
- Focus substantive edits on tool usage, current runtime/tooling facts, screenshot automation, documentation structure, and documentation design.
- Treat generated screenshot production images as documentation assets, not Playwright failure artifacts.
- For issues #51 and #52, add explanatory prose and examples only. Do not introduce new curation categories, thresholds, ontology terms, or decision rules.

## Evidence From Documentation Issues #49-#52

Four older open documentation issues are narrow enough to address in the first content-update PR, while still respecting the curation guardrails.

### Issue #49: Browser Console Bug Reports

Issue #49 asks for a description of how to check and report bugs using the console of Chromium browsers and how to write a minimal problem report.

Current state:

- `documentation/02-web-tool.qmd` has a short "Reporting bugs, problems and making feature requests" section.
- It already asks users to describe the affected page/input and provide screenshots.
- It includes a screenshot about saving console logs, but the prose is too thin and does not define a minimal useful report.

Recommended content addition:

- Keep the support email and existing Help & Feedback path.
- Add a short subsection titled "Minimal problem report".
- Ask for:
  - page URL or route,
  - date/time and browser,
  - logged-in role if relevant,
  - exact steps,
  - expected result,
  - observed result,
  - visible error message,
  - console errors,
  - whether the problem repeats after reload.
- Add a Chromium console workflow:
  - open Developer Tools with `F12`, `Ctrl+Shift+J`, or browser menu,
  - select the Console tab,
  - reproduce the issue,
  - right-click and save or copy console output,
  - avoid sending passwords, tokens, personal identifiers, or unpublished patient-level details.

Style:

- Practical user-support text, not developer troubleshooting.
- Avoid asking non-technical users to inspect network payloads unless support requests it.

### Issue #50: Finding A PMID For A GeneReviews Article

Issue #50 asks for a GitHub Pages description of how to find the PMID for a GeneReviews article.

Current state:

- `documentation/06-re-review-instructions.qmd` tells reviewers to add a GeneReviews PMID when available.
- It does not explain how to find that PMID.

Recommended content addition:

- Add a short "Finding the PMID for a GeneReviews article" subsection near the current GeneReviews instruction.
- Explain that GeneReviews chapters are hosted in NCBI Bookshelf and indexed in PubMed.
- Give two workflows:
  - From GeneReviews/NCBI Bookshelf: open the chapter and look for the citation box or metadata near the chapter title/footer; record the PubMed PMID when present.
  - From PubMed: search the condition name plus `GeneReviews`, open the PubMed record, and copy the PMID shown in the record.
- Tell reviewers to use the chapter-specific PMID, not the general GeneReviews collection PMID, when a chapter-specific PubMed record exists.
- If no chapter-specific PMID can be found, note this in the review comment rather than forcing an unrelated PMID.

Source note:

- NCBI Bookshelf states that GeneReviews chapters are indexed in PubMed. See https://www.ncbi.nlm.nih.gov/books/NBK1116/toc/.
- PubMed records show the PMID and can link back to GeneReviews/NCBI Bookshelf. Example collection record: https://pubmed.ncbi.nlm.nih.gov/20301295/.

### Issue #51: Variant Ontology Curation Description

Issue #51 asks for a description of how variant ontology curation is done.

Current state:

- `documentation/04-database-structure.qmd` says SysNDD uses the Variation Ontology for annotation of variation effects and mechanisms.
- `documentation/06-re-review-instructions.qmd` asks the synopsis to include the nature of reported variants.
- The reviewer-facing workflow does not explain how to choose or document variant ontology information.

Recommended content addition:

- Add a concise reviewer-facing section in `documentation/06-re-review-instructions.qmd`, with a cross-reference from `documentation/04-database-structure.qmd`.
- Describe the purpose: variant ontology terms standardize the molecular consequence or mechanism reported for an entity so that variants can be compared across entities and analyses.
- Keep the process descriptive:
  - read the publication/GeneReviews/OMIM wording,
  - identify the variant class or mechanism actually supported by the source,
  - select the closest existing SysNDD variation ontology term,
  - prefer the more specific term when the source is explicit,
  - use broader wording or a curator comment when the literature is heterogeneous or ambiguous,
  - do not infer a mechanism beyond the source text.
- Give examples without changing allowed terms:
  - recurrent missense variants reported with a gain-of-function mechanism should be captured with the matching existing mechanism/effect term if present;
  - truncating variants causing loss of function should be captured with the matching existing loss-of-function/truncating concept if present;
  - mixed missense and truncating reports with no proven common mechanism should be described conservatively in the synopsis/comment rather than over-specific ontology assignment.

Guardrail:

- The documentation should not introduce or rename ontology terms. It should point to the SysNDD API endpoint and VariO/OLS for the authoritative term list.

### Issue #52: Explaining The "n.a." Category

Issue #52 asks for a better explanation of the "not applicable" category with examples.

Current state:

- `documentation/05-curation-criteria.qmd` has a short "Special case: non-NDD entities" section.
- `documentation/06-re-review-instructions.qmd` says non-ID disorders will not go into any category but will be tagged with "n.a.".
- The meaning is correct but under-explained.

Recommended content addition:

- Expand the existing "Special case: non-NDD entities" section without changing the rule.
- Define `n.a.` as a tag for gene-disease-inheritance entities that are deliberately retained in SysNDD context because the gene has other NDD-relevant entities, but where the specific entity under review does not meet the SysNDD NDD scope.
- Make clear that `n.a.` is not a lower evidence category and not equivalent to "Limited" or "Refuted".
- Explain the decision contrast:
  - Category 1/2/3 asks how strong the evidence is for an NDD entity.
  - `n.a.` says the entity itself is outside the NDD classification scope.
  - "Refuted" says the proposed association should no longer be retained because evidence argues against it.
- Add examples:
  - A gene has one entity with early-onset developmental delay/ID and another well-established entity without cognitive impairment; the non-NDD entity is retained for gene context and tagged `n.a.`.
  - A disorder is mainly adult-onset or organ-specific and the literature does not show ID/NDD in a significant fraction; tag `n.a.` if retained as a separate entity.
  - A disorder includes motor delay only, with no evidence for cognitive impairment or early neurodevelopmental disorder; consider `n.a.` rather than Category 3 when the issue is scope, not weak evidence.
  - Do not use `n.a.` when there is weak but plausible NDD evidence; use Category 2/3 according to the existing criteria.
  - Do not use `n.a.` when the old association is contradicted by newer evidence; consider "Refuted" according to the existing criteria.

Guardrail:

- Keep this as explanatory text and examples. Do not change the NDD definition, thresholds, or entity inclusion rules.

## Evidence From Issue #140

Issue #140 asks to automate Quarto documentation screenshot generation with Playwright so images stay synchronized with production/development UI. The issue records the current state as:

- 57 screenshot images in `documentation/static/img/`.
- Manual callouts, arrows, and labels.
- Screenshots drift as the UI evolves.
- Inconsistent screenshot styling.
- Time-consuming manual updates.

It proposes a manifest-driven pipeline:

- Playwright captures raw screenshots.
- A post-processing layer adds labels/arrows/callouts.
- Sharp optimizes final images.
- A GitHub Actions workflow can run manually, weekly, or on UI changes.

That architecture is still the right target, with one adjustment: for SysNDD, the first stable implementation should be local/manual rather than CI-auto-generated, because reliable captures need the app, API, database, fixture data, and role-based auth state.

## Current Documentation State

### Quarto Structure

The documentation is a Quarto book:

- Source: `documentation/*.qmd`
- Config: `documentation/_quarto.yml`
- Output: `documentation/_book`
- Deploy workflow: `.github/workflows/gh-pages.yml`

The current navigation is coherent at a high level:

- Overview
- Using SysNDD
- Curation
- Project
- References

The main gap is that the documentation has not kept pace with the application rewrite and operations changes. The book contains older product descriptions beside newer development/deployment chapters.

### Content Freshness Issues

High-priority factual drift:

- `documentation/02-web-tool.qmd` says the frontend uses Vue.js v2.6, BootstrapVue, and Bootstrap v4. Current `app/package.json` uses Vue 3, Bootstrap 5, and Bootstrap-Vue-Next.
- `documentation/02-web-tool.qmd` still describes a "simple Bootstrap v4 website" and older mobile stacked table behavior. Current SysNDD has a much more deliberate clinical/table-first design language.
- `documentation/03-api.qmd` says the API runs in `rocker/tidyverse` R 4.2.0, is bundled through HAProxy, and rate limited by NGINX. Current production config uses Traefik and current container/runtime patterns.
- `documentation/03-api.qmd` says all endpoints live in one API script. Current API startup sources modular functions/core/services/endpoints.
- `documentation/04-database-structure.qmd` says MySQL 8.0 / image 8.0.29 and shows a schema dated 2022-06-07. Current compose uses MySQL 8.4.9.
- `documentation/02-web-tool.qmd` has `*-content coming soon-*` for NDD Publications even though the app and existing orphan screenshot indicate that surface exists.

Medium-priority structure/design drift:

- Several chapters include a redundant `---` horizontal rule immediately after YAML front matter.
- `documentation/10-visual-design-guide.md` is not part of Quarto navigation and is not listed in `documentation/README.md`.
- `documentation/styles.css` hardcodes Bootstrap default blue/dark gray and broad table overrides rather than the current quiet clinical design tokens.
- `documentation/SysNDD_documentation.log`, `_book/`, and `_site/` appear in the documentation tree and should be checked against ignore/build artifact expectations.

Low-priority language cleanup:

- Use `API`, `JavaScript`, `Docker`, `email`, `resources`, and `external and internal` consistently.
- Fix typos such as `teh`, `maxOS`, `externala nd`, `ressources`, and awkward phrasing in the re-review introduction.
- Prefer current user-facing route names over older modal/page labels where the app has changed.

## Screenshot Inventory

The current image directory contains 59 files:

- 57 documentation screenshots/icons.
- 2 brand assets: favicon and cover image.
- 58 files are referenced by current docs/config.
- 1 screenshot is orphaned: `documentation/static/img/02_18-sysndd.dbmr.unibe.ch_NDDpublications.png`.

Reference map:

- `02-web-tool.qmd`: 40 screenshots.
- `03-api.qmd`: 6 API/Swagger screenshots.
- `04-database-structure.qmd`: 1 DB schema image.
- `06-re-review-instructions.qmd`: 10 re-review screenshots/icons.
- `_quarto.yml`: favicon and cover image.

The image dimensions strongly indicate manual capture/crop/export:

- Landing/navigation: `4318x1851`, `3638x607`, `3638x1140`.
- Tables/detail pages: mostly `1058x409-513`, plus large full-page shots up to `4055x1525`.
- Analysis pages: `3637-3856` wide by `1451-1832`.
- Mobile/PWA: `750x1334`, `1334x750`, `1440x2993`, `1440x3120`.
- API screenshots: `2015x919` to `3700x1337`.
- Re-review screenshots: mostly manually cropped `1000px` wide images and small icon crops.

All PNG screenshots share a timestamp cluster around `2026-02-01 03:07`, which looks like a bulk import rather than per-route generated assets.

### Likely Stale Or Manual Images

High-confidence manual/annotated groups:

- Landing and navigation: `02_01` through `02_06`.
- Public web guide annotations: `02_09...AdditionalFeatures`, `02_11` through `02_16`, `02_19...HelpFeedback`, `02_20`, `02_21`, `02_33`, `02_34`.
- API auth flow: `03_03-api-authorize-a.png` through `03_06-api-authorize-d.png`.
- Re-review flow: `sysndd_login_page.png`, `sysndd_refresh_token.png`, `sysndd_review_page.png`, `modal_modify_review.png`, `modal_modify_status.png`, `modal_submit_re-review.png`.
- PWA install flow: `02_28` through `02_32`; these are inherently OS/browser-specific and age poorly.
- DB schema: explicitly dated 2022-06-07 in the text.

### Missing Screenshot Provenance

There is no manifest or metadata that records:

- Source route or URL.
- Capture selector/clip/full-page mode.
- Viewport.
- Auth role.
- Fixture setup.
- Wait condition.
- Browser version.
- App version.
- Git SHA.
- Capture timestamp.
- Whether callouts were generated or manually drawn.

This absence is the core maintenance failure. Replacing the images without adding provenance would only reset the clock.

## Existing SysNDD Automation Assets

SysNDD already has much of the infrastructure required for deterministic screenshot generation:

- Playwright dependency in `app/package.json`.
- E2E config in `app/playwright.config.ts`.
- Local-only Playwright stack in `Makefile`.
- Deterministic Playwright users seeded from `db/fixtures/playwright_users.sql`.
- Auth fixtures in `app/tests/e2e/fixtures/auth.ts`.
- Current design audit screenshots under `.planning/screenshots/`.
- Visual design guidance in `documentation/10-visual-design-guide.md`.

The current docs explicitly say committed Playwright screenshots are not part of the normal E2E suite. That remains correct for failure/debug artifacts, but documentation screenshots need a separate lane with a separate policy.

## VarLens Comparison

The sibling repo is `/home/bernt-popp/development/VarLens`, not lowercase `../varlens`.

VarLens has a working screenshot automation pattern:

- `package.json` defines `docs:screenshots`.
- `Makefile` defines `docs-screenshots`, depending on build prerequisites.
- `tests/e2e/screenshots.e2e.ts` launches the compiled Electron app, imports deterministic demo data, navigates through views, injects overlays, and writes PNGs to `docs/public/screenshots`.
- `docs/public/screenshots/*.png` are intentionally committed and served by VitePress as `/screenshots/...`.
- `.github/workflows/docs.yml` builds screenshots in a dedicated job, uploads them as artifacts, then downloads them before building docs.
- The screenshot generator uses stable screenshot slugs like `variant-table`, `app-layout`, and `status-bar`.
- Annotations are DOM overlays (`.screenshot-highlight`), not manual image edits.
- Specialized screenshots can emit bounding-box JSON for post-processing.

What SysNDD should adopt:

- A named docs screenshot command.
- Stable screenshot slugs.
- A deterministic data/user setup phase.
- DOM-generated callouts instead of manual drawing.
- A generated provenance manifest.
- CI artifact handoff only after the local workflow is stable.

What SysNDD should not copy directly:

- VarLens' Electron launch model. SysNDD needs the web app plus API plus DB.
- VitePress public asset paths. SysNDD uses Quarto and `documentation/static/img`.
- Always-on CI screenshot generation at the start. SysNDD's stack is heavier and more failure-prone in CI.

## External Research Notes

Relevant current documentation practices:

- Playwright's screenshot API supports page, full-page, element, clip, and buffer capture. Buffer capture enables post-processing before writing final images.
- Playwright visual comparisons are useful for regression testing, but docs production screenshots should be treated separately from `toHaveScreenshot()` baselines. Playwright warns that screenshots differ across OS, browser, fonts, hardware, and headless modes, so deterministic environments matter.
- Playwright supports `stylePath` during screenshot assertions to hide volatile elements. The same idea should be used in docs captures through injected CSS for timestamps, user names, dynamic counts, or sensitive values.
- `shot-scraper` is purpose-built for documentation screenshots and supports YAML multi-shot configs, selectors, JavaScript hooks, viewport size, quality, wait, and `wait_for`. It is a credible alternative for static public pages.
- Quarto websites/books centralize navigation and visual style in `_quarto.yml` and render all configured chapters. SysNDD can keep the book model and modernize CSS/navigation without migrating tooling.
- Kong's docs-as-code screenshot automation write-up supports the same general lesson: hide or control internal/dynamic UI through automation instead of repeated manual browser/devtools work.

Sources:

- Playwright Screenshots: https://playwright.dev/docs/screenshots
- Playwright Visual Comparisons: https://playwright.dev/docs/test-snapshots
- shot-scraper multi-shot docs: https://shot-scraper.datasette.io/en/1.4/multi.html
- Quarto websites/books workflow: https://quarto.org/docs/websites/
- Kong screenshot automation case study: https://konghq.com/blog/engineering/docs-as-code-screenshot-automation

## Recommended Documentation Architecture

### Documentation Structure

Keep the existing Quarto book and revise within the current structure:

- `index.qmd`: tighten preface and scope language.
- `01-intro.qmd`: review for current project summary and references.
- `02-web-tool.qmd`: split into current UI guide sections with generated screenshots.
- `03-api.qmd`: update current Plumber/OpenAPI/runtime/auth usage.
- `04-database-structure.qmd`: update MySQL/runtime/schema text and decide whether DB Designer remains authoritative.
- `05-curation-criteria.qmd`: preserve criteria; only grammar, formatting, and readability cleanup.
- `06-re-review-instructions.qmd`: update screenshots and tool usage wording while preserving review principles.
- `07-tutorial-videos.qmd`: either update with current video/status guidance or mark as intentionally pending.
- `08-development.qmd`: add docs screenshot generation workflow.
- `09-deployment.qmd`: add operator guidance only if screenshot/docs deployment behavior changes.
- `10-visual-design-guide.md`: either include in Quarto navigation as a project appendix or reference clearly from `README.md` and development docs.

### Documentation Design

Apply a restrained design overhaul:

- Keep the docs quiet, clinical, and readable.
- Use the visual guide's current palette direction rather than Bootstrap default blue.
- Avoid marketing hero sections, decorative gradients, and card-heavy pages.
- Improve image presentation with consistent max-width classes instead of inline `style="max-width:..."` wrappers.
- Add consistent captions that explain the task/state, not the obvious pixels.
- Prefer screenshots that show the actual interface without browser chrome unless browser/OS UI is the subject.
- Avoid handwritten-looking or inconsistent arrows/callouts.
- Use generated callout dots/boxes only where they reduce text burden.

## Recommended Screenshot Pipeline

### Phase 1: Manifest And Local Generator

Add:

- `app/tests/docs-screenshots/manifest.ts`
- `app/tests/docs-screenshots/docs-screenshots.spec.ts`
- `app/tests/docs-screenshots/overlays.ts`
- `app/tests/docs-screenshots/provenance.ts`

Manifest fields:

```ts
type DocsScreenshot = {
  output: string
  docRef: string
  route: string
  viewport: { width: number; height: number }
  authRole?: 'admin' | 'curator' | 'reviewer' | 'user'
  setup?: string
  waitFor?: string
  locator?: string
  clip?: { x: number; y: number; width: number; height: number }
  fullPage?: boolean
  maskSelectors?: string[]
  annotations?: Array<{
    selector: string
    label?: string
    number?: number
    mode: 'box' | 'dot' | 'callout'
  }>
}
```

Output layout:

- Raw generated screenshots: `documentation/static/img/generated/raw/*.png`
- Annotated generated screenshots: `documentation/static/img/generated/*.png`
- Provenance manifest: `documentation/static/img/generated/screenshot-manifest.generated.json`

The first implementation can write only final PNGs plus provenance if raw/final duplication is too much churn. The key is that callouts must be generated from code, not edited manually.

### Phase 2: Commands

Add an app command:

```json
"docs:screenshots": "playwright test tests/docs-screenshots/docs-screenshots.spec.ts --workers=1"
```

Add root make targets:

```make
docs-screenshots:
	make playwright-stack
	cd app && PLAYWRIGHT_BASE_URL=http://localhost npm run docs:screenshots

docs-screenshots-down:
	make playwright-stack-down
```

For convenience, a later target can wrap teardown with traps, but the first version should make stack lifetime explicit so failed captures are debuggable.

### Phase 3: Verification

Add a lightweight verifier:

- Every `documentation/*.qmd` image reference resolves.
- Every generated image is represented in the generated provenance manifest.
- Every manifest entry has an output file.
- Orphaned legacy screenshots are reported.
- Stale manual screenshots are allowed only while migration is incomplete.

Suggested command:

```bash
node app/scripts/verify-doc-screenshots.mjs
```

or a repo-level script under `scripts/documentation/`.

### Phase 4: CI

Start with manual/local generation. After stable local runs:

- Add a `workflow_dispatch` screenshot job.
- Run Docker-backed SysNDD stack in CI only for screenshot generation.
- Upload generated screenshots as artifacts.
- Build Quarto after artifact download.
- Do not auto-commit screenshots initially.
- Later, consider scheduled generation or PR comments with screenshot diffs.

This is deliberately more conservative than VarLens because SysNDD's screenshot environment depends on more services.

## Screenshot Migration Plan

### Keep Manual Images Temporarily

Do not delete all legacy images in the first automation PR. Instead:

- Add generated images under a new folder.
- Convert a representative subset of docs references first.
- Keep old screenshots until each section is migrated and reviewed.

### Suggested First Capture Set

Start with 8-12 high-value screenshots:

- Home page.
- Entities table.
- Genes table.
- Gene detail page.
- Entity detail page.
- Compare curations overview.
- NDD Publications analysis.
- Functional clusters analysis.
- Login page.
- Review/re-review page as reviewer.
- Modify review modal.
- API Swagger auth screen.

This set proves public, analysis, auth, reviewer, modal, and Swagger capture paths before scaling to all 57.

### Images To Reconsider Rather Than Regenerate

Some current screenshots may not deserve one-for-one replacement:

- PWA install screenshots are browser/OS-specific and may be better documented with text plus one representative capture.
- Tiny icon crops can often be replaced with inline icon names or generated UI button screenshots from the full page.
- The DB schema image should come from an authoritative schema/export pipeline or be clearly marked historical.
- Repeated navigation menu screenshots may be consolidated into fewer task-oriented captures.

## Content Update Plan

### Issue-Driven Documentation Additions

Address issues #49-#52 as a first content-focused documentation change before the broader design overhaul:

- `documentation/02-web-tool.qmd`: expand the bug-reporting section with a minimal problem report checklist and Chromium console-log workflow.
- `documentation/06-re-review-instructions.qmd`: add a GeneReviews PMID lookup subsection near the GeneReviews field instructions.
- `documentation/06-re-review-instructions.qmd`: add reviewer-facing variant ontology curation guidance near the synopsis/publication/GeneReviews guidance.
- `documentation/04-database-structure.qmd`: keep the authoritative ontology-source description, but cross-reference the reviewer-facing variant ontology workflow.
- `documentation/05-curation-criteria.qmd`: expand the "Special case: non-NDD entities" section to explain `n.a.` with examples and contrasts to Category 2/3 and Refuted.

These edits should be treated as documentation clarification, not curation-policy change.

### Web Tool Chapter

Update:

- Frontend stack: Vue 3, TypeScript, Vite, Bootstrap 5, Bootstrap-Vue-Next.
- Public tables and detail pages around the current SectionCard/SWR/cache behavior where user-relevant.
- Mobile behavior to match current purpose-built mobile record rows rather than old stacked Bootstrap tables where applicable.
- Help & Feedback wording and screenshots.
- Performance section with current SEO prerendering and app architecture only where useful for users.

Add:

- NDD Publications section in the same style as the existing analysis subsections.
- New analysis sections only if the app exposes new public analysis views not currently documented.

Preserve:

- User-task orientation.
- Plain, practical prose.
- No marketing-style page copy.

### API Chapter

Update:

- Current R/Plumber API description.
- Modular endpoint/service organization.
- OpenAPI/Swagger UI path.
- Authentication flow with body-only credential transport caveat if user-facing enough.
- Rate-limit/deployment wording to avoid stale HAProxy/NGINX claims unless production config confirms them.

Avoid:

- Over-documenting internal implementation details that are already maintained in `08-development.qmd`, `09-deployment.qmd`, or `AGENTS.md`.

### Database Chapter

Update:

- MySQL version/runtime statement.
- Migration runner and startup migration behavior if relevant to operators.
- Schema image source and freshness policy.

Decision needed:

- Either regenerate the schema diagram from the current schema or explicitly mark the current diagram as historical and link to migrations/current DDL.

### Curation And Re-review

Preserve curation substance:

- Definitions.
- Category thresholds.
- Strong/moderate criteria.
- Negative criteria.
- Moderate/Limited/Refuted conceptual rules.

Allowed changes:

- Grammar and spelling.
- More consistent headings.
- Better lists/tables.
- Clearer "how to use the tool" instructions.
- Clearer examples that explain existing categories and reviewer choices.
- Fresh screenshots of the re-review UI.

Not allowed in this work:

- Changing thresholds.
- Reclassifying evidence criteria.
- Altering the meaning of phenotype inclusion rules.
- Introducing new curation policy without domain approval.
- Adding new variation ontology terms or implying that curators should infer unsupported molecular mechanisms.

## Proposed Work Breakdown

### PR 1: Issue-Driven Documentation Clarifications

- Expand the bug-reporting section for #49.
- Add GeneReviews PMID lookup instructions for #50.
- Add variant ontology curation guidance for #51.
- Expand the `n.a.` explanation with examples for #52.
- Fix only nearby typos or grammar that affect readability.
- Preserve curation criteria substance.

Verification:

- `quarto render documentation`
- Manual review of `05-curation-criteria.qmd` to confirm thresholds and category meanings are unchanged.
- Manual review of `06-re-review-instructions.qmd` to confirm the new sections explain tool usage and source handling only.

### PR 2: Audit Guardrails And First Automation

- Add docs screenshot manifest and generator skeleton.
- Capture first representative public screenshots.
- Emit provenance manifest.
- Add `docs:screenshots` and `make docs-screenshots`.
- Add documentation in `08-development.qmd` for local screenshot generation.
- Do not replace all screenshots yet.

Verification:

- `make playwright-stack`
- `cd app && PLAYWRIGHT_BASE_URL=http://localhost npm run docs:screenshots`
- `quarto render documentation`

### PR 3: Content Freshness Update

- Update web stack claims.
- Update API/runtime claims.
- Update DB runtime claims.
- Add NDD Publications section.
- Fix obvious typos and capitalization.
- Preserve curation criteria substance.

Verification:

- `quarto render documentation`
- link/image reference verifier

### PR 4: Screenshot Migration

- Replace legacy screenshots section by section.
- Remove or archive orphaned/manual screenshots once references are migrated.
- Add generated callouts for screenshots that need labels.
- Update captions and nearby text to match current UI.

Verification:

- `make docs-screenshots`
- image reference verifier
- `quarto render documentation`

### PR 5: Documentation Design Overhaul

- Update `documentation/styles.css` to align with `10-visual-design-guide.md`.
- Normalize image wrappers/classes.
- Decide whether to expose `10-visual-design-guide.md` in Quarto navigation.
- Improve Quarto navigation labels and footer.
- Remove redundant horizontal rules.

Verification:

- `quarto render documentation`
- visual check of generated `_book`
- optionally Playwright screenshot of documentation pages if desired

### PR 6: Optional CI Integration

- Add a manual `workflow_dispatch` screenshot generation job.
- Store generated screenshots as workflow artifacts.
- Build Quarto from generated artifacts.
- Keep deployment separate until stable.

Verification:

- Manual GitHub Actions run.
- Compare local and CI screenshot output.

## Risks And Mitigations

Risk: Screenshot flakiness from dynamic data, cache state, or animations.

Mitigation: Use deterministic Playwright DB fixtures, fixed viewport, explicit waits, injected CSS to hide volatile elements, and one worker.

Risk: CI setup becomes too heavy.

Mitigation: Keep screenshot generation local/manual first. Add CI only after the manifest stabilizes.

Risk: Generated callouts obscure important clinical UI.

Mitigation: Keep clean raw screenshots and generate restrained overlays only where the text explicitly refers to numbered elements.

Risk: Documentation rewrite changes curation meaning.

Mitigation: Treat curation criteria as locked policy. Only copyedit and reformat unless domain owners approve semantic changes.

Risk: One-for-one screenshot replacement keeps obsolete documentation structure alive.

Mitigation: Reassess every screenshot before replacement. Consolidate redundant navigation/PWA/icon shots where text is clearer.

## Acceptance Criteria

Screenshot automation is acceptable when:

- A new contributor can run one documented command to regenerate screenshots locally.
- Each generated image has manifest provenance.
- Images are stable across repeated local runs against the same stack.
- Screenshots use fixed viewport and deterministic fixture state.
- Manual callouts are replaced by generated overlays or removed.
- Docs image references are verified automatically.

Documentation update is acceptable when:

- Stack/runtime descriptions match current repository configuration.
- Issues #49-#52 are addressed with explicit, reviewer/user-facing guidance.
- The `n.a.` text explains scope versus evidence strength versus refutation.
- GeneReviews PMID lookup distinguishes chapter-specific records from the general collection record.
- Variant ontology guidance describes source-based selection without adding terms or mechanisms.
- Bug-reporting guidance gives users a concise minimal report checklist and console-log workflow.
- NDD Publications is documented in the same style as other analysis views.
- Curation criteria content is substantively unchanged.
- Re-review instructions reflect current tool usage.
- The Quarto book renders cleanly.
- The visual design is quieter, more consistent, and aligned with `10-visual-design-guide.md`.

## Final Recommendation

Proceed with a staged documentation modernization rather than a single large rewrite. Start by adding the screenshot manifest/generator and updating the most stale factual claims. Then migrate screenshots section by section, using generated clean captures plus restrained overlays. Keep curation policy stable and make the docs design match the current product: clinical, compact, table-first, and operational rather than decorative.
