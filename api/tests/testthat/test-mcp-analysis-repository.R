test_that("MCP LLM summary repository is cache-only and validated by default", {
  source("../../functions/mcp-analysis-repository.R")

  sql_seen <- character()
  old_query <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  assign("db_execute_query", function(sql, params = list()) {
    sql_seen <<- c(sql_seen, sql)
    tibble::tibble(
      cache_id = 7L,
      cluster_type = "functional",
      cluster_number = 3L,
      cluster_hash = "abc",
      model_name = "gemini-3-flash",
      prompt_version = "1.0",
      summary_json = "{\"summary\":\"cached\"}",
      tags = "[\"synaptic\"]",
      is_current = 1L,
      validation_status = "validated",
      created_at = as.POSIXct("2026-05-01 00:00:00", tz = "UTC"),
      validated_at = as.POSIXct("2026-05-02 00:00:00", tz = "UTC")
    )
  }, envir = .GlobalEnv)
  withr::defer(
    if (is.null(old_query)) rm("db_execute_query", envir = .GlobalEnv) else assign("db_execute_query", old_query, envir = .GlobalEnv)
  )

  result <- mcp_analysis_repo_get_cached_llm_summaries("functional", cluster_hashes = "abc")

  expect_equal(nrow(result), 1L)
  expect_true(any(grepl("llm_cluster_summary_cache", sql_seen, fixed = TRUE)))
  expect_true(any(grepl("validation_status = 'validated'", sql_seen, fixed = TRUE)))
  expect_false(any(grepl("get_or_generate_summary|chat_google_gemini|llm-service", sql_seen)))
})

test_that("MCP NDDScore repository delegates to active current-view helpers", {
  source("../../functions/mcp-analysis-repository.R")

  old_detail <- get0("nddscore_repo_gene_detail", envir = .GlobalEnv, ifnotfound = NULL)
  assign("nddscore_repo_gene_detail", function(hgnc_id_or_symbol) {
    list(
      gene = tibble::tibble(hgnc_id = "HGNC:61", gene_symbol = "ABCD1", ndd_score = 0.7),
      hpo_predictions = tibble::tibble(phenotype_id = "HP:0001250", probability = 0.4)
    )
  }, envir = .GlobalEnv)
  withr::defer(
    if (is.null(old_detail)) rm("nddscore_repo_gene_detail", envir = .GlobalEnv) else assign("nddscore_repo_gene_detail", old_detail, envir = .GlobalEnv)
  )

  result <- mcp_analysis_repo_get_nddscore_gene("HGNC:61")
  expect_equal(result$gene$gene_symbol[[1]], "ABCD1")
})
