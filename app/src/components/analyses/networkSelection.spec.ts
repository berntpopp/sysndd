import { describe, expect, it } from 'vitest';

import {
  addNetworkCluster,
  removeNetworkCluster,
  selectSingleNetworkCluster,
  showAllNetworkClusters,
} from './networkSelection';

describe('networkSelection', () => {
  it('selects one cluster and leaves all-clusters mode', () => {
    expect(selectSingleNetworkCluster(3)).toEqual({
      selectedClusters: new Set([3]),
      showAllClusters: false,
    });
  });

  it('adds clusters to a multi-selection', () => {
    expect(addNetworkCluster(new Set([1]), 2)).toEqual({
      selectedClusters: new Set([1, 2]),
      showAllClusters: false,
    });
  });

  it('returns to all-clusters mode when the final selected cluster is removed', () => {
    expect(removeNetworkCluster(new Set([2]), 2)).toEqual({
      selectedClusters: new Set<number>(),
      showAllClusters: true,
    });
  });

  it('clears selections when all-clusters mode is enabled', () => {
    expect(showAllNetworkClusters(true, new Set([1, 2]))).toEqual({
      selectedClusters: new Set<number>(),
      showAllClusters: true,
    });
    expect(showAllNetworkClusters(false, new Set([1, 2]))).toEqual({
      selectedClusters: new Set([1, 2]),
      showAllClusters: false,
    });
  });
});
