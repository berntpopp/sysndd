# Phase 51: SMTP Testing Infrastructure - Context

**Gathered:** 2026-01-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Set up Mailpit container for email capture in development and write integration tests that verify existing email functionality (registration confirmation, email verification, password reset) works end-to-end. No new API endpoints — this validates the existing `send_noreply_email()` implementation after v8 refactors.

</domain>

<decisions>
## Implementation Decisions

### Mailpit integration
- Dev profile only (not test profile) — integration tests connect to Mailpit, unit tests mock
- Web UI exposed on port 8025 (standard Mailpit port)
- No persistent storage — emails cleared on container restart
- No dependency from API service — API starts independently, emails fail gracefully if Mailpit unavailable

### Integration testing approach
- Tests verify delivery by querying Mailpit API to confirm emails arrived
- Cover all user email flows: registration confirmation, email verification, password reset
- Clean Mailpit inbox before each test for isolation

### Environment configuration
- ENV-based switching: SMTP_HOST=mailpit in dev, real host in prod (same code path)
- If SMTP unreachable: log error and continue — API operations don't fail
- SMTP_ENABLED=false flag to disable all email sending (useful for CI/unit tests)
- SMTP credentials from .env file (SMTP_HOST, SMTP_USER, SMTP_PASS)

### Admin UI visibility
- No admin UI changes — developers access Mailpit directly at localhost:8025 in dev mode

### Claude's Discretion
- Mailpit container version selection
- Exact Mailpit API calls for test verification
- Test helper structure for Mailpit interactions
- SMTP port configuration (25 vs 587)

</decisions>

<specifics>
## Specific Ideas

- Goal is to verify existing email functionality still works after major v8 refactors
- Dev container uses Mailpit for captured emails
- Prod container uses real SMTP config (manual testing)
- Integration tests serve as regression tests for email sending

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 51-smtp-testing-infrastructure*
*Context gathered: 2026-01-29*
