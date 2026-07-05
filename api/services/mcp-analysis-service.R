# services/mcp-analysis-service.R
#
# Read-only MCP analysis services for NDDScore, comparisons, phenotype context, networks, and cached LLM summaries.

mcp_get_sysndd_analysis_catalog <- function(include_unavailable = FALSE,
                                            response_mode = "compact") {
  response_mode <- mcp_validate_enum(response_mode, c("minimal", "compact"), "response_mode")
  budget <- mcp_analysis_response_budget(response_mode, "auto")
  envelope <- mcp_analysis_provenance(
    "operational_metadata",
    "SysNDD MCP analysis catalog",
    "mcp_build_tool_registry",
    "deterministic_service"
  )
  analyses <- list(
    list(
      analysis_id = "gene_research_context",
      tool = "get_gene_research_context",
      data_class = "operational_metadata",
      payload_shape = "mixed_labeled_sections",
      availability = "available",
      estimated_latency_class = "fast_to_medium",
      default_limits = list(entity_limit = 10L, publication_limit = 5L, max_response_chars = "auto"),
      example_call = list(gene = "HGNC:61", sections = list("curated", "nddscore"), response_mode = "compact")
    ),
    list(
      analysis_id = "nddscore",
      tool = "get_nddscore_context",
      data_class = "ml_prediction",
      availability = "available",
      estimated_latency_class = "fast",
      default_limits = list(page_size = 25L, max_page_size = 50L, max_response_chars = "auto"),
      example_call = list(gene = "HGNC:61", response_mode = "compact")
    ),
    list(
      analysis_id = "curation_comparisons",
      tool = "get_curation_comparison_context",
      data_class = "curated_derived_analysis",
      availability = "available",
      estimated_latency_class = "fast",
      default_limits = list(page_size = 25L, max_page_size = 50L, max_response_chars = "auto"),
      example_call = list(gene = "HGNC:61", mode = "gene_sources")
    ),
    list(
      analysis_id = "phenotype_analysis",
      tool = "get_phenotype_analysis_context",
      data_class = "curated_derived_analysis",
      availability = "public_ready_snapshot_only",
      estimated_latency_class = "fast_on_snapshot_hit",
      default_limits = list(limit = 25L, max_limit = 50L, max_response_chars = "auto"),
      example_call = list(mode = "correlations", phenotype = "HP:0001250", response_mode = "compact")
    ),
    list(
      analysis_id = "gene_network",
      tool = "get_gene_network_context",
      data_class = "curated_derived_analysis",
      availability = "public_ready_snapshot_only",
      estimated_latency_class = "fast_on_snapshot_hit",
      default_limits = list(max_edges = 100L, hard_max_edges = 250L, max_response_chars = "auto"),
      example_call = list(gene = "HGNC:61", dry_run = TRUE)
    ),
    list(
      analysis_id = "cached_llm_summaries",
      tool = "get_gene_research_context",
      data_class = "llm_generated_summary",
      availability = "cache_only",
      estimated_latency_class = "fast",
      default_limits = list(limit = 5L, max_limit = 20L, max_response_chars = "auto"),
      example_call = list(gene = "HGNC:61", sections = list("phenotype_clusters", "cached_llm_summaries"))
    )
  )
  if (!isTRUE(include_unavailable)) {
    analyses <- Filter(function(x) !identical(x$availability, "unavailable"), analyses)
  }
  if (identical(response_mode, "minimal")) {
    analyses <- lapply(analyses, function(x) x[c("analysis_id", "tool", "data_class", "availability")])
  }
  payload <- list(
    response_mode = response_mode,
    analyses = analyses,
    recommended_workflow = list(
      "Call get_sysndd_analysis_catalog first for scope and limits.",
      "Use get_gene_research_context(response_mode = 'compact', dry_run = TRUE) to preflight broad gene questions.",
      "Use focused analysis tools only for narrower follow-up."
    ),
    contract = list(
      llm_generation = "never",
      llm_summaries = "current validated cache only",
      live_external_providers = "never",
      analysis_reads = "public_ready_snapshots_only",
      evidence_boundary = "ML and LLM outputs do not change curated SysNDD evidence"
    ),
    meta = list(
      response_mode = response_mode,
      include_unavailable = isTRUE(include_unavailable),
      analysis_count = length(analyses)
    ),
    recovery = list(
      retry_with = list(response_mode = "minimal", include_unavailable = include_unavailable)
    )
  )
  mcp_analysis_finalize_response_budget(c(envelope, payload), budget)
}

mcp_nddscore_release_record <- function(release) {
  if (is.null(release) || nrow(release) == 0L) return(NULL)
  keep <- intersect(
    c(
      "release_id", "score_schema_version", "version", "release_created_at",
      "n_genes", "n_hpo_predictions", "n_hpo_terms", "n_features",
      "hpo_threshold", "calibration_method", "version_doi", "concept_doi",
      "source_record_id", "import_completed_at", "activated_at"
    ),
    names(release)
  )
  mcp_rows_to_records(release[keep])[[1]]
}

mcp_get_nddscore_context <- function(gene = NULL,
                                     mode = NULL,
                                     risk_tier = NULL,
                                     confidence_tier = NULL,
                                     known_sysndd_gene = NULL,
                                     hpo_terms = NULL,
                                     search = NULL,
                                     sort = "rank",
                                     page = 1L,
                                     page_size = 25L,
                                     response_mode = "compact",
                                     max_response_chars = "auto",
                                     include_diagnostics = FALSE,
                                     dry_run = FALSE) {
  mode <- mode %||% if (!is.null(gene)) "gene" else "ranked_genes"
  mode <- mcp_validate_enum(mode, c("gene", "ranked_genes", "release"), "mode")
  budget <- mcp_analysis_response_budget(response_mode, max_response_chars)
  page <- suppressWarnings(as.integer(page %||% 1L))
  if (is.na(page) || page < 1L) {
    stop(mcp_error("invalid_input", "page must be a positive integer", list(argument = "page")))
  }
  page_size <- mcp_validate_limit(page_size, default = 25L, max = 50L, name = "page_size")
  release <- mcp_analysis_repo_current_release()
  if (is.null(release) || nrow(release) == 0L) {
    stop(mcp_error("temporarily_unavailable", "No active NDDScore release is available.", list(argument = "release")))
  }
  envelope <- mcp_analysis_provenance("ml_prediction", "NDDScore", "nddscore_*_current", "nddscore_model")
  release_record <- mcp_nddscore_release_record(release)

  if (isTRUE(dry_run) || identical(response_mode, "diagnostics")) {
    return(c(envelope, list(
      mode = mode,
      notice = "NDDScore is an ML prediction layer. Separate from curated SysNDD evidence. Not an evidence tier.",
      release = release_record,
      rows = list(),
      meta = list(
        page = page,
        page_size = page_size,
        diagnostics_only = TRUE,
        include_diagnostics = include_diagnostics
      ),
      budget = mcp_analysis_finalize_budget(list(mode = mode, release = release_record), budget),
      recovery = list(retry_with = list(response_mode = "compact", page = page, page_size = page_size))
    )))
  }

  if (identical(mode, "release")) {
    payload <- list(
      release = release_record,
      notice = "NDDScore is an ML prediction layer. Separate from curated SysNDD evidence. Not an evidence tier."
    )
    return(c(envelope, payload, list(budget = mcp_analysis_finalize_budget(payload, budget))))
  }

  if (identical(mode, "gene")) {
    if (is.null(gene)) {
      stop(mcp_error("invalid_input", "gene is required when mode is gene", list(argument = "gene")))
    }
    detail <- mcp_analysis_repo_get_nddscore_gene(gene)
    if (is.null(detail$gene) || nrow(detail$gene) == 0L) {
      stop(mcp_error("not_found", sprintf("NDDScore gene '%s' was not found.", gene), list(argument = "gene")))
    }
    payload <- list(
      notice = "NDDScore is an ML prediction layer. Separate from curated SysNDD evidence. Not an evidence tier.",
      release = release_record,
      gene = mcp_rows_to_records(detail$gene)[[1]],
      hpo_predictions = if (is.null(detail$hpo_predictions)) list() else mcp_rows_to_records(detail$hpo_predictions)
    )
    return(c(envelope, payload, list(budget = mcp_analysis_finalize_budget(payload, budget))))
  }

  filters <- Filter(Negate(is.null), list(
    risk_tier = risk_tier,
    confidence_tier = confidence_tier,
    known_sysndd_gene = known_sysndd_gene,
    hpo_terms = hpo_terms,
    search = search
  ))
  result <- tryCatch(
    mcp_analysis_repo_get_nddscore_genes(filters = filters, sort = sort, page = page, page_size = page_size),
    error = function(e) stop(mcp_error("invalid_input", conditionMessage(e), list(argument = "sort_or_filter")))
  )
  records <- mcp_rows_to_records(result$data)
  trimmed <- mcp_analysis_trim_records(records, max_records = page_size, budget = budget, label = "nddscore_genes")
  c(envelope, list(
    notice = "NDDScore is an ML prediction layer. Separate from curated SysNDD evidence. Not an evidence tier.",
    release = release_record,
    genes = trimmed$records,
    meta = list(
      total = result$total,
      page = result$page,
      page_size = result$page_size,
      has_more = result$page * result$page_size < result$total
    ),
    budget = trimmed$budget
  ))
}

mcp_analysis_hgnc_filter <- function(gene) {
  if (is.null(gene)) {
    return(NULL)
  }
  normalized <- mcp_normalize_gene_input(gene)
  if (identical(normalized$kind, "hgnc_id")) {
    return(normalized$value)
  }
  mcp_resolve_gene_one(gene)$hgnc_id[[1]]
}

mcp_get_curation_comparison_context <- function(gene = NULL,
                                                mode = NULL,
                                                sources = NULL,
                                                category = NULL,
                                                page = 1L,
                                                page_size = 25L,
                                                response_mode = "compact",
                                                max_response_chars = "auto",
                                                include_diagnostics = FALSE,
                                                dry_run = FALSE) {
  mode <- mode %||% if (!is.null(gene)) "gene_sources" else "browse"
  if (mode %in% c("source_overlap", "source_similarity")) {
    stop(mcp_error(
      "invalid_input",
      "Comparison plot modes are not exposed through MCP v1.2; use gene_sources or browse.",
      list(argument = "mode", allowed_values = c("gene_sources", "browse"))
    ))
  }
  mode <- mcp_validate_enum(mode, c("gene_sources", "browse"), "mode")
  budget <- mcp_analysis_response_budget(response_mode, max_response_chars)
  page <- suppressWarnings(as.integer(page %||% 1L))
  if (is.na(page) || page < 1L) {
    stop(mcp_error("invalid_input", "page must be a positive integer", list(argument = "page")))
  }
  page_size <- mcp_validate_limit(page_size, default = 25L, max = 50L, name = "page_size")
  category <- if (is.null(category)) NULL else mcp_validate_query(category, min_chars = 1L, max_chars = 100L, argument = "category")

  hgnc_id <- mcp_analysis_hgnc_filter(gene)
  total <- mcp_analysis_repo_count_comparison_rows(hgnc_id = hgnc_id, sources = sources, category = category)
  meta <- mcp_analysis_repo_get_comparison_metadata()
  envelope <- mcp_analysis_provenance("curated_derived_analysis", "SysNDD comparison view", "ndd_database_comparison_view", "sysndd_import_pipeline")

  if (isTRUE(dry_run) || identical(response_mode, "diagnostics")) {
    return(c(envelope, list(
      mode = mode,
      rows = list(),
      comparison_metadata = if (isTRUE(include_diagnostics)) mcp_rows_to_records(meta) else list(),
      meta = list(total = total, page = page, page_size = page_size, has_more = page * page_size < total),
      budget = mcp_analysis_finalize_budget(list(total = total, page = page, page_size = page_size), budget),
      recovery = list(retry_with = list(response_mode = "compact", page = page, page_size = min(page_size, 25L)))
    )))
  }

  rows <- mcp_analysis_repo_get_comparison_rows(hgnc_id = hgnc_id, sources = sources, category = category, page = page, page_size = page_size)
  records <- mcp_rows_to_records(rows)
  trimmed <- mcp_analysis_trim_records(records, max_records = page_size, budget = budget, label = "comparison_rows")
  c(envelope, list(
    mode = mode,
    rows = trimmed$records,
    comparison_metadata = mcp_rows_to_records(meta),
    meta = list(total = total, page = page, page_size = page_size, has_more = page * page_size < total),
    budget = trimmed$budget,
    notice = "Comparison sources are cross-references and do not alter curated SysNDD classifications."
  ))
}

mcp_analysis_snapshot_status <- function(analysis_type, params = list()) {
  status <- if (exists("mcp_analysis_repo_public_snapshot_status", mode = "function")) {
    tryCatch(
      mcp_analysis_repo_public_snapshot_status(analysis_type, params),
      error = function(e) "snapshot_missing"
    )
  } else if (exists("mcp_analysis_repo_public_snapshot_available", mode = "function")) {
    if (isTRUE(tryCatch(
      mcp_analysis_repo_public_snapshot_available(analysis_type, params),
      error = function(e) FALSE
    ))) {
      "available"
    } else {
      "snapshot_missing"
    }
  } else {
    "snapshot_missing"
  }
  as.character(status %||% "snapshot_missing")[1]
}

mcp_analysis_snapshot_error_message <- function(status, label) {
  switch(status,
    snapshot_stale = sprintf("%s snapshot exists but is past its freshness policy.", label),
    source_version_mismatch = sprintf("%s snapshot exists but was built from a different public source-data version.", label),
    sprintf("%s is supported but no public-ready snapshot is available.", label)
  )
}

mcp_stop_analysis_snapshot_unavailable <- function(status, label, argument, retry_with = NULL) {
  stop(mcp_error(
    status,
    mcp_analysis_snapshot_error_message(status, label),
    list(argument = argument, retry_with = retry_with %||% list(dry_run = TRUE, response_mode = "diagnostics"))
  ))
}

# Read-through extraction of the additive null-calibrated separation statistics
# (validation schema >= 2.0: separation_z, dip test, null-model diagnostics,
# giant-component counts, silhouette interpretation, k-decision curve). These are
# operational diagnostics of the served partition, exposed read-only and NEVER
# recomputed on MCP. Returns NULL when a snapshot predates the fields so older
# snapshots surface no empty object.
mcp_analysis_separation_statistics <- function(validation) {
  if (is.null(validation) || length(validation) == 0L) {
    return(NULL)
  }
  keys <- c(
    "separation_z", "null_model", "dip_statistic", "dip_p", "dip_interpretation",
    "modularity_z", "modularity_p_empirical", "modularity_null_mean",
    "modularity_null_sd", "modularity_combined_score", "weight_channel",
    "giant_component", "silhouette_z", "silhouette_p_empirical",
    "shared_modularity_z", "k_decision_curve", "k_selected",
    "silhouette_interpretation", "consolidation"
  )
  present <- keys[keys %in% names(validation)]
  if (length(present) == 0L) {
    return(NULL)
  }
  validation[present]
}

mcp_get_phenotype_analysis_context <- function(mode,
                                               gene = NULL,
                                               phenotype = NULL,
                                               min_abs_correlation = 0.3,
                                               drop_diagonal = TRUE,
                                               triangle_only = FALSE,
                                               cluster_id = NULL,
                                               limit = 25L,
                                               include_cached_llm_summaries = TRUE,
                                               response_mode = "compact",
                                               max_response_chars = "auto",
                                               include_diagnostics = FALSE,
                                               dry_run = FALSE) {
  mode <- mcp_validate_enum(mode, c("correlations", "clusters", "phenotype_functional_correlations"), "mode")
  budget <- mcp_analysis_response_budget(response_mode, max_response_chars)
  limit <- mcp_validate_limit(limit, default = 25L, max = 50L)
  min_abs_correlation <- suppressWarnings(as.numeric(min_abs_correlation))
  if (is.na(min_abs_correlation) || min_abs_correlation < 0 || min_abs_correlation > 1) {
    stop(mcp_error("invalid_input", "min_abs_correlation must be between 0 and 1", list(argument = "min_abs_correlation")))
  }
  if (identical(mode, "correlations") && !is.null(gene) && nzchar(trimws(as.character(gene)[1]))) {
    stop(mcp_error(
      "invalid_input",
      "Phenotype correlations are global in MCP; omit gene or use phenotype/clusters follow-up tools.",
      list(argument = "gene")
    ))
  }
  envelope <- mcp_analysis_provenance(
    "curated_derived_analysis",
    "SysNDD phenotype analysis",
    "public-ready analysis snapshots",
    "snapshot_worker"
  )
  snapshot_status <- switch(
    mode,
    correlations = mcp_analysis_snapshot_status("phenotype_correlations", list()),
    clusters = mcp_analysis_snapshot_status("phenotype_clusters", list()),
    phenotype_functional_correlations = mcp_analysis_snapshot_status("phenotype_functional_correlations", list()),
    "snapshot_missing"
  )
  snapshot_available <- identical(snapshot_status, "available")

  if (isTRUE(dry_run) || identical(response_mode, "diagnostics")) {
    return(c(envelope, list(
      section_status = snapshot_status,
      mode = mode,
      records = list(),
      cached_llm_summaries = list(),
      meta = list(
        limit = limit,
        diagnostics_only = TRUE,
        min_abs_correlation = min_abs_correlation,
        drop_diagonal = isTRUE(drop_diagonal),
        triangle_only = isTRUE(triangle_only),
        include_diagnostics = include_diagnostics,
        snapshot_available = snapshot_available,
        snapshot_status = snapshot_status
      ),
      budget = mcp_analysis_finalize_budget(list(snapshot_available = snapshot_available, mode = mode, limit = limit), budget),
      recovery = list(retry_with = list(mode = mode, response_mode = "compact", limit = min(limit, 25L)))
    )))
  }

  if (!isTRUE(snapshot_available)) {
    mcp_stop_analysis_snapshot_unavailable(snapshot_status, "Requested phenotype analysis", "mode")
  }

  reader_result <- tryCatch(
    switch(
      mode,
      correlations = mcp_analysis_repo_get_snapshot_phenotype_correlations(
        phenotype = phenotype,
        min_abs_correlation = min_abs_correlation,
        drop_diagonal = drop_diagonal,
        triangle_only = triangle_only,
        limit = limit
      ),
      clusters = mcp_analysis_repo_get_snapshot_phenotype_clusters(gene = gene, cluster_id = cluster_id, limit = limit),
      phenotype_functional_correlations = mcp_analysis_repo_get_snapshot_phenotype_functional_correlations(gene = gene, limit = limit)
    ),
    error = function(e) NULL
  )
  if (is.null(reader_result)) {
    stop(mcp_error(
      "snapshot_missing",
      "Requested phenotype analysis is supported but no public-ready snapshot is available.",
      list(argument = "mode", retry_with = list(dry_run = TRUE, response_mode = "diagnostics"))
    ))
  }

  # The clusters reader threads snapshot meta as list(records, meta) so the
  # partition-level cluster-validation metrics + DB release label surface
  # read-only; other modes return a bare rows tibble.
  cluster_validation <- NULL
  cluster_db_release <- NULL
  if (identical(mode, "clusters")) {
    snapshot_meta <- reader_result$meta$snapshot %||% list()
    cluster_validation <- snapshot_meta$validation %||% NULL
    cluster_db_release <- snapshot_meta$db_release %||% NULL
    records <- reader_result$records
  } else {
    records <- reader_result
  }
  if (is.null(records)) {
    stop(mcp_error(
      "snapshot_missing",
      "Requested phenotype analysis is supported but no public-ready snapshot is available.",
      list(argument = "mode", retry_with = list(dry_run = TRUE, response_mode = "diagnostics"))
    ))
  }

  record_list <- mcp_rows_to_records(records)
  trimmed <- mcp_analysis_trim_records(record_list, max_records = limit, budget = budget, label = paste0("phenotype_", mode))
  meta <- list(
    limit = limit,
    returned = length(trimmed$records),
    min_abs_correlation = min_abs_correlation,
    drop_diagonal = isTRUE(drop_diagonal),
    triangle_only = isTRUE(triangle_only),
    include_cached_llm_summaries = include_cached_llm_summaries,
    snapshot_available = snapshot_available,
    snapshot_status = snapshot_status
  )
  if (identical(mode, "clusters")) {
    # validation is curated_derived_analysis; db_release/partition_scope/
    # modularity_scope are operational_metadata. Read-only.
    meta$validation <- cluster_validation
    meta$db_release <- cluster_db_release
    meta$data_classes <- list(
      validation = "curated_derived_analysis",
      db_release = "operational_metadata"
    )
    # Additive null-calibrated separation diagnostics (validation schema >= 2.0)
    # surface as their own operational_metadata block, read-through from the same
    # validation object. Absent on pre-refresh snapshots -> omitted entirely.
    separation_statistics <- mcp_analysis_separation_statistics(cluster_validation)
    if (!is.null(separation_statistics)) {
      meta$separation_statistics <- separation_statistics
      meta$data_classes$separation_statistics <- "operational_metadata"
    }
  }
  c(envelope, list(
    mode = mode,
    records = trimmed$records,
    cached_llm_summaries = list(),
    meta = meta,
    budget = trimmed$budget
  ))
}

mcp_get_gene_network_context <- function(gene = NULL,
                                         cluster_type = "clusters",
                                         min_confidence = 400L,
                                         max_edges = 100L,
                                         include_cached_llm_summaries = TRUE,
                                         response_mode = "compact",
                                         max_response_chars = "auto",
                                         include_diagnostics = FALSE,
                                         dry_run = FALSE) {
  budget <- mcp_analysis_response_budget(response_mode, max_response_chars)
  cluster_type <- as.character(cluster_type %||% "clusters")[1]
  min_confidence <- suppressWarnings(as.integer(min_confidence))
  max_edges <- mcp_validate_limit(max_edges, default = 100L, max = 250L, name = "max_edges")
  normalized <- tryCatch(
    analysis_snapshot_normalize_params(
      "gene_network_edges",
      list(cluster_type = cluster_type, min_confidence = min_confidence, max_edges = 10000L)
    ),
    analysis_snapshot_unsupported_parameter_error = function(e) e
  )
  if (inherits(normalized, "analysis_snapshot_unsupported_parameter_error")) {
    stop(mcp_error(
      "unsupported_parameter",
      conditionMessage(normalized),
      list(argument = "gene_network_parameters")
    ))
  }
  envelope <- mcp_analysis_provenance(
    "curated_derived_analysis",
    "SysNDD STRING-derived network analysis",
    "public-ready analysis snapshots",
    "snapshot_worker"
  )
  snapshot_status <- mcp_analysis_snapshot_status(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = 400L, max_edges = 10000L)
  )
  snapshot_available <- identical(snapshot_status, "available")
  if (isTRUE(dry_run) || identical(response_mode, "diagnostics")) {
    return(c(envelope, list(
      section_status = snapshot_status,
      nodes = list(),
      edges = list(),
      meta = list(
        cluster_type = cluster_type,
        min_confidence = min_confidence,
        max_edges = max_edges,
        stored_snapshot_params = normalized$params,
        snapshot_available = snapshot_available,
        snapshot_status = snapshot_status,
        include_diagnostics = include_diagnostics
      ),
      budget = mcp_analysis_finalize_budget(list(snapshot_available = snapshot_available, cluster_type = cluster_type), budget),
      recovery = list(retry_with = list(response_mode = "compact", max_edges = min(max_edges, 100L)))
    )))
  }
  if (!isTRUE(snapshot_available)) {
    mcp_stop_analysis_snapshot_unavailable(snapshot_status, "Gene network context", "gene_network")
  }
  network <- tryCatch(
    mcp_analysis_repo_get_snapshot_network(
      gene = gene,
      max_edges = max_edges
    ),
    error = function(e) NULL
  )
  if (is.null(network)) {
    stop(mcp_error(
      "snapshot_missing",
      "Gene network context is supported but no public-ready snapshot is available.",
      list(argument = "gene_network")
    ))
  }
  edge_records <- mcp_rows_to_records(network$edges)
  trimmed <- mcp_analysis_trim_records(edge_records, max_records = max_edges, budget = budget, label = "gene_network_edges")
  # gene_network_edges has no cluster validation; surface only the db_release
  # label (operational_metadata) from the snapshot meta, read-only.
  network_db_release <- (network$metadata$snapshot$db_release) %||% NULL
  payload <- list(
    nodes = mcp_rows_to_records(network$nodes),
    edges = trimmed$records,
    meta = c(network$metadata %||% list(), list(
      cluster_type = cluster_type,
      min_confidence = min_confidence,
      max_edges = max_edges,
      stored_snapshot_params = normalized$params,
      snapshot_status = snapshot_status,
      include_cached_llm_summaries = include_cached_llm_summaries,
      db_release = network_db_release,
      data_classes = list(db_release = "operational_metadata")
    ))
  )
  trimmed$budget <- mcp_analysis_finalize_budget(payload, trimmed$budget)
  c(envelope, list(
    section_status = "available",
    nodes = payload$nodes,
    edges = payload$edges,
    meta = payload$meta,
    budget = trimmed$budget
  ))
}
