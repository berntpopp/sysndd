# Phase 22: Service Layer & Middleware - Research

**Researched:** 2026-01-24
**Domain:** R/Plumber middleware, service layer architecture, and API refactoring patterns
**Confidence:** HIGH

## Summary

Phase 22 implements clean separation between HTTP handling (endpoints), business logic (services), and cross-cutting concerns (middleware) in the R/Plumber API. The current codebase has 12 duplicated authentication checks across endpoints, 121 manual `res$status <-` assignments creating inconsistent response patterns, a 1,226-line `database-functions.R` god file mixing multiple domains, and 15 usages of global mutable state via `<<-`.

**Core findings:**
- Plumber filters provide middleware functionality with three patterns: forward-with-mutation, early-return, and error-throwing
- Authentication middleware uses allowlist pattern — global filter checks all requests, `plumber::forward()` for allowed endpoints, early-return for auth failures
- 401 vs 403 distinction: 401 = authentication missing/failed, 403 = authenticated but insufficient permissions
- Service layer uses plain R functions (not R6 classes) in `services/` directory, matching Phase 21 repository pattern
- Global state elimination via dependency injection: pass `pool` and `config` as function parameters instead of using `<<-`
- Current project already has `httpproblems` package for RFC 9457 error responses and `core/errors.R` helpers
- Integration testing with `testthat` + `callthat` package for in-package Plumber API testing

**Primary recommendation:** Create `require_auth()` and `require_role(min_role)` filters in `core/middleware.R` using allowlist pattern, extract business logic from endpoints into domain services in `services/` directory (entity-service.R, user-service.R, etc.), decompose `database-functions.R` by moving domain functions to corresponding services, eliminate `<<-` by passing dependencies as parameters, and use existing `httpproblems` helpers for consistent RFC 9457 error responses.

## Standard Stack

The established libraries/tools for service layer and middleware in R/Plumber:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| plumber | Latest (Dec 2025) | API framework with filter support | Official R API framework. Filters enable middleware pattern. Already in project. |
| httpproblems | Latest (July 2025) | RFC 9457 error responses | Standard Problem Details format for HTTP APIs. Already in project. |
| logger | 0.3.0 | Structured logging | Lightweight with glue syntax and DEBUG levels. Already in project. |
| rlang | Latest | Error conditions with classes | Enables typed errors for middleware handling. Already in tidyverse. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| testthat | 3.3.2 (Jan 2026) | Unit testing framework | Integration tests for service layer. Already in dev dependencies. |
| callthat | Latest | Test Plumber APIs in packages | Testing endpoints with testthat. Install if not present. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Plain functions | R6 service classes | R6 provides OOP encapsulation but is less idiomatic in R. Plain functions are standard for R packages. |
| Plumber filters | Custom middleware wrapper | Filters are native Plumber feature with proper lifecycle management. Don't reinvent. |
| httpproblems | Manual error objects | RFC 9457 compliance requires specific fields. httpproblems already implements spec. |

**Installation:**
```r
# All core packages already in project
# Optional: callthat for API testing
install.packages("callthat")
```

## Architecture Patterns

### Recommended Project Structure
```
api/
├── core/
│   ├── middleware.R              # NEW: require_auth, require_role filters
│   ├── errors.R                  # EXISTS: httpproblems helpers (already has error_unauthorized, etc.)
│   ├── responses.R               # EXISTS: response_success, response_error
│   ├── security.R                # EXISTS: password hashing utilities
│   └── logging_sanitizer.R       # EXISTS: sanitize sensitive data in logs
├── services/
│   ├── entity-service.R          # NEW: Entity business logic
│   ├── user-service.R            # NEW: User business logic
│   ├── review-service.R          # NEW: Review business logic
│   ├── approval-service.R        # NEW: Approval workflow logic
│   ├── auth-service.R            # NEW: Authentication/token logic
│   └── search-service.R          # NEW: Search functionality
├── functions/
│   ├── entity-repository.R       # Phase 21: Data access layer
│   ├── user-repository.R         # Phase 21: Data access layer
│   ├── database-functions.R      # DELETE: Decompose into services
│   └── helper-functions.R        # KEEP: Cross-cutting utilities (generate_hash, etc.)
├── endpoints/
│   └── *_endpoints.R             # REFACTOR: Thin handlers calling services
└── start_sysndd_api.R            # UPDATE: Register middleware filters
```

**Naming conventions:**
- Middleware: `require_<something>()` (imperative verb)
- Service files: `<domain>-service.R` (singular, hyphenated)
- Service functions: `<domain>_<action>()` (e.g., `entity_create()`, `auth_validate_token()`)

### Pattern 1: Authentication Middleware with Allowlist
**What:** Global filter that checks authentication for all requests except explicitly allowed public endpoints.
**When to use:** When most endpoints require auth but some are public.
**Example:**
```r
# Source: Plumber filters documentation + Phase 22 context decisions
# core/middleware.R

# Public endpoints that bypass authentication
AUTH_ALLOWLIST <- c(
  "/api/gene/hash",
  "/api/entity/hash",
  "/api/jobs/clustering/submit",
  "/api/jobs/phenotype_clustering/submit",
  "/api/user/password/reset/request",
  "/api/authentication/signin",
  "/api/authentication/verify",
  "/api/authentication/refresh",
  "/api/health",
  "/api/openapi.json"
)

#' Authentication middleware filter
#'
#' Checks all requests for valid Bearer token except allowlisted endpoints.
#' Attaches user_id and user_role to req object for downstream use.
#'
#' @filter require_auth
require_auth <- function(req, res) {
  # Check if endpoint is public
  if (req$PATH_INFO %in% AUTH_ALLOWLIST || req$REQUEST_METHOD == "OPTIONS") {
    return(plumber::forward())
  }

  # GET requests without auth are allowed (public read access)
  if (req$REQUEST_METHOD == "GET" && is.null(req$HTTP_AUTHORIZATION)) {
    return(plumber::forward())
  }

  # All other requests require Bearer token
  if (is.null(req$HTTP_AUTHORIZATION)) {
    res$status <- 401
    return(error_unauthorized("Authorization header missing"))
  }

  # Extract and validate JWT
  jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")
  key <- charToRaw(dw$secret)

  user <- tryCatch(
    jwt_decode_hmac(jwt, secret = key),
    error = function(e) NULL
  )

  # Check token validity
  if (is.null(user) || user$exp < as.numeric(Sys.time())) {
    res$status <- 401
    return(error_unauthorized("Token expired or invalid"))
  }

  # Attach user context to request
  req$user_id <- as.integer(user$user_id)
  req$user_role <- user$user_role
  req$user_name <- user$user_name

  # Forward to next handler
  plumber::forward()
}

#' Role-based authorization filter
#'
#' Checks if authenticated user has minimum required role.
#' Role hierarchy: Administrator > Curator > Reviewer > Viewer
#'
#' @param min_role Minimum role required (default: "Viewer")
#' @filter require_role
require_role <- function(req, res, min_role = "Viewer") {
  # Define role hierarchy (higher number = more privileges)
  role_levels <- c(
    "Viewer" = 1,
    "Reviewer" = 2,
    "Curator" = 3,
    "Administrator" = 4
  )

  # Get user's effective role level
  user_level <- role_levels[[req$user_role]] %||% 0
  required_level <- role_levels[[min_role]] %||% 1

  # Check authorization
  if (user_level < required_level) {
    res$status <- 403
    return(error_forbidden(sprintf(
      "This action requires %s privileges. You have %s role.",
      min_role, req$user_role
    )))
  }

  plumber::forward()
}
```

### Pattern 2: Service Layer with Dependency Injection
**What:** Business logic functions that accept dependencies as parameters (pool, config) instead of using global state.
**When to use:** All business logic that was previously in endpoints or database-functions.R.
**Example:**
```r
# Source: R dependency injection patterns + Phase 21 repository context
# services/entity-service.R

#' Create a new entity with validation and approval workflow
#'
#' Business logic for entity creation including:
#' - Input validation
#' - Duplicate detection
#' - Database persistence
#' - Approval queue insertion
#'
#' @param entity_data List with hgnc_id, disease_ontology_id_version, etc.
#' @param user_id Integer, ID of user creating entity
#' @param pool Database connection pool
#' @param config Configuration object (for validation rules)
#' @return List with status and created entity_id
entity_create <- function(entity_data, user_id, pool, config) {
  # Validate required fields
  required_fields <- c("hgnc_id", "hpo_mode_of_inheritance_term",
                       "disease_ontology_id_version", "ndd_phenotype")

  missing <- setdiff(required_fields, names(entity_data))
  if (length(missing) > 0) {
    stop_for_bad_request(sprintf("Missing required fields: %s",
                                  paste(missing, collapse = ", ")))
  }

  # Check for duplicates using repository
  existing <- entity_find_by_quadruple(
    hgnc_id = entity_data$hgnc_id,
    disease_id = entity_data$disease_ontology_id_version,
    inheritance = entity_data$hpo_mode_of_inheritance_term,
    phenotype = entity_data$ndd_phenotype,
    pool = pool
  )

  if (nrow(existing) > 0) {
    stop_for_bad_request("Entity with these attributes already exists")
  }

  # Create entity using repository
  entity_id <- entity_insert(
    entity_data = entity_data,
    user_id = user_id,
    pool = pool
  )

  # Add to approval queue (new entities require review)
  approval_queue_insert(
    entity_id = entity_id,
    action = "create",
    user_id = user_id,
    pool = pool
  )

  logger::log_info("Entity created", entity_id = entity_id, user_id = user_id)

  list(
    entity_id = entity_id,
    status = "pending_approval"
  )
}

#' Get entity by ID with full related data
#'
#' @param entity_id Integer
#' @param pool Database connection pool
#' @return List with entity data and related objects (reviews, publications)
entity_get_full <- function(entity_id, pool) {
  # Get base entity
  entity <- entity_find_by_id(entity_id, pool)

  if (is.null(entity) || nrow(entity) == 0) {
    stop_for_not_found(sprintf("Entity %d not found", entity_id))
  }

  # Enrich with related data
  entity$reviews <- review_find_by_entity(entity_id, pool)
  entity$publications <- publication_find_by_entity(entity_id, pool)
  entity$phenotypes <- phenotype_find_by_entity(entity_id, pool)

  entity
}
```

### Pattern 3: Thin Endpoint Handlers
**What:** Endpoints that parse request, call service functions, and format responses.
**When to use:** All Plumber endpoint functions.
**Example:**
```r
# Source: Service layer pattern + current endpoint structure
# endpoints/entity_endpoints.R

#* Create a new entity
#*
#* @tag entity
#* @serializer json list(na="string")
#* @param req:request
#* @param res:response
#* @post /
function(req, res, hgnc_id, hpo_mode_of_inheritance_term,
         disease_ontology_id_version, ndd_phenotype) {

  # Service layer handles all business logic
  result <- entity_create(
    entity_data = list(
      hgnc_id = hgnc_id,
      hpo_mode_of_inheritance_term = hpo_mode_of_inheritance_term,
      disease_ontology_id_version = disease_ontology_id_version,
      ndd_phenotype = ndd_phenotype
    ),
    user_id = req$user_id,  # Attached by require_auth middleware
    pool = pool,            # Global pool (approved global)
    config = dw             # Global config (approved global)
  )

  # Format success response
  res$status <- 201
  response_success(
    data = result,
    message = "Entity created successfully"
  )
}

#* Get entity by ID
#*
#* @tag entity
#* @serializer json list(na="string")
#* @get /<entity_id:int>
function(entity_id) {
  # Service layer handles all logic
  entity <- entity_get_full(entity_id, pool)

  # Response formatting
  response_success(data = entity)
}
```

### Pattern 4: Error Handler with RFC 9457 Support
**What:** Global error handler that catches typed errors and formats them as RFC 9457 Problem Details.
**When to use:** Register once in start_sysndd_api.R.
**Example:**
```r
# Source: Plumber error handling + httpproblems package
# start_sysndd_api.R

#* @plumber
function(pr) {
  pr %>%
    # Register error handler
    pr_set_error(function(req, res, err) {
      # httpproblems errors already have proper structure
      if (inherits(err, "http_problem_error")) {
        res$status <- err$status %||% 500
        return(err)
      }

      # Generic errors become 500
      res$status <- 500
      logger::log_error("Unhandled error", error = err$message)

      error_internal("An unexpected error occurred")
    })
}
```

## Anti-Patterns to Avoid

**1. Forgetting `forward()` in filters**
- **Wrong:** Filter without return or forward — silently returns NULL
- **Right:** Always call `plumber::forward()` to continue request chain
- **Detection:** Test public endpoints — if they return empty responses, filter missing forward()

**2. Direct database access in endpoints**
- **Wrong:** `dbConnect()` / `pool %>% tbl()` in endpoint functions
- **Right:** Call repository functions that encapsulate database access
- **Detection:** `grep -r "pool %>%" api/endpoints/` should find zero matches

**3. Global state modification with `<<-`**
- **Wrong:** `cache <<- compute_expensive()` modifying global
- **Right:** Use memoise with explicit cache or pass state as parameter
- **Detection:** `grep -r "<<-" api/` should only find approved globals (pool, config, memoized functions)

**4. Inconsistent error responses**
- **Wrong:** Mix of `list(error = "msg")`, `list(message = "msg")`, raw strings
- **Right:** Always use httpproblems helpers or response_error()
- **Detection:** Responses should have RFC 9457 fields (type, title, status)

**5. Role checks scattered in endpoints**
- **Wrong:** `if (req$user_role != "Administrator") { ... }` in 12 endpoints
- **Right:** Use `@preempt require_role` or call `require_role()` function
- **Detection:** `grep -r "user_role !=" api/endpoints/` should find zero matches after refactor

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JWT validation | Custom decode + expiry check | Centralized require_auth filter | Duplicated across 12 endpoints. Filter handles all edge cases once. |
| Role hierarchy | String comparison in endpoints | require_role with level mapping | Role hierarchy changes require editing multiple files. Centralized mapping prevents errors. |
| Error formatting | Manual list construction | httpproblems package | RFC 9457 has specific fields (type, title, status, detail). Package implements spec correctly. |
| Database connections | dbConnect/dbDisconnect in services | Repository pattern with pool | Connection management error-prone. Repositories already handle it (Phase 21). |
| Response structure | Ad-hoc list building | response_success/response_error | ~100 inconsistent patterns exist. Helpers standardize format. |
| Dependency passing | Global variables with <<- | Function parameters | Globals make testing impossible. Parameters enable mocking. |

**Key insight:** The current codebase has grown organically with duplicated patterns. Service layer consolidates these patterns into reusable functions with clear contracts.

## Common Pitfalls

### Pitfall 1: Filter Order Matters
**What goes wrong:** Authentication filter registered after CORS filter causes OPTIONS requests to fail with 401.
**Why it happens:** Filters execute in registration order. CORS needs to handle OPTIONS before auth check.
**How to avoid:** Register filters in start_sysndd_api.R in correct order: CORS → Auth → Role
**Warning signs:** Preflight requests failing, browser console showing CORS errors

### Pitfall 2: Forgetting to Call forward()
**What goes wrong:** Filter silently returns NULL, endpoint never executes, client gets empty response.
**Why it happens:** R functions return last expression. If last line isn't `plumber::forward()`, filter returns that value.
**How to avoid:** Audit all filter code paths. Every path must call `forward()` or return early with error.
**Warning signs:** Public endpoints returning null, no error logs

### Pitfall 3: Mixing Authentication and Authorization
**What goes wrong:** 401 returned when user lacks permissions (should be 403), confusing clients.
**Why it happens:** Not understanding 401 (who you are) vs 403 (what you can do).
**How to avoid:** 401 only for missing/invalid credentials. 403 for valid user with insufficient role.
**Warning signs:** Authenticated users seeing "Authentication required" errors

### Pitfall 4: Service Functions Using Global Pool
**What goes wrong:** Service functions can't be tested in isolation, tests require database connection.
**Why it happens:** Accessing `pool` directly from global environment instead of parameter.
**How to avoid:** All service functions accept `pool` and `config` as parameters.
**Warning signs:** Can't run tests without database, `<<-` usage in service files

### Pitfall 5: God File Decomposition Breaking Existing Code
**What goes wrong:** Moving functions from database-functions.R to services breaks endpoints that call them.
**Why it happens:** Function dependencies not mapped before moving.
**How to avoid:**
1. Grep all function calls to find dependencies
2. Move related functions together to same service file
3. Update source() statements in start_sysndd_api.R incrementally
4. Test after each migration batch
**Warning signs:** "Object not found" errors after moving functions

### Pitfall 6: Response Format Changes Breaking Frontend
**What goes wrong:** Changing response structure causes frontend to not render data.
**Why it happens:** Frontend expects specific JSON structure, changing `data` field location breaks parsing.
**How to avoid:**
- Core data fields must stay in same location
- Can add new fields but don't remove/rename existing
- Test with Playwright after each endpoint refactor
**Warning signs:** Frontend console errors, blank pages, API returns data but UI shows "No results"

## Code Examples

Verified patterns from official sources:

### Registering Middleware Filters
```r
# Source: Plumber routing documentation
# start_sysndd_api.R

# Create Plumber router
pr <- plumber::plumb()

# Register filters in correct order
pr %>%
  pr_filter("cors", corsFilter) %>%
  pr_filter("require_auth", require_auth) %>%
  # Mount endpoint routers
  pr_mount("/api/entity", plumber::plumb("endpoints/entity_endpoints.R")) %>%
  pr_mount("/api/user", plumber::plumb("endpoints/user_endpoints.R"))
```

### Preempting Filters for Specific Endpoints
```r
# Source: Plumber filters documentation
# endpoints/authentication_endpoints.R

#* Sign in endpoint (public, no auth required)
#*
#* @preempt require_auth
#* @tag authentication
#* @post signin
function(user_name, password) {
  # Authentication logic
  auth_signin(user_name, password, pool, dw)
}
```

### Service Function with Validation
```r
# Source: Phase 22 service layer pattern
# services/auth-service.R

#' Validate user credentials and return JWT token
#'
#' @param user_name String
#' @param password String (plaintext)
#' @param pool Database connection pool
#' @param config Configuration object (contains secret, expiry)
#' @return List with token and user info
auth_signin <- function(user_name, password, pool, config) {
  # Input validation
  if (missing(user_name) || nchar(user_name) == 0) {
    stop_for_bad_request("user_name is required")
  }
  if (missing(password) || nchar(password) == 0) {
    stop_for_bad_request("password is required")
  }

  # Get user from repository
  user <- user_find_by_name(user_name, pool)

  if (is.null(user) || nrow(user) == 0) {
    stop_for_unauthorized("Invalid username or password")
  }

  # Verify password using security helper
  if (!verify_password(password, user$password)) {
    stop_for_unauthorized("Invalid username or password")
  }

  # Generate JWT token
  claim <- jwt_claim(
    user_id = user$user_id,
    user_name = user$user_name,
    user_role = user$user_role,
    email = user$email,
    iat = as.numeric(Sys.time()),
    exp = as.numeric(Sys.time()) + config$token_expiry
  )

  token <- jwt_encode_hmac(claim, secret = charToRaw(config$secret))

  logger::log_info("User signed in", user_id = user$user_id)

  list(
    token = token,
    user = list(
      user_id = user$user_id,
      user_name = user$user_name,
      user_role = user$user_role,
      email = user$email
    )
  )
}
```

### Integration Test with testthat
```r
# Source: testthat + callthat package documentation
# tests/testthat/test-entity-service.R

library(testthat)
library(DBI)
library(pool)

test_that("entity_create validates required fields", {
  # Arrange: Setup test pool and config
  test_pool <- dbPool(...)  # Test database
  test_config <- list(...)

  # Act & Assert: Missing field should error
  expect_error(
    entity_create(
      entity_data = list(hgnc_id = "HGNC:1234"),  # Missing other required fields
      user_id = 1,
      pool = test_pool,
      config = test_config
    ),
    class = "error_400"
  )

  # Cleanup
  poolClose(test_pool)
})

test_that("entity_create inserts valid entity", {
  # Arrange
  test_pool <- dbPool(...)
  test_config <- list(...)

  valid_entity <- list(
    hgnc_id = "HGNC:1234",
    hpo_mode_of_inheritance_term = "HP:0000006",
    disease_ontology_id_version = "MONDO:0000001_1",
    ndd_phenotype = "1"
  )

  # Act
  result <- entity_create(
    entity_data = valid_entity,
    user_id = 1,
    pool = test_pool,
    config = test_config
  )

  # Assert
  expect_type(result$entity_id, "integer")
  expect_equal(result$status, "pending_approval")

  # Cleanup
  poolClose(test_pool)
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Duplicate auth in endpoints | Middleware filters | Plumber v1.0+ (2020) | Reduces code duplication, centralizes security logic |
| Manual error objects | httpproblems (RFC 9457) | RFC 9457 published 2023 | Standardized error format, better client error handling |
| R6 classes | Plain functions | R community shift 2020+ | More idiomatic R, easier testing, better integration |
| Global state with <<- | Dependency injection | Modern R best practices | Testable code, explicit dependencies |
| God files | Service layer pattern | Standard architecture 2015+ | Better maintainability, clear boundaries |
| Manual connection mgmt | Pool package | pool v1.0+ (2023) | Automatic resource management, connection reuse |

**Deprecated/outdated:**
- **Reference Classes (RC):** R's built-in OOP system superseded by R6 for performance, but plain functions preferred for services
- **String concatenation SQL:** Replaced by parameterized queries in Phase 21 (security vulnerability)
- **Inline database logic:** Moved to repositories in Phase 21, now services in Phase 22
- **Inconsistent error formats:** Replaced by RFC 9457 standard via httpproblems package

## Open Questions

Things that couldn't be fully resolved:

1. **Playwright R bindings availability**
   - What we know: Playwright has JavaScript, TypeScript, Python, Java, .NET bindings
   - What's unclear: No official R bindings found; likely need Node.js/Python wrapper or JavaScript-based tests
   - Recommendation: Use Playwright with TypeScript/JavaScript for end-to-end tests of API + frontend. R integration tests with testthat + callthat for service/endpoint logic.

2. **callthat package maintenance status**
   - What we know: Package exists and provides testthat integration for Plumber APIs
   - What's unclear: Last update date, active maintenance, compatibility with latest Plumber
   - Recommendation: Test compatibility in Phase 22 planning. If issues found, use httr + testthat directly for endpoint testing.

3. **Optimal service granularity**
   - What we know: Need entity-service, user-service, review-service, approval-service, auth-service, search-service (from requirements)
   - What's unclear: Whether to split further (e.g., separate token-service from auth-service) or consolidate
   - Recommendation: Start with 6 services per requirements. Split only if file exceeds ~500 lines or has >15 functions.

4. **Migration order for database-functions.R**
   - What we know: 1,226 lines mixing multiple domains; needs decomposition
   - What's unclear: Which functions are called by which endpoints; dependency graph
   - Recommendation: Planning phase should grep all function calls and create migration order based on dependencies. Move entity functions first (most endpoints), then reviews, then admin functions.

## Sources

### Primary (HIGH confidence)
- [Plumber Routing & Input](https://www.rplumber.io/articles/routing-and-input.html) - Filter patterns and request handling
- [Plumber Filters Example](https://rdrr.io/cran/plumber/src/inst/plumber/02-filters/plumber.R) - Authentication filter implementation
- [R Plumber Error Handling (Appsilon)](https://www.appsilon.com/post/api-oopsies-101) - Custom error handlers and RFC 9457 patterns
- [401 vs 403 Status Codes (Auth0)](https://auth0.com/blog/forbidden-unauthorized-http-status-codes/) - Authentication vs authorization semantics
- [R6 Introduction](https://r6.r-lib.org/articles/Introduction.html) - R6 classes vs plain functions tradeoffs
- [Advanced R: Environments](https://adv-r.hadley.nz/environments.html) - R6 objects and state management patterns
- Phase 21 RESEARCH.md - Repository layer patterns (provides foundation for service layer)

### Secondary (MEDIUM confidence)
- [RFC 9457 Specification](https://www.rfc-editor.org/rfc/rfc9457.html) - Problem Details for HTTP APIs standard
- [httpproblems Package (CRAN)](https://cran.r-project.org/web/packages/httpproblems/httpproblems.pdf) - R implementation of RFC 9457
- [testthat Package (CRAN)](https://cran.r-project.org/web/packages/testthat/testthat.pdf) - Testing framework v3.3.2
- [callthat Package](https://edgararuiz.github.io/callthat/) - Test Plumber APIs with testthat
- [Plumber API Best Practices (Posit Community)](https://forum.posit.co/t/plumber-api-best-practices/116578) - Community discussion on structure

### Tertiary (LOW confidence - community patterns)
- [Plumber API Project Structure (GitHub)](https://github.com/JfrAziz/r-plumber) - Boilerplate with services pattern
- [sealr Authentication](https://jandix.github.io/sealr/) - Third-party auth filter package (reference only)
- WebSearch results on superassignment alternatives - R6 vs plain functions for state management

## Metadata

**Confidence breakdown:**
- Middleware patterns: HIGH - Official Plumber documentation with working examples
- 401 vs 403 semantics: HIGH - RFC standards and authoritative Auth0 guide
- Service layer structure: MEDIUM - R community conventions, no official R/Plumber service layer guide
- Global state elimination: HIGH - Advanced R book and R6 documentation
- Testing patterns: MEDIUM - testthat official, callthat less verified in production
- Response standardization: HIGH - RFC 9457 standard + httpproblems package

**Research date:** 2026-01-24
**Valid until:** 30 days (R/Plumber ecosystem stable; filter patterns unlikely to change)
