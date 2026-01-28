// composables/useD3Lollipop.ts

/**
 * Composable for D3.js lollipop plot lifecycle management
 *
 * Manages D3.js SVG initialization, rendering, brush-to-zoom, tooltips,
 * and proper cleanup to prevent memory leaks.
 *
 * CRITICAL: D3 selections are stored in non-reactive variables (let svg)
 * to avoid Vue reactivity triggering layout recalculations.
 *
 * CRITICAL: Always removes event listeners and DOM nodes in onBeforeUnmount
 * to prevent memory leaks.
 *
 * Follows the useCytoscape pattern for safe D3/Vue integration.
 */

import { ref, onMounted, onBeforeUnmount, type Ref } from 'vue';
import * as d3 from 'd3';
import type {
  ProteinPlotData,
  ProcessedVariant,
  LollipopFilterState,
  PathogenicityClass,
} from '@/types/protein';
import { PATHOGENICITY_COLORS } from '@/types/protein';

/**
 * Margin configuration for the SVG plot
 */
export interface PlotMargin {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

/**
 * Options for the useD3Lollipop composable
 */
export interface LollipopOptions {
  /** Ref to the container HTML element */
  container: Ref<HTMLElement | null>;
  /** Inner width excluding margins (default: 800) */
  width?: number;
  /** Inner height excluding margins (default: 250) */
  height?: number;
  /** Margins around the plot area */
  margin?: PlotMargin;
  /** Callback when a variant marker is clicked (for Phase 45 3D viewer linking) */
  onVariantClick?: (variant: ProcessedVariant) => void;
  /** Callback when a variant marker is hovered (for Phase 45 3D viewer linking) */
  onVariantHover?: (variant: ProcessedVariant | null) => void;
}

/**
 * State and controls returned by the composable
 */
export interface D3LollipopState {
  /** Whether the D3 SVG is initialized */
  isInitialized: Ref<boolean>;
  /** Whether the plot is currently rendering */
  isLoading: Ref<boolean>;
  /** Current zoom domain (amino acid range), null if at original scale */
  currentZoomDomain: Ref<[number, number] | null>;
  /** Render/update the plot with new data and filter state */
  renderPlot: (data: ProteinPlotData, filterState: LollipopFilterState) => void;
  /** Reset zoom to original domain */
  resetZoom: () => void;
  /** Clean up D3 resources (called automatically on unmount) */
  cleanup: () => void;
}

// Default options
const DEFAULT_WIDTH = 800;
const DEFAULT_HEIGHT = 250;
const DEFAULT_MARGIN: PlotMargin = { top: 60, right: 30, bottom: 60, left: 50 };

// Visual constants
const BACKBONE_HEIGHT = 20;
const STEM_BASE_HEIGHT = 40;
const STEM_STACK_OFFSET = 14;
const MARKER_RADIUS = 5;
const MARKER_STROKE_WIDTH = 1;

/**
 * Map pathogenicity class to filter state key
 */
function isClassificationVisible(
  classification: PathogenicityClass,
  filterState: LollipopFilterState
): boolean {
  switch (classification) {
    case 'Pathogenic':
      return filterState.pathogenic;
    case 'Likely pathogenic':
      return filterState.likelyPathogenic;
    case 'Uncertain significance':
      return filterState.vus;
    case 'Likely benign':
      return filterState.likelyBenign;
    case 'Benign':
      return filterState.benign;
    default:
      return true; // Show 'other' by default
  }
}

/**
 * Composable for managing D3.js lollipop plot lifecycle
 *
 * @param options - Configuration options including container ref and callbacks
 * @returns State and control functions for the D3 plot
 *
 * @example
 * ```typescript
 * const containerRef = ref<HTMLElement | null>(null);
 *
 * const {
 *   isInitialized,
 *   renderPlot,
 *   resetZoom,
 * } = useD3Lollipop({
 *   container: containerRef,
 *   onVariantClick: (variant) => console.log('Clicked:', variant.proteinHGVS),
 * });
 *
 * // After data is fetched:
 * renderPlot(plotData, filterState);
 * ```
 */
export function useD3Lollipop(options: LollipopOptions): D3LollipopState {
  // CRITICAL: Store D3 selections in non-reactive variables
  // Using ref() would cause Vue reactivity to trigger unnecessary updates
  let svg: d3.Selection<SVGSVGElement, unknown, null, undefined> | null = null;
  let mainGroup: d3.Selection<SVGGElement, unknown, null, undefined> | null = null;
  let xScale: d3.ScaleLinear<number, number> | null = null;
  let xScaleOriginal: d3.ScaleLinear<number, number> | null = null;
  let brush: d3.BrushBehavior<unknown> | null = null;
  let tooltipDiv: d3.Selection<HTMLDivElement, unknown, null, undefined> | null = null;

  // Store current data for re-render on zoom
  let currentData: ProteinPlotData | null = null;
  let currentFilterState: LollipopFilterState | null = null;

  // Resolved options with defaults
  const width = options.width ?? DEFAULT_WIDTH;
  const height = options.height ?? DEFAULT_HEIGHT;
  const margin = options.margin ?? DEFAULT_MARGIN;
  const innerWidth = width;
  const innerHeight = height;

  // Reactive state for UI binding
  const isInitialized = ref(false);
  const isLoading = ref(false);
  const currentZoomDomain = ref<[number, number] | null>(null);

  /**
   * Initialize the D3 SVG and tooltip
   */
  const initializePlot = (): void => {
    if (!options.container.value) {
      console.warn('[useD3Lollipop] Container not available');
      return;
    }

    // Clean up any existing SVG
    d3.select(options.container.value).select('svg').remove();

    // Clean up any existing tooltip
    d3.select(options.container.value).select('.lollipop-tooltip').remove();

    const fullWidth = innerWidth + margin.left + margin.right;
    const fullHeight = innerHeight + margin.top + margin.bottom;

    // Create responsive SVG with viewBox
    svg = d3
      .select(options.container.value)
      .append('svg')
      .attr('viewBox', `0 0 ${fullWidth} ${fullHeight}`)
      .attr('preserveAspectRatio', 'xMinYMin meet')
      .attr('role', 'img')
      .attr('aria-labelledby', 'lollipop-title lollipop-desc')
      .style('width', '100%')
      .style('height', 'auto');

    // Add accessibility elements
    svg.append('title').attr('id', 'lollipop-title').text('Protein Domain Lollipop Plot');

    svg
      .append('desc')
      .attr('id', 'lollipop-desc')
      .text(
        'Interactive visualization showing protein domains and clinical variants plotted along the protein sequence.'
      );

    // Create main group with margin transform
    mainGroup = svg
      .append('g')
      .attr('class', 'main-group')
      .attr('transform', `translate(${margin.left}, ${margin.top})`);

    // Create tooltip div (absolute positioned, initially hidden)
    tooltipDiv = d3
      .select(options.container.value)
      .append('div')
      .attr('class', 'lollipop-tooltip')
      .style('position', 'absolute')
      .style('padding', '8px 12px')
      .style('background', 'rgba(0, 0, 0, 0.85)')
      .style('color', '#fff')
      .style('border-radius', '4px')
      .style('font-size', '12px')
      .style('pointer-events', 'none')
      .style('opacity', 0)
      .style('z-index', 1000)
      .style('max-width', '280px')
      .style('line-height', '1.4');

    isInitialized.value = true;
    console.log('[useD3Lollipop] Initialized');
  };

  /**
   * Show tooltip near the hovered element with edge detection
   */
  const showTooltip = (
    event: MouseEvent,
    variant: ProcessedVariant,
    containerEl: HTMLElement
  ): void => {
    if (!tooltipDiv) return;

    // Build tooltip content
    const colorStyle = `color: ${PATHOGENICITY_COLORS[variant.classification]};`;
    const starsDisplay = '★'.repeat(variant.goldStars) + '☆'.repeat(4 - variant.goldStars);
    const spliceNote = variant.isSpliceVariant
      ? '<div style="font-style: italic; margin-top: 4px; color: #aaa;">Position approximated from splice variant</div>'
      : '';

    const html = `
      <div style="font-weight: bold; margin-bottom: 4px;">${variant.proteinHGVS}</div>
      <div style="color: #ccc;">${variant.codingHGVS}</div>
      <div style="${colorStyle} margin-top: 4px;">${variant.classification}</div>
      <div style="margin-top: 4px;">Review: ${starsDisplay}</div>
      <div style="color: #aaa; font-size: 11px;">${variant.reviewStatus}</div>
      <div style="margin-top: 4px; color: #aaa; font-size: 11px;">
        ${variant.majorConsequence.replace(/_/g, ' ')}
        ${variant.inGnomad ? '| in gnomAD' : ''}
      </div>
      ${spliceNote}
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
   * Render the protein backbone line
   */
  const renderBackbone = (proteinLength: number, yBase: number): void => {
    if (!mainGroup || !xScale) return;

    mainGroup
      .append('rect')
      .attr('class', 'protein-backbone')
      .attr('x', xScale(0))
      .attr('y', yBase - BACKBONE_HEIGHT / 2)
      .attr('width', xScale(proteinLength) - xScale(0))
      .attr('height', BACKBONE_HEIGHT)
      .attr('fill', '#e0e0e0')
      .attr('rx', 4)
      .attr('ry', 4);
  };

  /**
   * Render protein domain rectangles
   */
  const renderDomains = (
    domains: ProteinPlotData['domains'],
    yBase: number,
    proteinLength: number
  ): void => {
    if (!mainGroup || !xScale) return;

    // Color scale for domain types
    const domainTypes = [...new Set(domains.map((d) => d.type))];
    const colorScale = d3.scaleOrdinal(d3.schemeSet2).domain(domainTypes);

    // Domain group
    const domainGroup = mainGroup.append('g').attr('class', 'domains');

    // Use D3 join pattern for enter/update/exit
    domainGroup
      .selectAll<SVGRectElement, (typeof domains)[0]>('rect.domain')
      .data(domains, (d) => `${d.type}-${d.begin}-${d.end}`)
      .join(
        (enter) =>
          enter
            .append('rect')
            .attr('class', 'domain')
            .attr('x', (d) => xScale!(Math.max(0, d.begin)))
            .attr('y', yBase - BACKBONE_HEIGHT / 2 - 2)
            .attr('width', (d) => {
              const start = Math.max(0, d.begin);
              const end = Math.min(proteinLength, d.end);
              return Math.max(0, xScale!(end) - xScale!(start));
            })
            .attr('height', BACKBONE_HEIGHT + 4)
            .attr('fill', (d) => colorScale(d.type))
            .attr('opacity', 0.7)
            .attr('rx', 3)
            .attr('ry', 3)
            .attr('aria-label', (d) => `${d.type}: ${d.description} (${d.begin}-${d.end})`),
        (update) => update,
        (exit) => exit.remove()
      );
  };

  /**
   * Render variant lollipops (stems + markers)
   */
  const renderVariants = (
    variants: ProcessedVariant[],
    filterState: LollipopFilterState,
    yBase: number
  ): void => {
    if (!mainGroup || !xScale) return;

    // Filter by visibility
    const visibleVariants = variants.filter((v) =>
      isClassificationVisible(v.classification, filterState)
    );

    // Group variants by position for stacking
    const positionGroups = d3.group(visibleVariants, (v) => v.proteinPosition);

    // Flatten with stack index
    const stackedVariants: Array<ProcessedVariant & { stackIndex: number }> = [];
    positionGroups.forEach((group) => {
      group.forEach((variant, index) => {
        stackedVariants.push({ ...variant, stackIndex: index });
      });
    });

    // Variant group
    const variantGroup = mainGroup.append('g').attr('class', 'variants');

    // Render stems (vertical lines)
    variantGroup
      .selectAll<SVGLineElement, (typeof stackedVariants)[0]>('line.stem')
      .data(stackedVariants, (d) => d.variantId)
      .join(
        (enter) =>
          enter
            .append('line')
            .attr('class', 'stem')
            .attr('x1', (d) => xScale!(d.proteinPosition))
            .attr('x2', (d) => xScale!(d.proteinPosition))
            .attr('y1', yBase - BACKBONE_HEIGHT / 2 - 2)
            .attr('y2', (d) => yBase - STEM_BASE_HEIGHT - d.stackIndex * STEM_STACK_OFFSET - 15)
            .attr('stroke', '#999')
            .attr('stroke-width', 1),
        (update) => update,
        (exit) => exit.remove()
      );

    // Get container element for tooltip positioning
    const containerEl = options.container.value;

    // Render markers (circles for coding, triangles for splice)
    // Using attr callbacks to avoid 'this' typing issues
    variantGroup
      .selectAll<SVGPathElement, (typeof stackedVariants)[0]>('path.marker')
      .data(stackedVariants, (d) => d.variantId)
      .join(
        (enter) => {
          const markers = enter
            .append('path')
            .attr('class', 'marker')
            .attr('d', (d) => {
              const symbolType = d.isSpliceVariant ? d3.symbolDiamond : d3.symbolCircle;
              const symbolGenerator = d3
                .symbol()
                .type(symbolType)
                .size(
                  d.isSpliceVariant
                    ? MARKER_RADIUS * MARKER_RADIUS * 2.5
                    : MARKER_RADIUS * MARKER_RADIUS * Math.PI
                );
              return symbolGenerator() ?? '';
            })
            .attr('transform', (d) => {
              const markerY = yBase - STEM_BASE_HEIGHT - d.stackIndex * STEM_STACK_OFFSET - 15;
              const markerX = xScale!(d.proteinPosition);
              return `translate(${markerX}, ${markerY})`;
            })
            .attr('fill', (d) => PATHOGENICITY_COLORS[d.classification])
            .attr('stroke', '#fff')
            .attr('stroke-width', MARKER_STROKE_WIDTH)
            .attr('cursor', 'pointer')
            .attr(
              'aria-label',
              (d) =>
                `${d.proteinHGVS}: ${d.classification}${d.isSpliceVariant ? ' (splice variant)' : ''}`
            );

          // Add event handlers
          markers
            .on('mouseover', (event: MouseEvent, d) => {
              if (containerEl) {
                showTooltip(event, d, containerEl);
                options.onVariantHover?.(d);
              }
            })
            .on('mouseout', () => {
              hideTooltip();
              options.onVariantHover?.(null);
            })
            .on('click', (_event: MouseEvent, d) => {
              options.onVariantClick?.(d);
            });

          return markers;
        },
        (update) => update,
        (exit) => exit.remove()
      );
  };

  /**
   * Render X axis (amino acid positions)
   */
  const renderAxis = (): void => {
    if (!mainGroup || !xScale) return;

    const xAxis = d3.axisBottom(xScale).ticks(10).tickSizeOuter(0);

    mainGroup
      .append('g')
      .attr('class', 'x-axis')
      .attr('transform', `translate(0, ${innerHeight - 20})`)
      .call(xAxis)
      .append('text')
      .attr('x', innerWidth / 2)
      .attr('y', 40)
      .attr('fill', '#333')
      .attr('text-anchor', 'middle')
      .text('Amino Acid Position');
  };

  /**
   * Setup brush for zoom selection
   */
  const setupBrush = (): void => {
    if (!mainGroup || !svg) return;

    brush = d3
      .brushX()
      .extent([
        [0, 0],
        [innerWidth, innerHeight - 30],
      ])
      .on('end', (event: d3.D3BrushEvent<unknown>) => {
        if (!event.selection || !xScale || !xScaleOriginal) return;

        const [x0, x1] = event.selection as [number, number];
        const newDomain: [number, number] = [xScale.invert(x0), xScale.invert(x1)];

        // Update zoom domain
        currentZoomDomain.value = newDomain;

        // Clear the brush selection
        mainGroup?.select('.brush').call(brush!.move as unknown as never, null);

        // Re-render with new scale
        if (currentData && currentFilterState) {
          renderPlotInternal(currentData, currentFilterState, newDomain);
        }
      });

    // Add brush to main group
    mainGroup.append('g').attr('class', 'brush').call(brush);

    // Add double-click to reset zoom
    svg.on('dblclick', () => {
      resetZoom();
    });
  };

  /**
   * Internal render function with optional zoom domain
   */
  const renderPlotInternal = (
    data: ProteinPlotData,
    filterState: LollipopFilterState,
    zoomDomain?: [number, number] | null
  ): void => {
    if (!mainGroup) {
      console.warn('[useD3Lollipop] Cannot render - not initialized');
      return;
    }

    isLoading.value = true;

    // Clear existing content
    mainGroup.selectAll('*').remove();

    // Create/update xScale
    const domain = zoomDomain ?? [0, data.proteinLength];
    xScale = d3.scaleLinear().domain(domain).range([0, innerWidth]).nice();

    // Store original scale for reset (only if not zoomed)
    if (!zoomDomain) {
      xScaleOriginal = d3.scaleLinear().domain([0, data.proteinLength]).range([0, innerWidth]);
    }

    // Calculate y positions
    const yBase = innerHeight - 50;

    // Render in order (back to front)
    renderBackbone(data.proteinLength, yBase);
    renderDomains(data.domains, yBase, data.proteinLength);
    renderAxis();
    renderVariants(data.variants, filterState, yBase);
    setupBrush();

    isLoading.value = false;
    console.log(
      `[useD3Lollipop] Rendered ${data.domains.length} domains, ${data.variants.length} variants`
    );
  };

  /**
   * Public render function - stores data for re-render on zoom
   */
  const renderPlot = (data: ProteinPlotData, filterState: LollipopFilterState): void => {
    currentData = data;
    currentFilterState = filterState;

    // Preserve zoom domain across filter changes
    renderPlotInternal(data, filterState, currentZoomDomain.value);
  };

  /**
   * Reset zoom to original domain
   */
  const resetZoom = (): void => {
    currentZoomDomain.value = null;

    if (currentData && currentFilterState) {
      renderPlotInternal(currentData, currentFilterState, null);
    }
  };

  /**
   * Clean up all D3 resources
   */
  const cleanup = (): void => {
    // Remove all D3 content
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

    // Null all references
    mainGroup = null;
    xScale = null;
    xScaleOriginal = null;
    brush = null;
    currentData = null;
    currentFilterState = null;

    isInitialized.value = false;
    console.log('[useD3Lollipop] Cleaned up');
  };

  // Lifecycle hooks
  onMounted(() => {
    initializePlot();
  });

  // CRITICAL: Cleanup to prevent memory leaks
  onBeforeUnmount(() => {
    cleanup();
  });

  return {
    isInitialized,
    isLoading,
    currentZoomDomain,
    renderPlot,
    resetZoom,
    cleanup,
  };
}

export default useD3Lollipop;
