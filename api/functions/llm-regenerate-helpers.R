# functions/llm-regenerate-helpers.R
#
# Snapshot-driven LLM cluster-summary regeneration (#488).
#
# The admin `POST /api/llm/regenerate` endpoint used to recompute clustering
# INLINE (functional `gen_string_clust_obj_mem`; phenotype rebuilt MCA/HCPC +
# `gen_mca_clust_obj_mem`) independently of the analysis-snapshot builder. That
# independent recompute produced DIFFERENT `cluster_hash` values than the
# published snapshot, so the generated summaries could never be served (serving
# looks them up by the snapshot's stored `cluster_hash`), and because each write
# flips `is_current`, a forced regeneration actively un-matched the previously
# correct summaries -> every cluster fell back to "being prepared".
#
# This module drives regeneration from the PUBLISHED snapshot's stored clusters
# instead, so the summaries' hashes match what serving looks up by construction.
# `service_analysis_snapshot_shape_clusters()` re-expands the stored clusters
# into the exact tibble shape `llm_batch_executor` consumes (`cluster`,
# `hash_filter` == stored cluster_hash, `identifiers`, and the phenotype
# metadata list-cols `quali_inp_var` / `quali_sup_var` / `quanti_sup_var`).
#
# The snapshot fetch / shaping / trigger dependencies are injectable so the
# orchestration is unit-testable without a database.

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

#' Map an LLM cluster_type to its analysis-snapshot coordinates.
#'
#' @param cluster_type "functional" or "phenotype".
#' @return list(analysis_type, cluster_kind, params) or NULL for an unknown type.
#' @export
llm_regenerate_cluster_type_map <- function(cluster_type) {
  switch(as.character(cluster_type[[1]]),
    functional = list(
      analysis_type = "functional_clusters",
      cluster_kind = "functional",
      params = list(algorithm = "leiden")
    ),
    phenotype = list(
      analysis_type = "phenotype_clusters",
      cluster_kind = "phenotype",
      params = list()
    ),
    NULL
  )
}

#' Regenerate LLM summaries for one cluster type from the published snapshot.
#'
#' Reads the public-ready snapshot, reshapes its stored clusters into the batch
#' generator's expected tibble, and triggers batch generation. Never recomputes
#' clustering. When no public-ready snapshot exists it returns `ready = FALSE`
#' (the caller should surface a 409, not recompute).
#'
#' @param cluster_type "functional" or "phenotype".
#' @param parent_job_id UUID string for job tracking.
#' @param force Logical, forward a real `force` to the batch generator so a
#'   forced regeneration bypasses the executor's cache-first short-circuit.
#' @param get_snapshot Injected snapshot fetcher (default the MCP repo reader).
#' @param shape_clusters Injected snapshot->clusters shaper.
#' @param trigger Injected batch-generation trigger.
#' @return list(ready, cluster_type, analysis_type, ...): when ready, includes
#'   `cluster_count` and the `result` of the trigger; when not ready, a `reason`.
#' @export
llm_regenerate_from_snapshot <- function(cluster_type,
                                         parent_job_id,
                                         force = FALSE,
                                         get_snapshot = mcp_analysis_repo_get_public_snapshot,
                                         shape_clusters = service_analysis_snapshot_shape_clusters,
                                         trigger = trigger_llm_batch_generation) {
  map <- llm_regenerate_cluster_type_map(cluster_type)
  if (is.null(map)) {
    return(list(ready = FALSE, reason = "unsupported_cluster_type", cluster_type = as.character(cluster_type)))
  }

  snap <- get_snapshot(map$analysis_type, map$params)
  if (is.null(snap) || is.null(snap$snapshot)) {
    return(list(
      ready = FALSE,
      reason = "snapshot_not_ready",
      cluster_type = cluster_type,
      analysis_type = map$analysis_type
    ))
  }

  clusters <- shape_clusters(snap$snapshot, cluster_kind = map$cluster_kind)
  if (is.null(clusters) || !is.data.frame(clusters) || nrow(clusters) == 0L) {
    return(list(
      ready = FALSE,
      reason = "snapshot_empty",
      cluster_type = cluster_type,
      analysis_type = map$analysis_type
    ))
  }

  result <- trigger(
    clusters,
    cluster_type = cluster_type,
    parent_job_id = parent_job_id,
    force = isTRUE(force)
  )

  list(
    ready = TRUE,
    cluster_type = cluster_type,
    analysis_type = map$analysis_type,
    cluster_count = nrow(clusters),
    result = result
  )
}
