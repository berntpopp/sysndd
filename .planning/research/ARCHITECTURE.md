# Architecture Integration: v10.5 Bug Fixes & Data Integrity

**Project:** SysNDD
**Milestone:** v10.5 Bug Fixes & Data Integrity  
**Researched:** 2026-02-08
**Type:** Subsequent milestone (architectural changes to existing system)

## Executive Summary

This milestone fixes 6 bugs across the R API, Vue frontend, and Docker infrastructure. The fixes are surgical interventions in an existing architecture with well-established patterns. All changes integrate with the existing **repository + service + endpoint** layering (R API) and **composables + components + views** pattern (Vue frontend).

**Key architectural impacts:**
1. **New shared utilities** for DRY violations (#173, #171)
2. **Repository layer enhancement** for data sync (#172 Bug 1)
3. **SQL query fix** for batch annotation logic (#170)
4. **Docker configuration patch** for Traefik routing (#169)
5. **New admin view** for data integrity audit (#167)

All fixes preserve existing patterns. No new dependencies, no schema changes, no architectural pivots.

## System Architecture Context

### Current R API Architecture

```
api/
├── endpoints/              # HTTP routing layer
│   ├── comparisons_endpoints.R
│   ├── statistics_endpoints.R
│   └── ...
├── functions/              # Business logic + DB access
│   ├── endpoint-functions.R
│   ├── review-repository.R
│   ├── status-repository.R
│   ├── pubtator-functions.R
│   └── ...
└── services/               # Service orchestration
    ├── entity-service.R
    ├── approval-service.R
    └── ...
```

**Conventions:**
- Endpoints wire HTTP to repository/service functions
- Repository functions own database transactions
- Service functions provide business logic orchestration  
- All DB operations use parameterized queries via db-helpers.R

### Current Frontend Architecture

```
app/src/
├── views/                  # Page components
│   ├── admin/
│   │   ├── AdminStatistics.vue
│   │   ├── ManageOntology.vue
│   │   └── ...
│   └── comparisons/
│       └── CurationComparisons.vue
├── components/             # Reusable UI components
└── utils/                  # Pure utility functions (currently minimal)
```

**Conventions:**
- Vue 3 Composition API with script setup
- Bootstrap-Vue-Next for UI components
- Axios for API calls with auth headers
- Chart.js for data visualization

## Bug Fixes: Integration Points

See full documentation at:
- `.planning/bugs/172-1-rereview-approved-pending.md` (Re-review approval sync)
- `.planning/bugs/171-entity-trend-aggregation.md` (Time series aggregation)

## Build Order (Dependency Chain)

### Phase 1: Foundation (No Dependencies)
1. **Fix #173: Category Normalization**
   - New: `api/functions/category-normalization.R`
   - Modify: `api/functions/endpoint-functions.R`, `api/endpoints/comparisons_endpoints.R`

2. **Fix #171: Time Series Utils**
   - New: `app/src/utils/timeSeriesUtils.ts`
   - Modify: `app/src/views/admin/AdminStatistics.vue`

3. **Fix #169: Traefik Configuration**
   - Modify: `docker-compose.prod.yml` router labels

### Phase 2: Repository Layer  
4. **Fix #172: Re-Review Approval Sync**
   - New: `api/functions/re-review-sync.R`
   - Modify: `api/functions/review-repository.R`, `api/functions/status-repository.R`
   - Modify: `api/endpoints/re_review_endpoints.R`, `api/endpoints/statistics_endpoints.R`

### Phase 3: Data Layer
6. **Fix #170: PubTator Batch Logic**
   - Modify: `api/functions/pubtator-functions.R` (LEFT JOIN for missing annotations)

### Phase 4: Admin Tooling
7. **Fix #167: Entity Integrity Audit**
   - New: `db/migrations/006_entity_integrity_fixes.sql`
   - New: `api/endpoints/admin_integrity_endpoints.R`
   - New: `app/src/views/admin/ManageEntityIntegrity.vue`
   - New: `app/src/components/admin/EntityIntegrityTable.vue`
   - Modify: `app/src/router/index.ts`, `app/src/views/admin/AdminPanel.vue`

**Estimated effort:** 10-14 hours (excluding testing and code review)

## Integration Points Summary

| Fix | Layer | Pattern | New Files | Modified Files |
|-----|-------|---------|-----------|----------------|
| #173 | API Functions | Utility extraction | 1 | 3 |
| #171 | Frontend Utils | Utility extraction | 1 | 1 |
| #172 | Repository | Transaction hook | 1 | 5 |
| #170 | Repository | SQL query fix | 0 | 1 |
| #169 | Infrastructure | Config patch | 0 | 1 |
| #167 | Full Stack | Admin view | 4 | 3 |

**Total:** 7 new files, 14 modified files

## Data Flow Changes

### Fix #172: Re-Review Approval Sync (Most Complex)

**Before:**
```
PUT /api/review/approve/:id
  → review_approve() 
    → UPDATE ndd_entity_review
    (re_review_entity_connect NOT touched)
```

**After:**
```
PUT /api/review/approve/:id
  → review_approve()
    → db_with_transaction({
        UPDATE ndd_entity_review
        sync_rereview_approval()  ← NEW
          → UPDATE re_review_entity_connect
      })
```

**Why Repository Layer:** Both direct approval and re-review approval call review_approve(). Adding sync here means ALL approval paths get it automatically (Open-Closed Principle).

### Fix #171: Time Series Aggregation

**Before:**
```
AdminStatistics.vue
  → API returns grouped series
    → Manual sum of incremental counts (WRONG)
```

**After:**
```
AdminStatistics.vue
  → API returns grouped series  
    → mergeGroupedCumulativeSeries() utility
      → Forward-fill + sum cumulative counts (CORRECT)
```

### Fix #170: PubTator Annotations

**Before:** Fetch annotations for ALL PMIDs (including already-cached)
**After:** LEFT JOIN to find only PMIDs missing annotations

## Deployment Considerations

### Database Migrations
- Migration 006 runs on API startup (existing auto-migration system)
- Idempotent: Can run multiple times without errors
- No schema changes, only data fixes

### Configuration Changes  
- Fix #169 requires docker-compose.prod.yml update
- No downtime (Traefik reload picks up new labels)

### Backward Compatibility
- All API endpoints remain unchanged (no breaking changes)
- Frontend changes are purely UI improvements
- Database schema unchanged

### Performance Impact
- Fix #173: Negligible (< 1ms function call overhead)
- Fix #171: Negligible (~10ms client-side aggregation)
- Fix #172: +10ms per approval (1 additional UPDATE)
- Fix #170: **Improvement** (saves 2-5 seconds per incremental update)
- Fix #167: Admin-only, no production impact

## Architectural Principles Applied

| Principle | How Applied |
|-----------|-------------|
| **DRY** | Fix #173 extracts normalization; Fix #171 extracts aggregation |
| **SRP** | Each new utility does exactly one thing |
| **OCP** | Fix #172 sync works for all future approval pathways |
| **Repository Pattern** | Fix #172 keeps DB mutations in repository layer |
| **Transaction Safety** | Fix #172 sync happens inside existing transaction |

## Sources

**HIGH Confidence:**
- SysNDD codebase (api/, app/, docker-compose.prod.yml) — read directly
- Bug fix proposals in .planning/bugs/ — authored by project team  
- GitHub issues #167, #169, #170, #171, #172, #173 — official bug reports
- PROJECT.md — project context and architectural history

No external sources needed. All information from codebase and project documentation.
