---
phase: 15-testing-infrastructure
plan: 03
subsystem: testing
tags: [msw, api-mocking, vitest, network-interception]

# Dependency graph
requires:
  - phase: 15-01
    provides: Vitest test framework and setup infrastructure
provides:
  - MSW server setup for network-level API mocking
  - Default handlers for SysNDD API endpoints
  - Per-test handler override capability
  - Automatic handler reset between tests
affects: [15-04, 15-05, 15-06, future component tests]

# Tech tracking
tech-stack:
  added: [msw@2.12.7]
  patterns: [network-level API mocking, request handler pattern]

key-files:
  created:
    - app/src/test-utils/mocks/handlers.ts
    - app/src/test-utils/mocks/server.ts
  modified:
    - app/vitest.setup.ts

key-decisions:
  - "onUnhandledRequest: 'warn' logs unmocked endpoints instead of failing tests"
  - "Generic fallback handler returns 500 for unmocked /api/* requests"
  - "Handlers reset after each test via server.resetHandlers() in afterEach"

patterns-established:
  - "MSW handler pattern: http.get('/api/path', ({ params, request }) => HttpResponse.json(data))"
  - "Per-test handler override: server.use(http.get(...)) for test-specific responses"
  - "Server lifecycle: beforeAll(listen) -> afterEach(resetHandlers) -> afterAll(close)"

# Metrics
duration: 4min
completed: 2026-01-23
---

# Phase 15 Plan 03: MSW API Mocking Summary

**MSW server configured with default SysNDD API handlers and Vitest lifecycle integration**

## Performance

- **Duration:** 4 min
- **Started:** 2026-01-23T13:09:50Z
- **Completed:** 2026-01-23T13:13:29Z
- **Tasks:** 4 (Task 1 already committed in 15-01)
- **Files modified:** 3

## Accomplishments
- MSW 2.12.7 installed for network-level request interception
- Default handlers created for auth, genes, entity, search, and Internet Archive endpoints
- MSW server lifecycle integrated into vitest.setup.ts
- Handler reset between tests ensures test isolation

## Task Commits

Each task was committed atomically:

1. **Task 1: Install MSW** - `7f3a959` (chore) - Already committed as part of 15-01
2. **Task 2: Create MSW Handlers** - `48b39cc` (feat)
3. **Task 3: Create MSW Server Setup** - `ccbf445` (feat)
4. **Task 4: Integrate MSW with Vitest Setup** - `bbf475c` (feat)

## Files Created/Modified
- `app/src/test-utils/mocks/handlers.ts` - Default API mock handlers for SysNDD endpoints
- `app/src/test-utils/mocks/server.ts` - MSW server setup using setupServer from msw/node
- `app/vitest.setup.ts` - Added MSW lifecycle hooks (beforeAll/afterEach/afterAll)

## Decisions Made
- **onUnhandledRequest: 'warn'** - Log warnings for unmocked requests instead of failing tests, making it easier to identify missing handlers during test development
- **Generic fallback handler** - Returns 500 error for any unmocked /api/* requests, helping identify what needs to be mocked
- **Handler reset per test** - server.resetHandlers() in afterEach ensures tests don't affect each other

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Vitest dependencies required for MSW**
- **Found during:** Task 1 (Install MSW)
- **Issue:** MSW requires Vitest for server lifecycle hooks (beforeAll, afterEach, afterAll)
- **Fix:** Vitest was already installed in plan 15-01; verified MSW installation works with existing infrastructure
- **Files modified:** None (already committed)
- **Verification:** npm list msw shows msw@2.12.7 installed
- **Note:** Plan 15-01 dependencies were already committed, no additional work needed

---

**Total deviations:** 1 dependency verification (already resolved)
**Impact on plan:** MSW installation relied on plan 15-01 completing first. Since 15-01 dependencies were committed, plan executed smoothly.

## Issues Encountered
None - plan executed as specified with infrastructure from 15-01 already in place.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- MSW handlers ready for use in component tests
- Server lifecycle automatically manages request interception
- Plan 15-04 can add vitest-axe accessibility matchers
- Plan 15-05 can write component tests using MSW for API mocking

---
*Phase: 15-testing-infrastructure*
*Completed: 2026-01-23*
