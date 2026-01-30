// composables/useD3GeneStructure.ts

/**
 * Composable for D3.js gene structure visualization lifecycle management
 *
 * Manages D3.js SVG initialization, gene structure rendering (exons, introns,
 * UTRs, strand direction), tooltips, and proper cleanup to prevent memory leaks.
 *
 * CRITICAL: D3 selections are stored in non-reactive variables (let svg)
 * to avoid Vue reactivity triggering layout recalculations.
 *
 * CRITICAL: Always removes event listeners and DOM nodes in onBeforeUnmount
 * to prevent memory leaks.
 *
 * Follows the useCytoscape/useD3Lollipop pattern for safe D3/Vue integration.
 *
 * Renders gene structure as a horizontal strip with:
 * - Intron lines with strand direction arrow markers
 * - Exon rectangles (tall for coding, short for UTR - UCSC convention)
 * - Coordinate axis with Mb/kb/bp formatting
 * - Scale bar with adaptive length
 * - Transcript ID and summary labels
 * - Tooltip with exon details and edge detection
 */

import { ref, onBeforeUnmount, readonly, type Ref } from 'vue';
import * as d3 from 'd3';
import type { GeneStructureRenderData, ClassifiedExon, Intron } from '@/types/ensembl';
import { formatGenomicCoordinate } from '@/types/ensembl';

/**
 * Options for the useD3GeneStructure composable
 */
export interface GeneStructureOptions {
  /** Ref to the container HTML element where SVG will be appended */
  container: Ref<HTMLElement | null>;
  /** Ref to the parent scroll container for horizontal overflow handling */
  scrollContainer: Ref<HTMLElement | null>;
}

/**
 * State and controls returned by the composable
 */
export interface D3GeneStructureState {
  /** Whether the D3 SVG is initialized */
  isInitialized: Readonly<Ref<boolean>>;
  /** Render/update the gene structure visualization */
  renderGeneStructure: (data: GeneStructureRenderData) => void;
  /** Clean up D3 resources (called automatically on unmount) */
  cleanup: () => void;
}

// Visual constants (heights in pixels)
const CODING_HEIGHT = 20; // Tall coding exon rectangles
const UTR_HEIGHT = 10; // Shorter UTR rectangles (UCSC convention)

// Color scheme (Tailwind CSS colors)
const CODING_COLOR = '#2563eb'; // blue-600
const UTR_COLOR = '#93c5fd'; // blue-300
const INTRON_COLOR = '#9ca3af'; // gray-400
const EXON_STROKE = '#1e40af'; // blue-800

// Layout constants
const MARGIN = { top: 20, right: 30, bottom: 35, left: 30 };
const STRIP_HEIGHT = 60; // Total SVG height
const MIN_SVG_WIDTH = 600; // Minimum width for small genes
const PIXELS_PER_BP = 0.05; // Default scale: 1kb = 50px

/**
 * Composable for managing D3.js gene structure visualization lifecycle
 *
 * @param options - Configuration options including container refs
 * @returns State and control functions for the D3 visualization
 *
 * @example
 * ```typescript
 * const containerRef = ref<HTMLElement | null>(null);
 * const scrollContainerRef = ref<HTMLElement | null>(null);
 *
 * const {
 *   isInitialized,
 *   renderGeneStructure,
 * } = useD3GeneStructure({
 *   container: containerRef,
 *   scrollContainer: scrollContainerRef,
 * });
 *
 * // After data is fetched:
 * renderGeneStructure(processedData);
 * ```
 */
export function useD3GeneStructure(options: GeneStructureOptions): D3GeneStructureState {
  // CRITICAL: Store D3 selections in non-reactive variables
  // Using ref() would cause Vue reactivity to trigger unnecessary updates
  let svg: d3.Selection<SVGSVGElement, unknown, null, undefined> | null = null;
  let tooltipDiv: d3.Selection<HTMLDivElement, unknown, null, undefined> | null = null;

  // Reactive state for UI binding
  const isInitialized = ref(false);

  /**
   * Calculate appropriate scale bar length based on gene length
   */
  const calculateScaleBarLength = (geneLength: number): { length: number; label: string } => {
    if (geneLength > 100_000) {
      return { length: 10_000, label: '10 kb' };
    } else if (geneLength > 10_000) {
      return { length: 1_000, label: '1 kb' };
    } else {
      return { length: 100, label: '100 bp' };
    }
  };

  /**
   * Show tooltip for exon hover with edge detection
   */
  const showExonTooltip = (
    event: MouseEvent,
    exon: ClassifiedExon,
    containerEl: HTMLElement
  ): void => {
    if (!tooltipDiv) return;

    // Build tooltip content
    const typeLabel =
      exon.type === 'coding' ? 'Coding exon' : exon.type === '5_utr' ? "5' UTR" : "3' UTR";
    const exonSize = exon.end - exon.start;

    const html = `
      <div style="font-weight: bold; margin-bottom: 4px;">Exon ${exon.exonNumber}</div>
      <div style="color: #ccc; margin-bottom: 4px;">${typeLabel}</div>
      <div style="color: #aaa; font-size: 11px;">
        Size: ${formatGenomicCoordinate(exonSize)}
      </div>
      <div style="color: #aaa; font-size: 11px;">
        ${exon.start.toLocaleString()} - ${exon.end.toLocaleString()}
      </div>
    `;

    tooltipDiv.html(html).style('opacity', 1);

    // Get dimensions for edge detection
    const tooltipNode = tooltipDiv.node();
    if (!tooltipNode) return;

    const tooltipRect = tooltipNode.getBoundingClientRect();
    const containerRect = containerEl.getBoundingClientRect();

    // Calculate position relative to container
    let left = event.clientX - containerRect.left + 15;
    let top = event.clientY - containerRect.top - 10;

    // Edge detection - check right overflow
    if (left + tooltipRect.width > containerRect.width) {
      left = event.clientX - containerRect.left - tooltipRect.width - 15;
    }

    // Edge detection - check bottom overflow
    if (top + tooltipRect.height > containerRect.height) {
      top = event.clientY - containerRect.top - tooltipRect.height - 10;
    }

    // Ensure not negative
    left = Math.max(0, left);
    top = Math.max(0, top);

    tooltipDiv.style('left', `${left}px`).style('top', `${top}px`);
  };

  /**
   * Hide tooltip
   */
  const hideTooltip = (): void => {
    if (!tooltipDiv) return;
    tooltipDiv.style('opacity', 0);
  };

  /**
   * Render the gene structure visualization
   *
   * @param data - Processed gene structure data ready for rendering
   *
   * Rendering steps:
   * 1. Calculate SVG width from gene length
   * 2. Clear previous render
   * 3. Create SVG with accessibility attributes
   * 4. Create scales and base y-position
   * 5. Render intron lines with strand arrow markers (back layer)
   * 6. Render exon rectangles with tooltips (front layer)
   * 7. Render coordinate axis with Mb/kb/bp formatting
   * 8. Render strand label, transcript ID, and summary
   * 9. Render scale bar
   * 10. Create tooltip div
   */
  const renderGeneStructure = (data: GeneStructureRenderData): void => {
    // Guard: return early if container ref is null
    if (!options.container.value) {
      console.warn('[useD3GeneStructure] Container not available');
      return;
    }

    // Calculate SVG width from gene length
    const calculatedWidth = data.geneLength * PIXELS_PER_BP;
    const svgWidth = Math.max(calculatedWidth, MIN_SVG_WIDTH);

    // Set container div width for scroll container to work
    if (options.scrollContainer.value) {
      (options.scrollContainer.value as HTMLElement).style.width =
        `${svgWidth + MARGIN.left + MARGIN.right}px`;
    }

    // Clear previous render
    d3.select(options.container.value).select('svg').remove();
    d3.select(options.container.value).select('.gene-structure-tooltip').remove();

    // Create SVG
    svg = d3
      .select(options.container.value)
      .append('svg')
      .attr('width', svgWidth + MARGIN.left + MARGIN.right)
      .attr('height', STRIP_HEIGHT)
      .attr('role', 'img')
      .attr(
        'aria-label',
        `Gene structure diagram for ${data.geneSymbol} showing ${data.exonCount} exons on chromosome ${data.chromosome}`
      );

    // Create main group with margin transform
    const mainGroup = svg
      .append('g')
      .attr('class', 'main-group')
      .attr('transform', `translate(${MARGIN.left}, ${MARGIN.top})`);

    // Calculate plot dimensions
    const plotWidth = svgWidth;
    const plotHeight = STRIP_HEIGHT - MARGIN.top - MARGIN.bottom;

    // Create x scale (genomic coordinates to pixels)
    const xScale = d3.scaleLinear().domain([data.geneStart, data.geneEnd]).range([0, plotWidth]);

    // Calculate y baseline (center of plot area)
    const yBase = plotHeight / 2;

    // Create strand arrow marker (SVG defs)
    const defs = svg.append('defs');
    const marker = defs
      .append('marker')
      .attr('id', 'strand-arrow')
      .attr('markerWidth', 6)
      .attr('markerHeight', 6)
      .attr('refX', data.strand === '+' ? 6 : 0)
      .attr('refY', 3)
      .attr('orient', 'auto');

    if (data.strand === '+') {
      // Right-pointing arrowhead for forward strand
      marker.append('path').attr('d', 'M 0 0 L 6 3 L 0 6 Z').attr('fill', INTRON_COLOR);
    } else {
      // Left-pointing arrowhead for reverse strand
      marker.append('path').attr('d', 'M 6 0 L 0 3 L 6 6 Z').attr('fill', INTRON_COLOR);
    }

    // Render intron lines (back layer)
    data.introns.forEach((intron: Intron) => {
      mainGroup
        .append('line')
        .attr('class', 'intron')
        .attr('x1', xScale(intron.start))
        .attr('y1', yBase)
        .attr('x2', xScale(intron.end))
        .attr('y2', yBase)
        .attr('stroke', INTRON_COLOR)
        .attr('stroke-width', 1)
        .attr('marker-end', 'url(#strand-arrow)');
    });

    // Get container element for tooltip positioning
    const containerEl = options.container.value;

    // Render exon rectangles (front layer)
    data.exons.forEach((exon: ClassifiedExon) => {
      const exonWidth = Math.max(xScale(exon.end) - xScale(exon.start), 2); // Minimum 2px for visibility
      const height = exon.type === 'coding' ? CODING_HEIGHT : UTR_HEIGHT;
      const fillColor = exon.type === 'coding' ? CODING_COLOR : UTR_COLOR;

      mainGroup
        .append('rect')
        .attr('class', 'exon')
        .attr('x', xScale(exon.start))
        .attr('y', yBase - height / 2) // Centered on baseline
        .attr('width', exonWidth)
        .attr('height', height)
        .attr('fill', fillColor)
        .attr('stroke', EXON_STROKE)
        .attr('stroke-width', 0.5)
        .attr('cursor', 'pointer')
        .attr('aria-label', `Exon ${exon.exonNumber}: ${exon.type}`)
        .on('mouseover', (event: MouseEvent) => {
          showExonTooltip(event, exon, containerEl);
        })
        .on('mouseout', () => {
          hideTooltip();
        });
    });

    // Render coordinate axis (bottom)
    const xAxis = d3
      .axisBottom(xScale)
      .ticks(5)
      .tickFormat((d) => formatGenomicCoordinate(d as number));

    const axisGroup = mainGroup
      .append('g')
      .attr('class', 'x-axis')
      .attr('transform', `translate(0, ${plotHeight})`)
      .call(xAxis);

    // Style axis
    axisGroup.selectAll('text').style('font-size', '9px').style('fill', '#6b7280'); // gray-500

    axisGroup.selectAll('line').style('stroke', '#d1d5db'); // gray-300

    axisGroup.select('.domain').style('stroke', '#d1d5db'); // gray-300

    // Render strand label (top-left)
    mainGroup
      .append('text')
      .attr('class', 'strand-label')
      .attr('x', 0)
      .attr('y', -10)
      .style('font-size', '9px')
      .style('fill', '#6b7280') // gray-500
      .text(`${data.strand} strand`);

    // Render transcript ID and summary (top-right)
    const summaryText = `${data.transcriptId} | ${data.exonCount} exons | ${formatGenomicCoordinate(data.geneLength)}`;
    mainGroup
      .append('text')
      .attr('class', 'transcript-summary')
      .attr('x', plotWidth)
      .attr('y', -10)
      .attr('text-anchor', 'end')
      .style('font-size', '9px')
      .style('fill', '#6b7280') // gray-500
      .text(summaryText);

    // Render scale bar (bottom-left)
    const scaleBar = calculateScaleBarLength(data.geneLength);
    const scaleBarWidth = scaleBar.length * PIXELS_PER_BP;

    const scaleBarGroup = mainGroup
      .append('g')
      .attr('class', 'scale-bar')
      .attr('transform', `translate(0, ${plotHeight + 20})`);

    // Horizontal line
    scaleBarGroup
      .append('line')
      .attr('x1', 0)
      .attr('y1', 0)
      .attr('x2', scaleBarWidth)
      .attr('y2', 0)
      .attr('stroke', '#374151') // gray-700
      .attr('stroke-width', 2);

    // Left cap
    scaleBarGroup
      .append('line')
      .attr('x1', 0)
      .attr('y1', -3)
      .attr('x2', 0)
      .attr('y2', 3)
      .attr('stroke', '#374151')
      .attr('stroke-width', 2);

    // Right cap
    scaleBarGroup
      .append('line')
      .attr('x1', scaleBarWidth)
      .attr('y1', -3)
      .attr('x2', scaleBarWidth)
      .attr('y2', 3)
      .attr('stroke', '#374151')
      .attr('stroke-width', 2);

    // Label
    scaleBarGroup
      .append('text')
      .attr('x', scaleBarWidth / 2)
      .attr('y', 12)
      .attr('text-anchor', 'middle')
      .style('font-size', '9px')
      .style('fill', '#374151')
      .text(scaleBar.label);

    // Create tooltip div (absolute positioned, initially hidden)
    tooltipDiv = d3
      .select(options.container.value)
      .append('div')
      .attr('class', 'gene-structure-tooltip')
      .style('position', 'absolute')
      .style('padding', '8px 12px')
      .style('background', 'rgba(0, 0, 0, 0.85)')
      .style('color', '#fff')
      .style('border-radius', '4px')
      .style('font-size', '12px')
      .style('pointer-events', 'none')
      .style('opacity', 0)
      .style('z-index', '1000')
      .style('max-width', '250px')
      .style('line-height', '1.4');

    isInitialized.value = true;
    console.log(
      `[useD3GeneStructure] Rendered ${data.exonCount} exons, ${data.introns.length} introns for ${data.geneSymbol}`
    );
  };

  /**
   * Clean up all D3 resources
   */
  const cleanup = (): void => {
    // Remove SVG
    if (svg) {
      svg.selectAll('*').remove();
      svg.remove();
      svg = null;
    }

    // Remove tooltip
    if (tooltipDiv) {
      tooltipDiv.remove();
      tooltipDiv = null;
    }

    isInitialized.value = false;
    console.log('[useD3GeneStructure] Cleaned up');
  };

  // CRITICAL: Cleanup to prevent memory leaks
  onBeforeUnmount(() => {
    cleanup();
  });

  return {
    isInitialized: readonly(isInitialized),
    renderGeneStructure,
    cleanup,
  };
}

export default useD3GeneStructure;
