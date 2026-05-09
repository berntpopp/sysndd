# Genes Detail UI/UX Fixes Design

## Goal

Fix the highest-impact `/Genes/:symbol` detail-page UI/UX regressions found in the 2026-05-09 audit, with focused validation on `/Genes/ARID1B` and `/Genes/NAA10`.

The page must preserve the current Vue 3 + TypeScript + Bootstrap Vue Next architecture, the v11.3 SWR/composable data-fetching model, and the entities-first mount behavior. This work changes presentation, layout, and accessibility semantics only.

## Current Findings

The source audit is `.planning/superpowers/plans/2026-05-09-genes-detail-ui-ux-plan.md`. It measured the local dev stack at `390`, `768`, `1024`, `1280`, `1366`, `1440`, and `1920` px widths.

Confirmed code points:

- `app/src/views/pages/GeneView.vue` renders external evidence cards as `cols="12" md="4"`, which creates three narrow columns from `768px` upward.
- `app/src/components/gene/GeneConstraintCard.vue` renders a four-column `BTable`; its metrics cell contains inline `Z`, `o/e`, a fixed-width SVG CI bar, interval text, and optional `pLI`.
- `app/src/components/ui/SectionCard.vue` returns nothing for `empty=true`; `GeneView.vue` currently passes `empty=true` for absent gnomAD constraints, zero ClinVar counts, and empty combined model-organism data.
- Compact gene metadata labels in `ClinicalResourcesCard.vue`, `IdentifierCard.vue`, and the gene header use low-contrast muted text.
- The page has no explicit `h1`; `GenomicVisualizationTabs.vue` uses an `h6` section heading.
- Gene visualization SVGs use ARIA labels in places that axe reports as prohibited on raw SVG shapes.
- `AppNavbar.vue` places `SearchCombobox` inside `BNavbarNav`; rendered output can produce an invalid direct `div` child under `ul.navbar-nav`.

Audit distinction:

- Playwright axe artifact includes `page-has-heading-one`.
- Lighthouse `ARID1B-mid-1280` includes `label-content-name-mismatch`, but not `page-has-heading-one`.
- Both artifacts include the page-relevant failures `aria-prohibited-attr`, `color-contrast`, `heading-order`, and `list`.

## Design Direction

Use the audit's recommended direction, with one refinement from review: source-level no-data states should live in the source cards, not in `SectionCard`.

1. Keep all three external source cards mounted after load, including missing external data.
2. Change the external evidence grid from viewport-only three-up behavior to content-aware breakpoints: one column below `lg`, two columns from `lg` through `xl`, and three columns at `xxl`.
3. Redesign the Gene Constraint card internals so the card fits its container instead of relying only on a wider grid.
4. Reserve comparable card space across loading, empty, error, and loaded states to reduce layout shift.
5. Fix accessibility issues that directly touch this page.

The implementation should be a conservative evolution of existing components, not a page rewrite.

## Page Layout

The gene header remains first, followed by the associated entities table, then the external evidence cards, then genomic visualizations.

The external evidence row should use these effective breakpoints:

- `<992px`: one card per row.
- `992px` through `1399px`: two cards per row.
- `>=1400px`: three cards per row if no overflow is detected.

Bootstrap props should be the first choice: `cols="12" lg="6" xxl="4"`. Bootstrap 5 `xxl` starts at `1400px`; the audit's first clean measured width was `1440px`, and the `1400-1439px` band is accepted as the three-up transition range as long as the overflow checks pass.

## Empty And Error States

`SectionCard` should remain a generic state wrapper with its existing collapse behavior for callers that intentionally hide empty content. It should not gain source-specific empty copy for this fix.

For the `/Genes/:symbol` external source row:

- `GeneView.vue` should stop passing `empty=true` for source-level no-data cases.
- Each external source card should mount and decide its own empty body.
- Source card headers and outbound links should stay visible even when no data is available.
- Error states remain visually distinct from empty states.

Required source messages:

- Gene Constraint: `No gnomAD constraint data available for this gene.`
- ClinVar: `No ClinVar variants returned for this gene.`
- Model Organisms: `No mouse or rat phenotype data returned for this gene.`

Empty states should look deliberately neutral, not like loaded data and not like failures. Use a secondary or dashed border treatment, subdued `bg-light` body, and readable contrast. Titles should keep the same weight as loaded cards so the page remains scannable.

Minimum heights should avoid large shifts but not force excessive mobile length. Prefer a responsive value such as `clamp(10rem, 30vw, 16rem)` for external skeletons and card bodies.

## Gene Constraint Card

The Gene Constraint card should become responsive internally and should always own its header, including the gnomAD outbound link.

Required behavior:

- No horizontal clipping or bleed at `390`, `768`, `1024`, `1280`, or `1366` px viewports.
- The `Synonymous`, `Missense`, and `pLoF` categories remain visible and comparable.
- Expected and observed SNV values remain visible.
- `Z`, `o/e`, confidence interval, and pLI remain visible where data exists.
- The gnomAD outbound link remains available in both loaded and no-data states.

Recommended structure:

- Replace the always-table layout with stacked metric rows or blocks that wrap within the card.
- Use CSS grid/flex for each category row: category label, SNV pair, metric pair, and CI summary.
- Use a CI bar that scales to container width, such as `width: 100%; max-width: 8rem`, rather than a layout-driving fixed inline width.
- Put confidence interval text on its own line at narrow widths if needed.
- Use Bootstrap's `sm` breakpoint (`576px`) for single-column metric stacks unless browser verification proves a narrower custom breakpoint is necessary.

A table may be retained only if it is wrapped in a deliberate responsive container and still passes overflow acceptance checks. The metric-block layout is preferred because it gives more control at mobile and tablet widths.

## Layout Stability

The external-card row should not re-center or collapse after a loading skeleton resolves to no data. The source card should occupy the same slot whether loaded, empty, or errored.

Expected metrics:

- ARID1B CLS at `1280x800` should improve from the audited `0.152`, with a target below `0.10`.
- ARID1B CLS at `768x1024` should improve from the audited `0.226`, with a target below `0.15`.
- `1024x768` should be checked because it is the narrowest two-column breakpoint after the grid change.
- If associated-entities table reflow dominates after the external-card fixes, document that residual source instead of broadening this PR.

## Accessibility

Use a state-invariant heading strategy:

- Add one coherent page-level `h1` in `GeneView.vue`. It may be visually compact and placed in the existing gene header. It should include the resolved gene symbol when available.
- Use semantic headings for major page sections only. `Genomic Visualizations` should become an `h2`.
- Generic card wrappers and per-source card titles should not introduce lower-level heading skips. Use non-heading text for card labels unless the full page outline is intentionally updated.
- `SectionCard` loading/error/loaded/empty states must not flip the same title between different heading levels.

Fix the highest-impact audit failures where they touch the gene page:

- Replace prohibited SVG ARIA on raw shapes in the gene visualization path. Decorative shapes should be `aria-hidden="true"`; meaningful SVGs should expose one valid accessible name on the parent SVG or valid grouped interactive elements.
- Increase contrast for compact metadata labels such as `Resources`, `Identifiers`, and chromosome location.
- Ensure navbar search markup has valid list semantics. Direct children of a rendered `ul.navbar-nav` must be `li` elements. Use literal `ul > li.nav-item` for search instead of `BNavItem`, because wrapping a search input in a link would break interaction semantics.
- Fix the page-scoped Lighthouse `label-content-name-mismatch` on model-organism phenotype badges. The audited ARID1B `1280px` culprit is the MGI badge: its visible text is shorter than its `aria-label`.

The target is not a site-wide accessibility rewrite. It is a gene-page cleanup that removes the recurring audit failures for `aria-prohibited-attr`, `color-contrast` on touched metadata labels, `heading-order`, `page-has-heading-one` in the Playwright axe artifact, and `list`.

## Data Flow And Architecture

No API changes are required.

Do not change:

- `useGeneRecord`, `useGeneClinVarCounts`, `useGeneClinVar`, `useGeneAlphaFold`, `useGeneUniProt`, `useGeneMGI`, or `useGeneRGD` semantics.
- SWR caching in `useResource.ts` or `cacheStore`.
- The `TablesEntities` tick-0 mount with URL-derived filter.
- Route shape for `/Genes/:symbol`.
- External source request ordering.

`GeneView.vue` remains the orchestration layer for source card state and layout. `SectionCard` remains the reusable skeleton/error wrapper. Source cards own source-specific empty/no-data presentation.

## Testing Strategy

Use test-first implementation.

Unit/spec coverage:

- `GeneView.spec.ts`: NAA10-style missing `gnomad_constraints` keeps the Gene Constraint title, gnomAD link, and no-data message visible; external card column props/classes reflect `cols=12 lg=6 xxl=4`.
- `GeneConstraintCard.spec.ts`: valid constraint JSON renders the three categories and metrics; null/invalid JSON renders a no-data message; the gnomAD link remains present; rendered markup avoids fixed table-only assumptions.
- Model-organism component tests: phenotype badge accessible names start with or match visible badge text.
- `SectionCard.spec.ts`: current collapse behavior remains pinned. If heading markup is changed in `SectionCard`, test that state transitions do not produce heading-level changes.
- Browser-level Playwright tests should verify rendered DOM semantics for navbar list structure and scoped axe rules.

Browser verification:

- Run local Playwright viewport checks for ARID1B and NAA10 at `390x844`, `768x1024`, `1024x768`, `1280x800`, `1366x768`, `1440x900`, and `1920x1080`.
- Use deterministic visible-page gates instead of `waitUntil: 'networkidle'`.
- Assert no horizontal overflow in the Gene Constraint card and its body.
- Assert NAA10 includes the visible gnomAD no-data state and outbound link at all audited widths.
- Run the existing local-only perf/axe bench and a focused Lighthouse pass.

## Acceptance Criteria

- `/Genes/ARID1B` Gene Constraint content does not overflow its card at `390`, `768`, `1024`, `1280`, or `1366` px.
- `/Genes/NAA10` visibly includes the `Gene Constraint (gnomAD)` card with the gnomAD no-data message and outbound gnomAD link.
- External source cards remain visible for empty data and do not collapse after loading.
- External evidence cards use one column below `lg`, two columns from `lg` through `xl`, and three columns at `xxl`.
- ARID1B CLS improves at `768x1024`, `1024x768`, and `1280x800`; target thresholds are `<0.15` for `768x1024` and `<0.10` for `1280x800`.
- Lighthouse accessibility for ARID1B at `1280x800` reaches at least `95`, or any lower score is explained by a documented unrelated issue outside this page scope.
- `aria-prohibited-attr`, `heading-order`, `page-has-heading-one` in Playwright axe, and navbar `list` failures do not reproduce on the gene page.
- Lighthouse `label-content-name-mismatch` is fixed for the model-organism phenotype badges.
- Frontend lint, type-check, and relevant unit tests pass before handoff.

## Out Of Scope

- API, database, or migration changes.
- Replacing Bootstrap Vue Next.
- Replacing the SWR/composable data layer.
- A full redesign of `/Entities/:entity_id`.
- A site-wide accessibility remediation beyond files touched for the gene page.
- Production bundle optimization for the dev-mode Lighthouse mobile payload warning.
- Shell or unrelated component accessibility failures that remain after page-scoped fixes.

## Spec Self-Review

- Placeholder scan: no unfinished-marker placeholders remain.
- Internal consistency: source cards own source-specific empty states; `SectionCard` stays generic.
- Scope check: the work is a single page-focused UI/UX fix with small shared-component changes only where needed for this page.
- Ambiguity check: breakpoints, empty messages, target pages, accessibility failures, and verification commands are explicit enough for an implementation plan.
