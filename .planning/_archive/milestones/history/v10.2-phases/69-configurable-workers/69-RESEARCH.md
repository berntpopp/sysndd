# Phase 69: Configurable Workers - Research

**Researched:** 2026-02-03
**Domain:** R/mirai daemon configuration, Docker environment variables, health monitoring
**Confidence:** HIGH

## Summary

This phase implements configurable mirai worker count via the MIRAI_WORKERS environment variable, allowing operators to tune memory usage for their server's constraints. The implementation follows the exact pattern already established in the codebase for DB_POOL_SIZE configuration.

The mirai package (v2.5.3, currently used by this project) provides straightforward APIs:
- `daemons(n = X)` spawns X background worker processes
- `status()$connections` returns the count of active daemon connections
- Invalid or out-of-bounds values should be sanitized to sensible defaults (1-8)

**Primary recommendation:** Follow the existing DB_POOL_SIZE pattern exactly: parse env var with default, validate bounds, log at startup, and expose in health endpoint.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| mirai | 2.5.3 | Async task execution | Already in use, provides daemons() and status() |
| base R | 4.5.2 | Sys.getenv(), as.integer() | Standard environment variable parsing |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (none required) | - | - | Implementation uses only base R and mirai |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Environment variable | config.yml entry | Env var preferred for container deployment (12-factor app) |
| as.integer(Sys.getenv()) | Sys.getenv(, unset=2L) | Explicit conversion matches existing pattern |

**Installation:**
No new packages required - mirai already in renv.lock.

## Architecture Patterns

### Recommended Project Structure
No new files needed. Changes to existing files:
```
api/
  start_sysndd_api.R            # Add MIRAI_WORKERS env var parsing (lines 374-381)
  endpoints/health_endpoints.R  # Add workers to health response
docker-compose.yml              # Add MIRAI_WORKERS env var
docker-compose.dev.yml          # Add MIRAI_WORKERS env var with dev default
```

### Pattern 1: Environment Variable Configuration
**What:** Read configuration from environment with default, validate bounds, log at startup
**When to use:** Any container-configurable value that affects runtime behavior
**Example:**
```r
# Source: Existing pattern from api/start_sysndd_api.R lines 184-204
# Read worker count from environment variable with default
worker_count <- as.integer(Sys.getenv("MIRAI_WORKERS", "2"))

# Validate bounds (minimum 1, maximum 8)
# Use max/min chain for clear, readable bounds enforcement
worker_count <- max(1L, min(worker_count, 8L))

daemons(
  n = worker_count,
  dispatcher = TRUE,
  autoexit = tools::SIGINT
)

message(sprintf("[%s] Started mirai daemon pool with %d workers", Sys.time(), worker_count))
```

### Pattern 2: Health Endpoint Exposure
**What:** Include runtime configuration in health response for monitoring/debugging
**When to use:** Any tunable that operators need to verify is correctly applied
**Example:**
```r
# Source: Existing pattern from api/endpoints/health_endpoints.R (pool_stats)
# Get worker statistics
worker_status <- tryCatch(
  {
    status <- mirai::status()
    list(
      configured = as.integer(Sys.getenv("MIRAI_WORKERS", "2")),
      connections = status$connections
    )
  },
  error = function(e) {
    list(
      configured = as.integer(Sys.getenv("MIRAI_WORKERS", "2")),
      error = "Unable to read worker status"
    )
  }
)
```

### Pattern 3: Docker Compose Environment Variables
**What:** Pass configuration to container with fallback default
**When to use:** Any configurable value that varies between deployments
**Example:**
```yaml
# Source: Existing pattern from docker-compose.yml line 158
environment:
  MIRAI_WORKERS: ${MIRAI_WORKERS:-2}  # Production default: 2 workers
```

### Anti-Patterns to Avoid
- **Hard-coded values:** Don't use `daemons(n = 2)` - make configurable
- **No validation:** Don't trust user input - validate bounds
- **Silent failure:** Don't silently use invalid values - log what was applied
- **Missing from health:** Don't omit runtime config from health endpoint - operators need visibility

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Worker configuration | Custom config system | Environment variables | 12-factor app standard, Docker-native |
| Daemon status | Custom tracking | mirai::status() | Returns connections count directly |
| Bounds validation | Complex validation | max()/min() chain | Clear, readable, idiomatic R |
| Invalid value handling | Custom parsing | as.integer() + NA check | Returns NA for non-numeric, easy to handle |

**Key insight:** The codebase already has the DB_POOL_SIZE pattern that solves this exact problem. Follow it exactly for consistency.

## Common Pitfalls

### Pitfall 1: NA from Invalid Environment Variable
**What goes wrong:** `as.integer("abc")` returns `NA`, which causes `daemons(n = NA)` to fail
**Why it happens:** User sets `MIRAI_WORKERS=abc` or empty string
**How to avoid:** Check for NA after conversion, apply default
```r
worker_count <- as.integer(Sys.getenv("MIRAI_WORKERS", "2"))
if (is.na(worker_count)) {
  message("[WARN] Invalid MIRAI_WORKERS value, using default 2")
  worker_count <- 2L
}
worker_count <- max(1L, min(worker_count, 8L))
```
**Warning signs:** API fails to start with cryptic error about daemons()

### Pitfall 2: Zero Workers
**What goes wrong:** `MIRAI_WORKERS=0` means no background processing capacity
**Why it happens:** User thinks 0 might mean "unlimited" or "auto"
**How to avoid:** Minimum bound of 1 enforced via max(1L, ...)
**Warning signs:** Jobs submitted but never execute

### Pitfall 3: Too Many Workers
**What goes wrong:** Memory exhaustion, OOM kills, system instability
**Why it happens:** User thinks more workers = better performance
**How to avoid:** Maximum bound of 8 enforced via min(..., 8L)
**Warning signs:** Server swapping, API container killed by Docker

### Pitfall 4: Inconsistent Status Reporting
**What goes wrong:** Health endpoint shows different count than actually running
**Why it happens:** Reading env var instead of actual daemon status
**How to avoid:** Use `mirai::status()$connections` for actual count, env var for configured
**Warning signs:** Monitoring shows 2 workers but performance suggests 1

## Code Examples

Verified patterns from official sources and existing codebase:

### Reading Environment Variable with Default
```r
# Source: api/start_sysndd_api.R line 188
pool_size <- as.integer(Sys.getenv("DB_POOL_SIZE", "5"))
```

### Validating Bounds
```r
# Source: Official R idiom for numeric bounds
worker_count <- max(1L, min(worker_count, 8L))
```

### Daemon Configuration
```r
# Source: https://mirai.r-lib.org/reference/daemons.html
daemons(
  n = worker_count,      # Number of local daemons
  dispatcher = TRUE,     # Enable FIFO scheduling
  autoexit = tools::SIGINT  # Clean shutdown on interrupt
)
```

### Getting Daemon Status
```r
# Source: https://mirai.r-lib.org/reference/status.html
status <- mirai::status()
active_workers <- status$connections  # Integer count
```

### Docker Compose Environment
```yaml
# Source: docker-compose.yml line 158 (DB_POOL_SIZE pattern)
environment:
  MIRAI_WORKERS: ${MIRAI_WORKERS:-2}
```

### Health Endpoint Response Structure
```r
# Source: api/endpoints/health_endpoints.R (pool pattern)
list(
  status = "healthy",
  workers = list(
    configured = worker_count,
    active = mirai::status()$connections
  ),
  # ... other fields
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hard-coded `daemons(n=2)` | Configurable via env var | This phase | Deployment flexibility |

**Deprecated/outdated:**
- Nothing deprecated - this is a new configuration option

## Open Questions

Things that couldn't be fully resolved:

1. **Behavior when workers=1 vs workers=2 under load**
   - What we know: 1 worker means sequential job processing, 2+ allows parallel
   - What's unclear: Exact memory savings per worker reduction (depends on workload)
   - Recommendation: Document that 1 worker uses ~50% less RAM but jobs queue

2. **Status connections vs configured discrepancy timing**
   - What we know: status()$connections reflects actual connected workers
   - What's unclear: Brief startup window where connections < configured
   - Recommendation: Health endpoint shows both configured and actual; document startup delay

## Sources

### Primary (HIGH confidence)
- mirai package documentation - https://mirai.r-lib.org/reference/daemons.html
- mirai status() documentation - https://mirai.r-lib.org/reference/status.html
- Existing codebase pattern - api/start_sysndd_api.R (DB_POOL_SIZE at line 188)
- Existing codebase pattern - api/endpoints/health_endpoints.R (pool_stats pattern)
- Existing codebase pattern - docker-compose.yml (environment variable pattern)

### Secondary (MEDIUM confidence)
- mirai package CRAN page - https://cran.r-project.org/web/packages/mirai/

### Tertiary (LOW confidence)
- None - all findings verified with primary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using existing packages in renv.lock
- Architecture: HIGH - Following existing codebase patterns exactly
- Pitfalls: HIGH - Based on direct observation of existing code and official docs

**Research date:** 2026-02-03
**Valid until:** 2026-04-03 (90 days - stable domain, simple configuration)
