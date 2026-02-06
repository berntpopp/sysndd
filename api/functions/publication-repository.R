# functions/publication-repository.R
#
# Repository for publication domain database operations.
# Publications connect reviews to literature references.
#
# Key responsibilities:
# - Find publication records by ID(s)
# - Validate publication IDs against allowed list
# - Connect publications to reviews with type classification
# - Replace all publications for a review (atomic operation)
# - Find publications with review/entity context
#
# Dependencies: db-helpers.R (db_execute_query, db_execute_statement, db_with_transaction)

library(DBI)
library(dplyr)
library(tibble)
library(rlang)
library(logger)

#' Find a single publication by ID
#'
#' @param publication_id Integer publication ID
#'
#' @return Tibble with publication record (0 rows if not found)
#'
#' @examples
#' \dontrun{
#' pub <- publication_find_by_id(123)
#' }
#'
#' @export
publication_find_by_id <- function(publication_id) {
  db_execute_query(
    "SELECT publication_id, pmid, title, publication_year
     FROM publication
     WHERE publication_id = ?",
    list(publication_id)
  )
}

#' Find multiple publications by IDs
#'
#' @param publication_ids Vector of publication IDs
#'
#' @return Tibble with publication records (0 rows if none found)
#'
#' @details
#' - Handles empty input by returning empty tibble with correct columns
#' - Uses parameterized IN clause for multiple IDs
#'
#' @examples
#' \dontrun{
#' pubs <- publication_find_by_ids(c(123, 124, 125))
#' }
#'
#' @export
publication_find_by_ids <- function(publication_ids) {
  # Handle empty input
  if (length(publication_ids) == 0) {
    return(tibble::tibble(
      publication_id = integer(),
      pmid = character(),
      title = character(),
      publication_year = integer()
    ))
  }

  # Generate placeholders for IN clause
  placeholders <- paste(rep("?", length(publication_ids)), collapse = ", ")

  db_execute_query(
    paste0("SELECT publication_id, pmid, title, publication_year
            FROM publication
            WHERE publication_id IN (", placeholders, ")"),
    as.list(publication_ids)
  )
}

#' Validate that publication IDs exist in the database
#'
#' @param publication_ids Vector of publication IDs to validate
#'
#' @return TRUE if all IDs are valid
#'
#' @details
#' - Uses pool with dplyr to get allowed publication IDs
#' - On invalid IDs: throws publication_validation_error with invalid_ids attribute
#'
#' @examples
#' \dontrun{
#' publication_validate_ids(c(123, 124, 125))
#' }
#'
#' @export
publication_validate_ids <- function(publication_ids) {
  # Get all allowed publication IDs from database
  publication_list_collected <- pool %>%
    tbl("publication") %>%
    dplyr::select(publication_id) %>%
    arrange(publication_id) %>%
    collect()

  # Check if all provided IDs are in the allowed list
  invalid_ids <- setdiff(publication_ids, publication_list_collected$publication_id)

  if (length(invalid_ids) > 0) {
    rlang::abort(
      message = paste0(
        "Some submitted publications are not in the allowed publications list. ",
        "Add them there first. Invalid IDs: ",
        paste(invalid_ids, collapse = ", ")
      ),
      class = "publication_validation_error",
      invalid_ids = invalid_ids
    )
  }

  log_debug("Validated {length(publication_ids)} publication IDs")

  return(TRUE)
}

#' Connect publications to a review
#'
#' @param review_id Integer review ID
#' @param entity_id Integer entity ID
#' @param publications Tibble with publication_id and publication_type columns
#'
#' @return Integer count of affected rows
#'
#' @details
#' - Validates publication IDs first
#' - Validates entity_id matches the review's entity_id (prevent changing associations)
#' - Inserts records into ndd_review_publication_join
#'
#' @examples
#' \dontrun{
#' publications <- tibble(
#'   publication_id = c(123, 124),
#'   publication_type = c("primary", "supporting")
#' )
#' rows <- publication_connect_to_review(5, 10, publications)
#' }
#'
#' @export
publication_connect_to_review <- function(review_id, entity_id, publications, conn = NULL) {
  # Skip validation when conn is provided (caller validates before transaction)
  if (is.null(conn)) {
    # Validate publication IDs
    publication_validate_ids(publications$publication_id)

    # Validate entity_id matches the review's entity_id
    review_entity <- pool %>%
      tbl("ndd_entity_review") %>%
      dplyr::select(review_id, entity_id) %>%
      filter(review_id == !!review_id) %>%
      collect() %>%
      unique()

    if (nrow(review_entity) > 0) {
      review_entity_id <- review_entity$entity_id[1]

      if (!is.na(review_entity_id) && review_entity_id != entity_id) {
        rlang::abort(
          "entity_id does not match the review's entity_id",
          class = "publication_validation_error"
        )
      }
    }
  }

  # Prepare publications for submission
  publications_submission <- publications %>%
    mutate(
      review_id = review_id,
      entity_id = entity_id
    ) %>%
    dplyr::select(review_id, entity_id, publication_id, publication_type)

  # Insert each publication
  total_affected <- 0
  for (i in seq_len(nrow(publications_submission))) {
    row <- publications_submission[i, ]
    affected <- db_execute_statement(
      "INSERT INTO ndd_review_publication_join (review_id, entity_id, publication_id, publication_type)
       VALUES (?, ?, ?, ?)",
      list(row$review_id, row$entity_id, row$publication_id, row$publication_type),
      conn = conn
    )
    total_affected <- total_affected + affected
  }

  log_debug("Connected {nrow(publications_submission)} publications to review {review_id}")

  return(total_affected)
}

#' Replace all publications for a review
#'
#' @param review_id Integer review ID
#' @param entity_id Integer entity ID
#' @param publications Tibble with publication_id and publication_type columns
#'
#' @return Integer count of affected rows
#'
#' @details
#' - Uses db_with_transaction for atomic operation
#' - First deletes all existing publications for the review
#' - Then inserts new publications
#' - Validates publication IDs and entity_id before operation
#' - Logs warning if publication count decreases (potential data loss)
#'
#' @examples
#' \dontrun{
#' publications <- tibble(
#'   publication_id = c(123, 124),
#'   publication_type = c("primary", "supporting")
#' )
#' rows <- publication_replace_for_review(5, 10, publications)
#' }
#'
#' @export
publication_replace_for_review <- function(review_id, entity_id, publications) {
  # Check existing publication count for validation
  existing_count <- pool %>%
    tbl("ndd_review_publication_join") %>%
    filter(review_id == !!review_id) %>%
    dplyr::select(publication_id) %>%
    collect() %>%
    nrow()

  new_count <- nrow(publications)

  # Log warning if publications are being removed (potential data loss)
  if (existing_count > 0 && new_count < existing_count) {
    log_warn(
      "Publication count decreasing for review {review_id}: {existing_count} -> {new_count}. ",
      "Ensure all existing publications are included in the update to prevent data loss."
    )
  }

  # Validate publication IDs
  publication_validate_ids(publications$publication_id)

  # Validate entity_id matches the review's entity_id
  review_entity <- pool %>%
    tbl("ndd_entity_review") %>%
    dplyr::select(review_id, entity_id) %>%
    filter(review_id == !!review_id) %>%
    collect() %>%
    unique()

  if (nrow(review_entity) > 0) {
    review_entity_id <- review_entity$entity_id[1]

    if (!is.na(review_entity_id) && review_entity_id != entity_id) {
      rlang::abort(
        "entity_id does not match the review's entity_id",
        class = "publication_validation_error"
      )
    }
  }

  # Prepare publications for submission
  publications_submission <- publications %>%
    mutate(
      review_id = review_id,
      entity_id = entity_id
    ) %>%
    dplyr::select(review_id, entity_id, publication_id, publication_type)

  # Execute replacement within transaction
  db_with_transaction({
    # Delete old publication connections
    db_execute_statement(
      "DELETE FROM ndd_review_publication_join WHERE review_id = ?",
      list(review_id)
    )

    # Insert new publications
    for (i in seq_len(nrow(publications_submission))) {
      row <- publications_submission[i, ]
      db_execute_statement(
        "INSERT INTO ndd_review_publication_join (review_id, entity_id, publication_id, publication_type)
         VALUES (?, ?, ?, ?)",
        list(row$review_id, row$entity_id, row$publication_id, row$publication_type)
      )
    }

    log_debug("Replaced publications for review {review_id}, inserted {nrow(publications_submission)} publications")
  })

  return(nrow(publications_submission))
}

#' Find publications with review and entity context
#'
#' @param publication_ids Vector of publication IDs
#'
#' @return Tibble with publication data joined with review and entity context
#'
#' @details
#' Joins publication table with ndd_review_publication_join and ndd_entity_review
#' to provide full context for where publications are used.
#'
#' @examples
#' \dontrun{
#' pubs_with_context <- publication_find_with_context(c(123, 124))
#' }
#'
#' @export
publication_find_with_context <- function(publication_ids) {
  # Handle empty input
  if (length(publication_ids) == 0) {
    return(tibble::tibble())
  }

  # Generate placeholders for IN clause
  placeholders <- paste(rep("?", length(publication_ids)), collapse = ", ")

  db_execute_query(
    paste0("SELECT p.publication_id, p.pmid, p.title, p.publication_year,
                   rpj.review_id, rpj.entity_id, rpj.publication_type,
                   er.synopsis
            FROM publication p
            LEFT JOIN ndd_review_publication_join rpj ON p.publication_id = rpj.publication_id
            LEFT JOIN ndd_entity_review er ON rpj.review_id = er.review_id
            WHERE p.publication_id IN (", placeholders, ")"),
    as.list(publication_ids)
  )
}
