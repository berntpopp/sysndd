/**
 * d3-lollipop/lollipop-export.ts
 *
 * SVG/PNG export functions for the D3 lollipop plot.
 * Each function takes the shared LollipopContext and reads `ctx.<prop>`
 * directly to preserve closure semantics.
 */

import type { LollipopContext } from './lollipop-context';

/**
 * Export the plot as SVG string
 */
export function exportSvgFrom(ctx: LollipopContext): string | null {
  if (!ctx.svg) return null;

  const svgNode = ctx.svg.node();
  if (!svgNode) return null;

  // Clone the SVG to avoid modifying the original
  const clonedSvg = svgNode.cloneNode(true) as SVGSVGElement;

  // Add XML namespace for standalone SVG
  clonedSvg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
  clonedSvg.setAttribute('xmlns:xlink', 'http://www.w3.org/1999/xlink');

  // Serialize to string
  const serializer = new XMLSerializer();
  return serializer.serializeToString(clonedSvg);
}

/**
 * Export the plot as PNG data URL
 * @param scale - Scale factor for higher resolution (default: 2 for retina)
 */
export async function exportPngFrom(ctx: LollipopContext, scale = 2): Promise<string | null> {
  if (!ctx.svg) return null;

  const svgNode = ctx.svg.node();
  if (!svgNode) return null;

  // Get dimensions from viewBox or attributes
  const fullWidth = ctx.innerWidth + ctx.margin.left + ctx.margin.right;
  const fullHeight = ctx.innerHeight + ctx.margin.top + ctx.margin.bottom;

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

      const canvasCtx = canvas.getContext('2d');
      if (!canvasCtx) {
        resolve(null);
        return;
      }

      // Fill white background
      canvasCtx.fillStyle = '#ffffff';
      canvasCtx.fillRect(0, 0, canvas.width, canvas.height);

      // Scale and draw
      canvasCtx.scale(scale, scale);
      canvasCtx.drawImage(img, 0, 0, fullWidth, fullHeight);

      resolve(canvas.toDataURL('image/png'));
    };

    img.onerror = (err) => {
      console.error('[useD3Lollipop] PNG export failed:', err);
      resolve(null);
    };

    img.src = dataUrl;
  });
}
