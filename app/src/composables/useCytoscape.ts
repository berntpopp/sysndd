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
 * Get Cytoscape.js style configuration
 *
 * Balanced between visibility and performance for 10k edge graphs.
 */
function getCytoscapeStyle(): CytoscapeStylesheet {
  return [
    {
      selector: 'node',
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
        'border-color': '#e74c3c',
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

      // Style configuration
      style: getCytoscapeStyle(),

      // fcose layout for proper force-directed network visualization
      // Using animate: false for reliable fit/center (per GitHub issue #2559)
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      layout: {
        name: 'fcose',
        quality: 'default',
        randomize: true,
        // CRITICAL: animate: false ensures synchronous layout for reliable fit
        animate: false,
        nodeDimensionsIncludeLabels: false,
        // fit and padding for proper centering
        fit: true,
        padding: 30,
        // Cluster separation
        idealEdgeLength: 80,
        nodeRepulsion: 8000,
        edgeElasticity: 0.45,
        nestingFactor: 0.1,
        gravity: 0.25,
        gravityRange: 3.8,
        // Performance
        numIter: 2500,
        tile: true,
        tilingPaddingVertical: 10,
        tilingPaddingHorizontal: 10,
      } as any,

      // WebGL renderer for better performance
      renderer: {
        name: 'canvas',
        webgl: true,
      },

      // Performance optimizations
      hideEdgesOnViewport: true,
      textureOnViewport: true,
      pixelRatio: 1,
      motionBlur: false,

      // Interaction
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
    // Use cy.fit() for reliable centering after layout completes
    cy.on('layoutstop', () => {
      if (cy) {
        // Small delay to ensure DOM is updated
        setTimeout(() => {
          if (!cy) return;

          // Force resize to pick up any container dimension changes
          cy.resize();

          // Use Cytoscape's built-in fit which handles centering correctly
          // Padding ensures the graph doesn't touch edges
          cy.fit(undefined, 30);

          // Log for debugging
          const bb = cy.elements().boundingBox();
          console.log(`[useCytoscape] Layout complete: ${cy.nodes().length} nodes, bb=${bb.w.toFixed(0)}x${bb.h.toFixed(0)}, zoom=${cy.zoom().toFixed(3)}`);
        }, 50);
      }
      isLoading.value = false;
    });

    isInitialized.value = true;

    // If no elements, loading is complete
    if (!options.elements || options.elements.length === 0) {
      isLoading.value = false;
    }
  };

  /**
   * Update the graph elements and run fcose layout
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

    // Add new elements
    cy.add(elements);

    // Run fcose layout for proper force-directed visualization
    // Using animate: false for reliable fit/center (per GitHub issue #2559)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const layout = cy.layout({
      name: 'fcose',
      quality: 'default',
      randomize: true,
      animate: false,
      fit: true,
      padding: 30,
      idealEdgeLength: 80,
      nodeRepulsion: 8000,
      edgeElasticity: 0.45,
      gravity: 0.25,
      numIter: 2500,
    } as any);

    layout.run();

    const elapsed = performance.now() - startTime;
    console.log(`[useCytoscape] Update started in ${elapsed.toFixed(0)}ms (layout animating)`);
  };

  /**
   * Fit the graph to the viewport and center it
   */
  const fitToScreen = (): void => {
    if (!cy) return;

    // Force resize to pick up container dimension changes
    cy.resize();

    // Use Cytoscape's built-in fit for reliable centering
    cy.fit(undefined, 30);
  };

  /**
   * Reset the layout - re-runs fcose layout
   */
  const resetLayout = (): void => {
    if (!cy) return;

    console.log('[useCytoscape] Resetting layout');
    isLoading.value = true;

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const layout = cy.layout({
      name: 'fcose',
      quality: 'default',
      randomize: true,
      animate: false,
      fit: true,
      padding: 30,
      idealEdgeLength: 80,
      nodeRepulsion: 8000,
      edgeElasticity: 0.45,
      gravity: 0.25,
      numIter: 2500,
    } as any);

    layout.run();
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
