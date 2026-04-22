# Phase 43: Protein Domain Lollipop Plot - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Interactive D3.js visualization showing protein domains as colored regions and ClinVar variants as positioned lollipop markers along a protein backbone. Users can filter by pathogenicity, zoom into regions, and hover for variant details. Bidirectional linking with the 3D structure viewer (Phase 45). Creating new visualizations or adding non-ClinVar variant sources are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Visual layout & density
- Fixed-height lollipop stems — all stems same height, variant position is the only spatial encoding
- Stacked markers for multiple variants at the same amino acid position — each variant individually visible as separate circles stacked vertically
- Protein domain rectangles styled with distinct colors per domain type using a categorical palette
- Full-width card (~300px tall) spanning entire content width — prominent, gives variants room to breathe

### Interaction patterns
- Hover tooltip for revealing variant details — fast exploration, standard data viz pattern
- Clickable legend items to toggle pathogenicity filter visibility (P, LP, VUS, LB, B)
- Brush selection to zoom into a region, double-click to reset — standard genomics pattern
- Bidirectional linking with 3D structure viewer (Phase 45) — clicking a variant in the lollipop highlights it in the 3D viewer and vice versa

### Information hierarchy
- Tooltip content: protein HGVS (p.) + coding DNA HGVS (c.) + pathogenicity classification
- Splice-site/intronic variants (e.g., c.123+2A>G) mapped to nearest amino acid position using coding position / 3 rule
- Splice/intronic variants use different marker shapes (triangles or diamonds) to distinguish from coding variant circles
- Splice variant tooltips show explicit mapping: "c.123+2A>G → mapped to AA 41 — Pathogenic"
- Domain legend placed below the plot — clean separation from the visualization
- No summary statistics in the card — ClinVar summary card (Phase 42) already covers variant counts
- Regular tick marks with amino acid position numbers on X-axis (e.g., every 100 AA)

### Empty & edge states
- No ClinVar variants: show domain rectangles with "No ClinVar variants mapped" message above
- No UniProt domains: show plain protein backbone with variant lollipops — still useful for positioning
- Dense variants (>200): show all variants, rely on brush-to-zoom for exploring dense regions
- Full data failure (both UniProt and gnomAD/ClinVar): error card with retry button — user knows something should be there

### Claude's Discretion
- Exact categorical color palette for domain types
- Marker sizes and spacing for stacked variants
- Brush selection visual styling
- D3.js rendering performance optimizations
- Exact tooltip positioning and styling
- Animation/transitions during zoom and filter operations

</decisions>

<specifics>
## Specific Ideas

- Splice-site variant mapping rule: coding position (e.g., 123 from c.123+2A>G) divided by 3 to get approximate amino acid position (AA 41), placed at that position on the backbone
- Genomics-standard brush-to-zoom with double-click reset (familiar to bioinformatics users)
- Bidirectional variant selection between lollipop plot and 3D viewer creates a connected analysis experience

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 43-protein-domain-lollipop-plot*
*Context gathered: 2026-01-27*
