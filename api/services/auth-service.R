# Authentication Service Layer for SysNDD API
# Provides business logic for signin, verify, and refresh operations
#
# Functions accept pool and config as parameters (dependency injection)
# Uses verify_password from core/security.R for dual-hash support
# Uses jose package for JWT encoding/decoding
# Uses core/errors.R helpers for RFC 9457 errors

#' Authenticate user and return JWT token
#'
#' Validates credentials against database, checks account status,
#' and generates JWT token pair (access + refresh) on success.
#'
#' @param user_name Username to authenticate
#' @param password Plain text password
#' @param pool Database connection pool
#' @param config Configuration object with JWT secret and expiry
#' @return List with access_token, refresh_token, token_type, expires_in, and user info
#' @examples
#' \dontrun{
#' result <- auth_signin("johndoe", "password123", pool, config)
#' # Returns: list(access_token, refresh_token, token_type, expires_in, user)
#' }
auth_signin <- function(user_name, password, pool, config) {
  # Validate inputs
  if (missing(user_name) || is.null(user_name) || nchar(trimws(user_name)) == 0) {
    stop_for_bad_request("user_name is required")
  }
  if (missing(password) || is.null(password) || nchar(password) == 0) {
    stop_for_bad_request("password is required")
  }

  # Look up user (include password for verification)
  user <- pool %>%
    tbl("user") %>%
    filter(user_name == !!user_name) %>%
    collect()

  if (nrow(user) == 0) {
    stop_for_unauthorized("Invalid username or password")
  }

  user <- user[1, ]

  # Check account status
  if (user$account_status != "active") {
    stop_for_unauthorized("Account is not active")
  }

  # Verify password using security.R helper (handles legacy + Argon2id)
  if (!verify_password(user$password, password)) {
    stop_for_unauthorized("Invalid username or password")
  }

  # Progressive password upgrade if needed
  if (needs_upgrade(user$password)) {
    upgrade_password(pool, user$user_id, password)
  }

  # Generate JWT token pair
  token <- auth_generate_token(user, config)

  logger::log_info("User signed in", user_id = user$user_id, user_name = user$user_name)

  list(
    access_token = token$access_token,
    refresh_token = token$refresh_token,
    token_type = "Bearer",
    expires_in = config$token_expiry %||% 3600,
    user = list(
      user_id = user$user_id,
      user_name = user$user_name,
      user_role = user$user_role,
      email = user$email
    )
  )
}


#' Verify JWT token and return user info
#'
#' Validates token signature and expiration without database lookup.
#' Returns user claims if valid, signals error if invalid/expired.
#'
#' @param jwt JWT token string (without "Bearer " prefix)
#' @param config Configuration object with JWT secret
#' @return List with user info (user_id, user_name, email, user_role, etc.)
#' @examples
#' \dontrun{
#' user_info <- auth_verify("eyJhbGciOiJIUzI1NiIsInR5...", config)
#' # Returns: list(user_id, user_name, email, user_role, ...)
#' }
auth_verify <- function(jwt, config) {
  if (missing(jwt) || is.null(jwt) || nchar(jwt) == 0) {
    stop_for_unauthorized("Token is required")
  }

  # Validate and decode token
  user <- auth_validate_token(jwt, config)

  if (is.null(user)) {
    stop_for_unauthorized("Invalid or expired token")
  }

  # Check expiration
  if (user$exp < as.numeric(Sys.time())) {
    stop_for_unauthorized("Token has expired")
  }

  # Return user info (excluding internal fields)
  list(
    user_id = user$user_id,
    user_name = user$user_name,
    email = user$email,
    user_role = user$user_role,
    user_created = user$user_created,
    abbreviation = user$abbreviation,
    orcid = user$orcid,
    exp = user$exp
  )
}


#' Refresh JWT token with new expiration
#'
#' Validates existing token and issues new token with extended expiry.
#' Requires token to be valid (not expired).
#'
#' @param refresh_token Current JWT refresh token
#' @param pool Database connection pool (unused but kept for consistency)
#' @param config Configuration object with JWT secret and expiry
#' @return New JWT token string
#' @examples
#' \dontrun{
#' new_token <- auth_refresh("eyJhbGciOiJIUzI1NiIsInR5...", pool, config)
#' # Returns: "eyJhbGciOiJIUzI1NiIsInR5..."
#' }
auth_refresh <- function(refresh_token, pool, config) {
  if (missing(refresh_token) || is.null(refresh_token) || nchar(refresh_token) == 0) {
    stop_for_bad_request("refresh_token is required")
  }

  # Validate current token
  user <- auth_validate_token(refresh_token, config)

  if (is.null(user)) {
    stop_for_unauthorized("Invalid refresh token")
  }

  # Check expiration
  if (user$exp < as.numeric(Sys.time())) {
    stop_for_unauthorized("Refresh token has expired")
  }

  # Generate new token with same user claims
  token <- auth_generate_token(user, config)

  logger::log_info("Token refreshed", user_id = user$user_id)

  # Return just the access token (string format for backward compatibility)
  token$access_token
}


#' Generate JWT token pair for user
#'
#' Internal helper to create access and refresh tokens with user claims.
#' Uses jose::jwt_encode_hmac for HMAC-SHA256 signing.
#'
#' @param user User object or list with user_id, user_name, email, etc.
#' @param config Configuration object with JWT secret and expiry
#' @return List with access_token and refresh_token
auth_generate_token <- function(user, config) {
  key <- charToRaw(config$secret)

  # Create claim with user info
  claim <- jose::jwt_claim(
    user_id = user$user_id,
    user_name = user$user_name,
    email = user$email,
    user_role = user$user_role,
    user_created = user$user_created %||% user$created_at,
    abbreviation = user$abbreviation,
    orcid = user$orcid,
    iat = as.numeric(Sys.time()),
    exp = as.numeric(Sys.time()) + (config$refresh %||% 86400)
  )

  # Encode JWT
  token <- jose::jwt_encode_hmac(claim, secret = key)

  # Return both access and refresh (same token for now, can be separated later)
  list(
    access_token = token,
    refresh_token = token
  )
}


#' Validate and decode JWT token
#'
#' Internal helper to decode JWT using jose::jwt_decode_hmac.
#' Returns user claims or NULL on error (invalid signature, malformed token).
#'
#' @param jwt JWT token string
#' @param config Configuration object with JWT secret
#' @return User claims list or NULL if validation fails
auth_validate_token <- function(jwt, config) {
  key <- charToRaw(config$secret)

  tryCatch(
    {
      user <- jose::jwt_decode_hmac(jwt, secret = key)
      return(user)
    },
    error = function(e) {
      logger::log_warn("Token validation failed", error = e$message)
      return(NULL)
    }
  )
}
