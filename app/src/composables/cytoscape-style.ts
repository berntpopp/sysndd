// composables/cytoscape-style.ts

/**
 * Cytoscape.js stylesheet for the gene-network visualization.
 *
 * Extracted from useCytoscape.ts as a pure, dependency-free helper. Balanced
 * between visibility and performance for 10k edge graphs. Internal to the
 * Cytoscape composable module — not re-exported from @/composables.
 */

// Cytoscape.js style type (simplified for our use case)
export type CytoscapeStylesheet = Array<{
  selector: string;
  style: Record<string, unknown>;
}>;

/**
 * Get Cytoscape.js style configuration
 *
 * Balanced between visibility and performance for 10k edge graphs.
 */
export function getCytoscapeStyle(): CytoscapeStylesheet {
  return [
    // Compound parent nodes (cluster containers)
    {
      selector: 'node[?isClusterParent]',
      style: {
        'background-color': 'data(color)',
        'background-opacity': 0.15,
        'border-width': 3,
        'border-color': 'data(color)',
        'border-opacity': 0.6,
        shape: 'round-rectangle',
        // Don't show label for cleaner look (clusters shown in legend)
        label: '',
        // Padding inside the cluster
        padding: '30px',
      },
    },
    // Regular gene nodes (children of cluster parents)
    {
      selector: 'node[!isClusterParent]',
      style: {
        // Node size based on degree (pre-computed as 'size')
        width: 'data(size)',
        height: 'data(size)',
        'background-color': 'data(color)',
        'border-width': 2,
        'border-color': '#333',
        // Show label always for identification
        label: 'data(symbol)',
        'font-size': '8px',
        'text-valign': 'bottom',
        'text-halign': 'center',
        'text-margin-y': 3,
        color: '#333',
        'min-zoomed-font-size': 8,
      },
    },
    {
      selector: 'edge',
      style: {
        // Straight lines for performance
        'curve-style': 'haystack',
        'haystack-radius': 0,
        width: 'data(width)',
        'line-color': '#ccc',
        opacity: 0.6,
      },
    },
    {
      selector: 'node:selected',
      style: {
        'border-color': '#0d47a1',
        'border-width': 4,
        'font-size': '12px',
        'font-weight': 'bold',
        'z-index': 999,
      },
    },
    {
      selector: 'node.highlighted',
      style: {
        'border-color': '#f39c12',
        'border-width': 3,
        'font-size': '10px',
        'z-index': 998,
      },
    },
    {
      selector: 'edge.highlighted',
      style: {
        'line-color': '#f39c12',
        width: 2,
        opacity: 1,
      },
    },
    {
      selector: 'node.dimmed',
      style: {
        opacity: 0.15,
      },
    },
    {
      selector: 'edge.dimmed',
      style: {
        opacity: 0.05,
      },
    },
    // Search highlighting styles (FILT-04, FILT-05)
    {
      selector: 'node.search-match',
      style: {
        'border-color': '#ffc107',
        'border-width': 4,
        'z-index': 999,
      },
    },
    {
      selector: 'node.search-no-match',
      style: {
        opacity: 0.3,
      },
    },
    // Table hover highlight styles (NAVL-05)
    {
      selector: 'node.hover-highlight',
      style: {
        'border-color': '#28a745',
        'border-width': 4,
        'z-index': 1000,
      },
    },
    {
      selector: 'node.neighbor-highlight',
      style: {
        'border-color': '#6c757d',
        'border-width': 2,
        'z-index': 900,
      },
    },
    {
      selector: 'edge.neighbor-highlight',
      style: {
        'line-color': '#6c757d',
        width: 2,
        opacity: 0.8,
      },
    },
    {
      selector: 'node.table-hover-highlight',
      style: {
        'border-color': '#17a2b8',
        'border-width': 4,
        'z-index': 1000,
      },
    },
  ];
}
