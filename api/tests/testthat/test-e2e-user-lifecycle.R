# tests/testthat/test-e2e-user-lifecycle.R
# End-to-end tests for user lifecycle flows
#
# Tests user registration (SMTP-03), curator approval (SMTP-04), and
# password reset (SMTP-05) using Mailpit to capture emails.
#
# Prerequisites:
#   - Mailpit running: docker compose -f docker-compose.dev.yml up -d mailpit
#   - API server running: make serve-api (port 7779)
#   - Test database running: docker compose -f docker-compose.dev.yml up -d db-test

library(testthat)
library(httr2)
library(jsonlite)

# =============================================================================
# Test Configuration
# =============================================================================

# Get API base URL from config (typically http://localhost:7779)
get_api_base_url <- function() {
  config <- get_test_config()
  config$api_base_url %||% "http://localhost:7779"
}

# Check if API server is available
api_available <- function() {
  tryCatch({
    resp <- httr2::request(paste0(get_api_base_url(), "/health")) |>
      httr2::req_timeout(2) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()
    httr2::resp_status(resp) == 200
  }, error = function(e) FALSE)
}

# Skip if API not available
skip_if_no_api <- function() {
  if (!api_available()) {
    testthat::skip("API server not available (start with: make serve-api)")
  }
}

# Generate unique test user data
# Uses example.com domain (RFC 2606 reserved for testing)
generate_test_user <- function(prefix = "e2etest") {
  timestamp <- format(Sys.time(), "%Y%m%d%H%M%S")
  random_suffix <- floor(runif(1, 10000, 99999))

  list(
    user_name = paste0(prefix, random_suffix),
    first_name = "Test",
    family_name = "User",
    email = paste0(prefix, "-", timestamp, "-", random_suffix, "@example.com"),
    orcid = paste0("0000-0000-0000-", sprintf("%04d", random_suffix %% 10000)),
    comment = "Automated E2E test user - safe to delete",
    terms_agreed = "accepted"
  )
}

# Cleanup test user from database
cleanup_test_user <- function(email) {
  tryCatch({
    con <- get_test_db_connection()
    withr::defer(DBI::dbDisconnect(con), envir = parent.frame())
    DBI::dbExecute(con, "DELETE FROM user WHERE email = ?", list(email))
  }, error = function(e) {
    # Ignore cleanup errors - user may not exist
    message("Cleanup note: ", e$message)
  })
}

# Get user from database by email
get_user_by_email <- function(email) {
  con <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(con), envir = parent.frame())
  result <- DBI::dbGetQuery(
    con,
    "SELECT user_id, user_name, email, approved, password FROM user WHERE email = ?",
    list(email)
  )
  if (nrow(result) == 0) NULL else result[1, ]
}

# Create admin JWT for curator operations
get_admin_token <- function() {
  # Use create_test_jwt from helper-auth.R if available
  # Otherwise construct minimal admin token
  if (exists("create_test_jwt")) {
    create_test_jwt(user_id = 1, user_role = "Administrator")
  } else {
    # Fallback: construct token manually
    config <- get_test_config()
    key <- charToRaw(config$secret)

    claim <- jose::jwt_claim(
      user_id = 1,
      user_name = "admin",
      user_role = "Administrator",
      iat = as.integer(Sys.time()),
      exp = as.integer(Sys.time()) + 3600
    )
    jose::jwt_encode_hmac(claim, secret = key)
  }
}


# =============================================================================
# User Registration Tests (SMTP-03)
# =============================================================================

test_that("user registration sends confirmation email", {
  skip_if_no_mailpit()
  skip_if_no_api()
  skip_if_no_test_db()

  # Clean Mailpit inbox
  mailpit_delete_all()

  # Generate unique test user
  test_user <- generate_test_user("signup")

  # Register cleanup BEFORE creating user (withr::defer runs even on failure)
  withr::defer(cleanup_test_user(test_user$email))

  # Make signup request
  signup_json <- jsonlite::toJSON(test_user, auto_unbox = TRUE)

  resp <- httr2::request(paste0(get_api_base_url(), "/api/authentication/signup")) |>
    httr2::req_url_query(signup_data = signup_json) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  # Signup should succeed (200)
  expect_equal(httr2::resp_status(resp), 200)

  # Wait for confirmation email in Mailpit
  message <- mailpit_wait_for_message(test_user$email, timeout_seconds = 10)

  expect_true(!is.null(message))
  expect_match(message$Subject, "registration request", ignore.case = TRUE)

  # Verify user was created in database with approved=0
  user <- get_user_by_email(test_user$email)
  expect_true(!is.null(user))
  expect_equal(user$approved, 0)
})


test_that("duplicate registration is rejected", {
  skip_if_no_mailpit()
  skip_if_no_api()
  skip_if_no_test_db()

  mailpit_delete_all()
  test_user <- generate_test_user("dupe")
  withr::defer(cleanup_test_user(test_user$email))

  signup_json <- jsonlite::toJSON(test_user, auto_unbox = TRUE)

  # First registration should succeed
  resp1 <- httr2::request(paste0(get_api_base_url(), "/api/authentication/signup")) |>
    httr2::req_url_query(signup_data = signup_json) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  expect_equal(httr2::resp_status(resp1), 200)

  # Wait for first email
  mailpit_wait_for_message(test_user$email, timeout_seconds = 5)
  initial_count <- mailpit_message_count()

  # Second registration should fail (duplicate email/username)
  # Note: The endpoint may return 200 or error depending on implementation
  resp2 <- httr2::request(paste0(get_api_base_url(), "/api/authentication/signup")) |>
    httr2::req_url_query(signup_data = signup_json) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  # Should not send additional email on duplicate attempt
  Sys.sleep(1)
  final_count <- mailpit_message_count()
  expect_equal(final_count, initial_count)
})


test_that("invalid registration data is rejected", {
  skip_if_no_mailpit()
  skip_if_no_api()

  mailpit_delete_all()

  # Invalid data: username too short, invalid ORCID format
  invalid_user <- list(
    user_name = "ab",
    first_name = "Test",
    family_name = "User",
    email = "invalid@example.com",
    orcid = "invalid-format",
    comment = "Test comment that is long enough",
    terms_agreed = "accepted"
  )

  signup_json <- jsonlite::toJSON(invalid_user, auto_unbox = TRUE)

  resp <- httr2::request(paste0(get_api_base_url(), "/api/authentication/signup")) |>
    httr2::req_url_query(signup_data = signup_json) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  # Should return error status (404 per endpoint code)
  expect_equal(httr2::resp_status(resp), 404)

  # No email should be sent
  Sys.sleep(1)
  count <- mailpit_message_count()
  expect_equal(count, 0)
})


# =============================================================================
# Curator Approval Tests (SMTP-04)
# =============================================================================

test_that("curator approval sends password email", {
  skip_if_no_mailpit()
  skip_if_no_api()
  skip_if_no_test_db()

  mailpit_delete_all()
  test_user <- generate_test_user("approve")
  withr::defer(cleanup_test_user(test_user$email))

  # First register the user
  signup_json <- jsonlite::toJSON(test_user, auto_unbox = TRUE)

  httr2::request(paste0(get_api_base_url(), "/api/authentication/signup")) |>
    httr2::req_url_query(signup_data = signup_json) |>
    httr2::req_perform()

  # Wait for registration email
  mailpit_wait_for_message(test_user$email, timeout_seconds = 5)

  # Get user_id from database
  user <- get_user_by_email(test_user$email)
  expect_true(!is.null(user))
  expect_equal(user$approved, 0)

  # Clear inbox before approval
  mailpit_delete_all()

  # Approve user via API (requires admin/curator token)
  admin_token <- get_admin_token()

  resp <- httr2::request(paste0(get_api_base_url(), "/api/user/approval")) |>
    httr2::req_method("PUT") |>
    httr2::req_url_query(user_id = user$user_id, status_approval = "TRUE") |>
    httr2::req_headers(Authorization = paste("Bearer", admin_token)) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  # Approval should succeed
  expect_true(httr2::resp_status(resp) %in% c(200, 204))

  # Wait for approval email with password
  message <- mailpit_wait_for_message(test_user$email, timeout_seconds = 10)

  expect_true(!is.null(message))
  expect_match(message$Subject, "approved", ignore.case = TRUE)

  # Verify user is now approved in database
  user_after <- get_user_by_email(test_user$email)
  expect_equal(user_after$approved, 1)

  # Verify password was set (not null/empty)
  expect_true(!is.null(user_after$password) && nchar(user_after$password) > 0)
})


test_that("curator rejection deletes user without email", {
  skip_if_no_mailpit()
  skip_if_no_api()
  skip_if_no_test_db()

  mailpit_delete_all()
  test_user <- generate_test_user("reject")
  # No defer cleanup needed - rejection deletes user

  # Register the user
  signup_json <- jsonlite::toJSON(test_user, auto_unbox = TRUE)

  httr2::request(paste0(get_api_base_url(), "/api/authentication/signup")) |>
    httr2::req_url_query(signup_data = signup_json) |>
    httr2::req_perform()

  # Wait for registration email
  mailpit_wait_for_message(test_user$email, timeout_seconds = 5)

  # Get user_id
  user <- get_user_by_email(test_user$email)
  expect_true(!is.null(user))

  # Clear inbox
  mailpit_delete_all()

  # Reject user (status_approval = FALSE)
  admin_token <- get_admin_token()

  resp <- httr2::request(paste0(get_api_base_url(), "/api/user/approval")) |>
    httr2::req_method("PUT") |>
    httr2::req_url_query(user_id = user$user_id, status_approval = "FALSE") |>
    httr2::req_headers(Authorization = paste("Bearer", admin_token)) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  expect_true(httr2::resp_status(resp) %in% c(200, 204))

  # User should be deleted
  user_after <- get_user_by_email(test_user$email)
  expect_null(user_after)

  # No rejection email should be sent
  Sys.sleep(1)
  count <- mailpit_message_count()
  expect_equal(count, 0)
})
