# Technology Stack: Docker Volume Permissions

**Project:** SysNDD Production Deployment Fixes
**Researched:** 2026-02-01
**Focus:** Docker volume permissions when container UID differs from host UID

## Docker Volume Permissions

### The Problem

The SysNDD API container runs as `apiuser` (UID 1001) but bind-mounted directories like `/app/data` are owned by the host user (typically UID 1000). Linux kernel permission checks use numeric UIDs, not usernames, causing write permission errors when the container process attempts to write to these directories.

**Current Dockerfile creates:**
```dockerfile
RUN groupadd -g 1001 api && \
    useradd -u 1001 -g api -m -s /bin/bash apiuser
```

**Affected volumes in docker-compose.yml:**
```yaml
volumes:
  - ./api/data:/app/data
  - ./api/results:/app/results
```

### Root Cause Analysis

1. **UID Mismatch**: Container UID 1001 !== Host UID 1000
2. **Bind Mounts Preserve Host Permissions**: Unlike named volumes, bind mounts directly map host filesystem with original ownership
3. **Non-Root Container**: Running as non-root (correct for security) means no permission to chown at runtime

## Recommended Approach

**Recommendation: Change container UID to 1000 with build-time configurability**

This is the simplest, most reliable, and most production-appropriate solution for this specific case.

### Why This Approach

| Factor | UID 1000 Approach | Entrypoint Script | Named Volumes | User Namespace |
|--------|-------------------|-------------------|---------------|----------------|
| Complexity | LOW | MEDIUM | MEDIUM | HIGH |
| Security | GOOD | REQUIRES ROOT START | GOOD | BEST |
| Build-time fix | YES | NO (runtime) | PARTIAL | NO (daemon-level) |
| Production-ready | YES | YES (with care) | YES | YES (but complex) |
| Bind mount compatible | YES | YES | NO (different model) | YES (with config) |

### Rationale

1. **UID 1000 is the standard first-user UID on Linux** - Most development and production hosts use UID 1000 for the primary user. This maximizes compatibility.

2. **Build-time ARG allows flexibility** - Using `ARG UID=1000` with default allows overriding at build time for hosts with different UIDs without changing the Dockerfile.

3. **No runtime permission gymnastics** - Entrypoint scripts that run as root to fix permissions then drop to non-root add complexity and potential security concerns.

4. **Maintains non-root security posture** - The container still runs as non-root, just with a UID that matches the host.

5. **Named volumes are not suitable here** - The `data/` and `results/` directories need host access for debugging, backup inspection, and development workflows. Named volumes hide data from the host filesystem.

6. **User namespace remapping is overkill** - Requires daemon-level configuration, affects all containers, has compatibility issues with host volumes, and is designed for multi-tenant isolation rather than simple permission alignment.

## Implementation

### Dockerfile Changes

```dockerfile
# Accept UID/GID as build arguments with sensible defaults
ARG API_UID=1000
ARG API_GID=1000

# Create non-root user with configurable UID/GID
RUN groupadd -g ${API_GID} api && \
    useradd -u ${API_UID} -g api -m -s /bin/bash apiuser
```

**Full production stage update:**
```dockerfile
# =============================================================================
# Stage 3: Production - Final slim image
# =============================================================================
FROM base AS production

# Accept git commit hash as build argument for version tracking
ARG GIT_COMMIT=unknown
ENV GIT_COMMIT=${GIT_COMMIT}

# Accept UID/GID as build arguments (default 1000 matches most Linux hosts)
ARG API_UID=1000
ARG API_GID=1000

# Create non-root user with configurable UID/GID for security
RUN groupadd -g ${API_GID} api && \
    useradd -u ${API_UID} -g api -m -s /bin/bash apiuser

WORKDIR /app

# ... rest of Dockerfile unchanged ...
```

### Docker Compose Changes

```yaml
services:
  api:
    build:
      context: ./api/
      args:
        API_UID: ${API_UID:-1000}
        API_GID: ${API_GID:-1000}
    # ... rest unchanged ...
```

### Environment File (.env)

Add optional overrides:
```bash
# Optional: Override if host user is not UID 1000
# API_UID=1001
# API_GID=1001
```

### Build Commands

**Default (UID 1000):**
```bash
docker compose build api
```

**Custom UID:**
```bash
docker compose build --build-arg API_UID=$(id -u) --build-arg API_GID=$(id -g) api
```

## What NOT To Do

### 1. chmod 777 on Host Directories

```bash
# NEVER DO THIS
chmod -R 777 ./api/data ./api/results
```

**Why:** Removes all security, allows any container (including compromised ones) to read/write/execute. This is a security anti-pattern.

### 2. Run Container as Root

```yaml
# NEVER DO THIS IN PRODUCTION
user: root
```

**Why:** Privilege escalation risk. If container is compromised, attacker has root in the container which can lead to host escape.

### 3. Entrypoint Script with Runtime chown

```dockerfile
# AVOID IN PRODUCTION
ENTRYPOINT ["/entrypoint.sh"]
```
```bash
#!/bin/bash
chown -R apiuser:api /app/data /app/results
exec gosu apiuser "$@"
```

**Why for this case:**
- Requires container to start as root (security concern)
- Adds runtime complexity
- chown on large directories is slow
- The fixuid tool explicitly warns: "DO NOT INCLUDE in a production container image"

**When it IS appropriate:** Development containers where flexibility trumps security.

### 4. User Namespace Remapping for Single Container

```json
// /etc/docker/daemon.json
{"userns-remap": "default"}
```

**Why not for this case:**
- Daemon-level configuration affects ALL containers
- Existing volumes become inaccessible after enabling
- Requires coordination with volume permissions anyway
- Overkill for simple UID alignment

**When it IS appropriate:** Multi-tenant environments, high-security requirements, container isolation is paramount.

### 5. Using UID 1001 Arbitrarily

**Why the current 1001 is problematic:**
- UID 1001 is not the default first-user on most systems
- Creates friction with standard host setups
- No security benefit over UID 1000

**Better alternative:** If avoiding UID 1000 for security (avoiding overlap with host users), use UID 10000+ which is recommended by security guidelines for production containers.

## Alternative Approaches (When to Use)

### Named Volumes (When Host Access Not Needed)

If `data/` and `results/` directories do not need direct host access:

```yaml
volumes:
  - api_data:/app/data
  - api_results:/app/results
  # ... keep other bind mounts for code ...

volumes:
  api_data:
    name: sysndd_api_data
  api_results:
    name: sysndd_api_results
```

**Pros:** Docker manages permissions automatically
**Cons:** Cannot easily access files from host without `docker cp` or exec

### Higher UID for Enhanced Security

For production environments with strict security requirements:

```dockerfile
ARG API_UID=10001
ARG API_GID=10001
```

**Why 10000+:** UIDs below 10000 may overlap with system users on some hosts. UID 10001+ reduces privilege escalation risk if container breakout occurs.

**Trade-off:** Requires ensuring host directories are owned by this UID or using named volumes.

### Entrypoint with gosu (Development Only)

For development containers where maximum flexibility is needed:

```dockerfile
FROM base AS development

# Install gosu for user switching
RUN apt-get update && apt-get install -y gosu && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["Rscript", "start_sysndd_api.R"]
```

```bash
#!/bin/bash
# docker-entrypoint.sh

# Fix ownership of mounted volumes
if [ "$(id -u)" = "0" ]; then
    chown -R apiuser:api /app/data /app/results 2>/dev/null || true
    exec gosu apiuser "$@"
else
    exec "$@"
fi
```

**Use for:** Local development with docker-compose.override.yml
**Never use for:** Production images

## Security Considerations

| Approach | Security Level | Notes |
|----------|---------------|-------|
| UID 1000 (non-root) | GOOD | Standard, matches most hosts |
| UID 10000+ (non-root) | BETTER | Avoids host UID overlap |
| User namespace remapping | BEST | Full isolation, but complex |
| Root user | POOR | Never for production |
| chmod 777 | UNACCEPTABLE | Security anti-pattern |

## Confidence Assessment

| Claim | Confidence | Source |
|-------|------------|--------|
| UID mismatch causes permission errors | HIGH | [Docker Forums](https://forums.docker.com/t/best-practices-for-uid-gid-and-permissions/139161), [Docker Mount Permissions Guide](https://eastondev.com/blog/en/posts/dev/20251217-docker-mount-permissions-guide/) |
| Build-arg UID approach works | HIGH | [Nick Janetakis Blog](https://nickjanetakis.com/blog/running-docker-containers-as-a-non-root-user-with-a-custom-uid-and-gid), [Baeldung](https://www.baeldung.com/ops/docker-set-user-container-host) |
| UID 1000 is standard first-user | HIGH | [Stream Security](https://www.stream.security/rules/ensure-containers-run-with-a-high-uid-to-avoid-host-conflict) |
| Named volumes have better permission handling | HIGH | [Docker Docs](https://docs.docker.com/engine/storage/volumes/) |
| fixuid not for production | HIGH | [GitHub boxboat/fixuid](https://github.com/boxboat/fixuid) |
| User namespace remapping complexity | HIGH | [Docker Docs](https://docs.docker.com/engine/security/userns-remap/) |
| UID 10000+ recommendation | MEDIUM | [Sysdig Best Practices](https://www.sysdig.com/learn-cloud-native/dockerfile-best-practices) |

## Summary

**Recommended fix:** Change Dockerfile to use UID 1000 (configurable via build arg) instead of UID 1001.

**Rationale:** Simplest solution that maintains security, aligns with Linux standards, and requires minimal changes. The build-arg approach provides flexibility for hosts with different UIDs without adding runtime complexity.

**Implementation effort:** LOW - Two-line Dockerfile change plus optional docker-compose.yml update.

## Sources

- [Docker Volumes Documentation](https://docs.docker.com/engine/storage/volumes/)
- [Docker User Namespace Remapping](https://docs.docker.com/engine/security/userns-remap/)
- [Docker Mount Permissions Guide (2025)](https://eastondev.com/blog/en/posts/dev/20251217-docker-mount-permissions-guide/)
- [Running Docker Containers as Non-root User](https://nickjanetakis.com/blog/running-docker-containers-as-a-non-root-user-with-a-custom-uid-and-gid)
- [Docker UID/GID Best Practices Forum](https://forums.docker.com/t/best-practices-for-uid-gid-and-permissions/139161)
- [fixuid GitHub Repository](https://github.com/boxboat/fixuid)
- [Dockerfile Best Practices - Sysdig](https://www.sysdig.com/learn-cloud-native/dockerfile-best-practices)
- [Understanding Docker USER Instruction](https://www.docker.com/blog/understanding-the-docker-user-instruction/)
