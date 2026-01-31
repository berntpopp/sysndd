# functions/entity-repository.R
#
# Entity domain repository - database operations for the ndd_entity table.
# All functions use parameterized queries via db-helpers.R for SQL injection prevention.
#
# Functions:
# - entity_find_by_id: Find single entity by ID
# - entity_create: Create new entity
# - entity_deactivate: Deactivate entity (set is_active = 0)
# - entity_find_with_reviews: Find entities with review data (eager loading)
# - entity_exists: Check if entity exists

library(tibble)
library(dplyr)
library(glue)
library(rlang)

#' Find entity by ID
#'
#' @param entity_id Integer entity ID
#' @return Tibble with 1 row if found, 0 rows if not found
#'
#' @examples
#' \dontrun{
#' entity <- entity_find_by_id(5)
#' }
#'
#' @export
entity_find_by_id <- function(entity_id) {
  # nolint start: line_length_linter
  sql <- "SELECT entity_id, hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype, is_active, replaced_by, entry_date, entry_user_id FROM ndd_entity WHERE entity_id = ?"
  # nolint end

  db_execute_query(sql, list(entity_id))
}

#' Create new entity
#'
#' Validates required fields and creates a new entity record.
#' On validation failure, throws entity_validation_error with missing_fields attribute.
#'
#' @param entity_data List or data frame with entity fields:
#'   - hgnc_id (required)
#'   - hpo_mode_of_inheritance_term (required)
#'   - disease_ontology_id_version (required)
#'   - ndd_phenotype (required)
#'   - entry_user_id (required)
#'   - is_active (optional, defaults to 1; set to 0 for pending approval)
#'
#' @return Integer entity_id of the newly created entity
#'
#' @examples
#' \dontrun{
#' entity_id <- entity_create(list(
#'   hgnc_id = 1234,
#'   hpo_mode_of_inheritance_term = "HP:0000006",
#'   disease_ontology_id_version = "ORDO:123",
#'   ndd_phenotype = "Intellectual disability",
#'   entry_user_id = 10
#' ))
#' }
#'
#' @export
entity_create <- function(entity_data) {
  # Required fields
  required_fields <- c(
    "hgnc_id",
    "hpo_mode_of_inheritance_term",
    "disease_ontology_id_version",
    "ndd_phenotype",
    "entry_user_id"
  )

  # Convert to list if tibble/data.frame
  if (is.data.frame(entity_data)) {
    entity_data <- as.list(entity_data[1, ])
  }

  # Validate required fields
  missing_fields <- setdiff(required_fields, names(entity_data))

  if (length(missing_fields) > 0) {
    rlang::abort(
      message = paste("Missing required fields:", paste(missing_fields, collapse = ", ")),
      class = c("entity_validation_error", "validation_error"),
      missing_fields = missing_fields
    )
  }

  # Build SQL based on whether is_active is specified
  if (!is.null(entity_data$is_active)) {
    # nolint start: line_length_linter
    sql <- "INSERT INTO ndd_entity (hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype, entry_user_id, is_active) VALUES (?, ?, ?, ?, ?, ?)"
    # nolint end

    params <- list(
      entity_data$hgnc_id,
      entity_data$hpo_mode_of_inheritance_term,
      entity_data$disease_ontology_id_version,
      entity_data$ndd_phenotype,
      entity_data$entry_user_id,
      as.integer(entity_data$is_active)
    )
  } else {
    # Insert entity (is_active defaults to 1 in database)
    # nolint start: line_length_linter
    sql <- "INSERT INTO ndd_entity (hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype, entry_user_id) VALUES (?, ?, ?, ?, ?)"
    # nolint end

    params <- list(
      entity_data$hgnc_id,
      entity_data$hpo_mode_of_inheritance_term,
      entity_data$disease_ontology_id_version,
      entity_data$ndd_phenotype,
      entity_data$entry_user_id
    )
  }

  db_execute_statement(sql, params)

  # Get last insert ID
  result <- db_execute_query("SELECT LAST_INSERT_ID() as entity_id")

  return(as.integer(result$entity_id[1]))
}

#' Deactivate entity
#'
#' Sets is_active = 0 and optionally sets replaced_by field.
#'
#' @param entity_id Integer entity ID to deactivate
#' @param replacement_id Integer ID of replacement entity, or NULL
#'
#' @return Integer count of affected rows (should be 1)
#'
#' @examples
#' \dontrun{
#' # Deactivate without replacement
#' entity_deactivate(5)
#'
#' # Deactivate with replacement
#' entity_deactivate(5, replacement_id = 10)
#' }
#'
#' @export
entity_deactivate <- function(entity_id, replacement_id = NULL) {
  sql <- "UPDATE ndd_entity SET is_active = 0, replaced_by = ? WHERE entity_id = ?"

  params <- list(replacement_id, entity_id)

  db_execute_statement(sql, params)
}

#' Find entities with review data (eager loading)
#'
#' Performs a LEFT JOIN with ndd_entity_review to load entity and review data
#' in a single query. Uses dynamic SQL for IN clause (safe - only for placeholders).
#'
#' @param entity_ids Integer vector of entity IDs
#'
#' @return Tibble with joined entity and review data
#'
#' @examples
#' \dontrun{
#' # Single entity
#' data <- entity_find_with_reviews(5)
#'
#' # Multiple entities
#' data <- entity_find_with_reviews(c(5, 10, 15))
#' }
#'
#' @export
entity_find_with_reviews <- function(entity_ids) {
  # Generate placeholders for IN clause
  placeholders <- paste(rep("?", length(entity_ids)), collapse = ", ")

  # Use glue for dynamic SQL (safe - only for placeholders, not user values)
  sql <- glue::glue("
    SELECT
      e.entity_id,
      e.hgnc_id,
      e.hpo_mode_of_inheritance_term,
      e.disease_ontology_id_version,
      e.ndd_phenotype,
      e.is_active,
      e.replaced_by,
      e.entry_date,
      e.entry_user_id,
      r.review_id,
      r.synopsis,
      r.is_primary,
      r.review_approved,
      r.approving_user_id
    FROM ndd_entity e
    LEFT JOIN ndd_entity_review r ON e.entity_id = r.entity_id
    WHERE e.entity_id IN ({placeholders})
    ORDER BY e.entity_id, r.review_id DESC
  ")

  # Pass entity_ids as list for parameterized query
  db_execute_query(sql, as.list(entity_ids))
}

#' Check if entity exists
#'
#' @param entity_id Integer entity ID
#'
#' @return Logical TRUE if exists, FALSE otherwise
#'
#' @examples
#' \dontrun{
#' if (entity_exists(5)) {
#'   # Entity exists
#' }
#' }
#'
#' @export
entity_exists <- function(entity_id) {
  sql <- "SELECT 1 FROM ndd_entity WHERE entity_id = ? LIMIT 1"

  result <- db_execute_query(sql, list(entity_id))

  return(nrow(result) > 0)
}
