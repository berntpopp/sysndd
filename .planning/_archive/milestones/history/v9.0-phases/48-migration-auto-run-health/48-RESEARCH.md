# Phase 48: Migration Auto-Run & Health - Research

**Researched:** 2026-01-29
**Domain:** R Plumber API startup integration, MySQL advisory locking, Kubernetes health probes
**Confidence:** HIGH

## Summary

This phase integrates the existing migration runner (Phase 47) into the API startup sequence and adds health endpoints for migration status visibility. The core challenge is coordinating migrations across multiple worker processes using MySQL advisory locks (GET_LOCK/RELEASE_LOCK) and implementing Kubernetes-compatible liveness/readiness probes.

The existing `run_migrations()` function from `api/functions/migration-runner.R` provides the migration execution foundation. The integration point is `api/start_sysndd_api.R` between pool creation (line 179-187) and endpoint mounting (line 463+). The current `/health` endpoint at `api/endpoints/health_endpoints.R` returns liveness status and needs a `/ready` sibling for readiness with migration checks.

**Primary recommendation:** Use MySQL `GET_LOCK('sysndd_migration', 30)` for worker coordination, call migrations between pool creation and endpoint mounting, and add `/health/ready` endpoint that returns HTTP 503 when migrations are pending.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DBI | existing | Database interface for GET_LOCK calls | Already in use, standard R database access |
| RMariaDB | existing | MySQL-specific driver for locking | Already in use, supports GET_LOCK |
| pool | existing | Connection pooling for startup queries | Already in use, connection management |
| logger | existing | Structured logging for migration output | Already in use, consistent log format |
| plumber | existing | Health endpoints via pr_mount | Already in use, API framework |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| tictoc | existing | Timing for migration duration | Already in use, startup timing |
| jsonlite | existing | JSON response serialization | Already in use, health endpoint responses |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| GET_LOCK | SELECT FOR UPDATE on schema_version | GET_LOCK simpler, doesn't need row locking |
| GET_LOCK | Redis locks | GET_LOCK uses existing MySQL, no new dependency |
| HTTP 503 | Custom JSON status | HTTP 503 is standard for Kubernetes readiness |

**Installation:**
No new packages required - all libraries already in renv.lock.

## Architecture Patterns

### Recommended Integration Structure
```
api/start_sysndd_api.R
├── ... (existing setup code, lines 1-187)
├── pool creation (line 179-187)
│
├── [NEW] Migration integration point (insert here)
│   ├── Source migration-runner.R
│   ├── Acquire advisory lock
│   ├── Run migrations (blocking)
│   ├── Release lock / handle errors
│   └── Store result for health endpoint
│
├── ... (global objects, memoization, etc.)
└── Endpoint mounting (line 463+)

api/endpoints/health_endpoints.R
├── GET /  (existing liveness - lightweight)
├── GET /health/performance (existing - metrics)
└── [NEW] GET /ready (readiness with migration check)
```

### Pattern 1: Advisory Lock Wrapper
**What:** Wrap migration execution in MySQL advisory lock acquisition/release
**When to use:** Any operation that must be serialized across multiple API workers
**Example:**
```r
# Source: MySQL 8.0 Reference Manual - Locking Functions
# https://dev.mysql.com/doc/refman/8.0/en/locking-functions.html

acquire_migration_lock <- function(conn, lock_name = "sysndd_migration", timeout = 30) {
  result <- DBI::dbGetQuery(
    conn,
    sprintf("SELECT GET_LOCK('%s', %d) AS acquired", lock_name, timeout)
  )
  if (result$acquired != 1) {
    if (is.na(result$acquired)) {
      stop("Migration lock acquisition failed: database error")
    } else {
      stop(sprintf("Migration lock acquisition timed out after %d seconds", timeout))
    }
  }
  log_info("Acquired migration lock '{lock_name}'")
  return(TRUE)
}

release_migration_lock <- function(conn, lock_name = "sysndd_migration") {
  result <- DBI::dbGetQuery(
    conn,
    sprintf("SELECT RELEASE_LOCK('%s') AS released", lock_name)
  )
  if (result$released == 1) {
    log_info("Released migration lock '{lock_name}'")
  }
  return(result$released == 1)
}
```

### Pattern 2: Blocking Startup Migration
**What:** Run migrations between pool creation and endpoint mounting, crash on failure
**When to use:** Ensuring schema is current before API serves requests
**Example:**
```r
# Integration point in start_sysndd_api.R (after pool creation, before endpoints)

# Source migration runner
source("functions/migration-runner.R", local = TRUE)

# Run migrations with lock coordination
tryCatch({
  # Checkout connection for lock (separate from pool for duration)
  migration_conn <- pool::poolCheckout(pool)
  on.exit(pool::poolReturn(migration_conn), add = TRUE)

  # Acquire lock (blocks until available or timeout)
  acquire_migration_lock(migration_conn, timeout = 30)
  on.exit(release_migration_lock(migration_conn), add = TRUE)

  # Run migrations (uses pool internally)
  start_time <- Sys.time()
  result <- run_migrations(migrations_dir = "db/migrations", conn = pool)
  duration <- difftime(Sys.time(), start_time, units = "secs")

  # Log summary
  if (result$newly_applied > 0) {
    log_info("Migrations complete ({result$newly_applied} applied in {round(duration, 2)}s): {paste(result$filenames, collapse = ', ')}")
  } else {
    log_info("Schema up to date ({result$total_applied} migrations applied)")
  }

  # Store result for health endpoint access
  migration_status <<- list(
    pending_migrations = 0,
    total_migrations = result$total_applied,
    last_run = Sys.time()
  )

}, error = function(e) {
  log_error("Migration failed: {e$message}")
  # Crash API - forces fix before deploy
  stop(paste("API startup aborted: migration failure -", e$message))
})
```

### Pattern 3: Readiness Endpoint
**What:** Health endpoint that reports migration status for Kubernetes readiness probes
**When to use:** Container orchestration needs to know when API is ready to serve traffic
**Example:**
```r
# Source: Kubernetes Health Checks documentation
# https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/

#* Readiness check for Kubernetes probes
#*
#* Returns HTTP 200 when ready to serve, HTTP 503 when migrations pending.
#* Reports pending migration count for monitoring.
#*
#* @tag health
#* @serializer json
#*
#* @get /ready
function(req, res) {
  # Check if migrations have run (variable set during startup)
  if (!exists("migration_status") || is.null(migration_status)) {
    res$status <- 503L
    return(list(
      status = "not_ready",
      reason = "migrations_not_run",
      pending_migrations = NA
    ))
  }

  pending <- migration_status$pending_migrations

  if (pending > 0) {
    res$status <- 503L
    return(list(
      status = "not_ready",
      reason = "migrations_pending",
      pending_migrations = pending
    ))
  }

  list(
    status = "ready",
    pending_migrations = 0
  )
}
```

### Anti-Patterns to Avoid
- **Running migrations in endpoint handler:** Never defer migrations to first request - run at startup
- **Ignoring lock timeout:** Always handle timeout case with clear error, don't wait forever
- **Using LOCK TABLES for migrations:** GET_LOCK is advisory and doesn't block normal queries
- **Checking pending in liveness probe:** Liveness should be lightweight; readiness checks state

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Worker coordination | Custom file locks or polling | MySQL GET_LOCK | Database-level, cross-host, timeout support |
| Migration execution | Manual SQL file reading | Existing run_migrations() | Phase 47 built robust runner with DELIMITER handling |
| Health probe responses | Custom JSON structures | HTTP status codes (200/503) | Kubernetes/Docker expect standard HTTP semantics |
| Lock cleanup | Manual try/finally | on.exit() chains | R idiom for guaranteed cleanup |

**Key insight:** MySQL advisory locks (GET_LOCK/RELEASE_LOCK) are specifically designed for application-level coordination like migrations. They work across connections, have built-in timeout, and integrate with MySQL's deadlock detector.

## Common Pitfalls

### Pitfall 1: Lock Not Released on Error
**What goes wrong:** Migration fails, lock remains held, other workers wait forever
**Why it happens:** Error handling doesn't include lock release
**How to avoid:** Use `on.exit(release_migration_lock(...), add = TRUE)` immediately after acquiring
**Warning signs:** Workers hang during startup, timeout errors on subsequent restarts

### Pitfall 2: Connection Pool Exhaustion During Migration
**What goes wrong:** Migration uses all pool connections, health check fails
**Why it happens:** Migrations run many queries without returning connections
**How to avoid:**
- Migration runner already handles this with poolCheckout/poolReturn per operation
- Health endpoint uses minimal connection (or no connection for liveness)
**Warning signs:** "pool exhausted" errors during startup

### Pitfall 3: Migrations Directory Not Mounted
**What goes wrong:** API starts but finds no migrations, reports "up to date" incorrectly
**Why it happens:** Docker container doesn't have db/migrations mounted
**How to avoid:**
- Add `./db/migrations:/app/db/migrations:ro` to docker-compose volumes
- Verify path in startup logs
**Warning signs:** "No migration files found" when migrations exist

### Pitfall 4: Health Endpoint in AUTH_ALLOWLIST Missing /ready
**What goes wrong:** Readiness probe returns 401 Unauthorized
**Why it happens:** New /health/ready not added to public endpoint list
**How to avoid:** Add "/health/ready" and "/health/ready/" to AUTH_ALLOWLIST in middleware.R
**Warning signs:** Docker health check fails with auth errors

### Pitfall 5: Race Condition Between Lock Acquire and Pool Creation
**What goes wrong:** Lock acquisition fails because pool not ready
**Why it happens:** Pool creation is async, lock check runs before connections available
**How to avoid:** Run migration integration AFTER pool creation block (line 187+)
**Warning signs:** "connection not available" errors on first lock attempt

## Code Examples

Verified patterns from official sources and existing codebase:

### MySQL GET_LOCK Usage
```r
# Source: MySQL 8.0 Reference Manual - Locking Functions
# https://dev.mysql.com/doc/refman/8.0/en/locking-functions.html

# Acquire lock with 30 second timeout
# Returns: 1 = success, 0 = timeout, NULL = error
result <- DBI::dbGetQuery(conn, "SELECT GET_LOCK('sysndd_migration', 30) AS acquired")

# Release lock
# Returns: 1 = released, 0 = not held by this connection, NULL = doesn't exist
DBI::dbGetQuery(conn, "SELECT RELEASE_LOCK('sysndd_migration') AS released")

# Check if lock is free (non-blocking)
DBI::dbGetQuery(conn, "SELECT IS_FREE_LOCK('sysndd_migration') AS free")

# Check who holds lock (returns connection_id or NULL)
DBI::dbGetQuery(conn, "SELECT IS_USED_LOCK('sysndd_migration') AS holder")
```

### Existing Migration Runner Integration
```r
# Source: api/functions/migration-runner.R (Phase 47)

# The run_migrations() function already returns structured result:
result <- run_migrations(migrations_dir = "db/migrations", conn = pool)
# Returns list:
#   total_applied: count of all applied migrations
#   newly_applied: count of migrations applied this run
#   filenames: character vector of newly applied filenames

# For pending count (used in health endpoint):
migration_files <- list_migration_files("db/migrations")
applied <- get_applied_migrations(pool)
pending_count <- length(setdiff(migration_files, applied))
```

### Existing Health Endpoint Structure
```r
# Source: api/endpoints/health_endpoints.R

# Current liveness endpoint (keep as-is):
#* @get /
function(req, res) {
  list(
    status = "healthy",
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    version = sysndd_api_version
  )
}

# New readiness endpoint follows same pattern with migration check
```

### Logger Output Format
```r
# Source: https://daroczig.github.io/logger/articles/customize_logger.html
# Existing format from codebase:

log_info("Applying {length(pending)} migrations...")  # Start
log_info("Migration completed: {filename}")          # Per-file (from migration-runner.R)
log_info("Migrations complete ({count} applied in {duration}s): {list}")  # Summary
log_info("Schema up to date ({total} migrations applied)")  # Already current
log_error("Migration failed: {filename} - {error}")  # Failure with SQL context
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Table-level LOCK TABLES | Advisory locks (GET_LOCK) | MySQL 5.0+ | Non-blocking for normal queries |
| Single /health endpoint | Separate liveness/readiness | Kubernetes patterns | Proper probe semantics |
| Manual migration scripts | Automated startup runner | Phase 47 | Consistent schema management |

**Deprecated/outdated:**
- Manual `LOCK TABLES` for app-level coordination - use GET_LOCK instead
- Single health endpoint for all purposes - separate liveness from readiness

## Open Questions

Things that couldn't be fully resolved:

1. **Migrations directory mount in production**
   - What we know: Development uses bind mounts, production Dockerfile copies /app but not db/migrations
   - What's unclear: Whether to mount db/migrations or copy during build
   - Recommendation: Add volume mount to docker-compose.yml for db/migrations:ro

2. **Failed migration status tracking**
   - What we know: CONTEXT.md specifies "Track failures in schema_version with error message"
   - What's unclear: Current schema_version only has success BOOLEAN
   - Recommendation: May need ALTER TABLE to add error_message column (could be Phase 48 task)

3. **Lock name scope**
   - What we know: GET_LOCK is server-wide, not database-specific
   - What's unclear: If multiple SysNDD instances share MySQL, lock could conflict
   - Recommendation: Use qualified name "sysndd_migration" - sufficient for single-tenant

## Sources

### Primary (HIGH confidence)
- [MySQL 8.0 Locking Functions](https://dev.mysql.com/doc/refman/8.0/en/locking-functions.html) - GET_LOCK API, return values, timeout behavior
- Existing codebase: `api/functions/migration-runner.R` - run_migrations() implementation
- Existing codebase: `api/start_sysndd_api.R` - Integration point structure (lines 179-187, 463+)
- Existing codebase: `api/endpoints/health_endpoints.R` - Current health endpoint patterns
- [Kubernetes Liveness/Readiness Probes](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/) - Probe semantics and HTTP status codes

### Secondary (MEDIUM confidence)
- [logger Package Documentation](https://daroczig.github.io/logger/articles/customize_logger.html) - Log format customization
- [Plumber Execution Model](https://www.rplumber.io/articles/execution-model.html) - Startup code execution order

### Tertiary (LOW confidence)
- WebSearch results on R Plumber blocking patterns - limited specific guidance found

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use, well-documented
- Architecture: HIGH - Patterns derived from MySQL docs and existing codebase
- Pitfalls: HIGH - Based on documented MySQL behavior and Docker integration experience

**Research date:** 2026-01-29
**Valid until:** 2026-03-01 (60 days - stable domain, no breaking changes expected)
