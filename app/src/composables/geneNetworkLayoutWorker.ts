// composables/geneNetworkLayoutWorker.ts
//
// Main-thread side of the off-thread network layout. Resolves null when workers are
// unavailable (tests, old browsers) or the layout fails, so the caller falls back to
// the in-page fCoSE layout it used before.

import type { ElementDefinition } from 'cytoscape';
import type { LayoutPosition } from './geneNetworkLayoutOptions';

export function computeLayoutInWorker(
  elements: ElementDefinition[]
): Promise<Map<string, LayoutPosition> | null> {
  if (typeof Worker === 'undefined') return Promise.resolve(null);
  return new Promise((resolve) => {
    let worker: Worker;
    try {
      worker = new Worker(new URL('./geneNetworkLayout.worker.ts', import.meta.url), {
        type: 'module',
      });
    } catch {
      resolve(null);
      return;
    }
    const finish = (positions: Map<string, LayoutPosition> | null) => {
      worker.terminate();
      resolve(positions);
    };
    worker.onmessage = (event) => {
      const { positions } = event.data ?? {};
      finish(
        positions ? new Map(Object.entries(positions as Record<string, LayoutPosition>)) : null
      );
    };
    worker.onerror = () => finish(null);
    worker.postMessage(elements);
  });
}
