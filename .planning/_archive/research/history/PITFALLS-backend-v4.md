# Domain Pitfalls: SysNDD v4 Backend Overhaul

**Domain:** R/Plumber API backend modernization
**Researched:** 2026-01-23
**Confidence:** HIGH (based on codebase analysis and verified documentation)

---

## Executive Summary

This pitfalls document addresses six critical areas of the v4 Backend Overhaul:

1. **R Version Upgrade (4.1.2 to 4.4.x)** - Package compatibility, Matrix/lme4 issues, renv migration
2. **Async/Promises in Plumber** - Worker blocking, filter forwarding, graphics device conflicts
3. **Password Migration (plaintext to bcrypt/sodium)** - Dual-hash transition, existing user handling
4. **OMIM Data Source Migration** - genemap2 to mim2gene.txt + JAX API transition
5. **Large Codebase Refactoring** - DRY/KISS/SOLID application to 1,234-line god file
6. **SQL Injection Remediation** - 66 paste0() vulnerabilities to parameterized queries

Each pitfall includes warning signs, prevention strategies, and phase assignment recommendations.

---

## Critical Pitfalls

Mistakes that cause rewrites, security breaches, or data loss.

### Pitfall 1: Matrix Package ABI Breaking Changes During R Upgrade

**What goes wrong:** After upgrading R from 4.1.2 to 4.4.x, the Matrix package (currently 1.4-0 in renv.lock) breaks lme4 and dependent packages like FactoMineR. The ABI (Application Binary Interface) changes between Matrix versions are not backward compatible.

**Why it happens:**
- Matrix >= 1.6.2 is required by lme4 >= 1.1-28
- Matrix 1.7-0 requires R >= 4.4.0
- Current setup uses Matrix 1.4-0 with R 4.1.2 (already has compatibility workarounds in Dockerfile using 2022-01-03 P3M snapshot)
- Binary incompatibility causes "function 'cholmod_factor_ldetA' not provided by package 'Matrix'" errors

**Consequences:**
- API startup fails completely
- FactoMineR and factoextra (used for clustering analysis) become unusable
- Complete rebuild of package dependencies required

**Prevention:**
1. Upgrade Matrix to 1.6.3+ BEFORE upgrading R
2. Use renv snapshot with Matrix 1.6.3 and lme4 1.1-35+
3. Test FactoMineR clustering endpoints after upgrade
4. Remove P3M 2022-01-03 snapshot workaround and use latest packages

**Detection (Warning Signs):**
- `Error in initializePtr()` during API startup
- Package load warnings about Matrix version
- Any mention of CHOLMOD in error messages

**Phase Assignment:** Phase 1 (Foundation) - Must be resolved before any other work

**Sources:**
- [lme4 Matrix compatibility issue #763](https://github.com/lme4/lme4/issues/763)
- [Databricks lme4 Matrix guide](https://kb.databricks.com/libraries/installing-lme4-fails-with-a-matrix-version-error)
- Observed in current Dockerfile lines 127-140

---

### Pitfall 2: SQL Injection via paste0() - 66 Vulnerable Statements

**What goes wrong:** User-controlled input is concatenated directly into SQL statements using paste0(), allowing SQL injection attacks that can read/modify/delete database contents.

**Why it happens:**
- Legacy codebase predates modern R database practices
- paste0() is convenient but creates injection vectors
- All 66 instances in database-functions.R use this pattern

**Specific Vulnerable Patterns Found:**
```r
# Lines 145-151: put_db_entity_deactivation - entity_id not sanitized
dbExecute(sysndd_db, paste0("UPDATE ndd_entity SET ",
  "is_active = 0, ",
  "replaced_by = ", replacement,
  " WHERE entity_id = ", entity_id, ";"))

# Lines 440-443: PUT publication - review_id not sanitized
dbExecute(sysndd_db,
  paste0("DELETE FROM ndd_review_publication_join WHERE review_id = ",
  review_id, ";"))

# Lines 703, 713 in user_endpoints.R: user_id not sanitized
paste0("SELECT COUNT(*) as count FROM user WHERE user_id = ", user_id, ";")
dbExecute(sysndd_db, paste0("DELETE FROM user WHERE user_id = ", user_id, ";"))
```

**Consequences:**
- Complete database compromise
- Data exfiltration
- Data destruction
- Privilege escalation (attacker becomes admin)

**Prevention:**
1. Use DBI's parameterized queries with dbBind():
```r
# SAFE approach
stmt <- dbSendQuery(sysndd_db,
  "UPDATE ndd_entity SET is_active = 0, replaced_by = ? WHERE entity_id = ?")
dbBind(stmt, list(replacement, entity_id))
dbFetch(stmt)
dbClearResult(stmt)
```

2. Use glue_sql() from glue package for complex queries:
```r
# SAFE approach with glue
library(glue)
sql <- glue_sql("SELECT * FROM users WHERE id = {user_id}", .con = sysndd_db)
```

3. Never use paste0()/paste() for SQL construction with user input

4. For RMariaDB, use `?` placeholders (positional matching)

**Detection (Warning Signs):**
- Any grep for `paste0.*WHERE|paste0.*SELECT|paste0.*UPDATE|paste0.*DELETE`
- String concatenation in dbExecute()/dbGetQuery() calls
- User input flowing to database functions without validation

**Phase Assignment:** Phase 2 (Security) - High priority after foundation

**Sources:**
- [Posit: Run Queries Safely](https://solutions.posit.co/connections/db/best-practices/run-queries-safely/)
- [DBI Advanced Usage - Parameterized Queries](https://dbi.r-dbi.org/articles/DBI-advanced.html)
- [DBI dbBind documentation](https://rdrr.io/cran/DBI/man/dbBind.html)

---

### Pitfall 3: Plaintext Password Comparison Breaks After Migration

**What goes wrong:** After adding bcrypt hashing, existing users with plaintext passwords in database cannot authenticate because bcrypt verification fails on non-hashed strings.

**Why it happens:**
- Current authentication (authentication_endpoints.R lines 151-154) does direct comparison:
```r
filter(user_name == check_user & password == check_pass & approved == 1)
```
- Bcrypt hash format ($2a$ or $2b$ prefix) is not detected
- No migration path for existing plaintext passwords
- Users locked out immediately after deployment

**Consequences:**
- All existing users locked out
- No way to recover without database access
- Production outage

**Prevention:**

1. **Implement dual-verification during transition:**
```r
verify_password <- function(input_password, stored_hash) {
  # Check if stored value is a bcrypt hash (starts with $2)
  if (str_detect(stored_hash, "^\\$2[aby]\\$")) {
    return(sodium::password_verify(stored_hash, input_password))
  } else {
    # Legacy plaintext comparison (temporary)
    return(stored_hash == input_password)
  }
}
```

2. **On successful login, upgrade hash in-place:**
```r
# After successful plaintext verification
if (!str_detect(stored_hash, "^\\$2[aby]\\$")) {
  new_hash <- sodium::password_store(input_password)
  # Update database with new hash
  dbExecute(conn, "UPDATE user SET password = ? WHERE user_id = ?",
            params = list(new_hash, user_id))
}
```

3. **Add password format column to track migration:**
```sql
ALTER TABLE user ADD COLUMN password_format
  ENUM('plaintext', 'bcrypt') DEFAULT 'plaintext';
```

4. **Set deadline for forced password reset** for unmigrated accounts

**Detection (Warning Signs):**
- Login failures after deployment
- Users reporting "wrong password" errors
- Database queries returning plaintext-looking passwords

**Phase Assignment:** Phase 2 (Security) - Must coordinate with SQL injection fixes

**Sources:**
- [How to safely migrate to bcrypt](https://antonvroemans.medium.com/how-can-i-safely-migrate-to-bcrypt-a2189a8c8cb)
- [Immediately migrating existing passwords to bcrypt](https://taylor.fausak.me/2013/05/21/immediately-migrating-existing-passwords-to-bcrypt/)
- Current code: authentication_endpoints.R lines 133-182

---

### Pitfall 4: future::future() Blocking in Plumber Async Filters

**What goes wrong:** Adding async to existing synchronous Plumber API causes request blocking when all future workers are busy, worse performance than synchronous version.

**Why it happens:**
- When `future::nbrOfFreeWorkers()` returns 0, future blocks the main R session
- Filter chains cannot use `plumber::forward()` inside future blocks
- Graphics device conflicts when multiple promises try to render plots

**Current Blocking Operations in SysNDD:**
- `update_ontology` endpoint (admin_endpoints.R) - fetches external data, processes large datasets
- `update_hgnc_data` endpoint - downloads HGNC file, processes gene data
- STRINGdb and biomaRt queries in various endpoints

**Consequences:**
- API appears to hang during heavy operations
- Timeouts on frontend
- Worse performance than before async implementation

**Prevention:**

1. **Use promises::future_promise() instead of future::future():**
```r
# AVOID
endpoint_handler <- function() {
  result <- future::future({
    expensive_operation()
  })
  value(result)  # Blocks!
}

# PREFER
endpoint_handler <- function() {
  promises::future_promise({
    expensive_operation()
  })
}
```

2. **Never call forward() inside a future block:**
```r
# WRONG - forward() inside future
filter <- function(req, res) {
  future({
    check <- auth_check()
    plumber::forward()  # Will fail!
  })
}

# CORRECT - forward() after promise resolves
filter <- function(req, res) {
  promises::future_promise({
    auth_check()
  }) %...>% {
    plumber::forward()
  }
}
```

3. **Configure adequate workers:**
```r
# In start_sysndd_api.R
library(future)
plan(multisession, workers = availableCores() - 1)  # Leave 1 core for main
```

4. **Queue long operations instead of blocking:**
- Background job queue for admin operations
- Return job_id immediately, poll for status

**Detection (Warning Signs):**
- Request timeouts under moderate load
- API becomes unresponsive during admin operations
- Log showing "waiting for free worker"

**Phase Assignment:** Phase 3 (Async) - After security fixes

**Sources:**
- [plumber + future: Async Web APIs](https://cloud.rstudio.com/resources/rstudioglobal-2021/plumber-and-future-async-web-apis/)
- [Advanced future and promises usage](https://rstudio.github.io/promises/articles/future_promise.html)
- [Plumber async filters issue #907](https://github.com/rstudio/plumber/issues/907)

---

### Pitfall 5: renv Restore Failures After R Version Upgrade

**What goes wrong:** `renv::restore()` fails repeatedly after R upgrade, requiring manual intervention for each package, turning a 5-minute task into hours of work.

**Why it happens:**
- renv.lock was created with R 4.1.2; packages may not be compatible with R 4.4.x
- Bioconductor version mismatch (strict R version requirements)
- Packages built with R < 4.0.0 must be rebuilt
- Current renv.lock is incomplete (requires Dockerfile workarounds)

**Current State (from Dockerfile analysis):**
- renv.lock has Matrix 1.4-0 (incompatible with modern lme4)
- Critical packages manually installed outside renv: plumber, RMariaDB, igraph, xlsx, tidyverse
- Bioconductor packages (STRINGdb, biomaRt) installed separately
- FactoMineR requires P3M 2022-01-03 snapshot workaround

**Consequences:**
- Hours of manual package-by-package restoration
- CI/CD pipeline failures
- Reproducibility lost (defeats purpose of renv)
- Docker builds become flaky

**Prevention:**

1. **Create fresh renv.lock on target R version:**
```r
# On machine with R 4.4.x
renv::init(bare = TRUE)
renv::install(c("plumber", "RMariaDB", ...))
BiocManager::install(c("STRINGdb", "biomaRt"))
renv::snapshot()
```

2. **Test in Docker before committing:**
```dockerfile
# Test stage in Dockerfile
FROM rocker/r-ver:4.4.1 AS test
COPY renv.lock renv.lock
RUN R -e 'renv::restore()'
RUN R -e 'library(plumber); library(RMariaDB); ...'
```

3. **Pin Bioconductor version explicitly:**
```r
# In .Rprofile
options(repos = BiocManager::repositories(version = "3.18"))
```

4. **Document package installation order** (some packages have strict dependency ordering)

5. **Remove all Dockerfile manual installs** once renv.lock is complete

**Detection (Warning Signs):**
- "Package X was installed before R 4.0.0: please re-install it"
- "Version X.Y is not compatible with R"
- Multiple `renv::install()` calls needed after `restore()`

**Phase Assignment:** Phase 1 (Foundation) - First task before any code changes

**Sources:**
- [renv::restore() failing with R version differences #1714](https://github.com/rstudio/renv/issues/1714)
- [Update to R 4.1 triggers re-install warnings #750](https://github.com/rstudio/renv/issues/750)
- Current Dockerfile lines 121-146

---

## Moderate Pitfalls

Mistakes that cause delays, technical debt, or partial functionality loss.

### Pitfall 6: God File Refactoring Creates Circular Dependencies

**What goes wrong:** Splitting database-functions.R (1,234 lines) into smaller modules creates circular dependencies where module A requires module B which requires module A.

**Why it happens:**
- Functions were written to share state via global variables (`dw`, `pool`)
- Functions call each other without clear hierarchy
- No dependency injection pattern exists

**Current Problematic Patterns:**
```r
# database-functions.R uses:
# - Global `pool` for reads
# - Global `dw` for credentials
# - Global `dw$dbname`, `dw$user`, etc for direct connections

# Functions that call each other:
# put_post_db_review() -> relies on pool
# put_db_review_approve() -> relies on pool AND creates new connection
```

**Consequences:**
- Refactored code fails to load
- "Object not found" errors at startup
- Must undo refactoring and start over

**Prevention:**

1. **Map dependencies before splitting:**
```
database-functions.R dependency graph:
- post_db_entity: dw, dbConnect
- put_db_entity_deactivation: dw, dbConnect, dbExecute
- put_post_db_review: dw, pool, dbConnect
...
```

2. **Extract pure functions first** (no global state):
```r
# Good candidate - no global dependencies
generate_update_query <- function(data) {
  data %>%
    mutate(row = row_number()) %>%
    ...
}
```

3. **Use dependency injection for database access:**
```r
# BEFORE (coupled)
post_db_entity <- function(entity_data) {
  sysndd_db <- dbConnect(RMariaDB::MariaDB(),
    dbname = dw$dbname,  # Global!
    ...
  )
}

# AFTER (injectable)
post_db_entity <- function(entity_data, connection_pool = pool) {
  conn <- poolCheckout(connection_pool)
  on.exit(poolReturn(conn))
  ...
}
```

4. **Load order matters** - document and enforce in start_sysndd_api.R

**Detection (Warning Signs):**
- "Object 'X' not found" errors at startup
- Tests pass individually but fail together
- Circular source() calls

**Phase Assignment:** Phase 4 (Refactoring) - After async implementation

---

### Pitfall 7: OMIM genemap2 Data Structure Changes

**What goes wrong:** Code expecting genemap2.txt fields fails silently when mim2gene.txt lacks disease name columns, returning empty/null results instead of errors.

**Why it happens:**
- genemap2.txt includes disease names (syndrome/phenotype text)
- mim2gene.txt only contains MIM number mappings to gene IDs
- Disease name must come from separate source (JAX API/MGI)
- Silent failures when fields are accessed but missing

**Current Data Flow (assumed based on context):**
```
genemap2.txt -> parse -> disease_ontology_set table
             -> disease_ontology_name field populated
```

**New Required Flow:**
```
mim2gene.txt -> MIM number -> gene ID mapping
     +
JAX/MGI API -> MIM number -> disease name lookup
     =
disease_ontology_set with complete data
```

**Consequences:**
- Disease names appear as NULL/empty
- Ontology updates appear successful but data is incomplete
- Frontend shows entities without disease names
- Data integrity violations (required field missing)

**Prevention:**

1. **Validate data completeness before database write:**
```r
validate_ontology_data <- function(df) {
  required_cols <- c("disease_ontology_id", "disease_ontology_name", "hgnc_id")

  # Check for NULL/NA in required columns
  missing <- df %>%
    filter(is.na(disease_ontology_name) | disease_ontology_name == "")

  if (nrow(missing) > 0) {
    stop(paste("Missing disease names for", nrow(missing), "entries"))
  }
}
```

2. **Implement JAX/MGI fallback for disease names:**
```r
get_disease_name <- function(mim_number) {
  # Primary: local cache
  cached <- get_cached_disease_name(mim_number)
  if (!is.null(cached)) return(cached)

  # Secondary: JAX MouseMine API
  jax_result <- query_mousemine(mim_number)
  if (!is.null(jax_result)) return(jax_result$disease_name)

  # Fallback: return placeholder with warning
  warning(paste("No disease name found for", mim_number))
  return(paste("OMIM:", mim_number))
}
```

3. **Add database constraint** for non-null disease_ontology_name

4. **Test with both data sources** before switching

**Detection (Warning Signs):**
- Empty disease name fields in UI
- Increased NULL values in disease_ontology_set table
- Ontology update completes but data appears incomplete

**Phase Assignment:** Phase 5 (OMIM Migration) - After core refactoring

**Sources:**
- [OMIM Downloads](https://www.omim.org/downloads/)
- [MGI Mouse Genome Informatics](https://www.informatics.jax.org/)
- [MouseMine programmatic access](http://www.mousemine.org)

---

### Pitfall 8: Connection Pool Exhaustion During Async Operations

**What goes wrong:** Multiple async requests exhaust the database connection pool, causing "Cannot acquire connection" errors under load.

**Why it happens:**
- Current code creates new connections with dbConnect() per operation
- pool::dbPool exists but not consistently used
- Async operations can spawn many concurrent requests
- Connections not properly returned to pool

**Current Pattern (database-functions.R):**
```r
# Creates NEW connection instead of using pool
sysndd_db <- dbConnect(RMariaDB::MariaDB(),
  dbname = dw$dbname,
  user = dw$user,
  ...
)
# Sometimes forgets dbDisconnect() in error paths
```

**Consequences:**
- "Too many connections" database error
- API becomes unresponsive under load
- Memory leaks from unclosed connections

**Prevention:**

1. **Always use pool for read operations:**
```r
# GOOD - uses existing pool
result <- pool %>%
  tbl("table_name") %>%
  filter(condition) %>%
  collect()
```

2. **For write operations, checkout/return pattern:**
```r
# GOOD - proper pool usage for writes
write_to_db <- function(data) {
  conn <- poolCheckout(pool)
  on.exit(poolReturn(conn), add = TRUE)

  tryCatch({
    dbBegin(conn)
    dbAppendTable(conn, "table", data)
    dbCommit(conn)
  }, error = function(e) {
    dbRollback(conn)
    stop(e)
  })
}
```

3. **Configure pool appropriately:**
```r
pool <- dbPool(
  drv = RMariaDB::MariaDB(),
  ...
  minSize = 2,      # Minimum connections
  maxSize = 10,     # Maximum connections
  idleTimeout = 60  # Seconds before closing idle
)
```

4. **Never create standalone dbConnect() in endpoint handlers**

**Detection (Warning Signs):**
- "Cannot acquire connection" errors in logs
- Increasing response times under load
- MySQL "Too many connections" errors

**Phase Assignment:** Phase 3 (Async) - Critical for async implementation

---

### Pitfall 9: Sodium vs Bcrypt Prefix Incompatibility

**What goes wrong:** sodium::password_store() uses Argon2 algorithm with different prefix than bcrypt ($argon2 vs $2b$), causing verification failures when code expects bcrypt.

**Why it happens:**
- sodium package provides both bcrypt and Argon2
- Default sodium::password_store() uses Argon2, not bcrypt
- Argon2 hash: `$argon2id$v=19$m=...`
- Bcrypt hash: `$2b$12$...`
- Code written for bcrypt fails with Argon2 hashes

**Consequences:**
- Hash verification always fails
- Users locked out after password change
- Security audit flags algorithm confusion

**Prevention:**

1. **Explicitly use bcrypt function:**
```r
# CORRECT for bcrypt
library(bcrypt)
hashed <- bcrypt::hashpw(password, bcrypt::gensalt(cost = 12))
verified <- bcrypt::checkpw(password, hashed)

# OR use sodium with explicit algorithm
library(sodium)
hashed <- sodium::password_store(password, opslimit = 2, memlimit = 67108864)
verified <- sodium::password_verify(hashed, password)
```

2. **Document chosen algorithm in code:**
```r
# Configuration constant
PASSWORD_ALGORITHM <- "argon2id"  # or "bcrypt"
PASSWORD_COST <- 12  # bcrypt work factor OR argon2 ops/mem limits
```

3. **Verify hash format in tests:**
```r
test_that("password uses correct algorithm", {
  hash <- hash_password("test123")
  expect_true(str_detect(hash, "^\\$2[aby]\\$"))  # bcrypt
  # OR
  expect_true(str_detect(hash, "^\\$argon2"))     # argon2
})
```

**Detection (Warning Signs):**
- Hash starts with `$argon2` instead of `$2b$`
- "Invalid hash format" errors
- Password verification always returns FALSE

**Phase Assignment:** Phase 2 (Security) - Part of password migration

**Sources:**
- [Hashing in Action: Understanding bcrypt](https://auth0.com/blog/hashing-in-action-understanding-bcrypt/)
- [bcrypt Wikipedia](https://en.wikipedia.org/wiki/Bcrypt)

---

## Minor Pitfalls

Mistakes that cause annoyance or technical debt but are fixable.

### Pitfall 10: Inconsistent Error Response Formats

**What goes wrong:** After refactoring, some endpoints return `{error: "message"}` while others return `{status: 400, message: "text"}`, breaking frontend error handling.

**Why it happens:**
- Current codebase mixes formats (observed in database-functions.R)
- No enforced error response schema
- Each developer chose own format

**Current Inconsistent Patterns:**
```r
# Format 1 (database-functions.R line 87)
return(list(status = 500, message = "Internal Server Error.", error = db_error))

# Format 2 (database-functions.R line 871)
return(list(status = 400, error = "Submitted data can not be null."))

# Format 3 (authentication_endpoints.R)
return(list(error = "Authorization http header missing."))
```

**Prevention:**

1. **Define single error response helper:**
```r
api_error <- function(status, message, details = NULL) {
  list(
    status = status,
    error = TRUE,
    message = message,
    details = details,
    timestamp = Sys.time()
  )
}
```

2. **Use consistently in all endpoints:**
```r
# Everywhere
return(api_error(400, "Invalid input", "entity_id must be numeric"))
```

**Phase Assignment:** Phase 4 (Refactoring) - Low priority cleanup

---

### Pitfall 11: Test Database State Pollution

**What goes wrong:** Running tests modifies production/development database state, causing failures on subsequent runs or corrupting real data.

**Why it happens:**
- Tests use same `pool` and `dw` config as production code
- No test isolation or cleanup
- Integration tests write to real tables

**Prevention:**

1. **Use separate test database:**
```r
# In tests/testthat/setup.R
test_pool <<- dbPool(
  drv = RMariaDB::MariaDB(),
  dbname = "sysndd_test",  # Separate DB
  ...
)
```

2. **Wrap tests in transactions:**
```r
test_that("write operations work", {
  conn <- poolCheckout(test_pool)
  dbBegin(conn)
  on.exit({
    dbRollback(conn)  # Always rollback
    poolReturn(conn)
  })

  # Test code here
})
```

3. **Mock database for unit tests** (see tests/testthat/helper-db-mock.R)

**Phase Assignment:** Phase 4 (Refactoring) - Testing infrastructure

---

### Pitfall 12: Logging Sensitive Data

**What goes wrong:** Password or JWT tokens appear in logs during debugging, violating security requirements.

**Why it happens:**
- Current logging (start_sysndd_api.R lines 369-382) logs query strings
- Query strings may contain passwords (GET authenticate endpoint)
- postBody logging could capture sensitive PUT data

**Current Risk (authentication_endpoints.R):**
```r
#* @get authenticate
function(req, res, user_name, password) {  # password in query string!
```

**Prevention:**

1. **Sanitize logs:**
```r
sanitize_log <- function(str) {
  str %>%
    str_replace_all("password=[^&]+", "password=***") %>%
    str_replace_all("Bearer [A-Za-z0-9._-]+", "Bearer ***")
}

log_info(skip_formatter(sanitize_log(log_entry)))
```

2. **Move password to request body** (POST instead of GET)

3. **Configure log retention/purging**

**Phase Assignment:** Phase 2 (Security) - Part of authentication overhaul

---

## Phase-Specific Warnings Summary

| Phase | Likely Pitfall | Mitigation |
|-------|---------------|------------|
| 1: Foundation | renv restore failures (#5) | Fresh renv.lock on R 4.4.x |
| 1: Foundation | Matrix/lme4 breaking changes (#1) | Upgrade Matrix before R |
| 2: Security | Password migration lockout (#3) | Dual-hash verification |
| 2: Security | SQL injection patterns missed | Automated grep check |
| 2: Security | Algorithm prefix confusion (#9) | Document chosen algorithm |
| 3: Async | Worker blocking (#4) | Use future_promise() |
| 3: Async | Pool exhaustion (#8) | Consistent pool usage |
| 4: Refactoring | Circular dependencies (#6) | Map dependencies first |
| 4: Refactoring | Inconsistent error formats (#10) | Define error helper |
| 5: OMIM | Empty disease names (#7) | Validate before write |

---

## Pre-Phase Checklist

Before starting any phase, verify:

- [ ] renv.lock tested on R 4.4.x in Docker
- [ ] Matrix 1.6.3+ confirmed compatible
- [ ] Test database exists and is isolated
- [ ] Logging sanitization in place
- [ ] Backup of current production database

---

## Sources

### Verified (HIGH Confidence)
- [Posit: Run Queries Safely](https://solutions.posit.co/connections/db/best-practices/run-queries-safely/)
- [DBI Advanced Usage](https://dbi.r-dbi.org/articles/DBI-advanced.html)
- [plumber async documentation](https://www.rplumber.io/articles/programmatic-usage.html)
- [promises + future guide](https://rstudio.github.io/promises/articles/future_promise.html)
- [renv GitHub issues #750, #1714](https://github.com/rstudio/renv/issues)
- [lme4 Matrix issues #763, #704](https://github.com/lme4/lme4/issues)

### Codebase Analysis (HIGH Confidence)
- `/home/bernt-popp/development/sysndd/api/functions/database-functions.R` (1,234 lines)
- `/home/bernt-popp/development/sysndd/api/endpoints/authentication_endpoints.R`
- `/home/bernt-popp/development/sysndd/api/Dockerfile`
- `/home/bernt-popp/development/sysndd/api/renv.lock`
- `/home/bernt-popp/development/sysndd/api/start_sysndd_api.R`

### External Research (MEDIUM Confidence)
- [bcrypt migration strategies](https://antonvroemans.medium.com/how-can-i-safely-migrate-to-bcrypt-a2189a8c8cb)
- [OMIM data files documentation](https://www.omim.org/downloads/)
- [MGI/JAX database access](https://www.informatics.jax.org/)
