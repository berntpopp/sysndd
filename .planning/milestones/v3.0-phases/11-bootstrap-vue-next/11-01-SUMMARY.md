---
phase: 11-bootstrap-vue-next
plan: 01
subsystem: ui
tags: [bootstrap-vue-next, bootstrap-5, vue-3, composables, toast, modal]

# Dependency graph
requires:
  - phase: 10-vue3-migration
    provides: Vue 3 app instance with @vue/compat, Pinia stores
provides:
  - Bootstrap-Vue-Next plugin registered alongside Bootstrap-Vue
  - BApp wrapper component for toast/modal orchestration
  - useToastNotifications composable for toast API
  - useModalControls composable for modal API
  - Bootstrap 5 CSS loaded
affects: [11-02 through 11-06, component-migrations, toast-replacements, modal-replacements]

# Tech tracking
tech-stack:
  added: [bootstrap-vue-next@0.42.0, bootstrap@5.3.8]
  patterns: [BApp wrapper for orchestrators, composables wrapping Bootstrap-Vue-Next hooks]

key-files:
  created:
    - app/src/composables/useToastNotifications.js
    - app/src/composables/useModalControls.js
  modified:
    - app/src/main.js
    - app/src/App.vue
    - app/package.json
    - app/vue.config.js

key-decisions:
  - "Upgraded Bootstrap 4.6.2 to 5.3.8 for Bootstrap-Vue-Next compatibility"
  - "Keep both Bootstrap-Vue and Bootstrap-Vue-Next CSS during transition"
  - "Fixed esm package incompatibility with Node.js 18+ in vue.config.js"
  - "Added babel-loader cache path to /tmp to avoid permission issues"

patterns-established:
  - "Composables pattern: wrap Bootstrap-Vue-Next hooks (useToast, useModal) with API matching existing mixins"
  - "BApp wrapper: always wrap root component with BApp for toast/modal orchestrator support"

# Metrics
duration: 17min
completed: 2026-01-23
---

# Phase 11 Plan 01: Bootstrap-Vue-Next Foundation Summary

**Bootstrap-Vue-Next foundation with BApp wrapper, useToastNotifications and useModalControls composables ready for component migrations**

## Performance

- **Duration:** 17 min
- **Started:** 2026-01-22T23:15:01Z
- **Completed:** 2026-01-22T23:32:08Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Bootstrap-Vue-Next plugin registered via createBootstrap() alongside existing Bootstrap-Vue
- BApp wrapper component added to App.vue providing toast/modal orchestrators
- Composables directory created with useToastNotifications and useModalControls
- Bootstrap upgraded from 4.6.2 to 5.3.8 for Bootstrap-Vue-Next compatibility
- Fixed pre-existing build issues (esm package incompatibility, babel cache permissions)

## Task Commits

Each task was committed atomically:

1. **Task 1: Configure Bootstrap-Vue-Next in main.js** - `dec471a` (feat)
2. **Task 2: Create composables directory and toast/modal composables** - `b829d0b` (feat)
3. **Task 3: Wrap App.vue with BApp component** - `b9ffc56` (feat)

## Files Created/Modified

- `app/src/main.js` - Added Bootstrap-Vue-Next imports and createBootstrap() plugin registration
- `app/src/App.vue` - Wrapped template with BApp component, imported/registered BApp
- `app/src/composables/useToastNotifications.js` - Toast composable wrapping useToast with makeToast API
- `app/src/composables/useModalControls.js` - Modal composable wrapping useModal with showModal/hideModal API
- `app/package.json` - Updated Bootstrap from 4.6.2 to 5.3.8
- `app/vue.config.js` - Fixed esm package issue, added babel cache config

## Decisions Made

1. **Bootstrap 5 upgrade required** - Bootstrap-Vue-Next requires Bootstrap 5; upgraded from 4.6.2 to 5.3.8
2. **Keep both Bootstrap CSS during transition** - Both Bootstrap 4 (via Bootstrap-Vue) and Bootstrap 5 (via Bootstrap-Vue-Next) CSS loaded temporarily until component migration completes
3. **esm package removal** - Replaced esm require with try/catch fallback for routes import (esm incompatible with Node.js 18+)
4. **Babel cache location** - Configured babel-loader to use /tmp/babel-cache to avoid permission issues with root-owned node_modules/.cache

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed esm package incompatibility with Node.js 18+**
- **Found during:** Task 1 (dev server startup verification)
- **Issue:** vue.config.js used `require = require('esm')(module)` which doesn't work with Node.js 18+
- **Fix:** Replaced with try/catch fallback that gracefully handles missing routes.cjs file
- **Files modified:** app/vue.config.js
- **Verification:** npm run serve starts successfully
- **Committed in:** dec471a (Task 1 commit)

**2. [Rule 3 - Blocking] Fixed babel-loader cache permission issue**
- **Found during:** Task 1 (dev server compilation)
- **Issue:** node_modules/.cache/babel-loader owned by root, causing EACCES errors
- **Fix:** Configured babel-loader to use /tmp/babel-cache via chainWebpack config
- **Files modified:** app/vue.config.js
- **Verification:** npm run serve compiles successfully
- **Committed in:** dec471a (Task 1 commit)

**3. [Rule 3 - Blocking] Installed Bootstrap 5**
- **Found during:** Task 1 (Bootstrap-Vue-Next setup)
- **Issue:** Plan stated Bootstrap 5 was already installed from Phase 10, but package.json had Bootstrap 4.6.2
- **Fix:** Ran npm install bootstrap@5.3.8 --legacy-peer-deps
- **Files modified:** app/package.json, app/package-lock.json
- **Verification:** node_modules/bootstrap/package.json shows version 5.3.8
- **Committed in:** dec471a (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (3 blocking issues)
**Impact on plan:** All auto-fixes necessary for build to succeed. No scope creep.

## Issues Encountered

- Pre-existing deprecation warning in SearchBar.vue (`.native` modifier removed in Vue 3) - unrelated to this plan, noted for future cleanup

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Bootstrap-Vue-Next foundation complete and ready for component migrations
- Composables ready for use in component refactoring (11-02 through 11-06)
- Both Bootstrap-Vue and Bootstrap-Vue-Next coexist - existing components continue working
- BApp wrapper provides toast and modal orchestrators for new composable-based components

---
*Phase: 11-bootstrap-vue-next*
*Completed: 2026-01-23*
