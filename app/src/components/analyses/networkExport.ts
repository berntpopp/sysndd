/** Downloads a Cytoscape SVG export and releases its short-lived object URL. */
export function downloadNetworkSvg(svgString: string): void {
  const blob = new Blob([svgString], { type: 'image/svg+xml' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.download = 'network.svg';
  link.href = url;
  link.click();
  URL.revokeObjectURL(url);
}
