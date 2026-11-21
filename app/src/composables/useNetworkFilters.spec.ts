import { describe, expect, it } from 'vitest';
import cytoscape from 'cytoscape';
import { useNetworkFilters } from './useNetworkFilters';
import { CLUSTER_BOX_MARGIN } from './geneNetworkLayoutOptions';

// Plain cluster boxes (stored positions) must track their visible genes the way
// compound parents do, and disappear when none of their genes is shown.
function flatNetwork() {
  return cytoscape({
    headless: true,
    styleEnabled: true,
    layout: { name: 'preset' },
    elements: [
      { data: { id: 'cluster-1', isClusterParent: true, boxWidth: 0, boxHeight: 0 } },
      { data: { id: 'cluster-2', isClusterParent: true, boxWidth: 0, boxHeight: 0 } },
      {
        data: { id: 'A', cluster: '1', category: 'Definitive', size: 20 },
        position: { x: 0, y: 0 },
      },
      {
        data: { id: 'B', cluster: '1.2', category: 'Moderate', size: 20 },
        position: { x: 100, y: 50 },
      },
      {
        data: { id: 'C', cluster: '2', category: 'Moderate', size: 20 },
        position: { x: 500, y: 0 },
      },
    ],
  });
}

describe('useNetworkFilters cluster boxes', () => {
  it('sizes each box to its visible genes and hides boxes without any', () => {
    const cy = flatNetwork();
    const filters = useNetworkFilters();

    filters.applyFilters(cy); // Definitive only: A
    const box = cy.getElementById('cluster-1');
    expect(box.position()).toEqual({ x: 0, y: 0 });
    expect(box.data('boxWidth')).toBe(20 + 2 * CLUSTER_BOX_MARGIN);
    expect(cy.getElementById('cluster-2').visible()).toBe(false);

    filters.categoryLevel.value = 'Moderate'; // A and B (sub-cluster 1.2 belongs to box 1)
    filters.applyFilters(cy);
    expect(box.position()).toEqual({ x: 50, y: 25 });
    expect(box.data('boxWidth')).toBe(120 + 2 * CLUSTER_BOX_MARGIN);
    expect(box.data('boxHeight')).toBe(70 + 2 * CLUSTER_BOX_MARGIN);
    expect(cy.getElementById('cluster-2').visible()).toBe(true);
    cy.destroy();
  });
});
