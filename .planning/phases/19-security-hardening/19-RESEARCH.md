# Phase 19: Security Hardening - Research

**Researched:** 2026-01-23
**Domain:** R/Plumber API Security (SQL Injection, Password Hashing, Error Handling)
**Confidence:** HIGH

## Summary

This phase addresses three critical security domains for R/Plumber APIs: SQL injection prevention through parameterized queries, password security via Argon2id hashing with progressive migration, and standardized error handling using RFC 9457 (Problem Details).

The research confirms that R's DBI package provides robust SQL injection protection through `dbBind()` and parameterized queries, making it straightforward to fix all 66 identified injection points. The sodium package offers Argon2id hashing via libsodium's `password_store()` and `password_verify()` functions, enabling production-safe progressive password migration without schema changes. For error handling, the httpproblems package implements RFC 9457 Problem Details format, integrating cleanly with Plumber's `pr_set_error()` mechanism.

The progressive password migration strategy (detect hash type by prefix, verify accordingly, upgrade on login) is industry-standard and avoids forcing user password resets—critical for maintaining user experience while improving security.

**Primary recommendation:** Use DBI parameterized queries for all SQL (never string concatenation), implement progressive Argon2id migration using sodium package functions, standardize errors with httpproblems package and RFC 9457 format, and sanitize logs by removing sensitive fields before logging.

## Standard Stack

The established libraries/tools for R API security hardening:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DBI | 1.2.x+ | Database parameterized queries | CRAN standard for database abstraction with SQL injection protection via `dbBind()` |
| pool | 1.0.4+ | Connection pooling | Official RStudio package for managing DBI connections safely |
| sodium | 1.3.x+ | Argon2id password hashing | CRAN bindings to libsodium with crypto_pwhash_str (Argon2id default since libsodium 1.0.15) |
| httpproblems | 0.1.x | RFC 9457 error format | Only R package implementing Problem Details standard for Plumber APIs |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| logger | 0.3.x+ | Structured logging | Modern logging framework with namespace support and flexible formatters |
| glue | 1.7.x+ | SQL interpolation fallback | Use `glue_sql()` if driver lacks parameterized query support (rare) |
| rlang | 1.1.x+ | Condition system | For classed errors and modern condition handling with `abort()` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| sodium | bcrypt | Argon2id is OWASP-recommended modern choice; bcrypt is older but still acceptable |
| httpproblems | custom errors | RFC 9457 provides machine-readable standard; custom format requires client coordination |
| logger | futile.logger | logger is more modern and actively maintained; futile.logger is mature but older design |
| DBI parameterized | dbQuoteLiteral | Parameterized queries are safer and more performant; quoting is fallback only |

**Installation:**
```bash
# Core security packages
install.packages(c("DBI", "pool", "sodium", "httpproblems", "logger", "glue", "rlang"))
```

## Architecture Patterns

### Recommended Security Module Structure
```
api/
├── core/
│   ├── errors.R              # RFC 9457 error helpers (response_error, stop_for_*)
│   ├── responses.R           # Response builders (response_success, response_error)
│   ├── security.R            # Password utilities (hash, verify, needs_upgrade)
│   └── logging_sanitizer.R   # Log sanitization (remove_sensitive_data)
└── endpoints/
    └── *_endpoints.R         # Use core/* utilities consistently
```

### Pattern 1: Parameterized Queries with dbBind()
**What:** Separate SQL structure from user data using placeholders
**When to use:** ALL queries with user input (no exceptions)
**Example:**
```r
# Source: https://cran.r-project.org/web/packages/DBI/vignettes/DBI-advanced.html
# GOOD: Parameterized query
user_filtered <- pool %>%
  dbGetQuery(
    "SELECT * FROM user WHERE user_name = ? AND approved = ?",
    params = list(check_user, 1)
  )

# For dplyr-style with pool (uses parameterization internally)
user_filtered <- pool %>%
  tbl("user") %>%
  filter(user_name == !!check_user, approved == 1) %>%
  collect()

# For multiple parameter binding
stmt <- dbSendQuery(pool, "SELECT * FROM user WHERE user_name = ? AND approved = ?")
dbBind(stmt, list(check_user, 1))
results <- dbFetch(stmt)
dbClearResult(stmt)

# BAD: String concatenation (SQL injection vulnerable)
query <- paste0("SELECT * FROM user WHERE user_name = '", check_user, "'")
```

**Critical:** Parameterization only works for literal values. Table/column names MUST use `dbQuoteIdentifier()`:
```r
# Source: https://solutions.posit.co/connections/db/best-practices/run-queries-safely/
safe_column <- dbQuoteIdentifier(pool, user_provided_column)
query <- paste0("SELECT ", safe_column, " FROM user WHERE user_id = ?")
dbGetQuery(pool, query, params = list(user_id))
```

### Pattern 2: Progressive Password Migration (Argon2id)
**What:** Detect hash format, verify with appropriate method, upgrade on successful login
**When to use:** During authentication with existing plaintext passwords in production
**Example:**
```r
# Source: https://rdrr.io/cran/sodium/man/password.html
# Source: https://brandur.org/fragments/password-hashing

# In core/security.R
is_hashed <- function(password_from_db) {
  # Argon2id hashes start with $argon2id$ (or $argon2i$/$argon2d$)
  grepl("^\\$argon2", password_from_db)
}

verify_password <- function(password_from_db, password_attempt) {
  if (is_hashed(password_from_db)) {
    # Already hashed - use sodium verification
    sodium::password_verify(password_from_db, password_attempt)
  } else {
    # Plaintext - direct comparison
    password_from_db == password_attempt
  }
}

upgrade_password_if_needed <- function(pool, user_id, password_from_db, password_attempt) {
  if (!is_hashed(password_from_db) && verify_password(password_from_db, password_attempt)) {
    # Password is plaintext and verified - upgrade to Argon2id
    new_hash <- sodium::password_store(password_attempt)
    dbExecute(
      pool,
      "UPDATE user SET password = ? WHERE user_id = ?",
      params = list(new_hash, user_id)
    )
    return(TRUE)
  }
  return(FALSE)
}

# In authentication endpoint
authenticated <- verify_password(user_table$password, check_pass)
if (authenticated) {
  upgrade_password_if_needed(pool, user_table$user_id, user_table$password, check_pass)
  # Continue with token generation
}
```

**Hash format detection:**
- `$argon2id$v=19$m=65536,t=3,p=2$...` = Argon2id hash (already secure)
- Anything else = plaintext (needs upgrade)

**Why this works:** Argon2id hashes follow PHC string format with explicit prefix. Source: https://passlib.readthedocs.io/en/stable/lib/passlib.hash.argon2.html

### Pattern 3: RFC 9457 Error Handling with httpproblems
**What:** Standardized machine-readable error responses with proper HTTP status codes
**When to use:** All API error conditions (validation, auth, server errors)
**Example:**
```r
# Source: https://github.com/atheriel/httpproblems
# Source: https://www.appsilon.com/post/api-oopsies-101

# In core/errors.R - Define classed error conditions
error_unauthorized <- function(message = "Authentication required") {
  structure(
    list(message = message, class = "error_401"),
    class = c("error_401", "error", "condition")
  )
}

error_bad_request <- function(message) {
  structure(
    list(message = message, class = "error_400"),
    class = c("error_400", "error", "condition")
  )
}

# In plumber.R - Set custom error handler
library(httpproblems)

handler_error <- function(req, res, err) {
  # Handle HTTP problem errors
  if (inherits(err, "http_problem_error")) {
    res$status <- err$status
    res$serializer <- plumber::serializer_unboxed_json()
    return(err)
  }

  # Handle custom classed errors
  if (inherits(err, "error_401")) {
    res$status <- 401
    return(unauthorized(detail = err$message))
  }

  if (inherits(err, "error_400")) {
    res$status <- 400
    return(bad_request(detail = err$message))
  }

  # Unhandled exception = 500
  res$status <- 500
  return(internal_server_error(detail = "An unexpected error occurred"))
}

pr() %>%
  pr_set_error(handler_error) %>%
  # ... endpoints
  pr_run()

# In endpoint - Signal errors
if (missing(user_name) || missing(password)) {
  stop(error_bad_request("Missing required parameters: user_name and password"))
}

if (!authenticated) {
  stop(error_unauthorized("Invalid credentials"))
}
```

**RFC 9457 response structure:**
```json
{
  "type": "https://tools.ietf.org/html/rfc9457#section-4.1",
  "title": "Bad Request",
  "status": 400,
  "detail": "Missing required parameters: user_name and password"
}
```

### Pattern 4: Log Sanitization
**What:** Remove sensitive data from logs before writing
**When to use:** ALL logging statements in authentication, user management, and endpoints handling credentials
**Example:**
```r
# Source: https://betterstack.com/community/guides/logging/sensitive-data/
# Source: https://daroczig.github.io/logger/

# In core/logging_sanitizer.R
sanitize_request <- function(req) {
  req_safe <- req
  # Remove password fields
  if (!is.null(req_safe$body$password)) req_safe$body$password <- "[REDACTED]"
  if (!is.null(req_safe$body$old_pass)) req_safe$body$old_pass <- "[REDACTED]"
  if (!is.null(req_safe$body$new_pass_1)) req_safe$body$new_pass_1 <- "[REDACTED]"
  if (!is.null(req_safe$body$new_pass_2)) req_safe$body$new_pass_2 <- "[REDACTED]"
  # Remove authorization headers
  if (!is.null(req_safe$HTTP_AUTHORIZATION)) req_safe$HTTP_AUTHORIZATION <- "[REDACTED]"
  return(req_safe)
}

sanitize_user <- function(user_data) {
  user_safe <- user_data
  if (!is.null(user_safe$password)) user_safe$password <- "[REDACTED]"
  if (!is.null(user_safe$token)) user_safe$token <- "[REDACTED]"
  return(user_safe)
}

# Usage in endpoints
library(logger)
log_info("Authentication attempt", user = check_user, request = sanitize_request(req))
log_info("User data fetched", data = sanitize_user(user_table))
```

### Anti-Patterns to Avoid

**SQL Injection:**
- **String concatenation with paste0():** Never build queries with `paste0("SELECT * FROM user WHERE name = '", user, "'")`
- **Assuming dplyr is always safe:** While dplyr's `filter()` with `==` is safe, using `filter_at()` with user-provided column names needs `dbQuoteIdentifier()`
- **Parameterizing identifiers:** Placeholders (`?`) only work for literal values, NOT table/column names

**Password Security:**
- **Direct password comparison after hashing implemented:** Don't mix `password == plaintext` checks with `password_verify()` calls
- **Logging passwords:** Never log `password`, `old_pass`, `new_pass`, `token`, or `authorization` header values
- **Trusting "try new then old" verification:** Verify with correct algorithm for hash type; don't try multiple methods (enables hash-only login)

**Error Handling:**
- **Empty tryCatch handlers:** `tryCatch(query, error = function(e) {})` swallows errors silently—always log or re-signal
- **500 for validation errors:** Client errors (missing params, invalid format) should be 400-range, not 500
- **Inconsistent error formats:** Use RFC 9457 consistently, not mix of JSON structures across endpoints

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Password hashing | Custom hash algorithm or raw bcrypt | `sodium::password_store()` | Handles salt generation, Argon2id parameters (memory, time, parallelism), and PHC format encoding automatically |
| SQL escaping | Custom escape functions | `dbBind()` with placeholders | Database-specific escaping rules vary; drivers handle correctly. Hand-rolled escaping misses edge cases |
| Error response format | Custom `list(error = ..., code = ...)` | `httpproblems` package | RFC 9457 is industry standard with defined structure, content-type, and extensibility |
| Log sanitization regex | One-off `gsub()` for passwords | Dedicated sanitization functions | Sensitive data patterns evolve (tokens, keys, PII); centralized function ensures consistency |
| Password strength validation | Custom regex rules | Existing validators + clear policy | Password policy enforcement (length, character classes) is well-solved; focus on hashing strength instead |
| Connection pooling | Manual connection management | `pool` package | Connection lifecycle, leak prevention, transaction handling, and resource cleanup are complex |

**Key insight:** Security primitives (hashing, parameterization, escaping) have subtle requirements that library implementations handle correctly. Custom solutions introduce vulnerabilities through missed edge cases.

## Common Pitfalls

### Pitfall 1: Parameterizing Dynamic Identifiers
**What goes wrong:** Trying to use `?` placeholders for table or column names results in SQL errors or still-vulnerable queries.
**Why it happens:** Developers assume parameterization works for all query parts. The database expects identifiers at parse time, before parameter binding occurs.
**How to avoid:** Use `dbQuoteIdentifier()` for user-provided table/column names, and validate against allowlists when possible:
```r
# Source: https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html
allowed_columns <- c("user_name", "user_id", "email", "created_at")
if (!(sort_column %in% allowed_columns)) {
  stop(error_bad_request("Invalid sort column"))
}
safe_column <- dbQuoteIdentifier(pool, sort_column)
query <- paste0("SELECT * FROM user ORDER BY ", safe_column)
```
**Warning signs:** SQL syntax errors when using `?` for ORDER BY, table names, or column selections.

### Pitfall 2: Incomplete Password Migration
**What goes wrong:** Upgrading only authentication endpoint leaves password change, admin resets, and other password-touching code with plaintext comparisons.
**Why it happens:** Password logic is scattered across multiple endpoints (login, password change, admin user management). Developers fix authentication but miss other code paths.
**How to avoid:** Centralize password verification in `core/security.R` and use consistently:
```r
# All password operations use these shared functions
verify_password(stored_hash, attempt)        # Works for both plaintext and hashed
needs_upgrade(stored_hash)                   # Returns TRUE if plaintext
upgrade_password(pool, user_id, new_hash)    # Updates database
```
**Warning signs:** Password change endpoint fails after hashing implemented; old passwords work for login but not password change.

### Pitfall 3: Error Information Leakage
**What goes wrong:** Returning detailed database errors or stack traces to clients exposes internal structure, table names, or SQL syntax.
**Why it happens:** Default error handlers return full error messages. Developers want debugging information during development.
**How to avoid:** Distinguish internal logging (full details) from client responses (sanitized):
```r
# Source: https://enterprisecraftsmanship.com/posts/rest-api-response-codes-400-vs-500/
handler_error <- function(req, res, err) {
  # Log full error for debugging (server-side only)
  log_error("Endpoint error", error = err, request = sanitize_request(req))

  # Return sanitized error to client
  res$status <- 500
  return(internal_server_error(detail = "An unexpected error occurred"))
}
```
**Warning signs:** Client error responses contain SQL query fragments, file paths, or function names.

### Pitfall 4: Swallowed Errors in tryCatch
**What goes wrong:** Using `tryCatch(operation, error = function(e) {})` hides failures silently. Operations appear to succeed when they actually failed.
**Why it happens:** Developers want to prevent errors from stopping execution, but don't add proper error handling or logging.
**How to avoid:** Always log errors or re-signal them with context:
```r
# Source: https://adv-r.hadley.nz/conditions.html
# BAD: Swallows error completely
result <- tryCatch(
  dbExecute(pool, query, params = params),
  error = function(e) NULL
)

# GOOD: Logs error and signals appropriate condition
result <- tryCatch(
  dbExecute(pool, query, params = params),
  error = function(e) {
    log_error("Database operation failed", error = e$message, query = query)
    stop(internal_server_error(detail = "Database operation failed"))
  }
)
```
**Warning signs:** Functions return NULL or default values unexpectedly; logs are silent when operations fail; database changes don't persist.

### Pitfall 5: Logging Sensitive Data
**What goes wrong:** Passwords, tokens, or API keys appear in log files in plaintext.
**Why it happens:** Logging entire request objects (`log_info(req)`) or user records (`log_debug(user)`) captures sensitive fields automatically.
**How to avoid:** Sanitize data structures before logging:
```r
# Source: https://betterstack.com/community/guides/logging/sensitive-data/
# BAD: Logs password in plaintext
log_info("User login", user = check_user, password = check_pass)

# BAD: Request body contains password
log_debug("Request received", request = req)

# GOOD: Sanitize before logging
log_info("User login", user = check_user)
log_debug("Request received", request = sanitize_request(req))
```
**Warning signs:** `grep password *.log` returns matches; compliance audit flags log files.

### Pitfall 6: 500 for Client Errors
**What goes wrong:** Returning HTTP 500 for missing parameters, invalid formats, or unauthorized access.
**Why it happens:** Using catch-all error handlers that default to 500; misunderstanding HTTP status code semantics.
**How to avoid:** Map error types to correct status codes using classed conditions:
```r
# Source: https://enterprisecraftsmanship.com/posts/rest-api-response-codes-400-vs-500/
# Client errors (4xx) - problem with request
- 400: Bad Request (missing params, invalid format)
- 401: Unauthorized (authentication required)
- 403: Forbidden (authenticated but insufficient permissions)
- 404: Not Found (resource doesn't exist)

# Server errors (5xx) - problem with server
- 500: Internal Server Error (unhandled exceptions, bugs)
- 503: Service Unavailable (database down, maintenance)
```
**Warning signs:** Clients retry requests that will never succeed; 5xx rate is high for validation errors.

## Code Examples

Verified patterns from official sources:

### SQL Injection Protection - Complete Pattern
```r
# Source: https://cran.r-project.org/web/packages/DBI/vignettes/DBI-advanced.html
# Source: https://solutions.posit.co/connections/db/best-practices/run-queries-safely/

# Pattern 1: Simple parameterized query
authenticate_user <- function(pool, username, password_hash) {
  users <- dbGetQuery(
    pool,
    "SELECT user_id, user_name, email FROM user WHERE user_name = ? AND password = ? AND approved = ?",
    params = list(username, password_hash, 1)
  )

  if (nrow(users) == 1) {
    return(users[1, ])
  } else {
    return(NULL)
  }
}

# Pattern 2: Multiple parameter binding (reusable statement)
get_users_by_filter <- function(pool, role, approved) {
  stmt <- dbSendQuery(
    pool,
    "SELECT user_id, user_name, email, role FROM user WHERE role = ? AND approved = ?"
  )
  dbBind(stmt, list(role, approved))
  results <- dbFetch(stmt)
  dbClearResult(stmt)
  return(results)
}

# Pattern 3: Dynamic column name (with allowlist validation)
sort_users <- function(pool, sort_column, approved = 1) {
  # Allowlist validation for identifiers
  allowed_columns <- c("user_name", "email", "created_at", "role")
  if (!(sort_column %in% allowed_columns)) {
    stop(error_bad_request(paste("Invalid sort column. Allowed:", paste(allowed_columns, collapse = ", "))))
  }

  # Use dbQuoteIdentifier for column name
  safe_column <- dbQuoteIdentifier(pool, sort_column)

  # Parameterize literal value (approved status)
  query <- paste0("SELECT user_id, user_name, email FROM user WHERE approved = ? ORDER BY ", safe_column)
  dbGetQuery(pool, query, params = list(approved))
}

# Pattern 4: glue_sql fallback (if dbBind not supported)
library(glue)
get_user_by_id_glue <- function(pool, user_id) {
  query <- glue_sql("SELECT * FROM user WHERE user_id = {user_id}", .con = pool)
  dbGetQuery(pool, query)
}
```

### Argon2id Password Hashing - Complete Pattern
```r
# Source: https://rdrr.io/cran/sodium/man/password.html
# Source: https://libsodium.gitbook.io/doc/password_hashing/default_phf

# In core/security.R

#' Check if password is already hashed (Argon2id format)
#' @param password_from_db Password string from database
#' @return TRUE if hashed, FALSE if plaintext
is_hashed <- function(password_from_db) {
  # Argon2id hashes start with $argon2id$ (or $argon2i$, $argon2d$)
  # PHC string format: $argon2id$v=19$m=65536,t=3,p=2$salt$hash
  grepl("^\\$argon2", password_from_db)
}

#' Hash password with Argon2id
#' @param password Plaintext password
#' @return Argon2id hash string (includes salt and parameters)
hash_password <- function(password) {
  sodium::password_store(password)
}

#' Verify password against stored hash (supports both plaintext and hashed)
#' @param password_from_db Stored password (plaintext or hash)
#' @param password_attempt User-provided password attempt
#' @return TRUE if password matches, FALSE otherwise
verify_password <- function(password_from_db, password_attempt) {
  if (is_hashed(password_from_db)) {
    # Hashed password - use sodium verification
    tryCatch(
      sodium::password_verify(password_from_db, password_attempt),
      error = function(e) {
        # Verification error (malformed hash) = failed authentication
        log_warn("Password verification error", error = e$message)
        return(FALSE)
      }
    )
  } else {
    # Plaintext password - direct comparison (legacy)
    password_from_db == password_attempt
  }
}

#' Check if password needs upgrade from plaintext to Argon2id
#' @param password_from_db Stored password
#' @return TRUE if needs upgrade (is plaintext), FALSE if already hashed
needs_upgrade <- function(password_from_db) {
  !is_hashed(password_from_db)
}

#' Upgrade password from plaintext to Argon2id hash
#' @param pool Database connection pool
#' @param user_id User ID to update
#' @param password_plaintext Verified plaintext password
#' @return TRUE if upgraded, FALSE on error
upgrade_password <- function(pool, user_id, password_plaintext) {
  tryCatch({
    new_hash <- hash_password(password_plaintext)
    dbExecute(
      pool,
      "UPDATE user SET password = ? WHERE user_id = ?",
      params = list(new_hash, user_id)
    )
    log_info("Password upgraded to Argon2id", user_id = user_id)
    return(TRUE)
  }, error = function(e) {
    log_error("Password upgrade failed", user_id = user_id, error = e$message)
    return(FALSE)
  })
}

# In authentication_endpoints.R - Usage example
authenticate <- function(pool, check_user, check_pass) {
  # Fetch user (don't filter by password in query)
  user_table <- pool %>%
    tbl("user") %>%
    filter(user_name == !!check_user, approved == 1) %>%
    collect()

  if (nrow(user_table) != 1) {
    return(NULL)
  }

  # Verify password (handles both plaintext and hashed)
  authenticated <- verify_password(user_table$password[1], check_pass)

  if (!authenticated) {
    return(NULL)
  }

  # Upgrade password if needed (progressive migration)
  if (needs_upgrade(user_table$password[1])) {
    upgrade_password(pool, user_table$user_id[1], check_pass)
  }

  # Return user data (without password)
  return(user_table %>% select(-password))
}
```

### RFC 9457 Error Handling - Complete Pattern
```r
# Source: https://github.com/atheriel/httpproblems
# Source: https://www.rplumber.io/reference/pr_set_error.html

# In core/errors.R

library(httpproblems)
library(rlang)

# Define classed error conditions for common cases
error_bad_request <- function(message, detail = NULL) {
  err <- bad_request(detail = detail %||% message)
  class(err) <- c("error_400", "http_problem_error", class(err))
  err
}

error_unauthorized <- function(message = "Authentication required", detail = NULL) {
  err <- unauthorized(detail = detail %||% message)
  class(err) <- c("error_401", "http_problem_error", class(err))
  err
}

error_forbidden <- function(message = "Insufficient permissions", detail = NULL) {
  err <- forbidden(detail = detail %||% message)
  class(err) <- c("error_403", "http_problem_error", class(err))
  err
}

error_not_found <- function(message, detail = NULL) {
  err <- not_found(detail = detail %||% message)
  class(err) <- c("error_404", "http_problem_error", class(err))
  err
}

error_internal <- function(message = "An unexpected error occurred", detail = NULL) {
  err <- internal_server_error(detail = detail %||% message)
  class(err) <- c("error_500", "http_problem_error", class(err))
  err
}

# Convenience functions for signaling errors
stop_for_bad_request <- function(message, detail = NULL) {
  stop(error_bad_request(message, detail))
}

stop_for_unauthorized <- function(message = "Authentication required", detail = NULL) {
  stop(error_unauthorized(message, detail))
}

stop_for_forbidden <- function(message = "Insufficient permissions", detail = NULL) {
  stop(error_forbidden(message, detail))
}

stop_for_not_found <- function(message, detail = NULL) {
  stop(error_not_found(message, detail))
}

# In core/responses.R

#' Build successful response
#' @param data Data to return
#' @param message Optional success message
#' @return List with consistent structure
response_success <- function(data, message = NULL) {
  result <- list(data = data)
  if (!is.null(message)) {
    result$message <- message
  }
  return(result)
}

#' Build error response (for use without httpproblems)
#' @param message Error message
#' @param status HTTP status code
#' @param detail Additional error details
#' @return RFC 9457 compliant error object
response_error <- function(message, status, detail = NULL) {
  error <- list(
    type = sprintf("https://tools.ietf.org/html/rfc9457#section-4.%d", floor(status / 100)),
    title = message,
    status = status
  )
  if (!is.null(detail)) {
    error$detail <- detail
  }
  return(error)
}

# In plumber.R - Configure error handler

library(httpproblems)
source("core/errors.R")
source("core/logging_sanitizer.R")

handler_error <- function(req, res, err) {
  # Log all errors with sanitized request info
  log_error(
    "API error",
    error_class = class(err)[1],
    error_message = err$message,
    endpoint = req$PATH_INFO,
    request = sanitize_request(req)
  )

  # Handle HTTP problem errors (from httpproblems package)
  if (inherits(err, "http_problem_error")) {
    res$status <- err$status
    res$serializer <- plumber::serializer_unboxed_json()
    res$setHeader("Content-Type", "application/problem+json")
    return(err)
  }

  # Handle custom classed errors
  if (inherits(err, "error_400")) {
    res$status <- 400
    res$serializer <- plumber::serializer_unboxed_json()
    res$setHeader("Content-Type", "application/problem+json")
    return(bad_request(detail = err$message))
  }

  if (inherits(err, "error_401")) {
    res$status <- 401
    res$serializer <- plumber::serializer_unboxed_json()
    res$setHeader("Content-Type", "application/problem+json")
    return(unauthorized(detail = err$message))
  }

  if (inherits(err, "error_403")) {
    res$status <- 403
    res$serializer <- plumber::serializer_unboxed_json()
    res$setHeader("Content-Type", "application/problem+json")
    return(forbidden(detail = err$message))
  }

  if (inherits(err, "error_404")) {
    res$status <- 404
    res$serializer <- plumber::serializer_unboxed_json()
    res$setHeader("Content-Type", "application/problem+json")
    return(not_found(detail = err$message))
  }

  # Unhandled exception = 500 Internal Server Error
  # Don't expose internal details to client
  res$status <- 500
  res$serializer <- plumber::serializer_unboxed_json()
  res$setHeader("Content-Type", "application/problem+json")
  return(internal_server_error(detail = "An unexpected error occurred"))
}

pr() %>%
  pr_set_error(handler_error) %>%
  # ... register endpoints
  pr_run()

# In endpoints - Usage examples

#* @post /api/auth/login
function(req, res, user_name, password) {
  # Validate input
  if (missing(user_name) || missing(password)) {
    stop_for_bad_request("Missing required parameters: user_name and password")
  }

  # Authenticate
  user <- authenticate(pool, user_name, password)

  if (is.null(user)) {
    stop_for_unauthorized("Invalid username or password")
  }

  # Generate token and return success
  token <- generate_token(user)
  return(response_success(list(token = token, user = user)))
}

#* @get /api/users/<user_id>
function(req, res, user_id, current_user_id) {
  # Check authorization
  if (user_id != current_user_id && !is_admin(current_user_id)) {
    stop_for_forbidden("You can only view your own user profile")
  }

  # Fetch user
  user <- get_user_by_id(pool, user_id)

  if (is.null(user)) {
    stop_for_not_found(sprintf("User with ID %s not found", user_id))
  }

  return(response_success(user))
}
```

### Logging Sanitization - Complete Pattern
```r
# Source: https://betterstack.com/community/guides/logging/sensitive-data/
# Source: https://daroczig.github.io/logger/

# In core/logging_sanitizer.R

library(logger)

# Define sensitive field patterns
SENSITIVE_FIELDS <- c(
  "password", "old_pass", "new_pass", "new_pass_1", "new_pass_2",
  "token", "jwt", "api_key", "secret", "authorization"
)

#' Recursively sanitize sensitive fields in nested lists
#' @param obj Object to sanitize (list, vector, or primitive)
#' @return Sanitized object with sensitive fields replaced
sanitize_object <- function(obj) {
  if (is.list(obj)) {
    # Sanitize each element
    sanitized <- lapply(names(obj), function(name) {
      if (tolower(name) %in% tolower(SENSITIVE_FIELDS)) {
        "[REDACTED]"
      } else {
        sanitize_object(obj[[name]])
      }
    })
    names(sanitized) <- names(obj)
    return(sanitized)
  } else {
    return(obj)
  }
}

#' Sanitize Plumber request object
#' @param req Plumber request object
#' @return Sanitized request safe for logging
sanitize_request <- function(req) {
  req_safe <- list(
    PATH_INFO = req$PATH_INFO,
    REQUEST_METHOD = req$REQUEST_METHOD,
    QUERY_STRING = req$QUERY_STRING,
    REMOTE_ADDR = req$REMOTE_ADDR
  )

  # Sanitize headers (especially Authorization)
  if (!is.null(req$HEADERS)) {
    headers_safe <- req$HEADERS
    if (!is.null(headers_safe$authorization)) headers_safe$authorization <- "[REDACTED]"
    if (!is.null(headers_safe$`x-api-key`)) headers_safe$`x-api-key` <- "[REDACTED]"
    req_safe$HEADERS <- headers_safe
  }

  # Sanitize body/args
  if (!is.null(req$args)) {
    req_safe$args <- sanitize_object(req$args)
  }

  if (!is.null(req$body)) {
    req_safe$body <- sanitize_object(req$body)
  }

  return(req_safe)
}

#' Sanitize user data object
#' @param user User data list/data.frame
#' @return Sanitized user data
sanitize_user <- function(user) {
  if (is.data.frame(user)) {
    user_safe <- user
    if ("password" %in% names(user_safe)) user_safe$password <- "[REDACTED]"
    if ("token" %in% names(user_safe)) user_safe$token <- "[REDACTED]"
    return(user_safe)
  } else if (is.list(user)) {
    return(sanitize_object(user))
  } else {
    return(user)
  }
}

# Usage in endpoints and filters

# Configure logger with namespace
log_appender(appender_file("logs/api.log", max_files = 30L, max_bytes = 10e6))
log_threshold(INFO)

# In authentication endpoint
log_info("Authentication attempt", user = user_name, request = sanitize_request(req))

# In user management endpoint
user_data <- get_user(pool, user_id)
log_debug("User data retrieved", user = sanitize_user(user_data))

# In filter (pre-hook logging)
function(req, res) {
  log_info(
    "Request received",
    method = req$REQUEST_METHOD,
    path = req$PATH_INFO,
    request = sanitize_request(req)
  )
  plumber::forward()
}

# Never log like this (exposes sensitive data)
# log_info("Login request", req = req)  # BAD: req$body$password in logs
# log_debug("User data", user = user_table)  # BAD: user_table$password in logs
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| dbQuoteString/dbQuoteLiteral | Parameterized queries (dbBind) | DBI 1.0+ (2016) | Safer and faster; prepared statements optimize query plans |
| bcrypt password hashing | Argon2id via sodium::password_store | libsodium 1.0.15 (2017), sodium 1.1+ | Argon2id winner of Password Hashing Competition 2015; OWASP recommended |
| RFC 7807 Problem Details | RFC 9457 Problem Details | July 2023 | Backward compatible; adds multiple problem support and shared registry |
| futile.logger | logger package | logger 0.1 (2018) | Modern design with namespace support and better performance |
| String concatenation SQL | glue_sql for safety | glue 1.3+ (2019) | Automatic quoting; fallback when dbBind unsupported |
| Manual connection management | pool package | pool 0.1 (2016) | Prevents connection leaks; handles transactions safely |

**Deprecated/outdated:**
- **dbQuoteString for parameterization**: Use `dbBind()` instead. `dbQuoteString()` is fallback only when parameterization unavailable.
- **MD5/SHA1 password hashing**: Use Argon2id. MD5/SHA1 are cryptographically broken for passwords.
- **bcrypt (still acceptable)**: Argon2id preferred (OWASP recommendation); bcrypt acceptable if already implemented.
- **Custom error JSON formats**: Use RFC 9457 Problem Details for machine-readable, standardized errors.
- **try() for error handling**: Use `tryCatch()` or `rlang::try_fetch()` for proper condition handling and logging.

## Open Questions

Things that couldn't be fully resolved:

1. **Argon2id Parameter Tuning for R/Plumber**
   - What we know: sodium::password_store() uses libsodium defaults (crypto_pwhash_str). Official docs recommend MODERATE opslimit and memlimit for interactive use.
   - What's unclear: Exact parameter values used by R sodium package; whether defaults are tunable; performance impact on Plumber API response times.
   - Recommendation: Test default sodium::password_store() performance in staging. If response times exceed 200ms, investigate libsodium binding documentation for parameter customization. Default parameters are production-safe per OWASP guidance.

2. **httpproblems Package Maintenance Status**
   - What we know: httpproblems 0.1.x implements RFC 7807; proposal exists to adopt it in Plumber core (issue #772).
   - What's unclear: Whether package is updated for RFC 9457 (supersedes RFC 7807 since July 2023); active maintenance status.
   - Recommendation: Verify httpproblems latest version and RFC 9457 compatibility. If unmaintained, implement RFC 9457 helpers directly in core/errors.R using list structures per spec. RFC 9457 is backward compatible with 7807, so existing httpproblems code remains valid.

3. **Logging Framework Performance with High Request Volume**
   - What we know: logger package supports multiple appenders and formatters; sanitization adds processing overhead per request.
   - What's unclear: Performance impact of sanitize_request() on every request at scale (1000+ req/sec); whether async logging is supported.
   - Recommendation: Implement logging with sanitization initially. Add performance monitoring (request duration logging). If logging bottleneck detected (>5ms per request), consider: (1) log sampling (e.g., 10% of successful requests, 100% of errors), (2) async logging via separate R process, (3) simplified sanitization (regex replacement vs recursive traversal).

## Sources

### Primary (HIGH confidence)
- [DBI Advanced Usage - Parameterized Queries](https://cran.r-project.org/web/packages/DBI/vignettes/DBI-advanced.html) - Official CRAN vignette
- [Posit Solutions - Run Queries Safely](https://solutions.posit.co/connections/db/best-practices/run-queries-safely/) - Official best practices
- [sodium Password Storage Documentation](https://rdrr.io/cran/sodium/man/password.html) - CRAN package docs
- [Plumber pr_set_error Documentation](https://www.rplumber.io/reference/pr_set_error.html) - Official API docs
- [OWASP SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html) - Industry standard
- [libsodium Password Hashing API](https://libsodium.gitbook.io/doc/password_hashing/default_phf) - Upstream library docs
- [RFC 9457: Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457.html) - Official specification

### Secondary (MEDIUM confidence)
- [httpproblems GitHub Repository](https://github.com/atheriel/httpproblems) - Package implementation verified
- [Appsilon: R Plumber Error Responses](https://www.appsilon.com/post/api-oopsies-101) - Industry best practices
- [logger Package Documentation](https://daroczig.github.io/logger/) - CRAN package, actively maintained
- [Better Stack: Logging Sensitive Data](https://betterstack.com/community/guides/logging/sensitive-data/) - Industry guidance
- [Posit: Database Connection Pooling](https://solutions.posit.co/connections/db/r-packages/pool/) - Official pool documentation
- [Advanced R: Conditions](https://adv-r.hadley.nz/conditions.html) - Authoritative R programming reference

### Tertiary (LOW confidence - requires validation)
- [Argon2 Hash Format Detection](https://passlib.readthedocs.io/en/stable/lib/passlib.hash.argon2.html) - Python library, but format is standard
- [Progressive Password Rehashing Strategies](https://brandur.org/fragments/password-hashing) - Engineering blog, practices verified
- [HTTP Status Codes: 4xx vs 5xx](https://enterprisecraftsmanship.com/posts/rest-api-response-codes-400-vs-500/) - Industry guidance
- [RFC 9457 vs RFC 7807 Comparison](https://redocly.com/blog/problem-details-9457) - Technical blog, spec changes verified

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages from CRAN with official documentation; DBI and sodium are industry-standard
- Architecture patterns: HIGH - Patterns sourced from official docs (DBI vignettes, Plumber docs, libsodium spec)
- Pitfalls: MEDIUM/HIGH - SQL injection and password pitfalls from OWASP (HIGH); R-specific tryCatch patterns from community sources (MEDIUM)
- Progressive password migration: MEDIUM - Strategy verified across multiple sources; R sodium specifics less documented

**Research date:** 2026-01-23
**Valid until:** ~60 days (2026-03-23) - Stable security domain; DBI, sodium, and httpproblems packages are mature with infrequent breaking changes. Monitor for: (1) sodium package updates (check for Argon2id parameter exposure), (2) httpproblems RFC 9457 compatibility, (3) Plumber built-in error handling improvements.
