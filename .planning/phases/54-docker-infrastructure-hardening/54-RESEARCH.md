# Phase 54: Docker Infrastructure Hardening - Research

**Researched:** 2026-01-30
**Domain:** Docker security hardening, nginx optimization, container resource management
**Confidence:** HIGH

## Summary

This research investigates how to implement the Docker infrastructure hardening recommendations from the January 30, 2026 infrastructure review. The review identified 2 CRITICAL, 5 HIGH, and 7 MEDIUM priority issues affecting the SysNDD Docker infrastructure, with a current rating of 8.4/10 and target of 9.0+/10 after fixes.

The infrastructure already demonstrates mature practices (non-root users, multi-stage builds, network segmentation, health checks). The hardening phase focuses on: (1) pinning the nginx image version to eliminate supply chain risk, (2) implementing proper static asset caching for Vue.js bundles, (3) enabling access logging for audit trails, (4) adding security_opt no-new-privileges to all services, (5) implementing CPU resource limits, and (6) configuring Docker log rotation.

**Primary recommendation:** Address CRITICAL issues (nginx version pinning, static asset caching) first, then systematically implement HIGH priority security controls (logging, no-new-privileges, CPU limits, log rotation).

## Standard Stack

The established tools and configurations for Docker security hardening:

### Core
| Tool/Config | Purpose | Why Standard |
|-------------|---------|--------------|
| `security_opt: no-new-privileges:true` | Prevent privilege escalation | OWASP Docker Security Cheat Sheet recommendation |
| `deploy.resources.limits` | CPU/memory limits | Docker best practice for resource isolation |
| `logging.options: max-size/max-file` | Log rotation | Prevents disk exhaustion |
| nginx Cache-Control headers | Static asset caching | Performance optimization standard |
| Brotli compression | Smaller payloads | Modern compression, 15-20% better than gzip |

### Supporting
| Tool/Config | Purpose | When to Use |
|-------------|---------|-------------|
| Docker socket proxy | Reduce Docker socket exposure | Optional security enhancement |
| Trivy vulnerability scanning | Image security scanning | CI/CD pipeline addition |
| Docker secrets | Credential management | Alternative to environment variables |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| fholzer/nginx-brotli | Build own brotli image | More maintenance, but controlled updates |
| Environment variables | Docker secrets | More secure but added complexity |
| json-file logging | local logging driver | local driver has built-in rotation |

## Architecture Patterns

### Pattern 1: Security Options for All Services
**What:** Apply no-new-privileges to every service
**When to use:** All production Docker Compose deployments
**Rationale:** Prevents setuid/setgid binaries from gaining privileges after container start

```yaml
# Source: OWASP Docker Security Cheat Sheet
services:
  api:
    security_opt:
      - no-new-privileges:true
  app:
    security_opt:
      - no-new-privileges:true
  mysql:
    security_opt:
      - no-new-privileges:true
```

### Pattern 2: Resource Limits with Reservations
**What:** Set both limits and reservations for CPU/memory
**When to use:** Production deployments with multiple services
**Rationale:** Limits prevent noisy neighbor, reservations ensure minimum resources

```yaml
# Source: Docker Compose Deploy Specification
services:
  api:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4608M
        reservations:
          cpus: '0.5'
          memory: 1024M
```

### Pattern 3: Log Rotation Configuration
**What:** Configure json-file driver with rotation
**When to use:** All services generating logs
**Rationale:** Prevents disk exhaustion from unbounded log growth

```yaml
# Source: Docker JSON File Logging Driver docs
services:
  api:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        compress: "true"
```

### Pattern 4: Static Asset Caching with Immutable
**What:** Long cache lifetimes for hashed/versioned assets
**When to use:** SPA applications with webpack/Vite content-hashed bundles
**Rationale:** Vue.js/Vite generates files like `index-a1b2c3.js` that never change

```nginx
# Source: Nginx Browser Caching Guide
# For Vite-generated assets in /assets/ directory
location ~* ^/assets/.*\.(js|css|woff2?|ttf|svg)$ {
    root /usr/share/nginx/html;
    expires 1y;
    add_header Cache-Control "public, immutable, max-age=31536000" always;
    access_log off;
}

# For images with shorter cache
location ~* \.(jpg|jpeg|png|gif|ico|webp)$ {
    root /usr/share/nginx/html;
    expires 30d;
    add_header Cache-Control "public, max-age=2592000" always;
}

# HTML/index files - no cache (so app updates are picked up)
location / {
    root /usr/share/nginx/html;
    index index.html;
    try_files $uri $uri/ /index.html;
    add_header Cache-Control "no-cache, no-store, must-revalidate" always;
}
```

### Pattern 5: Brotli Compression Configuration
**What:** Enable Brotli alongside gzip for better compression
**When to use:** When using brotli-enabled nginx image
**Rationale:** Brotli offers 15-20% better compression than gzip

```nginx
# Source: NGINX Brotli Documentation
# Add after gzip configuration
brotli on;
brotli_comp_level 6;
brotli_types text/plain text/css text/xml text/javascript
             application/x-javascript application/javascript
             application/xml application/json application/xml+rss
             image/svg+xml font/eot font/otf font/ttf;
```

### Anti-Patterns to Avoid
- **Using `latest` tag for images:** Creates supply chain vulnerability, unpredictable builds
- **Exposing Docker socket directly:** Even read-only carries privilege escalation risk
- **Global no-cache headers:** Prevents browser caching of static assets
- **Omitting log rotation:** Leads to disk exhaustion
- **Running as root when unnecessary:** Increases attack surface

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Brotli compression | Custom nginx build | fholzer/nginx-brotli (pinned) | Pre-compiled, tested, maintained |
| Log rotation | Custom rotation scripts | Docker json-file driver options | Built-in, zero maintenance |
| Signal handling | Custom SIGTERM handlers | Use exit hooks in existing code | Already implemented in start_sysndd_api.R (cleanupHook) |
| Socket security | Custom firewall rules | Docker socket proxy | Purpose-built, well-tested |
| Image scanning | Manual security review | Trivy in CI/CD | Automated, comprehensive CVE database |

**Key insight:** The current infrastructure already has most components in place. Hardening is about configuration adjustments, not new tools.

## Common Pitfalls

### Pitfall 1: Incorrect Cache Header Placement in Nginx
**What goes wrong:** Cache headers in http block apply to ALL responses including HTML
**Why it happens:** nginx.conf currently has global `Cache-Control: no-cache` in http block
**How to avoid:** Move cache headers to location blocks, apply per-content-type
**Warning signs:** Browser network tab shows Cache-Control: no-cache on .js/.css files

### Pitfall 2: Log Rotation Only Applies to New Containers
**What goes wrong:** Existing containers keep old logging config after daemon.json update
**Why it happens:** Docker logging config is set at container creation
**How to avoid:** Recreate containers after changing logging configuration
**Warning signs:** Old containers still have unlimited logs despite config change

### Pitfall 3: CPU Limits May Cause Throttling
**What goes wrong:** R processes become slow/unresponsive under load
**Why it happens:** CPU limits throttle when exceeded, unlike memory which OOM kills
**How to avoid:** Set limits based on actual profiled usage, use reservations too
**Warning signs:** API response times increase under moderate load

### Pitfall 4: Brotli Module Not Loaded
**What goes wrong:** brotli directives cause nginx to fail to start
**Why it happens:** fholzer/nginx-brotli requires no module loading (pre-compiled)
**How to avoid:** Don't add load_module directives, brotli module is built-in
**Warning signs:** nginx startup error mentioning "unknown directive brotli"

### Pitfall 5: Version Tag Format Varies Between Images
**What goes wrong:** Using wrong tag format for image
**Why it happens:** Some images use `v1.27.4`, others use `1.27.4`
**How to avoid:** Verify exact tag exists on Docker Hub before using
**Warning signs:** Image pull fails with "manifest not found"

### Pitfall 6: MySQL Healthcheck Exposes Root Password
**What goes wrong:** Root password visible in process listing during healthcheck
**Why it happens:** Password passed as command-line argument
**How to avoid:** Use application user credentials or healthcheck.sh script (MariaDB)
**Warning signs:** `ps aux` shows MYSQL_ROOT_PASSWORD in healthcheck process

## Code Examples

Verified patterns for implementation:

### Complete docker-compose.yml Service Security Pattern
```yaml
# Source: OWASP Docker Security + Docker Compose docs
services:
  api:
    build: ./api/
    container_name: sysndd_api
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4608M
        reservations:
          cpus: '0.5'
          memory: 1024M
```

### Nginx Configuration with Proper Caching
```nginx
# app/docker/nginx/local.conf
server {
    listen 8080;
    listen [::]:8080;
    server_name localhost;

    # Vite-generated hashed assets - 1 year cache with immutable
    location ~* ^/assets/.*\.(js|css|woff2?|ttf|eot|svg)$ {
        root /usr/share/nginx/html;
        expires 1y;
        add_header Cache-Control "public, immutable, max-age=31536000" always;
        access_log off;
    }

    # Images - 30 day cache
    location ~* \.(jpg|jpeg|png|gif|ico|webp|avif)$ {
        root /usr/share/nginx/html;
        expires 30d;
        add_header Cache-Control "public, max-age=2592000" always;
    }

    # HTML and root - no cache for app updates
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
        # No Cache-Control header here - uses global headers from nginx.conf
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

### Nginx Main Config with Access Logging
```nginx
# app/docker/nginx/nginx.conf - key changes
http {
    # ... existing config ...

    # Enable access logging (was: access_log off;)
    access_log /var/log/nginx/access.log main buffer=32k flush=5s;

    # Enable tcp_nopush for efficiency (was: commented out)
    tcp_nopush on;

    # ... existing gzip config ...

    # Add Brotli compression (fholzer/nginx-brotli has module built-in)
    brotli on;
    brotli_comp_level 6;
    brotli_types text/plain text/css text/xml text/javascript
                 application/x-javascript application/javascript
                 application/json application/xml application/xml+rss
                 image/svg+xml font/eot font/otf font/ttf;

    include /etc/nginx/conf.d/*.conf;

    # Move security headers here (keep existing)
    # But REMOVE the global Cache-Control headers - those go in location blocks
}
```

### Pinned Dockerfile Image Reference
```dockerfile
# app/Dockerfile - Stage 2
# Pin to specific version instead of 'latest'
# Check Docker Hub for latest available tag: https://hub.docker.com/r/fholzer/nginx-brotli/tags
FROM fholzer/nginx-brotli:v1.27.4 AS production
```

### MySQL Healthcheck with Application User
```yaml
# docker-compose.yml
mysql:
  healthcheck:
    # Use application user instead of root
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "${MYSQL_USER}", "-p${MYSQL_PASSWORD}"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 60s
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Unlimited container resources | CPU + memory limits | Docker 1.13+ | Prevents noisy neighbor |
| Default logging | json-file with rotation | Always available | Prevents disk exhaustion |
| `latest` image tags | Pinned versions | Always best practice | Supply chain security |
| gzip only | gzip + Brotli | nginx-brotli 2020+ | 15-20% better compression |
| Direct Docker socket | Socket proxy | 2019+ Traefik docs | Reduced attack surface |
| Global cache headers | Per-content-type | Modern SPA patterns | Proper asset caching |

**Deprecated/outdated:**
- Docker Compose version 2.x syntax (no `version:` key needed in modern compose)
- `mem_limit` (replaced by `deploy.resources.limits.memory`)
- `cpu_shares` (replaced by `deploy.resources.limits.cpus`)

## Open Questions

Things that couldn't be fully resolved:

1. **Exact fholzer/nginx-brotli version tag**
   - What we know: v1.27.4 is mentioned in the review as recommended version
   - What's unclear: Whether this exact tag exists on Docker Hub (no formal releases page)
   - Recommendation: Verify tag exists before implementation; fallback to latest known good

2. **R Plumber graceful shutdown**
   - What we know: Current code has cleanupHook for exit; sigterm R package exists
   - What's unclear: Whether Docker SIGTERM is properly handled by current implementation
   - Recommendation: Test current behavior before adding complexity

3. **Socket proxy necessity**
   - What we know: Docker socket even read-only carries risk; proxy reduces exposure
   - What's unclear: Whether risk level justifies added complexity for this deployment
   - Recommendation: Defer to "Best Practices Improvements" phase (review suggests this)

4. **CSP nonce implementation**
   - What we know: Current CSP uses unsafe-inline/unsafe-eval for Vue.js compatibility
   - What's unclear: Vue.js 3 nonce support requirements
   - Recommendation: Defer to separate security hardening phase (long-term item per review)

## Sources

### Primary (HIGH confidence)
- [Docker Logging Drivers - JSON File](https://docs.docker.com/engine/logging/drivers/json-file/) - Log rotation configuration
- [Docker Compose Deploy Specification](https://docs.docker.com/reference/compose-file/deploy/) - Resource limits syntax
- [Docker Resource Constraints](https://docs.docker.com/engine/containers/resource_constraints/) - CPU/memory limits

### Secondary (MEDIUM confidence)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html) - Security best practices
- [fholzer/nginx-brotli Docker Hub](https://hub.docker.com/r/fholzer/nginx-brotli/) - Image information
- [GetPageSpeed Nginx Browser Caching Guide](https://www.getpagespeed.com/server-setup/nginx/nginx-browser-caching) - Cache header patterns
- [NGINX Brotli Documentation](https://docs.nginx.com/nginx/admin-guide/dynamic-modules/brotli/) - Brotli configuration

### Tertiary (LOW confidence)
- WebSearch results for version-specific information (version tags may change)

## Issue-to-Solution Mapping

Quick reference mapping review issues to implementation approach:

| Priority | Issue | Solution | Files Affected |
|----------|-------|----------|----------------|
| CRITICAL | Nginx uses `latest` tag | Pin to `v1.27.4` | `app/Dockerfile` |
| CRITICAL | Static asset cache headers missing | Add location blocks with proper Cache-Control | `app/docker/nginx/local.conf`, `app/docker/nginx/nginx.conf` |
| HIGH | Access logging disabled | Change `access_log off;` to enabled | `app/docker/nginx/nginx.conf` |
| HIGH | Missing no-new-privileges | Add security_opt to api/app services | `docker-compose.yml` |
| HIGH | No CPU resource limits | Add deploy.resources.limits.cpus | `docker-compose.yml` |
| HIGH | No Docker log rotation | Add logging configuration | `docker-compose.yml` |
| MEDIUM | Brotli not explicitly enabled | Add brotli directives | `app/docker/nginx/nginx.conf` |
| MEDIUM | Root password in healthcheck | Use application user | `docker-compose.yml`, `docker-compose.dev.yml` |
| MEDIUM | tcp_nopush disabled | Uncomment tcp_nopush | `app/docker/nginx/nginx.conf` |

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Docker documentation and OWASP are authoritative sources
- Architecture patterns: HIGH - Patterns from official Docker and nginx docs
- Pitfalls: MEDIUM - Based on common issues, but project-specific behavior may vary

**Research date:** 2026-01-30
**Valid until:** 2026-02-28 (30 days - configurations are stable)
