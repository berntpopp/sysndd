# Project Research Summary: v10.1 Production Deployment Fixes

**Project:** SysNDD v10.1 Production Deployment Fixes
**Domain:** Docker multi-container scaling, volume permissions, migration coordination
**Researched:** 2026-02-01
**Confidence:** HIGH

## Executive Summary

SysNDD v10.1 fixes 3 critical production deployment issues blocking horizontal scaling:

1. **UID mismatch (#138)**: Container runs as UID 1001, host directories owned by UID 1000 → Change to UID 1000 with build-arg flexibility
2. **Migration lock timeout (#136)**: All containers acquire lock even when up-to-date → Implement double-checked locking pattern
3. **Missing favicon (#137)**: Image moved to _old/ but still referenced → Restore to public/ directory

**Key findings:**
- UID 1000 is the Linux standard first-user UID (maximum host compatibility)
- Double-checked locking is a well-documented pattern (golang-migrate, Rails) for migration coordination
- Build-arg UID approach is recommended over runtime entrypoint scripts for production
- `container_name` directive prevents Docker Compose scaling (must remove for replicas)

## Key Findings

### Issue #138: Data Directory Permissions

**Root cause:** Dockerfile creates `apiuser` with UID 1001, but bind-mounted `/app/data` is owned by host user UID 1000.

**Recommended fix:** Change UID to 1000 with build-time configurability:
```dockerfile
ARG API_UID=1000
ARG API_GID=1000
RUN groupadd -g ${API_GID} api && \
    useradd -u ${API_UID} -g api -m -s /bin/bash apiuser
```

**What NOT to do:**
- chmod 777 (security anti-pattern)
- Runtime entrypoint with chown (adds complexity, requires root start, slow on large volumes)
- User namespace remapping (overkill, daemon-level change)

### Issue #136: Migration Lock Timeout

**Root cause:** Current flow always acquires advisory lock before checking migration status. With 4 containers and 30s timeout, containers queue sequentially and timeout.

**Recommended fix:** Double-checked locking pattern:
```r
# Fast path: check first (no lock)
pending <- get_pending_migrations(pool)
if (length(pending) == 0) {
  log_info("Schema up to date - skipping lock")
  return()
}

# Slow path: acquire lock, re-check, run
acquire_migration_lock(conn)
pending <- get_pending_migrations(pool)  # Re-check after lock
if (length(pending) > 0) {
  run_migrations(...)
}
release_migration_lock(conn)
```

**Why this works:** 99% of startups find schema up-to-date → O(1) parallel startup instead of O(n) sequential.

### Issue #137: Missing Favicon

**Root cause:** File `brain-neurodevelopmental-disorders-sysndd.png` moved to `app/public/_old/` but still referenced in `app/index.html` line 9.

**Fix:** Move file back to `app/public/` or update the reference.

### Additional Finding: Container Naming

**Blocker for scaling:** `container_name: sysndd_api` in docker-compose.yml prevents `docker compose --scale api=4`.

**Fix:** Remove `container_name` directive, let Docker auto-name containers as `sysndd-api-1`, etc.

## Recommended Stack

| Component | Change | Notes |
|-----------|--------|-------|
| Dockerfile UID | Change 1001 → 1000 (with ARG) | Maximum host compatibility |
| docker-compose.yml | Remove `container_name: sysndd_api` | Required for scaling |
| migration-runner.R | Add `get_pending_migrations()` | ~50 lines of code |
| start_sysndd_api.R | Use double-checked locking | Replace current lock-first pattern |
| app/public/ | Restore favicon | Single file move |

**What NOT to add:**
- gosu/su-exec (not needed if using build-time UID fix)
- Init container for migrations (overkill for current setup)
- External volume drivers (local driver sufficient)

## Expected Features

**Table stakes (must have):**
- Multi-container scaling works (`docker compose --scale api=4`)
- No permission errors on /app/data write operations
- Favicon loads without 404 errors
- Migrations run safely with multiple containers

**Validation requirements:**
- Local testing of production multi-container setup
- Debug log inspection during parallel startup
- Migration coordination verification

## Architecture Approach

Three integration points:

1. **Dockerfile** → Change UID to 1000 (build-time fix)
2. **migration-runner.R** → Add pre-lock check (double-checked locking)
3. **docker-compose.yml** → Remove container_name (enable scaling)
4. **app/public/** → Restore favicon

## Critical Pitfalls

1. **Entrypoint chown on large volumes** → Skip if using build-time UID fix
2. **IS_FREE_LOCK race condition** → Use migration status check, not lock status check
3. **Extending timeout instead of fixing** → Hides problem, doesn't scale
4. **Named volume ownership drift** → Document volume initialization procedure

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 66: Permission & Scaling Infrastructure
**Delivers:** UID fix in Dockerfile, container_name removal, favicon restoration
**Risk:** LOW (isolated changes)

### Phase 67: Migration Double-Check Locking
**Delivers:** Pre-lock migration check, parallel container startup
**Risk:** LOW (builds on existing infrastructure)

### Phase 68: Local Production Testing
**Delivers:** Verified multi-container scaling, debug log inspection, migration coordination test
**Risk:** LOW (validation phase)

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| UID 1000 recommendation | HIGH | Docker community consensus, Linux standard |
| Double-checked locking pattern | HIGH | golang-migrate, Rails both use it |
| Container naming blocker | HIGH | Docker official docs confirm |
| Favicon fix | HIGH | Direct code inspection |
| Local testing approach | HIGH | Standard Docker Compose workflow |

**Overall confidence:** HIGH

### Gaps to Address

- None identified - all issues have clear solutions

## Sources

### Primary (HIGH confidence)
- [Docker Compose Deploy Specification](https://docs.docker.com/reference/compose-file/deploy/) - container_name/replicas conflict
- [MySQL 8.4 Locking Functions](https://dev.mysql.com/doc/refman/8.4/en/locking-functions.html) - GET_LOCK behavior
- [golang-migrate issue #468](https://github.com/golang-migrate/migrate/issues/468) - Double-checked locking pattern
- [Docker Volume Permissions Guide](https://eastondev.com/blog/en/posts/dev/20251217-docker-mount-permissions-guide/) - UID mismatch solutions

### Codebase Analysis (HIGH confidence)
- `api/Dockerfile` - Current UID 1001 hardcoding
- `api/functions/migration-runner.R` - Existing lock infrastructure
- `docker-compose.yml` - container_name blocker
- `app/index.html` - Favicon reference

---

**Research completed:** 2026-02-01
**Ready for roadmap:** Yes
