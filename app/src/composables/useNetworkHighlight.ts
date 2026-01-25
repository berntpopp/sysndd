// composables/useNetworkHighlight.ts

/**
 * @fileoverview Composable for bidirectional network-table hover highlighting
 *
 * Coordinates hover interactions between network visualization (Cytoscape.js)
 * and data tables, enabling bidirectional highlighting:
 * - Hover on table row -> highlight corresponding network node
 * - Hover on network node -> highlight corresponding table row
 *
 * CRITICAL: Implements source tracking to prevent feedback loops
 * (see RESEARCH.md pitfall #4). When one view initiates a hover,
 * the other view only responds if it wasn't the initiator.
 *
 * @example
 * ```typescript
 * import { useCytoscape, useNetworkHighlight } from '@/composables';
 *
 * // In component setup
 * const { cy } = useCytoscape({ container: containerRef });
 * const {
 *   highlightState,
 *   setupNetworkListeners,
 *   highlightNodeFromTable,
 *   clearHighlights,
 *   isRowHighlighted,
 * } = useNetworkHighlight(cy);
 *
 * // After Cytoscape initializes
 * onMounted(() => {
 *   setupNetworkListeners();
 * });
 *
 * // In table row hover handler
 * const onRowHover = (rowId: string | null) => {
 *   highlightNodeFromTable(rowId);
 * };
 *
 * // In table row template
 * <tr :class="{ 'row-highlighted': isRowHighlighted(row.hgnc_id) }">
 * ```
 */

import { ref, watch, type Ref } from 'vue';
import type { Core, NodeSingular } from 'cytoscape';

/**
 * Source of the hover interaction
 * Used to prevent feedback loops
 */
export type HoverSource = 'table' | 'network' | null;

/**
 * State tracking for bidirectional highlighting
 */
export interface HighlightState {
  /** ID of node currently hovered in network (null if none) */
  hoveredNodeId: string | null;
  /** ID of row currently hovered in table (null if none) */
  hoveredRowId: string | null;
  /** Which view initiated the current hover (null if no active hover) */
  hoverSource: HoverSource;
}

/**
 * Return type for the useNetworkHighlight composable
 */
export interface NetworkHighlightReturn {
  /** Reactive highlight state */
  highlightState: Ref<HighlightState>;
  /** Setup event listeners on Cytoscape instance */
  setupNetworkListeners: () => void;
  /** Highlight a node from table hover (call on table row mouseenter) */
  highlightNodeFromTable: (nodeId: string | null) => void;
  /** Clear all highlights (call on mouseleave) */
  clearHighlights: () => void;
  /** Check if a table row should be highlighted */
  isRowHighlighted: (rowId: string) => boolean;
  /** Cleanup function for removing listeners */
  cleanup: () => void;
}

/**
 * CSS classes applied during highlighting
 */
const CSS_CLASSES = {
  /** Applied to hovered node */
  HOVER_HIGHLIGHT: 'hover-highlight',
  /** Applied to neighbors of hovered node */
  NEIGHBOR_HIGHLIGHT: 'neighbor-highlight',
  /** Applied to node highlighted from table hover */
  TABLE_HOVER_HIGHLIGHT: 'table-hover-highlight',
  /** Applied to dimmed (non-highlighted) elements */
  DIMMED: 'dimmed',
} as const;

/**
 * Composable for bidirectional network-table hover highlighting
 *
 * @param cyGetter - Function returning the Cytoscape instance (from useCytoscape)
 * @returns Highlight state and control functions
 */
export function useNetworkHighlight(
  cyGetter: () => Core | null
): NetworkHighlightReturn {
  /**
   * Reactive highlight state
   * Tracks which element is hovered and who initiated
   */
  const highlightState = ref<HighlightState>({
    hoveredNodeId: null,
    hoveredRowId: null,
    hoverSource: null,
  });

  /**
   * References to event handler functions for cleanup
   */
  let mouseoverHandler: ((event: { target: NodeSingular }) => void) | null = null;
  let mouseoutHandler: (() => void) | null = null;

  /**
   * Clear all CSS highlight classes from Cytoscape elements
   */
  const clearCytoscapeHighlights = (): void => {
    const cy = cyGetter();
    if (!cy) return;

    cy.elements().removeClass([
      CSS_CLASSES.HOVER_HIGHLIGHT,
      CSS_CLASSES.NEIGHBOR_HIGHLIGHT,
      CSS_CLASSES.TABLE_HOVER_HIGHLIGHT,
      CSS_CLASSES.DIMMED,
    ].join(' '));
  };

  /**
   * Setup event listeners on Cytoscape instance
   * Should be called after Cytoscape is initialized
   */
  const setupNetworkListeners = (): void => {
    const cy = cyGetter();
    if (!cy) {
      console.warn('[useNetworkHighlight] Cannot setup listeners: cy not available');
      return;
    }

    // Remove existing listeners if any (prevent duplicates)
    cleanup();

    /**
     * Node mouseover handler
     * Only respond if table didn't initiate the hover
     */
    mouseoverHandler = (event: { target: NodeSingular }) => {
      // CRITICAL: Skip if table initiated this hover (prevent loop)
      if (highlightState.value.hoverSource === 'table') {
        return;
      }

      const node = event.target;

      // Skip cluster parent nodes
      if (node.data('isClusterParent')) {
        return;
      }

      const nodeId = node.data('hgnc_id') || node.id();

      // Update state - mark network as source
      highlightState.value.hoverSource = 'network';
      highlightState.value.hoveredNodeId = nodeId;

      // Apply visual highlighting on network
      node.addClass(CSS_CLASSES.HOVER_HIGHLIGHT);
      node.connectedEdges().addClass(CSS_CLASSES.NEIGHBOR_HIGHLIGHT);
      node.neighborhood('node').addClass(CSS_CLASSES.NEIGHBOR_HIGHLIGHT);

      // Dim other elements for focus
      const currentCy = cyGetter();
      if (currentCy) {
        currentCy.elements()
          .not(node)
          .not(node.neighborhood())
          .not(node.connectedEdges())
          .addClass(CSS_CLASSES.DIMMED);
      }
    };

    /**
     * Node mouseout handler
     * Clears all highlights and resets state
     */
    mouseoutHandler = () => {
      // Clear all highlights
      clearCytoscapeHighlights();

      // Reset state
      highlightState.value.hoverSource = null;
      highlightState.value.hoveredNodeId = null;
    };

    // Attach listeners
    cy.on('mouseover', 'node', mouseoverHandler);
    cy.on('mouseout', 'node', mouseoutHandler);
  };

  /**
   * Highlight a node from table hover
   * Call this when user hovers over a table row
   *
   * @param nodeId - ID of the node to highlight (or null to clear)
   */
  const highlightNodeFromTable = (nodeId: string | null): void => {
    const cy = cyGetter();

    // Clear previous highlights
    clearCytoscapeHighlights();

    if (!nodeId) {
      // Clear state when no row hovered
      highlightState.value.hoveredRowId = null;
      highlightState.value.hoverSource = null;
      return;
    }

    // Update state - mark table as source
    highlightState.value.hoverSource = 'table';
    highlightState.value.hoveredRowId = nodeId;

    // Apply highlight on network if available
    if (cy) {
      // Try to find node by hgnc_id first, then by id
      let node = cy.nodes(`[hgnc_id = "${nodeId}"]`);
      if (node.length === 0) {
        node = cy.getElementById(nodeId);
      }

      if (node.length > 0) {
        node.addClass(CSS_CLASSES.TABLE_HOVER_HIGHLIGHT);

        // Also highlight neighbors for context
        node.connectedEdges().addClass(CSS_CLASSES.NEIGHBOR_HIGHLIGHT);
        node.neighborhood('node').addClass(CSS_CLASSES.NEIGHBOR_HIGHLIGHT);

        // Dim other elements
        cy.elements()
          .not(node)
          .not(node.neighborhood())
          .not(node.connectedEdges())
          .addClass(CSS_CLASSES.DIMMED);
      }
    }
  };

  /**
   * Clear all highlights and reset state
   */
  const clearHighlights = (): void => {
    clearCytoscapeHighlights();
    highlightState.value = {
      hoveredNodeId: null,
      hoveredRowId: null,
      hoverSource: null,
    };
  };

  /**
   * Check if a table row should be highlighted
   * Returns true if network is hovering over corresponding node
   *
   * @param rowId - Row ID to check
   * @returns true if row should show highlight styling
   */
  const isRowHighlighted = (rowId: string): boolean => {
    // Only highlight from network-initiated hovers
    // (Table-initiated don't need additional row styling)
    return (
      highlightState.value.hoverSource === 'network' &&
      highlightState.value.hoveredNodeId === rowId
    );
  };

  /**
   * Cleanup function for removing listeners
   * Should be called on component unmount or before re-setup
   */
  const cleanup = (): void => {
    const cy = cyGetter();
    if (!cy) return;

    if (mouseoverHandler) {
      cy.off('mouseover', 'node', mouseoverHandler as unknown as (event: unknown) => void);
      mouseoverHandler = null;
    }

    if (mouseoutHandler) {
      cy.off('mouseout', 'node', mouseoutHandler);
      mouseoutHandler = null;
    }
  };

  return {
    highlightState,
    setupNetworkListeners,
    highlightNodeFromTable,
    clearHighlights,
    isRowHighlighted,
    cleanup,
  };
}

export default useNetworkHighlight;
