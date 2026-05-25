# functions/mcp-analysis-cache-repository.R
#
# Read-only disk-cache discovery for MCP analysis payloads. These helpers only
# read existing memoise/cachem RDS values and never compute or refresh analyses.

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

mcp_analysis_repo_cache_dir <- function() {
  Sys.getenv("MCP_CACHE_DIR", "/app/cache")
}

mcp_analysis_repo_read_cached_rds_value <- function(path) {
  cached <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(cached)) return(NULL)
  if (is.list(cached) && "value" %in% names(cached)) return(cached$value)
  cached
}

mcp_analysis_repo_find_disk_payload <- function(matches,
                                                cache_dir = mcp_analysis_repo_cache_dir(),
                                                max_files = 500L) {
  if (is.null(cache_dir) || !nzchar(cache_dir) || !dir.exists(cache_dir)) {
    return(NULL)
  }

  paths <- list.files(cache_dir, pattern = "[.]rds$", full.names = TRUE)
  if (length(paths) == 0L) return(NULL)

  info <- file.info(paths)
  paths <- paths[!is.na(info$mtime)]
  info <- info[!is.na(info$mtime), , drop = FALSE]
  if (length(paths) == 0L) return(NULL)

  paths <- paths[order(info$mtime, decreasing = TRUE)]
  paths <- utils::head(paths, max(1L, as.integer(max_files)))

  for (path in paths) {
    payload <- mcp_analysis_repo_read_cached_rds_value(path)
    if (isTRUE(matches(payload))) return(payload)
  }

  NULL
}

mcp_analysis_repo_network_payload_matches <- function(network,
                                                      cluster_type = "clusters",
                                                      min_confidence = 400L) {
  if (!is.list(network)) return(FALSE)
  if (!all(c("nodes", "edges", "metadata") %in% names(network))) return(FALSE)
  if (!is.list(network$metadata)) return(FALSE)

  payload_min_confidence <- suppressWarnings(as.integer(network$metadata$min_confidence %||% NA_integer_))
  if (is.na(payload_min_confidence) || payload_min_confidence != as.integer(min_confidence)) {
    return(FALSE)
  }

  payload_cluster_type <- network$metadata$cluster_type %||% NULL
  if (!is.null(payload_cluster_type)) {
    return(identical(as.character(payload_cluster_type)[1], as.character(cluster_type)[1]))
  }

  identical(as.character(cluster_type)[1], "clusters")
}

mcp_analysis_repo_find_network_disk_payload <- function(cluster_type = "clusters",
                                                        min_confidence = 400L) {
  network <- mcp_analysis_repo_find_disk_payload(function(payload) {
    mcp_analysis_repo_network_payload_matches(
      payload,
      cluster_type = cluster_type,
      min_confidence = min_confidence
    )
  })
  if (is.null(network)) return(NULL)
  network$metadata$cache_source <- "disk_payload_scan"
  network
}

mcp_analysis_repo_phenotype_cluster_payload_matches <- function(payload) {
  is.data.frame(payload) &&
    all(c("cluster", "identifiers", "hash_filter", "cluster_size") %in% names(payload)) &&
    "quali_inp_var" %in% names(payload) &&
    !"term_enrichment" %in% names(payload)
}

mcp_analysis_repo_functional_cluster_payload_matches <- function(payload) {
  is.data.frame(payload) &&
    all(c("cluster", "identifiers", "hash_filter", "cluster_size") %in% names(payload)) &&
    "term_enrichment" %in% names(payload)
}

mcp_analysis_repo_find_phenotype_cluster_disk_payload <- function() {
  payload <- mcp_analysis_repo_find_disk_payload(mcp_analysis_repo_phenotype_cluster_payload_matches)
  mcp_analysis_repo_enrich_phenotype_cluster_payload(payload)
}

mcp_analysis_repo_find_functional_cluster_disk_payload <- function() {
  mcp_analysis_repo_find_disk_payload(mcp_analysis_repo_functional_cluster_payload_matches)
}

mcp_analysis_repo_enrich_phenotype_cluster_payload <- function(payload) {
  if (is.null(payload) || nrow(payload) == 0L || !"identifiers" %in% names(payload)) {
    return(payload)
  }

  identifiers <- tryCatch(tidyr::unnest(payload, identifiers), error = function(e) NULL)
  if (is.null(identifiers) || "hgnc_id" %in% names(identifiers)) {
    return(payload)
  }
  if (!"entity_id" %in% names(identifiers) || !exists("generate_phenotype_cluster_input", mode = "function")) {
    return(payload)
  }

  input <- tryCatch(generate_phenotype_cluster_input(), error = function(e) NULL)
  gene_map <- input$entity_gene_map %||% NULL
  if (is.null(gene_map) || nrow(gene_map) == 0L || !"entity_id" %in% names(gene_map)) {
    return(payload)
  }

  identifiers %>%
    dplyr::mutate(entity_id = as.integer(entity_id)) %>%
    dplyr::left_join(gene_map, by = "entity_id") %>%
    tidyr::nest(identifiers = c(entity_id, hgnc_id, symbol))
}

mcp_analysis_repo_network_memoise_cache_hit <- function(cluster_type = "clusters",
                                                        min_confidence = 400L) {
  if (!requireNamespace("memoise", quietly = TRUE)) return(FALSE)
  if (!exists("gen_network_edges_mem", mode = "function")) return(FALSE)
  if (!memoise::is.memoised(gen_network_edges_mem)) return(FALSE)
  checker <- memoise::has_cache(gen_network_edges_mem)
  isTRUE(checker(cluster_type = cluster_type, min_confidence = min_confidence))
}

mcp_analysis_repo_functional_memoise_cache_hit <- function(algorithm = "leiden") {
  if (!requireNamespace("memoise", quietly = TRUE)) return(FALSE)
  if (!exists("gen_string_clust_obj_mem", mode = "function")) return(FALSE)
  if (!exists("generate_ndd_hgnc_ids", mode = "function")) return(FALSE)
  if (!memoise::is.memoised(gen_string_clust_obj_mem)) return(FALSE)

  genes <- tryCatch(generate_ndd_hgnc_ids(), error = function(e) NULL)
  if (is.null(genes) || is.null(genes$hgnc_id)) return(FALSE)

  checker <- memoise::has_cache(gen_string_clust_obj_mem)
  isTRUE(checker(genes$hgnc_id, algorithm = algorithm))
}

mcp_analysis_repo_phenotype_memoise_cache_hit <- function() {
  if (!requireNamespace("memoise", quietly = TRUE)) return(FALSE)
  if (!exists("gen_mca_clust_obj_mem", mode = "function")) return(FALSE)
  if (!exists("generate_phenotype_cluster_input", mode = "function")) return(FALSE)
  if (!memoise::is.memoised(gen_mca_clust_obj_mem)) return(FALSE)

  input <- tryCatch(generate_phenotype_cluster_input(), error = function(e) NULL)
  if (is.null(input) || is.null(input$matrix) || nrow(input$matrix) == 0L) {
    return(FALSE)
  }

  checker <- memoise::has_cache(gen_mca_clust_obj_mem)
  isTRUE(checker(input$matrix))
}

MCP_PHENOTYPE_CORRELATION_FILTER <- "contains(ndd_phenotype_word,Yes),any(category,Definitive)"

mcp_analysis_repo_phenotype_correlations_cache_hit <- function(filter = MCP_PHENOTYPE_CORRELATION_FILTER) {
  if (!requireNamespace("memoise", quietly = TRUE)) return(FALSE)
  if (!exists("generate_phenotype_correlations_mem", mode = "function")) return(FALSE)
  if (!memoise::is.memoised(generate_phenotype_correlations_mem)) return(FALSE)

  checker <- memoise::has_cache(generate_phenotype_correlations_mem)
  isTRUE(checker(filter = filter, min_abs_correlation = NULL))
}

mcp_analysis_repo_network_cache_hit <- function(cluster_type = "clusters",
                                                min_confidence = 400L) {
  mcp_analysis_repo_network_memoise_cache_hit(
    cluster_type = cluster_type,
    min_confidence = min_confidence
  ) ||
    !is.null(mcp_analysis_repo_find_network_disk_payload(
      cluster_type = cluster_type,
      min_confidence = min_confidence
    ))
}

mcp_analysis_repo_functional_cluster_cache_hit <- function(algorithm = "leiden") {
  mcp_analysis_repo_functional_memoise_cache_hit(algorithm = algorithm) ||
    !is.null(mcp_analysis_repo_find_functional_cluster_disk_payload())
}

mcp_analysis_repo_phenotype_cluster_cache_hit <- function() {
  mcp_analysis_repo_phenotype_memoise_cache_hit() ||
    !is.null(mcp_analysis_repo_find_phenotype_cluster_disk_payload())
}

mcp_analysis_repo_cluster_membership <- function(clusters, prefix) {
  if (is.null(clusters) || nrow(clusters) == 0L || !"identifiers" %in% names(clusters)) {
    return(tibble::tibble(cluster = character(), hgnc_id = character()))
  }

  clusters %>%
    dplyr::select(cluster, identifiers) %>%
    tidyr::unnest(identifiers) %>%
    dplyr::mutate(cluster = paste0(prefix, "_", cluster)) %>%
    dplyr::select(cluster, hgnc_id) %>%
    dplyr::filter(!is.na(hgnc_id)) %>%
    unique()
}

mcp_analysis_repo_compute_cluster_correlations <- function(functional_clusters,
                                                           phenotype_clusters,
                                                           include_membership = FALSE) {
  all_clusters <- dplyr::bind_rows(
    mcp_analysis_repo_cluster_membership(functional_clusters, "fc"),
    mcp_analysis_repo_cluster_membership(phenotype_clusters, "pc")
  )

  if (nrow(all_clusters) == 0L) {
    result <- list(
      correlation_melted = tibble::tibble(x = character(), y = character(), value = numeric()),
      cluster_membership = all_clusters
    )
    if (!isTRUE(include_membership)) result$cluster_membership <- NULL
    return(result)
  }

  cluster_matrix <- all_clusters %>%
    dplyr::mutate(has_hgnc_id = 1L) %>%
    unique() %>%
    tidyr::pivot_wider(names_from = cluster, values_from = has_hgnc_id) %>%
    dplyr::mutate(dplyr::across(-hgnc_id, ~ tidyr::replace_na(.x, 0))) %>%
    dplyr::select(-hgnc_id)

  correlation_matrix <- round(stats::cor(cluster_matrix), 2)
  correlation_melted <- as.data.frame(as.table(correlation_matrix), stringsAsFactors = FALSE) %>%
    dplyr::select(x = Var1, y = Var2, value = Freq)

  result <- list(correlation_melted = correlation_melted, cluster_membership = all_clusters)
  if (!isTRUE(include_membership)) result$cluster_membership <- NULL
  result
}
