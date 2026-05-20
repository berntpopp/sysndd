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
