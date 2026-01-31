# tests/testthat/helper-auth.R
# Authentication helpers for tests
#
# Provides JWT token generation for testing protected endpoints.
# Uses jose package (same as production API).

library(jose)

#' Generate test JWT token
#'
#' Creates a JWT token for testing purposes. Uses the secret from
#' sysndd_db_test config to ensure tokens are valid for the test API.
#'
#' @param user_id User ID to encode in token (default: 1)
#' @param user_name Username to encode (default: "test_user")
#' @param user_role User role (default: "Curator")
#' @param expired If TRUE, creates an already-expired token for testing
#'   token expiration handling (default: FALSE)
#'
#' @return JWT string
#'
#' @examples
#' # Create valid test token
#' token <- create_test_jwt()
#'
#' # Create token for specific user
#' token <- create_test_jwt(user_id = 42, user_role = "Administrator")
#'
#' # Create expired token for testing expiration handling
#' expired_token <- create_test_jwt(expired = TRUE)
create_test_jwt <- function(user_id = 1,
                            user_name = "test_user",
                            user_role = "Curator",
                            expired = FALSE) {
  # Get secret from test config
  secret <- get_test_config("secret")

  if (is.null(secret)) {
    stop("Could not retrieve secret from test config")
  }

  key <- charToRaw(secret)

  # Set expiration time
  exp_time <- if (expired) {
    as.numeric(Sys.time()) - 3600  # Expired 1 hour ago
  } else {
    as.numeric(Sys.time()) + 3600  # Valid for 1 hour
  }

  # Create JWT claim matching the structure in authentication_endpoints.R
  claim <- jose::jwt_claim(
    user_id = user_id,
    user_name = user_name,
    email = paste0(user_name, "@test.example.com"),
    user_role = user_role,
    user_created = as.character(Sys.time()),
    abbreviation = toupper(substr(user_name, 1, 2)),
    orcid = "0000-0000-0000-0000",
    iat = as.numeric(Sys.time()),
    exp = exp_time
  )

  # Encode with HMAC (same as production)
  jose::jwt_encode_hmac(claim, secret = key)
}


#' Decode test JWT token
#'
#' Decodes a JWT token using the test config secret.
#' Useful for verifying token contents in tests.
#'
#' @param token JWT string to decode
#' @return List with token claims
decode_test_jwt <- function(token) {
  secret <- get_test_config("secret")
  key <- charToRaw(secret)

  jose::jwt_decode_hmac(token, secret = key)
}


#' Get Authorization header value
#'
#' Formats a JWT token as a Bearer authorization header value.
#'
#' @param token JWT string
#' @return String formatted as "Bearer {token}"
auth_header <- function(token) {
  paste("Bearer", token)
}
