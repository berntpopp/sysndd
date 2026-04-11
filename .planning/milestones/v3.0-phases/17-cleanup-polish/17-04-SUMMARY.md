---
phase: 17-cleanup-polish
plan: 04
subsystem: build
tags: [npm, dependencies, security, vite, cleanup]

# Dependency graph
requires:
  - phase: 12-vite-migration
    provides: Vite build system and dev server
provides:
  - Lean dependency tree with only necessary packages
  - Zero security vulnerabilities in production dependencies
  - Clean package.json scripts pointing exclusively to Vite
affects: [all future development - reduced bundle size and security surface]

# Tech tracking
tech-stack:
  removed: [@vue/cli-*, vue-cli-plugin-*, webpack-*, legacy packages]
  patterns: [clean dependency management, security-first approach]

key-files:
  modified:
    - app/package.json
    - app/package-lock.json
    - app/vite.config.ts

key-decisions:
  - "Removed all Vue CLI and webpack packages after Vite migration complete"
  - "Updated axios from 0.21.4 to 1.13.2 for security (CSRF and SSRF vulnerabilities)"
  - "Kept swagger-ui packages despite depcheck flag (used in API.vue)"
  - "Kept @zanmato/vue3-treeselect despite depcheck flag (used in 9 files)"
  - "Main build script now points to Vite: vue-tsc --noEmit && vite build"

patterns-established:
  - "All scripts use Vite tooling exclusively"
  - "Zero-tolerance for high/critical production vulnerabilities"

# Metrics
duration: 4min
completed: 2026-01-23
---

# Phase 17 Plan 04: Dependency Cleanup Summary

**Reduced package count from 1787 to 1083 (39% reduction), eliminated all security vulnerabilities, removed all Vue CLI and webpack dependencies**

## Performance

- **Duration:** 4 minutes
- **Started:** 2026-01-23T15:55:37Z
- **Completed:** 2026-01-23T16:00:01Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Removed 704 packages including all Vue CLI and webpack dependencies
- Fixed all security vulnerabilities (6 → 0)
- Consolidated package.json scripts to use Vite exclusively
- Maintained 100% build and test compatibility

## Task Commits

Each task was committed atomically:

1. **Task 1: Identify and remove unused dependencies** - `dd160a1` (chore)
   - Removed @vue/cli-* packages (5 packages)
   - Removed vue-cli-plugin-* packages (5 packages)
   - Removed webpack packages (4 packages)
   - Removed legacy packages (9 packages: vue-loader, vue-server-renderer, esm, core-js, etc.)
   - Removed unused dependencies (2 packages: vue-axios, joi)
   - Reduced from 1787 to 1083 packages (704 removed)
   - Reduced vulnerabilities from 6 to 2

2. **Task 2: Run npm audit and fix vulnerabilities** - `ae272cd` (fix)
   - Fixed lodash prototype pollution vulnerability (moderate)
   - Updated axios from 0.21.4 to 1.13.2 (high: CSRF and SSRF)
   - Achieved zero vulnerabilities

3. **Task 3: Update package.json scripts and verify** - `afaa2aa` (refactor)
   - Removed Vue CLI scripts: serve, build (vue-cli-service), sitemap, start
   - Updated main build script to Vite
   - Fixed visualizer type assertion for compatibility
   - Verified dev, build, and test scripts work

## Files Created/Modified
- `app/package.json` - Cleaned dependencies and scripts, removed all Vue CLI references
- `app/package-lock.json` - Updated with new dependency tree
- `app/vite.config.ts` - Fixed visualizer type assertion after dependency updates

## Decisions Made

**1. Kept swagger-ui packages despite depcheck "unused" flag**
- Depcheck missed usage in `src/views/API.vue`
- Package is actually used for API documentation UI
- Confirmed with grep search

**2. Kept @zanmato/vue3-treeselect despite depcheck "unused" flag**
- Depcheck missed usage in 9 component files
- Used for hierarchical selection in forms
- Confirmed with grep search

**3. Kept @vitest/coverage-v8 despite depcheck "unused" flag**
- Used in package.json script `test:coverage`
- Essential for test coverage reporting

**4. Updated axios manually instead of using --force**
- Avoided `npm audit fix --force` to prevent breaking changes
- Manually updated axios to latest (1.13.2) in devDependencies
- Maintained compatibility while fixing vulnerabilities

**5. Fixed visualizer type assertion**
- Changed from `as PluginOption` to `as unknown as PluginOption`
- Required after removing packages that provided compatible types
- Standard TypeScript pattern for incompatible type assertions

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed visualizer TypeScript error**
- **Found during:** Task 3 (npm run build verification)
- **Issue:** Type assertion error after dependency removal - "Conversion of type 'Plugin' to type 'PluginOption' may be a mistake"
- **Fix:** Changed type assertion from `as PluginOption` to `as unknown as PluginOption` in vite.config.ts
- **Files modified:** app/vite.config.ts
- **Verification:** Build passes with `npm run build`
- **Committed in:** afaa2aa (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Type assertion fix necessary for build to pass after dependency updates. No scope creep.

## Issues Encountered
None - plan executed smoothly with one minor TypeScript compatibility fix

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Dependency tree lean and secure
- Build system fully consolidated on Vite
- Ready for continued Phase 17 cleanup tasks
- No blockers identified

**Key metrics:**
- Package count: 1787 → 1083 (39% reduction)
- Vulnerabilities: 6 → 0 (100% resolved)
- Vue CLI references: removed (100%)
- Webpack references: removed (100%)
- Build time: ~4s (maintained)
- Test pass rate: maintained (121 passing, 23 pre-existing failures)

---
*Phase: 17-cleanup-polish*
*Completed: 2026-01-23*
