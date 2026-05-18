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
