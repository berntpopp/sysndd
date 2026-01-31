# Security utilities for SysNDD API
# Provides password hashing and verification using Argon2id via sodium package
#
# Usage:
#   source("core/security.R")
#   hash <- hash_password("mypassword")
#   is_valid <- verify_password(stored_hash, "attempt")

# Note: db-helpers.R is sourced by start_sysndd_api.R before core modules
# The db_execute_statement function is available in the global environment

#' Check if password is already hashed (sodium/libsodium format)
#'
#' Detects hashes by checking for sodium pwhash prefixes:
#' - $argon2id$, $argon2i$, $argon2d$ (Argon2 variants)
#' - $7$ (libsodium pwhash scrypt format - default in sodium R package)
#'
#' @param password_from_db Password string from database
#' @return TRUE if hashed, FALSE if plaintext
#' @examples
#' is_hashed("$7$C6..../....salt$hash")
#' # TRUE
#' is_hashed("$argon2id$v=19$m=65536,t=3,p=1$...")
#' # TRUE
#' is_hashed("plaintext_password")
#' # FALSE
is_hashed <- function(password_from_db) {
  if (is.null(password_from_db) || is.na(password_from_db)) {
    return(FALSE)
  }
  # Match sodium pwhash formats: $7$ (scrypt) or $argon2 variants
  grepl("^\\$7\\$|^\\$argon2", password_from_db)
}

#' Hash password with Argon2id
#'
#' Uses sodium::password_store() which implements Argon2id hashing
#' with secure defaults (memory-hard, CPU-hard parameters).
#' The result includes the salt and parameters in PHC string format.
#'
#' @param password Plaintext password to hash
#' @return Argon2id hash string (includes salt and parameters)
#' @examples
#' hash <- hash_password("mypassword")
#' # Returns: "$argon2id$v=19$m=65536,t=3,p=1$..."
hash_password <- function(password) {
  if (is.null(password) || is.na(password) || nchar(password) == 0) {
    stop("Password cannot be NULL, NA, or empty")
  }
  sodium::password_store(password)
}

#' Verify password against stored hash (supports both plaintext and hashed)
#'
#' Handles progressive migration by detecting hash format:
#' - If stored password is Argon2id hash: uses sodium::password_verify
#' - If stored password is plaintext: uses direct comparison (legacy)
#'
#' Uses tryCatch to handle malformed hashes gracefully.
#'
#' @param password_from_db Stored password (plaintext or Argon2id hash)
#' @param password_attempt User-provided password attempt
#' @return TRUE if password matches, FALSE otherwise
#' @examples
#' # With hashed password
#' verify_password("$argon2id$v=19$...", "attempt")
#' # With plaintext password (legacy)
#' verify_password("plaintext", "plaintext")
verify_password <- function(password_from_db, password_attempt) {
  if (is.null(password_from_db) || is.na(password_from_db)) {
    return(FALSE)
  }
  if (is.null(password_attempt) || is.na(password_attempt)) {
    return(FALSE)
  }

  if (is_hashed(password_from_db)) {
    # Hashed password - use sodium verification
    tryCatch(
      sodium::password_verify(password_from_db, password_attempt),
      error = function(e) {
        # Verification error (malformed hash) = failed authentication
        # Log warning if logger is available
        if (requireNamespace("logger", quietly = TRUE)) {
          logger::log_warn("Password verification error: {e$message}")
        }
        return(FALSE)
      }
    )
  } else {
    # Plaintext password - direct comparison (legacy)
    password_from_db == password_attempt
  }
}

#' Check if password needs upgrade from plaintext to Argon2id
#'
#' Returns TRUE for passwords that are still stored as plaintext
#' and should be upgraded to Argon2id on next successful login.
#'
#' @param password_from_db Stored password
#' @return TRUE if needs upgrade (is plaintext), FALSE if already hashed
#' @examples
#' needs_upgrade("plaintext_password")
#' # TRUE
#' needs_upgrade("$argon2id$v=19$...")
#' # FALSE
needs_upgrade <- function(password_from_db) {
  !is_hashed(password_from_db)
}

#' Upgrade password from plaintext to Argon2id hash in database
#'
#' Called after successful plaintext verification to progressively
#' migrate passwords to Argon2id. Uses parameterized query to prevent
#' SQL injection.
#'
#' @param pool Database connection pool
#' @param user_id User ID to update
#' @param password_plaintext Verified plaintext password to hash and store
#' @return TRUE if upgraded successfully, FALSE on error
#' @examples
#' \dontrun{
#' upgrade_password(pool, 123, "verified_plaintext_password")
#' }
upgrade_password <- function(pool, user_id, password_plaintext) {
  tryCatch({
    new_hash <- hash_password(password_plaintext)
    db_execute_statement(
      "UPDATE user SET password = ? WHERE user_id = ?",
      list(new_hash, user_id)
    )
    # Log success if logger is available
    if (requireNamespace("logger", quietly = TRUE)) {
      logger::log_info("Password upgraded to Argon2id for user_id: {user_id}")
    }
    return(TRUE)
  }, error = function(e) {
    # Log error if logger is available
    if (requireNamespace("logger", quietly = TRUE)) {
      logger::log_error("Password upgrade failed for user_id: {user_id}, error: {e$message}")
    }
    return(FALSE)
  })
}
