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
  incoming <- deactivate_data$entity
  # A JSON object here would make as.integer() throw; a non-atomic value just fails the check below.
  incoming_is_active <- if (is.atomic(incoming$is_active)) as.integer(incoming$is_active)
  raw_replaced_by <- incoming$replaced_by
  # JSON null parses to NULL; the DB bind needs NA. Anything else must be an entity id.
  replaced_by_null <- is.null(raw_replaced_by) ||
    (is.atomic(raw_replaced_by) && length(raw_replaced_by) == 1L &&
      (is.na(raw_replaced_by) || toupper(trimws(raw_replaced_by)) == "NULL"))
  incoming_replaced_by <- if (replaced_by_null) {
    NA_integer_
  } else {
    svc_entity_body_entity_id(list(entity = list(entity_id = raw_replaced_by)))
  }

  # isTRUE() is FALSE for the length-0/2+ comparisons that missing fields, arrays
  # or an unknown entity (0 rows) produce; a bare `&&` on those used to 500.
  is_mutation_only <- (replaced_by_null || !is.na(incoming_replaced_by)) &&
    isTRUE(incoming$hgnc_id == ndd_entity_original$hgnc_id) &&
    isTRUE(incoming$hpo_mode_of_inheritance_term == ndd_entity_original$hpo_mode_of_inheritance_term) &&
    isTRUE(incoming$ndd_phenotype == ndd_entity_original$ndd_phenotype) &&
    isTRUE(incoming_is_active != ndd_entity_original$is_active)

  if (is_mutation_only) {
    return(list(
      action = "deactivate",
      entity_id = incoming$entity_id,
      replaced_by = incoming_replaced_by
    ))
  }

  list(
    action = "reject",
    error = "This endpoint only allows deactivating an entity."
  )
}


#' Parse `<key>$entity$entity_id` from an entity write body
#'
#' @param data Parsed `<key>` body (`list(entity = list(entity_id, ...))`).
#' @return The id as a positive integer, or `NA_integer_` when missing or invalid.
#' @export
svc_entity_body_entity_id <- function(data) {
  raw_id <- if (is.list(data) && is.list(data$entity)) data$entity$entity_id
  id_num <- if (is.numeric(raw_id) || is.character(raw_id)) suppressWarnings(as.numeric(raw_id)) else NA
  if (length(id_num) != 1 || is.na(id_num) || id_num < 1 || id_num != trunc(id_num) ||
    id_num > .Machine$integer.max) {
    return(NA_integer_)
  }
  as.integer(id_num)
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
  entity_id <- svc_entity_body_entity_id(deactivate_data)
  if (is.na(entity_id)) {
    return(list(http_status = 400, body = list(error = "deactivate_json$entity$entity_id must be a positive integer.")))
  }

  ndd_entity_original <- pool %>%
    tbl("ndd_entity") %>%
    dplyr::filter(entity_id == !!entity_id) %>%
    collect()

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


#' Decide whether a `POST /entity/reactivate` request may proceed (#711)
#'
#' Pure logic. Reactivation is refused when the entity is missing, not
#' inactive, or when an active entity already covers it (see
#' `svc_entity_reactivate_conflicts()`), because two active entries for one
#' association would duplicate it in every public table.
#'
#' @param ndd_entity_original Tibble with 0 or 1 `ndd_entity` row.
#' @param active_conflicts Tibble of active entities (column `entity_id`)
#'   that the reactivated entity would duplicate.
#' @return `list(action = "reactivate", entity_id)` or
#'   `list(action = "reject", http_status, error)`.
#' @export
svc_entity_reactivate_decision <- function(ndd_entity_original, active_conflicts) {
  reject <- function(http_status, error) list(action = "reject", http_status = http_status, error = error)

  if (nrow(ndd_entity_original) != 1) {
    return(reject(404, "Entity not found."))
  }
  # is_active is nullable; only a row that is explicitly 0 can be reactivated.
  if (!isTRUE(as.integer(ndd_entity_original$is_active) == 0L)) {
    return(reject(409, "Entity is already active."))
  }
  if (nrow(active_conflicts) > 0) {
    return(reject(409, paste0(
      "Entity cannot be reactivated: active entity ",
      paste0("sysndd:", active_conflicts$entity_id, collapse = ", "),
      " already covers this gene-disease association (its replacement or the same ",
      "gene, inheritance and disease). ",
      "Deactivate that entity first if this one should become current again."
    )))
  }

  list(action = "reactivate", entity_id = ndd_entity_original$entity_id)
}


#' Active entities that a reactivation would duplicate (#711)
#'
#' Two sources: (1) the end of the `replaced_by` chain, followed through
#' inactive hops because renames and deduplications chain (A -> B -> C);
#' (2) an active entity with the same gene and inheritance for the same disease
#' in any ontology version. The exact quadruple cannot recur: `entity_quadruple`
#' is unique over all rows.
#'
#' @param original Single-row `ndd_entity` tibble of the entity to reactivate.
#' @param pool Database connection pool (or DBI connection).
#' @return Tibble with column `entity_id` (0 rows when nothing conflicts).
#' @export
svc_entity_reactivate_conflicts <- function(original, pool) {
  successors <- integer()
  next_id <- original$replaced_by
  while (length(next_id) == 1 && !is.na(next_id) &&
    !(next_id %in% c(successors, original$entity_id))) {
    successors <- c(successors, as.integer(next_id))
    next_id <- pool %>%
      dplyr::tbl("ndd_entity") %>%
      dplyr::filter(entity_id == !!next_id) %>%
      dplyr::pull(replaced_by)
  }

  disease_id <- pool %>%
    dplyr::tbl("disease_ontology_set") %>%
    dplyr::filter(disease_ontology_id_version == !!original$disease_ontology_id_version) %>%
    dplyr::pull(disease_ontology_id)
  disease_versions <- pool %>%
    dplyr::tbl("disease_ontology_set") %>%
    dplyr::filter(disease_ontology_id %in% !!unique(disease_id[!is.na(disease_id)])) %>%
    dplyr::pull(disease_ontology_id_version)
  disease_versions <- unique(c(disease_versions, original$disease_ontology_id_version))

  pool %>%
    dplyr::tbl("ndd_entity") %>%
    dplyr::filter(
      is_active == 1,
      entity_id != !!original$entity_id,
      entity_id %in% !!successors |
        (hgnc_id == !!original$hgnc_id &
          hpo_mode_of_inheritance_term == !!original$hpo_mode_of_inheritance_term &
          disease_ontology_id_version %in% !!disease_versions)
    ) %>%
    dplyr::select(entity_id) %>%
    dplyr::collect()
}


#' `POST /entity/reactivate` — DB-touching orchestrator (#711)
#'
#' Undoes a deactivation: is_active 0 -> 1 and replaced_by cleared. Reviews
#' and statuses are not touched, so the curation history is kept as is.
#'
#' @param reactivate_data Parsed `reactivate_json` body (`list(entity = list(entity_id))`).
#' @param reactivate_user_id Integer, the authenticated administrator (logged).
#' @param pool Database connection pool.
#' @return `list(http_status, body)` like `svc_entity_deactivate_request()`.
#' @export
svc_entity_reactivate_request <- function(reactivate_data, reactivate_user_id, pool) {
  entity_id <- svc_entity_body_entity_id(reactivate_data)
  if (is.na(entity_id)) {
    return(list(http_status = 400, body = list(error = "reactivate_json$entity$entity_id must be a positive integer.")))
  }

  original <- pool %>%
    dplyr::tbl("ndd_entity") %>%
    dplyr::filter(entity_id == !!entity_id) %>%
    dplyr::collect()

  active_conflicts <- tibble::tibble(entity_id = integer())
  if (nrow(original) == 1) {
    active_conflicts <- svc_entity_reactivate_conflicts(original, pool)
  }

  decision <- svc_entity_reactivate_decision(original, active_conflicts)
  if (identical(decision$action, "reject")) {
    return(list(http_status = decision$http_status, body = list(error = decision$error)))
  }

  rows <- tryCatch(entity_reactivate(decision$entity_id), error = function(e) {
    logger::log_error("Entity reactivation failed: entity_id={entity_id} error={e$message}")
    NA_integer_
  })
  if (is.na(rows)) {
    return(list(http_status = 500, body = list(error = "Internal Server Error. Entity not reactivated.")))
  }
  # 0 rows: a concurrent request reactivated it between the check and the update.
  if (rows != 1L) {
    return(list(http_status = 409, body = list(error = "Entity is already active.")))
  }

  logger::log_info("Entity reactivated: entity_id={entity_id} user_id={reactivate_user_id}")
  if (exists("generate_gene_news_tibble_mem")) memoise::forget(generate_gene_news_tibble_mem)
  if (exists("generate_stat_tibble_mem")) memoise::forget(generate_stat_tibble_mem)

  list(
    http_status = 200,
    body = list(status = 200, message = "OK. Entity reactivated.", entity_id = entity_id)
  )
}
