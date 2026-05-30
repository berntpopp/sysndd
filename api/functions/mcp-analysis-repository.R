# functions/mcp-analysis-repository.R
#
# Read-only MCP analysis repository helpers. These helpers only delegate to
# existing read-only repositories or issue bounded SELECT statements.

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

mcp_analysis_repo_current_release <- function() {
  nddscore_repo_current_release()
}

mcp_analysis_repo_get_nddscore_gene <- function(gene) {
  nddscore_repo_gene_detail(gene)
}

mcp_analysis_repo_get_nddscore_genes <- function(filters = list(),
                                                 sort = "rank",
                                                 page = 1L,
                                                 page_size = 25L) {
  nddscore_repo_genes(filters = filters, sort = sort, page = page, page_size = page_size)
}

mcp_analysis_repo_get_comparison_metadata <- function() {
  db_execute_query(
    "SELECT last_full_refresh, last_refresh_status, sources_count, rows_imported
     FROM comparisons_metadata
     ORDER BY id DESC
     LIMIT 1",
    unname(list())
  )
}

mcp_analysis_repo_get_comparison_rows <- function(hgnc_id = NULL,
                                                  sources = NULL,
                                                  category = NULL,
                                                  page = 1L,
                                                  page_size = 25L) {
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
    bind_marks <- paste(rep("?", length(sources)), collapse = ", ")
    filters <- c(filters, sprintf("`list` IN (%s)", bind_marks))
    params <- c(params, as.list(sources))
  }

  where <- if (length(filters) > 0L) paste("WHERE", paste(filters, collapse = " AND ")) else ""
  offset <- (page - 1L) * page_size
  db_execute_query(
    paste(
      "SELECT hgnc_id, disease_ontology_id, inheritance, category, pathogenicity_mode, `list`, version",
      "FROM ndd_database_comparison_view",
      where,
      "ORDER BY hgnc_id, `list`, disease_ontology_id",
      "LIMIT ? OFFSET ?"
    ),
    unname(c(params, list(page_size, offset)))
  )
}

mcp_analysis_repo_count_comparison_rows <- function(hgnc_id = NULL,
                                                    sources = NULL,
                                                    category = NULL) {
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
    bind_marks <- paste(rep("?", length(sources)), collapse = ", ")
    filters <- c(filters, sprintf("`list` IN (%s)", bind_marks))
    params <- c(params, as.list(sources))
  }
  where <- if (length(filters) > 0L) paste("WHERE", paste(filters, collapse = " AND ")) else ""
  rows <- db_execute_query(
    paste("SELECT COUNT(*) AS total FROM ndd_database_comparison_view", where),
    unname(params)
  )
  as.integer(rows$total[[1]] %||% 0L)
}

mcp_analysis_repo_get_gene_external_identifiers <- function(hgnc_id) {
  db_execute_query(
    "
      SELECT hgnc_id, symbol, omim_id, ensembl_gene_id, uniprot_ids,
             STRING_id, mgd_id, rgd_id, mane_select,
             alphafold_id
      FROM non_alt_loci_set
      WHERE hgnc_id = ?
      LIMIT 1",
    unname(list(hgnc_id))
  )
}

mcp_analysis_repo_get_cached_llm_summaries <- function(cluster_type,
                                                       cluster_hashes = NULL,
                                                       cluster_numbers = NULL,
                                                       require_validated = TRUE,
                                                       limit = 10L) {
  filters <- c("cluster_type = ?", "is_current = TRUE")
  params <- list(cluster_type)
  if (isTRUE(require_validated)) {
    filters <- c(filters, "validation_status = 'validated'")
  }
  if (length(cluster_hashes %||% character()) > 0L) {
    bind_marks <- paste(rep("?", length(cluster_hashes)), collapse = ", ")
    filters <- c(filters, sprintf("cluster_hash IN (%s)", bind_marks))
    params <- c(params, as.list(cluster_hashes))
  }
  if (length(cluster_numbers %||% integer()) > 0L) {
    bind_marks <- paste(rep("?", length(cluster_numbers)), collapse = ", ")
    filters <- c(filters, sprintf("cluster_number IN (%s)", bind_marks))
    params <- c(params, as.list(cluster_numbers))
  }

  db_execute_query(
    paste(
      "SELECT cache_id, cluster_type, cluster_number, cluster_hash, model_name, prompt_version,",
      "summary_json, tags, is_current, validation_status, created_at, validated_at",
      "FROM llm_cluster_summary_cache",
      "WHERE", paste(filters, collapse = " AND "),
      "ORDER BY validated_at DESC, created_at DESC",
      "LIMIT ?"
    ),
    unname(c(params, list(limit)))
  )
}

mcp_analysis_repo_get_public_snapshot <- function(analysis_type, params = list()) {
  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
  snapshot <- analysis_snapshot_get_public(normalized$analysis_type, normalized$parameter_hash)
  if (is.null(snapshot) || !identical(snapshot$status_code %||% "available", "available")) {
    return(NULL)
  }
  list(normalized = normalized, snapshot = snapshot)
}

mcp_analysis_repo_shape_snapshot_network <- function(snapshot, max_edges = 10000L) {
  if (!exists("analysis_snapshot_shape_network", mode = "function")) {
    stop("analysis snapshot shaping service is not loaded", call. = FALSE)
  }
  analysis_snapshot_shape_network(snapshot, max_edges = max_edges)
}

mcp_analysis_repo_shape_snapshot_correlations <- function(snapshot,
                                                          min_abs_correlation = NULL,
                                                          drop_diagonal = TRUE,
                                                          triangle_only = FALSE) {
  if (!exists("analysis_snapshot_shape_correlations", mode = "function")) {
    stop("analysis snapshot shaping service is not loaded", call. = FALSE)
  }
  analysis_snapshot_shape_correlations(
    snapshot,
    min_abs_correlation = min_abs_correlation,
    drop_diagonal = drop_diagonal,
    triangle_only = triangle_only
  )
}

mcp_analysis_repo_shape_snapshot_phenotype_clusters <- function(snapshot) {
  if (!exists("analysis_snapshot_shape_phenotype_clusters", mode = "function")) {
    stop("analysis snapshot shaping service is not loaded", call. = FALSE)
  }
  analysis_snapshot_shape_phenotype_clusters(snapshot)
}

mcp_analysis_repo_get_snapshot_network <- function(gene = NULL, max_edges = 100L) {
  snapshot <- mcp_analysis_repo_get_public_snapshot(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = 400L, max_edges = 10000L)
  )
  if (is.null(snapshot)) {
    return(NULL)
  }

  network <- mcp_analysis_repo_shape_snapshot_network(snapshot$snapshot, max_edges = 10000L)
  network$metadata <- network$metadata %||% list()
  network$metadata$snapshot <- network$metadata$snapshot %||% (network$meta$snapshot %||% NULL)
  network <- mcp_analysis_repo_filter_network_gene(network, gene)
  if (!is.null(network$edges) && nrow(network$edges) > max_edges) {
    edge_order <- order(
      -network$edges$confidence,
      network$edges$source,
      network$edges$target
    )
    network$edges <- network$edges[edge_order, , drop = FALSE]
    network$edges <- utils::head(network$edges, max_edges)
    connected_nodes <- unique(c(network$edges$source, network$edges$target))
    network$nodes <- network$nodes[network$nodes$hgnc_id %in% connected_nodes, , drop = FALSE]
  }
  mcp_analysis_repo_refresh_network_metadata(network)
}

mcp_analysis_repo_get_snapshot_phenotype_correlations <- function(phenotype = NULL,
                                                                  min_abs_correlation = 0.3,
                                                                  drop_diagonal = TRUE,
                                                                  triangle_only = FALSE,
                                                                  limit = 25L) {
  snapshot <- mcp_analysis_repo_get_public_snapshot("phenotype_correlations", list())
  if (is.null(snapshot)) {
    return(NULL)
  }

  shaped <- mcp_analysis_repo_shape_snapshot_correlations(
    snapshot$snapshot,
    min_abs_correlation = min_abs_correlation,
    drop_diagonal = drop_diagonal,
    triangle_only = triangle_only
  )
  rows <- tibble::as_tibble(shaped$correlation_melted %||% tibble::tibble())
  if (nrow(rows) == 0L) {
    return(rows)
  }
  if (!is.null(phenotype) && nzchar(trimws(as.character(phenotype)[1]))) {
    phenotype <- trimws(as.character(phenotype)[1])
    rows <- rows %>%
      dplyr::filter(
        x == phenotype |
          y == phenotype |
          stringr::str_detect(x, stringr::fixed(phenotype, ignore_case = TRUE)) |
          stringr::str_detect(y, stringr::fixed(phenotype, ignore_case = TRUE))
      )
  }
  rows <- rows[order(-abs(rows$value), rows$x, rows$y), , drop = FALSE]
  utils::head(rows, mcp_analysis_repo_limit(limit))
}

mcp_analysis_repo_get_snapshot_phenotype_clusters <- function(gene = NULL,
                                                              cluster_id = NULL,
                                                              limit = 25L) {
  snapshot <- mcp_analysis_repo_get_public_snapshot("phenotype_clusters", list())
  if (is.null(snapshot)) {
    return(NULL)
  }

  shaped <- mcp_analysis_repo_shape_snapshot_phenotype_clusters(snapshot$snapshot)
  clusters <- tibble::as_tibble(shaped$clusters %||% tibble::tibble())
  if (nrow(clusters) == 0L || !"identifiers" %in% names(clusters)) {
    return(tibble::tibble())
  }

  rows <- clusters %>%
    tidyr::unnest(identifiers)
  rows <- mcp_analysis_repo_filter_gene_rows(rows, gene)
  if (!is.null(cluster_id) && nzchar(trimws(as.character(cluster_id)[1]))) {
    rows <- rows %>% dplyr::filter(as.character(cluster) == as.character(cluster_id)[1])
  }
  rows <- rows %>% dplyr::arrange(cluster, hgnc_id, entity_id)
  utils::head(rows, mcp_analysis_repo_limit(limit))
}

mcp_analysis_repo_get_snapshot_phenotype_functional_correlations <- function(gene = NULL,
                                                                             limit = 25L) {
  snapshot <- mcp_analysis_repo_get_public_snapshot("phenotype_functional_correlations", list())
  if (is.null(snapshot)) {
    return(NULL)
  }

  shaped <- mcp_analysis_repo_shape_snapshot_correlations(snapshot$snapshot, min_abs_correlation = NULL)
  rows <- tibble::as_tibble(shaped$correlation_melted %||% tibble::tibble())
  if (nrow(rows) == 0L) {
    return(rows)
  }

  if (!is.null(gene) && nzchar(trimws(as.character(gene)[1]))) {
    cluster_rows <- mcp_analysis_repo_get_snapshot_phenotype_clusters(gene = gene, limit = 50L)
    gene_clusters <- unique(as.character(cluster_rows$cluster %||% character()))
    gene_clusters <- gene_clusters[!is.na(gene_clusters) & nzchar(gene_clusters)]
    prefixed <- unique(c(gene_clusters, paste0("pc_", gene_clusters), paste0("phenotype_", gene_clusters)))
    if (length(prefixed) > 0L) {
      rows <- rows %>% dplyr::filter(x %in% prefixed | y %in% prefixed)
    }
  }

  rows <- rows[order(-abs(rows$value), rows$x, rows$y), , drop = FALSE]
  utils::head(rows, mcp_analysis_repo_limit(limit))
}

mcp_analysis_repo_filter_gene_rows <- function(rows, gene) {
  if (is.null(gene) || !nzchar(trimws(as.character(gene)[1])) || is.null(rows) || nrow(rows) == 0L) {
    return(rows)
  }

  gene_value <- trimws(as.character(gene)[1])
  hgnc_value <- toupper(gene_value)
  if (grepl("^[0-9]+$", hgnc_value)) {
    hgnc_value <- paste0("HGNC:", hgnc_value)
  }
  symbol_value <- toupper(gene_value)

  keep <- rep(FALSE, nrow(rows))
  if ("hgnc_id" %in% names(rows)) {
    keep <- keep | toupper(as.character(rows$hgnc_id)) == hgnc_value
  }
  if ("symbol" %in% names(rows)) {
    keep <- keep | toupper(as.character(rows$symbol)) == symbol_value
  }

  rows[keep, , drop = FALSE]
}

mcp_analysis_repo_limit <- function(limit, default = 25L, max = 50L) {
  limit <- suppressWarnings(as.integer(limit))
  if (is.na(limit) || limit < 1L) {
    return(default)
  }
  min(limit, max)
}

mcp_analysis_repo_get_phenotype_correlations <- function(phenotype = NULL,
                                                         min_abs_correlation = 0.3,
                                                         limit = 25L) {
  filter <- MCP_PHENOTYPE_CORRELATION_FILTER
  if (
    !mcp_analysis_repo_phenotype_correlations_cache_hit(filter = filter) ||
      !exists("generate_phenotype_correlations_mem", mode = "function")
  ) {
    return(NULL)
  }

  limit <- mcp_analysis_repo_limit(limit)

  rows <- tryCatch(
    generate_phenotype_correlations_mem(filter = filter, min_abs_correlation = NULL),
    error = function(e) NULL
  )
  if (is.null(rows) || nrow(rows) == 0L) {
    if (is.null(rows)) return(NULL)
    return(tibble::tibble())
  }

  if (!is.null(min_abs_correlation)) {
    rows <- rows %>% dplyr::filter(abs(value) >= min_abs_correlation)
  }

  if (!is.null(phenotype) && nzchar(trimws(as.character(phenotype)[1]))) {
    phenotype <- trimws(as.character(phenotype)[1])
    rows <- rows %>%
      dplyr::filter(
        x == phenotype |
          y == phenotype |
          x_id == phenotype |
          y_id == phenotype |
          stringr::str_detect(x, stringr::fixed(phenotype, ignore_case = TRUE)) |
          stringr::str_detect(y, stringr::fixed(phenotype, ignore_case = TRUE))
      )
  }

  rows <- rows[order(-abs(rows$value), rows$x, rows$y), , drop = FALSE]
  utils::head(rows, limit)
}

mcp_analysis_repo_get_phenotype_clusters <- function(gene = NULL,
                                                     cluster_id = NULL,
                                                     limit = 25L) {
  limit <- mcp_analysis_repo_limit(limit)

  clusters <- NULL
  if (mcp_analysis_repo_phenotype_memoise_cache_hit() && exists("generate_phenotype_clusters", mode = "function")) {
    clusters <- tryCatch(generate_phenotype_clusters(), error = function(e) NULL)
  }
  if (is.null(clusters)) {
    clusters <- mcp_analysis_repo_find_phenotype_cluster_disk_payload()
  }
  if (is.null(clusters)) {
    return(NULL)
  }
  if (nrow(clusters) == 0L || !"identifiers" %in% names(clusters)) {
    return(tibble::tibble())
  }

  rows <- clusters %>%
    tidyr::unnest(identifiers)

  rows <- mcp_analysis_repo_filter_gene_rows(rows, gene)

  if (!is.null(cluster_id) && nzchar(trimws(as.character(cluster_id)[1]))) {
    rows <- rows %>%
      dplyr::filter(as.character(cluster) == as.character(cluster_id)[1])
  }

  rows <- rows %>%
    dplyr::arrange(cluster, hgnc_id, entity_id)
  utils::head(rows, limit)
}

mcp_analysis_repo_get_phenotype_functional_correlations <- function(gene = NULL,
                                                                    limit = 25L) {
  limit <- mcp_analysis_repo_limit(limit)

  result <- NULL
  if (
    mcp_analysis_repo_functional_memoise_cache_hit(algorithm = "leiden") &&
      mcp_analysis_repo_phenotype_memoise_cache_hit() &&
      exists("generate_phenotype_functional_cluster_correlation", mode = "function")
  ) {
    result <- tryCatch(
      generate_phenotype_functional_cluster_correlation(
        include_membership = TRUE,
        include_sfari = FALSE
      ),
      error = function(e) NULL
    )
  }
  if (is.null(result)) {
    functional_clusters <- mcp_analysis_repo_find_functional_cluster_disk_payload()
    phenotype_clusters <- mcp_analysis_repo_find_phenotype_cluster_disk_payload()
    if (!is.null(functional_clusters) && !is.null(phenotype_clusters)) {
      result <- mcp_analysis_repo_compute_cluster_correlations(
        functional_clusters = functional_clusters,
        phenotype_clusters = phenotype_clusters,
        include_membership = TRUE
      )
    }
  }
  if (is.null(result)) {
    return(NULL)
  }
  rows <- result$correlation_melted %||% tibble::tibble()
  if (is.null(rows) || nrow(rows) == 0L) {
    return(tibble::tibble())
  }

  if (!is.null(gene) && nzchar(trimws(as.character(gene)[1]))) {
    membership <- mcp_analysis_repo_filter_gene_rows(result$cluster_membership %||% tibble::tibble(), gene)
    gene_clusters <- unique(membership$cluster %||% character())
    rows <- rows %>%
      dplyr::filter(x %in% gene_clusters | y %in% gene_clusters)
  }

  rows <- rows[order(-abs(rows$value), rows$x, rows$y), , drop = FALSE]
  utils::head(rows, limit)
}

mcp_analysis_repo_refresh_network_metadata <- function(network) {
  if (is.null(network$metadata)) network$metadata <- list()
  if (is.null(network$nodes)) network$nodes <- tibble::tibble()
  if (is.null(network$edges)) {
    network$edges <- tibble::tibble(source = character(), target = character(), confidence = numeric())
  }

  network$metadata$node_count <- nrow(network$nodes)
  network$metadata$edge_count <- nrow(network$edges)
  if ("cluster" %in% names(network$nodes)) {
    clusters <- unique(network$nodes$cluster[!is.na(network$nodes$cluster)])
    network$metadata$cluster_count <- length(clusters)
  }
  if ("category" %in% names(network$nodes)) {
    category_counts <- network$nodes %>%
      dplyr::filter(!is.na(category)) %>%
      dplyr::group_by(category) %>%
      dplyr::summarise(count = dplyr::n(), .groups = "drop")
    network$metadata$category_counts <- stats::setNames(
      as.list(category_counts$count),
      category_counts$category
    )
  }

  network
}

mcp_analysis_repo_filter_network_gene <- function(network, gene) {
  if (is.null(gene) || !nzchar(trimws(as.character(gene)[1]))) {
    network$metadata$gene_filtered <- FALSE
    return(mcp_analysis_repo_refresh_network_metadata(network))
  }

  if (is.null(network$nodes)) network$nodes <- tibble::tibble()
  if (is.null(network$edges)) {
    network$edges <- tibble::tibble(source = character(), target = character(), confidence = numeric())
  }
  if (is.null(network$metadata)) network$metadata <- list()

  matched_nodes <- mcp_analysis_repo_filter_gene_rows(network$nodes, gene)
  gene_ids <- unique(as.character(matched_nodes$hgnc_id %||% character()))
  gene_ids <- gene_ids[!is.na(gene_ids) & nzchar(gene_ids)]

  if (length(gene_ids) == 0L || nrow(network$edges) == 0L) {
    network$edges <- network$edges[0, , drop = FALSE]
    network$nodes <- network$nodes[0, , drop = FALSE]
  } else {
    network$edges <- network$edges[
      network$edges$source %in% gene_ids | network$edges$target %in% gene_ids,
      ,
      drop = FALSE
    ]
    connected_nodes <- unique(c(network$edges$source, network$edges$target))
    if ("hgnc_id" %in% names(network$nodes)) {
      network$nodes <- network$nodes[network$nodes$hgnc_id %in% connected_nodes, , drop = FALSE]
    }
  }

  network$metadata$gene_filtered <- TRUE
  network$metadata$gene_filter <- as.character(gene)[1]
  mcp_analysis_repo_refresh_network_metadata(network)
}

mcp_analysis_repo_get_network_edges_local <- function(cluster_type = "clusters",
                                                      min_confidence = 400L,
                                                      max_edges = 100L,
                                                      gene = NULL) {
  max_edges <- mcp_analysis_repo_limit(max_edges, default = 100L, max = 250L)

  network <- NULL
  if (
    mcp_analysis_repo_network_memoise_cache_hit(
      cluster_type = cluster_type,
      min_confidence = min_confidence
    ) &&
      exists("gen_network_edges_mem", mode = "function")
  ) {
    network <- tryCatch(
      gen_network_edges_mem(cluster_type = cluster_type, min_confidence = min_confidence),
      error = function(e) NULL
    )
  }
  if (is.null(network)) {
    network <- mcp_analysis_repo_find_network_disk_payload(
      cluster_type = cluster_type,
      min_confidence = min_confidence
    )
  }
  if (is.null(network)) {
    return(NULL)
  }
  network <- mcp_analysis_repo_filter_network_gene(network, gene)
  if (exists("limit_network_edges_response", mode = "function")) {
    network <- limit_network_edges_response(network, max_edges = max_edges)
  } else if (!is.null(network$edges) && nrow(network$edges) > max_edges) {
    network$edges <- network$edges[order(-network$edges$confidence), ]
    network$edges <- utils::head(network$edges, max_edges)
  }
  mcp_analysis_repo_refresh_network_metadata(network)
}
