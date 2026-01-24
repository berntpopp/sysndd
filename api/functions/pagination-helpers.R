# pagination-helpers.R
#
# Purpose: Pagination safety utilities with configurable max page size limits
# Author: SysNDD Team
# Created: 2026-01-24
#
# This module provides safe wrappers around generate_cursor_pag_inf to prevent
# DoS attacks via unlimited page_size requests (PAG-02 requirement).
#
# Functions:
#   - validate_page_size: Validates and sanitizes page_size parameter
#   - generate_cursor_pag_inf_safe: Safe wrapper with max limit enforcement

# Global configuration constant
PAGINATION_MAX_SIZE <- 500 # PAG-02 requirement

#' Validate Page Size
#'
#' Validates and sanitizes page_size parameter with configurable maximum limit.
#'
#' @param page_size Character or numeric page size value
#' @param max_size Integer maximum allowed page size (default: 500)
#'
#' @return Character validated page size ("all" or numeric as string)
#'
#' @details
#' Validation rules:
#' - If page_size == "all", returns "all" unchanged
#' - If page_size > max_size, caps at max_size and logs warning
#' - If page_size < 1, returns "10" (default)
#' - Returns validated integer as character for API consistency
#'
#' @examples
#' validate_page_size("all")           # Returns "all"
#' validate_page_size(100)             # Returns "100"
#' validate_page_size(1000)            # Returns "500" + logs warning
#' validate_page_size(0)               # Returns "10"
validate_page_size <- function(page_size, max_size = PAGINATION_MAX_SIZE) {
  # Handle "all" case - no validation needed
  if (is.character(page_size) && page_size == "all") {
    return("all")
  }

  # Convert to integer
  page_size_int <- as.integer(page_size)

  # Check if conversion failed
  if (is.na(page_size_int)) {
    log_warn(paste0(
      "Invalid page_size provided: '", page_size,
      "'. Defaulting to 10."
    ))
    return("10")
  }

  # Apply maximum limit
  if (page_size_int > max_size) {
    log_warn(paste0(
      "Page size ", page_size_int, " exceeds maximum allowed (", max_size,
      "). Capping at ", max_size, "."
    ))
    page_size_int <- max_size
  }

  # Apply minimum limit
  if (page_size_int < 1) {
    log_warn(paste0(
      "Page size ", page_size_int, " is below minimum (1). ",
      "Defaulting to 10."
    ))
    return("10")
  }

  # Return validated size as character for API consistency
  return(as.character(page_size_int))
}

#' Generate Cursor Pagination Information (Safe)
#'
#' Safe wrapper around generate_cursor_pag_inf with max page_size enforcement.
#'
#' @param pagination_tibble Tibble containing data to paginate
#' @param page_size Character or numeric page size (default: "all")
#' @param page_after Integer cursor position (default: 0)
#' @param pagination_identifier Character column name for cursor (default: "entity_id")
#' @param max_page_size Integer maximum allowed page size (default: PAGINATION_MAX_SIZE)
#'
#' @return List with paginated data and pagination metadata
#'
#' @details
#' This function validates page_size before delegating to generate_cursor_pag_inf.
#' It provides DoS protection by capping page_size at a configurable maximum.
#'
#' @examples
#' generate_cursor_pag_inf_safe(entities, page_size = 50, page_after = 0)
#' generate_cursor_pag_inf_safe(entities, page_size = "all")
generate_cursor_pag_inf_safe <- function(
  pagination_tibble,
  page_size = "all",
  page_after = 0,
  pagination_identifier = "entity_id",
  max_page_size = PAGINATION_MAX_SIZE
) {
  # Validate and sanitize page_size
  validated_size <- validate_page_size(page_size, max_page_size)

  # Delegate to original function with validated parameters
  generate_cursor_pag_inf(
    pagination_tibble,
    validated_size,
    page_after,
    pagination_identifier
  )
}
