# functions/review-repository.R
#
# Review domain repository - database operations for the ndd_entity_review table.
# All functions use parameterized queries via db-helpers.R for SQL injection prevention.
#
# Functions:
# - review_find_by_id: Find single review by ID
# - review_find_by_entity: Find all reviews for entity
# - review_create: Create new review
# - review_update: Update review (resets approval status)
# - review_approve: Approve/reject reviews (atomic multi-statement operation)
# - review_update_re_review_status: Update re_review_entity_connect status

library(tibble)
library(dplyr)
library(stringr)
library(rlang)

#' Find review by ID
#'
#' @param review_id Integer review ID
#' @return Tibble with 1 row if found, 0 rows if not found
#'
#' @examples
#' \dontrun{
#' review <- review_find_by_id(5)
#' }
#'
#' @export
review_find_by_id <- function(review_id) {
  sql <- "SELECT review_id, entity_id, synopsis, is_primary, review_approved, approving_user_id FROM ndd_entity_review WHERE review_id = ?"

  db_execute_query(sql, list(review_id))
}

#' Find all reviews for entity
#'
#' Returns reviews ordered by review_id DESC (newest first).
#'
#' @param entity_id Integer entity ID
#' @return Tibble with 0 or more rows
#'
#' @examples
#' \dontrun{
#' reviews <- review_find_by_entity(10)
#' }
#'
#' @export
review_find_by_entity <- function(entity_id) {
  sql <- "SELECT review_id, entity_id, synopsis, is_primary, review_approved, approving_user_id FROM ndd_entity_review WHERE entity_id = ? ORDER BY review_id DESC"

  db_execute_query(sql, list(entity_id))
}

#' Create new review
#'
#' Validates required fields and creates a new review record.
#' Escapes single quotes in synopsis to prevent SQL syntax errors.
#'
#' @param review_data List or data frame with review fields:
#'   - entity_id (required)
#'   - synopsis (required, can be NA)
#'
#' @return Integer review_id of the newly created review
#'
#' @examples
#' \dontrun{
#' review_id <- review_create(list(
#'   entity_id = 10,
#'   synopsis = "This gene is associated with..."
#' ))
#'
#' # Synopsis can be NA
#' review_id <- review_create(list(
#'   entity_id = 10,
#'   synopsis = NA
#' ))
#' }
#'
#' @export
review_create <- function(review_data) {
  # Convert to list if tibble/data.frame
  if (is.data.frame(review_data)) {
    review_data <- as.list(review_data[1, ])
  }

  # Validate entity_id
  if (is.null(review_data$entity_id) || is.na(review_data$entity_id)) {
    rlang::abort(
      message = "entity_id is required",
      class = c("review_validation_error", "validation_error"),
      missing_fields = "entity_id"
    )
  }

  # Escape single quotes in synopsis (even if NA, handle safely)
  synopsis <- review_data$synopsis
  if (!is.null(synopsis) && !is.na(synopsis) && is.character(synopsis)) {
    synopsis <- stringr::str_replace_all(synopsis, "'", "''")
  }

  # Insert review
  sql <- "INSERT INTO ndd_entity_review (entity_id, synopsis) VALUES (?, ?)"

  params <- list(review_data$entity_id, synopsis)

  db_execute_statement(sql, params)

  # Get last insert ID
  result <- db_execute_query("SELECT LAST_INSERT_ID() as review_id")

  return(as.integer(result$review_id[1]))
}

#' Update review
#'
#' Updates review fields and resets approval status.
#' Cannot change entity_id (business rule).
#' Uses transaction for atomic update.
#'
#' @param review_id Integer review ID to update
#' @param updates Named list of fields to update (e.g., list(synopsis = "new text"))
#'
#' @return Integer count of affected rows
#'
#' @examples
#' \dontrun{
#' review_update(5, list(synopsis = "Updated synopsis text"))
#' }
#'
#' @export
review_update <- function(review_id, updates) {
  # Remove entity_id if present (not allowed to change)
  if ("entity_id" %in% names(updates)) {
    updates$entity_id <- NULL
  }

  # Remove review_id if present (used in WHERE clause)
  if ("review_id" %in% names(updates)) {
    updates$review_id <- NULL
  }

  # Validate we have something to update
  if (length(updates) == 0) {
    rlang::abort(
      message = "No valid fields to update",
      class = c("review_validation_error", "validation_error")
    )
  }

  # Escape single quotes in synopsis if present
  if ("synopsis" %in% names(updates)) {
    synopsis <- updates$synopsis
    if (!is.null(synopsis) && !is.na(synopsis) && is.character(synopsis)) {
      updates$synopsis <- stringr::str_replace_all(synopsis, "'", "''")
    }
  }

  # Convert logical values to integer for MySQL
  updates <- lapply(updates, function(v) {
    if (is.logical(v)) as.integer(v) else v
  })

  # Use transaction for atomic operation
  db_with_transaction({
    # Build parameterized query: column names from code (safe), values via params
    col_names <- names(updates)
    set_clause <- paste0(col_names, " = ?", collapse = ", ")
    update_query <- paste0("UPDATE ndd_entity_review SET ", set_clause, " WHERE review_id = ?")

    # Prepare params list: all column values + review_id for WHERE
    params_list <- c(as.list(updates), list(review_id))

    # Perform the review update
    affected <- db_execute_statement(update_query, params_list)

    # Reset approval status
    db_execute_statement(
      "UPDATE ndd_entity_review SET review_approved = 0 WHERE review_id = ?",
      list(review_id)
    )

    # Reset approval user
    db_execute_statement(
      "UPDATE ndd_entity_review SET approving_user_id = NULL WHERE review_id = ?",
      list(review_id)
    )

    return(affected)
  })
}

#' Approve or reject reviews
#'
#' Handles single review_id or vector of review_ids.
#' When approving: resets is_primary for all reviews of the same entities, then
#' sets is_primary, review_approved, and approving_user_id for the specified reviews.
#' When rejecting: sets review_approved = 0 and approving_user_id.
#' Uses transaction for atomicity.
#'
#' @param review_ids Integer or integer vector of review IDs
#' @param approving_user_id Integer user ID of the approving user
#' @param approved Logical - TRUE to approve, FALSE to reject
#'
#' @return Integer vector of affected review_ids
#'
#' @examples
#' \dontrun{
#' # Approve single review
#' review_approve(5, approving_user_id = 10, approved = TRUE)
#'
#' # Approve multiple reviews
#' review_approve(c(5, 10, 15), approving_user_id = 10, approved = TRUE)
#'
#' # Reject review
#' review_approve(5, approving_user_id = 10, approved = FALSE)
#' }
#'
#' @export
review_approve <- function(review_ids, approving_user_id, approved = TRUE) {
  # Ensure review_ids is vector
  review_ids <- as.integer(review_ids)

  # Validate inputs
  if (length(review_ids) == 0) {
    rlang::abort(
      message = "review_ids cannot be empty",
      class = c("review_validation_error", "validation_error")
    )
  }

  if (is.null(approving_user_id) || is.na(approving_user_id)) {
    rlang::abort(
      message = "approving_user_id is required",
      class = c("review_validation_error", "validation_error")
    )
  }

  # Use transaction for atomic multi-statement operation
  db_with_transaction({
    # Get entity_ids for these reviews
    review_placeholders <- paste(rep("?", length(review_ids)), collapse = ", ")
    sql_get_entities <- paste0(
      "SELECT entity_id FROM ndd_entity_review WHERE review_id IN (",
      review_placeholders,
      ")"
    )

    entity_data <- db_execute_query(sql_get_entities, as.list(review_ids))
    entity_ids <- unique(entity_data$entity_id)

    if (approved) {
      # Build parameterized IN clause for entity_ids
      entity_placeholders <- paste(rep("?", length(entity_ids)), collapse = ", ")

      # Reset all reviews to not primary for these entities
      sql_reset_primary <- paste0(
        "UPDATE ndd_entity_review SET is_primary = 0 WHERE entity_id IN (",
        entity_placeholders,
        ")"
      )
      db_execute_statement(sql_reset_primary, as.list(entity_ids))

      # Set the specified reviews to primary
      sql_set_primary <- paste0(
        "UPDATE ndd_entity_review SET is_primary = 1 WHERE review_id IN (",
        review_placeholders,
        ")"
      )
      db_execute_statement(sql_set_primary, as.list(review_ids))

      # Add approving_user_id
      sql_set_user <- paste0(
        "UPDATE ndd_entity_review SET approving_user_id = ? WHERE review_id IN (",
        review_placeholders,
        ")"
      )
      db_execute_statement(sql_set_user, c(list(approving_user_id), as.list(review_ids)))

      # Set review_approved status to approved
      sql_set_approved <- paste0(
        "UPDATE ndd_entity_review SET review_approved = 1 WHERE review_id IN (",
        review_placeholders,
        ")"
      )
      db_execute_statement(sql_set_approved, as.list(review_ids))

    } else {
      # Rejection: add approving_user_id and set review_approved to 0
      sql_set_user <- paste0(
        "UPDATE ndd_entity_review SET approving_user_id = ? WHERE review_id IN (",
        review_placeholders,
        ")"
      )
      db_execute_statement(sql_set_user, c(list(approving_user_id), as.list(review_ids)))

      sql_set_rejected <- paste0(
        "UPDATE ndd_entity_review SET review_approved = 0 WHERE review_id IN (",
        review_placeholders,
        ")"
      )
      db_execute_statement(sql_set_rejected, as.list(review_ids))
    }

    return(review_ids)
  })
}

#' Update re-review entity connection status
#'
#' Called when creating a review in the re-review context.
#' Sets re_review_review_saved = 1 and links the review_id.
#'
#' @param entity_id Integer entity ID
#' @param review_id Integer review ID that was created
#'
#' @return Integer count of affected rows
#'
#' @examples
#' \dontrun{
#' review_update_re_review_status(entity_id = 10, review_id = 5)
#' }
#'
#' @export
review_update_re_review_status <- function(entity_id, review_id) {
  sql <- "UPDATE re_review_entity_connect SET re_review_review_saved = 1, review_id = ? WHERE entity_id = ?"

  params <- list(review_id, entity_id)

  db_execute_statement(sql, params)
}
