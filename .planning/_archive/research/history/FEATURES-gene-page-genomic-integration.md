# Feature Landscape: Gene Page Genomic Data Integration

**Domain:** Genomic database gene detail pages for clinical genetics
**Researched:** 2026-01-27
**Focus:** Gene page enhancements for neurodevelopmental disorder database
**Confidence:** HIGH

## Executive Summary

Gene detail pages in modern genomic databases serve as critical decision-support tools for clinical geneticists assessing pathogenicity. Research of competitive examples (gnomAD, DECIPHER, ClinGen, UniProt, AlphaFold DB) reveals clear patterns in information architecture, constraint score visualization, variant summaries, and protein structure integration. This document categorizes features into table stakes (expected baseline), differentiators (competitive advantages), and anti-features (common mistakes to avoid) for the SysNDD gene page enhancement milestone.

**Key Finding:** The industry has shifted from flat, table-based gene pages to card-based, hierarchical layouts with interactive visualizations. Constraint scores, ClinVar summaries, and protein domain plots are now expected baseline features for clinical genetics databases.

---

## Table Stakes Features

Features users expect in a modern gene page. Missing these creates friction and reduces trust.

### TS-1: Prominent Hero Section with Core Gene Identity

**What:** Large, above-the-fold section displaying gene symbol, full name, primary identifiers (HGNC ID, chromosome location, Ensembl ID), and quick actions.

**Why Expected:**
- gnomAD, DECIPHER, ClinGen all use hero sections
- Clinical users need immediate gene confirmation before scrolling
- Follows 2026 web UX patterns for "above the fold" optimization

**Complexity:** Low
**Dependencies:** Existing gene data (symbol, name, hgnc_id, chromosome location)

**Implementation Notes:**
- Asymmetric layout with gene symbol/badge left, actions right
- Copy-to-clipboard for symbol and IDs (standard pattern)
- Breadcrumb or back navigation
- Mobile-responsive (stack vertically)

**Competitive Examples:**
- gnomAD: Gene symbol with transcript selector, coordinates, quick stats
- UniProt: Accession with protein name, organism, gene names
- GeneCards: Gene symbol with aliases, location, and sections navigator

---

### TS-2: gnomAD Constraint Scores (pLI, LOEUF, mis_z)

**What:** Display of three key constraint metrics indicating gene intolerance to loss-of-function and missense variants.

**Why Expected:**
- **pLI ≥ 0.9** is standard threshold for haploinsufficiency screening
- **LOEUF < 0.6** (gnomAD v4) or **< 0.35** (v2.1.1) indicates constrained genes
- **mis_z** indicates missense constraint
- Used in every clinical variant interpretation workflow
- ClinGen explicitly recommends using gnomAD constraint in gene-disease validity curation

**Complexity:** Medium
**Dependencies:**
- Backend endpoint to gnomAD GraphQL API
- Server-side caching (24h TTL recommended)

**Visualization Patterns:**

1. **Gauge/Meter Display (RECOMMENDED)**
   - Visual gauge showing score with color-coded threshold zones
   - pLI: Green (0-0.9), Red (≥0.9 haploinsufficient)
   - LOEUF: Red (<0.35), Yellow (0.35-0.6), Green (>0.6)
   - Labels: "Tolerant" vs "Constrained"

2. **Number + Context**
   - Large number with small descriptor
   - Example: **pLI: 0.99** (Haploinsufficient)
   - Example: **LOEUF: 0.12** (Highly constrained)

3. **Threshold Indicators**
   - Visual marker showing where score falls relative to thresholds
   - Similar to progress bars but with meaning anchors

**Display Pattern:**
```
┌─────────────────────────────┐
│ gnomAD Constraint v4.1      │
│                             │
│ pLI: [████████░░] 0.99      │
│      Haploinsufficient      │
│                             │
│ LOEUF: [██░░░░░░░░] 0.12    │
│        Highly constrained   │
│                             │
│ mis_z: [█████░░░░░] 3.2     │
│        Missense constrained │
│                             │
│ [View in gnomAD →]          │
└─────────────────────────────┘
```

**Data Source:** gnomAD GraphQL API
- Endpoint: `https://gnomad.broadinstitute.org/api`
- Query: `gene(gene_symbol: "...", reference_genome: GRCh38) { gnomad_constraint { pLI, oe_lof, oe_lof_upper, mis_z } }`
- Cache: 24 hours (constraint scores stable)

**Important Notes:**
- gnomAD v4.0 constraint metrics are still experimental (beta stage)
- v2.1.1 metrics remain more established for clinical use
- Consider displaying both versions or allowing toggle
- Include version indicator and "Last updated" timestamp

**References:**
- [gnomAD v4.0 Gene Constraint](https://gnomad.broadinstitute.org/news/2024-03-gnomad-v4-0-gene-constraint/)
- [Gene constraint help](https://gnomad.broadinstitute.org/help/constraint)

---

### TS-3: ClinVar Variant Summary

**What:** Aggregate counts of variants by clinical significance (Pathogenic, Likely Pathogenic, VUS, Likely Benign, Benign, Conflicting).

**Why Expected:**
- Standard clinical question: "How many pathogenic variants exist in this gene?"
- ClinVar is the authoritative source for clinical variant interpretation
- Pattern distribution (where P/LP variants cluster) informs ACMG classification
- gnomAD v4 includes ClinVar data in gene pages

**Complexity:** Medium
**Dependencies:**
- ClinVar data via gnomAD GraphQL API (recommended) OR direct ClinVar API
- Backend proxy endpoint with caching

**Visualization Patterns:**

1. **Summary Card with Counts (RECOMMENDED)**
```
┌──────────────────────────────┐
│ ClinVar Variants             │
│                              │
│ ● 23  Pathogenic/Likely Path │
│ ● 45  VUS                    │
│ ● 12  Benign/Likely Benign   │
│ ● 3   Conflicting            │
│                              │
│ Total: 83 variants           │
│ [View distribution on plot →]│
└──────────────────────────────┘
```

2. **Color-Coded Bars**
   - Horizontal bar chart with ACMG colors
   - Red: Pathogenic
   - Orange: Likely Pathogenic
   - Yellow: VUS
   - Light Green: Likely Benign
   - Green: Benign
   - Purple: Conflicting

**ACMG Color Scheme (STANDARD):**
```css
--acmg-pathogenic: #D32F2F (red)
--acmg-likely-pathogenic: #F57C00 (orange)
--acmg-uncertain: #FBC02D (yellow)
--acmg-likely-benign: #9CCC65 (light green)
--acmg-benign: #388E3C (green)
--acmg-conflicting: #7B1FA2 (purple)
```

**Clinical Significance Categories (ClinVar standard):**
1. Pathogenic
2. Likely pathogenic
3. Uncertain significance (VUS)
4. Likely benign
5. Benign
6. Conflicting interpretations of pathogenicity

**Data Sources:**

**Option A (RECOMMENDED): Via gnomAD API**
- gnomAD includes `clinvar_variants` field in gene queries
- Benefit: Single API call for constraint + ClinVar
- Example: Simple ClinVar tool uses this approach

**Option B: Direct ClinVar API**
- NCBI E-utilities or ClinVar API
- More comprehensive but requires separate call
- May include additional metadata not in gnomAD

**Display Requirements:**
- Group P + LP together (clinically actionable)
- Highlight conflicting variants (requires deeper review)
- Link to detailed variant list (could be table below fold)

**References:**
- [Simple ClinVar](https://simple-clinvar.broadinstitute.org/)
- [ClinVar Classifications](https://www.ncbi.nlm.nih.gov/clinvar/docs/clinsig/)
- [gnomAD ClinVar Display](https://clinicalgenome.org/tools/educational-resources/materials/gnomad-v4-overview/)

---

### TS-4: Logical Grouping of External Database Links

**What:** External links organized by purpose (Clinical Resources, Sequence Databases, Model Organisms, Protein Resources) rather than flat list.

**Why Expected:**
- Current SysNDD gene page has 11 external links in flat stacked table
- Users scan for "clinical" vs "sequence" information separately
- Card-based layouts with icons are now standard (GeneCards, DECIPHER)
- Reduces cognitive load and improves scannability

**Complexity:** Low
**Dependencies:** Existing gene identifiers

**Grouping Structure (RECOMMENDED):**

```
┌───────────────────────┐  ┌─────────────────────────────┐
│ GENE IDENTIFIERS      │  │ CLINICAL RESOURCES          │
│                       │  │                             │
│ NCBI Gene    Copy ↗   │  │ ┌──────┐ ┌───────┐ ┌─────┐ │
│ Ensembl      Copy ↗   │  │ │OMIM  │ │ClinGen│ │SFARI│ │
│ UniProt      Copy ↗   │  │ └──────┘ └───────┘ └─────┘ │
│ UCSC         Copy     │  │ ┌────────┐ ┌──────┐ ┌────┐ │
│ CCDS         Copy     │  │ │PanelApp│ │gene2p│ │HGNC│ │
│                       │  │ └────────┘ └──────┘ └────┘ │
│ STRING       ↗        │  └─────────────────────────────┘
└───────────────────────┘
┌─────────────────────────────────────────┐
│ MODEL ORGANISMS                         │
│ 🐭 Mouse (MGI)        [Copy] [↗]        │
│ 🐀 Rat (RGD)          Not available     │
└─────────────────────────────────────────┘
```

**Categories:**

1. **Gene Identifiers** (Sequence Databases)
   - NCBI Gene (Entrez ID)
   - Ensembl Gene ID
   - UniProt Accession
   - UCSC ID
   - CCDS ID
   - Purpose: Genomic/transcript coordinates

2. **Clinical Resources**
   - OMIM (Mendelian inheritance)
   - ClinGen (Gene-disease validity)
   - SFARI (Autism research)
   - PanelApp (Gene panels)
   - gene2phenotype (Genotype-phenotype)
   - HGNC (Official nomenclature)
   - Purpose: Disease associations, clinical evidence

3. **Model Organisms**
   - MGI (Mouse Genome Informatics)
   - RGD (Rat Genome Database)
   - Purpose: Ortholog phenotypes for functional evidence

4. **Protein Interactions**
   - STRING (Protein-protein interactions)
   - Purpose: Functional networks

**UX Patterns:**
- **Copy-to-clipboard button** for all IDs (don't force external navigation)
- **Card/tile design** for clinical resources (visual, scannable)
- **Empty state handling:** "Not available" instead of hiding
- **Icon per resource** for quick recognition
- **Tooltip on hover** with resource description

**Reference Implementations:**
- GeneCards uses card-based external links with icons
- DECIPHER groups resources by clinical/sequence/functional

---

### TS-5: Protein Domain Lollipop Plot with Variants

**What:** Interactive D3.js visualization showing protein domains, regions, and mapped ClinVar variants as lollipops color-coded by pathogenicity.

**Why Expected:**
- Standard visualization in gnomAD, ClinGen, DECIPHER, Simple ClinVar
- Reveals variant clustering patterns (hotspots indicate functional domains)
- Visual pattern recognition faster than table scanning
- Critical for ACMG PS1 criterion (same amino acid, different change)

**Complexity:** High
**Dependencies:**
- UniProt REST API (protein domains and features)
- ClinVar variants with protein position (HGVS p. notation)
- D3.js v7 library
- Backend proxy endpoints with caching

**Visualization Components:**

1. **Protein Backbone**
   - Horizontal track representing amino acid sequence (1 to length)
   - Scale: amino acid positions (e.g., 1, 100, 200, 300...)
   - Length shown at right end

2. **Domain Annotations** (Below Backbone)
   - Rectangles for domains (e.g., "Kinase domain 150-300")
   - Different colors per domain type
   - Labels on hover or always visible if space allows

3. **Variant Lollipops** (Above Backbone)
   - Circle (lollipop head) at exact amino acid position
   - Stem connecting to backbone
   - Color by ACMG pathogenicity
   - Size by variant count (if multiple variants at same position)

4. **Interactions**
   - **Zoom/pan:** D3 zoom behavior for long proteins (>500 AA)
   - **Tooltip (pinnable):** Show variant details on hover/click
     - HGVS p. notation (e.g., p.Arg177Gly)
     - Clinical significance
     - Review status (gold stars)
     - Link to ClinVar entry
   - **Filter controls:**
     - Show/hide by clinical significance
     - Show/hide benign variants (reduce clutter)
     - Consequence type filter (missense, nonsense, frameshift)

**Data Requirements:**

1. **From UniProt:**
   - Protein accession
   - Protein length (amino acids)
   - Domain annotations (type, description, start, end)
   - API: `https://rest.uniprot.org/uniprotkb/{accession}.json`

2. **From ClinVar (via gnomAD):**
   - Variant HGVS protein notation (p.)
   - Extract amino acid position from HGVS
   - Clinical significance
   - Gold star review status

**Technical Implementation:**

**Library:** Use dedicated genomic lollipop library or custom D3
- **g3lollipop.js** (60+ chart options, 37 color palettes) — RECOMMENDED
- OR custom D3.js with standard patterns from D3 Graph Gallery

**Best Practices:**
- Circular discs sized by occurrence count
- Color-coded by ACMG pathogenicity
- Variants at same position: stack vertically in descending order
- Hover interaction highlights variant + shows tooltip
- Pinnable tooltip (click to pin, click outside to dismiss)

**Layout Pattern:**
```
   ● ●●●  ●    ●●      ●              ●●  ●    ●
   │ │││  │    ││      │              ││  │    │
═══╪═╪╪╪══╪════╪╪══════╪══════════════╪╪══╪════╪═════════
   1  [====Domain 1====][==Domain 2==]   [==Domain 3==] 500
Legend: ● Pathogenic  ● Likely Path  ● VUS  ● Benign
```

**Complexity Note:** High due to:
- D3.js learning curve for custom plots
- HGVS parsing to extract amino acid positions
- Coordinating UniProt domains + ClinVar variants
- Performance optimization for genes with >100 variants

**References:**
- [g3lollipop.js GitHub](https://github.com/G3viz/g3lollipop.js/)
- [D3 Lollipop Chart Examples](https://d3-graph-gallery.com/lollipop)
- [Simple ClinVar protein plots](https://simple-clinvar.broadinstitute.org/)
- [ProteinPaint GDC lollipop](https://docs.gdc.cancer.gov/Data_Portal/Users_Guide/proteinpaint_lollipop/)

---

### TS-6: Empty State Handling and Progressive Disclosure

**What:** Graceful handling of missing data ("Not available" messages) and collapsible/expandable sections for information density control.

**Why Expected:**
- Not all genes have all data (e.g., no AlphaFold structure, no ClinVar variants)
- Silent failures reduce trust
- Progressive disclosure prevents overwhelming users
- Modern UX standard across web applications

**Complexity:** Low
**Dependencies:** None (design pattern)

**Patterns:**

1. **Empty States**
   - Show component with "No data available" message
   - Explain why (e.g., "No ClinVar variants reported for this gene")
   - Provide link to submit data if applicable
   - Don't hide sections — maintain layout consistency

2. **Loading States**
   - Skeleton loaders (not just spinners)
   - Show expected layout structure while loading
   - Prevents layout shift

3. **Collapsible Sections**
   - Associated Entities: Collapsed by default with count badge
   - Model Organism Phenotypes: Expandable if >3 phenotypes
   - Use `[Expand ▼]` / `[Collapse ▲]` buttons

4. **Error States**
   - External API failures: Show error message with retry button
   - Don't break entire page if one API fails
   - Log errors for monitoring

---

## Differentiators

Features that set SysNDD apart from competitors. Not expected but provide competitive advantage for NDD research community.

### DIFF-1: Model Organism Phenotype Summaries with NDD Relevance Highlighting

**What:** Enhanced model organism cards showing phenotype counts with specific highlighting of neuronal/behavioral phenotypes relevant to NDDs.

**Why Differentiator:**
- Most databases show MGI/RGD links but not phenotype summaries
- NDD researchers specifically care about neuronal phenotypes
- Filtering phenotypes by relevance saves time
- SysNDD's NDD focus makes this natural

**Complexity:** Medium
**Dependencies:**
- MGI API (MouseMine) for mouse phenotype data
- RGD API for rat phenotype data
- Backend proxy with caching (7 day TTL)
- NDD-relevant phenotype term mapping (MP ontology)

**Enhanced Display Pattern:**
```
┌─────────────────────────────────────────┐
│ MODEL ORGANISMS                         │
│                                         │
│ 🐭 Mouse (Actl6b, MGI:1927578)          │
│    ● 15 phenotypes (3 neuronal)         │
│    ├─ Homozygous lethal: 8 phenotypes   │
│    ├─ Heterozygous viable: 7 phenotypes │
│    └─ NDD-relevant:                     │
│       • Abnormal brain morphology       │
│       • Impaired learning & memory      │
│       • Decreased anxiety-related resp. │
│    [View all phenotypes in MGI ↗]       │
│                                         │
│ 🐀 Rat (Actl6b, RGD:1560340)            │
│    ● No phenotype data available        │
└─────────────────────────────────────────┘
```

**NDD-Relevant MP Terms (Examples):**
- MP:0002063 — Abnormal learning/memory/conditioning
- MP:0001262 — Decreased body weight
- MP:0000788 — Abnormal cerebral cortex morphology
- MP:0000807 — Abnormal hippocampus morphology
- MP:0002066 — Abnormal motor capabilities/coordination/movement

**Value Proposition:**
- **Time-saving:** Immediate assessment of model organism relevance without navigating to MGI
- **NDD-specific:** Highlighting behavioral/neuronal phenotypes aligns with user needs
- **Functional evidence:** Quick check for loss-of-function phenotypes supporting haploinsufficiency

**Data Sources:**
- **MGI MouseMine API:** `https://www.mousemine.org/mousemine/service/query/results`
- **RGD REST API:** `https://rest.rgd.mcw.edu`
- **MP Ontology:** Use ontology mappings to identify neuronal terms

**Implementation Notes:**
- Server-side phenotype counting and categorization
- Cache 7 days (phenotype data updates slowly)
- Show top 3 NDD-relevant phenotypes, "View all" for rest
- Zygosity breakdown helps assess dosage sensitivity

**References:**
- [MGI Phenotypes](https://www.informatics.jax.org/phenotypes.shtml)
- [Mammalian Phenotype Ontology](https://pmc.ncbi.nlm.nih.gov/articles/PMC2801442/)

---

### DIFF-2: 3D AlphaFold Structure Viewer with Variant Highlighting

**What:** Interactive 3D protein structure viewer (NGL.js) loading AlphaFold models with ability to highlight variants on structure and measure distances to functional regions.

**Why Differentiator:**
- Most gene pages link to AlphaFold DB but don't embed viewer
- Embedding removes navigation friction
- Variant highlighting on 3D structure helps assess spatial clustering
- AlphaFold DB 2025 redesign emphasizes missense variant pathogenicity (AlphaMissense) on structure

**Complexity:** High
**Dependencies:**
- NGL.js library (WebGL-based structure viewer)
- AlphaFold API for structure file URLs
- ClinVar variants with amino acid positions
- Client-side rendering (NGL.js loads PDB/CIF files directly)

**Visualization Components:**

1. **Structure Viewer Canvas**
   - WebGL-based 3D rendering
   - Default: Cartoon representation colored by pLDDT (confidence)
   - Mouse controls: Rotate (drag), zoom (scroll), pan (right-drag)

2. **Representation Controls**
   - Toggle: Cartoon / Surface / Ball+Stick
   - Color scheme: pLDDT (confidence) / Secondary structure / Uniform

3. **Variant Highlighting**
   - Select variant from list (linked to lollipop plot)
   - Highlight residue on structure:
     - Ball+stick representation for side chain
     - Semi-transparent spacefill overlay (1.2× scale)
     - Color by ACMG pathogenicity
     - Optional label with HGVS notation

4. **Distance Measurements** (Advanced)
   - Click two residues to measure distance (Å)
   - Useful for assessing variant impact on binding sites

**Implementation Pattern:**

```typescript
// composables/useNGLStructure.ts
import * as NGL from 'ngl'

// Store NGL objects outside Vue reactivity (markRaw)
function loadStructure(alphafoldUrl: string) {
  const stage = new NGL.Stage(container)
  const structure = await stage.loadFile(alphafoldUrl)

  // Default: Cartoon colored by pLDDT
  structure.addRepresentation('cartoon', {
    colorScheme: 'bfactor',
    colorScale: 'RdYlBu',
    colorReverse: true
  })

  stage.autoView()
}

function highlightVariant(residueNum: number, color: string) {
  structure.addRepresentation('ball+stick', {
    sele: `${residueNum}`,
    color: color
  })
  structure.addRepresentation('spacefill', {
    sele: `${residueNum}`,
    color: color,
    opacity: 0.4,
    scale: 1.2
  })
}
```

**Complexity Factors:**
- NGL.js has Vue reactivity conflicts (must use markRaw)
- WebGL performance varies by device
- Large proteins (>1000 AA) may be slow
- Structure files are ~1-5MB (client downloads from AlphaFold CDN)

**AlphaFold DB 2025 Updates:**
- AlphaMissense pathogenicity scores integrated
- Interactive heatmap for missense variants
- Toggle between pLDDT (confidence) and pathogenicity coloring
- Custom annotation upload for user variants

**Value Proposition:**
- **Unique insight:** Spatial variant clustering not visible in 1D lollipop
- **Clinical utility:** Assess if variant disrupts known functional site
- **AlphaMissense integration:** Predict pathogenicity for novel missense variants

**User Research Insight:**
- From "Ten simple rules for developing visualization tools in genomics": Tooltips and linked views enable deep understanding without hiding overall patterns
- Pinning feature (like Google Sheets "Freeze") recommended for reference tracks

**References:**
- [NGL Viewer GitHub](https://github.com/nglviewer/ngl)
- [AlphaFold Database 2025](https://academic.oup.com/nar/article/54/D1/D358/8340156)
- [AlphaMissense Integration](https://alphafold.ebi.ac.uk/)
- [NGLVieweR R interface](https://nvelden.github.io/NGLVieweR/)

---

### DIFF-3: Integrated Gene-Disease Evidence Summary from SysNDD

**What:** Summary card showing SysNDD's curated gene-disease associations, inheritance patterns, review status, and curation timestamps directly on gene page.

**Why Differentiator:**
- SysNDD is a curation platform — showcase curated evidence
- Other databases link externally; SysNDD shows internal curation
- Provides context: "Why is this gene in SysNDD?"
- Curation metadata (review status, curator, date) builds trust

**Complexity:** Low
**Dependencies:** Existing SysNDD database (gene-entity associations)

**Display Pattern:**
```
┌─────────────────────────────────────────────────┐
│ SysNDD CURATION SUMMARY                         │
│                                                 │
│ Gene-Disease Associations: 3                    │
│                                                 │
│ ┌─────────────────────────────────────────────┐ │
│ │ Intellectual Disability, Autosomal Dominant │ │
│ │ Inheritance: AD  |  Category: Definitive    │ │
│ │ Curated: 2023-05-12  |  Reviewed: 2024-01   │ │
│ │ [View evidence details →]                   │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ ┌─────────────────────────────────────────────┐ │
│ │ Developmental Delay                         │ │
│ │ Inheritance: AD  |  Category: Strong        │ │
│ │ Curated: 2022-11-08  |  Reviewed: 2023-03   │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ [View full curation history →]                  │
└─────────────────────────────────────────────────┘
```

**Metadata to Include:**
- Disease/phenotype name
- Inheritance pattern (AD, AR, XL, etc.)
- Confidence category (Definitive, Strong, Moderate, Limited)
- Curation date
- Last review date
- Curator (if not sensitive)
- Publications supporting association (count + links)

**Value Proposition:**
- **Transparency:** Show curation quality and recency
- **Context:** Clinical users understand gene's NDD relevance immediately
- **Differentiation:** Other databases don't show internal curation metadata prominently

**References:**
- ClinGen gene-disease validity classifications use similar evidence summaries
- Plan document already includes "Associated Entities" table — this enhances it

---

### DIFF-4: Genomic Lollipop Plot (Gene Structure with Exons)

**What:** Second lollipop plot showing genomic coordinates, exon structure, and variants mapped to DNA position (not just protein).

**Why Differentiator:**
- Protein lollipop doesn't show splice variants, UTRs, or regulatory variants
- Reveals intronic variants (splice site, deep intronic)
- Shows exon count and structure at a glance
- Complements protein view for complete picture

**Complexity:** High
**Dependencies:**
- Ensembl REST API (gene structure, canonical transcript, exons)
- ClinVar variants with genomic coordinates (HGVS g. notation)
- D3.js for genomic scale visualization

**Visualization Components:**

1. **Genomic Backbone**
   - Horizontal track representing genomic coordinates
   - Scale: nucleotide positions (e.g., chr7:150,000,000)
   - Strand indicator (+/-)

2. **Exon Blocks**
   - Rectangles for exons (filled)
   - Lines for introns (thin connector)
   - UTRs (if shown): lighter color or shorter height
   - Label exon numbers (1, 2, 3...)

3. **Variant Lollipops**
   - Same as protein plot but at genomic positions
   - Color by consequence type:
     - Nonsense/Frameshift: Dark red
     - Missense: Orange
     - Splice site: Purple
     - Synonymous: Gray
   - Include non-coding variants (UTR, intronic)

4. **Interactions**
   - Zoom to exon (click exon to zoom in)
   - Link to Ensembl genome browser (external)
   - Tooltip with HGVS g. and c. notation

**Use Cases:**
- Identify splice site variant clustering
- Assess if variants cluster in specific exons
- Show deep intronic variants not in protein plot

**Complexity Note:**
- Requires coordinate transformation (genomic to exon-centric display)
- Must handle forward/reverse strand genes
- More complex than protein plot due to scale differences

**Competitive Examples:**
- gnomAD shows genomic lollipop for genes
- UCSC Genome Browser has ClinVar track on gene view

**References:**
- [Ensembl REST API](https://rest.ensembl.org/)
- Ensembl provides canonical transcript exon structure

---

## Anti-Features

Features to explicitly NOT build. Common mistakes in genomic databases.

### ANTI-1: Auto-Playing Animations or Transitions

**What NOT to do:** Animated chart transitions, auto-rotating 3D structures, or auto-scrolling carousels on page load.

**Why Avoid:**
- Distracts from critical clinical information
- Accessibility issue (motion sensitivity)
- Slows page perceived performance
- Users need static, stable reference views

**What to Do Instead:**
- Static initial state
- User-initiated animations (click to rotate structure)
- Instant chart rendering (no staggered reveal)

**Reference:** Medical/clinical interfaces prioritize stability over "delight"

---

### ANTI-2: Hiding Core Information Behind Multiple Clicks

**What NOT to do:**
- Constraint scores in collapsed accordion
- ClinVar summary only visible after clicking gene
- External links in hidden dropdown menus

**Why Avoid:**
- Clinical users need quick scan without exploration
- Every click is friction
- "Progressive disclosure" does not mean "hide important things"

**What to Do Instead:**
- Show table stakes features above the fold
- Use progressive disclosure for secondary details (e.g., full variant list)
- Collapsible sections for large tables (Associated Entities), not metrics

**Reference:**
- gnomAD shows constraint scores immediately
- ClinGen displays gene-disease validity upfront

---

### ANTI-3: Custom Interactive Charts Without Static Fallback

**What NOT to do:** D3 charts that require hover/click to see any data values.

**Why Avoid:**
- Screen readers can't access hover-only data
- Print/PDF export loses information
- Mobile hover interactions are awkward
- Screenshots for publications become useless

**What to Do Instead:**
- Show key values as text labels on chart
- Provide "View data table" toggle below chart
- Export buttons (PNG, SVG, CSV)
- Ensure WCAG 2.1 AA compliance

**Reference:**
- PLOS Computational Biology "Ten simple rules for genomics visualization" emphasizes accessibility

---

### ANTI-4: Client-Side Calling of Rate-Limited External APIs

**What NOT to do:** Frontend directly calling gnomAD, UniProt, Ensembl APIs without backend proxy.

**Why Avoid:**
- **CORS issues:** Many APIs don't allow cross-origin requests
- **Rate limiting:** gnomAD API has rate limits; client IPs get blocked
- **No caching:** Repeated calls for same gene waste resources
- **API key exposure:** Client-side keys visible in browser
- **Error handling:** Can't retry or fallback gracefully

**What to Do Instead:**
- **Backend proxy pattern (REQUIRED):**
  - All external API calls go through R/Plumber backend
  - Backend handles caching (24h for constraint, 7 days for structure)
  - Backend implements rate limiting and retries
  - Frontend only calls internal `/api/external/*` endpoints

**Architecture (from Plan):**
```
Frontend (Vue) → /api/external/gnomad/{symbol}
                 ↓
Backend (R/Plumber) → gnomAD GraphQL API
                      [Cache Layer: memoise + cachem]
```

**Reference:** Plan document explicitly requires backend proxy architecture

---

### ANTI-5: Displaying All Variants in Lollipop Plot by Default (Unfiltered)

**What NOT to do:** Show all ClinVar variants (including benign) without filtering on initial load for genes with >100 variants.

**Why Avoid:**
- Visual clutter overwhelms the plot
- Benign variants (often >50% of ClinVar entries) distract from pathogenic clusters
- Performance degrades with >200 lollipops
- Hard to see pathogenic variant patterns

**What to Do Instead:**
- **Default filter:** Show Pathogenic + Likely Pathogenic + VUS only
- **Toggle controls:** "Show benign" checkbox (opt-in)
- **Performance optimization:** Use canvas rendering for >500 variants
- **Pagination or virtualization** for variant tables

**Pattern from Competitors:**
- gnomAD allows filtering by consequence type
- Simple ClinVar defaults to P/LP/VUS view

**Reference:** Information density must serve user task (finding pathogenic variants)

---

### ANTI-6: Combining Multiple Unrelated Features in One Visualization

**What NOT to do:**
- Single plot showing protein domains + genomic coordinates + splice junctions + RNA expression levels

**Why Avoid:**
- Cognitive overload
- Each visualization has different scale (amino acids vs nucleotides vs TPM)
- Hard to compare across genes
- Maintenance nightmare (too many data sources)

**What to Do Instead:**
- **Separate visualizations per data type:**
  - Protein domain lollipop (amino acid scale)
  - Genomic structure lollipop (nucleotide scale)
  - 3D structure viewer (spatial)
- **Linked interactions:** Select variant in protein plot → highlight in 3D viewer
- **Consistent color coding:** ACMG colors across all views

**Reference:**
- Multi-view design patterns from "Multi-View Design Patterns and Responsive Visualization for Genomics Data"
- Linked views more effective than combined views

---

### ANTI-7: Ignoring Mobile/Tablet Users

**What NOT to do:** Desktop-only layouts with horizontal scrolling, tiny click targets, or hover-only interactions.

**Why Avoid:**
- Clinical geneticists use tablets for rounds
- Mobile usage increasing even for professional tools
- Accessibility: Touch targets must be ≥44px
- Responsive design is baseline expectation in 2026

**What to Do Instead:**
- **Card-based layouts:** Stack vertically on mobile
- **Touch-friendly controls:** Large buttons (≥44px), no hover-only tooltips
- **Responsive charts:** D3 charts should resize or provide simplified mobile version
- **Test on tablet (iPad):** Common clinical device

**Breakpoint Strategy:**
```css
/* Desktop: Side-by-side cards */
@media (min-width: 1024px) {
  .gene-cards { display: grid; grid-template-columns: 1fr 1fr; }
}

/* Tablet: Stacked cards */
@media (max-width: 1023px) {
  .gene-cards { display: block; }
}
```

---

### ANTI-8: Omitting Version Numbers for External Data

**What NOT to do:** Show gnomAD constraint scores without indicating v2.1.1 vs v4.0.

**Why Avoid:**
- **Threshold differences:** LOEUF <0.35 (v2) vs <0.6 (v4)
- **Clinical guidelines:** ClinGen may reference specific gnomAD version
- **Reproducibility:** Users need to know data provenance for publications
- **Trust:** Missing versions looks careless

**What to Do Instead:**
- **Always include version + update date:**
  - "gnomAD Constraint v4.1 (Updated 2024-11)"
  - "ClinVar variants (as of 2026-01-27)"
- **Link to version documentation**
- **Cache invalidation:** Consider TTL based on typical update frequency

**Example Display:**
```
┌─────────────────────────────┐
│ gnomAD Constraint v4.1      │
│ Updated: 2024-11-15         │
│                             │
│ pLI: 0.99                   │
│ LOEUF: 0.12                 │
│                             │
│ Note: v4 metrics are beta   │
│ [About v4.0 →]              │
└─────────────────────────────┘
```

---

## Feature Dependencies

Dependency diagram showing which features must be built before others.

```
PHASE 0: Redesign Existing Content (FOUNDATION)
├─ TS-4: Logical Grouping of Links (INDEPENDENT)
├─ TS-1: Hero Section (INDEPENDENT)
└─ TS-6: Empty State Handling (INDEPENDENT)

PHASE 1: Backend API Layer
├─ Backend proxy endpoints for external APIs
├─ Server-side caching (memoise + cachem)
└─ REQUIRED FOR: All features using external data

PHASE 2: Constraint & Variant Summaries
├─ TS-2: gnomAD Constraint Scores
│   └─ Depends on: Backend gnomAD endpoint
├─ TS-3: ClinVar Variant Summary
│   └─ Depends on: Backend gnomAD endpoint (clinvar_variants field)
└─ DIFF-3: SysNDD Curation Summary (PARALLEL, internal data only)

PHASE 3: Protein Domain Lollipop
├─ TS-5: Protein Domain Lollipop Plot
│   └─ Depends on:
│       - Backend UniProt endpoint (domains)
│       - Backend gnomAD endpoint (ClinVar variants)
│       - D3.js library
└─ DIFF-4: Genomic Lollipop (OPTIONAL, parallel)
    └─ Depends on: Backend Ensembl endpoint

PHASE 4: 3D Structure
├─ DIFF-2: AlphaFold 3D Viewer
│   └─ Depends on:
│       - Backend AlphaFold endpoint
│       - NGL.js library
│       - ClinVar variants (from Phase 2)
└─ Linked interaction: Select variant in lollipop → highlight in 3D

PHASE 5: Model Organism Enhancement
├─ DIFF-1: Model Organism Phenotype Summaries
│   └─ Depends on:
│       - Backend MGI/RGD endpoints
│       - MP ontology term mapping
└─ INDEPENDENT of other phases
```

**Critical Path:**
1. Backend API Layer (Phase 1) must complete before any external data features
2. Protein lollipop (Phase 3) must complete before 3D structure (Phase 4) for linked interactions
3. Phase 0 (redesign) is independent and should complete first for UX foundation

---

## MVP Recommendation

For minimum viable product launch, prioritize features that provide immediate clinical utility:

### Must Have (Core MVP):

1. **TS-1: Hero Section** — Users need gene confirmation
2. **TS-4: Logical Grouping** — Immediate UX improvement over current flat table
3. **TS-2: Constraint Scores** — Clinical geneticists expect this (standard workflow)
4. **TS-3: ClinVar Summary** — Answers "How many pathogenic variants exist?"
5. **TS-6: Empty State Handling** — Professional polish, prevents confusion

**Rationale:** These features provide immediate value without complex visualizations. Users can already interpret numbers (pLI, LOEUF, ClinVar counts) without training.

### Should Have (Enhanced MVP):

6. **TS-5: Protein Domain Lollipop** — High value but complex; defer if timeline tight
7. **DIFF-3: SysNDD Curation Summary** — Unique differentiator, leverages existing data

### Defer to Post-MVP:

- **DIFF-2: 3D AlphaFold Viewer** — High complexity, requires NGL.js expertise, WebGL debugging
- **DIFF-4: Genomic Lollipop** — Nice-to-have, but protein lollipop covers 80% of use cases
- **DIFF-1: Model Organism Phenotypes** — Useful but not critical for clinical decisions

**Phased Rollout Strategy:**
- **Month 1-2:** Phase 0 (redesign existing content) + Backend API layer
- **Month 3:** Constraint scores + ClinVar summary (table stakes MVP)
- **Month 4-5:** Protein lollipop (enhanced MVP)
- **Month 6+:** 3D structure viewer (advanced features)

---

## Complexity & Effort Estimates

| Feature | Complexity | Effort (Dev Days) | Risk Level |
|---------|-----------|-------------------|------------|
| TS-1: Hero Section | Low | 2-3 days | Low |
| TS-2: Constraint Scores | Medium | 5-7 days | Medium (API rate limits) |
| TS-3: ClinVar Summary | Medium | 4-6 days | Medium (data aggregation) |
| TS-4: Logical Grouping | Low | 3-4 days | Low |
| TS-5: Protein Lollipop | High | 10-15 days | High (D3.js, HGVS parsing) |
| TS-6: Empty States | Low | 2-3 days | Low |
| DIFF-1: Model Organism | Medium | 7-10 days | Medium (API complexity) |
| DIFF-2: 3D AlphaFold | High | 12-18 days | High (NGL.js, WebGL issues) |
| DIFF-3: SysNDD Summary | Low | 3-5 days | Low (internal data) |
| DIFF-4: Genomic Lollipop | High | 10-14 days | High (coordinate transforms) |

**Total MVP Estimate (TS-1 to TS-6, DIFF-3):** ~30-40 dev days (~6-8 weeks with testing/polish)

**Total Enhanced (Add lollipop, structure viewer):** ~50-70 dev days (~10-14 weeks)

**Risk Factors:**
- gnomAD API rate limiting (mitigation: server-side caching)
- D3.js learning curve (mitigation: use g3lollipop.js library)
- NGL.js Vue reactivity conflicts (mitigation: markRaw pattern from plan)
- HGVS parsing edge cases (mitigation: use existing libraries like biocommons.hgvs)

---

## Testing & Validation Checklist

Before considering any feature "complete":

### Functional Testing:
- [ ] Feature works with typical genes (e.g., SCN1A, MECP2)
- [ ] Feature handles edge cases (no data, API errors)
- [ ] Feature works on genes with >100 variants
- [ ] Feature works on genes with no variants
- [ ] External links open correct resource

### UX Testing:
- [ ] Feature understandable without documentation
- [ ] Tooltips clear and concise
- [ ] Loading states don't cause layout shift
- [ ] Empty states explain why data is missing

### Performance Testing:
- [ ] Page loads in <3 seconds (with caching)
- [ ] D3 charts render smoothly (60fps)
- [ ] No memory leaks in 3D viewer (dispose properly)

### Accessibility Testing:
- [ ] WCAG 2.1 AA compliance (color contrast, keyboard nav)
- [ ] Screen reader announces chart data
- [ ] Touch targets ≥44px
- [ ] No hover-only critical interactions

### Cross-Browser Testing:
- [ ] Chrome, Firefox, Safari, Edge
- [ ] Desktop (1920x1080) + Tablet (iPad 1024x768)
- [ ] WebGL support for 3D viewer (fallback message if unsupported)

### Data Integrity Testing:
- [ ] Constraint scores match gnomAD website (spot check)
- [ ] ClinVar variant counts match ClinVar website
- [ ] Protein positions align with UniProt
- [ ] Version numbers displayed correctly

---

## Sources

**gnomAD Constraint Scores:**
- [gnomAD v4.0 Gene Constraint](https://gnomad.broadinstitute.org/news/2024-03-gnomad-v4-0-gene-constraint/)
- [Gene constraint help](https://gnomad.broadinstitute.org/help/constraint)
- [Gene constraint and genotype-phenotype correlations in neurodevelopmental disorders](https://pmc.ncbi.nlm.nih.gov/articles/PMC10340126/)

**ClinVar Variant Display:**
- [Simple ClinVar](https://simple-clinvar.broadinstitute.org/)
- [ClinVar Classifications](https://www.ncbi.nlm.nih.gov/clinvar/docs/clinsig/)
- [Simple ClinVar: interactive web server](https://academic.oup.com/nar/article/47/W1/W99/5494761)

**Protein Lollipop Visualization:**
- [g3lollipop.js GitHub](https://github.com/G3viz/g3lollipop.js/)
- [D3 Lollipop Chart Examples](https://d3-graph-gallery.com/lollipop)
- [ProteinPaint GDC Documentation](https://docs.gdc.cancer.gov/Data_Portal/Users_Guide/proteinpaint_lollipop/)

**3D Protein Structure:**
- [NGL Viewer GitHub](https://github.com/nglviewer/ngl)
- [AlphaFold Database 2025](https://academic.oup.com/nar/article/54/D1/D358/8340156)
- [NGLVieweR Documentation](https://nvelden.github.io/NGLVieweR/)

**UniProt Feature Viewer:**
- [Exploring the Feature Viewer](https://www.ebi.ac.uk/training/online/courses/uniprot-exploring-protein-sequence-and-functional-info/exploring-a-uniprotkb-entry/exploring-the-protein-feature-viewer/)
- [ProtVista GitHub](https://github.com/ebi-uniprot/ProtVista)
- [UniProt 2025 Update](https://academic.oup.com/nar/article/53/D1/D609/7902999)

**Model Organism Databases:**
- [MGI Phenotypes](https://www.informatics.jax.org/phenotypes.shtml)
- [Mammalian Phenotype Ontology](https://pmc.ncbi.nlm.nih.gov/articles/PMC2801442/)
- [Mouse Genome Informatics Resource](https://pmc.ncbi.nlm.nih.gov/articles/PMC5886341/)

**DECIPHER & ClinGen:**
- [DECIPHER Supporting interpretation](https://pmc.ncbi.nlm.nih.gov/articles/PMC9303633/)
- [ClinGen Gene Curation Interface](https://clinicalgenome.org/tools/educational-resources/gene-disease-validity-topics/gene-curation-interface/)
- [Clinical Genome Resource](https://pmc.ncbi.nlm.nih.gov/articles/PMC11984750/)

**Genomic Visualization Best Practices:**
- [Ten simple rules for genomics visualization](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1010622)
- [Multi-View Design Patterns for Genomics](https://pmc.ncbi.nlm.nih.gov/articles/PMC10040461/)
- [Data Table Design UX Patterns](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables)

**General UX Patterns:**
- [Hero Section Best Practices 2026](https://www.perfectafternoon.com/2025/hero-section-design/)
- [Visual Hierarchy in Web Design](https://theorangebyte.com/visual-hierarchy-web-design/)
- [UCSC Genome Browser 2026 Update](https://academic.oup.com/nar/advance-article/doi/10.1093/nar/gkaf1250/8326455)

---

**Document Version:** 1.0
**Author:** Claude (GSD Project Researcher)
**Date:** 2026-01-27
**Confidence:** HIGH (verified with competitive examples, official documentation, and recent 2024-2026 updates)
