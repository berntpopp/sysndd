// composables/usePhenotypeCytoscape.ts
/**
 * Simplified Cytoscape composable for phenotype cluster visualization
 * Shows clusters as nodes with optional edges for relationships
 */

import { ref, onBeforeUnmount, type Ref } from 'vue';
import cytoscape from 'cytoscape';
import type { Core, ElementDefinition } from 'cytoscape';
import fcose from 'cytoscape-fcose';
import svg from 'cytoscape-svg';

// Register extensions once
const cytoscapeFn = cytoscape as any;
cytoscapeFn.use(fcose);
cytoscapeFn.use(svg);

export interface PhenotypeCluster {
  cluster: string | number;
  cluster_size: number;
  hash_filter?: string;
}

export interface PhenotypeCytoscapeOptions {
  container: Ref<HTMLElement | null>;
  onClusterClick?: (clusterId: string | number) => void;
}

const CLUSTER_COLORS = [
  '#e41a1c', '#377eb8', '#4daf4a', '#984ea3',
  '#ff7f00', '#ffff33', '#a65628', '#f781bf',
];

function getClusterColor(index: number): string {
  return CLUSTER_COLORS[index % CLUSTER_COLORS.length];
}

export function usePhenotypeCytoscape(options: PhenotypeCytoscapeOptions) {
  let cy: Core | null = null;
  const isInitialized = ref(false);
  const isLoading = ref(false);

  function initializeCytoscape() {
    if (!options.container.value) return;

    cy = cytoscape({
      container: options.container.value,
      style: [
        {
          selector: 'node',
          style: {
            width: 'data(size)',
            height: 'data(size)',
            'background-color': 'data(color)',
            'border-width': 2,
            'border-color': '#696969',
            label: 'data(label)',
            'font-size': '14px',
            'text-valign': 'center',
            'text-halign': 'center',
            color: '#fff',
            'text-outline-width': 2,
            'text-outline-color': 'data(color)',
          },
        },
        {
          selector: 'node:selected',
          style: {
            'border-width': 4,
            'border-color': '#000',
          },
        },
        {
          selector: 'edge',
          style: {
            'curve-style': 'bezier',
            width: 2,
            'line-color': '#ccc',
            opacity: 0.5,
          },
        },
      ],
      layout: { name: 'preset' }, // We'll position manually or use fcose
      minZoom: 0.3,
      maxZoom: 3,
      wheelSensitivity: 0.3,
    });

    // Click handler
    cy.on('tap', 'node', (evt) => {
      const node = evt.target;
      const clusterId = node.data('clusterId');
      if (options.onClusterClick) {
        options.onClusterClick(clusterId);
      }
    });

    isInitialized.value = true;
  }

  function updateElements(clusters: PhenotypeCluster[]) {
    if (!cy) return;
    isLoading.value = true;

    // Calculate size scale
    const sizes = clusters.map(c => c.cluster_size);
    const maxSize = Math.max(...sizes);
    const minSize = Math.min(...sizes);
    const sizeScale = (size: number) => {
      const normalized = (size - minSize) / (maxSize - minSize || 1);
      return 30 + normalized * 50; // 30-80px range
    };

    // Create node elements
    const elements: ElementDefinition[] = clusters.map((cluster, index) => ({
      data: {
        id: `cluster-${cluster.cluster}`,
        clusterId: cluster.cluster,
        label: `C${cluster.cluster}\n(${cluster.cluster_size})`,
        size: sizeScale(cluster.cluster_size),
        color: getClusterColor(index),
        clusterSize: cluster.cluster_size,
      },
    }));

    // Add edges between adjacent clusters (simple proximity-based)
    // This creates a visual structure showing cluster relationships
    for (let i = 0; i < clusters.length - 1; i++) {
      elements.push({
        data: {
          id: `edge-${i}-${i + 1}`,
          source: `cluster-${clusters[i].cluster}`,
          target: `cluster-${clusters[i + 1].cluster}`,
        },
      });
    }

    cy.elements().remove();
    cy.add(elements);

    // Run layout
    cy.layout({
      name: 'fcose',
      animate: true,
      animationDuration: 500,
      randomize: true,
      nodeRepulsion: () => 8000,
      idealEdgeLength: () => 100,
      edgeElasticity: () => 0.1,
      gravity: 0.5,
    } as any).run();

    isLoading.value = false;
  }

  function fitToScreen() {
    cy?.fit(undefined, 30);
  }

  function exportPNG(): string {
    return cy?.png({ full: true, scale: 2 }) || '';
  }

  function exportSVG(): string {
    return (cy as any)?.svg({ full: true }) || '';
  }

  onBeforeUnmount(() => {
    cy?.destroy();
    cy = null;
  });

  return {
    cy: () => cy,
    isInitialized,
    isLoading,
    initializeCytoscape,
    updateElements,
    fitToScreen,
    exportPNG,
    exportSVG,
  };
}
