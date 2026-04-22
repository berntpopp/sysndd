---
phase: 21
plan: 03
subsystem: data-access
tags: [repository-layer, status, publication, crud, validation, transactions]

requires:
  - 21-01  # Database helper functions

provides:
  - Status domain repository functions
  - Publication domain repository functions
  - Parameterized CRUD operations for status and publication

affects:
  - 22-*  # Endpoint refactoring will use these repositories

tech-stack:
  added: []
  patterns:
    - "Repository pattern for status domain"
    - "Repository pattern for publication domain"
    - "Atomic approval with transaction"
    - "Publication validation via pool+dplyr"

key-files:
  created:
    - api/functions/status-repository.R
    - api/functions/publication-repository.R
  modified:
    - api/start_sysndd_api.R

decisions:
  - slug: status-approval-transaction
    title: Status approval uses transaction for atomicity
    rationale: Approving a status requires multiple database operations (reset all entity statuses, set new active status). Transaction ensures all-or-nothing operation.
    date: 2026-01-24

  - slug: publication-validation-pool-dplyr
    title: Publication validation uses pool with dplyr
    rationale: Cleaner than raw SQL, leverages existing pool connection, type-safe with dplyr's collect()
    date: 2026-01-24

  - slug: prevent-entity-id-changes
    title: Status update prevents entity_id changes
    rationale: Changing which entity a status belongs to would break referential integrity. Remove from update operations.
    date: 2026-01-24

metrics:
  duration: "2m 53s"
  completed: 2026-01-24
---

# Phase 21 Plan 03: Status and Publication Repositories Summary

**One-liner:** Status and publication repositories with validation, transactions, and parameterized queries

## What Was Built

### Status Repository (`api/functions/status-repository.R`)
Created repository with 6 functions for status domain operations:

1. **status_find_by_id(status_id)** - Find single status record
   - Parameterized SELECT query
   - Returns tibble (0 rows if not found)

2. **status_find_by_entity(entity_id)** - Find all statuses for entity
   - Ordered by status_id DESC
   - Returns tibble (0 rows if none)

3. **status_create(status_data)** - Create new status
   - Validates required fields (entity_id, category_id)
   - Removes status_id if accidentally provided (for POST requests)
   - Returns newly created status_id from LAST_INSERT_ID()

4. **status_update(status_id, updates)** - Update existing status
   - Prevents entity_id and status_id changes (maintains associations)
   - Dynamic SET clause from provided fields
   - Converts logical to integer for database compatibility

5. **status_approve(status_ids, approving_user_id, approved)** - Approve/reject statuses
   - Handles single ID or vector of IDs
   - **Uses transaction for atomicity:**
     - If approved: Reset all entity statuses to inactive, set selected to active
     - If rejected: Set status_approved = 0
   - Sets approving_user_id in both cases

6. **status_update_re_review_status(entity_id, status_id)** - Link to re-review workflow
   - Marks re-review as having saved status
   - Used in re-review context

### Publication Repository (`api/functions/publication-repository.R`)
Created repository with 6 functions for publication domain operations:

1. **publication_find_by_id(publication_id)** - Find single publication
   - Returns pmid, title, publication_year
   - Returns tibble (0 rows if not found)

2. **publication_find_by_ids(publication_ids)** - Find multiple publications
   - Handles empty input (returns empty tibble with correct columns)
   - Uses parameterized IN clause

3. **publication_validate_ids(publication_ids)** - Validate against allowed list
   - **Uses pool with dplyr** (not raw SQL)
   - Checks all provided IDs exist in publication table
   - On invalid: throws publication_validation_error with invalid_ids attribute

4. **publication_connect_to_review(review_id, entity_id, publications)** - Connect publications
   - Validates publication IDs first
   - Validates entity_id matches review's entity_id (prevents changing associations)
   - Inserts into ndd_review_publication_join

5. **publication_replace_for_review(review_id, entity_id, publications)** - Replace all publications
   - **Uses transaction for atomicity:**
     - DELETE all existing publications for review
     - INSERT new publications
   - Validates publication IDs and entity_id before operation

6. **publication_find_with_context(publication_ids)** - Find with review/entity context
   - Joins publication with ndd_review_publication_join and ndd_entity_review
   - Returns full context for where publications are used

### Integration
Sourced both repositories in `start_sysndd_api.R`:
- Added after db-helpers.R (line 112-113)
- Loaded before endpoint-functions.R
- Available to all endpoint modules

## Deviations from Plan

None - plan executed exactly as written.

## Decisions Made

### 1. Status Approval Uses Transaction for Atomicity
**Context:** Approving a status requires multiple database operations:
- Reset is_active = 0 for all statuses of same entities
- Set is_active = 1 for selected statuses
- Set status_approved = 1
- Set approving_user_id

**Decision:** Wrap all operations in `db_with_transaction()`

**Rationale:**
- Ensures all-or-nothing operation (no partial approvals)
- Prevents race conditions between entity status updates
- Automatic rollback on any error

**Impact:** Status approval is now atomic and consistent

### 2. Publication Validation Uses pool + dplyr
**Context:** Need to validate that publication IDs exist in database

**Options considered:**
- A) Raw SQL with IN clause
- B) pool %>% tbl() %>% collect() with dplyr

**Decision:** Option B (pool + dplyr)

**Rationale:**
- Cleaner, more readable code
- Type-safe with dplyr's collect()
- Leverages existing pool connection
- Consistent with existing patterns in database-functions.R

**Impact:** Validation code is more maintainable

### 3. Status Update Prevents entity_id Changes
**Context:** Status update function accepts arbitrary fields to update

**Decision:** Remove entity_id and status_id from updates via `select(-any_of(...))`

**Rationale:**
- Changing which entity a status belongs to would break referential integrity
- status_id should never change (it's the primary key)
- Explicit prevention is better than relying on caller to not provide these fields

**Impact:** Prevents accidental data corruption

## Technical Achievements

### Parameterized Queries Throughout
- All SQL queries use positional `?` placeholders
- Parameters passed via params list
- No SQL injection vulnerabilities

### Consistent Error Handling
- Validation errors use `rlang::abort()` with class attributes
- Structured error classes: status_validation_error, publication_validation_error
- Enables type-safe error handling in endpoints

### Transaction Support
- Critical operations wrapped in transactions
- Automatic commit on success
- Automatic rollback on error

### Logging Integration
- DEBUG-level logging for all operations
- Logs entity counts, affected rows, operation types
- Helps debugging and auditing

## Testing Notes

### Status Repository
**Functions to test:**
- status_approve with multiple IDs
- status_approve with transaction rollback (invalid status_id)
- status_update preventing entity_id change
- status_create removing accidental status_id

**Edge cases:**
- Empty status_ids in approval
- Status approval when entity has no existing statuses
- Rejection flow (approved = FALSE)

### Publication Repository
**Functions to test:**
- publication_validate_ids with invalid IDs
- publication_replace_for_review with transaction rollback
- publication_connect_to_review with mismatched entity_id
- publication_find_by_ids with empty input

**Edge cases:**
- Empty publication_ids
- Publications with no review associations
- Entity_id mismatch validation

## Next Phase Readiness

### Status Repository Ready For
- 22-04: Status endpoint refactoring
- Review creation endpoints (status creation)
- Entity approval workflows (status approval)

### Publication Repository Ready For
- 22-05: Publication endpoint refactoring
- Review submission endpoints (publication connections)
- Publication management workflows

### Blockers/Concerns
None. Repositories ready for endpoint refactoring in Phase 22.

## Files Changed

### Created
- `api/functions/status-repository.R` (327 lines)
  - 6 exported functions
  - Full validation and transaction support

- `api/functions/publication-repository.R` (309 lines)
  - 6 exported functions
  - Validation with pool+dplyr

### Modified
- `api/start_sysndd_api.R` (+2 lines)
  - Source status-repository.R
  - Source publication-repository.R

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| 62bdf5b | feat | Create status-repository.R with 6 CRUD functions |
| af794c1 | feat | Create publication-repository.R with 6 CRUD functions |
| 4e97a5a | feat | Source both repositories in start_sysndd_api.R |

## Metrics

- **Duration:** 2 minutes 53 seconds
- **Files created:** 2
- **Files modified:** 1
- **Lines added:** 636
- **Functions created:** 12 (6 per repository)
- **Commits:** 3 (atomic per task)

---
*Completed: 2026-01-24*
*Phase: 21 (Repository Layer)*
*Plan: 03/08*
