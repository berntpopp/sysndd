---
phase: 05-expanded-test-coverage
verified: 2026-01-21T18:45:00Z
status: gaps_found
score: 2/4 success criteria verified
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  gaps_closed:
    - "make coverage generates HTML coverage report (was broken, now fixed)"
  gaps_remaining:
    - "Code coverage at 20.3%, still 49.7 points below 70% target"
    - "No HTTP endpoint integration tests exist"
  regressions: []
gaps:
  - truth: "Code coverage for functions/*.R reaches 70% or higher"
    status: failed
    reason: "Coverage at 20.3% (up from 12.4% after gap closure), still 49.7 points below target"
    artifacts:
      - path: "api/functions/*.R"
        issue: "Most function files have DB/network-dependent code that cannot be unit tested"
    missing:
      - "Integration tests with running database for DB functions"
      - "Recorded httptest2 fixtures for external API calls"
      - "Alternative: Adjust 70% target to reflect testable code vs DB/network code"
  - truth: "All critical endpoints have at least one integration test"
    status: failed
    reason: "test-integration-*.R files test helper functions at function level, not HTTP endpoints"
    artifacts:
      - path: "api/tests/testthat/test-integration-entity.R"
        issue: "Tests entity data structures and helpers, not POST/GET /entity HTTP endpoints"
      - path: "api/tests/testthat/test-integration-auth.R"
        issue: "Tests JWT functions, not /auth HTTP endpoint"
    missing:
      - "Plumber test infrastructure to start/stop API for endpoint testing"
      - "HTTP endpoint tests for POST /entity, GET /entities"
      - "HTTP endpoint tests for GET /genes, GET /phenotypes"
      - "HTTP endpoint tests for POST /analysis"
---

# Phase 5: Expanded Test Coverage Re-Verification Report

**Phase Goal:** Comprehensive test coverage providing confidence for future refactoring.

**Verified:** 2026-01-21T18:45:00Z

**Status:** gaps_found

**Re-verification:** Yes — after gap closure (plans 05-05 and 05-06)

## Goal Achievement

### Success Criteria from ROADMAP.md

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Code coverage for functions/*.R reaches 70% or higher | FAILED | Actual: 20.3% (49.7 points below target) |
| 2 | All critical endpoints have at least one integration test | FAILED | No HTTP endpoint tests; test-integration-*.R tests helper functions |
| 3 | Running `make coverage` generates HTML coverage report | VERIFIED | Command succeeds, outputs coverage/coverage-report.html |
| 4 | Test suite completes in under 2 minutes | VERIFIED | Test suite runs in 1m11s (49 seconds under budget) |

**Score:** 2/4 success criteria verified

### Coverage Progress After Gap Closure

| Metric | Before (05-04) | After (05-06) | Delta |
|--------|----------------|---------------|-------|
| Line coverage | 12.4% | 20.3% | +7.9% |
| Test count | 257 | 610 | +353 |
| Test files | 11 | 16 | +5 |
| Test assertions | ~200 | ~312 | +112 |

### Required Artifacts

| Artifact | Status | Lines | Details |
|----------|--------|-------|---------|
| `Makefile` (coverage target) | VERIFIED | 6 | `make coverage` succeeds, generates HTML report |
| `api/scripts/coverage.R` | VERIFIED | 92 | Pre-loads all dependencies, calculates coverage |
| `api/tests/testthat/test-unit-helper-functions.R` | VERIFIED | 454 | 38 test_that blocks |
| `api/tests/testthat/test-database-functions.R` | VERIFIED | 351 | 25 test_that blocks |
| `api/tests/testthat/test-unit-file-functions.R` | VERIFIED | 320 | 18 test_that blocks |
| `api/tests/testthat/test-unit-endpoint-functions.R` | VERIFIED | 395 | 18 test_that blocks |
| `api/tests/testthat/test-unit-ontology-functions.R` | VERIFIED | 392 | 17 test_that blocks |
| `api/tests/testthat/test-unit-logging-functions.R` | VERIFIED | 314 | 19 test_that blocks (NEW) |
| `api/tests/testthat/test-unit-config-functions.R` | VERIFIED | 400 | 8 test_that blocks (NEW) |
| `api/tests/testthat/test-unit-publication-functions.R` | VERIFIED | 547 | 23 test_that blocks (NEW) |
| `api/tests/testthat/test-unit-hpo-functions.R` | VERIFIED | 593 | 23 test_that blocks (NEW) |
| `api/tests/testthat/test-unit-genereviews-functions.R` | VERIFIED | 620 | 46 test_that blocks (NEW) |
| `coverage/coverage-report.html` | VERIFIED | ~2MB | HTML report generated successfully |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| Makefile | scripts/coverage.R | Rscript invocation | WIRED | make coverage succeeds |
| scripts/coverage.R | covr::file_coverage | Library call | WIRED | Coverage calculated correctly |
| test-unit-logging-functions.R | logging-functions.R | source() | WIRED | Tests convert_empty(), read_log_files() |
| test-unit-config-functions.R | config-functions.R | source() | WIRED | Tests update_api_spec_examples() |
| test-unit-publication-functions.R | publication-functions.R | source() | WIRED | Tests table_articles_from_xml() |
| test-unit-hpo-functions.R | hpo-functions.R | source() | WIRED | Tests hpo_children_from_term() |
| test-unit-genereviews-functions.R | string patterns | direct use | WIRED | Tests parsing patterns |

### Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| COV-01: 70%+ coverage of function files | BLOCKED | Coverage is 20.3%, 49.7 points below target; remaining functions require DB/network |
| COV-02: Integration tests for critical endpoints | BLOCKED | No HTTP endpoint tests exist; current "integration" tests test functions, not endpoints |
| COV-03: Coverage reporting via covr | VERIFIED | make coverage generates HTML report successfully |

### Gap Closure Assessment

**Closed from previous verification:**
1. Coverage script now works (was failing due to missing dependency loading)

**Remaining gaps (structural limitations):**

1. **Coverage at 20.3%, target was 70%**
   - Gap closure added 5 new test files with 353 additional tests
   - Improved from 12.4% to 20.3% (7.9 percentage point gain)
   - Remaining ~50% gap is due to functions tightly coupled to database and external APIs
   - These functions cannot be unit tested without:
     - Running database (requires Docker + DB container)
     - Recorded HTTP fixtures (requires live API calls during recording)
   - The SUMMARY for 05-06 notes: "Realistic target for unit tests: ~25-30%"

2. **No HTTP endpoint integration tests**
   - Files named `test-integration-*.R` test helper functions at the function level
   - No actual HTTP endpoint testing (POST /entity, GET /genes, etc.)
   - This requires plumber test infrastructure to start/stop API during tests
   - Outside the scope of unit test expansion; requires integration test infrastructure

### Function File Test Coverage Mapping

| Function File | Has Tests | Test File | Coverage Status |
|---------------|-----------|-----------|-----------------|
| helper-functions.R | Yes | test-unit-helper-functions.R | Comprehensive |
| endpoint-functions.R | Yes | test-unit-endpoint-functions.R | Comprehensive |
| file-functions.R | Yes | test-unit-file-functions.R | Comprehensive |
| ontology-functions.R | Yes | test-unit-ontology-functions.R | Comprehensive |
| database-functions.R | Yes | test-database-functions.R | Validation only |
| logging-functions.R | Yes | test-unit-logging-functions.R | Pure functions |
| config-functions.R | Yes | test-unit-config-functions.R | Pure functions |
| publication-functions.R | Yes | test-unit-publication-functions.R | XML parsing |
| hpo-functions.R | Yes | test-unit-hpo-functions.R | Local ontology |
| genereviews-functions.R | Yes | test-unit-genereviews-functions.R | String patterns |
| hgnc-functions.R | Yes | test-external-hgnc.R | Mocked HTTP |
| ensembl-functions.R | Yes | test-external-ensembl.R | Mocked HTTP |
| pubtator-functions.R | Yes | test-external-pubtator.R | Mocked HTTP |
| analyses-functions.R | No | - | DB-dependent |
| external-functions.R | No | - | 2 lines (wrapper) |
| oxo-functions.R | No | - | Deprecated API |

**14 of 16 function files (87.5%)** have dedicated test files.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| api/tests/testthat/test-integration-entity.R | 1-5 | Misleading "integration" name | Warning | Tests helper functions, not HTTP endpoints |
| api/tests/testthat/test-integration-auth.R | 1-6 | Misleading "integration" name | Warning | Tests JWT functions, not /auth endpoint |
| api/functions/ontology-functions.R | 4 | require(tidyverse) | Warning | Causes warnings in tests, should use specific packages |

### Human Verification Required

None - all verifiable items can be checked programmatically.

### Root Cause Analysis

**Why 70% coverage target was not achieved:**

1. **Architectural coupling:** Most API functions are tightly coupled to database and external services. Pure business logic is limited.

2. **Target miscalibration:** The 70% target was set without analyzing what percentage of code is testable with unit tests vs requires integration tests.

3. **Unit test scope:** Phase 5 focused on unit test expansion. HTTP endpoint testing requires different infrastructure (plumber test harness).

**Recommendation:**

The 70% target should be reconsidered given the architectural reality:
- **Unit-testable code:** ~25-30% (pure functions, validation, parsing)
- **Integration-testable code:** ~40-50% (DB queries, HTTP handlers)
- **Network-dependent code:** ~20-30% (external API calls)

To reach 70% overall coverage would require:
1. Database integration tests with Docker test container
2. Plumber test harness for HTTP endpoint testing
3. Extensive httptest2 fixture recording

This represents a separate phase of work beyond "unit test expansion."

### Summary

**What was accomplished:**
- Test suite expanded from 257 to 610 tests (137% increase)
- Coverage improved from 12.4% to 20.3% (64% relative improvement)
- 5 new test files covering pure functions in logging, config, publication, HPO, GeneReviews
- make coverage now works reliably with HTML report generation
- Test suite runs in 1m11s (well under 2 minute threshold)

**What remains blocked:**
- 70% coverage target requires integration tests with running services
- HTTP endpoint integration tests require plumber test infrastructure
- These are infrastructure investments beyond unit test expansion scope

---

_Verified: 2026-01-21T18:45:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification: After gap closure plans 05-05 and 05-06_
