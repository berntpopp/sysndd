# api/services/job-phenotype-submission-service.R
#
# Body of `POST /api/jobs/phenotype_clustering/submit`, extracted from
# endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5). Public endpoint —
# no role gate. The endpoint shell delegates the entire handler body here;
# `svc_job_submit_phenotype_clustering()` mutates `res` (status + headers)
# exactly as the inline handler used to, and returns the JSON payload.
#
# CRITICAL (mirai): database connections cannot cross process boundaries, so
# every value the anonymous `executor_fn` closure below needs is fetched from
# `pool` and captured in `params` BEFORE `create_job()` is called. Keep that
# closure anonymous/inline (do not extract it to a named helper) — it is what
# `create_job()` serializes into the mirai daemon call.
#
# This is an ENDPOINT service: it is sourced by the shared bootstrap loader
# (api/bootstrap/load_modules.R) like any other services/* file, but it is
# never registered as an async job handler and the worker never calls it
# directly — the worker only ever invokes the `executor_fn` closure that
# `create_job()` hands to `async_job_service_submit()`.

#' Submit a phenotype (MCA/HCPC) clustering job.
#'
#' SECURITY (#3, Codex PR-2): this is the PUBLIC phenotype-clustering submit
#' path. The review set is gated on `review_approved == 1` (not `is_primary`
#' alone) so the clustering input — and the per-cluster phenotype stats it
#' produces — cannot be derived from UNAPPROVED curation. Mirrors the
#' served-snapshot path `generate_phenotype_cluster_input()`. Never relax this
#' filter back to `is_primary` alone.
#'
#' Cache-first: if the memoised `gen_mca_clust_obj_mem()` already has a result
#' for the resolved phenotype-by-entity matrix, the result is persisted as an
#' already-completed durable job via `async_job_service_store_completed()` so
#' the LLM batch generator uses the same job/result hashes as the API-served
#' table. A cache miss falls through the public queue-depth capacity guard
#' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
#' new durable job via `create_job()`.
#'
#' @param req Plumber request (reads `req$user$user_id`).
#' @param res Plumber response, mutated in place (status + headers).
#' @return List payload for the `json` serializer.
#' @export
svc_job_submit_phenotype_clustering <- function(req, res) {
  # Guard FIRST (#535 S6): per-caller submit admission throttle, applied before any
  # DB/cache/duplicate work. The phenotype path otherwise collects five whole tables
  # and builds the wide MCA matrix before admission — an abusive caller must be
  # rejected before provoking that. Layered on the global capacity cap.
  admission <- async_job_submit_admission_guard(req, res)
  if (!isTRUE(admission$admitted)) {
    return(admission$response)
  }

  # Prepare data BEFORE mirai (database connections can't cross process boundary)
  # This replicates the data gathering from phenotype_clustering endpoint

  id_phenotype_ids <- c(
    "HP:0001249", "HP:0001256", "HP:0002187",
    "HP:0002342", "HP:0006889", "HP:0010864"
  )
  categories <- c("Definitive")

  # Gather all data from database
  ndd_entity_view_tbl <- pool %>%
    dplyr::tbl("ndd_entity_view") %>%
    dplyr::collect()
  # SECURITY (#3, Codex PR-2): this is the PUBLIC phenotype-clustering submit
  # path. Gate the review set on review_approved == 1 (not is_primary alone) so
  # the clustering input — and the per-cluster phenotype stats it produces —
  # cannot be derived from UNAPPROVED curation. Mirrors the served-snapshot path
  # generate_phenotype_cluster_input().
  ndd_entity_review_tbl <- pool %>%
    dplyr::tbl("ndd_entity_review") %>%
    dplyr::collect() %>%
    dplyr::filter(is_primary == 1, review_approved == 1) %>%
    dplyr::select(review_id)
  ndd_review_phenotype_connect_tbl <- pool %>%
    dplyr::tbl("ndd_review_phenotype_connect") %>%
    dplyr::collect()
  modifier_list_tbl <- pool %>%
    dplyr::tbl("modifier_list") %>%
    dplyr::collect()
  phenotype_list_tbl <- pool %>%
    dplyr::tbl("phenotype_list") %>%
    dplyr::collect()

  # Create params hash based on entity count (stable identifier)
  params_hash_input <- list(
    entity_count = nrow(ndd_entity_view_tbl),
    operation = "phenotype_clustering"
  )

  # Check for duplicate
  dup_check <- check_duplicate_job("phenotype_clustering", params_hash_input)
  if (dup_check$duplicate) {
    res$status <- 409
    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
    return(list(
      error = "DUPLICATE_JOB",
      message = "Identical job already running",
      existing_job_id = dup_check$existing_job_id,
      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
    ))
  }

  # Build the data frame for clustering (same as regular API endpoint)
  sysndd_db_phenotypes <- ndd_entity_view_tbl %>%
    dplyr::left_join(ndd_review_phenotype_connect_tbl, by = "entity_id") %>%
    dplyr::left_join(modifier_list_tbl, by = "modifier_id") %>%
    dplyr::left_join(phenotype_list_tbl, by = "phenotype_id") %>%
    dplyr::mutate(ndd_phenotype = dplyr::case_when(
      ndd_phenotype == 1 ~ "Yes",
      ndd_phenotype == 0 ~ "No"
    )) %>%
    dplyr::filter(ndd_phenotype == "Yes") %>%
    dplyr::filter(category %in% categories) %>%
    dplyr::filter(modifier_name == "present") %>%
    dplyr::filter(review_id %in% ndd_entity_review_tbl$review_id) %>%
    dplyr::select(entity_id, hpo_mode_of_inheritance_term_name, phenotype_id, HPO_term, hgnc_id) %>%
    dplyr::group_by(entity_id) %>%
    dplyr::mutate(
      phenotype_non_id_count = sum(!(phenotype_id %in% id_phenotype_ids)),
      phenotype_id_count = sum(phenotype_id %in% id_phenotype_ids)
    ) %>%
    dplyr::ungroup() %>%
    unique()

  sysndd_db_phenotypes_wider <- sysndd_db_phenotypes %>%
    dplyr::mutate(present = "yes") %>%
    dplyr::select(-phenotype_id) %>%
    tidyr::pivot_wider(names_from = HPO_term, values_from = present) %>%
    dplyr::group_by(hgnc_id) %>%
    dplyr::mutate(gene_entity_count = dplyr::n()) %>%
    dplyr::ungroup() %>%
    dplyr::relocate(gene_entity_count, .after = phenotype_id_count) %>%
    dplyr::select(-hgnc_id)

  sysndd_db_phenotypes_wider_df <- sysndd_db_phenotypes_wider %>%
    dplyr::select(-entity_id) %>%
    as.data.frame()
  row.names(sysndd_db_phenotypes_wider_df) <- sysndd_db_phenotypes_wider$entity_id

  # Cache-first: if the memoized function already has a cached result,
  # return it immediately without spawning an async daemon job.
  # This ensures the LLM batch uses the same hashes as the API endpoint.
  cache_hit <- tryCatch(
    memoise::has_cache(gen_mca_clust_obj_mem)(sysndd_db_phenotypes_wider_df),
    error = function(e) FALSE
  )

  if (cache_hit) {
    cached_clusters <- gen_mca_clust_obj_mem(sysndd_db_phenotypes_wider_df)

    # Add back gene identifiers
    ndd_entity_view_tbl_sub <- ndd_entity_view_tbl %>%
      dplyr::select(entity_id, hgnc_id, symbol)

    cached_clusters_with_ids <- cached_clusters %>%
      tidyr::unnest(identifiers) %>%
      dplyr::mutate(entity_id = as.integer(entity_id)) %>%
      dplyr::left_join(ndd_entity_view_tbl_sub, by = "entity_id") %>%
      tidyr::nest(identifiers = c(entity_id, hgnc_id, symbol))

    completed_job <- async_job_service_store_completed(
      job_type = "phenotype_clustering",
      request_payload = list(
        ndd_entity_view_tbl = ndd_entity_view_tbl,
        ndd_entity_review_tbl = ndd_entity_review_tbl,
        ndd_review_phenotype_connect_tbl = ndd_review_phenotype_connect_tbl,
        modifier_list_tbl = modifier_list_tbl,
        phenotype_list_tbl = phenotype_list_tbl,
        id_phenotype_ids = id_phenotype_ids,
        categories = categories
      ),
      result = cached_clusters_with_ids,
      submitted_by = req$user$user_id %||% NULL,
      queue_name = "analysis",
      priority = 50L
    )
    job_id <- completed_job$job_id[[1]]

    res$status <- 202
    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
    res$setHeader("Retry-After", "0")

    return(list(
      job_id = job_id,
      status = "accepted",
      estimated_seconds = 0,
      status_url = paste0("/api/jobs/", job_id, "/status"),
      meta = list(llm_generation = "snapshot_refresh_owned")
    ))
  }

  # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
  # "default" matches the queue create_job() enqueues on via async_job_service_submit.
  if (async_job_capacity_exceeded(
        tryCatch(
          async_job_active_count("default"),
          error = function(e) {
            log_warn("async_job_active_count failed (capacity check fail-open): {e$message}")
            0L
          }
        )
      )) {
    res$status <- 503
    res$setHeader("Retry-After", "60")
    return(list(
      error = "CAPACITY_EXCEEDED",
      message = "Analysis queue is at capacity. Please retry shortly.",
      retry_after = 60
    ))
  }

  # Cache miss - create async job with pre-built data frame
  result <- create_job(
    operation = "phenotype_clustering",
    params = list(
      ndd_entity_view_tbl = ndd_entity_view_tbl,
      ndd_entity_review_tbl = ndd_entity_review_tbl,
      ndd_review_phenotype_connect_tbl = ndd_review_phenotype_connect_tbl,
      modifier_list_tbl = modifier_list_tbl,
      phenotype_list_tbl = phenotype_list_tbl,
      id_phenotype_ids = id_phenotype_ids,
      categories = categories
    ),
    executor_fn = function(params) {
      # This runs in mirai daemon
      # Replicate phenotype_clustering logic
      sysndd_db_phenotypes <- params$ndd_entity_view_tbl %>%
        dplyr::left_join(params$ndd_review_phenotype_connect_tbl, by = "entity_id") %>%
        dplyr::left_join(params$modifier_list_tbl, by = "modifier_id") %>%
        dplyr::left_join(params$phenotype_list_tbl, by = "phenotype_id") %>%
        dplyr::mutate(ndd_phenotype = dplyr::case_when(
          ndd_phenotype == 1 ~ "Yes",
          ndd_phenotype == 0 ~ "No"
        )) %>%
        dplyr::filter(ndd_phenotype == "Yes") %>%
        dplyr::filter(category %in% params$categories) %>%
        dplyr::filter(modifier_name == "present") %>%
        dplyr::filter(review_id %in% params$ndd_entity_review_tbl$review_id) %>%
        dplyr::select(
          entity_id, hpo_mode_of_inheritance_term_name, phenotype_id,
          HPO_term, hgnc_id
        ) %>%
        dplyr::group_by(entity_id) %>%
        dplyr::mutate(
          phenotype_non_id_count = sum(!(phenotype_id %in% params$id_phenotype_ids)),
          phenotype_id_count = sum(phenotype_id %in% params$id_phenotype_ids)
        ) %>%
        dplyr::ungroup() %>%
        unique()

      sysndd_db_phenotypes_wider <- sysndd_db_phenotypes %>%
        dplyr::mutate(present = "yes") %>%
        dplyr::select(-phenotype_id) %>%
        tidyr::pivot_wider(names_from = HPO_term, values_from = present) %>%
        dplyr::group_by(hgnc_id) %>%
        dplyr::mutate(gene_entity_count = dplyr::n()) %>%
        dplyr::ungroup() %>%
        dplyr::relocate(gene_entity_count, .after = phenotype_id_count) %>%
        dplyr::select(-hgnc_id)

      sysndd_db_phenotypes_wider_df <- sysndd_db_phenotypes_wider %>%
        dplyr::select(-entity_id) %>%
        as.data.frame()

      row.names(sysndd_db_phenotypes_wider_df) <- sysndd_db_phenotypes_wider$entity_id

      # Use non-memoized version (memoized not available in daemon)
      phenotype_clusters <- gen_mca_clust_obj(sysndd_db_phenotypes_wider_df)

      # Add back identifiers
      ndd_entity_view_tbl_sub <- params$ndd_entity_view_tbl %>%
        dplyr::select(entity_id, hgnc_id, symbol)

      phenotype_clusters %>%
        tidyr::unnest(identifiers) %>%
        dplyr::mutate(entity_id = as.integer(entity_id)) %>%
        dplyr::left_join(ndd_entity_view_tbl_sub, by = "entity_id") %>%
        tidyr::nest(identifiers = c(entity_id, hgnc_id, symbol))
    }
  )

  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", as.character(result$retry_after))
    return(result)
  }

  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "5")

  list(
    job_id = result$job_id,
    status = result$status,
    estimated_seconds = 60,
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}
