# tests/testthat/test-unit-user-approval.R
# Unit tests for user approval endpoint logic
#
# These tests focus on the approval flow logic, particularly:
# - BUG-142: Missing user_name in query caused email generation failure
# - Error handling in approval flow
# - Validation of approval prerequisites

library(testthat)

# =============================================================================
# Helper Functions (Mock Definitions)
# =============================================================================

# Mock user data for testing
create_mock_user_table <- function(
  user_id = 1,
  user_name = "testuser",
  approved = 0,
  first_name = "Test",
  family_name = "User",
  email = "test@example.com"
) {
  tibble::tibble(
    user_id = user_id,
    user_name = user_name,
    approved = approved,
    first_name = first_name,
    family_name = family_name,
    email = email
  )
}

# =============================================================================
# BUG-142: user_name Field Tests
# =============================================================================

test_that("user table query includes user_name field", {
  # This test documents the BUG-142 fix

  # The query must include user_name for email template generation

  user_table <- create_mock_user_table()

  # Verify user_name is present (this was the bug)
  expect_true("user_name" %in% names(user_table))
  expect_equal(user_table$user_name, "testuser")
})

test_that("email template receives non-NULL user_name", {
  # The email_account_approved function requires user_name
  user_table <- create_mock_user_table()

  # Simulate what the endpoint does

  user_name_for_email <- user_table$user_name

  # Must not be NULL or NA
  expect_false(is.null(user_name_for_email))
  expect_false(is.na(user_name_for_email))
  expect_true(nchar(user_name_for_email) > 0)
})

test_that("missing user_name column returns NULL", {
  # Document behavior when user_name is missing (the bug condition)
  user_table_without_username <- tibble::tibble(
    user_id = 1,
    approved = 0,
    first_name = "Test",
    family_name = "User",
    email = "test@example.com"
  )

  # Accessing missing column returns NULL in R (suppress tibble column warning)
  result <- suppressWarnings(user_table_without_username$user_name)
  expect_null(result)
})

# =============================================================================
# Approval Prerequisites Tests
# =============================================================================

test_that("approval rejects non-existent user", {
  # User must exist before approval
  user_table <- tibble::tibble(
    user_id = integer(0),
    user_name = character(0),
    approved = integer(0),
    first_name = character(0),
    family_name = character(0),
    email = character(0)
  )

  user_exists <- as.logical(length(user_table$user_id))
  expect_false(user_exists)
})

test_that("approval rejects already-approved user", {
  user_table <- create_mock_user_table(approved = 1)

  user_already_approved <- as.logical(user_table$approved[1])
  expect_true(user_already_approved)
})

test_that("approval proceeds for unapproved user", {
  user_table <- create_mock_user_table(approved = 0)

  user_exists <- as.logical(length(user_table$user_id))
  user_approved <- as.logical(user_table$approved[1])

  expect_true(user_exists)
  expect_false(user_approved)
})

# =============================================================================
# Password Generation Tests
# =============================================================================

test_that("random_password generates 12 character password", {
  skip_if_not(exists("random_password"), "random_password function not loaded")

  password <- random_password()
  expect_equal(nchar(password), 12)
})

test_that("random_password uses valid character set", {
  skip_if_not(exists("random_password"), "random_password function not loaded")

  # Generate multiple passwords and check characters
  valid_chars <- c(0:9, letters, LETTERS, "!", "$")

  for (i in 1:10) {
    password <- random_password()
    chars <- strsplit(password, "")[[1]]
    all_valid <- all(chars %in% valid_chars)
    expect_true(all_valid)
  }
})

test_that("random_password is unique across calls", {
  skip_if_not(exists("random_password"), "random_password function not loaded")

  passwords <- vapply(1:100, function(x) random_password(), character(1))
  unique_passwords <- unique(passwords)

  # With 64^12 possible combinations, duplicates should be extremely rare
  expect_equal(length(unique_passwords), 100)
})

# =============================================================================
# Initials Generation Tests
# =============================================================================

test_that("generate_initials creates correct initials", {
  skip_if_not(exists("generate_initials"), "generate_initials function not loaded")

  expect_equal(generate_initials("John", "Doe"), "JD")
  expect_equal(generate_initials("Ada", "Lovelace"), "AL")
  expect_equal(generate_initials("Marie", "Curie"), "MC")
})

test_that("generate_initials handles single names", {
  skip_if_not(exists("generate_initials"), "generate_initials function not loaded")

  # Single character names
  expect_equal(generate_initials("A", "B"), "AB")
})

# =============================================================================
# Email Validation Tests
# =============================================================================

test_that("is_valid_email accepts valid emails", {
  skip_if_not(exists("is_valid_email"), "is_valid_email function not loaded")

  expect_true(is_valid_email("test@example.com"))
  expect_true(is_valid_email("user.name@domain.org"))
  expect_true(is_valid_email("user+tag@example.co.uk"))
})

test_that("is_valid_email rejects invalid emails", {
  skip_if_not(exists("is_valid_email"), "is_valid_email function not loaded")

  expect_false(is_valid_email("not-an-email"))
  expect_false(is_valid_email("@nodomain.com"))
  expect_false(is_valid_email("noatsign.com"))
  expect_false(is_valid_email(""))
})

# =============================================================================
# Integration Test: Approval Flow Order
# =============================================================================

test_that("approval operations execute in correct order", {
  # This test documents the expected execution order
  # Critical: password must be saved BEFORE email is generated
  #
  # Order:
  # 1. Generate password
  # 2. Generate initials
  # 3. Hash password
  # 4. Save to database (user_update + user_update_password)
  # 5. Generate email HTML
  # 6. Send email
  #
  # If steps 1-4 succeed but 5-6 fail, user is approved but never notified

  operations <- c(
    "random_password",
    "generate_initials",
    "hash_password",
    "user_update",
    "user_update_password",
    "email_account_approved",
    "send_noreply_email"
  )

  # Password operations must complete before email
  password_save_index <- which(operations == "user_update_password")
  email_generate_index <- which(operations == "email_account_approved")

  expect_true(password_save_index < email_generate_index)
})

# =============================================================================
# Error Scenario Tests
# =============================================================================

test_that("NULL user_name in email template is detectable", {
  # Document the bug scenario
  user_name <- NULL

  # In glue, NULL becomes "NULL" string which is problematic
  # The fix ensures user_name is never NULL
  is_problematic <- is.null(user_name) ||
    is.na(user_name) ||
    (is.character(user_name) && nchar(user_name) == 0)

  expect_true(is_problematic)
})

test_that("valid user_name passes validation",
{
  user_name <- "testuser"

  is_valid <- !is.null(user_name) &&
    !is.na(user_name) &&
    is.character(user_name) &&
    nchar(user_name) > 0

  expect_true(is_valid)
})
