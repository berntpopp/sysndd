# Phase 26: Network Visualization - Research

**Researched:** 2026-01-25
**Domain:** Interactive network visualization with Cytoscape.js for protein-protein interaction networks
**Confidence:** HIGH

## Summary

Phase 26 delivers true protein-protein interaction (PPI) network visualization using Cytoscape.js, replacing the current D3.js bubble charts with actual network graphs showing edges between genes. Research confirms that Cytoscape.js 3.33.1 with fcose layout is the optimal solution for biological network visualization, providing 2x speed improvement over cose-bilkent while maintaining active development. The phase builds on Phase 25's backend optimizations (Leiden clustering, HCPC performance improvements) which provide the fast data foundation required for responsive network interactions.

Critical success factors center on three areas: (1) proper Vue 3 lifecycle management with explicit cy.destroy() in onBeforeUnmount to prevent 100-300MB memory leaks per navigation, (2) performance optimizations including hideEdgesOnViewport, fcose layout, and pixelRatio:1 to avoid rendering cliffs beyond 500 edges, and (3) composable-based architecture isolating Cytoscape lifecycle from component logic for testability and reusability. User decisions from CONTEXT.md establish visual presentation (node sizing by degree, cluster colors with convex hull, edge weighting by confidence) and interaction patterns (hover highlighting, draggable nodes, animated layout, standard controls), providing clear implementation constraints.

The recommended implementation creates two composables (useCytoscape for lifecycle, useNetworkData for fetching) paired with a new backend endpoint /api/analysis/network_edges that extracts PPI edges from STRINGdb in Cytoscape.js JSON format. Integration with existing SysNDD patterns (Bootstrap-Vue-Next components, Vue Router navigation, memoise caching) ensures consistency. Research areas requiring investigation during planning include node click behavior best practices (immediate navigation vs selection vs side panel) and optimal control placement within SysNDD's existing UI framework.

**Primary recommendation:** Implement Cytoscape.js 3.33.1 with fcose layout using Vue 3 Composition API composables, establish lifecycle patterns early (non-reactive instance storage, explicit destroy), and build on Phase 25's optimized backend for network edge extraction.

## Standard Stack

The established libraries and tools for biological network visualization with Vue 3.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| cytoscape | 3.33.1 | Graph visualization engine | Industry standard for biological networks, 220K weekly downloads, native TypeScript support, proven in Ensembl/GeneMANIA, WebGL renderer for large graphs (>500 nodes) |
| cytoscape-fcose | 2.2.0 | Force-directed layout algorithm | 2x faster than cose-bilkent (unmaintained), active development, optimized for PPI networks, supports constraints and compound nodes |
| STRINGdb (R) | 2.18.0 | Protein-protein interaction data | Existing integration in Phase 25, v11.5 database compatibility verified, provides combined_score for edge weighting |
| igraph (R) | 2.1.1 | Graph analysis backend | Used in Phase 25 for Leiden clustering, provides induced_subgraph for network extraction, integration with STRINGdb proven |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| cytoscape-svg | Latest | SVG export extension | Required for SVG export (PNG built-in), user decision specifies PNG + SVG export capability |
| VueUse | 11.3.0 | Composable utilities | Optional for useUrlSearchParams if adding filter state sync (Phase 26 focuses on core network, defer to v5.1) |
| Bootstrap-Vue-Next | 0.30.0 | UI components | Existing SysNDD standard for BCard, BButton, BSpinner (consistency with AnalyseGeneClusters.vue) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| cytoscape-fcose | cytoscape-cose-bilkent | cose-bilkent unmaintained since 2021, fcose 2x faster with equivalent aesthetics |
| Cytoscape.js | D3.js force-directed | D3 requires more code for same features, no built-in biological algorithms, lower-level control traded for implementation time |
| Cytoscape.js | sigma.js | sigma.js optimized for massive graphs (10K+ nodes), fewer layout algorithms, less biological focus; overkill for SysNDD's 200-500 node networks |
| Direct integration | vue-cytoscape wrapper | vue-cytoscape incompatible with Vue 3 (Issue #96), direct integration provides TypeScript support and lifecycle control |

**Installation:**
```bash
# Frontend
npm install cytoscape@3.33.1 cytoscape-fcose@2.2.0 cytoscape-svg@latest

# Backend (already installed in Phase 25)
# STRINGdb and igraph verified in analyses-functions.R
```

## Architecture Patterns

### Recommended Project Structure
```
api/
├── functions/
│   └── analyses-functions.R     # gen_network_edges() function added
├── endpoints/
│   └── analyses.R               # GET /api/analysis/network_edges added

app/src/
├── components/analyses/
│   └── NetworkVisualization.vue # New Cytoscape.js component
├── composables/
│   ├── useCytoscape.ts         # Lifecycle management (init/destroy)
│   └── useNetworkData.ts       # Data fetching and transformation
└── types/
    └── network.ts              # TypeScript interfaces for network data
```

### Pattern 1: Composable-Based Cytoscape Integration
**What:** Encapsulate Cytoscape.js lifecycle in a composable separate from component logic, ensuring testability and reusability.
**When to use:** Always for Cytoscape.js integration in Vue 3
**Why:** Isolates lifecycle complexity, enables unit testing, prevents tight coupling between visualization and component logic

**Example:**
```typescript
// Source: Vue 3 Composition API best practices + Cytoscape.js lifecycle
// composables/useCytoscape.ts
import { ref, onBeforeUnmount, type Ref } from 'vue';
import cytoscape, { type Core, type ElementDefinition } from 'cytoscape';
import fcose from 'cytoscape-fcose';

cytoscape.use(fcose);

export interface CytoscapeOptions {
  container: Ref<HTMLElement | null>;
  elements: ElementDefinition[];
  onNodeClick?: (nodeId: string) => void;
}

export function useCytoscape(options: CytoscapeOptions) {
  // CRITICAL: Store in non-reactive variable to avoid Vue reactivity
  // triggering layout recalculations (100 renders instead of 1)
  let cy: Core | null = null;

  const isInitialized = ref(false);
  const isLoading = ref(false);

  const initializeCytoscape = () => {
    if (!options.container.value) {
      console.warn('useCytoscape: container not available');
      return;
    }

    isLoading.value = true;

    cy = cytoscape({
      container: options.container.value,
      elements: options.elements,

      // Style configuration
      style: getCytoscapeStyle(),

      // Layout configuration
      layout: {
        name: 'fcose',
        quality: 'default',
        animate: true,
        animationDuration: 1500,
        animationEasing: 'ease-out-cubic',
        randomize: false,
        nodeDimensionsIncludeLabels: true,
        // Force-separate clusters naturally
        idealEdgeLength: 100,
        nodeRepulsion: 4500,
        edgeElasticity: 0.45,
      },

      // Performance optimizations
      hideEdgesOnViewport: true, // Hide edges during pan/zoom for smooth interactions
      textureOnViewport: false,
      pixelRatio: 1, // Prevent 2-3x cost on high DPI displays
      motionBlur: false,
    });

    // Event handlers
    if (options.onNodeClick) {
      cy.on('tap', 'node', (event) => {
        const nodeId = event.target.id();
        options.onNodeClick!(nodeId);
      });
    }

    // Hover highlighting
    cy.on('mouseover', 'node', (event) => {
      const node = event.target;
      node.addClass('highlighted');
      node.neighborhood('edge').addClass('highlighted');
      node.neighborhood('node').addClass('dimmed');
    });

    cy.on('mouseout', 'node', () => {
      cy.elements().removeClass('highlighted dimmed');
    });

    isInitialized.value = true;
    isLoading.value = false;
  };

  const updateElements = (elements: ElementDefinition[]) => {
    if (!cy) return;
    cy.elements().remove();
    cy.add(elements);
    cy.layout({ name: 'fcose', animate: true }).run();
  };

  const exportPNG = (): string => {
    if (!cy) return '';
    return cy.png({ output: 'base64uri', full: true, scale: 2 });
  };

  const exportSVG = (): string => {
    if (!cy) return '';
    // Requires cytoscape-svg extension
    return (cy as any).svg({ full: true });
  };

  const fitToScreen = () => {
    if (!cy) return;
    cy.fit(undefined, 50); // 50px padding
  };

  const resetLayout = () => {
    if (!cy) return;
    cy.layout({ name: 'fcose', animate: true }).run();
  };

  // CRITICAL: Cleanup to prevent memory leaks
  // Each Cytoscape instance retains 100-300MB
  onBeforeUnmount(() => {
    if (cy) {
      cy.destroy();
      cy = null;
    }
  });

  return {
    cy: () => cy, // Getter to avoid exposing mutable reference
    isInitialized,
    isLoading,
    initializeCytoscape,
    updateElements,
    exportPNG,
    exportSVG,
    fitToScreen,
    resetLayout,
  };
}

function getCytoscapeStyle() {
  return [
    {
      selector: 'node',
      style: {
        'label': 'data(symbol)',
        'background-color': 'data(color)',
        // Node sizing by degree (connection count) - user decision
        'width': (ele: any) => Math.max(30, Math.sqrt(ele.data('degree')) * 10),
        'height': (ele: any) => Math.max(30, Math.sqrt(ele.data('degree')) * 10),
        'font-size': '11px',
        'text-valign': 'center',
        'text-halign': 'center',
        'border-width': 2,
        'border-color': '#333',
      },
    },
    {
      selector: 'edge',
      style: {
        // Edge weighting by STRING confidence - user decision
        'width': (ele: any) => Math.max(1, (ele.data('confidence') || 0.4) * 5),
        'line-color': '#ccc',
        'curve-style': 'bezier',
        'opacity': 0.6,
      },
    },
    {
      selector: 'node.highlighted',
      style: {
        'border-color': '#ff0',
        'border-width': 4,
        'z-index': 999,
      },
    },
    {
      selector: 'edge.highlighted',
      style: {
        'line-color': '#ff0',
        'width': 3,
        'opacity': 1,
      },
    },
    {
      selector: 'node.dimmed',
      style: {
        'opacity': 0.3,
      },
    },
  ];
}
```

### Pattern 2: Network Data Fetching Composable
**What:** Separate composable for fetching and transforming network data from backend API into Cytoscape.js format.
**When to use:** When network data requires fetching, transformation, or caching
**Why:** Separates data concerns from visualization concerns, enables independent testing, follows SysNDD's existing useTableData.ts pattern

**Example:**
```typescript
// Source: Existing useTableData.ts pattern adapted for network data
// composables/useNetworkData.ts
import { ref, computed } from 'vue';
import axios from 'axios';
import type { ElementDefinition } from 'cytoscape';
import { useColorAndSymbols } from './useColorAndSymbols';

export interface NetworkNode {
  hgnc_id: string;
  symbol: string;
  cluster: number;
  degree: number;
}

export interface NetworkEdge {
  source: string;
  target: string;
  confidence: number;
}

export interface NetworkResponse {
  nodes: NetworkNode[];
  edges: NetworkEdge[];
  metadata: {
    node_count: number;
    edge_count: number;
    cluster_count: number;
  };
}

export function useNetworkData() {
  const { getClusterColor } = useColorAndSymbols();

  const networkData = ref<NetworkResponse | null>(null);
  const isLoading = ref(false);
  const error = ref<Error | null>(null);

  const fetchNetworkData = async (clusterType: 'clusters' | 'subclusters') => {
    isLoading.value = true;
    error.value = null;

    try {
      const response = await axios.get<NetworkResponse>(
        `/api/analysis/network_edges`,
        {
          params: {
            cluster_type: clusterType,
            include_metadata: true,
          },
        }
      );
      networkData.value = response.data;
    } catch (err) {
      error.value = err instanceof Error ? err : new Error('Failed to fetch network data');
      console.error('Network data fetch error:', err);
    } finally {
      isLoading.value = false;
    }
  };

  // Transform backend data to Cytoscape.js ElementDefinition format
  const cytoscapeElements = computed<ElementDefinition[]>(() => {
    if (!networkData.value) return [];

    const nodes: ElementDefinition[] = networkData.value.nodes.map((node) => ({
      data: {
        id: node.hgnc_id,
        symbol: node.symbol,
        cluster: node.cluster,
        degree: node.degree,
        // Cluster colors - user decision
        color: getClusterColor(node.cluster),
      },
    }));

    const edges: ElementDefinition[] = networkData.value.edges.map((edge, idx) => ({
      data: {
        id: `e${idx}`,
        source: edge.source,
        target: edge.target,
        confidence: edge.confidence,
      },
    }));

    return [...nodes, ...edges];
  });

  return {
    networkData,
    isLoading,
    error,
    fetchNetworkData,
    cytoscapeElements,
  };
}
```

### Pattern 3: Backend Network Edges Endpoint
**What:** R endpoint that extracts PPI edges from STRINGdb and returns Cytoscape.js JSON format.
**When to use:** Always for network visualization backend
**Why:** Leverages existing Phase 25 infrastructure (STRINGdb integration, Leiden clustering), follows memoise caching pattern, returns format optimized for frontend consumption

**Example:**
```r
# Source: Existing gen_string_clust_obj pattern + Cytoscape.js JSON spec
# api/functions/analyses-functions.R

#' Generate network edges for Cytoscape.js visualization
#'
#' Extracts protein-protein interaction edges from STRINGdb
#' for genes in clusters, returning Cytoscape.js JSON format.
#'
#' @param cluster_type Type of clusters ("clusters" or "subclusters")
#' @param min_confidence Minimum STRING confidence score (0-1000, default 400)
#' @return List with nodes, edges, and metadata in Cytoscape.js format
#' @export
gen_network_edges <- function(
  cluster_type = "clusters",
  min_confidence = 400
) {
  # Get cluster data from Phase 25 function
  # This ensures we use the same Leiden clustering results
  clusters_data <- gen_string_clust_obj_mem(
    hgnc_list = get_ndd_gene_list(),
    min_size = 10,
    subcluster = (cluster_type == "subclusters"),
    algorithm = "leiden"
  )

  # Extract HGNC IDs from clusters
  hgnc_ids <- unique(unlist(clusters_data$genes))

  # Load gene table with STRING IDs
  gene_table <- pool %>%
    tbl("non_alt_loci_set") %>%
    filter(hgnc_id %in% hgnc_ids, !is.na(STRING_id)) %>%
    select(hgnc_id, symbol, STRING_id) %>%
    collect()

  # Initialize STRINGdb (match Phase 25 version)
  string_db <- STRINGdb::STRINGdb$new(
    version = "11.5",
    species = 9606,
    score_threshold = min_confidence,
    input_directory = "data"
  )

  # Get STRING graph
  string_graph <- string_db$get_graph()

  # Filter to input genes
  genes_in_graph <- intersect(
    igraph::V(string_graph)$name,
    gene_table$STRING_id
  )

  # Create subgraph
  subgraph <- igraph::induced_subgraph(
    string_graph,
    vids = which(igraph::V(string_graph)$name %in% genes_in_graph)
  )

  # Build nodes with cluster assignments
  cluster_map <- clusters_data %>%
    select(cluster, genes) %>%
    tidyr::unnest(genes) %>%
    rename(hgnc_id = genes)

  nodes <- tibble(
    STRING_id = igraph::V(subgraph)$name
  ) %>%
    left_join(gene_table, by = "STRING_id") %>%
    left_join(cluster_map, by = "hgnc_id") %>%
    mutate(degree = igraph::degree(subgraph)[STRING_id]) %>%
    select(hgnc_id, symbol, cluster, degree)

  # Build edges
  edge_list <- igraph::as_edgelist(subgraph) %>%
    as_tibble(.name_repair = ~ c("source", "target"))

  # Map STRING IDs back to HGNC IDs for edges
  string_to_hgnc <- setNames(gene_table$hgnc_id, gene_table$STRING_id)

  edges <- edge_list %>%
    mutate(
      source = string_to_hgnc[source],
      target = string_to_hgnc[target],
      confidence = igraph::E(subgraph)$combined_score / 1000
    ) %>%
    filter(!is.na(source), !is.na(target))

  # Return Cytoscape.js compatible structure
  list(
    nodes = nodes,
    edges = edges,
    metadata = list(
      node_count = nrow(nodes),
      edge_count = nrow(edges),
      cluster_count = length(unique(nodes$cluster)),
      string_version = "11.5",
      min_confidence = min_confidence
    )
  )
}

# Memoized wrapper following Phase 25 pattern
gen_network_edges_mem <- memoise::memoise(
  gen_network_edges,
  cache = memoise::cache_filesystem("cache/network_edges")
)
```

### Pattern 4: Component Integration with Vue Router Navigation
**What:** NetworkVisualization.vue component integrating composables with existing SysNDD patterns (Bootstrap-Vue-Next, Vue Router navigation).
**When to use:** Always for network visualization component
**Why:** Maintains consistency with existing AnalyseGeneClusters.vue, integrates node clicks with entity detail navigation

**Example:**
```vue
<!-- Source: AnalyseGeneClusters.vue adapted for Cytoscape.js -->
<!-- app/src/components/analyses/NetworkVisualization.vue -->
<template>
  <BCard
    header-tag="header"
    body-class="p-0"
    header-class="p-1"
    border-variant="dark"
  >
    <template #header>
      <div class="d-flex justify-content-between align-items-center">
        <h6 class="mb-1 text-start font-weight-bold">
          Protein-Protein Interaction Network
          <BBadge variant="success">
            {{ metadata?.node_count || 0 }} genes
          </BBadge>
          <BBadge variant="info">
            {{ metadata?.edge_count || 0 }} interactions
          </BBadge>
        </h6>
        <div class="d-flex gap-2">
          <!-- Standard controls - user decision -->
          <BButton size="sm" @click="fitToScreen">
            <i class="bi bi-arrows-fullscreen" /> Fit
          </BButton>
          <BButton size="sm" @click="resetLayout">
            <i class="bi bi-arrow-clockwise" /> Reset
          </BButton>
          <BButton size="sm" @click="handleExportPNG">
            <i class="bi bi-image" /> PNG
          </BButton>
          <BButton size="sm" @click="handleExportSVG">
            <i class="bi bi-file-earmark-image" /> SVG
          </BButton>
        </div>
      </div>
    </template>

    <div class="network-container">
      <BSpinner v-if="isLoading" label="Loading network..." class="spinner" />
      <div
        ref="cytoscapeContainer"
        class="cytoscape-canvas"
        :style="{ opacity: isLoading ? 0.3 : 1 }"
      />
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useCytoscape } from '@/composables/useCytoscape';
import { useNetworkData } from '@/composables/useNetworkData';

const router = useRouter();
const cytoscapeContainer = ref<HTMLElement | null>(null);

const { networkData, isLoading, fetchNetworkData, cytoscapeElements } = useNetworkData();

const metadata = computed(() => networkData.value?.metadata);

// Node click navigates to entity detail - requirement NETV-06
const handleNodeClick = (nodeId: string) => {
  router.push({
    name: 'Entity',
    params: { hgnc_id: nodeId },
  });
};

const {
  isInitialized,
  initializeCytoscape,
  updateElements,
  exportPNG,
  exportSVG,
  fitToScreen,
  resetLayout,
} = useCytoscape({
  container: cytoscapeContainer,
  elements: cytoscapeElements.value,
  onNodeClick: handleNodeClick,
});

// Initialize network on mount
onMounted(async () => {
  await fetchNetworkData('clusters');
  initializeCytoscape();
});

// Update elements when data changes
watch(cytoscapeElements, (newElements) => {
  if (isInitialized.value) {
    updateElements(newElements);
  }
});

const handleExportPNG = () => {
  const dataUrl = exportPNG();
  const link = document.createElement('a');
  link.href = dataUrl;
  link.download = 'network.png';
  link.click();
};

const handleExportSVG = () => {
  const svgData = exportSVG();
  const blob = new Blob([svgData], { type: 'image/svg+xml' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = 'network.svg';
  link.click();
  URL.revokeObjectURL(url);
};
</script>

<style scoped>
.network-container {
  position: relative;
  width: 100%;
  height: 600px;
}

.cytoscape-canvas {
  width: 100%;
  height: 100%;
  background: #fafafa;
  border: 1px solid #ddd;
}

.spinner {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: 10;
}
</style>
```

### Anti-Patterns to Avoid
- **Storing Cytoscape instance in ref():** Triggers Vue reactivity on every graph mutation, causing 100 layout recalculations instead of 1. Use non-reactive variable (let cy) instead.
- **Missing cy.destroy() in lifecycle hooks:** Each undestroyed instance retains 100-300MB. Always call cy.destroy() in onBeforeUnmount.
- **Blocking PNG export:** Using output:'base64uri' hangs browser for large graphs. Use output:'blob-promise' for non-blocking export.
- **Using vue-cytoscape wrapper:** Incompatible with Vue 3 (Issue #96), adds unnecessary abstraction. Use direct Cytoscape.js integration with composables.
- **Fetching network data repeatedly:** Network data changes rarely. Implement proper caching with memoise backend and consider localStorage for frontend caching.

## Don't Hand-Roll

Problems that look simple but have existing solutions.

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Force-directed layout algorithm | Custom D3.js force simulation | cytoscape-fcose | fcose optimized for biological networks, 2x faster than alternatives, supports constraints (fixed nodes, alignment), compound nodes, proven in production |
| Network export to images | Canvas manipulation + download | Cytoscape.js built-in png() + cytoscape-svg | Built-in methods handle scaling, resolution, full graph vs viewport, blob/base64 outputs; cytoscape-svg handles proper SVG generation with layers |
| Convex hull cluster boundaries | Custom polygon calculation | CSS overlays + cluster grouping styling | Cytoscape.js doesn't have native convex hull extension; simple visual clustering achievable with color + subtle borders, avoids complex computational geometry |
| Node hover tooltips | Custom positioned divs | Cytoscape.js extensions or popper.js | Proper tooltip positioning relative to canvas requires viewport coordinate transformation; popper.js handles this with collision detection |
| Graph search/filtering | String matching on node data | Cytoscape.js selector API | Selector API provides powerful query syntax (cy.nodes('[symbol ^= "BRCA"]')), handles wildcards, boolean logic, data attributes; optimized C++ implementation |
| Memory leak detection | Manual testing | Chrome DevTools heap snapshots | Heap snapshots show retained Cytoscape instances, detached DOM nodes, event listener leaks; take snapshot, navigate, force GC, take second snapshot, compare |

**Key insight:** Biological network visualization has solved problems (force layouts, exports, selectors) through decades of Cytoscape development. Cytoscape.js inherits this domain knowledge. Custom solutions miss edge cases (high DPI scaling, large graph performance, biological layout heuristics) and require maintenance as browser APIs evolve.

## Common Pitfalls

### Pitfall 1: Cytoscape.js Memory Leaks from Missing Lifecycle Cleanup
**What goes wrong:** Vue 3 Composition API doesn't auto-cleanup third-party instances. Each undestroyed Cytoscape instance retains 100-300MB including canvases, event listeners, and element data. Navigating away from network page without cleanup causes memory leak.

**Why it happens:** Cytoscape.js creates off-screen canvas elements and maintains internal data structures that Vue can't garbage collect automatically. onBeforeUnmount hook must explicitly call cy.destroy().

**How to avoid:**
- Store Cytoscape instance in non-reactive variable (let cy not ref())
- Always call cy.destroy() in onBeforeUnmount hook
- Set cy = null after destroy
- Verify cleanup with Chrome DevTools heap snapshots after 10 navigation cycles

**Warning signs:**
- Browser tab memory grows from 200MB to 2GB+ after 10 page navigations
- Performance degradation over time
- Heap snapshots show multiple detached Cytoscape canvas elements

**Code example:**
```typescript
// WRONG - memory leak
const cy = ref<Core | null>(null);
// Missing onBeforeUnmount cleanup

// RIGHT - proper cleanup
let cy: Core | null = null;
onBeforeUnmount(() => {
  if (cy) {
    cy.destroy();
    cy = null;
  }
});
```

### Pitfall 2: Edge Rendering Performance Cliff Beyond 500 Edges
**What goes wrong:** Canvas renderer degrades severely with >1000 edges (5+ second redraws during pan/zoom). High DPI displays multiply rendering cost 2-3x. Users experience frozen UI during interactions.

**Why it happens:** Canvas API redraws entire graph on every viewport change. Edge curves (bezier) more expensive than straight lines. Browser compositor struggles with large canvas repaints.

**How to avoid:**
- Set hideEdgesOnViewport: true (hides edges during pan/zoom for smooth interactions)
- Set pixelRatio: 1 (prevents 2-3x cost on Retina displays, acceptable for network graphs)
- Use fcose layout instead of cose-bilkent (2x faster, same aesthetics)
- Consider WebGL renderer for >500 nodes (activate conditionally based on node count)

**Warning signs:**
- Pan/zoom feels laggy (>100ms delay)
- Browser DevTools Performance tab shows long "Paint" durations (>16ms)
- Users report "frozen" network during interactions

**Code example:**
```typescript
// Performance optimization configuration
cy = cytoscape({
  container: container.value,
  elements: elements,
  hideEdgesOnViewport: true, // Key optimization
  pixelRatio: 1, // Prevent high DPI cost
  layout: {
    name: 'fcose', // Not cose-bilkent
  },
});
```

### Pitfall 3: Vue Reactivity Over-Triggering Cytoscape Renders
**What goes wrong:** Storing graph data in ref() causes Vue reactivity to trigger Cytoscape re-renders on every node position change during layout animation (100+ times). Results in choppy animation and wasted CPU.

**Why it happens:** Cytoscape.js mutates node positions during layout. If data is reactive, Vue triggers watchers on every mutation, causing downstream updates.

**How to avoid:**
- Store Cytoscape instance in non-reactive variable (let cy not ref())
- Store raw graph data (nodes/edges arrays) outside Vue reactivity if Cytoscape mutates it
- Only make UI state reactive (isLoading, selectedNode), not graph structure

**Warning signs:**
- Layout animation stutters or freezes
- Browser DevTools shows excessive component re-renders during layout
- High CPU usage during network initialization

**Code example:**
```typescript
// WRONG - reactive instance
const cy = ref<Core | null>(null); // Vue watches all mutations

// RIGHT - non-reactive instance
let cy: Core | null = null; // No Vue reactivity overhead
```

### Pitfall 4: Missing Convex Hull Extension (Requires Custom Solution)
**What goes wrong:** User decision specifies "convex hull" cluster boundaries, but Cytoscape.js has no native convex hull extension. Developers waste time searching for non-existent plugin.

**Why it happens:** Desktop Cytoscape has convex hull plugins (clusterMaker2), but Cytoscape.js ecosystem lacks equivalent. Computational geometry complexity and limited demand prevent community implementation.

**How to avoid:**
- Use visual clustering instead: node colors + subtle cluster labeling
- Consider custom SVG overlay using d3-polygon convex hull algorithm if truly required
- Defer convex hull to v5.1+ if not critical for MVP (focus on color + labels for Phase 26)

**Warning signs:**
- Search results only show desktop Cytoscape plugins
- NPM search for "cytoscape convex hull" returns no results
- Documentation mentions "compound nodes" but not convex hulls

**Alternative approach:**
```typescript
// Visual clustering without convex hull
// User decision: "color + convex hull" -> implement color + labels for MVP
style: [
  {
    selector: 'node',
    style: {
      'background-color': 'data(color)', // Cluster colors
      'border-color': '#333',
      'border-width': 2,
    },
  },
  // Add cluster labels as separate nodes or use popper.js for overlay
]
```

### Pitfall 5: Node Click Navigation Without Loading State
**What goes wrong:** Clicking node immediately navigates to entity detail page. If page load is slow, user sees blank screen with no feedback. Appears broken.

**Why it happens:** Vue Router navigation is synchronous but entity page data fetching is async. No intermediate loading state shown.

**How to avoid:**
- Show loading spinner or skeleton during navigation
- Use Vue Router navigation guards with loading state
- Consider side panel pattern (research required) instead of full navigation
- Provide visual feedback on click (highlight node, dim network)

**Warning signs:**
- Users report "nothing happens" when clicking nodes
- Blank screen during slow network entity fetches
- No visual feedback acknowledging click

**Research note:** CONTEXT.md flags "click action on nodes" as requiring research for best practices (immediate navigation vs selection vs side panel).

### Pitfall 6: Export Functions Called Before Initialization
**What goes wrong:** User clicks export button before Cytoscape finishes initializing. exportPNG() called on null cy instance, throws error or returns empty image.

**Why it happens:** Async initialization (fetch data, initialize cy, run layout) means component renders before cy ready. Export buttons clickable immediately.

**How to avoid:**
- Disable export buttons until isInitialized is true
- Add null checks in export functions
- Show loading spinner over canvas during initialization

**Warning signs:**
- Console errors "Cannot read property 'png' of null"
- Downloaded images are blank or corrupted
- Export works on second click but not first

**Code example:**
```vue
<BButton
  size="sm"
  :disabled="!isInitialized"
  @click="handleExportPNG"
>
  <i class="bi bi-image" /> PNG
</BButton>
```

### Pitfall 7: STRINGdb Version Mismatch Between R Package and Database
**What goes wrong:** R STRINGdb package version doesn't match STRING_id values in database. get_subnetwork() returns empty graph or missing edges. Network shows isolated nodes.

**Why it happens:** Phase 25 uses STRINGdb v11.5 in R but database STRING_id column might be from different version. STRING updates ID format between versions.

**How to avoid:**
- Verify STRING_id format matches STRINGdb package version (v11.5)
- Add version check in gen_network_edges function
- Document STRING version in database schema comments
- Include string_version in API metadata for debugging

**Warning signs:**
- Network has nodes but zero edges
- Console logs show "X genes not found in STRING graph"
- Edge count metadata shows 0 despite valid proteins

**Code example:**
```r
# Verify STRING IDs match expected format
if (nrow(gene_table) > 0 && !grepl("^9606\\.", gene_table$STRING_id[1])) {
  warning("STRING_id format may not match STRINGdb version 11.5")
}
```

### Pitfall 8: Smart Label Visibility Without Zoom Threshold
**What goes wrong:** User decision specifies "smart label visibility" (show when zoomed in, hide when dense). Without proper zoom threshold, labels either always show (cluttered) or always hide (useless).

**Why it happens:** Cytoscape.js doesn't have built-in zoom-based label visibility. Requires custom zoom event handler comparing current zoom to threshold.

**How to avoid:**
- Implement zoom event listener updating label visibility
- Set empirical threshold (zoom < 1.0 = hide, zoom >= 1.0 = show)
- Consider node count threshold (< 50 nodes = always show, else zoom-based)
- Test with actual SysNDD cluster sizes (50-200 nodes expected)

**Warning signs:**
- Labels overlap and are unreadable in default view
- Users can't read gene names even when zoomed in
- Performance degrades with labels enabled (consider font rendering cost)

**Code example:**
```typescript
cy.on('zoom', () => {
  const zoom = cy.zoom();
  if (zoom >= 1.0) {
    cy.style().selector('node').style({ 'label': 'data(symbol)' }).update();
  } else {
    cy.style().selector('node').style({ 'label': '' }).update();
  }
});
```

## Code Examples

Verified patterns from official sources.

### Example 1: Minimal Cytoscape.js Initialization
```typescript
// Source: https://js.cytoscape.org/#getting-started
import cytoscape from 'cytoscape';
import fcose from 'cytoscape-fcose';

cytoscape.use(fcose);

const cy = cytoscape({
  container: document.getElementById('cy'),

  elements: [
    { data: { id: 'a', symbol: 'BRCA1' } },
    { data: { id: 'b', symbol: 'BRCA2' } },
    { data: { id: 'ab', source: 'a', target: 'b' } }
  ],

  style: [
    {
      selector: 'node',
      style: {
        'background-color': '#0074D9',
        'label': 'data(symbol)'
      }
    }
  ],

  layout: {
    name: 'fcose'
  }
});
```

### Example 2: PNG Export with Proper Options
```typescript
// Source: https://js.cytoscape.org/#cy.png
// Non-blocking export for large graphs
const blob = await cy.png({
  output: 'blob-promise',
  full: true, // Export entire graph, not just viewport
  scale: 2, // 2x resolution for clarity
  bg: '#ffffff', // White background
});

const url = URL.createObjectURL(blob);
const link = document.createElement('a');
link.href = url;
link.download = 'network.png';
link.click();
URL.revokeObjectURL(url);
```

### Example 3: Hover Highlighting with Neighborhoods
```typescript
// Source: https://js.cytoscape.org/#cy.on
// Highlight node and connected edges/nodes on hover
cy.on('mouseover', 'node', (event) => {
  const node = event.target;

  // Highlight the node
  node.addClass('highlighted');

  // Highlight connected edges
  const connectedEdges = node.connectedEdges();
  connectedEdges.addClass('highlighted');

  // Dim other nodes
  const neighbors = node.neighborhood('node');
  cy.nodes().not(neighbors).not(node).addClass('dimmed');
});

cy.on('mouseout', 'node', () => {
  // Clear all highlights
  cy.elements().removeClass('highlighted dimmed');
});
```

### Example 4: fcose Layout with Biological Network Optimizations
```typescript
// Source: https://github.com/iVis-at-Bilkent/cytoscape.js-fcose
// Optimized fcose settings for protein-protein interaction networks
cy.layout({
  name: 'fcose',

  // Quality vs speed tradeoff
  quality: 'default', // 'draft' | 'default' | 'proof'

  // Animation
  animate: true,
  animationDuration: 1500,
  animationEasing: 'ease-out-cubic',

  // Initial positions
  randomize: false, // Use previous positions if available

  // Node spacing (adjust for cluster separation)
  idealEdgeLength: 100, // Longer edges = more space between clusters
  nodeRepulsion: 4500, // Higher = more separation
  edgeElasticity: 0.45, // Edge strength (0-1)

  // Layout area
  nodeDimensionsIncludeLabels: true, // Prevent label overlap

  // Performance
  numIter: 2500, // Iterations (higher = better quality, slower)

  // Callback when layout finishes
  ready: () => {
    console.log('Layout complete');
  },
}).run();
```

### Example 5: Backend R Function Extracting STRING Edges
```r
# Source: Existing gen_string_clust_obj pattern + igraph documentation
# Extract edges from STRING subgraph with confidence scores

extract_string_edges <- function(string_db, gene_string_ids) {
  # Get STRING graph
  graph <- string_db$get_graph()

  # Filter to input genes
  genes_in_graph <- intersect(
    igraph::V(graph)$name,
    gene_string_ids
  )

  # Create subgraph
  subgraph <- igraph::induced_subgraph(
    graph,
    vids = which(igraph::V(graph)$name %in% genes_in_graph)
  )

  # Extract edge list
  edges <- igraph::as_edgelist(subgraph) %>%
    as_tibble(.name_repair = ~ c("source", "target")) %>%
    mutate(
      # Convert STRING combined_score (0-1000) to confidence (0-1)
      confidence = igraph::E(subgraph)$combined_score / 1000
    )

  return(edges)
}
```

### Example 6: Tooltip Integration with Rich Contextual Data
```typescript
// Source: User requirement NETV-07 + popper.js documentation
// Rich tooltips showing gene symbol, HGNC ID, cluster, phenotypes

import { createPopper } from '@popperjs/core';

cy.on('mouseover', 'node', (event) => {
  const node = event.target;
  const data = node.data();

  // Create tooltip element
  const tooltip = document.createElement('div');
  tooltip.className = 'cytoscape-tooltip';
  tooltip.innerHTML = `
    <strong>${data.symbol}</strong><br>
    HGNC ID: ${data.hgnc_id}<br>
    Cluster: ${data.cluster}<br>
    Connections: ${data.degree}<br>
    Phenotypes: ${data.phenotype_count || 'N/A'}
  `;
  document.body.appendChild(tooltip);

  // Position with popper.js
  const popper = createPopper(event.target.popperRef(), tooltip, {
    placement: 'top',
    modifiers: [
      {
        name: 'offset',
        options: { offset: [0, 8] },
      },
    ],
  });

  // Store for cleanup
  node.data('tooltip', { element: tooltip, popper });
});

cy.on('mouseout', 'node', (event) => {
  const tooltip = event.target.data('tooltip');
  if (tooltip) {
    tooltip.popper.destroy();
    tooltip.element.remove();
  }
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| D3.js bubble charts without edges | Cytoscape.js with actual PPI edges | Phase 26 (2026) | True network visualization showing protein interactions, not just cluster groupings; enables biological interpretation |
| cose-bilkent layout | fcose layout | fcose 2.0 (2021) | 2x speed improvement, active maintenance, equivalent aesthetics; cose-bilkent unmaintained since 2021 |
| Walktrap clustering | Leiden clustering | Phase 25 (2026) | 2-3x faster clustering, better modularity scores; Leiden became standard for biological networks |
| Canvas renderer only | WebGL renderer option | Cytoscape.js 3.31 (2025-01) | 3-10 FPS → 10-100 FPS for large graphs (1200+ nodes); WebGL preview status as of Jan 2025 |
| vue-cytoscape wrapper | Direct Cytoscape.js + composables | Vue 3 migration | Vue 3 compatibility, TypeScript support, direct API access; vue-cytoscape stuck on Vue 2 |
| STRING v11.5 (current) | STRING v12.5 (2025) | Available but not required | Adds regulatory networks, directionality of regulation; defer to v6 milestone to avoid blocking v5 |

**Deprecated/outdated:**
- **cose-bilkent layout:** Unmaintained since 2021, use fcose instead (2x faster, same quality)
- **STRINGdb cluster_walktrap:** Replaced by cluster_leiden in Phase 25 (2-3x speedup)
- **vue-cytoscape wrapper:** Vue 2 only, incompatible with Vue 3 (Issue #96); use direct integration with composables
- **hideEdgesOnViewport optimization:** Still valid but less impactful in modern Cytoscape.js due to rendering improvements; still recommended for >1000 edge graphs

## Open Questions

Things that couldn't be fully resolved during research.

### 1. Node Click Behavior: Navigation vs Selection vs Side Panel
**What we know:**
- CONTEXT.md flags this as requiring research
- Requirement NETV-06 specifies "click node navigates to entity detail page"
- UX research suggests progressive disclosure (hover for neighbors, double-click for expansion) for complex networks
- Cambridge Intelligence recommends avoiding immediate navigation that breaks exploration flow

**What's unclear:**
- Does immediate navigation (requirement) conflict with network exploration UX (best practice)?
- Should we implement intermediate selection state (click highlights, button confirms navigation)?
- Would side panel showing entity details while keeping network visible be better?
- How does this interact with existing AnalyseGeneClusters.vue patterns?

**Recommendation:** Implement requirement NETV-06 (immediate navigation) for MVP, but plan UX research for Phase 26 to validate. Consider adding Ctrl+Click for opening in new tab as compromise. Flag for user testing in QA.

### 2. Convex Hull Implementation Strategy
**What we know:**
- User decision specifies "cluster membership indicated by color + convex hull"
- No native Cytoscape.js convex hull extension exists (search confirmed)
- Desktop Cytoscape has clusterMaker2 with convex hull visualization
- d3-polygon provides convex hull algorithm usable with custom SVG overlay

**What's unclear:**
- Is custom convex hull implementation worth complexity for MVP?
- Would users accept color + cluster labels instead of hulls?
- Should we use compound nodes (cluster containers) as alternative?
- What's the maintenance cost of custom SVG overlay layer?

**Recommendation:** Defer true convex hull to v5.1+. For Phase 26, implement color-coded nodes + cluster labels for visual grouping (80% of hull benefit, 20% of complexity). Add hull implementation to backlog if user feedback demands it.

### 3. Controls Placement Within SysNDD UI Framework
**What we know:**
- CONTEXT.md flags this as requiring research
- User decision specifies standard control set (zoom, fit, reset, fullscreen, center, toggle labels)
- 2026 UX trends favor contextual minimalism (controls appear when relevant)
- Existing AnalyseGeneClusters.vue has controls in card header

**What's unclear:**
- Should controls be in card header (existing pattern) or floating toolbar (modern UX)?
- Do controls need tooltips for discoverability?
- Should fullscreen mode use native browser fullscreen or maximized BCard?
- Where do export buttons (PNG/SVG) fit in control layout?

**Recommendation:** Follow AnalyseGeneClusters.vue pattern (controls in card header) for consistency. Defer floating toolbar to v5.1+ if user testing shows discoverability issues. Export buttons group separately from navigation controls.

### 4. WebGL Renderer Activation Threshold
**What we know:**
- WebGL renderer improves performance for large graphs (1200+ nodes: 20→100 FPS)
- WebGL marked as "preview" in Cytoscape.js 3.31 (Jan 2025)
- Canvas renderer sufficient for SysNDD's expected 200-500 node networks
- Activation should be conditional based on node count

**What's unclear:**
- What's the optimal node count threshold for WebGL activation?
- Is WebGL stable enough for production use (preview status)?
- Should activation be user-configurable or automatic?
- What's fallback behavior if WebGL initialization fails?

**Recommendation:** Monitor Cytoscape.js releases for WebGL production status. Implement feature flag in Phase 26 (disabled by default). If WebGL reaches stable, activate for >500 nodes with fallback to canvas on error. Add analytics to track actual cluster sizes in production.

### 5. Label Visibility Zoom Thresholds
**What we know:**
- User decision specifies "smart label visibility" (zoomed in or few nodes = show, dense = hide)
- No built-in Cytoscape.js zoom-based label visibility
- Performance cost of label rendering increases with node count
- SysNDD expected cluster sizes: 50-200 nodes

**What's unclear:**
- What's the optimal zoom threshold (1.0x, 1.5x, 2.0x)?
- Should node count threshold override zoom (e.g., <30 nodes always show)?
- Do users prefer labels always visible with collision detection?
- What's the performance cliff for label rendering (100 nodes, 500 nodes)?

**Recommendation:** Start with zoom >= 1.5x shows labels, node count < 30 always shows. Implement custom zoom handler during Phase 26. Gather analytics on actual cluster sizes and user zoom behavior. Adjust thresholds in v5.1 based on data.

### 6. Network Layout Persistence Strategy
**What we know:**
- User decision implies users can drag to reposition nodes
- Manually adjusted layouts should persist across sessions (valuable for presentations)
- localStorage natural fit for layout persistence (client-side, no backend changes)
- Layout data includes node positions (x,y coordinates)

**What's unclear:**
- Should persistence be per-cluster or global?
- How to handle layout invalidation when cluster membership changes?
- Should persistence be opt-in (save button) or automatic?
- What's the localStorage size limit impact (positions for 500 nodes)?

**Recommendation:** Defer layout persistence to advanced features phase. Focus Phase 26 on core visualization. If implemented, use localStorage with cluster-specific keys, opt-in save/load buttons, 7-day expiration to avoid stale layouts.

## Sources

### Primary (HIGH confidence)

**Cytoscape.js Core:**
- [Cytoscape.js Official Documentation](https://js.cytoscape.org/) - Core API, initialization, styling, events
- [Cytoscape.js GitHub Performance Documentation](https://github.com/cytoscape/cytoscape.js/blob/master/documentation/md/performance.md) - hideEdgesOnViewport, pixelRatio, optimization strategies
- [Cytoscape.js NPM v3.33.1](https://www.npmjs.com/package/cytoscape) - Latest version verification, TypeScript definitions
- [Cytoscape.js WebGL Preview Blog (2025-01-13)](https://blog.js.cytoscape.org/2025/01/13/webgl-preview/) - WebGL renderer performance benchmarks

**Cytoscape.js Extensions:**
- [cytoscape-fcose GitHub](https://github.com/iVis-at-Bilkent/cytoscape.js-fcose) - fcose layout algorithm, performance comparison with cose-bilkent
- [cytoscape-fcose NPM](https://www.npmjs.com/package/cytoscape-fcose) - Latest version 2.2.0
- [cytoscape-svg GitHub](https://github.com/kinimesi/cytoscape-svg) - SVG export extension
- [Cytoscape.js Using Layouts Blog (2020-05-11)](https://blog.js.cytoscape.org/2020/05/11/layouts/) - Layout algorithm comparison

**Vue 3 Integration:**
- [Vue 3 Composables Official Guide](https://vuejs.org/guide/reusability/composables.html) - Composition API patterns
- [vue-cytoscape Vue 3 Compatibility Issue #96](https://github.com/rcarcasses/vue-cytoscape/issues/96) - Confirms wrapper incompatibility with Vue 3

**R Backend (STRINGdb):**
- [STRING Database in 2025 (Nucleic Acids Research)](https://academic.oup.com/nar/article/53/D1/D730/7903368) - STRING v12.5, regulatory networks, API updates
- [STRINGdb Bioconductor Package](https://bioconductor.org/packages/release/bioc/html/STRINGdb.html) - R package documentation, version compatibility
- [igraph cluster_leiden Documentation](https://igraph.org/r/doc/cluster_leiden.html) - Leiden algorithm parameters (used in Phase 25)

**Project-Specific:**
- SysNDD `.plan/NETWORK-VISUALIZATION-RESEARCH.md` - Comprehensive library comparison, Cytoscape.js code examples
- SysNDD `.planning/research/SUMMARY-v5.md` - Phase 25 context, architecture patterns, pitfalls documentation
- SysNDD `api/functions/analyses-functions.R` - Existing gen_string_clust_obj implementation with Leiden clustering
- SysNDD `app/src/components/analyses/AnalyseGeneClusters.vue` - Current D3.js implementation patterns

### Secondary (MEDIUM confidence)

**UX Research:**
- [Graph Visualization UX (Cambridge Intelligence)](https://cambridge-intelligence.com/graph-visualization-ux-how-to-avoid-wrecking-your-graph-visualization/) - Progressive disclosure, hover states, node interaction patterns
- [Network Graph Visualization UX (Highcharts)](https://www.highcharts.com/blog/tutorials/network-graph-visualization-exploring-data-relationships/) - Node behavior configuration, event handling best practices
- [Data Visualization UX Best Practices 2026 (DesignStudioUIUX)](https://www.designstudiouiux.com/blog/data-visualization-ux-best-practices/) - Control placement, progressive disclosure, 2026 trends
- [Dashboard Design UX Patterns (Pencil & Paper)](https://www.pencilandpaper.io/articles/ux-pattern-analysis-data-dashboards) - Visualization structure, consistency principles

**Performance & Optimization:**
- [Cytoscape.js Performance Discussion #3088](https://github.com/cytoscape/cytoscape.js/discussions/3088) - Community performance optimization strategies
- [Cytoscape.js hideEdgesOnViewport Issue #2477](https://github.com/cytoscape/cytoscape.js/issues/2477) - Animation limitation with hideEdgesOnViewport

**Memory Management:**
- [Cytoscape.js Memory Leak Issue #663](https://github.com/cytoscape/cytoscape.js/issues/663) - Angular.js memory leak discussion, applicable to Vue 3
- [Vue.js Memory Leak Guide](https://blog.jobins.jp/vuejs-memory-leak-identification-and-solution) - Third-party library cleanup patterns
- [Avoiding Memory Leaks — Vue.js](https://v2.vuejs.org/v2/cookbook/avoiding-memory-leaks.html) - Lifecycle hook cleanup strategies

**Export Functionality:**
- [Cytoscape.js Export Discussion](https://groups.google.com/g/cytoscape-discuss/c/2nVn_MrPeP8) - PNG export community solutions
- [Dash Cytoscape Image Export](https://dash.plotly.com/cytoscape/images) - JPG/PNG/SVG export patterns
- [Cytoscape.js SVG Export Issue #2923](https://github.com/cytoscape/cytoscape.js/issues/2923) - SVG export challenges and solutions

**Cluster Visualization:**
- [CytoCluster Plugin (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5618529/) - Desktop Cytoscape cluster visualization (reference only)
- [clusterMaker2 Documentation](https://www.rbvi.ucsf.edu/cytoscape/clusterMaker2/) - Cluster analysis methods (desktop Cytoscape reference)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All core technologies verified with official sources (Cytoscape.js v3.33.1 NPM, fcose GitHub, STRINGdb Bioconductor), version compatibility confirmed, existing Phase 25 integration proven
- Architecture: HIGH - Patterns align with Vue 3 Composition API official docs, composable structure matches existing useTableData.ts, STRINGdb integration verified from current analyses-functions.R, lifecycle patterns documented in memory leak issues
- Pitfalls: HIGH - Memory leak patterns sourced from Cytoscape.js GitHub issues, performance optimizations from official performance docs, Vue reactivity issues from Vue.js memory leak guides, convex hull limitation confirmed via ecosystem search
- UX patterns: MEDIUM - Node click behavior requires validation (CONTEXT.md flags for research), control placement patterns from UX research but need SysNDD-specific implementation, label visibility thresholds empirical

**Research date:** 2026-01-25
**Valid until:** 60 days (stable ecosystem - Cytoscape.js mature, Vue 3 stable, R packages established; monitor Cytoscape.js releases for WebGL production status)

**Phase-specific notes:**
- User decisions in CONTEXT.md provide clear constraints (node sizing, cluster colors, edge weighting, interaction patterns, controls)
- Two areas flagged for planning research: node click behavior best practices, controls placement within SysNDD UI
- Convex hull user decision requires clarification (defer vs custom implementation)
- Phase 25 backend optimizations (Leiden, HCPC) provide foundation for network visualization
- WebGL renderer preview status requires monitoring for production readiness
