# PLAN: End-to-End Impeccable Design Overhaul & Execution

**Branch:** `feat/impeccable-design` (in worktree `/home/bernt-popp/development/sysndd/worktrees/feat-impeccable-design`)

---

## Phase 0: Foundations & SCSS Architecture Unification
- **File Edits:**
  - `app/src/assets/scss/partials/_radius.scss`: Add `--border-radius-base: var(--radius-md);`
  - `app/src/assets/scss/partials/_typography.scss`: Set `--letter-spacing-tight: 0;`
  - `app/src/assets/scss/components/_forms.scss`: Remove invalid `aria-label: 'required';`
  - `app/src/assets/scss/components/_public-pages.scss`: Replace literal hex values with design tokens.
  - `app/src/assets/scss/components/_tables.scss`: Add unified `.table-header-action-group` and `.table-header-btn` classes.
  - `app/src/views/HomeView.vue`: Replace `#f6f8fb`, `#fff`, and slate fallbacks with design tokens.
  - `app/src/components/analyses/AnalysisShell.vue`: Replace hardcoded `#f6f8fb` and `#fff` with design tokens.

## Phase 1: Accessibility & "Zero AI Smell" Remediation
- **File Edits:**
  - `app/src/components/analyses/AnalysesPhenotypeClusters.vue`:
    - Eliminate `✨` sparkles and `✨ AI Summary — Cluster 1`.
    - Retitle to `Cluster Profile Synthesis`.
    - Fix yellow badge contrast (1.5:1 -> >=4.5:1).
    - Fix cluster link `#0d6efd` to `--medical-blue-700`.
    - Fix `<h6>` heading to `<h3>`.
    - Fix `.xlsx` button aria-label matching.
    - Fix mobile export button layout.
  - `app/src/views/nddscore/NDDScore.vue` & `app/src/components/nddscore/NddScoreGeneTable.vue`:
    - Remove `✨` sparkles from `ML prediction`.
    - Compress giant multi-card disclaimer stack into a clean, compact metadata strip with inline AUC-ROC/Brier badges.
    - Clean up filter select placeholders and options.

## Phase 2: Data-Viz Polish & Label Truncation Fixes
- **File Edits:**
  - `app/src/components/analyses/AnalysesPhenotypeCorrelogram.vue`:
    - Fix rotated X-axis label vertical clipping: allocate proper bottom margin and viewbox.
    - Ensure correlation color scale is visible and token-aligned.
  - `app/src/components/analyses/AnalysesCurationMatrixPlot.vue`:
    - Add clear horizontal color scale legend bar with 0.0 to 1.0 range and descriptive label.
    - Flatten nested card chrome.
  - `app/src/components/analyses/AnalysesCurationUpset.vue`:
    - Remove duplicate question mark button.
    - Flatten inner card chrome.
  - `app/src/components/analyses/AnalysesPhenotypeCounts.vue`:
    - Improve X-axis bar label layout and spacing.

## Phase 3: Table Header Actions & Filter Placeholders Unification
- **File Edits:**
  - `app/src/views/tables/EntitiesTable.vue`
  - `app/src/views/tables/GenesTable.vue`
  - `app/src/views/tables/PhenotypesTable.vue`
  - `app/src/views/tables/PanelsTable.vue`
  - `app/src/components/analyses/AnalysesCurationComparisonsTable.vue`
  - Unify `.xlsx`, link copy, and column toggle buttons to shared subtle neutral action styling.
  - Replace double-dot placeholders (`.. Entity ..`, etc.) with clean human labels.
  - Fix `Hpo mode of inherit...` truncation in Genes table.
  - Add semantic chips and monospace IDs to Panels table.

## Phase 4: Adversarial Quality Review (Simulated Codex & Claude Code passes)
- Conduct rigorous adversarial review checks across all modified components:
  - Verify zero regressions in existing tests.
  - Verify strict adherence to WCAG 2.2 AA.
  - Verify no AI smell remains.
  - Verify file-size ceilings (<600 lines per file).

## Phase 5: Verification & Delivery
- Deterministic checks:
  - `cd app && npm run type-check`
  - `make lint-app`
  - `cd app && npm run test:unit`
- Re-run Lighthouse batch audit across all 12 pages.
- Verify all pages score >= 90/100 and a11y = 100.
- Prepare clean git commits on `feat/impeccable-design`.
