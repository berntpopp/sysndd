# Phase 8: Frontend Dockerfile Modernization - Research

**Researched:** 2026-01-22
**Domain:** Docker containerization, Node.js frontend builds, nginx Alpine security
**Confidence:** HIGH

## Summary

This research covers modernizing a Vue.js frontend Dockerfile with a focus on **Vue 2.7 compatibility constraints**. The current stack uses Vue 2.7.8 with Vue CLI 5.0.8 and webpack 5, which has **critical compatibility issues with Node.js 24** due to OpenSSL 3.0 changes and legacy tooling dependencies.

**CRITICAL FINDING:** Node.js 24 (and 22) use OpenSSL 3.0+ which disables legacy cryptographic algorithms (MD4, MD5) that webpack and Vue CLI tooling depend on for hashing. Vue 2 reached End-of-Life December 31, 2023 and receives no updates. The combination of EOL Vue 2 + EOL Node 16 creates a compatibility gap that cannot be cleanly bridged without either:
1. Using `NODE_OPTIONS=--openssl-legacy-provider` (security workaround, not recommended for production)
2. Upgrading to Vue 3 (significant effort: 14-20 weeks per FRONTEND-REVIEW-REPORT.md)
3. Using Node.js 20 LTS (maintenance LTS until April 2026, buys time for Vue 3 migration)

**Recommended approach for Phase 8:** Use **Node.js 20 LTS Alpine** (node:20-alpine) as a transitional solution that:
- Maintains compatibility with Vue 2.7 + Vue CLI 5 + webpack 5 toolchain
- Avoids security workarounds (`--openssl-legacy-provider`)
- Provides support until April 2026 (4 months runway for Vue 3 migration)
- Delivers all other modernization benefits (Alpine base, multi-stage build, non-root nginx, HEALTHCHECK)

The standard approach for production-ready Vue.js containers is a two-stage build: (1) node:20-alpine builder stage using npm ci with BuildKit cache mounts, and (2) nginx:alpine-slim production stage running as non-root user (UID 101) with proper health checks using wget.

**Primary recommendation:** Use node:20-alpine for builder stage (Vue 2 compatibility), nginxinc/nginx-unprivileged:alpine-slim for production stage (pre-configured for non-root), implement BuildKit cache mounts for npm, and add wget-based HEALTHCHECK with 5-second timeout. Plan Vue 3 migration before Node.js 20 EOL (April 2026).

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| node:20-alpine | 20.18.x | Build stage base image | **Maintenance LTS until April 2026**, compatible with Vue 2.7 + Vue CLI 5 + webpack 5, no OpenSSL workarounds needed |
| nginxinc/nginx-unprivileged:alpine-slim | 1.27.4+ | Production base image | Official non-root nginx (UID 101), pre-configured for port 8080, amd64/arm64 support |
| npm ci | 10.x (bundled) | Dependency installation | Faster, deterministic installs with lockfile validation, part of Node 20 |
| wget | busybox | Health check tool | Pre-installed in Alpine busybox, smaller than curl |

### Vue 2 Compatibility Constraints
| Constraint | Impact | Mitigation |
|------------|--------|------------|
| Vue 2.7.8 EOL (Dec 2023) | No security patches | Plan Vue 3 migration (Phase 10+) |
| Vue CLI 5.0.8 maintenance mode | No new features, limited Node.js support | Use Node.js 20 LTS for compatibility |
| webpack 5 MD4 hashing | ERR_OSSL_EVP_UNSUPPORTED on Node 22+ | Use Node.js 20 or upgrade webpack internals |
| vue-template-compiler EOL | Bundled with Vue 2, no longer maintained | Required until Vue 3 migration |
| bootstrap-vue 2.21.2 EOL | No Vue 3 path | Migrate to bootstrap-vue-next with Vue 3 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| nginx:alpine | 1.29.4-alpine | Alternative production base | When building custom non-root configuration (requires manual user setup) |
| libc6-compat | latest | glibc compatibility layer | Only if Vue.js dependencies fail with musl libc native module errors |
| dumb-init | latest | PID 1 init system | Advanced: for proper signal handling if running node directly (not needed for nginx) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| node:20-alpine | node:22-alpine + --openssl-legacy-provider | Node 22 is Active LTS but requires security workaround for Vue 2 compatibility, **not recommended** |
| node:20-alpine | node:24-alpine + --openssl-legacy-provider | Node 24 future-proof but requires security workaround, **not recommended** |
| nginxinc/nginx-unprivileged | nginx:alpine + manual config | Alpine saves ~5MB but requires manual non-root setup (addgroup/adduser, chown, port changes) |
| node:20-alpine | node:20-slim | Slim is ~200MB vs Alpine ~130MB, uses glibc (better native module compatibility), 70MB larger |
| npm ci | npm install | install doesn't validate lockfile, may cause version drift, slower |
| wget | curl | curl not in Alpine busybox, requires apk add curl (~6MB), wget included by default |

### Node.js Version Decision Matrix (Vue 2.7 Context)
| Node Version | Vue 2 Compatible | OpenSSL Workaround | Support Until | Recommendation |
|--------------|------------------|-------------------|---------------|----------------|
| 16.x | ✓ Yes | Not needed | **EOL Sept 2023** | Do not use (security risk) |
| 18.x | ✓ Yes | Not needed | **EOL April 2025** | Do not use (EOL imminent) |
| **20.x** | **✓ Yes** | **Not needed** | **April 2026** | **RECOMMENDED for Phase 8** |
| 22.x | ⚠ Requires workaround | --openssl-legacy-provider | April 2027 | Not recommended (workaround) |
| 24.x | ⚠ Requires workaround | --openssl-legacy-provider | April 2028 | Not recommended (workaround) |

**Installation:**
```bash
# Builder stage - no additional packages needed
FROM node:24-alpine3.23 AS builder

# Production stage - use pre-configured image
FROM nginxinc/nginx-unprivileged:1.29.3-alpine-slim

# If using nginx:alpine instead (manual non-root setup required):
# FROM nginx:alpine
# RUN addgroup -g 1001 -S appuser && adduser -u 1001 -S appuser -G appuser
```

## Architecture Patterns

### Recommended Project Structure
```
app/
├── Dockerfile              # Multi-stage: builder + production
├── .dockerignore          # Exclude node_modules, .git, tests, docs
├── docker/
│   └── nginx/
│       ├── local.conf     # Development nginx config (port 80)
│       ├── prod.conf      # Production nginx config (if needed)
│       └── nginx.conf     # Main nginx config with security headers
├── package.json
├── package-lock.json      # Critical: locked dependencies for npm ci
└── src/                   # Vue.js source files
```

### Pattern 1: Multi-Stage Alpine Build for Vue.js + Nginx
**What:** Separate builder stage (Node.js) from production runtime (nginx), minimizing final image size
**When to use:** All production frontend deployments with build steps
**Example:**
```dockerfile
# Source: Docker Official Docs + Vue.js containerization guides
# https://docs.docker.com/guides/vuejs/containerize/
# https://labs.iximiuz.com/tutorials/docker-multi-stage-builds
# NOTE: Node.js 20 for Vue 2.7 compatibility; upgrade to 24 after Vue 3 migration

# Stage 1: Build Vue.js application
FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependency manifests first (cache optimization)
COPY package*.json ./

# Install dependencies with cache mount for faster rebuilds
RUN --mount=type=cache,target=/root/.npm \
    npm ci --no-audit --no-fund

# Copy source code
COPY . .

# Build production bundle
ARG VUE_MODE=docker
RUN npm run build -- --mode ${VUE_MODE}

# Stage 2: Production nginx server
FROM nginxinc/nginx-unprivileged:1.27.4-alpine

# Copy built assets from builder
COPY --chown=nginx:nginx --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY --chown=nginx:nginx docker/nginx/local.conf /etc/nginx/conf.d/default.conf
COPY --chown=nginx:nginx docker/nginx/nginx.conf /etc/nginx/nginx.conf

# Health check using wget (included in Alpine busybox)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --spider --tries=1 --no-verbose http://localhost:8080/ || exit 1

EXPOSE 8080

# nginxinc/nginx-unprivileged uses non-root user by default
# No ENTRYPOINT needed - inherited from base image
```

### Pattern 2: BuildKit Cache Mounts for npm
**What:** Persist npm cache across builds using BuildKit's --mount=type=cache
**When to use:** All Node.js builds, especially in CI/CD pipelines
**Example:**
```dockerfile
# Source: Docker Build Cache Optimization Docs
# https://depot.dev/blog/how-to-use-cache-mount-to-speed-up-docker-builds
# https://docs.docker.com/build/cache/optimize/

RUN --mount=type=cache,target=/root/.npm \
    npm ci --no-audit --no-fund

# Benefits:
# - Cache persists across builds (even if layer invalidated)
# - Only downloads new/changed packages
# - Shared between multiple builds on same host
# - Critical for CI/CD performance
```

### Pattern 3: Non-Root Nginx Configuration
**What:** Run nginx as unprivileged user (UID 1001 or 101) on port 8080
**When to use:** All production containers (security requirement SEC-06)
**Example:**
```dockerfile
# Source: nginxinc/nginx-unprivileged official documentation
# https://github.com/nginx/docker-nginx-unprivileged

# Option A: Use pre-configured image (RECOMMENDED)
FROM nginxinc/nginx-unprivileged:alpine-slim
# Runs as user nginx (UID 101), listens on 8080
# PID file at /tmp/nginx.pid (not /var/run/nginx.pid)

# Option B: Manual configuration with nginx:alpine
FROM nginx:alpine
RUN addgroup -g 1001 -S appuser && \
    adduser -u 1001 -S appuser -G appuser && \
    chown -R appuser:appuser /var/cache/nginx && \
    chown -R appuser:appuser /var/log/nginx && \
    chown -R appuser:appuser /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appuser /var/run/nginx.pid

USER appuser
# Update nginx.conf: remove "user nginx;" directive, change port to 8080
```

### Pattern 4: Health Check with wget
**What:** Container self-monitoring using HTTP endpoint checks
**When to use:** All production containers (requirement FRONT-03)
**Example:**
```dockerfile
# Source: Docker HEALTHCHECK best practices
# https://lumigo.io/container-monitoring/docker-health-check-a-practical-guide/

# For nginxinc/nginx-unprivileged (port 8080)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --spider --tries=1 --no-verbose http://localhost:8080/ || exit 1

# For custom nginx (port 80)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --spider --tries=1 --no-verbose http://localhost/ || exit 1

# Alternatives if wget unavailable (should not happen with Alpine):
# CMD wget --quiet --tries=1 --spider http://localhost:8080/ || exit 1
# CMD nc -z localhost 8080 || exit 1  # Using netcat (also in busybox)
```

### Anti-Patterns to Avoid
- **Running nginx as root:** Violates security requirement SEC-06, enables privilege escalation attacks
- **Using node:latest or nginx:latest:** No version pinning, breaks reproducibility, can introduce breaking changes
- **Copying node_modules:** Invalidates cache optimization, bloats context, mix of host/container dependencies
- **Using npm install instead of npm ci:** Non-deterministic installs, ignores lockfile, slower
- **Not using .dockerignore:** Copies unnecessary files (tests, docs, .git), slows builds, larger context
- **Including curl for healthchecks:** Alpine busybox includes wget by default, curl adds ~6MB
- **Omitting --chown in COPY:** Files owned by root in non-root container, permission denied errors
- **Using ports < 1024 for non-root:** Privileged ports require root, will fail to bind

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Non-root nginx setup | Manual user creation, permission fixing, port changes | nginxinc/nginx-unprivileged:alpine-slim | Pre-configured for UID 101, port 8080, temp paths, weekly builds, multi-arch support |
| Health check implementation | Custom scripts, external monitoring | Docker HEALTHCHECK instruction | Native Docker feature, orchestrator integration, automatic restart on failure |
| npm cache optimization | Custom cache directories, volume mounts | BuildKit cache mounts (--mount=type=cache) | Persists across builds, shared between containers, works in CI/CD |
| Container init system | Custom signal handlers | dumb-init or tini | Handles zombie processes, forwards signals properly, battle-tested |
| CSP nonce generation | Custom middleware, build-time values | nginx set-misc-nginx-module with $request_id | Cryptographically random per-request, no additional dependencies |
| Static file compression | Runtime compression | nginx gzip + brotli modules | Pre-compression at build time, serves .gz/.br files directly, better performance |

**Key insight:** Alpine and nginx ecosystems have mature, well-tested solutions for common containerization patterns. The nginxinc/nginx-unprivileged image alone solves 5+ manual configuration steps and is maintained by the nginx team. BuildKit cache mounts are 10x more efficient than manual cache management. Always prefer official solutions over custom implementations.

## Critical: Vue 2 + Node.js 22/24 Compatibility

### The Problem

Vue 2.7 with Vue CLI 5 and webpack 5 uses cryptographic hashing (MD4) that was disabled in OpenSSL 3.0 (Node.js 17+). This causes `ERR_OSSL_EVP_UNSUPPORTED` errors during build.

**Error message:**
```
Error: error:0308010C:digital envelope routines::unsupported
    at new Hash (node:internal/crypto/hash:79:19)
```

### Root Cause

1. **webpack internal hashing:** webpack uses MD4 for module hashing by default
2. **OpenSSL 3.0 security changes:** Node.js 17+ uses OpenSSL 3.0 which disables legacy algorithms
3. **Vue CLI 5 in maintenance mode:** No updates to address this; recommendation is to use Vite

### Why Node.js 24 Won't Work Without Workarounds

| Component | Status | Issue |
|-----------|--------|-------|
| Vue 2.7.8 | EOL Dec 2023 | No updates for OpenSSL 3.0 compatibility |
| Vue CLI 5.0.8 | Maintenance mode | Webpack 5 internally uses deprecated crypto |
| vue-template-compiler 2.7.8 | EOL | Required by Vue 2, no updates |
| bootstrap-vue 2.21.2 | EOL | No Vue 3 support |
| webpack 5 (via Vue CLI) | Active but Vue CLI pins older version | Would need manual upgrade outside Vue CLI |

### Available Solutions

1. **Use Node.js 20 LTS (RECOMMENDED for Phase 8)**
   - Compatible with Vue 2.7 + Vue CLI 5
   - No workarounds needed
   - Supported until April 2026
   - Provides 4-month runway for Vue 3 migration

2. **Use `--openssl-legacy-provider` (NOT RECOMMENDED)**
   ```dockerfile
   ENV NODE_OPTIONS=--openssl-legacy-provider
   ```
   - Re-enables deprecated cryptographic algorithms
   - Security concern: allows insecure algorithms
   - Workaround, not a solution
   - May break in future Node.js versions

3. **Migrate to Vue 3 + Vite (FUTURE - Phase 10+)**
   - Estimated effort: 14-20 weeks (per FRONTEND-REVIEW-REPORT.md)
   - Eliminates dependency on Vue CLI and webpack
   - Vite uses modern tooling compatible with Node.js 22/24
   - Long-term solution

### Recommendation for Phase 8

Use **Node.js 20 LTS Alpine** as a transitional solution:

```dockerfile
# Phase 8: Use Node.js 20 for Vue 2 compatibility
FROM node:20-alpine AS builder

# After Vue 3 migration (Phase 10+): Upgrade to Node.js 24
# FROM node:24-alpine AS builder
```

This approach:
- ✓ Delivers all modernization benefits (Alpine, multi-stage, non-root, HEALTHCHECK)
- ✓ Avoids security workarounds
- ✓ Maintains build compatibility with existing codebase
- ✓ Creates clear upgrade path to Node.js 24 after Vue 3 migration

### Sources

- [Vue.js LTS Policy](https://v2.vuejs.org/lts/) - Vue 2 EOL December 2023
- [Vue CLI GitHub Issue #6770](https://github.com/vuejs/vue-cli/issues/6770) - ERR_OSSL_EVP_UNSUPPORTED with Node 17+
- [webpack Issue #14560](https://github.com/webpack/webpack/issues/14560) - webpack MD4 deprecation
- [Node.js endoflife.date](https://endoflife.date/nodejs) - Node.js 20 LTS until April 2026
- [How to Fix ERR_OSSL_EVP_UNSUPPORTED](https://builtin.com/software-engineering-perspectives/err-ossl-evp-unsupported) - Solution comparison

---

## Common Pitfalls

### Pitfall 1: Alpine musl libc Incompatibility with Native Modules
**What goes wrong:** Vue.js dependencies with native C bindings (bcrypt, node-sass, sharp, canvas) fail with "symbol not found" or segmentation faults
**Why it happens:** Alpine uses musl libc instead of glibc; some native modules hardcode glibc assumptions
**How to avoid:**
- Use node:24-alpine initially and test the build
- If native module errors occur: `RUN apk add --no-cache libc6-compat`
- Last resort: switch to node:24-slim (glibc-based, +64MB)
**Warning signs:** Build fails with "Error: Cannot find module" or "Segmentation fault" for native dependencies

### Pitfall 2: Non-Root User Permission Denied on Volume Mounts
**What goes wrong:** Nginx container fails to start with "permission denied" for /var/cache/nginx or mounted volumes
**Why it happens:** Host directories created by Docker have root ownership (UID 0), container runs as UID 101/1001
**How to avoid:**
- Use nginxinc/nginx-unprivileged (pre-configured temp paths in /tmp)
- For bind mounts: pre-create directories on host with correct ownership
- In Dockerfile: `COPY --chown=nginx:nginx` for all files
- For manual setup: ensure all nginx directories owned by non-root user
**Warning signs:** Container exits immediately, logs show "mkdir() failed (13: Permission denied)"

### Pitfall 3: Missing wget in Minimal Images
**What goes wrong:** HEALTHCHECK fails with "wget: not found" or "curl: command not found"
**Why it happens:** Assumed tool availability; minimal images exclude utilities
**How to avoid:**
- Alpine busybox includes wget by default (verify in base image)
- For distroless/scratch: use runtime-native health checks (e.g., node http module)
- Test health check: `docker run --rm <image> wget --spider http://localhost/`
**Warning signs:** Container marked unhealthy immediately, exec wget returns 127 (command not found)

### Pitfall 4: Port Binding Failures with Non-Root User
**What goes wrong:** Nginx fails to start with "bind() to 0.0.0.0:80 failed (13: Permission denied)"
**Why it happens:** Ports < 1024 are privileged, require root permission
**How to avoid:**
- Use port 8080 in nginx config (non-privileged port)
- Update local.conf: `listen 8080;` instead of `listen 80;`
- Use nginxinc/nginx-unprivileged (defaults to 8080)
- Update docker-compose.yml port mapping: "80:8080" (host:container)
**Warning signs:** Container exits immediately after start, nginx error log shows bind() failed

### Pitfall 5: Nginx PID File Permission Denied
**What goes wrong:** Nginx fails to start: "failed to write PID file /var/run/nginx.pid (13: Permission denied)"
**Why it happens:** /var/run owned by root, non-root user cannot write
**How to avoid:**
- Use nginxinc/nginx-unprivileged (uses /tmp/nginx.pid)
- For manual setup: add `pid /tmp/nginx.pid;` to nginx.conf
- Ensure no "user nginx;" directive in nginx.conf (incompatible with non-root)
**Warning signs:** Container exits immediately, error appears before "start worker processes"

### Pitfall 6: BuildKit Cache Not Working
**What goes wrong:** npm packages re-download on every build despite cache mount syntax
**Why it happens:** BuildKit not enabled, wrong cache target path, CI/CD without cache persistence
**How to avoid:**
- Enable BuildKit: `export DOCKER_BUILDKIT=1` or add to daemon.json
- Verify cache mount syntax: `--mount=type=cache,target=/root/.npm`
- For CI/CD: use external cache (`--cache-from`, `--cache-to`)
- Check npm cache location: `npm config get cache` (should match mount target)
**Warning signs:** Build logs show "Downloading ..." for unchanged dependencies, no "importing cache manifest" in verbose logs

### Pitfall 7: nginx.conf User Directive Conflict
**What goes wrong:** Nginx fails to start: "user directive is not supported, run as UID"
**Why it happens:** nginxinc/nginx-unprivileged or non-root configuration doesn't support "user nginx;" directive
**How to avoid:**
- Remove `user nginx;` from nginx.conf when running non-root
- Use nginxinc/nginx-unprivileged (handles this automatically)
- Verify nginx.conf doesn't override user in included configs
**Warning signs:** Container exits with "unsupported directive" error immediately on start

### Pitfall 8: Node.js 16 to 24 Breaking Changes
**What goes wrong:** Build succeeds but runtime errors: OpenSSL errors, webpack failures, DNS resolution issues
**Why it happens:** Node 24 includes OpenSSL 3.5 (security level 2), changes in crypto APIs, IPv6-first DNS
**How to avoid:**
- Test build locally with node:24-alpine before deploying
- Update package-lock.json: `npm install --package-lock-only`
- Check for deprecated crypto usage (shorter RSA/DSA keys < 2048 bits)
- Review Node.js migration guide: https://nodejs.org/en/blog/migrations/v22-to-v24
**Warning signs:** "error:0308010C:digital envelope routines::unsupported", "ERR_OSSL_EVP_UNSUPPORTED"

### Pitfall 9: Incorrect HEALTHCHECK Timing for Vue.js SPA
**What goes wrong:** Container marked unhealthy immediately after start, even though app works
**Why it happens:** Nginx starts before Vue.js assets fully serve, overly aggressive timeout/interval
**How to avoid:**
- Set appropriate start-period: `--start-period=10s` (grace period for startup)
- Reasonable timeout: `--timeout=5s` (per check, requirement: < 5s response)
- Test manually: `docker exec <container> wget --spider http://localhost:8080/`
**Warning signs:** Health check fails only on first 1-2 attempts, then succeeds

### Pitfall 10: Copying Unnecessary Files (No .dockerignore)
**What goes wrong:** Build takes minutes on file copy, image size bloated, slow CI/CD
**Why it happens:** No .dockerignore file, Docker copies node_modules, .git, tests, documentation
**How to avoid:**
- Create comprehensive .dockerignore (already exists in app/.dockerignore)
- Exclude: node_modules, dist, .git, tests, coverage, *.md, IDE configs
- Verify context size: `docker build --no-cache --progress=plain .` (check "COPY" step timing)
**Warning signs:** COPY steps take > 30 seconds, "Sending build context" shows > 100MB

## Code Examples

Verified patterns from official sources:

### Complete Multi-Stage Dockerfile (Vue 2.7 Compatible)
```dockerfile
# Source: Docker Official Docs, Vue.js containerization best practices
# https://docs.docker.com/guides/vuejs/containerize/
# IMPORTANT: Uses Node.js 20 for Vue 2.7 compatibility (see Vue 2 + Node.js section)

# Build arguments
ARG NODE_VERSION=20
ARG NGINX_VERSION=1.27.4
ARG VUE_MODE=docker

# Stage 1: Build Vue.js application
# NOTE: Node.js 20 LTS required for Vue 2.7 + Vue CLI 5 + webpack 5 compatibility
# Upgrade to node:24-alpine after Vue 3 migration (Phase 10+)
FROM node:${NODE_VERSION}-alpine AS builder

# Set working directory
WORKDIR /app

# Copy dependency manifests (cache optimization layer)
COPY package*.json ./

# Install dependencies with BuildKit cache mount
RUN --mount=type=cache,target=/root/.npm \
    npm ci --no-audit --no-fund

# Copy application source
COPY . .

# Build production bundle
RUN npm run build -- --mode ${VUE_MODE}

# Stage 2: Production nginx server
FROM nginxinc/nginx-unprivileged:${NGINX_VERSION}-alpine

# Copy nginx configuration
COPY --chown=nginx:nginx docker/nginx/local.conf /etc/nginx/conf.d/default.conf
COPY --chown=nginx:nginx docker/nginx/nginx.conf /etc/nginx/nginx.conf

# Copy built assets from builder stage
COPY --chown=nginx:nginx --from=builder /app/dist /usr/share/nginx/html

# Health check (wget included in Alpine busybox)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --spider --tries=1 --no-verbose http://localhost:8080/ || exit 1

# Expose non-privileged port
EXPOSE 8080

# Container runs as nginx user (UID 101) - inherited from base image
# ENTRYPOINT inherited from nginxinc/nginx-unprivileged
```

### nginx.conf for Non-Root Configuration
```nginx
# Source: nginxinc/nginx-unprivileged best practices
# https://github.com/nginx/docker-nginx-unprivileged/blob/main/mainline/alpine/Dockerfile

# IMPORTANT: Remove 'user nginx;' directive - not supported in non-root mode
# user nginx;  # <-- REMOVE THIS LINE

worker_processes auto;

error_log /var/log/nginx/error.log notice;
pid /tmp/nginx.pid;  # Changed from /var/run/nginx.pid for non-root

events {
    worker_connections 2048;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Temp paths for non-root (nginxinc/nginx-unprivileged handles this automatically)
    # If using manual non-root setup, uncomment:
    # client_body_temp_path /tmp/client_temp;
    # proxy_temp_path       /tmp/proxy_temp_path;
    # fastcgi_temp_path     /tmp/fastcgi_temp;
    # uwsgi_temp_path       /tmp/uwsgi_temp;
    # scgi_temp_path        /tmp/scgi_temp;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log off;

    sendfile on;
    keepalive_timeout 65;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Include server configs
    include /etc/nginx/conf.d/*.conf;
}
```

### nginx server config for non-root (local.conf)
```nginx
# Source: Vue.js Docker deployment best practices
# https://typeofnan.dev/how-to-serve-a-vue-app-with-nginx-in-docker/

server {
    listen 8080;  # Non-privileged port for non-root user
    listen [::]:8080;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;  # SPA fallback routing
    }

    # Optional: health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

### .dockerignore Optimization
```
# Source: Docker Node.js best practices
# https://snyk.io/blog/10-best-practices-to-containerize-nodejs-web-applications-with-docker/

# Dependencies (rebuilt in container)
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Build output (rebuilt in container)
dist/
build/

# Git
.git
.gitignore
.gitattributes

# Tests
tests/
__tests__/
*.spec.js
*.test.js
coverage/
.nyc_output/

# Development files
.env.local
.env.*.local
.vscode/
.idea/
*.swp
*.swo

# Documentation
*.md
README*
CHANGELOG*
docs/

# CI/CD
.github/
.gitlab-ci.yml
.travis.yml

# OS files
.DS_Store
Thumbs.db

# Docker files
Dockerfile*
docker-compose*.yml
.dockerignore
```

### BuildKit Cache Mount with npm ci
```dockerfile
# Source: Docker BuildKit cache optimization
# https://depot.dev/docs/container-builds/optimal-dockerfiles/node-npm-dockerfile

# Copy package files
COPY package.json package-lock.json ./

# Install with cache mount (requires Docker BuildKit)
RUN --mount=type=cache,target=/root/.npm \
    npm ci --no-audit --no-fund

# Explanation:
# --mount=type=cache,target=/root/.npm
#   - Persists /root/.npm across builds
#   - Only downloads changed packages
#   - Shared between multiple builds
#
# npm ci
#   - Requires package-lock.json
#   - Removes node_modules before install
#   - Faster and more reliable than 'npm install'
#   - Validates lockfile matches package.json
#
# --no-audit --no-fund
#   - Skips audit report (save ~2-3 seconds)
#   - Skips funding messages (cleaner output)
```

### Docker Compose Configuration for Non-Root Nginx
```yaml
# Source: nginxinc/nginx-unprivileged deployment patterns
# https://hub.docker.com/r/nginxinc/nginx-unprivileged

version: '3.8'

services:
  app:
    build:
      context: ./app
      dockerfile: Dockerfile
    ports:
      - "80:8080"  # Host:Container - map host 80 to container 8080
    networks:
      - frontend
    environment:
      - VUE_MODE=docker
    healthcheck:
      test: ["CMD", "wget", "--spider", "--tries=1", "--no-verbose", "http://localhost:8080/"]
      interval: 30s
      timeout: 5s
      start_period: 10s
      retries: 3
    restart: unless-stopped
    # Security: non-root user (inherited from image)
    # user: "101:101"  # Optional: explicit UID/GID for nginxinc/nginx-unprivileged

networks:
  frontend:
    driver: bridge
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| node:16-bullseye (650MB) | node:20-alpine (~130MB) for Vue 2, node:24-alpine for Vue 3 | Node 20 LTS Oct 2023, Node 24 LTS Oct 2025 | 80% size reduction, Vue 2 requires Node 20 for compatibility |
| nginx:latest (Debian 140MB) | nginxinc/nginx-unprivileged:alpine (~23MB) | Security focus 2024-2026 | 84% size reduction, non-root by default, weekly security updates |
| npm install | npm ci with cache mounts | npm v7+ / BuildKit 2021 | 10-50x faster rebuilds, deterministic installs, CI/CD optimization |
| Manual non-root setup | nginxinc/nginx-unprivileged | Official image 2022+ | Eliminates 8+ Dockerfile lines, pre-configured temp paths, multi-arch |
| curl for health checks | wget (Alpine busybox) | Alpine adoption 2020+ | No additional package install, 6MB savings, included by default |
| user nginx; in nginx.conf | Remove user directive | Non-root requirement | Required for unprivileged containers, incompatible with user directive |
| Static vulnerability scanning | Weekly rebuilt images | Container security 2024+ | nginxinc/nginx-unprivileged rebuilt weekly, automatic security patches |

**Vue 2 Specific Constraints (2026):**
- **node:22.x/24.x with Vue 2**: Requires `--openssl-legacy-provider` workaround due to webpack MD4 hashing
- **Vue CLI 5**: In maintenance mode, recommends Vite for new projects
- **bootstrap-vue**: No Vue 3 support, requires migration to bootstrap-vue-next

**Deprecated/outdated:**
- **node:16.x**: End-of-Life September 2023, no security patches, do not use
- **node:18.x**: End-of-Life April 2025, do not use for new deployments
- **npm install in Dockerfiles**: Non-deterministic, slower, ignores lockfile validation - always use npm ci
- **Running containers as root**: Security anti-pattern, violates least-privilege principle, SEC-06 requirement
- **Ports < 1024 for apps**: Requires root, use 8080+ for non-root containers
- **curl in Alpine**: Not included in busybox, adds 6MB, use wget instead

## Open Questions

Things that couldn't be fully resolved:

1. **Vue 3 Migration Timeline and Node.js 24 Upgrade Path**
   - What we know: Node.js 20 LTS ends April 2026; Vue 3 migration estimated at 14-20 weeks
   - What's unclear: Exact Vue 3 migration start date and whether it will complete before Node 20 EOL
   - Recommendation: Track as Phase 10+ in roadmap; consider starting Vue 3 planning in parallel
   - **Risk:** If Vue 3 migration delayed beyond April 2026, will need to use --openssl-legacy-provider

2. **Vue.js Native Dependency Compatibility with Alpine musl**
   - What we know: Vue.js 2.7 with standard dependencies (bootstrap-vue, d3, gsap) unlikely to have musl issues
   - What's unclear: Some dependencies like html2canvas may have native bindings; won't know until build test
   - Recommendation: Try node:20-alpine first; if build fails with native module errors, add libc6-compat or switch to node:20-slim

3. **nginx Brotli Module Compatibility with Non-Root**
   - What we know: Current Dockerfile compiles brotli module from source in custom builder stage
   - What's unclear: Whether compiled brotli modules compatible with nginxinc/nginx-unprivileged base image
   - Recommendation: Phase 8 focuses on Dockerfile modernization; brotli optimization can remain in separate builder stage or be deferred to later phase if incompatible

4. **CSP Nonce Implementation with Non-Root nginx**
   - What we know: Current nginx.conf includes CSP headers with 'unsafe-inline'; nonce generation requires set-misc-nginx-module
   - What's unclear: Whether nginxinc/nginx-unprivileged includes set-misc module or if custom compilation still needed
   - Recommendation: Keep existing CSP configuration for Phase 8; nonce-based CSP can be separate security enhancement phase

5. **Docker Compose Port Mapping Strategy**
   - What we know: Non-root nginx listens on 8080; docker-compose needs to map host port to 8080
   - What's unclear: Whether to expose host port 80 (requires "80:8080" mapping) or use 8080 on both (Traefik can handle)
   - Recommendation: Use "80:8080" mapping for local development; Traefik routes to container port 8080 in production (Phase 6 labels already configured)

6. **BuildKit Cache Mount Persistence in CI/CD**
   - What we know: Cache mounts work locally and with Docker cache backends
   - What's unclear: Exact CI/CD pipeline setup (GitHub Actions, GitLab CI, etc.) and cache configuration
   - Recommendation: Enable BuildKit locally first; CI/CD cache optimization can be separate task depending on platform

## Sources

### Primary (HIGH confidence)
- [Node.js Release Schedule (GitHub)](https://github.com/nodejs/Release) - Official EOL dates, Node.js 20 LTS until April 2026
- [Node.js endoflife.date](https://endoflife.date/nodejs) - Complete Node.js version support timeline
- [Vue.js LTS Policy](https://v2.vuejs.org/lts/) - Vue 2 EOL December 2023
- [Vue CLI GitHub Issue #6770](https://github.com/vuejs/vue-cli/issues/6770) - ERR_OSSL_EVP_UNSUPPORTED with Node 17+
- [webpack Issue #14560](https://github.com/webpack/webpack/issues/14560) - webpack MD4 deprecation discussion
- [nginxinc/nginx-unprivileged (Docker Hub)](https://hub.docker.com/r/nginxinc/nginx-unprivileged) - Official non-root nginx image
- [nginxinc/nginx-unprivileged (GitHub)](https://github.com/nginx/docker-nginx-unprivileged) - Source code and documentation
- [Docker BuildKit Cache Optimization (Docker Docs)](https://docs.docker.com/build/cache/optimize/) - Official cache mount documentation
- [Docker Multi-Stage Builds (Docker Labs)](https://labs.iximiuz.com/tutorials/docker-multi-stage-builds) - Multi-stage patterns
- [Docker Compose Health Checks (Docker Docs)](https://docs.docker.com/reference/compose-file/services/) - HEALTHCHECK syntax

### Secondary (MEDIUM confidence)
- [Node.js Docker Alpine Best Practices (Medium Jan 2026)](https://medium.com/@regansomi/4-easy-docker-best-practices-for-node-js-build-faster-smaller-and-more-secure-containers-151474129ac0) - Recent best practices
- [Vue.js Containerization (Medium 2024)](https://medium.com/@prasunamudawari/deploying-a-vue-js-application-with-docker-and-nginx-387fef1a27f2) - Vue.js + nginx patterns
- [Docker HEALTHCHECK Guide (Lumigo)](https://lumigo.io/container-monitoring/docker-health-check-a-practical-guide/) - Health check best practices
- [npm ci with Cache Mounts (Depot)](https://depot.dev/docs/container-builds/optimal-dockerfiles/node-npm-dockerfile) - npm optimization
- [Alpine musl libc Compatibility (Medium)](https://medium.com/@lucaslauriano.souza/why-you-should-use-run-apk-add-no-cache-libc6-compat-docker-with-node-js-6028a12d0ac5) - libc6-compat usage
- [Non-Root Docker Best Practices (DevOpsCube)](https://devopscube.com/run-docker-containers-as-non-root-user/) - Non-root configuration
- [nginx Non-Root Configuration (rockyourcode)](https://www.rockyourcode.com/run-docker-nginx-as-non-root-user/) - Manual setup guide

### Tertiary (LOW confidence - WebSearch verification needed)
- [Docker Multi-Stage Builds Guide (SmartTechWays Jan 2026)](https://smarttechways.com/2026/01/16/multi-stage-builds-in-docker-a-complete-guide/) - General patterns
- [Node.js Alpine Common Mistakes (DEV Community)](https://dev.to/arunangshu_das/10-common-docker-mistakes-that-hurt-nodejs-app-performance-1olc) - Pitfalls collection
- [Docker Volume Permissions (Linux Vox)](https://linuxvox.com/blog/understanding-user-file-ownership-in-docker-how-to-avoid-changing-permissions-of-linked-volumes/) - Permission issues

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Node.js/nginx images verified through Docker Hub, release schedules confirmed
- Architecture: HIGH - Multi-stage builds well-documented in official Docker guides, nginxinc/nginx-unprivileged extensively documented
- Vue 2 + Node.js compatibility: HIGH - Extensively researched via official GitHub issues, community reports, and EOL documentation
- Pitfalls: MEDIUM - Based on community reports and best practice articles, cross-referenced with official docs where possible

**Research date:** 2026-01-22 (Updated with Vue 2 compatibility deep-dive)
**Valid until:** 2026-04-22 (90 days - but Node.js 20 EOL April 2026 is hard deadline)
**Re-verify:** Node.js 20.x security releases, nginx security releases weekly, Vue 3 migration readiness
