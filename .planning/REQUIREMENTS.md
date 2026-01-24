# Requirements: SysNDD v5.0 Analysis Modernization

**Defined:** 2026-01-24
**Core Value:** Transform analysis pages into fast, interconnected, modern visualization experience with true network graphs and professional UI/UX

## v5 Requirements

Requirements for v5.0 release. Each maps to roadmap phases.

### Performance Optimization

- [ ] **PERF-01**: Clustering uses Leiden algorithm (2-3x faster than Walktrap)
- [ ] **PERF-02**: HCPC uses kk=50 pre-partitioning (50-70% faster)
- [ ] **PERF-03**: MCA uses ncp=8 dimensions (20-30% faster)
- [ ] **PERF-04**: Cache keys include algorithm name and STRING version
- [ ] **PERF-05**: functional_clustering endpoint paginated (8.6MB → <500KB per page)
- [ ] **PERF-06**: Cold start reduced from ~15s to <7s
- [ ] **PERF-07**: mirai dispatcher pattern for proper timeout handling

### Network Visualization

- [ ] **NETV-01**: New `/api/analysis/network_edges` endpoint returns Cytoscape.js JSON
- [ ] **NETV-02**: Cytoscape.js renders force-directed network layout with fcose
- [ ] **NETV-03**: Network shows actual protein-protein interaction edges
- [ ] **NETV-04**: Interactive node/edge highlighting on hover
- [ ] **NETV-05**: Pan and zoom controls for network navigation
- [ ] **NETV-06**: Click node navigates to entity detail page
- [ ] **NETV-07**: Rich contextual tooltips show gene symbol, HGNC ID, cluster, phenotypes
- [ ] **NETV-08**: useCytoscape composable manages lifecycle (init/destroy)
- [ ] **NETV-09**: useNetworkData composable handles data fetching
- [ ] **NETV-10**: hideEdgesOnViewport optimization for smooth interactions
- [ ] **NETV-11**: Proper cy.destroy() cleanup prevents memory leaks

### Filters and Search

- [ ] **FILT-01**: Column-level text filters on data tables
- [ ] **FILT-02**: Numeric range filters with comparison operators (FDR < 0.05)
- [ ] **FILT-03**: Dropdown categorical filters for enumerated columns (GO, KEGG, MONDO)
- [ ] **FILT-04**: Wildcard gene search supports patterns (PKD*, BRCA?)
- [ ] **FILT-05**: Search highlights matching nodes in network
- [ ] **FILT-06**: CategoryFilter.vue shared component
- [ ] **FILT-07**: ScoreSlider.vue shared component
- [ ] **FILT-08**: TermSearch.vue shared component

### Navigation and Interlinking

- [ ] **NAVL-01**: Navigation tabs across all analysis pages (Phenotype Clusters, Gene Networks, Correlation)
- [ ] **NAVL-02**: Click cell in correlation heatmap navigates to corresponding cluster
- [ ] **NAVL-03**: URL state sync for cluster selection and filters
- [ ] **NAVL-04**: Bookmarkable/shareable analysis views with query parameters
- [ ] **NAVL-05**: Bidirectional network-to-table sync (click cluster → filter table)
- [ ] **NAVL-06**: useFilterSync composable with VueUse useUrlSearchParams
- [ ] **NAVL-07**: Fix `filter=undefined` bug in Phenotype Clusters entity links

### UI/UX Polish

- [ ] **UIUX-01**: Color legend for correlation heatmap (-1 to +1 scale)
- [ ] **UIUX-02**: Enhanced tooltips with correlation interpretation
- [ ] **UIUX-03**: Enable download buttons (PNG/SVG) on all visualizations
- [ ] **UIUX-04**: Loading states with progress indication for long operations
- [ ] **UIUX-05**: Error states with retry buttons

## v6 Requirements

Deferred to next milestone. Tracked but not in current roadmap.

### CI/CD & Infrastructure

- **CICD-01**: GitHub Actions CI/CD pipeline
- **CICD-02**: Trivy security scanning in pipeline
- **CICD-03**: URL path versioning (/api/v1/)
- **CICD-04**: Version displayed in frontend

### Frontend Coverage

- **TEST-01**: Expanded frontend test coverage (40-50%)
- **TEST-02**: Vue component TypeScript conversion

### Advanced Network Features

- **ADVN-01**: WebGL renderer for >500 node networks
- **ADVN-02**: Network layout persistence in localStorage
- **ADVN-03**: Gene set upload for custom network generation
- **ADVN-04**: STRINGdb upgrade to v12.0 with database migration

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| 3D network visualization | Depth perception issues, occlusion problems, increased cognitive load |
| Real-time filter updates without debounce | Performance degradation with excessive API calls |
| Infinite scroll on tables | Memory leaks with large datasets; keep cursor-based pagination |
| Combined filter UI in modal/sidebar | Breaks visibility principle; keep column-level filters visible |
| Multi-cluster network overlay | High complexity; defer to v6+ |
| Cluster comparison mode (side-by-side) | High complexity; defer to v6+ |
| Network motif detection | Research feature requiring backend graph algorithms; defer |
| STRINGdb v12.0 upgrade | Requires database STRING_id migration; defer to v6 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PERF-01 | Phase 25 | Pending |
| PERF-02 | Phase 25 | Pending |
| PERF-03 | Phase 25 | Pending |
| PERF-04 | Phase 25 | Pending |
| PERF-05 | Phase 25 | Pending |
| PERF-06 | Phase 25 | Pending |
| PERF-07 | Phase 25 | Pending |
| NETV-01 | Phase 26 | Pending |
| NETV-02 | Phase 26 | Pending |
| NETV-03 | Phase 26 | Pending |
| NETV-04 | Phase 26 | Pending |
| NETV-05 | Phase 26 | Pending |
| NETV-06 | Phase 26 | Pending |
| NETV-07 | Phase 26 | Pending |
| NETV-08 | Phase 26 | Pending |
| NETV-09 | Phase 26 | Pending |
| NETV-10 | Phase 26 | Pending |
| NETV-11 | Phase 26 | Pending |
| FILT-01 | Phase 27 | Pending |
| FILT-02 | Phase 27 | Pending |
| FILT-03 | Phase 27 | Pending |
| FILT-04 | Phase 27 | Pending |
| FILT-05 | Phase 27 | Pending |
| FILT-06 | Phase 27 | Pending |
| FILT-07 | Phase 27 | Pending |
| FILT-08 | Phase 27 | Pending |
| NAVL-01 | Phase 27 | Pending |
| NAVL-02 | Phase 27 | Pending |
| NAVL-03 | Phase 27 | Pending |
| NAVL-04 | Phase 27 | Pending |
| NAVL-05 | Phase 27 | Pending |
| NAVL-06 | Phase 27 | Pending |
| NAVL-07 | Phase 27 | Pending |
| UIUX-01 | Phase 27 | Pending |
| UIUX-02 | Phase 27 | Pending |
| UIUX-03 | Phase 27 | Pending |
| UIUX-04 | Phase 27 | Pending |
| UIUX-05 | Phase 27 | Pending |

**Coverage:**
- v5 requirements: 37 total
- Mapped to phases: 37
- Unmapped: 0 ✓

---
*Requirements defined: 2026-01-24*
*Last updated: 2026-01-24 after initial definition*
