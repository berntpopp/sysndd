source_mcp_analysis_repository <- function() {
  source("../../functions/llm-summary-config.R")
  source("../../functions/analysis-snapshot-presets.R")
  source("../../functions/mcp-analysis-cache-repository.R")
  source("../../functions/mcp-analysis-repository.R")
}

restore_mcp_binding <- function(name, old_value) {
  if (is.null(old_value)) {
    if (exists(name, envir = .GlobalEnv, inherits = FALSE)) rm(list = name, envir = .GlobalEnv)
  } else {
    assign(name, old_value, envir = .GlobalEnv)
  }
}

test_that("analysis source version reads the public projection singleton", {
  source("../../functions/analysis-snapshot-repository.R")
  sql_seen <- character()
  old_query <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  assign("db_execute_query", function(sql, params = list(), conn = NULL) {
    sql_seen <<- c(sql_seen, sql)
    tibble::tibble(source_data_version = "source-v1")
  }, envir = .GlobalEnv)
  withr::defer(restore_mcp_binding("db_execute_query", old_query))

  expect_equal(analysis_snapshot_source_data_version(), "source-v1")
  expect_true(any(grepl("mcp_public_analysis_source_version", sql_seen, fixed = TRUE)))
  expect_false(any(grepl("ndd_entity_view|ndd_entity_review", sql_seen)))
})

test_that("MCP LLM summary reader uses the filtered projection and bound values", {
  source_mcp_analysis_repository()
  calls <- list()
  old_query <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  assign("db_execute_query", function(sql, params = list(), conn = NULL) {
    calls[[length(calls) + 1L]] <<- list(sql = sql, params = params)
    tibble::tibble()
  }, envir = .GlobalEnv)
  withr::defer(restore_mcp_binding("db_execute_query", old_query))

  mcp_analysis_repo_get_cached_llm_summaries(
    "functional", cluster_hashes = c("hash-a", "hash-b"), cluster_numbers = 3L
  )

  expect_match(calls[[1]]$sql, "FROM mcp_public_llm_cluster_summary", fixed = TRUE)
  expect_false(grepl("llm_cluster_summary_cache", calls[[1]]$sql, fixed = TRUE))
  expect_true(all(c("functional", "hash-a", "hash-b", 3L) %in% unlist(calls[[1]]$params)))
})

test_that("MCP NDDScore readers query only active-release projections", {
  source_mcp_analysis_repository()
  calls <- list()
  old_query <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  assign("db_execute_query", function(sql, params = list(), conn = NULL) {
    calls[[length(calls) + 1L]] <<- list(sql = sql, params = params)
    if (grepl("mcp_public_nddscore_release", sql, fixed = TRUE)) {
      return(tibble::tibble(release_id = 4L, activated_at = Sys.time()))
    }
    if (grepl("mcp_public_nddscore_gene_prediction", sql, fixed = TRUE) &&
        grepl("LIMIT 2", sql, fixed = TRUE)) {
      return(tibble::tibble(release_id = 4L, hgnc_id = "HGNC:61", gene_symbol = "ABCD1"))
    }
    if (grepl("mcp_public_nddscore_hpo_prediction", sql, fixed = TRUE)) {
      return(tibble::tibble(release_id = 4L, hgnc_id = "HGNC:61", phenotype_id = "HP:1"))
    }
    if (grepl("COUNT(*)", sql, fixed = TRUE)) return(tibble::tibble(total = 1L))
    tibble::tibble(release_id = 4L, hgnc_id = "HGNC:61", gene_symbol = "ABCD1", rank = 1L)
  }, envir = .GlobalEnv)
  withr::defer(restore_mcp_binding("db_execute_query", old_query))

  expect_equal(mcp_analysis_repo_current_release()$release_id[[1]], 4L)
  expect_equal(mcp_analysis_repo_get_nddscore_gene("ABCD1")$gene$hgnc_id[[1]], "HGNC:61")
  listed <- mcp_analysis_repo_get_nddscore_genes(
    filters = list(risk_tier = "high", search = "ABC"), sort = "-ndd_score"
  )
  expect_equal(listed$total, 1L)

  sql <- paste(vapply(calls, `[[`, character(1), "sql"), collapse = "\n")
  expect_match(sql, "mcp_public_nddscore_release")
  expect_match(sql, "mcp_public_nddscore_gene_prediction")
  expect_match(sql, "mcp_public_nddscore_hpo_prediction")
  expect_false(grepl("nddscore_repo_|nddscore_.*_current", sql))
})

test_that("MCP snapshot status depends only on eligible manifest projection rows", {
  source_mcp_analysis_repository()
  available <- TRUE
  calls <- list()
  old_query <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  assign("db_execute_query", function(sql, params = list(), conn = NULL) {
    calls[[length(calls) + 1L]] <<- list(sql = sql, params = params)
    if (!available) return(tibble::tibble())
    tibble::tibble(
      snapshot_id = 1L, analysis_type = params[[1]], parameter_hash = params[[2]],
      schema_version = "1.2", data_class = "curated_derived_analysis",
      generated_at = Sys.time(), activated_at = Sys.time(), stale_after = Sys.time() + 60,
      source_data_version = "v1", parameters_json = "{}", payload_hash = "p1",
      algorithm_name = "stored", algorithm_version = "1", row_counts_json = "{}"
    )
  }, envir = .GlobalEnv)
  withr::defer(restore_mcp_binding("db_execute_query", old_query))

  expect_equal(mcp_analysis_repo_public_snapshot_status("phenotype_correlations", list()), "available")
  available <- FALSE
  expect_equal(mcp_analysis_repo_public_snapshot_status("phenotype_correlations", list()), "snapshot_missing")
  sql <- paste(vapply(calls, `[[`, character(1), "sql"), collapse = "\n")
  expect_match(sql, "mcp_public_analysis_manifest")
  expect_false(grepl("analysis_snapshot_manifest", sql, fixed = TRUE))
})

test_that("MCP cluster reader joins projection rows with bound identifiers", {
  source_mcp_analysis_repository()
  calls <- list()
  old_query <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  assign("db_execute_query", function(sql, params = list(), conn = NULL) {
    calls[[length(calls) + 1L]] <<- list(sql = sql, params = params)
    if (grepl("mcp_public_analysis_manifest", sql, fixed = TRUE)) {
      return(tibble::tibble(
        snapshot_id = 7L, analysis_type = "phenotype_clusters", parameter_hash = params[[2]],
        schema_version = "1.2", data_class = "curated_derived_analysis",
        generated_at = Sys.time(), activated_at = Sys.time(), stale_after = Sys.time() + 60,
        source_data_version = "v1", parameters_json = "{}", payload_hash = "p1",
        algorithm_name = "hcpc", algorithm_version = "1", row_counts_json = "{}"
      ))
    }
    tibble::tibble(
      cluster = "3", entity_id = 1L, hgnc_id = "HGNC:1", symbol = "GENE1",
      cluster_hash = "h1", cluster_size = 1L, label = "cluster", metadata_json = "{}"
    )
  }, envir = .GlobalEnv)
  withr::defer(restore_mcp_binding("db_execute_query", old_query))

  result <- mcp_analysis_repo_get_snapshot_phenotype_clusters(
    gene = "GENE1", cluster_id = "3", limit = 5L
  )
  expect_equal(result$records$hgnc_id[[1]], "HGNC:1")
  sql <- calls[[2]]$sql
  expect_match(sql, "FROM mcp_public_analysis_cluster_member", fixed = TRUE)
  expect_match(sql, "JOIN mcp_public_analysis_cluster", fixed = TRUE)
  expect_true(all(c(7L, "phenotype", "GENE1", "3", 5L) %in% unlist(calls[[2]]$params)))
})

test_that("MCP correlation and network readers use normalized projection rows", {
  source_mcp_analysis_repository()
  calls <- list()
  old_query <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  assign("db_execute_query", function(sql, params = list(), conn = NULL) {
    calls[[length(calls) + 1L]] <<- list(sql = sql, params = params)
    if (grepl("mcp_public_analysis_manifest", sql, fixed = TRUE)) {
      return(tibble::tibble(
        snapshot_id = 9L, analysis_type = params[[1]], parameter_hash = params[[2]],
        schema_version = "1.2", data_class = "curated_derived_analysis",
        generated_at = Sys.time(), activated_at = Sys.time(), stale_after = Sys.time() + 60,
        source_data_version = "v1", parameters_json = "{}", payload_hash = "p1",
        algorithm_name = "stored", algorithm_version = "1", row_counts_json = "{}"
      ))
    }
    if (grepl("mcp_public_analysis_correlation", sql, fixed = TRUE)) {
      return(tibble::tibble(x = "HP:1", y = "HP:2", value = 0.8, correlation_kind = "phenotype", metadata_json = "{}"))
    }
    if (grepl("mcp_public_analysis_network_node", sql, fixed = TRUE)) {
      return(tibble::tibble(hgnc_id = c("HGNC:1", "HGNC:2"), symbol = c("A", "B"), cluster = "1", category = "Definitive"))
    }
    tibble::tibble(source = "HGNC:1", target = "HGNC:2", confidence = 900)
  }, envir = .GlobalEnv)
  withr::defer(restore_mcp_binding("db_execute_query", old_query))

  correlations <- mcp_analysis_repo_get_snapshot_phenotype_correlations(limit = 5L)
  expect_equal(correlations$value[[1]], 0.8)
  network <- mcp_analysis_repo_get_snapshot_network(gene = "HGNC:1", max_edges = 5L)
  expect_equal(network$metadata$edge_count, 1L)

  sql <- paste(vapply(calls, `[[`, character(1), "sql"), collapse = "\n")
  expect_match(sql, "mcp_public_analysis_correlation")
  expect_match(sql, "mcp_public_analysis_network_node")
  expect_match(sql, "mcp_public_analysis_network_edge")
})

test_that("MCP analysis repositories have no raw delegates or result-cache readers", {
  repository <- paste(readLines("../../functions/mcp-analysis-repository.R", warn = FALSE), collapse = "\n")
  retired <- paste(readLines("../../functions/mcp-analysis-cache-repository.R", warn = FALSE), collapse = "\n")

  expect_false(grepl("analysis_snapshot_get_public|nddscore_repo_|readRDS|memoise::|MCP_CACHE_DIR", repository))
  expect_false(grepl("readRDS|memoise::|MCP_CACHE_DIR|analysis_snapshot_manifest", retired))
  expect_false(grepl("(?i)\\b(?:FROM|JOIN)\\s+(?!mcp_public_)", repository, perl = TRUE))
})
