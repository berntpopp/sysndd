# Review Service Layer for SysNDD API
# Provides business logic for review creation, updates, and connections
#
# Functions accept pool as parameter (dependency injection)
# Uses repository functions for database operations
# Handles review connections to publications, phenotypes, and variation ontology

library(tibble)
library(dplyr)
library(stringr)

#' Create a new review (service layer)
#'
#' Business logic wrapper for review creation. Handles synopsis validation,
#' quote escaping, and optional re_review workflow.
#'
#' @param review_data List or tibble with entity_id and synopsis
#' @param user_id User ID creating the review (for re_review tracking)
#' @param pool Database connection pool
#' @param re_review Logical - if TRUE, updates re_review_entity_connect (default: FALSE)
#' @return List with status, message, and entry (review_id)
#' @examples
#' \dontrun{
#' result <- svc_review_create(
#'   review_data = list(entity_id = 10, synopsis = "Gene associated with..."),
#'   user_id = 5,
#'   pool = pool
#' )
#' # Returns: list(status = 200, message = "OK. Entry created.", entry = tibble(review_id = 42))
#' }
svc_review_create <- function(review_data, user_id, pool, re_review = FALSE) {
  # Convert to list if tibble
  if (is.data.frame(review_data)) {
    review_data <- as.list(review_data[1, ])
  }

  # Validate synopsis is not empty
  synopsis <- review_data$synopsis
  if (is.null(synopsis) || is.na(synopsis) || nchar(trimws(synopsis)) == 0) {
    return(list(
      status = 405,
      message = "Submitted synopsis data can not be empty."
    ))
  }

  # Escape single quotes in synopsis (SQL-safe)
  synopsis <- stringr::str_replace_all(synopsis, "'", "''")

  # Create review using repository
  new_review_id <- review_create(list(
    entity_id = review_data$entity_id,
    synopsis = synopsis
  ))

  # If re_review, update re_review_entity_connect
  if (re_review) {
    review_update_re_review_status(review_data$entity_id, new_review_id)
  }

  # Return success with review_id
  submitted_review_id <- tibble::tibble(review_id = new_review_id)
  return(list(
    status = 200,
    message = "OK. Entry created.",
    entry = submitted_review_id
  ))
}


#' Update an existing review (service layer)
#'
#' Business logic wrapper for review updates. Handles validation, quote escaping,
#' and delegates to repository (which automatically resets approval status).
#'
#' @param review_data List or tibble with review_id and fields to update
#' @param pool Database connection pool
#' @return List with status, message, and entry (review_id)
#' @examples
#' \dontrun{
#' result <- svc_review_update(
#'   review_data = list(review_id = 42, synopsis = "Updated synopsis"),
#'   pool = pool
#' )
#' # Returns: list(status = 200, message = "OK. Entry created.", entry = 42)
#' }
svc_review_update <- function(review_data, pool) {
  # Convert to list if tibble
  if (is.data.frame(review_data)) {
    review_data <- as.list(review_data[1, ])
  }

  # Validate review_id present
  if (is.null(review_data$review_id) || is.na(review_data$review_id)) {
    return(list(
      status = 405,
      message = "review_id is required for update."
    ))
  }

  # Extract review_id for WHERE clause
  review_id_for_update <- review_data$review_id

  # Prepare update data (remove entity_id and review_id)
  update_data <- review_data
  update_data$entity_id <- NULL
  update_data$review_id <- NULL

  # Escape single quotes in synopsis if present
  if (!is.null(update_data$synopsis)) {
    update_data$synopsis <- stringr::str_replace_all(update_data$synopsis, "'", "''")
  }

  # Use repository to update review (resets approval automatically)
  review_update(review_id_for_update, update_data)

  # Return success
  return(list(
    status = 200,
    message = "OK. Entry created.",
    entry = review_id_for_update
  ))
}


#' Add publication connections to a review (service layer)
#'
#' Business logic for connecting publications to reviews. Validates publication
#' existence, enforces entity_id matching, handles POST vs PUT operations.
#'
#' @param publication_data Data frame with publication_id and publication_type columns
#' @param entity_id Entity ID the review belongs to
#' @param review_id Review ID to connect publications to
#' @param pool Database connection pool
#' @param is_update Logical - if TRUE, replaces existing connections (default: FALSE)
#' @return List with status and message
#' @examples
#' \dontrun{
#' result <- svc_review_add_publications(
#'   publication_data = tibble(publication_id = c(1, 2), publication_type = c("primary", "secondary")),
#'   entity_id = 10,
#'   review_id = 42,
#'   pool = pool
#' )
#' }
svc_review_add_publications <- function(publication_data, entity_id, review_id, pool, is_update = FALSE) {
  # Validate publications exist in publication table
  publication_validate_ids(publication_data$publication_id)

  # Prepare publications tibble for submission
  publications_submission <- publication_data %>%
    add_column(review_id = review_id) %>%
    add_column(entity_id = entity_id) %>%
    select(review_id, entity_id, publication_id, publication_type)

  # For PUT request, verify entity_id matches (prevent changing entity association)
  review_publication_for_match <- (pool %>%
    tbl("ndd_entity_review") %>%
    select(review_id, entity_id) %>%
    filter(review_id == {{ review_id }}) %>%
    collect() %>%
    unique()
  )$entity_id[1]

  entity_id_match <- (review_publication_for_match == entity_id)

  if (!is_update) {
    # POST: create new connections
    publication_connect_to_review(review_id, entity_id, publications_submission)

    return(list(
      status = 200,
      message = "OK. Entry created."
    ))
  } else if (is_update && (entity_id_match || is.na(entity_id_match))) {
    # PUT: replace existing connections
    publication_replace_for_review(review_id, entity_id, publications_submission)

    return(list(
      status = 200,
      message = "OK. Entry created."
    ))
  } else {
    # Entity ID mismatch
    return(list(
      status = 405,
      message = "Method not Allowed."
    ))
  }
}


#' Add phenotype connections to a review (service layer)
#'
#' Business logic for connecting phenotypes to reviews. Validates phenotype
#' existence, enforces entity_id matching, handles POST vs PUT operations.
#'
#' @param phenotypes_data Data frame with phenotype_id and modifier_id columns
#' @param entity_id Entity ID the review belongs to
#' @param review_id Review ID to connect phenotypes to
#' @param pool Database connection pool
#' @param is_update Logical - if TRUE, replaces existing connections (default: FALSE)
#' @return List with status and message
#' @examples
#' \dontrun{
#' result <- svc_review_add_phenotypes(
#'   phenotypes_data = tibble(phenotype_id = c("HP:0001250", "HP:0001263"), modifier_id = c(1, 1)),
#'   entity_id = 10,
#'   review_id = 42,
#'   pool = pool
#' )
#' }
svc_review_add_phenotypes <- function(phenotypes_data, entity_id, review_id, pool, is_update = FALSE) {
  # Validate phenotypes exist in phenotype_list
  phenotype_validate_ids(phenotypes_data$phenotype_id)

  # Prepare phenotype tibble for submission
  phenotypes_submission <- phenotypes_data %>%
    add_column(review_id = review_id) %>%
    add_column(entity_id = entity_id) %>%
    select(review_id, phenotype_id, entity_id, modifier_id)

  # For PUT request, verify entity_id matches (prevent changing entity association)
  ndd_review_phenotype_for_match <- (pool %>%
    tbl("ndd_review_phenotype_connect") %>%
    select(review_id, entity_id) %>%
    filter(review_id == {{ review_id }}) %>%
    collect() %>%
    unique()
  )$entity_id[1]

  entity_id_match <- (ndd_review_phenotype_for_match == entity_id)

  if (!is_update) {
    # POST: create new connections
    phenotype_connect_to_review(review_id, entity_id, phenotypes_submission)

    return(list(
      status = 200,
      message = "OK. Entry created."
    ))
  } else if (is_update && (entity_id_match || is.na(entity_id_match))) {
    # PUT: replace existing connections
    phenotype_replace_for_review(review_id, entity_id, phenotypes_submission)

    return(list(
      status = 200,
      message = "OK. Entry created."
    ))
  } else {
    # Entity ID mismatch
    return(list(
      status = 405,
      message = "Method not Allowed."
    ))
  }
}


#' Add variation ontology connections to a review (service layer)
#'
#' Business logic for connecting variation ontology terms to reviews. Validates
#' term existence, enforces entity_id matching, handles POST vs PUT operations.
#'
#' @param vario_data Data frame with vario_id and modifier_id columns
#' @param entity_id Entity ID the review belongs to
#' @param review_id Review ID to connect variation ontology to
#' @param pool Database connection pool
#' @param is_update Logical - if TRUE, replaces existing connections (default: FALSE)
#' @return List with status and message
#' @examples
#' \dontrun{
#' result <- svc_review_add_variation_ontology(
#'   vario_data = tibble(vario_id = c("VariO:0001", "VariO:0002"), modifier_id = c(1, 1)),
#'   entity_id = 10,
#'   review_id = 42,
#'   pool = pool
#' )
#' }
svc_review_add_variation_ontology <- function(vario_data, entity_id, review_id, pool, is_update = FALSE) {
  # Validate variation ontology terms exist
  variation_ontology_validate_ids(vario_data$vario_id)

  # Prepare variation ontology tibble for submission
  variation_ontology_submission <- vario_data %>%
    add_column(review_id = review_id) %>%
    add_column(entity_id = entity_id) %>%
    select(review_id, vario_id, modifier_id, entity_id)

  # For PUT request, verify entity_id matches (prevent changing entity association)
  variation_ontology_match <- (pool %>%
    tbl("ndd_review_variation_ontology_connect") %>%
    select(review_id, entity_id) %>%
    filter(review_id == {{ review_id }}) %>%
    collect() %>%
    unique()
  )$entity_id[1]

  entity_id_match <- (variation_ontology_match == entity_id)

  if (!is_update) {
    # POST: create new connections
    variation_ontology_connect_to_review(review_id, entity_id, variation_ontology_submission)

    return(list(
      status = 200,
      message = "OK. Entry created."
    ))
  } else if (is_update && (entity_id_match || is.na(entity_id_match))) {
    # PUT: replace existing connections
    variation_ontology_replace_for_review(review_id, entity_id, variation_ontology_submission)

    return(list(
      status = 200,
      message = "OK. Entry created."
    ))
  } else {
    # Entity ID mismatch
    return(list(
      status = 405,
      message = "Method not Allowed."
    ))
  }
}
