source("../../services/mcp-service.R")
source("../../services/mcp-analysis-shaping.R")
source("../../services/mcp-query-service.R")
source("../../services/mcp-record-service.R")
source("../../services/mcp-analysis-service.R")
source("../../services/mcp-research-context-service.R")

test_that("MCP analysis data-class envelopes distinguish curated, derived, ML, and LLM data", {
  source("../../services/mcp-service.R")

  curated <- mcp_analysis_provenance(
    data_class = "curated_sysndd_evidence",
    source = "SysNDD",
    source_table_or_view = "ndd_entity_view",
    generated_by = "human_curation"
  )
  expect_equal(curated$data_class, "curated_sysndd_evidence")
  expect_equal(curated$curation_effect, "curated_evidence")
  expect_false(curated$not_evidence_tier)

  ml <- mcp_analysis_provenance(
    data_class = "ml_prediction",
    source = "NDDScore",
    source_table_or_view = "nddscore_gene_prediction_current",
    generated_by = "nddscore_model"
  )
  expect_equal(ml$curation_effect, "none")
  expect_true(ml$not_evidence_tier)
  expect_match(ml$limitations[[1]], "Not an evidence tier", fixed = TRUE)

  llm <- mcp_analysis_provenance(
    data_class = "llm_generated_summary",
    source = "SysNDD LLM summary cache",
    source_table_or_view = "llm_cluster_summary_cache",
    generated_by = "admin_llm_workflow"
  )
  expect_true(llm$not_evidence_tier)
  expect_match(llm$limitations[[1]], "Cache-only", fixed = TRUE)
})

test_that("MCP analysis response budgets support auto, diagnostics, and truncation metadata", {
  source("../../services/mcp-service.R")

  compact <- mcp_analysis_response_budget("compact", "auto")
  expect_equal(compact$response_mode, "compact")
  expect_true(compact$max_response_chars > 0L)

  diagnostics <- mcp_analysis_response_budget("diagnostics", "auto")
  expect_equal(diagnostics$response_mode, "diagnostics")
  expect_true(diagnostics$diagnostics_only)

  records <- replicate(
    10,
    list(id = "row", text = paste(rep("x", 200), collapse = "")),
    simplify = FALSE
  )
  trimmed <- mcp_analysis_trim_records(records, max_records = 3L, budget = compact)
  expect_length(trimmed$records, 3L)
  expect_true(trimmed$budget$dropped_records >= 7L)
  expect_true(length(trimmed$budget$dropped_summary) > 0L)

  tiny <- mcp_analysis_response_budget("compact", 1000L)
  oversized <- replicate(
    5,
    list(id = "row", text = paste(rep("y", 900), collapse = "")),
    simplify = FALSE
  )
  char_trimmed <- mcp_analysis_trim_records(oversized, max_records = 5L, budget = tiny)
  expect_true(char_trimmed$budget$truncated)
  expect_true(char_trimmed$budget$total_chars <= tiny$max_response_chars || length(char_trimmed$records) == 1L)

  sections <- list(
    curated = list(text = paste(rep("a", 900), collapse = "")),
    nddscore = list(text = paste(rep("b", 900), collapse = "")),
    gene_network = list(text = paste(rep("c", 900), collapse = ""))
  )
  section_trimmed <- mcp_analysis_trim_sections(
    sections,
    priority = c("curated", "nddscore", "gene_network"),
    budget = tiny
  )
  expect_true(section_trimmed$budget$truncated)
  expect_true(length(section_trimmed$sections) < length(sections))
})

test_that("analysis catalog advertises approved scope B tools and data classes", {
  source("../../services/mcp-service.R")

  catalog <- mcp_get_sysndd_analysis_catalog()
  ids <- vapply(catalog$analyses, `[[`, character(1), "analysis_id")

  expect_equal(catalog$schema_version, MCP_SCHEMA_VERSION)
  expect_true("nddscore" %in% ids)
  expect_true("gene_research_context" %in% ids)
  expect_true("cached_llm_summaries" %in% ids)
  expect_false(any(grepl("generate|prompt|gemini", ids, ignore.case = TRUE)))
  expect_true(all(vapply(catalog$analyses, function(x) !is.null(x$default_limits), logical(1))))
  expect_true(all(vapply(catalog$analyses, function(x) !is.null(x$example_call), logical(1))))
  expect_equal(catalog$recommended_workflow[[1]], "Call get_sysndd_analysis_catalog first for scope and limits.")
})

test_that("NDDScore MCP context is always marked as ML prediction and not evidence tier", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_release <- mcp_analysis_repo_current_release
  old_gene <- mcp_analysis_repo_get_nddscore_gene
  assign("mcp_analysis_repo_current_release", function() {
    tibble::tibble(release_id = "rel1", version = "2026.05", is_active = 1L)
  }, envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_nddscore_gene", function(gene) {
    list(
      gene = tibble::tibble(hgnc_id = "HGNC:61", gene_symbol = "ABCD1", ndd_score = 0.7),
      hpo_predictions = tibble::tibble(phenotype_id = "HP:0001250", probability = 0.4)
    )
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_current_release", old_release, envir = .GlobalEnv)
    assign("mcp_analysis_repo_get_nddscore_gene", old_gene, envir = .GlobalEnv)
  })

  result <- mcp_get_nddscore_context(gene = "HGNC:61")

  expect_equal(result$data_class, "ml_prediction")
  expect_equal(result$curation_effect, "none")
  expect_true(result$not_evidence_tier)
  expect_match(result$notice, "Separate from curated SysNDD evidence", fixed = TRUE)
})

test_that("curation comparison context returns bounded rows with derived-analysis labels", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_rows <- mcp_analysis_repo_get_comparison_rows
  old_count <- mcp_analysis_repo_count_comparison_rows
  old_meta <- mcp_analysis_repo_get_comparison_metadata
  assign("mcp_analysis_repo_get_comparison_rows", function(...) {
    tibble::tibble(hgnc_id = "HGNC:61", list = "SysNDD", category = "Definitive")
  }, envir = .GlobalEnv)
  assign("mcp_analysis_repo_count_comparison_rows", function(...) 1L, envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_comparison_metadata", function() tibble::tibble(last_refresh_status = "success"), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_get_comparison_rows", old_rows, envir = .GlobalEnv)
    assign("mcp_analysis_repo_count_comparison_rows", old_count, envir = .GlobalEnv)
    assign("mcp_analysis_repo_get_comparison_metadata", old_meta, envir = .GlobalEnv)
  })

  result <- mcp_get_curation_comparison_context(gene = "HGNC:61")
  expect_equal(result$data_class, "curated_derived_analysis")
  expect_equal(result$rows[[1]]$hgnc_id, "HGNC:61")
  expect_equal(result$meta$total, 1L)
})

test_that("MCP LLM summary service returns cached validated summaries and never generates", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_cache <- mcp_analysis_repo_get_cached_llm_summaries
  assign("mcp_analysis_repo_get_cached_llm_summaries", function(...) {
    tibble::tibble(
      cache_id = 7L,
      cluster_type = "functional",
      cluster_number = 3L,
      cluster_hash = "abc",
      model_name = "gemini-3-flash",
      prompt_version = "1.0",
      summary_json = "{\"summary\":\"cached summary\"}",
      tags = "[\"synaptic\"]",
      is_current = 1L,
      validation_status = "validated",
      created_at = as.POSIXct("2026-05-01 00:00:00", tz = "UTC"),
      validated_at = as.POSIXct("2026-05-02 00:00:00", tz = "UTC")
    )
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_get_cached_llm_summaries", old_cache, envir = .GlobalEnv))

  result <- mcp_get_cached_llm_summaries("functional", cluster_hashes = "abc")

  expect_true(result[[1]]$summary_available)
  expect_equal(result[[1]]$data_class, "llm_generated_summary")
  expect_true(result[[1]]$cache_only)
  expect_equal(result[[1]]$summary$summary, "cached summary")
})

test_that("MCP LLM summary service reports cache miss without generation", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_cache <- mcp_analysis_repo_get_cached_llm_summaries
  assign("mcp_analysis_repo_get_cached_llm_summaries", function(...) tibble::tibble(), envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_get_cached_llm_summaries", old_cache, envir = .GlobalEnv))

  result <- mcp_get_cached_llm_summaries("phenotype", cluster_numbers = 1L)

  expect_false(result[[1]]$summary_available)
  expect_true(result[[1]]$cache_only)
  expect_equal(result[[1]]$data_class, "llm_generated_summary")
})

test_that("phenotype analysis context validates mode and labels derived analyses", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_corr <- mcp_analysis_repo_get_phenotype_correlations
  assign("mcp_analysis_repo_get_phenotype_correlations", function(...) {
    tibble::tibble(x = "Seizure", x_id = "HP:0001250", y = "Ataxia", y_id = "HP:0001251", value = 0.42)
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_get_phenotype_correlations", old_corr, envir = .GlobalEnv))

  result <- mcp_get_phenotype_analysis_context(mode = "correlations", phenotype = "HP:0001250")
  expect_equal(result$data_class, "curated_derived_analysis")
  expect_equal(result$records[[1]]$value, 0.42)

  err <- tryCatch(
    mcp_get_phenotype_analysis_context(mode = "raw_matrix"),
    mcp_tool_error = function(e) unclass(e)
  )
  expect_equal(err$error$code, "invalid_input")
})

test_that("gene network context raises temporarily_unavailable when disk cache hit is absent", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_has <- mcp_analysis_repo_network_cache_hit
  assign("mcp_analysis_repo_network_cache_hit", function(...) FALSE, envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_network_cache_hit", old_has, envir = .GlobalEnv))

  err <- tryCatch(
    mcp_get_gene_network_context(gene = "HGNC:61"),
    mcp_tool_error = function(e) unclass(e)
  )
  expect_equal(err$error$code, "temporarily_unavailable")
})

test_that("gene network context passes the requested gene into cache-safe repository reads", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  seen_gene <- NULL
  old_has <- mcp_analysis_repo_network_cache_hit
  old_network <- get0("mcp_analysis_repo_get_network_edges_local", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_network_cache_hit", function(...) TRUE, envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_network_edges_local", function(gene = NULL, ...) {
    seen_gene <<- gene
    list(
      nodes = tibble::tibble(hgnc_id = "HGNC:61", symbol = "ABCD1"),
      edges = tibble::tibble(source = "HGNC:61", target = "HGNC:62", confidence = 0.9),
      metadata = list(gene_filtered = TRUE)
    )
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_network_cache_hit", old_has, envir = .GlobalEnv)
    if (is.null(old_network)) rm("mcp_analysis_repo_get_network_edges_local", envir = .GlobalEnv) else assign("mcp_analysis_repo_get_network_edges_local", old_network, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_network_context(gene = "HGNC:61")
  expect_equal(seen_gene, "HGNC:61")
  expect_true(result$meta$gene_filtered)
})

test_that("phenotype and network services convert cache-safe helper errors to temporary unavailability", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_corr <- mcp_analysis_repo_get_phenotype_correlations
  old_has <- mcp_analysis_repo_network_cache_hit
  old_network <- mcp_analysis_repo_get_network_edges_local
  assign("mcp_analysis_repo_get_phenotype_correlations", function(...) stop("helper failed"), envir = .GlobalEnv)
  assign("mcp_analysis_repo_network_cache_hit", function(...) TRUE, envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_network_edges_local", function(...) stop("network failed"), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_get_phenotype_correlations", old_corr, envir = .GlobalEnv)
    assign("mcp_analysis_repo_network_cache_hit", old_has, envir = .GlobalEnv)
    assign("mcp_analysis_repo_get_network_edges_local", old_network, envir = .GlobalEnv)
  })

  phenotype_err <- tryCatch(
    mcp_get_phenotype_analysis_context(mode = "correlations"),
    mcp_tool_error = function(e) unclass(e)
  )
  network_err <- tryCatch(
    mcp_get_gene_network_context(gene = "HGNC:61"),
    mcp_tool_error = function(e) unclass(e)
  )

  expect_equal(phenotype_err$error$code, "temporarily_unavailable")
  expect_equal(network_err$error$code, "temporarily_unavailable")
})

test_that("gene network context budget accounts for nodes and metadata", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_has <- mcp_analysis_repo_network_cache_hit
  old_network <- mcp_analysis_repo_get_network_edges_local
  assign("mcp_analysis_repo_network_cache_hit", function(...) TRUE, envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_network_edges_local", function(...) {
    list(
      nodes = tibble::tibble(hgnc_id = "HGNC:61", symbol = paste(rep("A", 500), collapse = "")),
      edges = tibble::tibble(source = "HGNC:61", target = "HGNC:62", confidence = 0.9),
      metadata = list(gene_filtered = TRUE, note = paste(rep("m", 500), collapse = ""))
    )
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_network_cache_hit", old_has, envir = .GlobalEnv)
    assign("mcp_analysis_repo_get_network_edges_local", old_network, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_network_context(gene = "HGNC:61", max_response_chars = 1000L)
  payload_chars <- mcp_analysis_estimate_chars(result[c("nodes", "edges", "meta")])

  expect_gte(result$budget$total_chars, payload_chars)
  expect_true(result$budget$truncated)
})

test_that("gene research context aggregates requested sections with explicit section statuses", {
  source("../../functions/mcp-repository.R")
  source("../../functions/mcp-analysis-repository.R")
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

test_that("gene research dry-run returns statuses and budget without bulky section rows", {
  source("../../functions/mcp-repository.R")
  source("../../functions/mcp-analysis-repository.R")
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
  source("../../functions/mcp-analysis-repository.R")
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
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-research-context-service.R")

  old_gene <- mcp_get_gene_context
  old_cluster_hit <- mcp_analysis_repo_phenotype_cluster_cache_hit
  assign("mcp_get_gene_context", function(gene, ...) {
    list(schema_version = MCP_SCHEMA_VERSION, gene = list(hgnc_id = "HGNC:61", symbol = "ABCD1"), entities = list())
  }, envir = .GlobalEnv)
  assign("mcp_analysis_repo_phenotype_cluster_cache_hit", function(...) FALSE, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_get_gene_context", old_gene, envir = .GlobalEnv)
    assign("mcp_analysis_repo_phenotype_cluster_cache_hit", old_cluster_hit, envir = .GlobalEnv)
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
  source("../../functions/mcp-analysis-repository.R")
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
  source("../../functions/mcp-analysis-repository.R")
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
  source("../../functions/mcp-analysis-repository.R")
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
