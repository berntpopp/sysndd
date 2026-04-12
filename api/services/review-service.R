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

# ---------------------------------------------------------------------------
# Migrated from legacy-wrappers.R (Phase D, D4)
# These functions retain their original names because endpoint handlers and
# Phase C test sandboxes reference them by name. They are thin orchestrators
# that delegate to the repository layer.
# ---------------------------------------------------------------------------

#' Create or update review (migrated from legacy-wrappers.R)
#'
#' @param method "POST" for create, "PUT" for update
#' @param review_data Tibble with review fields
#' @param re_review Logical indicating re-review operation
#' @return List with status, message, and entry
put_post_db_review <- function(method, review_data, re_review = FALSE) {
  logger::log_debug("put_post_db_review: {method} review (re_review={re_review})")

  if (is.data.frame(review_data)) {
    review_data <- as.list(review_data[1, ])
  }

  tryCatch(
    {
      if (toupper(method) == "POST") {
        review_id <- review_create(review_data)
        logger::log_info("put_post_db_review: Created review {review_id}")
        if (re_review && !is.null(review_data$entity_id)) {
          tryCatch(
            review_update_re_review_status(review_data$entity_id, review_id),
            error = function(e) logger::log_warn("put_post_db_review: Failed to update re_review status: {e$message}")
          )
        }
        return(list(status = 200, message = "OK. Review created.",
                    entry = tibble::tibble(review_id = review_id)))
      } else {
        if (is.null(review_data$review_id)) {
          return(list(status = 405, message = "review_id is required for PUT operation", entry = NA))
        }
        review_update(review_data$review_id, review_data)
        logger::log_info("put_post_db_review: Updated review {review_data$review_id}")
        if (re_review && !is.null(review_data$entity_id)) {
          tryCatch(
            review_update_re_review_status(review_data$entity_id, review_data$review_id),
            error = function(e) logger::log_warn("put_post_db_review: Failed to update re_review status: {e$message}")
          )
        }
        return(list(status = 200, message = "OK. Review updated.",
                    entry = tibble::tibble(review_id = review_data$review_id)))
      }
    },
    error = function(e) {
      logger::log_error("put_post_db_review: Error: {e$message}")
      return(list(status = 500, message = "Error processing review.", entry = NA, error = e$message))
    }
  )
}

#' Connect publications to review (migrated from legacy-wrappers.R)
#'
#' @param method "POST" to add, "PUT" to replace
#' @param publications Tibble with publication data
#' @param entity_id Integer entity ID
#' @param review_id Integer review ID
#' @return List with status and message
put_post_db_pub_con <- function(method, publications, entity_id, review_id) {
  logger::log_debug("put_post_db_pub_con: {method} publications for review {review_id}")

  tryCatch(
    {
      if (toupper(method) == "PUT") {
        publication_replace_for_review(review_id, entity_id, publications)
      } else {
        publication_connect_to_review(review_id, entity_id, publications)
      }
      logger::log_info("put_post_db_pub_con: Connected publications to review {review_id}")
      return(list(status = 200, message = "OK. Publications connected."))
    },
    error = function(e) {
      logger::log_error("put_post_db_pub_con: Error: {e$message}")
      return(list(status = 500, message = "Error connecting publications.", error = e$message))
    }
  )
}

#' Connect phenotypes to review (migrated from legacy-wrappers.R)
#'
#' @param method "POST" to add, "PUT" to replace
#' @param phenotypes Tibble with phenotype data
#' @param entity_id Integer entity ID
#' @param review_id Integer review ID
#' @return List with status and message
put_post_db_phen_con <- function(method, phenotypes, entity_id, review_id) {
  logger::log_debug("put_post_db_phen_con: {method} phenotypes for review {review_id}")

  if ("value" %in% colnames(phenotypes)) {
    phenotypes_transformed <- phenotypes %>%
      dplyr::mutate(
        phenotype_id = sapply(value, function(x) {
          parts <- strsplit(as.character(x), "-")[[1]]
          if (length(parts) >= 2) paste(parts[2:length(parts)], collapse = "-") else x
        }),
        modifier_id = sapply(value, function(x) {
          parts <- strsplit(as.character(x), "-")[[1]]
          if (length(parts) >= 1) parts[1] else NA
        })
      ) %>%
      dplyr::select(phenotype_id, modifier_id)
  } else if ("phenotype_id" %in% colnames(phenotypes) && "modifier_id" %in% colnames(phenotypes)) {
    phenotypes_transformed <- phenotypes
  } else {
    return(list(status = 405, message = "Invalid phenotypes format",
                error = "Expected 'value' or 'phenotype_id'/'modifier_id' columns"))
  }

  tryCatch(
    {
      if (toupper(method) == "PUT") {
        phenotype_replace_for_review(review_id, entity_id, phenotypes_transformed)
      } else {
        phenotype_connect_to_review(review_id, entity_id, phenotypes_transformed)
      }
      logger::log_info("put_post_db_phen_con: Connected phenotypes to review {review_id}")
      return(list(status = 200, message = "OK. Phenotypes connected."))
    },
    error = function(e) {
      logger::log_error("put_post_db_phen_con: Error: {e$message}")
      return(list(status = 500, message = "Error connecting phenotypes.", error = e$message))
    }
  )
}

#' Connect variation ontology to review (migrated from legacy-wrappers.R)
#'
#' @param method "POST" to add, "PUT" to replace
#' @param variation_ontology Tibble with variation ontology data
#' @param entity_id Integer entity ID
#' @param review_id Integer review ID
#' @return List with status and message
put_post_db_var_ont_con <- function(method, variation_ontology, entity_id, review_id) {
  logger::log_debug("put_post_db_var_ont_con: {method} variation ontology for review {review_id}")

  if ("value" %in% colnames(variation_ontology)) {
    vario_transformed <- variation_ontology %>%
      dplyr::mutate(
        vario_id = sapply(value, function(x) {
          parts <- strsplit(as.character(x), "-")[[1]]
          if (length(parts) >= 2) paste(parts[2:length(parts)], collapse = "-") else x
        }),
        modifier_id = sapply(value, function(x) {
          parts <- strsplit(as.character(x), "-")[[1]]
          if (length(parts) >= 1) parts[1] else NA
        })
      ) %>%
      dplyr::select(vario_id, modifier_id)
  } else if ("vario_id" %in% colnames(variation_ontology) && "modifier_id" %in% colnames(variation_ontology)) {
    vario_transformed <- variation_ontology
  } else {
    return(list(status = 405, message = "Invalid variation ontology format",
                error = "Expected 'value' or 'vario_id'/'modifier_id' columns"))
  }

  tryCatch(
    {
      if (toupper(method) == "PUT") {
        variation_ontology_replace_for_review(review_id, entity_id, vario_transformed)
      } else {
        variation_ontology_connect_to_review(review_id, entity_id, vario_transformed)
      }
      logger::log_info("put_post_db_var_ont_con: Connected variation ontology to review {review_id}")
      return(list(status = 200, message = "OK. Variation ontology connected."))
    },
    error = function(e) {
      logger::log_error("put_post_db_var_ont_con: Error: {e$message}")
      return(list(status = 500, message = "Error connecting variation ontology.", error = e$message))
    }
  )
}
