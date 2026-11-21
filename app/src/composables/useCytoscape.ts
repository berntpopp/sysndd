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
  CLUSTER_BOX_MARGIN,
  collectPresetPositions,
  initialFcoseLayoutOptions,
  LABEL_MIN_ZOOM,
  presetLayoutOptions,
  shouldUsePresetLayout,
  updateFcoseLayoutOptions,
} from './geneNetworkLayoutOptions';
import { getCytoscapeStyle } from './cytoscape-style';

/**
 * Fit the viewport to the visible genes and their cluster boxes. cy.fit() measures the
 * bounding box of every element (labels, edges), ~100 ms for the full network; the gene
 * positions and sizes give the same frame for a fraction of that.
 */
function fitToGenes(cy: Core, padding = 30): void {
  let [x1, y1, x2, y2] = [Infinity, Infinity, -Infinity, -Infinity];
  cy.nodes().forEach((node) => {
    if (node.data('isClusterParent') || !node.visible()) return;
    const { x, y } = node.position();
    const r = (Number(node.data('size')) || 0) / 2 + CLUSTER_BOX_MARGIN;
    [x1, y1, x2, y2] = [
      Math.min(x1, x - r),
      Math.min(y1, y - r),
      Math.max(x2, x + r),
      Math.max(y2, y + r),
    ];
  });
  const zoom = Math.min(
    (cy.width() - 2 * padding) / (x2 - x1),
    (cy.height() - 2 * padding) / (y2 - y1)
  );
  if (!Number.isFinite(zoom) || zoom <= 0) return;
  cy.viewport({
    zoom,
    pan: { x: (cy.width() - zoom * (x1 + x2)) / 2, y: (cy.height() - zoom * (y1 + y2)) / 2 },
  });
}

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
  let labelsShown = false;
  let pendingEdges: ElementDefinition[] = [];

  // The WebGL renderer ignores min-zoomed-font-size and measures and draws every label on
  // every frame, about half the drawing cost; labels exist only from the legible zoom.
  const syncLabels = (force = false): void => {
    if (!cy) return;
    const show = cy.zoom() >= LABEL_MIN_ZOOM;
    if (show === labelsShown && !force) return;
    labelsShown = show;
    cy.nodes('[!isClusterParent]').toggleClass('labelled', show);
  };

  /** Render with every gene label (exports are drawn at a legible scale). */
  const withAllLabels = <T>(render: (core: Core) => T): T => {
    const core = cy as Core;
    core.add(pendingEdges.splice(0)); // edges still queued for the first frames
    const genes = core.nodes('[!isClusterParent]');
    genes.addClass('labelled');
    try {
      return render(core);
    } finally {
      if (!labelsShown) genes.removeClass('labelled');
    }
  };

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

  const fitAndReportLayoutReady = (cycle = layoutReadyCycle, fit = true): void => {
    if (!cy) return;
    if (cycle !== layoutReadyCycle || reportedLayoutReadyCycle === cycle) return;

    reportedLayoutReadyCycle = cycle;

    cy.resize();
    if (fit) fitToGenes(cy);

    console.log(
      `[useCytoscape] Layout complete: ${cy.nodes().length} nodes, zoom=${cy.zoom().toFixed(3)}`
    );
    options.onLayoutReady?.();
  };

  // With stored positions every node mounts at once (filters and framing are exact) and the
  // edges follow in frame-sized batches: each frame stays a short task, where mounting the
  // whole network in one go blocks the page for several hundred ms.
  const EDGE_BATCH = 500;
  const addPendingEdges = (cycle: number): void => {
    if (!cy || cycle !== layoutReadyCycle) return;
    cy.add(pendingEdges.splice(0, EDGE_BATCH));
    if (pendingEdges.length > 0) {
      requestAnimationFrame(() => addPendingEdges(cycle));
    } else {
      // framed before the first paint; the user may have zoomed while edges arrived
      fitAndReportLayoutReady(cycle, false);
    }
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
    pendingEdges = lastUsedPreset ? initialElements.filter((el) => el.data?.source) : [];

    cy = cytoscapeFn({
      container: options.container.value,
      elements: pendingEdges.length
        ? initialElements.filter((el) => !el.data?.source)
        : initialElements,

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

    // Frame the stored positions before the first paint, so it is drawn once and in place.
    if (lastUsedPreset) fitToGenes(cy);
    labelsShown = false;
    syncLabels(true);
    cy.on('zoom', () => syncLabels());

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

    if (pendingEdges.length > 0) {
      const cycle = layoutReadyCycle;
      requestAnimationFrame(() => addPendingEdges(cycle));
    } else if (initialElements.length > 0) {
      scheduleFitAndReportLayoutReady();
    }

    isInitialized.value = true;
    // The constructor's layout (preset, or fcose without animation) has already run: its
    // layoutstop fired before the listener above existed.
    isLoading.value = false;
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
    syncLabels(true);

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
    fitToGenes(cy);
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
    return withAllLabels((core) =>
      core.png({
        output: 'base64uri',
        full: true, // Export entire graph, not just viewport
        scale: 2, // 2x resolution for clarity
        bg: '#ffffff', // White background
      })
    );
  };

  /**
   * Export graph as SVG string
   * Requires cytoscape-svg extension
   */
  const exportSVG = (): string => {
    if (!cy) return '';
    // cytoscape-svg adds svg() method to cy instance
    return withAllLabels((core) =>
      (core as Core & { svg: (options?: { full?: boolean }) => string }).svg({ full: true })
    );
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
