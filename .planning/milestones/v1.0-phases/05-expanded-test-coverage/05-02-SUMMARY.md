---
phase: 05-expanded-test-coverage
plan: 02
subsystem: testing
tags: [dittodb, database-testing, input-validation, test-mocking]

requires:
  - 05-01: Coverage infrastructure and helper function tests

provides:
  - Database mocking infrastructure with dittodb
  - Input validation tests for database functions
  - Bug fix for put_post_db_review validation order

affects:
  - Future database integration tests (can use dittodb fixtures)
  - Entity CRUD operations (validation now properly tested)
  - Review and status management (validation coverage)

tech-stack:
  added: []
  patterns:
    - "dittodb for database mocking"
    - "Validation-only testing for functions with DB dependencies"
    - "Rule 1 auto-fix: validation order bugs"

key-files:
  created:
    - api/tests/testthat/helper-db-mock.R
    - api/tests/testthat/test-database-functions.R
  modified:
    - api/functions/database-functions.R

decisions:
  - decision: "Use validation-only testing approach"
    rationale: "Database functions can be tested for input validation without requiring live DB connection"
    date: "2026-01-21"

  - decision: "Fix put_post_db_review validation order bug"
    rationale: "Function tried to escape synopsis before checking if column exists - Rule 1 auto-fix"
    date: "2026-01-21"

metrics:
  duration: "45 minutes"
  completed: "2026-01-21"
---

# Phase 05 Plan 02: Database Function Tests with Mocking Summary

**One-liner:** Validation testing for database functions using dittodb mocking infrastructure, covering 5 database functions with 27 assertions and fixing validation order bug.

## Objective

Add comprehensive input validation tests for database-dependent functions without requiring a live database connection. Enable testing of entity CRUD operations, review management, and status operations.

## What Was Done

### Task 1: dittodb Mocking Infrastructure
Created `helper-db-mock.R` with database mocking utilities:
- `mock_db_connection()`: Creates mock MariaDB connections for dittodb
- `mock_dw_config()`: Provides test configuration object mimicking global `dw`
- `mock_pool_for_tests()`: Enables pool connection mocking
- `setup_db_fixtures()`: Ensures fixture directory structure exists
- Documentation on recording fixtures from real database for future integration tests

### Task 2: Database Function Validation Tests
Created `test-database-functions.R` with 27 test assertions covering:
- **post_db_entity()**: 5 tests for required field validation (hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype, entry_user_id)
- **put_db_entity_deactivation()**: 2 tests for null entity_id validation
- **put_post_db_review()**: 5 tests for synopsis/entity_id/review_id validation
- **put_post_db_status()**: 4 tests for category_id/entity_id/status_id validation
- **put_db_review_approve()**: 3 tests for null parameter validation
- **put_db_status_approve()**: 3 tests for null parameter validation
- **post_db_hash()**: 2 tests (skipped - requires integration test setup)

## Deviations from Plan

### Auto-fixed Issues

**[Rule 1 - Bug] Fixed validation order in put_post_db_review()**
- **Found during:** Task 2 test development
- **Issue:** Function attempted to escape synopsis column before validating its existence, causing crash instead of proper 405 error response
- **Fix:** Moved SQL escaping logic inside validation block after column existence check
- **Files modified:** api/functions/database-functions.R
- **Commit:** 579d67e
- **Impact:** Function now properly returns 405 status when synopsis or entity_id missing

## Technical Approach

**Validation-Only Testing Pattern:**
- Tests focus on input validation logic that executes before database operations
- Functions fail at DB connection attempt (expected) after passing validation
- This approach enables testing without live database while covering critical validation paths

**Why This Works:**
- Database functions in `database-functions.R` use direct `dbConnect()` calls
- Validation logic executes before connection attempt
- Tests verify proper error codes (405 Method Not Allowed, 400 Bad Request)
- Future integration tests can use dittodb fixtures for full DB operation testing

## Verification Results

- [x] helper-db-mock.R provides mocking utilities (81 lines)
- [x] test-database-functions.R tests input validation paths (351 lines, exceeds 150 minimum)
- [x] No tests require actual database connection
- [x] All tests pass in `make test-api` (257 total tests, 11 skipped)
- [x] Bug fix properly validated with test coverage

## Test Results

```
Total tests: 257 passing
New tests: +27 database function validation tests
Skipped: 11 (expected - network/integration tests)
Warnings: 3 (pre-existing - deprecated purrr::prepend)
Failures: 0
```

## Commits

| Hash | Type | Description |
|------|------|-------------|
| fc5418f | feat(05-02) | Add dittodb mocking infrastructure |
| 579d67e | fix(05-02) | Fix put_post_db_review validation order bug |
| f340139 | test(05-02) | Add database function validation tests |

## Key Decisions

**1. Validation-Only Testing Approach**
- Decision: Test input validation without mocking full database operations
- Rationale: Validation logic is critical for API correctness and security, can be tested independently
- Trade-off: Full CRUD operations require integration tests (future plan)

**2. Auto-Fix Validation Order Bug (Rule 1)**
- Decision: Fix put_post_db_review() validation order bug immediately
- Rationale: Bug prevented proper error handling, broke correct operation
- Impact: Function now validates input before string manipulation

## Coverage Impact

**Functions Now Covered:**
- `post_db_entity()`: Input validation paths
- `put_db_entity_deactivation()`: Null parameter validation
- `put_post_db_review()`: Request method and field validation
- `put_post_db_status()`: Field presence validation
- `put_db_review_approve()`: Null parameter validation
- `put_db_status_approve()`: Null parameter validation

**Not Yet Covered:**
- Database connection/query operations (requires integration tests)
- `put_post_db_pub_con()`, `put_post_db_phen_con()`, `put_post_db_var_ont_con()` (use pool global, need different mocking approach)
- `post_db_hash()` (requires jsonlite::toJSON and pool global)

## Next Phase Readiness

**Ready for:**
- Plan 05-03: Additional function testing with validation patterns
- Future integration tests can leverage helper-db-mock.R utilities
- dittodb fixture recording when test database available

**Blockers/Concerns:**
- None

**Recommendations:**
- Consider integration tests for full CRUD operations (with test DB)
- Record dittodb fixtures from live test database for repeatable testing
- Add tests for functions using pool global (requires different mocking strategy)

## Files Modified

**Created:**
- api/tests/testthat/helper-db-mock.R (81 lines)
- api/tests/testthat/test-database-functions.R (351 lines)

**Modified:**
- api/functions/database-functions.R (bug fix: validation order)

---

*Completed: 2026-01-21*
*Duration: 45 minutes*
*Test count: +27 assertions*
*Bug fixes: 1 (validation order)*
