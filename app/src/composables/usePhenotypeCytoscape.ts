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

/**
 * fcose layout options (cytoscape-fcose plugin)
 * The fcose plugin extends cytoscape's built-in layout types.
 */
interface FcoseLayoutOptions {
  name: 'fcose';
  animate?: boolean;
  animationDuration?: number;
  randomize?: boolean;
  nodeRepulsion?: number | ((node: unknown) => number);
  idealEdgeLength?: number | ((edge: unknown) => number);
  edgeElasticity?: number | ((edge: unknown) => number);
  gravity?: number;
  fit?: boolean;
  padding?: number;
  numIter?: number;
}

/**
 * Cytoscape Core extended with cytoscape-svg plugin method
 */
interface CoreWithSvg extends Core {
  svg(options?: { full?: boolean; scale?: number; bg?: string }): string;
}

// Register extensions once using global flag to handle HMR
if (!(globalThis as Record<string, unknown>).__cytoscapeExtensionsRegistered) {
  cytoscape.use(fcose);
  cytoscape.use(svg);
  (globalThis as Record<string, unknown>).__cytoscapeExtensionsRegistered = true;
}

export interface PhenotypeCluster {
  cluster: string | number;
  cluster_size: number;
  hash_filter?: string;
}

export interface PhenotypeCytoscapeOptions {
  container: Ref<HTMLElement | null>;
  onClusterClick?: (clusterId: string | number) => void;
}

// Professional, accessible color palette (ColorBrewer Set2 - colorblind-safe)
const CLUSTER_COLORS = [
  '#66c2a5', // teal
  '#fc8d62', // coral
  '#8da0cb', // periwinkle
  '#e78ac3', // pink
  '#a6d854', // lime
  '#ffd92f', // yellow
  '#e5c494', // tan
  '#b3b3b3', // gray
];

function getClusterColor(index: number): string {
  return CLUSTER_COLORS[index % CLUSTER_COLORS.length];
}

export function usePhenotypeCytoscape(options: PhenotypeCytoscapeOptions) {
  let cy: Core | null = null;
  const isInitialized = ref(false);
  const isLoading = ref(false);

  function initializeCytoscape() {
    if (!options.container.value) {
      return;
    }

    cy = cytoscape({
      container: options.container.value,
      style: [
        {
          selector: 'node',
          style: {
            width: 'data(size)',
            height: 'data(size)',
            'background-color': 'data(color)',
            'background-opacity': 0.9,
            'border-width': 3,
            'border-color': '#444',
            label: 'data(label)',
            'font-size': '18px',
            'font-weight': 'bold',
            'text-valign': 'center',
            'text-halign': 'center',
            color: '#222',
            'text-outline-width': 3,
            'text-outline-color': '#fff',
            // Transition for smooth hover effects
            'transition-property': 'border-width, border-color, background-opacity',
            'transition-duration': 150, // milliseconds
          },
        },
        {
          selector: 'node:active',
          style: {
            'overlay-opacity': 0.1,
          },
        },
        {
          selector: 'node:selected',
          style: {
            'border-width': 5,
            'border-color': '#0d6efd',
            'background-opacity': 1,
            // Blue glow effect for selected cluster
            'overlay-color': '#0d6efd',
            'overlay-opacity': 0.15,
            'overlay-padding': 8,
          },
        },
        {
          selector: 'edge',
          style: {
            'curve-style': 'bezier',
            width: 2,
            'line-color': '#999',
            opacity: 0.4,
          },
        },
      ],
      layout: { name: 'preset' }, // We'll position manually or use fcose
      minZoom: 0.3,
      maxZoom: 3,
    });

    // Click handler for node selection
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

    // Calculate size scale - larger nodes for better visibility
    const sizes = clusters.map(c => c.cluster_size);
    const maxSize = Math.max(...sizes);
    const minSize = Math.min(...sizes);
    const sizeScale = (size: number) => {
      const normalized = (size - minSize) / (maxSize - minSize || 1);
      return 45 + normalized * 55; // 45-100px range for better visibility
    };

    // Create node elements with clean labels
    const elements: ElementDefinition[] = clusters.map((cluster, index) => ({
      data: {
        id: `cluster-${cluster.cluster}`,
        clusterId: cluster.cluster,
        label: `${cluster.cluster}`,  // Just cluster number, size shown via node size
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
    } as FcoseLayoutOptions).run();

    isLoading.value = false;
  }

  function fitToScreen() {
    cy?.fit(undefined, 30);
  }

  function selectCluster(clusterId: string | number) {
    if (!cy) return;
    cy.nodes().unselect();
    cy.$(`#cluster-${clusterId}`).select();
  }

  function exportPNG(): string {
    return cy?.png({ full: true, scale: 2 }) || '';
  }

  function exportSVG(): string {
    return (cy as CoreWithSvg | null)?.svg({ full: true }) || '';
  }

  function destroy() {
    cy?.destroy();
    cy = null;
    isInitialized.value = false;
  }

  // Only register cleanup if called during component setup
  // Check if we're in a component context
  try {
    onBeforeUnmount(() => {
      destroy();
    });
  } catch (_e) {
    // Called outside setup() - caller must call destroy() manually
  }

  return {
    cy: () => cy,
    isInitialized,
    isLoading,
    initializeCytoscape,
    updateElements,
    selectCluster,
    fitToScreen,
    exportPNG,
    exportSVG,
    destroy,
  };
}
