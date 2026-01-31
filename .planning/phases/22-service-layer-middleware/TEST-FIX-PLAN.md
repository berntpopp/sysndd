# Test Fix Plan: SysNDD API

## Overview

**Total Failures:** 14 errors, 19 skipped, 4 warnings
**Strategy:** Address root causes by category, then parallel agent execution

## Issue Analysis

### Failed Tests (14)

| Test File | Error | Root Cause |
|-----------|-------|------------|
| `test-database-functions.R:18` | Cannot find api directory | Path resolution fails in Docker/test context |
| `test-db-helpers.R` (10 failures) | Can't find binding for `pool` | `local_mocked_bindings` can't mock global `pool` - it's not a function |

### Skipped Tests (19)

| Test File | Skip Reason | Root Cause |
|-----------|-------------|------------|
| `test-external-ensembl.R` (14) | `useMart` not found | biomaRt not loaded or installed |
| `test-external-hgnc.R` (2) | Empty test, API error | Test incomplete or HGNC API issue |
| `test-unit-file-functions.R` (2) | Requires network access | Correct skip - external dependency |
| `test-unit-security.R` (1) | `{sysndd}` not installed | Package not installed in container |

### Warnings (4)

| Test File | Warning | Root Cause |
|-----------|---------|------------|
| `test-external-pubmed.R` | Cannot open `functions/db-helpers.R` | Incorrect relative path |
| `test-external-pubtator.R` | Cannot open `functions/db-helpers.R` | Incorrect relative path |
| `test-integration-entity.R` | Cannot open `/mnt/c/development/...` | Hardcoded Windows path |
| `test-unit-helper-functions.R` | `prepend()` deprecated | purrr API change |

## Strategic Decisions

### 1. Path Resolution - Use `test_path()` Consistently

**Decision:** All test files must use testthat's `test_path()` for fixture files and proper path detection for source files.

**Rationale:**
- [test_path() handles directory variations](https://testthat.r-lib.org/reference/test_path.html) (interactive, devtools::test(), R CMD check)
- Hardcoded paths break across environments (Docker, CI, Windows/Linux)
- [R-hub best practices](https://blog.r-hub.io/2020/11/18/testthat-utility-belt/) recommend test_path() for all test files

**Pattern:**
```r
# Instead of:
source("/mnt/c/development/sysndd/api/functions/helper-functions.R")

# Use:
api_dir <- if (file.exists("functions")) {
  "."
} else if (file.exists("../../functions")) {
  "../.."
} else {
  test_path("..", "..")
}
source(file.path(api_dir, "functions", "helper-functions.R"))
```

### 2. Global Pool Mocking - Use Dependency Injection

**Decision:** Refactor `db-helpers.R` to accept `pool` as parameter with default global fallback.

**Rationale:**
- [`local_mocked_bindings`](https://testthat.r-lib.org/reference/local_mocked_bindings.html) only mocks functions, not variables
- [Clean R Tests with Dependency Wrapping](https://www.r-bloggers.com/2025/09/clean-r-tests-with-local_mocked_bindings-and-dependency-wrapping/) recommends wrapping dependencies
- Dependency injection enables testability without breaking existing code

**Pattern:**
```r
# Before:
db_execute_query <- function(sql, params = list()) {
  result <- DBI::dbSendQuery(pool, sql)  # Uses global pool
  ...
}

# After:
db_execute_query <- function(sql, params = list(), conn = NULL) {
  # Use provided connection or fallback to global pool
  use_conn <- conn %||% pool
  result <- DBI::dbSendQuery(use_conn, sql)
  ...
}
```

### 3. External API Tests - Use Proper Skip Conditions

**Decision:** External tests should skip gracefully with informative messages.

**Rationale:**
- External APIs (Ensembl, HGNC, PubMed) are unreliable in CI/Docker
- [testthat 3.3.0](https://tidyverse.org/blog/2025/11/testthat-3-3-0/) recommends `skip_on_cran()` for external tests
- Tests should document why they skip

**Pattern:**
```r
test_that("API returns data", {
  skip_if_not_installed("biomaRt")
  skip_if_offline()
  skip_on_cran()

  tryCatch({
    result <- call_api()
  }, error = function(e) {
    skip(paste("API unavailable:", e$message))
  })
})
```

### 4. Deprecated Functions - Update to Modern APIs

**Decision:** Replace deprecated purrr functions with current alternatives.

**Rationale:**
- `purrr::prepend()` deprecated in 1.0.0, use `append(after = 0)` instead
- Keeps codebase current with tidyverse evolution

## Execution Plan

### Wave 1: Infrastructure Fixes (Single Agent)

**Agent:** Fix core test infrastructure issues

**Tasks:**
1. Create `tests/testthat/helper-paths.R` with robust path resolution utility
2. Refactor `db-helpers.R` to accept optional connection parameter
3. Update `test-db-helpers.R` mocking strategy

**Files to modify:**
- `api/functions/db-helpers.R`
- `api/tests/testthat/helper-paths.R` (CREATE)
- `api/tests/testthat/test-db-helpers.R`

### Wave 2: Path Resolution Fixes (Parallel - 4 Agents)

**Agent 1:** Fix database-related test paths
- `test-database-functions.R`
- `test-db-helpers.R`

**Agent 2:** Fix external API test paths
- `test-external-pubmed.R`
- `test-external-pubtator.R`
- `test-external-ensembl.R`
- `test-external-hgnc.R`

**Agent 3:** Fix integration test paths
- `test-integration-entity.R`
- `test-integration-auth.R`

**Agent 4:** Fix unit test paths and deprecations
- `test-unit-helper-functions.R` (fix prepend deprecation)
- `test-unit-security.R`

### Wave 3: Verification (Single Agent)

**Tasks:**
1. Run full test suite
2. Verify issue count reduction
3. Document any remaining skips
4. Commit all changes

## File Changes Summary

| File | Action | Wave |
|------|--------|------|
| `api/functions/db-helpers.R` | MODIFY - Add conn parameter | 1 |
| `api/tests/testthat/helper-paths.R` | CREATE - Path resolution utility | 1 |
| `api/tests/testthat/test-db-helpers.R` | MODIFY - Update mocking strategy | 1 |
| `api/tests/testthat/test-database-functions.R` | MODIFY - Fix path resolution | 2 |
| `api/tests/testthat/test-external-*.R` | MODIFY - Fix paths, improve skips | 2 |
| `api/tests/testthat/test-integration-*.R` | MODIFY - Remove hardcoded paths | 2 |
| `api/tests/testthat/test-unit-helper-functions.R` | MODIFY - Fix prepend() usage | 2 |
| `api/tests/testthat/test-unit-security.R` | MODIFY - Improve skip message | 2 |

## Success Criteria

- [ ] Zero test errors (down from 14)
- [ ] Skips only for legitimate external dependencies
- [ ] No warnings about deprecated functions
- [ ] All paths use portable resolution (no hardcoded absolute paths)
- [ ] Tests pass both locally and in Docker container

## Detailed Fixes

### Fix 1: Create helper-paths.R

```r
# tests/testthat/helper-paths.R
# Robust path resolution for tests

#' Get the API directory path
#'
#' Works in multiple contexts:
#' - Interactive R session in api/ directory
#' - testthat::test_dir() from api/ directory
#' - Running tests from tests/testthat/ directory
#' - Docker container execution
#'
#' @return Absolute path to api directory
get_api_dir <- function() {
  # Check multiple possible locations
  candidates <- c(
    getwd(),                              # Current directory IS api/
    file.path(getwd(), ".."),             # Parent is api/ (from tests/)
    file.path(getwd(), "..", ".."),       # Grandparent is api/ (from tests/testthat/)
    "/app"                                 # Docker container path
  )

  for (dir in candidates) {
    if (file.exists(file.path(dir, "functions", "db-helpers.R"))) {
      return(normalizePath(dir))
    }
  }

  stop(
    "Cannot find api directory. Tried:\n",
    paste("  -", candidates, collapse = "\n"),
    "\n\nEnsure tests are run from api/ directory or Docker container."
  )
}

#' Source an API file with robust path resolution
#'
#' @param relative_path Path relative to api/ directory (e.g., "functions/db-helpers.R")
#' @param local Whether to source into local environment
source_api_file <- function(relative_path, local = TRUE) {
  full_path <- file.path(get_api_dir(), relative_path)
  if (!file.exists(full_path)) {
    stop("File not found: ", full_path)
  }
  source(full_path, local = local)
}
```

### Fix 2: Refactor db-helpers.R for Dependency Injection

```r
# Current signature:
db_execute_query <- function(sql, params = list())

# New signature:
db_execute_query <- function(sql, params = list(), conn = NULL) {
  # Use provided connection or fallback to global pool
  use_conn <- if (is.null(conn)) pool else conn

  # ... rest of function unchanged, but use 'use_conn' instead of 'pool'
}
```

### Fix 3: Update test-db-helpers.R Mocking

```r
# Instead of trying to mock global 'pool':
local_mocked_bindings(
  pool = list(),  # This fails - pool is not a function
  .package = "base"
)

# Create a mock connection and pass it:
mock_conn <- list(class = "MockConnection")

# Mock only DBI functions (these ARE functions)
local_mocked_bindings(
  dbSendQuery = function(conn, sql) mock_result,
  dbBind = function(result, params) invisible(NULL),
  dbFetch = function(result) mock_data,
  dbClearResult = function(result) invisible(NULL),
  .package = "DBI"
)

# Call with explicit connection
result <- db_execute_query("SELECT * FROM test", list(1), conn = mock_conn)
```

## Sources

- [testthat test_path()](https://testthat.r-lib.org/reference/test_path.html)
- [testthat local_mocked_bindings()](https://testthat.r-lib.org/reference/local_mocked_bindings.html)
- [testthat 3.3.0 Release Notes](https://tidyverse.org/blog/2025/11/testthat-3-3-0/)
- [Clean R Tests with Dependency Wrapping](https://www.r-bloggers.com/2025/09/clean-r-tests-with-local_mocked_bindings-and-dependency-wrapping/)
- [R-hub Helper Files Best Practices](https://blog.r-hub.io/2020/11/18/testthat-utility-belt/)
- [Mocking in R - R-hub Blog](https://blog.r-hub.io/2024/03/21/mocking-new-take/)
