# Phase 52: User Lifecycle E2E - Research

**Researched:** 2026-01-30
**Domain:** User registration, email confirmation, and password reset E2E testing
**Confidence:** HIGH

## Summary

This phase focuses on writing end-to-end tests for the user lifecycle flows (registration, email confirmation, password reset) using the Mailpit infrastructure established in Phase 51. The existing codebase provides all the building blocks:

- **User endpoints** are fully implemented in `authentication_endpoints.R` (signup) and `user_endpoints.R` (password reset request/change)
- **Mailpit helpers** from Phase 51 provide `mailpit_wait_for_message()`, `mailpit_delete_all()`, `mailpit_search()`, and `mailpit_get_message()`
- **Database helpers** exist for test isolation via transactions or direct cleanup

Key insight: The signup flow does NOT require email confirmation to activate accounts. Instead, users register (receive confirmation email), then a curator manually approves them. This is different from a typical email-verified signup flow. However, password reset DOES use a JWT token sent via email.

**Primary recommendation:** Create `test-e2e-user-lifecycle.R` with tests for signup (SMTP-03), approval flow (SMTP-04 analog), and password reset (SMTP-05), using httr2 for HTTP calls and the existing Mailpit helpers for email verification.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| testthat | 3.x | Test framework | Standard R testing framework, already in use |
| httr2 | 1.x | HTTP requests | Modern HTTP client, already used in Mailpit helpers |
| withr | 2.x | Test cleanup | Provides `withr::defer()` for guaranteed cleanup |
| jose | 1.x | JWT handling | Already used for token generation in auth tests |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jsonlite | 1.8+ | JSON parsing | For encoding signup data and parsing responses |
| stringr | 1.5+ | String manipulation | For token extraction regex |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| httr2 | curl | httr2 is more modern, already used in codebase |
| regex token extraction | HTML parsing | Regex is simpler, portable, per CONTEXT.md decision |

**Installation:**
All packages already available in the project's renv lockfile.

## Architecture Patterns

### Recommended Project Structure
```
api/tests/testthat/
├── helper-mailpit.R          # Existing - add extract_token_from_email()
├── helper-db.R               # Existing - has get_test_db_connection()
├── helper-auth.R             # Existing - has create_test_jwt()
└── test-e2e-user-lifecycle.R # NEW - comprehensive E2E tests
```

### Pattern 1: Test with Automatic Cleanup
**What:** Use `withr::defer()` to ensure test users are deleted even on test failure
**When to use:** All tests that create database records
**Example:**
```r
# Source: Codebase convention from helper-db.R pattern
test_that("user registration sends confirmation email", {
  skip_if_no_mailpit()
  skip_if_no_test_db()

  # Clean Mailpit inbox first
  mailpit_delete_all()

  # Generate unique test user data
  test_email <- paste0("test-", format(Sys.time(), "%Y%m%d%H%M%S"), "@example.com")
  test_username <- paste0("testuser", floor(runif(1, 10000, 99999)))

  # Register cleanup BEFORE creating user
  withr::defer({
    # Delete test user from database
    con <- get_test_db_connection()
    DBI::dbExecute(con, "DELETE FROM user WHERE email = ?", list(test_email))
    DBI::dbDisconnect(con)
  })

  # Now create user via API call...
})
```

### Pattern 2: Token Extraction from Email
**What:** Extract JWT or verification tokens from email body using regex
**When to use:** Password reset and any token-based email verification
**Example:**
```r
# Source: CONTEXT.md decision - regex on email body, extract by URL pattern
extract_token_from_email <- function(message_id, pattern = "/PasswordReset/([^\\s\"<>]+)") {
  # Fetch full message content
  full_message <- mailpit_get_message(message_id)

  # Get text body (prefer plain text over HTML)
  email_body <- full_message$Text %||% full_message$HTML

  # Extract token using regex
  match <- regmatches(email_body, regexpr(pattern, email_body, perl = TRUE))

  if (length(match) == 0 || match == "") {
    stop("Could not extract token from email body")
  }

  # Extract just the token part (group 1)
  token <- sub(pattern, "\\1", match)

  # Validate token format - JWT has 3 parts separated by dots
  if (!grepl("^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$", token)) {
    stop("Extracted token does not appear to be a valid JWT format")
  }

  token
}
```

### Pattern 3: API Request Pattern with httr2
**What:** Make HTTP requests to API endpoints using httr2
**When to use:** All E2E API calls
**Example:**
```r
# Source: Existing pattern from test-integration-email.R
make_api_request <- function(method, endpoint, body = NULL, token = NULL) {
  base_url <- get_test_config()$api_base_url

  req <- httr2::request(paste0(base_url, endpoint))

  if (!is.null(body)) {
    req <- req |>
      httr2::req_body_json(body)
  }

  if (!is.null(token)) {
    req <- req |>
      httr2::req_headers(Authorization = paste("Bearer", token))
  }

  req |>
    httr2::req_method(method) |>
    httr2::req_error(is_error = function(resp) FALSE) |>  # Don't error on 4xx/5xx
    httr2::req_perform()
}
```

### Anti-Patterns to Avoid
- **Hardcoding test data:** Use unique timestamps/random IDs to avoid collisions
- **Skipping cleanup on failure:** Always use `withr::defer()` not manual cleanup at end
- **Testing in production database:** Always use test database (port 7655)
- **Asserting on error message text:** Per CONTEXT.md, verify status codes only

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Waiting for email | Polling loop | `mailpit_wait_for_message()` | Already handles timeout, polling interval |
| JWT generation | Manual encoding | `create_test_jwt()` from helper-auth.R | Already matches production format |
| DB connection | Raw DBI calls | `get_test_db_connection()` | Handles config lookup, connection |
| Test skipping | `skip()` | `skip_if_no_mailpit()`, `skip_if_no_test_db()` | Provides clear skip messages |

**Key insight:** Phase 51 already built the Mailpit infrastructure. Use the existing helpers rather than reimplementing.

## Common Pitfalls

### Pitfall 1: Signup Flow Misconception
**What goes wrong:** Assuming signup sends an "activation" email that must be clicked to enable account
**Why it happens:** Common pattern in other systems, but SysNDD uses curator approval
**How to avoid:** Understand the actual flow:
1. User calls `/api/authentication/signup` with JSON data
2. System inserts user with `approved=0`, sends "your request was received" email
3. Curator manually approves via `/api/user/approval` endpoint
4. Approval generates password and sends "account approved" email
**Warning signs:** Tests failing because account can't login after registration (need curator approval)

### Pitfall 2: Password Reset Token Extraction
**What goes wrong:** Token extraction fails because URL is HTML-encoded or spans multiple lines
**Why it happens:** Email body format varies (plain text vs HTML), URLs may be wrapped
**How to avoid:**
- Prefer plain text body (`$Text`) over HTML
- Use flexible regex that handles URL encoding
- Validate extracted token format before use
**Warning signs:** `regexpr()` returns -1, token contains `&amp;` or `%20`

### Pitfall 3: Test Isolation Failure
**What goes wrong:** Tests interfere with each other when run in parallel or after failures
**Why it happens:** Test user not cleaned up, Mailpit inbox contains stale messages
**How to avoid:**
- Delete Mailpit inbox at start of each test with `mailpit_delete_all()`
- Use unique email addresses with timestamps
- Register cleanup with `withr::defer()` BEFORE creating test data
**Warning signs:** Test passes alone but fails in suite, flaky tests

### Pitfall 4: API Endpoint Path Confusion
**What goes wrong:** Requests fail with 404 because endpoint path is wrong
**Why it happens:** Endpoints defined with different paths than expected
**How to avoid:** Use exact paths from endpoint files:
- Signup: `GET /api/authentication/signup?signup_data=...` (JSON-encoded query param)
- Password reset request: `PUT /api/user/password/reset/request?email_request=...`
- Password reset change: `GET /api/user/password/reset/change` with Bearer token
**Warning signs:** 404 responses, "endpoint not found" errors

### Pitfall 5: SMTP Password Environment Variable
**What goes wrong:** Email sending fails because SMTP_PASSWORD not set
**Why it happens:** The `send_noreply_email()` function uses `creds_envvar()` which reads `SMTP_PASSWORD`
**How to avoid:** Set environment variable in test: `withr::local_envvar(SMTP_PASSWORD = "test")`
**Warning signs:** Authentication error from blastula, SMTP connection refused

## Code Examples

Verified patterns from official sources:

### User Registration (Signup)
```r
# Source: api/endpoints/authentication_endpoints.R lines 45-106
# Signup endpoint: GET /api/authentication/signup?signup_data=<JSON>

# Required fields in signup JSON:
signup_data <- list(
  user_name = "testuser12345",      # 5-20 chars
  first_name = "Test",              # 2-50 chars
  family_name = "User",             # 2-50 chars
  email = "test@example.com",       # Valid email format
  orcid = "0000-0000-0000-0001",    # Format: NNNN-NNNN-NNNN-NNNX
  comment = "This is a test user registration comment",  # 10-250 chars
  terms_agreed = "accepted"         # Must be "accepted"
)

# Make signup request
signup_json <- jsonlite::toJSON(signup_data, auto_unbox = TRUE)
resp <- httr2::request(paste0(base_url, "/api/authentication/signup")) |>
  httr2::req_url_query(signup_data = signup_json) |>
  httr2::req_perform()
```

### Password Reset Request
```r
# Source: api/endpoints/user_endpoints.R lines 435-497
# Password reset request: PUT /api/user/password/reset/request

# Request password reset
resp <- httr2::request(paste0(base_url, "/api/user/password/reset/request")) |>
  httr2::req_method("PUT") |>
  httr2::req_url_query(email_request = user_email) |>
  httr2::req_perform()

# Response is always 200 (even if email doesn't exist - security)
# If email exists and is valid, email is sent with reset URL:
# Reset URL format: {base_url}/PasswordReset/{jwt_token}
```

### Password Reset Change
```r
# Source: api/endpoints/user_endpoints.R lines 500-560
# Password reset change: GET /api/user/password/reset/change

# Extract token from email body
reset_token <- extract_token_from_email(message$ID)

# Use token to set new password
# Password requirements: >7 chars, lowercase, uppercase, digit, special char
new_password <- "NewPass1!"

resp <- httr2::request(paste0(base_url, "/api/user/password/reset/change")) |>
  httr2::req_headers(Authorization = paste("Bearer", reset_token)) |>
  httr2::req_url_query(new_pass_1 = new_password, new_pass_2 = new_password) |>
  httr2::req_perform()

# Returns 201 on success, 409 on invalid password/token, 401 on expired token
```

### User Deletion for Cleanup
```r
# Source: Database direct access pattern from helper-db.R
cleanup_test_user <- function(email) {
  con <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(con))

  DBI::dbExecute(con, "DELETE FROM user WHERE email = ?", list(email))
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual email checking | Mailpit API integration | Phase 51 | Automated email verification in tests |
| Plaintext passwords | Argon2id hashing | Earlier phase | `verify_password()` handles both formats |
| Direct `curl` calls | httr2 package | R ecosystem shift | Cleaner request building |

**Deprecated/outdated:**
- httr package: Use httr2 instead (modern, pipe-friendly)
- Manual Mailpit polling: Use `mailpit_wait_for_message()` helper

## Open Questions

Things that couldn't be fully resolved:

1. **Email Confirmation vs Curator Approval**
   - What we know: Signup creates unapproved user, curator approval activates account
   - What's unclear: Is SMTP-04 "Email confirmation flow" referring to curator approval or something else?
   - Recommendation: Interpret as testing that the approval email is sent when curator approves

2. **API Server for E2E Tests**
   - What we know: Tests use `api_base_url` from config pointing to localhost:7779
   - What's unclear: Does the API server need to be running separately, or can tests start it?
   - Recommendation: Require API server running (like Mailpit), skip if unavailable

3. **Test User Collision in Parallel Tests**
   - What we know: Unique timestamps help, but parallel execution may cause issues
   - What's unclear: Whether testthat runs integration tests in parallel by default
   - Recommendation: Use unique identifiers and always cleanup; consider test isolation flag

## Sources

### Primary (HIGH confidence)
- `/home/bernt-popp/development/sysndd/api/endpoints/authentication_endpoints.R` - Signup endpoint
- `/home/bernt-popp/development/sysndd/api/endpoints/user_endpoints.R` - Password reset endpoints
- `/home/bernt-popp/development/sysndd/api/tests/testthat/helper-mailpit.R` - Mailpit helpers
- `/home/bernt-popp/development/sysndd/api/tests/testthat/helper-db.R` - Database helpers
- `/home/bernt-popp/development/sysndd/api/tests/testthat/helper-auth.R` - JWT helpers
- `/home/bernt-popp/development/sysndd/api/tests/testthat/test-integration-email.R` - Email test patterns

### Secondary (MEDIUM confidence)
- [RFC 2606](https://datatracker.ietf.org/doc/html/rfc2606) - Reserved domains for testing (example.com)
- `/home/bernt-popp/development/sysndd/api/config.yml` - Test configuration with Mailpit settings
- `/home/bernt-popp/development/sysndd/docker-compose.dev.yml` - Mailpit container setup

### Tertiary (LOW confidence)
- None - all findings verified with codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use in codebase
- Architecture: HIGH - Patterns derived from existing test files
- Pitfalls: HIGH - Identified from actual endpoint implementations
- API Endpoints: HIGH - Verified from source code

**Research date:** 2026-01-30
**Valid until:** 60 days (stable codebase, patterns unlikely to change)
