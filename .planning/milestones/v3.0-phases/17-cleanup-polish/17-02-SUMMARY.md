---
phase: 17-cleanup-polish
plan: 02
subsystem: build
tags: [vue3, vite, migration, compatibility]

# Dependency graph
requires:
  - phase: 17-01
    provides: Bundle analysis baseline
  - phase: 10-vue3-core
    provides: Vue 3 migration with compatibility layer
provides:
  - Pure Vue 3 application without compatibility layer
  - Clean vite.config.ts using standard Vue 3 plugin
  - Reduced bundle size by removing @vue/compat package
affects: [17-03, 17-04, build-optimization]

# Tech tracking
tech-stack:
  added: []
  removed: ["@vue/compat"]
  patterns: ["Standard Vue 3 configuration without compat bridge"]

key-files:
  created: []
  modified:
    - app/vite.config.ts
    - app/package.json
    - app/src/main.ts

key-decisions:
  - "Removed @vue/compat compatibility layer completely"
  - "Confirmed 23 pre-existing test failures are unrelated to compat removal"

patterns-established:
  - "Pure Vue 3 configuration: vue() plugin without compatConfig"
  - "No runtime compat configuration in main.ts"

# Metrics
duration: 4min
completed: 2026-01-23
---

# Phase 17 Plan 02: Remove Vue 2 Compatibility Layer Summary

**Application migrated to pure Vue 3 without @vue/compat bridge, removing 11 lines of compatibility configuration and the entire compat package**

## Performance

- **Duration:** 4 min
- **Started:** 2026-01-23T15:46:57Z
- **Completed:** 2026-01-23T15:51:09Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Removed Vue 2 compatibility mode from Vite configuration
- Uninstalled @vue/compat package from dependencies
- Removed configureCompat runtime configuration
- Production build succeeds with pure Vue 3 (4.01s build time)
- All 121 baseline tests pass (23 pre-existing failures confirmed unrelated to compat removal)

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove @vue/compat from vite.config.ts** - `aa3c8d6` (refactor)
2. **Task 2: Remove @vue/compat package and verify** - `273f9b4` (feat)

## Files Created/Modified
- `app/vite.config.ts` - Removed compatConfig from vue() plugin and vue alias
- `app/package.json` - Removed @vue/compat dependency
- `app/src/main.ts` - Removed configureCompat import and configuration block

## Decisions Made

**1. Verified test baseline before removal**
- Ran tests with compat mode enabled first (23 failures)
- Ran tests after compat removal (same 23 failures)
- Confirmed failures are pre-existing issues (Banner component rendering, FooterNavItem accessibility)
- These failures are unrelated to Vue 2 compatibility removal

**2. Used --legacy-peer-deps for npm uninstall**
- npm uninstall encountered peer dependency conflicts with legacy Vue CLI packages
- Used --legacy-peer-deps flag to bypass conflicts
- Safe because we're removing a package, not adding/upgrading

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

**1. npm peer dependency conflicts**
- **Problem:** `npm uninstall @vue/compat` failed with ERESOLVE error due to conflicting peer dependencies between @vue/cli-plugin-router@4.5.19 and @vue/cli-service@5.0.8
- **Resolution:** Used `npm uninstall @vue/compat --legacy-peer-deps` flag
- **Root cause:** Legacy Vue CLI plugins still present in devDependencies (will be cleaned up in future phase)
- **Impact:** Successfully removed @vue/compat without affecting other dependencies

**2. Pre-existing test failures**
- **Context:** 23 tests failing (Banner component, FooterNavItem accessibility)
- **Verification:** Confirmed same failures exist WITH compat mode enabled
- **Conclusion:** Failures are unrelated to compat removal
- **Next steps:** These failures should be addressed in a separate testing/accessibility focused plan

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Phase 17 Plan 03 and beyond:**
- Application now runs on pure Vue 3 without compatibility layer
- No Vue 2 compatibility warnings in console
- Development server starts successfully
- Production builds succeed
- Clean configuration files using standard Vue 3 patterns

**Technical debt cleaned up:**
- Removed 1 npm dependency (@vue/compat)
- Removed 11 lines of compatibility configuration from vite.config.ts
- Removed 30+ lines of runtime compat configuration from main.ts
- Cleaner build output without compat layer overhead

**Known issues to address in future plans:**
- 23 pre-existing test failures (Banner rendering, FooterNavItem accessibility)
- Legacy Vue CLI devDependencies still present (can be cleaned up separately)

---
*Phase: 17-cleanup-polish*
*Completed: 2026-01-23*
