# Phase 44: Gene Structure Visualization - Research

**Researched:** 2026-01-27
**Domain:** D3.js genomic track visualization in Vue 3 for exon/intron/UTR gene structure
**Confidence:** HIGH

## Summary

Phase 44 implements a compact horizontal gene structure visualization showing exons, introns, and UTRs from Ensembl canonical transcript data. The visualization follows established genomic browser conventions (UCSC, Ensembl, IGV) using D3.js v7 with SVG rendering. The standard approach renders exons as rectangles (tall for coding, short for UTRs) and introns as lines with directional arrowheads, all drawn to genomic scale with horizontal scrolling for large genes.

The implementation leverages the existing Vue 3 + D3.js patterns from Phase 43 (protein domain lollipop plot): useD3 composable pattern for lifecycle management, non-reactive D3 instance storage to prevent layout thrashing, and onBeforeUnmount cleanup to prevent memory leaks. Critical additions include: (1) horizontal scrolling container for wide genomic regions, (2) abbreviated coordinate formatting (Mb/kb) using custom D3.format functions, (3) UTR height distinction following UCSC convention, and (4) strand direction arrowheads on intron connector lines.

**Key challenges identified:**
1. Large genes (200+ kb) require horizontal scroll/pan — SVG groups don't natively support overflow scrolling
2. Abbreviated coordinate formatting (12.35 Mb) requires custom D3 formatter — d3-format doesn't include genomic units
3. Strand direction arrowheads on intron lines need SVG marker definitions with proper orientation
4. UTR vs coding exon distinction requires exon type classification from Ensembl API response
5. Responsive behavior on mobile/narrow screens — genomics tools typically fail at responsive design

**Primary recommendation:** Create a GeneStructureCard.vue component with horizontal scrolling wrapper (CSS overflow-x: auto) containing a wide SVG (viewBox width = genomic length scaled). Use D3.js scaleLinear for genomic coordinates with custom tickFormat for abbreviated labels (Mb/kb). Render exons as rect elements with height based on type (coding: 20px, UTR: 10px), introns as line elements with SVG marker-end for arrowheads, and implement tooltip with exon details on hover. Follow the existing useD3 composable pattern from Phase 43 for lifecycle management.

## Standard Stack

The established libraries/tools for genomic track visualization in Vue 3:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| d3 | 7.4.2 (in package.json) | SVG rendering, scales, axes, coordinate formatting | Industry standard for genomic visualization, used in UCSC, Ensembl web tools |
| Vue 3 | 3.5.25 (in package.json) | Composition API with onMounted, watchEffect, onBeforeUnmount | Project standard, established pattern from Phase 43 |
| Bootstrap Vue Next | 0.42.0 (in package.json) | BCard component for card container | Project UI standard, consistent with other gene page cards |

### D3 Modules (included in d3 7.4.2)
| Module | Purpose | When to Use |
|--------|---------|-------------|
| d3-scale | scaleLinear for genomic coordinates to pixel positions | All coordinate mapping from bp to SVG x-position |
| d3-axis | axisBottom for chromosome coordinate labels | X-axis with abbreviated tick marks (Mb/kb) |
| d3-format | Custom formatter for genomic units (Mb, kb, bp) | Coordinate axis tick formatting |
| d3-selection | select, selectAll, join for DOM manipulation | All D3 rendering (exons, introns, labels) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| D3.js | GSDS 2.0, GenePainter (web services) | D3 provides full control over layout and interaction; web services are rigid, server-dependent |
| SVG rendering | Canvas | SVG provides hover interactivity for exon tooltips; Canvas would lose click/hover events |
| Horizontal scroll | Intron compression | Genomic scale preserves accurate size relationships; compression distorts biology |
| Custom coordinate format | d3.format with SI prefix | SI prefixes use "M" for million (not Mb for megabase); genomics requires domain-specific units |

**Installation:**
Already installed - d3 7.4.2 in package.json dependencies. No additional libraries needed.

## Architecture Patterns

### Recommended Project Structure
```
app/src/
├── components/
│   └── gene/
│       ├── GeneStructureCard.vue           # Card wrapper with title and loading state
│       └── GeneStructurePlot.vue           # D3 visualization component
├── composables/
│   └── useD3GeneStructure.ts               # D3 lifecycle management composable
└── types/
    └── ensembl.ts                           # TypeScript interfaces for Ensembl transcript data
```

### Pattern 1: Horizontal Scrolling Container for Wide SVG
**What:** CSS overflow container wrapping SVG with width proportional to genomic length
**When to use:** Genes >50kb where SVG would exceed viewport width at readable scale
**Example:**
```vue
<!-- Source: Phase 44 CONTEXT.md requirements, UCSC Genome Browser pattern -->
<!-- Source: https://d3gb.usal.es/ (D3 Genome Browser horizontal scroll) -->

<template>
  <div class="gene-structure-scroll-container">
    <div ref="plotContainer" class="gene-structure-plot"></div>
  </div>
</template>

<style scoped>
.gene-structure-scroll-container {
  width: 100%;
  height: 80px; /* Fixed height for strip layout */
  overflow-x: auto;
  overflow-y: hidden;
  border: 1px solid #dee2e6;
  border-radius: 4px;
  background: #f8f9fa;
}

.gene-structure-plot {
  min-width: 100%; /* At least full width */
  height: 100%;
}

/* Styling for scrollbar */
.gene-structure-scroll-container::-webkit-scrollbar {
  height: 8px;
}

.gene-structure-scroll-container::-webkit-scrollbar-track {
  background: #f1f1f1;
}

.gene-structure-scroll-container::-webkit-scrollbar-thumb {
  background: #888;
  border-radius: 4px;
}

.gene-structure-scroll-container::-webkit-scrollbar-thumb:hover {
  background: #555;
}
</style>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import * as d3 from 'd3';

const plotContainer = ref<HTMLElement | null>(null);

function renderGeneStructure(geneLength: number) {
  if (!plotContainer.value) return;

  // Calculate SVG width based on genomic length
  // Use 0.05 pixels per base pair (1kb = 50px, 100kb = 5000px)
  const pixelsPerBp = 0.05;
  const svgWidth = geneLength * pixelsPerBp;
  const minWidth = 800; // Minimum for small genes
  const width = Math.max(svgWidth, minWidth);

  // Create SVG with calculated width (not viewBox)
  const svg = d3.select(plotContainer.value)
    .append('svg')
    .attr('width', width)
    .attr('height', 60)
    .attr('class', 'gene-structure-svg');

  // Parent container will scroll if width exceeds viewport
}
</script>
```

### Pattern 2: Abbreviated Genomic Coordinate Formatting
**What:** Custom D3 formatter that displays coordinates as Mb, kb, or bp based on magnitude
**When to use:** Chromosome coordinate axis labels
**Example:**
```typescript
// Source: Phase 44 CONTEXT.md requirements (abbreviated format)
// Source: https://d3js.org/d3-format (custom formatter pattern)
// Source: https://phanstiellab.github.io/plotgardener/reference/annoGenomeLabel.html (Mb/kb/bp scales)

// Custom formatter for genomic coordinates
function formatGenomicCoordinate(value: number): string {
  const absValue = Math.abs(value);

  if (absValue >= 1_000_000) {
    // Format as Mb (e.g., 12.35 Mb)
    return `${(value / 1_000_000).toFixed(2)} Mb`;
  } else if (absValue >= 1_000) {
    // Format as kb (e.g., 123.5 kb)
    return `${(value / 1_000).toFixed(1)} kb`;
  } else {
    // Format as bp (e.g., 456 bp)
    return `${value.toFixed(0)} bp`;
  }
}

// Use in D3 axis
const xScale = d3.scaleLinear()
  .domain([startPosition, endPosition])
  .range([0, width]);

const xAxis = d3.axisBottom(xScale)
  .ticks(5)
  .tickFormat(d => formatGenomicCoordinate(d as number));

svg.append('g')
  .attr('class', 'x-axis')
  .attr('transform', `translate(0, ${height - 10})`)
  .call(xAxis);
```

### Pattern 3: Exon/Intron/UTR Rendering with Height Distinction
**What:** Rectangles for exons (tall = coding, short = UTR), lines for introns
**When to use:** Gene structure track rendering
**Example:**
```typescript
// Source: UCSC Genome Browser convention (tall coding, short UTR)
// Source: https://www.ncbi.nlm.nih.gov/tools/sviewer/legends/ (NCBI convention)
// Source: Phase 44 CONTEXT.md (blue tones, height distinction)

interface Exon {
  start: number;
  end: number;
  type: 'coding' | '5_utr' | '3_utr';
}

interface Intron {
  start: number;
  end: number;
}

function renderExons(
  svg: d3.Selection<SVGSVGElement, unknown, null, undefined>,
  exons: Exon[],
  xScale: d3.ScaleLinear<number, number>,
  yBase: number
) {
  const CODING_HEIGHT = 20;
  const UTR_HEIGHT = 10;
  const CODING_COLOR = '#2563eb'; // Blue-600
  const UTR_COLOR = '#93c5fd';    // Blue-300

  svg.selectAll('.exon')
    .data(exons)
    .join('rect')
    .attr('class', 'exon')
    .attr('x', d => xScale(d.start))
    .attr('y', d => {
      const height = d.type === 'coding' ? CODING_HEIGHT : UTR_HEIGHT;
      return yBase - height / 2; // Center vertically
    })
    .attr('width', d => xScale(d.end) - xScale(d.start))
    .attr('height', d => d.type === 'coding' ? CODING_HEIGHT : UTR_HEIGHT)
    .attr('fill', d => d.type === 'coding' ? CODING_COLOR : UTR_COLOR)
    .attr('stroke', '#1e40af') // Blue-800
    .attr('stroke-width', 1)
    .style('cursor', 'pointer')
    .on('mouseover', showExonTooltip)
    .on('mouseout', hideTooltip);
}

function renderIntrons(
  svg: d3.Selection<SVGSVGElement, unknown, null, undefined>,
  introns: Intron[],
  xScale: d3.ScaleLinear<number, number>,
  yBase: number
) {
  svg.selectAll('.intron')
    .data(introns)
    .join('line')
    .attr('class', 'intron')
    .attr('x1', d => xScale(d.start))
    .attr('x2', d => xScale(d.end))
    .attr('y1', yBase)
    .attr('y2', yBase)
    .attr('stroke', '#9ca3af') // Gray-400
    .attr('stroke-width', 1)
    .attr('marker-end', 'url(#arrowhead)'); // Strand direction marker
}
```

### Pattern 4: SVG Marker for Strand Direction Arrowheads
**What:** SVG defs element with marker for intron line arrows
**When to use:** Indicating transcription direction on intron connectors
**Example:**
```typescript
// Source: UCSC Genome Browser pattern (arrowheads on introns)
// Source: https://genome.ucsc.edu/goldenPath/help/hgTracksHelp.html (strand indicators)
// Source: https://developer.mozilla.org/en-US/docs/Web/SVG/Element/marker

function createStrandArrowMarker(
  svg: d3.Selection<SVGSVGElement, unknown, null, undefined>,
  strand: '+' | '-'
) {
  // Create defs element for marker definitions
  const defs = svg.append('defs');

  // Arrowhead marker for plus strand (points right)
  defs.append('marker')
    .attr('id', 'arrowhead')
    .attr('markerWidth', 6)
    .attr('markerHeight', 6)
    .attr('refX', strand === '+' ? 6 : 0) // Point position
    .attr('refY', 3)
    .attr('orient', 'auto')
    .append('path')
    .attr('d', strand === '+' ? 'M 0 0 L 6 3 L 0 6 Z' : 'M 6 0 L 0 3 L 6 6 Z')
    .attr('fill', '#9ca3af'); // Gray-400 to match intron lines
}

// Usage: Call before rendering introns
createStrandArrowMarker(svg, transcriptStrand);

// Then intron lines use marker-end="url(#arrowhead)"
// For minus strand, also consider rendering right-to-left
```

### Pattern 5: Scale Bar Below Structure
**What:** Visual reference showing genomic distance (e.g., "10 kb")
**When to use:** All gene structure visualizations to provide scale context
**Example:**
```typescript
// Source: UCSC Genome Browser scale bar pattern
// Source: Phase 44 CONTEXT.md (scale bar below structure)

function renderScaleBar(
  svg: d3.Selection<SVGSVGElement, unknown, null, undefined>,
  geneLength: number,
  xScale: d3.ScaleLinear<number, number>,
  yPosition: number
) {
  // Calculate appropriate scale bar length (10% of gene length or round number)
  let scaleBarLength: number;
  if (geneLength > 100_000) {
    scaleBarLength = 10_000; // 10 kb
  } else if (geneLength > 10_000) {
    scaleBarLength = 1_000; // 1 kb
  } else {
    scaleBarLength = 100; // 100 bp
  }

  const scaleBarPixels = xScale(scaleBarLength) - xScale(0);
  const scaleBarX = 20; // 20px from left edge

  // Scale bar line
  svg.append('line')
    .attr('class', 'scale-bar')
    .attr('x1', scaleBarX)
    .attr('x2', scaleBarX + scaleBarPixels)
    .attr('y1', yPosition)
    .attr('y2', yPosition)
    .attr('stroke', '#374151') // Gray-700
    .attr('stroke-width', 2);

  // End caps
  svg.append('line')
    .attr('x1', scaleBarX)
    .attr('x2', scaleBarX)
    .attr('y1', yPosition - 3)
    .attr('y2', yPosition + 3)
    .attr('stroke', '#374151')
    .attr('stroke-width', 2);

  svg.append('line')
    .attr('x1', scaleBarX + scaleBarPixels)
    .attr('x2', scaleBarX + scaleBarPixels)
    .attr('y1', yPosition - 3)
    .attr('y2', yPosition + 3)
    .attr('stroke', '#374151')
    .attr('stroke-width', 2);

  // Label
  svg.append('text')
    .attr('x', scaleBarX + scaleBarPixels / 2)
    .attr('y', yPosition + 15)
    .attr('text-anchor', 'middle')
    .attr('font-size', '10px')
    .attr('fill', '#374151')
    .text(formatGenomicCoordinate(scaleBarLength));
}
```

### Anti-Patterns to Avoid
- **Using viewBox for wide SVG:** viewBox scales entire SVG to fit container, making large genes unreadable. Use absolute width with scroll instead.
- **Compressing introns:** Distorts genomic scale and confuses users about actual gene structure. Maintain proportional rendering.
- **Drawing minus-strand genes left-to-right:** Violates genomic convention. Coordinates always increase left-to-right regardless of transcription direction.
- **Skipping strand indicator:** Transcription direction is critical biological context. Always show strand with arrows or label.
- **Fixed SVG dimensions in responsive container:** Causes layout conflicts. Let container control overflow, SVG control content width.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Coordinate abbreviation | String manipulation for Mb/kb | Custom D3 tickFormat function | D3 integrates with axis, handles edge cases (negative, zero, very small) |
| Strand arrowheads | Unicode arrows or rotated text | SVG marker definitions | Markers scale with stroke-width, auto-orient, reusable across all introns |
| Horizontal scroll | Custom drag-to-pan with D3 | CSS overflow-x: auto | Native browser scroll is accessible, touch-friendly, familiar UX |
| Tooltip positioning | Fixed offset from mouse | Existing Phase 43 edge-aware tooltip | Edge detection already implemented, tested, prevents viewport overflow |
| Exon-intron calculation | Manual gap finding in coordinates | Ensembl API provides exon boundaries | API returns structured exon array, handles complex splicing, UTR annotation |

**Key insight:** Genomic browsers (UCSC, Ensembl, IGV) have solved these problems over decades of use. The patterns are well-established and expected by genomics users. Custom solutions break user expectations and introduce bugs (e.g., incorrect intron gap calculation for complex splicing).

## Common Pitfalls

### Pitfall 1: SVG Overflow Not Scrollable in Parent Container
**What goes wrong:** Large gene SVG extends beyond viewport but no scrollbar appears, content is cut off
**Why it happens:** SVG groups don't support overflow scrolling; need wrapper div with CSS overflow
**How to avoid:** Wrap SVG in a div with `overflow-x: auto`, set SVG width as absolute pixels (not 100%), allow container to scroll
**Warning signs:**
- Large gene structures are truncated at viewport edge
- No scrollbar appears despite wide content
- Entire visualization scales down to fit container (viewBox behavior)

### Pitfall 2: Incorrect UTR vs Coding Exon Classification
**What goes wrong:** All exons rendered at same height, no UTR distinction
**Why it happens:** Ensembl API returns exon coordinates but type classification requires checking against CDS start/end
**How to avoid:** Compare exon coordinates to transcript CDS start/end positions; exons before CDS start are 5' UTR, after CDS end are 3' UTR, overlapping are coding (or split)
**Warning signs:**
- User feedback: "Can't see where translation starts"
- All exons same color and height
- No visual distinction between coding and non-coding regions

### Pitfall 3: Coordinate Axis Doesn't Match Strand Orientation
**What goes wrong:** Minus-strand genes show coordinates decreasing left-to-right, confusing users
**Why it happens:** Intuition to flip coordinates for minus strand, but genomic convention is always left-to-right increasing
**How to avoid:** Always render coordinate axis increasing left-to-right regardless of strand; use arrowheads and strand label to indicate transcription direction
**Warning signs:**
- Coordinates decrease left-to-right on minus strand
- User confusion about chromosomal position
- Incompatible with genome browser conventions

### Pitfall 4: Hard-Coded Scale Factor Breaks for Large/Small Genes
**What goes wrong:** 1kb gene is microscopic or 1Mb gene requires minutes of scrolling
**Why it happens:** Fixed pixels-per-bp scale doesn't adapt to gene size range (100bp to 2Mb)
**How to avoid:** Implement adaptive scaling: calculate pixels-per-bp based on gene length with min/max bounds, or use zoom levels
**Warning signs:**
- Small genes (<10kb) appear as tiny strip
- Very large genes (>500kb) create multi-screen-width SVG
- User complaints about usability at extremes

### Pitfall 5: Missing Data Handling for Non-Canonical Transcripts
**What goes wrong:** API returns transcript without canonical flag, visualization fails or shows wrong transcript
**Why it happens:** Not all genes have canonical transcript annotated, or API endpoint filters incorrectly
**How to avoid:** Request canonical transcript explicitly in API call, fallback to longest transcript if canonical unavailable, show transcript ID in UI for verification
**Warning signs:**
- Different transcript shown than expected
- Missing gene structures for known genes
- Error state without fallback

### Pitfall 6: Mobile/Narrow Viewport Breaks Layout
**What goes wrong:** Gene structure card unusable on mobile, horizontal scroll conflicts with page scroll
**Why it happens:** Fixed height + horizontal scroll is challenging on touch devices
**How to avoid:** Implement responsive height reduction on narrow screens, ensure touch-scroll works, consider collapsible/expandable card state
**Warning signs:**
- User reports mobile difficulty
- Two-finger scroll required on touch devices
- Card pushes other content off-screen

## Code Examples

Verified patterns from official sources:

### Complete Gene Structure Rendering Function
```typescript
// Source: Phase 43 RESEARCH.md (D3 + Vue 3 integration pattern)
// Source: UCSC Genome Browser visual conventions
// Source: https://www.ensembl.org/info/genome/genebuild/canonical.html

interface TranscriptData {
  id: string;
  start: number;
  end: number;
  strand: '+' | '-';
  exons: Array<{
    start: number;
    end: number;
    type: 'coding' | '5_utr' | '3_utr';
  }>;
}

function renderGeneStructure(
  svg: d3.Selection<SVGSVGElement, unknown, null, undefined>,
  transcript: TranscriptData,
  width: number,
  height: number
) {
  const margin = { top: 10, right: 20, bottom: 25, left: 20 };
  const plotWidth = width - margin.left - margin.right;
  const plotHeight = height - margin.top - margin.bottom;
  const yBase = plotHeight / 2;

  // Create main group
  const g = svg.append('g')
    .attr('transform', `translate(${margin.left}, ${margin.top})`);

  // Scale: genomic coordinates to pixels
  const xScale = d3.scaleLinear()
    .domain([transcript.start, transcript.end])
    .range([0, plotWidth]);

  // Add strand direction marker
  createStrandArrowMarker(svg, transcript.strand);

  // Calculate introns (gaps between exons)
  const introns: Array<{ start: number; end: number }> = [];
  for (let i = 0; i < transcript.exons.length - 1; i++) {
    introns.push({
      start: transcript.exons[i].end,
      end: transcript.exons[i + 1].start
    });
  }

  // Render introns first (so exons render on top)
  renderIntrons(g, introns, xScale, yBase);

  // Render exons
  renderExons(g, transcript.exons, xScale, yBase);

  // Add coordinate axis
  const xAxis = d3.axisBottom(xScale)
    .ticks(5)
    .tickFormat(d => formatGenomicCoordinate(d as number));

  g.append('g')
    .attr('class', 'x-axis')
    .attr('transform', `translate(0, ${plotHeight - 5})`)
    .call(xAxis)
    .selectAll('text')
    .attr('font-size', '9px')
    .attr('fill', '#6b7280'); // Gray-500

  // Add scale bar
  renderScaleBar(g, transcript.end - transcript.start, xScale, plotHeight + 15);

  // Add chromosome and strand label
  g.append('text')
    .attr('x', 0)
    .attr('y', -2)
    .attr('font-size', '10px')
    .attr('fill', '#6b7280')
    .text(`${transcript.strand} strand`);
}
```

### Exon Tooltip with Details
```typescript
// Source: Phase 43 RESEARCH.md (tooltip edge detection pattern)
// Source: Phase 44 CONTEXT.md (exon number, size, coordinates)

function createExonTooltip(container: HTMLElement) {
  return d3.select(container)
    .append('div')
    .attr('class', 'gene-structure-tooltip')
    .style('position', 'absolute')
    .style('opacity', 0)
    .style('background-color', 'white')
    .style('border', '1px solid #d1d5db')
    .style('border-radius', '4px')
    .style('padding', '8px')
    .style('font-size', '12px')
    .style('pointer-events', 'none')
    .style('z-index', 1000)
    .style('box-shadow', '0 2px 4px rgba(0,0,0,0.1)');
}

function showExonTooltip(
  event: MouseEvent,
  exon: { start: number; end: number; type: string },
  exonIndex: number,
  tooltip: d3.Selection<HTMLDivElement, unknown, null, undefined>
) {
  const tooltipNode = tooltip.node();
  if (!tooltipNode) return;

  const exonSize = exon.end - exon.start;
  const exonTypeLabel = exon.type === 'coding' ? 'Coding exon' :
                        exon.type === '5_utr' ? "5' UTR" : "3' UTR";

  tooltip.html(`
    <div>
      <strong>Exon ${exonIndex + 1}</strong><br>
      ${exonTypeLabel}<br>
      ${formatGenomicCoordinate(exonSize)}<br>
      <span style="color: #6b7280; font-size: 10px;">
        ${exon.start.toLocaleString()} - ${exon.end.toLocaleString()}
      </span>
    </div>
  `);

  // Get tooltip dimensions
  const tooltipWidth = tooltipNode.offsetWidth;
  const tooltipHeight = tooltipNode.offsetHeight;

  // Calculate position with edge detection (from Phase 43 pattern)
  let left = event.pageX + 10;
  let top = event.pageY - 10;

  if (left + tooltipWidth > window.innerWidth - 20) {
    left = event.pageX - tooltipWidth - 10;
  }

  if (top + tooltipHeight > window.innerHeight - 20) {
    top = event.pageY - tooltipHeight - 10;
  }

  tooltip
    .style('left', `${left}px`)
    .style('top', `${top}px`)
    .style('opacity', 1);
}

function hideTooltip(
  tooltip: d3.Selection<HTMLDivElement, unknown, null, undefined>
) {
  tooltip.style('opacity', 0);
}
```

### Empty State and Error Handling
```typescript
// Source: Phase 43 RESEARCH.md (empty state pattern)
// Source: Phase 44 CONTEXT.md (loading/error states)

function renderGeneStructureOrEmptyState(
  container: HTMLElement,
  transcriptData: TranscriptData | null,
  loading: boolean,
  error: string | null
) {
  const svg = d3.select(container).select('svg');

  // Loading state
  if (loading) {
    svg.selectAll('*').remove();
    svg.append('text')
      .attr('x', 400)
      .attr('y', 30)
      .attr('text-anchor', 'middle')
      .attr('font-size', '12px')
      .attr('fill', '#6b7280')
      .text('Loading gene structure...');
    return;
  }

  // Error state
  if (error) {
    svg.selectAll('*').remove();
    svg.append('text')
      .attr('x', 400)
      .attr('y', 30)
      .attr('text-anchor', 'middle')
      .attr('font-size', '12px')
      .attr('fill', '#dc2626') // Red-600
      .text(`Error: ${error}`);
    return;
  }

  // Empty state (no canonical transcript)
  if (!transcriptData || !transcriptData.exons || transcriptData.exons.length === 0) {
    svg.selectAll('*').remove();
    svg.append('text')
      .attr('x', 400)
      .attr('y', 30)
      .attr('text-anchor', 'middle')
      .attr('font-size', '12px')
      .attr('fill', '#6b7280')
      .text('No canonical transcript available for this gene');
    return;
  }

  // Render normal state
  renderGeneStructure(svg, transcriptData, 800, 60);
}
```

### Summary Subtitle with Exon Count and Gene Length
```typescript
// Source: Phase 44 CONTEXT.md (summary subtitle requirement)

function createSummarySubtitle(
  transcript: TranscriptData
): string {
  const exonCount = transcript.exons.length;
  const geneLength = transcript.end - transcript.start;

  return `${exonCount} exon${exonCount !== 1 ? 's' : ''} • ${formatGenomicCoordinate(geneLength)}`;
}

// Usage in Vue component:
const summaryText = computed(() => {
  if (!transcriptData.value) return '';
  return createSummarySubtitle(transcriptData.value);
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flash/Java applets for genome browsers | JavaScript/D3.js with SVG | 2010-2015 | Modern browsers native SVG support, no plugins required |
| Fixed-width intron compression (equal gaps) | Proportional genomic scale | Ongoing best practice | Accurate size representation critical for understanding gene architecture |
| Server-side image generation | Client-side dynamic rendering | 2015-2020 | Interactive tooltips, responsive updates, reduced server load |
| Desktop apps (UCSC downloads) | Web-based genome browsers | 2000-2010 | Accessibility, no installation, instant updates |
| viewBox responsive scaling | Horizontal scroll for large regions | Genomics tools lagging | 29/33 tools use simple layout changes only, not information granularity control |

**Deprecated/outdated:**
- **Flash-based genome browsers:** Flash deprecated 2020, use JavaScript + SVG
- **Equal intron spacing:** Distorts biology, use proportional genomic coordinates
- **Server-generated gene structure images:** Use client-side D3.js for interactivity
- **Ignoring strand orientation:** Always indicate strand with arrows or label
- **Mobile-unfriendly fixed layouts:** Implement responsive height/width adaptation (though few genomics tools do this well)

## Open Questions

Things that couldn't be fully resolved:

1. **Ensembl Canonical Transcript API Response Format**
   - What we know: Ensembl REST API provides canonical transcript data at `/lookup/id/{id}` endpoint
   - What's unclear: Exact JSON structure for exon boundaries, UTR classification, whether exon types are pre-classified or require CDS comparison
   - Recommendation: Use Phase 40 Ensembl endpoint (40-01-PLAN.md exists) to fetch transcript data. Implement exon type classification by comparing exon coordinates to CDS start/end if not provided by API. Verify response format during implementation.

2. **Optimal Pixels-Per-Base-Pair Scale**
   - What we know: UCSC uses adaptive zoom levels, genes range from <1kb to >2Mb
   - What's unclear: Ideal default scale factor, whether to implement zoom levels or single scrollable view
   - Recommendation: Start with 0.05 pixels/bp (1kb = 50px, 100kb = 5000px) as default. For genes >100kb, horizontal scroll is acceptable per CONTEXT.md. Monitor user feedback for scale adjustment.

3. **Mobile Responsive Behavior**
   - What we know: Research shows 7/40 genomics tools have no responsive design, 29/33 use simple layout changes only
   - What's unclear: Best practice for horizontal scroll on touch devices, whether to collapse card on mobile
   - Recommendation: Mark as LOW confidence - implement basic responsive height reduction (<768px: 50px height instead of 60px), ensure touch scroll works. Phase 44 is secondary visualization, acceptable to have limited mobile UX. Iterate based on user analytics.

4. **Exon Number Labeling Strategy**
   - What we know: CONTEXT.md specifies "exon labels on hover only" in tooltip
   - What's unclear: Whether to show exon numbers inline for large exons, numbering direction for minus strand
   - Recommendation: Tooltip-only per CONTEXT.md decision. Number exons in genomic order (left-to-right) regardless of strand for consistency with coordinate axis. Show in tooltip as "Exon 3" with coordinates.

5. **Color Hex Values for Blue Tones**
   - What we know: CONTEXT.md specifies blue tones for coding exons, lighter blue for UTRs, gray for introns
   - What's unclear: Exact hex values, whether to match UCSC convention or use Tailwind/Bootstrap colors
   - Recommendation: Use Tailwind CSS blue scale for consistency with project (coding: #2563eb blue-600, UTR: #93c5fd blue-300, intron: #9ca3af gray-400). Mark as MEDIUM confidence - adjust if user feedback indicates poor contrast or accessibility issues.

## Sources

### Primary (HIGH confidence)
- Phase 43 RESEARCH.md - D3.js + Vue 3 patterns, useD3 composable, tooltip edge detection, cleanup lifecycle
- Phase 40 RESEARCH.md - Ensembl API integration, httr2 caching patterns
- Existing project codebase - package.json (d3 7.4.2, Vue 3.5.25, Bootstrap Vue Next 0.42.0)
- [D3.js v7 Official Documentation](https://d3js.org/)
  - [d3-format](https://d3js.org/d3-format) - Custom number formatting
  - [d3-scale](https://d3js.org/d3-scale) - Linear scales for genomic coordinates
  - [d3-axis](https://d3js.org/d3-axis) - Axis generation with custom tick formatting
- [Ensembl Canonical Transcript Documentation](https://www.ensembl.org/info/genome/genebuild/canonical.html)
- [NCBI Sequence Viewer Graphical Legend](https://www.ncbi.nlm.nih.gov/tools/sviewer/legends/) - Exon/intron visual conventions
- [UCSC Genome Browser User Guide](https://genome.ucsc.edu/goldenPath/help/hgTracksHelp.html) - Gene track conventions, strand indicators

### Secondary (MEDIUM confidence)
- [GenomeD3Plot GitHub](https://github.com/brinkmanlab/GenomeD3Plot) - D3-based genome viewer patterns for panning, genomic coordinates
- [plotgardener annoGenomeLabel](https://phanstiellab.github.io/plotgardener/reference/annoGenomeLabel.html) - Mb/kb/bp coordinate scale formatting
- [GenomeSpy Genomic Coordinates](https://genomespy.app/docs/genomic-data/genomic-coordinates/) - Chromosome-aware axis patterns
- [GSDS 2.0](https://academic.oup.com/bioinformatics/article/31/8/1296/213025) - Gene Structure Display Server exon/intron visualization patterns
- [ggbio package](https://genomebiology.biomedcentral.com/articles/10.1186/gb-2012-13-8-r77) - Rectangle (exon) and chevron (intron) conventions
- [Bootstrap Vue Next Card Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/card)
- [Multi-View Design Patterns and Responsive Visualization for Genomics Data](https://pmc.ncbi.nlm.nih.gov/articles/PMC10040461/) - Responsive design challenges in genomics tools

### Tertiary (LOW confidence - needs validation)
- Pixels-per-bp scale factor (0.05 px/bp): Estimated from UCSC zoom level behavior, not officially documented
- Exact color scheme (blue tones): CONTEXT.md specifies "blue tones" but not hex values - using Tailwind defaults
- Mobile responsive patterns: Research shows most genomics tools lack responsive design, best practices emerging
- SVG vs Canvas performance threshold: Phase 43 notes <1000 elements for SVG, but gene structure typically <100 elements (exons + introns)

### Genomic Conventions Referenced
- UCSC Genome Browser - https://genome.ucsc.edu/
- Ensembl Genome Browser - https://www.ensembl.org/
- IGV (Integrative Genomics Viewer) - https://eclipsebio.com/eblogs/how-to-use-igv-2/

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - D3.js v7 documented, Vue 3 Composition API established in project (Phase 43), existing patterns verified
- Architecture: HIGH - useD3 composable pattern proven in Phase 43, horizontal scroll pattern verified in D3 Genome Browser
- Exon/intron rendering: HIGH - UCSC/Ensembl/NCBI conventions well-documented, consistent across major browsers
- Coordinate formatting: MEDIUM - D3 custom formatter pattern verified, but genomic unit abbreviation requires custom implementation
- Strand direction arrows: HIGH - SVG marker pattern standard, UCSC/Ensembl use arrowheads on introns
- Responsive design: LOW - Research shows genomics tools lag in responsive design, best practices not established
- Color scheme: MEDIUM - Blue tones specified in CONTEXT.md, Tailwind colors provide accessible defaults
- Ensembl API integration: MEDIUM - Phase 40 establishes endpoint, but exact response format needs verification

**Research date:** 2026-01-27
**Valid until:** 45 days (D3.js and Vue 3 are stable; Ensembl API format should be verified during Phase 40 implementation; responsive patterns may evolve)
