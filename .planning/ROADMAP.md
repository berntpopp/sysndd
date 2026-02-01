# Roadmap: SysNDD v10.1 Production Deployment Fixes

## Overview

SysNDD v10.1 fixes three critical production deployment issues blocking horizontal scaling: API container permission mismatch (UID 1001 vs host UID 1000), migration lock timeout when multiple containers start simultaneously, and missing favicon image. The roadmap progresses from infrastructure fixes to migration coordination to validation testing, ensuring multi-container production deployments work correctly.

## Milestones

- ✅ **v10.0 Data Quality & AI Insights** - Phases 1-65 (shipped 2026-02-01)
- 🚧 **v10.1 Production Deployment Fixes** - Phases 66-68 (in progress)

## Phases

<details>
<summary>✅ v10.0 Data Quality & AI Insights (Phases 1-65) - SHIPPED 2026-02-01</summary>

See previous milestone documentation. v10.0 delivered:
- 8 major bug fixes (EIF2AK2, GAP43, MEF2C, viewer profile, PMID deletion, entities over time, disease renaming, re-reviewer identity)
- Publications view improvements with TimePlot, Stats, row details, admin bulk refresh
- Pubtator gene prioritization with novel alerts, PMID chips, Excel export
- LLM cluster summaries with Gemini API, batch pre-generation, LLM-as-judge validation
- LLM admin dashboard (ManageLLM.vue with 5 tabs)
- Comparisons data refresh async job
- GitHub Pages Actions workflow deployment

</details>

### 🚧 v10.1 Production Deployment Fixes (In Progress)

**Milestone Goal:** Fix critical production deployment issues blocking horizontal scaling on VPS.

**Target Issues:**
- #138: API container cannot write to /app/data directory (UID mismatch)
- #136: Multi-container scaling fails due to migration lock timeout
- #137: Missing favicon image (brain-neurodevelopmental-disorders-sysndd.png)

- [ ] **Phase 66: Infrastructure Fixes** - UID fix, container_name removal, favicon restoration
- [ ] **Phase 67: Migration Coordination** - Double-checked locking for parallel startup
- [ ] **Phase 68: Local Production Testing** - Multi-container validation with 4 API replicas

## Phase Details

### Phase 66: Infrastructure Fixes
**Goal**: API containers can write to host directories and scale horizontally
**Depends on**: Nothing (first phase of v10.1)
**Requirements**: DEPLOY-01, DEPLOY-02, DEPLOY-04, BUG-01
**Success Criteria** (what must be TRUE):
  1. API container writes to /app/data without permission errors
  2. Dockerfile UID is configurable via build-arg (default 1000)
  3. `docker compose --scale api=4` succeeds without container naming conflict
  4. Favicon image loads without 404 errors in browser
**Plans:** 1 plan

Plans:
- [ ] 66-01-PLAN.md — Infrastructure fixes (UID, container_name, favicon)

### Phase 67: Migration Coordination
**Goal**: Multiple API containers start in parallel without migration lock timeout
**Depends on**: Phase 66
**Requirements**: DEPLOY-03, MIGRATE-01, MIGRATE-02, MIGRATE-03
**Success Criteria** (what must be TRUE):
  1. Schema check happens before lock acquisition (fast path when up-to-date)
  2. Double-check after lock prevents race condition (handles concurrent migration)
  3. Health endpoint reports migration status accurately
  4. Four API containers start simultaneously without timeout errors
**Plans**: TBD

Plans:
- [ ] 67-01: Migration double-checked locking implementation

### Phase 68: Local Production Testing
**Goal**: Verified multi-container scaling works correctly in production-like environment
**Depends on**: Phase 67
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04
**Success Criteria** (what must be TRUE):
  1. Production Docker environment builds and runs locally with 4 API replicas
  2. Container logs show parallel startup (not sequential lock waiting)
  3. All 4 containers can write to shared /app/data directory
  4. Fresh database startup triggers migration from exactly one container
  5. Any issues discovered during testing are fixed and re-validated
**Plans**: TBD

Plans:
- [ ] 68-01: Local production multi-container testing and validation

## Progress

**Execution Order:**
Phases execute in numeric order: 66 -> 67 -> 68

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 66. Infrastructure Fixes | v10.1 | 0/1 | Planned | - |
| 67. Migration Coordination | v10.1 | 0/1 | Not started | - |
| 68. Local Production Testing | v10.1 | 0/1 | Not started | - |

---
*Roadmap created: 2026-02-01*
*Last updated: 2026-02-01*
