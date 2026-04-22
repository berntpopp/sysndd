---
phase: 21-repository-layer
plan: 04
subsystem: data-access
tags: [repository-pattern, phenotype, ontology, vario, hpo, validation, transactions]
requires: [21-01-database-helpers]
provides: [phenotype-repository, ontology-repository]
affects: [21-06-phenotype-endpoints, 21-07-ontology-endpoints]
tech-stack:
  added: []
  patterns: [repository-validation, entity-id-matching]
key-files:
  created:
    - api/functions/phenotype-repository.R
    - api/functions/ontology-repository.R
  modified:
    - api/start_sysndd_api.R
decisions:
  - decision: "Validate against allowed lists before database operations"
    rationale: "Prevents invalid HPO/VARIO terms from being inserted"
    impact: "All phenotype/ontology operations check against phenotype_list/variation_ontology_list tables"
  - decision: "Enforce entity_id matching for review connections"
    rationale: "Prevent changing entity association of existing reviews"
    impact: "Both connect and replace operations verify entity_id matches review"
  - decision: "Parallel domain structure (phenotype/ontology repositories mirror each other)"
    rationale: "Same connection pattern for different term types reduces cognitive load"
    impact: "Both repositories have identical function signatures and validation patterns"
metrics:
  duration: "172 seconds"
  completed: "2026-01-24"
---

# Phase 21 Plan 04: Phenotype and Ontology Repositories Summary

**One-liner:** HPO phenotype and VARIO ontology repositories with validation against allowed term lists and transactional replace operations

## What Was Built

Created two parallel domain repositories for managing connections between reviews and controlled vocabularies:

1. **Phenotype Repository** (HPO terms)
   - `phenotype_get_allowed_list()` - Retrieve valid phenotype IDs from phenotype_list table
   - `phenotype_validate_ids()` - Validate phenotype IDs against allowed list
   - `phenotype_find_by_review()` - Get phenotypes connected to a review
   - `phenotype_connect_to_review()` - Insert phenotype connections
   - `phenotype_replace_for_review()` - Transactional replace operation

2. **Ontology Repository** (VARIO terms)
   - `variation_ontology_get_allowed_list()` - Retrieve valid vario IDs from variation_ontology_list table
   - `variation_ontology_validate_ids()` - Validate vario IDs against allowed list
   - `variation_ontology_find_by_review()` - Get variation ontology terms connected to a review
   - `variation_ontology_connect_to_review()` - Insert variation ontology connections
   - `variation_ontology_replace_for_review()` - Transactional replace operation

Both repositories sourced in `start_sysndd_api.R` after db-helpers.R.

## Architecture

```
Endpoint Layer (future 21-06, 21-07)
         ↓
Repository Layer (21-04)
├─ phenotype-repository.R
│  ├─ Validates against phenotype_list table
│  ├─ Enforces entity_id matching
│  └─ Uses db-helpers for parameterized queries
└─ ontology-repository.R
   ├─ Validates against variation_ontology_list table
   ├─ Enforces entity_id matching
   └─ Uses db-helpers for parameterized queries
         ↓
Database Layer (21-01)
└─ db-helpers.R
   ├─ db_execute_query() - SELECT queries
   ├─ db_execute_statement() - INSERT/UPDATE/DELETE
   └─ db_with_transaction() - Atomic operations
```

## Validation Pattern

Both repositories follow this validation flow:

1. **ID Validation** - Check all IDs exist in allowed list (phenotype_list or variation_ontology_list)
2. **Entity ID Validation** - Verify entity_id matches review's entity_id from ndd_entity_review
3. **Database Operation** - Only proceed if both validations pass

This prevents:
- Invalid HPO/VARIO terms from being inserted
- Changing entity association of existing reviews
- Partial updates via transactional replace

## Database Schema Integration

**Phenotype Connections:**
- Table: `ndd_review_phenotype_connect`
- Columns: review_id, entity_id, phenotype_id, modifier_id
- Validates against: `phenotype_list.phenotype_id`

**Ontology Connections:**
- Table: `ndd_review_variation_ontology_connect`
- Columns: review_id, entity_id, vario_id, modifier_id
- Validates against: `variation_ontology_list.vario_id`

## Key Decisions

### 1. Validate Against Allowed Lists Before Database Operations

**Context:** Both phenotypes (HPO) and variation ontology (VARIO) use controlled vocabularies. Not all terms are allowed in the system.

**Decision:** Created separate validation functions that check against phenotype_list and variation_ontology_list tables before any INSERT operations.

**Alternatives Considered:**
- Database foreign key constraints - Would work but produces less helpful error messages
- Endpoint-level validation - Would duplicate validation logic across endpoints

**Outcome:**
- Repository layer validates all IDs before database operations
- Structured errors (`phenotype_validation_error`, `variation_ontology_validation_error`) with invalid_ids attribute
- Single source of truth for validation logic

### 2. Enforce Entity ID Matching for Review Connections

**Context:** Reviews are associated with entities. When updating phenotype/ontology connections, we need to prevent changing the entity association.

**Decision:** Both `connect_to_review()` and `replace_for_review()` functions query ndd_entity_review to verify the provided entity_id matches the review's entity_id.

**Alternatives Considered:**
- Trust caller to provide correct entity_id - Too risky, could corrupt data
- Remove entity_id from connection tables - Would lose referential integrity

**Outcome:**
- All connection operations verify entity_id matches review
- Throws `entity_id_mismatch_error` if mismatch detected
- Throws `review_not_found_error` if review doesn't exist

### 3. Parallel Domain Structure

**Context:** Phenotype and ontology repositories perform identical operations on different tables with different term types.

**Decision:** Mirrored the structure exactly - same function names (with different prefixes), same parameters, same validation pattern.

**Alternatives Considered:**
- Generic connection repository - Would be complex with multiple table/column configurations
- Combine into single file - Would be 500+ lines, harder to navigate

**Outcome:**
- phenotype-repository.R: 296 lines, 5 functions
- ontology-repository.R: 296 lines, 5 functions (exact mirror)
- Developers only need to learn pattern once, applies to both domains

## Implementation Details

### Replace Operation Pattern

Both repositories use identical transactional replace pattern:

```r
result <- db_with_transaction({
  # 1. Delete existing connections
  deleted <- db_execute_statement(
    "DELETE FROM [table] WHERE review_id = ?",
    list(review_id)
  )

  # 2. Insert new connections
  for (i in seq_len(nrow(data))) {
    db_execute_statement(
      "INSERT INTO [table] (...) VALUES (?, ?, ?, ?)",
      list(...)
    )
  }

  return(total_inserted)
})
```

This ensures atomic replace - either all new connections are inserted, or none are (transaction rollback on error).

### Validation Before Transaction

Both repositories validate IDs **before** starting the transaction:

```r
# Validate first (outside transaction)
[domain]_validate_ids(data$[id_column])

# Then transact
result <- db_with_transaction({ ... })
```

This avoids starting transactions that will fail validation, reducing database load.

### Use of Pool with dplyr

Validation functions use pool with dplyr for efficient retrieval:

```r
allowed <- pool %>%
  tbl("phenotype_list") %>%
  select(phenotype_id) %>%
  collect()
```

This leverages:
- Pool's automatic connection management
- dplyr's lazy evaluation (query built on DB side)
- Tibble return type for consistent interface

## Testing Notes

**Manual Testing Required:**
- Both repositories depend on database tables (phenotype_list, variation_ontology_list, ndd_review_phenotype_connect, ndd_review_variation_ontology_connect)
- Cannot run without database connection
- Future endpoint integration (plans 21-06, 21-07) will test via HTTP requests

**Key Test Cases for Future:**
1. Validation failures - Invalid phenotype/vario IDs
2. Entity ID mismatch - Provided entity_id doesn't match review
3. Review not found - review_id doesn't exist
4. Transaction rollback - Insert fails mid-transaction
5. Replace operation - Delete + insert atomicity

## Migration from database-functions.R

**Replaced Functions:**

From `put_post_db_phen_con()` (lines 491-597):
- Now: `phenotype_validate_ids()`, `phenotype_connect_to_review()`, `phenotype_replace_for_review()`
- Removed: dbConnect/dbDisconnect calls, replaced with db-helpers
- Removed: request_method parameter (will be handled by endpoints)
- Added: Structured error handling with error classes

From `put_post_db_var_ont_con()` (lines 618-725):
- Now: `variation_ontology_validate_ids()`, `variation_ontology_connect_to_review()`, `variation_ontology_replace_for_review()`
- Removed: dbConnect/dbDisconnect calls, replaced with db-helpers
- Removed: request_method parameter (will be handled by endpoints)
- Added: Structured error handling with error classes

**Improvements:**
1. No more dbConnect bypass (all operations use pool via db-helpers)
2. Parameterized queries prevent SQL injection
3. Structured errors enable type-safe error handling in endpoints
4. Transactional replace ensures atomicity
5. Entity ID validation separated from HTTP method logic

## Deviations from Plan

None - plan executed exactly as written.

## Files Changed

**Created:**
- `api/functions/phenotype-repository.R` (296 lines)
  - 5 exported functions for phenotype domain operations
  - Validates against phenotype_list table
  - Uses db-helpers for all database operations

- `api/functions/ontology-repository.R` (296 lines)
  - 5 exported functions for variation ontology domain operations
  - Validates against variation_ontology_list table
  - Uses db-helpers for all database operations

**Modified:**
- `api/start_sysndd_api.R`
  - Added `source("functions/phenotype-repository.R", local = TRUE)` after db-helpers.R
  - Added `source("functions/ontology-repository.R", local = TRUE)` after phenotype-repository.R

## Commits

| Commit | Message | Files |
|--------|---------|-------|
| 92e4558 | feat(21-04): create phenotype repository | api/functions/phenotype-repository.R |
| c889ae0 | feat(21-04): create ontology repository | api/functions/ontology-repository.R |
| 88947e2 | feat(21-04): source phenotype and ontology repositories | api/start_sysndd_api.R |

## Dependencies

**Requires:**
- 21-01: Database helpers (db_execute_query, db_execute_statement, db_with_transaction)
- Global pool object (from start_sysndd_api.R)
- Database tables: phenotype_list, variation_ontology_list, ndd_entity_review, ndd_review_phenotype_connect, ndd_review_variation_ontology_connect

**Enables:**
- 21-06: Phenotype endpoint refactoring (will use phenotype-repository functions)
- 21-07: Ontology endpoint refactoring (will use ontology-repository functions)

## Next Phase Readiness

**Ready for:**
- Plan 21-06: Phenotype endpoints can now use repository functions instead of database-functions.R
- Plan 21-07: Ontology endpoints can now use repository functions instead of database-functions.R

**Pattern established:**
- Validation before database operations
- Entity ID matching enforcement
- Transactional replace operations
- Parallel domain structures for similar operations

**No blockers** - both repositories ready for endpoint integration.
