# functions/phenotype-repository.R
#
# Repository layer for phenotype (HPO term) domain operations.
# All phenotype database operations for review connections.
#
# Key features:
# - Validates phenotype IDs against allowed phenotype_list table
# - Uses db-helpers for parameterized queries
# - Transactional replace operations
# - Structured error handling

library(dplyr)
library(pool)
library(logger)
library(rlang)
library(tibble)

#' Get list of allowed phenotype IDs
#'
#' Retrieves all valid phenotype IDs from the phenotype_list table.
#' Useful for caching/reuse in validation logic.
#'
#' @return Tibble with phenotype_id column
#'
#' @examples
#' \dontrun{
#' allowed <- phenotype_get_allowed_list()
#' }
#'
#' @export
phenotype_get_allowed_list <- function() {
  log_debug("Fetching allowed phenotype IDs from phenotype_list")

  # Use pool with dplyr for efficient retrieval
  allowed <- pool %>%
    tbl("phenotype_list") %>%
    select(phenotype_id) %>%
    collect()

  log_debug("Retrieved {nrow(allowed)} allowed phenotype IDs")

  return(allowed)
}

#' Validate phenotype IDs against allowed list
#'
#' Checks that all provided phenotype IDs exist in the phenotype_list table.
#' Throws structured error if any IDs are invalid.
#'
#' @param phenotype_ids Character vector of phenotype IDs to validate
#'
#' @return TRUE if all IDs are valid
#'
#' @details
#' On validation failure, throws phenotype_validation_error with:
#' - invalid_ids attribute containing the disallowed IDs
#' - Descriptive error message
#'
#' @examples
#' \dontrun{
#' phenotype_validate_ids(c("HP:0001250", "HP:0001263"))
#' }
#'
#' @export
phenotype_validate_ids <- function(phenotype_ids) {
  log_debug("Validating {length(phenotype_ids)} phenotype IDs")

  # Get allowed list
  allowed_list <- phenotype_get_allowed_list()

  # Check which IDs are invalid
  invalid_ids <- phenotype_ids[!phenotype_ids %in% allowed_list$phenotype_id]

  if (length(invalid_ids) > 0) {
    log_warn("Phenotype validation failed: {length(invalid_ids)} invalid IDs",
             invalid_ids = paste(invalid_ids, collapse = ", "))

    rlang::abort(
      message = paste0(
        "Some of the submitted phenotypes are not in the allowed phenotype_id list: ",
        paste(invalid_ids, collapse = ", ")
      ),
      class = "phenotype_validation_error",
      invalid_ids = invalid_ids
    )
  }

  log_debug("All phenotype IDs are valid")
  return(TRUE)
}

#' Find phenotypes connected to a review
#'
#' Retrieves all phenotype connections for a given review_id.
#'
#' @param review_id Integer review ID
#'
#' @return Tibble with columns: review_id, phenotype_id, entity_id, modifier_id
#'
#' @examples
#' \dontrun{
#' phenotypes <- phenotype_find_by_review(123)
#' }
#'
#' @export
phenotype_find_by_review <- function(review_id) {
  log_debug("Finding phenotypes for review_id: {review_id}")

  sql <- "SELECT review_id, phenotype_id, entity_id, modifier_id
          FROM ndd_review_phenotype_connect
          WHERE review_id = ?"

  result <- db_execute_query(sql, list(review_id))

  log_debug("Found {nrow(result)} phenotype connections for review {review_id}")

  return(result)
}

#' Connect phenotypes to a review
#'
#' Inserts new phenotype connections for a review. Validates both phenotype IDs
#' and entity_id match before inserting.
#'
#' @param review_id Integer review ID
#' @param entity_id Integer entity ID (must match review's entity_id)
#' @param phenotypes Tibble with columns: phenotype_id, modifier_id
#'
#' @return Integer count of rows inserted
#'
#' @details
#' - Validates all phenotype_ids against allowed list
#' - Validates entity_id matches the review's entity_id from ndd_entity_review
#' - Inserts one row per phenotype
#'
#' @examples
#' \dontrun{
#' phenotypes <- tibble(
#'   phenotype_id = c("HP:0001250", "HP:0001263"),
#'   modifier_id = c(1, 2)
#' )
#' count <- phenotype_connect_to_review(123, 456, phenotypes)
#' }
#'
#' @export
phenotype_connect_to_review <- function(review_id, entity_id, phenotypes) {
  log_debug("Connecting {nrow(phenotypes)} phenotypes to review {review_id}")

  # Validate phenotype IDs first
  phenotype_validate_ids(phenotypes$phenotype_id)

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

  # Insert each phenotype connection
  total_inserted <- 0

  for (i in seq_len(nrow(phenotypes))) {
    rows_affected <- db_execute_statement(
      "INSERT INTO ndd_review_phenotype_connect
       (review_id, entity_id, phenotype_id, modifier_id)
       VALUES (?, ?, ?, ?)",
      list(
        review_id,
        entity_id,
        phenotypes$phenotype_id[i],
        phenotypes$modifier_id[i]
      )
    )
    total_inserted <- total_inserted + rows_affected
  }

  log_debug("Inserted {total_inserted} phenotype connections for review {review_id}")

  return(total_inserted)
}

#' Replace all phenotypes for a review
#'
#' Deletes all existing phenotype connections for a review and inserts new ones.
#' Uses a transaction to ensure atomicity (all-or-nothing).
#'
#' @param review_id Integer review ID
#' @param entity_id Integer entity ID (must match review's entity_id)
#' @param phenotypes Tibble with columns: phenotype_id, modifier_id
#'
#' @return Integer count of rows inserted (after deletion)
#'
#' @details
#' - Validates entity_id matches review first
#' - Wraps DELETE + INSERT in a transaction
#' - On error, transaction automatically rolls back
#' - Validates all phenotype_ids before any database changes
#'
#' @examples
#' \dontrun{
#' phenotypes <- tibble(
#'   phenotype_id = c("HP:0001250", "HP:0001263"),
#'   modifier_id = c(1, 2)
#' )
#' count <- phenotype_replace_for_review(123, 456, phenotypes)
#' }
#'
#' @export
phenotype_replace_for_review <- function(review_id, entity_id, phenotypes) {
  log_debug("Replacing phenotypes for review {review_id} with {nrow(phenotypes)} new entries")

  # Validate phenotype IDs first (before transaction)
  phenotype_validate_ids(phenotypes$phenotype_id)

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
    # Delete existing phenotype connections
    deleted <- db_execute_statement(
      "DELETE FROM ndd_review_phenotype_connect WHERE review_id = ?",
      list(review_id)
    )

    log_debug("Deleted {deleted} existing phenotype connections for review {review_id}")

    # Insert new phenotype connections
    total_inserted <- 0

    for (i in seq_len(nrow(phenotypes))) {
      rows_affected <- db_execute_statement(
        "INSERT INTO ndd_review_phenotype_connect
         (review_id, entity_id, phenotype_id, modifier_id)
         VALUES (?, ?, ?, ?)",
        list(
          review_id,
          entity_id,
          phenotypes$phenotype_id[i],
          phenotypes$modifier_id[i]
        )
      )
      total_inserted <- total_inserted + rows_affected
    }

    log_debug("Inserted {total_inserted} new phenotype connections")

    return(total_inserted)
  })

  log_debug("Replace completed: {result} phenotypes now connected to review {review_id}")

  return(result)
}
