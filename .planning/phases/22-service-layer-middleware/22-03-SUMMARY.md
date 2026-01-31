---
phase: 22-service-layer-middleware
plan: 03
subsystem: api
tags: [service-layer, entity-management, business-logic, r, plumber, pool, parameterized-queries]

# Dependency graph
requires:
  - phase: 22-01
    provides: Authentication middleware and require_role helper
  - phase: 21-02
    provides: Entity repository with parameterized queries
  - phase: 19-01
    provides: RFC 9457 error helpers and logging sanitizer
provides:
  - Entity service layer with business logic
  - entity_validate for centralized validation
  - entity_create with duplicate checking
  - entity_deactivate with parameterized queries
  - entity_get_full for comprehensive entity retrieval
  - entity_check_duplicate for quadruple validation
affects: [22-04, 22-05, entity-endpoints, review-service]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Service layer dependency injection (pool as parameter)"
    - "Pool checkout/return pattern for connection management"
    - "Duplicate checking via entity quadruple validation"
    - "Comprehensive entity retrieval with related data"

key-files:
  created:
    - api/services/entity-service.R
  modified:
    - api/start_sysndd_api.R

key-decisions:
  - "Service layer uses pool parameter for dependency injection"
  - "Entity duplicate checking via quadruple (hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype)"
  - "entity_get_full retrieves entity with all related data (reviews, status, phenotypes, publications)"
  - "Direct db_execute_statement calls in service layer (bypassing repository for simplicity)"

patterns-established:
  - "Service layer pattern: validation -> business logic -> repository/DB -> structured response"
  - "Pool checkout/return with on.exit for guaranteed cleanup"
  - "Structured API responses with status, message, entry/error fields"

# Metrics
duration: 3min
completed: 2026-01-24
---

# Phase 22 Plan 03: Entity Service Layer Summary

**Entity service with validation, duplicate checking, and comprehensive retrieval using pool-based parameterized queries**

## Performance

- **Duration:** 3 min
- **Started:** 2026-01-24T14:56:47Z
- **Completed:** 2026-01-24T14:59:59Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- Created entity-service.R with 5 business logic functions (336 lines)
- Migrated post_db_entity and put_db_entity_deactivation from database-functions.R
- Added duplicate entity checking via quadruple validation
- Implemented comprehensive entity retrieval with related data
- Sourced service in start_sysndd_api.R

## Task Commits

Each task was committed atomically:

1. **Task 1: Create entity-service.R with core functions** - `3554145` (feat)
   - entity_validate, entity_create, entity_deactivate, entity_get_full, entity_check_duplicate
   - Pool checkout/return pattern
   - Parameterized queries via db_execute_statement

2. **Task 2: Source entity-service.R in start_sysndd_api.R** - `93122d6` (feat)
   - Added source line after auth-service.R

3. **Task 3: Document migration from database-functions.R** - `08f1257` (docs)
   - Migration mapping documented
   - Future migration roadmap identified

## Files Created/Modified
- `api/services/entity-service.R` - Entity business logic and validation (336 lines)
- `api/start_sysndd_api.R` - Added entity-service.R source line

## Decisions Made

**1. Service layer uses pool parameter for dependency injection**
- **Rationale:** Testability and SOLID principles - services accept dependencies rather than accessing global state
- **Impact:** Future tests can inject mock pools

**2. Entity duplicate checking via quadruple validation**
- **Rationale:** Prevent duplicate entities with same hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, and ndd_phenotype
- **Impact:** Returns 409 Conflict status when duplicate detected

**3. entity_get_full retrieves comprehensive entity data**
- **Rationale:** Single function to get entity with all related data (reviews, status, phenotypes, publications, variation ontology)
- **Impact:** Reduces boilerplate in endpoints

**4. Direct db_execute_statement calls in service layer**
- **Rationale:** Service layer directly uses db-helpers instead of going through repository layer for entity operations
- **Impact:** Simpler stack, avoids naming conflicts between repository and service functions

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

**1. Function naming conflict with repository layer**
- **Issue:** Repository (entity-repository.R) and service layer both define entity_create, entity_deactivate, etc.
- **Resolution:** Service layer directly calls db_execute_statement/db_execute_query instead of calling repository functions
- **Impact:** Cleaner separation - repository layer available for future use but service doesn't depend on it

## Migration Status

### Migrated from database-functions.R

| Original Function | Service Function | Lines |
|-------------------|------------------|-------|
| post_db_entity (23-99) | entity_create | Enhanced with duplicate checking |
| put_db_entity_deactivation (129-165) | entity_deactivate | Uses parameterized queries |

### Remaining for Future Plans

The following functions remain in database-functions.R for migration in later plans:

- **put_post_db_review** → review-service.R (Plan 22-04 or 22-05)
- **put_post_db_pub_con** → publication-service.R
- **put_post_db_phen_con** → review-service.R
- **put_post_db_var_ont_con** → review-service.R
- **put_post_db_status** → status-service.R
- **post_db_hash** → hash-service.R
- **put_db_review_approve** → approval-service.R
- **put_db_status_approve** → approval-service.R

Original functions will be deleted in Plan 22-08 (Service Migration Complete).

## Next Phase Readiness

**Ready for next phase:**
- Entity service layer complete and sourced
- Business logic extracted from database-functions.R
- Duplicate checking prevents data integrity issues
- Comprehensive retrieval function available for endpoints

**For future plans:**
- Review service will need similar pattern (Plan 22-04/22-05)
- Endpoints can be refactored to use entity_create, entity_deactivate, entity_get_full
- Database-functions.R cleanup in Plan 22-08

**No blockers.**

---
*Phase: 22-service-layer-middleware*
*Completed: 2026-01-24*
