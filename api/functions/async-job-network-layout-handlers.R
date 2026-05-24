# functions/async-job-network-layout-handlers.R
#### Durable async job runner for GeneNetworks display layout artifacts

.async_job_network_layout_or <- function(value, fallback) {
  if (is.null(value) || length(value) == 0) {
    return(fallback)
  }

  if (is.list(value)) {
    return(value[[1]])
  }

  value[[1]]
}

.async_job_run_network_layout_prewarm <- function(job, payload, state, worker_config) {
  cluster_type <- as.character(.async_job_network_layout_or(payload$cluster_type, "clusters"))
  min_confidence <- as.integer(.async_job_network_layout_or(payload$min_confidence, 400L))
  max_edges <- as.integer(.async_job_network_layout_or(payload$max_edges, 10000L))
  force <- isTRUE(.async_job_network_layout_or(payload$force, FALSE))

  network_data <- generate_network_edges_response(
    cluster_type = cluster_type,
    min_confidence = min_confidence,
    max_edges = max_edges
  )

  artifact <- generate_network_display_layout_artifact(
    network_data,
    cluster_type = cluster_type,
    min_confidence = min_confidence,
    max_edges = max_edges,
    force = force
  )
  metadata <- artifact$metadata

  list(
    status = "completed",
    cluster_type = cluster_type,
    min_confidence = min_confidence,
    max_edges = max_edges,
    layout_key = metadata$layout_key,
    cache_hit = isTRUE(metadata$cache_hit),
    node_count = metadata$node_count,
    edge_count = metadata$edge_count,
    layout_duration_ms = .async_job_network_layout_or(metadata$layout_duration_ms, NA_integer_)
  )
}
