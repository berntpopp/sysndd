# Response Builder Utilities for SysNDD API
# Provides consistent response structures for success and error cases
#
# Usage:
#   source("core/responses.R")
#   return(response_success(data = user_data, message = "User retrieved"))
#   return(response_error("Validation failed", status = 400))

#' Build a successful API response
#'
#' Creates a consistent response structure for successful operations.
#' The data is always wrapped in a "data" field, with an optional message.
#'
#' @param data Data to return (can be list, data.frame, vector, etc.)
#' @param message Optional success message to include
#' @return List with consistent structure: list(data = ..., message = ...)
#' @examples
#' response_success(list(user_id = 1, name = "John"))
#' response_success(data = user_df, message = "Users retrieved successfully")
response_success <- function(data, message = NULL) {
  result <- list(data = data)
  if (!is.null(message)) {
    result$message <- message
  }
  return(result)
}

#' Build an RFC 9457 compliant error response
#'
#' Creates an error response following the RFC 9457 Problem Details format.
#' Use this as a fallback when not using httpproblems package directly.
#'
#' Response structure:
#' - type: URI reference identifying the problem type
#' - title: Short summary of the problem
#' - status: HTTP status code
#' - detail: (optional) Detailed explanation specific to this occurrence
#'
#' @param message Error message (used as "title" in RFC 9457)
#' @param status HTTP status code (e.g., 400, 401, 404, 500)
#' @param detail Optional additional detail about this specific error occurrence
#' @return RFC 9457 compliant error object
#' @examples
#' response_error("Bad Request", status = 400, detail = "Missing user_name parameter")
#' response_error("Not Found", status = 404, detail = "User ID 123 does not exist")
response_error <- function(message, status, detail = NULL) {
  # RFC 9457 type URIs based on status code class
  type_map <- list(
    "4" = "https://tools.ietf.org/html/rfc9457#section-4.1",
    "5" = "https://tools.ietf.org/html/rfc9457#section-4.2"
  )

  # Get first digit for type classification
  status_class <- substr(as.character(status), 1, 1)
  type_uri <- type_map[[status_class]] %||% "about:blank"

  error <- list(
    type = type_uri,
    title = message,
    status = status
  )

  if (!is.null(detail)) {
    error$detail <- detail
  }

  return(error)
}
