# Genes Detail UI/UX Improvement Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve the `/Genes/:symbol` detail page so key evidence cards remain understandable, stable, and accessible from mobile through desktop widths.

**Architecture:** Keep the existing Vue 3, Bootstrap Vue Next, SWR composable, and per-card component architecture. Change the external evidence-card grid from viewport-only three-up behavior to content-aware responsive behavior, and make empty external data a visible section state rather than a collapsed layout gap.

**Tech Stack:** Vue 3, TypeScript, Bootstrap Vue Next, Vite, Playwright, axe, Lighthouse.

---

## Audit Scope

Audited local dev stack on 2026-05-09:

- `http://localhost/Genes/ARID1B`
- `http://localhost/Genes/NAA10`

Playwright viewport sweep:

- Mobile: `390x844`
- Tablet: `768x1024`
- Small laptop: `1024x768`
- Mid desktop: `1280x800`, `1366x768`
- Desktop: `1440x900`
- Wide desktop: `1920x1080`

Artifacts:

- Playwright JSON: `.planning/ui-audit/genes-detail/playwright-audit-accepted.json`
- Screenshots: `.planning/ui-audit/genes-detail/*-accepted.png`
- Lighthouse JSON: `.planning/ui-audit/genes-detail/lighthouse/*.json`
- Lighthouse summary: `.planning/ui-audit/genes-detail/lighthouse-summary.json`

Measurement caveat: Lighthouse was run against Vite dev output, not a production build. The mobile run therefore overstates JavaScript payload and minification issues. The layout, accessibility, and visible UX findings are still valid.

## UX Rating

Overall current rating: **6/10**

- Information value: **8/10**. The page exposes strong gene-centered evidence quickly: identifiers, resources, associated entities, ClinVar, model organisms, and genomic visualization.
- Responsive layout: **4/10**. The external card grid switches to three columns at `md`, which creates cards too narrow for their own content from `768px` through `1366px`.
- Empty states: **4/10**. Missing data collapses sections, so users cannot tell whether a source has no data, is still loading, failed, or was intentionally hidden.
- Accessibility: **6/10**. Lighthouse/axe scores are usable but show serious ARIA, contrast, heading-order, and list-structure issues.
- Performance: **6/10 in dev, likely higher in production**. Desktop Lighthouse is good; mobile dev Lighthouse is poor due mostly to unoptimized dev bundles and a large LCP/CLS event.

## Key Findings

### 1. Gene Constraint Card Does Not Fit Its Grid Column

Current code sets all three external cards to `cols="12" md="4"` in `app/src/views/pages/GeneView.vue:76`, `:91`, and `:110`. Bootstrap `md` begins at `768px`, so each card gets one third of the row from tablet width upward.

Observed ARID1B constraint card:

| Viewport | Card client width | Card scroll width | Result |
| --- | ---: | ---: | --- |
| 390 | 316 | 417 | Internal overflow, mobile card content clipped |
| 768 | 206 | 417 | Severe clipping |
| 1024 | 299 | 417 | Severe clipping |
| 1280 | 385 | 417 | Metrics visibly outside the border |
| 1366 | 413 | 417 | Still tight/overflowing |
| 1440 | 438 | 438 | First clean breakpoint |
| 1920 | 598 | 598 | Clean |

The root cause is not only Bootstrap. `GeneConstraintCard.vue` renders a four-column table plus a flex metrics cell with fixed-width SVG bars and inline confidence interval text (`app/src/components/gene/GeneConstraintCard.vue:35`, `:43`, `:50`). That content has a natural minimum width around 417px, so a one-third `md` column cannot reliably contain it.

Screenshots:

- `.planning/ui-audit/genes-detail/ARID1B-tablet-768-accepted.png`
- `.planning/ui-audit/genes-detail/ARID1B-mid-1280-accepted.png`
- `.planning/ui-audit/genes-detail/ARID1B-mid-1366-accepted.png`

### 2. Empty External Sections Collapse

`SectionCard` explicitly renders nothing when `empty=true` (`app/src/components/ui/SectionCard.vue:6-10`, `:102`). `GeneView.vue` passes `empty=true` for missing gnomAD constraints, zero ClinVar counts, and empty model-organism results (`app/src/views/pages/GeneView.vue:80`, `:95`, `:114`).

NAA10 shows this clearly: `Gene Constraint (gnomAD)` is absent at every audited viewport. At `1280px`, ClinVar and Model Organisms appear centered on the row, leaving no visible indication that gnomAD was checked and had no available constraint data.

This is a trust problem for scientific users. Missing evidence is itself meaningful metadata. A user should be able to distinguish "no gnomAD constraint data available" from "this card never loaded" or "this source is not part of the page".

Screenshot:

- `.planning/ui-audit/genes-detail/NAA10-mid-1280-accepted.png`

### 3. Layout Stability Regresses At Smaller Widths

Lighthouse CLS worsens as the external cards and associated-entities table reflow:

| Page / viewport | Performance | Accessibility | Best Practices | SEO | FCP | LCP | TBT | CLS | Speed Index |
| --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- | --- |
| ARID1B mobile 390 | 40 | 92 | 100 | 100 | 1.6s | 41.5s | 380ms | 0.425 | 6.3s |
| ARID1B tablet 768 | 85 | 93 | 100 | 100 | 0.4s | 1.3s | 10ms | 0.226 | 0.8s |
| ARID1B mid 1280 | 91 | 90 | 100 | 100 | 0.4s | 1.2s | 10ms | 0.152 | 0.8s |
| ARID1B desktop 1440 | 95 | 90 | 100 | 100 | 0.4s | 1.3s | 10ms | 0.09 | 0.8s |
| NAA10 mid 1280 | 94 | 90 | 100 | 100 | 0.4s | 1.4s | 10ms | 0.085 | 0.8s |

The `NAA10` mid-width CLS is lower partly because the missing gnomAD card collapses. That improves a metric while making the page less informative. The fix should reserve an explicit empty-card surface instead of removing the section.

### 4. Accessibility Issues Are Real And Reproducible

Lighthouse/axe recurring failures:

- `aria-prohibited-attr`: hundreds of SVG shapes use `aria-label` on elements like `<rect>` without an appropriate role.
- `color-contrast`: muted labels such as `RESOURCES`, `IDENTIFIERS`, and chromosomal location text are slightly below WCAG contrast thresholds.
- `heading-order`: `Genomic Visualizations` appears as an `h6` without a coherent page heading hierarchy.
- `list`: navbar search combobox is a `div` directly inside `ul.navbar-nav`.
- `page-has-heading-one`: axe reports no page-level `h1`.

These are not only Lighthouse score issues. They affect keyboard/screen-reader comprehension and semantic structure.

## Research Notes

- Lighthouse performance score is a weighted metric score, not a direct sum of opportunity warnings; Chrome documents Lighthouse 10 weights as FCP 10%, Speed Index 10%, LCP 25%, TBT 30%, and CLS 25%. Scores from 90-100 are green, 50-89 need improvement, and 0-49 are poor. Source: Chrome Lighthouse performance scoring, https://developer.chrome.com/docs/lighthouse/performance/performance-scoring.
- Lighthouse accessibility score is a weighted average of binary audits; partial failure on an audit still fails that audit. Source: Chrome Lighthouse accessibility scoring, https://developer.chrome.com/docs/lighthouse/accessibility/scoring/.
- WCAG Reflow allows two-dimensional scrolling for true data tables, but individual cells and surrounding text still need to fit; disappearing content when reflowed is called out as a common failure. Source: W3C WCAG 2.2 Understanding Reflow, https://www.w3.org/WAI/WCAG22/Understanding/reflow.html.
- Bootstrap’s `md` breakpoint starts at `768px`, `xl` at `1200px`, and `xxl` at `1400px`; using `md=4` makes a three-column layout far earlier than this card content can support. Source: Bootstrap grid documentation, https://getbootstrap.com/docs/5.0/layout/grid/.
- Responsive breakpoints should serve the content. web.dev frames media queries as a starting point for layout adaptation and documents `min-width` queries as "at least" that width. Source: web.dev media queries, https://web.dev/learn/design/media-queries.
- Empty states should communicate that the system is working, explain no data/no results, and guide next steps. Source: AIA Design System empty state guidance, https://design.aia.com/component/empty-state.

## Recommended Direction

Use a two-part design change:

1. **Make the external evidence grid content-aware.** Keep one column on mobile, use two columns through normal laptop/mid-desktop widths, and only use three columns when each card has enough inline space.
2. **Render explicit section-level empty states.** Keep the card frame for source-level absence and show concise, source-specific copy.

This directly fixes the reported `1300px` constraint-card overflow and the NAA10 hidden-card confusion without changing the data-fetching architecture.

## Implementation Plan

### Task 1: Add A Persistent Empty State To SectionCard

**Files:**

- Modify: `app/src/components/ui/SectionCard.vue`
- Modify tests: `app/src/components/ui/__tests__/SectionCard.spec.ts`

- [ ] Add props to `SectionCard`: `emptyMode?: 'collapse' | 'message'`, `emptyMessage?: string`, and optional `emptyDetail?: string`.
- [ ] Keep the default `emptyMode` as `'collapse'` to avoid changing every existing caller.
- [ ] When `empty && emptyMode === 'message'`, render a card with the normal title, a subdued icon, `emptyMessage`, and optional `emptyDetail`.
- [ ] For `frameless=true`, still render a framed empty card so the layout keeps its source slot visible.
- [ ] Add unit tests for default collapse behavior and new message behavior.

Acceptance criteria:

- Existing `SectionCard` callers remain unchanged unless they opt in.
- Empty message cards expose the section title in the card header.
- The component has no invisible empty placeholder; users can read what happened.

### Task 2: Use Visible Empty Cards On GeneView External Sources

**Files:**

- Modify: `app/src/views/pages/GeneView.vue`
- Modify tests: `app/src/views/pages/__tests__/GeneView.spec.ts`

- [ ] Set `emptyMode="message"` for the three external sources on the gene detail page.
- [ ] Use source-specific messages:
  - gnomAD: `No gnomAD constraint data available for this gene.`
  - ClinVar: `No ClinVar variants returned for this gene.`
  - Model organisms: `No mouse or rat phenotype data returned for this gene.`
- [ ] Keep error states visually distinct from empty states; empty means the source responded or the database has no value, error means retrieval failed.
- [ ] Add a NAA10-style test case proving the gnomAD card title remains visible when `gnomad_constraints` is null.

Acceptance criteria:

- `http://localhost/Genes/NAA10` visibly includes a Gene Constraint card with a no-data message.
- Empty cards do not imply failure and do not use danger styling.
- Layout remains stable when a source has no data.

### Task 3: Change The External Evidence Grid Breakpoints

**Files:**

- Modify: `app/src/views/pages/GeneView.vue`
- Optionally create scoped CSS in the same file if Bootstrap props are not expressive enough.

Recommended Bootstrap-only change:

- [ ] Change each external card column from `cols="12" md="4"` to `cols="12" lg="6" xxl="4"`.
- [ ] Keep `mb-2`; add `gy-2` to the row if vertical spacing needs to be explicit.

Rationale:

- `lg=6` gives two columns from `992px` through `1399px`, so the constraint card has enough width at 1024, 1280, and 1366.
- `xxl=4` restores three columns at `1400px+`, matching the observed clean breakpoint.

Acceptance criteria:

- At `1280x800`, ARID1B Gene Constraint card client width is at least 440px or no card/card-body horizontal overflow is detected.
- At `1366x768`, the metrics and confidence interval text stay inside the border.
- At `1440x900`, three columns are allowed if the card remains clean.

### Task 4: Redesign GeneConstraintCard For Narrow Containers

**Files:**

- Modify: `app/src/components/gene/GeneConstraintCard.vue`
- Add/modify tests: create `app/src/components/gene/GeneConstraintCard.spec.ts` if one does not exist.

- [ ] Replace the single always-table layout with a responsive internal layout.
- [ ] For wide card widths, keep the current table-like comparison.
- [ ] For narrow card widths, render each category as a compact metric block:
  - Category label
  - Expected and observed SNV stat pair
  - Z and o/e stat pair
  - CI bar with confidence interval below or beside it based on available width
  - pLI only on pLoF when present
- [ ] Avoid fixed pixel assumptions except the small SVG bar; let the bar use `width: 100%` with a bounded max width.
- [ ] If keeping a table, wrap it in a dedicated `.table-responsive` container and ensure individual cells do not clip text. Prefer the metric-block layout because it is easier to scan on mobile.

Acceptance criteria:

- At `390px`, no content bleeds beyond the Gene Constraint card.
- At `768px`, no metric text overlaps adjacent cards or card borders.
- At `1280px`, the card looks deliberate, not like a squeezed desktop table.

### Task 5: Reduce CLS Caused By Late Data And Empty Collapses

**Files:**

- Modify: `app/src/views/pages/GeneView.vue`
- Modify: `app/src/components/ui/SectionCard.vue`

- [ ] Keep minimum heights consistent between loading, empty, error, and loaded states for the external cards.
- [ ] Do not collapse a source card after loading if it was visible as a skeleton.
- [ ] Keep associated entity table behavior unchanged unless table overflow remains a major contributor after external-card fixes.

Acceptance criteria:

- Lighthouse CLS improves at `768px` and `1280px`.
- There is no sudden row re-centering when one external source has no data.

### Task 6: Fix The Highest-Impact Accessibility Failures

**Files to inspect first:**

- `app/src/components/gene/GeneStructurePlot*.vue`
- `app/src/composables/useD3GeneStructure.ts`
- `app/src/components/gene/GeneStructurePlotWithVariants.vue`
- `app/src/components/AppNavbar.vue`
- `app/src/views/pages/GeneView.vue`
- `app/src/components/gene/ClinicalResourcesCard.vue`
- `app/src/components/gene/IdentifierCard.vue`

- [ ] Replace prohibited SVG `aria-label` usage on raw shapes with valid accessible SVG patterns: either add appropriate roles/focusability where shapes are interactive, or mark decorative shapes `aria-hidden="true"` and expose the accessible detail through grouped elements, tooltips, or adjacent text.
- [ ] Increase muted label contrast for small text such as `RESOURCES`, `IDENTIFIERS`, and chromosome location.
- [ ] Add a coherent page-level heading, visually compact if needed, so the gene page has an `h1`.
- [ ] Fix navbar list semantics so direct children of `ul` are `li` elements.
- [ ] Re-run axe and Lighthouse accessibility after changes.

Acceptance criteria:

- Lighthouse accessibility score is at least 95 for ARID1B at `1280x800`.
- `aria-prohibited-attr`, `heading-order`, and `list` no longer fail on the gene page.
- Color contrast failures for header metadata are resolved.

### Task 7: Verify With Browser And CI Checks

**Commands:**

- [ ] `cd app && npx vitest run src/components/ui/__tests__/SectionCard.spec.ts src/views/pages/__tests__/GeneView.spec.ts`
- [ ] `cd app && npm run type-check`
- [ ] `cd app && npm run test:unit`
- [ ] `cd app && npx playwright test app/tests/perf/genes-entities.bench.spec.ts` if the local stack is running and the path is valid from repo root; otherwise run the existing perf bench from `app` with the correct relative path.
- [ ] Re-run the viewport sweep for `ARID1B` and `NAA10`.
- [ ] Re-run Lighthouse for `390`, `768`, `1280`, and `1440` widths.

Acceptance criteria:

- ARID1B has no Gene Constraint card overflow at audited widths.
- NAA10 visibly shows a no-data Gene Constraint card.
- Lighthouse desktop performance stays green.
- Lighthouse accessibility improves or at least does not regress while remaining above 90.

## Success Metrics

- ARID1B Gene Constraint card no longer reports `scrollWidth > clientWidth` at `390`, `768`, `1024`, `1280`, or `1366`.
- NAA10 body text includes `Gene Constraint (gnomAD)` and the no-data message at every audited viewport.
- CLS at ARID1B `1280x800` drops below `0.10`; `768x1024` drops below `0.15`.
- Lighthouse accessibility at ARID1B `1280x800` improves from `90` to at least `95`.
- The page still exposes the three external evidence domains above genomic visualizations.

## Handoff Notes

Prioritize Tasks 1-3 first. They address the two observed UX problems with the least risk. Task 4 is the deeper responsive polish that prevents the constraint card from depending on row width alone. Tasks 5-6 should follow after layout behavior is stable, because the empty-card change may improve CLS and reveal the remaining accessibility issues more clearly.
