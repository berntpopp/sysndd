# functions/re-review-sync.R
#
# Re-review approval synchronization utility.
# Ensures re_review_entity_connect.re_review_approved flag stays in sync
# when reviews/statuses are approved through standard pathways.

#' Sync re-review approval flag when reviews or statuses are approved
#'
#' Updates re_review_entity_connect.re_review_approved atomically within
#' the caller's transaction. Called by review_approve() and status_approve()
#' to ensure the re-review approval flag stays synchronized.
#'
#' @param review_ids Integer vector of review IDs being approved (optional)
#' @param status_ids Integer vector of status IDs being approved (optional)
#' @param approving_user_id Integer user ID performing the approval
#' @param conn Database connection (pool or transaction connection)
#'
#' @return invisible(NULL)
#' @keywords internal
sync_rereview_approval <- function(review_ids = NULL, status_ids = NULL, approving_user_id, conn = pool) {
  # Return silently if no IDs provided
  if (is.null(review_ids) && is.null(status_ids)) {
    return(invisible(NULL))
  }

  # Build WHERE clause based on which IDs are provided
  conditions <- character(0)
  params <- list()

  if (!is.null(review_ids) && length(review_ids) > 0) {
    review_placeholders <- paste(rep("?", length(review_ids)), collapse = ", ")
    conditions <- c(conditions, paste0("review_id IN (", review_placeholders, ")"))
    params <- c(params, as.list(review_ids))
  }

  if (!is.null(status_ids) && length(status_ids) > 0) {
    status_placeholders <- paste(rep("?", length(status_ids)), collapse = ", ")
    conditions <- c(conditions, paste0("status_id IN (", status_placeholders, ")"))
    params <- c(params, as.list(status_ids))
  }

  # If no conditions, return
  if (length(conditions) == 0) {
    return(invisible(NULL))
  }

  # Combine conditions with OR
  where_clause <- paste(conditions, collapse = " OR ")

  # Build complete SQL
  sql <- paste0(
    "UPDATE re_review_entity_connect ",
    "SET re_review_approved = 1, approving_user_id = ? ",
    "WHERE (", where_clause, ") ",
    "AND re_review_submitted = 1 ",
    "AND re_review_approved = 0"
  )

  # Prepend approving_user_id to params
  params <- c(list(approving_user_id), params)

  # Execute using db_execute_statement (handles unname internally)
  db_execute_statement(sql, params, conn = conn)

  invisible(NULL)
}
