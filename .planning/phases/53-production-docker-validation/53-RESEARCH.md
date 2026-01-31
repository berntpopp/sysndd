# Phase 53: Production Docker Validation - Research

**Researched:** 2026-01-30
**Domain:** Docker production deployment, R Plumber multi-worker, database connection pooling, health checks
**Confidence:** MEDIUM-HIGH

## Summary

This phase validates the production Docker build with 4 API workers, correct connection pool sizing, extended health checks, and a Makefile preflight target. The research focuses on three interconnected areas: (1) how to run multiple R Plumber workers in production, (2) correct database connection pool sizing for multi-worker setups, and (3) Kubernetes-ready health check patterns.

**Key Finding:** The current SysNDD setup uses a single Plumber process (R is single-threaded). Running "4 workers" in the requirement context means either external process orchestration (pm2, Valve, Docker Swarm replicas) OR recognizing that R Plumber handles requests sequentially and the pool size should match the *single process* needs, not multiple workers within one container.

**Primary recommendation:** For Phase 53, validate that the *production Docker image* starts correctly, the connection pool is sized for the single Plumber process (default pool settings are appropriate), and implement a comprehensive `/health/ready` endpoint that verifies database connectivity AND migration status. Use `make preflight` to orchestrate the validation sequence.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| pool | 1.0.4 | Database connection pooling | RStudio/Posit official package, integrates with DBI |
| RMariaDB | 1.3.4 | MySQL/MariaDB driver | DBI-compliant, supports parameterized queries |
| plumber | 1.2.2+ | REST API framework | De facto standard for R APIs |
| DBI | 1.2.3 | Database interface | CRAN standard for database access |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| mirai | 2.x | Async task execution | Background jobs (already configured with 2 daemons) |
| httpuv | 1.6.x | HTTP server (Plumber backend) | Automatic with Plumber |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Single Plumber | Valve (multi-process) | Adds Rust dependency, more complex deployment |
| Single Plumber | pm2 (multi-process) | Requires Node.js, each process needs own port |
| Single container | Docker Swarm replicas | Simpler for validation phase, scale-out later |

**Installation:**
```bash
# All packages already in renv.lock, no changes needed
```

## Architecture Patterns

### Current Production Architecture
```
                    Docker Host
                    +------------------------------------------+
                    |                                          |
  HTTP :80 ------->|  Traefik (reverse proxy)                 |
                    |      |                                   |
                    |      v                                   |
                    |  +--------------------------------+      |
                    |  |  sysndd_api container         |      |
                    |  |  - Single R Plumber process   |      |
                    |  |  - pool (connection pooling)  |      |
                    |  |  - mirai (2 async workers)    |      |
                    |  +--------------------------------+      |
                    |      |                                   |
                    |      v                                   |
                    |  +--------------------------------+      |
                    |  |  MySQL 8.0.40                 |      |
                    |  |  (internal network)           |      |
                    |  +--------------------------------+      |
                    +------------------------------------------+
```

### Pattern 1: Connection Pool Configuration for Single Process
**What:** Configure dbPool() with appropriate minSize/maxSize for a single Plumber process
**When to use:** Production deployment with single API container
**Example:**
```r
# Source: pool package documentation (rstudio.github.io/pool)
pool <- dbPool(
  drv = RMariaDB::MariaDB(),
  dbname = dw$dbname,
  host = dw$host,
  user = dw$user,
  password = dw$password,
  port = dw$port,
  # Pool sizing for single-threaded R process
  minSize = 1,              # Keep 1 connection always open
  maxSize = 5,              # Allow burst to 5 concurrent
  idleTimeout = 60,         # Close excess after 60s idle
  validationInterval = 60   # Validate connections every 60s
)
```

### Pattern 2: Extended Health Check with Database Verification
**What:** `/health/ready` endpoint that checks database connectivity and migration status
**When to use:** Kubernetes/load balancer readiness probes
**Example:**
```r
# Source: Kubernetes health check best practices
#* Readiness check endpoint
#* @get /ready
function(req, res) {
  # Check database connectivity
  db_ok <- tryCatch({
    result <- db_execute_query("SELECT 1 AS ok")
    !is.null(result) && nrow(result) == 1
  }, error = function(e) FALSE)

  # Check migration status (from global variable)
  migrations_ok <- exists("migration_status", where = .GlobalEnv) &&
    !is.null(.GlobalEnv$migration_status) &&
    .GlobalEnv$migration_status$pending_migrations == 0

  # Get pool statistics
  pool_stats <- tryCatch({
    list(
      size = pool$counters$free + pool$counters$taken,
      free = pool$counters$free,
      taken = pool$counters$taken
    )
  }, error = function(e) list(error = e$message))

  if (db_ok && migrations_ok) {
    list(
      status = "healthy",
      database = "connected",
      migrations = list(
        pending = 0,
        applied = .GlobalEnv$migration_status$total_migrations
      ),
      pool = pool_stats
    )
  } else {
    res$status <- 503L
    list(
      status = "unhealthy",
      reason = if (!db_ok) "database_unavailable" else "migrations_pending",
      database = if (db_ok) "connected" else "disconnected",
      migrations = if (migrations_ok) list(pending = 0) else list(pending = NA)
    )
  }
}
```

### Pattern 3: Makefile Preflight Validation
**What:** `make preflight` target that builds, starts, validates, and cleans up
**When to use:** Pre-deployment validation, CI/CD pipelines
**Example:**
```makefile
# Source: Makefile CI/CD best practices
.PHONY: preflight

PREFLIGHT_TIMEOUT := 120
HEALTH_ENDPOINT := http://localhost:7777/health/ready

preflight: check-docker ## [quality] Run production preflight validation
	@printf "$(CYAN)==> Running production preflight validation...$(RESET)\n"
	@printf "\n$(CYAN)[1/4] Building production image...$(RESET)\n"
	@docker build -t sysndd-api:preflight -f api/Dockerfile api/
	@printf "\n$(CYAN)[2/4] Starting containers...$(RESET)\n"
	@docker compose -f docker-compose.yml up -d
	@printf "\n$(CYAN)[3/4] Waiting for health check...$(RESET)\n"
	@SECONDS=0; \
	while [ $$SECONDS -lt $(PREFLIGHT_TIMEOUT) ]; do \
		if curl -sf $(HEALTH_ENDPOINT) > /dev/null 2>&1; then \
			printf "$(GREEN)Health check passed!$(RESET)\n"; \
			break; \
		fi; \
		sleep 2; \
		SECONDS=$$((SECONDS+2)); \
	done; \
	if [ $$SECONDS -ge $(PREFLIGHT_TIMEOUT) ]; then \
		printf "$(RED)Health check timed out after $(PREFLIGHT_TIMEOUT)s$(RESET)\n"; \
		docker compose logs api --tail=50; \
		docker compose down; \
		exit 1; \
	fi
	@printf "\n$(CYAN)[4/4] Cleanup...$(RESET)\n"
	@docker compose -f docker-compose.yml down
	@printf "\n$(GREEN)PREFLIGHT PASSED$(RESET)\n"
```

### Anti-Patterns to Avoid
- **Large pool sizes:** Don't set maxSize > 10 for a single R process; R is single-threaded so connections queue anyway
- **External dependencies in liveness:** Only use external checks (database) in readiness, not liveness probes
- **Blocking health checks:** Don't run expensive queries in health endpoints; use simple connectivity tests
- **Ignoring migration status:** Always check migrations before declaring ready; incomplete schema causes errors

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Connection pooling | Manual connection management | pool::dbPool() | Handles checkout/return, validation, timeout automatically |
| Health check framework | Custom HTTP server | Plumber endpoints | Already integrated, uses same runtime |
| Container orchestration | Shell scripts managing processes | Docker Compose healthcheck + depends_on | Declarative, automatic restart on failure |
| Process management | supervisor/systemd in container | Docker restart policy | Container-native, simpler |
| Database wait logic | wait-for-it.sh or sleep loops | Docker Compose depends_on: service_healthy | Native Docker feature, cleaner |

**Key insight:** The pool package already handles connection lifecycle, validation, and sizing. The existing health endpoint infrastructure (already has `/health` and `/health/ready`) just needs enhancement. Focus on *validation* not *building new infrastructure*.

## Common Pitfalls

### Pitfall 1: Misunderstanding "4 Workers" Requirement
**What goes wrong:** Assuming 4 workers means 4 parallel R processes within one container
**Why it happens:** Confusion between Plumber (single-threaded R) vs. Python/Node multi-worker models
**How to avoid:** Clarify: R Plumber is single-threaded. "4 workers" likely refers to:
  - Docker Swarm/Kubernetes replicas (4 container instances), OR
  - mirai daemon workers for async tasks (currently 2), OR
  - Connection pool allowing 4 concurrent DB connections
**Warning signs:** Attempting to use parallel::mclapply in Plumber endpoints (forks don't work reliably)

### Pitfall 2: Pool Exhaustion Under Load
**What goes wrong:** All pool connections are checked out, new requests fail
**Why it happens:** Long-running queries hold connections, pool maxSize too small
**How to avoid:**
  - Set maxSize = 5-10 for single Plumber process
  - Ensure all db_execute_* calls have proper cleanup (on.exit)
  - Monitor pool stats via `/health/ready` response
**Warning signs:** 503 errors with "Connection pool exhausted" or increasing latency

### Pitfall 3: Health Check External Dependency Cascade
**What goes wrong:** Database outage causes ALL pods to be marked unhealthy, no traffic served
**Why it happens:** Readiness probe checks database, all pods fail simultaneously
**How to avoid:**
  - Accept this behavior for readiness (it's correct - can't serve without DB)
  - Keep liveness simple (process alive check only, no external deps)
  - Use appropriate timeouts (don't mark unhealthy too quickly)
**Warning signs:** All pods cycling during brief DB maintenance windows

### Pitfall 4: Preflight Doesn't Match Production
**What goes wrong:** Preflight passes but production fails
**Why it happens:** Different compose files, different env vars, different volumes
**How to avoid:**
  - Preflight uses exact same docker-compose.yml as production
  - Validate with same environment variables (or subset)
  - Don't skip steps that production would run
**Warning signs:** "Works in preflight, fails in prod" reports

## Code Examples

Verified patterns from existing codebase and official sources:

### Current Pool Creation (start_sysndd_api.R:180-188)
```r
# Source: api/start_sysndd_api.R
pool <<- dbPool(
  drv      = RMariaDB::MariaDB(),
  dbname   = dw$dbname,
  host     = dw$host,
  user     = dw$user,
  password = dw$password,
  server   = dw$server,
  port     = dw$port
  # Note: Uses default pool settings (minSize=1, maxSize=Inf)
)
```

### Enhanced Pool with Explicit Sizing
```r
# Source: pool package documentation (rstudio.github.io/pool/reference/dbPool.html)
# Recommended for production - explicit limits
pool_size <- as.integer(Sys.getenv("DB_POOL_SIZE", "5"))

pool <<- dbPool(
  drv      = RMariaDB::MariaDB(),
  dbname   = dw$dbname,
  host     = dw$host,
  user     = dw$user,
  password = dw$password,
  server   = dw$server,
  port     = dw$port,
  minSize  = 1,
  maxSize  = pool_size,
  idleTimeout = 60,
  validationInterval = 60
)
```

### Existing Health Endpoint (health_endpoints.R)
```r
# Source: api/endpoints/health_endpoints.R
# Already has /health/ready - just needs enhancement for database check
#* @get /ready
function(req, res) {
  # Current: checks migration_status only
  # Enhancement needed: add actual database ping
}
```

### Docker HEALTHCHECK (api/Dockerfile:172-173)
```dockerfile
# Source: api/Dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:7777/health/ || exit 1
```

### Docker Compose healthcheck (docker-compose.yml:126-131)
```yaml
# Source: docker-compose.yml
healthcheck:
  test: ["CMD", "curl", "-sf", "http://localhost:7777/health/"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Multiple R processes via pm2 | Single container, scale via orchestrator | 2024 | Simpler deployment, better resource isolation |
| Manual connection management | pool package | 2018+ | Automatic lifecycle, validation |
| wait-for-it.sh scripts | Docker Compose depends_on: service_healthy | Compose v2 | Native Docker, declarative |
| Custom process supervisors | Container restart policies | Docker era | Simpler, container-native |

**Deprecated/outdated:**
- **Valve for single-container scaling:** Interesting but adds Rust dependency; better to use Docker/K8s replicas
- **Manual connection cycling:** pool package handles this automatically

## Open Questions

Things that couldn't be fully resolved:

1. **"4 workers" interpretation**
   - What we know: R Plumber is single-threaded; mirai provides 2 async workers for background jobs
   - What's unclear: Does requirement mean 4 container replicas? 4 mirai workers? Pool size of 4?
   - Recommendation: Interpret as "validate production configuration works correctly" - the Dockerfile CMD runs single Plumber process; scaling is via container replicas at orchestration layer

2. **Pool sizing formula**
   - What we know: pool defaults (minSize=1, maxSize=Inf) work but Inf is risky
   - What's unclear: Exact optimal maxSize for SysNDD workload
   - Recommendation: Use DB_POOL_SIZE env var with default of 5; monitor via /health/ready pool stats; adjust based on production metrics

3. **Preflight vs CI integration**
   - What we know: `make preflight` should be CI-friendly (exit codes, no prompts)
   - What's unclear: Whether to integrate with existing GitHub Actions
   - Recommendation: Focus on standalone Makefile target; CI integration can be added later

## Sources

### Primary (HIGH confidence)
- [pool package documentation](https://rstudio.github.io/pool/reference/dbPool.html) - dbPool parameters, defaults, usage
- [pool advanced usage](https://rstudio.github.io/pool/articles/advanced-pool.html) - Multi-worker considerations
- [Plumber execution model](https://www.rplumber.io/articles/execution-model.html) - Single-threaded nature, scaling approaches
- Existing codebase: api/start_sysndd_api.R, api/endpoints/health_endpoints.R, api/functions/db-helpers.R

### Secondary (MEDIUM confidence)
- [Kubernetes health check best practices](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/) - Readiness vs liveness separation
- [Docker Compose healthcheck docs](https://docs.docker.com/compose/how-tos/startup-order/) - depends_on with condition
- [Makefile CI/CD patterns](https://sjramblings.io/how-to-simplify-your-ci-cd-with-makefiles/) - Preflight validation structure

### Tertiary (LOW confidence)
- [Valve project](https://valve.josiahparry.com/) - Alternative for multi-worker R (not recommended for this phase)
- [MySQL connection sizing](https://releem.com/docs/mysql-performance-tuning/max_connections) - General guidance, not R-specific

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - pool package is well-documented, already in use
- Architecture: MEDIUM-HIGH - Single-process pattern is clear, "4 workers" needs clarification
- Pitfalls: HIGH - Common R/Plumber deployment issues well-documented
- Preflight pattern: MEDIUM - General Makefile patterns, needs adaptation to SysNDD

**Research date:** 2026-01-30
**Valid until:** 2026-02-28 (30 days - stable packages, no major version changes expected)
