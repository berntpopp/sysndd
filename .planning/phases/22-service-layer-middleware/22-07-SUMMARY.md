---
phase: 22
plan: 07
subsystem: endpoint-refactoring
tags: [middleware, authorization, service-layer, entity, review, status]
requires: [22-01, 22-03, 22-04, 22-05]
provides: [entity-endpoint-middleware, review-endpoint-middleware, status-endpoint-middleware]
affects: [22-08, 22-09]
tech-stack:
  added: []
  patterns: [require_role-helper, service-layer-delegation]
key-files:
  created: []
  modified:
    - api/endpoints/entity_endpoints.R
    - api/endpoints/review_endpoints.R
    - api/endpoints/status_endpoints.R
decisions:
  - name: "Remove inline authorization from endpoints"
    rationale: "Middleware provides consistent authorization, eliminates duplicated role checks"
    date: 2026-01-24
  - name: "Delegate approval operations to service layer"
    rationale: "Service layer provides batch operation support and consistent business logic"
    date: 2026-01-24
metrics:
  duration: 2 minutes
  completed: 2026-01-24
---

# Phase 22 Plan 07: Core Data Endpoint Refactoring Summary

**One-liner:** Migrated entity/review/status endpoints from inline authorization to require_role middleware and service layer

## What Was Delivered

Refactored core data endpoints (entity, review, status) to use centralized middleware and service layer patterns, eliminating duplicated authorization code across 3 endpoint files.

### Endpoint Migrations

**entity_endpoints.R** (3 endpoints refactored):
- POST /create → require_role("Curator")
- POST /rename → require_role("Curator")
- POST /deactivate → require_role("Curator")
- Removed: 3 inline `req$user_role %in% c("Administrator", "Curator")` checks
- Removed: 3 "Write access forbidden" error blocks

**review_endpoints.R** (2 endpoints refactored):
- POST /create, PUT /update → require_role("Reviewer")
- PUT /approve → require_role("Curator") + svc_approval_review_approve()
- Removed: 2 inline authorization checks
- Removed: 2 manual auth error blocks
- Added: Service layer call for approval workflow

**status_endpoints.R** (2 endpoints refactored):
- POST /create, PUT /update → require_role("Reviewer")
- PUT /approve → require_role("Curator") + svc_approval_status_approve()
- Removed: 2 inline authorization checks
- Removed: 2 manual auth error blocks
- Added: Service layer call for approval workflow

### Code Quality Improvements

**Before:**
```r
if (req$user_role %in% c("Administrator", "Curator")) {
  # 20+ lines of business logic
} else {
  res$status <- 403
  return(list(error = "Write access forbidden."))
}
```

**After:**
```r
require_role(req, res, "Curator")
# Business logic (no else block needed)
```

**Metrics:**
- 7 endpoints refactored
- 7 inline authorization checks eliminated
- 7 error handling blocks removed
- 2 service layer calls added (approval operations)
- ~70 lines of duplicated code eliminated

## Decisions Made

### 1. Remove inline authorization from endpoints

**Context:** Entity, review, and status endpoints had duplicated role checks using `req$user_role %in% c("Administrator", "Curator")` pattern.

**Decision:** Replace all inline authorization with require_role() helper calls.

**Rationale:**
- Centralized authorization logic in middleware.R (single source of truth)
- Consistent error messages across all endpoints
- Easier to audit security posture (grep for require_role)
- Eliminates role list duplication (was in 7+ places)

**Impact:** All write endpoints now use middleware pattern, GET endpoints remain public.

### 2. Delegate approval operations to service layer

**Context:** Review and status approval endpoints called repository functions directly.

**Decision:** Use svc_approval_review_approve() and svc_approval_status_approve() from approval-service.R.

**Rationale:**
- Service layer handles batch operations ("all" parameter)
- Consistent business logic (already implemented in 22-04)
- Enables future enhancements (e.g., approval notifications) without endpoint changes
- Maintains dependency injection pattern (pool as parameter)

**Impact:** Approval endpoints now follow same pattern as other refactored endpoints.

## Technical Implementation

### Authorization Pattern

**Role hierarchy enforcement:**
```r
# From middleware.R
role_levels <- c(
  "Viewer" = 1,
  "Reviewer" = 2,
  "Curator" = 3,
  "Administrator" = 4
)
```

**Endpoint usage:**
- Create/update operations: Reviewer+ (levels 2-4)
- Approval operations: Curator+ (levels 3-4)
- Deactivation operations: Curator+ (levels 3-4)

### Service Layer Integration

**Approval workflow (review_endpoints.R):**
```r
# Before
response_review_approve <- put_db_review_approve(
  review_id_requested,
  submit_user_id,
  review_ok
)

# After
response_review_approve <- svc_approval_review_approve(
  review_id_requested,
  submit_user_id,
  review_ok,
  pool
)
```

**Benefits:**
- Batch operation support (pass "all" to approve all pending)
- Consistent error handling
- Transaction management in service layer
- Pool parameter for dependency injection

## Testing & Verification

### Verification Commands

```bash
# Confirm require_role usage
grep -c "require_role" api/endpoints/entity_endpoints.R  # Expected: 3
grep -c "require_role" api/endpoints/review_endpoints.R  # Expected: 2
grep -c "require_role" api/endpoints/status_endpoints.R  # Expected: 2

# Confirm old pattern eliminated
grep -c "req\$user_role %in%" api/endpoints/*.R  # Expected: 0

# Confirm service layer calls
grep "svc_approval" api/endpoints/review_endpoints.R  # 1 call
grep "svc_approval" api/endpoints/status_endpoints.R  # 1 call
```

### Baseline vs After

**Authorization behavior unchanged:**
- Entity create/rename/deactivate: Still requires Curator+
- Review create/update: Still requires Reviewer+
- Review approve: Still requires Curator+
- Status create/update: Still requires Reviewer+
- Status approve: Still requires Curator+
- GET operations: Still public (no auth required)

**Error responses unchanged:**
- 403 Forbidden for insufficient role
- Same error message format (via middleware.R error_forbidden())

## Deviations from Plan

None - plan executed exactly as written.

## Commits

| Hash | Message |
|------|---------|
| 9de8b1f | refactor(22-07): migrate entity_endpoints.R to require_role middleware |
| 0db5cc4 | refactor(22-07): migrate review/status endpoints to middleware and service layer |

## Next Phase Readiness

### Ready for 22-08 (Admin Endpoint Refactoring)

**Pattern established:** The require_role + service layer pattern is now proven across 7 endpoints in 3 files. Admin endpoints (user, publication, hash) can follow this exact pattern.

**Service layer complete:** All necessary service functions exist:
- user-service.R: User CRUD and approval
- approval-service.R: Batch approval support
- auth-service.R: Authentication and signup

**Middleware stable:** require_role() handles all authorization scenarios, no changes needed.

### Dependencies Satisfied

**From 22-01:** middleware.R with require_role() helper
**From 22-03:** entity-service.R with validation and duplicate checking
**From 22-04:** approval-service.R with batch operation support
**From 22-05:** status-service.R for re-review workflows

### Blockers/Concerns

None. All endpoints migrated successfully, authorization behavior preserved, no API changes.

---

**Completed:** 2026-01-24
**Phase 22 Progress:** 7 of 9 plans complete
**Subsystem:** Endpoint refactoring (core data operations)
