// composables/d3-lollipop/useD3Lollipop.ts

/**
 * Composable for D3.js lollipop plot lifecycle management
 *
 * Manages D3.js SVG initialization, rendering, brush-to-zoom, tooltips,
 * and proper cleanup to prevent memory leaks.
 *
 * CRITICAL: D3 selections are stored in non-reactive properties of a single
 * mutable context object (LollipopContext) to avoid Vue reactivity
 * triggering layout recalculations.
 *
 * CRITICAL: Always removes event listeners and DOM nodes in onBeforeUnmount
 * to prevent memory leaks.
 *
 * Follows the useCytoscape pattern for safe D3/Vue integration.
 */

import { ref, onMounted, onBeforeUnmount, type Ref } from 'vue';
import * as d3 from 'd3';
import type { ProteinPlotData, ProcessedVariant, LollipopFilterState } from '@/types/protein';

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
  /** Export the plot as SVG string */
  exportSVG: () => string | null;
  /** Export the plot as PNG data URL */
  exportPNG: (scale?: number) => Promise<string | null>;
}

import { DEFAULT_WIDTH, DEFAULT_HEIGHT, DEFAULT_MARGIN } from './lollipop-helpers';
import type { LollipopContext } from './lollipop-context';
import { dismissLockedTooltip } from './lollipop-tooltip';
import { renderBackbone, renderDomains, renderVariants, renderAxis } from './lollipop-render';
import { exportSvgFrom, exportPngFrom } from './lollipop-export';

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

  // CRITICAL: Single mutable context object holding the non-reactive D3
  // selections/scales and tooltip state. Extracted module functions
  // read/write ctx.<prop> directly, preserving closure mutation semantics.
  const ctx: LollipopContext = {
    svg: null,
    mainGroup: null,
    xScale: null,
    xScaleOriginal: null,
    brush: null,
    tooltipDiv: null,
    currentData: null,
    currentFilterState: null,
    isTooltipLocked: false,
    lockedVariant: null,
    options,
    width,
    height,
    margin,
    innerWidth,
    innerHeight,
    isInitialized,
    isLoading,
    currentZoomDomain,
  };

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
    ctx.svg = d3
      .select(options.container.value)
      .append('svg')
      .attr('viewBox', `0 0 ${fullWidth} ${fullHeight}`)
      .attr('preserveAspectRatio', 'xMinYMin meet')
      .attr('role', 'img')
      .attr('aria-labelledby', 'lollipop-title lollipop-desc')
      .style('width', '100%')
      .style('height', 'auto');

    // Add accessibility elements
    ctx.svg.append('title').attr('id', 'lollipop-title').text('Protein Domain Lollipop Plot');

    ctx.svg
      .append('desc')
      .attr('id', 'lollipop-desc')
      .text(
        'Interactive visualization showing protein domains and clinical variants plotted along the protein sequence.'
      );

    // Create main group with margin transform
    ctx.mainGroup = ctx.svg
      .append('g')
      .attr('class', 'main-group')
      .attr('transform', `translate(${margin.left}, ${margin.top})`);

    // Create tooltip div (absolute positioned, initially hidden)
    ctx.tooltipDiv = d3
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
   * Setup brush for zoom selection
   * Brush is rendered last (on top) with normal pointer-events
   * Hover on markers works by clicking precisely on them
   */
  const setupBrush = (): void => {
    if (!ctx.mainGroup || !ctx.svg) return;

    ctx.brush = d3
      .brushX()
      .extent([
        [0, 0],
        [innerWidth, innerHeight - 30],
      ])
      .on('end', (event: d3.D3BrushEvent<unknown>) => {
        if (!event.selection || !ctx.xScale || !ctx.xScaleOriginal) return;

        const [x0, x1] = event.selection as [number, number];
        const newDomain: [number, number] = [ctx.xScale.invert(x0), ctx.xScale.invert(x1)];

        // Update zoom domain
        currentZoomDomain.value = newDomain;

        // Clear the brush selection
        ctx.mainGroup?.select('.brush').call(ctx.brush!.move as unknown as never, null);

        // Re-render with new scale
        if (ctx.currentData && ctx.currentFilterState) {
          renderPlotInternal(ctx.currentData, ctx.currentFilterState, newDomain);
        }
      });

    // Add brush to main group
    ctx.mainGroup.append('g').attr('class', 'brush').call(ctx.brush);

    // Add double-click to reset zoom
    ctx.svg.on('dblclick', () => {
      resetZoom();
    });

    // Add click handler to dismiss locked tooltip
    ctx.svg.on('click', (event: MouseEvent) => {
      const target = event.target as Element;
      if (
        ctx.isTooltipLocked &&
        !target.classList.contains('marker') &&
        !target.classList.contains('marker-aggregated') &&
        !target.closest('.lollipop-tooltip')
      ) {
        dismissLockedTooltip(ctx);
      }
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
    if (!ctx.mainGroup) {
      console.warn('[useD3Lollipop] Cannot render - not initialized');
      return;
    }

    isLoading.value = true;

    // Clear existing content
    ctx.mainGroup.selectAll('*').remove();

    // Create/update xScale
    const domain = zoomDomain ?? [0, data.proteinLength];
    ctx.xScale = d3.scaleLinear().domain(domain).range([0, innerWidth]).nice();

    // Store original scale for reset (only if not zoomed)
    if (!zoomDomain) {
      ctx.xScaleOriginal = d3.scaleLinear().domain([0, data.proteinLength]).range([0, innerWidth]);
    }

    // Calculate y positions
    const yBase = innerHeight - 50;

    // Render in order (back to front):
    // 1. Backbone (background)
    // 2. Axis
    // 3. Brush (below variants - can drag on empty areas)
    // 4. Domains (receive hover)
    // 5. Variants (on top - receive hover/click)
    renderBackbone(ctx, data.proteinLength, yBase);
    renderAxis(ctx);
    setupBrush(); // Brush below variants
    renderDomains(ctx, data.domains, yBase, data.proteinLength);
    renderVariants(ctx, data.variants, filterState, yBase, zoomDomain ?? null, data.proteinLength);

    isLoading.value = false;
    console.log(
      `[useD3Lollipop] Rendered ${data.domains.length} domains, ${data.variants.length} variants`
    );
  };

  /**
   * Public render function - stores data for re-render on zoom
   */
  const renderPlot = (data: ProteinPlotData, filterState: LollipopFilterState): void => {
    ctx.currentData = data;
    ctx.currentFilterState = filterState;

    // Preserve zoom domain across filter changes
    renderPlotInternal(data, filterState, currentZoomDomain.value);
  };

  /**
   * Reset zoom to original domain
   */
  const resetZoom = (): void => {
    currentZoomDomain.value = null;

    if (ctx.currentData && ctx.currentFilterState) {
      renderPlotInternal(ctx.currentData, ctx.currentFilterState, null);
    }
  };

  /**
   * Clean up all D3 resources
   */
  const cleanup = (): void => {
    // Remove all D3 content
    if (ctx.svg) {
      ctx.svg.selectAll('*').remove();
      ctx.svg.remove();
      ctx.svg = null;
    }

    // Remove tooltip
    if (ctx.tooltipDiv) {
      ctx.tooltipDiv.remove();
      ctx.tooltipDiv = null;
    }

    // Null all references
    ctx.mainGroup = null;
    ctx.xScale = null;
    ctx.xScaleOriginal = null;
    ctx.brush = null;
    ctx.currentData = null;
    ctx.currentFilterState = null;

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
    exportSVG: () => exportSvgFrom(ctx),
    exportPNG: (scale?: number) => exportPngFrom(ctx, scale),
  };
}

export default useD3Lollipop;
