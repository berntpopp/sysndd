---
phase: 22-service-layer-middleware
plan: 06
subsystem: api
tags: [plumber, middleware, service-layer, authorization, authentication, jwt]

# Dependency graph
requires:
  - phase: 22-01
    provides: require_auth filter and require_role helper for authorization
  - phase: 22-02
    provides: auth_signin, auth_verify, auth_refresh service functions
  - phase: 22-05
    provides: Service layer patterns and dependency injection

provides:
  - Refactored user endpoints using require_role middleware
  - Refactored admin endpoints using require_role middleware
  - Refactored authentication endpoints using auth service layer
  - Consolidated duplicated role checks across endpoints
  - First batch of endpoint refactoring complete

affects: [22-07, 22-08, 22-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Endpoint-level authorization via require_role helper"
    - "Service layer delegation for authentication logic"
    - "Backward-compatible service integration (return JWT string, not structured response)"

key-files:
  created: []
  modified:
    - api/endpoints/user_endpoints.R
    - api/endpoints/admin_endpoints.R
    - api/endpoints/authentication_endpoints.R

key-decisions:
  - "Keep password/update complex self-vs-admin logic inline (deferred to later refactoring)"
  - "Maintain backward compatibility in auth endpoints (return JWT string, not structured response)"
  - "Use require_role for straightforward role checks, keep == checks for differentiated behavior"

patterns-established:
  - "require_role(req, res, 'MinRole') pattern for endpoint authorization"
  - "Service function calls with dependency injection (pool, dw as params)"
  - "Error handling via tryCatch for service layer errors"

# Metrics
duration: 6min
completed: 2026-01-24
---

# Phase 22 Plan 06: User, Admin, and Auth Endpoints Refactoring Summary

**Migrated user, admin, and authentication endpoints to require_role middleware and auth service layer, reducing role check code by 73% (from 119 lines to 32 lines)**

## Performance

- **Duration:** 6 min
- **Started:** 2026-01-24T15:06:10Z
- **Completed:** 2026-01-24T15:12:01Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Refactored 8 user endpoints to use require_role middleware
- Refactored 2 admin endpoints to use require_role middleware
- Refactored 3 authentication endpoints to use auth service layer
- Reduced duplicated role check code from 119 lines to 32 lines (73% reduction)
- Maintained backward compatibility in authentication endpoints

## Task Commits

Each task was committed atomically:

1. **Task 1: Capture baseline responses for user endpoints** - `54216df` (docs)
2. **Task 2: Refactor user_endpoints.R to use middleware** - `8b9609c` (refactor)
3. **Task 3: Refactor admin_endpoints.R and authentication_endpoints.R** - `331cbeb` (refactor)

**Plan metadata:** (to be committed separately)

## Files Created/Modified

### api/endpoints/user_endpoints.R
- Added require_role middleware import
- Refactored 8 endpoints to use require_role:
  - GET /table: Curator+ (Admin sees all, Curator sees unapproved)
  - GET /<user_id>/contributions: Reviewer+
  - PUT /approval: Curator+
  - PUT /change_role: Curator+
  - GET /role_list: Curator+
  - GET /list: Curator+
  - DELETE /delete: Administrator
  - PUT /update: Administrator
- Kept password/update complex self-vs-admin logic inline (deferred)
- Reduced role check count from 17 to 11 (8 require_role + 3 differentiation)

### api/endpoints/admin_endpoints.R
- Added require_role middleware import
- Refactored 2 endpoints to use require_role:
  - PUT /update_ontology: Administrator
  - PUT /update_hgnc_data: Administrator
- Reduced manual role checks from 8 lines to 2 require_role calls

### api/endpoints/authentication_endpoints.R
- Added auth-service.R import
- Refactored 3 endpoints to use auth service:
  - GET /authenticate: Uses auth_signin service
  - GET /signin: Uses auth_verify service
  - GET /refresh: Uses auth_refresh service
- Maintained backward compatibility (return JWT string, not structured response)
- Reduced inline authentication logic from 90+ lines to 3 service calls

## Decisions Made

**1. Keep password/update endpoint inline logic**
- **Rationale:** Complex self-vs-admin authorization logic doesn't fit cleanly into require_role pattern. Deferred to later service layer refactoring.

**2. Maintain backward compatibility in auth endpoints**
- **Rationale:** auth service returns structured response (access_token, refresh_token, user info), but existing endpoints return plain JWT string. Maintained compatibility by extracting access_token from service response.

**3. Use require_role for simple checks, keep == checks for differentiation**
- **Rationale:** require_role enforces minimum role requirement. When endpoints need differentiated behavior (e.g., Admin sees all, Curator sees subset), keep explicit == checks after require_role.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for next batch of endpoint refactoring:**
- User, admin, and authentication endpoints successfully migrated
- Pattern established for require_role usage
- Pattern established for service layer integration
- Backward compatibility maintained

**Next batches (22-07, 22-08, 22-09):**
- Entity endpoints refactoring
- Review/status endpoints refactoring
- Specialized endpoints refactoring

**No blockers or concerns.**

---
*Phase: 22-service-layer-middleware*
*Completed: 2026-01-24*
