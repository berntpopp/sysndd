# Requirements: SysNDD v10.2 Performance & Memory Optimization

**Defined:** 2026-02-03
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v10.2 Requirements

Requirements for memory optimization and ViewLogs performance fixes. Each maps to roadmap phases.

### Memory Configuration (#150)

- [x] **MEM-01**: mirai worker count is configurable via MIRAI_WORKERS environment variable ✓
- [x] **MEM-02**: Worker count is bounded between 1 and 8 workers ✓
- [x] **MEM-03**: Worker count is exposed in health endpoint response for monitoring ✓
- [x] **MEM-04**: docker-compose.yml includes MIRAI_WORKERS with default 2 ✓
- [x] **MEM-05**: docker-compose.override.yml includes MIRAI_WORKERS with default 1 ✓

### STRING Optimization (#150)

- [ ] **STR-01**: STRING score_threshold is 400 (medium confidence) in gen_string_clust_obj()
- [ ] **STR-02**: STRING score_threshold is 400 in gen_string_enrich_tib()
- [ ] **STR-03**: score_threshold parameter is configurable via function argument with 400 default

### Layout Algorithm (#150)

- [ ] **LAY-01**: Layout algorithm adapts to graph size (>1000 nodes uses DrL)
- [ ] **LAY-02**: Medium graphs (500-1000 nodes) use FR with grid optimization
- [ ] **LAY-03**: Small graphs (<500 nodes) use standard FR (current behavior preserved)
- [ ] **LAY-04**: Network metadata reflects actual layout algorithm used

### LLM Batch Optimization (#150)

- [ ] **LLM-01**: LLM batch executor calls gc() every 10 clusters
- [ ] **LLM-02**: Final gc() call after batch processing completes

### ViewLogs Performance (#152)

- [ ] **LOG-01**: Logging endpoint uses database-side filtering (no collect() before filter)
- [ ] **LOG-02**: Query builder validates columns against whitelist
- [ ] **LOG-03**: Query builder uses parameterized queries (? placeholders)
- [ ] **LOG-04**: Filter parser rejects unparseable input with invalid_filter_error
- [ ] **LOG-05**: Offset-based pagination with LIMIT/OFFSET
- [ ] **LOG-06**: Count query returns total matching rows for pagination metadata

### Database Indexes (#152)

- [ ] **IDX-01**: Index on logging(timestamp) for date range queries
- [ ] **IDX-02**: Index on logging(status) for status filtering
- [ ] **IDX-03**: Index on logging(path) with prefix for path filtering
- [ ] **IDX-04**: Composite index on logging(timestamp, status)
- [ ] **IDX-05**: Composite index on logging(id DESC, status)

### Pagination Helper (#152)

- [ ] **PAG-01**: build_offset_pagination_response() function exists
- [ ] **PAG-02**: Pagination response includes totalCount, pageSize, offset, currentPage, totalPages, hasMore

### Documentation (#150)

- [ ] **DOC-01**: docs/DEPLOYMENT.md documents MIRAI_WORKERS configuration
- [ ] **DOC-02**: Deployment profiles for small (4-8GB), medium (16GB), large (32GB+) servers
- [ ] **DOC-03**: CLAUDE.md updated with memory configuration section

### Testing

- [ ] **TST-01**: Unit tests for MIRAI_WORKERS parsing and bounds
- [ ] **TST-02**: Unit tests for column validation in query builder
- [ ] **TST-03**: Unit tests for ORDER BY clause building
- [ ] **TST-04**: Unit tests for WHERE clause building with parameterization
- [ ] **TST-05**: Unit tests reject SQL injection attempts
- [ ] **TST-06**: Unit tests reject unparseable filter syntax
- [ ] **TST-07**: Integration tests verify database query execution
- [ ] **TST-08**: Integration tests verify pagination returns different pages
- [ ] **TST-09**: All existing tests continue to pass

## Future Requirements

None - this is a focused optimization milestone.

## Out of Scope

| Feature | Reason |
|---------|--------|
| MCA/HCPC optimization | Already optimal per FactoMineR docs (kk=50, ncp=8) |
| Keyset/cursor pagination for logs | Offset simpler and adequate for admin-only endpoint |
| Redis for shared cache | Named volume sufficient for current scale |
| STRINGdb v12.0 upgrade | Would require database migration |
| Custom vector store for RAG | Not needed for current LLM use case |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| MEM-01 | Phase 69 | Complete |
| MEM-02 | Phase 69 | Complete |
| MEM-03 | Phase 69 | Complete |
| MEM-04 | Phase 69 | Complete |
| MEM-05 | Phase 69 | Complete |
| STR-01 | Phase 70 | Pending |
| STR-02 | Phase 70 | Pending |
| STR-03 | Phase 70 | Pending |
| LAY-01 | Phase 70 | Pending |
| LAY-02 | Phase 70 | Pending |
| LAY-03 | Phase 70 | Pending |
| LAY-04 | Phase 70 | Pending |
| LLM-01 | Phase 70 | Pending |
| LLM-02 | Phase 70 | Pending |
| IDX-01 | Phase 71 | Pending |
| IDX-02 | Phase 71 | Pending |
| IDX-03 | Phase 71 | Pending |
| IDX-04 | Phase 71 | Pending |
| IDX-05 | Phase 71 | Pending |
| LOG-01 | Phase 71 | Pending |
| LOG-02 | Phase 71 | Pending |
| LOG-03 | Phase 71 | Pending |
| LOG-04 | Phase 71 | Pending |
| LOG-05 | Phase 71 | Pending |
| LOG-06 | Phase 71 | Pending |
| PAG-01 | Phase 71 | Pending |
| PAG-02 | Phase 71 | Pending |
| DOC-01 | Phase 72 | Pending |
| DOC-02 | Phase 72 | Pending |
| DOC-03 | Phase 72 | Pending |
| TST-01 | Phase 72 | Pending |
| TST-02 | Phase 72 | Pending |
| TST-03 | Phase 72 | Pending |
| TST-04 | Phase 72 | Pending |
| TST-05 | Phase 72 | Pending |
| TST-06 | Phase 72 | Pending |
| TST-07 | Phase 72 | Pending |
| TST-08 | Phase 72 | Pending |
| TST-09 | Phase 72 | Pending |

**Coverage:**
- v10.2 requirements: 39 total
- Mapped to phases: 39
- Unmapped: 0

---
*Requirements defined: 2026-02-03*
*Last updated: 2026-02-03 — Phase 69 requirements complete*
