# api/services/job-functional-submission-service.R
#
# Body of `POST /api/jobs/clustering/submit`, extracted from
# endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5). Public endpoint —
# no role gate. The endpoint shell delegates the entire handler body here;
# `svc_job_submit_functional_clustering()` mutates `res` (status + headers)
# exactly as the inline handler used to, and returns the JSON payload.
#
# The durable handler receives serialized input, not a database connection, so
# all values it needs are fetched from `pool` before `create_job()` is called.
#
# This is an ENDPOINT service: it is sourced by the shared bootstrap loader
# (api/bootstrap/load_modules.R) like any other services/* file. The worker
# executes the registered `clustering` durable handler, never this submitter.

#' Submit a functional (STRING-db) clustering job.
#'
#' Cache-first: if the memoised `gen_string_clust_obj_mem()` already has a
#' result for the resolved gene list + algorithm, the result is persisted as
#' an already-completed durable job via `async_job_service_store_completed()`
#' so the response shape matches a freshly-submitted job (this keeps LLM batch
#' generation on the same job/result hashes as the API-served table). A cache
#' miss falls through the public queue-depth capacity guard
#' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
#' new durable job via `create_job()`.
#'
#' The clustering gene universe (#574) is one of: an explicit `genes` list, a
#' curated-category selection via `category_filter` (resolved through
#' `clustering_resolve_category_universe()`), or -- when neither is supplied
#' -- the existing default all-NDD-genes universe. `genes` and
#' `category_filter` are mutually exclusive (400 if both are present). Every
#' submit records selector + fingerprint provenance in the durable payload
#' and (on a cache hit) the result meta; see `clustering-gene-universe.R`.
#'
#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm`/
#'   `category_filter` and `req$user$user_id`).
#' @param res Plumber response, mutated in place (status + headers).
#' @return List payload for the `json` serializer.
#' @export
svc_job_submit_functional_clustering <- function(req, res) {
  # Guard FIRST (#535 S6): per-caller submit admission throttle, applied before any
  # DB/cache/duplicate work so an abusive caller is rejected before it can do — or
  # provoke — expensive work (a cache hit still writes a completed job row, and the
  # duplicate/data fetch below touch the DB). Layered on the global capacity cap.
  admission <- async_job_submit_admission_guard(req, res)
  if (!isTRUE(admission$admitted)) {
    return(admission$response)
  }

  # Extract request data before durable submission.

  # Connection objects cannot cross process boundaries. `genes` and
  # `category_filter` are mutually exclusive gene-universe selectors (#574):
  # an explicit gene list, a curated-category selection, or (both absent) the
  # existing default all-NDD-genes universe. Presence is decided from the RAW
  # request field, not a length check, so an explicitly-empty category_filter
  # still reaches (and is rejected by) the resolver instead of silently
  # falling through to the all-NDD default.
  genes_in <- req$argsBody$genes
  category_supplied <- !is.null(req$argsBody$category_filter)
  has_genes <- !is.null(genes_in) && length(genes_in) > 0

  if (has_genes && category_supplied) {
    stop_for_bad_request("Provide either genes or category_filter, not both")
  }

  # Extract algorithm parameter (default: leiden)
  # Ensure we get a scalar value (JSON may pass arrays)
  algorithm <- "leiden"
  if (!is.null(req$argsBody$algorithm)) {
    algo_input <- req$argsBody$algorithm
    # Handle array input - always take first element if vector
    if (is.list(algo_input) || length(algo_input) >= 1) {
      algo_input <- algo_input[[1]]
    }
    algorithm <- tolower(as.character(algo_input))
    if (!algorithm %in% c("leiden", "walktrap")) {
      algorithm <- "leiden"
    }
  }

  # Resolve the clustering gene universe + selector provenance (#574). The
  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
  # from before this feature: `clustering_resolve_category_universe(NULL)`
  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
  # so cache parity (memoise key = gene set + algorithm) is preserved.
  selector_chr <- NULL
  if (has_genes) {
    genes_list <- as.character(unlist(genes_in))
    kind <- "explicit"
  } else if (category_supplied) {
    universe <- clustering_resolve_category_universe(req$argsBody$category_filter)
    genes_list <- universe$hgnc_ids
    selector_chr <- universe$selector
    kind <- "category"
  } else {
    universe <- clustering_resolve_category_universe(NULL)
    genes_list <- universe$hgnc_ids
    kind <- "all_ndd"
  }

  # Pre-fetch the STRING ID table because DB connections cannot cross the
  # durable worker boundary.
  string_id_table <- pool %>%
    dplyr::tbl("non_alt_loci_set") %>%
    dplyr::filter(!is.na(STRING_id)) %>%
    dplyr::select(symbol, hgnc_id, STRING_id) %>%
    dplyr::collect()

  # Check for duplicate job (include algorithm in check). The selector is
  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
  # submits keep the pre-#574 dedup identity byte-identical.
  dup_params <- list(genes = genes_list, algorithm = algorithm)
  if (!is.null(selector_chr)) {
    dup_params$category_filter <- selector_chr
  }
  dup_check <- check_duplicate_job("clustering", dup_params)
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

  # Cheap-path provenance (no expensive query yet). `selector_obj` records
  # WHICH universe was resolved; `intended_fingerprint` records the STRING
  # cache identity + fixed clustering params this submit intends to run
  # with. The *effective* fingerprint (e.g. the STRING weight channel a
  # computed result actually used) is only knowable from a computed result,
  # so it is recorded separately in the cache-hit result meta below.
  selector_obj <- list(kind = kind, category_filter = selector_chr)
  intended_fingerprint <- list(
    string_cache_fingerprint = analysis_string_cache_fingerprint(),
    score_threshold = 400L,
    algorithm = algorithm,
    seed = 42L
  )
  gene_sha <- clustering_gene_list_sha256(genes_list)

  # Source-data version: a CACHED, fail-closed read, fetched only now that a
  # payload is actually about to be built -- its backing view runs global
  # counts/joins, so it must never run before admission/dedup. A lookup
  # failure must never silently record NA/broken provenance; fail the
  # request closed instead.
  src_ver <- tryCatch(
    clustering_cached_source_data_version(conn = pool),
    error = function(e) e
  )
  if (inherits(src_ver, "error")) {
    res$status <- 503L
    return(list(
      error = "PROVENANCE_UNAVAILABLE",
      message = "Snapshot source-data version unavailable; retry shortly."
    ))
  }

  provenance <- list(
    selector = selector_obj,
    resolved_gene_count = length(genes_list),
    gene_list_sha256 = gene_sha,
    intended_fingerprint = intended_fingerprint,
    source_data_version = src_ver
  )

  # Define category links (needed for result)
  category_links <- tibble::tibble(
    value = c(
      "COMPARTMENTS", "Component", "DISEASES", "Function", "HPO",
      "InterPro", "KEGG", "Keyword", "NetworkNeighborAL", "Pfam",
      "PMID", "Process", "RCTM", "SMART", "TISSUES", "WikiPathways"
    ),
    link = c(
      "https://www.ebi.ac.uk/QuickGO/term/",
      "https://www.ebi.ac.uk/QuickGO/term/",
      "https://disease-ontology.org/term/",
      "https://www.ebi.ac.uk/QuickGO/term/",
      "https://hpo.jax.org/browse/term/",
      "http://www.ebi.ac.uk/interpro/entry/InterPro/",
      "https://www.genome.jp/dbget-bin/www_bget?",
      "https://www.uniprot.org/keywords/",
      "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
      "https://www.ebi.ac.uk/interpro/entry/pfam/",
      "https://www.ncbi.nlm.nih.gov/search/all/?term=",
      "https://www.ebi.ac.uk/QuickGO/term/",
      "https://reactome.org/content/detail/R-",
      "http://www.ebi.ac.uk/interpro/entry/smart/",
      "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
      "https://www.wikipathways.org/index.php/Pathway:"
    )
  )

  # Cache-first: if the memoized function already has a cached result,
  # return it immediately without submitting a durable worker job.
  # The network_edges endpoint (graph) warms this cache on first load,
  # so subsequent table requests resolve instantly.
  cache_hit <- tryCatch(
    memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm = algorithm),
    error = function(e) FALSE
  )

  if (cache_hit) {
    cached_clusters <- gen_string_clust_obj_mem(genes_list, algorithm = algorithm)

    categories <- cached_clusters %>%
      dplyr::select(term_enrichment) %>%
      tidyr::unnest(cols = c(term_enrichment)) %>%
      dplyr::select(category) %>%
      unique() %>%
      dplyr::arrange(category) %>%
      dplyr::mutate(
        text = dplyr::case_when(
          nchar(category) <= 5 ~ category,
          nchar(category) > 5 ~ stringr::str_to_sentence(category)
        )
      ) %>%
      dplyr::select(value = category, text) %>%
      dplyr::left_join(category_links, by = c("value"))

    # Splice the base cache-hit fields with `provenance` (already assembled
    # above as selector/resolved_gene_count/gene_list_sha256/
    # intended_fingerprint/source_data_version) instead of re-listing the same
    # five fields as duplicate literals -- keeps the two in lockstep by
    # construction. `effective_fingerprint` is added last: it is only knowable
    # from the computed result (`cached_clusters`), so it is not part of the
    # cheap-path `provenance` list.
    cache_result <- list(
      clusters = cached_clusters,
      categories = categories,
      meta = c(
        list(
          algorithm = algorithm,
          gene_count = length(genes_list),
          cluster_count = nrow(cached_clusters),
          cache_hit = TRUE
        ),
        provenance,
        list(effective_fingerprint = list(weight_channel = attr(cached_clusters, "weight_channel")))
      )
    )
    cache_request_payload <- list(
      genes = genes_list,
      algorithm = algorithm,
      category_links = category_links,
      string_id_table = string_id_table,
      provenance = provenance
    )
    if (!is.null(selector_chr)) {
      cache_request_payload$category_filter <- selector_chr
    }
    completed_job <- async_job_service_store_completed(
      job_type = "clustering",
      request_payload = cache_request_payload,
      result = cache_result,
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

  # Cache miss - create async job
  job_params <- list(
    genes = genes_list,
    algorithm = algorithm,
    category_links = category_links,
    string_id_table = string_id_table,
    provenance = provenance
  )
  if (!is.null(selector_chr)) {
    job_params$category_filter <- selector_chr
  }
  result <- create_job(
    operation = "clustering",
    params = job_params
  )

  # Check capacity
  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", as.character(result$retry_after))
    return(result)
  }

  # Success - return HTTP 202 Accepted
  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "5")

  list(
    job_id = result$job_id,
    status = result$status,
    estimated_seconds = result$estimated_seconds,
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}
