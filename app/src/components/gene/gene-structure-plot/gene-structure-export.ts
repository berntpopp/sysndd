/**
 * gene-structure-plot/gene-structure-export.ts
 *
 * SVG/PNG download functions for the D3 gene-structure plot. Each function
 * takes the shared GeneStructureContext and reads `ctx.<prop>` directly to
 * preserve the original closure semantics (browser download via anchor click).
 */

import type { GeneStructureContext } from './gene-structure-context';

/**
 * Export the plot as a downloaded SVG file
 */
export function downloadSvgFrom(ctx: GeneStructureContext): void {
  if (!ctx.svg) return;

  const svgNode = ctx.svg.node();
  if (!svgNode) return;

  const clonedSvg = svgNode.cloneNode(true) as SVGSVGElement;
  clonedSvg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');

  const serializer = new XMLSerializer();
  const svgString = serializer.serializeToString(clonedSvg);
  const blob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(blob);

  const link = document.createElement('a');
  link.href = url;
  link.download = `${ctx.inputs.geneSymbol}_gene_structure.svg`;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

/**
 * Export the plot as a downloaded PNG file
 */
export async function downloadPngFrom(ctx: GeneStructureContext): Promise<void> {
  if (!ctx.svg) return;

  const svgNode = ctx.svg.node();
  if (!svgNode) return;

  const { width, height } = ctx.layout;
  const scale = 2;
  const clonedSvg = svgNode.cloneNode(true) as SVGSVGElement;
  clonedSvg.setAttribute('width', String(width));
  clonedSvg.setAttribute('height', String(height));
  clonedSvg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');

  const serializer = new XMLSerializer();
  const svgString = serializer.serializeToString(clonedSvg);
  const base64 = btoa(unescape(encodeURIComponent(svgString)));
  const dataUrl = `data:image/svg+xml;base64,${base64}`;

  const img = new Image();
  img.onload = () => {
    const canvas = document.createElement('canvas');
    canvas.width = width * scale;
    canvas.height = height * scale;

    const canvasCtx = canvas.getContext('2d');
    if (!canvasCtx) return;

    canvasCtx.fillStyle = '#ffffff';
    canvasCtx.fillRect(0, 0, canvas.width, canvas.height);
    canvasCtx.scale(scale, scale);
    canvasCtx.drawImage(img, 0, 0, width, height);

    const pngUrl = canvas.toDataURL('image/png');
    const link = document.createElement('a');
    link.href = pngUrl;
    link.download = `${ctx.inputs.geneSymbol}_gene_structure.png`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };
  img.src = dataUrl;
}
