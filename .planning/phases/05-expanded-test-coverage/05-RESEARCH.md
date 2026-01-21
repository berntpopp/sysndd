# Phase 5: Expanded Test Coverage - Research

**Researched:** 2026-01-21
**Domain:** R testing with testthat 3e and covr coverage reporting
**Confidence:** HIGH

## Summary

This phase focuses on achieving comprehensive test coverage (70%+ for functions/*.R) using the existing testthat 3e infrastructure from Phase 2. The research confirms that testthat 3.3.2 (released January 11, 2026) with covr provides robust coverage reporting, and the 70% target is industry-standard for business logic. The key challenge is balancing comprehensive coverage with test suite performance (targeting <2 minutes total execution time).

The standard approach involves:
1. Organizing tests following testthat 3e conventions with 1:1 file mapping (test-functionname.R matches functions/functionname.R)
2. Using covr's `package_coverage()` for measurement with `.covrignore` for exclusions
3. Leveraging dittodb for database mocking (already installed in Phase 2)
4. Implementing conditional test skipping for slow integration tests
5. Enabling parallel execution via TESTTHAT_CPUS environment variable

**Primary recommendation:** Follow testthat's 1:1 file mapping convention, prioritize business logic coverage (entity helpers, data transformations, analysis functions), use dittodb for database mocking, and implement environment-variable-based skipping for slow tests to maintain performance budget.

## Standard Stack

The established libraries/tools for R test coverage:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| testthat | 3.3.2 | Unit and integration testing framework | Official R testing framework, 3rd edition (3e) with parallel support |
| covr | 3.6.4+ | Code coverage measurement and reporting | Official R coverage tool, integrates with testthat, generates HTML reports |
| dittodb | 0.1.7+ | Database mocking for DBI connections | Standard for testing database-dependent code without real DB |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| withr | 2.5.0+ | Temporary state changes with cleanup | Managing test state, temporary options/env vars |
| mockery | (superseded) | Function mocking | AVOID - superseded by testthat::local_mocked_bindings() |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| dittodb | testthat::local_mocked_bindings() | dittodb specialized for DBI, handles fixtures; local_mocked_bindings() more general but requires manual setup |
| testthat 3e | testthat 2e | testthat 3e required for parallel execution, modern conventions |
| covr | manual coverage tracking | covr provides industry-standard HTML reports, CI integration |

**Installation:**
```bash
# Already installed in Phase 2 via renv
cd api/
R -e "renv::status()"  # Verify testthat, covr, dittodb present
```

## Architecture Patterns

### Recommended Project Structure
```
api/
├── functions/
│   ├── helper-functions.R       # Pure business logic - HIGH priority
│   ├── database-functions.R     # DB-dependent - use dittodb mocking
│   ├── endpoint-functions.R     # API logic - integration tests
│   └── ...
└── tests/
    └── testthat/
        ├── setup.R              # Global test setup (loads libraries)
        ├── helper-*.R           # Shared test utilities (auto-loaded)
        ├── fixtures/            # httptest2 + dittodb fixtures
        │   ├── sysndd_test/     # dittodb DB fixtures by table
        │   └── pubmed.ropensci.org/  # httptest2 API fixtures
        ├── test-helper-functions.R      # 1:1 mapping to functions/
        ├── test-database-functions.R    # DB tests with dittodb
        ├── test-integration-entity.R    # Endpoint integration tests
        └── ...
```

### Pattern 1: 1:1 Test File Mapping (Recommended)
**What:** Each source file in `functions/` has a corresponding test file in `tests/testthat/`
**When to use:** Default approach for all function files
**Example:**
```r
# functions/helper-functions.R → tests/testthat/test-helper-functions.R
# functions/database-functions.R → tests/testthat/test-database-functions.R

# Benefits:
# - Supported by devtools::test_active_file() and test_coverage_active_file()
# - Clear navigation between source and tests
# - Official testthat recommendation
```
**Source:** [R Packages (2e) - Testing Design](https://r-pkgs.org/testing-design.html)

### Pattern 2: Database Mocking with dittodb
**What:** Use dittodb to intercept DBI connections and return fixture data
**When to use:** Testing functions that query MariaDB via Pool connections
**Example:**
```r
# Source: https://docs.ropensci.org/dittodb/reference/mockdb.html
library(dittodb)

test_that("get_entities retrieves entity list from database", {
  with_mock_db({
    # Connection MUST be inside with_mock_db()
    pool <- get_pool_connection()  # Intercepted by dittodb

    result <- get_entities(pool, status = "approved")

    expect_true(is.data.frame(result))
    expect_true("entity_id" %in% colnames(result))
  })
})

# Fixtures stored in tests/testthat/sysndd_test/
# Created via start_db_capturing() / stop_db_capturing()
```

### Pattern 3: Conditional Test Skipping for Performance
**What:** Skip slow integration tests by default, enable via environment variable
**When to use:** Tests exceeding ~5 seconds (API calls, complex DB queries)
**Example:**
```r
# Source: https://testthat.r-lib.org/articles/skipping.html
test_that("PubMed API enriches publication metadata", {
  skip_if_not(Sys.getenv("RUN_SLOW_TESTS") == "true",
              "Slow test - set RUN_SLOW_TESTS=true to run")

  # Expensive API call test here
})

# Usage:
# Fast run:  make test-api          (skips slow tests)
# Full run:  make test-api-full     (RUN_SLOW_TESTS=true)
```

### Pattern 4: Parallel Test Execution
**What:** Run test files in parallel across multiple cores
**When to use:** After ensuring test isolation (no shared state between files)
**Example:**
```r
# Configuration in tests/testthat/setup.R or .Renviron
withr::local_options(
  list(testthat.edition = 3),
  .local_envir = teardown_env()
)

# .Renviron configuration:
TESTTHAT_CPUS=4

# Overhead: ~50ms startup + ~80ms cleanup per subprocess
# Benefit: Significant for test suites >10s serial execution
# testthat itself: 10s serial → 8s parallel (20% improvement)
```
**Source:** [testthat Parallel Testing](https://testthat.r-lib.org/articles/parallel.html)

### Anti-Patterns to Avoid
- **Don't use mockery package:** Superseded by `testthat::local_mocked_bindings()` as of 2026
- **Don't put helper logic in test files:** Use `tests/testthat/helper-*.R` files instead
- **Don't create database connections outside `with_mock_db()`:** dittodb cannot intercept them
- **Don't include `library()` calls in test files:** Already loaded in `setup.R`, use `::` notation
- **Don't source functions manually:** Tests in packages use devtools::load_all() workflow

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Database mocking | Custom DB stub functions | dittodb with fixtures | Handles DBI protocol, fixture recording/playback, connection pooling edge cases |
| Function mocking | Manual replacement functions | testthat::local_mocked_bindings() | Automatic cleanup, namespace-aware, prevents state leakage |
| Test data cleanup | Manual teardown functions | withr::defer() / withr::local_*() | Guaranteed cleanup even on error, composable |
| Coverage threshold checking | Custom coverage parser | covr::percent_coverage() with conditional | Standard format, integrates with CI |
| Temporary files in tests | Manual tempdir() management | withr::local_tempfile() | Auto-cleanup, no orphaned files |
| Environment variable testing | Manual Sys.setenv/unsetenv | withr::local_envvar() | Restores original state automatically |

**Key insight:** testthat 3e and covr ecosystem has mature tooling for common testing challenges. Hand-rolled solutions miss edge cases (cleanup on error, namespace isolation, fixture management) that took years to discover in production packages.

## Common Pitfalls

### Pitfall 1: Recursive Coverage Testing
**What goes wrong:** Including coverage tests within testthat suite creates infinite recursion (covr installs package → runs tests → coverage test tries to install package again)
**Why it happens:** Developers want coverage checks to fail tests if below threshold
**How to avoid:** Run coverage checks separately via Makefile target, not as testthat test. Use environment variable guard if necessary:
```r
# BAD: In test file
test_that("coverage meets threshold", {
  cov <- covr::package_coverage()  # Infinite recursion!
})

# GOOD: In Makefile
coverage:
	Rscript -e "cov <- covr::package_coverage(); \
	            pct <- covr::percent_coverage(cov); \
	            if (pct < 70) warning('Coverage ', pct, '% below 70%')"
```
**Warning signs:** Test hangs during package installation, multiple renv locks, temp directory filling up
**Source:** [covr Issue #248](https://github.com/r-lib/covr/issues/248)

### Pitfall 2: Test File State Leakage in Parallel Mode
**What goes wrong:** Tests pass in serial but fail randomly in parallel execution
**Why it happens:** Tests modify global state (options, environment variables, loaded packages) without cleanup
**How to avoid:** Use `withr::local_*()` functions for ALL state changes, never raw `options()` or `Sys.setenv()`:
```r
# BAD: State persists to next test file
test_that("custom option affects behavior", {
  options(mypackage.verbose = TRUE)
  # ... test code ...
})

# GOOD: State automatically restored
test_that("custom option affects behavior", {
  withr::local_options(mypackage.verbose = TRUE)
  # ... test code ...
})
```
**Warning signs:** Intermittent test failures, failures only with TESTTHAT_CPUS>1, different results on reruns
**Source:** [testthat Parallel Testing Vignette](https://testthat.r-lib.org/articles/parallel.html)

### Pitfall 3: Database Connections Outside Mock Scope
**What goes wrong:** dittodb cannot intercept connection, test tries to connect to real database, fails with connection error
**Why it happens:** Creating pool/connection before entering `with_mock_db()` block
**How to avoid:** Always create connections INSIDE `with_mock_db()`, even if using same connection for multiple tests:
```r
# BAD: Connection created outside mock
pool <- get_pool_connection()  # Real connection attempt!
test_that("query works", {
  with_mock_db({
    result <- DBI::dbGetQuery(pool, "SELECT * FROM entities")  # Fails
  })
})

# GOOD: Connection inside mock scope
test_that("query works", {
  with_mock_db({
    pool <- get_pool_connection()  # Intercepted by dittodb
    result <- DBI::dbGetQuery(pool, "SELECT * FROM entities")  # Works
  })
})
```
**Warning signs:** "Could not connect to database" errors in tests, tests requiring dev database running
**Source:** [dittodb Getting Started](https://cran.r-project.org/web/packages/dittodb/vignettes/dittodb.html)

### Pitfall 4: Ignoring Parallel Execution Overhead
**What goes wrong:** Enabling parallel tests makes suite slower instead of faster
**Why it happens:** Overhead (~130ms per subprocess) exceeds time saved for fast test suites
**How to avoid:** Only enable parallel execution if total test time >10 seconds. Measure before/after:
```bash
# Measure serial execution
time Rscript -e "testthat::test_dir('tests/testthat')"

# Measure parallel execution (4 cores)
TESTTHAT_CPUS=4 time Rscript -e "testthat::test_dir('tests/testthat')"

# Enable only if parallel < 0.8 * serial
```
**Warning signs:** Test suite gets slower after enabling parallel mode, many small test files (<1s each)
**Source:** [testthat Parallel Testing Performance](https://testthat.r-lib.org/articles/parallel.html)

### Pitfall 5: Excluding Tests from Coverage Instead of Running
**What goes wrong:** Adding test files to `.covrignore` thinking it prevents them from running
**Why it happens:** Confusion between coverage exclusion and test execution
**How to avoid:** `.covrignore` only excludes files from coverage calculation, not test execution. Use `skip_if()` to prevent running:
```r
# .covrignore excludes from coverage metrics, NOT execution
# tests/testthat/test-slow-integration.R still RUNS

# To prevent execution:
test_that("slow integration test", {
  skip_if_not(Sys.getenv("RUN_SLOW_TESTS") == "true")
  # ... test code ...
})
```
**Warning signs:** Slow tests still running despite being in `.covrignore`, confusion about execution time
**Source:** [covr Issues](https://github.com/r-lib/covr/issues)

## Code Examples

Verified patterns from official sources:

### Coverage Report Generation (Console + HTML)
```r
# Source: https://covr.r-lib.org/
library(covr)

# Calculate coverage (excludes files in .covrignore)
cov <- package_coverage()

# Console output - overall percentage
percent_coverage(cov)
# [1] 73.5

# Console output - file-level breakdown
as.data.frame(cov)
#   filename                  functions lines
#   functions/helper.R       85.0       82.5
#   functions/database.R     68.2       65.0

# HTML report (saved to coverage/ directory)
report(cov, file = "coverage/coverage-report.html", browse = FALSE)

# Identify uncovered lines (opens RStudio markers pane)
zero_coverage(cov)
```

### Conditional Slow Test Skipping
```r
# Source: https://testthat.r-lib.org/articles/skipping.html
# tests/testthat/helper-skip.R
skip_if_not_slow_tests <- function() {
  skip_if_not(
    Sys.getenv("RUN_SLOW_TESTS") == "true",
    "Slow test - set RUN_SLOW_TESTS=true to run"
  )
}

# tests/testthat/test-integration-pubmed.R
test_that("PubMed API enriches publications", {
  skip_if_not_slow_tests()

  # This only runs when RUN_SLOW_TESTS=true
  result <- enrich_publication_from_pubmed(pmid = "12345678")
  expect_true(!is.null(result$title))
})
```

### Database Mocking with dittodb
```r
# Source: https://docs.ropensci.org/dittodb/reference/mockdb.html
library(dittodb)

test_that("get_entities_by_status filters approved entities", {
  with_mock_db({
    # Connection created INSIDE mock scope
    pool <- get_pool_connection()

    # Query uses fixtures from tests/testthat/sysndd_test/
    entities <- get_entities_by_status(pool, status = "approved")

    expect_true(is.data.frame(entities))
    expect_true(all(entities$status == "approved"))

    pool::poolClose(pool)
  })
})

# Recording fixtures (one-time setup):
# start_db_capturing()
# pool <- get_pool_connection()  # Real DB
# get_entities_by_status(pool, status = "approved")
# stop_db_capturing()
# → Saves to tests/testthat/sysndd_test/entities.R
```

### Test Suite Performance Monitoring
```r
# Source: https://testthat.r-lib.org/
# Use SlowReporter to identify slow tests
testthat::test_dir(
  "tests/testthat",
  reporter = SlowReporter(threshold = 1.0)  # Report tests >1s
)

# Output shows which tests exceed threshold:
# ✓ test-helper-functions.R (0.2s)
# ✓ test-database-functions.R (0.8s)
# ⚠ test-integration-entity.R (3.5s) SLOW
```

### Makefile Integration for Coverage
```makefile
# Source: Project Makefile pattern + covr documentation
coverage: check-r
	@printf "$(CYAN)==> Calculating test coverage...$(RESET)\n"
	@cd api && Rscript -e " \
		library(covr); \
		cov <- package_coverage(); \
		pct <- percent_coverage(cov); \
		cat('Overall coverage: ', pct, '%\n'); \
		print(as.data.frame(cov)); \
		if (pct < 70) { \
			warning('Coverage ', pct, '% below 70% threshold'); \
		}; \
		dir.create('coverage', showWarnings = FALSE, recursive = TRUE); \
		report(cov, file = 'coverage/coverage-report.html', browse = FALSE); \
		cat('HTML report: coverage/coverage-report.html\n'); \
	" && printf "$(GREEN)✓ coverage complete$(RESET)\n"

test-api-full: check-r
	@printf "$(CYAN)==> Running full test suite (including slow tests)...$(RESET)\n"
	@cd api && RUN_SLOW_TESTS=true Rscript -e "testthat::test_dir('tests/testthat')"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| testthat 2e with context() | testthat 3e with parallel support | testthat 3.0.0 (Oct 2020) | context() deprecated; parallel execution requires 3e opt-in |
| with_mock() for mocking | local_mocked_bindings() | testthat 3.2.0 (2023) | with_mock() abused R internals; new approach more stable |
| mockery package | testthat::local_mocked_bindings() | 2023-2024 | mockery superseded; testthat has built-in mocking now |
| Manual coverage thresholds | covr with CI integration | Ongoing | covr standardized format used by Codecov/Coveralls |

**Deprecated/outdated:**
- **testthat::context()**: Deprecated in 3e, use descriptive test_that() names instead
- **testthat::with_mock()**: Defunct, replaced by local_mocked_bindings()
- **testthat::local_mock()**: Defunct, replaced by local_mocked_bindings()
- **mockery package**: Superseded, use testthat native mocking

**Current best practice (2026):**
- testthat 3.3.2 (released January 11, 2026) with 3e edition enabled
- covr 3.6.4+ for coverage (last major update November 9, 2025)
- dittodb for database mocking (still recommended approach)
- Environment-variable-based conditional skipping for slow tests

## Open Questions

Things that couldn't be fully resolved:

1. **Pool Connection Mocking with dittodb**
   - What we know: dittodb works with standard DBI connections via `dbConnect()`
   - What's unclear: Whether dittodb correctly intercepts Pool package connections (`pool::dbPool()`)
   - Recommendation: Test empirically during implementation; may need `local_mocked_bindings()` for Pool-specific functions if dittodb doesn't intercept properly

2. **Test Timeout Enforcement**
   - What we know: testthat does not have built-in timeout support (GitHub issue #242 still open)
   - What's unclear: Best approach to enforce 30s/2min budgets programmatically
   - Recommendation: Use SlowReporter to identify violations, enforce via CI timeout, or wrap expensive operations with R.utils::withTimeout()

3. **Coverage of Plumber Endpoint Files**
   - What we know: Phase scope is `functions/*.R`, not `endpoints/*.R`
   - What's unclear: Whether integration tests of endpoints count toward coverage target
   - Recommendation: Follow phase boundary - only `functions/*.R` count toward 70%; endpoint tests are integration validation, not coverage target

## Sources

### Primary (HIGH confidence)
- [testthat 3.3.2 CRAN](https://cran.r-project.org/web/packages/testthat/testthat.pdf) - Latest package documentation (January 11, 2026)
- [R Packages (2e) - Testing Design](https://r-pkgs.org/testing-design.html) - Authoritative testing best practices
- [R Packages (2e) - Testing Basics](https://r-pkgs.org/testing-basics.html) - testthat fundamentals and conventions
- [testthat Skipping Tests](https://testthat.r-lib.org/articles/skipping.html) - Official skip functions documentation
- [testthat Mocking](https://testthat.r-lib.org/articles/mocking.html) - Official mocking guide (local_mocked_bindings)
- [covr Package Documentation](https://covr.r-lib.org/) - Official coverage reporting guide
- [dittodb MockDB Reference](https://docs.ropensci.org/dittodb/reference/mockdb.html) - Database mocking documentation

### Secondary (MEDIUM confidence)
- [testthat Parallel Testing](https://testthat.r-lib.org/articles/parallel.html) - Parallel execution guide (via WebSearch, domain blocked)
- [dittodb Getting Started](https://cran.r-project.org/web/packages/dittodb/vignettes/dittodb.html) - Database mocking tutorial
- [Coverage Target Best Practices](https://www.bullseye.com/minimum.html) - Industry standards for coverage thresholds
- [Qt Quality Assurance Coverage](https://www.qt.io/quality-assurance/blog/is-70-80-90-or-100-code-coverage-good-enough) - 70-80% target rationale
- [R-hub Mocking Blog](https://blog.r-hub.io/2019/10/29/mocking/) - General mocking patterns (2019, pre-local_mocked_bindings)

### Tertiary (LOW confidence)
- WebSearch results on test isolation and performance - Verified against official docs where possible
- GitHub issues for covr and testthat - Inform pitfalls but not authoritative for current best practices

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - testthat 3.3.2 and covr are current as of January 2026, well-documented
- Architecture: HIGH - 1:1 mapping and testthat 3e patterns are official recommendations
- Database mocking: MEDIUM - dittodb well-documented for DBI, Pool interaction needs empirical testing
- Parallel execution: MEDIUM - Official docs exist but performance characteristics project-specific
- Pitfalls: HIGH - Based on official issue trackers and documentation warnings

**Research date:** 2026-01-21
**Valid until:** 2026-04-21 (90 days - testthat and covr are stable, slow-moving packages)
