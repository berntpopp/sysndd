// composables/geneNetworkLayout.worker.ts — runs the gene-network fCoSE layout off the main thread.
import type { ElementDefinition } from 'cytoscape';
import { runHeadlessLayout } from './geneNetworkHeadlessLayout';

self.onmessage = (event: MessageEvent<ElementDefinition[]>) => {
  try {
    self.postMessage({ positions: runHeadlessLayout(event.data) });
  } catch (error) {
    self.postMessage({ error: String(error) });
  }
};
