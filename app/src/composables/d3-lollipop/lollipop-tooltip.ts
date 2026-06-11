/**
 * d3-lollipop/lollipop-tooltip.ts
 *
 * Tooltip show/hide/lock functions for the D3 lollipop plot.
 * Each function takes the shared LollipopContext and mutates `ctx.<prop>`
 * directly to preserve the original closure semantics.
 */

import type {
  ProteinPlotData,
  ProcessedVariant,
  LollipopFilterState,
  PathogenicityClass,
  EffectType,
  AggregatedVariant,
} from '@/types/protein';
import { PATHOGENICITY_COLORS, EFFECT_TYPE_COLORS } from '@/types/protein';
import type { LollipopContext } from './lollipop-context';

/**
 * Show tooltip near the hovered element with edge detection
 * @param locked - If true, tooltip is pinned and includes clickable ClinVar link
 */
export function showTooltip(
  ctx: LollipopContext,
  event: MouseEvent,
  variant: ProcessedVariant,
  containerEl: HTMLElement,
  locked = false
): void {
  if (!ctx.tooltipDiv) return;

  // Build tooltip content
  const colorStyle = `color: ${PATHOGENICITY_COLORS[variant.classification]};`;
  const starsDisplay = '★'.repeat(variant.goldStars) + '☆'.repeat(4 - variant.goldStars);
  const spliceNote = variant.isSpliceVariant
    ? '<div style="font-style: italic; margin-top: 4px; color: #aaa;">Position approximated from splice variant</div>'
    : '';

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

  ctx.tooltipDiv
    .html(html)
    .style('opacity', 1)
    .style('pointer-events', locked ? 'auto' : 'none');

  // Get dimensions for edge detection
  const tooltipNode = ctx.tooltipDiv.node();
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

  ctx.tooltipDiv.style('left', `${left}px`).style('top', `${top}px`);
}

/**
 * Hide tooltip (only if not locked)
 */
export function hideTooltip(ctx: LollipopContext): void {
  if (!ctx.tooltipDiv || ctx.isTooltipLocked) return;
  ctx.tooltipDiv.style('opacity', 0).style('pointer-events', 'none');
}

/**
 * Dismiss locked tooltip
 */
export function dismissLockedTooltip(ctx: LollipopContext): void {
  ctx.isTooltipLocked = false;
  ctx.lockedVariant = null;
  if (ctx.tooltipDiv) {
    ctx.tooltipDiv.style('opacity', 0).style('pointer-events', 'none');
  }
}

/**
 * Show tooltip for domain hover
 */
export function showDomainTooltip(
  ctx: LollipopContext,
  event: MouseEvent,
  domain: ProteinPlotData['domains'][0],
  containerEl: HTMLElement
): void {
  if (!ctx.tooltipDiv) return;

  const html = `
    <div style="font-weight: bold; margin-bottom: 4px;">${domain.type}</div>
    <div style="color: #ccc;">${domain.description}</div>
    <div style="margin-top: 4px; color: #aaa; font-size: 11px;">
      Position: ${domain.begin} - ${domain.end}
    </div>
  `;

  ctx.tooltipDiv.html(html).style('opacity', 1);

  // Get dimensions for edge detection
  const tooltipNode = ctx.tooltipDiv.node();
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

  ctx.tooltipDiv.style('left', `${left}px`).style('top', `${top}px`);
}

/**
 * Show tooltip for aggregated variant
 */
export function showAggregatedTooltip(
  ctx: LollipopContext,
  event: MouseEvent,
  aggregated: AggregatedVariant,
  containerEl: HTMLElement,
  filterState: LollipopFilterState
): void {
  if (!ctx.tooltipDiv) return;

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

  ctx.tooltipDiv.html(html).style('opacity', 1);

  // Position tooltip
  const tooltipNode = ctx.tooltipDiv.node();
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

  ctx.tooltipDiv.style('left', `${left}px`).style('top', `${top}px`);
}
