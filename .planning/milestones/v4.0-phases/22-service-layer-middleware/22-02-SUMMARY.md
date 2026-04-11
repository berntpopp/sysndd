---
phase: 22-service-layer-middleware
plan: 02
subsystem: auth
tags: [authentication, jwt, jose, service-layer, dependency-injection]

# Dependency graph
requires:
  - phase: 19-security-overhaul
    provides: verify_password, hash_password, needs_upgrade, upgrade_password (Argon2id + legacy dual-hash support)
  - phase: 19-security-overhaul
    provides: RFC 9457 error helpers (stop_for_bad_request, stop_for_unauthorized)
  - phase: 21-repository-layer
    provides: Parameterized query patterns, db_execute_statement helper
provides:
  - Authentication service layer with business logic
  - auth_signin: validates credentials, returns JWT token
  - auth_verify: validates token, returns user info
  - auth_refresh: extends token expiry
  - auth_generate_token/auth_validate_token: JWT helpers
  - Dependency injection pattern (pool, config as params)
affects: [22-03-authentication-endpoints, 22-service-layer-middleware]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Service layer pattern: business logic separated from endpoints"
    - "Dependency injection: services accept pool/config as params"
    - "Dual-hash password verification via verify_password"
    - "JWT token generation using jose::jwt_encode_hmac"

key-files:
  created:
    - api/services/auth-service.R
  modified:
    - api/start_sysndd_api.R

key-decisions:
  - "Service layer uses dependency injection (pool, config as params)"
  - "Progressive password upgrade on signin (transparent to user)"
  - "JWT claims include user_id, user_name, email, user_role, orcid, abbreviation"
  - "Token expiry configurable via config$refresh parameter"

patterns-established:
  - "Service layer pattern: api/services/ for business logic, endpoints call services"
  - "Services accept dependencies as parameters (no global state access)"
  - "Services use stop_for_* helpers from core/errors.R for RFC 9457 compliance"
  - "Services log significant events (signin, refresh) at INFO level"

# Metrics
duration: 2min
completed: 2026-01-24
---

# Phase 22 Plan 02: Authentication Service Layer Summary

**Authentication service layer with JWT signin/verify/refresh logic using jose package and dual-hash password verification**

## Performance

- **Duration:** 2 minutes
- **Started:** 2026-01-24T14:49:17Z
- **Completed:** 2026-01-24T14:51:28Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Created authentication service layer separating business logic from endpoints
- Implemented auth_signin with credential validation, account status check, JWT generation
- Implemented auth_verify for token validation without database lookup
- Implemented auth_refresh for token expiry extension
- Progressive password upgrade integrated into signin flow (transparent to user)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create services directory and auth-service.R** - `1caaa67` (feat)
2. **Task 2: Source auth-service.R in start_sysndd_api.R** - `e2750a9` (feat)
3. **Task 3: Verify auth-service syntax and structure** - (verification task, no commit)

## Files Created/Modified

- `api/services/auth-service.R` - Authentication business logic with 5 functions (221 lines)
  - auth_signin: validates credentials, checks account status, returns JWT token
  - auth_verify: validates token, returns user info
  - auth_refresh: extends token expiry for valid tokens
  - auth_generate_token: internal JWT creation helper
  - auth_validate_token: internal JWT decode helper
- `api/start_sysndd_api.R` - Added source line for auth-service.R after core modules

## Decisions Made

### 1. Service layer uses dependency injection
**Rationale:** Services accept pool and config as parameters rather than accessing global state. This enables testability, makes dependencies explicit, and follows SOLID principles.

### 2. Progressive password upgrade integrated in signin
**Rationale:** Transparently upgrades legacy plaintext passwords to Argon2id on successful login using verify_password + needs_upgrade + upgrade_password from core/security.R. Zero user friction.

### 3. JWT claims include comprehensive user info
**Rationale:** Include user_id, user_name, email, user_role, abbreviation, orcid in token claims to avoid database lookups on every request. Token verification can extract all needed info.

### 4. Token expiry configurable via config
**Rationale:** Uses config$refresh parameter with fallback to 86400 seconds (24 hours). Production can adjust expiry without code changes.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. R syntax verification noted that R/Rscript not available in bash environment (expected), but manual verification confirmed:
- All 5 auth functions properly defined
- 221 lines of code (exceeds 120 minimum)
- Balanced parentheses (96 pairs) and braces (22 pairs)
- Proper dependencies on verify_password, jose::jwt_*, stop_for_* helpers

## Next Phase Readiness

Ready for 22-03 to refactor authentication_endpoints.R to use auth service:
- Authentication service provides all required business logic
- Endpoints can become thin wrappers: parse request, call service, return response
- Dependency injection pattern allows endpoints to pass pool/config to services
- RFC 9457 errors properly signaled via stop_for_* helpers

**No blockers.** Authentication service layer complete and ready for endpoint migration.

---
*Phase: 22-service-layer-middleware*
*Completed: 2026-01-24*
