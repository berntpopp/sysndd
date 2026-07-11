# Entity Submission Endpoint Service for SysNDD API
#
# Create/deactivate request orchestration extracted from
# endpoints/entity_endpoints.R (#346, Wave 3).
#
# `POST /entity/create`'s publication-preparation-before-transaction logic
# (the part that inserts publications BEFORE the atomic entity transaction
# and must fail the whole request with no writes if any publication is
# unresolvable) stays INLINE in entity_endpoints.R rather than moving here.
# That is deliberate, not an oversight: test-integration-entity-rename.R
# hand-extracts the raw `@post /create` handler AST from entity_endpoints.R
# and `eval()`s it in a minimal environment that only binds `require_role`,
# `pool`, `new_publication`, and `genereviews_from_pmid` — it never sources
# this file — so any new globally-named helper reached on that code path
# would be unresolved in that test. Everything else (entity/review/status
# payload prep, phenotype/variation-ontology normalization, the atomic
# svc_entity_create_full() call, and 201/cache-invalidation response
# mapping) is reached exclusively on the path AFTER the publication check
# that test never exercises, so it is safe to extract into
# `svc_entity_create_finalize()` below.
#
# `POST /entity/deactivate` has no such extraction test, so its full
# orchestration moves here, split into a pure decision function
# (`svc_entity_deactivate_decision()`, unit-testable without a pool) and a
# thin DB-touching wrapper (`svc_entity_deactivate_request()`).

#' Finalize entity creation: prepare entity/review/status, normalize
#' phenotypes/variation, create atomically, map the response
#'
#' Called from the `POST /entity/create` endpoint AFTER `create_data` has
#' been parsed and publications have been validated + inserted (publication
#' failures return early from the endpoint before this is ever reached, so a
#' mocked/unresolved `svc_entity_create_full` never breaks that path).
#'
#' @param create_data Parsed `create_json` request body
#'   (`list(entity=, review=, status=)`).
#' @param publications Tibble of publication_id/publication_type (or NULL).
#' @param direct_approval Logical; when TRUE the review + status are approved
#'   in the same transaction and `approving_user_id` is server-attributed to
#'   `user_id` (never the client).
#' @param user_id Integer, the authenticated curator's user id.
#' @param pool Database connection pool.
#' @return `list(status, message, entry)` (or `entry` omitted on failure),
#'   identical in shape to `svc_entity_create_full()`'s return value.
#' @export
svc_entity_create_finalize <- function(create_data, publications, direct_approval, user_id, pool) {
  # Prepare entity data
  entity_data <- create_data$entity
  entity_data$entry_user_id <- user_id

  # Prepare review data
  review_data <- list(
    synopsis = if (length(create_data$review$synopsis) > 0) {
      create_data$review$synopsis[[1]]
    } else {
      NA
    },
    review_user_id = user_id,
    comment = create_data$review$comment
  )

  # Prepare status data
  status_data <- list(
    category_id = create_data$status$category_id,
    status_user_id = user_id,
    problematic = if (!is.null(create_data$status$problematic)) {
      create_data$status$problematic
    } else {
      0
    }
  )

  # Prepare phenotypes
  phenotypes <- NULL
  if (length(compact(create_data$review$phenotypes)) > 0) {
    phenotypes_raw <- tibble::as_tibble(create_data$review$phenotypes)
    if ("value" %in% colnames(phenotypes_raw)) {
      phenotypes <- phenotypes_raw %>%
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
        dplyr::select(phenotype_id, modifier_id)
    } else if (all(c("phenotype_id", "modifier_id") %in% colnames(phenotypes_raw))) {
      phenotypes <- phenotypes_raw
    }
  }

  # Prepare variation ontology
  variation_ontology <- NULL
  if (length(compact(create_data$review$variation_ontology)) > 0) {
    vario_raw <- tibble::as_tibble(create_data$review$variation_ontology)
    if ("value" %in% colnames(vario_raw)) {
      variation_ontology <- vario_raw %>%
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
        dplyr::select(vario_id, modifier_id)
    } else if (all(c("vario_id", "modifier_id") %in% colnames(vario_raw))) {
      variation_ontology <- vario_raw
    }
  }

  # --- Transactional creation (all-or-nothing via service layer) ---
  result <- svc_entity_create_full(
    entity_data = entity_data,
    review_data = review_data,
    status_data = status_data,
    publications = publications,
    phenotypes = phenotypes,
    variation_ontology = variation_ontology,
    direct_approval = direct_approval,
    approving_user_id = if (direct_approval) user_id else NULL,
    pool = pool
  )

  # Invalidate cached statistics after successful entity creation
  if (result$status == 200) {
    if (exists("generate_gene_news_tibble_mem")) memoise::forget(generate_gene_news_tibble_mem)
    if (exists("generate_stat_tibble_mem")) memoise::forget(generate_stat_tibble_mem)
  }

  result
}


#' Decide whether a `POST /entity/deactivate` request is a valid,
#' mutation-only deactivation
#'
#' Pure logic: the endpoint only allows flipping `is_active`/`replaced_by`;
#' any other field difference (or no `is_active` change at all) is rejected.
#' Unit-testable without a pool by passing in the already-fetched
#' `ndd_entity_original` row.
#'
#' @param deactivate_data Parsed `deactivate_json` request body
#'   (`list(entity = list(entity_id, hgnc_id, hpo_mode_of_inheritance_term,
#'   ndd_phenotype, is_active, replaced_by))`).
#' @param ndd_entity_original Single-row tibble, the current `ndd_entity` row
#'   for `deactivate_data$entity$entity_id`.
#' @return On success: `list(action = "deactivate", entity_id, replaced_by)`.
#'   On rejection: `list(action = "reject", error = <message>)`.
#' @export
svc_entity_deactivate_decision <- function(deactivate_data, ndd_entity_original) {
  incoming_is_active <- as.integer(deactivate_data$entity$is_active)
  incoming_replaced_by <- deactivate_data$entity$replaced_by
  if (is.character(incoming_replaced_by) && toupper(trimws(incoming_replaced_by)) == "NULL") {
    incoming_replaced_by <- NA_integer_
  }

  ndd_entity_replaced <- ndd_entity_original %>%
    mutate(is_active = incoming_is_active) %>%
    mutate(replaced_by = incoming_replaced_by)

  is_mutation_only <-
    deactivate_data$entity$hgnc_id == ndd_entity_replaced$hgnc_id &&
    deactivate_data$entity$hpo_mode_of_inheritance_term ==
      ndd_entity_replaced$hpo_mode_of_inheritance_term &&
    deactivate_data$entity$ndd_phenotype ==
      ndd_entity_replaced$ndd_phenotype &&
    deactivate_data$entity$is_active != ndd_entity_original$is_active

  if (isTRUE(is_mutation_only)) {
    return(list(
      action = "deactivate",
      entity_id = deactivate_data$entity$entity_id,
      replaced_by = ndd_entity_replaced$replaced_by
    ))
  }

  list(
    action = "reject",
    error = "This endpoint only allows deactivating an entity."
  )
}


#' `POST /entity/deactivate` — DB-touching orchestrator
#'
#' Fetches the current entity row, delegates the mutation-only decision to
#' `svc_entity_deactivate_decision()`, and on approval calls
#' `put_db_entity_deactivation()` + invalidates cached statistics.
#'
#' @param deactivate_data Parsed `deactivate_json` request body.
#' @param deactivate_user_id Integer, the authenticated curator's user id
#'   (kept for parity with the pre-refactor handler; not currently used by
#'   `put_db_entity_deactivation()`).
#' @param pool Database connection pool.
#' @return `list(http_status, body)` — `http_status` is what the endpoint
#'   should set `res$status` to, `body` is the exact response payload
#'   (deliberately different shapes: success returns `status`/`message`,
#'   rejection returns only `error`, matching the pre-refactor handler).
#' @export
svc_entity_deactivate_request <- function(deactivate_data, deactivate_user_id, pool) {
  ndd_entity_original <- pool %>%
    tbl("ndd_entity") %>%
    collect() %>%
    filter(entity_id == deactivate_data$entity$entity_id)

  decision <- svc_entity_deactivate_decision(deactivate_data, ndd_entity_original)

  if (identical(decision$action, "reject")) {
    return(list(
      http_status = 400,
      body = list(error = decision$error)
    ))
  }

  response_new_entity <- put_db_entity_deactivation(
    decision$entity_id,
    decision$replaced_by
  )

  # Invalidate cached statistics after successful entity deactivation
  if (response_new_entity$status == 200) {
    if (exists("generate_gene_news_tibble_mem")) memoise::forget(generate_gene_news_tibble_mem)
    if (exists("generate_stat_tibble_mem")) memoise::forget(generate_stat_tibble_mem)
  }

  list(
    http_status = response_new_entity$status,
    body = list(status = response_new_entity$status, message = response_new_entity$message)
  )
}
