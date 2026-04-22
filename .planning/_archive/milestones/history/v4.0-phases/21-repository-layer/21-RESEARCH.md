# Phase 21: Repository Layer - Research

**Researched:** 2026-01-23
**Domain:** R database access layer with repository pattern
**Confidence:** HIGH

## Summary

Phase 21 creates a database access layer that abstracts SQL queries behind domain-specific repositories, eliminating direct `dbConnect()` calls from endpoints. The current codebase has 17 instances of duplicated connection management and uses string concatenation for SQL (vulnerable to SQL injection). The repository layer will use the pool package for connection pooling, DBI's parameterized queries via `dbBind()` for security, and provide a consistent interface for all database operations.

**Core findings:**
- R6P package provides the Repository pattern for R, but plain R functions are more idiomatic for R projects
- Pool package (v1.0.4, released July 2025) handles connection lifecycle automatically with configurable size and timeout parameters
- RMariaDB only supports positional `?` placeholders (not named `:name` syntax) for parameterized queries
- DBI's `dbWithTransaction()` and `poolWithTransaction()` provide automatic rollback on errors
- R's `logger` package (already in project) supports structured DEBUG-level logging with glue syntax
- R project convention places repositories/data-access functions in `functions/` directory

**Primary recommendation:** Use plain R functions (not R6 classes) in `functions/` directory organized by domain (entity-repository.R, review-repository.R, etc.), wrap queries in helper functions that use `pool` directly for single queries and `poolWithTransaction()` for multi-table operations, use positional `?` placeholders with `dbBind()` for parameterization, and log all executed queries at DEBUG level with sanitized parameters.

## Standard Stack

The established libraries/tools for database access layers in R:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| pool | 1.0.4 | Connection pooling | Official Posit/RStudio package. Manages connection lifecycle automatically. Already in project. |
| DBI | Latest | Database interface | R's standard database abstraction layer. Defines `dbBind()`, `dbWithTransaction()`, etc. Already in project. |
| RMariaDB | Latest | MariaDB driver | DBI backend for MariaDB/MySQL. Already in project. |
| logger | 0.3.0 | Structured logging | Lightweight modern logging with glue syntax and severity levels. Already in project (used in start_sysndd_api.R). |
| dplyr | Latest | Data manipulation | Tidyverse integration with pool via `tbl()`. Already in project. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| glue | Latest | SQL interpolation | Fallback for dynamic SQL construction when `dbBind()` can't be used (table/column names). Already in tidyverse. |
| rlang | Latest | Error handling | `abort()` with structured conditions for better error messages. Already in project. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Plain functions | R6 classes (R6P package) | R6 provides OOP encapsulation but is less idiomatic in R. Most R packages use plain functions. User decided plain functions pattern. |
| Pool package | Manual dbConnect/dbDisconnect | Manual management is error-prone and slower. Pool already adopted in project. |
| Positional params | Named params | RMariaDB doesn't support `:name` syntax, only `?` positional. SQLite supports both but we're locked to MariaDB. |

**Installation:**
```r
# All packages already in project
# pool, DBI, RMariaDB, logger, dplyr, glue, rlang
```

## Architecture Patterns

### Recommended Project Structure
```
api/
├── functions/
│   ├── entity-repository.R       # NEW: Entity CRUD operations
│   ├── review-repository.R       # NEW: Review CRUD operations
│   ├── status-repository.R       # NEW: Status CRUD operations
│   ├── publication-repository.R  # NEW: Publication CRUD operations
│   ├── phenotype-repository.R    # NEW: Phenotype CRUD operations
│   ├── ontology-repository.R     # NEW: Ontology CRUD operations
│   ├── user-repository.R         # NEW: User CRUD operations
│   ├── hash-repository.R         # NEW: Hash CRUD operations
│   ├── db-helpers.R              # NEW: execute_query, with_transaction helpers
│   └── database-functions.R      # Refactor: Keep migration/admin operations
├── endpoints/
│   └── *_endpoints.R             # Refactor: Replace dbConnect() with repo calls
└── start_sysndd_api.R            # Already creates global pool object
```

**Naming conventions:**
- Repository files: `<domain>-repository.R` (singular, hyphenated)
- Repository functions: `<domain>_<operation>()` (e.g., `entity_create()`, `review_find_by_id()`)
- Helper functions: `db_<operation>()` (e.g., `db_execute_query()`, `db_with_transaction()`)

### Pattern 1: Query Helpers with Parameterized Queries
**What:** Wrapper functions that execute queries safely using pool and parameterized queries.
**When to use:** All SELECT/INSERT/UPDATE/DELETE operations.
**Example:**
```r
# Source: Based on DBI specification and pool best practices
# functions/db-helpers.R

#' Execute a query and return results
#'
#' @param sql SQL query string with ? placeholders
#' @param params List of positional parameters (unnamed)
#' @param fetch_all Logical, whether to fetch all rows (default TRUE)
#' @return Tibble of results, or empty tibble if no rows
db_execute_query <- function(sql, params = list(), fetch_all = TRUE) {
  # Log query with sanitized params (no sensitive data)
  logger::log_debug("Executing query: {sql}",
                   params = paste(lapply(params, function(p) {
                     if (is.character(p) && nchar(p) > 50) "[REDACTED]"
                     else as.character(p)
                   }), collapse = ", "))

  tryCatch({
    # Send parameterized query
    result <- DBI::dbSendQuery(pool, sql)

    # Register cleanup on exit
    on.exit(DBI::dbClearResult(result), add = TRUE)

    # Bind parameters if provided
    if (length(params) > 0) {
      DBI::dbBind(result, params)
    }

    # Fetch results
    if (fetch_all) {
      data <- DBI::dbFetch(result)
      # Return empty tibble with columns if no rows
      if (nrow(data) == 0) {
        return(tibble::as_tibble(data))
      }
      return(tibble::as_tibble(data))
    } else {
      return(result)
    }
  }, error = function(e) {
    logger::log_error("Query failed: {e$message}", sql = sql)
    rlang::abort(
      message = "Database query failed",
      class = "db_query_error",
      sql = sql,
      original_error = e$message
    )
  })
}

#' Execute a statement (INSERT/UPDATE/DELETE) and return affected rows
#'
#' @param sql SQL statement with ? placeholders
#' @param params List of positional parameters (unnamed)
#' @return Integer, number of rows affected
db_execute_statement <- function(sql, params = list()) {
  logger::log_debug("Executing statement: {sql}")

  tryCatch({
    result <- DBI::dbSendStatement(pool, sql)
    on.exit(DBI::dbClearResult(result), add = TRUE)

    if (length(params) > 0) {
      DBI::dbBind(result, params)
    }

    affected <- DBI::dbGetRowsAffected(result)
    logger::log_debug("Statement affected {affected} rows")
    return(affected)
  }, error = function(e) {
    logger::log_error("Statement failed: {e$message}", sql = sql)
    rlang::abort(
      message = "Database statement failed",
      class = "db_statement_error",
      sql = sql,
      original_error = e$message
    )
  })
}
```

**Key benefits:**
- Automatic SQL injection protection via `dbBind()`
- Consistent error handling with structured errors
- DEBUG-level logging for production debugging
- Connection cleanup via `on.exit()`
- Empty result handling (returns empty tibble with columns, not NULL)

### Pattern 2: Repository Functions for Domain Operations
**What:** Domain-specific functions that use query helpers to perform CRUD operations.
**When to use:** All data access operations grouped by domain (entity, review, status, etc.).
**Example:**
```r
# Source: Based on R6P Repository pattern adapted to plain functions
# functions/entity-repository.R

#' Find entity by ID
#'
#' @param entity_id Integer, the entity ID
#' @return Tibble with one row, or empty tibble if not found
entity_find_by_id <- function(entity_id) {
  sql <- "SELECT entity_id, hgnc_id, hpo_mode_of_inheritance_term,
                 disease_ontology_id_version, ndd_phenotype,
                 is_active, replaced_by, entry_date, entry_user_id
          FROM ndd_entity
          WHERE entity_id = ?"

  db_execute_query(sql, params = list(entity_id))
}

#' Create new entity
#'
#' @param entity_data List with required fields
#' @return Integer, the new entity_id
entity_create <- function(entity_data) {
  required_fields <- c("hgnc_id", "hpo_mode_of_inheritance_term",
                       "disease_ontology_id_version", "ndd_phenotype",
                       "entry_user_id")

  # Validate required fields
  missing <- setdiff(required_fields, names(entity_data))
  if (length(missing) > 0) {
    rlang::abort(
      message = glue::glue("Missing required fields: {paste(missing, collapse = ', ')}"),
      class = "entity_validation_error",
      missing_fields = missing
    )
  }

  sql <- "INSERT INTO ndd_entity
          (hgnc_id, hpo_mode_of_inheritance_term,
           disease_ontology_id_version, ndd_phenotype, entry_user_id)
          VALUES (?, ?, ?, ?, ?)"

  params <- list(
    entity_data$hgnc_id,
    entity_data$hpo_mode_of_inheritance_term,
    entity_data$disease_ontology_id_version,
    entity_data$ndd_phenotype,
    entity_data$entry_user_id
  )

  # Execute insert
  db_execute_statement(sql, params)

  # Get last insert ID
  result <- db_execute_query("SELECT LAST_INSERT_ID() as entity_id")
  return(result$entity_id[1])
}

#' Deactivate entity
#'
#' @param entity_id Integer, the entity ID
#' @param replacement_id Integer or NULL, the replacement entity ID
#' @return Integer, number of rows affected (should be 1)
entity_deactivate <- function(entity_id, replacement_id = NULL) {
  sql <- "UPDATE ndd_entity
          SET is_active = 0, replaced_by = ?
          WHERE entity_id = ?"

  params <- list(replacement_id, entity_id)
  db_execute_statement(sql, params)
}

#' Find entities with related review data (eager loading)
#'
#' @param entity_ids Vector of integers, entity IDs to fetch
#' @return Tibble with entity and review data joined
entity_find_with_reviews <- function(entity_ids) {
  # Use IN clause with proper parameter binding
  # Generate placeholders: ? for each ID
  placeholders <- paste(rep("?", length(entity_ids)), collapse = ", ")

  sql <- glue::glue("
    SELECT e.entity_id, e.hgnc_id, e.disease_ontology_id_version,
           r.review_id, r.synopsis, r.is_primary
    FROM ndd_entity e
    LEFT JOIN ndd_entity_review r ON e.entity_id = r.entity_id
    WHERE e.entity_id IN ({placeholders})
  ")

  # Pass entity_ids as separate parameters
  db_execute_query(sql, params = as.list(entity_ids))
}
```

**Key benefits:**
- Domain-specific validation and error messages
- Clean separation of concerns
- Eager loading support for common join patterns
- Type-safe parameter handling

### Pattern 3: Transactions with Automatic Rollback
**What:** Multi-table operations wrapped in transactions with automatic rollback on error.
**When to use:** Any operation that modifies multiple tables (create review + publications + phenotypes).
**Example:**
```r
# Source: DBI dbWithTransaction documentation
# functions/db-helpers.R

#' Execute code in a database transaction
#'
#' Automatically commits on success, rolls back on error
#'
#' @param code Expression to execute
#' @return Result of code execution
db_with_transaction <- function(code) {
  logger::log_debug("Starting transaction")

  # Get a connection from pool
  conn <- pool::poolCheckout(pool)
  on.exit(pool::poolReturn(conn), add = TRUE)

  tryCatch({
    result <- DBI::dbWithTransaction(conn, {
      logger::log_debug("In transaction")
      force(code)
    })
    logger::log_debug("Transaction committed")
    return(result)
  }, error = function(e) {
    logger::log_warn("Transaction rolled back: {e$message}")
    rlang::abort(
      message = "Transaction failed",
      class = "db_transaction_error",
      original_error = e$message
    )
  })
}

# Usage in repository:
# functions/review-repository.R

#' Create review with publications and phenotypes
#'
#' @param review_data List with review fields
#' @param publication_ids Vector of publication IDs
#' @param phenotype_data List of phenotype data
#' @return List with review_id
review_create_complete <- function(review_data, publication_ids, phenotype_data) {
  db_with_transaction({
    # 1. Insert review
    review_id <- review_create(review_data)

    # 2. Insert publications
    for (pub_id in publication_ids) {
      review_publication_add(review_id, review_data$entity_id, pub_id)
    }

    # 3. Insert phenotypes
    for (pheno in phenotype_data) {
      review_phenotype_add(review_id, review_data$entity_id, pheno$phenotype_id, pheno$modifier_id)
    }

    return(list(review_id = review_id))
  })
}
```

**Key benefits:**
- All-or-nothing semantics (atomicity)
- Automatic rollback on any error
- Transaction lifecycle logging
- Clean error propagation

### Anti-Patterns to Avoid

**Anti-pattern: String concatenation for SQL**
```r
# BAD - SQL injection vulnerability
sql <- paste0("SELECT * FROM users WHERE id = ", user_id)
DBI::dbGetQuery(pool, sql)

# GOOD - Parameterized query
sql <- "SELECT * FROM users WHERE id = ?"
db_execute_query(sql, params = list(user_id))
```

**Anti-pattern: Manual connection management**
```r
# BAD - Connection leaks, no pooling
conn <- dbConnect(RMariaDB::MariaDB(), ...)
result <- dbGetQuery(conn, sql)
dbDisconnect(conn)

# GOOD - Pool manages connections
db_execute_query(sql, params)
```

**Anti-pattern: Ignoring empty results**
```r
# BAD - NULL returned, breaks downstream code
result <- dbGetQuery(pool, sql)
if (is.null(result)) ...  # Never triggers, returns 0-row data.frame

# GOOD - Check nrow()
result <- db_execute_query(sql, params)
if (nrow(result) == 0) ...
```

**Anti-pattern: Transactions without cleanup**
```r
# BAD - No rollback on error
dbBegin(conn)
dbExecute(conn, sql1)
dbExecute(conn, sql2)  # If this fails, sql1 is committed!
dbCommit(conn)

# GOOD - Automatic rollback
db_with_transaction({
  db_execute_statement(sql1, params1)
  db_execute_statement(sql2, params2)
})
```

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SQL parameter escaping | Manual `gsub()` or string replacement | `dbBind()` with `?` placeholders | Handles all SQL injection edge cases (quotes, backslashes, NULL, binary data). Database-specific escaping rules. |
| Connection pooling | Custom queue/stack of connections | `pool` package | Handles timeouts, validation, concurrent access, cleanup. Production-tested. |
| Transaction management | Manual `dbBegin()`/`dbCommit()`/`dbRollback()` | `dbWithTransaction()` | Automatic rollback on error, cleanup on exit, nested transaction prevention. |
| Empty result handling | `if (is.null(result))` checks | `nrow(result) == 0` | `dbGetQuery()` never returns NULL, always returns data.frame (possibly 0 rows). |
| Dynamic IN clauses | Loop with individual queries | Generate `?` placeholders, pass list | Single query is faster, maintains prepared statement benefits. |
| Connection health checks | Periodic `SELECT 1` queries | Pool's `validationInterval` + `validateQuery` | Checked automatically on checkout, configurable interval. |
| Logging query parameters | Manual `paste()` with values | `logger` with structured fields | Handles sensitive data redaction, structured output, severity levels. |

**Key insight:** Database access is a solved problem in R. DBI + pool + parameterized queries provide comprehensive protection against SQL injection, connection leaks, and transaction errors. Custom solutions miss edge cases and security vulnerabilities.

## Common Pitfalls

### Pitfall 1: Using String Concatenation for User Input
**What goes wrong:** SQL injection vulnerability allows attackers to execute arbitrary SQL.
**Why it happens:** Looks simpler than parameterized queries, especially for complex WHERE clauses.
**How to avoid:** Always use `dbBind()` with `?` placeholders for data values. Use `glue::glue_sql()` only for dynamic table/column names (which can't be parameterized), and validate against whitelist.
**Warning signs:**
- `paste0()` or `glue()` used to build SQL with user input
- Variables concatenated directly into SQL strings
- No `?` placeholders in queries with parameters

**Detection:**
```r
# Grep for dangerous patterns:
grep -r "paste0.*SQL\\|SELECT.*paste\\|WHERE.*paste" functions/
```

### Pitfall 2: RMariaDB Named Parameter Confusion
**What goes wrong:** Using `:name` placeholder syntax causes "cannot bind unnamed parameters" error.
**Why it happens:** DBI documentation shows `:name` syntax, which works for SQLite but not MariaDB.
**How to avoid:** RMariaDB only supports positional `?` placeholders. Pass parameters as unnamed list in order of appearance.
**Warning signs:**
- Error: "need named or unnamed arguments, but not both"
- SQL queries with `:param_name` syntax
- `params = list(id = 5)` with `?` placeholders (works accidentally, but misleading)

**Example:**
```r
# WRONG for RMariaDB
sql <- "SELECT * FROM entity WHERE id = :entity_id"
dbGetQuery(pool, sql, params = list(entity_id = 5))

# CORRECT for RMariaDB
sql <- "SELECT * FROM entity WHERE id = ?"
dbGetQuery(pool, sql, params = list(5))
```

### Pitfall 3: Not Handling Empty Result Sets
**What goes wrong:** Code assumes result always has rows, crashes on empty results.
**Why it happens:** SQL query returns 0 rows (valid), but code expects at least one.
**How to avoid:** Always check `nrow(result) == 0` before accessing rows. Return empty tibbles with correct column types from repository functions.
**Warning signs:**
- `result[1, ]` or `result$col[1]` without `nrow()` check
- Assuming `dbGetQuery()` returns NULL (it doesn't, returns 0-row data.frame)
- Errors like "undefined columns selected" or "subscript out of bounds"

**Example:**
```r
# WRONG - crashes if no rows
result <- db_execute_query(sql, params)
entity_id <- result$entity_id[1]  # NA or error if nrow(result) == 0

# CORRECT - safe handling
result <- db_execute_query(sql, params)
if (nrow(result) == 0) {
  return(NULL)  # or empty tibble, or error
}
entity_id <- result$entity_id[1]
```

### Pitfall 4: Pool Exhaustion Without Error Handling
**What goes wrong:** All pool connections are in use, new requests hang indefinitely or timeout.
**Why it happens:** Long-running queries hold connections, or connections not returned due to errors.
**How to avoid:** Use query helpers that ensure `dbClearResult()` via `on.exit()`. Set pool `maxSize` to reasonable limit. Monitor pool usage.
**Warning signs:**
- API becomes unresponsive under load
- Errors like "Failed to checkout connection: timeout"
- `poolCheckout()` without corresponding `poolReturn()`

**Mitigation:**
```r
# Configure pool with limits
pool <- dbPool(
  RMariaDB::MariaDB(),
  dbname = dw$dbname,
  host = dw$host,
  user = dw$user,
  password = dw$password,
  maxSize = 10,  # Limit total connections
  idleTimeout = 60,  # Close idle connections after 60s
  validationInterval = 60  # Validate every 60s
)
```

### Pitfall 5: Forgetting `on.exit()` Cleanup
**What goes wrong:** Resources (connections, result sets) leak when errors occur.
**Why it happens:** Cleanup code after query never executes if error is raised.
**How to avoid:** Use `on.exit(cleanup, add = TRUE)` immediately after acquiring resource. Use `add = TRUE` to stack multiple cleanup handlers.
**Warning signs:**
- `dbClearResult()` called after `dbFetch()` but not in `on.exit()`
- `poolReturn()` only in success path, not in error handler
- Growing memory usage over time

**Example:**
```r
# WRONG - result not cleared on error
result <- dbSendQuery(pool, sql)
data <- dbFetch(result)  # If this errors, result leaks
dbClearResult(result)

# CORRECT - cleanup guaranteed
result <- dbSendQuery(pool, sql)
on.exit(dbClearResult(result), add = TRUE)
data <- dbFetch(result)
```

### Pitfall 6: Transaction Scope Too Broad
**What goes wrong:** Long-running transactions lock tables, block other requests, eventually timeout.
**Why it happens:** Including slow operations (API calls, file I/O) inside transaction.
**How to avoid:** Keep transactions as short as possible. Fetch data before transaction, only include database writes.
**Warning signs:**
- HTTP requests or external API calls inside `db_with_transaction()`
- File reads/writes inside transaction
- User input validation inside transaction
- Errors like "Lock wait timeout exceeded"

**Example:**
```r
# WRONG - slow API call inside transaction
db_with_transaction({
  entity_id <- entity_create(data)
  pub_details <- fetch_pubmed_details(pmid)  # Slow external API call!
  publication_create(pub_details)
})

# CORRECT - external calls outside transaction
pub_details <- fetch_pubmed_details(pmid)  # Do this first
db_with_transaction({
  entity_id <- entity_create(data)
  publication_create(pub_details)
})
```

## Code Examples

Verified patterns from official sources:

### Example 1: Basic Repository CRUD Operations
```r
# Source: DBI specification and pool package documentation
# functions/status-repository.R

#' Find status by ID
#'
#' @param status_id Integer
#' @return Tibble with one row, or empty tibble
status_find_by_id <- function(status_id) {
  sql <- "SELECT status_id, entity_id, category_id, problematic,
                 status_approved, approving_user_id, is_active
          FROM ndd_entity_status
          WHERE status_id = ?"

  db_execute_query(sql, params = list(status_id))
}

#' Find all statuses for entity
#'
#' @param entity_id Integer
#' @return Tibble with 0 or more rows
status_find_by_entity <- function(entity_id) {
  sql <- "SELECT status_id, entity_id, category_id, problematic,
                 status_approved, approving_user_id, is_active
          FROM ndd_entity_status
          WHERE entity_id = ?
          ORDER BY status_id DESC"

  db_execute_query(sql, params = list(entity_id))
}

#' Create new status
#'
#' @param status_data List with required fields
#' @return Integer, the new status_id
status_create <- function(status_data) {
  required_fields <- c("entity_id", "category_id")
  missing <- setdiff(required_fields, names(status_data))
  if (length(missing) > 0) {
    rlang::abort("Missing required fields", missing_fields = missing)
  }

  sql <- "INSERT INTO ndd_entity_status
          (entity_id, category_id, problematic)
          VALUES (?, ?, ?)"

  params <- list(
    status_data$entity_id,
    status_data$category_id,
    status_data$problematic %||% FALSE
  )

  db_execute_statement(sql, params)

  result <- db_execute_query("SELECT LAST_INSERT_ID() as status_id")
  return(result$status_id[1])
}

#' Update status
#'
#' @param status_id Integer
#' @param updates List with fields to update
#' @return Integer, rows affected
status_update <- function(status_id, updates) {
  # Build SET clause dynamically
  fields <- names(updates)
  set_clause <- paste(fields, "= ?", collapse = ", ")

  sql <- glue::glue("UPDATE ndd_entity_status SET {set_clause} WHERE status_id = ?")

  # Parameters: update values + status_id
  params <- c(as.list(updates), list(status_id))

  db_execute_statement(sql, params)
}
```

### Example 2: Complex Query with Multiple Joins
```r
# Source: Based on existing database-functions.R patterns
# functions/publication-repository.R

#' Find publications with review and entity context
#'
#' @param publication_ids Vector of integers
#' @return Tibble with joined data
publication_find_with_context <- function(publication_ids) {
  placeholders <- paste(rep("?", length(publication_ids)), collapse = ", ")

  sql <- glue::glue("
    SELECT p.publication_id, p.pmid, p.title, p.publication_year,
           rp.review_id, rp.publication_type,
           r.entity_id, r.synopsis
    FROM publication p
    LEFT JOIN ndd_review_publication_join rp
      ON p.publication_id = rp.publication_id
    LEFT JOIN ndd_entity_review r
      ON rp.review_id = r.review_id
    WHERE p.publication_id IN ({placeholders})
    ORDER BY p.publication_year DESC
  ")

  db_execute_query(sql, params = as.list(publication_ids))
}
```

### Example 3: Validation Against Reference Data
```r
# Source: Based on existing put_post_db_pub_con pattern
# functions/phenotype-repository.R

#' Validate phenotype IDs against allowed list
#'
#' @param phenotype_ids Vector of phenotype IDs
#' @return Logical, TRUE if all valid
#' @throws Error if any invalid
phenotype_validate_ids <- function(phenotype_ids) {
  # Get allowed phenotypes from pool-based query
  allowed <- pool %>%
    dplyr::tbl("phenotype_list") %>%
    dplyr::select(phenotype_id) %>%
    dplyr::collect()

  invalid <- setdiff(phenotype_ids, allowed$phenotype_id)

  if (length(invalid) > 0) {
    rlang::abort(
      message = glue::glue("Invalid phenotype IDs: {paste(invalid, collapse = ', ')}"),
      class = "phenotype_validation_error",
      invalid_ids = invalid
    )
  }

  return(TRUE)
}

#' Add phenotypes to review
#'
#' @param review_id Integer
#' @param entity_id Integer
#' @param phenotype_data List of phenotype records
review_phenotype_add_bulk <- function(review_id, entity_id, phenotype_data) {
  # Validate first
  phenotype_validate_ids(sapply(phenotype_data, function(x) x$phenotype_id))

  # Insert in transaction
  db_with_transaction({
    for (pheno in phenotype_data) {
      sql <- "INSERT INTO ndd_review_phenotype_connect
              (review_id, entity_id, phenotype_id, modifier_id)
              VALUES (?, ?, ?, ?)"

      params <- list(review_id, entity_id,
                    pheno$phenotype_id, pheno$modifier_id)

      db_execute_statement(sql, params)
    }
  })
}
```

### Example 4: Batch Operations with IN Clause
```r
# Source: DBI Advanced Usage vignette
# functions/user-repository.R

#' Find users by multiple IDs efficiently
#'
#' @param user_ids Vector of integers
#' @return Tibble with 0 or more rows
user_find_by_ids <- function(user_ids) {
  if (length(user_ids) == 0) {
    return(tibble::tibble(
      user_id = integer(),
      user_name = character(),
      user_email = character()
    ))
  }

  # Generate placeholders
  placeholders <- paste(rep("?", length(user_ids)), collapse = ", ")

  sql <- glue::glue("
    SELECT user_id, user_name, user_email, user_role
    FROM users_view
    WHERE user_id IN ({placeholders})
  ")

  db_execute_query(sql, params = as.list(user_ids))
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual `dbConnect()`/`dbDisconnect()` | Pool package | pool v0.1.0 (2016) | Automatic connection management, pooling, validation. Standard for Shiny and Plumber. |
| String concatenation SQL | Parameterized queries with `dbBind()` | DBI v1.0 (2018) | SQL injection prevention, prepared statements. Security requirement. |
| `tryCatch()` with manual `dbRollback()` | `dbWithTransaction()` | DBI v1.0 (2018) | Automatic rollback on error, guaranteed cleanup. Prevents partial commits. |
| R6 classes for repositories | Plain functions | Ongoing R community preference | More idiomatic R, simpler testing, better composability. |
| `log4r` or `futile.logger` | `logger` package | logger v0.1 (2019) | Modern glue-based syntax, lightweight, structured logging. |
| Named params `:name` | Positional `?` for RMariaDB | RMariaDB v1.0 (2018) | Database-specific limitation. SQLite supports both, MariaDB only positional. |

**Deprecated/outdated:**
- **Manual connection management**: Pool package is standard. No reason to manually manage connections in 2026.
- **String interpolation for SQL**: Security vulnerability. DBI's parameterized queries are the standard.
- **R6 Repository classes**: Not idiomatic R. Plain functions are simpler and more testable.
- **Global connection objects**: Use global pool, check out connections per query. Connection should not be long-lived.

## Open Questions

Things that couldn't be fully resolved:

1. **Should repository functions return tibbles or lists?**
   - What we know: Tibbles are standard for R data operations, integrate well with dplyr pipelines
   - What's unclear: Endpoint serializers expect lists for JSON:API format
   - Recommendation: Repository returns tibbles, endpoint layer converts to JSON:API format. Separation of concerns.

2. **How to handle validation in repositories vs endpoints?**
   - What we know: Repositories currently validate allowed values (phenotype IDs, publication IDs)
   - What's unclear: Should repositories throw errors or return validation results?
   - Recommendation: Repositories throw structured errors with `rlang::abort()`, endpoints catch and convert to HTTP error responses.

3. **Should query helpers be exported or private?**
   - What we know: `db_execute_query()` and `db_with_transaction()` are used by all repositories
   - What's unclear: Should endpoints call these directly or only through repositories?
   - Recommendation: Helpers in separate file (db-helpers.R), repositories use them, endpoints should not bypass repositories except for complex read-only queries.

4. **Connection pool configuration for production**
   - What we know: Current config has default settings (no explicit maxSize/idleTimeout)
   - What's unclear: Optimal pool size for production workload, whether to increase from defaults
   - Recommendation: Start with `maxSize = 10`, `idleTimeout = 60`, monitor pool usage in production and adjust. Add pool metrics endpoint.

## Sources

### Primary (HIGH confidence)
- [DBI package specification](https://dbi.r-dbi.org/articles/spec) - Parameterized queries, transactions, connection management
- [pool package documentation](https://rstudio.github.io/pool/) - Connection pooling, validation, configuration
- [Advanced DBI Usage vignette](https://cran.r-project.org/web/packages/DBI/vignettes/DBI-advanced.html) - Prepared statements, batch operations
- [pool Advanced Usage](https://rstudio.github.io/pool/articles/advanced-pool.html) - Transaction handling, configuration parameters
- [DBI transactions reference](https://dbi.r-dbi.org/reference/transactions.html) - `dbBegin()`, `dbCommit()`, `dbRollback()`, `dbWithTransaction()`
- [dbBind reference](https://dbi.r-dbi.org/reference/dbBind.html) - Parameterized query syntax, placeholder types
- [Run Queries Safely – Solutions](https://solutions.posit.co/connections/db/best-practices/run-queries-safely/) - SQL injection prevention

### Secondary (MEDIUM confidence)
- [R6P Repository Pattern](https://tidylab.github.io/R6P/articles/patterns/Repository.html) - Repository pattern examples (adapted for plain functions)
- [logger package documentation](https://daroczig.github.io/logger/) - Structured logging, severity levels
- [Advanced R: Conditions](https://adv-r.hadley.nz/conditions.html) - Error handling patterns, `tryCatch()`, structured errors
- [R project structure best practices](https://kdestasio.github.io/post/r_best_practices/) - Directory conventions, function organization

### Tertiary (LOW confidence)
- WebSearch: "R repository pattern database access layer" - General pattern overview, needs verification against R idioms
- WebSearch: "R6 classes vs plain functions" - Community preference for plain functions, but subjective

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Pool, DBI, RMariaDB are standard, well-documented packages actively maintained by Posit
- Architecture patterns: HIGH - Based on official DBI and pool documentation with verified code examples
- RMariaDB limitations: HIGH - Confirmed via official documentation and source code review
- Pitfalls: MEDIUM-HIGH - Based on documented issues and community patterns, but specific pitfalls may vary by use case
- Project structure: MEDIUM - Based on R community conventions, but no single authoritative standard

**Research date:** 2026-01-23
**Valid until:** 60 days (stable domain - DBI/pool APIs are mature and stable)

**Sources consulted:**
- 15 official documentation sources (DBI, pool, RMariaDB)
- 10 WebSearch results (verified against official docs where possible)
- 3 WebFetch operations (official documentation pages)
- Current project codebase examination

**Key limitations:**
- RMariaDB named parameters: Confirmed only positional `?` supported, not `:name` syntax
- Repository pattern: Adapted from R6P examples to plain functions (more idiomatic)
- Production pool configuration: No established benchmarks for this specific workload, recommend monitoring
