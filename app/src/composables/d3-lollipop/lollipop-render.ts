/**
 * d3-lollipop/lollipop-render.ts
 *
 * Rendering functions (backbone, domains, variants, axis) for the D3
 * lollipop plot. Each function takes the shared LollipopContext and
 * reads/writes `ctx.<prop>` directly to preserve closure semantics.
 */

import * as d3 from 'd3';
import type {
  ProteinPlotData,
  ProcessedVariant,
  LollipopFilterState,
  PathogenicityClass,
  AggregatedVariant,
} from '@/types/protein';
import {
  PATHOGENICITY_COLORS,
  EFFECT_TYPE_COLORS,
  normalizeEffectType,
  aggregateVariantsByPosition,
} from '@/types/protein';
import {
  BACKBONE_HEIGHT,
  STEM_BASE_HEIGHT,
  STEM_STACK_OFFSET,
  MARKER_RADIUS,
  MARKER_STROKE_WIDTH,
  MAX_STACK_DEPTH,
  isClassificationVisible,
  isEffectTypeVisible,
  calculateDynamicOpacity,
  calculateAggregatedRadius,
  determineRenderingMode,
} from './lollipop-helpers';
import {
  showTooltip,
  hideTooltip,
  dismissLockedTooltip,
  showDomainTooltip,
  showAggregatedTooltip,
} from './lollipop-tooltip';
import type { LollipopContext } from './lollipop-context';

/**
 * Render the protein backbone line
 */
export function renderBackbone(ctx: LollipopContext, proteinLength: number, yBase: number): void {
  if (!ctx.mainGroup || !ctx.xScale) return;

  ctx.mainGroup
    .append('rect')
    .attr('class', 'protein-backbone')
    .attr('x', ctx.xScale(0))
    .attr('y', yBase - BACKBONE_HEIGHT / 2)
    .attr('width', ctx.xScale(proteinLength) - ctx.xScale(0))
    .attr('height', BACKBONE_HEIGHT)
    .attr('fill', '#e0e0e0')
    .attr('rx', 4)
    .attr('ry', 4);
}

/**
 * Render protein domain rectangles
 */
export function renderDomains(
  ctx: LollipopContext,
  domains: ProteinPlotData['domains'],
  yBase: number,
  proteinLength: number
): void {
  if (!ctx.mainGroup || !ctx.xScale) return;

  // Color scale for domain types
  const domainTypes = [...new Set(domains.map((d) => d.type))];
  const colorScale = d3.scaleOrdinal(d3.schemeSet2).domain(domainTypes);

  // Domain group
  const domainGroup = ctx.mainGroup.append('g').attr('class', 'domains');

  // Get container element for tooltip positioning
  const containerEl = ctx.options.container.value;

  // Use D3 join pattern for enter/update/exit
  domainGroup
    .selectAll<SVGRectElement, (typeof domains)[0]>('rect.domain')
    .data(domains, (d) => `${d.type}-${d.begin}-${d.end}`)
    .join(
      (enter) => {
        const rects = enter
          .append('rect')
          .attr('class', 'domain')
          .attr('x', (d) => ctx.xScale!(Math.max(0, d.begin)))
          .attr('y', yBase - BACKBONE_HEIGHT / 2 - 2)
          .attr('width', (d) => {
            const start = Math.max(0, d.begin);
            const end = Math.min(proteinLength, d.end);
            return Math.max(0, ctx.xScale!(end) - ctx.xScale!(start));
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
              showDomainTooltip(ctx, event, d, containerEl);
            }
          })
          .on('mouseout', () => {
            hideTooltip(ctx);
          });

        return rects;
      },
      (update) => update,
      (exit) => exit.remove()
    );
}

/**
 * Render variant lollipops (stems + markers)
 * Uses adaptive rendering: aggregated mode for many variants, individual for fewer
 */
export function renderVariants(
  ctx: LollipopContext,
  variants: ProcessedVariant[],
  filterState: LollipopFilterState,
  yBase: number,
  zoomDomain: [number, number] | null,
  totalLength: number
): void {
  if (!ctx.mainGroup || !ctx.xScale) return;

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
  const variantGroup = ctx.mainGroup.append('g').attr('class', 'variants');

  // Get container element for tooltip positioning
  const containerEl = ctx.options.container.value;

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
            .attr('x1', (d) => ctx.xScale!(d.proteinPosition))
            .attr('x2', (d) => ctx.xScale!(d.proteinPosition))
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
            .attr('cx', (d) => ctx.xScale!(d.proteinPosition))
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
            .attr('aria-label', (d) => `Position ${d.proteinPosition}: ${d.count} variants`);

          // Event handlers for aggregated markers
          markers
            .on('mouseover', (event: MouseEvent, d) => {
              if (containerEl && !ctx.isTooltipLocked) {
                showAggregatedTooltip(ctx, event, d, containerEl, filterState);
              }
            })
            .on('mouseout', () => {
              if (!ctx.isTooltipLocked) {
                hideTooltip(ctx);
              }
            })
            .on('click', (event: MouseEvent, d) => {
              event.stopPropagation();
              // For aggregated: show breakdown, suggest zoom
              if (containerEl) {
                showAggregatedTooltip(ctx, event, d, containerEl, filterState);
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
            .attr('x1', (d) => ctx.xScale!(d.proteinPosition))
            .attr('x2', (d) => ctx.xScale!(d.proteinPosition))
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
              const markerX = ctx.xScale!(d.proteinPosition);
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
              if (containerEl && !ctx.isTooltipLocked) {
                showTooltip(ctx, event, d, containerEl, false);
                ctx.options.onVariantHover?.(d);
              }
            })
            .on('mouseout', () => {
              if (!ctx.isTooltipLocked) {
                hideTooltip(ctx);
                ctx.options.onVariantHover?.(null);
              }
            })
            .on('click', (event: MouseEvent, d) => {
              event.stopPropagation();
              if (containerEl) {
                if (ctx.isTooltipLocked && ctx.lockedVariant?.variantId === d.variantId) {
                  dismissLockedTooltip(ctx);
                } else {
                  ctx.isTooltipLocked = true;
                  ctx.lockedVariant = d;
                  showTooltip(ctx, event, d, containerEl, true);
                }
              }
              ctx.options.onVariantClick?.(d);
            });

          return markers;
        },
        (update) => update,
        (exit) => exit.remove()
      );
  }
}

/**
 * Render X axis (amino acid positions)
 */
export function renderAxis(ctx: LollipopContext): void {
  if (!ctx.mainGroup || !ctx.xScale) return;

  const xAxis = d3.axisBottom(ctx.xScale).ticks(10).tickSizeOuter(0);

  ctx.mainGroup
    .append('g')
    .attr('class', 'x-axis')
    .attr('transform', `translate(0, ${ctx.innerHeight - 20})`)
    .call(xAxis)
    .append('text')
    .attr('x', ctx.innerWidth / 2)
    .attr('y', 40)
    .attr('fill', '#333')
    .attr('text-anchor', 'middle')
    .text('Amino Acid Position');
}
