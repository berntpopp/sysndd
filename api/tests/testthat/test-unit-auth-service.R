# tests/testthat/test-unit-auth-service.R
# Unit tests for auth-service.R
#
# Verifies:
# 1. auth_generate_token correctly reads user_created from user object
# 2. auth_generate_token works with JWT refresh path (decoded token claims)
# 3. No warning is produced when user_created is present

library(testthat)
library(jose)

# Source dependencies
source_api_file("core/errors.R", local = FALSE)
source_api_file("services/auth-service.R", local = FALSE)

# =============================================================================
# auth_generate_token Tests
# =============================================================================

test_that("auth_generate_token includes user_created in JWT claims", {
  user <- list(
    user_id = 1,
    user_name = "test_user",
    email = "test@example.com",
    user_role = "Curator",
    user_created = "2024-01-15 10:00:00",
    abbreviation = "TU",
    orcid = "0000-0000-0000-0001"
  )

  config <- list(
    secret = "test-secret-key-for-unit-tests-only",
    refresh = 3600
  )

  result <- auth_generate_token(user, config)

  expect_true(!is.null(result$access_token))
  expect_true(!is.null(result$refresh_token))

  # Decode and verify the claim has user_created
  decoded <- jose::jwt_decode_hmac(
    result$access_token,
    secret = charToRaw(config$secret)
  )

  expect_equal(decoded$user_created, "2024-01-15 10:00:00")
  expect_equal(decoded$user_id, 1)
  expect_equal(decoded$user_name, "test_user")
})

test_that("auth_generate_token produces no warning when user_created is present", {
  user <- list(
    user_id = 1,
    user_name = "test_user",
    email = "test@example.com",
    user_role = "Curator",
    user_created = "2024-01-15 10:00:00",
    abbreviation = "TU",
    orcid = "0000-0000-0000-0001"
  )

  config <- list(
    secret = "test-secret-key-for-unit-tests-only",
    refresh = 3600
  )

  # Before the fix, accessing user$user_created on a tibble row without
  # that column name would produce a warning
  expect_no_warning(auth_generate_token(user, config))
})

test_that("auth_generate_token works with refresh path (decoded JWT claims)", {
  # Simulate the refresh path: user comes from decoded JWT which has user_created
  decoded_user <- list(
    user_id = 42,
    user_name = "refresh_user",
    email = "refresh@example.com",
    user_role = "Administrator",
    user_created = "2023-06-01 08:30:00",
    abbreviation = "RU",
    orcid = "0000-0000-0000-0042"
  )

  config <- list(
    secret = "test-secret-key-for-unit-tests-only",
    refresh = 7200
  )

  result <- auth_generate_token(decoded_user, config)

  decoded <- jose::jwt_decode_hmac(
    result$access_token,
    secret = charToRaw(config$secret)
  )

  expect_equal(decoded$user_created, "2023-06-01 08:30:00")
  expect_equal(decoded$user_id, 42)
})

# =============================================================================
# auth_validate_token Tests
# =============================================================================

test_that("auth_validate_token decodes valid token", {
  config <- list(
    secret = "test-secret-key-for-unit-tests-only",
    refresh = 3600
  )

  # Create a token
  user <- list(
    user_id = 1,
    user_name = "test_user",
    email = "test@example.com",
    user_role = "Curator",
    user_created = "2024-01-15 10:00:00",
    abbreviation = "TU",
    orcid = "0000-0000-0000-0001"
  )

  token_result <- auth_generate_token(user, config)

  # Validate it
  decoded <- auth_validate_token(token_result$access_token, config)

  expect_false(is.null(decoded))
  expect_equal(decoded$user_id, 1)
  expect_equal(decoded$user_name, "test_user")
  expect_equal(decoded$user_created, "2024-01-15 10:00:00")
})

test_that("auth_validate_token returns NULL for invalid token", {
  config <- list(
    secret = "test-secret-key-for-unit-tests-only"
  )

  result <- auth_validate_token("invalid.jwt.token", config)
  expect_null(result)
})

test_that("auth_validate_token returns NULL for tampered token", {
  config <- list(
    secret = "test-secret-key-for-unit-tests-only",
    refresh = 3600
  )

  user <- list(
    user_id = 1,
    user_name = "test_user",
    email = "test@example.com",
    user_role = "Curator",
    user_created = "2024-01-15 10:00:00",
    abbreviation = "TU",
    orcid = "0000-0000-0000-0001"
  )

  token_result <- auth_generate_token(user, config)

  # Tamper with the token (change last character)
  tampered <- paste0(token_result$access_token, "x")
  result <- auth_validate_token(tampered, config)
  expect_null(result)
})

# =============================================================================
# auth_verify Tests
# =============================================================================

test_that("auth_verify returns user info for valid token", {
  config <- list(
    secret = "test-secret-key-for-unit-tests-only",
    refresh = 3600
  )

  user <- list(
    user_id = 5,
    user_name = "curator_user",
    email = "curator@example.com",
    user_role = "Curator",
    user_created = "2024-03-01 12:00:00",
    abbreviation = "CU",
    orcid = "0000-0000-0000-0005"
  )

  token_result <- auth_generate_token(user, config)

  result <- auth_verify(token_result$access_token, config)

  expect_equal(result$user_id, 5)
  expect_equal(result$user_name, "curator_user")
  expect_equal(result$user_role, "Curator")
  expect_equal(result$user_created, "2024-03-01 12:00:00")
})

test_that("auth_verify rejects missing token", {
  config <- list(secret = "test-secret")

  expect_error(auth_verify("", config), "Token is required")
  expect_error(auth_verify(NULL, config), "Token is required")
})

# =============================================================================
# Function Signature Tests
# =============================================================================

test_that("auth_signin has correct signature", {
  params <- names(formals(auth_signin))
  expect_equal(params, c("user_name", "password", "pool", "config"))
})

test_that("auth_generate_token has correct signature", {
  params <- names(formals(auth_generate_token))
  expect_equal(params, c("user", "config"))
})

test_that("auth_refresh has correct signature", {
  params <- names(formals(auth_refresh))
  expect_equal(params, c("refresh_token", "pool", "config"))
})
