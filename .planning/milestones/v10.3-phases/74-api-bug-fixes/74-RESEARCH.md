# Phase 74: API Bug Fixes - Research

**Researched:** 2026-02-05
**Domain:** R/Plumber REST API bug fixes, testthat integration testing, dplyr/dbplyr edge cases
**Confidence:** HIGH

## Summary

This phase fixes three independent 500 errors in the SysNDD API: (1) direct-approval entity creation crashes, (2) Panels page column alias mismatch, and (3) clustering endpoints crash on empty STRING interaction results. Research covers REST API response conventions, R/dplyr edge case handling, Plumber testing patterns, and testthat CI skip mechanisms.

**Key findings:**
- REST APIs should return 201 Created with Location header and resource body for successful POST creation
- Empty result sets should return 200 OK with empty array, not 204 No Content (204 cannot have body)
- R dplyr rowwise operations on empty tibbles require defensive checks to avoid "subscript out of bounds" errors
- testthat provides `skip_on_ci()` for tests that should run locally but not in GitHub Actions
- Database integration tests follow transaction rollback pattern with `with_test_db_transaction()` helper

**Primary recommendation:** Use 201 Created for entity creation, 200 OK with empty array for clustering, add defensive `nrow(.) > 0` checks before rowwise operations, and leverage existing `skip_on_ci()` pattern for integration tests.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| testthat | 3.3.2+ | Unit testing framework | R community standard, built-in skip mechanisms |
| withr | 2.5.0+ | Safe cleanup (defer, local_*) | Handles test fixtures and teardown reliably |
| dplyr | 1.1.0+ | Data manipulation | Project standard, but has edge cases with empty rowwise tibbles |
| dbplyr | 2.3.0+ | Database queries via dplyr | Project standard, translates dplyr to SQL |
| DBI | 1.1.0+ | Database interface | Standard R database abstraction |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| httptest2 | 1.0.0+ | HTTP mocking | External API tests (project already uses) |
| mockery | 0.4.0+ | Function mocking | Unit tests that need to mock internal functions |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| testthat skip_on_ci() | Custom env check | skip_on_ci() is standard, well-documented |
| Transaction rollback | Database fixtures | Rollback is faster, simpler for integration tests |
| dittodb | Real DB with skip | Project already has working skip pattern |

**Installation:**
```bash
# All dependencies already in api/renv.lock
# No new packages needed
```

## Architecture Patterns

### Pattern 1: REST API Response for Entity Creation
**What:** POST to create resource returns 201 Created with Location header and created resource in body
**When to use:** Any POST endpoint that creates a new database entity
**Example:**
```r
# Source: https://dev.to/msnmongare/handling-http-status-codes-in-a-rest-api-200-ok-vs-201-created-28d
function(req, res) {
  # ... create entity ...
  if (success) {
    res$status <- 201
    res$setHeader("Location", paste0("/api/entity/", new_id))
    return(list(
      status = 201,
      message = "Created",
      data = created_entity  # Return the created resource
    ))
  }
}
```

### Pattern 2: Empty Result Set Response
**What:** GET returns 200 OK with empty array when query produces zero results
**When to use:** Any endpoint that returns collections (even if empty)
**Example:**
```r
# Source: https://apihandyman.io/empty-lists-http-status-code-200-vs-204-vs-404/
# Return 200 with empty array for valid query with no results
clusters <- compute_clusters(genes)

if (nrow(clusters) == 0) {
  return(list(
    clusters = list(),    # Empty array
    meta = list(count = 0)
  ))
  # Status is 200 OK (default), NOT 204 No Content
}
```

### Pattern 3: Defensive Rowwise Operations
**What:** Check for empty tibble before applying rowwise operations that could fail
**When to use:** Any rowwise mutate on list-columns where empty result is possible
**Example:**
```r
# Source: https://github.com/tidyverse/dplyr/issues/5804
# PROBLEM: rowwise $ operator fails on empty tibble
clusters_tibble %>%
  rowwise() %>%
  mutate(enrichment = gen_enrich(identifiers$hgnc_id))  # Crashes if 0 rows

# SOLUTION: Guard with nrow check
clusters_tibble %>%
  {
    if (nrow(.) > 0) {
      rowwise(.) %>%
        mutate(enrichment = gen_enrich(identifiers$hgnc_id))
    } else {
      .  # Return empty tibble unchanged
    }
  }
```

### Pattern 4: Integration Tests with CI Skip
**What:** Tests run locally with real database but skip in GitHub Actions
**When to use:** Integration tests requiring database writes that aren't suitable for CI
**Example:**
```r
# Source: https://testthat.r-lib.org/articles/skipping.html
test_that("entity creation writes to database", {
  skip_on_ci()  # Built-in testthat function

  # Real database test with transaction rollback
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    # ... perform writes ...
    # Transaction rolls back automatically
  })
})
```

### Pattern 5: Database Transaction Rollback
**What:** Wrap test in transaction that always rolls back to prevent test pollution
**When to use:** Any integration test that writes to database
**Example:**
```r
# Source: Project's helper-db.R (existing pattern)
with_test_db_transaction <- function(code) {
  skip_if_no_test_db()
  con <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(con))

  DBI::dbBegin(con)
  withr::defer(DBI::dbRollback(con))

  withr::local_options(list(.test_db_con = con))
  force(code)
}
```

### Anti-Patterns to Avoid
- **Returning 204 No Content for empty arrays:** 204 cannot have a body; use 200 with empty array instead
- **Returning 200 OK for resource creation:** Use 201 Created to be semantically correct
- **Skipping rowwise guards in pipelines:** Empty tibbles cause "subscript out of bounds" errors
- **Using custom CI detection:** testthat's `skip_on_ci()` is standard and well-maintained
- **Manual transaction management:** Use helper functions to ensure cleanup happens

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CI environment detection | Custom `Sys.getenv("GITHUB_ACTIONS")` checks | `skip_on_ci()` | testthat maintains this, handles multiple CI platforms |
| Database test cleanup | Manual DELETE statements | Transaction rollback with withr::defer | Automatic, safer, handles failures |
| Empty tibble detection | Type checking list-columns | Simple `nrow(.) > 0` guard | List-column types unknowable in empty tibbles |
| HTTP response status | Custom status logic | REST conventions (201, 200, etc.) | Standard, expected by clients |

**Key insight:** R's dplyr library has well-documented edge cases with empty tibbles in rowwise contexts. The solution is always defensive programming with row count checks, not custom type handling.

## Common Pitfalls

### Pitfall 1: Column Alias Mismatch (SQL vs R)
**What goes wrong:** SQL query uses column alias, R code tries to access original column name, throws "column not found" error
**Why it happens:** dbplyr generates SQL with AS aliases, but downstream R code expects different names
**How to avoid:**
1. Use consistent naming: if SQL says `SELECT category_id, max_category = category`, R must use `max_category`
2. Verify with `collect() %>% names()` during development
3. Scan for similar patterns: search codebase for other `left_join` + `select` + alias patterns
**Warning signs:**
- Error message mentions column name that exists in SQL but not in collected tibble
- Works in database query tool but fails in R

### Pitfall 2: Rowwise on Empty Tibble
**What goes wrong:** `rowwise() %>% mutate(x = data$column)` throws "subscript out of bounds" on zero-row tibble
**Why it happens:** List-columns in empty tibbles have no elements, so `$` operator has nothing to extract
**How to avoid:**
1. Always check `nrow(.) > 0` before rowwise operations on potentially-empty data
2. Pattern: `{ if (nrow(.) > 0) { rowwise(...) } else { . } }`
3. Scan for patterns: search for `rowwise()` + `mutate` + `$` operator combinations
**Warning signs:**
- Error message: "subscript out of bounds"
- Works with sample data but fails on edge cases (no STRING interactions, no clusters)
- Error occurs in pipeline after filtering/joining that could produce zero rows

### Pitfall 3: Direct Approval Flow Returns Wrong Status
**What goes wrong:** Entity creation with `direct_approval=TRUE` succeeds but returns wrong status/shape
**Why it happens:** Approval flow bypasses normal response path, doesn't set proper HTTP status or return entity
**How to avoid:**
1. Both approval paths (direct and normal) must return same response shape
2. Always set `res$status <- 201` for successful creation
3. Always return created entity data, not just success message
4. Review both code paths for consistency
**Warning signs:**
- Frontend receives 200 instead of 201
- Response missing Location header or created entity data
- Different response structure between direct and normal approval

### Pitfall 4: Test Pollution from Database Writes
**What goes wrong:** Integration test writes to database, subsequent tests see unexpected data
**Why it happens:** Tests don't clean up after themselves, state leaks between tests
**How to avoid:**
1. Always wrap database writes in `with_test_db_transaction()`
2. Transaction automatically rolls back, even on test failure
3. Never use manual cleanup (DELETE statements) - they won't run if test crashes
**Warning signs:**
- Tests pass individually but fail when run together
- Test results depend on run order
- Database has leftover test data after suite completes

## Code Examples

Verified patterns from the project:

### Empty Tibble Guard (From analyses-functions.R)
```r
# Source: /api/functions/analyses-functions.R (existing project pattern)
clusters_tibble <- compute_clusters(genes) %>%
  {
    # Only add enrichment if there are rows
    if (enrichment && nrow(.) > 0) {
      mutate(.,
        term_enrichment = list(gen_string_enrich_tib(identifiers$hgnc_id))
      )
    } else {
      .  # Return unchanged (empty tibble or enrichment disabled)
    }
  } %>%
  {
    # Only add subclusters if there are rows
    if (subcluster && nrow(.) > 0) {
      mutate(., subclusters = list(gen_string_clust_obj(identifiers$hgnc_id)))
    } else {
      .
    }
  }
```

### Integration Test with Transaction Rollback (From helper-db.R)
```r
# Source: /api/tests/testthat/helper-db.R (existing project helper)
test_that("entity creation works", {
  skip_on_ci()  # Skip in GitHub Actions

  with_test_db_transaction({
    con <- getOption(".test_db_con")

    # Create test entity
    result <- post_db_entity(test_data)

    # Verify in database
    entity <- DBI::dbGetQuery(con,
      "SELECT * FROM ndd_entity WHERE entity_id = ?",
      params = list(result$entry$entity_id)
    )

    expect_equal(entity$hgnc_id, test_data$hgnc_id)

    # Transaction rolls back automatically - no cleanup needed
  })
})
```

### REST API 201 Created Response Pattern
```r
# Source: REST API best practices (to be implemented)
#* @post /create
function(req, res) {
  # ... validation and creation logic ...

  response_entity <- post_db_entity(create_data$entity)

  if (response_entity$status == 200) {  # Internal success
    # Set HTTP 201 Created for client
    res$status <- 201
    res$setHeader("Location", paste0(
      dw$api_base_url, "/entity/", response_entity$entry$entity_id
    ))

    # ... additional creation steps (review, status) ...

    return(list(
      status = 201,
      message = "Created",
      data = response_entity$entry  # Return created entity
    ))
  } else {
    res$status <- response_entity$status
    return(list(
      status = response_entity$status,
      message = response_entity$message,
      error = response_entity$error
    ))
  }
}
```

### Scan Pattern: Find Rowwise Edge Cases
```bash
# Find all rowwise operations that might fail on empty tibbles
cd api
grep -rn "rowwise()" --include="*.R" | \
  grep -v "^renv/" | \
  xargs -I {} sh -c 'echo "{}"; grep -A5 "{}" | grep "\$"'

# Look for column alias mismatches
grep -rn "left_join.*by.*category" functions/ endpoints/ | \
  xargs -I {} sh -c 'echo "File: {}"; grep -B10 -A10 "select.*category" {}'
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 200 OK for all success | 201 Created for POST creation | REST maturity (2010s) | Semantic HTTP, better client handling |
| 204 No Content for empty | 200 OK with empty array | REST best practices | Body can contain metadata (count, links) |
| Manual test cleanup | Transaction rollback | Modern test patterns | Safer, automatic, handles failures |
| Custom CI skip logic | testthat skip_on_ci() | testthat 3.0+ (2021) | Standard, maintained, cross-platform |
| Unguarded rowwise | Defensive nrow checks | dplyr 1.0+ edge cases | Prevents crashes on empty data |

**Deprecated/outdated:**
- Custom `GITHUB_ACTIONS` environment checks: Use `skip_on_ci()` instead
- Manual database cleanup in tests: Use transaction rollback with withr::defer
- Assuming rowwise operations are safe: Always guard with nrow checks

## Open Questions

1. **Should clustering endpoints cache empty results?**
   - What we know: Empty results are fast to compute (no STRING API calls)
   - What's unclear: Whether caching empty response adds value vs complexity
   - Recommendation: Don't cache empty results - fast enough without cache, simpler logic

2. **Should Panels endpoint validation be more strict?**
   - What we know: Context says "minimal fix - just correct alias mismatch"
   - What's unclear: Whether frontend sends invalid column names that should be rejected
   - Recommendation: Follow context decision - minimal fix only, no new validation

3. **Scan scope for similar bugs**
   - What we know: Context says scan for similar patterns and fix all found
   - What's unclear: Exact search scope (all endpoints vs specific domains)
   - Recommendation: Scan within same domains - all clustering endpoints, all panel-like endpoints, all entity creation paths

## Sources

### Primary (HIGH confidence)
- testthat 3.3.2 official documentation: https://testthat.r-lib.org/articles/skipping.html
- testthat test fixtures guide: https://testthat.r-lib.org/articles/test-fixtures.html
- dplyr GitHub issue #5804 - rowwise empty tibble bug: https://github.com/tidyverse/dplyr/issues/5804
- dplyr GitHub issue #6303 - rowwise size zero edge case: https://github.com/tidyverse/dplyr/issues/6303
- Project's helper-db.R and helper-skip.R (existing patterns)

### Secondary (MEDIUM confidence)
- REST API 201 vs 200 best practices: https://dev.to/msnmongare/handling-http-status-codes-in-a-rest-api-200-ok-vs-201-created-28d
- REST API empty response patterns: https://apihandyman.io/empty-lists-http-status-code-200-vs-204-vs-404/
- HTTP 201 Created standard usage: https://www.codegenes.net/blog/create-request-with-post-which-response-codes-200-or-201-and-content/
- Plumber API testing patterns: https://jakubsobolewski.com/blog/plumber-api/
- Transaction rollback pattern: http://xunitpatterns.com/Transaction%20Rollback%20Teardown.html

### Tertiary (LOW confidence)
- None - all findings verified with official docs or project code

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use, versions confirmed in renv.lock
- Architecture: HIGH - Patterns verified in official docs and existing project code
- Pitfalls: HIGH - Documented in dplyr GitHub issues and REST API standards
- Testing patterns: HIGH - testthat official docs + existing project helpers

**Research date:** 2026-02-05
**Valid until:** 60 days (2026-04-05) - Stable APIs, established patterns, slow-moving standards
