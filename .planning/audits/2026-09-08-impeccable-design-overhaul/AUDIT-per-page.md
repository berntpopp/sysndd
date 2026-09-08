# SysNDD Detailed Per-Page Design & Lighthouse Audit
Date: 2026-09-08
Reviewer: 145-IQ Design Director & Senior Clinical Product Designer

## Home Page (`home`)
**Route:** `/`  
**Overall Impeccable Score:** **82 / 100**  
**Lighthouse:** Performance: **100** | Accessibility: **100** | Best Practices: **100** | SEO: **100**  
**Verdict:** Strong, clean reference surface; minor token hardcodes and slate fallback debt in CSS.

### Scores (1-10)
- Visual Hierarchy: **8**
- Typography: **8**
- Color & Contrast: **8**
- Consistency & Design Language: **8**
- Spacing & Density: **8**
- Responsiveness: **8**
- Accessibility: **10**
- Data Visualization: **8**
- Interaction & States: **8**
- Content Clarity & Tone (No AI Smell): **9**

### Findings & Concrete Evidence
- **[MED] [consistency]** Hardcoded background hex #f6f8fb and surface #fff instead of design tokens (Evidence: `HomeView.vue:252,266`)
- **[LOW] [color_contrast]** Fallback slate colors in CSS variables (#172033, #526070) instead of brand neutrals (Evidence: `HomeView.vue:272,281`)
- **[LOW] [consistency]** Card border shadow hardcoded with slate rgba(15, 23, 42, 0.08) (Evidence: `HomeView.vue:267`)

### Recommended Improvements
- **[foundation-shared] (S)** Unify HomeView container and cards to use var(--surface-canvas), var(--surface-raised), var(--border-subtle), and var(--shadow-sm) — *Impact: Eliminates one-off CSS and unifies background tone*

---

## Entities Table (`entities`)
**Route:** `/Entities?sort=%2Bentity_id&page_size=10`  
**Overall Impeccable Score:** **79 / 100**  
**Lighthouse:** Performance: **84** | Accessibility: **100** | Best Practices: **100** | SEO: **92**  
**Verdict:** Excellent table functionality marred by mismatched action button colors and amateurish double-dot filter placeholders.

### Scores (1-10)
- Visual Hierarchy: **8**
- Typography: **8**
- Color & Contrast: **7**
- Consistency & Design Language: **7**
- Spacing & Density: **8**
- Responsiveness: **8**
- Accessibility: **10**
- Data Visualization: **8**
- Interaction & States: **8**
- Content Clarity & Tone (No AI Smell): **8**

### Findings & Concrete Evidence
- **[HIGH] [color_contrast]** Top-right action buttons use 3 conflicting colors: dark gray (.xlsx), bright green (copy link), and bright cyan (column toggle) (Evidence: `entities.png top right header`)
- **[MED] [content_clarity]** Filter input placeholders use amateurish double-dot format (.. Entity .., .. Symbol .., .. Disease ..) (Evidence: `entities.png filter row`)
- **[LOW] [visual_noise]** Details column has repetitive outline blue Show buttons on every single row (Evidence: `entities.png rightmost column`)

### Recommended Improvements
- **[foundation-shared] (S)** Standardize table header actions into a unified neutral outline/subtle button group using --neutral-* and --border-subtle tokens — *Impact: Harmonious action cluster across all tables*
- **[foundation-shared] (S)** Replace double-dot placeholders with clean human-crafted labels ("Filter entity...", "Filter symbol...", "All inheritances") — *Impact: Eliminates AI/developer placeholder smell*

---

## Genes Table (`genes`)
**Route:** `/Genes?sort=%2Bsymbol&page_after=0&page_size=10`  
**Overall Impeccable Score:** **78 / 100**  
**Lighthouse:** Performance: **83** | Accessibility: **100** | Best Practices: **100** | SEO: **92**  
**Verdict:** Solid gene index; suffers from truncated header "Hpo mode of inherit...", mismatched buttons, and double-dot placeholders.

### Scores (1-10)
- Visual Hierarchy: **8**
- Typography: **7**
- Color & Contrast: **7**
- Consistency & Design Language: **7**
- Spacing & Density: **8**
- Responsiveness: **8**
- Accessibility: **10**
- Data Visualization: **8**
- Interaction & States: **8**
- Content Clarity & Tone (No AI Smell): **7**

### Findings & Concrete Evidence
- **[HIGH] [typography]** Column header truncated to "Hpo mode of inherit..." with ugly ellipsis, filter placeholder reads ".. Hpo mode of inherit... .." (Evidence: `genes.png 3rd column header`)
- **[HIGH] [consistency]** Same mismatched header buttons (dark gray .xlsx, green copy link, cyan column toggle) (Evidence: `genes.png top right header`)
- **[MED] [content_clarity]** Double-dot placeholders across all filter inputs (Evidence: `genes.png filter row`)

### Recommended Improvements
- **[per-page] (S)** Shorten column header to "Inheritance" or "HPO Inheritance" with full tooltip, clean up filter placeholder — *Impact: Removes clipping and improves scanability*
- **[foundation-shared] (S)** Apply shared unified table action button group — *Impact: Consistent header action pattern*

---

## Phenotype Search Table (`phenotypes`)
**Route:** `/Phenotypes?sort=entity_id&filter=all(modifier_phenotype_id,HP:0001249)&page_size=10`  
**Overall Impeccable Score:** **74 / 100**  
**Lighthouse:** Performance: **85** | Accessibility: **100** | Best Practices: **100** | SEO: **92**  
**Verdict:** Functional phenotype query table with chaotic button coloring (orange column toggle, green copy link, dark gray excel) and garbled placeholder punctuation.

### Scores (1-10)
- Visual Hierarchy: **8**
- Typography: **7**
- Color & Contrast: **6**
- Consistency & Design Language: **6**
- Spacing & Density: **8**
- Responsiveness: **7**
- Accessibility: **10**
- Data Visualization: **8**
- Interaction & States: **8**
- Content Clarity & Tone (No AI Smell): **7**

### Findings & Concrete Evidence
- **[HIGH] [consistency]** Column toggle button is styled bright ORANGE/YELLOW, while cyan on Entities/Genes and dark gray elsewhere (Evidence: `phenotypes.png top right header`)
- **[MED] [typography]** Garbled placeholder text ".. Disease ontology ... ." with irregular trailing dots and spaces (Evidence: `phenotypes.png filter row 3rd input`)
- **[LOW] [color_contrast]** High contrast mismatch between filled AND button and unselected OR button (Evidence: `phenotypes.png tag bar`)

### Recommended Improvements
- **[foundation-shared] (S)** Unify header actions with the shared table toolbar standard, removing one-off orange variant — *Impact: Eliminates jarring color surprises*
- **[per-page] (S)** Clean up placeholder strings to "Filter disease..." and "Inheritance" — *Impact: Professional clinical polish*

---

## Panel Compilation Table (`panels`)
**Route:** `/Panels/All/All`  
**Overall Impeccable Score:** **71 / 100**  
**Lighthouse:** Performance: **85** | Accessibility: **100** | Best Practices: **100** | SEO: **92**  
**Verdict:** Outlier among public tables: lacks standard category/inheritance chips and uses proportional sans font for database identifiers and genomic coordinates.

### Scores (1-10)
- Visual Hierarchy: **7**
- Typography: **6**
- Color & Contrast: **7**
- Consistency & Design Language: **6**
- Spacing & Density: **7**
- Responsiveness: **7**
- Accessibility: **10**
- Data Visualization: **6**
- Interaction & States: **7**
- Content Clarity & Tone (No AI Smell): **7**

### Findings & Concrete Evidence
- **[HIGH] [dataviz]** Category and Inheritance columns render truncated plain text rather than standard semantic chips (.sysndd-chip) (Evidence: `panels.png 1st and 2nd columns`)
- **[HIGH] [typography]** Identifiers (HGNC, Entrez, Ensembl, UCSC, BED coords) use proportional body font instead of --font-family-mono (Evidence: `panels.png columns 4-9`)
- **[MED] [consistency]** Column toggle is an inline button in the filter row ("Columns 9/9") rather than an action icon in the header (Evidence: `panels.png toolbar row`)

### Recommended Improvements
- **[per-page] (M)** Convert Category to CategoryIcon + badge and Inheritance to .sysndd-chip badges — *Impact: Brings Panels into visual parity with Entities and Genes*
- **[per-page] (S)** Apply font-mono class to HGNC, Entrez, Ensembl, UCSC, and BED coordinate columns — *Impact: Scannable scientific data formatting*

---

## Curation Comparisons (UpSet) (`curationcomparisons`)
**Route:** `/CurationComparisons`  
**Overall Impeccable Score:** **72 / 100**  
**Lighthouse:** Performance: **96** | Accessibility: **100** | Best Practices: **100** | SEO: **92**  
**Verdict:** Powerful UpSet visualization weakened by card-in-card nesting, duplicate headers, and duplicate question mark icons.

### Scores (1-10)
- Visual Hierarchy: **7**
- Typography: **7**
- Color & Contrast: **7**
- Consistency & Design Language: **6**
- Spacing & Density: **7**
- Responsiveness: **7**
- Accessibility: **10**
- Data Visualization: **8**
- Interaction & States: **7**
- Content Clarity & Tone (No AI Smell): **7**

### Findings & Concrete Evidence
- **[HIGH] [hierarchy]** Card inside card anti-pattern: inner bordered card duplicates outer tab title "Overlap" (Evidence: `curationcomparisons.png inner card`)
- **[HIGH] [consistency]** Duplicate question mark icons "(?) (?)" in inner card header (Evidence: `curationcomparisons.png header title`)
- **[MED] [color_contrast]** Source toggle chips use random discordant colors (blue, green, cyan) rather than systematic palette (Evidence: `curationcomparisons.png source pills`)

### Recommended Improvements
- **[per-page] (M)** Flatten inner card chrome into AnalysisShell content, remove duplicate "Overlap" heading — *Impact: Removes nested card chrome and visual clutter*
- **[per-page] (S)** Remove redundant second help button and standardize source chips to --medical-blue and --neutral tokens — *Impact: Clean, singular help affordance and cohesive colors*

---

## Curation Comparisons Similarity Matrix (`curationcomparisons-similarity`)
**Route:** `/CurationComparisons/Similarity`  
**Overall Impeccable Score:** **64 / 100**  
**Lighthouse:** Performance: **100** | Accessibility: **100** | Best Practices: **100** | SEO: **92**  
**Verdict:** Critical data visualization omission: cosine similarity heatmap lacks any color scale legend or numerical key.

### Scores (1-10)
- Visual Hierarchy: **6**
- Typography: **7**
- Color & Contrast: **6**
- Consistency & Design Language: **6**
- Spacing & Density: **6**
- Responsiveness: **6**
- Accessibility: **10**
- Data Visualization: **5**
- Interaction & States: **6**
- Content Clarity & Tone (No AI Smell): **6**

### Findings & Concrete Evidence
- **[HIGH] [dataviz]** NO COLOR SCALE / LEGEND: heatmap displays shades of dark red to light pink with zero indication of numerical correlation/similarity range (Evidence: `curationcomparisons-similarity.png`)
- **[MED] [hierarchy]** Card-in-card nesting with duplicate "Similarity" header (Evidence: `curationcomparisons-similarity.png`)
- **[MED] [spacing_density]** Excessive whitespace around centered matrix with no supplementary statistics or context (Evidence: `curationcomparisons-similarity.png layout`)

### Recommended Improvements
- **[per-page] (M)** Add clear, token-styled color scale legend bar (0.0 to 1.0) below the matrix plot — *Impact: Makes the visualization quantitatively interpretable*
- **[per-page] (S)** Flatten nested card border and integrate controls cleanly into AnalysisShell — *Impact: Single unified surface*

---

## Curation Comparisons Table (`curationcomparisons-table`)
**Route:** `/CurationComparisons/Table`  
**Overall Impeccable Score:** **70 / 100**  
**Lighthouse:** Performance: **100** | Accessibility: **100** | Best Practices: **100** | SEO: **92**  
**Verdict:** Valuable cross-database comparison table marred by truncated column headers ("Gene2Phenoty") and overflowing filter dropdowns.

### Scores (1-10)
- Visual Hierarchy: **7**
- Typography: **6**
- Color & Contrast: **7**
- Consistency & Design Language: **6**
- Spacing & Density: **7**
- Responsiveness: **7**
- Accessibility: **10**
- Data Visualization: **8**
- Interaction & States: **7**
- Content Clarity & Tone (No AI Smell): **6**

### Findings & Concrete Evidence
- **[HIGH] [typography]** Column header truncated to "Gene2Phenoty" and filter dropdowns overflow into arrows (.. Gene2Phenoty, .. Radboudumc.., .. NDD GeneHub) (Evidence: `curationcomparisons-table.png`)
- **[MED] [consistency]** Header actions repeat mismatched 3-color cluster (dark gray, green, cyan) (Evidence: `curationcomparisons-table.png top right`)
- **[MED] [hierarchy]** Nested card chrome inside AnalysisShell with duplicate title "Curation effort comparisons" (Evidence: `curationcomparisons-table.png`)

### Recommended Improvements
- **[per-page] (S)** Fix column header width / label truncation and provide clean filter select option labels — *Impact: Eliminates text collisions and ugly truncation*
- **[foundation-shared] (S)** Flatten nested card chrome and apply unified table action buttons — *Impact: Consistent table appearance*

---

## Phenotype Correlations (Correlogram) (`phenotypecorrelations`)
**Route:** `/PhenotypeCorrelations`  
**Overall Impeccable Score:** **58 / 100**  
**Lighthouse:** Performance: **100** | Accessibility: **100** | Best Practices: **100** | SEO: **92**  
**Verdict:** Severe visual defect: X-axis labels rotated 90 degrees are vertically clipped through the center of the words, rendering them illegible.

### Scores (1-10)
- Visual Hierarchy: **6**
- Typography: **5**
- Color & Contrast: **6**
- Consistency & Design Language: **6**
- Spacing & Density: **5**
- Responsiveness: **5**
- Accessibility: **10**
- Data Visualization: **5**
- Interaction & States: **6**
- Content Clarity & Tone (No AI Smell): **5**

### Findings & Concrete Evidence
- **[HIGH] [dataviz]** X-axis labels are vertically CLIPPED through the middle of the text lines ("idney", "ystem", "mality"), completely unreadable (Evidence: `phenotypecorrelations.png bottom of chart`)
- **[HIGH] [dataviz]** Correlation color scale legend is positioned off-screen / pushed below default viewport on desktop (Evidence: `phenotypecorrelations.png viewport bottom`)
- **[MED] [hierarchy]** Nested card chrome with redundant "Matrix of phenotype correlations" title (Evidence: `phenotypecorrelations.png`)
- **[MED] [responsiveness]** Tab bar overflows on mobile without visual scroll cues (Evidence: `phenotypecorrelations-mobile.png`)

### Recommended Improvements
- **[per-page] (M)** Increase bottom SVG/plot margin and configure proper text-anchor and padding so rotated HPO term labels never clip — *Impact: Restores primary scientific readability of the correlogram*
- **[per-page] (S)** Position correlation legend alongside or immediately beneath chart within the visible frame — *Impact: Immediate interpretive context*

---

## Phenotype Counts Bar Plot (`phenotypecounts`)
**Route:** `/PhenotypeCorrelations/PhenotypeCounts`  
**Overall Impeccable Score:** **64 / 100**  
**Lighthouse:** Performance: **100** | Accessibility: **100** | Best Practices: **100** | SEO: **92**  
**Verdict:** Frequency chart suffers from overlapping, crammed 45-degree rotated category labels on the X-axis.

### Scores (1-10)
- Visual Hierarchy: **7**
- Typography: **6**
- Color & Contrast: **7**
- Consistency & Design Language: **6**
- Spacing & Density: **5**
- Responsiveness: **6**
- Accessibility: **10**
- Data Visualization: **6**
- Interaction & States: **6**
- Content Clarity & Tone (No AI Smell): **6**

### Findings & Concrete Evidence
- **[HIGH] [typography]** X-axis bar labels are rotated 45 degrees and overlap into each other, creating an unreadable dense strip (Evidence: `phenotypecounts.png bottom axis`)
- **[MED] [hierarchy]** Nested card chrome inside AnalysisShell with duplicate title (Evidence: `phenotypecounts.png`)
- **[LOW] [interaction_states]** Lack of interactive hover tooltip or value display on bars (Evidence: `phenotypecounts.png`)

### Recommended Improvements
- **[per-page] (M)** Improve label spacing, consider horizontal bar layout or intelligent font scaling with hover highlights — *Impact: High-density scannable phenotype distribution*
- **[per-page] (S)** Flatten nested card border into AnalysisShell body — *Impact: Consistent single-surface layout*

---

## Phenotype Clusters Network & Synthesis (`phenotypeclusters`)
**Route:** `/PhenotypeCorrelations/PhenotypeClusters`  
**Overall Impeccable Score:** **54 / 100**  
**Lighthouse:** Performance: **94** | Accessibility: **96** | Best Practices: **100** | SEO: **92**  
**Verdict:** Lowest scoring page: 3 failing Lighthouse accessibility audits (1.5:1 yellow AI contrast, heading order, button name mismatch), garish consumer-AI sparkle tropes, and broken mobile export buttons.

### Scores (1-10)
- Visual Hierarchy: **6**
- Typography: **6**
- Color & Contrast: **4**
- Consistency & Design Language: **5**
- Spacing & Density: **6**
- Responsiveness: **5**
- Accessibility: **6**
- Data Visualization: **7**
- Interaction & States: **6**
- Content Clarity & Tone (No AI Smell): **5**

### Findings & Concrete Evidence
- **[HIGH] [accessibility]** FAILING WCAG CONTRAST (1.5:1): Yellow "AI" label (#ffc107 on #fff6da) is virtually invisible and severely fails AA requirement (Evidence: `lighthouse/phenotypeclusters.json & phenotypeclusters.png`)
- **[HIGH] [content_clarity]** HEAVY AI SMELL & TELL: Consumer-style sparkle emoji "✨ AI Summary — Cluster 1" and fake "Verified" badge degrade clinical credibility (Evidence: `phenotypeclusters.png bottom right card`)
- **[HIGH] [accessibility]** FAILING HEADING ORDER: Card uses <h6> for "Organ-system involvement", skipping h2-h5 levels (Evidence: `lighthouse/phenotypeclusters.json`)
- **[MED] [accessibility]** ACCESSIBLE NAME MISMATCH: .xlsx button has visible text ".xlsx" but aria-label "Download table data as Excel file" without matching text (Evidence: `lighthouse/phenotypeclusters.json`)
- **[HIGH] [color_contrast]** Cluster link #0d6efd on #fafafa has contrast 4.31:1, failing AA 4.5:1 requirement (Evidence: `lighthouse/phenotypeclusters.json`)
- **[MED] [responsiveness]** Mobile export buttons collapse into giant empty rectangle blocks (Evidence: `phenotypeclusters-mobile.png`)

### Recommended Improvements
- **[per-page] (S)** Eliminate sparkle emojis and "✨ AI Summary"; rebrand to dignified clinical nomenclature: "Cluster Synthesis" or "Phenotypic Profile" — *Impact: Zero AI smell; restores clinical research credibility*
- **[per-page] (M)** Fix all 3 a11y failures: replace yellow AI badge with high-contrast token pill, fix h6 -> h3, align button accessible name to include "xlsx", use --medical-blue-700 (8.59:1) for cluster link — *Impact: Restores Lighthouse a11y score from 96 to 100*
- **[per-page] (S)** Fix mobile button sizing so export buttons remain compact icon buttons — *Impact: Clean responsive layout at 390px*

---

## NDDScore Machine Learning Predictions (`nddscore`)
**Route:** `/NDDScore`  
**Overall Impeccable Score:** **62 / 100**  
**Lighthouse:** Performance: **100** | Accessibility: **100** | Best Practices: **100** | SEO: **92**  
**Verdict:** Overly defensive card-in-card disclaimer stack with sparkle emojis forces the actual prediction table below the fold.

### Scores (1-10)
- Visual Hierarchy: **6**
- Typography: **7**
- Color & Contrast: **6**
- Consistency & Design Language: **6**
- Spacing & Density: **5**
- Responsiveness: **6**
- Accessibility: **10**
- Data Visualization: **7**
- Interaction & States: **7**
- Content Clarity & Tone (No AI Smell): **6**

### Findings & Concrete Evidence
- **[MED] [content_clarity]** AI SMELL & TELL: Consumer-style sparkle emoji "✨ ML prediction" used in header badge and banner card (Evidence: `nddscore.png top badge and banner`)
- **[HIGH] [hierarchy]** Massive disclaimer banner with nested metric cards (AUC-ROC, Brier) consumes entire initial viewport, especially on mobile (Evidence: `nddscore.png and nddscore-mobile.png`)
- **[MED] [typography]** Filter select option text overlaps dropdown arrow (".. Top inherita") (Evidence: `nddscore.png 9th filter input`)
- **[MED] [consistency]** Inconsistent placeholder styles (mixing "Filter Gene", "Any NDD sco...", and ".. Risk tier ..") (Evidence: `nddscore.png filter row`)
- **[MED] [consistency]** Same mismatched header buttons (dark gray, green, cyan) (Evidence: `nddscore.png header`)

### Recommended Improvements
- **[per-page] (M)** Remove sparkle emojis; distill model disclaimer into a compact, elegant metadata header strip with inline metrics (AUC-ROC, Brier score) instead of a giant multi-card stack — *Impact: Immediate table visibility, zero AI smell, compact clinical density*
- **[per-page] (S)** Standardize filter placeholders to clean "Filter [Field]" or "All [Field]" format, avoiding text truncation into select arrows — *Impact: Visual polish and readable controls*
- **[foundation-shared] (S)** Apply shared unified table action buttons — *Impact: Consistent action cluster*

---

