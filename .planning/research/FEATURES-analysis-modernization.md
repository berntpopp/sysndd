# Feature Research

**Domain:** Biological Network Visualization and Data Exploration
**Researched:** 2026-01-24
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Force-directed network layout | Standard for PPI visualization; users expect force simulation showing protein-protein interactions | MEDIUM | D3.js already in use for cluster bubbles; extend with d3-force for true network graphs with collision detection and link forces |
| Interactive node/edge highlighting | Essential for exploring complex networks; users expect hover to highlight connections | LOW | Event handlers on SVG elements; highlight connected nodes/edges on mouseover |
| Pan and zoom controls | Networks can be large; users need navigation to explore dense regions | LOW | D3.js zoom behavior already standard; enables scale/translate transformations |
| Click-through navigation | Users expect to click node → see details page or filter related data | MEDIUM | Existing SysNDD has entity pages; wire network nodes to `/Entities/{id}` routes |
| Rich contextual tooltips | Bioinformatics users need immediate access to gene/protein metadata without leaving view | LOW | Replace basic hover tooltips with multi-line cards showing gene symbol, function, cluster membership, phenotypes |
| Column-level text filters | Standard data table feature; users expect per-column search boxes | LOW | Already partially implemented in GenericTable; extend to all columns systematically |
| Numeric range filters | Essential for filtering continuous data (p-values, scores, counts) | MEDIUM | Min/max input pairs with validation; apply to enrichment scores, cluster sizes, etc. |
| Dropdown categorical filters | Expected for discrete fields (inheritance modes, categories, yes/no flags) | LOW | BFormSelect already used; populate from distinct column values |
| Global "search any field" | Users expect one search box to filter across all columns | LOW | Already implemented in useTableMethods; applies filter.any.content |
| Sort by column (asc/desc) | Fundamental table interaction; click header to sort | LOW | Already implemented via handleSortUpdate in useTableMethods |
| Pagination controls | Expected for large datasets to manage performance | LOW | Already implemented with page_after cursor-based pagination |
| Excel/CSV export | Researchers need data downloads for external analysis | LOW | Already implemented via requestExcel in useTableMethods |

### Differentiators (Competitive Advantage)

Features that set SysNDD apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Integrated network-to-table navigation | Click cluster in network → auto-filter data table → click gene → see network position | MEDIUM | Bidirectional data flow: network selection filters table, table selection highlights network nodes; competitive advantage over STRING/GeneMANIA which separate views |
| Wildcard gene search (PKD*, BRCA?) | Biologists think in gene families; wildcard patterns (*, ?) let them search "all PKD genes" | MEDIUM | Transform wildcard patterns to SQL LIKE or regex; support both * (multi-char) and ? (single-char) |
| Multi-cluster network overlay | Show phenotype clusters AND functional clusters on same network with color coding | HIGH | Requires graph layout that accommodates multiple node groupings; use color channels for cluster type, size for cluster membership count |
| Network layout persistence | Save user's manually adjusted node positions; restore on return | MEDIUM | Store x/y coordinates in localStorage keyed by gene set hash; allow "reset to auto-layout" |
| Cluster comparison mode | Side-by-side network views to compare two functional categories or phenotype groups | HIGH | Split screen with synchronized zoom/pan; highlight shared nodes between networks |
| Pathway annotation overlay | Overlay KEGG/Reactome pathway boundaries on network to show functional modules | MEDIUM | Fetch pathway memberships from enrichment API; draw hulls or background regions grouping pathway members |
| Interactive edge filtering | Slider to filter edges by confidence score; reduces visual clutter for large networks | MEDIUM | D3.js transition to show/hide edges based on threshold; updates link force simulation |
| Gene set upload for network | Allow users to upload custom gene lists → generate network | MEDIUM | File upload (newline-separated gene symbols) → POST to functional_clustering endpoint with custom gene list |
| Network motif detection highlighting | Automatically detect and highlight feed-forward loops, cliques, hub nodes | HIGH | Graph algorithm analysis (requires igraph or NetworkX on backend); visual emphasis on detected patterns |
| Integrated literature links | Tooltip shows recent PubMed citations for gene or interaction | MEDIUM | Leverage PMID enrichment from functional_clustering endpoint; link directly to PubMed |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| 3D network visualization | "Looks impressive" / "utilizes screen space better" | Documented depth perception issues; occlusion makes exploration harder; navigation complexity increases cognitive load | Stick to 2D force-directed layouts with effective use of color, size, and clustering; if spatial depth needed, use hierarchical/layered layout in 2D |
| Real-time filter updates (no debounce) | "Instant feedback feels responsive" | Causes excessive API calls; degrades performance with large datasets; server load spikes | Use 500ms debounce (already implemented in TableSearchInput); batch filter changes; show loading indicator for clarity |
| Download entire network as image at arbitrary resolution | "Publication-quality figures" | SVG rendering limitations at very high resolutions; memory issues; browser crashes | Provide SVG download (already implemented in DownloadImageButtons) which can be edited in Inkscape/Illustrator for publication; limit raster exports to screen resolution |
| Automatic network layout "prettification" | "Algorithm should make it look good automatically" | No universal "pretty" for biological networks; automated adjustments can hide real structure; users lose trust when layout changes unexpectedly | Provide stable default layout (force-directed with fixed seed); allow manual node dragging with position persistence; offer layout algorithm selector (force/hierarchical/circular) instead of auto-adjustment |
| Infinite scroll on tables | "No pagination breaks; just keep scrolling" | Memory leaks with large biological datasets (1000s of entities); browser performance degrades; difficult to reference specific page/position | Keep cursor-based pagination with clear page controls; show total count and current range; allow page size adjustment (10/25/50/100) |
| Combined filter UI (all filters in modal/sidebar) | "Clean interface; filters hidden until needed" | Breaks "golden rule" of visible filters near data; increases clicks to filter; users forget what filters are active | Keep column-level filters visible in table header row (current approach); use filter badges to show active filters; provide "clear all" for quick reset |
| Machine learning-based query suggestions | "Help users discover interesting patterns" | Biased toward common queries; doesn't understand novel biological hypotheses; "black box" undermines scientific rigor | Provide clear documentation and examples of effective queries; show query syntax help; offer preset filters for common use cases (e.g., "Autosomal Dominant NDD genes") |

## Feature Dependencies

```
[Force-directed network layout]
    └──requires──> [Pan and zoom controls]
    └──requires──> [Interactive node highlighting]

[Click-through navigation]
    └──requires──> [Rich contextual tooltips] (for preview before navigating)

[Integrated network-to-table navigation]
    └──requires──> [Click-through navigation]
    └──requires──> [Column-level text filters]
    └──enhances──> [Multi-cluster network overlay]

[Wildcard gene search]
    └──enhances──> [Global "search any field"]
    └──enhances──> [Gene set upload for network]

[Interactive edge filtering]
    └──requires──> [Force-directed network layout]
    └──conflicts──> [Network layout persistence] (filtering changes layout)

[Multi-cluster network overlay]
    └──requires──> [Force-directed network layout]
    └──requires──> [Rich contextual tooltips] (to show multiple cluster memberships)

[Network motif detection highlighting]
    └──requires──> [Force-directed network layout]
    └──enhances──> [Interactive edge filtering]
```

### Dependency Notes

- **Force-directed network layout requires pan/zoom and highlighting:** Basic interactivity prerequisites for usable network visualization; without these, networks are static and hard to explore.
- **Click-through navigation requires rich tooltips:** Users need to preview what they'll see before committing to navigation; reduces back-button frustration.
- **Integrated network-to-table navigation enhances multi-cluster overlay:** The real power comes from filtering tables by cluster selection, then seeing those genes highlighted across both phenotype and functional networks.
- **Interactive edge filtering conflicts with layout persistence:** Changing visible edges triggers force simulation recalculation; saved positions become invalid. Solution: persist "unfiltered" positions OR re-save on manual adjustment.
- **Wildcard search enhances gene set upload:** Users can upload "PKD*" patterns, not just explicit symbols; dramatically improves flexibility for exploratory analysis.

## MVP Definition

### Launch With (Analysis Modernization v1)

Minimum viable product — what's needed to validate the concept.

- [x] **Force-directed network layout** — Core value proposition; shows true PPI networks not just cluster bubbles
- [x] **Interactive node/edge highlighting** — Essential for network exploration
- [x] **Pan and zoom controls** — Enables navigation of complex networks
- [x] **Click-through navigation** — Connects network to existing entity pages
- [x] **Rich contextual tooltips** — Immediate access to gene metadata without page navigation
- [x] **Column-level text filters** — Expected baseline for data tables
- [x] **Numeric range filters** — Critical for filtering enrichment scores, p-values
- [x] **Dropdown categorical filters** — Standard for discrete fields (inheritance, category)
- [x] **Wildcard gene search** — Differentiator that aligns with biologist mental models

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] **Integrated network-to-table navigation** — Add after network basics proven; requires coordinated state management
- [ ] **Network layout persistence** — Add when users complain about losing manual adjustments
- [ ] **Interactive edge filtering** — Add when users report "too many edges" in dense networks
- [ ] **Gene set upload for network** — Add when users request custom analysis beyond curated gene lists
- [ ] **Pathway annotation overlay** — Add when users want to see functional modules in network context

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] **Multi-cluster network overlay** — Complex feature; defer until single-cluster networks validated
- [ ] **Cluster comparison mode** — High complexity; needed for specific research questions only
- [ ] **Network motif detection highlighting** — Research feature; requires backend graph algorithms; low priority
- [ ] **Integrated literature links** — Nice-to-have; data already available in PMID enrichment

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Force-directed network layout | HIGH | MEDIUM | P1 |
| Interactive node/edge highlighting | HIGH | LOW | P1 |
| Pan and zoom controls | HIGH | LOW | P1 |
| Click-through navigation | HIGH | MEDIUM | P1 |
| Rich contextual tooltips | HIGH | LOW | P1 |
| Column-level text filters | HIGH | LOW | P1 |
| Numeric range filters | HIGH | MEDIUM | P1 |
| Dropdown categorical filters | HIGH | LOW | P1 |
| Wildcard gene search | MEDIUM | MEDIUM | P1 |
| Integrated network-to-table navigation | HIGH | MEDIUM | P2 |
| Network layout persistence | MEDIUM | MEDIUM | P2 |
| Interactive edge filtering | MEDIUM | MEDIUM | P2 |
| Gene set upload for network | MEDIUM | MEDIUM | P2 |
| Pathway annotation overlay | MEDIUM | MEDIUM | P2 |
| Multi-cluster network overlay | LOW | HIGH | P3 |
| Cluster comparison mode | LOW | HIGH | P3 |
| Network motif detection | LOW | HIGH | P3 |
| Integrated literature links | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch (MVP)
- P2: Should have, add when possible (post-launch iteration)
- P3: Nice to have, future consideration (v2+)

## Competitor Feature Analysis

| Feature | STRING Database | GeneMANIA | Cytoscape.js | Our Approach (SysNDD) |
|---------|-----------------|-----------|--------------|----------------------|
| **Network Visualization** | Interactive network with t-SNE layout; regulatory/functional/physical mode switching | Prefuse force-directed; automatically laid out; Cytoscape.js integration | Rich interactive graphs; full layout algorithm suite | D3.js force-directed (familiar to existing users from cluster bubbles); extend with multi-layout support |
| **Edge Interactions** | Click edge → pop-up with evidence viewer; text-mining sources; confidence scores | Click network type → highlight associated edges | User events (tap, drag, zoom) fully customizable | Click edge → show interaction confidence, source database, evidence; similar to STRING |
| **Node Click Navigation** | Node → protein detail page with annotations, pathways, diseases | Node → gene details; function list; expression heatmap | Event hooks for click/tap; developer controls navigation | Node → SysNDD entity page (existing infrastructure); integrated with curation data |
| **Data Table Integration** | Separate protein list view; no integrated filtering | Separate function list/network list panes; viewable simultaneously | Not applicable (library, not platform) | **DIFFERENTIATOR:** Bidirectional network-table integration; click cluster → filter table; click row → highlight in network |
| **Search Capabilities** | Protein name/ID search; no wildcards visible | Gene list input (multi-gene) | Programmatic filtering only | **DIFFERENTIATOR:** Wildcard patterns (PKD*, BRCA?) in gene search; aligns with biologist mental model |
| **Pathway/Cluster Overlay** | Pathway enrichment in separate panel; visual clustering of networks with redundancy filtering | Network types as overlays (co-expression, co-localization, physical interaction) | Developer implements custom coloring | Leverage existing MCA phenotype clusters + STRINGdb functional clusters; overlay both on network |
| **Export Options** | Download network (TSV, images); network embeddings for ML | Export to Cytoscape; images | Programmatic export (JSON, PNG) | SVG/PNG download (existing); add network JSON export for reproducibility |
| **Filtering** | Filter by evidence type, confidence threshold | Filter by network type, function | Programmatic filtering | **DIFFERENTIATOR:** Column-level + global search + numeric ranges + dropdowns; comprehensive filter UI |
| **Tooltips** | Edge tooltips with evidence; node tooltips basic | Minimal tooltips; relies on detail panes | Developer controls all tooltip content | **DIFFERENTIATOR:** Rich multi-line tooltips with gene symbol, HGNC ID, cluster membership, phenotypes, inheritance mode |
| **Layout Customization** | t-SNE-based; zoom/pan interactive; no manual adjustment visible | Force-directed default; optimized for GeneMANIA | Full layout algorithm library | Force-directed default with manual node dragging; persist positions in localStorage |

### Key Differentiators Identified

1. **Bidirectional network-table integration** — Neither STRING nor GeneMANIA tightly couples network selection to data table filtering in both directions
2. **Wildcard gene search** — Not prominently featured in competitor interfaces; SysNDD can lead here
3. **Comprehensive filter UI** — STRING/GeneMANIA focus on network; SysNDD combines network + robust data exploration
4. **Rich contextual tooltips** — Leverage SysNDD's curation data (phenotypes, inheritance, NDD status) in tooltips; competitors show basic annotations

### Where Competitors Excel (Adopt Best Practices)

1. **STRING's evidence viewer** — Pop-up showing text-mining sources, confidence scores; adopt for interaction evidence
2. **GeneMANIA's simultaneous pane view** — Gene list, network list, function list visible at once; adapt to network + table layout
3. **Cytoscape.js's event system** — Mature tap/drag/zoom handling; leverage as D3.js alternative if performance issues arise

## Existing SysNDD Features (Build Upon)

Based on codebase analysis:

| Component | Current Capability | Extension for Network Viz |
|-----------|-------------------|--------------------------|
| `AnalyseGeneClusters.vue` | D3.js bubble clusters; cluster/subcluster selection; term enrichment table | Replace bubble layout with force-directed PPI network; keep cluster selection logic |
| `useTableMethods.ts` | Text filter, sort, pagination, Excel export, global "any" search | Add numeric range inputs, dropdown filters; wire to network selection state |
| `GenericTable.vue` | BTable with column filters, sort handlers, slot-based customization | Add numeric/dropdown filter slots; highlight rows when network node selected |
| `analysis_endpoints.R` | `/functional_clustering` returns STRINGdb clusters with identifiers and term_enrichment | Extend to return PPI edges (protein1, protein2, score) for network rendering |
| Correlation heatmap | Already correlates phenotype clusters + functional clusters | Use correlation data to suggest interesting network overlays |

## Sources

### Biological Network Visualization Best Practices
- [An introduction to and survey of biological network visualization - ScienceDirect](https://www.sciencedirect.com/science/article/pii/S0097849324002504)
- [Ten simple rules to create biological network figures for communication - PLOS Computational Biology](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007244)
- [A survey of visualization tools for biological network analysis - BioData Mining](https://biodatamining.biomedcentral.com/articles/10.1186/1756-0381-1-12)

### Protein-Protein Interaction Network Tools
- [STRING database in 2025: protein networks with directionality of regulation - Nucleic Acids Research](https://academic.oup.com/nar/article/53/D1/D730/7903368)
- [Cytoscape StringApp 2.0: Analysis and Visualization of Heterogeneous Biological Networks - Journal of Proteome Research](https://pubs.acs.org/doi/10.1021/acs.jproteome.2c00651)
- [Visualization of protein interaction networks: problems and solutions - BMC Bioinformatics](https://bmcbioinformatics.biomedcentral.com/articles/10.1186/1471-2105-14-S1-S1)

### Modern Data Table Filtering Patterns
- [Filter UX Design Patterns & Best Practices - Pencil & Paper](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-filtering)
- [Data Table Design UX Patterns & Best Practices - Pencil & Paper](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables)
- [19+ Filter UI Examples for SaaS: Design Patterns & Best Practices - Eleken](https://www.eleken.co/blog-posts/filter-ux-and-ui-for-saas)
- [Complex Filters UX — Smart Interface Design Patterns](https://smart-interface-design-patterns.com/articles/complex-filtering/)

### Interactive Network Visualization Libraries
- [D3.js Force Layout - GitHub](https://github.com/d3/d3-force)
- [D3 Force Layout - D3 in Depth](https://www.d3indepth.com/force-layout/)
- [Cytoscape.js - Official Documentation](https://js.cytoscape.org/)
- [Network Visualization with Cytoscape - Tutorial](https://cytoscape.org/cytoscape-tutorials/presentations/network-visualization.html)

### GeneMANIA Features
- [GeneMANIA update 2018 - Nucleic Acids Research](https://academic.oup.com/nar/article/46/W1/W60/5038280)
- [GeneMANIA Cytoscape App](https://apps.cytoscape.org/apps/genemania)

### Bioinformatics UX and Tooltips
- [Bioinformatics Meets User-Centred Design: A Perspective - PLOS Computational Biology](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1002554)
- [Harnessing UX Design in Bioinformatics - Ncanto](https://ncanto.in/harnessing_ux_design_in_bioinformatic/)

### Database Filtering Pitfalls
- [Ten common issues with reference sequence databases and how to mitigate them - Frontiers in Bioinformatics](https://www.frontiersin.org/journals/bioinformatics/articles/10.3389/fbinf.2024.1278228/full)
- [Data errors in Bioinformatics databases - Omics Tutorials](https://omicstutorials.com/data-errors-in-bioinformatics-databases/)

### Gene Search and Wildcard Patterns
- [A novel optimal multi-pattern matching method with wildcards for DNA sequence - PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC8150449/)
- [Gene Ontology Resource - Official Site](https://geneontology.org/)

---
*Feature research for: SysNDD Analysis Modernization*
*Researched: 2026-01-24*
