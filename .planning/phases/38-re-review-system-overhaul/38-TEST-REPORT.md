# Phase 38: Re-Review System Overhaul - Test Report

**Date:** 2026-01-26
**Tester:** Claude (automated testing via curl/API)
**Status:** BUGS FOUND - FIXES APPLIED

## Executive Summary

During post-implementation testing of Phase 38 (Re-Review System Overhaul), two bugs were discovered:

1. **BUG-01 (FIXED)**: SQL query references non-existent column `e.is_active` on `ndd_entity_view`
2. **BUG-02 (NOT FIXED)**: Authentication middleware returns HTTP 500 instead of HTTP 401 for missing auth

## Test Environment

- **API Server:** sysndd_api Docker container (port 7778 → 7777)
- **Database:** sysndd_mysql Docker container (sysndd_db)
- **Frontend:** sysndd_app Docker container (port 5173)

## Bug Details

### BUG-01: SQL Query Uses Non-Existent Column (FIXED)

**Symptom:** POST /api/re_review/batch/preview returns 500 Internal Server Error

**Root Cause:**
The `re-review-service.R` file contained SQL queries that referenced `e.is_active = 1` where `e` is an alias for `ndd_entity_view`. However, the view does not expose the `is_active` column - it only filters internally via:
```sql
WHERE ndd_entity.is_active = 1
```

**Error Message:**
```
Database query failed: Unknown column 'e.is_active' in 'where clause' [1054]
```

**Affected Lines:**
- Line 141: `WHERE e.is_active = 1`
- Line 238: `WHERE e.is_active = 1`
- Line 550: `AND e.is_active = 1`
- Line 720: `WHERE e.is_active = 1`

**Fix Applied:**
Removed all `e.is_active = 1` conditions since the view already filters active entities internally.

```diff
-     WHERE e.is_active = 1
-       AND ", where_clause, "
+     WHERE ", where_clause, "
```

**Verification:**
Direct SQL query against database succeeds:
```sql
SELECT DISTINCT e.entity_id, e.hgnc_id, e.symbol, e.disease_ontology_name,
        e.disease_ontology_id_version, e.hpo_mode_of_inheritance_term_name,
        r.review_date, s.category_id
FROM ndd_entity_view e
LEFT JOIN ndd_entity_review r ON e.entity_id = r.entity_id AND r.is_primary = 1
LEFT JOIN ndd_entity_status s ON e.entity_id = s.entity_id AND s.is_active = 1
WHERE r.review_date >= '2020-01-01' AND r.review_date <= '2022-12-31'
ORDER BY r.review_date ASC
LIMIT 20;
```
Returns 20 matching entities as expected.

---

### BUG-02: Authentication Returns 500 Instead of 401 (NOT FIXED)

**Symptom:** Unauthenticated POST requests return HTTP 500 instead of HTTP 401

**Evidence from Logs:**
```
WARN [2026-01-26 22:53:32] require_auth: Missing authorization header
ERROR [2026-01-26 22:53:32] API error
INFO [2026-01-26 22:53:32] ...;POST;/api/re_review/batch/preview;...;500;0.001
```

**Root Cause Analysis:**
The middleware correctly detects missing auth:
```r
# api/core/middleware.R line 83-88
if (is.null(req$HTTP_AUTHORIZATION)) {
  log_warn("require_auth: Missing authorization header", ...)
  res$status <- 401
  stop(error_unauthorized("Authorization header missing. Please provide a Bearer token."))
}
```

The error handler should catch `http_problem_error`:
```r
# api/start_sysndd_api.R line 387-391
if (inherits(err, "http_problem_error")) {
  res$status <- err$status
  ...
  return(err)
}
```

However, the error is not being properly handled, resulting in 500 instead of 401.

**Possible Causes:**
1. The `httpproblems` package error object doesn't have `status` attribute set correctly
2. The error class inheritance chain is not matching `inherits(err, "http_problem_error")`
3. The error is being caught and re-thrown somewhere before reaching the error handler

**Impact:**
- Cannot test authenticated endpoints via curl without valid credentials
- Frontend testing blocked for batch management features
- All POST/PUT/DELETE endpoints return 500 for missing auth (should be 401)

**Recommended Fix:**
Debug the error object structure in the error handler:
```r
errorHandler <- function(req, res, err) {
  log_debug("Error class:", paste(class(err), collapse=", "))
  log_debug("Error status:", err$status)
  ...
}
```

---

## Test Results Summary

### Endpoints Tested

| Endpoint | Method | Auth Required | Status | Notes |
|----------|--------|---------------|--------|-------|
| /api/entity/?entity_id=1 | GET | No | PASS | Returns entity data |
| /api/auth/authenticate | GET | No | PASS | Returns "User or password wrong" |
| /api/re_review/batch/preview | POST | Yes | FAIL | Returns 500 (BUG-02) |
| /api/re_review/batch/create | POST | Yes | BLOCKED | Cannot test without auth |
| /api/re_review/batch/reassign | PUT | Yes | BLOCKED | Cannot test without auth |
| /api/re_review/batch/recalculate | PUT | Yes | BLOCKED | Cannot test without auth |
| /api/re_review/entities/assign | PUT | Yes | BLOCKED | Cannot test without auth |

### Database Schema Verification

| Table/View | Column | Status |
|------------|--------|--------|
| ndd_entity | is_active | EXISTS (tinyint, default 1) |
| ndd_entity_view | is_active | NOT EXISTS (filtered internally) |
| re_review_entity_connect | re_review_approved | EXISTS |
| re_review_assignment | user_id | EXISTS |

### Service Layer Verification

| Function | Status | Notes |
|----------|--------|-------|
| build_batch_where_clause() | FIXED | Correctly builds WHERE clause |
| build_batch_params() | OK | Matches WHERE clause placeholders |
| batch_preview() | FIXED | Removed e.is_active reference |
| batch_create() | FIXED | Removed e.is_active reference |
| entity_assign() | FIXED | Removed e.is_active reference |
| batch_recalculate() | FIXED | Removed e.is_active reference |

---

## Human Testing Required

Due to BUG-02 blocking API authentication, the following tests require manual execution:

### Test 1: Create Batch with Date Range
1. Login to SysNDD as a Curator user
2. Navigate to Manage Re-Review page
3. Enter date range: 2020-01-01 to 2022-12-31
4. Click "Preview Matching Entities"
5. **Expected:** Preview modal shows ~20 matching entities
6. Click "Create Batch"
7. **Expected:** Success toast, batch appears in assignment table

### Test 2: Gene-Specific Assignment
1. Expand "Assign Specific Genes to User" section
2. Select multiple entities from the table
3. Select a user from dropdown
4. Click "Assign N Entities to User"
5. **Expected:** New batch created with selected entities assigned to user

### Test 3: Batch Recalculation
1. Find an unassigned batch in the table
2. Click calculator icon to open recalculate modal
3. Enter new criteria
4. Click "Recalculate"
5. **Expected:** Batch entity count updates

### Test 4: Batch Reassignment
1. Find an assigned batch
2. Click reassign icon
3. Select new user
4. Click "Reassign"
5. **Expected:** Batch assignment changes to new user

---

## Files Modified

1. **api/services/re-review-service.R**
   - Removed 4 instances of `e.is_active = 1` condition
   - View already filters active entities

## Recommendations

1. **Immediate:** Fix BUG-02 authentication error handling to enable API testing
2. **Before Release:** Complete manual testing of all batch management features
3. **Future:** Add integration tests for re-review endpoints with mocked authentication

---

*Report generated: 2026-01-26*
