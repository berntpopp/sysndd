import { readFileSync, writeFileSync } from 'node:fs';

const OUT = '/home/bernt-popp/development/sysndd/.planning/audits/2026-09-08-impeccable-design-overhaul';
const lhCsv = readFileSync(`${OUT}/lighthouse/summary.csv`, 'utf8');

const lhLines = lhCsv.trim().split('\n').slice(1);
const lhMap = {};
for (const line of lhLines) {
  const [name, perf, a11y, bp, seo, url] = line.split(',');
  lhMap[name] = { perf: Number(perf), a11y: Number(a11y), bp: Number(bp), seo: Number(seo), url };
}

const auditData = [
  {
    page: 'home',
    title: 'Home Page',
    route: '/',
    scores: { hierarchy: 8, typography: 8, color_contrast: 8, consistency: 8, spacing_density: 8, responsiveness: 8, accessibility: 10, dataviz: 8, interaction_states: 8, content_clarity: 9 },
    overall: 82,
    one_line_verdict: 'Strong, clean reference surface; minor token hardcodes and slate fallback debt in CSS.',
    top_findings: [
      { issue: 'Hardcoded background hex #f6f8fb and surface #fff instead of design tokens', severity: 'med', dimension: 'consistency', evidence: 'HomeView.vue:252,266' },
      { issue: 'Fallback slate colors in CSS variables (#172033, #526070) instead of brand neutrals', severity: 'low', dimension: 'color_contrast', evidence: 'HomeView.vue:272,281' },
      { issue: 'Card border shadow hardcoded with slate rgba(15, 23, 42, 0.08)', severity: 'low', dimension: 'consistency', evidence: 'HomeView.vue:267' }
    ],
    improvements: [
      { recommendation: 'Unify HomeView container and cards to use var(--surface-canvas), var(--surface-raised), var(--border-subtle), and var(--shadow-sm)', effort: 'S', sprint_type: 'foundation-shared', expected_impact: 'Eliminates one-off CSS and unifies background tone' }
    ]
  },
  {
    page: 'entities',
    title: 'Entities Table',
    route: '/Entities?sort=%2Bentity_id&page_size=10',
    scores: { hierarchy: 8, typography: 8, color_contrast: 7, consistency: 7, spacing_density: 8, responsiveness: 8, accessibility: 10, dataviz: 8, interaction_states: 8, content_clarity: 8 },
    overall: 79,
    one_line_verdict: 'Excellent table functionality marred by mismatched action button colors and amateurish double-dot filter placeholders.',
    top_findings: [
      { issue: 'Top-right action buttons use 3 conflicting colors: dark gray (.xlsx), bright green (copy link), and bright cyan (column toggle)', severity: 'high', dimension: 'color_contrast', evidence: 'entities.png top right header' },
      { issue: 'Filter input placeholders use amateurish double-dot format (.. Entity .., .. Symbol .., .. Disease ..)', severity: 'med', dimension: 'content_clarity', evidence: 'entities.png filter row' },
      { issue: 'Details column has repetitive outline blue Show buttons on every single row', severity: 'low', dimension: 'visual_noise', evidence: 'entities.png rightmost column' }
    ],
    improvements: [
      { recommendation: 'Standardize table header actions into a unified neutral outline/subtle button group using --neutral-* and --border-subtle tokens', effort: 'S', sprint_type: 'foundation-shared', expected_impact: 'Harmonious action cluster across all tables' },
      { recommendation: 'Replace double-dot placeholders with clean human-crafted labels ("Filter entity...", "Filter symbol...", "All inheritances")', effort: 'S', sprint_type: 'foundation-shared', expected_impact: 'Eliminates AI/developer placeholder smell' }
    ]
  },
  {
    page: 'genes',
    title: 'Genes Table',
    route: '/Genes?sort=%2Bsymbol&page_after=0&page_size=10',
    scores: { hierarchy: 8, typography: 7, color_contrast: 7, consistency: 7, spacing_density: 8, responsiveness: 8, accessibility: 10, dataviz: 8, interaction_states: 8, content_clarity: 7 },
    overall: 78,
    one_line_verdict: 'Solid gene index; suffers from truncated header "Hpo mode of inherit...", mismatched buttons, and double-dot placeholders.',
    top_findings: [
      { issue: 'Column header truncated to "Hpo mode of inherit..." with ugly ellipsis, filter placeholder reads ".. Hpo mode of inherit... .."', severity: 'high', dimension: 'typography', evidence: 'genes.png 3rd column header' },
      { issue: 'Same mismatched header buttons (dark gray .xlsx, green copy link, cyan column toggle)', severity: 'high', dimension: 'consistency', evidence: 'genes.png top right header' },
      { issue: 'Double-dot placeholders across all filter inputs', severity: 'med', dimension: 'content_clarity', evidence: 'genes.png filter row' }
    ],
    improvements: [
      { recommendation: 'Shorten column header to "Inheritance" or "HPO Inheritance" with full tooltip, clean up filter placeholder', effort: 'S', sprint_type: 'per-page', expected_impact: 'Removes clipping and improves scanability' },
      { recommendation: 'Apply shared unified table action button group', effort: 'S', sprint_type: 'foundation-shared', expected_impact: 'Consistent header action pattern' }
    ]
  },
  {
    page: 'phenotypes',
    title: 'Phenotype Search Table',
    route: '/Phenotypes?sort=entity_id&filter=all(modifier_phenotype_id,HP:0001249)&page_size=10',
    scores: { hierarchy: 8, typography: 7, color_contrast: 6, consistency: 6, spacing_density: 8, responsiveness: 7, accessibility: 10, dataviz: 8, interaction_states: 8, content_clarity: 7 },
    overall: 74,
    one_line_verdict: 'Functional phenotype query table with chaotic button coloring (orange column toggle, green copy link, dark gray excel) and garbled placeholder punctuation.',
    top_findings: [
      { issue: 'Column toggle button is styled bright ORANGE/YELLOW, while cyan on Entities/Genes and dark gray elsewhere', severity: 'high', dimension: 'consistency', evidence: 'phenotypes.png top right header' },
      { issue: 'Garbled placeholder text ".. Disease ontology ... ." with irregular trailing dots and spaces', severity: 'med', dimension: 'typography', evidence: 'phenotypes.png filter row 3rd input' },
      { issue: 'High contrast mismatch between filled AND button and unselected OR button', severity: 'low', dimension: 'color_contrast', evidence: 'phenotypes.png tag bar' }
    ],
    improvements: [
      { recommendation: 'Unify header actions with the shared table toolbar standard, removing one-off orange variant', effort: 'S', sprint_type: 'foundation-shared', expected_impact: 'Eliminates jarring color surprises' },
      { recommendation: 'Clean up placeholder strings to "Filter disease..." and "Inheritance"', effort: 'S', sprint_type: 'per-page', expected_impact: 'Professional clinical polish' }
    ]
  },
  {
    page: 'panels',
    title: 'Panel Compilation Table',
    route: '/Panels/All/All',
    scores: { hierarchy: 7, typography: 6, color_contrast: 7, consistency: 6, spacing_density: 7, responsiveness: 7, accessibility: 10, dataviz: 6, interaction_states: 7, content_clarity: 7 },
    overall: 71,
    one_line_verdict: 'Outlier among public tables: lacks standard category/inheritance chips and uses proportional sans font for database identifiers and genomic coordinates.',
    top_findings: [
      { issue: 'Category and Inheritance columns render truncated plain text rather than standard semantic chips (.sysndd-chip)', severity: 'high', dimension: 'dataviz', evidence: 'panels.png 1st and 2nd columns' },
      { issue: 'Identifiers (HGNC, Entrez, Ensembl, UCSC, BED coords) use proportional body font instead of --font-family-mono', severity: 'high', dimension: 'typography', evidence: 'panels.png columns 4-9' },
      { issue: 'Column toggle is an inline button in the filter row ("Columns 9/9") rather than an action icon in the header', severity: 'med', dimension: 'consistency', evidence: 'panels.png toolbar row' }
    ],
    improvements: [
      { recommendation: 'Convert Category to CategoryIcon + badge and Inheritance to .sysndd-chip badges', effort: 'M', sprint_type: 'per-page', expected_impact: 'Brings Panels into visual parity with Entities and Genes' },
      { recommendation: 'Apply font-mono class to HGNC, Entrez, Ensembl, UCSC, and BED coordinate columns', effort: 'S', sprint_type: 'per-page', expected_impact: 'Scannable scientific data formatting' }
    ]
  },
  {
    page: 'curationcomparisons',
    title: 'Curation Comparisons (UpSet)',
    route: '/CurationComparisons',
    scores: { hierarchy: 7, typography: 7, color_contrast: 7, consistency: 6, spacing_density: 7, responsiveness: 7, accessibility: 10, dataviz: 8, interaction_states: 7, content_clarity: 7 },
    overall: 72,
    one_line_verdict: 'Powerful UpSet visualization weakened by card-in-card nesting, duplicate headers, and duplicate question mark icons.',
    top_findings: [
      { issue: 'Card inside card anti-pattern: inner bordered card duplicates outer tab title "Overlap"', severity: 'high', dimension: 'hierarchy', evidence: 'curationcomparisons.png inner card' },
      { issue: 'Duplicate question mark icons "(?) (?)" in inner card header', severity: 'high', dimension: 'consistency', evidence: 'curationcomparisons.png header title' },
      { issue: 'Source toggle chips use random discordant colors (blue, green, cyan) rather than systematic palette', severity: 'med', dimension: 'color_contrast', evidence: 'curationcomparisons.png source pills' }
    ],
    improvements: [
      { recommendation: 'Flatten inner card chrome into AnalysisShell content, remove duplicate "Overlap" heading', effort: 'M', sprint_type: 'per-page', expected_impact: 'Removes nested card chrome and visual clutter' },
      { recommendation: 'Remove redundant second help button and standardize source chips to --medical-blue and --neutral tokens', effort: 'S', sprint_type: 'per-page', expected_impact: 'Clean, singular help affordance and cohesive colors' }
    ]
  },
  {
    page: 'curationcomparisons-similarity',
    title: 'Curation Comparisons Similarity Matrix',
    route: '/CurationComparisons/Similarity',
    scores: { hierarchy: 6, typography: 7, color_contrast: 6, consistency: 6, spacing_density: 6, responsiveness: 6, accessibility: 10, dataviz: 5, interaction_states: 6, content_clarity: 6 },
    overall: 64,
    one_line_verdict: 'Critical data visualization omission: cosine similarity heatmap lacks any color scale legend or numerical key.',
    top_findings: [
      { issue: 'NO COLOR SCALE / LEGEND: heatmap displays shades of dark red to light pink with zero indication of numerical correlation/similarity range', severity: 'high', dimension: 'dataviz', evidence: 'curationcomparisons-similarity.png' },
      { issue: 'Card-in-card nesting with duplicate "Similarity" header', severity: 'med', dimension: 'hierarchy', evidence: 'curationcomparisons-similarity.png' },
      { issue: 'Excessive whitespace around centered matrix with no supplementary statistics or context', severity: 'med', dimension: 'spacing_density', evidence: 'curationcomparisons-similarity.png layout' }
    ],
    improvements: [
      { recommendation: 'Add clear, token-styled color scale legend bar (0.0 to 1.0) below the matrix plot', effort: 'M', sprint_type: 'per-page', expected_impact: 'Makes the visualization quantitatively interpretable' },
      { recommendation: 'Flatten nested card border and integrate controls cleanly into AnalysisShell', effort: 'S', sprint_type: 'per-page', expected_impact: 'Single unified surface' }
    ]
  },
  {
    page: 'curationcomparisons-table',
    title: 'Curation Comparisons Table',
    route: '/CurationComparisons/Table',
    scores: { hierarchy: 7, typography: 6, color_contrast: 7, consistency: 6, spacing_density: 7, responsiveness: 7, accessibility: 10, dataviz: 8, interaction_states: 7, content_clarity: 6 },
    overall: 70,
    one_line_verdict: 'Valuable cross-database comparison table marred by truncated column headers ("Gene2Phenoty") and overflowing filter dropdowns.',
    top_findings: [
      { issue: 'Column header truncated to "Gene2Phenoty" and filter dropdowns overflow into arrows (.. Gene2Phenoty, .. Radboudumc.., .. NDD GeneHub)', severity: 'high', dimension: 'typography', evidence: 'curationcomparisons-table.png' },
      { issue: 'Header actions repeat mismatched 3-color cluster (dark gray, green, cyan)', severity: 'med', dimension: 'consistency', evidence: 'curationcomparisons-table.png top right' },
      { issue: 'Nested card chrome inside AnalysisShell with duplicate title "Curation effort comparisons"', severity: 'med', dimension: 'hierarchy', evidence: 'curationcomparisons-table.png' }
    ],
    improvements: [
      { recommendation: 'Fix column header width / label truncation and provide clean filter select option labels', effort: 'S', sprint_type: 'per-page', expected_impact: 'Eliminates text collisions and ugly truncation' },
      { recommendation: 'Flatten nested card chrome and apply unified table action buttons', effort: 'S', sprint_type: 'foundation-shared', expected_impact: 'Consistent table appearance' }
    ]
  },
  {
    page: 'phenotypecorrelations',
    title: 'Phenotype Correlations (Correlogram)',
    route: '/PhenotypeCorrelations',
    scores: { hierarchy: 6, typography: 5, color_contrast: 6, consistency: 6, spacing_density: 5, responsiveness: 5, accessibility: 10, dataviz: 5, interaction_states: 6, content_clarity: 5 },
    overall: 58,
    one_line_verdict: 'Severe visual defect: X-axis labels rotated 90 degrees are vertically clipped through the center of the words, rendering them illegible.',
    top_findings: [
      { issue: 'X-axis labels are vertically CLIPPED through the middle of the text lines ("idney", "ystem", "mality"), completely unreadable', severity: 'high', dimension: 'dataviz', evidence: 'phenotypecorrelations.png bottom of chart' },
      { issue: 'Correlation color scale legend is positioned off-screen / pushed below default viewport on desktop', severity: 'high', dimension: 'dataviz', evidence: 'phenotypecorrelations.png viewport bottom' },
      { issue: 'Nested card chrome with redundant "Matrix of phenotype correlations" title', severity: 'med', dimension: 'hierarchy', evidence: 'phenotypecorrelations.png' },
      { issue: 'Tab bar overflows on mobile without visual scroll cues', severity: 'med', dimension: 'responsiveness', evidence: 'phenotypecorrelations-mobile.png' }
    ],
    improvements: [
      { recommendation: 'Increase bottom SVG/plot margin and configure proper text-anchor and padding so rotated HPO term labels never clip', effort: 'M', sprint_type: 'per-page', expected_impact: 'Restores primary scientific readability of the correlogram' },
      { recommendation: 'Position correlation legend alongside or immediately beneath chart within the visible frame', effort: 'S', sprint_type: 'per-page', expected_impact: 'Immediate interpretive context' }
    ]
  },
  {
    page: 'phenotypecounts',
    title: 'Phenotype Counts Bar Plot',
    route: '/PhenotypeCorrelations/PhenotypeCounts',
    scores: { hierarchy: 7, typography: 6, color_contrast: 7, consistency: 6, spacing_density: 5, responsiveness: 6, accessibility: 10, dataviz: 6, interaction_states: 6, content_clarity: 6 },
    overall: 64,
    one_line_verdict: 'Frequency chart suffers from overlapping, crammed 45-degree rotated category labels on the X-axis.',
    top_findings: [
      { issue: 'X-axis bar labels are rotated 45 degrees and overlap into each other, creating an unreadable dense strip', severity: 'high', dimension: 'typography', evidence: 'phenotypecounts.png bottom axis' },
      { issue: 'Nested card chrome inside AnalysisShell with duplicate title', severity: 'med', dimension: 'hierarchy', evidence: 'phenotypecounts.png' },
      { issue: 'Lack of interactive hover tooltip or value display on bars', severity: 'low', dimension: 'interaction_states', evidence: 'phenotypecounts.png' }
    ],
    improvements: [
      { recommendation: 'Improve label spacing, consider horizontal bar layout or intelligent font scaling with hover highlights', effort: 'M', sprint_type: 'per-page', expected_impact: 'High-density scannable phenotype distribution' },
      { recommendation: 'Flatten nested card border into AnalysisShell body', effort: 'S', sprint_type: 'per-page', expected_impact: 'Consistent single-surface layout' }
    ]
  },
  {
    page: 'phenotypeclusters',
    title: 'Phenotype Clusters Network & Synthesis',
    route: '/PhenotypeCorrelations/PhenotypeClusters',
    scores: { hierarchy: 6, typography: 6, color_contrast: 4, consistency: 5, spacing_density: 6, responsiveness: 5, accessibility: 6, dataviz: 7, interaction_states: 6, content_clarity: 5 },
    overall: 54,
    one_line_verdict: 'Lowest scoring page: 3 failing Lighthouse accessibility audits (1.5:1 yellow AI contrast, heading order, button name mismatch), garish consumer-AI sparkle tropes, and broken mobile export buttons.',
    top_findings: [
      { issue: 'FAILING WCAG CONTRAST (1.5:1): Yellow "AI" label (#ffc107 on #fff6da) is virtually invisible and severely fails AA requirement', severity: 'high', dimension: 'accessibility', evidence: 'lighthouse/phenotypeclusters.json & phenotypeclusters.png' },
      { issue: 'HEAVY AI SMELL & TELL: Consumer-style sparkle emoji "✨ AI Summary — Cluster 1" and fake "Verified" badge degrade clinical credibility', severity: 'high', dimension: 'content_clarity', evidence: 'phenotypeclusters.png bottom right card' },
      { issue: 'FAILING HEADING ORDER: Card uses <h6> for "Organ-system involvement", skipping h2-h5 levels', severity: 'high', dimension: 'accessibility', evidence: 'lighthouse/phenotypeclusters.json' },
      { issue: 'ACCESSIBLE NAME MISMATCH: .xlsx button has visible text ".xlsx" but aria-label "Download table data as Excel file" without matching text', severity: 'med', dimension: 'accessibility', evidence: 'lighthouse/phenotypeclusters.json' },
      { issue: 'Cluster link #0d6efd on #fafafa has contrast 4.31:1, failing AA 4.5:1 requirement', severity: 'high', dimension: 'color_contrast', evidence: 'lighthouse/phenotypeclusters.json' },
      { issue: 'Mobile export buttons collapse into giant empty rectangle blocks', severity: 'med', dimension: 'responsiveness', evidence: 'phenotypeclusters-mobile.png' }
    ],
    improvements: [
      { recommendation: 'Eliminate sparkle emojis and "✨ AI Summary"; rebrand to dignified clinical nomenclature: "Cluster Synthesis" or "Phenotypic Profile"', effort: 'S', sprint_type: 'per-page', expected_impact: 'Zero AI smell; restores clinical research credibility' },
      { recommendation: 'Fix all 3 a11y failures: replace yellow AI badge with high-contrast token pill, fix h6 -> h3, align button accessible name to include "xlsx", use --medical-blue-700 (8.59:1) for cluster link', effort: 'M', sprint_type: 'per-page', expected_impact: 'Restores Lighthouse a11y score from 96 to 100' },
      { recommendation: 'Fix mobile button sizing so export buttons remain compact icon buttons', effort: 'S', sprint_type: 'per-page', expected_impact: 'Clean responsive layout at 390px' }
    ]
  },
  {
    page: 'nddscore',
    title: 'NDDScore Machine Learning Predictions',
    route: '/NDDScore',
    scores: { hierarchy: 6, typography: 7, color_contrast: 6, consistency: 6, spacing_density: 5, responsiveness: 6, accessibility: 10, dataviz: 7, interaction_states: 7, content_clarity: 6 },
    overall: 62,
    one_line_verdict: 'Overly defensive card-in-card disclaimer stack with sparkle emojis forces the actual prediction table below the fold.',
    top_findings: [
      { issue: 'AI SMELL & TELL: Consumer-style sparkle emoji "✨ ML prediction" used in header badge and banner card', severity: 'med', dimension: 'content_clarity', evidence: 'nddscore.png top badge and banner' },
      { issue: 'Massive disclaimer banner with nested metric cards (AUC-ROC, Brier) consumes entire initial viewport, especially on mobile', severity: 'high', dimension: 'hierarchy', evidence: 'nddscore.png and nddscore-mobile.png' },
      { issue: 'Filter select option text overlaps dropdown arrow (".. Top inherita")', severity: 'med', dimension: 'typography', evidence: 'nddscore.png 9th filter input' },
      { issue: 'Inconsistent placeholder styles (mixing "Filter Gene", "Any NDD sco...", and ".. Risk tier ..")', severity: 'med', dimension: 'consistency', evidence: 'nddscore.png filter row' },
      { issue: 'Same mismatched header buttons (dark gray, green, cyan)', severity: 'med', dimension: 'consistency', evidence: 'nddscore.png header' }
    ],
    improvements: [
      { recommendation: 'Remove sparkle emojis; distill model disclaimer into a compact, elegant metadata header strip with inline metrics (AUC-ROC, Brier score) instead of a giant multi-card stack', effort: 'M', sprint_type: 'per-page', expected_impact: 'Immediate table visibility, zero AI smell, compact clinical density' },
      { recommendation: 'Standardize filter placeholders to clean "Filter [Field]" or "All [Field]" format, avoiding text truncation into select arrows', effort: 'S', sprint_type: 'per-page', expected_impact: 'Visual polish and readable controls' },
      { recommendation: 'Apply shared unified table action buttons', effort: 'S', sprint_type: 'foundation-shared', expected_impact: 'Consistent action cluster' }
    ]
  }
];

// Calculate summary stats
const meanScore = Math.round((auditData.reduce((acc, p) => acc + p.overall, 0) / auditData.length) * 10) / 10;
const meanA11y = Math.round((auditData.reduce((acc, p) => acc + p.scores.accessibility, 0) / auditData.length) * 10) / 10;
const meanLhA11y = Math.round((Object.values(lhMap).reduce((acc, p) => acc + p.a11y, 0) / Object.values(lhMap).length) * 10) / 10;
const meanLhPerf = Math.round((Object.values(lhMap).reduce((acc, p) => acc + p.perf, 0) / Object.values(lhMap).length) * 10) / 10;

const ratingsJson = {
  metadata: {
    title: 'SysNDD Impeccable Design & Lighthouse Audit',
    date: '2026-09-08',
    reviewer_calibration: '145 IQ Design Director & Clinical UI/UX Specialist',
    total_pages_reviewed: 12,
    mean_impeccable_score: meanScore,
    mean_lighthouse_perf: meanLhPerf,
    mean_lighthouse_a11y: meanLhA11y,
    pages_at_100_a11y: Object.values(lhMap).filter(p => p.a11y === 100).length
  },
  lighthouse: lhMap,
  ratings: auditData
};

writeFileSync(`${OUT}/ratings.json`, JSON.stringify(ratingsJson, null, 2));

// Generate AUDIT.md
let auditMd = `# SysNDD 145-IQ Impeccable UI/UX & Lighthouse Design Audit
Date: 2026-09-08
Reviewer Calibration: Award-winning Design Director & Senior Clinical Product Designer (145-IQ calibration)
Target: 12 Core Public Surfaces requested on https://sysndd.dbmr.unibe.ch/

---

## Executive Summary

- **Total Scanned Pages:** 12 production routes
- **Lighthouse Performance Mean:** **${meanLhPerf} / 100** (prod build)
- **Lighthouse Accessibility Mean:** **${meanLhA11y} / 100** (11/12 pages at 100, 1 at 96)
- **Lighthouse Best Practices:** **100 / 100** on all 12 pages
- **Lighthouse SEO:** **92-100 / 100** on all 12 pages
- **Mean Impeccable Design Score:** **${meanScore} / 100** (Range: 54 - 82)
- **Target Post-Overhaul:** **> 90 / 100** across all pages, 100% Lighthouse A11y, unified SCSS, and **Zero AI Smell and Tell**.

---

## Scoreboard

| Page | Impeccable Score | LH Perf | LH A11y | LH BP | LH SEO | Hier | Type | Color | Cons | Space | Resp | A11y | DViz | State | Clar (No AI Smell) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
`;

for (const p of auditData) {
  const lh = lhMap[p.page] || { perf: '-', a11y: '-', bp: '-', seo: '-' };
  const s = p.scores;
  auditMd += `| \`${p.page}\` | **${p.overall}** | ${lh.perf} | ${lh.a11y} | ${lh.bp} | ${lh.seo} | ${s.hierarchy} | ${s.typography} | ${s.color_contrast} | ${s.consistency} | ${s.spacing_density} | ${s.responsiveness} | ${s.accessibility} | ${s.dataviz} | ${s.interaction_states} | ${s.content_clarity} |\n`;
}

auditMd += `
---

## Key Systemic Findings (Root Causes)

### 1. "AI Smell and Tell" & Cheesy Consumer-AI Tropes
- **Cluster 1 Phenotype Synthesis (\`/PhenotypeCorrelations/PhenotypeClusters\`):** Renders a garish \`✨ AI Summary — Cluster 1\` card with yellow sparkle emoji and a \`✔ Verified\` pill. In a clinical genetics research database, consumer AI marketing gimmicks erode institutional trust.
- **NDDScore Disclaimers (\`/NDDScore\`):** Uses \`✨ ML prediction\` sparkles in badges and titles, and wraps the page in an overly defensive, multi-nested card disclaimer stack with giant metric callout cards that push the gene table entirely below the fold.

### 2. Action Button Color Chaos & Visual Disharmony
- Across public tables (\`/Entities\`, \`/Genes\`, \`/Phenotypes\`, \`/CurationComparisons/Table\`, \`/NDDScore\`), table header utility buttons exhibit discordant coloring:
  - Export: dark gray \`#424242\`
  - Copy Link: bright green \`#2e7d32\`
  - Column Toggle: bright cyan on Entities/Genes, but bright ORANGE/YELLOW on Phenotypes!
  - Panels table uses an inline text button \`Columns 9/9\` in the toolbar instead of a header icon button.
  - These buttons should form a calm, coherent utility button group using subtle neutral borders and tokens.

### 3. Amateurish Filter Placeholders & Label Collisions
- Filter inputs across data tables use a developer placeholder convention: \`.. Entity ..\`, \`.. Symbol ..\`, \`.. Disease ontology ... .\`, \`.. Hpo mode of inherit... ..\`.
- Several dropdown filter selects (\`.. Top inherita\`, \`.. Gene2Phenoty\`, \`.. Radboudumc..\`, \`.. NDD GeneHub\`) collide with and clip under the dropdown caret icon.
- Column headers suffer from abrupt truncation (e.g. \`Gene2Phenoty\` instead of \`Gene2Phenotype\`, \`Hpo mode of inherit...\` instead of \`Inheritance\`).

### 4. Card-in-Card Nesting & Redundant Chrome
- Inside \`AnalysisShell\` (\`/CurationComparisons\` and \`/PhenotypeCorrelations\` tabs), child views embed another full bordered card component with duplicate headers (e.g. Tab reads "Overlap" and inner card header reads "Overlap (?) (?)"), violating the visual design guide rule against nested UI cards.
- On \`/CurationComparisons\`, the header renders two identical question mark buttons side-by-side.

### 5. Critical Data-Viz Defects
- **Phenotype Correlogram (\`/PhenotypeCorrelations\`):** Rotated X-axis HPO term labels are vertically sliced through the middle of the text, making them completely unreadable.
- **Curation Similarity (\`/CurationComparisons/Similarity\`):** The cosine similarity heatmap has NO legend or numerical color scale bar whatsoever.
- **Phenotype Counts (\`/PhenotypeCorrelations/PhenotypeCounts\`):** 45-degree angled bar labels overlap and cram together into an illegible jumble.

### 6. Lighthouse Accessibility Regressions on PhenotypeClusters (Score: 96)
- **Contrast Failure 1:** \`span.ai-label\` has contrast ratio **1.5:1** (yellow text \`#ffc107\` on pale yellow \`#fff6da\`).
- **Contrast Failure 2:** Cluster link \`#0d6efd\` on \`#fafafa\` has contrast ratio **4.31:1** (fails AA 4.5:1).
- **Heading Order Violation:** Uses \`<h6>Organ-system involvement</h6>\` skipping h2-h5 levels.
- **Accessible Name Mismatch:** \`.xlsx\` button visible text \`.xlsx\` does not match aria-label \`Download table data as Excel file\`.

### 7. SCSS Architecture Inconsistencies & Token Drift
- Undefined variable reference: \`--border-radius-base\` used in \`_responsive.scss:22\` and \`_tables.scss:140\` (defaults to 0px in browsers).
- Invalid CSS property: \`aria-label: 'required'\` inside SCSS rules in \`_forms.scss:24\`.
- Negative letter-spacing in \`_typography.scss:37,71\` violating the Visual Design Guide mandate to avoid negative letter spacing in dense tables.
- Extensive hardcoded hex values in \`_public-pages.scss\` (\`#f6f8fb\`, \`#d9e1ec\`, \`#102033\`, \`#667085\`, \`#1d2939\`, \`#9fb3c8\`) and \`HomeView.vue\` instead of central tokens.
`;

writeFileSync(`${OUT}/AUDIT.md`, auditMd);

// Generate AUDIT-per-page.md
let perPageMd = `# SysNDD Detailed Per-Page Design & Lighthouse Audit
Date: 2026-09-08
Reviewer: 145-IQ Design Director & Senior Clinical Product Designer

`;

for (const p of auditData) {
  const lh = lhMap[p.page] || { perf: '-', a11y: '-', bp: '-', seo: '-' };
  perPageMd += `## ${p.title} (\`${p.page}\`)
**Route:** \`${p.route}\`  
**Overall Impeccable Score:** **${p.overall} / 100**  
**Lighthouse:** Performance: **${lh.perf}** | Accessibility: **${lh.a11y}** | Best Practices: **${lh.bp}** | SEO: **${lh.seo}**  
**Verdict:** ${p.one_line_verdict}

### Scores (1-10)
- Visual Hierarchy: **${p.scores.hierarchy}**
- Typography: **${p.scores.typography}**
- Color & Contrast: **${p.scores.color_contrast}**
- Consistency & Design Language: **${p.scores.consistency}**
- Spacing & Density: **${p.scores.spacing_density}**
- Responsiveness: **${p.scores.responsiveness}**
- Accessibility: **${p.scores.accessibility}**
- Data Visualization: **${p.scores.dataviz}**
- Interaction & States: **${p.scores.interaction_states}**
- Content Clarity & Tone (No AI Smell): **${p.scores.content_clarity}**

### Findings & Concrete Evidence
${p.top_findings.map(f => `- **[${f.severity.toUpperCase()}] [${f.dimension}]** ${f.issue} (Evidence: \`${f.evidence}\`)`).join('\n')}

### Recommended Improvements
${p.improvements.map(i => `- **[${i.sprint_type}] (${i.effort})** ${i.recommendation} — *Impact: ${i.expected_impact}*`).join('\n')}

---

`;
}

writeFileSync(`${OUT}/AUDIT-per-page.md`, perPageMd);
console.log('Successfully generated ratings.json, AUDIT.md, and AUDIT-per-page.md');
