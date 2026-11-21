import { describe, expect, it } from 'vitest';
import type { ElementDefinition } from 'cytoscape';
import { runHeadlessLayout } from './geneNetworkHeadlessLayout';

describe('runHeadlessLayout', () => {
  it('places every gene node (not the cluster parents) at a finite position', () => {
    const genes = ['A', 'B', 'C', 'D'];
    const elements: ElementDefinition[] = [
      { data: { id: 'cluster-1', isClusterParent: true } },
      { data: { id: 'cluster-2', isClusterParent: true } },
      ...genes.map((id, i) => ({ data: { id, parent: `cluster-${(i % 2) + 1}`, size: 20 } })),
      { data: { id: 'e1', source: 'A', target: 'B', width: 1 } },
      { data: { id: 'e2', source: 'C', target: 'D', width: 1 } },
    ];
    const positions = runHeadlessLayout(elements);
    expect(Object.keys(positions).sort()).toEqual(genes);
    Object.values(positions).forEach(({ x, y }) => {
      expect(Number.isFinite(x) && Number.isFinite(y)).toBe(true);
    });
    // a real layout spreads the nodes rather than stacking them at the origin
    expect(
      new Set(Object.values(positions).map((p) => `${Math.round(p.x)},${Math.round(p.y)}`)).size
    ).toBe(4);
  });
});
