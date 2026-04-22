# Phase 2: Test Infrastructure Foundation - Research

**Researched:** 2026-01-20
**Domain:** R API testing with testthat, dittodb, and mirai
**Confidence:** HIGH

## Summary

This phase establishes testthat-based testing infrastructure for the SysNDD R Plumber API. The research confirms that testthat 3e (Edition 3) is the current standard for R testing, with specific patterns for API testing involving separation of business logic tests from endpoint tests. The dittodb package provides database mocking through recorded fixtures, eliminating the need for a live database during unit tests. For integration tests, transaction rollback with `withr::defer()` ensures clean state.

The codebase has 16 function files in `api/functions/` containing testable business logic (helpers, database operations, validation) and 21 endpoint files in `api/endpoints/` requiring integration tests. The existing infrastructure (database pooling via `pool`, JWT auth via `jose`, config via `config`) works well with the testing patterns identified.

**Primary recommendation:** Use testthat 3e with dittodb for unit tests (no DB required) and mirai + httr2 for integration tests (real test DB with transaction rollback).

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| testthat | >= 3.0.0 | Unit testing framework | Standard R testing, Edition 3 provides modern features |
| dittodb | 0.1.8 | Database mocking | Records real DB responses as fixtures, RMariaDB support |
| withr | >= 3.0.0 | Cleanup/teardown | `defer()` for connection cleanup, `local_*()` functions |
| httr2 | >= 1.0.0 | HTTP client for API tests | Pipeable API, handles auth, modern httr replacement |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| mirai | >= 2.5.0 | Async background processes | Launch API in background for integration tests |
| jose | (existing) | JWT handling | Create test tokens for auth tests |
| pool | (existing) | DB connection pooling | Reuse in tests with test DB config |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| dittodb | mockery | dittodb is database-specific, mockery is general mocking |
| mirai | callr | mirai has better async patterns, callr is simpler but blocking |
| httr2 | httr | httr2 is modern replacement, httr deprecated |
| httr2 | callthat | callthat experimental, httr2 production-ready |

**Installation:**
```r
# Add to DESCRIPTION Suggests:
# testthat (>= 3.0.0),
# dittodb (>= 0.1.8),
# withr (>= 3.0.0),
# httr2 (>= 1.0.0),
# mirai (>= 2.5.0)

# For manual installation:
install.packages(c("testthat", "dittodb", "withr", "httr2", "mirai"))
```

## Architecture Patterns

### Recommended Project Structure
```
api/
├── tests/
│   └── testthat/
│       ├── setup.R                    # Global test setup (load helpers, skip logic)
│       ├── helper-db.R                # DB connection helpers for tests
│       ├── helper-auth.R              # JWT token generation for tests
│       ├── helper-api.R               # API start/stop for integration tests
│       ├── fixtures/                  # dittodb recorded fixtures
│       │   └── sysndd_test/           # Named after test DB
│       │       ├── SELECT-abc123.R    # Recorded query responses
│       │       └── ...
│       ├── test-unit-helper-functions.R     # Unit tests for helper-functions.R
│       ├── test-unit-database-functions.R   # Unit tests for database-functions.R
│       ├── test-unit-validation.R           # Unit tests for validation logic
│       ├── test-integration-auth.R          # Auth endpoint integration tests
│       └── test-integration-entity.R        # Entity CRUD integration tests
├── testthat.R                         # Test runner entry point
└── DESCRIPTION                        # Package metadata with testthat 3e config
```

### Pattern 1: testthat 3e Test File Structure
**What:** Standard test file organization with descriptive test names
**When to use:** All test files
**Example:**
```r
# Source: R Packages (2e) - Testing basics
# tests/testthat/test-unit-helper-functions.R

test_that("is_valid_email returns TRUE for valid email addresses", {
  expect_true(is_valid_email("test@example.com"))
  expect_true(is_valid_email("user.name@domain.org"))
  expect_true(is_valid_email("USER@CAPS.COM"))
})

test_that("is_valid_email returns FALSE for invalid email addresses", {
  expect_false(is_valid_email("not-an-email"))
  expect_false(is_valid_email("missing@tld"))
  expect_false(is_valid_email("@nodomain.com"))
})

test_that("generate_initials creates correct initials from names", {
  expect_equal(generate_initials("John", "Doe"), "JD")
  expect_equal(generate_initials("Ada", "Lovelace"), "AL")
})
```

### Pattern 2: dittodb Database Mocking for Unit Tests
**What:** Record DB responses and replay without live connection
**When to use:** Unit tests for functions that query database
**Example:**
```r
# Source: dittodb vignette - Getting Started
# tests/testthat/test-unit-database-functions.R

test_that("database query returns expected data with mocked DB", {
  # with_mock_db() intercepts dbConnect and uses fixtures
  with_mock_db({
    # This connection uses fixtures, not real DB
    con <- dbConnect(
      RMariaDB::MariaDB(),
      dbname = "sysndd_test"
    )

    # Queries return pre-recorded responses from fixtures/
    result <- dbGetQuery(con, "SELECT * FROM user WHERE user_id = 1")

    expect_equal(nrow(result), 1)
    expect_equal(result$user_name, "test_curator")

    dbDisconnect(con)
  })
})
```

### Pattern 3: Integration Tests with Real Test DB
**What:** Test against real database with transaction rollback
**When to use:** Integration tests validating full data flow
**Example:**
```r
# Source: withr documentation, tidyverse blog
# tests/testthat/test-integration-entity.R

test_that("entity creation writes to database correctly", {
  skip_if_no_test_db()  # Custom skip helper

  # Start transaction for rollback
  con <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(con))

  DBI::dbBegin(con)
  withr::defer(DBI::dbRollback(con))  # Always rollback, even on error

  # Test entity creation
  entity_data <- list(
    hgnc_id = "HGNC:9999",
    hpo_mode_of_inheritance_term = "HP:0000006",
    disease_ontology_id_version = "OMIM:999999",
    ndd_phenotype = TRUE,
    entry_user_id = 1
  )

  result <- post_db_entity(entity_data)

  expect_equal(result$status, 200)
  expect_true(!is.na(result$entry$entity_id))
})
```

### Pattern 4: API Endpoint Integration Tests with mirai
**What:** Launch API in background, test endpoints via httr2
**When to use:** Full endpoint integration tests
**Example:**
```r
# Source: Testing Plumber APIs blog post
# tests/testthat/test-integration-auth.R

test_that("authenticate endpoint returns JWT for valid credentials", {
  skip_if_no_test_db()

  # Use API started in setup.R
  api_url <- Sys.getenv("TEST_API_URL", "http://127.0.0.1:7779")

  resp <- httr2::request(api_url) |>
    httr2::req_url_path_append("api", "auth", "authenticate") |>
    httr2::req_url_query(user_name = "test_user", password = "test_pass") |>
    httr2::req_perform()

  expect_equal(httr2::resp_status(resp), 200)

  body <- httr2::resp_body_json(resp)
  expect_true(is.character(body))  # JWT string returned
  expect_match(body, "^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$")
})

test_that("authenticate endpoint returns 401 for invalid credentials", {
  skip_if_no_test_db()

  api_url <- Sys.getenv("TEST_API_URL", "http://127.0.0.1:7779")

  resp <- httr2::request(api_url) |>
    httr2::req_url_path_append("api", "auth", "authenticate") |>
    httr2::req_url_query(user_name = "wrong_user", password = "wrong_pass") |>
    httr2::req_error(is_error = function(resp) FALSE) |>  # Don't throw on 4xx
    httr2::req_perform()

  expect_equal(httr2::resp_status(resp), 401)
})
```

### Anti-Patterns to Avoid
- **Testing business logic at API layer:** Don't duplicate unit tests in integration tests
- **Shared mutable state:** Each test should set up and tear down its own state
- **Hard-coded test credentials:** Use helper functions and environment variables
- **Missing transaction rollback:** Always use `withr::defer(dbRollback())` for DB tests
- **Blocking API startup:** Use mirai for non-blocking API launch

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| DB mocking | Manual mock functions | dittodb `with_mock_db()` | Handles connection interception, fixture management |
| Test cleanup | Manual on.exit() | `withr::defer()` | Works across environments, LIFO order, flexible |
| API background | system2() or callr | mirai daemons | Non-blocking, proper async handling |
| HTTP requests | Base R or RCurl | httr2 | Modern API, proper error handling, pipeable |
| Skip conditions | Manual if/return | testthat `skip_if()` | Proper test reporting, skip counts visible |
| Test paths | Manual paste0() | `testthat::test_path()` | Works in interactive and test modes |
| Fixture access | Hardcoded paths | `test_path("fixtures", "file.rds")` | Portable across environments |

**Key insight:** The R testing ecosystem has mature solutions for database mocking (dittodb), state management (withr), and async (mirai). Hand-rolling these leads to bugs around connection cleanup, fixture paths, and race conditions.

## Common Pitfalls

### Pitfall 1: dbConnect Outside with_mock_db()
**What goes wrong:** dittodb cannot intercept connections created before mocking starts
**Why it happens:** Natural to create connection once at file level
**How to avoid:** Always call `dbConnect()` inside `with_mock_db()` block
**Warning signs:** Tests fail with "connection failed" even with fixtures present

### Pitfall 2: Missing Transaction Rollback
**What goes wrong:** Integration tests leave test data in database
**Why it happens:** Forget to add rollback, or error occurs before rollback
**How to avoid:** Use `withr::defer(dbRollback(con))` immediately after `dbBegin()`
**Warning signs:** Tests pass individually but fail when run together

### Pitfall 3: Testing Business Logic in API Tests
**What goes wrong:** Slow test suite, duplicate coverage, unclear failures
**Why it happens:** Seems convenient to test everything through endpoints
**How to avoid:** Unit test business logic separately; API tests verify contract only
**Warning signs:** Integration tests have many assertions about data transformation

### Pitfall 4: Hardcoded Test Database Credentials
**What goes wrong:** Tests fail in CI, security issues if committed
**Why it happens:** Works locally, easy to forget
**How to avoid:** Use config file with `sysndd_db_test` entry or env vars
**Warning signs:** Tests fail with "access denied" in different environments

### Pitfall 5: Global State from setup.R Leaking
**What goes wrong:** Tests become order-dependent
**Why it happens:** setup.R modifies global state without teardown
**How to avoid:** Use `teardown_env()` in setup.R or `withr::local_*()` functions
**Warning signs:** Tests pass in isolation but fail in suite

### Pitfall 6: Skipping Too Many Tests Silently
**What goes wrong:** False confidence - tests "pass" but actually skip
**Why it happens:** `skip_if_no_test_db()` skips all integration tests when DB unavailable
**How to avoid:** Monitor skip counts, ensure CI always has DB available
**Warning signs:** Local runs show many skips, CI shows 100% pass with few tests

## Code Examples

Verified patterns from official sources:

### setup.R for Test Infrastructure
```r
# Source: R Packages (2e) - Testing design
# tests/testthat/setup.R

library(dittodb)
library(withr)
library(httr2)

# Load test helpers
source(test_path("helper-db.R"))
source(test_path("helper-auth.R"))

# Disable interactive features during tests
withr::local_options(
  list(
    testthat.progress.max_fails = 50  # Don't stop early
  ),
  .local_envir = teardown_env()
)

# Check if test database is available
TEST_DB_AVAILABLE <- tryCatch({
  con <- get_test_db_connection()
  DBI::dbDisconnect(con)
  TRUE
}, error = function(e) FALSE)

# Export for skip functions
Sys.setenv(TEST_DB_AVAILABLE = as.character(TEST_DB_AVAILABLE))
```

### helper-db.R for Database Connections
```r
# Source: withr documentation, dittodb vignette
# tests/testthat/helper-db.R

#' Get test database connection
#' @return DBI connection to test database
get_test_db_connection <- function() {
  # Load test config
  test_config <- config::get("sysndd_db_test", file = "config.yml")

  DBI::dbConnect(
    RMariaDB::MariaDB(),
    dbname = test_config$dbname,
    host = test_config$host,
    user = test_config$user,
    password = test_config$password,
    port = test_config$port
  )
}

#' Skip test if test database unavailable
skip_if_no_test_db <- function() {
  if (Sys.getenv("TEST_DB_AVAILABLE") != "TRUE") {
    testthat::skip("Test database not available")
  }
}

#' Run code with test database transaction (auto-rollback)
with_test_db_transaction <- function(code) {
  skip_if_no_test_db()

  con <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(con))

  DBI::dbBegin(con)
  withr::defer(DBI::dbRollback(con))

  # Make connection available to code
  withr::local_options(list(.test_db_con = con))

  force(code)
}
```

### helper-auth.R for JWT Testing
```r
# Source: jose package, existing auth implementation
# tests/testthat/helper-auth.R

#' Generate test JWT token
#' @param user_id User ID for token
#' @param user_role Role for token
#' @param expired If TRUE, creates expired token
#' @return JWT string
create_test_jwt <- function(user_id = 1,
                            user_role = "Curator",
                            expired = FALSE) {
  test_config <- config::get("sysndd_db_test", file = "config.yml")
  key <- charToRaw(test_config$secret)

  exp_time <- if (expired) {
    as.numeric(Sys.time()) - 3600  # Expired 1 hour ago
  } else {
    as.numeric(Sys.time()) + 3600  # Valid for 1 hour
  }

  claim <- jose::jwt_claim(
    user_id = user_id,
    user_name = "test_user",
    email = "test@example.com",
    user_role = user_role,
    iat = as.numeric(Sys.time()),
    exp = exp_time
  )

  jose::jwt_encode_hmac(claim, secret = key)
}
```

### Recording dittodb Fixtures
```r
# Source: dittodb vignette
# Run interactively to record fixtures:

library(dittodb)

# Start recording
start_db_capturing()

# Connect and run queries you want to mock
con <- DBI::dbConnect(
  RMariaDB::MariaDB(),
  dbname = "sysndd_test",
  host = "127.0.0.1",
  # ... credentials
)

# Run the queries to record
user_data <- DBI::dbGetQuery(con, "SELECT * FROM user WHERE user_id = 1")
entity_data <- DBI::dbGetQuery(con, "SELECT * FROM ndd_entity WHERE entity_id = 1")

DBI::dbDisconnect(con)

# Stop recording - fixtures saved to tests/testthat/sysndd_test/
stop_db_capturing()
```

### Makefile Targets for Test Execution
```makefile
# Source: User context decisions
# api/Makefile

.PHONY: test test-unit test-integration

# Run all tests
test:
	Rscript -e "testthat::test_dir('tests/testthat', reporter = 'progress')"

# Run only unit tests (test-unit-*.R files)
test-unit:
	Rscript -e "testthat::test_dir('tests/testthat', filter = 'unit', reporter = 'progress')"

# Run only integration tests (test-integration-*.R files)
test-integration:
	Rscript -e "testthat::test_dir('tests/testthat', filter = 'integration', reporter = 'progress')"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| testthat 2e | testthat 3e | 2020+ | Edition 3 is default, better failure messages |
| httr | httr2 | 2022+ | httr is soft-deprecated, httr2 modern API |
| on.exit() | withr::defer() | 2020+ | More flexible cleanup, works across environments |
| Manual mocking | dittodb fixtures | 2020+ | Standardized DB mocking with recording |
| callr for background | mirai | 2022+ | Better async patterns, non-blocking |

**Deprecated/outdated:**
- `testthat::context()`: Removed in 3e, use descriptive test file names instead
- `testthat::with_mock()`: Use mockery or dittodb instead
- Raw httr: Use httr2 for new code
- `expect_known_*()`: Replaced by snapshot testing

## Open Questions

Things that couldn't be fully resolved:

1. **Test Database Seeding Strategy**
   - What we know: Need base data for integration tests (users, permissions)
   - What's unclear: Whether to use SQL seed scripts or R helper functions
   - Recommendation: Start with SQL seed script for base data, add R helpers for test-specific data as needed

2. **API Background Process Port Conflict**
   - What we know: Integration tests need running API on test port
   - What's unclear: Best port number to avoid conflicts with dev server
   - Recommendation: Use port 7779 for tests (dev uses 7778, prod uses 7777)

3. **Parallel Test Execution**
   - What we know: testthat supports parallel tests, mirai provides parallelism
   - What's unclear: Whether DB transaction isolation works with parallel tests
   - Recommendation: Start with sequential, add parallel for unit tests only after baseline

## Sources

### Primary (HIGH confidence)
- [R Packages (2e) - Testing basics](https://r-pkgs.org/testing-basics.html) - test structure, expectations
- [R Packages (2e) - Testing design](https://r-pkgs.org/testing-design.html) - fixtures, helpers, cleanup
- [testthat documentation](https://testthat.r-lib.org/) - Edition 3 features
- [dittodb vignette](https://cran.r-project.org/web/packages/dittodb/vignettes/dittodb.html) - fixture recording, mocking
- [withr documentation](https://withr.r-lib.org/reference/defer.html) - defer() patterns

### Secondary (MEDIUM confidence)
- [testthat 3.3.0 release blog](https://tidyverse.org/blog/2025/11/testthat-3-3-0/) - Latest features
- [mirai 2.5.0 release blog](https://tidyverse.org/blog/2025/09/mirai-2-5-0/) - Async patterns
- [Testing Plumber APIs blog](https://jakubsobolewski.com/blog/plumber-api/) - API testing patterns
- [Self-cleaning test fixtures blog](https://tidyverse.org/blog/2020/04/self-cleaning-test-fixtures/) - withr patterns

### Tertiary (LOW confidence)
- [callthat GitHub](https://github.com/edgararuiz/callthat) - Alternative API testing (experimental)
- [plumber test source](https://github.com/rstudio/plumber/blob/main/tests/testthat/test-plumber.R) - Internal testing patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - testthat and dittodb are well-documented, actively maintained
- Architecture: HIGH - Patterns from R Packages book and official documentation
- Pitfalls: HIGH - Based on official documentation warnings and established patterns

**Research date:** 2026-01-20
**Valid until:** 2026-04-20 (stable libraries, 90 days)
