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
#' svc_entity_validate(list(hgnc_id = 123, hpo_mode_of_inheritance_term = "HP:0000006", ...))
#' }
svc_entity_validate <- function(entity_data) {
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
#' result <- svc_entity_create(entity_data, user_id = 10, pool)
#' # Returns: list(status = 200, message = "OK. Entry created.", entry = tibble(entity_id = 123))
#' }
svc_entity_create <- function(entity_data, user_id, pool) {
  # Validate required fields
  svc_entity_validate(entity_data)

  # Add user_id to entity data
  entity_data$entry_user_id <- user_id

  # Check for duplicate entity (same quadruple)
  duplicate <- svc_entity_check_duplicate(entity_data, pool)
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
#' result <- svc_entity_deactivate(5, replacement = 10, pool)
#' # Returns: list(status = 200, message = "OK. Entity deactivated.", entry = 5)
#' }
svc_entity_deactivate <- function(entity_id, replacement = NULL, pool) {
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
#' full_entity <- svc_entity_get_full(5, pool)
#' # Returns: list(entity = ..., reviews = ..., status = ..., phenotypes = ..., publications = ...)
#' }
svc_entity_get_full <- function(entity_id, pool) {
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
#' duplicate <- svc_entity_check_duplicate(entity_data, pool)
#' }
svc_entity_check_duplicate <- function(entity_data, pool) {
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


#' Create entity with review and status atomically
#'
#' Creates entity, review, and status records in a single transaction.
#' This ensures entity is never orphaned (created without review/status).
#' Fixes BUG-02/BUG-03 (GAP43, MEF2C visibility issues).
#'
#' @param entity_data List with entity fields (hgnc_id, hpo_mode_of_inheritance_term, etc.)
#' @param review_data List with review fields (synopsis, comment, review_user_id)
#' @param status_data List with status fields (category_id, problematic, status_user_id)
#' @param pool Database connection pool
#' @return List with status, message, and entry (tibble with entity_id, review_id, status_id)
#'
#' @examples
#' \dontrun{
#' result <- svc_entity_create_with_review_status(
#'   entity_data = list(hgnc_id = 123, ...),
#'   review_data = list(synopsis = "...", review_user_id = 10),
#'   status_data = list(category_id = 1, problematic = 0, status_user_id = 10),
#'   pool = pool
#' )
#' }
svc_entity_create_with_review_status <- function(entity_data, review_data, status_data, pool) {
  logger::log_debug(
    "Starting atomic entity+review+status creation",
    hgnc_id = entity_data$hgnc_id
  )

  # Validate required fields
  svc_entity_validate(entity_data)

  # Check for duplicate
  duplicate <- svc_entity_check_duplicate(entity_data, pool)
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

  # Execute entity+review+status creation in transaction
  tryCatch(
    {
      result <- db_with_transaction(function(txn_conn) {
        # Step 1: Create entity
        # nolint start: line_length_linter
        sql_entity <- "INSERT INTO ndd_entity (hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype, entry_user_id) VALUES (?, ?, ?, ?, ?)"
        # nolint end
        db_execute_statement(
          sql_entity,
          list(
            entity_data$hgnc_id,
            entity_data$hpo_mode_of_inheritance_term,
            entity_data$disease_ontology_id_version,
            entity_data$ndd_phenotype,
            entity_data$entry_user_id
          ),
          conn = txn_conn
        )

        # Get entity_id
        result_id <- db_execute_query("SELECT LAST_INSERT_ID() as entity_id", conn = txn_conn)
        entity_id <- as.integer(result_id$entity_id[1])

        logger::log_debug("Entity created in transaction", entity_id = entity_id)

        # Step 2: Create review
        synopsis <- review_data$synopsis
        if (!is.null(synopsis) && !is.na(synopsis) && is.character(synopsis)) {
          synopsis <- stringr::str_replace_all(synopsis, "'", "''")
        }

        # BUG-01/BUG-02/BUG-03 fix: include review_user_id which is required by database
        db_execute_statement(
          "INSERT INTO ndd_entity_review (entity_id, synopsis, review_user_id) VALUES (?, ?, ?)",
          list(entity_id, synopsis, review_data$review_user_id),
          conn = txn_conn
        )

        # Get review_id
        review_result <- db_execute_query("SELECT LAST_INSERT_ID() as review_id", conn = txn_conn)
        review_id <- as.integer(review_result$review_id[1])

        logger::log_debug("Review created in transaction", review_id = review_id)

        # Step 3: Create status
        db_execute_statement(
          "INSERT INTO ndd_entity_status (entity_id, category_id, status_user_id, problematic) VALUES (?, ?, ?, ?)",
          list(
            entity_id,
            status_data$category_id,
            status_data$status_user_id,
            if (!is.null(status_data$problematic)) status_data$problematic else 0
          ),
          conn = txn_conn
        )

        # Get status_id
        status_result <- db_execute_query("SELECT LAST_INSERT_ID() as status_id", conn = txn_conn)
        status_id <- as.integer(status_result$status_id[1])

        logger::log_debug("Status created in transaction", status_id = status_id)

        # Return all IDs
        list(
          entity_id = entity_id,
          review_id = review_id,
          status_id = status_id
        )
      }, pool_obj = pool)

      logger::log_info(
        "Entity+review+status created atomically",
        entity_id = result$entity_id,
        review_id = result$review_id,
        status_id = result$status_id
      )

      return(list(
        status = 200,
        message = "OK. Entry created.",
        entry = tibble::tibble(
          entity_id = result$entity_id,
          review_id = result$review_id,
          status_id = result$status_id
        )
      ))
    },
    error = function(e) {
      logger::log_error(
        "Atomic entity creation failed",
        error = e$message,
        hgnc_id = entity_data$hgnc_id
      )
      return(list(
        status = 500,
        message = "Internal Server Error. Entity creation failed.",
        error = e$message
      ))
    }
  )
}


#' Create entity with all related data atomically
#'
#' Creates entity, review, publications, phenotypes, variation ontology,
#' and status in a single database transaction. If any step fails, all
#' changes are rolled back - no orphaned records.
#'
#' Validation and external API calls (publication lookups) happen BEFORE
#' the transaction to keep transactions short.
#'
#' @param entity_data List with entity fields
#' @param review_data List with synopsis and review_user_id
#' @param status_data List with category_id, problematic, status_user_id
#' @param publications Tibble with publication_id and publication_type (or NULL)
#' @param phenotypes Tibble with phenotype_id and modifier_id (or NULL)
#' @param variation_ontology Tibble with vario_id and modifier_id (or NULL)
#' @param direct_approval Logical - if TRUE, approve review and status in same transaction
#' @param approving_user_id Integer user ID for approval (required if direct_approval = TRUE)
#' @param pool Database connection pool
#' @return List with status, message, and entry
#'
#' @examples
#' \dontrun{
#' result <- svc_entity_create_full(
#'   entity_data = list(hgnc_id = 123, ...),
#'   review_data = list(synopsis = "...", review_user_id = 10),
#'   status_data = list(category_id = 1, problematic = 0),
#'   publications = tibble(publication_id = c("PMID:123"), publication_type = c("additional_references")),
#'   phenotypes = tibble(phenotype_id = c("HP:0001249"), modifier_id = c("1")),
#'   variation_ontology = NULL,
#'   direct_approval = FALSE,
#'   approving_user_id = NULL,
#'   pool = pool
#' )
#' }
# nolint start: cyclocomp_linter
svc_entity_create_full <- function(entity_data, review_data, status_data,
                                   publications = NULL, phenotypes = NULL,
                                   variation_ontology = NULL,
                                   direct_approval = FALSE,
                                   approving_user_id = NULL,
                                   pool) {
  logger::log_info(
    "Starting full entity creation",
    hgnc_id = entity_data$hgnc_id,
    direct_approval = direct_approval
  )

  # --- Phase 1: Validation (before transaction, uses pool) ---

  # Validate entity fields
  svc_entity_validate(entity_data)

  # Check for duplicate entity

  duplicate <- svc_entity_check_duplicate(entity_data, pool)
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

  # Validate publication IDs exist in publication table (if publications provided)
  if (!is.null(publications) && nrow(publications) > 0) {
    tryCatch(
      publication_validate_ids(publications$publication_id),
      publication_validation_error = function(e) {
        logger::log_error(
          "Publication validation failed before transaction",
          error = e$message
        )
        rlang::abort(
          message = e$message,
          class = "entity_creation_validation_error"
        )
      }
    )
  }

  # --- Phase 2: All DB writes in a single transaction ---

  tryCatch(
    {
      result <- db_with_transaction(function(txn_conn) {
        # Step 1: Create entity
        entity_id <- entity_create(entity_data, conn = txn_conn)
        logger::log_debug("Transaction: entity created", entity_id = entity_id)

        # Step 2: Create review (add entity_id to review_data)
        review_data$entity_id <- entity_id
        review_id <- review_create(review_data, conn = txn_conn)
        logger::log_debug("Transaction: review created", review_id = review_id)

        # Step 3: Connect publications to review
        if (!is.null(publications) && nrow(publications) > 0) {
          publication_connect_to_review(
            review_id, entity_id, publications,
            conn = txn_conn
          )
          logger::log_debug(
            "Transaction: {nrow(publications)} publications connected"
          )
        }

        # Step 4: Connect phenotypes to review
        if (!is.null(phenotypes) && nrow(phenotypes) > 0) {
          phenotype_connect_to_review(
            review_id, entity_id, phenotypes,
            conn = txn_conn
          )
          logger::log_debug(
            "Transaction: {nrow(phenotypes)} phenotypes connected"
          )
        }

        # Step 5: Connect variation ontology to review
        if (!is.null(variation_ontology) && nrow(variation_ontology) > 0) {
          variation_ontology_connect_to_review(
            review_id, entity_id, variation_ontology,
            conn = txn_conn
          )
          logger::log_debug(
            "Transaction: {nrow(variation_ontology)} variation ontology terms connected"
          )
        }

        # Step 6: Create status
        status_data$entity_id <- entity_id
        status_id <- status_create(status_data, conn = txn_conn)
        logger::log_debug("Transaction: status created", status_id = status_id)

        # Step 7: Direct approval (if requested)
        if (direct_approval && !is.null(approving_user_id)) {
          # Approve review: set is_primary, review_approved, approving_user_id
          db_execute_statement(
            "UPDATE ndd_entity_review SET is_primary = 1, review_approved = 1, approving_user_id = ? WHERE review_id = ?", # nolint: line_length_linter
            list(approving_user_id, review_id),
            conn = txn_conn
          )
          logger::log_debug(
            "Transaction: review approved",
            review_id = review_id
          )

          # Approve status: set is_active, status_approved, approving_user_id
          db_execute_statement(
            "UPDATE ndd_entity_status SET is_active = 1, status_approved = 1, approving_user_id = ? WHERE status_id = ?", # nolint: line_length_linter
            list(approving_user_id, status_id),
            conn = txn_conn
          )
          logger::log_debug(
            "Transaction: status approved",
            status_id = status_id
          )
        }

        # Return all IDs from transaction
        list(
          entity_id = entity_id,
          review_id = review_id,
          status_id = status_id
        )
      }, pool_obj = pool)

      logger::log_info(
        "Full entity creation completed atomically",
        entity_id = result$entity_id,
        review_id = result$review_id,
        status_id = result$status_id,
        direct_approval = direct_approval
      )

      return(list(
        status = 200,
        message = "OK. Entry created.",
        entry = tibble::tibble(
          entity_id = result$entity_id,
          review_id = result$review_id,
          status_id = result$status_id
        )
      ))
    },
    entity_creation_validation_error = function(e) {
      logger::log_error("Entity creation validation failed", error = e$message)
      return(list(
        status = 400,
        message = paste("Bad Request.", e$message),
        error = e$message
      ))
    },
    db_transaction_error = function(e) {
      logger::log_error(
        "Entity creation transaction failed - all changes rolled back",
        error = e$message,
        hgnc_id = entity_data$hgnc_id
      )
      return(list(
        status = 500,
        message = "Internal Server Error. Entity creation failed. All changes rolled back.",
        error = e$message
      ))
    },
    error = function(e) {
      logger::log_error(
        "Unexpected error during entity creation",
        error = e$message,
        hgnc_id = entity_data$hgnc_id
      )
      return(list(
        status = 500,
        message = "Internal Server Error. Entity creation failed.",
        error = e$message
      ))
    }
  )
}
# nolint end
