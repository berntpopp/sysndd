// composables/geneNetworkHeadlessLayout.ts
//
// fCoSE layout of the gene network without a DOM, so it can run in a Web Worker
// (geneNetworkLayout.worker.ts) instead of blocking the main thread for seconds.
// The main thread then renders the result with the cheap preset layout.

import cytoscape from 'cytoscape';
import type { ElementDefinition } from 'cytoscape';
import fcose from 'cytoscape-fcose';
import {
  initialFcoseLayoutOptions,
  isGeneNodeElement,
  type LayoutPosition,
} from './geneNetworkLayoutOptions';
import { getCytoscapeStyle } from './cytoscape-style';

let registered = false;

/** Lay out the elements headlessly; returns the position of every gene node by id. */
export function runHeadlessLayout(elements: ElementDefinition[]): Record<string, LayoutPosition> {
  if (!registered) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (cytoscape as any).use(fcose);
    registered = true;
  }
  // styleEnabled: node sizes come from the same stylesheet the canvas uses
  const cy = cytoscape({
    headless: true,
    styleEnabled: true,
    elements,
    style: getCytoscapeStyle(),
  });
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  cy.layout({ ...initialFcoseLayoutOptions(), fit: false } as any).run();
  const positions: Record<string, LayoutPosition> = {};
  for (const element of elements) {
    if (!isGeneNodeElement(element)) continue;
    const id = String(element.data?.id);
    const { x, y } = cy.getElementById(id).position();
    positions[id] = { x, y };
  }
  cy.destroy();
  return positions;
}
