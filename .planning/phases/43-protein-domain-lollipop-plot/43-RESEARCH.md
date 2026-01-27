# Phase 43: Protein Domain Lollipop Plot - Research

**Researched:** 2026-01-27
**Domain:** D3.js lollipop plot visualization in Vue 3 Composition API for protein domains and ClinVar variants
**Confidence:** HIGH

## Summary

Phase 43 implements an interactive D3.js lollipop plot showing protein domains as colored rectangles and ClinVar variants as positioned markers along a protein backbone. The visualization uses established D3.js patterns for genomic data: lollipop stems (vertical lines) topped with circular markers, brush selection for zoom, and interactive tooltips for variant details.

The standard stack combines D3.js v7 (already in project at 7.4.2) with Vue 3 Composition API lifecycle hooks. Critical patterns include: (1) isolating D3 instance from Vue reactivity to prevent layout thrashing, (2) using brushX for horizontal selection with double-click reset, (3) implementing forceCollide or vertical stacking for overlapping variants at the same position, and (4) proper cleanup in onBeforeUnmount to prevent memory leaks.

**Key challenges identified:**
1. Dense variant regions (200+ variants) require performance optimization - keep SVG elements under 1000 for smooth interaction
2. Stacked markers at same position need collision resolution or deterministic vertical offset
3. Tooltip positioning at viewport edges requires boundary detection and repositioning
4. Splice-site/intronic variants need visual distinction (shape) and explicit position mapping in tooltips
5. Bidirectional linking with 3D viewer (Phase 45) requires event emitter pattern

**Primary recommendation:** Create a useD3Lollipop composable that manages D3 lifecycle (initialize in onMounted, cleanup in onBeforeUnmount), uses watchEffect for reactive data updates, stores cy instance in non-reactive variable (let not ref), implements brushX with rescaleX for zoom, uses forceCollide or simple vertical offset for stacked markers, and provides edge-aware tooltip positioning with viewport boundary detection.

## Standard Stack

The established libraries/tools for D3.js lollipop plots in Vue 3:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| d3 | 7.4.2 (in package.json) | SVG visualization, scales, axes, brush, zoom | Industry standard for data visualization, modular design, extensive genomics usage |
| Vue 3 | 3.5.25 (in package.json) | Composition API with onMounted, watchEffect, onBeforeUnmount | Project standard, reactive lifecycle management |
| Bootstrap Vue Next | 0.42.0 (in package.json) | BCard component for card layout | Project UI standard, consistent styling |

### D3 Modules (included in d3 7.4.2)
| Module | Purpose | When to Use |
|--------|---------|-------------|
| d3-scale | scaleLinear (y-axis AA positions), scaleBand or categorical for domain colors | All coordinate mapping |
| d3-axis | axisBottom for amino acid position labels | X-axis with tick marks every 100 AA |
| d3-brush | brushX for horizontal selection, zoom into regions | Brush-to-zoom interaction |
| d3-zoom | Alternative zoom API (not needed if using brush) | Optional, brush is more genomics-standard |
| d3-force | forceCollide for preventing marker overlap | When using force simulation for stacking |
| d3-scale-chromatic | schemePaired, schemeSet3 for categorical domain colors | Protein domain color palette |
| d3-selection | select, selectAll, join for DOM manipulation | All D3 rendering |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| D3.js | Chart.js, Plotly.js | D3 provides fine-grained control needed for custom genomics viz; others are higher-level |
| brushX | d3-zoom | Brush provides selection rectangle visual feedback; zoom is more general but less intuitive for linear plots |
| forceCollide | Manual vertical offset | forceCollide is physics-based and smooth; manual offset is deterministic and faster for <50 variants per position |
| Canvas rendering | SVG | Canvas faster for 1000+ elements but loses interactivity; SVG preferred for <1000 elements with tooltips |

**Installation:**
Already installed - d3 7.4.2 in package.json dependencies.

## Architecture Patterns

### Recommended Project Structure
```
app/src/
├── components/
│   └── gene/
│       ├── ProteinDomainLollipopCard.vue    # Main card component
│       └── ProteinDomainLollipopPlot.vue    # D3 visualization component
├── composables/
│   └── useD3Lollipop.ts                     # D3 lifecycle management composable
└── types/
    └── protein.ts                            # TypeScript interfaces for UniProt/ClinVar data
```

### Pattern 1: Vue 3 + D3 Lifecycle Management (useD3Lollipop)
**What:** Composable that manages D3 instance creation, updates, and cleanup
**When to use:** All D3 visualizations in Vue 3 Composition API
**Example:**
```typescript
// Source: Existing useCytoscape.ts pattern (lines 1-100)
// Source: https://dev.to/muratkemaldar/using-vue-3-with-d3-composition-api-3h1g

import { ref, onMounted, onBeforeUnmount, watchEffect, type Ref } from 'vue';
import * as d3 from 'd3';

export interface LollipopOptions {
  container: Ref<HTMLElement | null>;
  width: number;
  height: number;
  onVariantClick?: (variantId: string) => void;
}

export function useD3Lollipop(options: LollipopOptions) {
  // CRITICAL: Store D3 selection in non-reactive variable to prevent Vue
  // reactivity from triggering layout recalculations on every update
  let svg: d3.Selection<SVGSVGElement, unknown, null, undefined> | null = null;
  let brush: d3.BrushBehavior<unknown> | null = null;

  const isInitialized = ref(false);
  const isLoading = ref(false);

  const initializePlot = () => {
    if (!options.container.value) return;

    // Remove any existing SVG
    d3.select(options.container.value).select('svg').remove();

    // Create SVG with viewBox for responsive scaling
    svg = d3.select(options.container.value)
      .append('svg')
      .attr('viewBox', `0 0 ${options.width} ${options.height}`)
      .attr('preserveAspectRatio', 'xMinYMin meet');

    // Create brush for zoom
    brush = d3.brushX()
      .extent([[0, 0], [options.width, options.height]])
      .on('end', handleBrushEnd);

    isInitialized.value = true;
  };

  const updatePlot = (data: ProteinData) => {
    if (!svg) return;
    isLoading.value = true;

    // D3 rendering logic here
    renderDomains(svg, data.domains);
    renderVariants(svg, data.variants);

    isLoading.value = false;
  };

  const cleanup = () => {
    // CRITICAL: Clean up D3 to prevent memory leaks
    if (svg) {
      svg.selectAll('*').remove();
      svg.remove();
      svg = null;
    }
    brush = null;
    isInitialized.value = false;
  };

  // Initialize on mount
  onMounted(() => {
    initializePlot();
  });

  // Clean up on unmount
  onBeforeUnmount(() => {
    cleanup();
  });

  return {
    isInitialized,
    isLoading,
    updatePlot,
    getSvg: () => svg,
  };
}
```

### Pattern 2: Lollipop Plot Structure (Lines + Circles)
**What:** Vertical lines (stems) from baseline with circles (heads) at data values
**When to use:** Showing discrete variant positions along continuous protein backbone
**Example:**
```typescript
// Source: https://d3-graph-gallery.com/graph/lollipop_basic.html
// Source: Existing AnalysesTimePlot.vue pattern (lines 264-336)

function renderVariants(
  svg: d3.Selection<SVGSVGElement, unknown, null, undefined>,
  variants: Variant[],
  xScale: d3.ScaleLinear<number, number>,
  yBase: number
) {
  // Group by position for stacking
  const variantsByPosition = d3.group(variants, d => d.proteinPosition);

  // Flatten with stack offset
  const stackedVariants = Array.from(variantsByPosition.entries()).flatMap(
    ([position, vars]) => vars.map((v, i) => ({
      ...v,
      stackOffset: i * 12 // 12px vertical spacing per variant
    }))
  );

  const g = svg.append('g').attr('class', 'variants');

  // Draw stems (vertical lines)
  g.selectAll('.stem')
    .data(stackedVariants)
    .join('line')
    .attr('class', 'stem')
    .attr('x1', d => xScale(d.proteinPosition))
    .attr('x2', d => xScale(d.proteinPosition))
    .attr('y1', yBase)
    .attr('y2', d => yBase - 40 - d.stackOffset) // 40px base height + stack
    .attr('stroke', '#ccc')
    .attr('stroke-width', 1);

  // Draw heads (circles or triangles for splice variants)
  g.selectAll('.variant-marker')
    .data(stackedVariants)
    .join('circle') // or 'path' for triangles
    .attr('class', 'variant-marker')
    .attr('cx', d => xScale(d.proteinPosition))
    .attr('cy', d => yBase - 40 - d.stackOffset)
    .attr('r', 5)
    .attr('fill', d => getPathogenicityColor(d.classification))
    .attr('stroke', '#fff')
    .attr('stroke-width', 1)
    .style('cursor', 'pointer')
    .on('mouseover', showTooltip)
    .on('mouseout', hideTooltip)
    .on('click', (event, d) => handleVariantClick(d));
}

// Pathogenicity colors (convention-based, not ACMG-official)
function getPathogenicityColor(classification: string): string {
  const colors: Record<string, string> = {
    'Pathogenic': '#d73027',           // Red
    'Likely pathogenic': '#fc8d59',    // Orange
    'Uncertain significance': '#fee08b', // Yellow
    'Likely benign': '#91cf60',        // Light green
    'Benign': '#1a9850',               // Green
  };
  return colors[classification] || '#999';
}
```

### Pattern 3: Brush Selection for Zoom
**What:** brushX with double-click reset for exploring dense regions
**When to use:** Genomics visualizations with linear scale (AA positions)
**Example:**
```typescript
// Source: https://d3js.org/d3-brush
// Source: https://github.com/brinkmanlab/GenomeD3Plot (genomics brush pattern)

function setupBrush(
  svg: d3.Selection<SVGSVGElement, unknown, null, undefined>,
  xScale: d3.ScaleLinear<number, number>,
  height: number,
  onZoom: (newScale: d3.ScaleLinear<number, number>) => void
) {
  const brush = d3.brushX()
    .extent([[0, 0], [xScale.range()[1], height]])
    .on('end', (event) => {
      if (!event.selection) return;

      const [x0, x1] = event.selection as [number, number];

      // Create new scale zoomed to selection
      const newScale = xScale.copy().domain([
        xScale.invert(x0),
        xScale.invert(x1)
      ]);

      // Clear brush selection
      svg.select('.brush').call(brush.move as any, null);

      // Trigger re-render with new scale
      onZoom(newScale);
    });

  // Add brush to SVG
  const brushGroup = svg.append('g')
    .attr('class', 'brush')
    .call(brush);

  // Double-click to reset zoom
  svg.on('dblclick', () => {
    onZoom(xScale.copy()); // Reset to original scale
  });
}
```

### Pattern 4: Tooltip with Viewport Edge Detection
**What:** Tooltip that repositions when near viewport edges
**When to use:** All interactive hover tooltips in D3 visualizations
**Example:**
```typescript
// Source: https://d3-graph-gallery.com/graph/interactivity_tooltip.html
// Source: https://gist.github.com/GerHobbelt/2505393 (edge detection)
// Source: Existing AnalysesTimePlot.vue (lines 280-310)

function createTooltip(container: HTMLElement) {
  return d3.select(container)
    .append('div')
    .attr('class', 'lollipop-tooltip')
    .style('position', 'absolute')
    .style('opacity', 0)
    .style('background-color', 'white')
    .style('border', '1px solid #ccc')
    .style('border-radius', '4px')
    .style('padding', '8px')
    .style('pointer-events', 'none')
    .style('z-index', 1000);
}

function showTooltip(
  event: MouseEvent,
  variant: Variant,
  tooltip: d3.Selection<HTMLDivElement, unknown, null, undefined>
) {
  const tooltipNode = tooltip.node();
  if (!tooltipNode) return;

  // Set content first to measure dimensions
  tooltip.html(`
    <strong>${variant.proteinHGVS}</strong><br>
    ${variant.codingHGVS}<br>
    <span style="color: ${getPathogenicityColor(variant.classification)}">
      ${variant.classification}
    </span>
  `);

  // Get tooltip dimensions
  const tooltipWidth = tooltipNode.offsetWidth;
  const tooltipHeight = tooltipNode.offsetHeight;

  // Calculate position with edge detection
  let left = event.pageX + 10;
  let top = event.pageY - 10;

  // Check right edge overflow
  if (left + tooltipWidth > window.innerWidth - 20) {
    left = event.pageX - tooltipWidth - 10;
  }

  // Check bottom edge overflow
  if (top + tooltipHeight > window.innerHeight - 20) {
    top = event.pageY - tooltipHeight - 10;
  }

  // Position and show tooltip
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

### Pattern 5: Categorical Color Palette for Domains
**What:** D3 categorical color schemes for protein domain types
**When to use:** Mapping domain types to distinct colors
**Example:**
```typescript
// Source: https://d3js.org/d3-scale-chromatic/categorical

import * as d3 from 'd3';

// schemePaired: 12 colors, good for many domain types
// schemeSet3: 12 colors, softer palette
// schemeSet2: 8 colors, medium saturation
const domainColorScale = d3.scaleOrdinal(d3.schemePaired);

function renderDomains(
  svg: d3.Selection<SVGSVGElement, unknown, null, undefined>,
  domains: Domain[],
  xScale: d3.ScaleLinear<number, number>,
  yBase: number
) {
  svg.selectAll('.domain-rect')
    .data(domains)
    .join('rect')
    .attr('class', 'domain-rect')
    .attr('x', d => xScale(d.start))
    .attr('y', yBase + 10)
    .attr('width', d => xScale(d.end) - xScale(d.start))
    .attr('height', 20)
    .attr('fill', d => domainColorScale(d.type))
    .attr('opacity', 0.7)
    .attr('stroke', '#333')
    .attr('stroke-width', 1);

  // Domain labels
  svg.selectAll('.domain-label')
    .data(domains.filter(d => (d.end - d.start) > 30)) // Only label large domains
    .join('text')
    .attr('class', 'domain-label')
    .attr('x', d => (xScale(d.start) + xScale(d.end)) / 2)
    .attr('y', yBase + 25)
    .attr('text-anchor', 'middle')
    .attr('font-size', '10px')
    .attr('fill', '#000')
    .text(d => d.name);
}
```

### Anti-Patterns to Avoid
- **Making D3 instance reactive (ref):** Causes 100+ layout recalculations, massive performance hit. Store in `let` variable.
- **Appending elements on every update:** Use `.join()` pattern for enter/update/exit, not `.append()` in watchEffect.
- **Skipping onBeforeUnmount cleanup:** Causes 50-100MB memory leaks per navigation, D3 holds DOM references.
- **Using Canvas for <1000 elements:** Loses hover interactivity, tooltips, click handlers. SVG is fine for 200-500 variants.
- **Fixed tooltip positioning:** Tooltips overflow viewport edges. Always implement boundary detection.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Brush selection | Custom drag-select rectangle | d3.brushX() | Handles touch events, modifier keys, cancellation, edge snapping - 500+ lines of edge cases |
| Collision detection | Manual overlap checking | d3.forceCollide() | Physics-based iterative relaxation handles simultaneous overlaps, n-body optimization |
| Scale transformation | Manual domain/range math | d3.scaleLinear() with domain/range | Handles clamping, rounding, inversion, rescaling - battle-tested edge cases |
| Color interpolation | Manual RGB math | d3.scaleOrdinal() with categorical schemes | Color-blind safe palettes, perceptually uniform spacing, proven in genomics |
| Axis generation | Manual tick calculation and SVG | d3.axisBottom() | Automatic tick spacing, label collision, formatting, orientation - 1000+ lines |

**Key insight:** D3 modules are designed for composition - brushX, scaleLinear, axisBottom work together seamlessly. Custom implementations break these integrations and miss edge cases (touch events, accessibility, extreme values, NaN handling).

## Common Pitfalls

### Pitfall 1: D3 Instance as Reactive Ref
**What goes wrong:** Making D3 selection or Cytoscape instance a ref() triggers Vue reactivity on every D3 update, causing 100+ layout recalculations and UI freezing
**Why it happens:** Natural Vue pattern to wrap state in ref(), but D3 has its own internal state management
**How to avoid:** Store D3 selections in `let` variables, not `ref()`. Only make UI state reactive (isLoading, isInitialized).
**Warning signs:**
- Component lags during pan/zoom
- DevTools shows hundreds of reactive triggers
- CPU spikes to 100% on data updates

### Pitfall 2: Memory Leaks from Missing Cleanup
**What goes wrong:** Not calling `.remove()` on D3 selections in onBeforeUnmount causes 50-100MB leaks per navigation, accumulating until browser crashes
**Why it happens:** D3 attaches event listeners and holds DOM references; Vue unmounting component doesn't clean up D3 state
**How to avoid:** Always implement cleanup in onBeforeUnmount that removes all D3 selections and nullifies references
**Warning signs:**
- Memory usage grows with each navigation
- Event listeners multiply in DevTools
- Page becomes sluggish after 5-10 navigations

### Pitfall 3: Tooltip Positioning at Viewport Edges
**What goes wrong:** Tooltips overflow viewport right/bottom edges, cutting off content and confusing users
**Why it happens:** Naive `left: event.pageX + 10` positioning doesn't check viewport bounds
**How to avoid:** Always implement edge detection - check if tooltip would overflow, reposition to opposite side of cursor
**Warning signs:**
- Tooltips cut off when hovering near edges
- Scrollbars appear when tooltip shown
- Tooltip partially offscreen

### Pitfall 4: Overlapping Variants Without Stacking
**What goes wrong:** Multiple variants at same position render on top of each other, making all but top one invisible and unclickable
**Why it happens:** Protein positions are integers (AA 123), multiple variants can map to same position
**How to avoid:** Group variants by position, apply vertical offset (stackOffset = index * 12px) to separate them visually
**Warning signs:**
- User reports "missing variants" that are actually hidden
- Click targets overlap and wrong variant is selected
- Tooltips show for wrong variant

### Pitfall 5: Performance Degradation with 500+ Variants
**What goes wrong:** Rendering slows to 2-3 seconds, pan/zoom becomes laggy, browser becomes unresponsive
**Why it happens:** Each variant is 2 SVG elements (line + circle), 500 variants = 1000 DOM nodes, plus event listeners
**How to avoid:**
- Use `.join()` pattern for efficient enter/update/exit (not re-appending all elements)
- Reduce SVG complexity (combine paths where possible)
- Consider visibility culling (only render variants in current zoom extent)
- Debounce zoom updates to avoid render thrashing
**Warning signs:**
- Initial render takes >1 second
- Zoom feels sluggish or janky
- DevTools shows long paint times (>16ms)

### Pitfall 6: Forgetting Splice Variant Visual Distinction
**What goes wrong:** Splice-site/intronic variants (c.123+2A>G) rendered as circles like coding variants, no indication they're mapped to approximate position
**Why it happens:** Easy to forget non-coding variants need special handling during development
**How to avoid:** Filter variants by type, render triangles/diamonds for splice variants, add explicit mapping note to tooltip ("c.123+2A>G → mapped to AA 41")
**Warning signs:**
- Geneticist user feedback about "confusing" splice variant positions
- No visual distinction between direct and mapped variants
- Tooltip doesn't explain position derivation

## Code Examples

Verified patterns from official sources:

### Complete Responsive SVG Setup
```typescript
// Source: Existing AnalysesTimePlot.vue (lines 209-220)
// Source: https://chartio.com/resources/tutorials/how-to-resize-an-svg-when-the-window-is-resized-in-d3-js/

const margin = { top: 50, right: 50, bottom: 50, left: 50 };
const width = 800 - margin.left - margin.right;
const height = 300 - margin.top - margin.bottom;

// Remove any existing SVG
d3.select(container.value).select('svg').remove();

// Create responsive SVG with viewBox
const svg = d3.select(container.value)
  .append('svg')
  .attr('id', 'lollipop-svg')
  .attr('viewBox', `0 0 ${width + margin.left + margin.right} ${height + margin.top + margin.bottom}`)
  .attr('preserveAspectRatio', 'xMinYMin meet')
  .classed('svg-content', true)
  .append('g')
  .attr('transform', `translate(${margin.left},${margin.top})`);
```

### Accessible SVG with ARIA Labels
```typescript
// Source: https://fossheim.io/writing/posts/accessible-dataviz-d3-intro/
// Source: Existing AnalysesTimePlot.vue aria-label pattern (line 326)

// Add title and description for screen readers
svg.append('title')
  .attr('id', 'lollipop-title')
  .text('Protein domain and variant lollipop plot');

svg.append('desc')
  .attr('id', 'lollipop-desc')
  .text(`Interactive visualization showing ${variants.length} ClinVar variants mapped to protein domains for ${geneSymbol}`);

svg.attr('aria-labelledby', 'lollipop-title lollipop-desc')
  .attr('role', 'img');

// Add aria-label to clickable elements
svg.selectAll('.variant-marker')
  .attr('role', 'button')
  .attr('aria-label', d => `${d.proteinHGVS}, ${d.classification}, click to highlight in 3D viewer`);
```

### Legend with Clickable Filter Toggle
```typescript
// Source: Existing AnalysesTimePlot.vue (lines 339-361)

interface LegendItem {
  label: string;
  color: string;
  visible: boolean;
}

const legendData: LegendItem[] = [
  { label: 'Pathogenic', color: '#d73027', visible: true },
  { label: 'Likely pathogenic', color: '#fc8d59', visible: true },
  { label: 'VUS', color: '#fee08b', visible: true },
  { label: 'Likely benign', color: '#91cf60', visible: true },
  { label: 'Benign', color: '#1a9850', visible: true },
];

function createLegend(
  svg: d3.Selection<SVGSVGElement, unknown, null, undefined>,
  data: LegendItem[],
  onToggle: (label: string) => void
) {
  const legend = svg.append('g')
    .attr('class', 'legend')
    .attr('transform', `translate(0, ${height + 40})`);

  const items = legend.selectAll('.legend-item')
    .data(data)
    .join('g')
    .attr('class', d => `legend-item ${d.label.replace(/\s+/g, '_')}`)
    .attr('transform', (d, i) => `translate(${i * 150}, 0)`)
    .style('cursor', 'pointer')
    .on('click', (event, d) => {
      // Toggle visibility
      d.visible = !d.visible;

      // Visual feedback - lower opacity for hidden
      d3.select(event.currentTarget)
        .style('opacity', d.visible ? 1 : 0.3);

      // Trigger filter update
      onToggle(d.label);
    });

  // Color circle
  items.append('circle')
    .attr('cx', 0)
    .attr('cy', 0)
    .attr('r', 6)
    .attr('fill', d => d.color);

  // Label text
  items.append('text')
    .attr('x', 12)
    .attr('y', 5)
    .text(d => d.label)
    .style('font-size', '12px')
    .style('fill', '#333');
}
```

### Empty State Handling
```typescript
// Source: Phase 43 CONTEXT.md requirements

function renderPlot(proteinData: ProteinData) {
  const { domains, variants, proteinLength } = proteinData;

  // Case 1: No ClinVar variants but have domains
  if (variants.length === 0 && domains.length > 0) {
    renderDomains(svg, domains, xScale, yBase);
    showEmptyMessage(svg, 'No ClinVar variants mapped to this protein');
    return;
  }

  // Case 2: No domains but have variants
  if (domains.length === 0 && variants.length > 0) {
    renderProteinBackbone(svg, proteinLength, xScale, yBase);
    renderVariants(svg, variants, xScale, yBase);
    return;
  }

  // Case 3: Both data types available
  if (domains.length > 0 && variants.length > 0) {
    renderDomains(svg, domains, xScale, yBase);
    renderVariants(svg, variants, xScale, yBase);
    return;
  }

  // Case 4: No data at all - error state handled by parent component
}

function showEmptyMessage(
  svg: d3.Selection<SVGSVGElement, unknown, null, undefined>,
  message: string
) {
  svg.append('text')
    .attr('class', 'empty-message')
    .attr('x', width / 2)
    .attr('y', height / 2)
    .attr('text-anchor', 'middle')
    .style('font-size', '14px')
    .style('fill', '#666')
    .text(message);
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| d3.scaleOrdinal(d3.schemeCategory20) | d3.scaleOrdinal(d3.schemePaired) or schemeSet3 | D3 v5 (2018) | Category20 deprecated; new schemes are color-blind safe |
| .enter().append() pattern | .join() pattern | D3 v5 (2018) | join() handles enter/update/exit in one call, less boilerplate |
| Options API (Vue 2) | Composition API (Vue 3) | Vue 3 (2020) | Better lifecycle control, easier to extract D3 logic to composable |
| httr (R client) | httr2 (R client) | 2023 | Better retry/throttle for external APIs (Phase 40 dependency) |
| Canvas for all large datasets | SVG for <1000 elements, Canvas for 1000+ | Ongoing best practice | SVG maintains interactivity; Canvas only when performance requires |

**Deprecated/outdated:**
- **d3.schemeCategory20:** Removed in D3 v5, use schemePaired or schemeSet3 instead
- **d3.event (global):** Removed in D3 v6, event passed as first parameter to handlers
- **selection.data(data).enter().append():** Use selection.data(data).join('element') instead
- **Vue 2 Options API with D3:** Use Vue 3 Composition API with lifecycle hooks for cleaner integration

## Open Questions

Things that couldn't be fully resolved:

1. **Bidirectional Linking with 3D Viewer (Phase 45)**
   - What we know: CONTEXT.md specifies clicking variant in lollipop should highlight in 3D viewer and vice versa
   - What's unclear: Event bus pattern vs. props/emits, coordination mechanism for two independent D3 visualizations
   - Recommendation: Implement event emitter pattern in parent GeneView component; both visualizations emit 'variant-selected' events and listen for updates. Phase 45 will define the protocol.

2. **Splice Variant Position Mapping Accuracy**
   - What we know: Context specifies "coding position / 3" rule (c.123+2A>G → AA 41)
   - What's unclear: Edge cases (start codon variants, stop codon variants, frameshifts, negative offsets)
   - Recommendation: Implement simple "floor(codingPosition / 3)" for MVP, mark as approximate in tooltip. Phase 42 backend may provide pre-computed protein positions.

3. **Official ACMG Color Scheme**
   - What we know: 5-tier classification (P, LP, VUS, LB, B) is standard, but no official color scheme in ACMG guidelines
   - What's unclear: Whether to follow ClinVar convention (red/orange/yellow/green) or use different scheme
   - Recommendation: Use convention-based red-to-green spectrum (Pathogenic: #d73027, LP: #fc8d59, VUS: #fee08b, LB: #91cf60, Benign: #1a9850). Mark as LOW confidence for color scheme specifically - verify with domain expert if available.

4. **Performance Threshold for Canvas Fallback**
   - What we know: SVG preferred for interactivity, Canvas faster for large datasets
   - What's unclear: Exact variant count threshold where Canvas becomes necessary (500? 1000? 2000?)
   - Recommendation: Start with SVG, monitor performance. If user reports with >500 variants show lag, implement Canvas fallback. Decision point: if rendering takes >500ms or pan/zoom FPS <30.

## Sources

### Primary (HIGH confidence)
- D3.js v7 Official Documentation - https://d3js.org/
  - d3-brush module: https://d3js.org/d3-brush
  - d3-zoom module: https://d3js.org/d3-zoom
  - Categorical color schemes: https://d3js.org/d3-scale-chromatic/categorical
  - d3-force collide: https://d3js.org/d3-force/collide
- Vue 3 Composition API Lifecycle Hooks: https://vuejs.org/api/composition-api-lifecycle
- D3 Graph Gallery Lollipop Chart: https://d3-graph-gallery.com/lollipop
- Existing project code patterns (useCytoscape.ts, AnalysesTimePlot.vue, AnalysesVariantCorrelogram.vue)
- Phase 40 RESEARCH.md (httr2, caching patterns for external data)

### Secondary (MEDIUM confidence)
- Vue 3 Composition API with D3 integration: https://dev.to/muratkemaldar/using-vue-3-with-d3-composition-api-3h1g
- Accessible D3 visualizations: https://fossheim.io/writing/posts/accessible-dataviz-d3-intro/
- D3 tooltip positioning: https://d3-graph-gallery.com/graph/interactivity_tooltip.html
- Performance optimization strategies: https://moldstud.com/articles/p-optimizing-d3js-rendering-best-practices-for-faster-graphics-performance
- GenomeD3Plot (brush patterns): https://github.com/brinkmanlab/GenomeD3Plot

### Tertiary (LOW confidence - needs validation)
- ACMG variant color scheme (red/green convention): Community standard observed in tools like ProteinPaint, Simple ClinVar, but not documented in official ACMG guidelines
- Exact performance thresholds (1000 SVG elements): Rule of thumb from https://groups.google.com/g/d3-js/c/ZJ6pznVU5LQ/m/wLYuIGPUnvsJ, varies by browser and element complexity
- Splice variant mapping formula (position / 3): Simple approximation, may have edge cases not covered in available documentation

### Tools Referenced
- ProteinPaint (NCI GDC): https://docs.gdc.cancer.gov/Data_Portal/Users_Guide/proteinpaint_lollipop/
- Simple ClinVar: https://simple-clinvar.broadinstitute.org/
- LollipopVariant (GitHub): https://github.com/arturolp/LollipopVariant
- Lollipops command-line tool: https://github.com/joiningdata/lollipops

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - D3.js v7 documented, Vue 3 Composition API established in project, existing patterns verified
- Architecture: HIGH - Composable pattern proven in useCytoscape.ts, D3 lifecycle management well-documented
- Lollipop plot structure: HIGH - Official D3 Graph Gallery examples, verified in genomics tools
- Brush/zoom patterns: HIGH - Official d3-brush documentation, genomics-specific implementations found
- Performance optimization: MEDIUM - General guidance from multiple sources, exact thresholds vary by use case
- Pathogenicity colors: LOW - Convention-based not official standard, should verify with domain expert
- Accessibility: HIGH - Official guidelines from fossheim.io and W3C, ARIA patterns verified

**Research date:** 2026-01-27
**Valid until:** 60 days (D3.js and Vue 3 are stable; color schemes and performance thresholds should be re-evaluated with user feedback)
