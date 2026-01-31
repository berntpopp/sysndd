# Approval Service Layer for SysNDD API
# Provides business logic for review and status approval workflows
#
# Functions accept pool as parameter (dependency injection)
# Handles both single ID and "all" batch operations
# Uses repository functions for database operations

library(dplyr)

#' Approve or unapprove reviews (service layer)
#'
#' Business logic for review approval workflow. Handles single review_id,
#' multiple review_ids, or "all" for batch approval of pending reviews.
#' Delegates to repository which handles approval atomically.
#'
#' @param review_id Review ID(s) to approve, or "all" for all pending
#' @param user_id User performing the approval
#' @param approve Logical - TRUE to approve, FALSE to unapprove
#' @param pool Database connection pool
#' @return List with status, message, and entry (review_id(s))
#' @examples
#' \dontrun{
#' # Approve single review
#' result <- svc_approval_review_approve(42, user_id = 10, approve = TRUE, pool = pool)
#'
#' # Approve multiple reviews
#' result <- svc_approval_review_approve(c(42, 43), user_id = 10, approve = TRUE, pool = pool)
#'
#' # Approve all pending reviews
#' result <- svc_approval_review_approve("all", user_id = 10, approve = TRUE, pool = pool)
#'
#' # Unapprove review
#' result <- svc_approval_review_approve(42, user_id = 10, approve = FALSE, pool = pool)
#' }
svc_approval_review_approve <- function(review_id, user_id, approve = FALSE, pool) {
  # Validate inputs
  if (is.null(review_id) || is.null(user_id)) {
    return(list(
      status = 400,
      error = "Submitted data can not be null."
    ))
  }

  # Convert approve to logical
  approve <- as.logical(approve)

  # Handle "all" case - get all pending reviews
  if (as.character(review_id) == "all") {
    pending_reviews <- pool %>%
      tbl("ndd_entity_review") %>%
      filter(review_approved == 0) %>%
      select(review_id) %>%
      collect()

    review_ids <- pending_reviews$review_id
  } else {
    review_ids <- as.integer(review_id)
  }

  # Check if there are reviews to process
  if (length(review_ids) == 0) {
    return(list(
      status = 200,
      message = "OK. No reviews to approve.",
      entry = integer(0)
    ))
  }

  # Use repository to approve/unapprove reviews
  review_approve(review_ids, user_id, approve)

  # Return success
  return(list(
    status = 200,
    message = "OK. Review approved.",
    entry = review_ids
  ))
}


#' Approve or unapprove status entries (service layer)
#'
#' Business logic for status approval workflow. Handles single status_id,
#' multiple status_ids, or "all" for batch approval of pending statuses.
#' Delegates to repository which handles approval atomically.
#'
#' @param status_id Status ID(s) to approve, or "all" for all pending
#' @param user_id User performing the approval
#' @param approve Logical - TRUE to approve, FALSE to unapprove
#' @param pool Database connection pool
#' @return List with status, message, and entry (status_id(s))
#' @examples
#' \dontrun{
#' # Approve single status
#' result <- svc_approval_status_approve(42, user_id = 10, approve = TRUE, pool = pool)
#'
#' # Approve multiple statuses
#' result <- svc_approval_status_approve(c(42, 43), user_id = 10, approve = TRUE, pool = pool)
#'
#' # Approve all pending statuses
#' result <- svc_approval_status_approve("all", user_id = 10, approve = TRUE, pool = pool)
#'
#' # Unapprove status
#' result <- svc_approval_status_approve(42, user_id = 10, approve = FALSE, pool = pool)
#' }
svc_approval_status_approve <- function(status_id, user_id, approve = FALSE, pool) {
  # Validate inputs
  if (is.null(status_id) || is.null(user_id)) {
    return(list(
      status = 400,
      error = "Submitted data can not be null."
    ))
  }

  # Convert approve to logical
  approve <- as.logical(approve)

  # Handle "all" case - get all pending statuses
  if (as.character(status_id) == "all") {
    pending_statuses <- pool %>%
      tbl("ndd_entity_status") %>%
      filter(status_approved == 0) %>%
      select(status_id) %>%
      collect()

    status_ids <- pending_statuses$status_id
  } else {
    status_ids <- as.integer(status_id)
  }

  # Check if there are statuses to process
  if (length(status_ids) == 0) {
    return(list(
      status = 200,
      message = "OK. No statuses to approve.",
      entry = integer(0)
    ))
  }

  # Use repository to approve/unapprove statuses
  status_approve(status_ids, user_id, approve)

  # Return success
  return(list(
    status = 200,
    message = "OK. Status approved.",
    entry = status_ids
  ))
}
