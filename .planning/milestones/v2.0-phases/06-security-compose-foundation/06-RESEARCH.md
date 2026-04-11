# Phase 6: Security and Compose Foundation - Research

**Researched:** 2026-01-21
**Domain:** Docker Compose infrastructure modernization, Traefik reverse proxy, network isolation
**Confidence:** HIGH

## Summary

Phase 6 establishes the foundation for modern Docker infrastructure by replacing the abandoned dockercloud/haproxy with Traefik v3.6, implementing proper network isolation, adding health checks, and modernizing the Docker Compose configuration. The existing `.plan/DOCKER-REVIEW-REPORT.md` provides excellent templates that align well with Phase 6 requirements.

Key findings:
1. **Traefik v3.6** is current stable release (v3.6.2 as of Jan 2026) with excellent Docker integration
2. **.dockerignore files already exist** in both `api/` and `app/` directories - require verification only
3. **Named volumes and networks** are straightforward migration from current bind mounts
4. **Health checks** need to be added - API lacks a `/health` endpoint currently
5. **MySQL 8.0.40** is valid but **8.0.44** is now available (Nov 2025)

**Primary recommendation:** Follow the DOCKER-REVIEW-REPORT.md templates with adjustments per CONTEXT.md decisions (no dashboard, HTTP only, memory limits only).

## Standard Stack

The established tools for this phase:

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Traefik | v3.6 | Reverse proxy, routing | Native Docker provider, auto-discovery, actively maintained |
| MySQL | 8.0.40+ | Database | Security patches, caching_sha2_password support |
| Docker Compose | Latest (no version field) | Orchestration | Standard container orchestration |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| curl | System | Health checks | API, Traefik health verification |
| wget | System | Health checks | Nginx/frontend health verification |
| mysqladmin | In MySQL image | Health checks | MySQL ping verification |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Traefik | HAProxy 2.9 | HAProxy has better raw performance but lacks auto-discovery |
| Traefik | Nginx Proxy Manager | NPM has GUI but less flexible for path-based routing |
| caching_sha2_password | mysql_native_password | mysql_native_password is deprecated, security risk |

## Architecture Patterns

### Recommended Network Topology
```
                    Internet
                        |
                   [Port 80]
                        |
                  +----------+
                  | Traefik  |---- proxy network
                  +----------+
                   /        \
            +---------+  +---------+
            |   App   |  |   API   |--+-- backend network
            +---------+  +---------+  |
                              |       |
                         +---------+  |
                         |  MySQL  |--+
                         +---------+
                              |
                      [NOT on proxy]
```

### Network Configuration Pattern
```yaml
networks:
  proxy:
    name: sysndd_proxy
    driver: bridge
  backend:
    name: sysndd_backend
    driver: bridge
    internal: true  # Critical: MySQL isolation
```

**Key insight:** The `internal: true` flag on backend network prevents any external access to MySQL, even if ports were accidentally exposed.

### Service-to-Network Mapping
| Service | proxy | backend | Reason |
|---------|-------|---------|--------|
| traefik | Yes | No | Only needs to route to web services |
| app | Yes | No | Receives traffic, no DB access |
| api | Yes | Yes | Receives traffic AND talks to MySQL |
| mysql | No | Yes | Must be isolated from proxy network |
| mysql-backup | No | Yes | Only needs MySQL access |

### Traefik Routing Pattern (Path-Based, Single Domain)
```yaml
# API routing: /api/* -> api:7777
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.api.rule=PathPrefix(`/api`)"
  - "traefik.http.routers.api.entrypoints=web"
  - "traefik.http.services.api.loadbalancer.server.port=7777"

# Frontend routing: /* -> app:80
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.app.rule=PathPrefix(`/`)"
  - "traefik.http.routers.app.entrypoints=web"
  - "traefik.http.services.app.loadbalancer.server.port=80"
  - "traefik.http.routers.app.priority=1"  # Lower priority than /api
```

**Router priority:** Traefik uses longest path match by default, but explicit priority ensures `/api` matches before `/`.

### Anti-Patterns to Avoid
- **Exposing MySQL port to host:** Remove `ports: - "7654:3306"` in production
- **Using `links:` directive:** Deprecated, use networks instead
- **Version field in compose:** `version: '3.8'` is obsolete, remove entirely
- **Read-write Docker socket:** Always use `:ro` for security

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Service discovery | DNS/config files | Traefik Docker provider | Auto-updates on container changes |
| Health checking | Custom scripts | Docker HEALTHCHECK + Compose healthcheck | Integrated with orchestration |
| Load balancing | iptables/nginx | Traefik with labels | Declarative, version-controlled |
| Network isolation | firewall rules | Docker networks | Container-native, portable |
| Certificate management | Manual certs | Traefik Let's Encrypt (future) | Auto-renewal, no maintenance |

**Key insight:** Traefik's Docker provider eliminates all manual routing configuration. Labels on services ARE the routing config.

## Common Pitfalls

### Pitfall 1: Docker Socket Security
**What goes wrong:** Container compromise leads to host compromise via Docker socket
**Why it happens:** Socket mounted read-write allows container to spawn privileged containers
**How to avoid:**
- Mount socket read-only: `/var/run/docker.sock:/var/run/docker.sock:ro`
- Add `security_opt: - no-new-privileges:true`
**Warning signs:** Traefik can still read container metadata but cannot modify containers

### Pitfall 2: Network Isolation Gaps
**What goes wrong:** MySQL accessible from unexpected services
**Why it happens:** Services placed on wrong networks, or using default network
**How to avoid:**
- Explicit network assignments per service
- Use `internal: true` on backend network
- Remove all port mappings for MySQL in production
**Warning signs:** `docker network inspect sysndd_backend` shows unexpected containers

### Pitfall 3: Health Check Start Period
**What goes wrong:** Services marked unhealthy during startup, restart loops
**Why it happens:** Health checks run before application fully initialized
**How to avoid:**
- Use `start_period: 60s` for all services
- MySQL especially needs long start_period for initialization
- Use `start_interval: 5s` for faster initial checks (Compose 2.20.2+)
**Warning signs:** Containers restart multiple times on fresh deployment

### Pitfall 4: Volume Migration Data Loss
**What goes wrong:** MySQL data lost when switching from bind mounts to named volumes
**Why it happens:** Named volumes start empty; bind mount data not migrated
**How to avoid:**
- Stop containers before migration
- Copy data: `cp -r ../data/mysql/* /var/lib/docker/volumes/sysndd_mysql_data/_data/`
- Or use driver_opts to point named volume at existing path
**Warning signs:** MySQL reports fresh installation, no existing databases

### Pitfall 5: Traefik Router Priority Conflicts
**What goes wrong:** Wrong service receives requests, 404 errors
**Why it happens:** PathPrefix(`/`) catches all requests before specific paths
**How to avoid:**
- Traefik auto-calculates priority by path length (longer = higher priority)
- Use explicit `priority=N` labels if needed
- Test with `curl -v http://localhost/api/...` to verify routing
**Warning signs:** API requests return HTML from frontend

### Pitfall 6: Missing Health Endpoint in API
**What goes wrong:** Health checks fail, container marked unhealthy
**Why it happens:** API doesn't expose a `/health` endpoint
**How to avoid:**
- Add simple health endpoint to API that checks DB connection
- Or use simpler curl check on existing endpoint
**Warning signs:** API container continuously restarts despite functioning

## Code Examples

### Traefik Service Configuration (No Dashboard, HTTP Only)
```yaml
# Per CONTEXT.md: dashboard disabled, HTTP only, minimal logging
traefik:
  image: traefik:v3.6
  container_name: sysndd_traefik
  restart: unless-stopped
  security_opt:
    - no-new-privileges:true
  command:
    # Disable dashboard entirely (security)
    - "--api.dashboard=false"
    # Enable Docker provider
    - "--providers.docker=true"
    - "--providers.docker.exposedbydefault=false"
    - "--providers.docker.network=sysndd_proxy"
    # HTTP only (no TLS in this phase)
    - "--entryPoints.web.address=:80"
    # Enable ping for health checks
    - "--ping=true"
    - "--ping.entryPoint=web"
    # Minimal logging: errors and warnings only
    - "--log.level=WARN"
  ports:
    - "80:80"
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro  # Read-only!
  networks:
    - proxy
  healthcheck:
    test: ["CMD", "traefik", "healthcheck", "--ping"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 60s
```
Source: [Traefik Ping Documentation](https://doc.traefik.io/traefik/reference/install-configuration/observability/healthcheck/ping/)

### MySQL Configuration (caching_sha2_password)
```yaml
mysql:
  image: mysql:8.0.40
  container_name: sysndd_mysql
  restart: unless-stopped
  command:
    # Modern authentication (mysql_native_password deprecated in 8.0)
    - --authentication-policy=caching_sha2_password
    - --character-set-server=utf8mb4
    - --collation-server=utf8mb4_unicode_ci
  environment:
    MYSQL_DATABASE: ${MYSQL_DATABASE}
    MYSQL_USER: ${MYSQL_USER}
    MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
  volumes:
    - mysql_data:/var/lib/mysql
    - mysql_backup:/backup
  networks:
    - backend  # Only backend, NOT proxy
  healthcheck:
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 60s
```
Source: [MySQL caching_sha2_password Documentation](https://dev.mysql.com/doc/refman/8.0/en/caching-sha2-pluggable-authentication.html)

### Health Check Pattern (60s Grace Period)
```yaml
# Pattern for all services per CONTEXT.md
healthcheck:
  test: ["CMD", "..."]
  interval: 30s       # Check every 30 seconds
  timeout: 10s        # Fail if no response in 10s
  retries: 3          # 3 consecutive failures = unhealthy
  start_period: 60s   # 60 second grace period on startup
```
Source: [Docker Compose Health Check Documentation](https://docs.docker.com/reference/compose-file/services/)

### Resource Limits (Memory Only)
```yaml
# Per CONTEXT.md: memory limits only, no CPU limits
# Target: 8GB VPS with other containers

# API: 4GB+ for peak memory operations
api:
  deploy:
    resources:
      limits:
        memory: 4608M  # 4.5GB to handle peaks

# MySQL: ~1GB
mysql:
  deploy:
    resources:
      limits:
        memory: 1024M

# Frontend: minimal
app:
  deploy:
    resources:
      limits:
        memory: 256M

# Traefik: minimal
traefik:
  deploy:
    resources:
      limits:
        memory: 256M

# Backup: minimal (runs periodically)
mysql-backup:
  deploy:
    resources:
      limits:
        memory: 256M
```
Source: [Docker Compose Deploy Specification](https://docs.docker.com/reference/compose-file/deploy/)

### Named Volume Definitions
```yaml
volumes:
  mysql_data:
    name: sysndd_mysql_data
  mysql_backup:
    name: sysndd_mysql_backup
```

### API Health Check Options
Since the API lacks a dedicated `/health` endpoint, use one of these approaches:

**Option 1: Check existing endpoint (fast, no code changes)**
```yaml
healthcheck:
  test: ["CMD", "curl", "-sf", "http://localhost:7777/api/status_list"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

**Option 2: Simple TCP check (fastest, no code changes)**
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -sf http://localhost:7777/ || exit 1"]
```

**Option 3: Add dedicated health endpoint (recommended for future)**
```r
# endpoints/health_endpoints.R
#* @get /
function() {
  list(status = "ok", timestamp = Sys.time())
}
```

### Frontend Health Check
```yaml
# Nginx responds to any path with 200 when serving SPA
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:80/"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `version: '3.8'` | No version field | Docker Compose v2+ | Remove field entirely |
| `links:` directive | `networks:` | Docker Compose v3+ | Use explicit networks |
| mysql_native_password | caching_sha2_password | MySQL 8.0.4 (2018) | Better security, faster auth |
| dockercloud/haproxy | Traefik v3.x | HAProxy archived Dec 2018 | Active maintenance, features |
| Bind mounts (`../data/`) | Named volumes | Best practice | Portability, backup, management |

**Deprecated/outdated:**
- `dockercloud/haproxy:1.6.7`: Repository archived December 13, 2018, no security patches since
- `mysql_native_password`: Deprecated in MySQL 8.0, will be removed in future version
- `version:` in compose file: Ignored by Docker Compose v2+, causes warnings

## Verification Checklist

Before marking Phase 6 complete, verify:

1. **`docker compose up` starts all services**
   ```bash
   docker compose up -d
   docker compose ps  # All services should be "healthy" or "running"
   ```

2. **Traefik handles routing correctly**
   ```bash
   curl http://localhost/           # Should return frontend HTML
   curl http://localhost/api/status_list  # Should return API JSON
   ```

3. **MySQL isolated from proxy network**
   ```bash
   docker network inspect sysndd_proxy  # MySQL should NOT be listed
   docker network inspect sysndd_backend  # MySQL should be listed
   ```

4. **Health checks pass within 60 seconds**
   ```bash
   watch docker compose ps  # Wait for "healthy" status
   ```

5. **No deprecated warnings**
   ```bash
   docker compose config 2>&1 | grep -i "warning\|deprecated"  # Should be empty
   ```

6. **Docker socket is read-only**
   ```bash
   docker compose config | grep "docker.sock"  # Should show :ro
   ```

## Open Questions

### Question 1: API Health Endpoint
- What we know: API lacks a dedicated `/health` endpoint
- What's unclear: Whether to add one in this phase or use existing endpoint
- Recommendation: Use existing `/api/status_list` endpoint for health checks now; adding dedicated `/health` can be a future enhancement

### Question 2: MySQL Version
- What we know: REQUIREMENTS.md specifies 8.0.40, but 8.0.44 is now available
- What's unclear: Whether to use exact version specified or latest patch
- Recommendation: Use `mysql:8.0.40` as specified; upgrading to 8.0.44 can be separate maintenance task

### Question 3: Existing Data Migration
- What we know: Current setup uses `../data/mysql/` bind mount
- What's unclear: Whether production has data to migrate
- Recommendation: Document migration steps in PLAN.md; actual migration depends on deployment environment

## Sources

### Primary (HIGH confidence)
- [Traefik v3.6 Docker Setup Documentation](https://doc.traefik.io/traefik/v3.6/setup/docker/) - Traefik configuration patterns
- [Traefik Ping Endpoint](https://doc.traefik.io/traefik/reference/install-configuration/observability/healthcheck/ping/) - Health check configuration
- [Docker Compose Services Reference](https://docs.docker.com/reference/compose-file/services/) - Health check syntax, networks
- [Docker Compose Deploy Specification](https://docs.docker.com/reference/compose-file/deploy/) - Resource limits
- [MySQL caching_sha2_password](https://dev.mysql.com/doc/refman/8.0/en/caching-sha2-pluggable-authentication.html) - Authentication plugin

### Secondary (MEDIUM confidence)
- [Docker Hub MySQL](https://hub.docker.com/_/mysql) - MySQL 8.0.44 is latest 8.0.x (Nov 2025)
- [Docker Volumes Documentation](https://docs.docker.com/engine/storage/volumes/) - Named volume patterns
- `.plan/DOCKER-REVIEW-REPORT.md` - Project-specific templates (verified against official docs)

### Tertiary (LOW confidence)
- WebSearch for best practices - Validated against official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Verified against official Traefik and Docker documentation
- Architecture: HIGH - Network topology from CONTEXT.md, patterns from official docs
- Pitfalls: HIGH - Based on official documentation and known issues
- Code examples: HIGH - Adapted from official documentation with project specifics

**Research date:** 2026-01-21
**Valid until:** 2026-02-21 (30 days - stable technologies)
