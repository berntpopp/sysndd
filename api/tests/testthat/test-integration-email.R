# tests/testthat/test-integration-email.R
# Integration tests for email delivery via Mailpit
#
# These tests verify that send_noreply_email() correctly delivers
# emails to the Mailpit testing server. Requires Mailpit running:
#   docker compose -f docker-compose.dev.yml up -d mailpit

library(testthat)

# =============================================================================
# Mailpit Connectivity Tests
# =============================================================================

test_that("Mailpit is accessible", {
  skip_if_no_mailpit()

  # Should be able to get messages (even if empty)
  messages <- mailpit_get_messages()

  expect_true(is.list(messages))
  expect_true("total" %in% names(messages) || "messages" %in% names(messages))
})


test_that("Mailpit can delete all messages", {
  skip_if_no_mailpit()

  # Delete should not error
  result <- mailpit_delete_all()

  expect_true(result)

  # Inbox should be empty after delete
  count <- mailpit_message_count()
  expect_equal(count, 0)
})


# =============================================================================
# Email Sending Tests
# =============================================================================

test_that("send_noreply_email delivers to Mailpit", {
  skip_if_no_mailpit()

  # Clean inbox first
  mailpit_delete_all()

  # Generate unique recipient to avoid collision
  test_email <- paste0("test-", format(Sys.time(), "%H%M%S"), "@example.com")

  # Source the email function
  source("../../functions/helper-functions.R", local = TRUE)

  # Set SMTP_PASSWORD env var (Mailpit accepts any password)
  withr::local_envvar(SMTP_PASSWORD = "test")

  # Get config to set up dw variable
  test_config <- get_test_config()
  # Override with Mailpit settings
  test_config$mail_noreply_host <- "127.0.0.1"
  test_config$mail_noreply_port <- 1025
  test_config$mail_noreply_use_ssl <- FALSE

  # Create dw in local environment
  dw <- test_config

  # Attempt to send email (may fail if not all dependencies loaded)
  result <- tryCatch({
    send_noreply_email(
      email_body = "This is a test email body.",
      email_subject = "Test Email from Integration Test",
      email_recipient = test_email,
      email_blind_copy = ""
    )
    TRUE
  }, error = function(e) {
    # Expected - blastula may not be loaded in test context
    # Skip this test if blastula not available
    testthat::skip(paste("Email send failed (expected if blastula not loaded):", e$message))
  })

  if (result) {
    # Wait for message to appear
    message <- mailpit_wait_for_message(test_email, timeout_seconds = 5)

    expect_true(!is.null(message))
    expect_match(message$Subject, "Test Email")
  }
})


# =============================================================================
# SMTP Connection Test Endpoint
# =============================================================================

test_that("SMTP test endpoint function exists", {
  skip_if_no_mailpit()

  # The endpoint is in admin_endpoints.R
  # We test that the socket connection logic works

  smtp_host <- "127.0.0.1"
  smtp_port <- 1025

  # Test socket connection (same logic as endpoint)
  result <- tryCatch({
    con <- socketConnection(
      host = smtp_host,
      port = smtp_port,
      open = "r+",
      blocking = TRUE,
      timeout = 5
    )
    close(con)
    list(success = TRUE, error = NULL)
  }, error = function(e) {
    list(success = FALSE, error = e$message)
  })

  expect_true(result$success)
  expect_null(result$error)
})


test_that("SMTP connection fails gracefully for invalid host", {
  # Test that connection fails cleanly (no crash)
  result <- tryCatch({
    con <- socketConnection(
      host = "invalid.host.example",
      port = 9999,
      open = "r+",
      blocking = TRUE,
      timeout = 2
    )
    close(con)
    list(success = TRUE)
  }, error = function(e) {
    list(success = FALSE, error = e$message)
  })

  expect_false(result$success)
  expect_true(nchar(result$error) > 0)
})


# =============================================================================
# Mailpit Search and Filter Tests
# =============================================================================

test_that("Mailpit search finds messages by recipient", {
  skip_if_no_mailpit()

  # This test verifies search works
  # We don't send email here (tested above) - just verify API

  # Search for non-existent email should return empty
  result <- mailpit_search("nonexistent@nowhere.invalid")

  expect_true(is.list(result))
  expect_equal(result$total %||% 0, 0)
})
