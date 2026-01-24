# functions/ontology-repository.R
#
# Repository layer for variation ontology (VARIO term) domain operations.
# All variation ontology database operations for review connections.
#
# Key features:
# - Validates variation ontology IDs against allowed variation_ontology_list table
# - Uses db-helpers for parameterized queries
# - Transactional replace operations
# - Structured error handling

library(dplyr)
library(pool)
library(logger)
library(rlang)
library(tibble)

#' Get list of allowed variation ontology IDs
#'
#' Retrieves all valid variation ontology IDs from the variation_ontology_list table.
#' Useful for caching/reuse in validation logic.
#'
#' @return Tibble with vario_id column
#'
#' @examples
#' \dontrun{
#' allowed <- variation_ontology_get_allowed_list()
#' }
#'
#' @export
variation_ontology_get_allowed_list <- function() {
  log_debug("Fetching allowed variation ontology IDs from variation_ontology_list")

  # Use pool with dplyr for efficient retrieval
  allowed <- pool %>%
    tbl("variation_ontology_list") %>%
    select(vario_id) %>%
    collect()

  log_debug("Retrieved {nrow(allowed)} allowed variation ontology IDs")

  return(allowed)
}

#' Validate variation ontology IDs against allowed list
#'
#' Checks that all provided variation ontology IDs exist in the variation_ontology_list table.
#' Throws structured error if any IDs are invalid.
#'
#' @param vario_ids Character vector of variation ontology IDs to validate
#'
#' @return TRUE if all IDs are valid
#'
#' @details
#' On validation failure, throws variation_ontology_validation_error with:
#' - invalid_ids attribute containing the disallowed IDs
#' - Descriptive error message
#'
#' @examples
#' \dontrun{
#' variation_ontology_validate_ids(c("VariO:0001", "VariO:0002"))
#' }
#'
#' @export
variation_ontology_validate_ids <- function(vario_ids) {
  log_debug("Validating {length(vario_ids)} variation ontology IDs")

  # Get allowed list
  allowed_list <- variation_ontology_get_allowed_list()

  # Check which IDs are invalid
  invalid_ids <- vario_ids[!vario_ids %in% allowed_list$vario_id]

  if (length(invalid_ids) > 0) {
    log_warn("Variation ontology validation failed: {length(invalid_ids)} invalid IDs",
             invalid_ids = paste(invalid_ids, collapse = ", "))

    rlang::abort(
      message = paste0(
        "Some of the submitted variation ontology terms are not in the allowed vario_id list: ",
        paste(invalid_ids, collapse = ", ")
      ),
      class = "variation_ontology_validation_error",
      invalid_ids = invalid_ids
    )
  }

  log_debug("All variation ontology IDs are valid")
  return(TRUE)
}

#' Find variation ontology terms connected to a review
#'
#' Retrieves all variation ontology connections for a given review_id.
#'
#' @param review_id Integer review ID
#'
#' @return Tibble with columns: review_id, vario_id, modifier_id, entity_id
#'
#' @examples
#' \dontrun{
#' terms <- variation_ontology_find_by_review(123)
#' }
#'
#' @export
variation_ontology_find_by_review <- function(review_id) {
  log_debug("Finding variation ontology terms for review_id: {review_id}")

  sql <- "SELECT review_id, vario_id, modifier_id, entity_id
          FROM ndd_review_variation_ontology_connect
          WHERE review_id = ?"

  result <- db_execute_query(sql, list(review_id))

  log_debug("Found {nrow(result)} variation ontology connections for review {review_id}")

  return(result)
}

#' Connect variation ontology terms to a review
#'
#' Inserts new variation ontology connections for a review. Validates both vario IDs
#' and entity_id match before inserting.
#'
#' @param review_id Integer review ID
#' @param entity_id Integer entity ID (must match review's entity_id)
#' @param variation_ontology Tibble with columns: vario_id, modifier_id
#'
#' @return Integer count of rows inserted
#'
#' @details
#' - Validates all vario_ids against allowed list
#' - Validates entity_id matches the review's entity_id from ndd_entity_review
#' - Inserts one row per variation ontology term
#'
#' @examples
#' \dontrun{
#' terms <- tibble(
#'   vario_id = c("VariO:0001", "VariO:0002"),
#'   modifier_id = c(1, 2)
#' )
#' count <- variation_ontology_connect_to_review(123, 456, terms)
#' }
#'
#' @export
variation_ontology_connect_to_review <- function(review_id, entity_id, variation_ontology) {
  log_debug("Connecting {nrow(variation_ontology)} variation ontology terms to review {review_id}")

  # Validate vario IDs first
  variation_ontology_validate_ids(variation_ontology$vario_id)

  # Validate entity_id matches the review's entity_id
  review_entity <- db_execute_query(
    "SELECT entity_id FROM ndd_entity_review WHERE review_id = ?",
    list(review_id)
  )

  if (nrow(review_entity) == 0) {
    rlang::abort(
      message = paste("Review not found:", review_id),
      class = "review_not_found_error",
      review_id = review_id
    )
  }

  if (review_entity$entity_id[1] != entity_id) {
    rlang::abort(
      message = paste0(
        "Entity ID mismatch: provided ", entity_id,
        " but review ", review_id, " has entity_id ", review_entity$entity_id[1]
      ),
      class = "entity_id_mismatch_error",
      provided_entity_id = entity_id,
      review_entity_id = review_entity$entity_id[1]
    )
  }

  # Insert each variation ontology connection
  total_inserted <- 0

  for (i in seq_len(nrow(variation_ontology))) {
    rows_affected <- db_execute_statement(
      "INSERT INTO ndd_review_variation_ontology_connect
       (review_id, vario_id, modifier_id, entity_id)
       VALUES (?, ?, ?, ?)",
      list(
        review_id,
        variation_ontology$vario_id[i],
        variation_ontology$modifier_id[i],
        entity_id
      )
    )
    total_inserted <- total_inserted + rows_affected
  }

  log_debug("Inserted {total_inserted} variation ontology connections for review {review_id}")

  return(total_inserted)
}

#' Replace all variation ontology terms for a review
#'
#' Deletes all existing variation ontology connections for a review and inserts new ones.
#' Uses a transaction to ensure atomicity (all-or-nothing).
#'
#' @param review_id Integer review ID
#' @param entity_id Integer entity ID (must match review's entity_id)
#' @param variation_ontology Tibble with columns: vario_id, modifier_id
#'
#' @return Integer count of rows inserted (after deletion)
#'
#' @details
#' - Validates entity_id matches review first
#' - Wraps DELETE + INSERT in a transaction
#' - On error, transaction automatically rolls back
#' - Validates all vario_ids before any database changes
#'
#' @examples
#' \dontrun{
#' terms <- tibble(
#'   vario_id = c("VariO:0001", "VariO:0002"),
#'   modifier_id = c(1, 2)
#' )
#' count <- variation_ontology_replace_for_review(123, 456, terms)
#' }
#'
#' @export
variation_ontology_replace_for_review <- function(review_id, entity_id, variation_ontology) {
  log_debug("Replacing variation ontology terms for review {review_id} with {nrow(variation_ontology)} new entries")

  # Validate vario IDs first (before transaction)
  variation_ontology_validate_ids(variation_ontology$vario_id)

  # Validate entity_id matches the review's entity_id
  review_entity <- db_execute_query(
    "SELECT entity_id FROM ndd_entity_review WHERE review_id = ?",
    list(review_id)
  )

  if (nrow(review_entity) == 0) {
    rlang::abort(
      message = paste("Review not found:", review_id),
      class = "review_not_found_error",
      review_id = review_id
    )
  }

  if (review_entity$entity_id[1] != entity_id) {
    rlang::abort(
      message = paste0(
        "Entity ID mismatch: provided ", entity_id,
        " but review ", review_id, " has entity_id ", review_entity$entity_id[1]
      ),
      class = "entity_id_mismatch_error",
      provided_entity_id = entity_id,
      review_entity_id = review_entity$entity_id[1]
    )
  }

  # Use transaction for atomic replace
  result <- db_with_transaction({
    # Delete existing variation ontology connections
    deleted <- db_execute_statement(
      "DELETE FROM ndd_review_variation_ontology_connect WHERE review_id = ?",
      list(review_id)
    )

    log_debug("Deleted {deleted} existing variation ontology connections for review {review_id}")

    # Insert new variation ontology connections
    total_inserted <- 0

    for (i in seq_len(nrow(variation_ontology))) {
      rows_affected <- db_execute_statement(
        "INSERT INTO ndd_review_variation_ontology_connect
         (review_id, vario_id, modifier_id, entity_id)
         VALUES (?, ?, ?, ?)",
        list(
          review_id,
          variation_ontology$vario_id[i],
          variation_ontology$modifier_id[i],
          entity_id
        )
      )
      total_inserted <- total_inserted + rows_affected
    }

    log_debug("Inserted {total_inserted} new variation ontology connections")

    return(total_inserted)
  })

  log_debug("Replace completed: {result} variation ontology terms now connected to review {review_id}")

  return(result)
}
