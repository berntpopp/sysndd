# SysNDD 145-IQ Impeccable UI/UX & Lighthouse Design Audit
Date: 2026-09-08
Reviewer Calibration: Award-winning Design Director & Senior Clinical Product Designer (145-IQ calibration)
Target: 12 Core Public Surfaces requested on https://sysndd.dbmr.unibe.ch/

---

## Executive Summary

- **Total Scanned Pages:** 12 production routes
- **Lighthouse Performance Mean:** **93.9 / 100** (prod build)
- **Lighthouse Accessibility Mean:** **99.7 / 100** (11/12 pages at 100, 1 at 96)
- **Lighthouse Best Practices:** **100 / 100** on all 12 pages
- **Lighthouse SEO:** **92-100 / 100** on all 12 pages
- **Mean Impeccable Design Score:** **69 / 100** (Range: 54 - 82)
- **Target Post-Overhaul:** **> 90 / 100** across all pages, 100% Lighthouse A11y, unified SCSS, and **Zero AI Smell and Tell**.

---

## Scoreboard

| Page | Impeccable Score | LH Perf | LH A11y | LH BP | LH SEO | Hier | Type | Color | Cons | Space | Resp | A11y | DViz | State | Clar (No AI Smell) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `home` | **82** | 100 | 100 | 100 | 100 | 8 | 8 | 8 | 8 | 8 | 8 | 10 | 8 | 8 | 9 |
| `entities` | **79** | 84 | 100 | 100 | 92 | 8 | 8 | 7 | 7 | 8 | 8 | 10 | 8 | 8 | 8 |
| `genes` | **78** | 83 | 100 | 100 | 92 | 8 | 7 | 7 | 7 | 8 | 8 | 10 | 8 | 8 | 7 |
| `phenotypes` | **74** | 85 | 100 | 100 | 92 | 8 | 7 | 6 | 6 | 8 | 7 | 10 | 8 | 8 | 7 |
| `panels` | **71** | 85 | 100 | 100 | 92 | 7 | 6 | 7 | 6 | 7 | 7 | 10 | 6 | 7 | 7 |
| `curationcomparisons` | **72** | 96 | 100 | 100 | 92 | 7 | 7 | 7 | 6 | 7 | 7 | 10 | 8 | 7 | 7 |
| `curationcomparisons-similarity` | **64** | 100 | 100 | 100 | 92 | 6 | 7 | 6 | 6 | 6 | 6 | 10 | 5 | 6 | 6 |
| `curationcomparisons-table` | **70** | 100 | 100 | 100 | 92 | 7 | 6 | 7 | 6 | 7 | 7 | 10 | 8 | 7 | 6 |
| `phenotypecorrelations` | **58** | 100 | 100 | 100 | 92 | 6 | 5 | 6 | 6 | 5 | 5 | 10 | 5 | 6 | 5 |
| `phenotypecounts` | **64** | 100 | 100 | 100 | 92 | 7 | 6 | 7 | 6 | 5 | 6 | 10 | 6 | 6 | 6 |
| `phenotypeclusters` | **54** | 94 | 96 | 100 | 92 | 6 | 6 | 4 | 5 | 6 | 5 | 6 | 7 | 6 | 5 |
| `nddscore` | **62** | 100 | 100 | 100 | 92 | 6 | 7 | 6 | 6 | 5 | 6 | 10 | 7 | 7 | 6 |

---

## Key Systemic Findings (Root Causes)

### 1. "AI Smell and Tell" & Cheesy Consumer-AI Tropes
- **Cluster 1 Phenotype Synthesis (`/PhenotypeCorrelations/PhenotypeClusters`):** Renders a garish `✨ AI Summary — Cluster 1` card with yellow sparkle emoji and a `✔ Verified` pill. In a clinical genetics research database, consumer AI marketing gimmicks erode institutional trust.
- **NDDScore Disclaimers (`/NDDScore`):** Uses `✨ ML prediction` sparkles in badges and titles, and wraps the page in an overly defensive, multi-nested card disclaimer stack with giant metric callout cards that push the gene table entirely below the fold.

### 2. Action Button Color Chaos & Visual Disharmony
- Across public tables (`/Entities`, `/Genes`, `/Phenotypes`, `/CurationComparisons/Table`, `/NDDScore`), table header utility buttons exhibit discordant coloring:
  - Export: dark gray `#424242`
  - Copy Link: bright green `#2e7d32`
  - Column Toggle: bright cyan on Entities/Genes, but bright ORANGE/YELLOW on Phenotypes!
  - Panels table uses an inline text button `Columns 9/9` in the toolbar instead of a header icon button.
  - These buttons should form a calm, coherent utility button group using subtle neutral borders and tokens.

### 3. Amateurish Filter Placeholders & Label Collisions
- Filter inputs across data tables use a developer placeholder convention: `.. Entity ..`, `.. Symbol ..`, `.. Disease ontology ... .`, `.. Hpo mode of inherit... ..`.
- Several dropdown filter selects (`.. Top inherita`, `.. Gene2Phenoty`, `.. Radboudumc..`, `.. NDD GeneHub`) collide with and clip under the dropdown caret icon.
- Column headers suffer from abrupt truncation (e.g. `Gene2Phenoty` instead of `Gene2Phenotype`, `Hpo mode of inherit...` instead of `Inheritance`).

### 4. Card-in-Card Nesting & Redundant Chrome
- Inside `AnalysisShell` (`/CurationComparisons` and `/PhenotypeCorrelations` tabs), child views embed another full bordered card component with duplicate headers (e.g. Tab reads "Overlap" and inner card header reads "Overlap (?) (?)"), violating the visual design guide rule against nested UI cards.
- On `/CurationComparisons`, the header renders two identical question mark buttons side-by-side.

### 5. Critical Data-Viz Defects
- **Phenotype Correlogram (`/PhenotypeCorrelations`):** Rotated X-axis HPO term labels are vertically sliced through the middle of the text, making them completely unreadable.
- **Curation Similarity (`/CurationComparisons/Similarity`):** The cosine similarity heatmap has NO legend or numerical color scale bar whatsoever.
- **Phenotype Counts (`/PhenotypeCorrelations/PhenotypeCounts`):** 45-degree angled bar labels overlap and cram together into an illegible jumble.

### 6. Lighthouse Accessibility Regressions on PhenotypeClusters (Score: 96)
- **Contrast Failure 1:** `span.ai-label` has contrast ratio **1.5:1** (yellow text `#ffc107` on pale yellow `#fff6da`).
- **Contrast Failure 2:** Cluster link `#0d6efd` on `#fafafa` has contrast ratio **4.31:1** (fails AA 4.5:1).
- **Heading Order Violation:** Uses `<h6>Organ-system involvement</h6>` skipping h2-h5 levels.
- **Accessible Name Mismatch:** `.xlsx` button visible text `.xlsx` does not match aria-label `Download table data as Excel file`.

### 7. SCSS Architecture Inconsistencies & Token Drift
- Undefined variable reference: `--border-radius-base` used in `_responsive.scss:22` and `_tables.scss:140` (defaults to 0px in browsers).
- Invalid CSS property: `aria-label: 'required'` inside SCSS rules in `_forms.scss:24`.
- Negative letter-spacing in `_typography.scss:37,71` violating the Visual Design Guide mandate to avoid negative letter spacing in dense tables.
- Extensive hardcoded hex values in `_public-pages.scss` (`#f6f8fb`, `#d9e1ec`, `#102033`, `#667085`, `#1d2939`, `#9fb3c8`) and `HomeView.vue` instead of central tokens.
