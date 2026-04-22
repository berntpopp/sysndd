# Phase 44: Gene Structure Visualization - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Render gene structure (exons, introns, UTRs, strand orientation) from Ensembl canonical transcript data as a visual diagram on the gene page. This is a secondary visualization — the protein domain lollipop plot (Phase 43) is the primary visual. The gene structure serves as a supporting compact view.

</domain>

<decisions>
## Implementation Decisions

### Visual style & proportions
- Exons and introns drawn to genomic scale (proportional to actual base pair lengths)
- Protein representation (Phase 43) is the primary visualization; gene structure is secondary/supporting
- UTRs distinguished by height difference: coding exons are tall rectangles, UTRs are shorter/thinner rectangles (UCSC Genome Browser style)
- Color scheme: blue tones — coding exons in solid blue, UTRs in lighter blue, intron lines in gray
- Slim strip layout (~40-60px height) — compact horizontal strip, minimal vertical space

### Transcript selection & labeling
- Canonical transcript only — single track, clean and simple
- Exon labels on hover only — tooltip shows exon number, size in bp, and coordinates
- Ensembl transcript ID (e.g., ENST00000...) displayed as small text label above or below the strip
- Summary subtitle shown: exon count and gene length (e.g., "42 exons • 156,234 bp")

### Coordinate display & scale
- Abbreviated coordinate format on axis (e.g., 12.35 Mb)
- Scale bar below the structure showing genomic distance (e.g., "10 kb")
- Large genes rendered at genomic scale even if very wide — user can scroll/pan horizontally (no intron compression)
- Chromosome name included on axis (e.g., "chr1" at start, then position ticks)

### Strand & orientation cues
- Strand direction indicated by small arrowheads along intron connector lines, pointing in transcription direction (UCSC/Ensembl style)
- Minus-strand genes drawn right-to-left matching genomic coordinate orientation (not normalized to 5'→3' left-to-right)
- Coordinate axis always increases left-to-right regardless of strand (genomic convention)
- Explicit strand label as small text near the strip (e.g., "+ strand" or "– strand")

### Claude's Discretion
- Exact blue color hex values and intron line styling
- Tooltip design and positioning
- How to handle the scroll/pan interaction for large genes (scrollbar vs drag)
- SVG vs Canvas rendering choice
- Exact font sizes for labels and subtitle
- Responsive behavior at different viewport widths
- Loading and error states

</decisions>

<specifics>
## Specific Ideas

- UCSC Genome Browser style for exon/UTR height distinction (tall coding exons, shorter UTRs)
- UCSC/Ensembl style arrowheads on intron lines for strand direction
- Gene structure should feel like a secondary supporting visualization — compact, not dominant on the page

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 44-gene-structure-visualization*
*Context gathered: 2026-01-27*
