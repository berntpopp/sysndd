# Logging Sanitization Utilities for SysNDD API
# Provides functions to remove sensitive data before logging
#
# Usage:
#   source("core/logging_sanitizer.R")
#   log_info("Request received", request = sanitize_request(req))
#   log_debug("User data", user = sanitize_user(user_table))

# Define sensitive field names that should be redacted in logs
# Case-insensitive matching is used when sanitizing
SENSITIVE_FIELDS <- c(
  "password",
  "old_pass",
  "new_pass",
  "new_pass_1",
  "new_pass_2",
  "token",
  "jwt",
  "api_key",
  "secret",
  "authorization"
)

#' Recursively sanitize sensitive fields in nested lists
#'
#' Traverses list structures and replaces values of sensitive fields
#' with "[REDACTED]". Uses case-insensitive matching for field names.
#'
#' @param obj Object to sanitize (list, vector, or primitive)
#' @return Sanitized object with sensitive field values replaced
#' @examples
#' sanitize_object(list(user = "john", password = "secret123"))
#' # Returns: list(user = "john", password = "[REDACTED]")
sanitize_object <- function(obj) {
  if (is.null(obj)) {
    return(NULL)
  }

  if (is.list(obj) && !is.null(names(obj))) {
    # Named list - check each field name
    sanitized <- lapply(names(obj), function(name) {
      if (tolower(name) %in% tolower(SENSITIVE_FIELDS)) {
        "[REDACTED]"
      } else {
        sanitize_object(obj[[name]])
      }
    })
    names(sanitized) <- names(obj)
    return(sanitized)
  } else if (is.list(obj)) {
    # Unnamed list - recurse into elements
    return(lapply(obj, sanitize_object))
  } else {
    # Primitive value - return as-is
    return(obj)
  }
}

#' Sanitize Plumber request object for safe logging
#'
#' Extracts safe fields from Plumber request and sanitizes potentially
#' sensitive data like headers, args, and body.
#'
#' Safe fields retained: PATH_INFO, REQUEST_METHOD, QUERY_STRING, REMOTE_ADDR
#' Sanitized: headers (especially Authorization), args, body
#'
#' @param req Plumber request object
#' @return Sanitized request object safe for logging
#' @examples
#' \dontrun{
#' log_info("Request received", request = sanitize_request(req))
#' }
sanitize_request <- function(req) {
  if (is.null(req)) {
    return(NULL)
  }

  # Build safe request object with only safe fields
  req_safe <- list(
    PATH_INFO = req$PATH_INFO %||% NA_character_,
    REQUEST_METHOD = req$REQUEST_METHOD %||% NA_character_,
    QUERY_STRING = req$QUERY_STRING %||% NA_character_,
    REMOTE_ADDR = req$REMOTE_ADDR %||% NA_character_
  )

  # Sanitize headers (especially Authorization, X-Api-Key)
  if (!is.null(req$HEADERS)) {
    headers_safe <- as.list(req$HEADERS)
    # Redact known sensitive headers
    sensitive_headers <- c("authorization", "x-api-key", "cookie", "x-auth-token")
    for (header_name in names(headers_safe)) {
      if (tolower(header_name) %in% sensitive_headers) {
        headers_safe[[header_name]] <- "[REDACTED]"
      }
    }
    req_safe$HEADERS <- headers_safe
  }

  # Also check HTTP_ prefixed headers (Plumber convention)
  if (!is.null(req$HTTP_AUTHORIZATION)) {
    req_safe$HTTP_AUTHORIZATION <- "[REDACTED]"
  }

  # Sanitize args (query parameters and path parameters)
  if (!is.null(req$args)) {
    req_safe$args <- sanitize_object(req$args)
  }

  # Sanitize body (POST/PUT request body)
  if (!is.null(req$body)) {
    req_safe$body <- sanitize_object(req$body)
  }

  # Sanitize argsBody (alternative body accessor in Plumber)
  if (!is.null(req$argsBody)) {
    req_safe$argsBody <- sanitize_object(req$argsBody)
  }

  return(req_safe)
}

#' Sanitize user data for safe logging
#'
#' Handles both data.frame and list representations of user data.
#' Replaces sensitive fields (password, token) with "[REDACTED]".
#'
#' @param user User data (data.frame or list)
#' @return Sanitized user data safe for logging
#' @examples
#' sanitize_user(list(user_id = 1, password = "secret"))
#' # Returns: list(user_id = 1, password = "[REDACTED]")
sanitize_user <- function(user) {
  if (is.null(user)) {
    return(NULL)
  }

  if (is.data.frame(user)) {
    # Data frame - sanitize column values
    user_safe <- user
    sensitive_columns <- intersect(tolower(names(user_safe)), tolower(SENSITIVE_FIELDS))
    for (col in names(user_safe)) {
      if (tolower(col) %in% tolower(SENSITIVE_FIELDS)) {
        user_safe[[col]] <- "[REDACTED]"
      }
    }
    return(user_safe)
  } else if (is.list(user)) {
    # List - use recursive sanitization
    return(sanitize_object(user))
  } else {
    # Unknown type - return as-is
    return(user)
  }
}
