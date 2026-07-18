# api/functions/async-job-handlers.R
#
# Durable async job handler shell (#346 Wave 4 split): common
# payload/progress/clustering helpers, the legacy-executor passthrough
# factory, the `async_job_handler_registry` list, and the
# `async_job_get_handler()` lookup.
#
# Family-specific handler definitions live in sibling files sourced BEFORE
# this one at every worker entrypoint, because the registry list below
# references handler functions by bare symbol and R evaluates a list()
# literal's elements eagerly at construction time:
#   - functions/async-job-network-layout-handlers.R (network_layout_prewarm)
#   - functions/async-job-analysis-snapshot-handlers.R (analysis_snapshot_refresh)
#   - functions/async-job-omim-apply.R (OMIM DB-write / additive-terms helpers)
#   - functions/async-job-force-apply-payload.R (force-apply payload-shape helpers)
#   - functions/async-job-provider-handlers.R (HGNC, PubTator, NDDScore,
#     disease-ontology mapping, OMIM update, force-apply-ontology)
#   - functions/async-job-maintenance-handlers.R (backup create/restore,
#     publication refresh/backfill)
# Restart the worker container after changing any of these (worker-executed
# code is sourced once at startup).

.async_job_after_success_noop <- function(result, job, payload, state, worker_config) {
  invisible(result)
}
.async_job_or <- function(value, fallback) {
  if (is.null(value) || length(value) == 0) {
    return(fallback)
  }

  value
}
.async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
  if (!exists("create_async_job_progress_reporter", mode = "function")) {
    stop("create_async_job_progress_reporter() is required for durable async job handlers", call. = FALSE)
  }

  create_async_job_progress_reporter(job_id, throttle_seconds = throttle_seconds)
}
.async_job_payload_field <- function(payload, field, required = TRUE, default = NULL) {
  value <- payload[[field]]

  if (is.null(value)) {
    if (isTRUE(required)) {
      stop(sprintf("Async job payload is missing required field '%s'", field), call. = FALSE)
    }

    return(default)
  }

  value
}
.async_job_payload_scalar <- function(payload, field, required = TRUE, default = NULL) {
  value <- .async_job_payload_field(payload, field, required = required, default = default)

  if (is.null(value)) {
    return(value)
  }

  if (is.list(value)) {
    value <- value[[1]]
  }

  value[[1]]
}

.async_job_add_job_id <- function(payload, job) {
  payload$.__job_id__ <- job$job_id[[1]]
  payload
}

.async_job_functional_categories <- function(clusters, category_links) {
  categories <- clusters |>
    dplyr::select(term_enrichment) |>
    tidyr::unnest(cols = c(term_enrichment)) |>
    dplyr::select(category) |>
    unique() |>
    dplyr::arrange(category) |>
    dplyr::mutate(
      text = dplyr::case_when(
        nchar(category) <= 5 ~ category,
        nchar(category) > 5 ~ stringr::str_to_sentence(category)
      )
    ) |>
    dplyr::select(value = category, text)

  if (!is.null(category_links)) {
    categories <- dplyr::left_join(categories, category_links, by = c("value"))
  }

  categories
}

.async_job_run_clustering <- function(job, payload, state, worker_config) {
  genes <- .async_job_payload_field(payload, "genes")
  algorithm <- .async_job_payload_scalar(payload, "algorithm")
  string_id_table <- .async_job_payload_field(payload, "string_id_table", required = FALSE)
  category_links <- .async_job_payload_field(payload, "category_links", required = FALSE)
  # #574 D3: the cheap-path selector/fingerprint provenance the submit
  # service (job-functional-submission-service.R) recorded in the payload.
  # Absent on legacy/explicit-genes payloads pre-dating #574 (required =
  # FALSE) so a worker-run job for those still completes normally.
  provenance <- .async_job_payload_field(payload, "provenance", required = FALSE)
  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)

  progress("cluster", "Running functional clustering...", current = 0, total = 1)

  clusters <- gen_string_clust_obj(
    genes,
    algorithm = algorithm,
    string_id_table = string_id_table
  )

  progress("complete", "Functional clustering complete", current = 1, total = 1)

  # Mirror the cache-hit result meta shape (job-functional-submission-service.R):
  # base fields, then the request's cheap-path `provenance` (selector/
  # resolved_gene_count/gene_list_sha256/intended_fingerprint/
  # source_data_version) when present, then the `effective_fingerprint` --
  # only knowable now that `clusters` has actually been computed -- so a
  # silent exp+db -> combined-score STRING fallback on a worker-run job is
  # visible in the stored result too, not just a cache hit's.
  meta <- c(
    list(
      algorithm = algorithm,
      gene_count = length(genes),
      cluster_count = nrow(clusters)
    ),
    if (!is.null(provenance)) provenance else list(),
    list(effective_fingerprint = list(weight_channel = attr(clusters, "weight_channel")))
  )

  list(
    clusters = clusters,
    categories = .async_job_functional_categories(clusters, category_links),
    meta = meta
  )
}

.async_job_chain_llm <- function(result, job, cluster_type) {
  if (!exists("trigger_llm_batch_generation", mode = "function")) {
    return(invisible(result))
  }

  llm_clusters <- result

  if (is.list(result) && "clusters" %in% names(result) && !is.null(result[["clusters"]])) {
    llm_clusters <- result[["clusters"]]
  }

  trigger_llm_batch_generation(
    clusters = llm_clusters,
    cluster_type = cluster_type,
    parent_job_id = job$job_id[[1]]
  )

  invisible(result)
}

.async_job_phenotype_matrix <- function(payload) {
  sysndd_db_phenotypes <- payload$ndd_entity_view_tbl |>
    dplyr::left_join(payload$ndd_review_phenotype_connect_tbl, by = "entity_id") |>
    dplyr::left_join(payload$modifier_list_tbl, by = "modifier_id") |>
    dplyr::left_join(payload$phenotype_list_tbl, by = "phenotype_id") |>
    dplyr::mutate(ndd_phenotype = dplyr::case_when(
      ndd_phenotype == 1 ~ "Yes",
      ndd_phenotype == 0 ~ "No",
      TRUE ~ ndd_phenotype
    )) |>
    dplyr::filter(ndd_phenotype == "Yes") |>
    dplyr::filter(category %in% payload$categories) |>
    dplyr::filter(modifier_name == "present") |>
    dplyr::filter(review_id %in% payload$ndd_entity_review_tbl$review_id) |>
    dplyr::select(
      entity_id, hpo_mode_of_inheritance_term_name, phenotype_id,
      HPO_term, hgnc_id
    ) |>
    dplyr::group_by(entity_id) |>
    dplyr::mutate(
      phenotype_non_id_count = sum(!(phenotype_id %in% payload$id_phenotype_ids)),
      phenotype_id_count = sum(phenotype_id %in% payload$id_phenotype_ids)
    ) |>
    dplyr::ungroup() |>
    unique()

  sysndd_db_phenotypes_wider <- sysndd_db_phenotypes |>
    dplyr::mutate(present = "yes") |>
    dplyr::select(-phenotype_id) |>
    tidyr::pivot_wider(names_from = HPO_term, values_from = present) |>
    dplyr::group_by(hgnc_id) |>
    dplyr::mutate(gene_entity_count = dplyr::n()) |>
    dplyr::ungroup() |>
    dplyr::relocate(gene_entity_count, .after = phenotype_id_count) |>
    dplyr::select(-hgnc_id)

  phenotype_df <- sysndd_db_phenotypes_wider |>
    dplyr::select(-entity_id) |>
    as.data.frame()
  row.names(phenotype_df) <- sysndd_db_phenotypes_wider$entity_id

  # #508 MCA feature hygiene via the shared helper (same as
  # generate_phenotype_cluster_input) so the interactive/durable clustering job
  # produces the cleaned partition and can't diverge from the public snapshot.
  phenotype_df <- phenotype_mca_prep_matrix(
    phenotype_df,
    hpo_lookup = dplyr::select(payload$phenotype_list_tbl, HPO_term, phenotype_id)
  )

  phenotype_df
}

.async_job_run_phenotype_clustering <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)

  progress("prepare_matrix", "Preparing phenotype matrix...", current = 0, total = 2)
  phenotype_matrix <- .async_job_phenotype_matrix(payload)
  progress("cluster", "Running phenotype clustering...", current = 1, total = 2)
  phenotype_clusters <- gen_mca_clust_obj(phenotype_matrix)
  progress("complete", "Phenotype clustering complete", current = 2, total = 2)

  identifiers <- payload$ndd_entity_view_tbl |>
    dplyr::select(entity_id, hgnc_id, symbol)

  phenotype_clusters |>
    tidyr::unnest(identifiers) |>
    dplyr::mutate(entity_id = as.integer(entity_id)) |>
    dplyr::left_join(identifiers, by = "entity_id") |>
    tidyr::nest(identifiers = c(entity_id, hgnc_id, symbol))
}

.async_job_run_ontology_update <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]])

  progress("init", "Preparing ontology update", current = 0, total = 4)
  disease_ontology_set <- process_combine_ontology(
    hgnc_list = payload$hgnc_list,
    mode_of_inheritance_list = payload$mode_of_inheritance_list,
    max_file_age = 0,
    output_path = "data/",
    progress_callback = progress
  )
  progress("complete", "Ontology update complete", current = 4, total = 4)

  list(
    status = "completed",
    rows_processed = nrow(disease_ontology_set),
    sources = c("MONDO", "OMIM"),
    output_file = paste0("data/disease_ontology_set.", format(Sys.Date(), "%Y-%m-%d"), ".csv")
  )
}

.async_job_run_passthrough <- function(fn_name) {
  force(fn_name)

  function(job, payload, state, worker_config) {
    fn <- base::get(fn_name, mode = "function")
    fn(.async_job_add_job_id(payload, job))
  }
}

async_job_handler_registry <- list(
  clustering = list(
    cancel_mode = "best_effort",
    run = .async_job_run_clustering,
    after_success = function(result, job, payload, state, worker_config) {
      .async_job_chain_llm(result, job, cluster_type = "functional")
    }
  ),
  phenotype_clustering = list(
    cancel_mode = "best_effort",
    run = .async_job_run_phenotype_clustering,
    after_success = function(result, job, payload, state, worker_config) {
      .async_job_chain_llm(result, job, cluster_type = "phenotype")
    }
  ),
  ontology_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_ontology_update,
    after_success = .async_job_after_success_noop
  ),
  hgnc_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_hgnc_update,
    after_success = .async_job_after_success_noop
  ),
  comparisons_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_passthrough("comparisons_update_async"),
    after_success = .async_job_after_success_noop
  ),
  pubtator_update = list(
    cancel_mode = "best_effort",
    run = .async_job_run_pubtator,
    after_success = .async_job_after_success_noop
  ),
  pubtator_enrichment_refresh = list(
    cancel_mode = "best_effort",
    run = .async_job_run_pubtator_enrichment,
    after_success = .async_job_after_success_noop
  ),
  pubtatornidd_nightly = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_pubtatornidd_nightly,
    after_success = .async_job_after_success_noop
  ),
  disease_ontology_mapping_refresh = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_disease_ontology_mapping_refresh,
    after_success = .async_job_after_success_noop
  ),
  nddscore_import = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_nddscore_import,
    after_success = .async_job_after_success_noop
  ),
  llm_generation = list(
    cancel_mode = "best_effort",
    run = .async_job_run_passthrough("llm_batch_executor"),
    after_success = .async_job_after_success_noop
  ),
  network_layout_prewarm = list(
    cancel_mode = "best_effort",
    run = function(...) .async_job_run_network_layout_prewarm(...),
    after_success = .async_job_after_success_noop
  ),
  analysis_snapshot_refresh = list(
    cancel_mode = "best_effort",
    run = function(...) .async_job_run_analysis_snapshot_refresh(...),
    after_success = .async_job_after_success_noop
  ),
  backup_create = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_backup_create,
    after_success = .async_job_after_success_noop
  ),
  backup_restore = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_backup_restore,
    after_success = .async_job_after_success_noop
  ),
  omim_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_omim_update,
    after_success = .async_job_after_success_noop
  ),
  force_apply_ontology = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_force_apply_ontology,
    after_success = .async_job_after_success_noop
  ),
  publication_refresh = list(
    cancel_mode = "best_effort",
    run = .async_job_run_publication_refresh,
    after_success = .async_job_after_success_noop
  ),
  publication_date_backfill = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_publication_date_backfill,
    after_success = .async_job_after_success_noop
  )
)

#' Resolve a durable async job handler definition
#' @param job_type Character async job type.
#' @param registry Named handler registry.
#'
#' @return Registry entry with run/cancel metadata.
#' @export
async_job_get_handler <- function(job_type, registry = async_job_handler_registry) {
  entry <- registry[[job_type]]

  if (is.null(entry)) {
    stop(sprintf("No durable async job handler registered for '%s'", job_type), call. = FALSE)
  }

  if (!is.function(entry$run)) {
    stop(sprintf("Handler registry entry for '%s' is missing a callable run function", job_type), call. = FALSE)
  }

  if (is.null(entry$after_success)) {
    entry$after_success <- .async_job_after_success_noop
  }

  entry
}
