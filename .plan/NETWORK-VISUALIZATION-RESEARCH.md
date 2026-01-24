# Network Visualization Research Report

**Date:** 2026-01-24
**Purpose:** Research solutions for adding true network visualization to SysNDD analysis pages

---

## Executive Summary

Currently, SysNDD's "Gene Networks" page displays **clustered bubbles** (force-directed layout grouping subclusters) but does **not show actual interaction edges** between genes. This is technically clustering visualization, not network visualization.

Based on comparison with kidney-genetics-db and web research, this report recommends implementing **Cytoscape.js** for true network visualization with:
- Actual protein-protein interaction edges from STRING-db
- Compound nodes to preserve cluster bubble aesthetic
- Gene search with highlighting
- Multiple layout algorithms
- WebGL rendering for performance

---

## 1. Current SysNDD Implementation Analysis

### What We Have Now

**Backend (`api/functions/analyses-functions.R`):**
- STRINGdb v11.5 with Walktrap clustering algorithm
- Returns cluster assignments but **not interaction edges**
- File-based caching with JSON serialization
- Recursive subclustering support

**Frontend (`app/src/components/analyses/AnalyseGeneClusters.vue`):**
- D3.js force simulation for bubble layout
- Bubbles represent subclusters, not individual genes
- No edges/links between nodes
- Click to select cluster, tooltip on hover
- No search functionality

### Current Data Flow
```
STRINGdb → get_clusters(walktrap) → cluster assignments → JSON → D3 bubbles
                                    ↑
                              No edges extracted
```

### What's Missing
1. **Interaction edges** - The STRING network edges are computed internally by `get_clusters()` but never returned
2. **Individual gene nodes** - Only cluster summaries are shown
3. **Search functionality** - No way to find specific genes
4. **Network metrics** - No degree, centrality, or connectivity info

---

## 2. kidney-genetics-db Implementation (Reference)

### Architecture Overview

| Component | Technology | Purpose |
|-----------|------------|---------|
| Backend | Python igraph | Network construction & clustering |
| Clustering | Leiden/Louvain/Walktrap | Community detection |
| Frontend | Cytoscape.js v3.33 | Network visualization |
| Layout | COSE-Bilkent | Force-directed positioning |
| Data Source | STRING-db v12.0 | PPI interactions |

### Key Features

**1. Multiple Clustering Algorithms:**
```python
# Leiden (recommended - faster, better quality)
clusters = cluster_leiden(graph, resolution=1.0)

# Walktrap (SysNDD current)
clusters = cluster_walktrap(graph, steps=4)
```

**2. Rich Node Coloring Modes:**
- Cluster assignment
- Clinical classification (HPO groups)
- Age of onset
- Syndromic assessment

**3. Gene Search with Highlighting:**
```javascript
// Wildcard pattern matching (*, ?)
useNetworkSearch(cy, {
  caseSensitive: false,
  highlightColor: '#ffcc00',
  fitOnMatch: true
});
```

**4. Cytoscape JSON Format:**
```json
{
  "nodes": [
    {"data": {"id": "PKD1", "cluster": 2, "degree": 15}}
  ],
  "edges": [
    {"data": {"source": "PKD1", "target": "PKD2", "weight": 0.85}}
  ]
}
```

**5. URL State Compression:**
- Network state encoded in URL for sharing
- Auto-rebuild on page load

---

## 3. Recommended Solution Architecture

### Hybrid Approach: Preserve Bubbles + Add Networks

Instead of replacing the current bubble visualization, implement a **dual-view system**:

```
┌─────────────────────────────────────────────────────────────┐
│  View Toggle: [Cluster Bubbles] [Gene Network] [Hybrid]     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Cluster Bubbles View (Current D3)                          │
│  ┌─────┐  ┌─────┐                                           │
│  │  ●  │  │  ●  │  ← Subclusters as bubbles                 │
│  │ ●●● │  │ ●●  │                                           │
│  └─────┘  └─────┘                                           │
│                                                             │
│  Gene Network View (Cytoscape.js)                           │
│       ●───●                                                 │
│      /│\  │\                                                │
│     ● ● ●─●─●   ← Individual genes with edges               │
│                                                             │
│  Hybrid View (Cytoscape.js Compound Nodes)                  │
│  ┌─────────┐                                                │
│  │ ●──●    │───┐                                            │
│  │ │╲ │    │   │  ← Genes inside cluster containers         │
│  │ ●──●    │   │    with inter-cluster edges                │
│  └─────────┘   │                                            │
│        └───────┘                                            │
└─────────────────────────────────────────────────────────────┘
```

### 3.1 Backend Changes

**New API Endpoint: `/api/analysis/functional_network`**

```r
#' @get /api/analysis/functional_network
#' @serializer json
function(min_score = 400, include_edges = TRUE) {

  # Get gene list
  genes <- pool %>%
    tbl("ndd_entity_view") %>%
    filter(ndd_phenotype == 1) %>%
    select(hgnc_id, symbol) %>%
    collect()

  # Initialize STRING-db
  string_db <- STRINGdb$new(
    version = "12.0",  # Upgrade from 11.5
    species = 9606,
    score_threshold = min_score
  )

  # Get STRING IDs
  mapped <- string_db$map(genes, "hgnc_id")

  # Build network graph
  graph <- string_db$get_subnetwork(mapped$STRING_id)

  # Perform clustering (use Leiden if available via igraph)
  clusters <- cluster_leiden(graph, resolution = 1.0)

  # Convert to Cytoscape JSON format
  cytoscape_json <- igraph_to_cytoscape(graph, clusters)

  return(cytoscape_json)
}
```

**igraph to Cytoscape Conversion:**

```r
#' Convert igraph to Cytoscape.js JSON format
igraph_to_cytoscape <- function(graph, clusters = NULL) {

  # Extract nodes
  nodes <- data.frame(
    id = V(graph)$name,
    label = V(graph)$symbol %||% V(graph)$name,
    degree = degree(graph),
    cluster = if (!is.null(clusters)) membership(clusters) else NA
  ) %>%
    mutate(data = purrr::pmap(., list)) %>%
    mutate(elements = list(list(data = data)))

  # Extract edges
  edges <- as_edgelist(graph) %>%
    as.data.frame() %>%
    rename(source = V1, target = V2) %>%
    mutate(
      id = paste(source, target, sep = "_"),
      weight = E(graph)$combined_score / 1000
    ) %>%
    mutate(data = purrr::pmap(., list)) %>%
    mutate(elements = list(list(data = data)))

  list(
    nodes = nodes$elements,
    edges = edges$elements,
    metadata = list(
      node_count = vcount(graph),
      edge_count = ecount(graph),
      modularity = if (!is.null(clusters)) modularity(clusters) else NA
    )
  )
}
```

### 3.2 Frontend Implementation

**New Component: `NetworkGraphCytoscape.vue`**

```javascript
// Key imports
import cytoscape from 'cytoscape';
import coseBilkent from 'cytoscape-cose-bilkent';
cytoscape.use(coseBilkent);

export default {
  setup() {
    const cy = ref(null);
    const searchQuery = ref('');
    const selectedCluster = ref(null);

    // Initialize Cytoscape
    const initCytoscape = (container, elements) => {
      cy.value = cytoscape({
        container,
        elements,
        style: getCytoscapeStyle(),
        layout: {
          name: 'cose-bilkent',
          quality: 'proof',
          nodeDimensionsIncludeLabels: true,
          animate: true
        }
      });

      // Add event handlers
      cy.value.on('tap', 'node', handleNodeClick);
      cy.value.on('mouseover', 'node', handleNodeHover);
    };

    // Search functionality
    const searchGenes = (query) => {
      cy.value.elements().removeClass('highlighted dimmed');

      if (!query) return;

      const pattern = query.replace(/\*/g, '.*').replace(/\?/g, '.');
      const regex = new RegExp(pattern, 'i');

      const matches = cy.value.nodes().filter(node =>
        regex.test(node.data('label'))
      );

      if (matches.length > 0) {
        matches.addClass('highlighted');
        cy.value.nodes().not(matches).addClass('dimmed');
        cy.value.fit(matches, 50);
      }
    };

    return { cy, searchQuery, searchGenes, selectedCluster };
  }
};
```

**Cytoscape Stylesheet:**

```javascript
const getCytoscapeStyle = () => [
  {
    selector: 'node',
    style: {
      'label': 'data(label)',
      'background-color': ele => clusterColors[ele.data('cluster')] || '#666',
      'width': ele => Math.max(20, Math.sqrt(ele.data('degree')) * 8),
      'height': ele => Math.max(20, Math.sqrt(ele.data('degree')) * 8),
      'font-size': '10px',
      'text-valign': 'center',
      'text-halign': 'center',
      'border-width': 2,
      'border-color': '#333'
    }
  },
  {
    selector: 'edge',
    style: {
      'width': ele => ele.data('weight') * 3,
      'line-color': '#ccc',
      'curve-style': 'bezier',
      'opacity': 0.6
    }
  },
  {
    selector: 'node.highlighted',
    style: {
      'border-color': '#ff0',
      'border-width': 4,
      'z-index': 999
    }
  },
  {
    selector: '.dimmed',
    style: {
      'opacity': 0.2
    }
  },
  {
    selector: ':parent',  // Compound nodes (clusters)
    style: {
      'background-opacity': 0.1,
      'border-width': 3,
      'padding': '20px'
    }
  }
];
```

### 3.3 Compound Nodes for Hybrid View

To preserve the cluster bubble aesthetic while showing gene-level detail:

```javascript
// Transform flat node list into compound graph
const createCompoundGraph = (nodes, edges, clusters) => {
  const elements = [];

  // Create cluster parent nodes
  const clusterIds = [...new Set(nodes.map(n => n.cluster))];
  clusterIds.forEach(clusterId => {
    elements.push({
      data: {
        id: `cluster_${clusterId}`,
        label: `Cluster ${clusterId}`,
        isCluster: true
      }
    });
  });

  // Create gene nodes as children of clusters
  nodes.forEach(node => {
    elements.push({
      data: {
        ...node,
        parent: `cluster_${node.cluster}`  // Makes it a child
      }
    });
  });

  // Add edges (Cytoscape handles compound node containment)
  edges.forEach(edge => {
    elements.push({ data: edge });
  });

  return elements;
};
```

---

## 4. Visualization Libraries Comparison

| Library | Pros | Cons | Best For |
|---------|------|------|----------|
| **Cytoscape.js** | Biological focus, compound nodes, rich API | Learning curve | **Recommended** for SysNDD |
| **v-network-graph** | Vue-native, simple API | Less biological features | Simple networks |
| **Vis.js** | Physics-based, 3D support | Not biological-focused | General networks |
| **D3.js** | Full control, current in use | Low-level, more code | Custom visualizations |
| **Sigma.js** | WebGL performance | Less features | Very large networks |

### Why Cytoscape.js?

1. **Biological heritage** - Created for bioinformatics at University of Toronto
2. **Compound nodes** - Native support for cluster containers
3. **Layout algorithms** - COSE-Bilkent excellent for PPI networks
4. **Search/filter** - Built-in selector queries
5. **WebGL renderer** - v3.31+ has GPU acceleration for large networks
6. **Proven** - Used by Ensembl, FlyBase, WormBase, GeneMANIA

---

## 5. Search Implementation

### Gene Search Features

```javascript
const useNetworkSearch = (cy) => {
  const searchState = reactive({
    query: '',
    matches: [],
    currentIndex: 0
  });

  const search = (query) => {
    // Reset previous highlights
    cy.elements().removeClass('highlighted dimmed searched');

    if (!query.trim()) {
      searchState.matches = [];
      return;
    }

    // Support wildcards: PKD* matches PKD1, PKD2, etc.
    const pattern = query
      .replace(/[.+^${}()|[\]\\]/g, '\\$&')  // Escape regex special chars
      .replace(/\*/g, '.*')                    // * → any chars
      .replace(/\?/g, '.');                    // ? → single char

    const regex = new RegExp(`^${pattern}$`, 'i');

    // Find matching nodes
    searchState.matches = cy.nodes().filter(node => {
      const label = node.data('label') || node.data('symbol') || '';
      return regex.test(label);
    });

    if (searchState.matches.length > 0) {
      // Highlight matches
      searchState.matches.addClass('highlighted searched');
      cy.elements().not(searchState.matches).addClass('dimmed');

      // Fit view to matches with padding
      cy.fit(searchState.matches, 80);

      // Flash animation
      searchState.matches.animate({
        style: { 'border-width': 6 },
        duration: 200
      }).animate({
        style: { 'border-width': 4 },
        duration: 200
      });
    }

    return searchState.matches.length;
  };

  // Navigate between matches
  const nextMatch = () => {
    if (searchState.matches.length === 0) return;
    searchState.currentIndex = (searchState.currentIndex + 1) % searchState.matches.length;
    cy.center(searchState.matches[searchState.currentIndex]);
  };

  const prevMatch = () => {
    if (searchState.matches.length === 0) return;
    searchState.currentIndex = (searchState.currentIndex - 1 + searchState.matches.length) % searchState.matches.length;
    cy.center(searchState.matches[searchState.currentIndex]);
  };

  return { searchState, search, nextMatch, prevMatch };
};
```

### Search UI Component

```vue
<template>
  <div class="network-search">
    <BInputGroup size="sm">
      <BInputGroupText>
        <i class="bi bi-search" />
      </BInputGroupText>
      <BFormInput
        v-model="searchQuery"
        placeholder="Search genes (e.g., PKD*, BRCA?)"
        @input="debouncedSearch"
        @keydown.enter="nextMatch"
      />
      <BInputGroupText v-if="matchCount > 0">
        {{ currentIndex + 1 }}/{{ matchCount }}
      </BInputGroupText>
      <BButton
        v-if="matchCount > 1"
        variant="outline-secondary"
        size="sm"
        @click="prevMatch"
      >
        <i class="bi bi-chevron-up" />
      </BButton>
      <BButton
        v-if="matchCount > 1"
        variant="outline-secondary"
        size="sm"
        @click="nextMatch"
      >
        <i class="bi bi-chevron-down" />
      </BButton>
      <BButton
        v-if="searchQuery"
        variant="outline-danger"
        size="sm"
        @click="clearSearch"
      >
        <i class="bi bi-x" />
      </BButton>
    </BInputGroup>
  </div>
</template>
```

---

## 6. Performance Considerations

### Large Network Handling

| Network Size | Recommendation |
|--------------|----------------|
| < 500 nodes | Standard canvas rendering |
| 500-2000 nodes | Use COSE layout with quality='draft' |
| 2000-5000 nodes | Enable WebGL renderer |
| > 5000 nodes | Use subgraph extraction or aggregation |

### WebGL Renderer (Cytoscape.js 3.31+)

```javascript
import cytoscape from 'cytoscape';

const cy = cytoscape({
  container,
  elements,
  // Enable WebGL for large networks
  renderer: {
    name: 'webgl'  // New in v3.31
  }
});
```

### Lazy Loading Strategy

```javascript
// Initial load: Only cluster summaries (current behavior)
const loadClusterSummary = async () => {
  const response = await axios.get('/api/analysis/functional_clustering');
  return response.data.clusters;
};

// On-demand: Full network for selected cluster
const loadClusterNetwork = async (clusterId) => {
  const response = await axios.get(`/api/analysis/cluster_network/${clusterId}`);
  return response.data;  // Cytoscape JSON for that cluster only
};
```

---

## 7. Implementation Roadmap

### Phase 1: Backend Network Endpoint (P1)

**Estimated effort:** Medium

1. Upgrade STRINGdb from v11.5 to v12.0
2. Create `/api/analysis/functional_network` endpoint
3. Implement `igraph_to_cytoscape()` conversion function
4. Add edge extraction from STRING subnetwork
5. Consider Leiden algorithm (via igraph R package)

**New files:**
- `api/functions/network-functions.R`
- `api/endpoints/network_endpoints.R`

### Phase 2: Cytoscape.js Integration (P1)

**Estimated effort:** Medium-High

1. Install Cytoscape.js + cose-bilkent extension
2. Create `NetworkGraphCytoscape.vue` component
3. Implement basic network rendering
4. Add cluster coloring
5. Add node tooltips

**New files:**
- `app/src/components/analyses/NetworkGraphCytoscape.vue`
- `app/src/composables/useCytoscapeNetwork.js`

### Phase 3: Search & Interaction (P2)

**Estimated effort:** Medium

1. Implement gene search composable
2. Add search UI component
3. Implement node/edge highlighting
4. Add cluster selection interaction
5. Export to PNG/SVG

**New files:**
- `app/src/composables/useNetworkSearch.js`
- `app/src/components/analyses/NetworkSearchBar.vue`

### Phase 4: Hybrid View with Compound Nodes (P3)

**Estimated effort:** High

1. Implement compound graph transformation
2. Create cluster container nodes
3. Inter-cluster edge visualization
4. Collapsible clusters
5. Layout optimization for compound graphs

### Phase 5: Polish & Performance (P3)

**Estimated effort:** Medium

1. WebGL renderer for large networks
2. URL state compression for sharing
3. Multiple coloring modes (cluster, phenotype, etc.)
4. Animation and transitions
5. Responsive design

---

## 8. Code Examples

### Minimal Cytoscape.js Setup

```vue
<template>
  <div ref="cyContainer" class="cy-container" />
</template>

<script setup>
import { ref, onMounted } from 'vue';
import cytoscape from 'cytoscape';
import coseBilkent from 'cytoscape-cose-bilkent';

cytoscape.use(coseBilkent);

const cyContainer = ref(null);
const cy = ref(null);

const initNetwork = async () => {
  const response = await fetch('/api/analysis/functional_network');
  const data = await response.json();

  cy.value = cytoscape({
    container: cyContainer.value,
    elements: [...data.nodes, ...data.edges],
    style: [
      {
        selector: 'node',
        style: {
          'label': 'data(label)',
          'background-color': '#0074D9',
          'width': 30,
          'height': 30
        }
      },
      {
        selector: 'edge',
        style: {
          'width': 2,
          'line-color': '#ccc'
        }
      }
    ],
    layout: {
      name: 'cose-bilkent',
      animate: true,
      animationDuration: 1000
    }
  });
};

onMounted(initNetwork);
</script>

<style scoped>
.cy-container {
  width: 100%;
  height: 600px;
  border: 1px solid #ccc;
}
</style>
```

### R Backend: Extract STRING Network

```r
#' Get STRING network with edges for Cytoscape
#' @param hgnc_ids Character vector of HGNC IDs
#' @param min_score Minimum STRING confidence score (0-1000)
#' @return List with nodes and edges in Cytoscape JSON format
get_string_network <- function(hgnc_ids, min_score = 400) {

  # Initialize STRING-db
  string_db <- STRINGdb$new(
    version = "12.0",
    species = 9606,
    score_threshold = min_score,
    input_directory = "data"
  )

  # Map HGNC IDs to STRING IDs
  gene_table <- pool %>%
    tbl("non_alt_loci_set") %>%
    filter(hgnc_id %in% hgnc_ids, !is.na(STRING_id)) %>%
    select(hgnc_id, symbol, STRING_id) %>%
    collect()

  # Get subnetwork as igraph object
  graph <- string_db$get_subnetwork(gene_table$STRING_id)

  # Perform clustering
  clusters <- igraph::cluster_leiden(
    graph,
    resolution = 1.0,
    objective_function = "modularity"
  )

  # Build nodes
  nodes <- tibble(
    id = V(graph)$name
  ) %>%
    left_join(gene_table, by = c("id" = "STRING_id")) %>%
    mutate(
      cluster = membership(clusters)[id],
      degree = degree(graph)[id]
    ) %>%
    rowwise() %>%
    mutate(
      data = list(list(
        id = id,
        label = symbol,
        hgnc_id = hgnc_id,
        cluster = cluster,
        degree = degree
      ))
    ) %>%
    pull(data)

  # Build edges
  edge_list <- as_edgelist(graph) %>%
    as_tibble(.name_repair = ~ c("source", "target"))

  edges <- edge_list %>%
    mutate(
      id = paste(source, target, sep = "_"),
      weight = E(graph)$combined_score / 1000
    ) %>%
    rowwise() %>%
    mutate(
      data = list(list(
        id = id,
        source = source,
        target = target,
        weight = weight
      ))
    ) %>%
    pull(data)

  list(
    nodes = lapply(nodes, function(n) list(data = n)),
    edges = lapply(edges, function(e) list(data = e)),
    metadata = list(
      node_count = vcount(graph),
      edge_count = ecount(graph),
      cluster_count = length(unique(membership(clusters))),
      modularity = modularity(clusters)
    )
  )
}
```

---

## 9. Research Sources

### Libraries & Documentation
- [Cytoscape.js Official](https://js.cytoscape.org/) - Graph theory library for visualization
- [Cytoscape.js WebGL Preview (2025)](https://blog.js.cytoscape.org/2025/01/13/webgl-preview/) - GPU-accelerated rendering
- [v-network-graph](https://dash14.github.io/v-network-graph/) - Vue 3 network component
- [STRING Database 2025](https://academic.oup.com/nar/article/53/D1/D730/7903368) - Regulatory network features

### Biological Network Visualization
- [Cytoscape.js Bioinformatics Paper](https://academic.oup.com/bioinformatics/article/32/2/309/1744007) - Original publication
- [CytoCluster Plugin](https://pmc.ncbi.nlm.nih.gov/articles/PMC5618529/) - Cluster analysis methods
- [clusterMaker](https://www.cgl.ucsf.edu/cytoscape/cluster/clusterMaker.shtml) - Multi-algorithm clustering

### Data Conversion
- [igraph to Cytoscape (RCy3)](https://cytoscape.org/RCy3/articles/Cytoscape-and-iGraph.html) - R integration
- [toCytoscape function](https://rdrr.io/cran/stringgaussnet/man/toCytoscape.html) - JSON conversion

### JavaScript Libraries Comparison
- [Top JavaScript Graph Libraries](https://linkurious.com/blog/top-javascript-graph-libraries/) - Library comparison
- [Vue Chart Libraries 2025](https://www.luzmo.com/blog/vue-chart-libraries) - Vue ecosystem

---

## 10. Conclusion

### Recommendation

Implement **Cytoscape.js** with a **phased approach**:

1. **Keep existing D3 bubble chart** as "Cluster Overview" view
2. **Add Cytoscape.js network view** as "Gene Network" view
3. **Implement hybrid compound node view** for best of both worlds
4. **Add gene search** across all views

### Expected Benefits

| Feature | Current | After Implementation |
|---------|---------|---------------------|
| Shows actual interactions | No | Yes |
| Gene-level detail | No | Yes |
| Search genes | No | Yes (wildcard support) |
| Multiple layouts | No | Yes (COSE, circle, grid) |
| Large network support | Limited | WebGL for 2000+ nodes |
| Shareable state | No | URL compression |
| Export options | PNG/SVG | PNG/SVG/JSON |

### Files to Create

```
api/
├── functions/network-functions.R        # igraph/Cytoscape conversion
└── endpoints/network_endpoints.R        # New network API endpoints

app/src/
├── components/analyses/
│   ├── NetworkGraphCytoscape.vue       # Main Cytoscape component
│   ├── NetworkSearchBar.vue            # Search UI
│   └── NetworkControls.vue             # Layout/filter controls
├── composables/
│   ├── useCytoscapeNetwork.js          # Cytoscape initialization
│   ├── useNetworkSearch.js             # Search logic
│   └── useNetworkUrlState.js           # URL state compression
└── config/
    └── networkAnalysis.js              # Configuration constants
```
