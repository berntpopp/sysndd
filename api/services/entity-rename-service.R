# Entity Rename Service Layer for SysNDD API
# Atomic disease-ontology rename orchestration, split out of
# entity-service.R (#346) to keep files under the 600-line ceiling.
# Uses the *-repository.R DB layers plus svc_entity_check_duplicate
# from entity-service.R for shared duplicate detection.

#' Rename a disease ontology atomically
#'
#' Replaces an entity's disease_ontology_id_version by creating a new entity,
#' deactivating the old one with replaced_by set, and copying the source
#' entity's review/status/joins forward — all in a single transaction.
#' Approval state (review_approved, status is_active/approved, approving_user_id)
#' is propagated from the source so the new entity remains visible to curators.
#'
#' Fixes #318. Replaces the previous non-atomic, default-resetting flow that
#' lived inline in the /rename endpoint handler.
#'
#' @param rename_data Parsed JSON body, shape
#'   `list(entity = list(entity_id, hgnc_id, hpo_mode_of_inheritance_term,
#'   ndd_phenotype, disease_ontology_id_version))`.
#' @param user_id Integer, the curator performing the rename (entry_user_id of the new entity).
#' @param pool Database connection pool.
#' @return list(status, message, entry = tibble(entity_id, review_id, status_id))
#' @export
svc_entity_rename_full <- function(rename_data, user_id, pool) {
  rename_entity <- rename_data$entity

  if (is.null(rename_entity) || !is.list(rename_entity)) {
    return(list(status = 400, message = "Bad Request. entity is required."))
  }

  if (is.data.frame(rename_entity)) {
    rename_entity <- as.list(rename_entity[1, ])
  }

  is_missing_rename_value <- function(value) {
    if (is.null(value) || length(value) != 1) {
      return(TRUE)
    }
    if (is.na(value)) {
      return(TRUE)
    }
    if (is.character(value) && trimws(value) == "") {
      return(TRUE)
    }
    FALSE
  }

  if (is_missing_rename_value(rename_entity$entity_id)) {
    return(list(status = 400, message = "Bad Request. entity_id is required."))
  }

  old_entity_id <- suppressWarnings(as.integer(rename_entity$entity_id))
  if (length(old_entity_id) != 1 || is.na(old_entity_id)) {
    return(list(status = 400, message = "Bad Request. entity_id is required."))
  }

  required_rename_fields <- c(
    "hgnc_id",
    "hpo_mode_of_inheritance_term",
    "ndd_phenotype",
    "disease_ontology_id_version"
  )
  missing_rename_fields <- required_rename_fields[vapply(
    required_rename_fields,
    function(field) is_missing_rename_value(rename_entity[[field]]),
    logical(1)
  )]

  if (length(missing_rename_fields) > 0) {
    return(list(
      status = 400,
      message = paste(
        "Bad Request. Missing or empty required rename field(s):",
        paste(missing_rename_fields, collapse = ", ")
      )
    ))
  }

  logger::log_info(
    "Disease rename started",
    entity_id = old_entity_id,
    user_id = user_id
  )

  # --- Phase 1: validation outside the transaction ---

  ndd_entity_original <- pool %>%
    dplyr::tbl("ndd_entity") %>%
    dplyr::filter(entity_id == !!old_entity_id, is_active == 1) %>%
    dplyr::collect()

  if (nrow(ndd_entity_original) == 0) {
    return(list(status = 404, message = "Not Found. Source entity does not exist."))
  }

  if (rename_entity$disease_ontology_id_version ==
        ndd_entity_original$disease_ontology_id_version[1]) {
    return(list(status = 400,
                message = "Bad Request. New disease_ontology_id_version is identical to the current one."))
  }

  if (rename_entity$hgnc_id != ndd_entity_original$hgnc_id[1] ||
      rename_entity$hpo_mode_of_inheritance_term != ndd_entity_original$hpo_mode_of_inheritance_term[1] ||
      rename_entity$ndd_phenotype != ndd_entity_original$ndd_phenotype[1]) {
    return(list(status = 400,
                message = "Bad Request. Only disease_ontology_id_version may differ in a rename."))
  }

  # Destination quadruple must not already exist
  destination <- list(
    hgnc_id = rename_entity$hgnc_id,
    hpo_mode_of_inheritance_term = rename_entity$hpo_mode_of_inheritance_term,
    disease_ontology_id_version = rename_entity$disease_ontology_id_version,
    ndd_phenotype = rename_entity$ndd_phenotype
  )
  duplicate <- svc_entity_check_duplicate(destination, pool)
  if (!is.null(duplicate)) {
    return(list(status = 409,
                message = "Conflict. Destination quadruple already exists.",
                entry = duplicate))
  }

  # Load source review (primary, active) and status (active) — to be copied forward
  review_original <- pool %>%
    dplyr::tbl("ndd_entity_review") %>%
    dplyr::filter(entity_id == !!old_entity_id, is_primary == 1) %>%
    dplyr::collect()

  status_original <- pool %>%
    dplyr::tbl("ndd_entity_status") %>%
    dplyr::filter(entity_id == !!old_entity_id, is_active == 1) %>%
    dplyr::collect()

  if (nrow(status_original) == 0) {
    return(list(
      status = 409,
      message = "Conflict. Active source status could not be loaded for rename."
    ))
  }

  publications_original <- if (nrow(review_original) > 0) {
    pool %>%
      dplyr::tbl("ndd_review_publication_join") %>%
      dplyr::filter(review_id == !!review_original$review_id[1]) %>%
      dplyr::select(publication_id, publication_type) %>%
      dplyr::collect()
  } else {
    tibble::tibble()
  }

  phenotypes_original <- if (nrow(review_original) > 0) {
    pool %>%
      dplyr::tbl("ndd_review_phenotype_connect") %>%
      dplyr::filter(review_id == !!review_original$review_id[1]) %>%
      dplyr::select(phenotype_id, modifier_id) %>%
      dplyr::collect()
  } else {
    tibble::tibble()
  }

  vario_original <- if (nrow(review_original) > 0) {
    pool %>%
      dplyr::tbl("ndd_review_variation_ontology_connect") %>%
      dplyr::filter(review_id == !!review_original$review_id[1]) %>%
      dplyr::select(vario_id, modifier_id) %>%
      dplyr::collect()
  } else {
    tibble::tibble()
  }

  logger::log_warn(
    "Disease rename bypassing approval workflow",
    old_entity_id = old_entity_id,
    old_ontology = ndd_entity_original$disease_ontology_id_version[1],
    new_ontology = rename_entity$disease_ontology_id_version
  )

  # --- Phase 2: all DB writes in one transaction ---

  tryCatch(
    {
      result <- db_with_transaction(function(txn_conn) {
        # 1. Create new entity (carries hgnc_id/MOI/ndd_phenotype from source, new ontology)
        new_entity_id <- entity_create(list(
          hgnc_id                       = rename_entity$hgnc_id,
          hpo_mode_of_inheritance_term  = rename_entity$hpo_mode_of_inheritance_term,
          disease_ontology_id_version   = rename_entity$disease_ontology_id_version,
          ndd_phenotype                 = rename_entity$ndd_phenotype,
          entry_user_id                 = user_id
        ), conn = txn_conn)

        # 2. Deactivate old entity, set replaced_by
        rows_deactivated <- db_execute_statement(
          "UPDATE ndd_entity SET is_active = 0, replaced_by = ? WHERE entity_id = ? AND is_active = 1",
          list(new_entity_id, old_entity_id),
          conn = txn_conn
        )
        if (length(rows_deactivated) != 1 || is.na(rows_deactivated) || rows_deactivated != 1L) {
          rlang::abort(
            message = paste(
              "Source entity was not active during rename deactivation.",
              "Expected 1 row, affected",
              rows_deactivated
            ),
            class = "entity_rename_stale_source_error"
          )
        }

        # 3. Create new review with approval state propagated from source
        review_payload <- list(
          entity_id         = new_entity_id,
          synopsis          = if (nrow(review_original) > 0) review_original$synopsis[1] else NA,
          review_user_id    = user_id,
          is_primary        = if (nrow(review_original) > 0) review_original$is_primary[1] else 1,
          review_approved   = if (nrow(review_original) > 0) review_original$review_approved[1] else 0,
          approving_user_id = if (nrow(review_original) > 0) review_original$approving_user_id[1] else NA,
          comment           = if (nrow(review_original) > 0) review_original$comment[1] else NA
        )
        new_review_id <- review_create(review_payload, conn = txn_conn)

        # 4. Connect publications / phenotypes / variation ontology to new review
        if (nrow(publications_original) > 0) {
          publication_connect_to_review(new_review_id, new_entity_id,
                                        publications_original, conn = txn_conn)
        }
        if (nrow(phenotypes_original) > 0) {
          phenotype_connect_to_review(new_review_id, new_entity_id,
                                      phenotypes_original, conn = txn_conn)
        }
        if (nrow(vario_original) > 0) {
          variation_ontology_connect_to_review(new_review_id, new_entity_id,
                                               vario_original, conn = txn_conn)
        }

        # 5. Create new status with approval state propagated from source
        status_payload <- tibble::tibble(
          entity_id         = new_entity_id,
          category_id       = status_original$category_id[1],
          status_user_id    = user_id,
          is_active         = status_original$is_active[1],
          status_approved   = status_original$status_approved[1],
          approving_user_id = status_original$approving_user_id[1],
          problematic       = status_original$problematic[1],
          comment           = status_original$comment[1]
        )
        new_status_id <- status_create(status_payload, conn = txn_conn)

        list(entity_id = new_entity_id, review_id = new_review_id, status_id = new_status_id)
      }, pool_obj = pool)

      logger::log_info(
        "Disease rename completed atomically",
        old_entity_id = old_entity_id,
        new_entity_id = result$entity_id
      )

      return(list(
        status = 200,
        message = "OK. Entity renamed.",
        entry = tibble::tibble(
          entity_id = result$entity_id,
          review_id = result$review_id,
          status_id = result$status_id
        )
      ))
    },
    db_transaction_error = function(e) {
      logger::log_error(
        "Rename transaction failed - all changes rolled back",
        old_entity_id = old_entity_id,
        error = e$message
      )
      list(status = 500,
           message = "Internal Server Error. Rename failed. All changes rolled back.",
           error = e$message)
    },
    error = function(e) {
      logger::log_error("Unexpected error during rename",
                        old_entity_id = old_entity_id, error = e$message)
      list(status = 500,
           message = "Internal Server Error. Rename failed.",
           error = e$message)
    }
  )
}
