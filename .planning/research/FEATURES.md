# Feature Landscape: v4 Backend Overhaul

**Domain:** R/Plumber API modernization (async, pagination, security, OMIM alternatives)
**Project:** SysNDD (neurodevelopmental disorders database)
**Researched:** 2026-01-23
**Overall Confidence:** MEDIUM-HIGH (multiple authoritative sources verified)

---

## Executive Summary

The v4 Backend Overhaul introduces six interconnected feature domains. This research maps expected behavior for each:

1. **Async/Non-blocking patterns** - Required for long-running operations (clustering, ontology updates)
2. **Pagination** - Required for 4200+ entity records in table endpoints
3. **Password security** - Required to fix plaintext password storage vulnerability
4. **OMIM data alternatives** - Required because genemap2 no longer provides needed fields
5. **API versioning** - Required for GitHub #21, enables breaking change management
6. **DRY/KISS/SOLID patterns** - Required to address 66 SQL injection points and code duplication

**Key insight:** These features are interdependent. Pagination requires consistent error handling. Async requires proper error propagation. Security hardening requires database access layer. Plan phases accordingly.

---

## Table Stakes Features

Features users and developers **expect** from a modern API. Missing these = API feels incomplete or insecure.

### 1. Async/Non-blocking API Patterns

**Why expected:** Blocking operations cause timeout failures. Users expect API responsiveness even during long operations.

| Feature | Complexity | Current State | Expected Behavior |
|---------|------------|---------------|-------------------|
| Non-blocking ontology updates | High | Blocking, times out | Returns immediately, processes in background |
| Non-blocking clustering analysis | High | Blocking, times out | Returns job ID, poll for results |
| Concurrent request handling | Medium | Single-threaded blocks all | Multiple requests process in parallel |
| Progress indication | Medium | None | WebSocket or polling endpoint for status |
| Cancellation support | Low | None | Ability to cancel long-running jobs |

**Implementation Approaches (R/Plumber):**

**Option A: future + promises (Recommended)**
```r
library(future)
library(promises)
future::plan("multisession")

#* @post /ontology/update
function(req, res) {
  promises::future_promise({
    # Long-running ontology update
    process_combine_ontology(hgnc_list, moi_list)
  }) %...>% (function(result) {
    list(status = "complete", data = result)
  })
}
```

**Option B: mirai for higher concurrency**
```r
library(mirai)
daemons(4L, dispatcher = TRUE)  # 4 parallel workers

#* @post /ontology/update
function(req, res) {
  mirai({
    process_combine_ontology(hgnc_list, moi_list)
  }) %...>% (function(result) {
    res$status <- 200L
    res$body <- list(status = "complete", data = result)
  })
}
```

**Expected Behavior:**
- API returns HTTP 202 Accepted immediately for long operations
- Client polls status endpoint or receives WebSocket notification
- Multiple concurrent requests handled without blocking
- Timeouts only for actual failures, not processing time

**SysNDD Impact:**
- `process_combine_ontology()` in ontology-functions.R
- `calculate_entity_clustering()` in analyses-functions.R
- Any endpoint fetching external APIs (HGNC, Ensembl, HPO)

**Sources:**
- [Plumber + future: Async Web APIs](https://posit.co/resources/videos/plumber-and-future-async-web-apis/)
- [Mirai Promises Documentation](https://mirai.r-lib.org/articles/v3-promises.html)
- [FvD/futureplumber GitHub](https://github.com/FvD/futureplumber)
- [Plumber Package CRAN (Dec 2025)](https://cran.r-project.org/web/packages/plumber/plumber.pdf)

**Confidence:** HIGH (official plumber documentation, CRAN packages)

---

### 2. Pagination for Tabular Endpoints

**Why expected:** 4200+ entities cannot load in single response. Users expect fast initial load and progressive data access.

| Feature | Complexity | Current State | Expected Behavior |
|---------|------------|---------------|-------------------|
| Cursor-based pagination | Medium | Partially implemented | Consistent across all tabular endpoints |
| Offset/limit fallback | Low | Mixed implementation | Available for simple use cases |
| Page size limits | Low | No enforcement | Server enforces max 100-500 per page |
| Total count in metadata | Low | Inconsistent | Always returned for UI pagination controls |
| Stable sorting | Medium | Some endpoints inconsistent | Results stable across page requests |

**Cursor vs Offset Comparison:**

| Criterion | Cursor-Based | Offset/Limit |
|-----------|--------------|--------------|
| Performance at scale | Excellent (index lookup) | Poor (OFFSET scans N rows) |
| Consistency with data changes | Good (no skips/duplicates) | Poor (rows shift) |
| Implementation complexity | Higher | Lower |
| Jump to arbitrary page | Not possible | Possible |
| SysNDD recommendation | **Use for entities, genes** | Use for static lists |

**Expected API Response Format:**
```json
{
  "links": {
    "self": "/api/entity?page_after=abc123&page_size=50",
    "next": "/api/entity?page_after=xyz789&page_size=50",
    "prev": "/api/entity?page_before=abc123&page_size=50"
  },
  "meta": {
    "total_count": 4287,
    "page_size": 50,
    "has_next": true,
    "has_prev": true,
    "execution_time": "0.23 secs"
  },
  "data": [...]
}
```

**Best Practices:**
1. Enforce maximum page_size (100-500) to prevent DoS
2. Return opaque cursors (Base64-encoded) to hide implementation
3. Include total_count for pagination UI (cache if expensive)
4. Validate cursor format, return 400 for malformed
5. Support both forward and backward navigation
6. Index database columns used for cursor sorting

**SysNDD Impact:** Already partially implemented in entity_endpoints.R via `generate_cursor_pag_inf()`. Need to:
- Standardize across all 21 endpoints
- Add enforcement of page_size limits
- Ensure stable sorting with composite keys

**Sources:**
- [API Pagination Guide - Treblle](https://treblle.com/blog/api-pagination-guide-techniques-benefits-implementation)
- [Offset vs Cursor-Based Pagination - Medium](https://medium.com/@maryam-bit/offset-vs-cursor-based-pagination-choosing-the-best-approach-2e93702a118b)
- [API Design Basics: Pagination](https://apisyouwonthate.com/blog/api-design-basics-pagination/)
- [Speakeasy Pagination Best Practices](https://www.speakeasy.com/api-design/pagination)

**Confidence:** HIGH (established API design patterns, multiple authoritative sources)

---

### 3. Password Hashing and Security

**Why expected:** Plaintext password storage is a critical vulnerability. Any security audit flags this immediately.

| Feature | Complexity | Current State | Expected Behavior |
|---------|------------|---------------|-------------------|
| Password hashing | Low | Plaintext in DB | Argon2id or bcrypt hashed |
| Hash verification | Low | Direct comparison | Timing-safe comparison |
| Existing password migration | Medium | N/A | Batch update or migrate-on-login |
| Password complexity rules | Low | None | Minimum requirements enforced |
| Rate limiting on auth | Medium | None | Prevent brute force |

**Algorithm Recommendations (2025 OWASP):**

| Algorithm | Status | Work Factor | Notes |
|-----------|--------|-------------|-------|
| **Argon2id** | Recommended | 19 MiB memory, 2 iterations min | Best for new implementations |
| **scrypt** | Second choice | 2^17 cost | If Argon2 unavailable |
| **bcrypt** | Acceptable | Cost factor 12+ | Legacy systems, 72-byte limit |
| PBKDF2 | FIPS only | 600,000+ iterations | Only for compliance requirements |
| MD5, SHA-1 | NEVER | N/A | Insecure, trivially cracked |

**R Implementation Options:**

**Option A: sodium package (Argon2)**
```r
library(sodium)

# Hash password for storage
hash <- password_store("user_password")
# Returns: "$argon2id$v=19$m=65536,t=2,p=1$..."

# Verify on login
password_verify(hash, "user_password")  # TRUE/FALSE
```

**Option B: bcrypt package**
```r
library(bcrypt)

# Hash with cost factor 12
hash <- hashpw("user_password", gensalt(log_rounds = 12))
# Returns: "$2a$12$..."

# Verify on login
checkpw("user_password", hash)  # TRUE/FALSE
```

**Migration Strategy:**
1. Add `password_hash` column to user table
2. On login with plaintext match, hash and store, clear plaintext
3. After migration period, remove plaintext column
4. For immediate security, batch hash all passwords

**SysNDD Current State (authentication_endpoints.R line 153):**
```r
# CURRENT: Plaintext comparison - INSECURE
filter(user_name == check_user & password == check_pass & approved == 1)
```

**Expected Implementation:**
```r
# FIXED: Hash verification
user <- pool %>%
  tbl("user") %>%
  filter(user_name == check_user & approved == 1) %>%
  select(user_id, password_hash, ...) %>%
  collect()

if (nrow(user) == 1 && sodium::password_verify(user$password_hash, check_pass)) {
  # Generate JWT
}
```

**Sources:**
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [sodium R Package CRAN (July 2025)](https://cran.r-project.org/web/packages/sodium/sodium.pdf)
- [bcrypt R Package CRAN (July 2025)](https://cran.r-project.org/web/packages/bcrypt/bcrypt.pdf)
- [Password Security in 2025](https://clxon.com/en/blog/password-security-hashing-algorithms-2025)

**Confidence:** HIGH (OWASP guidelines, official R packages)

---

### 4. SQL Injection Prevention

**Why expected:** 66 SQL injection vulnerabilities identified in code review. Critical security requirement.

| Feature | Complexity | Current State | Expected Behavior |
|---------|------------|---------------|-------------------|
| Parameterized queries | Medium | String concatenation | All queries use placeholders |
| Identifier escaping | Low | None | Table/column names escaped |
| Input validation | Low | Minimal | All inputs validated before query |
| Query builder pattern | Medium | Manual SQL strings | Consistent query construction |

**Current Vulnerable Pattern (database-functions.R line 145):**
```r
# VULNERABLE: String interpolation
dbExecute(sysndd_db, paste0("UPDATE ndd_entity SET ",
  "is_active = 0, ",
  "replaced_by = ", replacement,  # INJECTION POINT
  " WHERE entity_id = ", entity_id, ";"))  # INJECTION POINT
```

**Safe Patterns in R:**

**Option A: DBI::dbBind() with placeholders (Recommended)**
```r
query <- dbSendQuery(con, "UPDATE ndd_entity SET is_active = 0, replaced_by = ? WHERE entity_id = ?")
dbBind(query, list(replacement, entity_id))
dbClearResult(query)
```

**Option B: glue::glue_sql() for dynamic queries**
```r
library(glue)
query <- glue_sql("UPDATE ndd_entity SET is_active = 0,
                   replaced_by = {replacement}
                   WHERE entity_id = {entity_id}",
                  .con = con)
dbExecute(con, query)
```

**Option C: DBI::dbQuoteString() for manual escaping**
```r
safe_replacement <- dbQuoteString(con, as.character(replacement))
safe_entity_id <- dbQuoteString(con, as.character(entity_id))
# Use in query...
```

**Database Access Layer Pattern:**
```r
# functions/db-utils.R
execute_query <- function(pool, query, params = list()) {
  con <- pool::poolCheckout(pool)
  on.exit(pool::poolReturn(con))

  stmt <- DBI::dbSendStatement(con, query)
  on.exit(DBI::dbClearResult(stmt), add = TRUE)

  if (length(params) > 0) {
    DBI::dbBind(stmt, params)
  }

  DBI::dbGetRowsAffected(stmt)
}
```

**SysNDD Impact:** 66 occurrences of `paste0()` with SQL need conversion. Priority by risk:
1. User input endpoints (authentication, forms)
2. Admin endpoints with entity_id parameters
3. Internal functions with less direct user input

**Sources:**
- [Posit: Run Queries Safely](https://solutions.posit.co/connections/db/best-practices/run-queries-safely/)
- [glue_sql Documentation](https://glue.tidyverse.org/reference/glue_sql.html)
- [DBI Advanced Usage](https://cran.r-project.org/web/packages/DBI/vignettes/DBI-advanced.html)
- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)

**Confidence:** HIGH (official R documentation, OWASP)

---

### 5. RFC 7807 Problem Details for Errors

**Why expected:** Consistent error responses enable client-side error handling. Ad-hoc error formats create fragile integrations.

| Feature | Complexity | Current State | Expected Behavior |
|---------|------------|---------------|-------------------|
| Structured error format | Low | Inconsistent JSON | RFC 7807/9457 compliant |
| Error type URIs | Low | None | Unique type per error category |
| HTTP status codes | Low | Sometimes inconsistent | Correct codes for error type |
| Error middleware | Medium | None | Centralized error handling |

**RFC 7807 Response Format:**
```json
{
  "type": "https://api.sysndd.org/errors/validation",
  "title": "Validation Error",
  "status": 400,
  "detail": "The entity_id field is required.",
  "instance": "/api/entity/create",
  "errors": [
    {"field": "entity_id", "message": "Required field missing"}
  ]
}
```

**R Implementation with httpproblems package:**
```r
library(httpproblems)

# In plumber setup
pr() |>
  pr_set_error(function(req, res, error) {
    res$setHeader("Content-Type", "application/problem+json")
    res$status <- 500
    internal_error(detail = conditionMessage(error))
  }) |>
  pr_set_404(function(req, res) {
    not_found(detail = paste0("Resource not found: ", req$PATH_INFO))
  })

# In endpoint
#* @post /entity/create
function(req, res) {
  if (is.null(req$body$entity_id)) {
    res$status <- 400
    return(bad_request(
      title = "Validation Error",
      detail = "entity_id is required"
    ))
  }
  # ...
}
```

**Error Categories for SysNDD:**

| Type URI | HTTP Status | Use Case |
|----------|-------------|----------|
| `/errors/validation` | 400 | Invalid input data |
| `/errors/authentication` | 401 | Missing/invalid token |
| `/errors/authorization` | 403 | Insufficient permissions |
| `/errors/not-found` | 404 | Resource doesn't exist |
| `/errors/conflict` | 409 | Duplicate entity |
| `/errors/internal` | 500 | Server error |

**Sources:**
- [RFC 7807 (IETF)](https://datatracker.ietf.org/doc/html/rfc7807)
- [RFC 9457 (supersedes 7807)](https://www.rfc-editor.org/rfc/rfc9457.html)
- [httpproblems R Package](https://github.com/atheriel/httpproblems)
- [Introduction to RFC 7807 - Axway](https://blog.axway.com/learning-center/apis/api-design/introduction-to-rfc-7807)

**Confidence:** HIGH (IETF standard, dedicated R package)

---

### 6. API Versioning

**Why expected:** GitHub #21 requires version display. Breaking changes need migration path.

| Feature | Complexity | Current State | Expected Behavior |
|---------|------------|---------------|-------------------|
| Version in response | Low | None | Version header or field |
| URL path versioning | Medium | None | /api/v1/... prefix |
| Version endpoint | Low | None | GET /api/version |
| Deprecation headers | Low | None | Sunset header for old versions |

**Versioning Strategies:**

| Strategy | URL Example | Pros | Cons |
|----------|-------------|------|------|
| **URL Path** | `/api/v1/entity` | Visible, cacheable, simple | URL proliferation |
| Header | `Accepts-version: 1.0` | Clean URLs | Hidden, harder to test |
| Query param | `/api/entity?version=1` | Easy to test | Less RESTful |

**Recommended: URL Path Versioning with Plumber mount()**
```r
# plumber.R
pr_v1 <- plumber::plumb("endpoints_v1/")
pr_v2 <- plumber::plumb("endpoints_v2/")

pr() |>
  pr_mount("/api/v1", pr_v1) |>
  pr_mount("/api/v2", pr_v2) |>
  pr_run()
```

**Version Endpoint:**
```r
#* @get /version
function() {
  list(
    api_version = "1.2.0",
    api_major = 1,
    r_version = R.version.string,
    build_date = "2026-01-23"
  )
}
```

**SysNDD Approach:**
- Start with `/api/v1/` prefix for all current endpoints
- Add `/api/version` endpoint returning version info
- Use Semantic Versioning (MAJOR.MINOR.PATCH)
- Document sunset policy for deprecated versions

**Sources:**
- [API Versioning Best Practices - getlate.dev](https://getlate.dev/blog/api-versioning-best-practices)
- [Top 5 API Versioning Strategies 2025](https://blog.dreamfactory.com/top-5-api-versioning-strategies-2025-dreamfactory)
- [API Versioning: URL vs Header](https://www.lonti.com/blog/api-versioning-url-vs-header-vs-media-type-versioning)
- [Plumber Routing Documentation](https://www.rplumber.io/)

**Confidence:** HIGH (established patterns, plumber supports mounting)

---

## Differentiators

Features that set a **well-engineered** API apart from a minimal implementation.

### 1. OMIM Data Source Migration (mim2gene.txt + HPO)

**Value proposition:** Current genemap2 dependency is broken. New approach uses freely available sources without OMIM license.

| Feature | Complexity | Current Source | Target Source |
|---------|------------|----------------|---------------|
| Gene-disease mapping | Medium | genemap2 (broken) | mim2gene.txt (free) |
| Disease names | High | genemap2 | HPO annotations or MONDO |
| Mode of inheritance | Medium | genemap2 | HPO-OMIM mappings |
| Cross-references | Low | Manual | MONDO ontology xrefs |

**Current Problem (ontology-functions.R):**
- genemap2 requires OMIM license for commercial use
- genemap2 no longer provides all required fields reliably
- Current code downloads from `omim_links.txt` file

**Alternative Data Sources:**

| Source | Access | Contains | Limitations |
|--------|--------|----------|-------------|
| **mim2gene.txt** | Free, no license | MIM number, gene symbols, Entrez ID | No disease names |
| **HPO annotations** | Free, CC license | Disease-phenotype mappings | Need to join with MIM |
| **MONDO ontology** | Free, CC license | Disease names, OMIM xrefs | Requires ontology parsing |
| **MGI Disease Connection** | Free | Human-mouse disease mappings | Mouse focus |

**Proposed Solution:**
1. Use `mim2gene.txt` for gene-OMIM mappings (free, always available)
2. Use MONDO ontology xrefs for OMIM-to-disease-name mapping
3. Use HPO annotations for disease-phenotype relationships
4. Store disease names from MONDO rather than OMIM directly

**Implementation Pattern:**
```r
# 1. Load mim2gene.txt (free)
mim2gene <- read_delim("https://omim.org/static/omim/data/mim2gene.txt",
                       delim = "\t", comment = "#")

# 2. Get disease names from MONDO ontology (already implemented)
mondo_ontology <- get_ontology_object("mondo", config_vars)
mondo_mappings <- get_mondo_mappings(mondo_ontology)

# 3. Join to get disease names
omim_with_names <- mim2gene %>%
  left_join(mondo_mappings, by = c("MIM_Number" = "OMIM"))
```

**Sources:**
- [OMIM Downloads Page](https://www.omim.org/downloads/)
- [Human Phenotype Ontology](https://hpo.jax.org/)
- [MONDO Disease Ontology](https://mondo.monarchinitiative.org/)
- [MGI Human-Mouse Disease Connection](https://www.informatics.jax.org/userhelp/disease_connection_help.shtml)

**Confidence:** MEDIUM (requires validation that all needed data is available)

---

### 2. Database Access Layer

**Value proposition:** Eliminates 17 `dbConnect` duplications, centralizes error handling, enables connection pooling.

| Feature | Complexity | Current State | Expected Behavior |
|---------|------------|---------------|-------------------|
| Single connection pattern | Low | 17 dbConnect calls | Use pool throughout |
| Transaction support | Medium | None | `poolWithTransaction()` for multi-step operations |
| Query helpers | Medium | Manual SQL | `execute_query()`, `fetch_one()`, `fetch_all()` |
| Error wrapping | Low | Try-catch per call | Centralized error handler |

**Current Pattern (repeated 17 times):**
```r
sysndd_db <- dbConnect(RMariaDB::MariaDB(),
  dbname = dw$dbname,
  user = dw$user,
  password = dw$password,
  server = dw$server,
  host = dw$host,
  port = dw$port
)
# ... operations ...
dbDisconnect(sysndd_db)
```

**Recommended Database Access Layer:**
```r
# functions/db-access.R

#' Execute a parameterized query returning affected row count
execute_query <- function(query, params = list()) {
  pool::poolWithTransaction(pool, function(con) {
    stmt <- DBI::dbSendStatement(con, query)
    on.exit(DBI::dbClearResult(stmt))
    if (length(params) > 0) DBI::dbBind(stmt, params)
    DBI::dbGetRowsAffected(stmt)
  })
}

#' Fetch single row, NULL if not found
fetch_one <- function(query, params = list()) {
  result <- fetch_all(query, params)
  if (nrow(result) == 0) return(NULL)
  if (nrow(result) > 1) warning("fetch_one returned multiple rows")
  as.list(result[1, ])
}

#' Fetch all rows as tibble
fetch_all <- function(query, params = list()) {
  pool::poolWithTransaction(pool, function(con) {
    stmt <- DBI::dbSendQuery(con, query)
    on.exit(DBI::dbClearResult(stmt))
    if (length(params) > 0) DBI::dbBind(stmt, params)
    tibble::as_tibble(DBI::dbFetch(stmt))
  })
}
```

**Confidence:** HIGH (established patterns, pool package documentation)

---

### 3. Authentication Middleware Refactoring

**Value proposition:** Extract duplicated JWT validation into reusable filters.

| Feature | Complexity | Current State | Expected Behavior |
|---------|------------|---------------|-------------------|
| Reusable auth filter | Medium | Inline in each endpoint | `require_auth()` filter |
| Role-based access | Low | Inline role checks | `require_role("Administrator")` |
| Token refresh handling | Low | Manual | Automatic in middleware |

**Current Pattern (repeated in many endpoints):**
```r
if (req$user_role %in% c("Administrator", "Curator")) {
  # endpoint logic
} else {
  res$status <- 403
  return(list(error = "Write access forbidden."))
}
```

**Recommended Filter Pattern:**
```r
# filters/auth.R

#' Require authenticated user
require_auth <- function(req, res) {
  if (is.null(req$user_id)) {
    res$status <- 401
    return(list(error = "Authentication required"))
  }
  plumber::forward()
}

#' Require specific role(s)
require_role <- function(...) {
  roles <- c(...)
  function(req, res) {
    if (!req$user_role %in% roles) {
      res$status <- 403
      return(list(error = paste("Required role:", paste(roles, collapse = " or "))))
    }
    plumber::forward()
  }
}

# Usage in endpoint
#* @filter require_role("Administrator", "Curator")
#* @post /entity/create
function(req, res) {
  # No auth check needed here
}
```

**Confidence:** HIGH (plumber filter documentation)

---

### 4. Response Builder Helpers

**Value proposition:** Consistent response format across all endpoints.

```r
# helpers/response.R

response_success <- function(data, meta = list(), status = 200) {
  list(
    status = status,
    meta = c(meta, list(timestamp = Sys.time())),
    data = data
  )
}

response_error <- function(title, detail, status = 400, type = NULL) {
  list(
    type = type %||% paste0("https://api.sysndd.org/errors/", status),
    title = title,
    status = status,
    detail = detail,
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
  )
}

response_created <- function(data, location = NULL) {
  list(
    status = 201,
    message = "Resource created",
    data = data,
    location = location
  )
}
```

**Confidence:** HIGH (common API pattern)

---

## Anti-Features

Features to **explicitly avoid**. Common mistakes that create technical debt or security issues.

### 1. Synchronous Long-Running Operations

**What:** Keeping blocking operations that timeout under load.

**Why bad:**
- API becomes unresponsive during ontology updates
- Users retry, creating more load
- Kubernetes/load balancers kill hung requests
- Poor user experience

**Instead:** Implement job queue pattern:
1. POST /jobs/ontology-update returns job_id immediately
2. GET /jobs/{job_id}/status returns progress
3. GET /jobs/{job_id}/result returns completed data

**Detection:** If any endpoint takes >30 seconds, it needs async handling.

---

### 2. Partial Security Fixes

**What:** Fixing some SQL injections but leaving others. Adding password hashing without rate limiting.

**Why bad:**
- False sense of security
- Attackers find the unfixed vulnerabilities
- Inconsistent codebase is harder to audit

**Instead:** Complete security hardening:
1. Fix ALL 66 SQL injection points
2. Add password hashing AND rate limiting
3. Audit all input validation
4. Document security measures

**Detection:** If code review shows mixed patterns (some parameterized, some not), you have partial fixes.

---

### 3. Custom Error Formats per Endpoint

**What:** Each endpoint returns errors differently.

**Why bad:**
- Frontend must handle multiple error formats
- Documentation is inconsistent
- New developers reinvent error handling

**Instead:** Single RFC 7807 format everywhere via middleware.

**Detection:** If grepping for `list(error =` shows different structures, you have inconsistent errors.

---

### 4. Pagination Without Limits

**What:** Allowing `page_size=1000000` to return entire database.

**Why bad:**
- Memory exhaustion
- DoS vector
- Slow queries

**Instead:** Enforce max_page_size (100-500), reject larger requests with 400.

---

### 5. Mixing Direct DB Connections with Pool

**What:** Using both `dbConnect()` and pool in same codebase.

**Why bad:**
- Connection leaks from missed `dbDisconnect()`
- Inconsistent transaction handling
- Pool benefits negated

**Instead:** ALL database access goes through pool. Remove all `dbConnect()` calls.

**Detection:** If `grep -r "dbConnect"` finds results outside of pool setup, you have mixed patterns.

---

### 6. Storing API Secrets in Code

**What:** Hardcoding OMIM download URLs, API keys, or secrets in R files.

**Why bad:**
- Secrets committed to git
- Can't change without code deploy
- Security risk

**Instead:**
- Environment variables for secrets
- Config files for non-secret configuration
- Document required environment variables

---

## Feature Dependencies

```
Security Hardening (FIRST - unblocks safe development)
  ├── SQL Injection Prevention (blocking: all DB operations)
  │   └── Database Access Layer (enables: parameterized queries)
  └── Password Hashing (blocking: auth endpoints)

Pagination Standardization (PARALLEL with security)
  └── Error Handling RFC 7807 (enables: consistent error responses)

Async Operations (AFTER security + pagination basics)
  ├── future + promises setup (blocking: async endpoints)
  └── Job queue pattern (enables: long-running operations)

OMIM Migration (AFTER async, uses async for updates)

API Versioning (LAST - labels the stable state)
```

**Key insight:** Security hardening must come first. Everything else builds on secure foundations.

---

## Implementation Complexity Summary

| Feature | Complexity | Time Estimate | Blocking? | Priority |
|---------|------------|---------------|-----------|----------|
| **Table Stakes** | | | | |
| SQL Injection Prevention | Medium | 1-2 weeks | Yes | P0 |
| Password Hashing | Low | 2-3 days | Yes | P0 |
| Database Access Layer | Medium | 1 week | No | P1 |
| RFC 7807 Errors | Low | 3-4 days | No | P1 |
| Pagination Standardization | Medium | 1 week | No | P1 |
| API Versioning | Low | 2-3 days | No | P2 |
| **Differentiators** | | | | |
| Async Operations | High | 2-3 weeks | No | P1 |
| OMIM Migration | High | 2-3 weeks | No | P1 |
| Auth Middleware | Medium | 3-4 days | No | P2 |
| Response Builders | Low | 1-2 days | No | P2 |

**Total Estimate:** 8-12 weeks for comprehensive implementation

---

## SysNDD-Specific Considerations

### Endpoints Requiring Async

| Endpoint | Current Behavior | Why Async Needed |
|----------|------------------|------------------|
| POST /ontology/update | Blocks 2-5 minutes | External API calls, file processing |
| GET /analyses/clustering | Blocks 1-2 minutes | CPU-intensive calculation |
| POST /external/pubtator | Blocks 30-60 seconds | External API rate limits |
| POST /external/hgnc | Blocks 10-30 seconds | External API calls |

### Endpoints Requiring Pagination Audit

| Endpoint | Current State | Action Needed |
|----------|---------------|---------------|
| GET /entity | Has cursor pagination | Audit consistency |
| GET /gene | Needs verification | May need cursor params |
| GET /phenotype | Unknown | Assess row counts |
| GET /statistics | Likely fine | Probably no pagination needed |

### Database Functions Requiring Parameterized Queries

All functions in `database-functions.R` using `paste0()` with SQL:
- `post_db_entity()`
- `put_db_entity_deactivation()`
- `put_post_db_review()`
- `put_post_db_pub_con()`
- `put_post_db_phen_con()`
- `put_post_db_var_ont_con()`
- `put_post_db_status()`
- `post_db_hash()`
- `put_db_review_approve()`
- `put_db_status_approve()`

---

## Validation Checklist

Feature implementation is complete when:

**Security:**
- [ ] All 66 SQL injection points use parameterized queries
- [ ] Password hashing implemented with Argon2id or bcrypt
- [ ] Existing passwords migrated to hashed format
- [ ] Rate limiting on authentication endpoints

**Pagination:**
- [ ] All tabular endpoints support pagination
- [ ] Page size limits enforced (max 100-500)
- [ ] Cursor pagination on high-volume endpoints
- [ ] Consistent metadata (total_count, has_next, has_prev)

**Async:**
- [ ] Ontology update returns immediately
- [ ] Job status endpoint functional
- [ ] Multiple concurrent requests handled
- [ ] Proper error propagation from async tasks

**Error Handling:**
- [ ] All errors use RFC 7807 format
- [ ] Content-Type: application/problem+json
- [ ] Consistent HTTP status codes

**OMIM Migration:**
- [ ] Uses mim2gene.txt instead of genemap2
- [ ] Disease names from MONDO/HPO
- [ ] All existing functionality preserved

**API Versioning:**
- [ ] /api/version endpoint returns version info
- [ ] URL path versioning implemented (/api/v1/)
- [ ] Version documented in OpenAPI spec

---

## Sources

### Official Documentation
- [Plumber Package CRAN (Dec 2025)](https://cran.r-project.org/web/packages/plumber/plumber.pdf)
- [sodium R Package CRAN (July 2025)](https://cran.r-project.org/web/packages/sodium/sodium.pdf)
- [bcrypt R Package CRAN (July 2025)](https://cran.r-project.org/web/packages/bcrypt/bcrypt.pdf)
- [DBI Advanced Usage CRAN](https://cran.r-project.org/web/packages/DBI/vignettes/DBI-advanced.html)
- [glue_sql Documentation](https://glue.tidyverse.org/reference/glue_sql.html)
- [RFC 7807 (IETF)](https://datatracker.ietf.org/doc/html/rfc7807)
- [RFC 9457 (IETF)](https://www.rfc-editor.org/rfc/rfc9457.html)
- [OWASP Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)

### API Design Resources
- [API Pagination Guide - Treblle](https://treblle.com/blog/api-pagination-guide-techniques-benefits-implementation)
- [Cursor vs Offset Pagination](https://medium.com/@maryam-bit/offset-vs-cursor-based-pagination-choosing-the-best-approach-2e93702a118b)
- [API Versioning Best Practices](https://getlate.dev/blog/api-versioning-best-practices)
- [Speakeasy Pagination](https://www.speakeasy.com/api-design/pagination)

### R Async Resources
- [Plumber + future: Async Web APIs](https://posit.co/resources/videos/plumber-and-future-async-web-apis/)
- [Mirai Promises](https://mirai.r-lib.org/articles/v3-promises.html)
- [FvD/futureplumber GitHub](https://github.com/FvD/futureplumber)

### Data Sources
- [OMIM Downloads](https://www.omim.org/downloads/)
- [Human Phenotype Ontology](https://hpo.jax.org/)
- [Mouse Genome Informatics](https://www.informatics.jax.org/)

### Clean Code
- [Clean Code Principles - Codacy](https://blog.codacy.com/clean-code-principles)
- [SOLID, DRY, KISS Guide](https://medium.com/@hlfdev/kiss-dry-solid-yagni-a-simple-guide-to-some-principles-of-software-engineering-and-clean-code-05e60233c79f)

---

*Research completed: 2026-01-23*
*Confidence: MEDIUM-HIGH (official sources verified, some OMIM migration details need validation)*
*Researcher: GSD Project Researcher (Features dimension)*
