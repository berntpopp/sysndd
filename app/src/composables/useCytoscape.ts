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

import cytoscape from 'cytoscape';
import type { Core, ElementDefinition } from 'cytoscape';
import fcose from 'cytoscape-fcose';
import svg from 'cytoscape-svg';
import {
  collectPresetPositions,
  initialFcoseLayoutOptions,
  presetLayoutOptions,
  shouldUsePresetLayout,
  updateFcoseLayoutOptions,
} from './geneNetworkLayoutOptions';

// Cytoscape.js style type (simplified for our use case)
type CytoscapeStylesheet = Array<{
  selector: string;
  style: Record<string, unknown>;
}>;

function restorePresetPositions(cy: Core, elements: ElementDefinition[]): void {
  for (const [nodeId, position] of collectPresetPositions(elements)) {
    cy.getElementById(nodeId).position(position);
  }
}

// Type assertion for cytoscape function
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const cytoscapeFn = cytoscape as any;

// Register extensions once using global flag to handle HMR and multiple composables
if (!(globalThis as Record<string, unknown>).__cytoscapeExtensionsRegistered) {
  cytoscapeFn.use(fcose);
  cytoscapeFn.use(svg);
  (globalThis as Record<string, unknown>).__cytoscapeExtensionsRegistered = true;
}

/**
 * Options for the useCytoscape composable
 */
export interface CytoscapeOptions {
  /** Ref to the container HTML element */
  container: Ref<HTMLElement | null>;
  /** Initial elements to render */
  elements?: ElementDefinition[];
  /** Callback when a regular gene node is clicked */
  onNodeClick?: (nodeId: string, nodeData: Record<string, unknown>) => void;
  /** Callback when a compound cluster parent node is clicked */
  onClusterClick?: (clusterId: number, nodeData: Record<string, unknown>) => void;
  /** Callback when the graph background is clicked */
  onBackgroundClick?: () => void;
  /** Callback after layout has stopped, resized, and fitted the viewport */
  onLayoutReady?: () => void;
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
  initializeCytoscape: (elements?: ElementDefinition[]) => void;
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
 * Parse a compound cluster parent node ID from Cytoscape node data.
 */
function parseClusterParentId(nodeId: string, nodeData: Record<string, unknown>): number | null {
  const rawClusterId =
    typeof nodeData.cluster === 'number' || typeof nodeData.cluster === 'string'
      ? nodeData.cluster
      : typeof nodeData.label === 'string'
        ? nodeData.label.replace(/^Cluster\s+/i, '')
        : nodeId.replace(/^cluster-/, '');

  const clusterId = Number.parseInt(String(rawClusterId).split('.')[0], 10);

  return Number.isFinite(clusterId) ? clusterId : null;
}

/**
 * Get Cytoscape.js style configuration
 *
 * Balanced between visibility and performance for 10k edge graphs.
 */
function getCytoscapeStyle(): CytoscapeStylesheet {
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
  let lastElements: ElementDefinition[] = [];
  let lastUsedPreset = false;
  let layoutReadyCycle = 0;
  let reportedLayoutReadyCycle = 0;
  let layoutReadyTimeout: ReturnType<typeof setTimeout> | null = null;

  // Reactive state for UI binding
  const isInitialized = ref(false);
  const isLoading = ref(false);

  const clearLayoutReadyTimeout = (): void => {
    if (layoutReadyTimeout) {
      clearTimeout(layoutReadyTimeout);
      layoutReadyTimeout = null;
    }
  };

  const startLayoutReadyCycle = (): void => {
    layoutReadyCycle += 1;
    clearLayoutReadyTimeout();
  };

  const fitAndReportLayoutReady = (cycle = layoutReadyCycle): void => {
    if (!cy) return;
    if (cycle !== layoutReadyCycle || reportedLayoutReadyCycle === cycle) return;

    reportedLayoutReadyCycle = cycle;

    cy.resize();
    cy.fit(undefined, 30);

    const bb = cy.elements().boundingBox();
    console.log(
      `[useCytoscape] Layout complete: ${cy.nodes().length} nodes, bb=${bb.w.toFixed(0)}x${bb.h.toFixed(0)}, zoom=${cy.zoom().toFixed(3)}`
    );
    options.onLayoutReady?.();
  };

  const scheduleFitAndReportLayoutReady = (): void => {
    const cycle = layoutReadyCycle;
    clearLayoutReadyTimeout();
    layoutReadyTimeout = setTimeout(() => {
      layoutReadyTimeout = null;
      fitAndReportLayoutReady(cycle);
    }, 50);
  };

  /**
   * Initialize the Cytoscape instance
   */
  const initializeCytoscape = (elements?: ElementDefinition[]): void => {
    if (!options.container.value) {
      console.warn('useCytoscape: container not available');
      return;
    }

    // Clean up existing instance if any
    if (cy) {
      clearLayoutReadyTimeout();
      cy.destroy();
      cy = null;
    }

    isLoading.value = true;
    const initialElements = elements || options.elements || [];
    console.log('[useCytoscape] Initializing with', initialElements.length, 'elements');
    const startTime = performance.now();
    lastElements = initialElements;
    lastUsedPreset = shouldUsePresetLayout(lastElements);
    startLayoutReadyCycle();

    cy = cytoscapeFn({
      container: options.container.value,
      elements: initialElements,

      // Style configuration
      style: getCytoscapeStyle(),

      // fcose layout for proper force-directed network visualization
      // Optimized for compound graphs with cluster separation
      // Using animate: false for reliable fit/center (per GitHub issue #2559)

      layout: lastUsedPreset ? presetLayoutOptions() : initialFcoseLayoutOptions(),

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
    if (options.onNodeClick || options.onClusterClick) {
      cy.on('tap', 'node', (event) => {
        const node = event.target;
        const nodeId = node.id();
        const nodeData = node.data();

        if (nodeData.isClusterParent === true) {
          const clusterId = parseClusterParentId(nodeId, nodeData);
          if (clusterId !== null) {
            options.onClusterClick?.(clusterId, nodeData);
          }
          return;
        }

        options.onNodeClick?.(nodeId, nodeData);
      });
    }

    // Event handlers - graph background click
    if (options.onBackgroundClick) {
      cy.on('tap', (event) => {
        if (event.target === cy) {
          options.onBackgroundClick?.();
        }
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
        scheduleFitAndReportLayoutReady();
      }
      isLoading.value = false;
    });

    if (initialElements.length > 0) {
      scheduleFitAndReportLayoutReady();
    }

    isInitialized.value = true;

    // If no elements, loading is complete
    if (initialElements.length === 0) {
      isLoading.value = false;
    }
  };

  /**
   * Update the graph elements and run preset layout when complete positions exist.
   */
  const updateElements = (elements: ElementDefinition[]): void => {
    if (!cy) {
      console.warn('useCytoscape: cannot update elements, cy not initialized');
      return;
    }

    console.log(`[useCytoscape] Updating with ${elements.length} elements`);
    const startTime = performance.now();
    isLoading.value = true;

    cy.batch(() => {
      cy.elements().remove();
      cy.add(elements);
    });

    lastElements = elements;
    lastUsedPreset = shouldUsePresetLayout(elements);
    startLayoutReadyCycle();

    const layout = cy.layout(lastUsedPreset ? presetLayoutOptions() : updateFcoseLayoutOptions());

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
   * Reset the layout - restores preset coordinates when available, otherwise re-runs fcose
   */
  const resetLayout = (): void => {
    if (!cy) return;

    console.log('[useCytoscape] Resetting layout');
    isLoading.value = true;
    lastUsedPreset = shouldUsePresetLayout(lastElements);
    if (lastUsedPreset) {
      restorePresetPositions(cy, lastElements);
    }

    const layout = cy.layout(lastUsedPreset ? presetLayoutOptions() : updateFcoseLayoutOptions());

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
