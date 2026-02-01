# Architecture Patterns: Docker Compose Production Scaling

**Domain:** Multi-container API scaling with shared data directories
**Researched:** 2026-02-01
**Confidence:** HIGH (verified with Docker official docs)

## Current Architecture

### Existing Docker Compose Structure

The project currently uses a three-file Docker Compose structure:

| File | Purpose | Auto-loaded |
|------|---------|-------------|
| `docker-compose.yml` | Base configuration with all services | Yes |
| `docker-compose.override.yml` | Development overrides (Traefik debug, exposed ports) | Yes (by default) |
| `docker-compose.dev.yml` | Isolated dev databases for local R development | No (requires `-f` flag) |

### Current Service Definitions

**Traefik (Load Balancer):**
- Image: `traefik:v3.6`
- Fixed container name: `sysndd_traefik`
- Exposes port 80, routes based on path prefix
- Docker provider for dynamic service discovery

**API Service:**
- Build from `./api/`
- Fixed container name: `sysndd_api`
- Single instance (no replicas currently)
- Memory: 4608MB, CPU: 2.0 cores
- Mounts multiple directories including `/app/data`, `/app/cache`, `/app/results`

**App Service (Frontend):**
- Build from `./app/`
- Fixed container name: `sysndd_app`
- Single instance
- Memory: 256MB, CPU: 0.5 cores

**MySQL:**
- Fixed container name: `sysndd_mysql`
- Internal network only (`sysndd_backend`)
- Persistent volume: `sysndd_mysql_data`

### Current Volume Mounts (API)

```yaml
volumes:
  - ./api/endpoints:/app/endpoints
  - ./api/functions:/app/functions
  - ./api/core:/app/core
  - ./api/services:/app/services
  - ./api/repository:/app/repository
  - ./api/config:/app/config
  - ./api/data:/app/data          # Shared data files (STRING, HGNC, etc.)
  - ./api/results:/app/results    # Job output files
  - api_cache:/app/cache          # Named volume for memoization cache
  - mysql_backup:/backup:rw       # Backup volume
  - ./api/config.yml:/app/config.yml
  - ./api/version_spec.json:/app/version_spec.json
  - ./api/start_sysndd_api.R:/app/start_sysndd_api.R
```

### Current Migration Strategy

The API startup script (`start_sysndd_api.R`) runs migrations with MySQL advisory locking:

```r
# Acquire advisory lock (blocks until available or 30s timeout)
acquire_migration_lock(migration_conn, timeout = 30)
# Run migrations
result <- run_migrations(migrations_dir = "db/migrations", conn = pool)
# Release lock on exit
release_migration_lock(migration_conn)
```

**Existing coordination mechanism:** MySQL `GET_LOCK()` / `RELEASE_LOCK()` ensures only one API instance runs migrations at a time. Other instances wait up to 30 seconds.

## Integration Points

### 1. Container Naming and Replicas

**Current Problem:**
The `container_name: sysndd_api` directive in `docker-compose.yml` prevents scaling because container names must be unique.

**Integration Point:**
```yaml
# docker-compose.yml (base)
api:
  container_name: sysndd_api  # REMOVE for scaling
```

**Resolution Pattern:**
Remove `container_name` and use `deploy.replicas`:

```yaml
# docker-compose.yml (modified for scaling)
api:
  build: ./api/
  # container_name: removed
  deploy:
    replicas: 4
    resources:
      limits:
        memory: 4608M
        cpus: '2.0'
```

Docker Compose will auto-name containers as: `sysndd-api-1`, `sysndd-api-2`, etc.

**Source:** [Docker Compose Deploy Specification](https://docs.docker.com/reference/compose-file/deploy/) - "container_name and replicas cannot be used together"

### 2. Traefik Load Balancing

**Current Configuration:**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.api.rule=PathPrefix(`/api`)"
  - "traefik.http.services.api.loadbalancer.server.port=7777"
```

**Integration Point:**
Traefik automatically discovers all containers with the `traefik.enable=true` label and adds them to the load balancer pool. No configuration changes needed for basic round-robin.

**Optional Enhancements:**
```yaml
labels:
  # Sticky sessions (if needed for stateful requests)
  - "traefik.http.services.api.loadbalancer.sticky.cookie.name=sysndd_api"

  # Health check configuration
  - "traefik.http.services.api.loadbalancer.healthcheck.path=/api/health/"
  - "traefik.http.services.api.loadbalancer.healthcheck.interval=10s"
```

**Source:** [Traefik Docker Documentation](https://doc.traefik.io/traefik/providers/docker/) - "The Service automatically gets a server per instance of the container"

### 3. Shared Volume Strategy

**Critical Issue:**
Docker does not handle file locking. Multiple containers writing to shared volumes requires application-level coordination.

**Current Shared Directories:**

| Directory | Access Pattern | Risk with Replicas |
|-----------|---------------|-------------------|
| `/app/data` | Read-heavy (STRING, HGNC files) | LOW - mostly static data |
| `/app/cache` | Read/Write (memoise cache) | MEDIUM - concurrent writes |
| `/app/results` | Write (job outputs) | HIGH - filename collisions |
| `/app/logs` | Write (log files) | MEDIUM - per-container logging |

**Resolution Patterns:**

**Pattern A: Read-Only for Static Data**
```yaml
volumes:
  - ./api/data:/app/data:ro  # Read-only mount
```

**Pattern B: Named Volumes with Volume Drivers**
For shared write access, use a named volume that all replicas mount:
```yaml
volumes:
  api_cache:
    name: sysndd_api_cache
    # Consider external volume driver for production
```

**Pattern C: Per-Container Isolation**
For logs and results, use container-specific paths:
```r
# In R code, generate unique file paths
log_file <- sprintf("logs/%s_%s.log", Sys.getenv("HOSTNAME"), format(Sys.time(), "%Y%m%d"))
```

**Pattern D: File-Based Locking**
For critical shared writes, implement advisory locking:
```r
lock_file <- "/app/data/.lock"
lock <- flock::lock(lock_file)
on.exit(flock::unlock(lock))
# ... write operation ...
```

**Source:** [Docker Volumes Documentation](https://docs.docker.com/engine/storage/volumes/) - "Docker doesn't handle file locking"

### 4. Migration Coordination

**Current Implementation (Already Suitable):**
The existing MySQL advisory lock pattern handles multi-instance migrations correctly:

1. First container to start acquires `GET_LOCK('sysndd_migration', 30)`
2. Other containers block waiting for lock
3. First container runs migrations, releases lock
4. Other containers acquire lock, see no pending migrations, proceed

**No changes needed** for migration handling.

**Verification:**
- Lock timeout (30s) is sufficient for typical migrations
- Schema versioning in `schema_version` table prevents re-running
- Failure causes container crash (fail-fast), triggering restart

### 5. Health Check Coordination

**Current Health Check:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-sf", "http://localhost:7777/api/health/"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

**Integration Point:**
The `start_period: 60s` allows time for:
1. Database connection
2. Migration lock acquisition (up to 30s wait)
3. Migration execution
4. Package loading and API startup

**Recommended Adjustment for Replicas:**
Increase `start_period` to account for staggered container starts:
```yaml
healthcheck:
  start_period: 120s  # Increased from 60s
```

### 6. Production Override Pattern

**Recommended Structure:**
Create `docker-compose.prod.yml` for production-specific scaling:

```yaml
# docker-compose.prod.yml
services:
  api:
    # Remove container_name (inherited from base would conflict)
    container_name: null  # Explicit null to override
    deploy:
      mode: replicated
      replicas: 4
      resources:
        limits:
          memory: 4608M
          cpus: '2.0'
      update_config:
        parallelism: 1
        delay: 30s
        order: start-first
      rollback_config:
        parallelism: 1
        delay: 30s
```

**Usage:**
```bash
# Production deployment
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Development (with override)
docker compose up --watch
```

## Build Order

### Phase 1: Remove Container Name Conflicts

**Files to Modify:**
1. `docker-compose.yml` - Remove or comment out `container_name: sysndd_api`

**Verification:**
```bash
docker compose config  # Validate merged configuration
docker compose up --scale api=2  # Test basic scaling
```

### Phase 2: Add Production Scaling Configuration

**Files to Create:**
1. `docker-compose.prod.yml` - Production overrides with replicas

**Content:**
```yaml
services:
  api:
    deploy:
      mode: replicated
      replicas: 4
      update_config:
        parallelism: 1
        delay: 30s
        order: start-first
```

**Verification:**
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml config
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Phase 3: Adjust Volume Access Patterns

**Files to Modify:**
1. `docker-compose.yml` - Change volume mounts to read-only where safe

**Changes:**
```yaml
volumes:
  - ./api/data:/app/data:ro           # Static data - read-only
  - ./api/endpoints:/app/endpoints:ro  # Code - read-only in prod
  - ./api/functions:/app/functions:ro  # Code - read-only in prod
  # ... etc for code directories
```

**Keep Read-Write:**
- `api_cache:/app/cache` - Memoise cache (shared named volume)
- `./api/results:/app/results` - Job outputs (needs container-aware paths)

### Phase 4: Update Health Check Timing

**Files to Modify:**
1. `docker-compose.yml` or `docker-compose.prod.yml`

**Changes:**
```yaml
healthcheck:
  start_period: 120s  # Increased from 60s
```

### Phase 5: Application-Level File Isolation

**Files to Modify (R Code):**
1. `api/functions/job-manager.R` - Use container-unique filenames
2. `api/functions/logging-functions.R` - Per-container log files

**Pattern:**
```r
# Get container hostname for unique identification
container_id <- Sys.getenv("HOSTNAME", "default")
output_file <- sprintf("results/job_%s_%s.json", job_id, container_id)
```

## Dependency Graph

```
Phase 1: Remove container_name
    |
    v
Phase 2: Add deploy.replicas
    |
    +---> Traefik auto-discovers new containers (no changes needed)
    |
    v
Phase 3: Adjust volume permissions
    |
    v
Phase 4: Adjust health check timing
    |
    v
Phase 5: Application file isolation (R code changes)
```

## Patterns to Follow

### Pattern 1: Graceful Rollout

Use `update_config` for zero-downtime deployments:

```yaml
deploy:
  update_config:
    parallelism: 1      # Update one container at a time
    delay: 30s          # Wait between updates
    order: start-first  # Start new before stopping old
    failure_action: rollback
```

**Why:** Ensures at least one healthy container serves traffic during updates.

### Pattern 2: Resource Limits Per Container

Keep current resource limits but apply per-replica:

```yaml
deploy:
  replicas: 4
  resources:
    limits:
      memory: 4608M  # Per container, not total
      cpus: '2.0'
```

**Why:** Docker enforces limits per container; 4 replicas = 4x resources consumed.

### Pattern 3: Named Volumes for Shared State

```yaml
volumes:
  api_cache:
    name: sysndd_api_cache
    driver: local
```

**Why:** Named volumes persist across container recreations and can be shared.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Bind Mounts for Production Code

**Problem:**
```yaml
volumes:
  - ./api/endpoints:/app/endpoints  # Development pattern
```

**Why Bad:**
- Host filesystem changes affect running containers
- Slow performance on some Docker hosts (especially macOS)
- Security risk (container can modify host files)

**Instead:**
In production, bake code into image and use read-only mounts only for data:
```yaml
# Production override
volumes:
  - ./api/data:/app/data:ro  # Only external data, read-only
```

### Anti-Pattern 2: Hardcoded Container Names in Application

**Problem:**
```r
# In R code
system("docker exec sysndd_api ...")
```

**Why Bad:** Container names change with replicas (`sysndd-api-1`, `sysndd-api-2`).

**Instead:** Use service discovery via Docker networks and DNS names.

### Anti-Pattern 3: Shared Writable Directories Without Coordination

**Problem:**
Multiple containers writing to same files in shared volume.

**Why Bad:** Race conditions, data corruption, unpredictable behavior.

**Instead:**
- Use unique filenames per container
- Use database for shared state
- Use Redis/external cache for shared caching

## Scalability Considerations

| Component | At 1 Container | At 4 Containers | At 8+ Containers |
|-----------|---------------|-----------------|------------------|
| API Memory | 4.6GB | 18.4GB total | 36.8GB+ (may need VM resize) |
| DB Pool | 5 connections | 20 connections | 40+ (check MySQL max_connections) |
| Traefik | Round-robin | Round-robin | Consider sticky sessions |
| Cache | Local memoise | Shared volume | Consider Redis |
| Logs | File per container | Many files | Consider log aggregation |

## Sources

- [Docker Compose Deploy Specification](https://docs.docker.com/reference/compose-file/deploy/) - Replicas, update config
- [Docker Compose Startup Order](https://docs.docker.com/compose/how-tos/startup-order/) - Health checks, depends_on
- [Docker Volumes Documentation](https://docs.docker.com/engine/storage/volumes/) - Shared volume patterns
- [Docker Bind Mounts](https://docs.docker.com/engine/storage/bind-mounts/) - Read-only options
- [Traefik Docker Provider](https://doc.traefik.io/traefik/providers/docker/) - Service discovery, load balancing
- [Docker Community Forums](https://forums.docker.com/t/why-does-it-throw-an-error-when-i-set-container-name-on-a-replicated-service/140721) - container_name/replicas conflict

---

*Architecture research: 2026-02-01*
