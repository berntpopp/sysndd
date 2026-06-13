# PLAN — Execution (parallelizable sprints)

Branch: `feat/frontend-design-9of10` off `master`. Atomic commits per task. Re-Lighthouse + re-rate per sprint.

File-ownership groups are chosen so parallel agents (isolated worktrees) don't collide on shared files.

## Wave 1 — Sprint 0 Foundation (4 parallel tracks; disjoint file ownership)

### Track A — Shells & headings  (owns: `components/table/TableShell.vue`, `components/analyses/AnalysisShell.vue`, layout/navbar/footer if heading-order traces there)
- **A1** `TableShell`: add `titleTag`/`headingLevel` prop (default `h1`); render title via `:is`; size 18px/600, color `--neutral-900`; meta/desc/border/shadow/radius → `--border-subtle`/`--neutral-600`/`--radius-md`/`--shadow-sm`. Remove slate hardcodes.
- **A2** `AnalysisShell`: title→`--neutral-900` 18px; subtitle `--neutral-600`; active tab + hover → `--medical-blue-700`/`--medical-blue-800`; badge/border → tokens. Remove `#0d6efd`/`#172033`.
- **A3** Heading-order: identify the global skip (likely navbar brand / footer / banner heading level) via DOM; ensure order h1→h2→… on a sample of pages. AC: `heading-order` passes on home, entities, genenetworks.
- **Verify:** type-check + unit; screenshot-diff home/genes/entities (no IA regression); Lighthouse a11y on 3 pages.

### Track B — Table renderer a11y  (owns: `components/small/GenericTable.vue`, `TablePaginationControls.vue`, `TableFilterControls.vue`, `tables/TablesEntities.vue` filter slot pattern)
- **B1** Every filter `<select>` / `<BFormSelect>` in the filter row + per-page select gets `aria-label` (mirror the `TablesGenes` labeled pattern). AC: `select-name`→0.
- **B2** Filter-row cells + body cells associate with headers (`scope="col"` on `<th>`, `headers`/`role` on filter `<td>`, or relocate filters into a labeled region). AC: `td-has-header`→0.
- **Verify:** unit (`GenericTable.spec.ts`), type-check; Lighthouse a11y on entities/phenotypes/curationcomparisons-table/nddscore.

### Track C — Chip/contrast system  (owns: `assets/scss/partials/_colors.scss` or new `_chips.scss`, `analyses/PubtatorNDDTable.vue`, `analyses/PublicationsNDDTable.vue`, `nddscore/NddScoreModelCard.vue`, `ApiView.vue` chip styles)
- **C1** Add token-based chip classes (AA-passing: e.g. `--medical-blue-700` text on `--medical-blue-50`, etc.); document in tokens.
- **C2** Replace `.gene-chip`/pastel chips in pubtator/publications/modelcard/api with the token classes; kill `#0d6efd`/`#e7f1ff`/etc. AC: `color-contrast`→0 on those 4 pages.
- **Verify:** type-check; Lighthouse a11y pubtatorndd (29→0), publicationsndd, nddscore-modelcard, api.

### Track D — Icon-button names  (owns: shared icon buttons in `small/*` download/copy/expand, `analyses/AnalyseGeneClusters.vue` + `PhenotypesTable`/`TablesPhenotypes` action buttons)
- **D1** Add `aria-label` + tooltip to icon-only controls. AC: `button-name`→0 on genenetworks, phenotypes.
- **Verify:** a11y spec / axe; Lighthouse genenetworks + phenotypes button-name.

**Wave 1 gate:** merge tracks A–D to the feature branch; full re-Lighthouse batch (expect a11y ≥99 nearly everywhere); `make lint-app` + type-check:strict + test:unit green; re-capture screenshots; quick re-rating of entities/phenotypes/pubtatorndd/nddscore (expect +1–2 overall, a11y ≥9).

## Wave 2 — Per-page sprints (parallel worktrees; disjoint page components)

- **S1 GeneNetworks** (`views/analyses/GeneNetworks.vue`, `analyses/AnalyseGeneClusters.vue`): use precomputed `preset` layout on public path; reserve canvas height; defer non-critical work; hierarchy of the two-panel layout. AC: CLS ≤0.1, no synchronous fCoSE on public load, perf no longer an outlier (interpret vs dev baseline), re-rate ≥9.
- **S2 Detail pages** (`views/pages/GeneView.vue`, `EntityView.vue`, `gene/*Card.vue`, `ui/SectionCard.vue`, genomic-viz/lollipop): lollipop SVG ARIA (`aria-hidden` decorative + one labelled summary) → `aria-prohibited-attr`→0; `SectionCard` reserves skeleton height → CLS ≤0.1; entity-detail h1 + content + fix 5 failed requests. AC: gene-detail/entity-detail re-rate ≥9.
- **S3 Analysis viz** (`AnalysesCurationMatrixPlot`, `AnalysesPhenotypeCorrelogram`, `AnalysesVariantCorrelogram`, `AnalysesTimePlot`, `PhenotypeFunctionalCorrelation`): spacing/density, legend/axis/units, empty+loading+error states, token color scales, mobile. AC: dataviz ≥8, overall ≥9.
- **S4 Heavy tables** (`PubtatorNDDTable`, `PublicationsNDDTable`, `NddScoreGeneTable`, `AnalysesCurationComparisonsTable`): post-C chip contrast, column overload → progressive disclosure, density/labels. AC: overall ≥9.
- **S5 API/About/Register** (`ApiView.vue`, `help/AboutView.vue`, `RegisterView.vue`): on-brand embed frame (API cons 3→8+), About LCP element priority, Register↔Login parity. AC: overall ≥9.
- **S6 Reference polish** (`HomeView.vue` + home panels, minor genes/mcp/login): home loading/empty states, hero trim to operational tone; micro-polish. AC: home/genes/mcp/login ≥9 without regressions.

**Wave 2 gate:** full Lighthouse + screenshot re-capture + full re-rating (target: all 25 ≥9); `make ci-local`; update `documentation/10-visual-design-guide.md` if shared patterns changed; PR.

## Execution mechanics
- Each track/sprint = one subagent in an isolated worktree (no shared-file collisions by design).
- After each wave, integrate to the feature branch, run the verification gate, and re-audit before opening the next wave.
- A task only counts done when its named Lighthouse audit(s) pass and the re-rating clears the bar — evidence before assertion.
