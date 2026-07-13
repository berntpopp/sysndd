# functions/mcp-analysis-repository.R
#
# Bounded MCP analysis reads over the dedicated approved-public projections.

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

mcp_analysis_repo_limit <- function(limit, default = 25L, max = 50L) {
  limit <- suppressWarnings(as.integer(limit))
  if (is.na(limit) || limit < 1L) return(default)
  min(limit, max)
}

mcp_analysis_repo_current_release <- function() {
  db_execute_query(
    "SELECT release_id, score_schema_version, version, release_created_at,
            n_genes, n_hpo_predictions, n_hpo_terms, n_features,
            hpo_threshold, calibration_method, ndd_model_created_at,
            phenotype_model_created_at, inheritance_model_created_at,
            ndd_performance_json, phenotype_performance_json,
            inheritance_performance_json, data_versions_json,
            artifact_hashes_json, zenodo_record_url, version_doi,
            concept_doi, source_record_id, import_completed_at, activated_at
       FROM mcp_public_nddscore_release
      ORDER BY activated_at DESC, release_id DESC
      LIMIT 1",
    unname(list())
  )
}

mcp_analysis_repo_get_nddscore_gene <- function(gene) {
  gene_rows <- db_execute_query(
    "SELECT release_id, hgnc_id, gene_symbol, ensembl_gene_id, ndd_score,
            ndd_score_std, ndd_score_iqr, bag_agreement, `rank`, percentile,
            risk_tier, confidence_tier, known_sysndd_gene, model_split,
            inheritance_ad_probability, inheritance_ar_probability,
            inheritance_xld_probability, inheritance_xlr_probability,
            top_inheritance_mode, called_inheritance_modes, n_predicted_hpo,
            top_hpo_predictions_json, shap_clinical, shap_constraint,
            shap_expression, shap_network, shap_conservation, shap_other,
            dominant_shap_group, top_features_json, prediction_note
       FROM mcp_public_nddscore_gene_prediction
      WHERE UPPER(hgnc_id) = UPPER(?) OR UPPER(gene_symbol) = UPPER(?)
      LIMIT 2",
    unname(list(gene, gene))
  )
  if (is.null(gene_rows) || nrow(gene_rows) == 0L) {
    return(list(gene = tibble::tibble(), hpo_predictions = tibble::tibble()))
  }
  hpo_rows <- db_execute_query(
    "SELECT release_id, hgnc_id, gene_symbol, phenotype_id, phenotype_name,
            probability, rank_for_gene, passes_default_threshold,
            term_auc_roc, term_auc_pr, term_training_support
       FROM mcp_public_nddscore_hpo_prediction
      WHERE release_id = ? AND hgnc_id = ?
      ORDER BY rank_for_gene, phenotype_id
      LIMIT 200",
    unname(list(gene_rows$release_id[[1]], gene_rows$hgnc_id[[1]]))
  )
  list(gene = gene_rows, hpo_predictions = hpo_rows)
}

mcp_analysis_repo_get_nddscore_genes <- function(filters = list(),
                                                 sort = "rank",
                                                 page = 1L,
                                                 page_size = 25L) {
  allowed_filters <- c("risk_tier", "confidence_tier", "known_sysndd_gene", "hpo_terms", "search")
  invalid <- setdiff(names(filters), allowed_filters)
  if (length(invalid) > 0L) stop(sprintf("Invalid filter column '%s'", invalid[[1]]), call. = FALSE)

  sort_columns <- c(
    hgnc_id = "hgnc_id", gene_symbol = "gene_symbol", ndd_score = "ndd_score",
    rank = "`rank`", percentile = "percentile", risk_tier = "risk_tier",
    confidence_tier = "confidence_tier", known_sysndd_gene = "known_sysndd_gene",
    n_predicted_hpo = "n_predicted_hpo"
  )
  direction <- if (startsWith(sort, "-")) "DESC" else "ASC"
  sort_name <- sub("^-", "", sort)
  if (!sort_name %in% names(sort_columns)) stop(sprintf("Invalid sort column '%s'", sort_name), call. = FALSE)

  where <- character()
  params <- list()
  for (field in c("risk_tier", "confidence_tier")) {
    value <- filters[[field]] %||% NULL
    if (!is.null(value) && nzchar(as.character(value)[1])) {
      where <- c(where, sprintf("%s = ?", field))
      params <- c(params, list(as.character(value)[1]))
    }
  }
  if (!is.null(filters$known_sysndd_gene)) {
    value <- tolower(as.character(filters$known_sysndd_gene)[1])
    bool <- if (value %in% c("true", "yes", "1")) 1L else if (value %in% c("false", "no", "0")) 0L else NA_integer_
    if (is.na(bool)) stop("known_sysndd_gene must be boolean", call. = FALSE)
    where <- c(where, "known_sysndd_gene = ?")
    params <- c(params, list(bool))
  }
  if (!is.null(filters$hpo_terms)) {
    terms <- trimws(as.character(unlist(filters$hpo_terms, use.names = FALSE)))
    terms <- terms[nzchar(terms)]
    if (length(terms) > 0L) {
      clauses <- rep("top_hpo_predictions_json LIKE ?", length(terms))
      where <- c(where, paste0("(", paste(clauses, collapse = " OR "), ")"))
      params <- c(params, as.list(paste0("%", terms, "%")))
    }
  }
  if (!is.null(filters$search) && nzchar(as.character(filters$search)[1])) {
    where <- c(where, "(UPPER(hgnc_id) LIKE UPPER(?) OR UPPER(gene_symbol) LIKE UPPER(?))")
    like <- paste0("%", as.character(filters$search)[1], "%")
    params <- c(params, list(like, like))
  }

  page <- max(1L, suppressWarnings(as.integer(page)))
  page_size <- mcp_analysis_repo_limit(page_size, max = 50L)
  offset <- (page - 1L) * page_size
  where_sql <- if (length(where) == 0L) "" else paste("WHERE", paste(where, collapse = " AND "))
  rows <- db_execute_query(
    paste(
      "SELECT release_id, hgnc_id, gene_symbol, ensembl_gene_id, ndd_score,
              ndd_score_std, ndd_score_iqr, bag_agreement, `rank`, percentile,
              risk_tier, confidence_tier, known_sysndd_gene, model_split,
              top_inheritance_mode, n_predicted_hpo, top_hpo_predictions_json,
              dominant_shap_group, top_features_json, prediction_note
         FROM mcp_public_nddscore_gene_prediction",
      where_sql, "ORDER BY", unname(sort_columns[[sort_name]]), direction, "LIMIT ? OFFSET ?"
    ),
    unname(c(params, list(page_size, offset)))
  )
  count <- db_execute_query(
    paste("SELECT COUNT(*) AS total FROM mcp_public_nddscore_gene_prediction", where_sql),
    unname(params)
  )
  list(data = rows, total = as.integer(count$total[[1]] %||% 0L), page = page, page_size = page_size)
}

mcp_analysis_repo_get_comparison_metadata <- function() {
  db_execute_query(
    "SELECT last_full_refresh, last_refresh_status, sources_count, rows_imported
       FROM mcp_public_comparison_metadata
      LIMIT 1",
    unname(list())
  )
}

mcp_analysis_repo_comparison_filter <- function(hgnc_id, sources, category) {
  filters <- character()
  params <- list()
  if (!is.null(hgnc_id)) {
    filters <- c(filters, "hgnc_id = ?")
    params <- c(params, list(hgnc_id))
  }
  if (!is.null(category)) {
    filters <- c(filters, "category = ?")
    params <- c(params, list(category))
  }
  if (length(sources %||% character()) > 0L) {
    filters <- c(filters, sprintf("`list` IN (%s)", paste(rep("?", length(sources)), collapse = ", ")))
    params <- c(params, as.list(sources))
  }
  list(where = if (length(filters) > 0L) paste("WHERE", paste(filters, collapse = " AND ")) else "", params = params)
}

mcp_analysis_repo_get_comparison_rows <- function(hgnc_id = NULL, sources = NULL,
                                                  category = NULL, page = 1L,
                                                  page_size = 25L) {
  filter <- mcp_analysis_repo_comparison_filter(hgnc_id, sources, category)
  offset <- (page - 1L) * page_size
  db_execute_query(
    paste(
      "SELECT hgnc_id, disease_ontology_id, inheritance, category,
              pathogenicity_mode, `list`, version
         FROM mcp_public_comparison",
      filter$where, "ORDER BY hgnc_id, `list`, disease_ontology_id LIMIT ? OFFSET ?"
    ),
    unname(c(filter$params, list(page_size, offset)))
  )
}

mcp_analysis_repo_count_comparison_rows <- function(hgnc_id = NULL, sources = NULL, category = NULL) {
  filter <- mcp_analysis_repo_comparison_filter(hgnc_id, sources, category)
  rows <- db_execute_query(
    paste("SELECT COUNT(*) AS total FROM mcp_public_comparison", filter$where),
    unname(filter$params)
  )
  as.integer(rows$total[[1]] %||% 0L)
}

mcp_analysis_repo_get_gene_external_identifiers <- function(hgnc_id) {
  db_execute_query(
    "SELECT hgnc_id, symbol, omim_id, ensembl_gene_id, uniprot_ids,
            STRING_id, mgd_id, rgd_id, mane_select, alphafold_id
       FROM mcp_public_gene
      WHERE hgnc_id = ?
      LIMIT 1",
    unname(list(hgnc_id))
  )
}

mcp_analysis_repo_get_cached_llm_summaries <- function(cluster_type,
                                                       cluster_hashes = NULL,
                                                       cluster_numbers = NULL,
                                                       require_validated = TRUE,
                                                       limit = 10L,
                                                       prompt_version = LLM_SUMMARY_PROMPT_VERSION) {
  filters <- c("cluster_type = ?", "prompt_version = ?")
  params <- list(cluster_type, prompt_version)
  if (length(cluster_hashes %||% character()) > 0L) {
    filters <- c(filters, sprintf("cluster_hash IN (%s)", paste(rep("?", length(cluster_hashes)), collapse = ", ")))
    params <- c(params, as.list(cluster_hashes))
  }
  if (length(cluster_numbers %||% integer()) > 0L) {
    filters <- c(filters, sprintf("cluster_number IN (%s)", paste(rep("?", length(cluster_numbers)), collapse = ", ")))
    params <- c(params, as.list(cluster_numbers))
  }
  db_execute_query(
    paste(
      "SELECT cache_id, snapshot_id, cluster_type, cluster_number, cluster_hash,
              model_name, prompt_version, summary_json, tags, created_at, validated_at
         FROM mcp_public_llm_cluster_summary
        WHERE", paste(filters, collapse = " AND "),
      "ORDER BY validated_at DESC, created_at DESC LIMIT ?"
    ),
    unname(c(params, list(mcp_analysis_repo_limit(limit, max = 20L))))
  )
}

mcp_analysis_repo_get_public_snapshot <- function(analysis_type, params = list()) {
  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
  rows <- db_execute_query(
    "SELECT snapshot_id, analysis_type, parameter_hash, schema_version, data_class,
            generated_at, activated_at, stale_after, source_data_version,
            parameters_json, payload_hash, algorithm_name, algorithm_version,
            row_counts_json
       FROM mcp_public_analysis_manifest
      WHERE analysis_type = ? AND parameter_hash = ?
      LIMIT 1",
    unname(list(normalized$analysis_type, normalized$parameter_hash))
  )
  if (is.null(rows) || nrow(rows) == 0L) return(NULL)
  list(normalized = normalized, manifest = rows[1, , drop = FALSE])
}

mcp_analysis_repo_public_snapshot_status <- function(analysis_type, params = list(), conn = NULL, ...) {
  snapshot <- tryCatch(mcp_analysis_repo_get_public_snapshot(analysis_type, params), error = function(e) NULL)
  if (is.null(snapshot)) "snapshot_missing" else "available"
}

mcp_analysis_repo_public_snapshot_available <- function(analysis_type, params = list(), conn = NULL) {
  identical(mcp_analysis_repo_public_snapshot_status(analysis_type, params, conn = conn), "available")
}

mcp_analysis_repo_manifest_meta <- function(snapshot) {
  row <- snapshot$manifest
  if (is.null(row) || nrow(row) == 0L) return(list())
  list(
    snapshot = list(
      snapshot_id = row$snapshot_id[[1]], analysis_type = row$analysis_type[[1]],
      parameter_hash = row$parameter_hash[[1]], schema_version = row$schema_version[[1]],
      source_data_version = row$source_data_version[[1]], payload_hash = row$payload_hash[[1]],
      generated_at = row$generated_at[[1]], activated_at = row$activated_at[[1]],
      stale_after = row$stale_after[[1]], algorithm_name = row$algorithm_name[[1]],
      algorithm_version = row$algorithm_version[[1]]
    )
  )
}

mcp_analysis_repo_get_snapshot_network <- function(gene = NULL, max_edges = 100L) {
  snapshot <- mcp_analysis_repo_get_public_snapshot(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = 400L, max_edges = 10000L)
  )
  if (is.null(snapshot)) return(NULL)
  snapshot_id <- snapshot$manifest$snapshot_id[[1]]
  nodes <- db_execute_query(
    "SELECT hgnc_id, symbol, cluster_id AS cluster, category, degree,
            x, y, layout_x, layout_y, igraph_x, igraph_y, display_order
       FROM mcp_public_analysis_network_node
      WHERE snapshot_id = ?
      ORDER BY display_order, hgnc_id
      LIMIT 10000",
    unname(list(snapshot_id))
  )
  edges <- db_execute_query(
    "SELECT source_hgnc_id AS source, target_hgnc_id AS target, confidence
       FROM mcp_public_analysis_network_edge
      WHERE snapshot_id = ?
      ORDER BY edge_rank
      LIMIT 10000",
    unname(list(snapshot_id))
  )
  network <- list(nodes = nodes, edges = edges, metadata = mcp_analysis_repo_manifest_meta(snapshot)$snapshot)
  network$metadata <- list(snapshot = network$metadata)
  network <- mcp_analysis_repo_filter_network_gene(network, gene)
  max_edges <- mcp_analysis_repo_limit(max_edges, default = 100L, max = 250L)
  if (nrow(network$edges) > max_edges) network$edges <- utils::head(network$edges, max_edges)
  mcp_analysis_repo_refresh_network_metadata(network)
}

mcp_analysis_repo_get_snapshot_correlations <- function(analysis_type, phenotype = NULL,
                                                        min_abs_correlation = NULL,
                                                        limit = 25L) {
  snapshot <- mcp_analysis_repo_get_public_snapshot(analysis_type, list())
  if (is.null(snapshot)) return(NULL)
  filters <- c("snapshot_id = ?")
  params <- list(snapshot$manifest$snapshot_id[[1]])
  if (!is.null(min_abs_correlation)) {
    filters <- c(filters, "abs_value >= ?")
    params <- c(params, list(min_abs_correlation))
  }
  if (!is.null(phenotype) && nzchar(trimws(as.character(phenotype)[1]))) {
    filters <- c(filters, "(UPPER(x_key) LIKE UPPER(?) OR UPPER(y_key) LIKE UPPER(?))")
    like <- paste0("%", trimws(as.character(phenotype)[1]), "%")
    params <- c(params, list(like, like))
  }
  db_execute_query(
    paste(
      "SELECT x_key AS x, y_key AS y, value, correlation_kind, metadata_json
         FROM mcp_public_analysis_correlation
        WHERE", paste(filters, collapse = " AND "),
      "ORDER BY abs_value DESC, row_rank LIMIT ?"
    ),
    unname(c(params, list(mcp_analysis_repo_limit(limit))))
  )
}

mcp_analysis_repo_get_snapshot_phenotype_correlations <- function(phenotype = NULL,
                                                                  min_abs_correlation = 0.3,
                                                                  drop_diagonal = TRUE,
                                                                  triangle_only = FALSE,
                                                                  limit = 25L) {
  rows <- mcp_analysis_repo_get_snapshot_correlations(
    "phenotype_correlations", phenotype, min_abs_correlation, limit
  )
  if (!is.null(rows) && isTRUE(drop_diagonal) && nrow(rows) > 0L) rows <- rows[rows$x != rows$y, , drop = FALSE]
  rows
}

mcp_analysis_repo_get_snapshot_cluster_rows <- function(analysis_type, cluster_kind,
                                                        gene = NULL, cluster_id = NULL,
                                                        limit = 25L) {
  params <- if (identical(analysis_type, "functional_clusters")) list(algorithm = "leiden") else list()
  snapshot <- mcp_analysis_repo_get_public_snapshot(analysis_type, params)
  if (is.null(snapshot)) return(NULL)
  filters <- c("m.snapshot_id = ?", "m.cluster_kind = ?")
  values <- list(snapshot$manifest$snapshot_id[[1]], cluster_kind)
  if (!is.null(gene) && nzchar(trimws(as.character(gene)[1]))) {
    filters <- c(filters, "(UPPER(m.hgnc_id) = UPPER(?) OR UPPER(m.symbol) = UPPER(?))")
    values <- c(values, list(gene, gene))
  }
  if (!is.null(cluster_id) && nzchar(as.character(cluster_id)[1])) {
    filters <- c(filters, "m.cluster_id = ?")
    values <- c(values, list(as.character(cluster_id)[1]))
  }
  rows <- db_execute_query(
    paste(
      "SELECT m.cluster_id AS cluster, m.entity_id, m.hgnc_id, m.symbol,
              c.cluster_hash, c.cluster_size, c.label, c.metadata_json
         FROM mcp_public_analysis_cluster_member m
         JOIN mcp_public_analysis_cluster c
           ON c.snapshot_id = m.snapshot_id
          AND c.cluster_kind = m.cluster_kind
          AND c.cluster_id = m.cluster_id
        WHERE", paste(filters, collapse = " AND "),
      "ORDER BY m.cluster_id, m.member_rank LIMIT ?"
    ),
    unname(c(values, list(mcp_analysis_repo_limit(limit))))
  )
  list(records = rows, meta = mcp_analysis_repo_manifest_meta(snapshot))
}

mcp_analysis_repo_get_snapshot_phenotype_clusters <- function(gene = NULL, cluster_id = NULL, limit = 25L) {
  mcp_analysis_repo_get_snapshot_cluster_rows("phenotype_clusters", "phenotype", gene, cluster_id, limit)
}

mcp_analysis_repo_get_snapshot_functional_clusters <- function(gene = NULL, cluster_id = NULL, limit = 25L) {
  mcp_analysis_repo_get_snapshot_cluster_rows("functional_clusters", "functional", gene, cluster_id, limit)
}

mcp_analysis_repo_get_snapshot_phenotype_functional_correlations <- function(gene = NULL, limit = 25L) {
  rows <- mcp_analysis_repo_get_snapshot_correlations(
    "phenotype_functional_correlations", min_abs_correlation = NULL, limit = limit
  )
  if (is.null(rows) || is.null(gene) || nrow(rows) == 0L) return(rows)
  phenotype <- mcp_analysis_repo_get_snapshot_phenotype_clusters(gene = gene, limit = 50L)
  functional <- mcp_analysis_repo_get_snapshot_functional_clusters(gene = gene, limit = 50L)
  keys <- unique(c(
    paste0("pc_", phenotype$records$cluster %||% character()),
    paste0("fc_", functional$records$cluster %||% character())
  ))
  rows[rows$x %in% keys | rows$y %in% keys, , drop = FALSE]
}

mcp_analysis_repo_filter_gene_rows <- function(rows, gene) {
  if (is.null(gene) || !nzchar(trimws(as.character(gene)[1])) || is.null(rows) || nrow(rows) == 0L) return(rows)
  gene_value <- trimws(as.character(gene)[1])
  hgnc_value <- toupper(gene_value)
  if (grepl("^[0-9]+$", hgnc_value)) hgnc_value <- paste0("HGNC:", hgnc_value)
  keep <- rep(FALSE, nrow(rows))
  if ("hgnc_id" %in% names(rows)) keep <- keep | toupper(as.character(rows$hgnc_id)) == hgnc_value
  if ("symbol" %in% names(rows)) keep <- keep | toupper(as.character(rows$symbol)) == toupper(gene_value)
  rows[keep, , drop = FALSE]
}

mcp_analysis_repo_refresh_network_metadata <- function(network) {
  network$metadata <- network$metadata %||% list()
  network$nodes <- network$nodes %||% tibble::tibble()
  network$edges <- network$edges %||% tibble::tibble(source = character(), target = character(), confidence = numeric())
  network$metadata$node_count <- nrow(network$nodes)
  network$metadata$edge_count <- nrow(network$edges)
  if ("cluster" %in% names(network$nodes)) {
    network$metadata$cluster_count <- length(unique(stats::na.omit(network$nodes$cluster)))
  }
  network
}

mcp_analysis_repo_filter_network_gene <- function(network, gene) {
  network$metadata <- network$metadata %||% list()
  if (is.null(gene) || !nzchar(trimws(as.character(gene)[1]))) {
    network$metadata$gene_filtered <- FALSE
    return(mcp_analysis_repo_refresh_network_metadata(network))
  }
  matched <- mcp_analysis_repo_filter_gene_rows(network$nodes, gene)
  ids <- unique(as.character(matched$hgnc_id %||% character()))
  keep_edges <- network$edges$source %in% ids | network$edges$target %in% ids
  network$edges <- network$edges[keep_edges, , drop = FALSE]
  connected <- unique(c(network$edges$source, network$edges$target))
  network$nodes <- network$nodes[network$nodes$hgnc_id %in% connected, , drop = FALSE]
  network$metadata$gene_filtered <- TRUE
  network$metadata$gene_filter <- as.character(gene)[1]
  mcp_analysis_repo_refresh_network_metadata(network)
}
