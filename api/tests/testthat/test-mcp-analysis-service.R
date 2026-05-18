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
