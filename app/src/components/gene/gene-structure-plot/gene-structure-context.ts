/**
 * gene-structure-plot/gene-structure-context.ts
 *
 * Shared mutable context object for the D3 gene-structure plot module.
 * Holds the non-reactive D3 selections/scales, tooltip lock state, resolved
 * layout constants, and reactive refs that the extracted render/tooltip/export
 * functions read and write via `ctx.<prop>` (preserving closure semantics).
 *
 * Mirrors the d3-lollipop module's ctx-object pattern.
 */

import type * as d3 from 'd3';
import type { Ref } from 'vue';
import type { GeneStructureRenderData } from '@/types/ensembl';
import type { AggregatedGeneStructureVariant } from '../geneStructureVariantPlotUtils';
import type { GenomicVariant } from '../GenomicVisualizationTabs.vue';

/**
 * Margin configuration for the SVG plot
 */
export interface GeneStructurePlotMargin {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

/**
 * Layout/styling constants resolved once and stored on the context.
 */
export interface GeneStructurePlotLayout {
  width: number;
  height: number;
  margin: GeneStructurePlotMargin;
  codingHeight: number;
  utrHeight: number;
  codingColor: string;
  utrColor: string;
  intronColor: string;
  exonStroke: string;
  stemBaseHeight: number;
  markerRadius: number;
  markerStrokeWidth: number;
}

/**
 * Aggregated genomic variant bin (alias to keep render code terse).
 */
export type AggregatedGenomicVariant = AggregatedGeneStructureVariant<GenomicVariant>;

/**
 * Inputs the render functions read each frame. These are owned by the Vue
 * component (props + reactive filter/zoom state) and passed in via the
 * context so the extracted functions stay framework-agnostic.
 */
export interface GeneStructurePlotInputs {
  /** Gene structure data (exons/introns/coordinates) */
  geneData: GeneStructureRenderData;
  /** Variants to plot at genomic positions */
  variants: GenomicVariant[];
  /** Gene symbol for ARIA labels and export file names */
  geneSymbol: string;
  /** Whether the variant layer is shown */
  showVariants: boolean;
  /** Predicate: is this variant visible under the current filters? */
  isVariantVisible: (variant: GenomicVariant) => boolean;
  /** Resolve the color for an individual variant under the current coloring mode */
  getVariantColor: (variant: GenomicVariant) => string;
  /** Resolve the color for an aggregated variant bin under the current coloring mode */
  getAggregatedColor: (agg: AggregatedGenomicVariant) => string;
  /** Emit a variant-click event to the parent component */
  onVariantClick: (variant: GenomicVariant) => void;
}

export interface GeneStructureContext {
  // CRITICAL: D3 selections are stored in non-reactive properties to avoid
  // Vue reactivity triggering layout recalculations on every mutation.
  svg: d3.Selection<SVGSVGElement, unknown, null, undefined> | null;
  mainGroup: d3.Selection<SVGGElement, unknown, null, undefined> | null;
  tooltipDiv: d3.Selection<HTMLDivElement, unknown, null, undefined> | null;
  brush: d3.BrushBehavior<unknown> | null;
  xScale: d3.ScaleLinear<number, number> | null;

  // Tooltip lock state for click-to-pin functionality
  isTooltipLocked: boolean;
  lockedVariant: GenomicVariant | null;

  // Container element (D3 owns the SVG inside it)
  container: Ref<HTMLElement | null>;

  // Resolved layout constants
  layout: GeneStructurePlotLayout;

  // Per-frame inputs (refreshed by the composable before each render)
  inputs: GeneStructurePlotInputs;

  // Reactive state for UI binding
  isInitialized: Ref<boolean>;
  zoomDomain: Ref<[number, number] | null>;
}
