# SPEC: SysNDD Impeccable Design & Architecture Overhaul

**Target Goal:** Elevate all 12 requested SysNDD public surfaces from baseline (mean 69/100, a11y 96-100) to reference-class clinical operations tools (>90/100, 100% Lighthouse A11y, 100% Best Practices).
**Aesthetic & UX Stance:** Compact, trustworthy, table-first, and quiet. Zero consumer AI marketing tropes ("no AI smell and tell"), unified SCSS tokens, and surgical typography/dataviz fixes.

---

## 1. Design Principles & Anti-Patterns to Eliminate

### A. "No AI Smell and Tell"
- **Anti-Pattern:** Sparkle emojis (`✨`), bright gold/yellow badges, consumer-grade "✨ AI Summary" branding, fake verification checkmarks, and defensive walls of disclaimers that push user data off-screen.
- **Solution:** 
  - Dignified clinical scientific nomenclature: "Cluster Synthesis" / "Phenotypic Profile Synthesis".
  - Transparent, subdued methodology attribution: "Curated HPO term synthesis; reviewed".
  - Sleek, compact metadata bars for ML models (AUC-ROC, Brier scores) integrated into table headers instead of stacked multi-card alert boxes.

### B. Single Color & Design Language (SCSS Unification)
- **Anti-Pattern:** Mismatched action buttons in table headers (dark gray `.xlsx`, green link, cyan/orange column toggle), hardcoded hex values (`#f6f8fb`, `#d9e1ec`, `#102033`, `#667085`), broken radius variables (`--border-radius-base`).
- **Solution:**
  - Define `--border-radius-base: var(--radius-md);` in `_radius.scss`.
  - Eliminate all hardcoded hex in `_public-pages.scss`, `HomeView.vue`, and `AnalysisShell.vue`, replacing them with `--surface-canvas`, `--surface-raised`, `--border-subtle`, `--neutral-900`, `--neutral-700`.
  - Standardize all table header utility actions into a unified, subtle action button group (`.table-header-action-group`) with quiet neutral styling.

### C. Eliminate Card-in-Card Nesting
- **Anti-Pattern:** Inside `AnalysisShell`, embedding another `BCard` with a duplicate header (e.g. Tab "Overlap", Card Title "Overlap", duplicate question marks).
- **Solution:**
  - Flatten child analysis views so the visualization or table occupies the `AnalysisShell` body directly, eliminating redundant card borders, margins, and duplicate titles.

### D. Table Polish & Eliminating "Developer Placeholders"
- **Anti-Pattern:** Double-dot placeholders (`.. Entity ..`, `.. Disease ontology ... .`), truncated column headers (`Gene2Phenoty`, `Hpo mode of inherit...`), overflowing select text into arrows.
- **Solution:**
  - Human-crafted placeholder strings: "Filter entity...", "Filter symbol...", "Filter disease...", "All inheritances".
  - Clean column headers with full tooltips and no ugly ellipses.
  - Form select minimum widths and padding preventing text from clipping under the dropdown arrow.

### E. Data Visualization Rigor
- **Anti-Pattern:** Rotated X-axis labels sliced through the center in correlograms, missing color scale legends in similarity matrices, overlapping 45-degree labels in bar charts.
- **Solution:**
  - Ensure SVG viewbox and bottom margins allocate sufficient height (at least 140px) for 90-degree rotated HPO labels in `AnalysesPhenotypeCorrelogram`.
  - Add a clear horizontal color scale legend bar (0.0 to 1.0) with high contrast to `AnalysesCurationMatrixPlot`.
  - Improve label spacing and density in `AnalysesPhenotypeCounts`.

---

## 2. Accessibility Invariants (Lighthouse 100 Across All Pages)

1. **Color Contrast:** Every text/background combination must achieve WCAG 2.2 AA (>= 4.5:1).
   - Replace yellow AI label `#ffc107` on `#fff6da` (1.5:1) with `--neutral-700` on subtle neutral background (5.4:1).
   - Cluster link `#0d6efd` on `#fafafa` (4.31:1) replaced with `--medical-blue-700` (8.59:1).
   - Secondary button outlines verified >= 4.5:1.
2. **Heading Hierarchy:** Strictly sequentially-descending headings on every surface.
   - Replace `<h6>` in `Organ-system involvement` with `<h3>`.
   - Ensure exactly one `<h1>` per route.
3. **Accessible Names:** Ensure every icon button and action control includes matching accessible names (clearing `label-content-name-mismatch`).
