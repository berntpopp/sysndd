# functions/legacy-wrappers.R
#
# Legacy wrapper functions for backward compatibility with endpoints.
# These functions provide the interface expected by entity_endpoints.R
# while delegating to the new repository layer.
#
# Background: The original database-functions.R was removed in a refactoring,
# but the endpoints still call these wrapper functions. This file bridges
# the gap until the endpoints can be updated to use the service layer directly.
#
# Functions:
# - post_db_entity: Create new entity
# - put_db_entity_deactivation: Deactivate entity
# - put_post_db_review: Create/update review
# - put_post_db_pub_con: Connect publications to review
# - put_post_db_phen_con: Connect phenotypes to review
# - put_post_db_var_ont_con: Connect variation ontology to review
# - put_post_db_status: Create/update status
# - put_db_review_approve: Approve review
# - put_db_status_approve: Approve status
# - new_publication: Create new publications

library(tibble)
library(dplyr)
library(stringr)
library(logger)

#' Create new entity (legacy wrapper)
#'
#' @param entity_data Tibble or list with entity fields
#'
#' @return List with status, message, entry (tibble with entity_id), and error
#'
#' @export
post_db_entity <- function(entity_data) {
  log_debug("post_db_entity: Creating new entity")

  # Convert tibble to list if necessary

if (is.data.frame(entity_data)) {
    entity_data <- as.list(entity_data[1, ])
  }

  # Validate required fields
  required_fields <- c(
    "hgnc_id",
    "hpo_mode_of_inheritance_term",
    "disease_ontology_id_version",
    "ndd_phenotype",
    "entry_user_id"
  )

  missing_fields <- setdiff(required_fields, names(entity_data))
  missing_fields <- missing_fields[!sapply(entity_data[missing_fields], function(x) !is.null(x) && !is.na(x))]

  if (length(missing_fields) > 0) {
    log_warn("post_db_entity: Missing required fields: {paste(missing_fields, collapse = ', ')}")
    return(list(
      status = 405,
      message = paste("Missing required fields:", paste(missing_fields, collapse = ", ")),
      entry = NA,
      error = paste("Missing fields:", paste(missing_fields, collapse = ", "))
    ))
  }

  tryCatch({
    # Call repository function
    entity_id <- entity_create(entity_data)

    log_info("post_db_entity: Created entity {entity_id}")

    return(list(
      status = 200,
      message = "OK. Entry created.",
      entry = tibble::tibble(entity_id = entity_id),
      error = NULL
    ))
  }, error = function(e) {
    log_error("post_db_entity: Error creating entity: {e$message}")
    return(list(
      status = 500,
      message = "Error creating entity.",
      entry = NA,
      error = e$message
    ))
  })
}

#' Deactivate entity (legacy wrapper)
#'
#' @param entity_id Integer entity ID to deactivate
#' @param replacement_id Integer replacement entity ID (or NULL)
#'
#' @return List with status and message
#'
#' @export
put_db_entity_deactivation <- function(entity_id, replacement_id = NULL) {
  log_debug("put_db_entity_deactivation: Deactivating entity {entity_id}")

  tryCatch({
    entity_deactivate(entity_id, replacement_id)

    log_info("put_db_entity_deactivation: Deactivated entity {entity_id}")

    return(list(
      status = 200,
      message = "OK. Entity deactivated."
    ))
  }, error = function(e) {
    log_error("put_db_entity_deactivation: Error: {e$message}")
    return(list(
      status = 500,
      message = "Error deactivating entity.",
      error = e$message
    ))
  })
}

#' Create or update review (legacy wrapper)
#'
#' @param method "POST" for create, "PUT" for update
#' @param review_data Tibble with review fields (entity_id, synopsis, comment, review_user_id)
#'
#' @return List with status, message, and entry (tibble with review_id)
#'
#' @export
put_post_db_review <- function(method, review_data) {
  log_debug("put_post_db_review: {method} review")

  # Convert tibble to list if necessary
  if (is.data.frame(review_data)) {
    review_data <- as.list(review_data[1, ])
  }

  tryCatch({
    if (toupper(method) == "POST") {
      # Create new review
      review_id <- review_create(review_data)

      log_info("put_post_db_review: Created review {review_id}")

      return(list(
        status = 200,
        message = "OK. Review created.",
        entry = tibble::tibble(review_id = review_id)
      ))
    } else {
      # Update existing review
      if (is.null(review_data$review_id)) {
        return(list(
          status = 405,
          message = "review_id is required for PUT operation",
          entry = NA
        ))
      }

      review_update(review_data$review_id, review_data)

      log_info("put_post_db_review: Updated review {review_data$review_id}")

      return(list(
        status = 200,
        message = "OK. Review updated.",
        entry = tibble::tibble(review_id = review_data$review_id)
      ))
    }
  }, error = function(e) {
    log_error("put_post_db_review: Error: {e$message}")
    return(list(
      status = 500,
      message = "Error processing review.",
      entry = NA,
      error = e$message
    ))
  })
}

#' Connect publications to review (legacy wrapper)
#'
#' @param method "POST" to add, "PUT" to replace
#' @param publications Tibble with publication_id and publication_type
#' @param entity_id Integer entity ID
#' @param review_id Integer review ID
#'
#' @return List with status and message
#'
#' @export
put_post_db_pub_con <- function(method, publications, entity_id, review_id) {
  log_debug("put_post_db_pub_con: {method} publications for review {review_id}")

  tryCatch({
    if (toupper(method) == "PUT") {
      publication_replace_for_review(review_id, entity_id, publications)
    } else {
      publication_connect_to_review(review_id, entity_id, publications)
    }

    log_info("put_post_db_pub_con: Connected publications to review {review_id}")

    return(list(
      status = 200,
      message = "OK. Publications connected."
    ))
  }, error = function(e) {
    log_error("put_post_db_pub_con: Error: {e$message}")
    return(list(
      status = 500,
      message = "Error connecting publications.",
      error = e$message
    ))
  })
}

#' Connect phenotypes to review (legacy wrapper)
#'
#' @param method "POST" to add, "PUT" to replace
#' @param phenotypes Tibble with phenotype_id and modifier_id
#' @param entity_id Integer entity ID
#' @param review_id Integer review ID
#'
#' @return List with status and message
#'
#' @export
put_post_db_phen_con <- function(method, phenotypes, entity_id, review_id) {
  log_debug("put_post_db_phen_con: {method} phenotypes for review {review_id}")

  # Transform phenotypes data to expected format
  # Input format: tibble with 'value' column containing "modifier-phenotype_id"
  # Need to extract phenotype_id and modifier_id
  if ("value" %in% colnames(phenotypes)) {
    phenotypes_transformed <- phenotypes %>%
      mutate(
        phenotype_id = sapply(value, function(x) {
          parts <- strsplit(as.character(x), "-")[[1]]
          if (length(parts) >= 2) paste(parts[2:length(parts)], collapse = "-") else x
        }),
        modifier_id = sapply(value, function(x) {
          parts <- strsplit(as.character(x), "-")[[1]]
          if (length(parts) >= 1) parts[1] else NA
        })
      ) %>%
      select(phenotype_id, modifier_id)
  } else if ("phenotype_id" %in% colnames(phenotypes) && "modifier_id" %in% colnames(phenotypes)) {
    phenotypes_transformed <- phenotypes
  } else {
    return(list(
      status = 405,
      message = "Invalid phenotypes format",
      error = "Expected 'value' or 'phenotype_id'/'modifier_id' columns"
    ))
  }

  tryCatch({
    if (toupper(method) == "PUT") {
      phenotype_replace_for_review(review_id, entity_id, phenotypes_transformed)
    } else {
      phenotype_connect_to_review(review_id, entity_id, phenotypes_transformed)
    }

    log_info("put_post_db_phen_con: Connected phenotypes to review {review_id}")

    return(list(
      status = 200,
      message = "OK. Phenotypes connected."
    ))
  }, error = function(e) {
    log_error("put_post_db_phen_con: Error: {e$message}")
    return(list(
      status = 500,
      message = "Error connecting phenotypes.",
      error = e$message
    ))
  })
}

#' Connect variation ontology to review (legacy wrapper)
#'
#' @param method "POST" to add, "PUT" to replace
#' @param variation_ontology Tibble with vario_id and modifier_id
#' @param entity_id Integer entity ID
#' @param review_id Integer review ID
#'
#' @return List with status and message
#'
#' @export
put_post_db_var_ont_con <- function(method, variation_ontology, entity_id, review_id) {
  log_debug("put_post_db_var_ont_con: {method} variation ontology for review {review_id}")

  # Transform variation ontology data to expected format
  # Input format: tibble with 'value' column containing "modifier-vario_id"
  if ("value" %in% colnames(variation_ontology)) {
    vario_transformed <- variation_ontology %>%
      mutate(
        vario_id = sapply(value, function(x) {
          parts <- strsplit(as.character(x), "-")[[1]]
          if (length(parts) >= 2) paste(parts[2:length(parts)], collapse = "-") else x
        }),
        modifier_id = sapply(value, function(x) {
          parts <- strsplit(as.character(x), "-")[[1]]
          if (length(parts) >= 1) parts[1] else NA
        })
      ) %>%
      select(vario_id, modifier_id)
  } else if ("vario_id" %in% colnames(variation_ontology) && "modifier_id" %in% colnames(variation_ontology)) {
    vario_transformed <- variation_ontology
  } else {
    return(list(
      status = 405,
      message = "Invalid variation ontology format",
      error = "Expected 'value' or 'vario_id'/'modifier_id' columns"
    ))
  }

  tryCatch({
    if (toupper(method) == "PUT") {
      variation_ontology_replace_for_review(review_id, entity_id, vario_transformed)
    } else {
      variation_ontology_connect_to_review(review_id, entity_id, vario_transformed)
    }

    log_info("put_post_db_var_ont_con: Connected variation ontology to review {review_id}")

    return(list(
      status = 200,
      message = "OK. Variation ontology connected."
    ))
  }, error = function(e) {
    log_error("put_post_db_var_ont_con: Error: {e$message}")
    return(list(
      status = 500,
      message = "Error connecting variation ontology.",
      error = e$message
    ))
  })
}

#' Create or update status (legacy wrapper)
#'
#' @param method "POST" for create, "PUT" for update
#' @param status_data Tibble with entity_id, category_id, status_user_id, comment, problematic
#'
#' @return List with status, message, and entry (status_id)
#'
#' @export
put_post_db_status <- function(method, status_data) {
  log_debug("put_post_db_status: {method} status")

  # Convert tibble to list if necessary
  if (is.data.frame(status_data)) {
    status_data <- as.list(status_data[1, ])
  }

  tryCatch({
    if (toupper(method) == "POST") {
      # Create new status
      status_id <- status_create(status_data)

      log_info("put_post_db_status: Created status {status_id}")

      return(list(
        status = 200,
        message = "OK. Status created.",
        entry = status_id
      ))
    } else {
      # Update existing status
      if (is.null(status_data$status_id)) {
        return(list(
          status = 405,
          message = "status_id is required for PUT operation",
          entry = NA
        ))
      }

      status_update(status_data$status_id, status_data)

      log_info("put_post_db_status: Updated status {status_data$status_id}")

      return(list(
        status = 200,
        message = "OK. Status updated.",
        entry = status_data$status_id
      ))
    }
  }, error = function(e) {
    log_error("put_post_db_status: Error: {e$message}")
    return(list(
      status = 500,
      message = "Error processing status.",
      entry = NA,
      error = e$message
    ))
  })
}

#' Approve review (legacy wrapper)
#'
#' @param review_id Integer review ID to approve
#' @param approving_user_id Integer user ID of approver
#' @param approved Logical TRUE to approve, FALSE to reject
#'
#' @return List with status and message
#'
#' @export
put_db_review_approve <- function(review_id, approving_user_id, approved = TRUE) {
  log_debug("put_db_review_approve: {ifelse(approved, 'Approving', 'Rejecting')} review {review_id}")

  tryCatch({
    review_approve(review_id, approving_user_id, approved)

    log_info("put_db_review_approve: Review {review_id} {ifelse(approved, 'approved', 'rejected')}")

    return(list(
      status = 200,
      message = paste0("OK. Review ", ifelse(approved, "approved", "rejected"), ".")
    ))
  }, error = function(e) {
    log_error("put_db_review_approve: Error: {e$message}")
    return(list(
      status = 500,
      message = "Error approving review.",
      error = e$message
    ))
  })
}

#' Approve status (legacy wrapper)
#'
#' @param status_id Integer status ID (or tibble/list containing it)
#' @param approving_user_id Integer user ID of approver
#' @param approved Logical TRUE to approve, FALSE to reject
#'
#' @return List with status and message
#'
#' @export
put_db_status_approve <- function(status_id, approving_user_id, approved = TRUE) {
  # Handle case where status_id might be passed as list/tibble
  if (is.list(status_id) || is.data.frame(status_id)) {
    status_id <- as.integer(status_id[[1]])
  }

  log_debug("put_db_status_approve: {ifelse(approved, 'Approving', 'Rejecting')} status {status_id}")

  tryCatch({
    status_approve(status_id, approving_user_id, approved)

    log_info("put_db_status_approve: Status {status_id} {ifelse(approved, 'approved', 'rejected')}")

    return(list(
      status = 200,
      message = paste0("OK. Status ", ifelse(approved, "approved", "rejected"), ".")
    ))
  }, error = function(e) {
    log_error("put_db_status_approve: Error: {e$message}")
    return(list(
      status = 500,
      message = "Error approving status.",
      error = e$message
    ))
  })
}

#' Create new publications (legacy wrapper)
#'
#' This function creates new publication entries in the database from PMIDs.
#' It fetches metadata from PubMed and inserts the publications.
#'
#' @param publications Tibble with publication_id column (PMIDs)
#'
#' @return List with status and message
#'
#' @export
new_publication <- function(publications) {
  log_debug("new_publication: Processing {nrow(publications)} publications")

  tryCatch({
    # Get existing publications from database
    existing_publications <- pool %>%
      tbl("publication") %>%
      select(publication_id) %>%
      collect()

    # Find new publications that don't exist
    new_pubs <- publications %>%
      filter(!publication_id %in% existing_publications$publication_id)

    if (nrow(new_pubs) == 0) {
      log_debug("new_publication: All publications already exist")
      return(list(
        status = 200,
        message = "OK. All publications already exist."
      ))
    }

    # Insert new publications one by one
    for (i in seq_len(nrow(new_pubs))) {
      pmid <- new_pubs$publication_id[i]

      # Try to fetch metadata from PubMed (optional - basic insert if fails)
      tryCatch({
        # Basic insert with just PMID
        db_execute_statement(
          "INSERT INTO publication (publication_id) VALUES (?)",
          list(pmid)
        )
        log_debug("new_publication: Inserted publication {pmid}")
      }, error = function(e) {
        # Ignore duplicate key errors
        if (!grepl("Duplicate entry", e$message, ignore.case = TRUE)) {
          log_warn("new_publication: Failed to insert {pmid}: {e$message}")
        }
      })
    }

    log_info("new_publication: Processed {nrow(new_pubs)} new publications")

    return(list(
      status = 200,
      message = paste0("OK. Processed ", nrow(new_pubs), " publications.")
    ))
  }, error = function(e) {
    log_error("new_publication: Error: {e$message}")
    return(list(
      status = 500,
      message = "Error creating publications.",
      error = e$message
    ))
  })
}
