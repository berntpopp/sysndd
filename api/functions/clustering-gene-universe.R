# api/functions/clustering-gene-universe.R
#
# Category-selected clustering gene-universe resolver (#574 D1).
#
# `POST /api/jobs/clustering/submit` will (D2/D3, not this file) accept a
# `category_filter` (e.g. c("Definitive")) to resolve the clustering gene
# universe from curated SysNDD confidence categories instead of the default
# "all NDD genes" set. This file builds ONLY the resolver + provenance
# helpers; the submit service and durable handler wiring is done later.
#
# Entity-level resolution: a gene qualifies if it has >=1 NDD entity
# (`ndd_phenotype == 1`) whose `category` is in the selector, even if the
# same gene also has OTHER-category entities. This mirrors
# `generate_ndd_hgnc_ids()` (the existing default-universe query) with an
# added `category %in% selector` filter -- it deliberately does NOT use
# `select_network_gene_category()`, which is a gene-level display-label
# aggregator for node coloring, not a universe filter.
#
# Category validation is live against `ndd_entity_status_categories_list
# WHERE is_active = 1` -- no hardcoded category strings, and no category
# string is interpolated into SQL (dbplyr `%in%` + an allowlist pre-check).

# Returns NULL ONLY when the field was absent (arg is NULL). A supplied-but-empty
# selector returns character(0), which the resolver rejects with 400 -- it must
# never fall through to the all-NDD default.
clustering_normalize_category_filter <- function(category_filter) {
  if (is.null(category_filter)) return(NULL)
  vals <- trimws(as.character(unlist(category_filter, use.names = FALSE)))
  vals <- vals[nzchar(vals)]
  if (length(vals) == 0L) return(character(0)) # supplied but empty -> 400 downstream
  sort(unique(vals))
}

clustering_gene_list_sha256 <- function(hgnc_ids) {
  digest::digest(
    jsonlite::toJSON(sort(unique(as.character(hgnc_ids))), auto_unbox = TRUE),
    algo = "sha256", serialize = FALSE
  )
}

clustering_resolve_category_universe <- function(category_filter, conn = pool) {
  selector <- clustering_normalize_category_filter(category_filter)

  if (is.null(selector)) {
    # Absent -> preserve the exact current default ordering for cache parity.
    hgnc_ids <- generate_ndd_hgnc_ids() %>% dplyr::pull(hgnc_id)
    return(list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids)))
  }
  if (length(selector) == 0L) {
    stop_for_bad_request("category_filter was supplied but empty; provide at least one active category")
  }

  active <- conn %>%
    dplyr::tbl("ndd_entity_status_categories_list") %>%
    dplyr::filter(is_active == 1) %>%
    dplyr::select(category) %>%
    dplyr::collect() %>%
    dplyr::pull(category)
  unknown <- setdiff(selector, active)
  if (length(unknown) > 0L) {
    # Allowed set goes in the MESSAGE: core/filters.R serializes conditionMessage(err), not `detail`.
    stop_for_bad_request(sprintf(
      "Unknown or inactive category_filter value(s): %s. Allowed active categories: %s",
      paste(unknown, collapse = ", "), paste(sort(active), collapse = ", ")
    ))
  }

  hgnc_ids <- conn %>%
    dplyr::tbl("ndd_entity_view") %>%
    dplyr::arrange(entity_id) %>%
    dplyr::filter(ndd_phenotype == 1, category %in% !!selector) %>%
    dplyr::select(hgnc_id) %>%
    dplyr::collect() %>%
    unique() %>%
    dplyr::pull(hgnc_id)

  if (length(hgnc_ids) < 2L) {
    stop_for_bad_request(sprintf(
      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2",
      paste(selector, collapse = ","), length(hgnc_ids)
    ))
  }
  list(hgnc_ids = hgnc_ids, selector = selector, resolved_gene_count = length(hgnc_ids))
}

# Module-level (survives across requests within the same process) cache for
# `analysis_snapshot_source_data_version()`. That read joins/aggregates across
# public tables and changes rarely (only when the snapshot builder's source
# view moves), so a short-TTL process cache avoids paying that cost on every
# clustering submit while still self-refreshing.
.clustering_source_data_version_cache <- new.env(parent = emptyenv())

#' Cached, fail-closed read of the current analysis source-data version.
#'
#' D2 (#574) provenance helper: the clustering submit service calls this
#' AFTER admission/dedup, only when it is actually about to build a durable
#' payload. Refetches once `ttl_seconds` has elapsed since the last
#' successful read. Deliberately does NOT wrap
#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
#' PROPAGATES to the caller (never cached, never coerced to NA), so a
#' transient DB problem fails the submit closed (503) instead of recording
#' broken provenance.
#'
#' @param conn DB connection/pool. Defaults to the package-global `pool`.
#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
#' @return character(1) source data version.
#' @export
clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
  now <- Sys.time()
  cached_at <- .clustering_source_data_version_cache$cached_at
  if (!is.null(cached_at) &&
        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
    return(.clustering_source_data_version_cache$value)
  }

  value <- analysis_snapshot_source_data_version(conn = conn)

  .clustering_source_data_version_cache$value <- value
  .clustering_source_data_version_cache$cached_at <- now
  value
}

# Assemble the clustering result `meta`: base fields + the cheap-path provenance
# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
# source_data_version, NULL for a legacy payload) + the EFFECTIVE weight_channel
# observed post-compute. Shared by the cache-hit path
# (job-functional-submission-service.R) and the worker-run/durable handler
# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
# shapes cannot drift apart by hand-copied edits.
clustering_result_meta <- function(base, provenance, weight_channel) {
  c(base,
    if (!is.null(provenance)) provenance else list(),
    list(effective_fingerprint = list(weight_channel = weight_channel)))
}
