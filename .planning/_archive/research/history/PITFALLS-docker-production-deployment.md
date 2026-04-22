# Pitfalls Research: Docker Production Deployment

**Domain:** Docker volume permissions and database migration coordination in horizontally scaled containers
**Researched:** 2026-02-01
**Confidence:** HIGH (verified with WebSearch sources, Docker documentation, and codebase analysis)

---

## Permission Pitfalls

### CRITICAL: UID Mismatch Between Container and Host

**What Goes Wrong:** Container runs as UID 1001 (apiuser) but host volume directories are owned by UID 1000. Container cannot write to bind-mounted volumes, causing permission denied errors on /app/cache, /app/results, or /backup.

**Why It Happens:**
- Dockerfile creates user with hardcoded UID (1001 in current Dockerfile)
- Host directories created by developer with their UID (typically 1000)
- Named volumes start as root:root (UID 0) by default
- Docker Desktop (macOS/Windows) handles this automatically; native Linux does not

**Warning Signs:**
- "Permission denied" errors in container logs on startup
- API health checks failing with 500 errors on write operations
- Empty result directories despite successful API calls
- `ls -la` inside container shows different ownership than expected

**Consequences:**
- API cannot write cache files (performance degradation)
- Backup operations fail silently or with errors
- Results endpoints return errors

**Prevention:**
1. **Build-time UID matching:** Use ARG to make UID configurable:
   ```dockerfile
   ARG HOST_UID=1001
   ARG HOST_GID=1001
   RUN groupadd -g ${HOST_GID} api && \
       useradd -u ${HOST_UID} -g api -m -s /bin/bash apiuser
   ```
   Build with: `docker build --build-arg HOST_UID=$(id -u) --build-arg HOST_GID=$(id -g) ...`

2. **Entrypoint script for runtime fix:** Create entrypoint that adjusts permissions before switching user:
   ```bash
   #!/bin/bash
   # Run as root initially, fix permissions, then drop to apiuser
   chown -R apiuser:api /app/cache /app/results
   exec gosu apiuser "$@"
   ```

3. **Use docker-compose user directive:**
   ```yaml
   api:
     user: "${UID:-1000}:${GID:-1000}"
   ```

**Detection:** Run `docker exec -it sysndd_api id` and compare with `ls -ln` on host volumes.

**Phase to Address:** Phase 1 - Core infrastructure fix before any scaling

**Sources:**
- [Baeldung - Docker Shared Volumes Permissions](https://www.baeldung.com/ops/docker-shared-volumes-permissions)
- [Docker Volume Permissions Guide](https://eastondev.com/blog/en/posts/dev/20251217-docker-mount-permissions-guide/)

---

### CRITICAL: Entrypoint chown on Large Volumes Causes Timeout

**What Goes Wrong:** Using `chown -R` in entrypoint script on large volumes (backup directory with 60+ backups, cache with many files) takes minutes, causing health check timeout and container restart loop.

**Why It Happens:**
- `chown -R` is synchronous and blocks container startup
- Health check start_period (60s) is shorter than chown duration
- Docker Compose restarts container, chown starts again, infinite loop
- Reported in Mastodon issue: 8-10 second delays even on small volumes

**Warning Signs:**
- Container in restart loop with exit code 0 or 137
- Health check failures during "starting" state
- Very long container startup times (minutes instead of seconds)
- CPU spike during container startup

**Consequences:**
- Deployment appears to hang
- Zero-downtime deployments become impossible
- Rolling updates fail with all replicas unhealthy

**Prevention:**
1. **Skip chown if permissions already correct:**
   ```bash
   # Only chown if needed
   if [ "$(stat -c '%u' /app/cache)" != "$(id -u apiuser)" ]; then
     chown -R apiuser:api /app/cache
   fi
   ```

2. **Use environment variable to disable:**
   ```bash
   if [ "${SKIP_PERMISSION_FIX:-false}" != "true" ]; then
     chown -R apiuser:api /app/cache
   fi
   ```

3. **Fix permissions in Docker volume initialization, not entrypoint:**
   ```bash
   # One-time fix after volume creation
   docker run --rm -v sysndd_api_cache:/app/cache alpine chown -R 1001:1001 /app/cache
   ```

4. **Extend health check start_period:**
   ```yaml
   healthcheck:
     start_period: 300s  # 5 minutes for first-time permission fix
   ```

**Detection:** Time container startup with `docker logs --timestamps sysndd_api 2>&1 | head -20`

**Phase to Address:** Phase 1 - If using entrypoint script approach

**Sources:**
- [Mastodon Issue #3194 - Permission update takes long time](https://github.com/tootsuite/mastodon/issues/3194)
- [InvokeAI Issue #6264 - chown in entrypoint breaks read-only mounts](https://github.com/invoke-ai/InvokeAI/issues/6264)

---

### HIGH: chmod 777 as "Quick Fix" Creates Security Vulnerability

**What Goes Wrong:** Developer uses `chmod 777` on host directories to "fix" permission issues. This makes files world-writable, creating security vulnerabilities.

**Why It Happens:**
- Frustration with permission errors leads to "just make it work" attitude
- 60% of Docker beginners use chmod 777 according to research
- Works immediately, so seems like correct solution
- Security implications not immediately visible

**Warning Signs:**
- `ls -la` shows `drwxrwxrwx` on data directories
- Production directories writable by any process
- No systematic permission strategy documented

**Consequences:**
- Any container or process can modify application data
- Potential for privilege escalation attacks
- Fails security audits and compliance requirements

**Prevention:**
1. **Document correct permission approach** in README/deployment docs
2. **Add CI check for overly permissive directories:**
   ```bash
   find /app -perm 777 -type d && exit 1
   ```
3. **Use principle of least privilege:** Only grant permissions actually needed
4. **Fix root cause (UID mismatch)** instead of symptoms

**Detection:** `find /path/to/volumes -perm 777 -type d`

**Phase to Address:** Phase 1 - Include in deployment documentation

**Sources:**
- [Fix Docker Permission Denied](https://www.buildwithmatija.com/blog/how-to-fix-permission-denied-when-manipulating-files-in-docker-container)
- [Docker Volume Permissions Guide](https://eastondev.com/blog/en/posts/dev/20251217-docker-mount-permissions-guide/)

---

### HIGH: SELinux/AppArmor Blocking Volume Access on Linux

**What Goes Wrong:** Even with correct UID/GID matching, SELinux (RHEL/CentOS) or AppArmor (Ubuntu) blocks container access to bind-mounted volumes.

**Why It Happens:**
- Mandatory Access Control (MAC) overrides Discretionary Access Control (DAC)
- Docker contexts not automatically applied to arbitrary directories
- Ubuntu 24.04 has AppArmor enabled by default

**Warning Signs:**
- Permission denied despite correct ownership
- Works on developer machine (Docker Desktop), fails on production VPS
- `dmesg | grep denied` shows AppArmor/SELinux denials
- Works with `--privileged` but not without

**Consequences:**
- Production deployment fails
- Debug time wasted on wrong cause (UID mismatch vs MAC)

**Prevention:**
1. **For SELinux, add :z or :Z suffix to volume mounts:**
   ```yaml
   volumes:
     - ./api/data:/app/data:z  # Shared label
   ```

2. **For AppArmor, check profile conflicts:**
   ```bash
   aa-status | grep docker
   ```

3. **Document OS-specific requirements** in deployment runbook

4. **Test on production-equivalent environment** before release

**Detection:**
- SELinux: `sudo chcon -Rt svirt_sandbox_file_t /path/to/volume`
- AppArmor: `sudo dmesg | grep -i apparmor`

**Phase to Address:** Phase 2 - Production validation

**Sources:**
- [Docker Compose Volume Permission Fix](https://www.codegenes.net/blog/docker-compose-and-named-volume-permission-denied/)
- [LabEx - Resolve Permission Denied](https://labex.io/tutorials/docker-how-to-resolve-permission-denied-error-when-mounting-volume-in-docker-417724)

---

### MEDIUM: Named Volume Ownership Changes Between Container Rebuilds

**What Goes Wrong:** Named volume (`api_cache`) is initialized with ownership from first container that uses it. Changing container UID in rebuild causes permission errors.

**Why It Happens:**
- Docker only copies directory permissions from image if volume is empty
- Existing volumes retain their original ownership
- Dockerfile UID change doesn't propagate to existing volumes

**Warning Signs:**
- Works on fresh deploy, fails after container image rebuild
- `docker volume inspect` shows old creation timestamp
- Different behavior between new and existing deployments

**Consequences:**
- Upgrades break existing installations
- Inconsistent behavior across environments

**Prevention:**
1. **Document volume initialization requirements:**
   ```bash
   # After changing UID, fix existing volumes:
   docker run --rm -v sysndd_api_cache:/data alpine chown -R 1001:1001 /data
   ```

2. **Version volume naming** if major UID changes needed:
   ```yaml
   volumes:
     api_cache_v2:  # New volume for new UID
   ```

3. **Include volume permission check in startup:**
   ```bash
   if [ ! -w /app/cache ]; then
     echo "ERROR: /app/cache not writable. Run volume permission fix."
     exit 1
   fi
   ```

**Detection:** Compare `docker volume inspect sysndd_api_cache` creation time with last Dockerfile UID change.

**Phase to Address:** Phase 1 - Document migration procedure

---

### MEDIUM: gosu/su-exec Missing or Outdated in Image

**What Goes Wrong:** Entrypoint tries to use `gosu` to drop privileges but package not installed or is outdated with security vulnerabilities.

**Why It Happens:**
- gosu not included in base rocker/r-ver image
- Alpine uses su-exec instead of gosu
- Older versions have parser bugs (su-exec < 0.3)

**Warning Signs:**
- `gosu: command not found` in logs
- Container runs as root despite USER directive (entrypoint overrides)
- Security scanner flags gosu vulnerabilities

**Consequences:**
- Process runs as root (security risk)
- Entrypoint script fails entirely
- Potential CVE exposure

**Prevention:**
1. **Install correct tool for base image:**
   ```dockerfile
   # For Ubuntu/Debian (rocker/r-ver)
   RUN apt-get update && apt-get install -y gosu

   # For Alpine
   RUN apk add --no-cache su-exec
   ```

2. **Verify version is current:**
   ```dockerfile
   RUN gosu --version && gosu nobody true
   ```

3. **Alternative: Don't use entrypoint root, use init container pattern**

**Detection:** `docker run --rm sysndd-api which gosu` or `gosu --version`

**Phase to Address:** Phase 1 - If implementing entrypoint approach

**Sources:**
- [gosu GitHub Repository](https://github.com/tianon/gosu)
- [su-exec vs gosu Comparison](https://www.sobyte.net/post/2023-01/docker-gosu-su-exec/)

---

## Migration Pitfalls

### CRITICAL: Multiple Containers Running Migrations Simultaneously

**What Goes Wrong:** When scaling to multiple API containers (`docker-compose up --scale api=4`), all containers attempt to run migrations at startup simultaneously, causing race conditions, duplicate key errors, or partial migrations.

**Why It Happens:**
- Each container runs migration check independently
- No distributed lock mechanism
- MySQL DDL is NOT transactional (commits immediately)
- By the time second container checks schema_version, first container's migration is in progress but not recorded

**Warning Signs:**
- "Duplicate column" or "Table already exists" errors on startup
- Random containers failing to start, others succeeding
- Inconsistent schema across containers (some have column, others don't)
- Partial migrations (some columns added, procedure failed)

**Consequences:**
- Database in inconsistent state
- Manual intervention required to fix
- Data corruption possible

**Prevention:**
1. **Use MySQL advisory locks for migration coordination:**
   ```sql
   -- Acquire lock (timeout 30 seconds)
   SELECT GET_LOCK('sysndd_migration', 30);

   -- Check and run migrations
   ...

   -- Release lock
   SELECT RELEASE_LOCK('sysndd_migration');
   ```

2. **Init container pattern** (run migrations separately):
   ```yaml
   services:
     migrations:
       image: sysndd-api
       command: ["Rscript", "run_migrations.R"]
       deploy:
         restart_policy:
           condition: on-failure
     api:
       depends_on:
         migrations:
           condition: service_completed_successfully
   ```

3. **Single-instance migration mode:**
   ```r
   # Only run migrations if ENABLE_MIGRATIONS=true (set on one instance only)
   if (Sys.getenv("ENABLE_MIGRATIONS", "false") == "true") {
     run_migrations()
   }
   ```

4. **Record migration start, not just completion:**
   ```sql
   INSERT INTO schema_version (version, status, started_at)
   VALUES (4, 'running', NOW());
   -- Run migration
   UPDATE schema_version SET status = 'completed', completed_at = NOW()
   WHERE version = 4;
   ```

**Detection:** Check schema_version table for 'running' status entries, or `SHOW PROCESSLIST` during startup.

**Phase to Address:** Phase 1 - Critical for any horizontal scaling

**Sources:**
- [Rails Advisory Locks PR #22122](https://github.com/rails/rails/pull/22122)
- [Rails Migration Race Condition Issue #22092](https://github.com/rails/rails/issues/22092)
- [Flyway Migration Strategy](https://thinhdanggroup.github.io/flyway-migration/)

---

### CRITICAL: Migration Lock Timeout Causes Container Restart Loop

**What Goes Wrong:** Container acquires migration lock but migration takes longer than health check timeout. Container killed, lock potentially orphaned (if using database locks without session binding), next container waits on orphaned lock, timeout, restart, infinite loop.

**Why It Happens:**
- Health check timeout (30s) shorter than migration duration
- start_period (60s) may be insufficient for schema changes
- MySQL table locks persist even if client disconnects (depending on lock type)
- Container orchestration interprets timeout as failure

**Warning Signs:**
- All containers in restart loop
- `SHOW PROCESSLIST` shows waiting connections
- Migration never completes
- ConcurrentMigrationError or lock timeout errors

**Consequences:**
- Zero availability during deployment
- Requires manual intervention (kill locks, restart)
- Data loss if migration was partially applied

**Prevention:**
1. **Use advisory locks (auto-released on session end):**
   ```sql
   -- GET_LOCK is advisory and released when session ends
   SELECT GET_LOCK('sysndd_migration', 30);
   ```

2. **Add migration-aware health check:**
   ```r
   # /health/ready endpoint
   if (file.exists("/tmp/migration_in_progress")) {
     return(list(status = "migrating", ready = FALSE))
   }
   return(list(status = "ready", ready = TRUE))
   ```

3. **Separate migration from API startup:**
   ```yaml
   healthcheck:
     test: ["CMD", "curl", "-sf", "http://localhost:7777/health/ready"]
     start_period: 300s  # 5 minutes for migrations
   ```

4. **Add lock timeout with graceful exit:**
   ```r
   lock_result <- dbGetQuery(pool, "SELECT GET_LOCK('migration', 60)")
   if (lock_result[[1]] != 1) {
     logger::log_warn("Could not acquire migration lock, skipping")
     return()  # Let another container handle it
   }
   ```

**Detection:** `SELECT IS_USED_LOCK('sysndd_migration');` and check for waiting processes.

**Phase to Address:** Phase 1 - Must handle before enabling auto-migrations

**Sources:**
- [EF Core Migration Lock Issue #34439](https://github.com/dotnet/efcore/issues/34439)
- [Distributed Locking Guide](https://www.architecture-weekly.com/p/distributed-locking-a-practical-guide)

---

### HIGH: Container Abrupt Termination Leaves Migration Incomplete

**What Goes Wrong:** Container receives SIGKILL during migration (OOM, manual docker stop, orchestrator timeout). MySQL DDL partially applied, migration not recorded as complete, next startup fails.

**Why It Happens:**
- MySQL DDL commits immediately (no rollback)
- Container process doesn't get graceful shutdown
- schema_version updated only after migration success
- Memory-intensive migrations trigger OOM killer

**Warning Signs:**
- "Column already exists" but migration not in schema_version
- Container exit code 137 (OOM killed) or 143 (SIGTERM)
- Inconsistent schema between runs
- `dmesg | grep -i oom` shows kills

**Consequences:**
- Database in undefined state
- Manual schema repair required
- Cannot re-run migration (would fail), cannot skip (not recorded)

**Prevention:**
1. **Make migrations truly idempotent:**
   ```sql
   -- Check before modifying
   IF NOT EXISTS (
     SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_NAME = 'mytable' AND COLUMN_NAME = 'newcol'
   ) THEN
     ALTER TABLE mytable ADD COLUMN newcol VARCHAR(255);
   END IF;
   ```

2. **Add graceful shutdown handling:**
   ```r
   # Trap SIGTERM
   signal::trap("TERM", function() {
     logger::log_warn("Shutdown requested, completing current migration")
     # Set flag to stop after current migration
   })
   ```

3. **Increase container memory for migration phase:**
   ```yaml
   deploy:
     resources:
       limits:
         memory: 8192M  # During migration
   ```

4. **Record partial progress:**
   ```sql
   -- Before each DDL statement
   INSERT INTO migration_steps (version, step, status) VALUES (4, 1, 'running');
   -- After DDL
   UPDATE migration_steps SET status = 'done' WHERE version = 4 AND step = 1;
   ```

**Detection:** Query `INFORMATION_SCHEMA.COLUMNS` and compare with expected schema from migrations.

**Phase to Address:** Phase 1 - Idempotent migrations are prerequisite

**SysNDD-Specific Context:** Migration 002 is documented as non-idempotent in `.planning/todos/pending/make-migration-002-idempotent.md`.

**Sources:**
- [Safe Ecto Migrations Guide](https://github.com/fly-apps/safe-ecto-migrations)
- [Top 10 Docker/Kubernetes Scaling Mistakes](https://medium.com/@techInFocus/top-10-mistakes-when-scaling-docker-and-kubernetes-and-how-to-fix-them-c0431d50e752)

---

### HIGH: Schema Version Table Race on Fresh Database

**What Goes Wrong:** On completely fresh database, multiple containers try to CREATE TABLE schema_version simultaneously. One succeeds, others fail with "Table already exists".

**Why It Happens:**
- Fresh database has no schema_version table
- All containers check "does table exist?" - answer is no for all
- All containers try to create table
- Only first succeeds
- Others crash or retry indefinitely

**Warning Signs:**
- Works on single container, fails on scale-out
- "Table 'schema_version' already exists" errors
- First deployment fails, subsequent deployments work

**Consequences:**
- First deployment requires manual intervention
- Containers fail to start on fresh database

**Prevention:**
1. **Use CREATE TABLE IF NOT EXISTS:**
   ```sql
   CREATE TABLE IF NOT EXISTS schema_version (
     version INT PRIMARY KEY,
     filename VARCHAR(255),
     applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   ```

2. **Still acquire lock before checking/creating:**
   ```r
   # Even IF NOT EXISTS needs coordination
   lock <- dbGetQuery(pool, "SELECT GET_LOCK('schema_init', 30)")
   dbExecute(pool, "CREATE TABLE IF NOT EXISTS schema_version (...)")
   dbGetQuery(pool, "SELECT RELEASE_LOCK('schema_init')")
   ```

3. **Include schema_version in base database setup** (not in migration runner)

**Detection:** Check if schema_version table exists before starting containers.

**Phase to Address:** Phase 1 - Part of migration runner implementation

---

### MEDIUM: Long-Running DDL Blocks All Container Startups

**What Goes Wrong:** One container holds migration lock while running long ALTER TABLE. All other containers wait on lock, health checks fail, orchestrator restarts waiting containers, restart storm.

**Why It Happens:**
- ALTER TABLE on large tables can take minutes
- Lock acquisition timeout too short
- Other containers keep retrying, consuming resources
- Orchestrator interprets waiting containers as failed

**Warning Signs:**
- Single container healthy, others in CrashLoopBackOff
- High CPU on database during migration
- `SHOW PROCESSLIST` shows many waiting connections

**Consequences:**
- Extended deployment window
- Resource waste on restart attempts
- Potential for cascading failures

**Prevention:**
1. **Non-blocking lock acquisition with graceful skip:**
   ```r
   lock <- dbGetQuery(pool, "SELECT GET_LOCK('migration', 0)")  # Non-blocking
   if (lock[[1]] != 1) {
     logger::log_info("Migration in progress on another instance, skipping")
     return()  # Proceed with startup, no migrations needed
   }
   ```

2. **Probe migration status endpoint:**
   ```yaml
   # Readiness probe waits for migration
   readinessProbe:
     exec:
       command: ["curl", "-sf", "http://localhost:7777/health/migrations"]
     initialDelaySeconds: 10
     periodSeconds: 5
   ```

3. **Use MySQL Online DDL where possible:**
   ```sql
   ALTER TABLE large_table ADD COLUMN new_col VARCHAR(255),
   ALGORITHM=INPLACE, LOCK=NONE;
   ```

4. **For very large tables, use pt-online-schema-change**

**Detection:** Monitor lock wait times with `SELECT * FROM performance_schema.data_locks;`

**Phase to Address:** Phase 2 - Part of production validation

**Sources:**
- [MySQL Online DDL Locks](https://medium.com/@hamidrezaniazi/behind-the-scenes-of-mysql-online-ddl-locks-638804b777b3)

---

### MEDIUM: Static Asset Inconsistency Across Replicas

**What Goes Wrong:** Favicon or other static assets baked into container image at build time. Different replicas built at different times have different assets. Load balancer serves inconsistent content.

**Why It Happens:**
- Build pipeline doesn't guarantee identical builds
- Assets fetched during build from external source
- Container image not pinned to specific digest
- Rolling updates mix old and new replicas

**Warning Signs:**
- Favicon flickers or changes on page refresh
- Users report inconsistent UI across sessions
- Asset hash differs between replicas
- 404 on assets intermittently

**Consequences:**
- User confusion
- Cache invalidation issues
- Broken asset references

**Prevention:**
1. **Bake assets at image build time, use content hash:**
   ```dockerfile
   COPY public/favicon.ico /app/public/favicon.ico
   # Hash verified at build
   ```

2. **Use shared volume for static assets (if dynamically generated):**
   ```yaml
   volumes:
     static_assets:
       driver: local  # All replicas see same files
   ```

3. **Version assets in URL:**
   ```html
   <link rel="icon" href="/favicon.ico?v=${GIT_COMMIT}">
   ```

4. **Pin container image digest in deployment:**
   ```yaml
   image: sysndd-app@sha256:abc123...
   ```

**Detection:** Compare `docker inspect sysndd_app` image ID across replicas.

**Phase to Address:** Phase 1 - Ensure favicon in build, not external

**SysNDD-Specific Context:** Missing favicon was identified as one of the issues to fix.

---

## Prevention Strategies

### Strategy 1: Init Container for Migrations

**Pattern:** Run migrations in a separate, single-instance container before starting API replicas.

```yaml
services:
  migrations:
    image: sysndd-api
    command: ["Rscript", "run_migrations.R"]
    environment:
      - MYSQL_HOST=mysql
    depends_on:
      mysql:
        condition: service_healthy
    deploy:
      mode: replicated
      replicas: 1
      restart_policy:
        condition: on-failure
        max_attempts: 3

  api:
    image: sysndd-api
    depends_on:
      migrations:
        condition: service_completed_successfully
    deploy:
      replicas: 4
```

**Benefits:**
- No migration race conditions
- API containers start fast (no migration overhead)
- Clear separation of concerns
- Failure isolated to migration step

**Drawbacks:**
- More complex deployment orchestration
- Requires `service_completed_successfully` (Compose v2.20+)

### Strategy 2: Build-Time UID Matching with .env

**Pattern:** Pass host UID/GID at build time via .env file.

```bash
# .env file (gitignored)
HOST_UID=1000
HOST_GID=1000
```

```yaml
# docker-compose.yml
services:
  api:
    build:
      context: ./api
      args:
        HOST_UID: ${HOST_UID:-1001}
        HOST_GID: ${HOST_GID:-1001}
```

```dockerfile
ARG HOST_UID=1001
ARG HOST_GID=1001
RUN groupadd -g ${HOST_GID} api && \
    useradd -u ${HOST_UID} -g api -m -s /bin/bash apiuser
```

**Benefits:**
- Permissions correct from start
- No runtime overhead
- Works with named volumes

**Drawbacks:**
- Requires rebuild when deploying to different host
- .env file must be maintained per environment

### Strategy 3: Advisory Lock Wrapper for R

**Pattern:** R function that wraps migration execution with MySQL advisory lock.

```r
with_migration_lock <- function(pool, callback, lock_name = "sysndd_migration", timeout = 60) {
  # Acquire lock
  lock_result <- DBI::dbGetQuery(pool, sprintf(
    "SELECT GET_LOCK('%s', %d) as acquired", lock_name, timeout
  ))

  if (lock_result$acquired != 1) {
    logger::log_warn("Could not acquire migration lock within {timeout}s")
    return(FALSE)
  }

  tryCatch({
    callback()
    TRUE
  }, finally = {
    DBI::dbGetQuery(pool, sprintf("SELECT RELEASE_LOCK('%s')", lock_name))
    logger::log_debug("Released migration lock")
  })
}

# Usage
with_migration_lock(pool, function() {
  run_pending_migrations(pool)
})
```

**Benefits:**
- Lock auto-released on session end (container crash safe)
- Simple to implement
- Works with existing pool infrastructure

**Drawbacks:**
- Still need health check coordination
- Single-threaded migration bottleneck

### Strategy 4: Idempotent Migration Template

**Pattern:** Standard template for all new migrations ensuring idempotency.

```sql
-- migrations/00X_description.sql
DELIMITER //

-- Create idempotent migration procedure
CREATE PROCEDURE IF NOT EXISTS migrate_00X()
BEGIN
    -- Add column only if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'target_table'
          AND COLUMN_NAME = 'new_column'
    ) THEN
        ALTER TABLE target_table
        ADD COLUMN new_column VARCHAR(255) NULL,
        ALGORITHM=INPLACE, LOCK=NONE;
    END IF;

    -- Create index only if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'target_table'
          AND INDEX_NAME = 'idx_new_column'
    ) THEN
        CREATE INDEX idx_new_column ON target_table(new_column);
    END IF;
END //

DELIMITER ;

-- Execute migration
CALL migrate_00X();

-- Cleanup
DROP PROCEDURE IF EXISTS migrate_00X;
```

**Benefits:**
- Safe to run multiple times
- Clear pattern to follow
- Self-documenting
- Works with MySQL Online DDL

**Drawbacks:**
- More verbose than simple DDL
- Requires stored procedure support

---

## Phase Mapping Summary

| Pitfall | Severity | Warning Signs | Phase |
|---------|----------|---------------|-------|
| UID mismatch container/host | CRITICAL | Permission denied on write | Phase 1 |
| Entrypoint chown timeout | CRITICAL | Container restart loop | Phase 1 |
| chmod 777 security hole | HIGH | World-writable directories | Phase 1 |
| Multiple containers running migrations | CRITICAL | Duplicate column errors | Phase 1 |
| Migration lock timeout restart loop | CRITICAL | All containers in restart | Phase 1 |
| Abrupt termination partial migration | HIGH | Schema version mismatch | Phase 1 |
| schema_version race on fresh DB | HIGH | Table already exists | Phase 1 |
| Static asset inconsistency | MEDIUM | Flickering favicon | Phase 1 |
| SELinux/AppArmor blocking | HIGH | Permission denied despite correct UID | Phase 2 |
| Long DDL blocks startups | MEDIUM | Waiting containers | Phase 2 |
| Named volume ownership drift | MEDIUM | Works fresh, fails after rebuild | Phase 2 |
| gosu/su-exec missing | MEDIUM | Command not found | Phase 1 (if using) |

---

## SysNDD-Specific Considerations

### Current Dockerfile Analysis

The current `api/Dockerfile` creates user with UID 1001:
```dockerfile
RUN groupadd -g 1001 api && \
    useradd -u 1001 -g api -m -s /bin/bash apiuser
```

**Issue:** Host user is likely UID 1000 (default on Ubuntu). This causes permission denied on bind-mounted volumes.

**Fix:** Make UID/GID configurable via ARG or use runtime entrypoint fix.

### Current docker-compose.yml Analysis

- Uses named volumes (`api_cache`, `mysql_backup`) - these start as root:root
- Uses bind mounts for code (`./api/endpoints:/app/endpoints`) - these inherit host permissions
- No user directive on api service - relies on Dockerfile USER
- Health check has 60s start_period - may be insufficient for migrations on slow hardware

**Recommendations:**
1. Add `user: "${UID:-1001}:${GID:-1001}"` to api service for bind mounts
2. Initialize named volumes with correct ownership
3. Increase start_period if implementing auto-migrations
4. Consider init container pattern for migrations before scaling

### Migration 002 Non-Idempotent

Already documented in `.planning/todos/pending/make-migration-002-idempotent.md`. Must be fixed before implementing auto-run migrations in horizontally scaled environment.

---

## Sources

### Official Documentation
- [MySQL GET_LOCK Function](https://dev.mysql.com/doc/refman/8.0/en/locking-functions.html)
- [MySQL Online DDL](https://dev.mysql.com/doc/refman/8.0/en/innodb-online-ddl.html)
- [Docker Compose Volumes](https://docs.docker.com/compose/compose-file/07-volumes/)
- [Docker Volumes](https://docs.docker.com/engine/storage/volumes/)

### Best Practice Articles
- [Docker Volume Permissions Guide](https://eastondev.com/blog/en/posts/dev/20251217-docker-mount-permissions-guide/)
- [Baeldung - Docker Shared Volumes](https://www.baeldung.com/ops/docker-shared-volumes-permissions)
- [Flyway Migration Best Practices](https://thinhdanggroup.github.io/flyway-migration/)
- [Safe Ecto Migrations](https://github.com/fly-apps/safe-ecto-migrations)
- [Distributed Locking Guide](https://www.architecture-weekly.com/p/distributed-locking-a-practical-guide)
- [R Plumber Docker Deployment](https://medium.com/tmobile-tech/using-docker-to-deploy-an-r-plumber-api-863ccf91516d)
- [Docker Best Practices for R](https://collabnix.com/10-essential-docker-best-practices-for-r-developers-in-2025/)

### Issue Discussions
- [Rails Migration Race Conditions](https://github.com/rails/rails/issues/22092)
- [EF Core Migration Lock](https://github.com/dotnet/efcore/issues/34439)
- [gosu GitHub](https://github.com/tianon/gosu)
- [su-exec GitHub](https://github.com/ncopa/su-exec)

### Codebase Analysis
- `/home/bernt-popp/development/sysndd/api/Dockerfile` - UID hardcoded to 1001
- `/home/bernt-popp/development/sysndd/docker-compose.yml` - Volume configuration analyzed
- `/home/bernt-popp/development/sysndd/.planning/research/PITFALLS-production-readiness.md` - Related migration pitfalls
