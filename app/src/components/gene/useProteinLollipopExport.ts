/**
 * useProteinLollipopExport.ts
 *
 * DOM download mechanics for ProteinDomainLollipopPlot.vue's SVG/PNG export
 * buttons: object-URL/anchor-click plumbing only. The actual SVG
 * serialization / canvas rasterization stays in the `useD3Lollipop`
 * composable (`exportSVG` / `exportPNG`) — this composable just turns those
 * outputs into a browser download and cleans up after itself.
 *
 * Deliberately reads nothing from the plot's reactive filter state: export
 * must never mutate (or even observe) `LollipopFilterState` — it downloads
 * whatever is currently rendered.
 */

/** Options for the useProteinLollipopExport composable. */
export interface UseProteinLollipopExportOptions {
  /** Getter for the current gene symbol, used to build the download filename. */
  geneSymbol: () => string;
  /** Serializes the current plot to an SVG string (from useD3Lollipop). */
  exportSVG: () => string | null;
  /** Rasterizes the current plot to a PNG data URL (from useD3Lollipop). */
  exportPNG: (scale?: number) => Promise<string | null>;
}

/** Download controls returned by the useProteinLollipopExport composable. */
export interface ProteinLollipopExportControls {
  /** Download the plot as `${geneSymbol}_lollipop_plot.svg`. */
  downloadSVG: () => void;
  /** Download the plot as `${geneSymbol}_lollipop_plot.png`. */
  downloadPNG: () => Promise<void>;
}

/**
 * Composable exposing SVG/PNG download handlers for the protein lollipop plot.
 */
export function useProteinLollipopExport(
  options: UseProteinLollipopExportOptions
): ProteinLollipopExportControls {
  function downloadSVG(): void {
    const svgString = options.exportSVG();
    if (!svgString) return;

    const blob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${options.geneSymbol()}_lollipop_plot.svg`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }

  async function downloadPNG(): Promise<void> {
    const dataUrl = await options.exportPNG(2);
    if (!dataUrl) return;

    const link = document.createElement('a');
    link.href = dataUrl;
    link.download = `${options.geneSymbol()}_lollipop_plot.png`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  return { downloadSVG, downloadPNG };
}

export default useProteinLollipopExport;
