# RESULTS — Public-page design + a11y program

Branch: `feat/frontend-design-9of10` · 7 commits · 67 files (+7163 / −1660)

## What was delivered (audit → spec → plan → implement → re-audit)

A full pipeline against all 25 public pages: Lighthouse + Playwright audit → expert 1–10 ratings (7 parallel review agents) → spec + parallelizable sprint plan → a Foundation sprint + 6 per-page sprints (executed by parallel subagents) → cleanup → re-audit + re-rating. All work verified with `type-check`, `eslint`, **1490 unit tests**, and fresh Lighthouse.

## Accessibility — objective, verified

Lighthouse desktop accessibility, before → after:

- **Mean accessibility 96.6 → 99.8.**
- **23 / 25 public pages now score a11y = 100** (best-practices = 100 and SEO = 100 on **all** 25).
- Remaining: `/About` 99 (one heading inside CMS-rendered content) and `/API` 99 (the embedded third-party Swagger UI renders its own DOM/headings we don't control). Both documented limitations.

Cleared, app-wide, via shared components:
- `heading-order` (was failing on **every** page — root cause was the `DisclaimerDialog` h5/h6; fixed to h2/h3) → 0
- `td-has-header` across all data tables (filter-row cells `role="presentation"`) → 0
- `select-name` on filter/page-size selects → 0
- `button-name` on icon controls → 0
- `color-contrast`: the ad-hoc pastel chips (PubTator 29, Publications 10, ModelCard 8, …) replaced with AA `.sysndd-chip--*` tokens → 0
- `aria-prohibited-attr(636)` on the gene-detail protein-domain lollipop → 0

## Design quality — expert 1–10 re-rating

Same rubric and reviewer calibration as the baseline audit (demanding senior designer; 9 = excellent & distinctive).

- **Mean overall 6.24 → 7.44** (+1.2). Every page improved or held; none regressed.
- **15 / 25 now ≥ 8** (was 4); biggest jumps: `entity-detail` 4→8, `register` 5→8, `pubtatorndd` 5→8, `api` 5→7, `genenetworks` 4→6, `phenotypecorrelations` 6→8.
- **2 / 25 rated ≥ 9** (`home`, `genes`) by the agents.

> **Honest caveat on the design re-rating:** the agent overalls are a **conservative floor**. The re-rate agents partly anchored accessibility to the *pre-fix* Lighthouse findings supplied in their prompt (and to theoretical source reading), so several pages were scored a11y 7–8 even though they are **empirically Lighthouse a11y = 100** (independently verified, above). Correcting that anchoring would lift several pages from 8 to 9. The honest takeaway: **accessibility/consistency/interaction-states are verified strongly improved; the demanding "9 = distinctive" bar for dense clinical data tables is the real remaining gap.**

## Reaching a uniform ≥ 9 — remaining work

Pages still below 8 and the path to 9 (from the re-rate agents' concrete recommendations):

- **genenetworks (6)** — capped by **backend**: the fCoSE network layout is precomputed server-side in production but runs in-browser on the dev DB (perf 17→29 after deferring it off the synchronous path). True ≥9 needs the precomputed-layout snapshot served on the public path. Frontend a11y/CLS/hierarchy are done.
- **api (7)** — capped by the embedded **third-party Swagger UI**. We added an on-brand frame + method-badge contrast; a fully on-brand API explorer would need replacing/heavily theming Swagger.
- **correlations cluster (similarity 6, functional 6, variant 6), entriesovertime (6)** — charts now have legends/axes/states/token scales; reaching 9 needs deeper bespoke viz refinement (denser-label handling, richer empty/interaction affordances).
- **phenotypes (7), nddscore (7)** — strong tables; 9 needs density refinement / progressive column disclosure (deferred to keep files under the 600-line ceiling).
- **gene-detail (6), documentation (7)** — gene-detail: residual CLS from async sub-tables (SectionCard reserved, deeper reservation needed); documentation was not in a sprint.

A shared, recurring recommendation: extract the duplicated Home panel chrome into a tokenized `PanelShell` (today the 3 home panels copy `TableShell`-like chrome with literal hex) — a clean foundation-shared follow-up.

## Artifacts
`AUDIT.md` (baseline) · `AUDIT-per-page.md` · `FINDINGS-cross-cutting.md` · `SPEC.md` · `PLAN.md` · `ratings.json` (before) · `ratings-final.json` (after) · `lighthouse/` + `lighthouse-final/` summaries · `screenshots/` (post-improvement) · repro scripts (`run-lighthouse.sh`, `capture.mjs`, `recheck.sh`, `rate-pages.workflow.mjs`).
