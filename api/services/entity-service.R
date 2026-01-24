# Entity Service Layer for SysNDD API
# Provides business logic for entity CRUD operations
#
# Functions accept pool as parameter (dependency injection)
# Uses entity-repository.R for database operations
# Uses core/errors.R helpers for RFC 9457 errors

#' Validate entity data
#'
#' Validates that all required fields are present and non-empty.
#' Throws bad_request error if validation fails.
#'
#' @param entity_data List with entity fields
#' @return TRUE if valid
#' @examples
#' \dontrun{
#' entity_validate(list(hgnc_id = 123, hpo_mode_of_inheritance_term = "HP:0000006", ...))
#' }
entity_validate <- function(entity_data) {
  required_fields <- c(
    "hgnc_id",
    "hpo_mode_of_inheritance_term",
    "disease_ontology_id_version",
    "ndd_phenotype"
  )

  # Convert to list if tibble/data.frame
  if (is.data.frame(entity_data)) {
    entity_data <- as.list(entity_data[1, ])
  }

  # Check for missing fields
  missing_fields <- setdiff(required_fields, names(entity_data))
  if (length(missing_fields) > 0) {
    stop_for_bad_request(
      paste("Missing required fields:", paste(missing_fields, collapse = ", "))
    )
  }

  # Check for empty values
  for (field in required_fields) {
    value <- entity_data[[field]]
    if (is.null(value) || is.na(value) || (is.character(value) && nchar(trimws(value)) == 0)) {
      stop_for_bad_request(paste("Field", field, "cannot be empty"))
    }
  }

  TRUE
}


#' Create a new entity
#'
#' Validates entity data and creates new entity in database.
#' Returns structured response matching current API format.
#'
#' @param entity_data List with hgnc_id, hpo_mode_of_inheritance_term,
#'   disease_ontology_id_version, ndd_phenotype
#' @param user_id User ID creating the entity
#' @param pool Database connection pool
#' @return List with status, message, and entry
#' @examples
#' \dontrun{
#' result <- entity_create(entity_data, user_id = 10, pool)
#' # Returns: list(status = 200, message = "OK. Entry created.", entry = tibble(entity_id = 123))
#' }
entity_create <- function(entity_data, user_id, pool) {
  # Validate required fields
  entity_validate(entity_data)

  # Add user_id to entity data
  entity_data$entry_user_id <- user_id

  # Check for duplicate entity (same quadruple)
  duplicate <- entity_check_duplicate(entity_data, pool)
  if (!is.null(duplicate)) {
    logger::log_warn(
      "Duplicate entity detected",
      hgnc_id = entity_data$hgnc_id,
      existing_entity_id = duplicate$entity_id
    )
    return(list(
      status = 409,
      message = "Conflict. Entity with same quadruple already exists.",
      entry = duplicate
    ))
  }

  # Create entity using repository (from entity-repository.R)
  # Note: The repository function entity_create is already loaded globally
  # We need to prepare the entity_data with entry_user_id included
  result <- tryCatch(
    {
      # Prepare entity tibble for repository
      entity_tibble <- tibble::tibble(
        hgnc_id = entity_data$hgnc_id,
        hpo_mode_of_inheritance_term = entity_data$hpo_mode_of_inheritance_term,
        disease_ontology_id_version = entity_data$disease_ontology_id_version,
        ndd_phenotype = entity_data$ndd_phenotype,
        entry_user_id = entity_data$entry_user_id
      )

      # Call repository layer (this is from functions/entity-repository.R)
      # The repository returns integer entity_id on success
      conn <- pool::poolCheckout(pool)
      on.exit(pool::poolReturn(conn), add = TRUE)

      # Use db_execute_statement via repository pattern
      sql <- "INSERT INTO ndd_entity (hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype, entry_user_id) VALUES (?, ?, ?, ?, ?)"
      params <- list(
        entity_data$hgnc_id,
        entity_data$hpo_mode_of_inheritance_term,
        entity_data$disease_ontology_id_version,
        entity_data$ndd_phenotype,
        entity_data$entry_user_id
      )
      db_execute_statement(sql, params)

      # Get last insert ID
      result_id <- db_execute_query("SELECT LAST_INSERT_ID() as entity_id")
      entity_id <- as.integer(result_id$entity_id[1])

      logger::log_info(
        "Entity created",
        entity_id = entity_id,
        user_id = user_id,
        hgnc_id = entity_data$hgnc_id
      )

      list(
        status = 200,
        message = "OK. Entry created.",
        entry = tibble::tibble(entity_id = entity_id)
      )
    },
    entity_validation_error = function(e) {
      logger::log_error("Entity validation failed", error = e$message)
      list(
        status = 400,
        message = "Bad Request. Entity validation failed.",
        error = e$message
      )
    },
    error = function(e) {
      logger::log_error("Entity creation failed", error = e$message)
      list(
        status = 500,
        message = "Internal Server Error. Entry not created.",
        error = e$message
      )
    }
  )

  result
}


#' Deactivate entity
#'
#' Marks entity as inactive and optionally sets replacement.
#' Uses parameterized UPDATE query via repository.
#'
#' @param entity_id Integer entity ID to deactivate
#' @param replacement Integer ID of replacement entity, or NULL
#' @param pool Database connection pool
#' @return List with status, message, and entity_id
#' @examples
#' \dontrun{
#' result <- entity_deactivate(5, replacement = 10, pool)
#' # Returns: list(status = 200, message = "OK. Entity deactivated.", entry = 5)
#' }
entity_deactivate <- function(entity_id, replacement = NULL, pool) {
  if (is.null(entity_id) || is.na(entity_id)) {
    return(list(
      status = 400,
      message = "Bad Request. Submitted entity_id cannot be empty."
    ))
  }

  # Check if entity exists (using pool query)
  existing <- pool %>%
    dplyr::tbl("ndd_entity") %>%
    dplyr::filter(entity_id == !!entity_id) %>%
    dplyr::collect()

  if (nrow(existing) == 0) {
    return(list(
      status = 404,
      message = "Not Found. Entity does not exist."
    ))
  }

  # Deactivate using parameterized query
  result <- tryCatch(
    {
      # Use parameterized UPDATE query
      sql <- "UPDATE ndd_entity SET is_active = 0, replaced_by = ? WHERE entity_id = ?"
      params <- list(replacement, entity_id)
      db_execute_statement(sql, params)

      logger::log_info(
        "Entity deactivated",
        entity_id = entity_id,
        replaced_by = replacement
      )

      list(
        status = 200,
        message = "OK. Entity deactivated.",
        entry = entity_id
      )
    },
    error = function(e) {
      logger::log_error("Entity deactivation failed", error = e$message, entity_id = entity_id)
      list(
        status = 500,
        message = "Internal Server Error. Entity not deactivated.",
        error = e$message
      )
    }
  )

  result
}


#' Get full entity with related data
#'
#' Retrieves entity with all related reviews, status, and phenotypes.
#' Uses pool to perform multiple queries and join data.
#'
#' @param entity_id Integer entity ID
#' @param pool Database connection pool
#' @return List with entity, reviews, status, phenotypes, and publications
#' @examples
#' \dontrun{
#' full_entity <- entity_get_full(5, pool)
#' # Returns: list(entity = ..., reviews = ..., status = ..., phenotypes = ..., publications = ...)
#' }
entity_get_full <- function(entity_id, pool) {
  # Get base entity
  entity <- pool %>%
    dplyr::tbl("ndd_entity_view") %>%
    dplyr::filter(entity_id == !!entity_id) %>%
    dplyr::collect()

  if (nrow(entity) == 0) {
    return(list(
      status = 404,
      message = "Not Found. Entity does not exist."
    ))
  }

  # Get primary review
  review <- pool %>%
    dplyr::tbl("ndd_entity_review") %>%
    dplyr::filter(entity_id == !!entity_id, is_primary == 1) %>%
    dplyr::collect()

  # Get active status
  status <- pool %>%
    dplyr::tbl("ndd_entity_status") %>%
    dplyr::filter(entity_id == !!entity_id, is_active == 1) %>%
    dplyr::collect()

  # Get phenotypes (via review)
  phenotypes <- tibble::tibble()
  if (nrow(review) > 0) {
    phenotypes <- pool %>%
      dplyr::tbl("ndd_review_phenotype_connect") %>%
      dplyr::filter(review_id == !!review$review_id[1]) %>%
      dplyr::left_join(
        dplyr::tbl(pool, "phenotype_list"),
        by = "phenotype_id"
      ) %>%
      dplyr::collect()
  }

  # Get publications (via review)
  publications <- tibble::tibble()
  if (nrow(review) > 0) {
    publications <- pool %>%
      dplyr::tbl("ndd_review_publication_join") %>%
      dplyr::filter(review_id == !!review$review_id[1]) %>%
      dplyr::collect()
  }

  # Get variation ontology (via review)
  variation_ontology <- tibble::tibble()
  if (nrow(review) > 0) {
    variation_ontology <- pool %>%
      dplyr::tbl("ndd_review_variation_ontology_connect") %>%
      dplyr::filter(review_id == !!review$review_id[1]) %>%
      dplyr::left_join(
        dplyr::tbl(pool, "variation_ontology_list"),
        by = "vario_id"
      ) %>%
      dplyr::collect()
  }

  list(
    status = 200,
    entity = entity,
    review = review,
    status = status,
    phenotypes = phenotypes,
    publications = publications,
    variation_ontology = variation_ontology
  )
}


#' Check for duplicate entity
#'
#' Checks if entity with same quadruple (hgnc_id, hpo_mode_of_inheritance_term,
#' disease_ontology_id_version, ndd_phenotype) already exists.
#'
#' @param entity_data List with entity fields
#' @param pool Database connection pool
#' @return Tibble with existing entity or NULL if no duplicate
#' @examples
#' \dontrun{
#' duplicate <- entity_check_duplicate(entity_data, pool)
#' }
entity_check_duplicate <- function(entity_data, pool) {
  # Query for existing entity with same quadruple
  existing <- pool %>%
    dplyr::tbl("ndd_entity") %>%
    dplyr::filter(
      hgnc_id == !!entity_data$hgnc_id,
      hpo_mode_of_inheritance_term == !!entity_data$hpo_mode_of_inheritance_term,
      disease_ontology_id_version == !!entity_data$disease_ontology_id_version,
      ndd_phenotype == !!entity_data$ndd_phenotype,
      is_active == 1
    ) %>%
    dplyr::collect()

  if (nrow(existing) > 0) {
    return(existing[1, ])
  }

  NULL
}
