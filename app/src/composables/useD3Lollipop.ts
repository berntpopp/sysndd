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
  EffectType,
  AggregatedVariant,
} from '@/types/protein';
import {
  PATHOGENICITY_COLORS,
  EFFECT_TYPE_COLORS,
  normalizeEffectType,
  aggregateVariantsByPosition,
} from '@/types/protein';

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

// Default options
const DEFAULT_WIDTH = 800;
const DEFAULT_HEIGHT = 250;
const DEFAULT_MARGIN: PlotMargin = { top: 60, right: 30, bottom: 60, left: 50 };

// Visual constants
const BACKBONE_HEIGHT = 14;
const STEM_BASE_HEIGHT = 18;
const STEM_STACK_OFFSET = 8;
const MARKER_RADIUS = 5;
const MARKER_STROKE_WIDTH = 1;

// Adaptive rendering thresholds
const AGGREGATION_THRESHOLD = 500; // Switch to aggregated mode above this count
const MAX_STACK_DEPTH = 8; // Maximum stacking in individual mode
const MIN_OPACITY = 0.25; // Minimum opacity for markers
const MAX_OPACITY = 0.95; // Maximum opacity for markers
const DENSITY_THRESHOLD = 200; // Reference count for density calculation
const MIN_MARKER_RADIUS = 3; // Minimum marker size in aggregated mode
const MAX_MARKER_RADIUS = 12; // Maximum marker size for high-count positions

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
 * Check if effect type is visible based on filter state
 */
function isEffectTypeVisible(
  majorConsequence: string,
  filterState: LollipopFilterState
): boolean {
  // Safety check: if effectFilters is not defined, show all effect types
  if (!filterState.effectFilters) return true;

  const effectType: EffectType = normalizeEffectType(majorConsequence);
  return filterState.effectFilters[effectType];
}

/**
 * Calculate dynamic opacity based on zoom level and variant density
 *
 * @param visibleCount - Number of variants currently visible
 * @param zoomRatio - Ratio of visible range to total range (1.0 = full view)
 * @returns Opacity value between MIN_OPACITY and MAX_OPACITY
 */
function calculateDynamicOpacity(visibleCount: number, zoomRatio: number): number {
  // Base opacity from density (fewer variants = higher opacity)
  const densityFactor = Math.min(1, DENSITY_THRESHOLD / Math.max(visibleCount, 1));

  // Zoom factor (more zoomed in = higher opacity)
  const zoomFactor = 1 - zoomRatio * 0.6;

  // Combined opacity with bounds
  const opacity = 0.5 * densityFactor + 0.5 * zoomFactor;
  return Math.max(MIN_OPACITY, Math.min(MAX_OPACITY, opacity));
}

/**
 * Calculate marker radius for aggregated variant based on count
 *
 * @param count - Number of variants at this position
 * @param maxCount - Maximum count at any position
 * @returns Marker radius scaled by count
 */
function calculateAggregatedRadius(count: number, maxCount: number): number {
  // Use square root scaling so area is proportional to count
  const scale = Math.sqrt(count / Math.max(maxCount, 1));
  return MIN_MARKER_RADIUS + scale * (MAX_MARKER_RADIUS - MIN_MARKER_RADIUS);
}

/**
 * Determine rendering mode based on visible variant count
 *
 * @param visibleCount - Number of variants to render
 * @returns 'aggregated' if above threshold, 'individual' otherwise
 */
function determineRenderingMode(visibleCount: number): 'aggregated' | 'individual' {
  return visibleCount > AGGREGATION_THRESHOLD ? 'aggregated' : 'individual';
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

  // Tooltip lock state for click-to-pin functionality
  let isTooltipLocked = false;
  let lockedVariant: ProcessedVariant | null = null;

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
   * @param locked - If true, tooltip is pinned and includes clickable ClinVar link
   */
  const showTooltip = (
    event: MouseEvent,
    variant: ProcessedVariant,
    containerEl: HTMLElement,
    locked = false
  ): void => {
    if (!tooltipDiv) return;

    // Build tooltip content
    const colorStyle = `color: ${PATHOGENICITY_COLORS[variant.classification]};`;
    const starsDisplay = '★'.repeat(variant.goldStars) + '☆'.repeat(4 - variant.goldStars);
    const spliceNote = variant.isSpliceVariant
      ? '<div style="font-style: italic; margin-top: 4px; color: #aaa;">Position approximated from splice variant</div>'
      : '';

    // ClinVar link (only shown when locked)
    const clinvarLink = locked && variant.clinvarId
      ? `<div style="margin-top: 8px; padding-top: 8px; border-top: 1px solid #444;">
           <a href="https://www.ncbi.nlm.nih.gov/clinvar/variation/${variant.clinvarId}/"
              target="_blank"
              rel="noopener noreferrer"
              style="color: #6ea8fe; text-decoration: none;">
             View in ClinVar →
           </a>
         </div>`
      : '';

    // Dismiss hint when locked
    const dismissHint = locked
      ? '<div style="margin-top: 6px; font-size: 10px; color: #888;">Click elsewhere to dismiss</div>'
      : '<div style="margin-top: 6px; font-size: 10px; color: #888;">Click to pin</div>';

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
      ${clinvarLink}
      ${dismissHint}
    `;

    tooltipDiv
      .html(html)
      .style('opacity', 1)
      .style('pointer-events', locked ? 'auto' : 'none');

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
   * Hide tooltip (only if not locked)
   */
  const hideTooltip = (): void => {
    if (!tooltipDiv || isTooltipLocked) return;
    tooltipDiv.style('opacity', 0).style('pointer-events', 'none');
  };

  /**
   * Dismiss locked tooltip
   */
  const dismissLockedTooltip = (): void => {
    isTooltipLocked = false;
    lockedVariant = null;
    if (tooltipDiv) {
      tooltipDiv.style('opacity', 0).style('pointer-events', 'none');
    }
  };

  /**
   * Show tooltip for domain hover
   */
  const showDomainTooltip = (
    event: MouseEvent,
    domain: ProteinPlotData['domains'][0],
    containerEl: HTMLElement
  ): void => {
    if (!tooltipDiv) return;

    const html = `
      <div style="font-weight: bold; margin-bottom: 4px;">${domain.type}</div>
      <div style="color: #ccc;">${domain.description}</div>
      <div style="margin-top: 4px; color: #aaa; font-size: 11px;">
        Position: ${domain.begin} - ${domain.end}
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

    // Get container element for tooltip positioning
    const containerEl = options.container.value;

    // Use D3 join pattern for enter/update/exit
    domainGroup
      .selectAll<SVGRectElement, (typeof domains)[0]>('rect.domain')
      .data(domains, (d) => `${d.type}-${d.begin}-${d.end}`)
      .join(
        (enter) => {
          const rects = enter
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
            .attr('cursor', 'pointer')
            .style('pointer-events', 'all')
            .attr('aria-label', (d) => `${d.type}: ${d.description} (${d.begin}-${d.end})`);

          // Add event handlers for domain tooltips
          rects
            .on('mouseover', (event: MouseEvent, d) => {
              if (containerEl) {
                showDomainTooltip(event, d, containerEl);
              }
            })
            .on('mouseout', () => {
              hideTooltip();
            });

          return rects;
        },
        (update) => update,
        (exit) => exit.remove()
      );
  };

  /**
   * Show tooltip for aggregated variant
   */
  const showAggregatedTooltip = (
    event: MouseEvent,
    aggregated: AggregatedVariant,
    containerEl: HTMLElement,
    filterState: LollipopFilterState
  ): void => {
    if (!tooltipDiv) return;

    // Build breakdown by classification or effect
    let breakdownHtml = '';
    if (filterState.coloringMode === 'effect') {
      const effectEntries = Object.entries(aggregated.countByEffect)
        .filter(([, count]) => count > 0)
        .sort((a, b) => b[1] - a[1]);
      breakdownHtml = effectEntries
        .map(
          ([effect, count]) =>
            `<div style="color: ${EFFECT_TYPE_COLORS[effect as EffectType]};">${effect.replace(/_/g, ' ')}: ${count}</div>`
        )
        .join('');
    } else {
      const classEntries = Object.entries(aggregated.countByClass)
        .filter(([, count]) => count > 0)
        .sort((a, b) => b[1] - a[1]);
      breakdownHtml = classEntries
        .map(
          ([cls, count]) =>
            `<div style="color: ${PATHOGENICITY_COLORS[cls as PathogenicityClass]};">${cls}: ${count}</div>`
        )
        .join('');
    }

    const html = `
      <div style="font-weight: bold; margin-bottom: 4px;">Position ${aggregated.proteinPosition}</div>
      <div style="margin-bottom: 8px;">${aggregated.count} variant${aggregated.count > 1 ? 's' : ''}</div>
      ${breakdownHtml}
      <div style="margin-top: 8px; font-size: 10px; color: #888;">Zoom in to see individual variants</div>
    `;

    tooltipDiv.html(html).style('opacity', 1);

    // Position tooltip
    const tooltipNode = tooltipDiv.node();
    if (!tooltipNode) return;

    const tooltipRect = tooltipNode.getBoundingClientRect();
    const containerRect = containerEl.getBoundingClientRect();

    let left = event.clientX - containerRect.left + 15;
    let top = event.clientY - containerRect.top - 10;

    if (left + tooltipRect.width > containerRect.width) {
      left = event.clientX - containerRect.left - tooltipRect.width - 15;
    }
    if (top + tooltipRect.height > containerRect.height) {
      top = event.clientY - containerRect.top - tooltipRect.height - 10;
    }

    left = Math.max(0, left);
    top = Math.max(0, top);

    tooltipDiv.style('left', `${left}px`).style('top', `${top}px`);
  };

  /**
   * Render variant lollipops (stems + markers)
   * Uses adaptive rendering: aggregated mode for many variants, individual for fewer
   */
  const renderVariants = (
    variants: ProcessedVariant[],
    filterState: LollipopFilterState,
    yBase: number,
    zoomDomain: [number, number] | null,
    totalLength: number
  ): void => {
    if (!mainGroup || !xScale) return;

    // Calculate zoom domain
    const domain = zoomDomain ?? [0, totalLength];
    const visibleRange = domain[1] - domain[0];
    const zoomRatio = visibleRange / totalLength;

    // Filter by pathogenicity AND effect type AND visible domain
    const visibleVariants = variants.filter(
      (v) =>
        isClassificationVisible(v.classification, filterState) &&
        isEffectTypeVisible(v.majorConsequence, filterState) &&
        v.proteinPosition >= domain[0] &&
        v.proteinPosition <= domain[1]
    );

    // Calculate dynamic opacity based on visible (in-domain) variants
    const dynamicOpacity = calculateDynamicOpacity(visibleVariants.length, zoomRatio);

    // Determine rendering mode based on variants IN THE VISIBLE DOMAIN
    const renderingMode = determineRenderingMode(visibleVariants.length);

    // Variant group
    const variantGroup = mainGroup.append('g').attr('class', 'variants');

    // Get container element for tooltip positioning
    const containerEl = options.container.value;

    if (renderingMode === 'aggregated') {
      // AGGREGATED MODE: Group by position, show count-scaled markers
      const aggregatedVariants = aggregateVariantsByPosition(visibleVariants);
      const maxCount = Math.max(...aggregatedVariants.map((a) => a.count), 1);

      // Render single stem per position (to highest point)
      variantGroup
        .selectAll<SVGLineElement, AggregatedVariant>('line.stem')
        .data(aggregatedVariants, (d) => String(d.proteinPosition))
        .join(
          (enter) =>
            enter
              .append('line')
              .attr('class', 'stem')
              .attr('x1', (d) => xScale!(d.proteinPosition))
              .attr('x2', (d) => xScale!(d.proteinPosition))
              .attr('y1', yBase - BACKBONE_HEIGHT / 2 - 2)
              .attr('y2', yBase - STEM_BASE_HEIGHT - 15)
              .attr('stroke', '#999')
              .attr('stroke-width', 1)
              .attr('opacity', dynamicOpacity),
          (update) => update,
          (exit) => exit.remove()
        );

      // Render aggregated markers (size by count)
      variantGroup
        .selectAll<SVGCircleElement, AggregatedVariant>('circle.marker-aggregated')
        .data(aggregatedVariants, (d) => String(d.proteinPosition))
        .join(
          (enter) => {
            const markers = enter
              .append('circle')
              .attr('class', 'marker-aggregated')
              .attr('cx', (d) => xScale!(d.proteinPosition))
              .attr('cy', yBase - STEM_BASE_HEIGHT - 15)
              .attr('r', (d) => calculateAggregatedRadius(d.count, maxCount))
              .attr('fill', (d) => {
                if (filterState.coloringMode === 'effect') {
                  return EFFECT_TYPE_COLORS[d.dominantEffect];
                }
                return PATHOGENICITY_COLORS[d.dominantClass];
              })
              .attr('stroke', '#fff')
              .attr('stroke-width', MARKER_STROKE_WIDTH)
              .attr('opacity', dynamicOpacity)
              .attr('cursor', 'pointer')
              .style('pointer-events', 'all')
              .attr(
                'aria-label',
                (d) => `Position ${d.proteinPosition}: ${d.count} variants`
              );

            // Event handlers for aggregated markers
            markers
              .on('mouseover', (event: MouseEvent, d) => {
                if (containerEl && !isTooltipLocked) {
                  showAggregatedTooltip(event, d, containerEl, filterState);
                }
              })
              .on('mouseout', () => {
                if (!isTooltipLocked) {
                  hideTooltip();
                }
              })
              .on('click', (event: MouseEvent, d) => {
                event.stopPropagation();
                // For aggregated: show breakdown, suggest zoom
                if (containerEl) {
                  showAggregatedTooltip(event, d, containerEl, filterState);
                }
              });

            return markers;
          },
          (update) => update,
          (exit) => exit.remove()
        );
    } else {
      // INDIVIDUAL MODE: Show each variant with limited stacking
      const positionGroups = d3.group(visibleVariants, (v) => v.proteinPosition);

      // Sort within each position: P/LP first (on top visually = rendered last)
      const severityOrder: Record<PathogenicityClass, number> = {
        Benign: 0,
        'Likely benign': 1,
        'Uncertain significance': 2,
        'Likely pathogenic': 3,
        Pathogenic: 4,
        other: -1,
      };

      // Flatten with stack index, limiting depth
      const stackedVariants: Array<ProcessedVariant & { stackIndex: number }> = [];
      positionGroups.forEach((group) => {
        // Sort by severity (less severe first, so more severe renders on top)
        const sorted = [...group].sort(
          (a, b) => severityOrder[a.classification] - severityOrder[b.classification]
        );
        sorted.forEach((variant, index) => {
          // Limit stack depth to avoid towers
          const stackIndex = Math.min(index, MAX_STACK_DEPTH - 1);
          stackedVariants.push({ ...variant, stackIndex });
        });
      });

      // Render stems
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
              .attr('stroke-width', 1)
              .attr('opacity', dynamicOpacity * 0.7),
          (update) => update,
          (exit) => exit.remove()
        );

      // Render markers
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
              .attr('fill', (d) => {
                if (filterState.coloringMode === 'effect') {
                  return EFFECT_TYPE_COLORS[normalizeEffectType(d.majorConsequence)];
                }
                return PATHOGENICITY_COLORS[d.classification];
              })
              .attr('stroke', '#fff')
              .attr('stroke-width', MARKER_STROKE_WIDTH)
              .attr('opacity', dynamicOpacity)
              .attr('cursor', 'pointer')
              .style('pointer-events', 'all')
              .attr(
                'aria-label',
                (d) =>
                  `${d.proteinHGVS}: ${d.classification}${d.isSpliceVariant ? ' (splice variant)' : ''}`
              );

            // Event handlers
            markers
              .on('mouseover', (event: MouseEvent, d) => {
                if (containerEl && !isTooltipLocked) {
                  showTooltip(event, d, containerEl, false);
                  options.onVariantHover?.(d);
                }
              })
              .on('mouseout', () => {
                if (!isTooltipLocked) {
                  hideTooltip();
                  options.onVariantHover?.(null);
                }
              })
              .on('click', (event: MouseEvent, d) => {
                event.stopPropagation();
                if (containerEl) {
                  if (isTooltipLocked && lockedVariant?.variantId === d.variantId) {
                    dismissLockedTooltip();
                  } else {
                    isTooltipLocked = true;
                    lockedVariant = d;
                    showTooltip(event, d, containerEl, true);
                  }
                }
                options.onVariantClick?.(d);
              });

            return markers;
          },
          (update) => update,
          (exit) => exit.remove()
        );
    }
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
   * Brush is rendered last (on top) with normal pointer-events
   * Hover on markers works by clicking precisely on them
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

    // Add click handler to dismiss locked tooltip
    svg.on('click', (event: MouseEvent) => {
      const target = event.target as Element;
      if (
        isTooltipLocked &&
        !target.classList.contains('marker') &&
        !target.classList.contains('marker-aggregated') &&
        !target.closest('.lollipop-tooltip')
      ) {
        dismissLockedTooltip();
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

    // Render in order (back to front):
    // 1. Backbone (background)
    // 2. Axis
    // 3. Brush (below variants - can drag on empty areas)
    // 4. Domains (receive hover)
    // 5. Variants (on top - receive hover/click)
    renderBackbone(data.proteinLength, yBase);
    renderAxis();
    setupBrush(); // Brush below variants
    renderDomains(data.domains, yBase, data.proteinLength);
    renderVariants(data.variants, filterState, yBase, zoomDomain, data.proteinLength);

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

  /**
   * Export the plot as SVG string
   */
  const exportSVG = (): string | null => {
    if (!svg) return null;

    const svgNode = svg.node();
    if (!svgNode) return null;

    // Clone the SVG to avoid modifying the original
    const clonedSvg = svgNode.cloneNode(true) as SVGSVGElement;

    // Add XML namespace for standalone SVG
    clonedSvg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    clonedSvg.setAttribute('xmlns:xlink', 'http://www.w3.org/1999/xlink');

    // Serialize to string
    const serializer = new XMLSerializer();
    return serializer.serializeToString(clonedSvg);
  };

  /**
   * Export the plot as PNG data URL
   * @param scale - Scale factor for higher resolution (default: 2 for retina)
   */
  const exportPNG = async (scale = 2): Promise<string | null> => {
    if (!svg) return null;

    const svgNode = svg.node();
    if (!svgNode) return null;

    // Get dimensions from viewBox or attributes
    const fullWidth = innerWidth + margin.left + margin.right;
    const fullHeight = innerHeight + margin.top + margin.bottom;

    // Clone the SVG
    const clonedSvg = svgNode.cloneNode(true) as SVGSVGElement;

    // Set explicit width/height for canvas rendering
    clonedSvg.setAttribute('width', String(fullWidth));
    clonedSvg.setAttribute('height', String(fullHeight));
    clonedSvg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    clonedSvg.setAttribute('xmlns:xlink', 'http://www.w3.org/1999/xlink');

    // Serialize to string
    const serializer = new XMLSerializer();
    const svgString = serializer.serializeToString(clonedSvg);

    // Encode as base64 data URL (more reliable than blob URL)
    const base64 = btoa(unescape(encodeURIComponent(svgString)));
    const dataUrl = `data:image/svg+xml;base64,${base64}`;

    return new Promise((resolve) => {
      const img = new Image();

      img.onload = () => {
        // Create canvas with scaled dimensions
        const canvas = document.createElement('canvas');
        canvas.width = fullWidth * scale;
        canvas.height = fullHeight * scale;

        const ctx = canvas.getContext('2d');
        if (!ctx) {
          resolve(null);
          return;
        }

        // Fill white background
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Scale and draw
        ctx.scale(scale, scale);
        ctx.drawImage(img, 0, 0, fullWidth, fullHeight);

        resolve(canvas.toDataURL('image/png'));
      };

      img.onerror = (err) => {
        console.error('[useD3Lollipop] PNG export failed:', err);
        resolve(null);
      };

      img.src = dataUrl;
    });
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
    exportSVG,
    exportPNG,
  };
}

export default useD3Lollipop;
