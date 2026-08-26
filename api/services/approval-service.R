# Approval Service Layer for SysNDD API
# Provides business logic for review and status approval workflows
#
# Functions accept pool as parameter (dependency injection)
# Handles both single ID and "all" batch operations
# Uses repository functions for database operations

library(dplyr)

#' Approve or unapprove reviews (service layer)
#'
#' Business logic for the review approval workflow. Handles a single review_id, a
#' vector of them, or "all" for batch approval of pending reviews. Delegates the
#' row writes to `review_approve()`.
#'
#' #612 -- APPROVAL IS WHEN THE SERVED SET BECOMES REAL. Write reconciliation
#' gates its rejection edges on `review_write_save_determines_served_set()`, and
#' `review_update()` unconditionally sets `review_approved = 0`, so on the
#' ordinary edit-then-approve-separately workflow a removed term never has its
#' assertion retired: it stops being served but stays `active_unconfirmed`, and
#' the curation queue keeps offering it. This function therefore reconciles each
#' affected entity after approving, REJECTION-ONLY
#' (`variation_provenance_reconcile_on_approval()`): approving a review is an act
#' on the review, not a per-term reading of machine evidence, so it must never
#' promote anything to `confirmed`.
#'
#' The approval and the reconciliation share ONE transaction scope, so a
#' reconciliation failure rolls the approval back rather than leaving an entity
#' whose served terms and provenance disagree.
#'
#' Direct approval does NOT come through here: `review_write_mutate()`
#' (services/review-write-service.R) calls `review_approve()` itself on its own
#' transaction, having already reconciled in that same transaction. The one live
#' caller is `PUT /api/review/approve/<review_id_requested>`.
#'
#' @param review_id Review ID(s) to approve, or "all" for all pending
#' @param user_id User performing the approval
#' @param approve Logical - TRUE to approve, FALSE to unapprove
#' @param pool Database connection pool (or a caller-owned DBI connection)
#' @return List with status, message, and entry (review_id(s))
#' @examples
#' \dontrun{
#' result <- svc_approval_review_approve(42, user_id = 10, approve = TRUE, pool = pool)
#' result <- svc_approval_review_approve(c(42, 43), user_id = 10, approve = TRUE, pool = pool)
#' result <- svc_approval_review_approve("all", user_id = 10, approve = TRUE, pool = pool)
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

  # Guard on LENGTH first. `if (as.character(c(42, 43)) == "all")` raises "the
  # condition has length > 1", so the documented vector support above has never
  # actually worked -- and the per-entity reconciliation below needs it to.
  is_all <- length(review_id) == 1L && identical(as.character(review_id), "all")

  if (is_all) {
    pending_reviews <- pool %>%
      tbl("ndd_entity_review") %>%
      dplyr::filter(review_approved == 0, is.na(approving_user_id)) %>%
      dplyr::select(review_id) %>%
      collect()

    review_ids <- as.integer(pending_reviews$review_id)
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

  # Approve and reconcile in ONE scope. Pool -> transaction; caller-owned
  # connection -> savepoint (db_with_savepoint_or_transaction, #612).
  db_with_savepoint_or_transaction(pool, "review_approve_reconcile", fn = function(conn) {
    review_approve(review_ids, user_id, approve, conn = conn)

    if (!isTRUE(approve)) {
      # Unapproving does not establish a served set, so nothing is retired.
      return(invisible(NULL))
    }

    placeholders <- paste(rep("?", length(review_ids)), collapse = ", ")
    entity_rows <- db_execute_query(
      paste0(
        "SELECT DISTINCT entity_id FROM ndd_entity_review WHERE review_id IN (",
        placeholders, ")"
      ),
      as.list(review_ids),
      conn = conn
    )
    if (is.null(entity_rows) || nrow(entity_rows) == 0L) {
      return(invisible(NULL))
    }

    # The served set is read AFTER review_approve() has run on this connection,
    # so it observes the review this scope just made primary and approved. An
    # empty served set is meaningful, not a reason to skip -- see
    # variation_provenance_reconcile_on_approval().
    for (entity_id in unique(as.integer(entity_rows$entity_id))) {
      variation_provenance_reconcile_on_approval(
        entity_id = entity_id, review_user_id = user_id, conn = conn
      )
    }
    invisible(NULL)
  })

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
      dplyr::filter(status_approved == 0, is.na(approving_user_id)) %>%
      dplyr::select(status_id) %>%
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

# ---------------------------------------------------------------------------
# Direct-approval helpers for the modify path (issues #36 / #37)
# ---------------------------------------------------------------------------
# These fold an optional "approve in the same request" step onto the status /
# review create+update handlers, mirroring the entity-create direct-approval
# flow. They reuse svc_approval_*_approve so the sibling-reset semantics
# (one active status / one primary review per entity) stay identical to the
# /approve endpoints. Role gating (Curator+) is enforced by the endpoint
# BEFORE these run; they only act when `direct_approval` is TRUE and the
# preceding write succeeded.

#' Fold a direct-approval step onto a status write response
#'
#' @param write_response List returned by the status write (`status`,
#'   `message`, `entry` = status_id).
#' @param user_id Integer user id performing the approval.
#' @param direct_approval Logical; when FALSE the write_response is returned
#'   unchanged.
#' @param pool Database connection pool.
#' @return The (possibly augmented) write_response list.
svc_status_apply_direct_approval <- function(write_response,
                                             user_id,
                                             direct_approval,
                                             pool) {
  if (!isTRUE(direct_approval)) {
    return(write_response)
  }
  if (is.null(write_response$status) || write_response$status != 200) {
    return(write_response)
  }
  status_id <- write_response$entry
  if (is.null(status_id) || length(status_id) == 0 || is.na(status_id[[1]])) {
    return(write_response)
  }

  approval <- svc_approval_status_approve(status_id, user_id, TRUE, pool)
  if (is.null(approval$status) || approval$status != 200) {
    write_response$status <- approval$status %||% 500
    write_response$message <- paste(
      write_response$message,
      "Direct approval failed:",
      approval$message %||% approval$error %||% "unknown error"
    )
  } else {
    write_response$message <- paste(write_response$message, "Status approved.")
  }
  write_response
}

#' Fold a direct-approval step onto a review write response
#'
#' @param write_response List returned by the review handler (`status`,
#'   `message`).
#' @param review_id Integer review id to approve (from the write result).
#' @param user_id Integer user id performing the approval.
#' @param direct_approval Logical; when FALSE the write_response is returned
#'   unchanged.
#' @param pool Database connection pool.
#' @return The (possibly augmented) write_response list.
review_apply_direct_approval <- function(write_response,
                                         review_id,
                                         user_id,
                                         direct_approval,
                                         pool) {
  if (!isTRUE(direct_approval)) {
    return(write_response)
  }
  # The review handler may return a vectorized status (one element per distinct
  # downstream message), so collapse to a single "all OK" check.
  if (is.null(write_response$status) || !all(write_response$status == 200)) {
    return(write_response)
  }
  if (is.null(review_id) || length(review_id) == 0 || is.na(review_id[[1]])) {
    write_response$message <- paste(
      write_response$message,
      "Direct approval skipped: review id unavailable."
    )
    return(write_response)
  }

  approval <- svc_approval_review_approve(review_id, user_id, TRUE, pool)
  if (is.null(approval$status) || approval$status != 200) {
    write_response$status <- approval$status %||% 500
    write_response$message <- paste(
      write_response$message,
      "Direct approval failed:",
      approval$message %||% approval$error %||% "unknown error"
    )
  } else {
    write_response$message <- paste(write_response$message, "Review approved.")
  }
  write_response
}

# ---------------------------------------------------------------------------
# Migrated from legacy-wrappers.R (Phase D, D4)
# ---------------------------------------------------------------------------

#' Approve review (migrated from legacy-wrappers.R)
#'
#' @param review_id Integer review ID to approve
#' @param approving_user_id Integer user ID of approver
#' @param approved Logical TRUE to approve, FALSE to reject
#' @return List with status and message
put_db_review_approve <- function(review_id, approving_user_id, approved = TRUE) {
  logger::log_debug("put_db_review_approve: {ifelse(approved, 'Approving', 'Rejecting')} review {review_id}")

  tryCatch(
    {
      review_approve(review_id, approving_user_id, approved)
      logger::log_info("put_db_review_approve: Review {review_id} {ifelse(approved, 'approved', 'rejected')}")
      return(list(status = 200, message = paste0("OK. Review ", ifelse(approved, "approved", "rejected"), ".")))
    },
    error = function(e) {
      logger::log_error("put_db_review_approve: Error: {e$message}")
      return(list(status = 500, message = "Error approving review.", error = e$message))
    }
  )
}

#' Approve status (migrated from legacy-wrappers.R)
#'
#' @param status_id Integer status ID (or tibble/list containing it)
#' @param approving_user_id Integer user ID of approver
#' @param approved Logical TRUE to approve, FALSE to reject
#' @return List with status and message
put_db_status_approve <- function(status_id, approving_user_id, approved = TRUE) {
  if (is.list(status_id) || is.data.frame(status_id)) {
    status_id <- as.integer(status_id[[1]])
  }

  logger::log_debug("put_db_status_approve: {ifelse(approved, 'Approving', 'Rejecting')} status {status_id}")

  tryCatch(
    {
      status_approve(status_id, approving_user_id, approved)
      logger::log_info("put_db_status_approve: Status {status_id} {ifelse(approved, 'approved', 'rejected')}")
      return(list(status = 200, message = paste0("OK. Status ", ifelse(approved, "approved", "rejected"), ".")))
    },
    error = function(e) {
      logger::log_error("put_db_status_approve: Error: {e$message}")
      return(list(status = 500, message = "Error approving status.", error = e$message))
    }
  )
}
