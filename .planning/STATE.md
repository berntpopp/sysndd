# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-24)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** Phase 27 - Advanced Features & Filters (v5.0 Analysis Modernization)

## Current Position

**Milestone:** v5.0 Analysis Modernization
**Phase:** 27 of 27 (Advanced Features & Filters)
**Plan:** 8 of 10 complete
**Status:** In progress
**Last activity:** 2026-01-25 — Completed 27-08-PLAN.md (PhenotypeClusters Cytoscape Migration)

```
v5 Analysis Modernization: PHASE 27 IN PROGRESS
Goal: Transform analysis pages with performance, network viz, and modern UI/UX
Progress: ██████████████████████▓▓▓▓▓▓ 80% (8/10 plans complete)
          [Phase 25 ✓] → [Phase 26 ✓] → [Phase 27 ▶]
```

## Completed Milestones

| Milestone | Phases | Plans | Shipped | Archive |
|-----------|--------|-------|---------|---------|
| v1 Developer Experience | 1-5 | 19 | 2026-01-21 | milestones/v1-* |
| v2 Docker Infrastructure | 6-9 | 8 | 2026-01-22 | milestones/v2-* |
| v3 Frontend Modernization | 10-17 | 53 | 2026-01-23 | milestones/03-frontend-modernization/ |
| v4 Backend Overhaul | 18-24 | 42 | 2026-01-24 | milestones/v4-* |

**v5 Target:**
- 3 phases (25-27)
- Expected duration: 1-2 days
- Key deliverable: 50-65% cold start reduction (15s → 5-7s), true PPI networks

## GitHub Issues

| Issue | Description | Status |
|-------|-------------|--------|
| #109 | Refactor sysndd_plumber.R into smaller endpoint files | Ready for PR (v4 complete) |
| #123 | Implement comprehensive testing | Foundation complete, integration tests added |

## Tech Debt

**Remaining (non-blocking):**
- Job workers cannot access pool (pre-fetch workaround functional)
- OMIM/MONDO functions worker-sourced, not global (works for async use case)
- entity_endpoints.R uses old pagination (pre-existing)
- Vue components still .vue JavaScript (not TypeScript)
- Frontend test coverage ~1.5%

**Deferred to v6:**
- CI/CD pipeline (GitHub Actions)
- Trivy security scanning
- Expanded frontend test coverage (40-50%)
- Vue component TypeScript conversion
- URL path versioning (/api/v1/)
- Version displayed in frontend

## Key Decisions

See PROJECT.md for full decisions table.

Recent v5-relevant decisions:
- **Leiden over Walktrap**: 2-3x faster clustering, built-in igraph support
- **Leiden parameters**: modularity objective, resolution=1.0, beta=0.01, n_iterations=2
- **Cache key versioning**: Include algorithm, STRING version, and CACHE_VERSION env var
- **HCPC kk=50**: Pre-partition into 50 clusters (16% of ~309 entities) for 50-70% speedup
- **MCA ncp=8**: Captures >70% variance, reduced from ncp=15 for 20-30% speedup
- **Performance monitoring**: /health/performance endpoint for worker pool and cache observability
- **Cytoscape.js over D3 force**: Rich algorithms, compound nodes, WebGL support
- **fcose over cose-bilkent**: 2x speed improvement, active maintenance
- **Vue 3 composables**: Direct control, TypeScript support, established pattern
- **VueUse useUrlSearchParams**: Zero boilerplate URL state sync
- **Non-reactive cy instance**: let cy (not ref()) prevents 100+ layout recalculations
- **cy.destroy() cleanup**: Prevents 100-300MB memory leaks per navigation
- **STRING ID deduplication**: Pick first HGNC ID alphabetically for deterministic 1:1 mapping
- **URL parameter pattern**: Use filterStrToObj for URL state initialization (matches TablesGenes.vue)
- **Optional composable imports**: Only import composables where actually used, not speculatively
- **Simplified Cytoscape composables**: Not all use cases need compound node complexity (usePhenotypeCytoscape vs useCytoscape)
- **Sequential cluster edges**: Connect adjacent clusters for network structure (prevents isolated bubbles in fcose layout)

## Accumulated Context

### Blockers/Concerns

**Pre-Phase 25 (RESOLVED):**
- ~~Cache invalidation: Existing memoise cache keys don't include algorithm name or STRING version~~ FIXED in 25-01
- Worker pool sizing: Current 8-worker pool may be insufficient with pagination
- Cluster sizes: Need to validate actual max cluster sizes in production data

**Research status:** Complete with HIGH confidence. No phases require deeper research.

### v5 Context Files

Pre-existing analysis documents:
- `.planning/research/SUMMARY-v5.md` — Full research findings (HIGH confidence)
- `.plan/ANALYSIS-ENDPOINTS-DEBUG-REPORT.md` — Performance bottlenecks
- `.plan/NETWORK-VISUALIZATION-RESEARCH.md` — Cytoscape.js architecture
- `.plan/UI-UX-ANALYSIS-REVIEW.md` — Interlinking, filters, navigation

### Phase 26 Completed Plans

| Plan | Name | Summary |
|------|------|---------|
| 26-01 | Backend Network Endpoint | /api/analysis/network_edges endpoint with STRINGdb PPI extraction (3k+ nodes, 66k+ edges) |
| 26-02 | Vue 3 Composables | useCytoscape lifecycle management, useNetworkData data fetching |
| 26-03 | NetworkVisualization Component | 807-line Cytoscape.js component with fcose layout, hover tooltips, click navigation, cluster filtering |

### Phase 27 Completed Plans

| Plan | Name | Summary |
|------|------|---------|
| 27-01 | Core Composables | useFilterSync (URL state sync), useWildcardSearch (PKD*/BRCA? matching), useNetworkHighlight (bidirectional hover) |
| 27-02 | Filter Components | CategoryFilter, ScoreSlider, TermSearch reusable filter components with v-model binding |
| 27-03 | Analysis Navigation | AnalysisTabs navigation, AnalysisView parent orchestration, /Analysis route, NAVL-07 bug fix |
| 27-04 | Filter Integration | Wildcard search highlighting in network, URL state persistence, correlation heatmap filter sync prep |
| 27-05 | UI Polish | ColorLegend component, correlation interpretation tooltips, error states with retry buttons |
| 27-06 | URL Parameter Fix | Fixed broken URL parameter handling on Entities page using filterStrToObj pattern |
| 27-07 | Filter Integration (Gene Clusters) | CategoryFilter dropdown and ScoreSlider FDR threshold integrated into AnalyseGeneClusters |
| 27-08 | PhenotypeClusters Cytoscape Migration | D3.js bubble chart replaced with Cytoscape.js network, simplified usePhenotypeCytoscape composable (-134 lines) |
| 27-10 | Fix PhenotypeCorrelations | Removed unused useFilterSync import that was breaking /PhenotypeCorrelations page |

## Session Continuity

**Last session:** 2026-01-25
**Stopped at:** Completed 27-08-PLAN.md (PhenotypeClusters Cytoscape Migration)
**Resume file:** None
**Next action:** Continue Phase 27 gap closure plans (27-09)

---
*State initialized: 2026-01-24 for v5.0 milestone*
*Last updated: 2026-01-25 — Plan 27-08 complete (PhenotypeClusters Cytoscape Migration)*
