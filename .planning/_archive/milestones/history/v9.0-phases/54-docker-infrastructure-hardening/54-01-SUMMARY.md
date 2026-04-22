---
phase: 54-docker-infrastructure-hardening
plan: 01
subsystem: infra
tags: [nginx, docker, brotli, caching, security]

# Dependency graph
requires:
  - phase: 53-production-docker-validation
    provides: Production validation infrastructure and health endpoints
provides:
  - Pinned nginx-brotli image v1.28.0 for reproducible builds
  - Static asset caching with immutable headers for Vite hashed assets
  - Brotli compression for 15-20% better compression than gzip
  - Access logging with buffered writes
  - tcp_nopush for sendfile optimization
affects: [54-02-PLAN, future deployments, CDN configuration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "nginx location block ordering: specific regex -> general regex -> prefix"
    - "Cache-Control immutable for content-hashed assets"
    - "Brotli compression level 6 for balance of speed/ratio"

key-files:
  created: []
  modified:
    - app/Dockerfile
    - app/docker/nginx/nginx.conf
    - app/docker/nginx/local.conf

key-decisions:
  - "Use nginx-brotli v1.28.0 (v1.27.4 doesn't exist on fholzer/nginx-brotli)"
  - "Use npm run build:${VUE_MODE} to match package.json scripts"
  - "Access logs symlinked to stdout in container (inherent in fholzer image)"
  - "1-year immutable cache for /assets/ (Vite content-hashed files)"
  - "30-day cache for images (may be updated without hash change)"
  - "No-cache for root/HTML (immediate app update pickup)"

patterns-established:
  - "Nginx static asset caching: 1y immutable for hashed, 30d for images, no-cache for HTML"
  - "Brotli compression: level 6, comprehensive type list"

# Metrics
duration: 10min
completed: 2026-01-30
---

# Phase 54 Plan 01: Nginx Hardening Summary

**Nginx hardening with pinned v1.28.0 image, brotli compression, static asset caching (1-year immutable), and access logging**

## Performance

- **Duration:** 10 min
- **Started:** 2026-01-30T20:00:49Z
- **Completed:** 2026-01-30T20:11:02Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Pinned nginx-brotli to v1.28.0 for reproducible builds and supply chain security
- Enabled brotli compression (15-20% better than gzip) at level 6
- Configured static asset caching: 1-year immutable for /assets/, 30-day for images
- Enabled buffered access logging (32k buffer, 5s flush)
- Enabled tcp_nopush for sendfile efficiency

## Task Commits

Each task was committed atomically:

1. **Task 1: Pin nginx image and configure access logging with brotli** - `b110a026` (feat)
2. **Task 2: Configure static asset caching with proper headers** - `f74ec8e6` (feat)
3. **Task 3: Build and verify nginx configuration** - `42b8b9b6` (fix)

## Files Created/Modified

- `app/Dockerfile` - Pinned nginx-brotli:v1.28.0, fixed build script to use npm run build:${VUE_MODE}
- `app/docker/nginx/nginx.conf` - Access logging, tcp_nopush, brotli compression config
- `app/docker/nginx/local.conf` - Location blocks for static asset caching (assets, images, root)

## Decisions Made

1. **nginx-brotli v1.28.0 instead of v1.27.4:** The planned v1.27.4 tag doesn't exist on Docker Hub. Used v1.28.0 (latest stable).

2. **Build script fix:** Changed from `npm run build:vite -- --mode ${VUE_MODE}` to `npm run build:${VUE_MODE}` to match package.json scripts (build:docker, build:production).

3. **Access log destination:** The fholzer/nginx-brotli image symlinks /var/log/nginx/access.log to /dev/stdout. Configuration writes to the file path, output goes to stdout (container logging best practice).

4. **Cache-Control header strategy:**
   - /assets/ (Vite hashed files): 1-year immutable (files never change, hash changes instead)
   - Images: 30-day cache (may be updated without filename change)
   - Root/HTML: no-cache (app updates should be picked up immediately)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] nginx-brotli v1.27.4 tag doesn't exist**
- **Found during:** Task 3 (Build verification)
- **Issue:** Docker pull failed - fholzer/nginx-brotli:v1.27.4 not found on Docker Hub
- **Fix:** Changed to v1.28.0 (latest available stable version)
- **Files modified:** app/Dockerfile
- **Verification:** docker build succeeds, nginx -t passes
- **Committed in:** 42b8b9b6

**2. [Rule 3 - Blocking] build:vite script doesn't exist**
- **Found during:** Task 3 (Build verification)
- **Issue:** npm run build:vite fails - script not in package.json. Correct scripts are build:docker and build:production
- **Fix:** Changed to `npm run build:${VUE_MODE}` which resolves to build:docker or build:production based on VUE_MODE arg
- **Files modified:** app/Dockerfile
- **Verification:** docker build succeeds, Vite bundles correctly
- **Committed in:** 42b8b9b6

---

**Total deviations:** 2 auto-fixed (both Rule 3 - blocking issues)
**Impact on plan:** Both fixes necessary to complete build. No scope creep - just correcting plan assumptions.

## Issues Encountered

- **Access log file symlink:** The container image symlinks access.log to /dev/stdout. This is actually better than file-based logging for container environments (logs go to docker logs / container orchestration). Configuration still works correctly.

## Verification Results

All success criteria verified:

1. **Pinned image:** `FROM fholzer/nginx-brotli:v1.28.0` (corrected from v1.27.4)
2. **Asset caching:** `/assets/*.js` returns `Cache-Control: public, immutable, max-age=31536000`
3. **Image caching:** PNG files return `Cache-Control: public, max-age=2592000`
4. **Root no-cache:** `Cache-Control: no-cache, no-store, must-revalidate`
5. **Brotli:** Request with `Accept-Encoding: br` returns `Content-Encoding: br`
6. **tcp_nopush:** Enabled in nginx.conf
7. **nginx -t:** Configuration passes syntax validation

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Nginx hardening complete, ready for 54-02 (additional Docker security)
- Production build verified working with new configuration
- Brotli and caching working as expected

---
*Phase: 54-docker-infrastructure-hardening*
*Completed: 2026-01-30*
