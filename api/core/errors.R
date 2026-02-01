# RFC 9457 Error Helpers for SysNDD API
# Provides standardized HTTP error conditions using httpproblems package
#
# Usage:
#   source("core/errors.R")
#   stop_for_bad_request("Missing required parameter: user_name")
#   stop_for_unauthorized("Invalid credentials")

library(httpproblems)

#' Create a 400 Bad Request error condition
#'
#' For client errors involving malformed requests, missing parameters,
#' or invalid input formats.
#'
#' @param message Error message describing the issue
#' @param detail Optional additional detail for the error response
#' @return RFC 9457 compliant error condition with class "error_400"
#' @examples
#' error_bad_request("Missing required parameter: user_name")
error_bad_request <- function(message, detail = NULL) {
  err <- bad_request(detail = detail %||% message)
  # Create a proper condition so class is preserved through stop()
  cond <- simpleError(message)
  cond$http_problem <- err
  cond$status <- 400
  class(cond) <- c("error_400", "http_problem_error", class(cond))
  cond
}

#' Create a 401 Unauthorized error condition
#'
#' For authentication failures - credentials missing, invalid, or expired.
#'
#' @param message Error message (default: "Authentication required")
#' @param detail Optional additional detail for the error response
#' @return RFC 9457 compliant error condition with class "error_401"
#' @examples
#' error_unauthorized("Invalid username or password")
error_unauthorized <- function(message = "Authentication required", detail = NULL) {
  err <- unauthorized(detail = detail %||% message)
  # Create a proper condition so class is preserved through stop()
  cond <- simpleError(message)
  cond$http_problem <- err
  cond$status <- 401
  class(cond) <- c("error_401", "http_problem_error", class(cond))
  cond
}

#' Create a 403 Forbidden error condition
#'
#' For authorization failures - user is authenticated but lacks permission
#' to perform the requested action.
#'
#' @param message Error message (default: "Insufficient permissions")
#' @param detail Optional additional detail for the error response
#' @return RFC 9457 compliant error condition with class "error_403"
#' @examples
#' error_forbidden("You do not have permission to modify this resource")
error_forbidden <- function(message = "Insufficient permissions", detail = NULL) {
  err <- forbidden(detail = detail %||% message)
  # Create a proper condition so class is preserved through stop()
  cond <- simpleError(message)
  cond$http_problem <- err
  cond$status <- 403
  class(cond) <- c("error_403", "http_problem_error", class(cond))
  cond
}

#' Create a 404 Not Found error condition
#'
#' For resources that do not exist or cannot be found.
#'
#' @param message Error message describing what was not found
#' @param detail Optional additional detail for the error response
#' @return RFC 9457 compliant error condition with class "error_404"
#' @examples
#' error_not_found("User with ID 123 not found")
error_not_found <- function(message, detail = NULL) {
  err <- not_found(detail = detail %||% message)
  # Create a proper condition so class is preserved through stop()
  cond <- simpleError(message)
  cond$http_problem <- err
  cond$status <- 404
  class(cond) <- c("error_404", "http_problem_error", class(cond))
  cond
}

#' Create a 500 Internal Server Error condition
#'
#' For unexpected server-side errors. The message returned to clients
#' should be generic to avoid leaking internal details.
#'
#' @param message Error message (default: "An unexpected error occurred")
#' @param detail Optional additional detail for the error response
#' @return RFC 9457 compliant error condition with class "error_500"
#' @examples
#' error_internal("An unexpected error occurred")
error_internal <- function(message = "An unexpected error occurred", detail = NULL) {
  err <- internal_server_error(detail = detail %||% message)
  # Create a proper condition so class is preserved through stop()
  cond <- simpleError(message)
  cond$http_problem <- err
  cond$status <- 500
  class(cond) <- c("error_500", "http_problem_error", class(cond))
  cond
}

# Convenience stop functions for signaling errors in endpoints

#' Stop execution with a 400 Bad Request error
#'
#' Convenience wrapper that signals a bad_request error condition.
#'
#' @param message Error message describing the issue
#' @param detail Optional additional detail for the error response
#' @examples
#' \dontrun{
#' if (missing(user_name)) {
#'   stop_for_bad_request("Missing required parameter: user_name")
#' }
#' }
stop_for_bad_request <- function(message, detail = NULL) {
  stop(error_bad_request(message, detail))
}

#' Stop execution with a 401 Unauthorized error
#'
#' Convenience wrapper that signals an unauthorized error condition.
#'
#' @param message Error message (default: "Authentication required")
#' @param detail Optional additional detail for the error response
#' @examples
#' \dontrun{
#' if (!authenticated) {
#'   stop_for_unauthorized("Invalid username or password")
#' }
#' }
stop_for_unauthorized <- function(message = "Authentication required", detail = NULL) {
  stop(error_unauthorized(message, detail))
}

#' Stop execution with a 403 Forbidden error
#'
#' Convenience wrapper that signals a forbidden error condition.
#'
#' @param message Error message (default: "Insufficient permissions")
#' @param detail Optional additional detail for the error response
#' @examples
#' \dontrun{
#' if (!user_has_permission) {
#'   stop_for_forbidden("You do not have permission to access this resource")
#' }
#' }
stop_for_forbidden <- function(message = "Insufficient permissions", detail = NULL) {
  stop(error_forbidden(message, detail))
}

#' Stop execution with a 404 Not Found error
#'
#' Convenience wrapper that signals a not_found error condition.
#'
#' @param message Error message describing what was not found
#' @param detail Optional additional detail for the error response
#' @examples
#' \dontrun{
#' user <- get_user(user_id)
#' if (is.null(user)) {
#'   stop_for_not_found(sprintf("User with ID %s not found", user_id))
#' }
#' }
stop_for_not_found <- function(message, detail = NULL) {
  stop(error_not_found(message, detail))
}
