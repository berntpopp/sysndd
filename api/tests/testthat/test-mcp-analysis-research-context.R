# Gene research-context aggregation tests are split from
# test-mcp-analysis-service.R to keep each focused test file under 600 lines.
source(file.path(
  get_api_dir(),
  "tests", "testthat", "mcp-analysis-service-fixtures.R"
), local = TRUE)

test_that("gene research context aggregates requested sections with explicit section statuses", {
  source("../../functions/mcp-repository.R")
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_gene <- mcp_get_gene_context
  old_ndd <- mcp_get_nddscore_context
  old_comp <- mcp_get_curation_comparison_context
  old_net <- mcp_get_gene_network_context
  assign("mcp_get_gene_context", function(gene, ...) {
    list(schema_version = MCP_SCHEMA_VERSION, gene = list(hgnc_id = "HGNC:61", symbol = "ABCD1"), entities = list())
  }, envir = .GlobalEnv)
  assign("mcp_get_nddscore_context", function(gene, ...) {
    list(data_class = "ml_prediction", gene = list(hgnc_id = "HGNC:61"))
  }, envir = .GlobalEnv)
  assign("mcp_get_curation_comparison_context", function(gene, ...) {
    list(data_class = "curated_derived_analysis", rows = list())
  }, envir = .GlobalEnv)
  assign("mcp_get_gene_network_context", function(gene, ...) {
    list(section_status = "temporarily_unavailable", edges = list())
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_get_gene_context", old_gene, envir = .GlobalEnv)
    assign("mcp_get_nddscore_context", old_ndd, envir = .GlobalEnv)
    assign("mcp_get_curation_comparison_context", old_comp, envir = .GlobalEnv)
    assign("mcp_get_gene_network_context", old_net, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_research_context(
    gene = "HGNC:61",
    sections = c("curated", "comparison", "nddscore", "gene_network")
  )

  expect_equal(result$gene$symbol, "ABCD1")
  expect_equal(result$section_status$curated, "available")
  expect_equal(result$section_status$nddscore, "available")
  expect_equal(result$section_status$gene_network, "temporarily_unavailable")
  expect_false(is.null(result$sections$nddscore))
  expect_false(is.null(result$budget))
  expect_equal(result$meta$response_mode, "compact")
})

test_that("gene research phenotype correlations use global snapshot context", {
  source("../../functions/mcp-repository.R")
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_gene <- mcp_get_gene_context
  old_phenotype <- mcp_get_phenotype_analysis_context
  seen_gene <- "not-called"
  assign("mcp_get_gene_context", function(gene, ...) {
    list(schema_version = MCP_SCHEMA_VERSION, gene = list(hgnc_id = "HGNC:61", symbol = "ABCD1"), entities = list())
  }, envir = .GlobalEnv)
  assign("mcp_get_phenotype_analysis_context", function(mode, gene = NULL, ...) {
    expect_equal(mode, "correlations")
    seen_gene <<- gene
    list(section_status = "available", records = list(list(x = "Seizure", y = "Ataxia", value = 0.42)))
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_get_gene_context", old_gene, envir = .GlobalEnv)
    assign("mcp_get_phenotype_analysis_context", old_phenotype, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_research_context(gene = "HGNC:61", sections = "phenotype_correlations")

  expect_null(seen_gene)
  expect_equal(result$section_status$phenotype_correlations, "available")
  expect_equal(result$sections$phenotype_correlations$records[[1]]$value, 0.42)
})

test_that("gene research dry-run returns statuses and budget without bulky section rows", {
  source("../../functions/mcp-repository.R")
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_gene <- mcp_get_gene_context
  assign("mcp_get_gene_context", function(gene, ...) {
    list(schema_version = MCP_SCHEMA_VERSION, gene = list(hgnc_id = "HGNC:61", symbol = "ABCD1"), entities = list())
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_get_gene_context", old_gene, envir = .GlobalEnv))

  result <- mcp_get_gene_research_context(
    gene = "HGNC:61",
    sections = c("curated", "nddscore", "gene_network"),
    dry_run = TRUE,
    include_diagnostics = TRUE
  )

  expect_equal(result$section_status$curated, "available")
  expect_true(result$meta$dry_run)
  expect_equal(result$sections, list())
  expect_false(is.null(result$budget$estimated_tokens))
})

test_that("gene research dry-run probes section availability instead of assuming available", {
  source("../../functions/mcp-repository.R")
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_gene <- mcp_get_gene_context
  old_ndd <- mcp_get_nddscore_context
  assign("mcp_get_gene_context", function(gene, ...) {
    list(schema_version = MCP_SCHEMA_VERSION, gene = list(hgnc_id = "HGNC:61", symbol = "ABCD1"), entities = list())
  }, envir = .GlobalEnv)
  assign("mcp_get_nddscore_context", function(...) {
    stop(mcp_error("temporarily_unavailable", "No active NDDScore release is available."))
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_get_gene_context", old_gene, envir = .GlobalEnv)
    assign("mcp_get_nddscore_context", old_ndd, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_research_context(
    gene = "HGNC:61",
    sections = c("curated", "nddscore"),
    dry_run = TRUE
  )

  expect_equal(result$section_status$curated, "available")
  expect_equal(result$section_status$nddscore, "temporarily_unavailable")
})

test_that("gene research dry-run reports phenotype cache unavailability explicitly", {
  source_mcp_analysis_repository()
  source("../../services/mcp-research-context-service.R")

  old_gene <- mcp_get_gene_context
  old_cluster_hit <- mcp_analysis_repo_phenotype_cluster_cache_hit
  old_snapshot_available <- mcp_analysis_repo_public_snapshot_available
  assign("mcp_get_gene_context", function(gene, ...) {
    list(schema_version = MCP_SCHEMA_VERSION, gene = list(hgnc_id = "HGNC:61", symbol = "ABCD1"), entities = list())
  }, envir = .GlobalEnv)
  assign("mcp_analysis_repo_phenotype_cluster_cache_hit", function(...) FALSE, envir = .GlobalEnv)
  assign("mcp_analysis_repo_public_snapshot_available", function(...) FALSE, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_get_gene_context", old_gene, envir = .GlobalEnv)
    assign("mcp_analysis_repo_phenotype_cluster_cache_hit", old_cluster_hit, envir = .GlobalEnv)
    assign("mcp_analysis_repo_public_snapshot_available", old_snapshot_available, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_research_context(
    gene = "HGNC:61",
    sections = c("phenotype_clusters", "phenotype_functional_correlations", "cached_llm_summaries"),
    dry_run = TRUE
  )

  expect_equal(result$section_status$phenotype_clusters, "temporarily_unavailable")
  expect_equal(result$section_status$phenotype_functional_correlations, "temporarily_unavailable")
  expect_equal(result$section_status$cached_llm_summaries, "temporarily_unavailable")
})

test_that("gene research validates public limits before wrapping section errors", {
  source("../../services/mcp-research-context-service.R")

  err <- tryCatch(
    mcp_get_gene_research_context(gene = "HGNC:61", entity_limit = 0L),
    mcp_tool_error = function(e) unclass(e)
  )

  expect_equal(err$error$code, "invalid_input")
  expect_equal(err$error$argument, "entity_limit")
})

test_that("gene research cached LLM section can derive phenotype cluster numbers without returning clusters", {
  source("../../functions/mcp-repository.R")
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_gene <- mcp_get_gene_context
  old_phenotype <- mcp_get_phenotype_analysis_context
  old_summaries <- mcp_get_cached_llm_summaries
  seen_cluster_numbers <- NULL
  assign("mcp_get_gene_context", function(gene, ...) {
    list(schema_version = MCP_SCHEMA_VERSION, gene = list(hgnc_id = "HGNC:61", symbol = "ABCD1"), entities = list())
  }, envir = .GlobalEnv)
  assign("mcp_get_phenotype_analysis_context", function(mode, ...) {
    expect_equal(mode, "clusters")
    list(records = list(list(cluster = 7L)))
  }, envir = .GlobalEnv)
  assign("mcp_get_cached_llm_summaries", function(cluster_type, cluster_numbers = NULL, ...) {
    seen_cluster_numbers <<- cluster_numbers
    list(list(data_class = "llm_generated_summary", cache_only = TRUE, cluster_number = cluster_numbers[[1]]))
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_get_gene_context", old_gene, envir = .GlobalEnv)
    assign("mcp_get_phenotype_analysis_context", old_phenotype, envir = .GlobalEnv)
    assign("mcp_get_cached_llm_summaries", old_summaries, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_research_context(gene = "HGNC:61", sections = "cached_llm_summaries")

  expect_equal(seen_cluster_numbers, 7L)
  expect_equal(result$section_status$cached_llm_summaries, "available")
  expect_equal(result$sections$cached_llm_summaries[[1]]$cluster_number, 7L)
  expect_true(is.null(result$sections$phenotype_clusters))
})

test_that("gene research cached LLM section handles disabled and unavailable cluster lookups explicitly", {
  source("../../functions/mcp-repository.R")
  source_mcp_analysis_repository()
  source("../../services/mcp-research-context-service.R")

  old_gene <- mcp_get_gene_context
  old_phenotype <- mcp_get_phenotype_analysis_context
  assign("mcp_get_gene_context", function(gene, ...) {
    list(schema_version = MCP_SCHEMA_VERSION, gene = list(hgnc_id = "HGNC:61", symbol = "ABCD1"), entities = list())
  }, envir = .GlobalEnv)
  assign("mcp_get_phenotype_analysis_context", function(...) {
    stop(mcp_error("temporarily_unavailable", "Phenotype cluster cache unavailable."))
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_get_gene_context", old_gene, envir = .GlobalEnv)
    assign("mcp_get_phenotype_analysis_context", old_phenotype, envir = .GlobalEnv)
  })

  disabled <- mcp_get_gene_research_context(
    gene = "HGNC:61",
    sections = "cached_llm_summaries",
    include_cached_llm_summaries = FALSE
  )
  unavailable <- mcp_get_gene_research_context(gene = "HGNC:61", sections = "cached_llm_summaries")

  expect_equal(disabled$section_status$cached_llm_summaries, "disabled_by_request")
  expect_true(is.null(disabled$sections$cached_llm_summaries))
  expect_equal(unavailable$section_status$cached_llm_summaries, "temporarily_unavailable")
  expect_equal(unavailable$sections$cached_llm_summaries$error$code, "temporarily_unavailable")
})

test_that("gene research marks budget-dropped sections and returns recovery hints", {
  source("../../functions/mcp-repository.R")
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_gene <- mcp_get_gene_context
  old_ndd <- mcp_get_nddscore_context
  assign("mcp_get_gene_context", function(gene, ...) {
    list(schema_version = MCP_SCHEMA_VERSION, gene = list(hgnc_id = "HGNC:61", symbol = "ABCD1"), entities = list())
  }, envir = .GlobalEnv)
  assign("mcp_get_nddscore_context", function(gene, ...) {
    list(data_class = "ml_prediction", gene = list(hgnc_id = "HGNC:61"), payload = paste(rep("x", 2000), collapse = ""))
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_get_gene_context", old_gene, envir = .GlobalEnv)
    assign("mcp_get_nddscore_context", old_ndd, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_research_context(
    gene = "HGNC:61",
    sections = c("curated", "nddscore"),
    max_response_chars = 1000L
  )

  expect_true(result$budget$truncated)
  expect_equal(result$section_status$nddscore, "dropped_by_budget")
  expect_true(is.null(result$sections$nddscore))
  expect_false(is.null(result$recovery$retry_with))
  expect_gte(result$budget$total_chars, mcp_analysis_estimate_chars(result))
})
