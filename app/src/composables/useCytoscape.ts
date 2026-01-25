// composables/useCytoscape.ts

/**
 * Composable for Cytoscape.js lifecycle management
 *
 * Provides a Vue 3 composable that handles Cytoscape.js initialization,
 * element updates, and proper cleanup to prevent memory leaks.
 *
 * CRITICAL: Cytoscape instance is stored in a non-reactive variable (let cy)
 * to avoid Vue reactivity triggering 100+ layout recalculations.
 *
 * CRITICAL: Always calls cy.destroy() in onBeforeUnmount to prevent
 * 100-300MB memory leaks per navigation.
 *
 * @returns Cytoscape control functions and state
 */

import { ref, onBeforeUnmount, type Ref } from 'vue';
// eslint-disable-next-line @typescript-eslint/no-require-imports
import cytoscape from 'cytoscape';
import type { Core, ElementDefinition, NodeSingular } from 'cytoscape';
import fcose from 'cytoscape-fcose';
import svg from 'cytoscape-svg';

// Cytoscape.js style type (simplified for our use case)
type CytoscapeStylesheet = Array<{
  selector: string;
  style: Record<string, unknown>;
}>;

// Type assertion for cytoscape function
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const cytoscapeFn = cytoscape as any;

// Register extensions
cytoscapeFn.use(fcose);
cytoscapeFn.use(svg);

/**
 * Options for the useCytoscape composable
 */
export interface CytoscapeOptions {
  /** Ref to the container HTML element */
  container: Ref<HTMLElement | null>;
  /** Initial elements to render */
  elements?: ElementDefinition[];
  /** Callback when a node is clicked */
  onNodeClick?: (nodeId: string, nodeData: Record<string, unknown>) => void;
}

/**
 * State and controls returned by the composable
 */
export interface CytoscapeState {
  /** Getter function for the Cytoscape instance (use sparingly) */
  cy: () => Core | null;
  /** Whether the Cytoscape instance is initialized */
  isInitialized: Ref<boolean>;
  /** Whether the graph is currently loading/laying out */
  isLoading: Ref<boolean>;
  /** Initialize the Cytoscape instance */
  initializeCytoscape: () => void;
  /** Update the graph elements and re-run layout */
  updateElements: (elements: ElementDefinition[]) => void;
  /** Fit the graph to the viewport */
  fitToScreen: () => void;
  /** Reset the layout (re-run fcose) */
  resetLayout: () => void;
  /** Zoom in */
  zoomIn: () => void;
  /** Zoom out */
  zoomOut: () => void;
  /** Export graph as PNG data URL */
  exportPNG: () => string;
  /** Export graph as SVG string */
  exportSVG: () => string;
}

/**
 * Get Cytoscape.js style configuration - PERFORMANCE OPTIMIZED
 *
 * CRITICAL: This style is optimized for large graphs (10k+ elements)
 * Following Cytoscape.js performance best practices:
 * - NO function-based styles (use data() mappings instead)
 * - Haystack edges (straight lines, 10x faster than bezier)
 * - No labels by default (shown on zoom/hover)
 * - Opaque edges (faster than semitransparent)
 * - No text-outline (expensive)
 *
 * @see https://js.cytoscape.org/#performance
 */
function getCytoscapeStyle(): CytoscapeStylesheet {
  return [
    {
      selector: 'node',
      style: {
        // PERFORMANCE: Use data() mapping instead of function
        // Node size pre-computed on server/client as 'size' data property
        width: 'data(size)',
        height: 'data(size)',
        'background-color': 'data(color)',
        // PERFORMANCE: Hide labels by default (expensive to render)
        label: '',
        // PERFORMANCE: Simple border, no outline
        'border-width': 1,
        'border-color': '#666',
      },
    },
    {
      selector: 'edge',
      style: {
        // PERFORMANCE: haystack edges are 10x faster than bezier
        'curve-style': 'haystack',
        'haystack-radius': 0.5,
        // PERFORMANCE: Use data() mapping for width
        width: 'data(width)',
        'line-color': '#aaa',
        // PERFORMANCE: Opaque edges are 2x faster than semitransparent
        opacity: 1,
      },
    },
    {
      // Show labels on hover/select
      selector: 'node:selected, node.highlighted',
      style: {
        label: 'data(symbol)',
        'font-size': '12px',
        'text-valign': 'center',
        'text-halign': 'center',
        color: '#000',
        'text-background-color': '#fff',
        'text-background-opacity': 0.8,
        'text-background-padding': '2px',
        'border-color': '#ff0',
        'border-width': 3,
        'z-index': 999,
      },
    },
    {
      selector: 'edge.highlighted',
      style: {
        'line-color': '#ff0',
        width: 3,
      },
    },
    {
      selector: 'node.dimmed',
      style: {
        opacity: 0.2,
      },
    },
    {
      selector: 'edge.dimmed',
      style: {
        opacity: 0.1,
      },
    },
    {
      // Minimum zoom level to show labels (performance)
      selector: 'node[?showLabel]',
      style: {
        label: 'data(symbol)',
        'font-size': '10px',
      },
    },
  ];
}

/**
 * Composable for managing Cytoscape.js lifecycle
 *
 * @param options - Configuration options including container ref and callbacks
 * @returns State and control functions for the Cytoscape instance
 *
 * @example
 * ```typescript
 * const cytoscapeContainer = ref<HTMLElement | null>(null);
 *
 * const {
 *   isInitialized,
 *   initializeCytoscape,
 *   updateElements,
 *   exportPNG,
 * } = useCytoscape({
 *   container: cytoscapeContainer,
 *   onNodeClick: (nodeId) => router.push(`/Entities/${nodeId}`),
 * });
 *
 * onMounted(() => {
 *   initializeCytoscape();
 * });
 * ```
 */
export function useCytoscape(options: CytoscapeOptions): CytoscapeState {
  // CRITICAL: Store Cytoscape instance in non-reactive variable
  // Using ref() would cause Vue reactivity to trigger layout recalculations
  // on every graph mutation (100 renders instead of 1)
  let cy: Core | null = null;

  // Reactive state for UI binding
  const isInitialized = ref(false);
  const isLoading = ref(false);

  /**
   * Initialize the Cytoscape instance
   */
  const initializeCytoscape = (): void => {
    if (!options.container.value) {
      console.warn('useCytoscape: container not available');
      return;
    }

    // Clean up existing instance if any
    if (cy) {
      cy.destroy();
      cy = null;
    }

    isLoading.value = true;
    console.log('[useCytoscape] Initializing with', options.elements?.length || 0, 'elements');
    const startTime = performance.now();

    cy = cytoscapeFn({
      container: options.container.value,
      elements: options.elements || [],

      // Style configuration - PERFORMANCE OPTIMIZED
      style: getCytoscapeStyle(),

      // PERFORMANCE: Use 'preset' layout - positions pre-computed server-side
      // This eliminates expensive client-side layout computation entirely
      // fcose/cose with 66k edges would take 30+ seconds and block the UI
      layout: {
        name: 'preset',  // Uses position property from each node
        fit: true,
        padding: 50,
      },

      // WebGL renderer for 10x performance on large graphs
      // Cytoscape 3.31+ supports this
      renderer: {
        name: 'canvas',
        webgl: true,  // Enable GPU acceleration
      },

      // PERFORMANCE OPTIMIZATIONS for large graphs
      hideEdgesOnViewport: true,  // Hide edges during pan/zoom
      textureOnViewport: true,    // Cache as texture during interaction
      pixelRatio: 1,              // Don't double pixels on retina
      motionBlur: false,

      // Interaction settings
      userZoomingEnabled: true,
      userPanningEnabled: true,
      boxSelectionEnabled: false,
    });

    const elapsed = performance.now() - startTime;
    console.log(`[useCytoscape] Initialized in ${elapsed.toFixed(0)}ms`);

    // Event handlers - node click
    if (options.onNodeClick) {
      cy.on('tap', 'node', (event) => {
        const node = event.target;
        const nodeId = node.id();
        const nodeData = node.data();
        options.onNodeClick!(nodeId, nodeData);
      });
    }

    // Hover highlighting - user decision: dim other nodes, show connections
    cy.on('mouseover', 'node', (event) => {
      if (!cy) return;
      const node = event.target;

      // Highlight the hovered node
      node.addClass('highlighted');

      // Highlight connected edges
      node.connectedEdges().addClass('highlighted');

      // Highlight neighbor nodes
      const neighbors = node.neighborhood('node');
      neighbors.addClass('highlighted');

      // Dim all other nodes and edges
      cy.elements().not(node).not(neighbors).not(node.connectedEdges()).addClass('dimmed');
    });

    cy.on('mouseout', 'node', () => {
      if (!cy) return;
      // Clear all highlights
      cy.elements().removeClass('highlighted dimmed');
    });

    // Layout complete handler
    cy.on('layoutstop', () => {
      isLoading.value = false;
    });

    isInitialized.value = true;

    // If no elements, loading is complete
    if (!options.elements || options.elements.length === 0) {
      isLoading.value = false;
    }
  };

  /**
   * Update the graph elements - PERFORMANCE OPTIMIZED
   *
   * Uses 'preset' layout since positions are pre-computed server-side.
   * This avoids expensive client-side layout computation.
   */
  const updateElements = (elements: ElementDefinition[]): void => {
    if (!cy) {
      console.warn('useCytoscape: cannot update elements, cy not initialized');
      return;
    }

    console.log(`[useCytoscape] Updating with ${elements.length} elements`);
    const startTime = performance.now();
    isLoading.value = true;

    // Remove existing elements
    cy.elements().remove();

    // Add new elements (positions already included from server)
    cy.add(elements);

    // PERFORMANCE: Use 'preset' layout - positions pre-computed server-side
    // No layout computation needed, just fit to viewport
    const layout = cy.layout({
      name: 'preset',
      fit: true,
      padding: 50,
    });

    layout.run();

    const elapsed = performance.now() - startTime;
    console.log(`[useCytoscape] Update complete in ${elapsed.toFixed(0)}ms`);
    isLoading.value = false;
  };

  /**
   * Fit the graph to the viewport
   */
  const fitToScreen = (): void => {
    if (!cy) return;
    cy.fit(undefined, 50); // 50px padding
  };

  /**
   * Reset the layout - re-runs preset layout and fits to viewport
   *
   * NOTE: For large graphs, we use the pre-computed server-side positions.
   * Running fcose on 60k+ edges would freeze the browser.
   */
  const resetLayout = (): void => {
    if (!cy) return;

    console.log('[useCytoscape] Resetting layout');
    isLoading.value = true;

    // Just re-run preset layout and fit to viewport
    // The positions are already computed server-side
    const layout = cy.layout({
      name: 'preset',
      fit: true,
      padding: 50,
    });

    layout.run();
    isLoading.value = false;
  };

  /**
   * Zoom in
   */
  const zoomIn = (): void => {
    if (!cy) return;
    const currentZoom = cy.zoom();
    cy.zoom({
      level: currentZoom * 1.2,
      renderedPosition: { x: cy.width() / 2, y: cy.height() / 2 },
    });
  };

  /**
   * Zoom out
   */
  const zoomOut = (): void => {
    if (!cy) return;
    const currentZoom = cy.zoom();
    cy.zoom({
      level: currentZoom / 1.2,
      renderedPosition: { x: cy.width() / 2, y: cy.height() / 2 },
    });
  };

  /**
   * Export graph as PNG data URL
   */
  const exportPNG = (): string => {
    if (!cy) return '';
    return cy.png({
      output: 'base64uri',
      full: true, // Export entire graph, not just viewport
      scale: 2, // 2x resolution for clarity
      bg: '#ffffff', // White background
    });
  };

  /**
   * Export graph as SVG string
   * Requires cytoscape-svg extension
   */
  const exportSVG = (): string => {
    if (!cy) return '';
    // cytoscape-svg adds svg() method to cy instance
    return (cy as Core & { svg: (options?: { full?: boolean }) => string }).svg({ full: true });
  };

  // CRITICAL: Cleanup to prevent memory leaks
  // Each Cytoscape instance retains 100-300MB
  onBeforeUnmount(() => {
    if (cy) {
      cy.destroy();
      cy = null;
    }
  });

  return {
    cy: () => cy, // Getter to avoid exposing mutable reference
    isInitialized,
    isLoading,
    initializeCytoscape,
    updateElements,
    fitToScreen,
    resetLayout,
    zoomIn,
    zoomOut,
    exportPNG,
    exportSVG,
  };
}

export default useCytoscape;
