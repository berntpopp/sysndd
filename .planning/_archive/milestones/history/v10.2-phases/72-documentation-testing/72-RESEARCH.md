# Phase 72: Documentation & Testing - Research

**Researched:** 2026-02-03
**Domain:** R testthat framework, Markdown documentation, deployment guides
**Confidence:** HIGH

## Summary

Phase 72 completes the documentation and testing for the features implemented in Phases 69 (configurable workers), 70 (analysis optimization), and 71 (viewlogs database filtering). The research confirms that the codebase has well-established patterns for both documentation and testing that this phase can follow exactly.

**Documentation scope:**
1. `docs/DEPLOYMENT.md` - New deployment guide documenting MIRAI_WORKERS with server profiles (small/medium/large)
2. `CLAUDE.md` update - Add memory configuration section for worker tuning guidance

**Testing scope:**
1. Unit tests for MIRAI_WORKERS parsing (Phase 69)
2. Unit tests for logging-repository.R query builder (Phase 71): column whitelist, ORDER BY, WHERE clause building, SQL injection rejection
3. Integration tests for pagination (Phase 71)

The existing test infrastructure (44 test files, ~700+ tests) provides clear patterns. All new tests should use the existing helpers: `source_api_file()`, `skip_if_no_test_db()`, `local_mocked_bindings()`.

**Primary recommendation:** Follow existing test file patterns exactly. Create `test-unit-mirai-workers.R` for Phase 69 tests and `test-unit-logging-repository.R` for Phase 71 query builder tests. Documentation uses standard Markdown.

## Standard Stack

The established libraries/tools for this domain:

### Core Testing
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| testthat | 3.x | Unit testing framework | Already configured in setup.R |
| withr | 3.0.x | Test environment isolation | Used for local_envvar, local_mocked_bindings |
| rlang | 1.1.x | Error classes for expect_error | Standard for class-based error testing |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| httr2 | 1.x | HTTP requests for integration tests | Already used in test-integration-pagination.R |
| DBI | 1.2.x | Database interface mocking | Already used in test-db-helpers.R |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| local_mocked_bindings | mockery::mock | local_mocked_bindings is testthat 3.x native |
| describe()/it() | test_that() | Both supported; test_that() more common in codebase |

**Installation:**
No new packages required - all dependencies already in renv.lock.

## Architecture Patterns

### Recommended Project Structure
```
api/tests/testthat/
  test-unit-mirai-workers.R          # NEW - Phase 69 tests
  test-unit-logging-repository.R     # NEW - Phase 71 query builder tests
  test-integration-logs-pagination.R # NEW - Phase 71 integration tests
  helper-db.R                        # EXISTING - use skip_if_no_test_db()
  helper-paths.R                     # EXISTING - use source_api_file()
  helper-skip.R                      # EXISTING - use skip_if_not_slow_tests()
docs/
  DEPLOYMENT.md                      # NEW - deployment guide
CLAUDE.md                            # MODIFY - add memory section
```

### Pattern 1: Unit Test File Structure
**What:** Standard testthat file structure with describe/it or test_that blocks
**When to use:** All unit tests
**Example:**
```r
# Source: api/tests/testthat/test-unit-security.R
# Source the module under test
source_api_file("functions/logging-repository.R", local = FALSE)

# ============================================================================
# validate_logging_column() tests
# ============================================================================

describe("validate_logging_column", {
  it("accepts valid columns", {
    expect_no_error(validate_logging_column("status"))
    expect_no_error(validate_logging_column("timestamp"))
  })

  it("rejects invalid columns with invalid_filter_error", {
    expect_error(
      validate_logging_column("nonexistent"),
      class = "invalid_filter_error"
    )
  })

  it("rejects SQL injection attempts", {
    expect_error(
      validate_logging_column("id; DROP TABLE logging; --"),
      class = "invalid_filter_error"
    )
  })
})
```

### Pattern 2: Testing Environment Variable Parsing
**What:** Use withr::local_envvar() to set environment variables in test scope
**When to use:** Testing functions that read Sys.getenv()
**Example:**
```r
# Source: api/tests/testthat/test-unit-analyses-functions.R
test_that("MIRAI_WORKERS defaults to 2 when not set", {
  withr::local_envvar(MIRAI_WORKERS = NA)  # Unset

  worker_count <- as.integer(Sys.getenv("MIRAI_WORKERS", "2"))
  if (is.na(worker_count)) worker_count <- 2L

  expect_equal(worker_count, 2L)
})

test_that("MIRAI_WORKERS=abc falls back to default", {
  withr::local_envvar(MIRAI_WORKERS = "abc")

  worker_count <- as.integer(Sys.getenv("MIRAI_WORKERS", "2"))
  if (is.na(worker_count)) worker_count <- 2L
  worker_count <- max(1L, min(worker_count, 8L))

  expect_equal(worker_count, 2L)
})

test_that("MIRAI_WORKERS=0 is bounded to 1", {
  withr::local_envvar(MIRAI_WORKERS = "0")

  worker_count <- as.integer(Sys.getenv("MIRAI_WORKERS", "2"))
  if (is.na(worker_count)) worker_count <- 2L
  worker_count <- max(1L, min(worker_count, 8L))

  expect_equal(worker_count, 1L)
})

test_that("MIRAI_WORKERS=10 is bounded to 8", {
  withr::local_envvar(MIRAI_WORKERS = "10")

  worker_count <- as.integer(Sys.getenv("MIRAI_WORKERS", "2"))
  if (is.na(worker_count)) worker_count <- 2L
  worker_count <- max(1L, min(worker_count, 8L))

  expect_equal(worker_count, 8L)
})
```

### Pattern 3: Testing Query Builder Functions
**What:** Test SQL building functions without database, verify output strings and params
**When to use:** Testing functions like build_logging_where_clause()
**Example:**
```r
# Source: Pattern from test-db-helpers.R
describe("build_logging_where_clause", {
  it("returns 1=1 for empty filters", {
    result <- build_logging_where_clause(list())
    expect_equal(result$clause, "1=1")
    expect_equal(length(result$params), 0)
  })

  it("builds status filter with parameterization", {
    result <- build_logging_where_clause(list(status = 200))
    expect_true(grepl("status = \\?", result$clause))
    expect_equal(result$params[[1]], 200L)
  })

  it("builds path prefix filter with LIKE", {
    result <- build_logging_where_clause(list(path_prefix = "/api/"))
    expect_true(grepl("path LIKE \\?", result$clause))
    expect_equal(result$params[[1]], "/api/%")  # % appended
  })

  it("combines multiple filters with AND", {
    result <- build_logging_where_clause(list(
      status = 200,
      request_method = "GET"
    ))
    expect_true(grepl("AND status = \\?", result$clause))
    expect_true(grepl("AND request_method = \\?", result$clause))
    expect_equal(length(result$params), 2)
  })
})
```

### Pattern 4: Integration Test with Database Skip
**What:** Test that accesses real database with skip_if_no_test_db()
**When to use:** Testing actual database queries and pagination
**Example:**
```r
# Source: api/tests/testthat/test-integration-pagination.R
test_that("logs pagination returns different pages", {
  skip_if_no_test_db()
  skip_if_api_not_running()

  # Get first page
  resp1 <- request("http://localhost:8000/api/logs") %>%
    req_url_query(page = 1, per_page = 10) %>%
    req_perform()

  body1 <- resp_body_json(resp1)

  # Get second page
  resp2 <- request("http://localhost:8000/api/logs") %>%
    req_url_query(page = 2, per_page = 10) %>%
    req_perform()

  body2 <- resp_body_json(resp2)

  # Verify different data
  if (length(body1$data) > 0 && length(body2$data) > 0) {
    # First item IDs should be different
    expect_false(body1$data[[1]]$id == body2$data[[1]]$id)
  }
})

test_that("logs pagination metadata is correct", {
  skip_if_no_test_db()
  skip_if_api_not_running()

  resp <- request("http://localhost:8000/api/logs") %>%
    req_url_query(page = 1, per_page = 10) %>%
    req_perform()

  body <- resp_body_json(resp)

  # Verify pagination metadata
  expect_true("totalCount" %in% names(body$meta) || "totalCount" %in% names(body))
  expect_true("pageSize" %in% names(body$meta) || "perPage" %in% names(body$meta))
})
```

### Anti-Patterns to Avoid
- **Testing implementation instead of behavior:** Don't test private functions; test public API
- **Brittle string matching:** Use regex patterns (`grepl`) not exact string equality for SQL
- **Missing cleanup:** Always use `withr::local_*` instead of manual setup/teardown
- **Skipping error classes:** Use `class = "error_class"` in expect_error, not just message

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Environment isolation | Manual Sys.setenv/unsetenv | withr::local_envvar() | Automatic cleanup, safer |
| Function mocking | Manual function replacement | local_mocked_bindings() | Scoped to test, testthat 3.x native |
| Database skip | Manual connection check | skip_if_no_test_db() | Already handles config.yml vs env vars |
| Error class testing | Message regex | expect_error(..., class = "...") | More precise, catches rlang::abort classes |

**Key insight:** The existing test infrastructure solves all common testing problems. Follow the patterns in test-db-helpers.R and test-unit-security.R.

## Common Pitfalls

### Pitfall 1: Testing Parser Logic in Isolation
**What goes wrong:** Tests for MIRAI_WORKERS parsing that don't match actual implementation
**Why it happens:** Testing a copy of the logic instead of the actual function
**How to avoid:** Either test the actual function (source it) or document that tests verify the pattern
**Warning signs:** Tests pass but actual implementation has bugs

### Pitfall 2: SQL Injection Tests Too Weak
**What goes wrong:** Tests pass but real SQL injection attacks succeed
**Why it happens:** Only testing obvious patterns like "DROP TABLE"
**How to avoid:** Test various injection patterns:
```r
injection_attempts <- c(
  "id; DROP TABLE logging; --",
  "id' OR '1'='1",
  "id/**/OR/**/1=1",
  "id UNION SELECT * FROM users",
  "'; DELETE FROM logging WHERE '1'='1"
)
for (attempt in injection_attempts) {
  expect_error(validate_logging_column(attempt), class = "invalid_filter_error")
}
```
**Warning signs:** Only 1-2 injection test cases

### Pitfall 3: Integration Tests Without Pagination Data
**What goes wrong:** Pagination tests skip because not enough data
**Why it happens:** Test database has fewer rows than page_size
**How to avoid:** Use small page_size (2-5) or explicitly insert test data
**Warning signs:** Tests always skipped with "Not enough data"

### Pitfall 4: Documentation Without Version
**What goes wrong:** DEPLOYMENT.md becomes outdated, readers don't know currency
**Why it happens:** No date or version marker in document
**How to avoid:** Include "Last updated: YYYY-MM-DD" and version references
**Warning signs:** Documentation references deprecated env vars or defaults

## Code Examples

Verified patterns from existing codebase:

### SQL Injection Test Pattern
```r
# Source: Based on test-unit-security.R pattern
describe("SQL injection prevention", {
  injection_attempts <- c(
    "id; DROP TABLE logging; --",
    "id' OR '1'='1",
    "id/**/OR/**/1=1",
    "id UNION SELECT * FROM users",
    "'; DELETE FROM logging WHERE '1'='1",
    "status\n-- comment"
  )

  for (attempt in injection_attempts) {
    it(paste("rejects:", substr(attempt, 1, 30), "..."), {
      expect_error(
        validate_logging_column(attempt),
        class = "invalid_filter_error"
      )
    })
  }
})
```

### Environment Variable Parsing Test
```r
# Source: Based on test-unit-analyses-functions.R pattern
describe("MIRAI_WORKERS parsing", {
  it("defaults to 2 when not set", {
    withr::local_envvar(MIRAI_WORKERS = NA)

    result <- parse_mirai_workers()  # Or inline the logic
    expect_equal(result, 2L)
  })

  it("parses valid integer values", {
    withr::local_envvar(MIRAI_WORKERS = "4")

    result <- parse_mirai_workers()
    expect_equal(result, 4L)
  })

  it("bounds values to 1-8 range", {
    withr::local_envvar(MIRAI_WORKERS = "20")
    expect_equal(parse_mirai_workers(), 8L)

    withr::local_envvar(MIRAI_WORKERS = "0")
    expect_equal(parse_mirai_workers(), 1L)

    withr::local_envvar(MIRAI_WORKERS = "-5")
    expect_equal(parse_mirai_workers(), 1L)
  })

  it("handles non-numeric values", {
    withr::local_envvar(MIRAI_WORKERS = "abc")
    expect_equal(parse_mirai_workers(), 2L)  # Default

    withr::local_envvar(MIRAI_WORKERS = "")
    expect_equal(parse_mirai_workers(), 2L)  # Default
  })
})
```

### Query Builder Test
```r
# Source: Based on test-db-helpers.R pattern
describe("build_logging_where_clause", {
  it("handles empty filters", {
    result <- build_logging_where_clause(list())
    expect_equal(result$clause, "1=1")
    expect_equal(result$params, list())
  })

  it("handles single filter", {
    result <- build_logging_where_clause(list(status = 404))
    expect_match(result$clause, "status = \\?")
    expect_equal(result$params, list(404L))
  })

  it("handles timestamp range", {
    result <- build_logging_where_clause(list(
      timestamp_from = "2026-01-01 00:00:00",
      timestamp_to = "2026-01-31 23:59:59"
    ))
    expect_match(result$clause, "timestamp >= \\?")
    expect_match(result$clause, "timestamp <= \\?")
    expect_equal(length(result$params), 2)
  })

  it("handles path prefix with LIKE", {
    result <- build_logging_where_clause(list(path_prefix = "/api/logs"))
    expect_match(result$clause, "path LIKE \\?")
    expect_equal(result$params[[1]], "/api/logs%")
  })
})
```

### Deployment Documentation Structure
```markdown
# Deployment Guide

**Last Updated:** 2026-02-XX
**Applies to:** SysNDD API v2.x

## Memory Configuration

### MIRAI_WORKERS

Controls the number of background worker processes for async operations.

| Environment | Default | Range |
|-------------|---------|-------|
| Production | 2 | 1-8 |
| Development | 1 | 1-8 |

### Server Profiles

**Small (4-8GB RAM):**
```yaml
MIRAI_WORKERS: 1
DB_POOL_SIZE: 3
```
Expected memory: ~2-3GB peak

**Medium (16GB RAM):**
```yaml
MIRAI_WORKERS: 2
DB_POOL_SIZE: 5
```
Expected memory: ~4-6GB peak

**Large (32GB+ RAM):**
```yaml
MIRAI_WORKERS: 4
DB_POOL_SIZE: 10
```
Expected memory: ~8-12GB peak
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual worker count | MIRAI_WORKERS env var | Phase 69 | Configurable per deployment |
| Undocumented deployment | docs/DEPLOYMENT.md | Phase 72 | Operators have reference |
| Limited test coverage | Comprehensive unit tests | Phase 72 | Higher confidence |

**Deprecated/outdated:**
- None - all patterns are current testthat 3.x

## Open Questions

Things that couldn't be fully resolved:

1. **Test file naming for cross-phase tests**
   - What we know: Each test file typically tests one source file
   - What's unclear: Should MIRAI_WORKERS tests go in test-unit-mirai-workers.R or test-unit-startup.R?
   - Recommendation: Create test-unit-mirai-workers.R since the logic is self-contained

2. **Integration test database state**
   - What we know: test database has some logging data
   - What's unclear: How many rows exist for pagination testing?
   - Recommendation: Use page_size=2 to ensure pagination works with minimal data

3. **DEPLOYMENT.md vs README.md scope**
   - What we know: README.md exists at project root
   - What's unclear: Should deployment info go there or separate file?
   - Recommendation: Separate docs/DEPLOYMENT.md for operator-focused content

## Sources

### Primary (HIGH confidence)
- api/tests/testthat/test-db-helpers.R - Comprehensive mocking and testing patterns
- api/tests/testthat/test-unit-security.R - describe/it structure for unit tests
- api/tests/testthat/test-integration-pagination.R - Integration test with skip patterns
- api/tests/testthat/helper-db.R - Database testing utilities
- api/tests/testthat/helper-paths.R - source_api_file() utility
- api/tests/testthat/setup.R - Test environment setup
- .planning/phases/69-configurable-workers/69-01-PLAN.md - MIRAI_WORKERS implementation
- .planning/phases/71-viewlogs-database-filtering/71-02-PLAN.md - logging-repository.R specification

### Secondary (MEDIUM confidence)
- api/tests/testthat/test-unit-analyses-functions.R - Environment variable testing pattern
- CLAUDE.md - Current structure for memory configuration section

### Tertiary (LOW confidence)
- None - all findings verified with primary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using existing test infrastructure exactly
- Architecture: HIGH - Following established test file patterns
- Pitfalls: HIGH - Based on observed patterns in existing test suite

**Research date:** 2026-02-03
**Valid until:** Indefinite (stable test patterns)

## Codebase Analysis Summary

### Current Test Infrastructure

**44 test files** in api/tests/testthat/ covering:
- Unit tests: test-unit-*.R files
- Integration tests: test-integration-*.R files
- External API tests: test-external-*.R files
- Database tests: test-db-*.R files

**Key helpers available:**
- `source_api_file()` - Source files with robust path resolution
- `skip_if_no_test_db()` - Skip if test database unavailable
- `skip_if_api_not_running()` - Skip if API not running locally
- `local_mocked_bindings()` - Mock functions in test scope
- `with_test_db_transaction()` - Run code in auto-rollback transaction

### Functions to Test (from Phase Plans)

**Phase 69 (MIRAI_WORKERS):**
- Worker count parsing: `as.integer(Sys.getenv("MIRAI_WORKERS", "2"))`
- NA handling: `if (is.na(worker_count)) worker_count <- 2L`
- Bounds validation: `max(1L, min(worker_count, 8L))`
- Note: These are inline in start_sysndd_api.R, test the pattern

**Phase 71 (logging-repository.R):**
- `LOGGING_ALLOWED_COLUMNS` - Constant, test via validate function
- `LOGGING_ALLOWED_SORT_COLUMNS` - Constant, test via validate function
- `validate_logging_column()` - Whitelist validation, throws invalid_filter_error
- `validate_sort_direction()` - ASC/DESC validation
- `build_logging_where_clause()` - Parameterized WHERE builder
- `build_logging_order_clause()` - Validated ORDER BY builder

### Documentation Targets

**docs/DEPLOYMENT.md (NEW):**
- MIRAI_WORKERS configuration
- Server profiles (small/medium/large)
- Memory tuning guidance

**CLAUDE.md (UPDATE):**
- Add Memory Configuration section
- Document worker tuning
- Reference DEPLOYMENT.md for details

### Requirement Coverage

| Requirement | Test File | Test Type |
|-------------|-----------|-----------|
| TST-01: MIRAI_WORKERS parsing | test-unit-mirai-workers.R | Unit |
| TST-02: Column validation | test-unit-logging-repository.R | Unit |
| TST-03: ORDER BY building | test-unit-logging-repository.R | Unit |
| TST-04: WHERE clause building | test-unit-logging-repository.R | Unit |
| TST-05: SQL injection rejection | test-unit-logging-repository.R | Unit |
| TST-06: Unparseable filter syntax | test-unit-logging-repository.R | Unit |
| TST-07: Database query execution | test-integration-logs-pagination.R | Integration |
| TST-08: Pagination different pages | test-integration-logs-pagination.R | Integration |
| TST-09: Existing tests pass | make test-api | CI |
| DOC-01: DEPLOYMENT.md | docs/DEPLOYMENT.md | Documentation |
| DOC-02: Server profiles | docs/DEPLOYMENT.md | Documentation |
| DOC-03: CLAUDE.md update | CLAUDE.md | Documentation |
