/**
 * d3-lollipop/lollipop-context.ts
 *
 * Shared mutable context object for the D3 lollipop plot module.
 * Holds the non-reactive D3 selections/scales, tooltip lock state, resolved
 * options, and reactive refs that the extracted render/tooltip/export
 * functions read and write via `ctx.<prop>` (preserving closure semantics).
 */

import type * as d3 from 'd3';
import type { Ref } from 'vue';
import type { ProteinPlotData, ProcessedVariant, LollipopFilterState } from '@/types/protein';
import type { LollipopOptions, PlotMargin } from './useD3Lollipop';

export interface LollipopContext {
  // CRITICAL: D3 selections are stored in non-reactive properties
  // to avoid Vue reactivity triggering layout recalculations.
  svg: d3.Selection<SVGSVGElement, unknown, null, undefined> | null;
  mainGroup: d3.Selection<SVGGElement, unknown, null, undefined> | null;
  xScale: d3.ScaleLinear<number, number> | null;
  xScaleOriginal: d3.ScaleLinear<number, number> | null;
  brush: d3.BrushBehavior<unknown> | null;
  tooltipDiv: d3.Selection<HTMLDivElement, unknown, null, undefined> | null;

  // Store current data for re-render on zoom
  currentData: ProteinPlotData | null;
  currentFilterState: LollipopFilterState | null;

  // Tooltip lock state for click-to-pin functionality
  isTooltipLocked: boolean;
  lockedVariant: ProcessedVariant | null;

  // Resolved options with defaults
  options: LollipopOptions;
  width: number;
  height: number;
  margin: PlotMargin;
  innerWidth: number;
  innerHeight: number;

  // Reactive state for UI binding
  isInitialized: Ref<boolean>;
  isLoading: Ref<boolean>;
  currentZoomDomain: Ref<[number, number] | null>;
}
