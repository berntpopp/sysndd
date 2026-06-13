/**
 * gene-structure-plot/gene-structure-render.ts
 *
 * D3 render + brush-zoom setup for the gene-structure plot. Each function
 * takes the shared GeneStructureContext and reads/writes `ctx.<prop>` directly
 * to preserve the original closure semantics.
 */

import * as d3 from 'd3';
import type { ClassifiedExon } from '@/types/ensembl';
import { formatGenomicCoordinate } from '@/types/ensembl';
import type { GenomicVariant } from '../GenomicVisualizationTabs.vue';
import {
  aggregateVariantsByGenomicPosition,
  calculateAggregatedRadius,
  calculateDynamicOpacity,
  determineRenderingMode,
} from '../geneStructureVariantPlotUtils';
import type { GeneStructureContext } from './gene-structure-context';
import {
  forceHideTooltip,
  hideTooltip,
  showAggregatedTooltip,
  showExonTooltip,
  showVariantTooltip,
  type TooltipTriggerEvent,
} from './gene-structure-tooltip';

function getVariantMarkerLabel(variant: GenomicVariant): string {
  return `${variant.proteinHGVS}, ${variant.classification} variant`;
}

function activateVariantMarker(
  ctx: GeneStructureContext,
  event: TooltipTriggerEvent,
  variant: GenomicVariant
): void {
  showVariantTooltip(ctx, event, variant, true);
  ctx.inputs.onVariantClick(variant);
}

/**
 * Setup brush for zoom selection.
 * Brush is added BEFORE variant markers so markers receive click events (higher z-order).
 */
function setupBrush(
  ctx: GeneStructureContext,
  innerWidth: number,
  innerHeight: number,
  render: () => void
): void {
  if (!ctx.mainGroup) return;

  ctx.brush = d3
    .brushX()
    .extent([
      [0, 0],
      [innerWidth, innerHeight],
    ])
    .on('end', (event: d3.D3BrushEvent<unknown>) => {
      if (!event.selection || !ctx.xScale) return;

      const [x0, x1] = event.selection as [number, number];
      const newDomain: [number, number] = [ctx.xScale.invert(x0), ctx.xScale.invert(x1)];

      // Only zoom if selection is meaningful (at least 1kb)
      if (newDomain[1] - newDomain[0] > 1000) {
        ctx.zoomDomain.value = newDomain;
        // Clear the brush selection visually
        ctx.mainGroup?.select('.brush').call(ctx.brush!.move as unknown as never, null);
        render();
      } else {
        ctx.mainGroup?.select('.brush').call(ctx.brush!.move as unknown as never, null);
      }
    });

  // Add brush to main group (variants will be added after, on top)
  ctx.mainGroup.append('g').attr('class', 'brush').call(ctx.brush);

  // Add double-click to reset zoom
  ctx.svg?.on('dblclick', () => {
    if (ctx.zoomDomain.value) {
      resetZoom(ctx, render);
    }
  });
}

/**
 * Reset zoom to full gene view and re-render.
 */
export function resetZoom(ctx: GeneStructureContext, render: () => void): void {
  ctx.zoomDomain.value = null;
  render();
}

/**
 * Initialize and render the gene-structure visualization.
 */
export function renderGeneStructure(ctx: GeneStructureContext, render: () => void): void {
  if (!ctx.container.value) return;

  const { geneData, variants, geneSymbol, showVariants } = ctx.inputs;
  const { width, height, margin } = ctx.layout;
  const {
    codingHeight: CODING_HEIGHT,
    utrHeight: UTR_HEIGHT,
    codingColor: CODING_COLOR,
    utrColor: UTR_COLOR,
    intronColor: INTRON_COLOR,
    exonStroke: EXON_STROKE,
    stemBaseHeight: STEM_BASE_HEIGHT,
    markerRadius: MARKER_RADIUS,
    markerStrokeWidth: MARKER_STROKE_WIDTH,
  } = ctx.layout;

  // Reset tooltip lock on re-render
  forceHideTooltip(ctx);

  const innerWidth = width - margin.left - margin.right;
  const innerHeight = height - margin.top - margin.bottom;

  // Clear previous render
  d3.select(ctx.container.value).select('svg').remove();
  d3.select(ctx.container.value).select('.gene-tooltip').remove();

  // Create responsive SVG with viewBox.
  // role="img" + aria-labelledby (title + desc) is the correct accessible pattern
  // for a decorative/informational SVG chart. aria-label on role="group" is a
  // prohibited naming attribute and triggers Lighthouse aria-prohibited-attr.
  ctx.svg = d3
    .select(ctx.container.value)
    .append('svg')
    .attr('viewBox', `0 0 ${width} ${height}`)
    .attr('preserveAspectRatio', 'xMinYMin meet')
    .attr('role', 'img')
    .attr('aria-labelledby', 'gene-structure-title gene-structure-desc')
    .style('width', '100%')
    .style('height', 'auto');

  // Embedded accessible title and description (consumed by aria-labelledby above).
  ctx.svg
    .append('title')
    .attr('id', 'gene-structure-title')
    .text(`Gene structure diagram for ${geneSymbol}`);
  ctx.svg
    .append('desc')
    .attr('id', 'gene-structure-desc')
    .text(
      'Interactive visualization showing exon/intron structure and clinical variants along the genomic sequence.'
    );

  // Click on SVG background to dismiss locked tooltip
  ctx.svg.on('click', (event: MouseEvent) => {
    // Only dismiss if clicking on SVG background (not on markers)
    if ((event.target as Element).tagName === 'svg') {
      forceHideTooltip(ctx);
    }
  });

  // Create main group with margin transform
  ctx.mainGroup = ctx.svg
    .append('g')
    .attr('class', 'main-group')
    .attr('transform', `translate(${margin.left}, ${margin.top})`);

  // Determine domain (use zoom or full gene)
  const domain: [number, number] = ctx.zoomDomain.value ?? [geneData.geneStart, geneData.geneEnd];

  // Create x scale (genomic coordinates)
  ctx.xScale = d3.scaleLinear().domain(domain).range([0, innerWidth]);
  const xScale = ctx.xScale;

  // Y positions
  const exonY = innerHeight - 30;
  const variantBaseY = exonY - CODING_HEIGHT / 2 - 5;

  // Create strand arrow marker
  const defs = ctx.svg.append('defs');
  const marker = defs
    .append('marker')
    .attr('id', 'gene-strand-arrow')
    .attr('markerWidth', 6)
    .attr('markerHeight', 6)
    .attr('refX', geneData.strand === '+' ? 6 : 0)
    .attr('refY', 3)
    .attr('orient', 'auto');

  marker
    .append('path')
    .attr('d', geneData.strand === '+' ? 'M 0 0 L 6 3 L 0 6 Z' : 'M 6 0 L 0 3 L 6 6 Z')
    .attr('fill', INTRON_COLOR)
    .attr('aria-hidden', 'true');

  // Render intron lines (back layer)
  geneData.introns.forEach((intron) => {
    ctx.mainGroup!.append('line')
      .attr('class', 'intron')
      .attr('x1', xScale(intron.start))
      .attr('y1', exonY)
      .attr('x2', xScale(intron.end))
      .attr('y2', exonY)
      .attr('stroke', INTRON_COLOR)
      .attr('stroke-width', 1)
      .attr('marker-end', 'url(#gene-strand-arrow)')
      .attr('aria-hidden', 'true');
  });

  // Render exon rectangles
  geneData.exons.forEach((exon: ClassifiedExon) => {
    const exonWidth = Math.max(xScale(exon.end) - xScale(exon.start), 2);
    const exonHeight = exon.type === 'coding' ? CODING_HEIGHT : UTR_HEIGHT;
    const fillColor = exon.type === 'coding' ? CODING_COLOR : UTR_COLOR;

    ctx.mainGroup!.append('rect')
      .attr('class', 'exon')
      .attr('x', xScale(exon.start))
      .attr('y', exonY - exonHeight / 2)
      .attr('width', exonWidth)
      .attr('height', exonHeight)
      .attr('fill', fillColor)
      .attr('stroke', EXON_STROKE)
      .attr('stroke-width', 0.5)
      .attr('cursor', 'pointer')
      .attr('aria-hidden', 'true')
      .on('mouseover', (event: MouseEvent) => {
        showExonTooltip(ctx, event, exon);
      })
      .on('mouseout', () => hideTooltip(ctx));
  });

  // Setup brush-to-zoom BEFORE variants (so variants are on top and can receive clicks)
  setupBrush(ctx, innerWidth, innerHeight, render);

  // Create a variant group that will be on top of the brush
  const variantGroup = ctx.mainGroup.append('g').attr('class', 'variant-group');

  // Render variants (if enabled) with adaptive density-aware rendering
  if (showVariants && variants.length > 0) {
    // Filter by pathogenicity and by visible domain
    const visibleVariants = variants.filter((v) => {
      if (!ctx.inputs.isVariantVisible(v)) return false;
      // Filter by zoom domain
      if (ctx.zoomDomain.value) {
        return (
          v.genomicPosition >= ctx.zoomDomain.value[0] &&
          v.genomicPosition <= ctx.zoomDomain.value[1]
        );
      }
      return true;
    });
    const geneLength = domain[1] - domain[0];
    const renderMode = determineRenderingMode(visibleVariants.length);
    const opacity = calculateDynamicOpacity(visibleVariants.length);

    if (renderMode === 'aggregated') {
      // Aggregated mode for dense regions
      const aggregated = aggregateVariantsByGenomicPosition(visibleVariants, geneLength);
      const maxCount = Math.max(...aggregated.map((a) => a.count), 1);

      aggregated.forEach((agg) => {
        const x = xScale(agg.genomicPosition);
        const radius = calculateAggregatedRadius(agg.count, maxCount);
        const stemHeight = STEM_BASE_HEIGHT;
        const markerY = variantBaseY - stemHeight;

        // Stem line
        variantGroup
          .append('line')
          .attr('class', 'variant-stem')
          .attr('x1', x)
          .attr('y1', variantBaseY)
          .attr('x2', x)
          .attr('y2', markerY)
          .attr('stroke', '#999')
          .attr('stroke-width', 1)
          .attr('opacity', 0.4)
          .attr('aria-hidden', 'true');

        // Aggregated marker circle (size = count)
        const color = ctx.inputs.getAggregatedColor(agg);

        variantGroup
          .append('circle')
          .attr('class', 'variant-marker aggregated')
          .attr('cx', x)
          .attr('cy', markerY)
          .attr('r', radius)
          .attr('fill', color)
          .attr('stroke', '#fff')
          .attr('stroke-width', MARKER_STROKE_WIDTH)
          .attr('opacity', opacity)
          .attr('cursor', 'pointer')
          .attr('aria-hidden', 'true')
          .on('mouseover', (event: MouseEvent) => {
            showAggregatedTooltip(ctx, event, agg);
          })
          .on('mouseout', () => hideTooltip(ctx));
      });
    } else {
      // Individual mode for sparse regions
      // Group by genomic position to handle stacking
      const variantGroups = d3.group(
        visibleVariants,
        (v) => Math.round(v.genomicPosition / 100) * 100
      );

      // Render stems and markers
      variantGroups.forEach((group) => {
        group.forEach((variant, index) => {
          const x = xScale(variant.genomicPosition);
          const stemHeight = STEM_BASE_HEIGHT + Math.min(index, 8) * 10;
          const markerY = variantBaseY - stemHeight;

          // Stem line
          variantGroup
            .append('line')
            .attr('class', 'variant-stem')
            .attr('x1', x)
            .attr('y1', variantBaseY)
            .attr('x2', x)
            .attr('y2', markerY)
            .attr('stroke', '#999')
            .attr('stroke-width', 1)
            .attr('opacity', 0.6)
            .attr('aria-hidden', 'true');

          // Marker circle
          const color = ctx.inputs.getVariantColor(variant);

          variantGroup
            .append('circle')
            .attr('class', 'variant-marker')
            // Decorative inside role="img" SVG — aria naming and role="button" are
            // prohibited on SVG child elements of role="img". Mark hidden from AT;
            // the SVG title/desc carry the accessible figure description.
            .attr('aria-hidden', 'true')
            .attr('cx', x)
            .attr('cy', markerY)
            .attr('r', MARKER_RADIUS)
            .attr('fill', color)
            .attr('stroke', '#fff')
            .attr('stroke-width', MARKER_STROKE_WIDTH)
            .attr('opacity', opacity)
            .attr('cursor', 'pointer')
            .on('mouseover', (event: MouseEvent) => {
              if (!ctx.isTooltipLocked) {
                showVariantTooltip(ctx, event, variant);
              }
            })
            .on('mouseout', () => hideTooltip(ctx))
            .on('click', (event: MouseEvent) => {
              event.stopPropagation(); // Prevent SVG click handler
              activateVariantMarker(ctx, event, variant);
            })
            .on('keydown', (event: KeyboardEvent) => {
              if (event.key !== 'Enter' && event.key !== ' ') return;
              event.preventDefault();
              event.stopPropagation();
              activateVariantMarker(ctx, event, variant);
            });
        });
      });
    }
  }

  // Render X axis
  const xAxis = d3
    .axisBottom(xScale)
    .ticks(6)
    .tickFormat((d) => formatGenomicCoordinate(d as number));

  const axisGroup = ctx.mainGroup
    .append('g')
    .attr('class', 'x-axis')
    .attr('transform', `translate(0, ${innerHeight})`)
    .call(xAxis);

  axisGroup.selectAll('line, path').attr('aria-hidden', 'true');

  axisGroup
    .append('text')
    .attr('x', innerWidth / 2)
    .attr('y', 30)
    .attr('fill', '#666')
    .attr('text-anchor', 'middle')
    .style('font-size', '11px')
    .text(`Genomic Position (chr${geneData.chromosome})`);

  // Style axis
  ctx.mainGroup.selectAll('.x-axis text').style('font-size', '9px');

  // Create tooltip
  ctx.tooltipDiv = d3
    .select(ctx.container.value)
    .append('div')
    .attr('class', 'gene-tooltip')
    .style('position', 'absolute')
    .style('padding', '8px 12px')
    .style('background', 'rgba(0, 0, 0, 0.85)')
    .style('color', '#fff')
    .style('border-radius', '4px')
    .style('font-size', '12px')
    .style('pointer-events', 'none')
    .style('opacity', 0)
    .style('z-index', '1000')
    .style('max-width', '280px')
    .style('line-height', '1.4');

  ctx.isInitialized.value = true;
}
