# Phase 66: Infrastructure Fixes - Research

**Researched:** 2026-02-01
**Domain:** Docker containerization, file permissions, horizontal scaling
**Confidence:** HIGH

## Summary

Phase 66 addresses four critical infrastructure issues discovered on the VPS production deployment:

1. **API container cannot write to bind-mounted `/app/data`** - UID mismatch between container user (1001) and host file owner (1000)
2. **Non-configurable UID in Dockerfile** - Hardcoded UID 1001 prevents matching host user
3. **Container naming prevents horizontal scaling** - `container_name` directive blocks `docker compose --scale api=4`
4. **Favicon 404 error** - Missing image file at expected path

The root cause for issues 1-2 is fundamental Linux filesystem semantics: UIDs are numeric kernel-level identifiers, not usernames. A container user with UID 1001 cannot write to host files owned by UID 1000, even if both are named "apiuser". The solution is making the Dockerfile UID configurable via build-arg with a default of 1000 (most common host UID on Linux).

Issue 3 is a Docker Compose design constraint: named containers cannot be scaled because names must be unique. The fix is removing the `container_name` directive from the API service.

Issue 4 is a simple missing file: `app/public/brain-neurodevelopmental-disorders-sysndd.png` does not exist, but `index.html` references it.

**Primary recommendation:** Implement ARG-based UID configuration with default 1000, remove `container_name` from API service, copy favicon from `_old/` directory.

## Standard Stack

### Core Pattern: ARG-Based UID Matching

| Component | Purpose | Why Standard |
|-----------|---------|--------------|
| Dockerfile ARG | Build-time UID/GID configuration | Industry pattern for bind mount permission matching |
| Default UID 1000 | Host compatibility | Most common non-root UID on Linux systems |
| Build args in Compose | Pass host UID to build | Enables `--build-arg UID=$(id -u)` pattern |

### Current State vs. Target State

| Aspect | Current (UID 1001) | Target (ARG UID=1000) |
|--------|-------------------|----------------------|
| Container user | `apiuser:api` (1001:1001) | `apiuser:api` (ARG:ARG, default 1000:1000) |
| Host file owner | `bernt-popp:bernt-popp` (1000:1000) | Same |
| Bind mount permission | **FAILS** - UID mismatch | **WORKS** - UID match |
| Build flexibility | None | Override via `--build-arg UID=1001` if needed |

### Installation Pattern

**Dockerfile changes:**
```dockerfile
# Before (hardcoded):
RUN groupadd -g 1001 api && \
    useradd -u 1001 -g api -m -s /bin/bash apiuser

# After (configurable):
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} api && \
    useradd -u ${UID} -g api -m -s /bin/bash apiuser
```

**docker-compose.yml changes:**
```yaml
# Optional: Pass build args from environment
services:
  api:
    build:
      context: ./api/
      args:
        - UID=${HOST_UID:-1000}
        - GID=${HOST_GID:-1000}
    # Remove this line:
    # container_name: sysndd_api
```

**Build command (default):**
```bash
# Uses default UID=1000, GID=1000
docker compose build api

# Override for non-standard host UID:
docker compose build api --build-arg UID=$(id -u) --build-arg GID=$(id -g)
```

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ARG UID=1000 | `user: "${UID:-1000}:${GID:-1000}"` in Compose | Runtime-only, doesn't fix COPY --chown ownership |
| ARG UID=1000 | chmod 777 on host | **DANGEROUS** - removes all security, container escape risk |
| ARG UID=1000 | Named volume instead of bind mount | Loses live code editing for development |
| Remove container_name | Init container pattern | Overkill for Docker Compose (Kubernetes pattern) |

## Architecture Patterns

### Recommended Dockerfile Structure for Non-Root with Bind Mounts

```dockerfile
# Stage: production
FROM base AS production

# Accept UID/GID as build arguments (default 1000 for broad compatibility)
ARG UID=1000
ARG GID=1000

# Create non-root user with configurable UID/GID
RUN groupadd -g ${GID} api && \
    useradd -u ${UID} -g api -m -s /bin/bash apiuser

WORKDIR /app

# Copy with ownership matching container user
# CRITICAL: Ownership is numeric UID:GID, not username
COPY --chown=apiuser:api endpoints/ endpoints/
COPY --chown=apiuser:api functions/ functions/
# ... rest of COPY commands

# Create directories with correct ownership
RUN mkdir -p /app/logs /app/results /app/cache /app/data && \
    chown -R apiuser:api /app/logs /app/results /app/cache /app/data

# Switch to non-root user BEFORE CMD
USER apiuser

CMD ["Rscript", "start_sysndd_api.R"]
```

### Pattern: Scaling Services in Docker Compose

**Anti-pattern (current):**
```yaml
services:
  api:
    build: ./api/
    container_name: sysndd_api  # BLOCKS SCALING
    restart: unless-stopped
```

**Correct pattern:**
```yaml
services:
  api:
    build: ./api/
    # NO container_name directive
    restart: unless-stopped
    deploy:
      replicas: 4  # Optional: default replica count
```

**Scaling command:**
```bash
# Scale to 4 instances
docker compose up --scale api=4

# Container names auto-generated:
# sysndd_api_1
# sysndd_api_2
# sysndd_api_3
# sysndd_api_4
```

### Pattern: Static Assets in Vite/Vue Build

**Problem:** HTML references `/brain-neurodevelopmental-disorders-sysndd.png` but file doesn't exist in `app/public/`.

**Solution:** Move file from `_old/` to public root.

```
app/public/
├── _old/
│   └── brain-neurodevelopmental-disorders-sysndd.png  # Current location
├── brain-neurodevelopmental-disorders-sysndd.png      # Target location (MISSING)
└── index.html                                         # References /brain-neurodevelopmental-disorders-sysndd.png
```

**Why this happens:**
- Vite serves files from `public/` at root path `/`
- `index.html` at line 9: `<link rel="icon" type="image/png" href="/brain-neurodevelopmental-disorders-sysndd.png">`
- File exists only in `public/_old/` subdirectory
- Browser requests `/brain-neurodevelopmental-disorders-sysndd.png` → 404

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UID mapping in containers | Custom entrypoint script with chown | ARG + COPY --chown | Build-time ownership is faster, immutable |
| Container naming for scale | Custom naming scheme with env vars | Remove container_name, use Compose auto-naming | Docker handles collision-free naming |
| Permission fixes | `chmod 777` or `chown -R root` | Match UID between host and container | Security best practice - least privilege |
| Migration coordination | Custom semaphore files | MySQL advisory locks (GET_LOCK) | Already implemented in migration-runner.R |

**Key insight:** Docker filesystem permissions are not abstracted - they're raw Linux kernel UID/GID matching. Tools can't "fix" a fundamental numeric mismatch; architecture must align UIDs.

## Common Pitfalls

### Pitfall 1: Confusing Usernames with UIDs

**What goes wrong:** Assuming same username means same permissions.
```dockerfile
# Container: apiuser (UID 1001)
USER apiuser

# Host: bernt-popp (UID 1000) owns /app/data
# Container writes fail: "Permission denied"
```

**Why it happens:** Linux kernel only sees numeric UIDs. Username is a userspace convention. `apiuser` in container has no relation to host users.

**How to avoid:** Always match numeric UIDs between container user and host file owner.

**Warning signs:**
- "Permission denied" errors when writing to bind mounts
- `ls -ln` shows different numeric owners inside vs. outside container
- `docker exec container ls -ln /app/data` shows different UID than `ls -ln api/data` on host

### Pitfall 2: Using chmod 777 to "Fix" Permissions

**What goes wrong:**
```bash
# Host: "Just make it writable"
chmod -R 777 api/data
```
This removes all security. Any process (including compromised containers) can read/write/execute.

**Why it happens:** Frustration with permission errors leads to nuclear option.

**How to avoid:** Fix the root cause (UID mismatch), not the symptom (permission denied).

**Warning signs:** Security scanners flag world-writable directories as critical vulnerabilities.

### Pitfall 3: Hardcoding Container Names When Scaling is Needed

**What goes wrong:**
```yaml
services:
  api:
    container_name: sysndd_api

# Later:
$ docker compose up --scale api=4
ERROR: Cannot create container for service api:
Conflict. The container name "/sysndd_api" is already in use
```

**Why it happens:** Container names are globally unique. Docker can't create 4 containers with the same name.

**How to avoid:** Only use `container_name` for singleton services (databases, reverse proxies). Never for horizontally scalable services.

**Warning signs:** Any service that might need >1 instance for load balancing or redundancy.

### Pitfall 4: Runtime `user:` Directive Without Fixing COPY Ownership

**What goes wrong:**
```yaml
services:
  api:
    image: sysndd-api
    user: "1000:1000"  # Run as UID 1000

# But Dockerfile has:
COPY --chown=apiuser:api endpoints/ endpoints/  # Owned by UID 1001
```
Container runs as UID 1000 but files are owned by UID 1001 → permission errors.

**Why it happens:** Misunderstanding that `user:` in Compose only affects runtime, not build-time ownership.

**How to avoid:** Use ARG UID at build time so COPY ownership matches runtime user.

**Warning signs:** "Permission denied" errors even after adding `user:` directive in Compose.

### Pitfall 5: Not Re-checking Pending Migrations After Lock

**What goes wrong:**
```r
# Anti-pattern:
pending <- get_pending_migrations()
acquire_migration_lock()
# Another container migrated while we waited for lock
run_migrations()  # Tries to apply already-applied migrations
```

**Why it happens:** Race condition - state changed while waiting for lock.

**How to avoid:** Double-checked locking pattern (check, lock, re-check, run).

**Warning signs:** Duplicate migration errors in multi-container startup.

## Code Examples

Verified patterns from official sources and existing codebase:

### Configurable UID in Dockerfile
```dockerfile
# Source: https://dev.to/izackv/running-a-docker-container-with-a-custom-non-root-user-syncing-host-and-container-permissions-26mb
# Pattern: ARG with defaults for broad compatibility

ARG UID=1000
ARG GID=1000

# Create group and user with provided UID/GID
RUN groupadd -g ${GID} api && \
    useradd -u ${UID} -g api -m -s /bin/bash apiuser

# All subsequent COPY commands use numeric UID from ARG
COPY --chown=${UID}:${GID} endpoints/ endpoints/
COPY --chown=${UID}:${GID} functions/ functions/

# Create writable directories with correct ownership
RUN mkdir -p /app/data /app/logs /app/results && \
    chown -R ${UID}:${GID} /app/data /app/logs /app/results

# Switch to non-root user
USER apiuser
```

### Build Args in Docker Compose
```yaml
# Source: https://docs.docker.com/build/building/variables/
# Pass host UID/GID to build

services:
  api:
    build:
      context: ./api/
      args:
        # Use environment variables with defaults
        - UID=${HOST_UID:-1000}
        - GID=${HOST_GID:-1000}
    volumes:
      - ./api/data:/app/data
```

### Scalable Service Configuration
```yaml
# Source: https://github.com/docker/compose/issues/3722
# Remove container_name to enable scaling

services:
  api:
    build: ./api/
    # NO container_name directive
    restart: unless-stopped
    volumes:
      - ./api/data:/app/data
    networks:
      - proxy
      - backend
    deploy:
      replicas: 2  # Optional: set default count

  # Singleton services CAN have container_name
  mysql:
    image: mysql:8.4.8
    container_name: sysndd_mysql  # OK - never scaled
```

### Diagnosis Commands
```bash
# Source: https://www.buildwithmatija.com/blog/how-to-fix-permission-denied-when-manipulating-files-in-docker-container
# 1. Check file owner UID on host
ls -ln api/data
# Output: drwxrwxr-x 2 1000 1000 4096 ...
#                      ^^^^ ^^^^ Host UID:GID

# 2. Check container user UID
docker exec sysndd_api id
# Output: uid=1001(apiuser) gid=1001(api)
#             ^^^^ Container UID

# 3. Verify mismatch
docker exec sysndd_api ls -ln /app/data
# Output: drwxrwxr-x 2 1000 1000 4096 ...
#                      ^^^^ ^^^^ Directory owned by different UID
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded UID 1001 | ARG UID=1000 with build-time override | 2026 (this phase) | Enables host UID matching without Dockerfile edits |
| `chmod 777` permission fixes | UID alignment | 2020s security hardening | Removes container escape vector |
| Init containers for migrations | Double-checked locking | 2024-2025 migration tools | O(1) startup instead of O(n) serialization |
| `user: "1000:1000"` in Compose | `ARG UID` in Dockerfile | 2023-2024 best practices | Fixes COPY ownership at build time |

**Deprecated/outdated:**
- **chmod 777 as permission fix**: Security anti-pattern, replaced by UID matching
- **Running containers as root**: Disabled by default in many orchestrators (Kubernetes security contexts)
- **docker-compose scale** command: Deprecated, replaced by `docker compose up --scale` (Compose V2)

## Current State Analysis

### API Dockerfile (api/Dockerfile)

**Lines 160-162:**
```dockerfile
# Create non-root user with specific UID/GID for security
RUN groupadd -g 1001 api && \
    useradd -u 1001 -g api -m -s /bin/bash apiuser
```

**Problem:** Hardcoded UID 1001. Host files in `api/data/` owned by UID 1000 (user `bernt-popp`).

**Evidence:**
```bash
$ id -u
1000

$ ls -ln api/data/ | head -5
total 111672
-rw-r--r--  1 1000 1000 21726816 Jan 26 00:59 9606.protein.aliases.v11.5.txt.gz
-rw-r--r--  1 1000 1000  1901833 Jan 26 00:59 9606.protein.info.v11.5.txt.gz
```

All files owned by UID 1000, but container runs as UID 1001 → write fails.

### docker-compose.yml

**Line 124:**
```yaml
services:
  api:
    build: ./api/
    container_name: sysndd_api  # BLOCKS SCALING
```

**Problem:** Prevents `docker compose up --scale api=4` due to name collision.

**Other services with container_name:**
- `traefik`: `sysndd_traefik` (line 4) - **OK, singleton**
- `mysql`: `sysndd_mysql` (line 54) - **OK, singleton**
- `mysql-cron-backup`: `sysndd_mysql_backup` (line 91) - **OK, singleton**
- `app`: `sysndd_app` (line 197) - **MAYBE REMOVE** if scaling frontend needed

**Recommendation:** Remove `container_name` from `api` service. Keep for singletons (traefik, mysql, backup).

### Favicon File (app/public/)

**Missing:** `brain-neurodevelopmental-disorders-sysndd.png`
**Exists:** `_old/brain-neurodevelopmental-disorders-sysndd.png`

**Referenced by:**
- `app/index.html` line 9: `<link rel="icon" type="image/png" href="/brain-neurodevelopmental-disorders-sysndd.png">`
- `app/public/index.html` line 9: `<link rel="icon" type="image/png" href="<%= BASE_URL %>brain-neurodevelopmental-disorders-sysndd.png">`

**Fix:** Copy `app/public/_old/brain-neurodevelopmental-disorders-sysndd.png` to `app/public/brain-neurodevelopmental-disorders-sysndd.png`

### Migration Coordination (Existing Implementation)

**Good news:** Double-checked locking pattern is NOT yet implemented, but all building blocks exist.

**Current flow (start_sysndd_api.R lines 210-253):**
1. Checkout connection
2. **Always acquire lock** (blocks up to 30s)
3. Run migrations (may find nothing to do)
4. Release lock

**Gap:** No pre-lock check to skip lock acquisition when schema is up-to-date.

**Available functions (migration-runner.R):**
- `list_migration_files()` - Gets migration files from disk
- `get_applied_migrations()` - Gets applied migrations from schema_version table
- `ensure_schema_version_table()` - Creates tracking table
- `run_migrations()` - Executes pending migrations

**Missing function:** `get_pending_migrations()` to compare disk vs. database before lock.

## Open Questions

None - all research domains resolved with HIGH confidence.

## Sources

### PRIMARY (HIGH confidence)

**Docker UID/Permission Patterns:**
- [Add a non-root user to a container - VS Code Docs](https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user)
- [Running a Docker Container with a Custom Non-Root User - DEV Community](https://dev.to/izackv/running-a-docker-container-with-a-custom-non-root-user-syncing-host-and-container-permissions-26mb)
- [Docker Best Practices: Using ARG and ENV in Dockerfiles](https://www.docker.com/blog/docker-best-practices-using-arg-and-env-in-your-dockerfiles/)
- [Variables | Docker Docs](https://docs.docker.com/build/building/variables/)

**Docker Compose Scaling:**
- [Docker Compose can't scale containers with hard-coded name · Issue #3722](https://github.com/docker/compose/issues/3722)
- [Scaling Services with Docker Compose - CodeSignal](https://codesignal.com/learn/courses/multi-container-orchestration-with-docker-compose/lessons/scaling-services-with-docker-compose)
- [Running multiple instances of a service with Docker Compose - PSPDFKit](https://pspdfkit.com/blog/2018/how-to-use-docker-compose-to-run-multiple-instances-of-a-service-in-development/)

**Permission Diagnostics:**
- [Fix Docker Permission Denied: Volumes, Bind Mounts & CI/CD](https://www.buildwithmatija.com/blog/how-to-fix-permission-denied-when-manipulating-files-in-docker-container)
- [The Complete Guide to Docker Mount Permission Issues](https://eastondev.com/blog/en/posts/dev/20251217-docker-mount-permissions-guide/)

**Migration Coordination:**
- [Multi-Container Migration Coordination Research](file:///home/bernt-popp/development/sysndd/.planning/research/FEATURES.md#L416-L746) - Existing research on double-checked locking pattern
- [MySQL 8.4 Locking Functions](https://dev.mysql.com/doc/refman/8.4/en/locking-functions.html) - GET_LOCK behavior
- [golang-migrate Double Check Locking Issue #468](https://github.com/golang-migrate/migrate/issues/468) - Exact pattern description

### SECONDARY (MEDIUM confidence)

- [How to Pass Build Arguments and Environment Variables in Docker](https://oneuptime.com/blog/post/2026-01-06-docker-build-args-env-variables/view)
- [Docker ARG, ENV and .env - a Complete Guide](https://vsupalov.com/docker-arg-env-variable-guide/)
- [Best practices for uid/gid and permissions? - Docker Forums](https://forums.docker.com/t/best-practices-for-uid-gid-and-permissions/139161)

### TERTIARY (LOW confidence - flagged for validation)

None - all findings verified with official documentation or multiple sources.

## Metadata

**Confidence breakdown:**
- UID/GID permission patterns: HIGH - Official Docker docs, multiple verified sources
- Scaling patterns: HIGH - Docker Compose GitHub issue, official Compose V2 docs
- Favicon issue: HIGH - Direct file inspection, clear missing file
- Migration coordination: HIGH - Existing codebase analysis, MySQL docs, golang-migrate pattern
- Current state analysis: HIGH - Direct Dockerfile/Compose inspection

**Research date:** 2026-02-01
**Valid until:** 60 days (stable patterns, official Docker behavior)
**Researcher:** GSD Phase Researcher (Infrastructure domain)

## Implementation Readiness

All issues have clear, verified solutions:

1. **DEPLOY-01 (API write permissions)**: Add ARG UID=1000/GID=1000 to Dockerfile
2. **DEPLOY-02 (Configurable UID)**: ARG already enables --build-arg override
3. **DEPLOY-04 (Container scaling)**: Remove `container_name: sysndd_api` from docker-compose.yml
4. **BUG-01 (Favicon 404)**: Copy PNG from `_old/` to `public/` root

No blockers. No external dependencies. All solutions are Dockerfile/Compose config changes.
