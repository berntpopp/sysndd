# Architecture Patterns: v4 Backend Overhaul

**Domain:** R/Plumber API refactoring to DRY/KISS/SOLID compliance
**Researched:** 2026-01-23
**Confidence:** HIGH (Official documentation verified, multiple authoritative sources)

## Executive Summary

The SysNDD API's current architecture suffers from 8 identified SOLID violations, 66 SQL injection vulnerabilities, and significant code duplication across 21 endpoint files and 16 function files. The `database-functions.R` (1,234 lines) is a "god file" handling entity CRUD, reviews, publications, phenotypes, variation ontology, and approval workflows.

This architecture document defines patterns for refactoring to DRY/KISS/SOLID compliance:
- **Repository Pattern** for database access, eliminating 17 direct `dbConnect` calls
- **Service Layer** for business logic isolation
- **Middleware Chain** for cross-cutting concerns (auth, validation, error handling)
- **Response Builder** for consistent API responses
- **Parameterized Queries** for SQL injection prevention

**Key architectural shifts:**
- Monolithic `database-functions.R` decomposed into 6 domain-specific repositories
- Global state (`<<-`) eliminated via dependency injection through closures
- 100+ inconsistent error patterns unified via centralized error handler
- All SQL queries migrated to parameterized queries via `dbBind()` or `glue_sql()`

---

## Current Architecture Analysis

### Identified Issues

| Issue | Count | Impact |
|-------|-------|--------|
| Direct `dbConnect` calls (bypass pool) | 17 | Connection leaks, performance degradation |
| Global mutable state (`<<-`) | 15 | Testing difficulty, race conditions |
| SQL injection vulnerabilities | 66 | Security critical |
| Inconsistent error patterns | ~100 | Poor API UX, debugging difficulty |
| SRP violations (god functions) | 5 | Maintenance burden, testing complexity |
| DRY violations (auth checks) | 12 | Code duplication, inconsistent security |
| Response pattern duplications | 50+ | Inconsistent API responses |

### Current File Dependencies

```
start_sysndd_api.R
    |
    +-- functions/ (16 files, sourced globally)
    |       |
    |       +-- database-functions.R (1,234 lines - GOD FILE)
    |       +-- endpoint-functions.R (758 lines)
    |       +-- helper-functions.R (1,010 lines)
    |       +-- logging-functions.R (171 lines)
    |       +-- publication-functions.R
    |       +-- hpo-functions.R
    |       +-- hgnc-functions.R
    |       +-- ... (9 more)
    |
    +-- endpoints/ (22 files, mounted on router)
            |
            +-- entity_endpoints.R (uses database-functions, helper-functions)
            +-- gene_endpoints.R (uses helper-functions, pool directly)
            +-- review_endpoints.R (uses database-functions)
            +-- ... (19 more)
```

### Problem Patterns in Current Code

**1. God File (database-functions.R):**
```r
# Handles 8+ distinct responsibilities:
# - Entity CRUD (post_db_entity, put_db_entity_deactivation)
# - Review CRUD (put_post_db_review)
# - Publication connections (put_post_db_pub_con)
# - Phenotype connections (put_post_db_phen_con)
# - Variation ontology (put_post_db_var_ont_con)
# - Status management (put_post_db_status)
# - Approval workflows (put_db_review_approve, put_db_status_approve)
# - Hash generation (post_db_hash)
```

**2. Bypassing Connection Pool:**
```r
# Current pattern (17 occurrences):
sysndd_db <- dbConnect(RMariaDB::MariaDB(),
  dbname = dw$dbname, user = dw$user, password = dw$password,
  server = dw$server, host = dw$host, port = dw$port)
# ... do work ...
dbDisconnect(sysndd_db)
```

**3. SQL Injection Vulnerability:**
```r
# Current pattern (66 occurrences):
dbExecute(sysndd_db, paste0("UPDATE ndd_entity SET ",
  "is_active = 0, replaced_by = ", replacement,  # VULNERABLE
  " WHERE entity_id = ", entity_id, ";"))         # VULNERABLE
```

**4. Inconsistent Error Handling:**
```r
# Pattern A (returns list):
return(list(status = 200, message = "OK.", entry = id))

# Pattern B (sets res$status):
res$status <- 403
return(list(error = "Write access forbidden."))

# Pattern C (mixed):
res$status <- response$status
return(list(status = response$status, message = response$message))
```

**5. Duplicated Auth Checks:**
```r
# Repeated 12+ times across endpoints:
if (req$user_role %in% c("Administrator", "Curator")) {
  # ... business logic
} else {
  res$status <- 403
  return(list(error = "Write access forbidden."))
}
```

---

## Target Architecture

### Directory Structure

```
api/
├── start_sysndd_api.R              # Entry point (simplified)
├── config/
│   ├── api_spec.json               # OpenAPI examples (existing)
│   └── version_spec.json           # Version info (existing)
├── core/                           # NEW: Core infrastructure
│   ├── database.R                  # Connection pool factory
│   ├── response.R                  # Response builder functions
│   ├── errors.R                    # Error classes and handlers
│   └── middleware.R                # Middleware chain builder
├── repositories/                   # NEW: Domain repositories
│   ├── entity_repository.R         # Entity CRUD
│   ├── review_repository.R         # Review CRUD
│   ├── status_repository.R         # Status CRUD
│   ├── publication_repository.R    # Publication connections
│   ├── phenotype_repository.R      # Phenotype connections
│   ├── ontology_repository.R       # Variation ontology
│   ├── user_repository.R           # User management
│   └── hash_repository.R           # Hash storage
├── services/                       # NEW: Business logic layer
│   ├── entity_service.R            # Entity business rules
│   ├── review_service.R            # Review workflows
│   ├── approval_service.R          # Approval workflows
│   ├── auth_service.R              # Authentication logic
│   └── search_service.R            # Search/filter logic
├── middleware/                     # NEW: Plumber filters
│   ├── cors.R                      # CORS filter
│   ├── auth.R                      # JWT authentication
│   ├── logging.R                   # Request logging
│   ├── validation.R                # Input validation
│   └── error_handler.R             # Global error handler
├── endpoints/                      # REFACTORED: Thin controllers
│   ├── entity_endpoints.R          # Uses services, not DB directly
│   ├── gene_endpoints.R
│   ├── review_endpoints.R
│   └── ... (19 more)
├── functions/                      # REFACTORED: Pure utilities
│   ├── helper-functions.R          # Pagination, sorting, filtering
│   ├── file-functions.R            # File operations
│   └── external/                   # External API clients
│       ├── hgnc-client.R
│       ├── hpo-client.R
│       ├── ensembl-client.R
│       └── pubtator-client.R
└── tests/                          # ENHANCED: Test coverage
    └── testthat/
        ├── test-unit-repositories.R
        ├── test-unit-services.R
        ├── test-integration-endpoints.R
        └── helper-*.R
```

### Component Boundaries

| Layer | Responsibility | Dependencies | Depends On |
|-------|---------------|--------------|------------|
| **Endpoints** | HTTP routing, request parsing, response serialization | Services, Response Builder | Services |
| **Middleware** | Cross-cutting: auth, logging, validation, errors | Core infrastructure | Core |
| **Services** | Business logic, workflow orchestration | Repositories | Repositories |
| **Repositories** | Database CRUD, query building | Pool, Core | Pool |
| **Core** | Pool management, response formatting, error classes | Config | Config |

### Data Flow

```
HTTP Request
     |
     v
+------------------------+
|  Middleware Chain      |
|  - CORS Filter         |
|  - Auth Filter         |
|  - Logging Filter      |
|  - Validation Filter   |
+------------------------+
     |
     v
+------------------------+
|  Endpoint Handler      |
|  (Thin Controller)     |
+------------------------+
     |
     v
+------------------------+
|  Service Layer         |
|  (Business Logic)      |
+------------------------+
     |
     v
+------------------------+
|  Repository Layer      |
|  (Data Access)         |
+------------------------+
     |
     v
+------------------------+
|  Connection Pool       |
|  (Managed by core)     |
+------------------------+
     |
     v
+------------------------+
|  MariaDB Database      |
+------------------------+
```

---

## Pattern Implementation

### Pattern 1: Repository Pattern

**Purpose:** Encapsulate all database access for a domain, use parameterized queries, eliminate direct dbConnect calls.

**Example: entity_repository.R**

```r
# repositories/entity_repository.R

#' Create Entity Repository
#'
#' Factory function that returns repository functions with pool injected.
#' Follows dependency injection via closures pattern.
#'
#' @param pool Database connection pool
#' @return List of repository functions
#' @export
create_entity_repository <- function(pool) {

  #' Find Entity by ID
  #'
  #' @param entity_id Integer entity ID
  #' @return Tibble with entity data or NULL
  find_by_id <- function(entity_id) {
    pool %>%
      tbl("ndd_entity_view") %>%
      filter(entity_id == !!entity_id) %>%
      collect()
  }

  #' Create New Entity
  #'
  #' @param entity_data Tibble with entity fields

  #' @return Created entity ID
  insert <- function(entity_data) {
    # Use dbBind for parameterized insert
    query <- "INSERT INTO ndd_entity (hgnc_id, hpo_mode_of_inheritance_term,
              disease_ontology_id_version, ndd_phenotype, entry_user_id)
              VALUES (?, ?, ?, ?, ?)"

    conn <- pool::poolCheckout(pool)
    on.exit(pool::poolReturn(conn))

    stmt <- DBI::dbSendStatement(conn, query)
    DBI::dbBind(stmt, list(
      entity_data$hgnc_id,
      entity_data$hpo_mode_of_inheritance_term,
      entity_data$disease_ontology_id_version,
      entity_data$ndd_phenotype,
      entity_data$entry_user_id
    ))
    DBI::dbClearResult(stmt)

    # Get last insert ID
    result <- DBI::dbGetQuery(conn, "SELECT LAST_INSERT_ID() AS id")
    result$id
  }

  #' Deactivate Entity
  #'
  #' @param entity_id Entity to deactivate
  #' @param replacement_id Optional replacement entity
  #' @return Number of affected rows
  deactivate <- function(entity_id, replacement_id = NULL) {
    query <- "UPDATE ndd_entity SET is_active = 0, replaced_by = ?
              WHERE entity_id = ?"

    conn <- pool::poolCheckout(pool)
    on.exit(pool::poolReturn(conn))

    stmt <- DBI::dbSendStatement(conn, query)
    DBI::dbBind(stmt, list(replacement_id, entity_id))
    affected <- DBI::dbGetRowsAffected(stmt)
    DBI::dbClearResult(stmt)
    affected
  }

  #' List Entities with Pagination
  #'
  #' @param sort_exprs Sorting expressions
  #' @param filter_exprs Filter expressions
  #' @param page_after Cursor position
  #' @param page_size Number of results
  #' @return Tibble with paginated results
  list_paginated <- function(sort_exprs = "entity_id",
                             filter_exprs = "",
                             page_after = 0,
                             page_size = 10) {
    base_query <- pool %>%
      tbl("ndd_entity_view")

    if (filter_exprs != "") {
      base_query <- base_query %>%
        filter(!!!rlang::parse_exprs(filter_exprs))
    }

    base_query %>%
      arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
      collect()
  }

  # Return repository interface
  list(
    find_by_id = find_by_id,
    insert = insert,
    deactivate = deactivate,
    list_paginated = list_paginated
  )
}
```

**Benefits:**
- SQL injection prevented via parameterized queries
- Connection pool always used (no direct dbConnect)
- Single point of change for entity data access
- Testable via mock pool injection

---

### Pattern 2: Service Layer

**Purpose:** Encapsulate business logic and workflow orchestration, separate from HTTP concerns.

**Example: entity_service.R**

```r
# services/entity_service.R

#' Create Entity Service
#'
#' @param entity_repo Entity repository
#' @param review_repo Review repository
#' @param status_repo Status repository
#' @param publication_repo Publication repository
#' @param phenotype_repo Phenotype repository
#' @param ontology_repo Variation ontology repository
#' @return List of service functions
#' @export
create_entity_service <- function(entity_repo, review_repo, status_repo,
                                   publication_repo, phenotype_repo,
                                   ontology_repo) {

  #' Create Complete Entity with Review and Status
  #'
  #' Orchestrates the complete entity creation workflow:
  #' 1. Create entity record
  #' 2. Create initial review with synopsis
  #' 3. Create publication connections
  #' 4. Create phenotype connections
  #' 5. Create variation ontology connections
  #' 6. Create initial status
  #' 7. Optionally auto-approve
  #'
  #' @param create_data List with entity, review, status data
  #' @param user_id ID of creating user
  #' @param direct_approval Whether to auto-approve
  #' @return List with status, message, and created entity_id
  create_entity <- function(create_data, user_id, direct_approval = FALSE) {

    # Validate required fields
    validate_entity_input(create_data$entity)

    # Set user IDs
    create_data$entity$entry_user_id <- user_id

    # Step 1: Create entity
    entity_id <- entity_repo$insert(create_data$entity)

    if (is.null(entity_id)) {
      api_error("Failed to create entity", 500)
    }

    # Step 2: Create review
    review_data <- prepare_review_data(create_data$review, entity_id, user_id)
    review_result <- review_repo$insert(review_data)

    if (review_result$status != 200) {
      # Rollback: deactivate entity
      entity_repo$deactivate(entity_id)
      api_error(review_result$message, review_result$status)
    }

    review_id <- review_result$entry$review_id

    # Step 3: Create publication connections (if provided)
    if (length(purrr::compact(create_data$review$literature)) > 0) {
      publications <- prepare_publications(create_data$review$literature)
      publication_repo$create_connections(publications, entity_id, review_id)
    }

    # Step 4: Create phenotype connections (if provided)
    if (length(purrr::compact(create_data$review$phenotypes)) > 0) {
      phenotype_repo$create_connections(
        create_data$review$phenotypes, entity_id, review_id
      )
    }

    # Step 5: Create variation ontology connections (if provided)
    if (length(purrr::compact(create_data$review$variation_ontology)) > 0) {
      ontology_repo$create_connections(
        create_data$review$variation_ontology, entity_id, review_id
      )
    }

    # Step 6: Create status
    status_data <- tibble::tibble(
      entity_id = entity_id,
      category_id = create_data$status$category_id,
      status_user_id = user_id,
      comment = create_data$status$comment,
      problematic = create_data$status$problematic
    )
    status_result <- status_repo$insert(status_data)

    # Step 7: Auto-approve if requested
    if (direct_approval) {
      review_repo$approve(review_id, user_id, TRUE)
      status_repo$approve(status_result$entry, user_id, TRUE)
    }

    list(
      status = 200,
      message = "OK. Entity created.",
      entry = list(entity_id = entity_id)
    )
  }

  #' Validate Entity Input
  validate_entity_input <- function(entity) {
    required <- c("hgnc_id", "hpo_mode_of_inheritance_term",
                  "disease_ontology_id_version", "ndd_phenotype")

    missing <- required[!required %in% names(entity)]
    if (length(missing) > 0) {
      validation_error(paste("Missing required fields:", paste(missing, collapse = ", ")))
    }
  }

  #' Prepare Review Data
  prepare_review_data <- function(review, entity_id, user_id) {
    tibble::tibble(
      entity_id = entity_id,
      synopsis = review$synopsis %||% NA_character_,
      review_user_id = user_id,
      comment = review$comment %||% NA_character_
    )
  }

  # Return service interface
  list(
    create_entity = create_entity
  )
}
```

**Benefits:**
- Business logic isolated from HTTP concerns
- Workflow orchestration in one place
- Repositories injected (testable with mocks)
- Clear transaction boundaries

---

### Pattern 3: Middleware Chain

**Purpose:** Handle cross-cutting concerns (auth, validation, logging, errors) in reusable filters.

**Example: middleware/auth.R**

```r
# middleware/auth.R

#' Create Authentication Filter
#'
#' Factory that returns auth filter with config injected.
#'
#' @param secret JWT secret key
#' @param public_paths Paths that don't require auth
#' @return Plumber filter function
#' @export
create_auth_filter <- function(secret, public_paths = c()) {

  key <- charToRaw(secret)

  function(req, res) {
    # Public paths bypass auth
    if (is_public_path(req, public_paths)) {
      return(plumber::forward())
    }

    # GET without auth is allowed (public read)
    if (req$REQUEST_METHOD == "GET" && is.null(req$HTTP_AUTHORIZATION)) {
      return(plumber::forward())
    }

    # All other requests require valid token
    if (is.null(req$HTTP_AUTHORIZATION)) {
      auth_error("Authorization header missing")
    }

    jwt <- stringr::str_remove(req$HTTP_AUTHORIZATION, "Bearer ")

    tryCatch({
      user <- jose::jwt_decode_hmac(jwt, secret = key)

      if (user$exp < as.numeric(Sys.time())) {
        auth_error("Token expired")
      }

      # Attach user info to request
      req$user_id <- as.integer(user$user_id)
      req$user_role <- user$user_role
      req$user_name <- user$user_name

      plumber::forward()

    }, error = function(e) {
      auth_error("Invalid token")
    })
  }
}

#' Check if Path is Public
is_public_path <- function(req, public_paths) {
  path <- req$PATH_INFO
  method <- req$REQUEST_METHOD

  for (public in public_paths) {
    if (grepl(public$pattern, path) && method %in% public$methods) {
      return(TRUE)
    }
  }
  FALSE
}
```

**Example: middleware/error_handler.R**

```r
# middleware/error_handler.R

#' Create Global Error Handler
#'
#' Handles all errors, distinguishing operational from programmer errors.
#' Operational errors (api_error) return user-friendly messages.
#' Programmer errors return generic 500 and are logged.
#'
#' @return Error handler function for pr_set_error()
#' @export
create_error_handler <- function() {

  function(req, res, err) {

    # Operational errors (user-facing)
    if (inherits(err, "api_error")) {
      res$status <- err$status
      return(list(
        status = err$status,
        error = err$message
      ))
    }

    # Programmer errors (log, return generic)
    logger::log_error(paste(
      "Unhandled error:",
      conditionMessage(err),
      "\nStack:",
      paste(capture.output(traceback()), collapse = "\n")
    ))

    res$status <- 500
    list(
      status = 500,
      error = "Internal server error"
    )
  }
}
```

**Example: core/errors.R**

```r
# core/errors.R

#' Create Operational API Error
#'
#' Signals an operational error that should be returned to the user.
#' Classified as 4xx (client error) or specific 5xx.
#'
#' @param message Error message for user
#' @param status HTTP status code (default 400)
#' @export
api_error <- function(message, status = 400) {
  err <- structure(
    list(message = message, status = status),
    class = c("api_error", "error", "condition")
  )
  stop(err)
}

#' Authentication Error (401)
#' @export
auth_error <- function(message = "Authentication required") {
  api_error(message, 401)
}

#' Authorization Error (403)
#' @export
forbidden_error <- function(message = "Access forbidden") {
  api_error(message, 403)
}

#' Not Found Error (404)
#' @export
not_found_error <- function(message = "Resource not found") {
  api_error(message, 404)
}

#' Validation Error (400)
#' @export
validation_error <- function(message = "Invalid input") {
  api_error(message, 400)
}
```

---

### Pattern 4: Response Builder

**Purpose:** Standardize all API responses with consistent structure.

**Example: core/response.R**

```r
# core/response.R

#' Build Success Response
#'
#' @param data Response data
#' @param message Optional message
#' @param links Optional pagination links
#' @param meta Optional metadata
#' @return List with consistent structure
#' @export
success_response <- function(data, message = "OK", links = NULL, meta = NULL) {
  response <- list(
    status = 200,
    message = message,
    data = data
  )

  if (!is.null(links)) response$links <- links
  if (!is.null(meta)) response$meta <- meta

  response
}

#' Build Created Response
#'
#' @param entry Created entity/ID
#' @param message Optional message
#' @return List with 201 status
#' @export
created_response <- function(entry, message = "Resource created") {
  list(
    status = 201,
    message = message,
    entry = entry
  )
}

#' Build Paginated Response
#'
#' @param data Tibble of results
#' @param pagination Pagination info from helper
#' @param meta Additional metadata
#' @return List with links, meta, and data
#' @export
paginated_response <- function(data, pagination, meta = list()) {
  list(
    links = pagination$links,
    meta = c(pagination$meta, meta),
    data = pagination$data
  )
}
```

---

### Pattern 5: Thin Endpoint (Controller)

**Purpose:** Endpoints become thin controllers that delegate to services.

**Example: endpoints/entity_endpoints.R (refactored)**

```r
# endpoints/entity_endpoints.R

#* @plumber
function(pr) {
  # Get injected dependencies
  entity_service <- .GlobalEnv$services$entity
  response <- .GlobalEnv$core$response

  pr %>%

    #* Get Paginated Entities
    #* @tag entity
    #* @serializer json list(na="string")
    #* @get /
    pr_get("/", function(req, res,
                         sort = "entity_id",
                         filter = "",
                         fields = "",
                         page_after = 0,
                         page_size = "10",
                         fspec = "entity_id,symbol,...") {

      result <- entity_service$list_entities(
        sort = sort,
        filter = filter,
        fields = fields,
        page_after = page_after,
        page_size = page_size,
        fspec = fspec
      )

      response$paginated_response(result$data, result$pagination, result$meta)
    }) %>%

    #* Create New Entity
    #* @tag entity
    #* @serializer json list(na="string")
    #* @post /create
    pr_post("/create", function(req, res, direct_approval = FALSE) {

      # Role check via middleware sets req$user_role
      require_role(req, c("Administrator", "Curator"))

      result <- entity_service$create_entity(
        create_data = req$argsBody$create_json,
        user_id = req$user_id,
        direct_approval = as.logical(direct_approval)
      )

      res$status <- result$status
      response$created_response(result$entry, result$message)
    }) %>%

    #* Deactivate Entity
    #* @tag entity
    #* @serializer json list(na="string")
    #* @post /deactivate
    pr_post("/deactivate", function(req, res) {

      require_role(req, c("Administrator", "Curator"))

      result <- entity_service$deactivate_entity(
        deactivate_data = req$argsBody$deactivate_json,
        user_id = req$user_id
      )

      res$status <- result$status
      response$success_response(NULL, result$message)
    })
}

#' Require User Role
#' @param req Request object
#' @param allowed_roles Vector of allowed role names
require_role <- function(req, allowed_roles) {
  if (is.null(req$user_role) || !(req$user_role %in% allowed_roles)) {
    forbidden_error("Insufficient permissions")
  }
}
```

---

### Pattern 6: Dependency Injection Setup

**Purpose:** Wire all components together at startup.

**Example: start_sysndd_api.R (refactored)**

```r
# start_sysndd_api.R

# 1. Load configuration
dw <- config::get(Sys.getenv("API_CONFIG"))

# 2. Create database pool
pool <- pool::dbPool(
  drv = RMariaDB::MariaDB(),
  dbname = dw$dbname,
  host = dw$host,
  user = dw$user,
  password = dw$password,
  port = dw$port
)

# 3. Source core modules
source("core/database.R")
source("core/errors.R")
source("core/response.R")

# 4. Create repositories (inject pool)
repositories <- list(
  entity = create_entity_repository(pool),
  review = create_review_repository(pool),
  status = create_status_repository(pool),
  publication = create_publication_repository(pool),
  phenotype = create_phenotype_repository(pool),
  ontology = create_ontology_repository(pool),
  user = create_user_repository(pool),
  hash = create_hash_repository(pool)
)

# 5. Create services (inject repositories)
services <- list(
  entity = create_entity_service(
    repositories$entity,
    repositories$review,
    repositories$status,
    repositories$publication,
    repositories$phenotype,
    repositories$ontology
  ),
  review = create_review_service(repositories$review),
  auth = create_auth_service(repositories$user, dw$secret)
)

# 6. Store in global env for endpoint access
.GlobalEnv$pool <- pool
.GlobalEnv$repositories <- repositories
.GlobalEnv$services <- services
.GlobalEnv$core <- list(
  response = list(
    success_response = success_response,
    created_response = created_response,
    paginated_response = paginated_response
  )
)

# 7. Create middleware
cors_filter <- create_cors_filter()
auth_filter <- create_auth_filter(dw$secret, public_paths = list(
  list(pattern = "^/health", methods = c("GET")),
  list(pattern = "^/api/auth/authenticate", methods = c("GET")),
  list(pattern = "^/api/gene/hash$", methods = c("POST"))
))
logging_filter <- create_logging_filter(pool)
error_handler <- create_error_handler()

# 8. Build router
root <- pr() %>%
  pr_set_api_spec(create_api_spec) %>%
  pr_filter("cors", cors_filter) %>%
  pr_filter("auth", auth_filter) %>%
  pr_filter("logging", logging_filter) %>%
  pr_set_error(error_handler) %>%
  pr_hook("exit", function() { pool::poolClose(pool) }) %>%
  # Mount endpoints
  pr_mount("/health", pr("endpoints/health_endpoints.R")) %>%
  pr_mount("/api/entity", pr("endpoints/entity_endpoints.R")) %>%
  pr_mount("/api/gene", pr("endpoints/gene_endpoints.R")) %>%
  # ... mount remaining endpoints
  pr_run(host = "0.0.0.0", port = as.numeric(dw$port_self))
```

---

## Migration Strategy

### Phase-Based Incremental Approach

**CRITICAL:** Do not attempt big-bang refactoring. Each phase should be independently deployable and testable.

### Phase 1: Core Infrastructure (Foundation)

**Goal:** Create core modules without breaking existing code.

**Tasks:**
1. Create `core/errors.R` with error classes
2. Create `core/response.R` with response builders
3. Create `middleware/error_handler.R`
4. Add global error handler to `start_sysndd_api.R`
5. Write unit tests for error handling

**Dependencies:** None
**Risk:** LOW - Additive only
**Estimated Effort:** 1-2 days

### Phase 2: Repository Layer (First Domain)

**Goal:** Extract entity repository, prove the pattern works.

**Tasks:**
1. Create `repositories/entity_repository.R`
2. Migrate all entity queries to parameterized queries
3. Update `database-functions.R` to use repository internally
4. Keep existing API contract unchanged
5. Add integration tests for repository

**Dependencies:** Phase 1 complete
**Risk:** MEDIUM - First real refactoring
**Estimated Effort:** 3-4 days

### Phase 3: Remaining Repositories

**Goal:** Extract all domain repositories.

**Tasks:**
1. Create `review_repository.R`
2. Create `status_repository.R`
3. Create `publication_repository.R`
4. Create `phenotype_repository.R`
5. Create `ontology_repository.R`
6. Create `user_repository.R`
7. Migrate all SQL to parameterized queries (eliminate 66 injection points)

**Dependencies:** Phase 2 complete
**Risk:** MEDIUM - Bulk migration
**Estimated Effort:** 5-7 days

### Phase 4: Service Layer

**Goal:** Extract business logic from endpoints to services.

**Tasks:**
1. Create `entity_service.R` with workflow logic
2. Create `review_service.R`
3. Create `approval_service.R`
4. Create `auth_service.R`
5. Refactor endpoints to delegate to services
6. Ensure consistent error handling via api_error()

**Dependencies:** Phase 3 complete
**Risk:** HIGH - Changes business logic location
**Estimated Effort:** 5-7 days

### Phase 5: Middleware Consolidation

**Goal:** Centralize cross-cutting concerns.

**Tasks:**
1. Extract CORS filter to `middleware/cors.R`
2. Extract auth filter to `middleware/auth.R`
3. Extract logging to `middleware/logging.R`
4. Create `middleware/validation.R` for input validation
5. Remove duplicate auth checks from endpoints (12 occurrences)

**Dependencies:** Phase 4 complete
**Risk:** MEDIUM - Auth logic changes
**Estimated Effort:** 2-3 days

### Phase 6: Response Standardization

**Goal:** Consistent API responses across all endpoints.

**Tasks:**
1. Audit all endpoints for response patterns
2. Replace 100+ inconsistent patterns with response builders
3. Update API documentation to reflect standard responses
4. Add response validation tests

**Dependencies:** Phase 5 complete
**Risk:** LOW - Response format changes
**Estimated Effort:** 3-4 days

### Phase 7: Cleanup and Optimization

**Goal:** Remove dead code, optimize performance.

**Tasks:**
1. Delete unused functions from `database-functions.R`
2. Delete `database-functions.R` if completely migrated
3. Review and remove unused helper functions
4. Add comprehensive test coverage (target: 80%)
5. Performance testing and optimization

**Dependencies:** Phase 6 complete
**Risk:** LOW - Cleanup only
**Estimated Effort:** 2-3 days

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Over-Engineering with R6 Classes

**What:** Using R6 for every component (repositories, services)
**Why Bad:** R6 adds complexity, reference semantics confuse R users
**Instead:** Use factory functions returning lists of closures (shown in patterns above)

### Anti-Pattern 2: Global State for Convenience

**What:** Using `<<-` to set package-level variables
**Why Bad:** Testing difficulty, race conditions, hidden dependencies
**Instead:** Inject dependencies via factory function parameters

### Anti-Pattern 3: Mixing HTTP and Business Logic

**What:** Response building inside service functions
**Why Bad:** Services become untestable without HTTP context
**Instead:** Services return data, endpoints build responses

### Anti-Pattern 4: One Repository per Table

**What:** Creating `ndd_entity_repository.R`, `ndd_entity_review_repository.R`, etc.
**Why Bad:** Over-fragmentation, explosion of small files
**Instead:** Domain-based repositories (entity_repository handles entity + related joins)

### Anti-Pattern 5: Premature Abstraction

**What:** Creating BaseRepository, AbstractService before needed
**Why Bad:** YAGNI - adds complexity without solving problems
**Instead:** Start concrete, extract abstractions when patterns repeat 3+ times

---

## Testing Strategy

### Unit Tests for Repositories

```r
# tests/testthat/test-unit-entity-repository.R

test_that("entity_repository$find_by_id returns entity", {
  # Mock pool that returns canned data
  mock_pool <- create_mock_pool(
    ndd_entity_view = tibble::tibble(
      entity_id = 1,
      hgnc_id = "HGNC:123",
      symbol = "TEST"
    )
  )

  repo <- create_entity_repository(mock_pool)
  result <- repo$find_by_id(1)

  expect_equal(nrow(result), 1)
  expect_equal(result$entity_id, 1)
})
```

### Integration Tests for Endpoints

```r
# tests/testthat/test-integration-entity.R

test_that("GET /api/entity returns paginated entities", {
  # Use callr to spawn background API
  bg <- callr::r_bg(function() {
    source("start_sysndd_api.R")
  })
  on.exit(bg$kill())

  Sys.sleep(2) # Wait for startup

  resp <- httr::GET("http://localhost:8080/api/entity?page_size=5")

  expect_equal(httr::status_code(resp), 200)
  body <- httr::content(resp, as = "parsed")
  expect_true("data" %in% names(body))
  expect_true("links" %in% names(body))
})
```

---

## Scalability Considerations

| Concern | Current | At Scale | Recommendation |
|---------|---------|----------|----------------|
| **Connection Pool** | Single global pool | May exhaust connections | Configure pool size based on load testing |
| **Query Caching** | Memoise at function level | Memory pressure | Move to Redis/external cache |
| **Response Size** | Full tibbles returned | Large memory per request | Streaming responses for large datasets |
| **Background Jobs** | None | Blocking for long operations | Use `future` for async processing |

---

## Integration Points

### New Components to Create

| Component | Location | Purpose |
|-----------|----------|---------|
| `core/errors.R` | NEW | Error classes (api_error, auth_error, etc.) |
| `core/response.R` | NEW | Response builders |
| `middleware/error_handler.R` | NEW | Global error handler |
| `middleware/auth.R` | EXTRACTED | Auth filter (from start_sysndd_api.R) |
| `repositories/*.R` | NEW (8 files) | Domain repositories |
| `services/*.R` | NEW (5 files) | Business logic services |

### Modified Components

| Component | Changes |
|-----------|---------|
| `start_sysndd_api.R` | Wire DI, use new filters |
| `endpoints/*.R` (22 files) | Delegate to services, use response builders |
| `functions/database-functions.R` | Gradually empty as code moves to repositories |
| `functions/helper-functions.R` | Keep pagination/filtering helpers, remove business logic |

### Components to Delete (after migration)

| Component | Reason |
|-----------|--------|
| `functions/database-functions.R` | Replaced by repositories |
| Direct dbConnect in functions | Replaced by pool via repositories |
| Inline auth checks (12 occurrences) | Replaced by middleware |
| Inconsistent error returns | Replaced by api_error() |

---

## Build Order

The following order ensures each step has its dependencies satisfied:

```
Week 1:
  Day 1-2: Phase 1 (Core Infrastructure)
           - core/errors.R
           - core/response.R
           - middleware/error_handler.R

Week 2:
  Day 3-6: Phase 2 (Entity Repository - Proof of Pattern)
           - repositories/entity_repository.R
           - Migrate entity queries to parameterized
           - Integration tests

Week 3:
  Day 7-13: Phase 3 (Remaining Repositories)
            - All 7 remaining repositories
            - All SQL injection points eliminated

Week 4:
  Day 14-20: Phase 4 (Service Layer)
             - Extract business logic to services
             - Refactor endpoint handlers

Week 5:
  Day 21-23: Phase 5 (Middleware Consolidation)
             - Centralize auth, CORS, logging
             - Remove duplicate auth checks

Week 5-6:
  Day 24-27: Phase 6 (Response Standardization)
             - Consistent responses across all endpoints

Week 6:
  Day 28-30: Phase 7 (Cleanup)
             - Remove dead code
             - Performance optimization
             - Documentation
```

---

## Sources

### Official Documentation (HIGH Confidence)
- [Plumber Official Documentation](https://www.rplumber.io/)
- [Plumber Programmatic Usage](https://www.rplumber.io/articles/programmatic-usage.html)
- [Plumber Routing & Filters](https://rplumber.io/docs/routing-and-input.html#filters)
- [DBI Parameterized Queries](https://dbi.r-dbi.org/articles/DBI-advanced.html)
- [Posit: Run Queries Safely](https://solutions.posit.co/connections/db/best-practices/run-queries-safely/)
- [R6 Introduction](https://r6.r-lib.org/articles/Introduction.html)

### Community Resources (MEDIUM Confidence)
- [Practical Plumber Patterns (ppp)](https://github.com/blairj09-talks/ppp)
- [sol-eng/plumbpkg](https://github.com/sol-eng/plumbpkg)
- [Structured Errors in Plumber APIs](https://unconj.ca/blog/structured-errors-in-plumber-apis.html)
- [R Plumber: Error Responses (Appsilon)](https://www.appsilon.com/post/api-oopsies-101)
- [Advanced R: R6 Chapter](https://adv-r.hadley.nz/r6.html)
- [JfrAziz/r-plumber Boilerplate](https://github.com/JfrAziz/r-plumber)
- [Jafar Aziz Plumber Tutorial Series](https://jafaraziz.com/blog/rest-api-with-r-part-1/)

### Security Resources (HIGH Confidence)
- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [DBI dbBind Documentation](https://search.r-project.org/CRAN/refmans/DBI/html/dbBind.html)
- [glue_sql for Safe Interpolation](https://glue.tidyverse.org/reference/glue_sql.html)

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Repository Pattern | HIGH | Well-established pattern, verified with DBI docs |
| Parameterized Queries | HIGH | Official DBI documentation, OWASP recommendations |
| Error Handling | HIGH | Plumber docs, multiple verified tutorials |
| Middleware Pattern | HIGH | Official Plumber filter documentation |
| Response Builder | MEDIUM | Community convention, adapted to R |
| Service Layer | MEDIUM | Adapted from OOP patterns, not R-specific |
| Migration Strategy | MEDIUM | Based on incremental refactoring principles |
| Build Order | HIGH | Dependency-based ordering |

**Overall Architecture Confidence:** HIGH

The architecture recommendations are based on official Plumber documentation, DBI parameterized query specifications, and verified community patterns. The phased migration approach allows for incremental risk mitigation and independent deployment of each phase.
