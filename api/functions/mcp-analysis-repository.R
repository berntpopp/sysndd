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

mcp_analysis_repo_network_cache_hit <- function(cluster_type = "clusters",
                                                min_confidence = 400L) {
  if (!requireNamespace("memoise", quietly = TRUE)) return(FALSE)
  if (!exists("gen_network_edges_mem", mode = "function")) return(FALSE)
  if (!memoise::is.memoised(gen_network_edges_mem)) return(FALSE)
  checker <- memoise::has_cache(gen_network_edges_mem)
  isTRUE(checker(cluster_type = cluster_type, min_confidence = min_confidence))
}
