# tests/testthat/test-integration-auth.R
# Integration tests for authentication endpoints
#
# These tests validate JWT token generation and validation logic.
# They test the auth logic at the function level rather than HTTP level
# to avoid requiring a running API server during tests.

library(testthat)
library(jose)

# =============================================================================
# JWT Token Generation Tests
# =============================================================================

test_that("create_test_jwt generates a valid JWT token", {
  token <- create_test_jwt()

  # Token should be a non-empty string
  expect_true(is.character(token))
  expect_true(nchar(token) > 50)

  # Token should have 3 parts (header.payload.signature)
  parts <- strsplit(token, "\\.")[[1]]
  expect_equal(length(parts), 3)
})

test_that("create_test_jwt encodes correct user information", {
  token <- create_test_jwt(
    user_id = 42,
    user_name = "admin_user",
    user_role = "Administrator"
  )

  decoded <- decode_test_jwt(token)

  expect_equal(decoded$user_id, 42)
  expect_equal(decoded$user_name, "admin_user")
  expect_equal(decoded$user_role, "Administrator")
})

test_that("create_test_jwt sets correct expiration for valid token", {
  token <- create_test_jwt(expired = FALSE)
  decoded <- decode_test_jwt(token)

  # Token should expire in the future
  expect_true(decoded$exp > as.numeric(Sys.time()))
})

test_that("create_test_jwt creates expired token that fails validation", {
  token <- create_test_jwt(expired = TRUE)
  
  # Decoding an expired token should throw error about expiration
  expect_error(
    decode_test_jwt(token),
    "expired"
  )
})


# =============================================================================
# JWT Token Validation Tests
# =============================================================================

test_that("JWT token can be decoded with correct secret", {
  token <- create_test_jwt()
  secret <- get_test_config("secret")
  key <- charToRaw(secret)

  # Should decode without error
  decoded <- jose::jwt_decode_hmac(token, secret = key)

  expect_true(is.list(decoded))
  expect_true("user_id" %in% names(decoded))
})

test_that("JWT token fails to decode with wrong secret", {
  token <- create_test_jwt()
  wrong_key <- charToRaw("wrong_secret_key_12345")

  # Should throw error with wrong secret
  expect_error(
    jose::jwt_decode_hmac(token, secret = wrong_key)
  )
})

test_that("auth_header formats token correctly", {
  token <- "test.jwt.token"
  header <- auth_header(token)

  expect_equal(header, "Bearer test.jwt.token")
})


# =============================================================================
# Token Expiration Logic Tests
# =============================================================================

test_that("expired token is rejected by decode", {
  token <- create_test_jwt(expired = TRUE)

  # Should throw error when trying to decode expired token
  expect_error(
    decode_test_jwt(token),
    "expired"
  )
})

test_that("valid token is not expired", {
  token <- create_test_jwt(expired = FALSE)
  decoded <- decode_test_jwt(token)

  # Check expiration - should be in the future
  is_expired <- decoded$exp < as.numeric(Sys.time())

  expect_false(is_expired)
})
