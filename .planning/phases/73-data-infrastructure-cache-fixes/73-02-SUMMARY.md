---
phase: 73-data-infrastructure-cache-fixes
plan: 02
subsystem: infrastructure
tags: [memoise, cache, deployment, R, plumber]

# Dependency graph
requires:
  - phase: 73-01
    provides: "HGNC symbol mismatch fix for GeneNetworks table"
provides:
  - "CACHE_VERSION environment variable for automatic cache invalidation"
  - "Cache version management system in API startup"
  - "Documentation for cache management and troubleshooting"
affects: ["deployment", "operations", "future-data-fixes"]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Version-based cache invalidation on startup"]

key-files:
  created: []
  modified:
    - "api/start_sysndd_api.R"
    - "docker-compose.yml"
    - "docs/DEPLOYMENT.md"

key-decisions:
  - "Use .cache_version marker file (dot-prefix) so cachem ignores it"
  - "Default CACHE_VERSION to '1' for backward compatibility"
  - "Only delete .rds files, preserve directory structure and version marker"
  - "Clear cache BEFORE cachem::cache_disk() initialization"

patterns-established:
  - "Cache invalidation via environment variable version bumping"
  - "Startup-time cache management for memoise disk caches"

# Metrics
duration: 5min
completed: 2026-02-05
---

# Phase 73 Plan 02: Cache Invalidation Summary

**CACHE_VERSION environment variable with automatic .rds file clearing on version mismatch, preventing stale memoise cache after code deployments**

## Performance

- **Duration:** ~5 minutes
- **Started:** 2026-02-05T20:47:51Z
- **Completed:** 2026-02-05T20:52:00Z (approx)
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- CACHE_VERSION environment variable controls automatic cache invalidation on API startup
- Version comparison logic clears all .rds cache files when version changes
- Comprehensive cache management documentation in DEPLOYMENT.md
- Backward compatible (default "1" means no clearing unless explicitly set)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add CACHE_VERSION-based cache invalidation to API startup** - `5debc522` (feat)
2. **Task 2: Document cache management in DEPLOYMENT.md** - `df1096f2` (docs)

## Files Created/Modified

- `api/start_sysndd_api.R` - Added section 8.5 cache version management before memoisation setup
- `docker-compose.yml` - Added CACHE_VERSION environment variable to api service
- `docs/DEPLOYMENT.md` - Added Cache Management section with CACHE_VERSION documentation, when to increment guidance, manual clearing commands, cached functions inventory, and troubleshooting

## Decisions Made

1. **Use .cache_version marker file with dot-prefix** - Ensures cachem ignores it (cachem only stores .rds files)
2. **Default CACHE_VERSION to "1"** - Backward compatible; existing deployments work without change
3. **Only delete .rds files** - Preserves directory structure and the version file itself
4. **Clear cache BEFORE cachem::cache_disk()** - Ensures cachem starts fresh without needing memoise::forget()
5. **Use list.files(..., recursive = TRUE)** - Clears both main cache directory and external/dynamic/ subdirectory

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - implementation was straightforward with clear insertion points.

## User Setup Required

None - no external service configuration required. CACHE_VERSION is optional and defaults to "1".

## Next Phase Readiness

Cache invalidation mechanism is ready for production use. Operators can now safely deploy code changes that affect cached data structures by incrementing CACHE_VERSION in .env file.

Ready for next data infrastructure fixes in phase 73.

**Blockers/Concerns:** None

---
*Phase: 73-data-infrastructure-cache-fixes*
*Completed: 2026-02-05*
