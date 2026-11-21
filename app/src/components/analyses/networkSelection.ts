import type { Collection, Core } from 'cytoscape';

export interface NetworkClusterSelection {
  selectedClusters: Set<number>;
  showAllClusters: boolean;
}

export function selectSingleNetworkCluster(clusterId: number): NetworkClusterSelection {
  return {
    selectedClusters: new Set([clusterId]),
    showAllClusters: false,
  };
}

export function addNetworkCluster(
  currentSelection: Set<number>,
  clusterId: number
): NetworkClusterSelection {
  const selectedClusters = new Set(currentSelection);
  selectedClusters.add(clusterId);
  return {
    selectedClusters,
    showAllClusters: false,
  };
}

export function removeNetworkCluster(
  currentSelection: Set<number>,
  clusterId: number
): NetworkClusterSelection {
  const selectedClusters = new Set(currentSelection);
  selectedClusters.delete(clusterId);

  return {
    selectedClusters,
    showAllClusters: selectedClusters.size === 0,
  };
}

export function showAllNetworkClusters(
  showAllClusters: boolean,
  currentSelection: Set<number>
): NetworkClusterSelection {
  return {
    selectedClusters: showAllClusters ? new Set<number>() : new Set(currentSelection),
    showAllClusters,
  };
}

/**
 * Gently pan and zoom to frame the given nodes: zoom is capped at 1.5x so a
 * single match never fills the screen, and 150 px padding keeps the framing loose.
 */
export function focusNetworkNodes(cy: Core, nodes: Collection): void {
  const bb = nodes.boundingBox();
  const padding = 150;
  const width = cy.width();
  const height = cy.height();
  const zoom = Math.min(width / (bb.w + padding * 2), height / (bb.h + padding * 2), 1.5);
  cy.animate({
    pan: {
      x: width / 2 - ((bb.x1 + bb.x2) / 2) * zoom,
      y: height / 2 - ((bb.y1 + bb.y2) / 2) * zoom,
    },
    zoom,
    duration: 400,
    easing: 'ease-out-cubic',
  });
}
