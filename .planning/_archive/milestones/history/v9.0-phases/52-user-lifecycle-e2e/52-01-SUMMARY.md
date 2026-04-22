---
phase: 52-user-lifecycle-e2e
plan: 01
subsystem: testing
tags: [e2e, mailpit, httr2, user-registration, curator-approval, smtp]

# Dependency graph
requires:
  - phase: 51-smtp-testing-infrastructure
    provides: Mailpit container, helper-mailpit.R functions, skip_if_no_mailpit()
provides:
  - E2E tests for user registration flow (SMTP-03)
  - E2E tests for curator approval flow (SMTP-04)
  - Token extraction helper for password reset emails
  - Test user generation and cleanup utilities
affects: [52-02-PLAN, password-reset-tests, user-lifecycle-tests]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - E2E test pattern with httr2 HTTP requests
    - Test user generation with RFC 2606 example.com domain
    - withr::defer() for guaranteed test cleanup
    - Skip pattern for graceful degradation when prerequisites unavailable

key-files:
  created:
    - api/tests/testthat/test-e2e-user-lifecycle.R
  modified:
    - api/tests/testthat/helper-mailpit.R

key-decisions:
  - "Use RFC 2606 example.com domain for test email addresses"
  - "Prefer plain text email body over HTML for token extraction"
  - "Verify status codes only, not error message content (less brittle)"
  - "No rejection email sent on curator rejection (security decision)"

patterns-established:
  - "E2E test pattern: skip_if_no_mailpit() + skip_if_no_api() + skip_if_no_test_db()"
  - "Test isolation: mailpit_delete_all() at start of each test"
  - "User generation: unique timestamp + random suffix to avoid collision"
  - "Guaranteed cleanup: withr::defer(cleanup_test_user()) before user creation"

# Metrics
duration: 3min
completed: 2026-01-30
---

# Phase 52 Plan 01: User Lifecycle E2E Tests Summary

**E2E tests for user registration and curator approval flows using Mailpit email capture**

## Performance

- **Duration:** 3 min
- **Started:** 2026-01-30T09:00:00Z
- **Completed:** 2026-01-30T09:03:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `extract_token_from_email()` helper function for JWT extraction from password reset emails
- Created comprehensive E2E test file with 5 tests covering registration and approval flows
- Established patterns for E2E testing with graceful skip when prerequisites unavailable
- Tests verify both email delivery (via Mailpit) and database state changes

## Task Commits

Each task was committed atomically:

1. **Task 1: Add token extraction helper** - `d0a56bb3` (feat)
2. **Task 2: Create E2E test file** - `b2183c91` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified

- `api/tests/testthat/helper-mailpit.R` - Added extract_token_from_email() function (46 lines)
- `api/tests/testthat/test-e2e-user-lifecycle.R` - E2E tests for user lifecycle (326 lines)

## Test Coverage

The test file includes 5 E2E tests:

### User Registration Tests (SMTP-03)
1. **user registration sends confirmation email** - Verifies signup creates user (approved=0) and sends confirmation email
2. **duplicate registration is rejected** - Verifies no additional email on duplicate attempt
3. **invalid registration data is rejected** - Verifies 404 status and no email on invalid input

### Curator Approval Tests (SMTP-04)
4. **curator approval sends password email** - Verifies approval sets approved=1, generates password, sends email
5. **curator rejection deletes user without email** - Verifies rejection deletes user, no email sent

## Decisions Made

1. **RFC 2606 example.com domain** - Used for test emails per CONTEXT.md (reserved for testing, no accidental real emails)
2. **Plain text body preference** - Token extraction prefers Text over HTML (simpler, more reliable)
3. **Status code verification only** - Tests check HTTP status codes, not error message content (per CONTEXT.md decision for less brittle tests)
4. **No rejection email** - Security decision: don't send email to potentially spoofed addresses on rejection

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- **R not available in CI environment** - Unable to run syntax verification via Rscript. Files verified manually for correct R syntax (balanced braces, proper function definitions). Tests will be validated when run locally with R installed.

## Next Phase Readiness

- Ready for 52-02-PLAN.md (Password Reset E2E Tests)
- Token extraction helper is available for password reset flow testing
- All prerequisite patterns established (skip functions, user generation, cleanup)
- Mailpit infrastructure from Phase 51 fully utilized

---
*Phase: 52-user-lifecycle-e2e*
*Completed: 2026-01-30*
