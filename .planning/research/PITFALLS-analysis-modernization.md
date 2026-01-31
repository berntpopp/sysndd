# Pitfalls Research

**Domain:** Adding Cytoscape.js Network Visualization + R Clustering Optimization to Vue 3 + R/Plumber App
**Researched:** 2026-01-24
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Memory Leaks from Cytoscape.js Instance Lifecycle

**What goes wrong:**
When navigating between Vue 3 route views or toggling components, Cytoscape.js instances accumulate in memory without being garbage collected. Each new instance allocates canvas memory and element caches, consuming 50-200MB per instance depending on graph size. With the current 8.6MB functional_clustering response, a single undestroyed instance could retain 100-300MB of memory including canvases and internal caches.

**Why it happens:**
Vue 3's Composition API doesn't automatically clean up third-party library instances. Developers forget to call `cy.destroy()` in `onBeforeUnmount`, or they store the Cytoscape instance in reactive refs that create additional references preventing garbage collection. The vue-cytoscape wrapper for Vue 2 doesn't work with Vue 3 (issue #96 on GitHub), forcing manual integration where cleanup is easily overlooked.

**How to avoid:**
1. Store Cytoscape instance in a non-reactive variable (`let cy` not `const cy = ref()`)
2. Always call `cy.destroy()` in `onBeforeUnmount` lifecycle hook
3. Clear all references to the instance (`cy = null`) after destroy
4. Test memory usage with Chrome DevTools heap snapshots when navigating between analysis pages
5. Verify instance cleanup by checking `cy.destroyed()` returns true

**Warning signs:**
- Browser memory usage increases 100-300MB each time user navigates to cluster analysis page
- Tab crashes after 5-10 navigation cycles
- Performance Monitor shows "Detached DOM tree" warnings for canvas elements
- DevTools heap snapshot shows multiple Cytoscape instances with same graph ID

**Phase to address:**
Phase 25-02 (Cytoscape.js Integration) — implement proper lifecycle management during initial integration to avoid expensive refactoring later.

---

### Pitfall 2: Performance Cliff with Edge Rendering at Scale

**What goes wrong:**
Network visualization becomes unusable when rendering STRING protein-protein interaction edges. With typical gene clusters of 50-200 genes, STRING networks can have 200-2000 edges. Canvas rendering degrades severely beyond 2000 edges (5+ second redraws), and multigraph edges with bezier curves are 3-5x more expensive. Edge arrows with semitransparency are >2x slower than opaque arrows. Users experience frozen UI during pan/zoom operations.

**Why it happens:**
The current D3.js bubble chart implementation shows no edges, so developers underestimate edge rendering cost. Cytoscape.js's default canvas renderer recomputes bezier curves and arrows on every frame during interactions. High DPI displays (Retina/4K) multiply rendering cost by pixelRatio (typically 2-3x). The cose-bilkent layout algorithm is expensive (2-10 seconds for 100-500 nodes) and must complete before first render.

**How to avoid:**
1. Use `hideEdgesOnViewport: true` in Cytoscape config to hide edges during pan/zoom/drag
2. Set `pixelRatio: 1` in init options for large graphs (accept slight blur on Retina displays)
3. Simplify edge styling: opaque arrows, no shadows, solid colors
4. Use fcose layout instead of cose-bilkent (2x faster, same aesthetics per GitHub docs)
5. For networks >500 nodes, switch to WebGL renderer (preview in v3.31, production in later versions)
6. Implement progressive loading: show clusters first, load edges on user interaction
7. Add UI warning when network exceeds 1000 nodes + 2000 edges

**Warning signs:**
- Layout computation takes >5 seconds for 200-node graphs
- Pan/zoom operations lag with visible frame drops
- Browser DevTools Performance tab shows >100ms "Recalculate Style" blocks
- Canvas render calls dominate main thread time (>80% in profiler)
- Users report "browser tab unresponsive" warnings

**Phase to address:**
Phase 25-02 (Cytoscape.js Integration) — implement performance optimizations from the start. Phase 25-03 (Advanced Features) adds WebGL fallback for large networks.

---

### Pitfall 3: Cache Invalidation Strategy Missing for Leiden Migration

**What goes wrong:**
Existing memoise file-based cache stores Walktrap clustering results using panel_hash + function_hash + parameters as keys. When switching from Walktrap to Leiden algorithm, old cached results are served because `generate_function_hash()` hashes function body content, but algorithm selection happens inside `string_db$get_clusters()` call. Users see wrong cluster assignments. Worse, if STRINGdb version upgrades from v11.5 to v12.0, cached results use obsolete protein namespace causing incorrect network edges.

**Why it happens:**
The current `gen_string_clust_obj` function (lines 12-110 in analyses-functions.R) generates cache filename from function body hash, not from critical configuration like STRINGdb version or algorithm choice. Memoise package has no automatic invalidation when function internals change. The cache persists across API restarts unless manually cleared. Developers assume function_hash captures algorithm changes, but it only hashes the R function definition, not the stringdb object's internal state.

**How to avoid:**
1. Include algorithm name and STRINGdb version in cache key: `paste0(panel_hash, ".", function_hash, ".", "leiden", ".", "v11.5", ".", min_size, ".", subcluster, ".json")`
2. Implement cache versioning: add CACHE_VERSION environment variable, increment on breaking changes
3. Add cache expiry using memoise's `max_age` parameter (e.g., 30 days for analysis results)
4. Document cache clearing procedure in deployment docs: `rm -rf api/results/*.json`
5. Create `/api/admin/cache/clear` endpoint for manual cache invalidation (require admin auth)
6. Log cache hits/misses to detect staleness issues early

**Warning signs:**
- Different cluster results between fresh computation and cached response
- Network edges connect to wrong genes after STRINGdb upgrade
- Users report "cluster changed when I refreshed" but cache wasn't cleared
- Git diffs show algorithm change but integration tests still pass (using old cached data)
- Cache directory grows unbounded (100s of MB after months)

**Phase to address:**
Phase 25-01 (Performance Optimization) — fix cache invalidation when implementing Leiden algorithm to prevent wrong results in production.

---

### Pitfall 4: R Plumber Single-Threading Bottleneck with Large JSON Responses

**What goes wrong:**
The current functional_clustering endpoint returns 8.6MB JSON response. With R's single-threaded nature, serializing this to JSON via jsonlite takes 500-2000ms, during which the entire Plumber API is blocked. If two users request clustering simultaneously, the second request waits 15s (cold start) + 2s (serialization) = 17s. Response compression (gzip) adds another 200-500ms on the main thread. The API appears frozen during serialization.

**Why it happens:**
Plumber serializes all responses synchronously on the main R thread. Large tibbles with nested lists (clusters containing gene lists containing metadata) create deep object trees that jsonlite must recursively traverse. The current mirai async implementation only handles the clustering computation, not the JSON serialization. Each filter and endpoint must complete quickly, but 8.6MB JSON serialization violates this principle.

**How to avoid:**
1. Implement pagination for `/api/analysis/functional_clustering`: return 10-20 clusters per page, not all 50+
2. Add `/api/analysis/functional_network` endpoint that returns Cytoscape JSON format (smaller, pre-structured)
3. Move serialization into mirai worker: serialize to JSON in background thread, return pre-serialized string
4. Use binary serialization (application/octet-stream) for large responses, deserialize client-side
5. Enable Plumber's built-in response compression only for responses <500KB
6. Run multiple Plumber processes behind load balancer (already have mirai 8-worker pool)
7. Pre-warm cache on API startup: compute common clustering results during init

**Warning signs:**
- `/api/analysis/functional_clustering` returns HTTP 200 but takes 5-15 seconds
- Plumber logs show "serialization time: 1500ms" for clustering endpoints
- Other API endpoints (e.g., gene search) timeout during clustering request
- htop shows single R process at 100% CPU during "waiting for response" phase
- API becomes unresponsive when 2+ users access analysis pages simultaneously

**Phase to address:**
Phase 25-01 (Performance Optimization) — implement pagination and optimize serialization to prevent API blocking. This is infrastructure for Phase 25-02's Cytoscape integration.

---

### Pitfall 5: mirai Timeout Without Cancellation in Clustering Operations

**What goes wrong:**
When clustering computation exceeds the `.timeout` value in mirai async call, the mirai resolves to errorValue 5L (timed out) in the API process, but the clustering computation continues running in the daemon process until completion. This wastes worker resources for 15+ seconds. If user retries, multiple abandoned computations accumulate, exhausting the 8-worker pool. New requests queue indefinitely waiting for workers.

**Why it happens:**
Without dispatcher, mirai tasks continue to completion even after timeout in host process (documented in mirai 2.3.0 release notes). The current implementation uses raw mirai without dispatcher. Developers set aggressive timeouts (e.g., 10s) to improve perceived responsiveness, but this creates more problems than it solves when computations genuinely need 15s.

**How to avoid:**
1. Always use `mirai::dispatcher()` with `mirai()` calls to enable automatic cancellation on timeout
2. Set realistic timeouts: 30s for clustering (not 10s) based on actual performance metrics
3. Implement exponential backoff in frontend: wait 2s, 4s, 8s before retry on timeout
4. Add worker pool monitoring: log available workers, queue length, timeout frequency
5. Return HTTP 202 Accepted with job ID for long operations (already implemented for other endpoints)
6. Use job status polling endpoint for clustering results instead of synchronous mirai
7. Test timeout behavior: simulate slow clustering, verify worker returns to pool

**Warning signs:**
- htop shows 8 R daemon processes all at 100% CPU but API reports "no workers available"
- API logs show "mirai timed out" but worker logs show "clustering completed 20s later"
- Clustering endpoint returns 504 Gateway Timeout during normal load (not high traffic)
- mirai worker pool exhaustion errors after 8 concurrent requests
- Logs show duplicate clustering computations for same panel_hash (retries without cancellation)

**Phase to address:**
Phase 25-01 (Performance Optimization) — implement dispatcher pattern when optimizing clustering to ensure timeouts actually free resources.

---

### Pitfall 6: Leiden Algorithm Migration Without Pre-Partitioning

**What goes wrong:**
Replacing Walktrap with Leiden provides faster community detection (2-3x speedup per IEEE 2026 study), but naive implementation still takes 8-12s on 500-node graphs. The real performance gain requires HCPC pre-partitioning: run Leiden on pre-partitioned graph using `kk` parameter. Without pre-partitioning, the HCPC step becomes the new bottleneck (10-15s) because it performs hierarchical clustering on the full correlation matrix instead of on Leiden-identified communities.

**Why it happens:**
Documentation emphasizes Leiden's speed over Louvain, but doesn't mention that HCPC (used for functional analysis) needs `kk` parameter to leverage Leiden's pre-partitioning. Developers implement Leiden as drop-in replacement for Walktrap without modifying the HCPC call. The 50-70% speedup from pre-partitioning is lost.

**How to avoid:**
1. Modify HCPC call to accept `kk` parameter from Leiden clustering result
2. Sequence operations: Leiden first (community detection), then HCPC on communities (not on full data)
3. Benchmark end-to-end: cold start from SQL query to JSON response, not just clustering step
4. Reduce MCA principal components from 15 to 8 (diminishing returns, analyzed in planning docs)
5. Push database joins to SQL: single collect() instead of multiple filter/join cycles (4x faster)
6. Document the full optimization chain in code comments: SQL → MCA → Leiden → HCPC with kk

**Warning signs:**
- Leiden implementation complete but cold start still 12-15s (expecting <5s)
- HCPC step takes longer than Leiden step (should be 2-3x faster)
- Profiling shows HCPC consuming 60-70% of compute time
- No `kk` parameter passed to HCPC function call
- MCA still computing 15 principal components (check with str(mca_result))

**Phase to address:**
Phase 25-01 (Performance Optimization) — implement complete optimization chain including HCPC kk parameter, not just Leiden algorithm swap.

---

### Pitfall 7: STRINGdb v11.5 to v12.0 Upgrade Breaking Network Edges

**What goes wrong:**
STRING v12.0 (released 2025) changes protein namespace and edge definitions compared to v11.5. The `protein.aliases.v12.0` file structure differs from v11.5. Existing SysNDD database table `non_alt_loci_set` stores STRING_id values from v11.5 namespace. Upgrading STRINGdb breaks edge extraction: protein IDs don't match between cached database values and new STRING network, resulting in empty networks or wrong edges.

**Why it happens:**
Current code hardcodes `version = "11.5"` in `STRINGdb::STRINGdb$new()`. Developers upgrade STRINGdb package to latest version (supporting v12.0) without updating database STRING_id mappings. The mapping between HGNC symbols and STRING IDs becomes stale. STRINGv11 and STRINGv10 used different protein namespaces (historical pattern repeats for v12).

**How to avoid:**
1. Keep STRINGdb version synchronized across: R package version, database STRING_id column, cache keys
2. Create database migration script to update STRING_id mappings: fetch fresh protein.aliases from STRING v12
3. Add API version check: compare STRINGdb version in code vs. version used for database STRING_id population
4. Implement graceful fallback: if STRING_id missing for gene, fetch on-demand via STRING API
5. Document STRING version in database schema comments and API documentation
6. Test edge extraction with 10-20 known genes, verify edge counts match STRING web interface
7. Store STRING version in cache filename (already mentioned in Pitfall 3)

**Warning signs:**
- Cytoscape.js shows nodes but zero edges after STRINGdb upgrade
- Console logs "Warning: STRING_id X not found in network" for 50%+ of genes
- Network edge count drastically differs from STRING web interface for same gene set
- `left_join(sysndd_db_string_id_table)` returns many NA values for STRING_id
- STRINGdb R package version (packageVersion("STRINGdb")) doesn't match `version = "11.5"` in code

**Phase to address:**
Phase 25-02 (Cytoscape.js Integration) — resolve STRING version compatibility when implementing edge extraction. Consider deferring v12.0 upgrade to later phase if it requires database migration.

---

### Pitfall 8: Vue 3 Reactivity Over-Triggering Cytoscape.js Renders

**What goes wrong:**
Storing Cytoscape graph data in reactive Vue refs (`ref(cytoscapeData)`) causes Cytoscape to re-render on every data mutation. When adding nodes incrementally (e.g., search results highlighting), each node addition triggers Vue's reactivity, which triggers watcher/computed that updates Cytoscape, causing full layout recalculation. For 100-node graphs, this creates 100 layout recalculations instead of 1, freezing the UI for 10-30 seconds.

**Why it happens:**
Vue 3's Composition API makes everything reactive by default. Developers naturally use `const graphData = ref({ nodes: [], edges: [] })` and mutate it with `graphData.value.nodes.push(newNode)`. Each push triggers Vue's reactivity system. Cytoscape.js has its own internal state management and doesn't benefit from Vue reactivity—in fact, it conflicts.

**How to avoid:**
1. Store Cytoscape instance in non-reactive variable: `let cy` not `const cy = ref()`
2. Store graph data in non-reactive variable: `let cytoscapeData = { nodes: [], edges: [] }`
3. Batch Cytoscape updates: collect all changes, then call `cy.json({ elements: newData })` once
4. Use Cytoscape's built-in add/remove methods: `cy.add([...nodes])` instead of mutating reactive array
5. If reactivity needed for UI controls, use separate reactive state: `const nodeCount = ref(0)` updated manually
6. Disable Vue reactivity for large data objects: `markRaw(cytoscapeData)` if you must store in component
7. Document in code comments: "Cytoscape data intentionally non-reactive for performance"

**Warning signs:**
- UI freezes when adding nodes to graph via search/filter functionality
- DevTools Performance tab shows 100s of "Layout calculation" entries in rapid succession
- Console warns "Maximum call stack size exceeded" during graph updates
- Cytoscape layout runs on every keystroke in search input
- CPU usage spikes to 100% when highlighting 10-20 search results

**Phase to address:**
Phase 25-02 (Cytoscape.js Integration) — establish non-reactive pattern during initial integration. Phase 25-03 (Advanced Features) when adding search/highlighting functionality.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip `cy.destroy()` in prototype | Faster development | Memory leaks in production | Never — takes 2 lines of code |
| Use default canvas renderer for all graphs | No WebGL complexity | Unusable with >500 nodes | Only if graphs proven to stay <200 nodes |
| Synchronous JSON serialization | Simpler code | API blocking, poor UX | Only for responses <100KB |
| No pagination on clustering results | Avoids UI complexity | 8.6MB responses, slow load | Never — impacts all users |
| Hardcode STRINGdb v11.5 | Stability for current data | Blocks future upgrades | Acceptable if v12 upgrade deferred to v6 |
| Cache without expiry/versioning | Simple implementation | Stale data bugs | Only with clear manual invalidation process |
| Copy vue-cytoscape Vue 2 wrapper | Reuse existing code | Incompatible with Vue 3 Composition API | Never — write Vue 3 native integration |
| Use reactive refs for Cytoscape data | Familiar Vue pattern | Performance cliff at 50+ nodes | Never — Cytoscape has own state management |
| mirai without dispatcher | Fewer dependencies | Timeout doesn't free workers | Only if timeouts never expected (unrealistic) |
| cose-bilkent layout | Good default in examples | 2x slower than fcose | Acceptable if graphs <100 nodes |

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| STRINGdb R package | Assume `get_clusters()` algorithm param is in cache key | Include algorithm + version in cache filename |
| Cytoscape.js in Vue 3 | Use vue-cytoscape wrapper (Vue 2 only) | Manual integration with onMounted/onBeforeUnmount |
| Plumber async responses | Use mirai for computation, forget JSON serialization blocks | Move serialization into mirai worker or paginate |
| memoise caching | Rely on automatic function hash invalidation | Explicit cache versioning and max_age |
| STRING network edges | Extract edges in separate API call after clustering | Extract during clustering, return in single response |
| Layout algorithms | Use first example in docs (cose-bilkent) | Use fcose (2x faster, same result quality) |
| WebGL renderer | Enable for all graphs | Only enable for >500 nodes (canvas sufficient for smaller) |
| High DPI displays | Use default pixelRatio (2-3) | Set pixelRatio: 1 for large graphs (accept blur) |
| Gene search highlighting | Update Cytoscape on every keystroke | Debounce input (300ms), batch Cytoscape updates |
| STRINGdb version upgrade | Update R package, assume database STRING_id still valid | Regenerate STRING_id mappings with database migration |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Canvas rendering all edges | Pan/zoom lag, frame drops | hideEdgesOnViewport: true | >500 edges |
| No edge rendering optimization | 5+ second redraws | Opaque arrows, no shadows, pixelRatio: 1 | >1000 edges |
| Synchronous clustering computation | API blocks for 15s | HTTP 202 + job polling (already implemented elsewhere) | 2+ concurrent users |
| Deep nested JSON (clusters > subclusters > genes > metadata) | 2s serialization time | Flatten structure or paginate | Responses >5MB |
| No response pagination | 8.6MB responses | Return 10-20 clusters per page | 50+ clusters |
| In-memory clustering without streaming | 2GB memory spike | Stream results to file, return file handle | 1000+ genes |
| Vue reactive Cytoscape data | UI freeze during updates | Non-reactive variables for Cytoscape | >50 nodes |
| mirai timeout without dispatcher | Worker pool exhaustion | Always use dispatcher() | 8+ concurrent requests |
| cose-bilkent for all layouts | 10s layout time | Use fcose (2x faster) | >100 nodes |
| No layout result caching | Recalculate on every zoom/pan | Cache layout positions, only recalculate on data change | >200 nodes |
| Loading full STRING network upfront | 30s initial load | Progressive loading: clusters first, edges on interaction | >500 nodes + 2000 edges |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Return all cluster data without auth check | Expose unpublished gene associations | Require auth for analysis endpoints (already have require_auth middleware) |
| No rate limiting on clustering endpoint | DOS via expensive computation | Add rate limiting: 5 requests/minute/user for clustering |
| Cache clustering results with user-specific data | Leak private gene panels between users | Include user_id in cache key if panels are user-specific |
| Expose panel_hash in API response | Reverse engineer gene lists from other users | Use opaque job IDs instead of deterministic hashes in URLs |
| Log full gene lists in error messages | Leak sensitive research data in logs | Already sanitized via logging_sanitizer.R — verify clustering errors also sanitized |
| Return stack traces to client on clustering error | Expose database schema, file paths | RFC 9457 error format (already implemented) — ensure clustering endpoints use it |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No loading indicator during 15s clustering | User thinks page crashed | Spinner + progress updates ("Computing clusters... 30%") |
| Layout animation on every zoom/pan | Disorienting, hard to focus | Disable animation during interaction (already in hideEdgesOnViewport) |
| No timeout warning before computation | Surprise 504 error after 15s wait | Show warning: "Large gene set, this may take 20-30s" before submit |
| Clustering fails, no actionable error | "Something went wrong" → user stuck | "Gene set too large (max 500 genes), please filter and retry" |
| Network too large, canvas crashes tab | Lost work, frustration | Pre-check node count, show warning: "500+ genes detected, enable WebGL renderer?" |
| Search highlights trigger full layout recalculation | 5s freeze on search | Batch updates, only highlight nodes without relayout |
| No edge legend/explanation | User doesn't understand what edges represent | Add tooltip: "Edge thickness = STRING confidence score (0.2-1.0)" |
| Cluster colors change on re-render | User loses context between views | Deterministic color assignment based on cluster ID hash |
| No link from correlation heatmap to clusters | User must manually find cluster | Click-through: heatmap cell → cluster detail (planned in v5 scope) |
| Download button appears before graph loads | Download generates empty/corrupted image | Disable download button until cy.ready() event fires |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Cytoscape.js integration:** Often missing `cy.destroy()` in onBeforeUnmount — verify with DevTools memory profiler after 10 navigation cycles
- [ ] **Edge rendering:** Often missing performance optimizations (hideEdgesOnViewport, pixelRatio: 1) — verify pan/zoom is smooth at 500 edges
- [ ] **Leiden algorithm:** Often missing HCPC kk parameter integration — verify end-to-end time <5s, not just Leiden step
- [ ] **Cache invalidation:** Often missing version/algorithm in cache key — verify different algorithms don't return identical results
- [ ] **mirai timeout:** Often missing dispatcher() call — verify timeout actually frees worker with htop during timeout test
- [ ] **JSON pagination:** Often missing total count in response — verify client can show "Page 1 of 5" without fetching all pages
- [ ] **STRING version:** Often missing compatibility check between R package and database STRING_id — verify edge count matches STRING web
- [ ] **Cytoscape data reactivity:** Often missing markRaw() or non-reactive pattern — verify no layout recalculation during array mutations
- [ ] **fcose layout:** Often hardcoded cose-bilkent from examples — verify using fcose with benchmark comparison
- [ ] **WebGL renderer:** Often conditionally enabled but never tested — verify actually activates for >500 node graphs
- [ ] **Error handling:** Often returns 500 with generic message — verify RFC 9457 format with actionable detail
- [ ] **Loading states:** Often shows generic spinner — verify progress updates during long clustering operations

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Memory leak from missing cy.destroy() | LOW | 1. Add onBeforeUnmount hook with cy.destroy() and cy = null; 2. Test with heap snapshot; 3. Deploy |
| Performance cliff from edge rendering | MEDIUM | 1. Add hideEdgesOnViewport: true; 2. Set pixelRatio: 1; 3. Switch cose-bilkent → fcose; 4. Test with 500+ edge graph |
| Stale cache after algorithm change | LOW | 1. Delete api/results/*.json; 2. Add algorithm to cache key; 3. Increment CACHE_VERSION; 4. Document in deploy notes |
| API blocking from large JSON serialization | HIGH | 1. Implement pagination (new endpoint contract); 2. Update frontend to fetch pages; 3. Extensive testing; 4. Breaking change migration |
| mirai worker pool exhaustion | MEDIUM | 1. Add dispatcher(); 2. Increase timeout to realistic value (30s); 3. Monitor worker availability; 4. Restart API to clear hung workers |
| Leiden without HCPC kk parameter | MEDIUM | 1. Modify HCPC call to accept kk parameter; 2. Pass Leiden result to HCPC; 3. Benchmark end-to-end; 4. Clear cache |
| STRINGdb v11.5/v12.0 incompatibility | HIGH | 1. Database migration to update STRING_id; 2. Update code to v12; 3. Clear cache; 4. Test edge extraction; 5. Staged rollout |
| Vue reactivity triggering layout storm | MEDIUM | 1. Replace ref() with let variable; 2. Batch cy.add() calls; 3. Test incremental updates; 4. May require refactor if deep in component |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Cache invalidation (Leiden + STRING version) | Phase 25-01 (Performance Optimization) | Cache keys include "leiden" + "v11.5", different algorithms return different results |
| mirai timeout without dispatcher | Phase 25-01 (Performance Optimization) | Timeout test shows worker returns to pool (htop), no hung processes |
| Leiden without HCPC kk parameter | Phase 25-01 (Performance Optimization) | End-to-end clustering <5s cold start, HCPC step faster than Leiden step |
| Plumber JSON serialization blocking | Phase 25-01 (Performance Optimization) | /api/analysis/functional_clustering returns 10-20 clusters per page, response <500KB |
| Cytoscape.js memory leaks | Phase 25-02 (Cytoscape Integration) | DevTools heap snapshot after 10 navigation cycles shows single Cytoscape instance |
| Edge rendering performance cliff | Phase 25-02 (Cytoscape Integration) | Pan/zoom smooth at 500 edges, hideEdgesOnViewport verified in code |
| STRINGdb version incompatibility | Phase 25-02 (Cytoscape Integration) | Edge count matches STRING web for 10 test genes, STRING_id join has no NAs |
| cose-bilkent instead of fcose | Phase 25-02 (Cytoscape Integration) | Layout algorithm set to fcose, benchmark shows <2s for 100-node graph |
| Vue reactivity over-triggering renders | Phase 25-03 (Advanced Features) | Search highlighting doesn't trigger layout recalculation, Cytoscape data non-reactive |
| WebGL renderer not enabled for large graphs | Phase 25-03 (Advanced Features) | Programmatic test: create 600-node graph, verify WebGL activates (check renderer type) |

## Sources

### Cytoscape.js Performance & Integration
- [Cytoscape.js Performance Documentation](https://github.com/cytoscape/cytoscape.js/blob/master/documentation/md/performance.md) (HIGH confidence)
- [WebGL Renderer Preview (2025-01-13)](https://blog.js.cytoscape.org/2025/01/13/webgl-preview/) (HIGH confidence)
- [Cytoscape.js Large Graph Performance Issue #875](https://github.com/cytoscape/cytoscape.js/issues/875) (MEDIUM confidence)
- [vue-cytoscape Vue 3 Compatibility Issue #96](https://github.com/rcarcasses/vue-cytoscape/issues/96) (HIGH confidence)
- [Memory leak with Angular.js Issue #663](https://github.com/cytoscape/cytoscape.js/issues/663) (MEDIUM confidence — different framework, similar pattern)

### Layout Algorithms
- [fcose vs cose-bilkent Performance Comparison](https://github.com/iVis-at-Bilkent/cytoscape.js-fcose) (HIGH confidence — official repo docs)
- [Cytoscape.js Layouts Blog Post (2020)](https://blog.js.cytoscape.org/2020/05/11/layouts/) (MEDIUM confidence)
- [cose-bilkent Performance Issue #16](https://github.com/cytoscape/cytoscape.js-cose-bilkent/issues/16) (MEDIUM confidence)

### R Clustering Algorithms
- [Leiden vs Louvain vs Walktrap Comparison (IEEE 2026)](https://ieeexplore.ieee.org/document/10845656/) (HIGH confidence)
- [igraph Leiden Algorithm Documentation](https://r.igraph.org/reference/cluster_leiden.html) (HIGH confidence)
- [Leiden Benchmarking Vignette](https://cran.r-project.org/web/packages/leiden/vignettes/benchmarking.html) (MEDIUM confidence)

### R Plumber Performance
- [Plumber Large JSON Issue #408](https://github.com/rstudio/plumber/issues/408) (MEDIUM confidence)
- [Plumber Streaming Data Issue #308](https://github.com/trestletech/plumber/issues/308) (MEDIUM confidence)
- [Plumber Rendering Output Documentation](https://www.rplumber.io/articles/rendering-output.html) (HIGH confidence)
- [Plumber Runtime Execution Model](https://www.rplumber.io/articles/execution-model.html) (HIGH confidence)

### mirai Async Framework
- [mirai 2.3.0 Release Notes](https://shikokuchuo.net/posts/26-mirai-230/) (HIGH confidence)
- [mirai Timeout & Error Handling Documentation](https://mirai.r-lib.org/articles/mirai.html) (HIGH confidence)
- [mirai Quick Reference](https://cran.r-project.org/web/packages/mirai/vignettes/mirai.html) (HIGH confidence)

### memoise Caching
- [memoise Cache Invalidation Issue #58](https://github.com/r-lib/memoise/issues/58) (MEDIUM confidence)
- [memoise Caching Strategies Issue #39](https://github.com/r-lib/memoise/issues/39) (MEDIUM confidence)
- [memoise Documentation](https://memoise.r-lib.org/) (HIGH confidence)

### STRING Database
- [STRING v12.5 with Regulatory Networks (2025)](https://academic.oup.com/nar/article/53/D1/D730/7903368) (HIGH confidence)
- [STRINGdb v12 R Package Compatibility](https://support.bioconductor.org/p/9155261/) (MEDIUM confidence)
- [STRING v11 vs v10 Namespace Changes](https://support.bioconductor.org/p/121393/) (MEDIUM confidence)

### Network Visualization General
- [Network Graph Rendering Performance at Scale (2026)](https://nightingaledvs.com/how-to-visualize-a-graph-with-a-million-nodes/) (MEDIUM confidence)
- [Comparison of JS Graph Libraries](https://www.cylynx.io/blog/a-comparison-of-javascript-graph-network-visualisation-libraries/) (MEDIUM confidence)

### Project-Specific Context
- SysNDD `.planning/PROJECT.md` — current implementation details (HIGH confidence)
- SysNDD `api/functions/analyses-functions.R` — existing clustering code (HIGH confidence)
- SysNDD `app/src/components/analyses/AnalyseGeneClusters.vue` — current D3.js bubble chart (HIGH confidence)

---
*Pitfalls research for: Adding Cytoscape.js Network Visualization + R Clustering Optimization to SysNDD Vue 3 + R/Plumber App*
*Researched: 2026-01-24*
