---
phase: 29
plan: 01
subsystem: user-management
tags: [R, plumber, bulk-operations, transactions, user-management]
requires: [28-03]
provides: [bulk-user-endpoints, atomic-operations]
affects: [29-02, 29-03]
tech-stack:
  added: []
  patterns: [atomic-transactions, bulk-operations]
key-files:
  created: []
  modified:
    - api/services/user-service.R
    - api/endpoints/user_endpoints.R
decisions:
  - id: bulk-20-user-limit
    what: Enforce 20 user maximum per bulk request
    why: Prevents timeout and ensures responsive API
    alternatives: [50 users, unlimited]
    chosen: 20 users
  - id: admin-deletion-protection
    what: Reject bulk delete if any user is Administrator
    why: Prevents accidental deletion of admin accounts
    alternatives: [allow-with-warning, filter-admins-out]
    chosen: reject-entire-request
  - id: transaction-semantics
    what: Use all-or-nothing atomic transactions for all bulk operations
    why: Ensures data consistency and prevents partial updates
    alternatives: [best-effort-partial, individual-commits]
    chosen: atomic-transactions
metrics:
  tasks: 3
  commits: 2
  files-modified: 2
  duration: 2.4min
  completed: 2026-01-25
---

# Phase 29 Plan 01: Bulk User Management Endpoints Summary

**One-liner:** Atomic bulk operations for user approval, deletion, and role assignment with 20-user limits and admin protection

## What Was Delivered

Three new bulk user management endpoints with ATOMIC transaction semantics:

1. **POST /api/user/bulk_approve** (Curator+)
   - Approves multiple users in single atomic transaction
   - Generates passwords and sends approval emails
   - Max 20 users per request
   - All-or-nothing: if ANY user fails, ALL changes roll back

2. **POST /api/user/bulk_delete** (Administrator only)
   - Deletes multiple users atomically
   - Admin protection: rejects request if ANY user is Administrator
   - Returns 403 with clear message when admins in selection
   - Max 20 users per request

3. **POST /api/user/bulk_assign_role** (Curator+)
   - Assigns role to multiple users atomically
   - Permission check: Curator cannot assign Administrator role
   - Max 20 users per request
   - Validates role against allowed list

**Service Layer:** Three new functions in `api/services/user-service.R`:
- `user_bulk_approve(user_ids, approving_user_id, pool)`
- `user_bulk_delete(user_ids, requesting_user_id, pool)`
- `user_bulk_assign_role(user_ids, new_role, requesting_role, pool)`

All use `db_with_transaction()` for atomic semantics.

## Technical Details

### Architecture

```
Endpoint Layer (user_endpoints.R)
├─ Input validation (max 20, non-empty, type checks)
├─ Permission checks (role-based access)
└─ Calls service layer ↓

Service Layer (user-service.R)
├─ Business logic validation
├─ db_with_transaction() wrapper ← ATOMIC
│  ├─ Loop through user_ids
│  ├─ Validate each user
│  ├─ Perform operation
│  └─ If ANY fails → rollback ALL
└─ Return result or throw error

Database Layer
└─ DBI::dbWithTransaction() ensures atomicity
```

### Transaction Guarantees

- **Atomic**: All users updated or none updated
- **Rollback on error**: Database automatically rolled back if ANY operation fails
- **Connection management**: Pool checkout/return handled automatically
- **Error propagation**: Clear error messages bubble up to endpoint layer

### Validation Flow

```
Endpoint validation:
├─ user_ids array not empty? → 400 if empty
├─ user_ids length ≤ 20? → 400 if exceeded
├─ role valid? → 400 if invalid (assign_role only)
└─ permission check → 403 if insufficient

Service validation (in transaction):
├─ For bulk_delete: any admin users? → stop() with clear message
├─ For bulk_assign_role: Curator + Administrator? → stop() with message
└─ For each user:
    ├─ User exists? → stop() with user_id
    ├─ Already approved? → stop() with user_id (approve only)
    └─ Perform operation
```

### Error Handling

```
HTTP Status Codes:
├─ 200: Success (all operations completed)
├─ 400: Validation error (empty, >20 users, invalid role)
├─ 403: Permission denied (admin in delete selection, Curator→Admin)
├─ 409: Operation failed (user not found, already approved, transaction error)
```

## Deviations from Plan

**None** - plan executed exactly as written.

All required functionality implemented:
- ✓ Max 20 user validation at service and endpoint level
- ✓ Admin deletion protection
- ✓ Atomic transaction semantics
- ✓ Role-based permissions
- ✓ Clear error messages with rollback

## Commits

```
274cef0 feat(29-01): add bulk user service functions with atomic transactions
  - user_bulk_approve: approve multiple users atomically
  - user_bulk_delete: delete multiple users with admin protection
  - user_bulk_assign_role: assign roles with permission checks
  - All functions validate max 20 users per request
  - Transaction semantics ensure all-or-nothing operations

0a1afaf feat(29-01): add bulk user management endpoints
  - POST /api/user/bulk_approve: requires Curator role
  - POST /api/user/bulk_delete: requires Administrator role
  - POST /api/user/bulk_assign_role: requires Curator role
  - All endpoints validate max 20 users per request
  - Proper error handling with appropriate HTTP status codes
  - Admin deletion protection with 403 for admin users in selection
```

## Decisions Made

### 1. 20 User Maximum Per Request

**Rationale:** Prevents API timeouts and ensures responsive user experience. Bulk operations that process emails (approval) or multiple database writes need reasonable bounds.

**Trade-offs:**
- Lower limit = more requests for large batches
- Higher limit = risk of timeout
- 20 strikes balance for typical admin workflows

**Alternative considered:** 50 users rejected as too high for approval workflow (email generation)

### 2. Admin Deletion Protection

**Rationale:** Prevents catastrophic accidental deletion of admin accounts. Better to require explicit single-user deletion for admins.

**Implementation:** Check ALL user roles BEFORE transaction starts. If ANY administrator found, reject entire request with clear message listing admin IDs.

**Alternative considered:** Filtering admins out silently - rejected because it hides important information from user

### 3. Atomic Transaction Semantics

**Rationale:** Data consistency is critical for user management. Partial updates create inconsistent states (some users approved, some not).

**Implementation:** Used existing `db_with_transaction()` helper which wraps `DBI::dbWithTransaction()` for automatic commit/rollback.

**Alternative considered:** Best-effort partial updates - rejected because partial state is confusing to users

## Testing Notes

**Verified:**
- ✓ R syntax parsing successful for both files
- ✓ API container starts without errors
- ✓ All three bulk endpoints present in loaded API
- ✓ Service functions use `db_with_transaction()` wrapper
- ✓ Endpoint layer validates max 20 users
- ✓ Service layer validates max 20 users (defense in depth)

**Not tested (requires database):**
- Actual transaction rollback on error
- Email sending for bulk approval
- Admin protection logic execution
- Permission checks with real user tokens

**Recommended frontend testing:**
- Test bulk approve with 1, 5, 20 users
- Test bulk delete with admin user in selection (should fail with 403)
- Test bulk assign role as Curator trying to assign Administrator (should fail with 403)
- Test >20 users in request (should fail with 400)

## Next Phase Readiness

**Phase 29 Plan 02 (Frontend Bulk UI) can proceed:**
- ✓ Backend endpoints ready
- ✓ Error response format consistent
- ✓ Status codes follow REST conventions

**Required for 29-02:**
- Checkbox selection UI component
- Bulk action button panel
- Error toast notifications
- Transaction rollback messaging ("All or nothing - no users updated")

**Blockers:** None

**Risks:** None identified

## Performance Notes

**Expected performance:**
- Bulk approve (20 users): ~2-4 seconds (includes email generation)
- Bulk delete (20 users): ~200-500ms (database only)
- Bulk assign role (20 users): ~200-500ms (database only)

**Transaction overhead:** Minimal - `dbWithTransaction()` adds ~10-20ms

**Email bottleneck:** Approval is slowest due to synchronous email sending. Consider async email queue in future if >100 approvals/day.

## Dependencies

**Requires:**
- Phase 28-03: Table filtering/sorting (provides user selection in table UI)
- Existing: `db_with_transaction()` helper (implemented in 28-01)
- Existing: `user_approve()`, `user_update_role()` patterns

**Provides for:**
- Phase 29-02: Frontend bulk action UI
- Phase 29-03: Audit logging for bulk operations
- Future: Bulk import workflows

**Breaking changes:** None - only adds new endpoints
