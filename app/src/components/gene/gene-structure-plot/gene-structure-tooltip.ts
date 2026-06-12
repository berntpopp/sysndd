/**
 * gene-structure-plot/gene-structure-tooltip.ts
 *
 * Tooltip show/hide/lock + positioning functions for the D3 gene-structure
 * plot. Each function takes the shared GeneStructureContext and reads/mutates
 * `ctx.<prop>` directly to preserve the original closure semantics.
 */

import type { ClassifiedExon } from '@/types/ensembl';
import { formatGenomicCoordinate } from '@/types/ensembl';
import { PATHOGENICITY_COLORS } from '@/types/protein';
import type { GenomicVariant } from '../GenomicVisualizationTabs.vue';
import type { AggregatedGenomicVariant, GeneStructureContext } from './gene-structure-context';

export type TooltipTriggerEvent = MouseEvent | KeyboardEvent;

/**
 * Force hide tooltip (used when clicking elsewhere or on re-render)
 */
export function forceHideTooltip(ctx: GeneStructureContext): void {
  if (!ctx.tooltipDiv) return;
  ctx.isTooltipLocked = false;
  ctx.lockedVariant = null;
  ctx.tooltipDiv.style('opacity', 0).style('pointer-events', 'none');
}

/**
 * Hide tooltip (respects lock state)
 */
export function hideTooltip(ctx: GeneStructureContext): void {
  if (!ctx.tooltipDiv || ctx.isTooltipLocked) return;
  ctx.tooltipDiv.style('opacity', 0);
}

/**
 * Show exon tooltip
 */
export function showExonTooltip(
  ctx: GeneStructureContext,
  event: MouseEvent,
  exon: ClassifiedExon
): void {
  if (!ctx.tooltipDiv || !ctx.container.value) return;

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

  showTooltipAt(ctx, event, html);
}

/**
 * Show variant tooltip (with optional click-to-pin)
 */
export function showVariantTooltip(
  ctx: GeneStructureContext,
  event: TooltipTriggerEvent,
  variant: GenomicVariant,
  locked = false
): void {
  if (!ctx.tooltipDiv || !ctx.container.value) return;

  // If clicking to lock, check if already locked on this variant
  if (locked && ctx.isTooltipLocked && ctx.lockedVariant === variant) {
    forceHideTooltip(ctx);
    return;
  }

  if (locked) {
    ctx.isTooltipLocked = true;
    ctx.lockedVariant = variant;
  }

  const colorStyle = `color: ${PATHOGENICITY_COLORS[variant.classification as keyof typeof PATHOGENICITY_COLORS]};`;
  const starsDisplay = '★'.repeat(variant.goldStars) + '☆'.repeat(4 - variant.goldStars);

  // ClinVar link (only shown when locked)
  const clinvarLink =
    locked && variant.clinvarId
      ? `<div style="margin-top: 8px; padding-top: 8px; border-top: 1px solid #444;">
         <a href="https://www.ncbi.nlm.nih.gov/clinvar/variation/${variant.clinvarId}/"
            target="_blank"
            rel="noopener noreferrer"
            style="color: #6ea8fe; text-decoration: none;">
           View in ClinVar →
         </a>
       </div>`
      : '';

  // Dismiss hint
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
      Genomic pos: ${variant.genomicPosition.toLocaleString()}
    </div>
    ${clinvarLink}
    ${dismissHint}
  `;

  showTooltipAt(ctx, event, html, locked);
}

/**
 * Show tooltip for aggregated variants (dense region)
 */
export function showAggregatedTooltip(
  ctx: GeneStructureContext,
  event: MouseEvent,
  agg: AggregatedGenomicVariant
): void {
  if (!ctx.tooltipDiv || !ctx.container.value) return;

  // Build classification breakdown
  const classificationLines = Object.entries(agg.classifications)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5) // Show top 5 classifications
    .map(([cls, count]) => {
      const color = PATHOGENICITY_COLORS[cls as keyof typeof PATHOGENICITY_COLORS] || '#888';
      return `<div style="color: ${color}; font-size: 11px;">${cls}: ${count}</div>`;
    })
    .join('');

  const html = `
    <div style="font-weight: bold; margin-bottom: 4px;">${agg.count} variants at this position</div>
    <div style="color: #aaa; font-size: 11px; margin-bottom: 4px;">
      Genomic pos: ${agg.genomicPosition.toLocaleString()}
    </div>
    <div style="margin-top: 4px; border-top: 1px solid #444; padding-top: 4px;">
      ${classificationLines}
    </div>
    <div style="margin-top: 4px; color: #888; font-size: 10px;">
      (Aggregated view - zoom to see individual variants)
    </div>
  `;

  showTooltipAt(ctx, event, html);
}

/**
 * Position tooltip with edge detection
 */
export function showTooltipAt(
  ctx: GeneStructureContext,
  event: TooltipTriggerEvent,
  html: string,
  locked = false
): void {
  if (!ctx.tooltipDiv || !ctx.container.value) return;

  ctx.tooltipDiv
    .html(html)
    .style('opacity', 1)
    .style('pointer-events', locked ? 'auto' : 'none');

  const tooltipNode = ctx.tooltipDiv.node();
  if (!tooltipNode) return;

  const tooltipRect = tooltipNode.getBoundingClientRect();
  const containerRect = ctx.container.value.getBoundingClientRect();
  const point = getTooltipClientPoint(ctx, event);

  let left = point.clientX - containerRect.left + 15;
  let top = point.clientY - containerRect.top - 10;

  if (left + tooltipRect.width > containerRect.width) {
    left = point.clientX - containerRect.left - tooltipRect.width - 15;
  }
  if (top + tooltipRect.height > containerRect.height) {
    top = point.clientY - containerRect.top - tooltipRect.height - 10;
  }

  left = Math.max(0, left);
  top = Math.max(0, top);

  ctx.tooltipDiv.style('left', `${left}px`).style('top', `${top}px`);
}

function getTooltipClientPoint(
  ctx: GeneStructureContext,
  event: TooltipTriggerEvent
): { clientX: number; clientY: number } {
  if (event instanceof MouseEvent) {
    return { clientX: event.clientX, clientY: event.clientY };
  }

  const target = event.target instanceof Element ? event.target : null;
  const rect = target?.getBoundingClientRect();
  if (rect) {
    return {
      clientX: rect.left + rect.width / 2,
      clientY: rect.top + rect.height / 2,
    };
  }

  const containerRect = ctx.container.value?.getBoundingClientRect();
  return {
    clientX: containerRect ? containerRect.left : 0,
    clientY: containerRect ? containerRect.top : 0,
  };
}
