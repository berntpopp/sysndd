# Phase 52: User Lifecycle E2E - Context

**Gathered:** 2026-01-30
**Status:** Ready for planning

<domain>
## Phase Boundary

End-to-end verification that user registration, email confirmation, and password reset flows work completely using the Mailpit infrastructure from Phase 51. The flows themselves already exist — this phase writes E2E tests that verify they work correctly.

</domain>

<decisions>
## Implementation Decisions

### Test Structure
- Single comprehensive file: `test-e2e-user-lifecycle.R` with sections for registration, confirmation, and password reset
- Skip by default using `skip_if_no_mailpit()` — tests skip gracefully when Mailpit isn't running
- Use actual HTTP requests via httr2 to call API endpoints — true end-to-end verification
- Test naming: research best practices and repo conventions (Claude's discretion based on findings)

### Token Extraction
- Use regex on email body to extract token from URL — simple and portable
- Create reusable helper function `extract_token_from_email()` in helper-mailpit.R
- Verify token format (length, characters) before using — aids debugging when things go wrong
- Extract by URL pattern (e.g., `/confirm?token=`) to handle emails with multiple links

### Test User Cleanup
- Cleanup after each test — tests leave no trace in database
- Create helper with auto-cleanup using `withr::defer()` — cleanup runs automatically
- Email domain: research best practices for test email domains (Claude's discretion to avoid paid services or accidental real emails)
- Always cleanup even if test fails — use `withr::defer()` or `on.exit()` for guaranteed execution

### Failure Scenarios
- Include failure scenario tests — test invalid tokens, expired links, duplicate registration
- Test both token failures (invalid/expired) AND duplicate registration attempts
- Verify error status codes only (not specific message content) — less brittle
- Verify that failed operations don't send emails — assert Mailpit inbox empty after failures

### Claude's Discretion
- Test naming convention after researching repo patterns
- Safe test email domain after researching best practices
- Exact regex patterns for token extraction from email body
- Order of test cases within the comprehensive test file

</decisions>

<specifics>
## Specific Ideas

- Use Phase 51's Mailpit helpers as foundation — `mailpit_available()`, `mailpit_wait_for_message()`, `mailpit_delete_all()`
- Security-conscious: verify failed operations don't accidentally send emails
- Test isolation: each test should be independent with its own user and cleanup

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 52-user-lifecycle-e2e*
*Context gathered: 2026-01-30*
