# v5 Analysis Modernization Research Summary

**Project:** SysNDD v5.0 Analysis Modernization
**Domain:** Biological network visualization and clustering analysis performance optimization
**Researched:** 2026-01-24
**Confidence:** HIGH

## Executive Summary

The v5 Analysis Modernization milestone transforms SysNDD's analysis pages from basic D3.js bubble charts to sophisticated interactive network visualizations with optimized backend clustering performance. Research reveals that expert bioinformatics tools (STRING, GeneMANIA, Cytoscape) consistently combine force-directed network layouts with rich contextual tooltips and bidirectional data exploration. The recommended approach uses Cytoscape.js 3.33.1 for frontend network rendering (leveraging WebGL for large graphs) and migrates backend clustering from Walktrap to Leiden algorithm with HCPC pre-partitioning, achieving 50-65% reduction in cold start time (15s → 5-7s).

Critical risks center on three areas: (1) Cytoscape.js memory leaks from missing lifecycle cleanup in Vue 3 Composition API, (2) edge rendering performance cliffs beyond 500 edges without proper optimizations (hideEdgesOnViewport, fcose layout), and (3) cache invalidation complexity when migrating clustering algorithms. Mitigation requires establishing proper patterns early: non-reactive Cytoscape data storage, explicit cy.destroy() in lifecycle hooks, algorithm/version inclusion in cache keys, and mirai dispatcher usage for proper timeout handling. The research indicates high confidence across all dimensions with well-documented patterns and verified performance benchmarks.

The milestone delivers three key competitive advantages: wildcard gene search patterns (PKD*, BRCA?) aligned with biologist mental models, bidirectional network-table integration enabling click-cluster-to-filter-table workflows, and comprehensive filter UI combining column-level, numeric range, and categorical filters. These differentiators distinguish SysNDD from competitors like STRING and GeneMANIA which separate network visualization from data exploration.

## Key Findings

### Recommended Stack

The frontend addition centers on Cytoscape.js 3.33.1 as the graph visualization core, chosen over D3.js force layouts and alternatives like sigma.js for its rich algorithm library, compound node support, and extensive layout options. The fcose layout extension (v2.2.0) provides 2x speed improvement over the unmaintained cose-bilkent. WebGL renderer (preview in v3.31+) improves large graph performance from 3 FPS to 10 FPS on 3200-node networks but should only activate for graphs exceeding 500 nodes. Integration uses Vue 3 Composition API with custom composables (no wrapper libraries) for direct control and TypeScript support.

**Core technologies:**
- **Cytoscape.js 3.33.1**: Graph visualization with WebGL renderer for >500 node networks — industry standard for biological networks with 220K weekly downloads, native TypeScript definitions, proven performance
- **cytoscape-fcose 2.2.0**: Fast force-directed layout algorithm — 2x faster than cose-bilkent with equivalent aesthetics, ideal for PPI networks
- **igraph 2.1.1 (R)**: Leiden clustering algorithm via cluster_leiden() — 2-3x faster than Walktrap, built-in C implementation avoiding Python bridge complexity
- **FactoMineR 2.13 (R)**: MCA/HCPC with kk preprocessing parameter — 50-70% speedup via K-means preprocessing before hierarchical clustering
- **Vue 3.5.25 Composables**: Network state management — pure composables for visualization state, no Pinia needed for page-scoped data
- **VueUse useUrlSearchParams**: Filter state synchronization — reactive URL state sync with zero boilerplate for shareable/bookmarkable filters

**Backend performance optimizations:**
- Leiden algorithm: 2-3x faster clustering (7-10s → 2-3s)
- HCPC kk=50 parameter: 50-70% faster hierarchical clustering (5s → 1.5-2s)
- MCA ncp=8 reduction: 20-30% speedup by reducing dimensions from 15 to 8
- **Expected total improvement**: 50-65% cold start reduction (15s → 5-7s)

**Version compatibility verified:**
- cytoscape@3.33.1 compatible with Vue 3.5.25 (framework-agnostic)
- igraph@2.1.1 compatible with R 4.4.3 and STRINGdb@2.18.0
- FactoMineR@2.13 latest stable (2026-01-12)

### Expected Features

Research identified 9 table stakes features users expect, 9 competitive differentiators, and 7 anti-features to avoid. The MVP prioritizes P1 features balancing user expectations with implementation complexity.

**Must have (table stakes):**
- Force-directed network layout with PPI edges — standard expectation for protein interaction visualization, users assume networks show connections not just bubbles
- Interactive node/edge highlighting — essential for exploring complex networks, hover to highlight connections is fundamental UX
- Pan and zoom controls — networks can be large, navigation is baseline requirement
- Click-through navigation to entity pages — users expect node clicks to show details, leverages existing SysNDD infrastructure
- Rich contextual tooltips — bioinformatics users need immediate gene metadata (symbol, function, cluster, phenotypes) without page navigation
- Column-level text filters + numeric range filters + dropdown categorical filters — standard data table expectations, users assume per-column filtering
- Global "search any field" functionality — one search box to filter across all columns, already implemented pattern
- Sort by column (asc/desc) and pagination controls — fundamental table interactions, existing implementations
- Wildcard gene search (PKD*, BRCA?) — differentiator elevating search to match biologist mental models for gene families

**Should have (competitive differentiators):**
- Integrated network-to-table navigation — bidirectional: click cluster → filter table, click row → highlight in network; neither STRING nor GeneMANIA provides tight coupling
- Network layout persistence — save manually adjusted node positions, restore on return via localStorage
- Interactive edge filtering — slider to filter edges by confidence score, reduces visual clutter for large networks
- Gene set upload for network — custom gene list file upload to generate networks beyond curated sets
- Pathway annotation overlay — overlay KEGG/Reactome pathway boundaries on network showing functional modules

**Defer (v2+):**
- Multi-cluster network overlay — complex feature showing phenotype + functional clusters simultaneously with color coding
- Cluster comparison mode — side-by-side synchronized network views for comparing categories
- Network motif detection highlighting — research feature requiring backend graph algorithms (feed-forward loops, cliques, hubs)
- Integrated literature links — tooltip PubMed citations for genes/interactions, data already available in enrichment endpoint

**Anti-features to avoid:**
- 3D network visualization — documented depth perception issues, occlusion problems, increased cognitive load
- Real-time filter updates without debounce — excessive API calls, performance degradation; stick with 500ms debounce
- Infinite scroll on tables — memory leaks with large datasets; keep cursor-based pagination
- Combined filter UI in modal/sidebar — breaks visibility principle; keep column-level filters visible
- Automatic network layout prettification — no universal "pretty" for biological networks; provide stable default with manual adjustment

### Architecture Approach

The milestone extends existing Vue 3 + R/Plumber patterns rather than replacing them. Frontend adds Cytoscape.js as a peer to existing D3.js visualizations (D3 for cluster bubbles/heatmaps, Cytoscape for PPI networks). Backend adds parallel network_edges endpoint alongside existing functional_clustering endpoint. Integration points leverage established patterns: Vue 3 Composition API composables for state management, memoise file-based caching for network data, Bootstrap-Vue-Next for UI components, existing STRINGdb integration for PPI data extraction.

**Major components:**

1. **Frontend: GeneClusterNetwork.vue component** — New Cytoscape.js network visualization using Composition API, integrates with existing views/analyses/ structure, uses useCytoscape composable for lifecycle management and useNetworkData composable for data fetching
2. **Backend: gen_network_edges() function** — Extracts PPI edges from STRINGdb in Cytoscape.js JSON format, memoized with cache manager, returns elements: {nodes, edges} structure
3. **Backend: Optimized clustering pipeline** — Switches gen_string_clust_obj from Walktrap to Leiden algorithm, adds kk parameter to HCPC call, reduces MCA ncp from 15 to 8, maintains memoise caching compatibility
4. **Shared filter components** — Extract CategoryFilter.vue, ScoreSlider.vue, TermSearch.vue for reuse across analysis views, wire to useFilterSync composable for URL state synchronization
5. **Composables layer** — useNetworkData.ts (network data fetching), useCytoscape.ts (Cytoscape lifecycle), useFilterSync.ts (URL state via VueUse), parallel to existing useTableData.ts pattern

**Architectural patterns:**
- **Composable-based Cytoscape integration**: Encapsulate lifecycle in composable not component for testability and reusability
- **Parallel endpoint strategy**: Separate cluster metadata and network edges endpoints for independent caching characteristics
- **Filter state in URL**: VueUse useUrlSearchParams for bidirectional URL sync with automatic reactivity
- **Non-reactive Cytoscape data**: Store Cytoscape instance in non-reactive variable (let cy) to avoid Vue reactivity triggering layout recalculations
- **Client-side edge filtering**: Fetch all edges once with score_threshold=0.0, filter client-side to avoid redundant API calls

**Data flow:**
```
User selects cluster → watch(selectedCluster) →
useNetworkData.loadNetworkData → axios.get(/api/network_edges) →
gen_network_edges_mem (check cache) → STRINGdb$get_interactions →
Transform to Cytoscape.js format → useCytoscape.updateElements →
Cytoscape.js re-renders network
```

### Critical Pitfalls

Research identified 8 critical pitfalls with high impact and 12 moderate/minor issues documented in PITFALLS-analysis-modernization.md. The top 5 require attention during specific phases:

1. **Cytoscape.js memory leaks from missing lifecycle cleanup** — Vue 3 Composition API doesn't auto-cleanup third-party instances. Each undestroyed instance retains 100-300MB including canvases. **Avoid:** Store instance in non-reactive variable (let cy not ref()), always call cy.destroy() in onBeforeUnmount, verify with Chrome DevTools heap snapshots after 10 navigation cycles. **Address in Phase 25-02.**

2. **Edge rendering performance cliff beyond 500 edges** — Canvas renderer degrades severely with >2000 edges (5+ second redraws), high DPI displays multiply cost 2-3x. **Avoid:** Use hideEdgesOnViewport: true, pixelRatio: 1 for large graphs, fcose layout instead of cose-bilkent (2x faster), WebGL renderer for >500 nodes. **Address in Phase 25-02.**

3. **Cache invalidation missing for Leiden algorithm migration** — Existing memoise cache keys don't include algorithm name or STRINGdb version, serving stale Walktrap results after switching to Leiden. **Avoid:** Include algorithm + version in cache filename: paste0(panel_hash, ".", "leiden", ".", "v11.5", ".", params, ".json"), add CACHE_VERSION environment variable, document cache clearing procedure. **Address in Phase 25-01.**

4. **R Plumber single-threading bottleneck with 8.6MB JSON serialization** — jsonlite serialization takes 500-2000ms blocking entire API. **Avoid:** Implement pagination (10-20 clusters per page), add network_edges endpoint with smaller Cytoscape-specific format, move serialization into mirai worker. **Address in Phase 25-01.**

5. **Leiden algorithm migration without HCPC pre-partitioning** — Naive Leiden drop-in replacement misses 50-70% speedup from kk parameter in HCPC call. **Avoid:** Modify HCPC to accept kk parameter from Leiden result, sequence as Leiden → HCPC on communities, reduce MCA ncp from 15 to 8, benchmark end-to-end not just clustering step. **Address in Phase 25-01.**

**Additional high-risk pitfalls:**
- **mirai timeout without dispatcher**: Timeout doesn't free workers without dispatcher() call, exhausting 8-worker pool; always use dispatcher pattern
- **STRINGdb v11.5 to v12.0 upgrade breaking edges**: Version mismatch between R package and database STRING_id values causes empty networks; synchronize version across stack or defer upgrade
- **Vue reactivity over-triggering Cytoscape renders**: Storing graph data in ref() triggers 100 layout recalculations instead of 1; use non-reactive variables for Cytoscape data

## Implications for Roadmap

Based on research, the milestone should be structured into 3 sequential phases addressing infrastructure, core functionality, and advanced features. Phase ordering follows dependency chains and risk mitigation principles.

### Phase 25-01: Performance Optimization (Backend Infrastructure)

**Rationale:** Backend optimization is foundational for frontend integration. Slow clustering (15s cold start) undermines user experience regardless of frontend quality. Cache invalidation bugs risk serving wrong results in production. This phase establishes infrastructure that Phase 25-02 depends on.

**Delivers:**
- Leiden algorithm integration replacing Walktrap in gen_string_clust_obj
- HCPC kk parameter optimization for 50-70% speedup
- MCA ncp reduction from 15 to 8 components
- Cache key versioning including algorithm name + STRINGdb version
- mirai dispatcher pattern for proper timeout handling
- Pagination for functional_clustering endpoint (10-20 clusters per page)
- Expected cold start reduction: 15s → 5-7s (50-65% improvement)

**Addresses features:**
- Infrastructure for all network visualization features (performance baseline)
- Enables responsive UI for large gene sets (200+ genes)

**Avoids pitfalls:**
- Pitfall 3: Cache invalidation missing (include "leiden" + "v11.5" in cache keys)
- Pitfall 4: JSON serialization blocking (implement pagination, reduce response size)
- Pitfall 5: Leiden without HCPC kk parameter (sequence Leiden → HCPC with kk=50)
- Pitfall 6: mirai timeout without dispatcher (add dispatcher() call)

**Stack elements:**
- igraph 2.1.1 with cluster_leiden()
- FactoMineR 2.13 with HCPC kk parameter
- Existing memoise caching infrastructure
- Existing mirai async framework

**Research confidence:** HIGH — Leiden benchmarks verified, HCPC kk parameter documented in official docs, cache invalidation pattern established

**Needs phase research:** No — well-documented R package patterns, existing caching infrastructure understood

### Phase 25-02: Cytoscape.js Integration (Core Network Visualization)

**Rationale:** With optimized backend, implement core network visualization using Cytoscape.js. This phase delivers the primary user-facing value: true PPI networks with edges replacing D3.js bubble charts. Establishes lifecycle patterns, performance optimizations, and composable structure that Phase 25-03 builds upon.

**Delivers:**
- GeneClusterNetwork.vue component with Cytoscape.js integration
- useCytoscape.ts composable for lifecycle management (init/destroy)
- useNetworkData.ts composable for data fetching
- gen_network_edges() backend function + memoized wrapper
- GET /api/analysis/network_edges endpoint
- Force-directed layout with fcose algorithm
- Interactive node/edge highlighting, pan/zoom controls
- Click-through navigation to entity pages
- Rich contextual tooltips (gene symbol, HGNC ID, cluster, phenotypes)
- hideEdgesOnViewport optimization for smooth interactions
- Proper cy.destroy() lifecycle cleanup

**Addresses features (P1 table stakes):**
- Force-directed network layout showing actual PPI edges
- Interactive node/edge highlighting for exploration
- Pan and zoom controls for navigation
- Click-through navigation integrating with existing entity pages
- Rich contextual tooltips with SysNDD curation data

**Avoids pitfalls:**
- Pitfall 1: Memory leaks (implement cy.destroy() in onBeforeUnmount from start)
- Pitfall 2: Edge rendering performance cliff (hideEdgesOnViewport, fcose layout, pixelRatio: 1)
- Pitfall 7: STRINGdb version compatibility (verify STRING_id join, match v11.5 in code and database)
- Pitfall 8: Vue reactivity over-triggering (establish non-reactive pattern for Cytoscape data)

**Stack elements:**
- cytoscape.js 3.33.1 with native TypeScript definitions
- cytoscape-fcose 2.2.0 layout extension
- Vue 3 Composition API with custom composables (no wrapper libraries)
- Bootstrap-Vue-Next for UI components (BCard, BButton)
- Existing STRINGdb integration for PPI data

**Architecture components:**
- Frontend: GeneClusterNetwork.vue component
- Backend: gen_network_edges() function with memoise caching
- Composables: useCytoscape.ts, useNetworkData.ts
- API: GET /api/analysis/network_edges endpoint

**Research confidence:** HIGH — Cytoscape.js performance documentation verified, fcose benchmarks confirmed, Vue 3 Composition API patterns established

**Needs phase research:** No — Cytoscape.js integration well-documented, architecture patterns established in research

### Phase 25-03: Advanced Features & Filters (Enhanced User Experience)

**Rationale:** With core network visualization working, add differentiating features that set SysNDD apart from competitors. Wildcard search and bidirectional network-table integration provide unique value. Filter components enable comprehensive data exploration.

**Delivers:**
- Wildcard gene search (PKD*, BRCA?) with pattern matching
- useFilterSync.ts composable with VueUse useUrlSearchParams
- Shared filter components: CategoryFilter.vue, ScoreSlider.vue, TermSearch.vue
- Column-level text filters, numeric range filters, dropdown categorical filters
- Client-side edge filtering by confidence score
- Integrated network-to-table navigation (bidirectional sync)
- WebGL renderer activation for >500 node networks
- Network layout persistence in localStorage
- Gene set upload for custom network generation

**Addresses features:**
- P1: Wildcard gene search (differentiator)
- P1: Column/numeric/dropdown filters (table stakes)
- P2: Integrated network-to-table navigation (competitive differentiator)
- P2: Interactive edge filtering (should have)
- P2: Network layout persistence (should have)
- P2: Gene set upload (should have)

**Avoids pitfalls:**
- Pitfall 2: WebGL renderer for large graphs (>500 nodes activation logic)
- Pitfall 8: Vue reactivity during search highlighting (batch updates, non-reactive data)

**Stack elements:**
- VueUse useUrlSearchParams for filter state synchronization
- Cytoscape.js WebGL renderer (conditional activation)
- Cytoscape.js selector API for search/highlighting
- localStorage for layout persistence

**Architecture components:**
- Shared filter components (components/filters/)
- useFilterSync.ts composable
- Enhanced GeneClusterNetwork.vue with bidirectional sync
- Extended useNetworkData.ts with search/filter logic

**Research confidence:** HIGH — VueUse patterns documented, Cytoscape.js selector API verified, wildcard pattern transformation straightforward

**Needs phase research:** No — Feature patterns well-documented, VueUse integration standard, localStorage persistence simple

### Phase Ordering Rationale

**Why Phase 25-01 first:**
- Backend optimization is blocking for frontend development (slow clustering undermines UX)
- Cache invalidation bugs risk production data integrity (must fix before Leiden rollout)
- Performance baseline established before adding visualization complexity
- Independent from frontend work (can parallelize if needed, but sequential is safer)

**Why Phase 25-02 second:**
- Requires optimized backend from Phase 25-01 for acceptable performance
- Core visualization must work before adding advanced features
- Establishes lifecycle patterns and composable structure for Phase 25-03
- Delivers primary user-facing value (PPI networks with edges)

**Why Phase 25-03 third:**
- Builds on working network visualization from Phase 25-02
- Filters and search require stable base component
- Bidirectional sync needs both network and table components functional
- WebGL optimization only matters after core rendering proven

**Dependency chain:**
```
25-01 (Performance) → 25-02 (Core Viz) → 25-03 (Advanced Features)
        ↓                      ↓                    ↓
  Fast clustering    Cytoscape.js network    Filters & search
  Cache versioning   Lifecycle patterns      Bidirectional sync
  Pagination         Edge rendering          WebGL renderer
```

**Risk mitigation through ordering:**
- Address cache invalidation (Pitfall 3) before algorithm migration prevents wrong results
- Establish lifecycle cleanup (Pitfall 1) during initial integration avoids expensive refactoring
- Implement edge optimizations (Pitfall 2) from start prevents performance cliff discovery late
- Defer advanced features (Phase 25-03) until core patterns validated reduces rework risk

### Research Flags

**Phases with standard patterns (skip research-phase):**
- **Phase 25-01 (Performance Optimization):** Well-documented R packages (igraph, FactoMineR), existing caching infrastructure, established memoise patterns
- **Phase 25-02 (Cytoscape.js Integration):** Extensive official documentation, verified Vue 3 Composition API patterns, architecture research complete
- **Phase 25-03 (Advanced Features):** VueUse standard patterns, Cytoscape.js selector API documented, filter components follow Bootstrap-Vue-Next conventions

**No phases require deeper research.** All critical integration points, performance optimizations, and architectural patterns researched with HIGH confidence. Implementation can proceed directly from research findings.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All core technologies verified with official sources: Cytoscape.js v3.33.1 NPM + GitHub releases, igraph 2.1.1 CRAN + docs, FactoMineR 2.13 CRAN (2026-01-12). Version compatibility checked. fcose vs cose-bilkent benchmarks from official GitHub repo. WebGL renderer performance data from official Cytoscape.js blog (2025-01-13). |
| Features | HIGH | Table stakes identified from competitor analysis (STRING, GeneMANIA) + UX research papers. Differentiators validated against competitor feature matrices. Anti-features documented with specific problems (3D visualization depth perception issues, infinite scroll memory leaks). MVP definition aligned with existing SysNDD patterns. |
| Architecture | HIGH | Integration points with existing Vue 3 + R/Plumber stack verified from PROJECT.md and codebase analysis. Composable patterns align with Vue 3 official docs. Data flow tested against existing useTableData.ts pattern. STRINGdb integration verified from current analyses-functions.R. Memoise caching patterns understood from start_sysndd_api.R. |
| Pitfalls | HIGH | Critical pitfalls sourced from official Cytoscape.js performance docs, mirai 2.3.0 release notes, Leiden benchmarking studies (IEEE 2026), Plumber execution model docs. Memory leak patterns verified from Cytoscape.js GitHub issues. Cache invalidation risks identified from memoise package issues and project-specific context. |

**Overall confidence:** HIGH

All research dimensions backed by official documentation, verified benchmarks, and existing codebase analysis. Stack recommendations include specific version numbers with compatibility verification. Architecture patterns align with established Vue 3 and R/Plumber conventions. Pitfalls documented with warning signs, prevention strategies, and phase-specific addressing.

### Gaps to Address

**Minor gaps requiring validation during implementation:**

- **WebGL renderer production readiness**: WebGL renderer marked as "preview" in v3.31 (Jan 2025). Monitor Cytoscape.js releases for production status announcement. Fallback: Canvas renderer sufficient for current data scales (estimated 200-500 node graphs), WebGL optimization deferred if needed.

- **STRINGdb v12.0 upgrade timing**: STRING v12.0 released 2025, adds regulatory networks. Current code uses v11.5. Research confirms namespace changes require database STRING_id migration. **Recommendation:** Defer v12.0 upgrade to v6 milestone to avoid blocking v5. Document STRING version in database schema comments.

- **Actual gene cluster sizes in production**: Research assumes 50-200 gene clusters based on typical NDD gene panels. Larger clusters (500+ genes) may require WebGL renderer earlier than Phase 25-03. **Validation:** Analyze current functional_clustering endpoint responses for max cluster size before Phase 25-01.

- **mirai worker pool sizing**: Current 8-worker pool may be insufficient with pagination (more frequent smaller requests instead of fewer large requests). **Monitor:** Worker queue length and timeout frequency after Phase 25-01 pagination implementation. Adjust pool size if needed.

**Handling strategy:**
- WebGL: Implement feature flag in Phase 25-02, monitor Cytoscape.js releases
- STRING v12: Document version dependency, create v6 migration ticket
- Cluster sizes: Add analytics to Phase 25-01 to track max sizes
- Worker pool: Add monitoring to Phase 25-01, tune based on production metrics

**No research gaps block implementation.** All gaps are validation/monitoring items addressable during normal development process.

## Sources

### Primary (HIGH confidence)

**Cytoscape.js:**
- [Cytoscape.js NPM v3.33.1](https://www.npmjs.com/package/cytoscape) — Latest version verification, download stats
- [Cytoscape.js Performance Documentation](https://github.com/cytoscape/cytoscape.js/blob/master/documentation/md/performance.md) — hideEdgesOnViewport, pixelRatio settings, optimization strategies
- [Cytoscape.js WebGL Preview Blog 2025-01-13](https://blog.js.cytoscape.org/2025/01/13/webgl-preview/) — WebGL renderer performance benchmarks (1200 nodes 20→100 FPS, 3200 nodes 3→10 FPS)
- [cytoscape-fcose GitHub](https://github.com/iVis-at-Bilkent/cytoscape.js-fcose) — fcose vs cose-bilkent 2x speed comparison
- [Cytoscape.js Official Documentation](https://js.cytoscape.org/) — Core API, element definitions, TypeScript types

**R Packages:**
- [igraph CRAN Package](https://cran.r-project.org/package=igraph) — Version 2.1.1 (2025-01-10)
- [igraph cluster_leiden Documentation](https://igraph.org/r/doc/cluster_leiden.html) — Leiden algorithm implementation, parameters
- [FactoMineR CRAN Package](https://cran.r-project.org/package=FactoMineR) — Version 2.13 (2026-01-12)
- [HCPC Documentation](https://rdrr.io/cran/FactoMineR/man/HCPC.html) — kk parameter for K-means preprocessing
- [mirai 2.3.0 Release Notes](https://shikokuchuo.net/posts/26-mirai-230/) — Dispatcher pattern for timeout cancellation

**Vue 3 & VueUse:**
- [Vue 3 Composables Official Guide](https://vuejs.org/guide/reusability/composables.html) — Composition API patterns
- [VueUse useUrlSearchParams](https://vueuse.org/core/useurlsearchparams/) — Reactive URL state synchronization

**Competitor Analysis:**
- [STRING Database in 2025](https://academic.oup.com/nar/article/53/D1/D730/7903368) — STRING v12 features, regulatory networks
- [GeneMANIA Update 2018](https://academic.oup.com/nar/article/46/W1/W60/5038280) — Feature comparison baseline

**UX Research:**
- [Ten Simple Rules to Create Biological Network Figures](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007244) — Network visualization best practices
- [Data Table Design UX Patterns](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables) — Filter UI patterns
- [Complex Filters UX](https://smart-interface-design-patterns.com/articles/complex-filtering/) — Filter visibility principles

### Secondary (MEDIUM confidence)

**Performance Benchmarks:**
- [Leiden vs Louvain vs Walktrap Comparison (IEEE 2026)](https://ieeexplore.ieee.org/document/10845656/) — 2-3x Leiden speedup verified
- [Best Libraries for Large Network Graphs](https://weber-stephen.medium.com/the-best-libraries-and-methods-to-render-large-network-graphs-on-the-web-d122ece2f4dc) — Cytoscape.js vs D3.js vs sigma.js comparison
- [Network Visualization at Scale (2026)](https://nightingaledvs.com/how-to-visualize-a-graph-with-a-million-nodes/) — Progressive loading patterns

**Integration Patterns:**
- [vue-cytoscape Vue 3 Compatibility Issue #96](https://github.com/rcarcasses/vue-cytoscape/issues/96) — Vue 2 wrapper incompatibility confirmed
- [Design Patterns with Composition API](https://dev.to/jacobandrewsky/good-practices-and-design-patterns-for-vue-composables-24lk) — Composable best practices

### Project-Specific (HIGH confidence)

- SysNDD `.planning/PROJECT.md` — Current architecture, Vue 3.5.25 + R 4.4.3 stack
- SysNDD `api/functions/analyses-functions.R` — gen_string_clust_obj, gen_mca_clust_obj patterns, memoise usage
- SysNDD `app/src/components/analyses/AnalyseGeneClusters.vue` — Current D3.js implementation, component structure
- SysNDD `app/src/composables/useTableData.ts` — Existing composable pattern for state management

---
*Research completed: 2026-01-24*
*Ready for roadmap: yes*
