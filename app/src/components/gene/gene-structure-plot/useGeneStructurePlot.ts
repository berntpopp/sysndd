/**
 * gene-structure-plot/useGeneStructurePlot.ts
 *
 * Composable for D3.js gene-structure plot lifecycle management.
 *
 * Manages D3.js SVG initialization, exon/intron/variant rendering,
 * brush-to-zoom, tooltips, SVG/PNG export, and cleanup.
 *
 * CRITICAL: D3 selections are stored in non-reactive properties of a single
 * mutable context object (GeneStructureContext) to avoid Vue reactivity
 * triggering layout recalculations.
 *
 * Mirrors the d3-lollipop module's useD3Lollipop composable.
 */

import { ref, type Ref } from 'vue';
import type {
  GeneStructureContext,
  GeneStructurePlotInputs,
  GeneStructurePlotLayout,
} from './gene-structure-context';
import { downloadPngFrom, downloadSvgFrom } from './gene-structure-export';
import { renderGeneStructure, resetZoom as resetZoomFn } from './gene-structure-render';

/**
 * Options for the useGeneStructurePlot composable.
 */
export interface UseGeneStructurePlotOptions {
  /** Ref to the container HTML element (D3 owns the SVG inside it) */
  container: Ref<HTMLElement | null>;
  /** Resolved layout/styling constants */
  layout: GeneStructurePlotLayout;
  /**
   * Getter returning the current per-frame inputs (props + filter/coloring
   * accessors). Read fresh before each render so reactive changes are picked up.
   */
  getInputs: () => GeneStructurePlotInputs;
}

/**
 * State and controls returned by the composable.
 */
export interface GeneStructurePlotState {
  /** Whether the D3 SVG is initialized */
  isInitialized: Ref<boolean>;
  /** Current zoom domain (genomic range), null at full gene view */
  zoomDomain: Ref<[number, number] | null>;
  /** Render/update the plot from the latest inputs */
  render: () => void;
  /** Reset zoom to the full gene view */
  resetZoom: () => void;
  /** Download the plot as an SVG file */
  downloadSVG: () => void;
  /** Download the plot as a PNG file */
  downloadPNG: () => Promise<void>;
  /** Clean up D3 resources (call from onBeforeUnmount) */
  cleanup: () => void;
}

export function useGeneStructurePlot(
  options: UseGeneStructurePlotOptions
): GeneStructurePlotState {
  const isInitialized = ref(false);
  const zoomDomain = ref<[number, number] | null>(null);

  // CRITICAL: Single mutable context object holding the non-reactive D3
  // selections/scales and tooltip state. Extracted module functions
  // read/write ctx.<prop> directly, preserving closure mutation semantics.
  const ctx: GeneStructureContext = {
    svg: null,
    mainGroup: null,
    tooltipDiv: null,
    brush: null,
    xScale: null,
    isTooltipLocked: false,
    lockedVariant: null,
    container: options.container,
    layout: options.layout,
    inputs: options.getInputs(),
    isInitialized,
    zoomDomain,
  };

  /**
   * Render the plot, refreshing the per-frame inputs first so the latest
   * props + filter/coloring state are used.
   */
  const render = (): void => {
    ctx.inputs = options.getInputs();
    renderGeneStructure(ctx, render);
  };

  const resetZoom = (): void => {
    ctx.inputs = options.getInputs();
    resetZoomFn(ctx, render);
  };

  const cleanup = (): void => {
    if (ctx.svg) {
      ctx.svg.selectAll('*').remove();
      ctx.svg.remove();
      ctx.svg = null;
    }
    if (ctx.tooltipDiv) {
      ctx.tooltipDiv.remove();
      ctx.tooltipDiv = null;
    }
    isInitialized.value = false;
  };

  return {
    isInitialized,
    zoomDomain,
    render,
    resetZoom,
    downloadSVG: () => downloadSvgFrom(ctx),
    downloadPNG: () => downloadPngFrom(ctx),
    cleanup,
  };
}

export default useGeneStructurePlot;
