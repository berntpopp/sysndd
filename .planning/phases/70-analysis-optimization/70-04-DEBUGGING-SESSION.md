# Phase 70: Post-Verification Debugging Session

**Date:** 2026-02-03
**Trigger:** User reported 2GB RAM spikes and 60+ second blocking requests on GeneNetworks page
**Status:** Resolved

## Problem Statement

After Phase 70 plans were executed, the following issues remained:
1. Each visit to `/GeneNetworks` caused a 2GB RAM spike in the R process
2. Requests blocked for 60+ seconds due to repeated STRING API calls
3. STRINGdb was re-initializing on every request (version check to string-db.org)

## Root Cause Analysis

### Issue 1: STRINGdb Repeated Initialization
- `STRINGdb::STRINGdb$new()` was called fresh on every clustering request
- Each initialization performs HTTP request to `https://string-db.org/api/tsv-no-header/version`
- This added ~500ms latency per request even with cached data

### Issue 2: Large Objects Not Cleaned Up
- `string_db$get_graph()` loads entire PPI network (~20M edges) into memory
- Large intermediate objects (`subgraph`, `cluster_result`, `layout_matrix`) persisted after function return
- R's garbage collector doesn't return memory to OS, but rm() + gc() reduces peak usage

### Issue 3: Mirai Worker Isolation
- Initial singleton cache was placed in `start_sysndd_api.R`
- Mirai workers source `analyses-functions.R` directly and don't inherit parent environment
- Singleton needed to be in the file that workers actually source

## Solution Implemented

### 1. STRINGdb Singleton Cache (analyses-functions.R)

Added at top of file:
```r
# STRINGdb singleton cache - reuse across requests to avoid repeated API version checks
# Each score_threshold gets its own cached instance
string_db_cache <- new.env(parent = emptyenv())

get_string_db <- function(score_threshold = 400L) {
 cache_key <- as.character(score_threshold)
 if (!exists(cache_key, envir = string_db_cache)) {
   message(sprintf("[STRING] Initializing STRINGdb singleton (threshold=%d)...", score_threshold))
   string_db_cache[[cache_key]] <- STRINGdb::STRINGdb$new(
     version = "11.5",
     species = 9606,
     score_threshold = score_threshold,
     input_directory = "data"
   )
   message(sprintf("[STRING] STRINGdb singleton ready (threshold=%d)", score_threshold))
 }
 string_db_cache[[cache_key]]
}
```

Replaced all `STRINGdb::STRINGdb$new()` calls with `get_string_db()`.

### 2. Explicit Memory Cleanup (analyses-functions.R)

Added to `gen_string_clust_obj()`:
```r
# Memory cleanup - remove large objects before returning
rm(string_db, subgraph, cluster_result, clusters_list)
gc(verbose = FALSE)
```

Added to `gen_network_edges()`:
```r
# Memory cleanup - remove large intermediate objects
rm(string_graph, subgraph, edge_list, layout_matrix, layout_normalized)
rm(string_to_hgnc, gene_table, cluster_map, node_degrees)
gc(verbose = FALSE)
```

### 3. Endpoint-Level GC (analysis_endpoints.R)

Added after network_edges endpoint:
```r
gc(verbose = FALSE)
```

## Files Modified

| File | Changes |
|------|---------|
| `api/functions/analyses-functions.R` | Added `string_db_cache` env, `get_string_db()` function, memory cleanup in `gen_string_clust_obj()` and `gen_network_edges()` |
| `api/endpoints/analysis_endpoints.R` | Added `gc()` after network_edges endpoint |
| `api/start_sysndd_api.R` | Removed duplicate singleton (moved to analyses-functions.R), added reference comment |

## Performance Results

### Before Optimization
- Cold cache: 60-70 seconds (STRING API version check + graph load)
- Memory spike: +2GB per request
- Memory not released between requests

### After Optimization
- **Cold cache:** 60-70 seconds (first request only, unavoidable STRING graph load)
- **Warm cache:** ~1 second (memoise disk cache hit)
- **Memory spike:** +630MB (reduced from 2GB)
- **Memory stable:** 2.8GB baseline after warmup

### Docker Resource Monitoring

```
NAME                  CPU %     MEM USAGE / LIMIT   MEM %
sysndd-api-1          0.78%     2.823GiB / 4.5GiB   62.74%
sysndd_mysql          1.52%     532.5MiB / 1GiB     52.00%
sysndd_app            1.61%     168.7MiB / 2GiB     8.24%
```

### Cache Status
- Location: `/app/cache/` (Docker volume `api_cache`)
- Size: 4.3MB after tests
- Persistence: Survives container restarts

## Testing Performed

1. **Health endpoint:** Verified API running on port 7777
2. **Network edges endpoint:** Warm cache response in ~1 second
3. **Functional clustering endpoint:** Warm cache response in ~1 second
4. **Memory monitoring:** Confirmed stable at 2.8GB after multiple requests
5. **Cache verification:** Confirmed disk cache growing and persisting

## Recommendations for Future

1. **Cache Pre-warming:** Consider initializing common gene set caches on API startup to eliminate 60-second cold start wait for users
2. **Async Processing:** Move clustering to async job queue for large gene sets (>100 genes)
3. **Memory Headroom:** Current 4.5GB limit is adequate; consider 6GB for safety if deploying with more workers

## Verification Commands

```bash
# Check API memory usage
docker stats --no-stream sysndd-api-1

# Check cache size
docker exec sysndd-api-1 du -sh /app/cache/

# Test warm cache performance
time docker exec sysndd_traefik wget -q -O - \
  "http://api:7777/api/analysis/network_edges?gene_list=STXBP1,SCN1A,KCNQ2"

# Check API logs for singleton initialization
docker logs sysndd-api-1 2>&1 | grep -i "STRING"
```

---

*Session documented: 2026-02-03*
*Outcome: Performance optimized, memory stable, caching working correctly*
