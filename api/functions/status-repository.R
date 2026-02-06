# functions/status-repository.R
#
# Repository for status domain database operations.
# Status tracks entity categorization and approval state.
#
# Key responsibilities:
# - Find status records by ID or entity
# - Create and update status records with validation
# - Approve/reject status records with atomic entity updates
# - Link status to re-review workflow
#
# Dependencies: db-helpers.R (db_execute_query, db_execute_statement, db_with_transaction)

library(DBI)
library(dplyr)
library(tibble)
library(rlang)
library(logger)

#' Find a single status record by ID
#'
#' @param status_id Integer status ID
#'
#' @return Tibble with status record (0 rows if not found)
#'
#' @examples
#' \dontrun{
#' status <- status_find_by_id(42)
#' }
#'
#' @export
status_find_by_id <- function(status_id) {
  db_execute_query(
    "SELECT status_id, entity_id, category_id, problematic, status_approved, approving_user_id, is_active
     FROM ndd_entity_status
     WHERE status_id = ?",
    list(status_id)
  )
}

#' Find all status records for an entity
#'
#' @param entity_id Integer entity ID
#'
#' @return Tibble with status records ordered by status_id DESC (0 rows if none)
#'
#' @examples
#' \dontrun{
#' statuses <- status_find_by_entity(5)
#' }
#'
#' @export
status_find_by_entity <- function(entity_id) {
  db_execute_query(
    "SELECT status_id, entity_id, category_id, problematic, status_approved, approving_user_id, is_active
     FROM ndd_entity_status
     WHERE entity_id = ?
     ORDER BY status_id DESC",
    list(entity_id)
  )
}

#' Create a new status record
#'
#' @param status_data Tibble or list with entity_id, category_id, and optional problematic
#'
#' @return Integer status_id of newly created record
#'
#' @details
#' - Validates that category_id and entity_id are provided
#' - Removes status_id if accidentally provided (for POST requests)
#' - Returns the LAST_INSERT_ID() from the database
#'
#' @examples
#' \dontrun{
#' status_id <- status_create(tibble(
#'   entity_id = 5,
#'   category_id = 2,
#'   problematic = 0
#' ))
#' }
#'
#' @export
status_create <- function(status_data, conn = NULL) {
  # Convert to tibble if list
  if (is.list(status_data) && !inherits(status_data, "data.frame")) {
    status_data <- tibble::as_tibble(status_data)
  }

  # Validate required fields
  if (!"entity_id" %in% colnames(status_data)) {
    rlang::abort(
      "entity_id is required",
      class = "status_validation_error"
    )
  }

  if (!"category_id" %in% colnames(status_data)) {
    rlang::abort(
      "category_id is required",
      class = "status_validation_error"
    )
  }

  if (!"status_user_id" %in% colnames(status_data)) {
    rlang::abort(
      "status_user_id is required",
      class = "status_validation_error"
    )
  }

  # Remove status_id if accidentally provided (for POST requests)
  if ("status_id" %in% colnames(status_data)) {
    status_data <- status_data %>% dplyr::select(-status_id)
  }

  # Extract values for insert
  entity_id <- status_data$entity_id[1]
  category_id <- status_data$category_id[1]
  status_user_id <- status_data$status_user_id[1]
  problematic <- if ("problematic" %in% colnames(status_data)) {
    status_data$problematic[1]
  } else {
    0
  }

  # Insert record
  db_execute_statement(
    "INSERT INTO ndd_entity_status (entity_id, category_id, status_user_id, problematic)
     VALUES (?, ?, ?, ?)",
    list(entity_id, category_id, status_user_id, problematic),
    conn = conn
  )

  # Get the last insert ID
  id_result <- db_execute_query("SELECT LAST_INSERT_ID() as status_id", conn = conn)
  status_id <- id_result$status_id[1]

  log_debug("Created status {status_id} for entity {entity_id}")

  return(status_id)
}

#' Update an existing status record
#'
#' @param status_id Integer status ID to update
#' @param updates Tibble or list with fields to update
#'
#' @return Integer count of affected rows (should be 1 if successful, 0 if not found)
#'
#' @details
#' - Removes entity_id and status_id from updates (prevent changing associations)
#' - Builds dynamic SET clause from provided fields
#' - Converts logical values to integers for database compatibility
#'
#' @examples
#' \dontrun{
#' rows <- status_update(42, tibble(category_id = 3, problematic = 1))
#' }
#'
#' @export
status_update <- function(status_id, updates) {
  # Convert to tibble if list
  if (is.list(updates) && !inherits(updates, "data.frame")) {
    # Remove NULL values before converting to tibble
    updates <- purrr::compact(updates)
    updates <- tibble::as_tibble(updates)
  }

  # Valid columns in ndd_entity_status table (excluding status_id, entity_id)
  valid_columns <- c("category_id", "problematic", "status_approved", "approving_user_id", "is_active")

  # Keep only valid columns and remove entity_id/status_id (prevent changing associations)
  updates <- updates %>%
    dplyr::select(any_of(valid_columns))

  # Check if any fields remain
  if (ncol(updates) == 0) {
    rlang::abort(
      "No valid fields to update",
      class = "status_validation_error"
    )
  }

  # Convert logical to integer for database compatibility
  updates <- updates %>%
    mutate(across(where(is.logical), as.integer))

  # Build parameterized query: column names from code (safe), values via params
  col_names <- colnames(updates)
  set_clause <- paste0(col_names, " = ?", collapse = ", ")
  update_query <- paste0("UPDATE ndd_entity_status SET ", set_clause, " WHERE status_id = ?")

  # Prepare params list: all column values + status_id for WHERE
  # IMPORTANT: Must unname the list for anonymous (?) placeholders
  params_list <- unname(as.list(updates[1, ]))
  params_list <- c(params_list, list(status_id))

  # Execute update
  affected <- db_execute_statement(update_query, params_list)

  log_debug("Updated status {status_id}, affected {affected} rows")

  return(affected)
}

#' Approve or reject status records
#'
#' @param status_ids Integer or vector of status IDs to approve/reject
#' @param approving_user_id Integer user ID performing the approval
#' @param approved Logical, TRUE to approve, FALSE to reject (default: TRUE)
#'
#' @return Vector of status_ids that were processed
#'
#' @details
#' When approved = TRUE:
#' - Gets entity_ids for the statuses being approved
#' - Resets is_active = 0 for all statuses of same entities (within transaction)
#' - Sets is_active = 1, status_approved = 1, approving_user_id for these statuses
#'
#' When approved = FALSE:
#' - Sets status_approved = 0, approving_user_id
#'
#' Uses db_with_transaction to ensure atomicity.
#'
#' @examples
#' \dontrun{
#' # Approve single status
#' status_approve(42, approving_user_id = 7)
#'
#' # Approve multiple statuses
#' status_approve(c(42, 43, 44), approving_user_id = 7)
#'
#' # Reject status
#' status_approve(42, approving_user_id = 7, approved = FALSE)
#' }
#'
#' @export
status_approve <- function(status_ids, approving_user_id, approved = TRUE) {
  # Ensure status_ids is a vector
  status_ids <- as.integer(status_ids)

  if (length(status_ids) == 0) {
    rlang::abort(
      "status_ids cannot be empty",
      class = "status_validation_error"
    )
  }

  # Get entity_ids for the statuses being approved
  status_placeholders <- paste(rep("?", length(status_ids)), collapse = ", ")
  ndd_entity_status_data <- db_execute_query(
    paste0("SELECT status_id, entity_id FROM ndd_entity_status WHERE status_id IN (", status_placeholders, ")"),
    as.list(status_ids)
  )

  if (nrow(ndd_entity_status_data) == 0) {
    rlang::abort(
      "No status records found for provided IDs",
      class = "status_not_found_error"
    )
  }

  # Execute approval/rejection within transaction
  db_with_transaction({
    if (approved) {
      # Get unique entity IDs
      entity_ids <- unique(ndd_entity_status_data$entity_id)
      entity_placeholders <- paste(rep("?", length(entity_ids)), collapse = ", ")

      # Reset all statuses for these entities to inactive
      db_execute_statement(
        paste0("UPDATE ndd_entity_status SET is_active = 0 WHERE entity_id IN (", entity_placeholders, ")"),
        as.list(entity_ids)
      )

      # Set the selected statuses to active
      db_execute_statement(
        paste0("UPDATE ndd_entity_status SET is_active = 1 WHERE status_id IN (", status_placeholders, ")"),
        as.list(status_ids)
      )

      # Add approving_user_id
      db_execute_statement(
        paste0("UPDATE ndd_entity_status SET approving_user_id = ? WHERE status_id IN (", status_placeholders, ")"),
        c(list(approving_user_id), as.list(status_ids))
      )

      # Set status_approved to approved
      db_execute_statement(
        paste0("UPDATE ndd_entity_status SET status_approved = 1 WHERE status_id IN (", status_placeholders, ")"),
        as.list(status_ids)
      )

      log_debug("Approved {length(status_ids)} statuses for {length(entity_ids)} entities")
    } else {
      # Rejection: set approving_user_id and status_approved = 0
      db_execute_statement(
        paste0("UPDATE ndd_entity_status SET approving_user_id = ? WHERE status_id IN (", status_placeholders, ")"),
        c(list(approving_user_id), as.list(status_ids))
      )

      db_execute_statement(
        paste0("UPDATE ndd_entity_status SET status_approved = 0 WHERE status_id IN (", status_placeholders, ")"),
        as.list(status_ids)
      )

      log_debug("Rejected {length(status_ids)} statuses")
    }
  })

  return(status_ids)
}

#' Update re-review status when status is created
#'
#' @param entity_id Integer entity ID
#' @param status_id Integer status ID
#'
#' @return Integer count of affected rows
#'
#' @details
#' Used when creating status in re-review context.
#' Marks the re-review as having saved status.
#'
#' @examples
#' \dontrun{
#' rows <- status_update_re_review_status(5, 42)
#' }
#'
#' @export
status_update_re_review_status <- function(entity_id, status_id) {
  affected <- db_execute_statement(
    "UPDATE re_review_entity_connect SET re_review_status_saved = 1, status_id = ?
     WHERE entity_id = ?",
    list(status_id, entity_id)
  )

  log_debug("Updated re_review_entity_connect for entity {entity_id}, affected {affected} rows")

  return(affected)
}
