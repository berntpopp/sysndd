# Phase 51: SMTP Testing Infrastructure - Research

**Researched:** 2026-01-29
**Domain:** Email testing infrastructure (Mailpit), SMTP configuration, integration testing
**Confidence:** HIGH

## Summary

This phase adds Mailpit as a local SMTP testing container for development and creates an admin endpoint to test SMTP connection status. The existing email infrastructure uses the R `blastula` package with `smtp_send()` and `creds_envvar()` for credential management. The current SMTP configuration is stored in `config.yml` with fields `mail_noreply_host`, `mail_noreply_port`, `mail_noreply_user`, and `mail_noreply_use_ssl`.

Mailpit is the modern successor to the abandoned MailHog project. It provides a lightweight Docker container with SMTP server (port 1025), Web UI (port 8025), and REST API for automated testing. The API allows listing, searching, and deleting messages programmatically, enabling integration tests to verify email delivery.

**Primary recommendation:** Add Mailpit to `docker-compose.dev.yml` (dev profile only), update `config.yml` with a `sysndd_db_dev` config pointing SMTP to mailpit:1025, and create a new admin endpoint `GET /api/admin/smtp/test` that attempts an SMTP connection and returns status.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Mailpit | v1.28.4 | Local SMTP server and email testing UI | Modern MailHog successor, actively maintained, single binary |
| blastula | 0.3.6 | R package for sending HTML emails via SMTP | Already in use in project, supports creds_envvar |
| httr2 | (existing) | HTTP client for Mailpit API queries | Already in project, used for external API calls |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jsonlite | (existing) | Parse Mailpit API responses | Already in project |
| testthat | (existing) | Integration test framework | Already in project |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Mailpit | MailHog | MailHog is abandoned (no updates since 2020) |
| Mailpit | Mailtrap | Cloud service, requires internet, has rate limits |
| Mailpit | greenmail | Java-based, heavier than Mailpit |

**Installation:**
```yaml
# Add to docker-compose.dev.yml
services:
  mailpit:
    image: axllent/mailpit:v1.28.4
    container_name: sysndd_mailpit
    restart: unless-stopped
    ports:
      - "127.0.0.1:8025:8025"  # Web UI
      - "127.0.0.1:1025:1025"  # SMTP (for local R development)
    environment:
      MP_SMTP_AUTH_ACCEPT_ANY: 1
      MP_SMTP_AUTH_ALLOW_INSECURE: 1
      MP_MAX_MESSAGES: 500
    networks:
      - backend
```

## Architecture Patterns

### Recommended Project Structure
```
api/
├── config.yml              # Add sysndd_db_dev with mailpit SMTP settings
├── endpoints/
│   └── admin_endpoints.R   # Add /smtp/test endpoint
├── tests/
│   └── testthat/
│       ├── helper-mailpit.R      # Mailpit API helper functions
│       └── test-integration-email.R  # Email delivery tests
docker-compose.dev.yml          # Add mailpit service
```

### Pattern 1: Environment-Based SMTP Switching
**What:** Use config.yml profiles to switch SMTP host between environments
**When to use:** Development vs Production environments need different SMTP servers
**Example:**
```yaml
# config.yml
default:
  sysndd_db:        # Production - real SMTP
    mail_noreply_host: "smtp.strato.de"
    mail_noreply_port: 587
    mail_noreply_use_ssl: TRUE

  sysndd_db_dev:    # Development - Mailpit in Docker
    mail_noreply_host: "mailpit"  # Docker service name
    mail_noreply_port: 1025
    mail_noreply_use_ssl: FALSE

  sysndd_db_local:  # Local R development (host machine)
    mail_noreply_host: "127.0.0.1"
    mail_noreply_port: 1025
    mail_noreply_use_ssl: FALSE
```

### Pattern 2: Graceful SMTP Failure
**What:** Log error and continue when SMTP is unreachable (don't crash API)
**When to use:** API operations should succeed even if email fails
**Example:**
```r
# Source: Existing pattern in send_noreply_email, enhanced
send_noreply_email_safe <- function(email_body, email_subject, email_recipient, email_blind_copy = "noreply@sysndd.org") {
  tryCatch({
    send_noreply_email(email_body, email_subject, email_recipient, email_blind_copy)
    list(success = TRUE)
  }, error = function(e) {
    logger::log_error("SMTP send failed: {e$message}")
    list(success = FALSE, error = e$message)
  })
}
```

### Pattern 3: Mailpit API Integration Testing
**What:** Query Mailpit REST API to verify email delivery in tests
**When to use:** Integration tests validating email functionality
**Example:**
```r
# Source: Mailpit API documentation https://mailpit.axllent.org/docs/api-v1/
# Helper function to query Mailpit API
mailpit_get_messages <- function(mailpit_url = "http://localhost:8025") {
  resp <- httr2::request(paste0(mailpit_url, "/api/v1/messages")) |>
    httr2::req_perform()
  httr2::resp_body_json(resp)
}

mailpit_search <- function(query, mailpit_url = "http://localhost:8025") {
  resp <- httr2::request(paste0(mailpit_url, "/api/v1/search")) |>
    httr2::req_url_query(query = query) |>
    httr2::req_perform()
  httr2::resp_body_json(resp)
}

mailpit_delete_all <- function(mailpit_url = "http://localhost:8025") {
  httr2::request(paste0(mailpit_url, "/api/v1/messages")) |>
    httr2::req_method("DELETE") |>
    httr2::req_perform()
}
```

### Anti-Patterns to Avoid
- **Hardcoding SMTP settings:** Use config.yml profiles, not environment variables for host/port
- **Exposing Mailpit externally:** Bind ports to 127.0.0.1, not 0.0.0.0
- **Mocking email in integration tests:** Integration tests should use real Mailpit, not mocks
- **Making API depend on Mailpit:** API should start independently, fail gracefully if SMTP unavailable

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Local SMTP server | Custom SMTP mock | Mailpit | Full-featured, includes UI, API, handles edge cases |
| Email capture | Log emails to file | Mailpit | Provides searchable inbox, attachment viewing, headers |
| SMTP credential management | Custom env parsing | blastula creds_envvar | Handles auth, SSL, provider presets |
| Email content testing | Parse raw email | Mailpit Web UI | Visual inspection of HTML, headers, attachments |

**Key insight:** Mailpit provides a complete email testing solution with web UI for visual debugging and REST API for automated verification. Building custom solutions would miss features like attachment handling, HTML rendering, and advanced search.

## Common Pitfalls

### Pitfall 1: Docker Service Name vs Host Machine Access
**What goes wrong:** R code running on host machine can't reach `mailpit` hostname
**Why it happens:** Docker DNS only resolves service names inside Docker network
**How to avoid:**
- In Docker (API container): Use `mailpit` as hostname (service name)
- On host (local R development): Use `127.0.0.1` as hostname
- Expose port 1025 to localhost in docker-compose.dev.yml
**Warning signs:** "Connection refused" or "Host not found" errors during local development

### Pitfall 2: SSL/TLS Configuration Mismatch
**What goes wrong:** Connection fails with SSL handshake errors
**Why it happens:** Mailpit by default doesn't use SSL, but blastula might expect it
**How to avoid:**
- Set `mail_noreply_use_ssl: FALSE` in dev config
- Set `MP_SMTP_AUTH_ALLOW_INSECURE: 1` in Mailpit
**Warning signs:** "SSL connection required" or "handshake failure" errors

### Pitfall 3: Port Conflicts
**What goes wrong:** Mailpit fails to start because port already in use
**Why it happens:** Another service (MailHog, other SMTP server) on 1025 or 8025
**How to avoid:**
- Check for conflicts: `lsof -i :1025` and `lsof -i :8025`
- Use different ports if needed: `- "9025:8025"` in docker-compose
**Warning signs:** Docker container exits immediately after start

### Pitfall 4: Forgetting to Clean Mailpit Between Tests
**What goes wrong:** Tests pass/fail inconsistently due to leftover messages
**Why it happens:** Previous test run left messages in Mailpit inbox
**How to avoid:** Call `mailpit_delete_all()` in test setup (before each test or test file)
**Warning signs:** Flaky tests, tests passing locally but failing in CI

### Pitfall 5: Testing Against Production SMTP
**What goes wrong:** Test emails sent to real users during development
**Why it happens:** Running tests with production config instead of dev config
**How to avoid:**
- Never use production SMTP credentials in development
- Integration tests should explicitly check for Mailpit availability and skip if not present
- Use `skip_if_no_mailpit()` helper in tests
**Warning signs:** Users receiving test emails, unexpected SMTP charges

## Code Examples

Verified patterns from official sources:

### SMTP Test Endpoint
```r
# Source: Pattern from admin_endpoints.R, adapted for SMTP testing
#* Test SMTP connection status
#*
#* Attempts to connect to the configured SMTP server and returns
#* connection status. Does not send any email.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* - success: Boolean indicating if connection succeeded
#* - host: SMTP host that was tested
#* - port: SMTP port that was tested
#* - error: Error message if connection failed (null on success)
#*
#* @tag admin
#* @serializer unboxedJSON
#* @get /smtp/test
function(req, res) {
  require_role(req, res, "Administrator")

  smtp_host <- dw$mail_noreply_host
  smtp_port <- as.integer(dw$mail_noreply_port)

  result <- tryCatch({
    # Attempt socket connection to SMTP server
    con <- socketConnection(
      host = smtp_host,
      port = smtp_port,
      open = "r+",
      blocking = TRUE,
      timeout = 5
    )
    close(con)

    list(
      success = TRUE,
      host = smtp_host,
      port = smtp_port,
      error = NULL
    )
  }, error = function(e) {
    list(
      success = FALSE,
      host = smtp_host,
      port = smtp_port,
      error = e$message
    )
  })

  result
}
```

### Mailpit Test Helper
```r
# Source: Mailpit API docs https://mailpit.axllent.org/docs/api-v1/
# tests/testthat/helper-mailpit.R

#' Check if Mailpit is available
mailpit_available <- function(mailpit_url = "http://localhost:8025") {
  tryCatch({
    resp <- httr2::request(paste0(mailpit_url, "/api/v1/messages")) |>
      httr2::req_timeout(2) |>
      httr2::req_perform()
    httr2::resp_status(resp) == 200
  }, error = function(e) FALSE)
}

#' Skip test if Mailpit not available
skip_if_no_mailpit <- function() {
  if (!mailpit_available()) {
    testthat::skip("Mailpit not available (start with docker compose -f docker-compose.dev.yml up)")
  }
}

#' Get all messages from Mailpit
mailpit_get_messages <- function(mailpit_url = "http://localhost:8025") {
  resp <- httr2::request(paste0(mailpit_url, "/api/v1/messages")) |>
    httr2::req_perform()
  httr2::resp_body_json(resp)
}

#' Search messages in Mailpit
#' @param query Search query (email address, subject, etc.)
mailpit_search <- function(query, mailpit_url = "http://localhost:8025") {
  resp <- httr2::request(paste0(mailpit_url, "/api/v1/search")) |>
    httr2::req_url_query(query = query) |>
    httr2::req_perform()
  httr2::resp_body_json(resp)
}

#' Delete all messages in Mailpit
mailpit_delete_all <- function(mailpit_url = "http://localhost:8025") {
  httr2::request(paste0(mailpit_url, "/api/v1/messages")) |>
    httr2::req_method("DELETE") |>
    httr2::req_perform()
  invisible(TRUE)
}

#' Get message count in Mailpit
mailpit_message_count <- function(mailpit_url = "http://localhost:8025") {
  messages <- mailpit_get_messages(mailpit_url)
  messages$total %||% 0
}

#' Wait for message to appear in Mailpit (with timeout)
#' @param recipient Email address to search for
#' @param timeout_seconds Maximum time to wait
mailpit_wait_for_message <- function(recipient, timeout_seconds = 10, mailpit_url = "http://localhost:8025") {
  start_time <- Sys.time()
  while (difftime(Sys.time(), start_time, units = "secs") < timeout_seconds) {
    result <- mailpit_search(recipient, mailpit_url)
    if (!is.null(result$total) && result$total > 0) {
      return(result$messages[[1]])
    }
    Sys.sleep(0.5)
  }
  stop(paste("Timeout waiting for email to", recipient))
}
```

### Integration Test Example
```r
# Source: Pattern from test-integration-auth.R, adapted for email
# tests/testthat/test-integration-email.R

test_that("user approval sends email to Mailpit", {
  skip_if_no_mailpit()
  skip_if_no_test_db()

  # Clean Mailpit inbox
  mailpit_delete_all()

  # ... create test user and trigger approval ...

  # Verify email arrived in Mailpit
  message <- mailpit_wait_for_message("testuser@example.com", timeout_seconds = 5)

  expect_equal(message$To[[1]]$Address, "testuser@example.com")
  expect_match(message$Subject, "Account approved")
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| MailHog | Mailpit | 2022 (MailHog abandoned) | Must use Mailpit - MailHog has no updates |
| Direct SMTP mocking | Mailpit container | 2023-2024 | Integration tests use real SMTP flow |
| Email logging to file | Mailpit Web UI + API | Current | Better debugging, searchable inbox |

**Deprecated/outdated:**
- MailHog: No longer maintained, last release 2020. Use Mailpit instead.
- Mailtrap free tier: Limited to 100 emails/month, use Mailpit for unlimited local testing.

## Open Questions

Things that couldn't be fully resolved:

1. **Exact Mailpit API response format**
   - What we know: API exists at `/api/v1/messages`, `/api/v1/search`, DELETE `/api/v1/messages`
   - What's unclear: Exact JSON response structure (fields, pagination)
   - Recommendation: Verify by running Mailpit locally and checking `/api/v1/` Swagger docs

2. **blastula SMTP connection test method**
   - What we know: `smtp_send()` sends email, no built-in "test connection only" function
   - What's unclear: Whether blastula exposes SMTP connection testing
   - Recommendation: Use raw socket connection for SMTP test endpoint (shown in example)

## Sources

### Primary (HIGH confidence)
- [Mailpit GitHub](https://github.com/axllent/mailpit) - v1.28.4 (Jan 2026), Docker setup, environment variables
- [Mailpit Docker docs](https://mailpit.axllent.org/docs/install/docker/) - Docker Compose configuration
- [Mailpit configuration](https://mailpit.axllent.org/docs/configuration/runtime-options/) - MP_SMTP_AUTH_ACCEPT_ANY, MP_MAX_MESSAGES
- [blastula CRAN docs](https://cran.r-project.org/web/packages/blastula/blastula.pdf) - v0.3.6, creds_envvar

### Secondary (MEDIUM confidence)
- [Mailpit API v1 docs](https://mailpit.axllent.org/docs/api-v1/) - Endpoint patterns (full spec at runtime)
- Existing project code: `api/functions/helper-functions.R` - send_noreply_email implementation
- Existing project code: `api/config.yml` - SMTP configuration structure

### Tertiary (LOW confidence)
- [Medium article on Mailpit 2026](https://medium.com/@doobie-droid/mailpit-review-2026-the-undisputed-champion-of-local-email-testing-faf9ddf522c7) - Community perspective
- [Testcontainers Mailpit module](https://testcontainers.com/modules/mailpit/) - Java testing pattern (not directly applicable to R)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Mailpit is well-documented, actively maintained, official Docker image
- Architecture: HIGH - Config-based switching pattern is standard, matches existing project patterns
- Pitfalls: HIGH - Based on official documentation and common Docker networking issues

**Research date:** 2026-01-29
**Valid until:** 2026-03-29 (60 days - stable infrastructure, Mailpit mature)
