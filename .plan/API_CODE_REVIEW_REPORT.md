# SysNDD API Code Review Report

**Date:** 2026-01-20
**Reviewer:** Senior R/Tidyverse Developer
**Scope:** `/api/` directory - R Plumber REST API
**Version:** 0.2.1 (Enhanced Review)

---

## Executive Summary

The SysNDD API is a functional R Plumber application that successfully serves a neurodevelopmental disorders database. The recent refactoring effort (splitting the monolithic `sysndd_plumber.R` into modular endpoint files) demonstrates good architectural direction. However, several areas require immediate attention regarding modern best practices, security, maintainability, performance, and testability.

### Overall Grade: **C+** (68/100)

| Category | Grade | Score |
|----------|-------|-------|
| Architecture & Modularization | B | 75/100 |
| DRY (Don't Repeat Yourself) | D+ | 55/100 |
| KISS (Keep It Simple, Stupid) | C | 65/100 |
| SOLID Principles | D | 50/100 |
| Security | D | 52/100 |
| Error Handling | C- | 60/100 |
| Testing | F | 20/100 |
| Performance & Scalability | C- | 58/100 |
| Code Quality & Style | B- | 72/100 |
| Documentation | B | 78/100 |

---

## Detailed Findings

### 1. Architecture & Modularization (Grade: B - 75/100)

#### Strengths
- **Modular endpoint structure**: 21 endpoint files organized by domain (entity, user, review, etc.)
- **Separation of concerns**: Functions directory separates business logic from endpoints
- **Configuration management**: Uses `config.yml` with environment-specific settings
- **Connection pooling**: Proper use of `pool` package for database connections
- **Memoization**: Strategic caching with `memoise` for expensive operations

#### Issues

**Anti-Pattern: God Script Entry Point**
```r
# start_sysndd_api.R loads 42 libraries at startup (lines 21-61)
library(dotenv)
library(plumber)
library(logger)
# ... 39 more libraries
```
*Impact:* Slow startup (~15-30 seconds), unclear dependencies per module, increased memory footprint

**Recommendation:** Use a package structure with DESCRIPTION file for dependency management, or lazy-load libraries per endpoint using `requireNamespace()`.

**Anti-Pattern: Excessive Global State via `<<-` Operator**
```r
# start_sysndd_api.R - Found 15 occurrences (not 8 as initially estimated)
# Lines: 133, 146, 153, 161, 173, 174, 176, 177, 187-194
pool <<- dbPool(...)
serializers <<- list(...)
inheritance_input_allowed <<- c(...)
user_status_allowed <<- c(...)
version_json <<- fromJSON(...)
sysndd_api_version <<- version_json$version
generate_stat_tibble_mem <<- memoise(...)
# ... 8 more memoized functions
```
*Impact:* Hard to test, hidden dependencies, potential race conditions in concurrent environments

**Positive Note:** `admin_endpoints.R:208` demonstrates proper cleanup pattern:
```r
on.exit(dbDisconnect(sysndd_db), add = TRUE)
```

---

### 2. DRY Violations (Grade: D+ - 55/100)

#### Critical: Database Connection Duplication

Found **17 occurrences** of `dbConnect(RMariaDB::MariaDB(), ...)` throughout the codebase despite having a global connection pool.

**File Distribution:**
- `database-functions.R`: 15 occurrences
- `logging-functions.R`: 1 occurrence
- `publication-functions.R`: 1 occurrence

```r
# Repeated pattern in database-functions.R (lines 48-54, 135-142, 230-237, etc.)
sysndd_db <- dbConnect(RMariaDB::MariaDB(),
  dbname = dw$dbname,
  user = dw$user,
  password = dw$password,
  server = dw$server,
  host = dw$host,
  port = dw$port)
```

**Why this is problematic:**
1. Connection pool exists (`pool`) but functions create new connections
2. Connections not always properly closed on error paths
3. 90+ references to `dw$` config object scattered across 16 files

**Recommendation:** Create a database access layer:
```r
# functions/db-access.R
with_db_connection <- function(fn) {
  pool::poolWithTransaction(pool, fn)
}

execute_query <- function(query, params = list()) {
  pool::dbGetQuery(pool, query, params)
}

execute_parameterized <- function(query, ...) {
  DBI::dbExecute(pool, query, params = list(...))
}
```

#### Repeated Validation Patterns

Found 12 occurrences of authentication check pattern:
```r
# Found across: user_endpoints.R, re_review_endpoints.R, review_endpoints.R, etc.
if (length(user) == 0) {
  res$status <- 401
  return(list(error = "Please authenticate."))
}
```

**Recommendation:** Create middleware/filter:
```r
require_auth <- function(req, res) {
  if (is.null(req$user_id)) {
    res$status <- 401
    stop_for_status(list(error = "Please authenticate."))
  }
}

require_role <- function(req, res, allowed_roles) {
  require_auth(req, res)
  if (!(req$user_role %in% allowed_roles)) {
    res$status <- 403
    stop_for_status(list(error = "Access forbidden."))
  }
}
```

#### Repeated Response Patterns

Status/message response construction repeated 50+ times:
```r
return(list(status = 200, message = "OK. Entry created.", entry = ...))
return(list(status = 405, message = "Method not Allowed."))
return(list(status = 400, message = "Submitted data can not be null."))
```

**Recommendation:** Create response builders:
```r
response_success <- function(message = "OK", data = NULL, status = 200) {
  list(status = status, message = message, data = data)
}

response_error <- function(message, status = 400) {
  list(status = status, error = message)
}
```

---

### 3. KISS Violations (Grade: C - 65/100)

#### Over-Engineered Filter Expression Generation

`generate_filter_expressions()` in `helper-functions.R` (lines 308-506, ~200 lines) implements a custom query language parser:

```r
# functions/helper-functions.R:308-506
generate_filter_expressions <- function(filter_string,
    operations_allowed = "equals,contains,any,all,lessThan,...") {
  # Complex string parsing logic with 40+ case_when branches
  # Multiple regex operations
  # Database lookups for hash validation
  # Custom expression building
}
```

**Issues:**
- Complex string manipulation is error-prone
- No input validation before processing
- Difficult to maintain and extend

**Recommendation:** Consider using established packages like `dbplyr` filters, or implement a structured query object pattern.

#### Complex Nested Conditions

```r
# endpoints/entity_endpoints.R - POST /create endpoint
# 200+ lines of nested if-else with multiple database operations
if (response_entity$status == 200) {
  # 150 lines of code
  if (response_entity$status == 200 && response_review_post$status == 200) {
    # More nested code
    if (response_entity$status == 200 &&
      response_review_post$status == 200 &&
      response_status_post$status == 200) {
      # Even more nesting (4+ levels deep)
    }
  }
}
```

**Recommendation:** Use early returns, extract sub-operations into functions, implement proper transaction handling with rollback.

---

### 4. SOLID Principles (Grade: D - 50/100)

#### Single Responsibility Principle (SRP) Violations

**`database-functions.R` (1,234 lines)** handles:
- Entity CRUD operations
- Review management
- Publication connections
- Phenotype connections
- Ontology connections
- Status management
- Hash operations
- Approval workflows

**Recommendation:** Split into domain-specific repositories:
```
functions/
├── repositories/
│   ├── entity-repository.R
│   ├── review-repository.R
│   ├── publication-repository.R
│   ├── phenotype-repository.R
│   └── status-repository.R
├── services/
│   ├── approval-service.R
│   └── hash-service.R
└── db/
    └── db-access.R
```

#### Open/Closed Principle Violations

Adding new filter operations requires modifying `generate_filter_expressions()`:
```r
mutate(exprs = case_when(
  column == "any" & logic == "contains" ~ ...
  column == "any" & logic == "equals" ~ ...
  # Must add new cases for each combination (currently 32 cases)
))
```

#### Dependency Inversion Violations

Functions directly depend on global `dw` configuration and `pool`:
```r
# Hard-coded dependencies throughout
publication_list_collected <- pool %>%
  tbl("publication") %>%
  ...
```

**Recommendation:** Pass dependencies as parameters or use dependency injection patterns:
```r
get_publications <- function(db_pool = pool) {
  db_pool %>% tbl("publication") %>% ...
}
```

---

### 5. Security Concerns (Grade: D - 52/100)

#### Critical: SQL Injection Vulnerabilities

Found **66 occurrences** of `dbExecute` with string concatenation across 7 files:

**File Distribution:**
| File | Count | Severity |
|------|-------|----------|
| `database-functions.R` | 23 | Critical |
| `re_review_endpoints.R` | 17 | Critical |
| `user_endpoints.R` | 13 | Critical |
| `admin_endpoints.R` | 7 | Medium |
| `pubtator-functions.R` | 4 | Low |
| `logging-functions.R` | 1 | Low |
| `ontology_endpoints.R` | 1 | Medium |

**Critical Examples:**

```r
# database-functions.R:145-151 - User input directly in SQL
dbExecute(sysndd_db, paste0("UPDATE ndd_entity SET ",
  "is_active = 0, ",
  "replaced_by = ", replacement,  # User input!
  " WHERE entity_id = ", entity_id,  # User input!
  ";"))

# user_endpoints.R:478-485 - Password in plain SQL
dbExecute(sysndd_db,
  paste0(
    "UPDATE user SET password = '",
    new_pass_1,  # PASSWORD IN PLAIN TEXT SQL!
    "' WHERE user_id = ",
    user_id_pass_change,
    ";"
  )
)

# user_endpoints.R:793-805 - Dynamic query from user input
set_clause <- paste(
  sapply(fields_to_update, function(field) {
    paste0(field, " = '", user_details[[field]], "'")  # Unvalidated user input!
  }, USE.NAMES = FALSE),
  collapse = ", "
)
query <- sprintf("UPDATE user SET %s WHERE user_id = %d;", set_clause, user_details[["user_id"]])
```

**Severity:** CRITICAL - Direct SQL injection possible on multiple endpoints

**Recommendation:** Use parameterized queries exclusively:
```r
# Using DBI parameterized queries
DBI::dbExecute(sysndd_db,
  "UPDATE ndd_entity SET is_active = 0, replaced_by = ? WHERE entity_id = ?",
  params = list(replacement, entity_id))

# Or using glue_sql for complex queries
query <- glue::glue_sql("UPDATE user SET password = {password} WHERE user_id = {user_id}",
  password = hashed_password, user_id = user_id, .con = sysndd_db)
```

#### Critical: Plaintext Password Storage and Comparison

```r
# authentication_endpoints.R:151-153
user_filtered <- pool %>%
  tbl("user") %>%
  filter(user_name == check_user & password == check_pass & approved == 1)
```

**Issues:**
1. Passwords stored in plaintext in database
2. Passwords compared in plaintext
3. Passwords visible in logs (via postBody logging in `start_sysndd_api.R:369`)
4. Passwords sent directly in SQL queries

**Recommendation:** Use the R `bcrypt` package ([CRAN](https://cran.r-project.org/web/packages/bcrypt/bcrypt.pdf)):
```r
library(bcrypt)

# When storing password
hashed_password <- bcrypt::hashpw(password)

# When verifying
bcrypt::checkpw(submitted_password, stored_hash)
```

Or use `sodium` package for scrypt ([CRAN](https://cran.r-project.org/web/packages/sodium/vignettes/intro.html)):
```r
library(sodium)

# Hash password
hash <- sodium::password_store(password)

# Verify
sodium::password_verify(hash, submitted_password)
```

#### JWT Secret Handling

```r
# Loaded from config, but referenced directly in multiple files
key <- charToRaw(dw$secret)
```

**Recommendations:**
- Rotate JWT secrets periodically
- Use asymmetric keys (RS256) for better security
- Store secrets in environment variables, not config files

---

### 6. Error Handling (Grade: C- - 60/100)

#### Inconsistent Error Responses

```r
# Different error formats across endpoints
return(list(error = "Message"))                    # Format 1
return(list(status = 405, message = "Message"))    # Format 2
res$body <- "Message"                              # Format 3
stop("Message")                                    # Format 4
res$status <- 404; res$body <- "Message"; res     # Format 5
```

**Recommendation:** Implement standardized error response:
```r
# Use a consistent error structure following RFC 7807
api_error <- function(res, status, message, details = NULL) {
  res$status <- status
  list(
    type = paste0("https://api.sysndd.org/errors/", status),
    status = status,
    title = http_status_text(status),
    detail = message,
    instance = req$PATH_INFO,
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
  )
}
```

#### Swallowed Errors

```r
# database-functions.R:58-63
db_append <- tryCatch({
  dbAppendTable(sysndd_db, "ndd_entity", entity_received)
}, error = function(cond) {
  return(cond$message)  # Error becomes a string, not properly handled
})

# user_endpoints.R:712-716
delete_result <- tryCatch({
  dbExecute(sysndd_db, paste0("DELETE FROM user WHERE user_id = ", user_id, ";"))
}, error = function(e) {
  NULL  # Error completely swallowed
})
```

#### Missing Connection Cleanup on Errors

```r
# If error occurs between connect and disconnect, connection leaks
sysndd_db <- dbConnect(...)
# ... operations that might fail ...
dbDisconnect(sysndd_db)  # Never reached on error
```

**Recommendation:** Use `on.exit()` or `tryCatch` with `finally`:
```r
sysndd_db <- dbConnect(...)
on.exit(dbDisconnect(sysndd_db), add = TRUE)

# Or use withConnection pattern
with_connection <- function(fn) {
  con <- dbConnect(...)
  on.exit(dbDisconnect(con))
  fn(con)
}
```

**Positive Note:** `admin_endpoints.R:208` already implements this correctly.

---

### 7. Testing (Grade: F - 20/100)

#### Critical Gap: No Test Files Found

```bash
# Search results
api/**/*test*.R → No files found
api/**/tests/**/*.R → No files found
api/testthat/** → No directory found
```

**Impact:**
- No regression protection
- No documentation of expected behavior
- Refactoring risk
- Integration issues undetected
- Security vulnerabilities may go unnoticed

**Recommendation:** Implement testing following modern R best practices:

1. **Package structure with `testthat`:**
```r
# tests/testthat/test-authentication.R
test_that("authentication rejects invalid credentials", {
  res <- mock_request("GET", "/api/auth/authenticate",
    params = list(user_name = "test", password = "wrong"))
  expect_equal(res$status, 401)
})
```

2. **API integration tests:**
```r
# Using httptest2 or httr2 for API testing
test_that("entity creation requires authentication", {
  resp <- httr2::request("http://localhost:7778/api/entity/") %>%
    httr2::req_method("POST") %>%
    httr2::req_perform()
  expect_equal(resp$status_code, 401)
})
```

3. **Load testing:** Use `loadtest` or `crul` package

**References:**
- [Practical Plumber Patterns](https://github.com/blairj09-talks/ppp)
- [testthat Package](https://testthat.r-lib.org/)

---

### 8. Performance & Scalability (Grade: C- - 58/100)

#### R Single-Threaded Limitation

R is single-threaded. Current implementation blocks all requests during long operations.

```r
# Blocking operations found:
# - Large data exports (gene_endpoints.R, entity_endpoints.R)
# - Ontology updates (admin_endpoints.R)
# - PubTator API calls (pubtator-functions.R)
```

#### Recommendation: Implement Async Processing

Use `future` and `promises` packages for non-blocking operations:

```r
# In start_sysndd_api.R, add:
library(future)
library(promises)
future::plan("multisession", workers = 4)

# For long-running endpoints:
#* @get /api/analysis/heavy_computation
function() {
  promises::future_promise({
    # Long-running computation here
    heavy_analysis_function()
  })
}
```

**Implementation Pattern:**
```r
# functions/async-utils.R
run_async <- function(fn) {
  promises::future_promise({
    fn()
  })
}

# In endpoint:
#* @get /api/export/large_dataset
function(req, res) {
  run_async(function() {
    generate_large_export()
  })
}
```

**Resources:**
- [Plumber + Future: Async Web APIs](https://posit.co/resources/videos/plumber-and-future-async-web-apis/)
- [FuturePlumber GitHub](https://github.com/FvD/futureplumber)

#### Database Query Optimization

```r
# Found: Full table scans with collect() before filtering
user_table <- pool %>%
  tbl("user") %>%
  collect()  # Loads ALL users into memory

user_info <- user_table %>%
  filter(user_id == user)  # Then filters locally
```

**Recommendation:** Push filters to database:
```r
user_info <- pool %>%
  tbl("user") %>%
  filter(user_id == !!user) %>%  # Filter at DB level
  collect()  # Only fetch filtered results
```

#### Connection Pool Configuration

Current pool has default settings. Recommend tuning:
```r
pool <<- dbPool(
  drv = RMariaDB::MariaDB(),
  dbname = dw$dbname,
  # Add pool tuning parameters:
  minSize = 2,
  maxSize = 10,
  idleTimeout = 60000,  # 60 seconds
  validationInterval = 60  # Validate every 60 seconds
)
```

---

### 9. Code Quality & Style (Grade: B- - 72/100)

#### Strengths
- Consistent tidyverse style
- Good use of pipe operators
- `.lintr` configuration present
- Formatting tools (`styler`) in use
- Roxygen2 documentation on functions

#### Issues

**30 TODO Comments** indicating incomplete implementations:

| File | Count | Examples |
|------|-------|----------|
| `ontology-functions.R` | 9 | Implementation gaps |
| `helper-functions.R` | 6 | Error handling, column validation |
| `analyses-functions.R` | 5 | Feature completions |
| `external-functions.R` | 3 | API integrations |
| `database-functions.R` | 2 | Error handling |
| Others | 5 | Various |

**Magic Numbers/Strings**
```r
# Scattered throughout with no constants file
if (nchar(value) >= 5 & nchar(value) <= 20)  # What are these limits?
dw$refresh  # Token expiry, value not documented
page_size = "10"  # Default pagination - why 10?
nrow(x) > 5  # Why 5?
```

**Recommendation:** Create constants file:
```r
# config/constants.R
USERNAME_MIN_LENGTH <- 5L
USERNAME_MAX_LENGTH <- 20L
PASSWORD_MIN_LENGTH <- 8L
DEFAULT_PAGE_SIZE <- 10L
TOKEN_EXPIRY_SECONDS <- 3600L
```

---

### 10. Documentation (Grade: B - 78/100)

#### Strengths
- Roxygen2-style documentation on most functions
- OpenAPI/Swagger integration
- README.md present
- CLAUDE.md with development guidance

#### Areas for Improvement
- No architecture documentation (ADR - Architecture Decision Records)
- Missing API versioning strategy documentation
- No contribution guidelines (CONTRIBUTING.md)
- Database schema documentation not linked
- No security documentation
- No deployment runbook

---

## Anti-Patterns Summary

| Anti-Pattern | Occurrences | Severity | Files Affected |
|--------------|-------------|----------|----------------|
| SQL Injection via string concatenation | 66 | Critical | 7 |
| Plaintext password storage | 5+ endpoints | Critical | 2 |
| Connection pool bypass | 17 | High | 4 |
| Global mutable state (`<<-`) | 15 | Medium | 1 |
| God function (>200 lines) | 5 | Medium | 3 |
| Inconsistent error handling | ~100 | Medium | All |
| Missing tests | Entire codebase | Critical | N/A |
| Synchronous blocking operations | 10+ | Medium | 5+ |
| Hard-coded configuration access | 259 | Low | 16 |
| Incomplete TODOs | 30 | Low | 10 |

---

## Recommendations Priority Matrix

### Immediate (Security/Critical) - Week 1-2
1. **Parameterize all SQL queries** - SQL injection risk
2. **Implement password hashing** using `bcrypt` or `sodium` package
3. **Remove passwords from logs** - modify postroute hook
4. **Set up basic test infrastructure** with `testthat`

### Short-term (1-2 sprints)
5. Create database access layer to eliminate `dbConnect` duplication
6. Implement consistent error handling middleware following RFC 7807
7. Extract authentication logic into reusable filters
8. Add input validation middleware using `validate` package
9. Implement `on.exit()` cleanup pattern consistently

### Medium-term (1-3 months)
10. Convert to R package structure with DESCRIPTION file
11. Implement comprehensive test suite (80%+ coverage target)
12. Add CI/CD pipeline with linting and testing
13. Implement async processing with `future` + `promises`
14. Document architecture decisions (ADRs)
15. Add structured logging with correlation IDs

### Long-term (3-6 months)
16. Implement proper dependency injection
17. Add API versioning strategy (URL-based: `/api/v2/`)
18. Add observability (structured logging, metrics, tracing)
19. Performance profiling and optimization
20. Consider migration to `{plumber} + {ambiorix}` for better async support

---

## Positive Observations

1. **Clean modular refactoring** - Splitting monolithic file shows good direction
2. **Memoization strategy** - Smart caching for expensive operations using `cachem`
3. **Configuration management** - Environment-specific configs well structured
4. **OpenAPI documentation** - Good API discoverability via Swagger
5. **Code quality tooling** - lintr and styler integration
6. **Consistent tidyverse style** - Code follows conventions
7. **Transaction usage** - `admin_endpoints.R` demonstrates proper transaction handling with rollback
8. **`on.exit()` usage** - `admin_endpoints.R:208` shows proper cleanup pattern
9. **Infrastructure-level rate limiting** - Handled via nginx reverse proxy in Docker deployment

---

## Modern R API Best Practices References

### Security
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [R bcrypt Package](https://cran.r-project.org/web/packages/bcrypt/bcrypt.pdf)
- [R sodium Package](https://cran.r-project.org/web/packages/sodium/vignettes/intro.html)

### Plumber
- [Plumber Best Practices](https://www.rplumber.io/)
- [Plumber Security Guide](https://www.rplumber.io/articles/security.html)
- [Practical Plumber Patterns](https://github.com/blairj09-talks/ppp)
- [REST APIs with Plumber Cheatsheet](https://rstudio.github.io/cheatsheets/html/plumber.html)

### Async/Performance
- [Plumber + Future: Async Web APIs](https://posit.co/resources/videos/plumber-and-future-async-web-apis/)
- [FuturePlumber GitHub](https://github.com/FvD/futureplumber)
- [Plumber Execution Model](https://www.rplumber.io/articles/execution-model.html)

### Testing
- [R Packages Book](https://r-pkgs.org/)
- [testthat Package](https://testthat.r-lib.org/)

---

## Appendix: Quick Wins Checklist

- [ ] Add `on.exit(dbDisconnect(...))` to all functions with `dbConnect`
- [ ] Replace `paste0` SQL with `DBI::dbExecute(..., params = list(...))`
- [ ] Add `library(bcrypt)` and hash passwords
- [ ] Create `require_auth()` helper function
- [ ] Add `.env.example` template file
- [ ] Create `response_success()` and `response_error()` helpers
- [ ] Add `future::plan("multisession")` for async support
- [ ] Create `tests/testthat/` directory structure
- [ ] Document API versioning strategy

---

*Report generated as part of code quality assessment for SysNDD API v0.2.1*
*Enhanced with modern R/Plumber best practices research - 2026-01-20*
