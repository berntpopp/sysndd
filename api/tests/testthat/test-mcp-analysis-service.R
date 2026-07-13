# Shared setup is explicitly sourced so this file remains standalone under
# testthat::test_file() after the research-context tests were split out.
source(file.path(
  get_api_dir(),
  "tests", "testthat", "mcp-analysis-service-fixtures.R"
), local = TRUE)

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
  expect_match(llm$limitations[[1]], "validated stored projection", fixed = TRUE)
  expect_false(grepl("cache", llm$limitations[[1]], ignore.case = TRUE))
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
  expect_equal(catalog$data_class, "operational_metadata")
  expect_equal(catalog$curation_effect, "none")
  expect_true(catalog$not_evidence_tier)
  expect_false(is.null(catalog$provenance))
  expect_false(is.null(catalog$budget))
  expect_equal(catalog$meta$response_mode, "compact")
  expect_false(is.null(catalog$recovery$retry_with))
})

test_that("NDDScore MCP context is always marked as ML prediction and not evidence tier", {
  source_mcp_analysis_repository()
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
  source_mcp_analysis_repository()
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

test_that("curation comparison plot modes return documented invalid_input errors", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  err <- tryCatch(
    mcp_get_curation_comparison_context(mode = "source_overlap"),
    mcp_tool_error = function(e) unclass(e)
  )

  expect_equal(err$error$code, "invalid_input")
  expect_equal(err$error$argument, "mode")
  expect_true("gene_sources" %in% err$error$allowed_values)
  expect_true("browse" %in% err$error$allowed_values)
})

test_that("MCP LLM summary service returns allowlisted validated summaries and never generates", {
  source_mcp_analysis_repository()
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
      summary_json = paste0(
        "{\"summary\":\"stored summary\",\"key_themes\":[\"synaptic\"],",
        "\"judge_reasoning\":\"forbidden\",\"unknown\":\"forbidden\"}"
      ),
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
  expect_true(result[[1]]$stored_summary_only)
  expect_equal(result[[1]]$summary$summary, "stored summary")
  expect_equal(names(result[[1]]$summary), c("summary", "key_themes"))
  expect_null(result[[1]]$summary$judge_reasoning)
})

test_that("MCP LLM summary service reports stored-summary miss without generation", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_cache <- mcp_analysis_repo_get_cached_llm_summaries
  assign("mcp_analysis_repo_get_cached_llm_summaries", function(...) tibble::tibble(), envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_get_cached_llm_summaries", old_cache, envir = .GlobalEnv))

  result <- mcp_get_cached_llm_summaries("phenotype", cluster_numbers = 1L)

  expect_false(result[[1]]$summary_available)
  expect_true(result[[1]]$stored_summary_only)
  expect_equal(result[[1]]$data_class, "llm_generated_summary")
})

test_that("phenotype analysis context validates mode and labels derived analyses", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_status <- mcp_analysis_repo_public_snapshot_status
  old_corr <- mcp_analysis_repo_get_snapshot_phenotype_correlations
  assign("mcp_analysis_repo_public_snapshot_status", function(...) "available", envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_snapshot_phenotype_correlations", function(...) {
    tibble::tibble(x = "Seizure", x_id = "HP:0001250", y = "Ataxia", y_id = "HP:0001251", value = 0.42)
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_public_snapshot_status", old_status, envir = .GlobalEnv)
    assign("mcp_analysis_repo_get_snapshot_phenotype_correlations", old_corr, envir = .GlobalEnv)
  })

  result <- mcp_get_phenotype_analysis_context(mode = "correlations", phenotype = "HP:0001250")
  expect_equal(result$data_class, "curated_derived_analysis")
  expect_equal(result$records[[1]]$value, 0.42)

  err <- tryCatch(
    mcp_get_phenotype_analysis_context(mode = "raw_matrix"),
    mcp_tool_error = function(e) unclass(e)
  )
  expect_equal(err$error$code, "invalid_input")
})

test_that("phenotype correlation controls propagate to snapshot repository reads", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_status <- mcp_analysis_repo_public_snapshot_status
  old_corr <- mcp_analysis_repo_get_snapshot_phenotype_correlations
  seen <- list()
  assign("mcp_analysis_repo_public_snapshot_status", function(...) "available", envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_snapshot_phenotype_correlations", function(phenotype,
                                                                           min_abs_correlation,
                                                                           drop_diagonal,
                                                                           triangle_only,
                                                                           limit) {
    seen <<- list(
      phenotype = phenotype,
      min_abs_correlation = min_abs_correlation,
      drop_diagonal = drop_diagonal,
      triangle_only = triangle_only,
      limit = limit
    )
    tibble::tibble(x = "Seizure", y = "Ataxia", value = 0.42)
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_public_snapshot_status", old_status, envir = .GlobalEnv)
    assign("mcp_analysis_repo_get_snapshot_phenotype_correlations", old_corr, envir = .GlobalEnv)
  })

  mcp_get_phenotype_analysis_context(
    mode = "correlations",
    phenotype = "HP:0001250",
    min_abs_correlation = 0.5,
    drop_diagonal = FALSE,
    triangle_only = TRUE,
    limit = 7L
  )

  expect_equal(seen$phenotype, "HP:0001250")
  expect_equal(seen$min_abs_correlation, 0.5)
  expect_false(seen$drop_diagonal)
  expect_true(seen$triangle_only)
  expect_equal(seen$limit, 7L)
})

test_that("phenotype correlations raise snapshot_missing when public snapshot is absent", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_status <- mcp_analysis_repo_public_snapshot_status
  assign("mcp_analysis_repo_public_snapshot_status", function(...) "snapshot_missing", envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_public_snapshot_status", old_status, envir = .GlobalEnv))

  err <- tryCatch(
    mcp_get_phenotype_analysis_context(mode = "correlations"),
    mcp_tool_error = function(e) unclass(e)
  )

  expect_equal(err$error$code, "snapshot_missing")
})

test_that("phenotype analysis dry_run reports missing public snapshot", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_status <- mcp_analysis_repo_public_snapshot_status
  assign("mcp_analysis_repo_public_snapshot_status", function(...) "snapshot_missing", envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_public_snapshot_status", old_status, envir = .GlobalEnv))

  result <- mcp_get_phenotype_analysis_context(mode = "correlations", dry_run = TRUE)
  expect_equal(result$section_status, "snapshot_missing")
  expect_false(result$meta$snapshot_available)
})

test_that("phenotype dry_run uses manifest availability without loading payloads", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_status <- mcp_analysis_repo_public_snapshot_status
  old_snapshot <- mcp_analysis_repo_get_public_snapshot
  assign("mcp_analysis_repo_public_snapshot_status", function(...) "available", envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_public_snapshot", function(...) stop("full snapshot getter called"), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_public_snapshot_status", old_status, envir = .GlobalEnv)
    assign("mcp_analysis_repo_get_public_snapshot", old_snapshot, envir = .GlobalEnv)
  })

  result <- mcp_get_phenotype_analysis_context(mode = "correlations", dry_run = TRUE)

  expect_equal(result$section_status, "available")
  expect_true(result$meta$snapshot_available)
})

test_that("public snapshot availability reads manifest only", {
  source_mcp_analysis_repository()

  old_db <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  old_get_public <- get0("analysis_snapshot_get_public", envir = .GlobalEnv, ifnotfound = NULL)
  old_source_version <- get0("analysis_snapshot_source_data_version", envir = .GlobalEnv, ifnotfound = NULL)
  seen_query <- NULL
  assign("db_execute_query", function(query, params = list(), conn = NULL) {
    seen_query <<- query
    expect_equal(params[[1]], "phenotype_correlations")
    tibble::tibble(snapshot_id = 1L, source_data_version = "source-v1", stale_after = Sys.time() + 3600)
  }, envir = .GlobalEnv)
  assign("analysis_snapshot_get_public", function(...) stop("full snapshot getter called"), envir = .GlobalEnv)
  assign("analysis_snapshot_source_data_version", function(...) NULL, envir = .GlobalEnv)
  withr::defer({
    if (is.null(old_db)) {
      rm("db_execute_query", envir = .GlobalEnv)
    } else {
      assign("db_execute_query", old_db, envir = .GlobalEnv)
    }
    if (is.null(old_get_public)) {
      rm("analysis_snapshot_get_public", envir = .GlobalEnv)
    } else {
      assign("analysis_snapshot_get_public", old_get_public, envir = .GlobalEnv)
    }
    if (is.null(old_source_version)) {
      rm("analysis_snapshot_source_data_version", envir = .GlobalEnv)
    } else {
      assign("analysis_snapshot_source_data_version", old_source_version, envir = .GlobalEnv)
    }
  })

  expect_true(mcp_analysis_repo_public_snapshot_available("phenotype_correlations", list()))
  expect_true(grepl("mcp_public_analysis_manifest", seen_query, fixed = TRUE))
})

test_that("gene network context raises snapshot_missing when public snapshot is absent", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_status <- mcp_analysis_repo_public_snapshot_status
  assign("mcp_analysis_repo_public_snapshot_status", function(...) "snapshot_missing", envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_public_snapshot_status", old_status, envir = .GlobalEnv))

  err <- tryCatch(
    mcp_get_gene_network_context(gene = "HGNC:61"),
    mcp_tool_error = function(e) unclass(e)
  )
  expect_equal(err$error$code, "snapshot_missing")
})

test_that("gene network context passes the requested gene into snapshot repository reads", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  seen_gene <- NULL
  old_status <- mcp_analysis_repo_public_snapshot_status
  old_network <- get0("mcp_analysis_repo_get_snapshot_network", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_public_snapshot_status", function(...) "available", envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_snapshot_network", function(gene = NULL, ...) {
    seen_gene <<- gene
    list(
      nodes = tibble::tibble(hgnc_id = "HGNC:61", symbol = "ABCD1"),
      edges = tibble::tibble(source = "HGNC:61", target = "HGNC:62", confidence = 0.9),
      metadata = list(gene_filtered = TRUE)
    )
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_public_snapshot_status", old_status, envir = .GlobalEnv)
    if (is.null(old_network)) rm("mcp_analysis_repo_get_snapshot_network", envir = .GlobalEnv) else assign("mcp_analysis_repo_get_snapshot_network", old_network, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_network_context(gene = "HGNC:61")
  expect_equal(seen_gene, "HGNC:61")
  expect_true(result$meta$gene_filtered)
})

test_that("phenotype and network services convert snapshot helper errors to snapshot_missing", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_status <- mcp_analysis_repo_public_snapshot_status
  old_corr <- mcp_analysis_repo_get_snapshot_phenotype_correlations
  old_network <- mcp_analysis_repo_get_snapshot_network
  assign("mcp_analysis_repo_public_snapshot_status", function(...) "available", envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_snapshot_phenotype_correlations", function(...) stop("helper failed"), envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_snapshot_network", function(...) stop("network failed"), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_public_snapshot_status", old_status, envir = .GlobalEnv)
    assign("mcp_analysis_repo_get_snapshot_phenotype_correlations", old_corr, envir = .GlobalEnv)
    assign("mcp_analysis_repo_get_snapshot_network", old_network, envir = .GlobalEnv)
  })

  phenotype_err <- tryCatch(
    mcp_get_phenotype_analysis_context(mode = "correlations"),
    mcp_tool_error = function(e) unclass(e)
  )
  network_err <- tryCatch(
    mcp_get_gene_network_context(gene = "HGNC:61"),
    mcp_tool_error = function(e) unclass(e)
  )

  expect_equal(phenotype_err$error$code, "snapshot_missing")
  expect_equal(network_err$error$code, "snapshot_missing")
})

test_that("gene network context budget accounts for nodes and metadata", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_status <- mcp_analysis_repo_public_snapshot_status
  old_network <- mcp_analysis_repo_get_snapshot_network
  assign("mcp_analysis_repo_public_snapshot_status", function(...) "available", envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_snapshot_network", function(...) {
    list(
      nodes = tibble::tibble(hgnc_id = "HGNC:61", symbol = paste(rep("A", 500), collapse = "")),
      edges = tibble::tibble(source = "HGNC:61", target = "HGNC:62", confidence = 0.9),
      metadata = list(gene_filtered = TRUE, note = paste(rep("m", 500), collapse = ""))
    )
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_public_snapshot_status", old_status, envir = .GlobalEnv)
    assign("mcp_analysis_repo_get_snapshot_network", old_network, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_network_context(gene = "HGNC:61", max_response_chars = 1000L)
  payload_chars <- mcp_analysis_estimate_chars(result[c("nodes", "edges", "meta")])

  expect_gte(result$budget$total_chars, payload_chars)
  expect_true(result$budget$truncated)
})

test_that("phenotype clusters expose validation but ignore unprojected db_release", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_status <- get0("mcp_analysis_repo_public_snapshot_status", envir = .GlobalEnv, ifnotfound = NULL)
  old_reader <- get0("mcp_analysis_repo_get_snapshot_phenotype_clusters", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_public_snapshot_status", function(...) "available", envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_snapshot_phenotype_clusters", function(...) list(
    records = tibble::tibble(cluster = "1", hgnc_id = "HGNC:1", entity_id = 1L, symbol = "A"),
    meta = list(snapshot = list(
      validation = list(partition_scope = "visible_top_level", mean_silhouette = 0.4,
                        k = 3L, algorithm = "mca_hcpc",
                        separation_z = 3.1, silhouette_z = 3.1,
                        silhouette_p_empirical = 0.012, null_model = "label_permutation",
                        dip_statistic = 0.02, dip_p = 0.4,
                        silhouette_interpretation = "no_substantial_structure_continuum"),
      db_release = list(version = "v3.2.0", commit = "abc1234")
    ))
  ), envir = .GlobalEnv)
  withr::defer({
    if (!is.null(old_status)) assign("mcp_analysis_repo_public_snapshot_status", old_status, envir = .GlobalEnv)
    if (!is.null(old_reader)) assign("mcp_analysis_repo_get_snapshot_phenotype_clusters", old_reader, envir = .GlobalEnv)
  })

  result <- mcp_get_phenotype_analysis_context(mode = "clusters", limit = 10L)

  expect_equal(result$meta$validation$partition_scope, "visible_top_level")
  expect_null(result$meta$db_release)
  expect_equal(result$meta$data_classes$validation, "curated_derived_analysis")
  expect_null(result$meta$data_classes$db_release)
  # Additive null-calibrated separation diagnostics surface read-only as their own
  # operational_metadata block (validation schema >= 2.0), never recomputed on MCP.
  expect_equal(result$meta$separation_statistics$separation_z, 3.1)
  expect_equal(result$meta$separation_statistics$silhouette_interpretation,
               "no_substantial_structure_continuum")
  expect_equal(result$meta$separation_statistics$null_model, "label_permutation")
  expect_null(result$meta$separation_statistics$mean_silhouette)
  expect_equal(result$meta$data_classes$separation_statistics, "operational_metadata")
})

test_that("phenotype clusters tool omits separation_statistics on pre-2.0 snapshots", {
  source_mcp_analysis_repository()
  source("../../services/mcp-service.R")

  old_status <- get0("mcp_analysis_repo_public_snapshot_status", envir = .GlobalEnv, ifnotfound = NULL)
  old_reader <- get0("mcp_analysis_repo_get_snapshot_phenotype_clusters", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_public_snapshot_status", function(...) "available", envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_snapshot_phenotype_clusters", function(...) list(
    records = tibble::tibble(cluster = "1", hgnc_id = "HGNC:1", entity_id = 1L, symbol = "A"),
    meta = list(snapshot = list(
      validation = list(partition_scope = "visible_top_level", mean_silhouette = 0.4,
                        k = 3L, algorithm = "mca_hcpc"),
      db_release = list(version = "v3.2.0", commit = "abc1234")
    ))
  ), envir = .GlobalEnv)
  withr::defer({
    if (!is.null(old_status)) assign("mcp_analysis_repo_public_snapshot_status", old_status, envir = .GlobalEnv)
    if (!is.null(old_reader)) assign("mcp_analysis_repo_get_snapshot_phenotype_clusters", old_reader, envir = .GlobalEnv)
  })

  result <- mcp_get_phenotype_analysis_context(mode = "clusters", limit = 10L)

  expect_null(result$meta$separation_statistics)
  expect_null(result$meta$data_classes$separation_statistics)
  expect_equal(result$meta$data_classes$validation, "curated_derived_analysis")
})
