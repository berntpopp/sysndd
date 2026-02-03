# Roadmap: SysNDD v10.2 Performance & Memory Optimization

## Overview

SysNDD v10.2 optimizes API memory usage for memory-constrained servers and fixes the ViewLogs performance bug that loads 1M+ rows into memory before filtering. The roadmap progresses from configurable workers (enabling deployment tuning), through analysis algorithm optimizations (STRING thresholds, adaptive layouts, GC calls), to database-side filtering for logs (indexes, parameterized queries, pagination), concluding with documentation and comprehensive testing.

## Milestones

- **v10.0 Data Quality & AI Insights** - Phases 1-65 (shipped 2026-02-01)
- **v10.1 Production Deployment Fixes** - Phases 66-68 (shipped 2026-02-03)
- **v10.2 Performance & Memory Optimization** - Phases 69-72 (in progress)

## Phases

<details>
<summary>v10.0 Data Quality & AI Insights (Phases 1-65) - SHIPPED 2026-02-01</summary>

See previous milestone documentation. v10.0 delivered:
- 8 major bug fixes (EIF2AK2, GAP43, MEF2C, viewer profile, PMID deletion, entities over time, disease renaming, re-reviewer identity)
- Publications view improvements with TimePlot, Stats, row details, admin bulk refresh
- Pubtator gene prioritization with novel alerts, PMID chips, Excel export
- LLM cluster summaries with Gemini API, batch pre-generation, LLM-as-judge validation
- LLM admin dashboard (ManageLLM.vue with 5 tabs)
- Comparisons data refresh async job
- GitHub Pages Actions workflow deployment

</details>

<details>
<summary>v10.1 Production Deployment Fixes (Phases 66-68) - SHIPPED 2026-02-03</summary>

See previous milestone documentation. v10.1 delivered:
- Fixed API container UID mismatch (configurable via build-arg, default 1000)
- Fixed migration lock timeout with double-checked locking pattern
- Restored favicon image from _old directory
- Removed container_name directive from API service for scaling

</details>

### v10.2 Performance & Memory Optimization (In Progress)

**Milestone Goal:** Optimize API memory usage for memory-constrained servers and fix ViewLogs performance bug.

**Target Issues:**
- #150: Optimize mirai worker configuration for memory-constrained servers
- #152: ViewLogs endpoint loads entire table into memory before filtering

- [ ] **Phase 69: Configurable Workers** - MIRAI_WORKERS env var with bounded configuration
- [ ] **Phase 70: Analysis Optimization** - STRING threshold, adaptive layout, LLM batch GC
- [ ] **Phase 71: ViewLogs Database Filtering** - Indexes, parameterized queries, pagination
- [ ] **Phase 72: Documentation & Testing** - Deployment guide and comprehensive test coverage

## Phase Details

### Phase 69: Configurable Workers
**Goal**: Operators can tune mirai worker count for their server's memory constraints
**Depends on**: Nothing (first phase of v10.2)
**Requirements**: MEM-01, MEM-02, MEM-03, MEM-04, MEM-05
**Success Criteria** (what must be TRUE):
  1. Operator can set MIRAI_WORKERS=N in docker-compose and API spawns exactly N workers
  2. Invalid values (0, 9, "abc") are rejected with sensible defaults applied
  3. Health endpoint response includes current worker count for monitoring
  4. Production docker-compose.yml defaults to 2 workers, dev defaults to 1 worker
**Plans:** 1 plan

Plans:
- [ ] 69-01-PLAN.md - Implement MIRAI_WORKERS configuration with validation and health endpoint exposure

### Phase 70: Analysis Optimization
**Goal**: Cluster analysis runs faster and uses less memory for large gene sets
**Depends on**: Phase 69
**Requirements**: STR-01, STR-02, STR-03, LAY-01, LAY-02, LAY-03, LAY-04, LLM-01, LLM-02
**Success Criteria** (what must be TRUE):
  1. STRING API returns ~50% fewer edges with score_threshold=400 (observable via API response size)
  2. Operator can override STRING threshold via function parameter when calling analysis endpoints
  3. Network visualization uses DrL layout for >1000 nodes (fast), FR-grid for 500-1000 nodes, standard FR for <500 nodes
  4. Network metadata reports actual layout algorithm used (user can verify in response)
  5. LLM batch job memory usage stays bounded over long runs (no gradual increase)
**Plans:** 3 plans

Plans:
- [ ] 70-01-PLAN.md - Increase STRING score_threshold to 400 with configurable parameter
- [ ] 70-02-PLAN.md - Implement adaptive layout algorithm selection based on graph size
- [ ] 70-03-PLAN.md - Add periodic gc() calls to LLM batch executor

### Phase 71: ViewLogs Database Filtering
**Goal**: ViewLogs page loads quickly with filtering done in database, not R memory
**Depends on**: Phase 70
**Requirements**: IDX-01, IDX-02, IDX-03, IDX-04, IDX-05, LOG-01, LOG-02, LOG-03, LOG-04, LOG-05, LOG-06, PAG-01, PAG-02
**Success Criteria** (what must be TRUE):
  1. Logging endpoint executes SQL with WHERE/LIMIT/OFFSET (no full table scan to R memory)
  2. Filter by timestamp range, status, path prefix all resolve to indexed queries
  3. SQL injection attempts in filter parameters are rejected (column whitelist enforced)
  4. Invalid filter syntax returns explicit 400 error with invalid_filter_error type
  5. Pagination response includes totalCount, totalPages, hasMore for UI pagination controls
**Plans:** TBD

Plans:
- [ ] 71-01: Add database indexes for logging table (timestamp, status, path, composites)
- [ ] 71-02: Implement query builder with column whitelist and parameterized queries
- [ ] 71-03: Implement offset-based pagination with build_offset_pagination_response()
- [ ] 71-04: Refactor logging endpoint to use database-side filtering

### Phase 72: Documentation & Testing
**Goal**: Deployment guide exists and all new code has test coverage
**Depends on**: Phase 71
**Requirements**: DOC-01, DOC-02, DOC-03, TST-01, TST-02, TST-03, TST-04, TST-05, TST-06, TST-07, TST-08, TST-09
**Success Criteria** (what must be TRUE):
  1. docs/DEPLOYMENT.md documents MIRAI_WORKERS with recommended values for small/medium/large servers
  2. CLAUDE.md memory configuration section helps developers understand worker tuning
  3. Unit tests verify MIRAI_WORKERS parsing rejects invalid values
  4. Unit tests verify column whitelist blocks unknown columns and SQL injection patterns
  5. Integration tests verify paginated queries return different pages with correct metadata
**Plans:** TBD

Plans:
- [ ] 72-01: Write unit tests for worker configuration and query builder
- [ ] 72-02: Write integration tests for database queries and pagination
- [ ] 72-03: Create deployment documentation with memory configuration profiles

## Progress

**Execution Order:**
Phases execute in numeric order: 69 -> 70 -> 71 -> 72

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 69. Configurable Workers | v10.2 | 0/1 | Planned | - |
| 70. Analysis Optimization | v10.2 | 0/3 | Planned | - |
| 71. ViewLogs Database Filtering | v10.2 | 0/4 | Not started | - |
| 72. Documentation & Testing | v10.2 | 0/3 | Not started | - |

---
*Roadmap created: 2026-02-03*
*Last updated: 2026-02-03 - Phase 70 planned (3 plans)*
