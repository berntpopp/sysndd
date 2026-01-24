# Architecture Research: Analysis Modernization

**Domain:** Network visualization and clustering analysis integration
**Researched:** 2026-01-24
**Confidence:** HIGH

## Integration Overview

This milestone adds Cytoscape.js network visualization and optimized clustering to an existing Vue 3 + R/Plumber architecture. The integration extends existing patterns rather than replacing them.

### Current Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Vue 3 Frontend (app/)                     │
├─────────────────────────────────────────────────────────────┤
│  Views (views/analyses/)                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ PhenoFunc   │  │ GeneNetworks│  │ PhenoCorr   │         │
│  │ Correlation │  │             │  │             │         │
│  └─────┬───────┘  └──────┬──────┘  └──────┬──────┘         │
│        │                 │                 │                │
├────────┴─────────────────┴─────────────────┴────────────────┤
│  Components (components/analyses/)                           │
│  ┌────────────────────┐  ┌────────────────────┐             │
│  │ AnalysesPhenotype  │  │ AnalyseGeneClusters│             │
│  │ Clusters (D3.js)   │  │ (D3.js bubble)     │             │
│  └────────┬───────────┘  └────────┬───────────┘             │
│           │                       │                         │
├───────────┴───────────────────────┴─────────────────────────┤
│  Composables (composables/)                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                   │
│  │useTable  │  │useUrlPars│  │useToast  │                   │
│  │Data      │  │ing       │  │          │                   │
│  └──────────┘  └──────────┘  └──────────┘                   │
└─────────────────────────────────────────────────────────────┘
                        ↓ HTTP (axios)
┌─────────────────────────────────────────────────────────────┐
│                  R/Plumber API (api/)                        │
├─────────────────────────────────────────────────────────────┤
│  Endpoints (endpoints/analysis_endpoints.R)                  │
│  ┌────────────────┐  ┌────────────────┐                     │
│  │ GET /phenotype │  │ GET /functional│                     │
│  │ _clustering    │  │ _clustering    │                     │
│  └────────┬───────┘  └────────┬───────┘                     │
│           │                   │                             │
├───────────┴───────────────────┴─────────────────────────────┤
│  Functions (functions/analyses-functions.R)                  │
│  ┌────────────────────────────────────────────┐             │
│  │ gen_mca_clust_obj (MCA + HCPC)             │             │
│  │ gen_string_clust_obj (STRINGdb walktrap)   │             │
│  │ gen_string_enrich_tib (enrichment)         │             │
│  └────────────────────────────────────────────┘             │
├─────────────────────────────────────────────────────────────┤
│  Caching Layer (memoise + file cache)                       │
│  ┌────────────────────────────────────────────┐             │
│  │ gen_mca_clust_obj_mem (cached MCA)         │             │
│  │ gen_string_clust_obj_mem (cached STRING)   │             │
│  └────────────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│                    Database (pool)                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ndd_entity_   │  │phenotype_    │  │non_alt_loci_ │       │
│  │view          │  │list          │  │set           │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### Target Architecture (After Milestone)

```
┌─────────────────────────────────────────────────────────────┐
│                    Vue 3 Frontend (app/)                     │
├─────────────────────────────────────────────────────────────┤
│  Views (views/analyses/)                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ PhenoFunc   │  │ GeneNetworks│  │ PhenoCorr   │         │
│  │ Correlation │  │ (NEW)       │  │             │         │
│  └─────┬───────┘  └──────┬──────┘  └──────┬──────┘         │
│        │                 │                 │                │
├────────┴─────────────────┴─────────────────┴────────────────┤
│  Components (components/analyses/)                           │
│  ┌────────────────────┐  ┌────────────────────┐             │
│  │ AnalysesPhenotype  │  │ GeneClusterNetwork │ (NEW)      │
│  │ Clusters           │  │ (Cytoscape.js)     │             │
│  │ (D3.js bubble)     │  └────────┬───────────┘             │
│  └────────┬───────────┘           │                         │
│           │                       │                         │
│  ┌────────┴───────────────────────┴───────────┐             │
│  │ Shared Filter Components (NEW)             │             │
│  │ ┌──────────┐  ┌──────────┐  ┌──────────┐  │             │
│  │ │Category  │  │Score     │  │Term      │  │             │
│  │ │Filter    │  │Filter    │  │Search    │  │             │
│  │ └──────────┘  └──────────┘  └──────────┘  │             │
│  └────────────────────────────────────────────┘             │
├─────────────────────────────────────────────────────────────┤
│  Composables (composables/)                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │useTable  │  │useUrlPars│  │useNetwork│  │useFilter │    │
│  │Data      │  │ing       │  │Data(NEW) │  │Sync(NEW) │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└─────────────────────────────────────────────────────────────┘
                        ↓ HTTP (axios)
┌─────────────────────────────────────────────────────────────┐
│                  R/Plumber API (api/)                        │
├─────────────────────────────────────────────────────────────┤
│  Endpoints (endpoints/analysis_endpoints.R)                  │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐   │
│  │ GET /phenotype │  │ GET /functional│  │ GET /network │   │
│  │ _clustering    │  │ _clustering    │  │ _edges (NEW) │   │
│  └────────┬───────┘  └────────┬───────┘  └──────┬───────┘   │
│           │                   │                 │           │
├───────────┴───────────────────┴─────────────────┴───────────┤
│  Functions (functions/analyses-functions.R)                  │
│  ┌────────────────────────────────────────────┐             │
│  │ gen_mca_clust_obj (MCA + HCPC)             │             │
│  │ gen_string_clust_obj (STRINGdb walktrap)   │             │
│  │ gen_string_enrich_tib (enrichment)         │             │
│  │ gen_network_edges (STRINGdb interactions)  │ (NEW)       │
│  └────────────────────────────────────────────┘             │
├─────────────────────────────────────────────────────────────┤
│  Caching Layer (memoise + file cache)                       │
│  ┌────────────────────────────────────────────┐             │
│  │ gen_mca_clust_obj_mem (cached MCA)         │             │
│  │ gen_string_clust_obj_mem (cached STRING)   │             │
│  │ gen_network_edges_mem (cached edges)       │ (NEW)       │
│  └────────────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────────┘
```

## Integration Points with Existing Architecture

### 1. Frontend Component Layer

**Existing Pattern:**
- Views in `views/analyses/` are simple wrappers
- Components in `components/analyses/` contain visualization logic
- D3.js visualizations use Options API pattern
- Axios calls to API endpoints in `mounted()` hook

**Integration Approach:**
- **Preserve wrapper pattern**: Create new view `views/analyses/GeneNetworks.vue` (already exists but needs update)
- **New component**: `components/analyses/GeneClusterNetwork.vue` with Cytoscape.js
- **Gradual migration**: New component uses Composition API, existing D3 components unchanged
- **Shared filter components**: Extract reusable filter logic into separate components

**Data Flow:**
```
View (GeneNetworks.vue)
  ↓
Component (GeneClusterNetwork.vue)
  ↓ onMounted
useNetworkData composable
  ↓ axios.get
API endpoint (/api/analysis/network_edges)
  ↓
Cytoscape.js instance
```

### 2. Composables Layer

**Existing Composables:**
- `useTableData.ts`: Per-instance state (pagination, sorting, filters)
- `useUrlParsing.ts`: Filter object ↔ URL string conversion
- `useToast.ts`: Toast notifications
- `useColorAndSymbols.ts`: Color schemes and symbols

**New Composables:**

#### useNetworkData.ts
```typescript
// Manages Cytoscape.js network state
interface NetworkDataOptions {
  clusterId?: string;
  autoLoad?: boolean;
}

export default function useNetworkData(options: NetworkDataOptions = {}) {
  const nodes = ref<Array<CytoscapeNode>>([]);
  const edges = ref<Array<CytoscapeEdge>>([]);
  const loading = ref(false);
  const cytoscapeInstance = ref<cytoscape.Core | null>(null);

  const loadNetworkData = async (clusterId: string) => { /* ... */ };
  const initCytoscape = (container: HTMLElement, options: CytoscapeOptions) => { /* ... */ };

  return {
    nodes,
    edges,
    loading,
    cytoscapeInstance,
    loadNetworkData,
    initCytoscape
  };
}
```

**Rationale:** Follows existing per-instance pattern from `useTableData.ts`. Each component instance gets independent state.

#### useFilterSync.ts
```typescript
// Syncs filter state with URL using VueUse
import { useUrlSearchParams } from '@vueuse/core';

export default function useFilterSync() {
  const params = useUrlSearchParams('history');

  const categoryFilter = computed({
    get: () => params.category || '',
    set: (val) => { params.category = val; }
  });

  const scoreFilter = computed({
    get: () => Number(params.score) || 0.5,
    set: (val) => { params.score = String(val); }
  });

  return {
    categoryFilter,
    scoreFilter,
    clearFilters: () => { params.category = null; params.score = null; }
  };
}
```

**Rationale:** VueUse `useUrlSearchParams` provides reactive URL state sync. Simpler than existing `useUrlParsing.ts` for new components, but both patterns coexist.

### 3. Backend API Layer

**Existing Pattern:**
- Endpoints in `api/endpoints/analysis_endpoints.R`
- Functions in `api/functions/analyses-functions.R`
- Memoise caching with file-based cache manager
- JSON serialization via `jsonlite`

**New Endpoint:**

#### GET /api/analysis/network_edges

```r
#* Retrieve Network Edges for Cluster
#*
#* Returns Cytoscape.js formatted network data (nodes + edges)
#* for protein-protein interactions from STRINGdb.
#*
#* @param cluster_id Cluster identifier (e.g., "1" for main cluster, "1.2" for subcluster)
#* @param score_threshold Minimum interaction score (default: 0.4, range: 0-1)
#*
#* @tag analysis
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns network data in Cytoscape.js format.
#*
#* @get network_edges
function(cluster_id = "1", score_threshold = 0.4) {
  # Get cluster identifiers from cached clustering result
  functional_clusters <- gen_string_clust_obj_mem(genes_from_entity_table$hgnc_id)

  # Filter to requested cluster
  cluster_data <- filter_cluster(functional_clusters, cluster_id)

  # Get network edges
  network_data <- gen_network_edges_mem(
    cluster_data$identifiers$hgnc_id,
    score_threshold
  )

  return(network_data)
}
```

**New Function:**

#### gen_network_edges (in analyses-functions.R)

```r
#' Generate network edges from STRINGdb interactions
#'
#' @param hgnc_list Vector of HGNC IDs
#' @param score_threshold Minimum combined score (0-1)
#'
#' @return List with nodes and edges in Cytoscape.js format
#' @export
gen_network_edges <- function(hgnc_list, score_threshold = 0.4) {
  # Load STRING database
  string_db <- STRINGdb$new(
    version = "11.5",
    species = 9606,
    score_threshold = as.integer(score_threshold * 1000),
    input_directory = "data/"
  )

  # Get gene table with STRING IDs
  sysndd_db_string_id_table <- pool %>%
    tbl("non_alt_loci_set") %>%
    filter(!is.na(STRING_id)) %>%
    select(symbol, hgnc_id, STRING_id) %>%
    collect() %>%
    filter(hgnc_id %in% hgnc_list)

  # Get interactions
  interactions_df <- string_db$get_interactions(
    sysndd_db_string_id_table$STRING_id
  )

  # Transform to Cytoscape.js format
  nodes <- sysndd_db_string_id_table %>%
    transmute(
      data = list(
        id = STRING_id,
        label = symbol,
        hgnc_id = hgnc_id
      )
    )

  edges <- interactions_df %>%
    transmute(
      data = list(
        id = paste0(from, "_", to),
        source = from,
        target = to,
        score = combined_score
      )
    )

  return(list(
    elements = list(
      nodes = nodes,
      edges = edges
    )
  ))
}
```

**Caching Strategy:**
```r
# In start_sysndd_api.R
gen_network_edges_mem <<- memoise(gen_network_edges, cache = cm)
```

**Integration with Existing Functions:**
- Reuses `STRINGdb` initialization pattern from `gen_string_clust_obj`
- Reuses database query pattern from existing functions
- Returns Cytoscape.js compatible JSON structure
- Leverages existing memoise caching infrastructure

### 4. Data Transformation Layer

**Challenge:** STRINGdb returns R data frames, Cytoscape.js expects specific JSON structure.

**Transformation Pattern:**

```r
# R data frame (STRINGdb output)
# protein1, protein2, combined_score
# "9606.ENSP000001", "9606.ENSP000002", 0.85

# Cytoscape.js JSON format
{
  "elements": {
    "nodes": [
      { "data": { "id": "9606.ENSP000001", "label": "BRCA1", "hgnc_id": "HGNC:1100" } }
    ],
    "edges": [
      { "data": { "source": "9606.ENSP000001", "target": "9606.ENSP000002", "score": 0.85 } }
    ]
  }
}
```

**Implementation:**
- Use `tidyr::nest()` pattern (already used in existing clustering functions)
- Transform nested data to list-of-lists for jsonlite serialization
- Auto-boxing handled by Plumber's default `jsonlite::toJSON(auto_unbox=FALSE)`

## Architectural Patterns

### Pattern 1: Composable-Based Cytoscape.js Integration

**What:** Encapsulate Cytoscape.js lifecycle in a composable, not directly in component.

**When to use:** Network visualization components that need reactive data updates.

**Trade-offs:**
- **Pro:** Testable without DOM, reusable across components
- **Pro:** Reactive state updates trigger Cytoscape re-renders automatically
- **Con:** Adds abstraction layer (acceptable for better separation of concerns)

**Example:**
```typescript
// In component
import { useCytoscape } from '@/composables/useCytoscape';
import { onMounted, ref } from 'vue';

export default {
  setup() {
    const containerRef = ref<HTMLElement | null>(null);
    const { initCytoscape, updateElements, cy } = useCytoscape();

    onMounted(() => {
      if (containerRef.value) {
        initCytoscape(containerRef.value, {
          layout: { name: 'cose' },
          style: [/* ... */]
        });
      }
    });

    return { containerRef, updateElements, cy };
  }
}
```

### Pattern 2: Parallel Endpoint Strategy (Cluster + Network)

**What:** Separate endpoints for cluster metadata and network edges, called in parallel.

**When to use:** When cluster information and network data have different caching/performance characteristics.

**Trade-offs:**
- **Pro:** Cluster endpoint cached longer (clusters stable), network endpoint dynamic (filters change)
- **Pro:** Client can request network edges independently for different score thresholds
- **Con:** Two HTTP requests instead of one (mitigated by HTTP/2 multiplexing)

**Example:**
```typescript
// Load cluster metadata (cached, stable)
const clusterResponse = await axios.get('/api/analysis/functional_clustering');

// Load network edges for selected cluster (dynamic, filtered)
const networkResponse = await axios.get('/api/analysis/network_edges', {
  params: { cluster_id: '1', score_threshold: 0.5 }
});
```

### Pattern 3: Filter State in URL (VueUse Pattern)

**What:** Use VueUse `useUrlSearchParams` for bidirectional URL state sync.

**When to use:** New components that need shareable/bookmarkable filter states.

**Trade-offs:**
- **Pro:** Automatic reactivity, simpler than manual URL manipulation
- **Pro:** Shareable URLs, browser back/forward support
- **Pro:** No boilerplate for URL encode/decode
- **Con:** Different pattern from existing `useUrlParsing.ts` (acceptable, gradual migration)

**Example:**
```typescript
import { useUrlSearchParams } from '@vueuse/core';

const params = useUrlSearchParams('history');

// Reading from URL: ?category=GO&score=0.7
const categoryFilter = computed(() => params.category || '');
const scoreFilter = computed(() => Number(params.score) || 0.5);

// Writing to URL: sets ?category=KEGG&score=0.8
categoryFilter.value = 'KEGG';
scoreFilter.value = 0.8;
```

### Pattern 4: Shared Filter Components

**What:** Extract filter UI (dropdowns, sliders) into small reusable components.

**When to use:** Multiple analysis components need same filter types.

**Trade-offs:**
- **Pro:** DRY principle, consistent UX across analysis views
- **Pro:** Single source of truth for filter options
- **Con:** Requires props/events wiring (acceptable, standard Vue pattern)

**Example:**
```vue
<!-- components/filters/CategoryFilter.vue -->
<template>
  <BFormSelect
    :model-value="modelValue"
    :options="categoryOptions"
    @update:model-value="$emit('update:modelValue', $event)"
  />
</template>

<script setup>
defineProps<{ modelValue: string }>();
defineEmits<{ (e: 'update:modelValue', value: string): void }>();

const categoryOptions = [
  { value: '', text: 'All Categories' },
  { value: 'GO', text: 'Gene Ontology' },
  { value: 'KEGG', text: 'KEGG Pathways' }
];
</script>
```

## Data Flow Patterns

### Request Flow: Network Visualization

```
User Action (select cluster)
    ↓
Component (GeneClusterNetwork.vue)
    ↓ watch(selectedCluster)
useNetworkData.loadNetworkData(clusterId)
    ↓ axios.get
Plumber Endpoint (/api/analysis/network_edges?cluster_id=1&score_threshold=0.5)
    ↓
gen_network_edges_mem (check cache)
    ↓ cache miss
gen_network_edges (compute)
    ↓
STRINGdb$get_interactions(string_ids)
    ↓
Transform to Cytoscape.js format
    ↓ return JSON
useCytoscape.updateElements(elements)
    ↓
Cytoscape.js re-renders network
```

### State Management: Filter Synchronization

```
URL (?category=GO&score=0.7)
    ↓ (reactive sync)
useFilterSync composable
    ↓ computed refs
categoryFilter.value = 'GO'
scoreFilter.value = 0.7
    ↓ v-model
Filter Components (CategoryFilter, ScoreSlider)
    ↓ @update:modelValue
categoryFilter.value = 'KEGG' (user changes filter)
    ↓ computed setter
params.category = 'KEGG' (VueUse updates URL)
    ↓ watch(categoryFilter)
loadNetworkData({ category: 'KEGG' })
```

### Caching Flow: Multi-Level Strategy

```
Request: GET /api/analysis/network_edges?cluster_id=1&score_threshold=0.5
    ↓
Check memoise cache (gen_network_edges_mem)
    ↓ hash(hgnc_list, score_threshold)
Cache HIT? → Return cached JSON
    ↓
Cache MISS
    ↓
Compute gen_network_edges(hgnc_list, 0.5)
    ↓
Query STRINGdb (may hit STRINGdb file cache in data/)
    ↓
Transform to Cytoscape.js format
    ↓
Save to memoise cache (file: results/{hash}.json)
    ↓
Return JSON
```

**Cache Invalidation:**
- Cluster data cache: Invalidated when database entities change (rare)
- Network edges cache: Per score_threshold, long-lived (STRINGdb data stable)
- Frontend cache: Browser HTTP cache headers (set by Plumber)

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| **Current (< 1k entities)** | Existing memoise + file cache sufficient. D3.js bubble charts handle current cluster sizes. No changes needed. |
| **1k-5k entities** | Cytoscape.js handles 1k-5k nodes efficiently with cose layout. Consider progressive loading (render visible nodes first). Monitor cluster computation time; may need async endpoints. |
| **5k-10k entities** | Switch Cytoscape.js layout to `preset` or `circle` (faster than `cose`). Implement node aggregation (collapse low-score edges). Consider WebWorker for layout computation. Backend: Add async job endpoints for clustering (already mentioned in analysis_endpoints.R). |
| **10k+ entities** | Virtualization required: Render only visible viewport nodes. Use Cytoscape.js with custom renderer or switch to WebGL-based library (e.g., sigma.js). Backend: Consider pre-computing network hierarchies, store in database. |

### Scaling Priorities

1. **First bottleneck: Cytoscape.js layout computation (5k+ nodes)**
   - **Symptom:** Browser freezes during layout
   - **Fix:** Switch to simpler layout (`circle`, `grid`), or use WebWorker
   - **Timeline:** Unlikely before 5k entities (current: ~1k)

2. **Second bottleneck: STRINGdb clustering computation (10k+ genes)**
   - **Symptom:** API endpoint timeout (> 30s)
   - **Fix:** Implement async job pattern (already designed in comments)
   - **Pattern:**
     ```
     POST /api/jobs/clustering/submit → { job_id: "abc123" }
     GET /api/jobs/abc123/status → { status: "running", progress: 45% }
     GET /api/jobs/abc123/status → { status: "complete", result_url: "/results/abc123" }
     ```
   - **Timeline:** Consider when clustering takes > 10s

3. **Third bottleneck: Network data transfer (large JSON payloads)**
   - **Symptom:** Slow API response (>5MB JSON)
   - **Fix:** Implement pagination/streaming or binary format
   - **Timeline:** Unlikely with current data sizes

## Anti-Patterns to Avoid

### Anti-Pattern 1: Mixing D3.js and Cytoscape.js in Same Component

**What people do:** Try to use D3.js for nodes and Cytoscape.js for edges, or vice versa.

**Why it's wrong:**
- Each library manages its own DOM rendering lifecycle
- Conflicting event handlers and state management
- Performance penalty from running two rendering engines

**Do this instead:**
- Use Cytoscape.js for network visualization exclusively
- Use D3.js for non-network charts (bubble, heatmap) exclusively
- If you need D3-style force simulation in Cytoscape, use Cytoscape's cola layout (based on WebCola, similar to D3 force)

### Anti-Pattern 2: Fetching Full Network on Every Filter Change

**What people do:**
```typescript
// BAD: Re-fetch all edges when score changes
watch(scoreThreshold, async (newScore) => {
  const response = await axios.get('/api/network_edges', {
    params: { score_threshold: newScore }
  });
  updateNetwork(response.data);
});
```

**Why it's wrong:**
- Unnecessary API calls (data already on client)
- Slow user experience
- Server load for client-side filtering task

**Do this instead:**
```typescript
// GOOD: Fetch once, filter client-side
const allEdges = ref([]);

onMounted(async () => {
  const response = await axios.get('/api/network_edges', {
    params: { score_threshold: 0.0 } // Get all edges
  });
  allEdges.value = response.data.edges;
});

const filteredEdges = computed(() => {
  return allEdges.value.filter(edge => edge.data.score >= scoreThreshold.value);
});

watch(filteredEdges, (edges) => {
  cy.value?.edges().remove();
  cy.value?.add(edges);
});
```

### Anti-Pattern 3: Initializing Cytoscape Multiple Times

**What people do:**
```typescript
// BAD: Re-initialize Cytoscape on every data update
watch(networkData, (data) => {
  cytoscape({ container: document.getElementById('cy'), elements: data });
});
```

**Why it's wrong:**
- Memory leak (previous instance not destroyed)
- Loss of user interactions (zoom, pan, selection)
- Poor performance

**Do this instead:**
```typescript
// GOOD: Initialize once, update elements
const cy = ref<cytoscape.Core | null>(null);

onMounted(() => {
  cy.value = cytoscape({
    container: document.getElementById('cy'),
    elements: []
  });
});

watch(networkData, (data) => {
  if (cy.value) {
    cy.value.elements().remove(); // Clear old elements
    cy.value.add(data);           // Add new elements
    cy.value.layout({ name: 'cose' }).run(); // Re-run layout
  }
});

onUnmounted(() => {
  cy.value?.destroy(); // Clean up
});
```

### Anti-Pattern 4: Not Using Existing Composables

**What people do:** Recreate pagination/sorting logic in new network component.

**Why it's wrong:**
- Code duplication
- Inconsistent behavior across components
- Misses existing features (filter state, URL sync patterns)

**Do this instead:**
```typescript
// GOOD: Reuse existing composables for table portions
import useTableData from '@/composables/useTableData';

const {
  perPage,
  currentPage,
  sortBy,
  filter_string
} = useTableData({
  pageSizeInput: 25,
  sortInput: '+score'
});

// Combine with network-specific state
const { nodes, edges } = useNetworkData();
```

## Component Organization

### Recommended File Structure

```
app/src/
├── components/
│   ├── analyses/
│   │   ├── AnalysesPhenotypeClusters.vue       (existing, D3.js)
│   │   ├── AnalyseGeneClusters.vue             (existing, D3.js)
│   │   ├── AnalysesPhenotypeFunctionalCorrelation.vue (existing, D3.js)
│   │   └── GeneClusterNetwork.vue              (NEW, Cytoscape.js)
│   │
│   ├── filters/                                (NEW)
│   │   ├── CategoryFilter.vue                  (NEW)
│   │   ├── ScoreSlider.vue                     (NEW)
│   │   └── TermSearch.vue                      (NEW)
│   │
│   └── small/                                   (existing)
│       ├── GenericTable.vue
│       ├── TableSearchInput.vue
│       └── TablePaginationControls.vue
│
├── composables/
│   ├── useTableData.ts                          (existing)
│   ├── useUrlParsing.ts                         (existing)
│   ├── useToast.ts                              (existing)
│   ├── useNetworkData.ts                        (NEW)
│   ├── useCytoscape.ts                          (NEW)
│   └── useFilterSync.ts                         (NEW)
│
├── views/
│   └── analyses/
│       ├── PhenotypeFunctionalCorrelation.vue   (existing)
│       ├── GeneNetworks.vue                     (existing, needs update)
│       └── PhenotypeCorrelations.vue            (existing)
│
└── types/
    ├── components.ts                            (existing)
    └── cytoscape.ts                             (NEW)
```

### Structure Rationale

- **`components/filters/`**: Extracted filter components promote reuse across analysis views. Small, focused components (Single Responsibility Principle).

- **`composables/useNetworkData.ts`**: Parallel to existing `useTableData.ts`. Encapsulates network-specific state management (nodes, edges, loading).

- **`composables/useCytoscape.ts`**: Separates Cytoscape.js lifecycle from component logic. Enables testing without DOM, reusable across future network components.

- **`composables/useFilterSync.ts`**: URL state synchronization using VueUse pattern. Cleaner API than manual URL parsing for new components (gradual migration from `useUrlParsing.ts`).

- **`types/cytoscape.ts`**: TypeScript definitions for Cytoscape.js elements, matches existing pattern (`types/components.ts`).

## Integration with Backend Caching

### Current Caching Strategy

**File:** `api/start_sysndd_api.R`

```r
# Existing memoization
cm <- cache_mem(max_size = 1024 * 1024^2)  # 1GB cache
gen_string_clust_obj_mem <<- memoise(gen_string_clust_obj, cache = cm)
gen_mca_clust_obj_mem <<- memoise(gen_mca_clust_obj, cache = cm)
```

**Cache Storage:**
- Results saved to `results/{panel_hash}.{function_hash}.{params}.json`
- Panel hash: MD5 of input gene list
- Function hash: Hash of function code (invalidates on function change)

### New Network Endpoint Caching

```r
# Add to start_sysndd_api.R
gen_network_edges_mem <<- memoise(gen_network_edges, cache = cm)
```

**Cache Key Components:**
1. HGNC list (determines protein set)
2. Score threshold (filters edges)

**Cache Behavior:**
- First request: Compute + cache (~5-10s for 100 genes)
- Subsequent requests: Instant (< 100ms)
- Cache invalidation: Only when gene list changes OR score threshold changes
- Cache sharing: Multiple users share cache (same gene list + threshold)

**Cache Size Estimates:**
- 100 genes, 500 edges: ~50KB JSON
- 1000 genes, 5000 edges: ~500KB JSON
- 1GB cache: ~2000 network snapshots

## Technology Choices

### Frontend: Cytoscape.js vs Alternatives

**Cytoscape.js** (Recommended)
- **Pros:**
  - Rich graph analysis algorithms (shortest path, centrality, etc.)
  - Compound nodes support (nested clusters)
  - Extensive layout options (cose, cola, dagre, etc.)
  - Active development, large community
  - Vue 3 wrappers available (`@orbifold/vue-cytoscape`)
- **Cons:**
  - Larger bundle size (~500KB) vs D3.js
  - Learning curve for developers familiar with D3.js

**D3.js force layout** (Already used, not recommended for networks)
- **Pros:** Team already familiar, lightweight
- **Cons:** No graph algorithms, manual edge routing, less performant for large graphs

**Sigma.js** (Not recommended for this milestone)
- **Pros:** WebGL rendering (faster for 10k+ nodes)
- **Cons:** Less mature, fewer layout options, no compound nodes

**Decision:** Cytoscape.js provides best balance of features, performance, and ecosystem support.

### Backend: STRINGdb Package Integration

**Existing Usage:**
```r
string_db <- STRINGdb$new(
  version = "11.5",
  species = 9606,
  score_threshold = 200,
  input_directory = "data"
)
```

**For Network Edges:**
- Use `string_db$get_interactions(string_ids)` method
- Returns data frame: `protein1, protein2, combined_score`
- Score range: 0-1000 (normalize to 0-1 for client)

**Data File Caching:**
- STRINGdb downloads protein links file (~1GB) to `data/`
- Cached permanently (only re-downloads on version change)
- No per-request overhead after initial download

### URL State: VueUse vs Manual Parsing

**VueUse `useUrlSearchParams`** (Recommended for new components)
- **Pros:**
  - Reactive URL sync with zero boilerplate
  - Handles encoding/decoding automatically
  - Type-safe with TypeScript
  - Browser history support
- **Cons:**
  - External dependency (acceptable, widely used)
  - Different pattern from existing `useUrlParsing.ts`

**Existing `useUrlParsing.ts`** (Keep for existing components)
- **Pros:**
  - Custom filter format: `contains(symbol,BRCA),any(category,GO,KEGG)`
  - Already integrated in table components
- **Cons:**
  - Manual encode/decode logic
  - More verbose API

**Decision:** Use VueUse for new network component, keep existing pattern in table components. Gradual migration acceptable.

## Build Order Recommendation

Based on dependencies and integration points:

### Phase 1: Backend Network Endpoint (Foundational)
1. Add `gen_network_edges()` function to `analyses-functions.R`
2. Add memoization wrapper in `start_sysndd_api.R`
3. Add GET `/api/analysis/network_edges` endpoint
4. Test with Postman/curl: Verify Cytoscape.js JSON format

**Rationale:** Frontend development blocked without working endpoint.

### Phase 2: Frontend Composables (Core Logic)
1. Create `useNetworkData.ts` (data fetching)
2. Create `useCytoscape.ts` (Cytoscape lifecycle)
3. Create `useFilterSync.ts` (URL state)
4. Write unit tests for composables

**Rationale:** Composables testable without UI, provides API contract for component.

### Phase 3: Network Component (Visualization)
1. Create `GeneClusterNetwork.vue` component
2. Integrate composables from Phase 2
3. Basic Cytoscape.js rendering (no filters yet)
4. Test with existing cluster endpoint data

**Rationale:** Incremental development, validates composable integration.

### Phase 4: Filter Components (Enhancement)
1. Extract `CategoryFilter.vue`, `ScoreSlider.vue`, `TermSearch.vue`
2. Wire filters to `useFilterSync` composable
3. Implement client-side filtering in `GeneClusterNetwork.vue`
4. Test URL state synchronization

**Rationale:** Filters depend on working network component.

### Phase 5: View Integration (Polish)
1. Update `GeneNetworks.vue` view to use new component
2. Add routing if needed
3. Style consistency with existing analysis views
4. Cross-browser testing

**Rationale:** View is thin wrapper, minimal risk.

### Phase 6: Performance Optimization (Optional)
1. Add progressive loading for large networks (>1k nodes)
2. Optimize Cytoscape.js layout settings
3. Add loading skeletons
4. Monitor and tune memoise cache

**Rationale:** Optimize after validating functionality with real usage.

## Sources

**Cytoscape.js Integration:**
- [GitHub - rcarcasses/vue-cytoscape](https://github.com/rcarcasses/vue-cytoscape)
- [vue-cytoscape documentation](https://rcarcasses.github.io/vue-cytoscape/)
- [@orbifold/vue-cytoscape - npm](https://www.npmjs.com/package/@orbifold/vue-cytoscape)
- [Cytoscape.js official documentation](https://js.cytoscape.org/)

**Cytoscape.js Architecture:**
- [Cytoscape.js GitHub](https://github.com/cytoscape/cytoscape.js)
- [Cytoscape.js and Cytoscape Manual](https://manual.cytoscape.org/en/stable/Cytoscape.js_and_Cytoscape.html)
- [Introduction to Cytoscape.js: Visualizing Graphs in the Browser](https://gili842.medium.com/introduction-to-cytoscape-js-visualizing-graphs-in-the-browser-ce09ad6aa610)

**Cytoscape.js Data Format:**
- [Cytoscape.js Data Model Documentation](https://js.cytoscape.org/)
- [Elements JSON serialisation discussion](https://github.com/cytoscape/cytoscape.js/issues/2201)
- [GraphSpace Network Model](http://manual.graphspace.org/en/latest/GraphSpace_Network_Model.html)

**Vue 3 Composable Patterns:**
- [Composables | Vue.js](https://vuejs.org/guide/reusability/composables.html)
- [Design Patterns and best practices with the Composition API in Vue 3](https://medium.com/@davisaac8/design-patterns-and-best-practices-with-the-composition-api-in-vue-3-77ba95cb4d63)
- [Good practices and Design Patterns for Vue Composables](https://dev.to/jacobandrewsky/good-practices-and-design-patterns-for-vue-composables-24lk)

**VueUse URL State Sync:**
- [useUrlSearchParams | VueUse](https://vueuse.org/core/useurlsearchparams/)
- [VueUse GitHub - useUrlSearchParams source](https://github.com/vueuse/vueuse/blob/main/packages/core/useUrlSearchParams/index.ts)

**R Plumber API:**
- [Plumber Quickstart](https://www.rplumber.io/articles/quickstart.html)
- [Rendering Output in Plumber](https://www.rplumber.io/articles/rendering-output.html)
- [REST APIs with plumber Cheatsheet](https://rstudio.github.io/cheatsheets/html/plumber.html)

**STRINGdb R Package:**
- [STRINGdb R Documentation](https://www.rdocumentation.org/packages/STRINGdb/versions/1.8.1/topics/STRINGdb)
- [STRINGdb Bioconductor Manual](https://bioc.r-universe.dev/STRINGdb/doc/manual.html)
- [Network Analysis in Systems Biology with R/Bioconductor - PPI Networks](https://almeidasilvaf.github.io/NASB/chapters/04_analysis_of_PPI_networks.html)

**D3.js vs Cytoscape.js Comparison:**
- [CytoscapeJS vs. D3 graph drawing discussion](https://groups.google.com/g/cytoscape-discuss/c/Ny8_1HuT0vo)
- [Best Libraries and Methods to Render Large Network Graphs](https://weber-stephen.medium.com/the-best-libraries-and-methods-to-render-large-network-graphs-on-the-web-d122ece2f4dc)
- [Cytoscape tools for the web age: D3.js and Cytoscape.js exporters](https://www.researchgate.net/publication/269765189_Cytoscape_tools_for_the_web_age_D3js_and_Cytoscapejs_exporters)

---
*Architecture research for: Analysis Modernization (Cytoscape.js + Clustering Optimization)*
*Researched: 2026-01-24*
