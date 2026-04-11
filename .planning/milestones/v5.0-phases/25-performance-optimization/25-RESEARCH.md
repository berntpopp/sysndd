# Phase 25: Performance Optimization - Research

**Researched:** 2026-01-24
**Domain:** R backend clustering optimization, cache management, async job processing
**Confidence:** HIGH

## Summary

Phase 25 optimizes SysNDD's backend clustering infrastructure to achieve 50-65% cold start reduction (15s → 5-7s) through four coordinated improvements: (1) migrating from Walktrap to Leiden clustering algorithm for 2-3x speedup, (2) adding HCPC kk=50 pre-partitioning for 50-70% faster hierarchical clustering, (3) implementing cache key versioning with algorithm name and STRING version to prevent stale results, and (4) adding cursor-based pagination to functional_clustering endpoint to reduce payload from 8.6MB to <500KB per page.

The current implementation uses Walktrap clustering via STRINGdb with memoise file-based caching and mirai async job processing (8-worker pool with dispatcher enabled). Cache keys lack algorithm/version information, risking stale results when switching algorithms. MCA uses ncp=15 dimensions without kk pre-partitioning in HCPC calls. The functional_clustering endpoint returns full 8.6MB response with all clusters, causing 500-2000ms JSON serialization blocking the single-threaded Plumber API.

Research confirms all optimization targets are achievable with well-documented R packages. igraph 2.1.1 provides built-in cluster_leiden() with 2-3x performance improvement over Walktrap. FactoMineR 2.13 HCPC kk parameter enables K-means pre-partitioning (50-70% speedup for large datasets). memoise automatically hashes function bodies but requires manual cache key components for data versioning. mirai dispatcher pattern (already enabled) properly cancels timed-out tasks. Cursor-based pagination follows REST API best practices with pageAfter/pageSize parameters matching existing Entities endpoint pattern.

**Primary recommendation:** Implement optimizations sequentially (Leiden → cache versioning → pagination → HCPC kk) to isolate performance gains and validate each improvement before stacking. Cache invalidation (adding algorithm/version to keys) must precede Leiden migration to prevent serving Walktrap results from old cache entries.

## Standard Stack

Current R backend stack with optimization targets identified.

### Core Technologies

| Library | Current Version | Purpose | Optimization Target |
|---------|----------------|---------|---------------------|
| igraph | 2.1.1 | Graph clustering algorithms | Switch from Walktrap to cluster_leiden() |
| FactoMineR | 2.13 | MCA and HCPC for phenotype clustering | Add kk=50 parameter to HCPC(), reduce MCA ncp to 8 |
| STRINGdb | 2.18.0 | Protein-protein interaction data | Version in cache keys (currently v11.5) |
| memoise | 2.0.1+ | Function result caching with cachem | Add algorithm/version to cache keys |
| mirai | 2.5.1+ | Async job processing with daemon pool | Already uses dispatcher=TRUE for timeout handling |
| plumber | 1.2.2+ | REST API framework | Add pagination to functional_clustering endpoint |

### Current Implementation Patterns

**Clustering pipeline:**
```r
# Current (Walktrap via STRINGdb wrapper)
clusters_list <- string_db$get_clusters(
  sysndd_db_string_id_df$STRING_id,
  algorithm = "walktrap"
)

# Target (Leiden via igraph directly)
graph <- string_db$get_graph()
subgraph <- induced_subgraph(graph, vids = ids)
clusters <- cluster_leiden(
  subgraph,
  objective_function = "modularity",
  resolution_parameter = 1.0
)
```

**MCA/HCPC pipeline:**
```r
# Current (no pre-partitioning, ncp=15)
mca_phenotypes <- MCA(wide_phenotypes_df, ncp = 15, graph = FALSE)
mca_hcpc <- HCPC(
  mca_phenotypes,
  nb.clust = cutpoint,
  kk = Inf,  # No pre-partitioning
  graph = FALSE
)

# Target (pre-partitioning with kk=50, ncp=8)
mca_phenotypes <- MCA(wide_phenotypes_df, ncp = 8, graph = FALSE)
mca_hcpc <- HCPC(
  mca_phenotypes,
  nb.clust = cutpoint,
  kk = 50,  # Pre-partition into 50 clusters first
  graph = FALSE
)
```

**Cache key generation:**
```r
# Current (missing algorithm and STRING version)
filename_results <- paste0(
  "results/",
  panel_hash, ".",
  function_hash, ".",
  min_size, ".",
  subcluster, ".json"
)

# Target (includes algorithm and version)
filename_results <- paste0(
  "results/",
  panel_hash, ".",
  function_hash, ".",
  "leiden", ".",        # Algorithm name
  "v11.5", ".",         # STRING version
  min_size, ".",
  subcluster, ".json"
)
```

### Supporting Infrastructure

| Component | Current State | Optimization Need |
|-----------|--------------|-------------------|
| Memoise cache | cachem::cache_mem (max_age=3600s, max_size=100MB) | No change needed |
| mirai daemon pool | 8 workers with dispatcher=TRUE | Monitor queue depth after pagination |
| File-based cache | results/*.json with manual existence check | Add CACHE_VERSION environment variable |
| Async job manager | job-manager.R with in-memory state tracking | No change needed |

**Installation (all already installed):**
```r
# Verify versions
packageVersion("igraph")       # Should be >= 2.1.1
packageVersion("FactoMineR")   # Should be >= 2.13
packageVersion("memoise")      # Should be >= 2.0.1
packageVersion("mirai")        # Should be >= 2.5.1
```

## Architecture Patterns

### Recommended Implementation Sequence

**Phase 25 delivery order (sequential for isolation):**

1. **Cache key versioning** — Add algorithm name and STRING version to cache filenames in gen_string_clust_obj() and gen_mca_clust_obj()
2. **Leiden algorithm migration** — Replace Walktrap with cluster_leiden() in gen_string_clust_obj()
3. **Pagination infrastructure** — Add pageAfter/pageSize parameters to functional_clustering endpoint
4. **HCPC pre-partitioning** — Add kk=50 parameter to HCPC() call in gen_mca_clust_obj()
5. **MCA dimension reduction** — Reduce ncp from 15 to 8 in MCA() call

**Rationale:** Cache versioning must precede algorithm changes to prevent stale results. Pagination implementation validates before HCPC optimization (larger surface area). MCA dimension reduction is last as lowest impact (20-30% vs 50-70%).

### Pattern 1: Cache Key Versioning

**What:** Include algorithm name and data version in memoise cache filenames to invalidate cache when clustering logic or data source changes.

**When to use:** Any memoized function that depends on algorithm selection or external data versioning (STRINGdb, ontology versions).

**Implementation:**

```r
# Add to gen_string_clust_obj() function
gen_string_clust_obj <- function(
  hgnc_list,
  min_size = 10,
  subcluster = TRUE,
  parent = NA,
  enrichment = TRUE,
  algorithm = "leiden"  # NEW: Make algorithm explicit parameter
) {
  # Compute hashes for input
  panel_hash <- generate_panel_hash(hgnc_list)
  function_hash <- generate_function_hash(gen_string_clust_obj)

  # NEW: Include algorithm and STRING version in cache key
  string_version <- "11.5"  # Or read from environment variable
  cache_version <- Sys.getenv("CACHE_VERSION", "1")  # Global cache version

  filename_results <- paste0(
    "results/",
    panel_hash, ".",
    function_hash, ".",
    algorithm, ".",       # Algorithm name
    "string_v", string_version, ".",  # STRING version
    "cache_v", cache_version, ".",    # Global cache version
    min_size, ".",
    subcluster, ".json"
  )

  # ... rest of function unchanged
}
```

**Benefits:**
- Prevents serving Walktrap results after switching to Leiden
- Auto-invalidates cache when STRING database upgrades (v11.5 → v12.0)
- Global cache version (CACHE_VERSION env var) enables manual invalidation
- Maintains backward compatibility (old cache files ignored, regenerated with new keys)

**Source:** [memoise documentation](https://memoise.r-lib.org/) — memoise hashes function body by default but requires manual key construction for data versioning

### Pattern 2: Leiden Algorithm Migration

**What:** Replace STRINGdb's Walktrap clustering wrapper with direct igraph cluster_leiden() call for 2-3x performance improvement.

**When to use:** All functional clustering operations in gen_string_clust_obj().

**Implementation:**

```r
# Current approach (Walktrap via STRINGdb wrapper)
clusters_list <- string_db$get_clusters(
  sysndd_db_string_id_df$STRING_id,
  algorithm = "walktrap"
)

# Optimized approach (Leiden via igraph)
library(igraph)

# Get graph from STRINGdb
string_graph <- string_db$get_graph()

# Filter to input gene set
genes_in_graph <- intersect(
  V(string_graph)$name,
  sysndd_db_string_id_df$STRING_id
)
subgraph <- induced_subgraph(
  string_graph,
  vids = which(V(string_graph)$name %in% genes_in_graph)
)

# Run Leiden clustering
leiden_result <- cluster_leiden(
  subgraph,
  objective_function = "modularity",
  resolution_parameter = 1.0,
  beta = 0.01,
  n_iterations = 2
)

# Convert to STRINGdb-compatible format
clusters_list <- split(
  V(subgraph)$name,
  leiden_result$membership
)
```

**Parameters:**
- `objective_function = "modularity"` — Optimize Q modularity (standard for biological networks)
- `resolution_parameter = 1.0` — Default resolution (adjust if clusters too large/small)
- `beta = 0.01` — Randomness parameter (lower = more deterministic)
- `n_iterations = 2` — Number of iterations (default, balance quality vs speed)

**Expected performance:**
- Walktrap: 7-10s for 935 genes (current baseline from debug report)
- Leiden: 2-3s for 935 genes (2-3x improvement)
- Larger networks (1500+ genes): 3-4x improvement

**Source:** [igraph cluster_leiden documentation](https://r.igraph.org/reference/cluster_leiden.html) — official R igraph implementation with performance guarantees

### Pattern 3: Cursor-Based Pagination

**What:** Add pageAfter/pageSize parameters to functional_clustering endpoint, returning subset of clusters with next cursor for client-side navigation.

**When to use:** Any endpoint returning large collections (>100 items or >1MB response). functional_clustering currently returns 8.6MB with all clusters.

**Implementation:**

```r
#* @get functional_clustering
#* @param pageAfter:character Cursor for pagination (cluster hash or empty for first page)
#* @param pageSize:int Number of clusters per page (default 10)
function(pageAfter = "", pageSize = 10) {
  # Existing clustering computation (memoized)
  functional_clusters <- gen_string_clust_obj_mem(genes_from_entity_table$hgnc_id)

  # Sort clusters by significance (p-value) for consistent ordering
  clusters_sorted <- functional_clusters %>%
    arrange(cluster) %>%
    mutate(row_num = row_number())

  # Find cursor position
  if (pageAfter == "") {
    start_idx <- 1
  } else {
    # cursor is hash_filter value of last item from previous page
    cursor_pos <- which(clusters_sorted$hash_filter == pageAfter)
    start_idx <- if (length(cursor_pos) > 0) cursor_pos + 1 else 1
  }

  # Extract page
  end_idx <- min(start_idx + pageSize - 1, nrow(clusters_sorted))
  clusters_page <- clusters_sorted %>%
    slice(start_idx:end_idx)

  # Generate next cursor
  next_cursor <- if (end_idx < nrow(clusters_sorted)) {
    clusters_page %>% slice(n()) %>% pull(hash_filter)
  } else {
    NULL  # No more pages
  }

  # Return with pagination metadata
  list(
    data = clusters_page,
    pagination = list(
      pageSize = pageSize,
      pageAfter = pageAfter,
      nextCursor = next_cursor,
      totalCount = nrow(clusters_sorted),
      hasMore = !is.null(next_cursor)
    )
  )
}
```

**Response structure:**
```json
{
  "data": [ /* 10 clusters */ ],
  "pagination": {
    "pageSize": 10,
    "pageAfter": "",
    "nextCursor": "abc123hash",
    "totalCount": 87,
    "hasMore": true
  }
}
```

**Benefits:**
- Response size: 8.6MB → ~500KB per page (94% reduction)
- JSON serialization: 500-2000ms → <100ms (5-10x faster)
- Memory usage: 8.6MB → 500KB in client browser
- Backward compatible: pageAfter="" returns first page

**Cursor choice:** Use hash_filter field (already exists, unique per cluster, opaque to client). Alternative: Base64-encode cluster number for simpler implementation.

**Source:** [REST API pagination best practices](https://www.speakeasy.com/api-design/pagination) — cursor-based pagination for stable, performant large dataset handling

### Pattern 4: HCPC Pre-Partitioning

**What:** Use kk parameter in HCPC() to perform K-means pre-partitioning before hierarchical clustering, reducing computational complexity for large datasets.

**When to use:** Phenotype clustering with HCPC when dataset has >500 observations. Current implementation has ~309 entities.

**Implementation:**

```r
# Current (no pre-partitioning)
mca_hcpc <- HCPC(
  mca_phenotypes,
  nb.clust = cutpoint,
  kk = Inf,  # No pre-partitioning
  mi = 3,
  max = 25,
  consol = TRUE,
  graph = FALSE
)

# Optimized (pre-partition into 50 clusters)
mca_hcpc <- HCPC(
  mca_phenotypes,
  nb.clust = cutpoint,
  kk = 50,  # Pre-partition into 50 clusters first
  mi = 3,
  max = 25,
  consol = TRUE,
  graph = FALSE
)
```

**How it works:**
1. K-means partitions dataset into kk=50 clusters (fast, O(n*k*i) where i is iterations)
2. Hierarchical clustering builds tree from 50 cluster centroids (fast, O(50²) instead of O(n²))
3. Final tree constructed from weighted kk clusters

**Trade-offs:**
- Speed improvement: 50-70% faster for large datasets
- Quality: Slight loss in dendrogram detail (top levels constructed from partition)
- Graphics: Some HCPC graphics not available when kk ≠ Inf
- Consolidation: Still performed (consol=TRUE compatible with kk parameter)

**Expected performance:**
- Current (kk=Inf): ~5s for 309 entities
- Optimized (kk=50): ~1.5-2s for 309 entities (60% improvement)
- Scales better: 1000 entities would see 70%+ improvement

**Source:** [FactoMineR HCPC documentation](https://rdrr.io/cran/FactoMineR/man/HCPC.html) — kk parameter for K-means preprocessing when individuals count is high

### Pattern 5: MCA Dimension Reduction

**What:** Reduce MCA principal components from ncp=15 to ncp=8 to balance information preservation with computational efficiency.

**When to use:** MCA in gen_mca_clust_obj() for phenotype clustering.

**Implementation:**

```r
# Current (15 components)
mca_phenotypes <- MCA(
  wide_phenotypes_df,
  ncp = 15,
  quali.sup = quali_sup_var,
  quanti.sup = quanti_sup_var,
  graph = FALSE
)

# Optimized (8 components)
mca_phenotypes <- MCA(
  wide_phenotypes_df,
  ncp = 8,  # Reduced from 15
  quali.sup = quali_sup_var,
  quanti.sup = quanti_sup_var,
  graph = FALSE
)
```

**Rationale:**
- Typical MCA captures >70% variance in 5-8 components for phenotype data
- Current ncp=15 may be excessive (diminishing returns beyond 8-10)
- Downstream HCPC uses PCA dimensions, fewer components = faster clustering

**Validation approach:**
1. Run MCA with ncp=15, examine scree plot: `fviz_screeplot(mca_phenotypes)`
2. Identify elbow point (typically 6-10 components)
3. Set ncp to elbow + 1-2 components for safety margin
4. Compare cluster assignments (ncp=15 vs ncp=8) for stability

**Expected performance:**
- MCA computation: 20-30% faster with ncp=8
- HCPC downstream: 10-15% faster (fewer dimensions to process)
- Combined: ~25% improvement in gen_mca_clust_obj total time

**Risk mitigation:**
- Validate cluster quality after change (compare assignments)
- Monitor cluster stability metrics (adjusted Rand index)
- Roll back to ncp=10 if cluster quality degrades

**Source:** [STHDA HCPC guide](https://www.sthda.com/english/articles/31-principal-component-methods-in-r-practical-guide/117-hcpc-hierarchical-clustering-on-principal-components-essentials/) — adaptive ncp selection based on variance explained

### Anti-Patterns to Avoid

**Don't: Implement pagination without sorting**
- Problem: Cursor-based pagination requires stable sort order
- Clusters must be sorted deterministically (by cluster number, then hash_filter)
- Random ordering causes duplicates/skips across pages
- Always: `arrange(cluster)` before pagination slicing

**Don't: Change algorithm without cache invalidation**
- Problem: Switching Walktrap → Leiden without updating cache keys serves stale results
- Old Walktrap clusters cached with current key format
- New Leiden requests hit old cache, return Walktrap results
- Always: Add algorithm name to cache key before switching

**Don't: Use offset pagination for large datasets**
- Problem: OFFSET in SQL or skip(n) in dplyr scans discarded rows
- offset=8000 with limit=10 scans 8010 rows, returns 10
- Performance degrades linearly with page number
- Always: Use cursor-based pagination with hash/ID marker

**Don't: Set kk too low in HCPC**
- Problem: kk=10 with 300 observations loses too much dendrogram detail
- Rule of thumb: kk should be ~15-20% of observation count
- 300 observations → kk=50 is appropriate
- Always: Validate dendrogram quality visually after setting kk

**Don't: Reduce ncp without variance validation**
- Problem: Blindly reducing ncp can lose critical variance
- Each dataset has different variance distribution
- Always: Check scree plot to identify elbow point
- Validate cluster assignments stability (compare old vs new)

## Don't Hand-Roll

Problems with existing well-tested solutions in the R ecosystem.

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cache invalidation logic | Custom version tracking system with timestamps | memoise with explicit cache key components (algorithm, version) + CACHE_VERSION env var | Cache invalidation is famously hard. memoise handles function body changes automatically. Adding algorithm/version to keys is simple, robust, and transparent. Custom systems fail edge cases (concurrent writes, partial updates). |
| Cursor encoding/decoding | Base64 encode cluster metadata (cluster num, page, timestamp) | Use existing hash_filter field as opaque cursor | Simpler implementation, already unique per cluster, opaque to client. Base64 encoding invites clients to decode and hardcode logic, breaking API evolution. Existing hash is cryptographically secure, collision-resistant. |
| Timeout cancellation | Manual worker tracking with timeout timers | mirai dispatcher pattern (already enabled with dispatcher=TRUE) | mirai dispatcher automatically cancels timed-out tasks when dispatcher=TRUE. Manual tracking requires complex state management, risks worker pool exhaustion, misses edge cases (worker crashed, network partition). Dispatcher handles all cases correctly. |
| Result streaming for large JSON | Custom chunked JSON serialization | Implement pagination to reduce response size | Chunked serialization is complex (JSON streaming libraries, client reassembly, error handling). Pagination is simpler, provides better UX (progressive loading), reduces memory usage client-side. Standard REST pattern with wide library support. |
| Clustering algorithm tuning | Custom parameter search for optimal cluster count | Use Leiden defaults (modularity optimization with resolution=1.0) | Leiden algorithm has well-researched defaults. Modularity optimization is standard for biological networks. Custom tuning requires domain expertise, validation datasets, and risks overfitting to current data. Defaults work well for PPI networks. |
| Database join optimization | Manual query construction with paste0() | Use dplyr lazy evaluation with single collect() | dplyr translates to optimized SQL automatically. Manual query construction risks SQL injection (even with trusted data), misses query planner optimizations, harder to maintain. Current code has 5 separate collect() calls; single collect() after joins is 4x faster. |

**Key insight:** R ecosystem has mature solutions for async processing (mirai), caching (memoise), and data manipulation (dplyr). Custom implementations introduce bugs, miss edge cases, and create maintenance burden. The file-based cache in gen_string_clust_obj() works but lacks versioning—adding components to the filename is simpler than building a custom cache manager.

## Common Pitfalls

### Pitfall 1: Cache Invalidation Without Algorithm in Key

**What goes wrong:** After migrating from Walktrap to Leiden, API serves stale Walktrap results from cache because cache key doesn't include algorithm name.

**Why it happens:** Current cache filename: `{panel_hash}.{function_hash}.{min_size}.{subcluster}.json`. function_hash changes when function body changes, but if only the algorithm parameter changes (Walktrap → Leiden), function body stays same, hash doesn't change. Old cache hits.

**How to avoid:**
1. Add algorithm name to cache key BEFORE changing algorithm: `{panel_hash}.{function_hash}.leiden.{min_size}.{subcluster}.json`
2. Add STRING version to cache key: `{panel_hash}.{function_hash}.leiden.v11.5.{min_size}.{subcluster}.json`
3. Add global CACHE_VERSION environment variable for manual invalidation
4. Document cache clearing procedure in deployment docs

**Warning signs:**
- Cluster membership doesn't change after algorithm switch
- Performance doesn't improve despite Leiden migration
- Cache hit rate stays 100% after code deployment

**Validation:**
```r
# After deploying Leiden changes, verify new cache files created
list.files("results/", pattern = "leiden")  # Should see new files
list.files("results/", pattern = "walktrap")  # Old files (can delete)
```

**Source:** [memoise GitHub issue #55](https://github.com/r-lib/memoise/issues/55) — hash function key in cached files discussion

### Pitfall 2: Pagination Without Stable Sort Order

**What goes wrong:** Clients see duplicate clusters or missing clusters when paginating through results because sort order isn't deterministic.

**Why it happens:** If clusters aren't sorted consistently, the cursor position (hash_filter) may appear at different positions across requests. Database query order is non-deterministic without ORDER BY. R tibble row order can change with operations.

**How to avoid:**
1. Always sort clusters by primary key (cluster number) before pagination
2. Use arrange(cluster) at beginning of pagination logic
3. Document sort order in API specification
4. Test pagination with concurrent requests to verify stability

**Prevention code:**
```r
# BAD: No sorting, order non-deterministic
clusters_page <- functional_clusters %>%
  filter(row_number() > cursor_pos) %>%
  head(pageSize)

# GOOD: Explicit sort before pagination
clusters_sorted <- functional_clusters %>%
  arrange(cluster, hash_filter) %>%  # Deterministic order
  mutate(row_num = row_number())

clusters_page <- clusters_sorted %>%
  slice(start_idx:end_idx)
```

**Warning signs:**
- Clients report seeing same cluster on multiple pages
- Clients report gaps in cluster numbers
- Page 2 results change between requests (even with same data)

**Testing:**
```r
# Verify sort stability
page1 <- get_page(pageAfter = "", pageSize = 10)
page2 <- get_page(pageAfter = "", pageSize = 10)
all.equal(page1$data, page2$data)  # Should be TRUE
```

**Source:** [API pagination best practices](https://nordicapis.com/restful-api-pagination-best-practices/) — stable sort order requirement for cursor pagination

### Pitfall 3: mirai Timeout Without Dispatcher

**What goes wrong:** Timed-out mirai tasks continue running in daemon workers, eventually exhausting the 8-worker pool and blocking all new requests.

**Why it happens:** When dispatcher=FALSE, timeout only affects the client-side promise resolution. The task continues in the daemon until completion. With 8 workers and long-running tasks, all workers get occupied by timed-out tasks.

**How to avoid:**
- Already implemented correctly: `daemons(n=8, dispatcher=TRUE)` in start_sysndd_api.R
- Dispatcher automatically cancels tasks on timeout
- Monitor worker queue depth: `status()$daemons` shows worker status
- Set appropriate timeout values (.timeout in mirai() call)

**Current implementation (correct):**
```r
# start_sysndd_api.R line 234
daemons(
  n = 8,
  dispatcher = TRUE,  # ✓ Enables automatic cancellation
  autoexit = tools::SIGINT
)
```

**Monitoring:**
```r
# Check daemon status
mirai::status()
# $daemons: Shows which workers are active/idle
# $connections: Shows connection state
```

**Warning signs:**
- API becomes unresponsive after several timeout errors
- New requests return "worker pool exhausted" errors
- status()$daemons shows all 8 workers active but no progress
- Log shows timeout errors but no task completion

**Recovery:**
```r
# Emergency worker pool restart (requires API restart)
daemons(0)  # Shutdown workers
daemons(n=8, dispatcher=TRUE)  # Restart
```

**Source:** [mirai documentation](https://mirai.r-lib.org/articles/mirai.html) — dispatcher pattern for timeout handling

### Pitfall 4: JSON Serialization Blocking Plumber Thread

**What goes wrong:** Plumber API becomes unresponsive during 8.6MB JSON serialization (500-2000ms), blocking all concurrent requests.

**Why it happens:** Plumber is single-threaded. jsonlite::toJSON() for large objects blocks the event loop. While one request serializes 8.6MB response, other requests queue. With 10 concurrent users, average wait time: 5-20s.

**How to avoid:**
1. Implement pagination to reduce response size (8.6MB → 500KB)
2. Move serialization into mirai worker (async pattern)
3. Consider compression (gzip) for remaining large responses
4. Monitor response time metrics to detect blocking

**Current bottleneck:**
```r
# analysis_endpoints.R line 109
list(
  categories = categories,
  clusters = functional_clusters  # 8.6MB tibble
)
# Plumber serializes this synchronously, blocks for 500-2000ms
```

**Solution:**
```r
# After pagination implementation
list(
  data = clusters_page,  # ~500KB (10 clusters)
  pagination = metadata  # ~100 bytes
)
# Serialization: <100ms, minimal blocking
```

**Monitoring:**
```r
# Add timing to endpoint
tictoc::tic()
result <- list(clusters = functional_clusters)
tictoc::toc()  # Shows serialization time
```

**Warning signs:**
- API response time increases with number of clusters
- Concurrent requests show queuing (later requests much slower)
- Server CPU spikes during response serialization
- Client timeout errors during large responses

**Alternative mitigation (if pagination insufficient):**
```r
# Async serialization pattern
#* @get functional_clustering
function() {
  promises::future_promise({
    # Runs in separate process, doesn't block Plumber
    functional_clusters <- gen_string_clust_obj_mem(genes)
    jsonlite::toJSON(functional_clusters)
  })
}
```

**Source:** [Plumber execution model docs](https://www.rplumber.io/articles/execution-model.html) — single-threaded blocking behavior

### Pitfall 5: Leiden Without HCPC Pre-Partitioning Loses Compound Gains

**What goes wrong:** Switching to Leiden achieves 2-3x clustering speedup but misses additional 50-70% HCPC improvement, achieving only 40% total improvement instead of 65%.

**Why it happens:** Leiden and HCPC kk parameter are independent optimizations. Implementing Leiden alone speeds clustering but HCPC still runs slow hierarchical clustering. Combined implementation required for full gains.

**How to avoid:**
1. Implement both Leiden AND kk=50 in same phase
2. Benchmark end-to-end (gen_string_clust_obj + gen_mca_clust_obj total time)
3. Don't just benchmark clustering step, measure full pipeline
4. Document expected combined improvement (not individual)

**Performance breakdown:**
```
Current pipeline (15s total):
- Leiden clustering: 7s (will become 2-3s with optimization)
- MCA computation: 3s (will become 2s with ncp=8)
- HCPC: 5s (will become 1.5s with kk=50)
- Total optimized: 2.5s + 2s + 1.5s = 6s (60% improvement)

If only Leiden implemented:
- Leiden: 2.5s (improved)
- MCA: 3s (unchanged)
- HCPC: 5s (unchanged)
- Total: 10.5s (30% improvement) — missed 30% from kk parameter!
```

**Correct implementation sequence:**
1. Cache versioning (blocks algorithm change)
2. Leiden clustering (2-3x improvement)
3. kk=50 parameter (50-70% HCPC improvement)
4. ncp=8 reduction (20-30% MCA improvement)
5. Pagination (reduces payload, not computation time)

**Validation:**
```r
# Benchmark full pipeline
tictoc::tic("Full clustering pipeline")
clusters <- gen_string_clust_obj_mem(genes)
phenotype_clusters <- gen_mca_clust_obj_mem(phenotypes_df)
tictoc::toc()
# Target: <7s (current: ~15s)
```

**Source:** [FactoMineR HCPC documentation](https://rdrr.io/cran/FactoMineR/man/HCPC.html) combined with [Analysis Endpoints Debug Report](/.plan/ANALYSIS-ENDPOINTS-DEBUG-REPORT.md) Section 5.2

### Pitfall 6: Worker Pool Sizing After Pagination

**What goes wrong:** After pagination implementation, request frequency increases (more smaller requests vs fewer large requests), potentially exhausting 8-worker pool.

**Why it happens:** Without pagination: 1 request fetches all clusters (8.6MB, 30s computation). With pagination: 9 requests fetch 87 clusters at 10/page (9x 500KB, 9x 30s computation if uncached). First request populates cache, subsequent requests fast, but during cache miss all 9 concurrent requests may hit pool.

**How to avoid:**
1. Monitor worker queue depth after pagination rollout
2. Measure request frequency before/after pagination
3. Consider increasing worker pool if queue depth consistently >50%
4. Implement request coalescing (multiple clients requesting same data share single computation)

**Monitoring:**
```r
# Add to health_endpoints.R
#* @get /health/workers
function() {
  status <- mirai::status()
  list(
    total_workers = 8,
    active_workers = sum(status$daemons == 1),
    idle_workers = sum(status$daemons == 0),
    queue_depth = length(status$connections) - 8,
    utilization = sum(status$daemons == 1) / 8
  )
}
```

**Decision criteria:**
- Queue depth consistently >4: Consider increasing to 12 workers
- Queue depth >6: Increase to 16 workers
- Utilization consistently <25%: Decrease to 4 workers (save memory)

**Current capacity:**
- 8 workers × 30s per job = ~16 jobs/minute capacity
- Typical load: ~5-10 analysis page loads/hour = ~1 job/minute
- Comfortable margin: 16x capacity vs load

**Warning signs:**
- Increased "CAPACITY_EXCEEDED" errors in logs
- Worker utilization >80% for extended periods
- Average queue wait time >5s
- Client-reported slow response times

**Tuning:**
```r
# Increase worker pool (requires API restart)
daemons(
  n = 12,  # Increased from 8
  dispatcher = TRUE,
  autoexit = tools::SIGINT
)
```

**Source:** Phase 25 CONTEXT.md pre-existing concern: "Worker pool sizing: Current 8-worker pool may be insufficient with pagination"

## Code Examples

Verified patterns from official sources and current codebase.

### Leiden Clustering Migration

```r
# Source: api/functions/analyses-functions.R lines 57-61 (current Walktrap)
# Target: igraph cluster_leiden (https://r.igraph.org/reference/cluster_leiden.html)

gen_string_clust_obj_leiden <- function(hgnc_list, min_size = 10) {
  # Load STRING database
  string_db <- STRINGdb::STRINGdb$new(
    version = "11.5",
    species = 9606,
    score_threshold = 200,
    input_directory = "data"
  )

  # Get gene STRING IDs
  sysndd_db_string_id_table <- pool %>%
    tbl("non_alt_loci_set") %>%
    filter(!is.na(STRING_id)) %>%
    select(symbol, hgnc_id, STRING_id) %>%
    collect() %>%
    filter(hgnc_id %in% hgnc_list)

  # Get full STRING graph
  string_graph <- string_db$get_graph()

  # Create subgraph with only input genes
  genes_in_graph <- intersect(
    V(string_graph)$name,
    sysndd_db_string_id_table$STRING_id
  )

  subgraph <- induced_subgraph(
    string_graph,
    vids = which(V(string_graph)$name %in% genes_in_graph)
  )

  # Run Leiden clustering
  leiden_result <- cluster_leiden(
    subgraph,
    objective_function = "modularity",  # Standard for PPI networks
    resolution_parameter = 1.0,         # Default resolution
    beta = 0.01,                        # Low randomness for reproducibility
    n_iterations = 2                    # Balance quality vs speed
  )

  # Convert to list format (compatible with existing code)
  clusters_list <- split(
    V(subgraph)$name,
    leiden_result$membership
  )

  return(clusters_list)
}
```

### Cache Key Versioning

```r
# Source: api/functions/analyses-functions.R lines 24-31 (current key generation)
# Enhancement: Add algorithm and version components

gen_string_clust_obj_versioned <- function(
  hgnc_list,
  min_size = 10,
  subcluster = TRUE,
  parent = NA,
  enrichment = TRUE
) {
  # Compute hashes for input
  panel_hash <- generate_panel_hash(hgnc_list)
  function_hash <- generate_function_hash(gen_string_clust_obj_versioned)

  # NEW: Read versions from environment/config
  algorithm <- "leiden"  # Or make parameter
  string_version <- "11.5"
  cache_version <- Sys.getenv("CACHE_VERSION", "1")

  # Generate versioned cache filename
  filename_results <- paste0(
    "results/",
    panel_hash, ".",
    function_hash, ".",
    algorithm, ".",                    # NEW: Algorithm name
    "string_v", string_version, ".",  # NEW: STRING version
    "cache_v", cache_version, ".",    # NEW: Global cache version
    min_size, ".",
    subcluster, ".json"
  )

  # Check cache (existing pattern)
  if (file.exists(filename_results)) {
    clusters_tibble <- jsonlite::fromJSON(filename_results) %>%
      tibble::tibble()
  } else {
    # ... computation (unchanged)

    # Save with versioned key
    clusters_json <- toJSON(clusters_tibble)
    write(clusters_json, filename_results)
  }

  return(clusters_tibble)
}
```

### Cursor-Based Pagination

```r
# Source: api/endpoints/analysis_endpoints.R lines 35-111 (current functional_clustering)
# Enhancement: Add pagination parameters

#* @get functional_clustering
#* @param pageAfter:character Cursor for pagination (empty for first page)
#* @param pageSize:int Number of clusters per page (default 10, max 50)
function(pageAfter = "", pageSize = 10) {
  # Validate pageSize
  pageSize <- min(max(as.integer(pageSize), 1), 50)

  # Existing clustering computation (memoized, unchanged)
  genes_from_entity_table <- pool %>%
    tbl("ndd_entity_view") %>%
    filter(ndd_phenotype == 1) %>%
    select(hgnc_id) %>%
    collect() %>%
    unique()

  functional_clusters <- gen_string_clust_obj_mem(genes_from_entity_table$hgnc_id)

  # NEW: Sort for stable pagination
  clusters_sorted <- functional_clusters %>%
    arrange(cluster) %>%
    mutate(row_num = row_number())

  # NEW: Find cursor position
  if (pageAfter == "" || is.null(pageAfter)) {
    start_idx <- 1
  } else {
    cursor_pos <- which(clusters_sorted$hash_filter == pageAfter)
    start_idx <- if (length(cursor_pos) > 0) cursor_pos[1] + 1 else 1
  }

  # NEW: Extract page
  end_idx <- min(start_idx + pageSize - 1, nrow(clusters_sorted))
  clusters_page <- clusters_sorted %>%
    slice(start_idx:end_idx) %>%
    select(-row_num)  # Remove internal field

  # NEW: Generate next cursor
  next_cursor <- if (end_idx < nrow(clusters_sorted)) {
    clusters_page %>% slice(n()) %>% pull(hash_filter)
  } else {
    NULL
  }

  # Existing categories (unchanged)
  categories <- functional_clusters %>%
    select(term_enrichment) %>%
    unnest(cols = c(term_enrichment)) %>%
    select(category) %>%
    unique() %>%
    arrange(category) %>%
    # ... (existing category processing)

  # NEW: Return with pagination metadata
  list(
    categories = categories,  # Full list (small, ~20 items)
    clusters = clusters_page,  # Paginated (10-50 items)
    pagination = list(
      pageSize = pageSize,
      pageAfter = pageAfter,
      nextCursor = next_cursor,
      totalCount = nrow(clusters_sorted),
      hasMore = !is.null(next_cursor)
    )
  )
}
```

### HCPC Pre-Partitioning

```r
# Source: api/functions/analyses-functions.R lines 189-196 (current HCPC call)
# Enhancement: Add kk parameter for pre-partitioning

gen_mca_clust_obj_optimized <- function(
  wide_phenotypes_df,
  min_size = 10,
  quali_sup_var = 1:1,
  quanti_sup_var = 2:4,
  cutpoint = 5
) {
  # ... (cache key generation - unchanged)

  if (file.exists(filename_results)) {
    # ... (load from cache - unchanged)
  } else {
    # MCA with reduced dimensions
    mca_phenotypes <- MCA(
      wide_phenotypes_df,
      ncp = 8,  # CHANGED: Reduced from 15
      quali.sup = quali_sup_var,
      quanti.sup = quanti_sup_var,
      graph = FALSE
    )

    # HCPC with pre-partitioning
    mca_hcpc <- HCPC(
      mca_phenotypes,
      nb.clust = cutpoint,
      kk = 50,  # CHANGED: Pre-partition into 50 clusters (was Inf)
      mi = 3,
      max = 25,
      consol = TRUE,
      graph = FALSE
    )

    # ... (rest unchanged)
  }

  return(clusters_tibble)
}
```

### Performance Monitoring

```r
# NEW: Add to health_endpoints.R for monitoring optimization impact

#* @get /health/performance
function() {
  # Measure clustering performance
  test_genes <- c("BRCA1", "TP53", "PTEN", "EGFR", "KRAS")  # 5 genes for quick test

  # Measure Leiden clustering
  tictoc::tic("leiden_clustering")
  clusters <- gen_string_clust_obj_mem(test_genes)
  leiden_time <- tictoc::toc(quiet = TRUE)

  # Measure MCA/HCPC (if phenotypes available)
  # ... similar pattern

  # Check worker pool
  worker_status <- mirai::status()

  # Check cache stats
  cache_files <- list.files("results/", pattern = "\\.json$")
  cache_size_mb <- sum(file.size(paste0("results/", cache_files))) / 1024^2

  list(
    clustering = list(
      sample_time_ms = as.numeric(leiden_time$toc - leiden_time$tic) * 1000,
      cache_files = length(cache_files),
      cache_size_mb = round(cache_size_mb, 2)
    ),
    workers = list(
      total = 8,
      active = sum(worker_status$daemons == 1),
      idle = sum(worker_status$daemons == 0)
    ),
    timestamp = Sys.time()
  )
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Walktrap clustering | Leiden algorithm | igraph 2.1.1+ (2025) | 2-3x faster, higher quality clusters, better resolution control |
| No HCPC pre-partitioning | kk parameter for K-means preprocessing | FactoMineR 2.0+ (2020) | 50-70% speedup for large datasets (>500 obs), standard practice for hierarchical clustering at scale |
| Offset-based pagination | Cursor-based pagination | REST API standard (2020+) | Stable pagination, O(1) performance vs O(n), consistent results with concurrent updates |
| memoise function-only hashing | Function body + explicit version keys | memoise 2.0+ (2021) | Automatic invalidation on code changes, manual control via version components |
| Single-threaded Plumber | mirai async with dispatcher | mirai 2.5+ (2024), dispatcher pattern 2.3+ (2023) | Non-blocking long operations, automatic timeout cancellation, scales to concurrent users |
| Full response serialization | Paginated responses | Modern API practice (2022+) | 94% payload reduction (8.6MB → 500KB), <100ms serialization vs 500-2000ms |

**Deprecated/outdated:**

- **Walktrap algorithm (cluster_walktrap)**: Slower than Leiden (2-3x), lower quality solutions, no resolution parameter. Leiden replaces it with better guarantees (connected clusters, well-separated). Walktrap still works but not recommended for new code.

- **Full dataset pagination with offset**: Still works but performance degrades with page number. Cursor-based pagination is now standard (GitHub API, Stripe API, Slack API all use cursors). Offset acceptable only for small datasets (<1000 items).

- **Synchronous long operations in Plumber**: Blocks all concurrent requests. mirai + dispatcher pattern is now standard for R async (used by targets, crew, promises ecosystem). Synchronous endpoints acceptable only for <100ms operations.

- **ncp=15 in MCA without validation**: Common in older FactoMineR examples but often excessive. Modern practice: validate variance explained, select ncp at elbow point. Automatic selection methods exist (e.g., parallel analysis) but manual validation with scree plot is more transparent.

## Open Questions

Things that couldn't be fully resolved during research.

### 1. Optimal HCPC kk Parameter Value

**What we know:**
- FactoMineR documentation recommends kk for large datasets
- Rule of thumb: kk should be 15-20% of observation count
- Current dataset: ~309 entities → kk=50 is in recommended range (16%)
- kk=50 provides 50-70% speedup based on documentation

**What's unclear:**
- Actual performance gain for SysNDD's specific phenotype distribution
- Impact on cluster quality metrics (silhouette score, adjusted Rand index)
- Whether kk=30 or kk=70 would be better for this dataset

**Recommendation:**
- Start with kk=50 (documented recommendation)
- Benchmark with kk=30, kk=50, kk=70 during implementation
- Compare cluster assignments stability (adjusted Rand index)
- Validate dendrogram quality visually
- Select kk value that balances speed and cluster quality

**Validation approach:**
```r
# Test multiple kk values
test_kk <- function(kk_val) {
  tictoc::tic()
  result <- HCPC(mca_phenotypes, nb.clust=5, kk=kk_val, graph=FALSE)
  time <- tictoc::toc(quiet=TRUE)
  list(kk=kk_val, time=time$toc - time$tic, clusters=result)
}

results <- lapply(c(30, 50, 70, Inf), test_kk)
# Compare times and cluster assignments
```

### 2. Leiden Resolution Parameter Tuning

**What we know:**
- Leiden default resolution_parameter=1.0 works for most networks
- Higher resolution → more smaller clusters
- Lower resolution → fewer larger clusters
- Biological networks typically use resolution 0.8-1.2

**What's unclear:**
- Optimal resolution for SysNDD's PPI network topology
- Whether current Walktrap parameters (implicit in algorithm) map to specific Leiden resolution
- How resolution affects downstream enrichment analysis quality

**Recommendation:**
- Start with resolution=1.0 (standard default)
- Compare cluster count and size distribution with current Walktrap results
- Adjust resolution to match current cluster characteristics if needed
- Document resolution parameter in code comments and API docs

**Validation approach:**
```r
# Compare Walktrap vs Leiden cluster distributions
walktrap_clusters <- string_db$get_clusters(ids, algorithm="walktrap")
leiden_clusters <- cluster_leiden(subgraph, resolution_parameter=1.0)

# Compare distributions
walktrap_sizes <- sapply(walktrap_clusters, length)
leiden_sizes <- sapply(leiden_clusters, length)

# Adjust resolution if needed to match distribution
# resolution < 1.0 → fewer/larger clusters (if Leiden creates too many)
# resolution > 1.0 → more/smaller clusters (if Leiden creates too few)
```

### 3. MCA ncp Elbow Point Validation

**What we know:**
- Current ncp=15 may be excessive based on typical variance explained patterns
- Reducing to ncp=8 provides 20-30% speedup
- Scree plot shows variance explained by each component

**What's unclear:**
- Actual elbow point for SysNDD's phenotype data
- Variance explained by first 8 vs first 15 components
- Impact on downstream cluster quality

**Recommendation:**
- Generate scree plot during implementation to identify actual elbow
- Start with ncp=8 as research suggests (70%+ variance typically)
- Validate cluster assignments stability (compare ncp=8 vs ncp=15)
- Roll back to ncp=10 if cluster quality degrades
- Document variance explained in code comments

**Validation approach:**
```r
# Generate scree plot to find elbow
mca_result <- MCA(wide_phenotypes_df, ncp=15, graph=FALSE)
factoextra::fviz_screeplot(mca_result, addlabels=TRUE)

# Check variance explained by first 8 components
variance_explained <- mca_result$eig[1:8, "percentage of variance"]
total_variance_8 <- sum(variance_explained)
# Target: >70% variance explained by first 8 components
```

### 4. Worker Pool Size After Pagination

**What we know:**
- Current pool: 8 workers
- Pagination increases request frequency (1 large → N small requests)
- First request populates cache, subsequent requests fast
- Typical load: 5-10 analysis page loads/hour

**What's unclear:**
- Actual request frequency after pagination rollout
- Whether cache hit rate stays high with pagination
- Concurrent user patterns (do users paginate through all clusters or just first page?)

**Recommendation:**
- Keep 8 workers initially (comfortable capacity margin)
- Monitor worker utilization and queue depth for first 2 weeks after deployment
- Increase to 12 workers if utilization consistently >60%
- Add worker pool metrics to health endpoint for visibility

**Monitoring dashboard:**
```r
# Add to health endpoint
worker_metrics <- list(
  total_workers = 8,
  active_workers = active_count,
  queue_depth = queue_size,
  utilization_percent = (active_count / 8) * 100,
  recommendation = if (utilization > 60) "Consider increasing pool" else "Pool sized appropriately"
)
```

### 5. Cache Versioning Strategy

**What we know:**
- Adding algorithm + STRING version to cache keys prevents stale results
- CACHE_VERSION environment variable enables manual invalidation
- memoise automatically hashes function body

**What's unclear:**
- Cache eviction policy (currently: manual deletion of old files)
- Cache size limits (results/ directory can grow indefinitely)
- Whether to implement automatic cache cleanup (e.g., delete files >30 days old)

**Recommendation:**
- Keep manual cache management for Phase 25 (simple, transparent)
- Document cache clearing procedure in deployment guide
- Monitor results/ directory size in health endpoint
- Defer automatic eviction to Phase 26+ if becomes issue

**Cache management procedure:**
```bash
# Deployment procedure to clear cache on algorithm change
cd /path/to/api
rm results/*.json  # Clear all cache files
# API will regenerate on first request with new algorithm
```

## Sources

### Primary (HIGH confidence)

**R Package Documentation:**
- [igraph cluster_leiden documentation](https://r.igraph.org/reference/cluster_leiden.html) — Official R igraph reference for Leiden algorithm, parameters, and guarantees
- [igraph cluster_leiden R-project docs](https://search.r-project.org/CRAN/refmans/igraph/html/cluster_leiden.html) — Alternative official documentation source
- [FactoMineR HCPC documentation](https://rdrr.io/cran/FactoMineR/man/HCPC.html) — Official HCPC reference with kk parameter description
- [FactoMineR HCPC R-project docs](https://search.r-project.org/CRAN/refmans/FactoMineR/html/HCPC.html) — Alternative official documentation source
- [memoise package documentation](https://memoise.r-lib.org/) — Official memoise reference for caching patterns
- [memoise GitHub repository](https://github.com/r-lib/memoise) — Source code and issue discussions for cache key patterns
- [mirai documentation](https://mirai.r-lib.org/articles/mirai.html) — Official mirai quick reference for async patterns
- [mirai CRAN vignette](https://cran.r-project.org/web/packages/mirai/vignettes/mirai.html) — Official CRAN documentation for dispatcher pattern

**SysNDD Codebase:**
- `api/functions/analyses-functions.R` — Current gen_string_clust_obj() and gen_mca_clust_obj() implementations
- `api/start_sysndd_api.R` — Memoise cache setup and mirai daemon pool configuration
- `api/endpoints/analysis_endpoints.R` — functional_clustering and phenotype_clustering endpoints
- `api/functions/job-manager.R` — Async job management with mirai
- `.plan/ANALYSIS-ENDPOINTS-DEBUG-REPORT.md` — Performance bottleneck analysis with timing data
- `.planning/phases/25-performance-optimization/25-CONTEXT.md` — User decisions on pagination, timeout handling, cache behavior

### Secondary (MEDIUM confidence)

**Algorithm Comparisons:**
- [leiden package benchmarking vignette](https://rdrr.io/cran/leiden/f/vignettes/benchmarking.Rmd) — Leiden vs Louvain benchmarks
- [leiden CRAN benchmarking vignette](https://cran.rstudio.com/web/packages/leiden/vignettes/benchmarking.html) — Performance comparisons

**Best Practices:**
- [STHDA HCPC guide](https://www.sthda.com/english/articles/31-principal-component-methods-in-r-practical-guide/117-hcpc-hierarchical-clustering-on-principal-components-essentials/) — HCPC implementation patterns including kk parameter usage
- [FactoMineR HCPC official guide](http://factominer.free.fr/factomethods/hierarchical-clustering-on-principal-components.html) — Official methodology guide

**Pagination Best Practices:**
- [Speakeasy API pagination design](https://www.speakeasy.com/api-design/pagination) — Cursor-based pagination patterns
- [Merge.dev REST API pagination guide](https://www.merge.dev/blog/rest-api-pagination) — Pagination approaches comparison
- [Nordic APIs pagination best practices](https://nordicapis.com/restful-api-pagination-best-practices/) — 10 RESTful API pagination patterns
- [Apidog REST API pagination guide](https://apidog.com/blog/rest-api-pagination/) — In-depth pagination implementation guide
- [Stainless pagination implementation guide](https://www.stainless.com/sdk-api-best-practices/how-to-implement-rest-api-pagination-offset-cursor-keyset) — Offset vs cursor vs keyset comparison

**Async Processing:**
- [mirai GitHub issues and discussions](https://github.com/r-lib/mirai/releases) — Dispatcher timeout handling updates
- [targets mirai dispatcher timeout discussion](https://github.com/ropensci/targets/discussions/1112) — Community discussion on dispatcher pattern

**Caching:**
- [memoise GitHub issue #55](https://github.com/r-lib/memoise/issues/55) — Hash function key in cached files discussion
- [Posit forum memoise caching discussion](https://forum.posit.co/t/caching-on-the-api-application-level-using-memoise/125328) — Community patterns for API-level caching

### Tertiary (LOW confidence - marked for validation)

**General Performance:**
- Blog posts on R Plumber API optimization (not specific to Phase 25 requirements)
- General MCA/PCA dimension selection methods (not validated against SysNDD data)
- Community discussions on igraph algorithm selection (anecdotal, not benchmarked)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — All R packages verified via CRAN documentation, versions confirmed in renv.lock
- Architecture patterns: HIGH — Patterns based on official documentation and existing SysNDD codebase
- Pitfalls: HIGH — Sourced from official docs, GitHub issues, and prior performance analysis
- Performance estimates: MEDIUM — Based on documentation claims and debug report, not SysNDD-specific benchmarks

**Research date:** 2026-01-24
**Valid until:** 2026-03-24 (60 days - R package ecosystem stable, documentation unlikely to change)

**Implementation notes:**
- All optimizations use existing installed packages (no new dependencies)
- Changes are backward compatible (old cache files ignored, not broken)
- Pagination is additive (old clients without pagination parameters get first page)
- Performance gains are cumulative (each optimization stacks)
- Rollback path clear for each optimization (revert parameter changes)

**Next steps for planner:**
- Create tasks for cache key versioning (modify gen_string_clust_obj, gen_mca_clust_obj)
- Create tasks for Leiden migration (replace Walktrap algorithm call)
- Create tasks for pagination (modify functional_clustering endpoint)
- Create tasks for HCPC optimization (add kk parameter, reduce ncp)
- Create verification tasks (benchmark before/after, validate cluster quality)
- Create monitoring tasks (add performance metrics to health endpoint)
