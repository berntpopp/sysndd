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
      availability = "local_analysis_or_cache",
      estimated_latency_class = "medium",
      default_limits = list(limit = 25L, max_limit = 50L, max_response_chars = "auto"),
      example_call = list(mode = "correlations", phenotype = "HP:0001250", response_mode = "compact")
    ),
    list(
      analysis_id = "gene_network",
      tool = "get_gene_network_context",
      data_class = "curated_derived_analysis",
      availability = "cache_hit_only",
      estimated_latency_class = "fast_on_cache_hit",
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

mcp_parse_json_field <- function(value, default = list()) {
  if (is.null(value) || length(value) == 0L || is.na(value[[1]]) || !nzchar(as.character(value[[1]]))) {
    return(default)
  }
  tryCatch(
    jsonlite::fromJSON(as.character(value[[1]]), simplifyVector = FALSE),
    error = function(e) default
  )
}

mcp_llm_cache_miss <- function(cluster_type, cluster_hash = NULL, cluster_number = NULL) {
  c(
    mcp_analysis_provenance("llm_generated_summary", "SysNDD LLM summary cache", "llm_cluster_summary_cache", "admin_llm_workflow"),
    list(
      summary_available = FALSE,
      cache_only = TRUE,
      cluster_type = cluster_type,
      cluster_hash = cluster_hash,
      cluster_number = cluster_number
    )
  )
}

mcp_get_cached_llm_summaries <- function(cluster_type,
                                         cluster_hashes = NULL,
                                         cluster_numbers = NULL,
                                         require_validated = TRUE,
                                         limit = 10L) {
  cluster_type <- mcp_validate_enum(cluster_type, c("functional", "phenotype"), "cluster_type")
  limit <- mcp_validate_limit(limit, default = 10L, max = 20L)
  rows <- mcp_analysis_repo_get_cached_llm_summaries(
    cluster_type = cluster_type,
    cluster_hashes = cluster_hashes,
    cluster_numbers = cluster_numbers,
    require_validated = require_validated,
    limit = limit
  )

  if (is.null(rows) || nrow(rows) == 0L) {
    return(list(mcp_llm_cache_miss(
      cluster_type,
      cluster_hash = (cluster_hashes %||% list(NULL))[[1]],
      cluster_number = (cluster_numbers %||% list(NULL))[[1]]
    )))
  }

  lapply(seq_len(nrow(rows)), function(i) {
    row <- mcp_row_to_list(rows[i, , drop = FALSE])
    c(
      mcp_analysis_provenance("llm_generated_summary", "SysNDD LLM summary cache", "llm_cluster_summary_cache", "admin_llm_workflow"),
      list(
        summary_available = TRUE,
        cache_only = TRUE,
        cache_id = row$cache_id,
        cluster_type = row$cluster_type,
        cluster_number = row$cluster_number,
        cluster_hash = row$cluster_hash,
        model_name = row$model_name,
        prompt_version = row$prompt_version,
        validation_status = row$validation_status,
        created_at = row$created_at,
        validated_at = row$validated_at,
        tags = mcp_parse_json_field(row$tags, list()),
        summary = mcp_parse_json_field(row$summary_json, list())
      )
    )
  })
}

mcp_get_phenotype_analysis_context <- function(mode,
                                               gene = NULL,
                                               phenotype = NULL,
                                               min_abs_correlation = 0.3,
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
  envelope <- mcp_analysis_provenance(
    "curated_derived_analysis",
    "SysNDD phenotype analysis",
    "approved primary review phenotypes",
    "deterministic_analysis"
  )

  if (isTRUE(dry_run) || identical(response_mode, "diagnostics")) {
    return(c(envelope, list(
      mode = mode,
      records = list(),
      cached_llm_summaries = list(),
      meta = list(
        limit = limit,
        diagnostics_only = TRUE,
        min_abs_correlation = min_abs_correlation,
        include_diagnostics = include_diagnostics
      ),
      budget = mcp_analysis_finalize_budget(list(mode = mode, limit = limit), budget),
      recovery = list(retry_with = list(mode = mode, response_mode = "compact", limit = min(limit, 25L)))
    )))
  }

  records <- tryCatch(
    switch(
      mode,
      correlations = mcp_analysis_repo_get_phenotype_correlations(
        phenotype = phenotype,
        min_abs_correlation = min_abs_correlation,
        limit = limit
      ),
      clusters = mcp_analysis_repo_get_phenotype_clusters(gene = gene, cluster_id = cluster_id, limit = limit),
      phenotype_functional_correlations = mcp_analysis_repo_get_phenotype_functional_correlations(gene = gene, limit = limit)
    ),
    error = function(e) NULL
  )
  if (is.null(records)) {
    stop(mcp_error(
      "temporarily_unavailable",
      "Requested phenotype analysis mode is not available from shared helper/cache-safe data.",
      list(argument = "mode")
    ))
  }

  record_list <- mcp_rows_to_records(records)
  trimmed <- mcp_analysis_trim_records(record_list, max_records = limit, budget = budget, label = paste0("phenotype_", mode))
  c(envelope, list(
    mode = mode,
    records = trimmed$records,
    cached_llm_summaries = list(),
    meta = list(
      limit = limit,
      returned = length(trimmed$records),
      min_abs_correlation = min_abs_correlation,
      include_cached_llm_summaries = include_cached_llm_summaries
    ),
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
  cluster_type <- mcp_validate_enum(cluster_type, c("clusters", "subclusters"), "cluster_type")
  budget <- mcp_analysis_response_budget(response_mode, max_response_chars)
  min_confidence <- suppressWarnings(as.integer(min_confidence))
  max_edges <- mcp_validate_limit(max_edges, default = 100L, max = 250L, name = "max_edges")
  if (is.na(min_confidence) || min_confidence < 0L || min_confidence > 1000L) {
    stop(mcp_error("invalid_input", "min_confidence must be between 0 and 1000", list(argument = "min_confidence")))
  }
  envelope <- mcp_analysis_provenance(
    "curated_derived_analysis",
    "SysNDD STRING-derived network analysis",
    "local STRING/memoise cache",
    "deterministic_analysis"
  )
  cache_hit <- mcp_analysis_repo_network_cache_hit(cluster_type = cluster_type, min_confidence = min_confidence)
  if (isTRUE(dry_run) || identical(response_mode, "diagnostics")) {
    return(c(envelope, list(
      section_status = if (isTRUE(cache_hit)) "available" else "temporarily_unavailable",
      nodes = list(),
      edges = list(),
      meta = list(
        cluster_type = cluster_type,
        min_confidence = min_confidence,
        max_edges = max_edges,
        cache_hit = cache_hit,
        include_diagnostics = include_diagnostics
      ),
      budget = mcp_analysis_finalize_budget(list(cache_hit = cache_hit, cluster_type = cluster_type), budget),
      recovery = list(retry_with = list(response_mode = "compact", max_edges = min(max_edges, 100L)))
    )))
  }
  if (!isTRUE(cache_hit)) {
    stop(mcp_error(
      "temporarily_unavailable",
      "Gene network context is not available from local cache without initializing STRINGdb.",
      list(argument = "gene_network", retry_with = list(dry_run = TRUE, response_mode = "diagnostics"))
    ))
  }
  network <- tryCatch(
    mcp_analysis_repo_get_network_edges_local(
      gene = gene,
      cluster_type = cluster_type,
      min_confidence = min_confidence,
      max_edges = max_edges
    ),
    error = function(e) NULL
  )
  if (is.null(network)) {
    stop(mcp_error(
      "temporarily_unavailable",
      "Gene network context is not available from local cache without initializing STRINGdb.",
      list(argument = "gene_network")
    ))
  }
  edge_records <- mcp_rows_to_records(network$edges)
  trimmed <- mcp_analysis_trim_records(edge_records, max_records = max_edges, budget = budget, label = "gene_network_edges")
  payload <- list(
    nodes = mcp_rows_to_records(network$nodes),
    edges = trimmed$records,
    meta = c(network$metadata %||% list(), list(
      cluster_type = cluster_type,
      min_confidence = min_confidence,
      max_edges = max_edges,
      include_cached_llm_summaries = include_cached_llm_summaries
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
