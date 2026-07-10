/**
 * useProteinLollipopExport contract tests.
 *
 * Pins the DOM download mechanics extracted from ProteinDomainLollipopPlot.vue:
 * SVG filename `${geneSymbol}_lollipop_plot.svg`, PNG filename
 * `${geneSymbol}_lollipop_plot.png`, object-URL creation/revocation for the
 * SVG blob path (PNG uses a data URL and never touches the Blob/object-URL
 * path), and that export never mutates unrelated reactive state (the plot's
 * filter state must never be touched by a download).
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { useProteinLollipopExport } from './useProteinLollipopExport';

let createObjectURLSpy: ReturnType<typeof vi.spyOn>;
let revokeObjectURLSpy: ReturnType<typeof vi.spyOn>;

beforeEach(() => {
  createObjectURLSpy = vi.spyOn(URL, 'createObjectURL').mockReturnValue('blob:mock-url');
  revokeObjectURLSpy = vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {});
});

afterEach(() => {
  createObjectURLSpy.mockRestore();
  revokeObjectURLSpy.mockRestore();
});

/**
 * jsdom doesn't implement navigation for `<a>` clicks. Stub `document.createElement`
 * so the anchor node created inside the composable can be inspected (href/download)
 * and its `.click()` observed without jsdom logging a "not implemented" error.
 */
function captureAnchor() {
  const clickSpy = vi.fn();
  let captured: HTMLAnchorElement | null = null;
  const originalCreateElement = document.createElement.bind(document);
  const createElementSpy = vi
    .spyOn(document, 'createElement')
    .mockImplementation(((tagName: string) => {
      const element = originalCreateElement(tagName);
      if (tagName === 'a') {
        (element as HTMLAnchorElement).click = clickSpy;
        captured = element as HTMLAnchorElement;
      }
      return element;
    }) as typeof document.createElement);
  return {
    clickSpy,
    createElementSpy,
    get anchor(): HTMLAnchorElement | null {
      return captured;
    },
  };
}

describe('useProteinLollipopExport', () => {
  describe('downloadSVG', () => {
    it('downloads an SVG blob named `${geneSymbol}_lollipop_plot.svg` and revokes the object URL', () => {
      const exportSVG = vi.fn().mockReturnValue('<svg></svg>');
      const exportPNG = vi.fn();
      const { downloadSVG } = useProteinLollipopExport({
        geneSymbol: () => 'CHD8',
        exportSVG,
        exportPNG,
      });
      const capture = captureAnchor();

      downloadSVG();

      expect(exportSVG).toHaveBeenCalledTimes(1);
      expect(createObjectURLSpy).toHaveBeenCalledTimes(1);
      expect(capture.anchor?.download).toBe('CHD8_lollipop_plot.svg');
      expect(capture.anchor?.href).toBe('blob:mock-url');
      expect(capture.clickSpy).toHaveBeenCalledTimes(1);
      expect(revokeObjectURLSpy).toHaveBeenCalledWith('blob:mock-url');
      expect(exportPNG).not.toHaveBeenCalled();

      capture.createElementSpy.mockRestore();
    });

    it('does nothing when exportSVG has no data (no plot rendered yet)', () => {
      const exportSVG = vi.fn().mockReturnValue(null);
      const { downloadSVG } = useProteinLollipopExport({
        geneSymbol: () => 'CHD8',
        exportSVG,
        exportPNG: vi.fn(),
      });

      downloadSVG();

      expect(createObjectURLSpy).not.toHaveBeenCalled();
      expect(revokeObjectURLSpy).not.toHaveBeenCalled();
    });
  });

  describe('downloadPNG', () => {
    it('downloads a PNG data URL named `${geneSymbol}_lollipop_plot.png` at 2x scale, bypassing the Blob path', async () => {
      const exportPNG = vi.fn().mockResolvedValue('data:image/png;base64,AAA');
      const { downloadPNG } = useProteinLollipopExport({
        geneSymbol: () => 'SCN2A',
        exportSVG: vi.fn(),
        exportPNG,
      });
      const capture = captureAnchor();

      await downloadPNG();

      expect(exportPNG).toHaveBeenCalledWith(2);
      expect(capture.anchor?.download).toBe('SCN2A_lollipop_plot.png');
      expect(capture.anchor?.href).toBe('data:image/png;base64,AAA');
      expect(capture.clickSpy).toHaveBeenCalledTimes(1);
      // PNG export uses the data URL directly — no Blob/object-URL is created.
      expect(createObjectURLSpy).not.toHaveBeenCalled();
      expect(revokeObjectURLSpy).not.toHaveBeenCalled();

      capture.createElementSpy.mockRestore();
    });

    it('does nothing when exportPNG resolves to no data', async () => {
      const exportPNG = vi.fn().mockResolvedValue(null);
      const { downloadPNG } = useProteinLollipopExport({
        geneSymbol: () => 'SCN2A',
        exportSVG: vi.fn(),
        exportPNG,
      });
      const { clickSpy, createElementSpy } = captureAnchor();

      await downloadPNG();

      expect(clickSpy).not.toHaveBeenCalled();

      createElementSpy.mockRestore();
    });
  });

  describe('filter-state isolation', () => {
    it('never mutates the plot filter state during SVG or PNG export', async () => {
      // A stand-in for the parent's reactive LollipopFilterState. The
      // composable is never handed a reference to it — this snapshot
      // comparison guards against a future regression that threads filter
      // state into export and starts mutating it (e.g. a "temporarily show
      // all variants for export" shortcut).
      const filterState = {
        pathogenic: true,
        likelyPathogenic: false,
        vus: false,
        likelyBenign: false,
        benign: false,
        effectFilters: { missense: true, frameshift: false },
        coloringMode: 'acmg' as const,
      };
      const snapshot = JSON.parse(JSON.stringify(filterState));

      const { downloadSVG, downloadPNG } = useProteinLollipopExport({
        geneSymbol: () => 'CHD8',
        exportSVG: vi.fn().mockReturnValue('<svg></svg>'),
        exportPNG: vi.fn().mockResolvedValue('data:image/png;base64,AAA'),
      });
      const { createElementSpy } = captureAnchor();

      downloadSVG();
      await downloadPNG();

      expect(filterState).toEqual(snapshot);

      createElementSpy.mockRestore();
    });
  });
});
