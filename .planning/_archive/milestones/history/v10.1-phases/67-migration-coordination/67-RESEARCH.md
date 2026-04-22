# Phase 67: Migration Coordination - Research

**Researched:** 2026-02-01
**Domain:** Database migration coordination for parallel container startup
**Confidence:** HIGH

## Summary

This phase addresses the migration lock timeout issue when multiple API containers start simultaneously in Docker Compose with `--scale api=4`. The current implementation acquires a MySQL advisory lock immediately at startup, causing all but one container to wait up to 30 seconds even when no migrations are needed (the common case).

The research confirms that **double-checked locking** is the correct pattern: check schema version before acquiring the lock, and if up-to-date, skip the lock entirely. This provides a "fast path" for the 99% of container starts where the database is already current. For the rare case where migrations are needed, the pattern acquires the lock and re-checks to handle race conditions where another container may have completed the migration while waiting.

**Primary recommendation:** Implement double-checked locking in `start_sysndd_api.R` with schema version check before lock acquisition, re-check after lock, and enhanced health endpoint reporting.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MySQL GET_LOCK | 8.4.x | Advisory locking for coordination | Built-in MySQL function, no external dependencies |
| pool (R) | Current | Connection pool management | Already in use, handles checkout/return |
| DBI (R) | Current | Database interface | Already in use for all DB operations |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| logger (R) | Current | Structured logging | Already in use, essential for debugging coordination |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Advisory lock | Init container | More complex deployment, separate container to manage |
| Advisory lock | Redis lock | External dependency, not needed for this scale |
| Advisory lock | File-based lock | Doesn't work across containers without shared filesystem |

**Installation:** No new packages required - all libraries already installed.

## Architecture Patterns

### Recommended Implementation Structure

The migration coordination code lives in `api/start_sysndd_api.R` section 7.5. The changes are localized to this section:

```
api/
├── start_sysndd_api.R           # Modify section 7.5 for double-checked locking
├── functions/
│   └── migration-runner.R       # No changes needed - already has lock functions
└── endpoints/
    └── health_endpoints.R       # Enhance to show lock acquisition status
```

### Pattern 1: Double-Checked Locking for Migrations

**What:** Check schema before lock, acquire lock only if needed, re-check after lock

**When to use:** Multiple containers starting simultaneously where most starts are "fast path" (schema already current)

**Pseudocode Pattern:**
```r
# Source: Double-checked locking pattern adapted for R
# Step 1: Fast path check (no lock)
pending_before_lock <- get_pending_migrations()
if (length(pending_before_lock) == 0) {
  # Schema up to date - skip lock entirely
  log_info("Fast path: schema up to date, skipping lock")
  return(fast_path_result)
}

# Step 2: Acquire lock (only reached if migrations might be needed)
acquire_migration_lock(conn, timeout = 30)
on.exit(release_migration_lock(conn), add = TRUE)

# Step 3: Re-check after lock (another container may have migrated)
pending_after_lock <- get_pending_migrations()
if (length(pending_after_lock) == 0) {
  log_info("Another container completed migrations while we waited")
  return(no_migrations_needed_result)
}

# Step 4: Apply migrations (we hold lock, migrations needed)
result <- run_migrations(...)
```

### Pattern 2: Health Endpoint Migration Status

**What:** Report migration coordination state to orchestration systems

**When to use:** Container health checks, Kubernetes readiness probes, load balancer health

**Structure:**
```r
# Source: Kubernetes health check best practices
list(
  status = "healthy" | "unhealthy" | "migrating",
  migrations = list(
    pending = 0,            # Number of pending migrations
    applied = 9,            # Total applied migrations
    lock_acquired = FALSE,  # Whether this container acquired the lock
    lock_held_by = NULL     # Connection ID if another container holds lock
  ),
  database = "connected" | "disconnected"
)
```

### Anti-Patterns to Avoid

- **Lock-first approach:** Acquiring lock before checking if needed wastes 30s on all but one container
- **No re-check after lock:** Race condition where another container migrated while waiting
- **Silent lock failure:** Must surface lock timeouts as unhealthy status
- **Blocking forever:** Always use timeout on GET_LOCK, never negative timeout

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Advisory locking | Custom lock table | MySQL GET_LOCK() | Server handles deadlock detection, connection cleanup |
| Connection pooling | Manual connections | pool::poolCheckout/Return | Handles connection lifecycle, timeouts, validation |
| Schema tracking | Version numbers | Existing schema_version table | Already tracks applied migrations by filename |
| Lock cleanup | Manual release in finally | on.exit() with RELEASE_LOCK | Guarantees cleanup on any exit path |

**Key insight:** MySQL's advisory lock system handles the hard problems (deadlock detection, automatic release on disconnect, server-wide coordination) - our job is just to use it correctly with the double-check pattern.

## Common Pitfalls

### Pitfall 1: Lock Held After Error

**What goes wrong:** Migration fails partway through, lock remains held until connection timeout
**Why it happens:** Error handling doesn't properly release lock
**How to avoid:** Use `on.exit(release_migration_lock(conn), add = TRUE)` immediately after acquiring
**Warning signs:** Containers hang waiting for lock after a failed migration

### Pitfall 2: Pool Connection for Lock Duration

**What goes wrong:** Advisory lock is connection-scoped, returning connection releases lock
**Why it happens:** Using `pool::poolCheckout()` then returning before migrations complete
**How to avoid:** Checkout connection at start of migration block, return only after all operations complete
**Warning signs:** Lock appears free but migrations still running

### Pitfall 3: Checking Wrong Schema Version

**What goes wrong:** Fast path check sees pending migrations, but different container applies them
**Why it happens:** Single check before lock, no re-check after
**How to avoid:** Always re-check `get_pending_migrations()` after acquiring lock
**Warning signs:** Multiple containers attempt same migration simultaneously

### Pitfall 4: Silent Timeout Failure

**What goes wrong:** Container appears healthy but never completed migrations
**Why it happens:** Lock timeout caught but not properly reported in health endpoint
**How to avoid:** Set `migration_status$lock_timeout = TRUE` on timeout, health endpoint returns 503
**Warning signs:** Container serving requests with stale schema

### Pitfall 5: Health Endpoint Database Dependency

**What goes wrong:** Health check fails when database is slow, causing cascade of container restarts
**Why it happens:** Liveness probe queries database
**How to avoid:** Basic `/health` endpoint checks only process, `/health/ready` checks database
**Warning signs:** Containers restarting during database maintenance

## Code Examples

Verified patterns from official sources and existing codebase:

### MySQL Advisory Lock Functions

```sql
-- Source: https://dev.mysql.com/doc/refman/8.4/en/locking-functions.html

-- Acquire lock with 30 second timeout
-- Returns: 1 = acquired, 0 = timeout, NULL = error
SELECT GET_LOCK('sysndd_migration', 30) AS acquired;

-- Check if lock is free (useful for health endpoint)
-- Returns: 1 = free, 0 = in use
SELECT IS_FREE_LOCK('sysndd_migration') AS is_free;

-- Check who holds lock (useful for debugging)
-- Returns: connection_id if held, NULL if not held
SELECT IS_USED_LOCK('sysndd_migration') AS holder;

-- Release lock
-- Returns: 1 = released, 0 = not held by us, NULL = not exists
SELECT RELEASE_LOCK('sysndd_migration') AS released;
```

### Existing get_pending_migrations Pattern

```r
# Source: api/functions/migration-runner.R (already implemented)
# This function already exists and can be used for the fast path check

get_pending_migrations <- function(migrations_dir = "db/migrations", conn = NULL) {
  # Get list of all migration files
  migration_files <- list_migration_files(migrations_dir)

  # Get already-applied migrations
  applied <- get_applied_migrations(conn)

  # Calculate pending migrations
  pending <- setdiff(migration_files, applied)

  return(pending)
}
```

### Health Endpoint Lock Status Query

```r
# Source: MySQL documentation + R DBI patterns

check_migration_lock_status <- function() {
  tryCatch({
    # IS_USED_LOCK returns connection_id of holder, or NULL if free
    result <- db_execute_query(
      "SELECT IS_USED_LOCK('sysndd_migration') AS holder"
    )

    if (is.na(result$holder) || is.null(result$holder)) {
      list(locked = FALSE, holder = NULL)
    } else {
      list(locked = TRUE, holder = result$holder)
    }
  }, error = function(e) {
    list(locked = NA, error = e$message)
  })
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Lock-first migration | Double-checked locking | This phase | Fast path skips lock when schema current |
| Single health endpoint | Liveness + Readiness probes | Docker/K8s standard | Separates "alive" from "ready to serve" |
| Init containers | In-process migration | Simplified deployment | Single image serves both purposes |

**Deprecated/outdated:**
- **Init containers for simple migrations:** Adds deployment complexity without benefit for single-pod coordination
- **Redis locks:** Overkill when MySQL advisory locks suffice

## Open Questions

Things that couldn't be fully resolved:

1. **Lock timeout duration**
   - What we know: Current 30 second timeout, may be too long for fast startup
   - What's unclear: Optimal timeout balancing quick failure vs. waiting for slow migrations
   - Recommendation: Keep 30s for now, configurable via environment variable if needed

2. **Health check interval vs. lock timeout**
   - What we know: Docker healthcheck default interval is 30s, same as lock timeout
   - What's unclear: Whether health check should report "migrating" status differently
   - Recommendation: Add `migrating` status to health response, don't count as unhealthy

3. **Multiple simultaneous migration needs**
   - What we know: Very rare edge case (fresh database with multiple containers)
   - What's unclear: Whether we need startup ordering in compose
   - Recommendation: Test with 4 containers on fresh database in Phase 68

## Sources

### Primary (HIGH confidence)
- [MySQL 8.4 Locking Functions Reference](https://dev.mysql.com/doc/refman/8.4/en/locking-functions.html) - Official documentation for GET_LOCK, RELEASE_LOCK, IS_USED_LOCK
- Existing codebase: `api/functions/migration-runner.R` - Current lock implementation
- Existing codebase: `api/start_sysndd_api.R` - Current startup sequence
- Existing codebase: `api/endpoints/health_endpoints.R` - Current health endpoint

### Secondary (MEDIUM confidence)
- [Docker Compose startup order](https://docs.docker.com/compose/how-tos/startup-order/) - depends_on conditions
- [Kubernetes Health Checks Best Practices](https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-setting-up-health-checks-with-readiness-and-liveness-probes) - Liveness vs Readiness probes
- [Decoupling Database Migrations from Server Startup](https://pythonspeed.com/articles/schema-migrations-server-startup/) - Migration patterns

### Tertiary (LOW confidence)
- [EF Core Migration Locking Discussion](https://github.com/dotnet/efcore/issues/24233) - General patterns from other ecosystems
- [Double-Checked Locking Pattern](https://java-design-patterns.com/patterns/double-checked-locking/) - Pattern description (Java-focused)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using existing MySQL features, no new dependencies
- Architecture: HIGH - Double-checked locking is well-established pattern, fits R/Plumber context
- Pitfalls: HIGH - Based on documented MySQL behavior and existing codebase analysis

**Research date:** 2026-02-01
**Valid until:** 2026-04-01 (stable infrastructure patterns, long validity)
