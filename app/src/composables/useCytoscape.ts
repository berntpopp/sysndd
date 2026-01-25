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
 * Style configuration based on user decisions from CONTEXT.md:
 * - Node sizing by degree (connection count)
 * - Cluster colors via data(color) property
 * - Edge width from confidence score
 * - Highlighted state for hover interactions
 */
function getCytoscapeStyle(): CytoscapeStylesheet {
  return [
    {
      selector: 'node',
      style: {
        label: 'data(symbol)',
        'background-color': 'data(color)',
        // Node sizing by degree - user decision: more connected genes appear larger
        width: (ele: NodeSingular) => Math.max(30, Math.sqrt(ele.data('degree') || 1) * 10),
        height: (ele: NodeSingular) => Math.max(30, Math.sqrt(ele.data('degree') || 1) * 10),
        'font-size': '11px',
        'text-valign': 'center',
        'text-halign': 'center',
        'border-width': 2,
        'border-color': '#333',
        color: '#000',
        'text-outline-width': 2,
        'text-outline-color': '#fff',
      },
    },
    {
      selector: 'edge',
      style: {
        // Edge width from STRING confidence - user decision: thicker = higher confidence
        width: (ele: NodeSingular) => Math.max(1, (ele.data('confidence') || 0.4) * 5),
        'line-color': '#999',
        'curve-style': 'bezier',
        opacity: 0.6,
      },
    },
    {
      selector: 'node.highlighted',
      style: {
        'border-color': '#ff0',
        'border-width': 4,
        'z-index': 999,
      },
    },
    {
      selector: 'edge.highlighted',
      style: {
        'line-color': '#ff0',
        width: 3,
        opacity: 1,
      },
    },
    {
      selector: 'node.dimmed',
      style: {
        opacity: 0.3,
      },
    },
    {
      selector: 'edge.dimmed',
      style: {
        opacity: 0.15,
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

    cy = cytoscapeFn({
      container: options.container.value,
      elements: options.elements || [],

      // Style configuration
      style: getCytoscapeStyle(),

      // Layout configuration - fcose for force-directed layout
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      layout: {
        name: 'fcose',
        quality: 'default',
        animate: true,
        animationDuration: 1500,
        animationEasing: 'ease-out-cubic',
        randomize: false,
        nodeDimensionsIncludeLabels: true,
        // Force-separate clusters naturally - user decision
        idealEdgeLength: 100,
        nodeRepulsion: 4500,
        edgeElasticity: 0.45,
      } as any,

      // Performance optimizations
      hideEdgesOnViewport: true, // Hide edges during pan/zoom for smooth interactions
      textureOnViewport: false,
      pixelRatio: 1, // Prevent 2-3x cost on high DPI displays
      motionBlur: false,

      // Interaction settings
      userZoomingEnabled: true,
      userPanningEnabled: true,
      boxSelectionEnabled: false,
    });

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
   * Update the graph elements and re-run layout
   */
  const updateElements = (elements: ElementDefinition[]): void => {
    if (!cy) {
      console.warn('useCytoscape: cannot update elements, cy not initialized');
      return;
    }

    isLoading.value = true;

    // Remove existing elements
    cy.elements().remove();

    // Add new elements
    cy.add(elements);

    // Run layout - user decision: data changes trigger full layout re-run
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const layout = cy.layout({
      name: 'fcose',
      animate: true,
      animationDuration: 1500,
      idealEdgeLength: 100,
      nodeRepulsion: 4500,
      edgeElasticity: 0.45,
      nodeDimensionsIncludeLabels: true,
    } as any);

    layout.run();
  };

  /**
   * Fit the graph to the viewport
   */
  const fitToScreen = (): void => {
    if (!cy) return;
    cy.fit(undefined, 50); // 50px padding
  };

  /**
   * Reset the layout (re-run fcose)
   */
  const resetLayout = (): void => {
    if (!cy) return;

    isLoading.value = true;

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const layout = cy.layout({
      name: 'fcose',
      animate: true,
      animationDuration: 1500,
      idealEdgeLength: 100,
      nodeRepulsion: 4500,
      edgeElasticity: 0.45,
      randomize: true, // Randomize for fresh layout
      nodeDimensionsIncludeLabels: true,
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
