source_mcp_analysis_repository <- function() {
  # llm-summary-config.R defines LLM_SUMMARY_PROMPT_VERSION, which
  # mcp-analysis-repository.R references as a default arg (evaluated lazily at
  # call time). In production both are loaded by bootstrap_load_modules(); the
  # test must source it too or the lookup errors with "object not found".
  source("../../functions/llm-summary-config.R")
  source("../../functions/mcp-analysis-cache-repository.R")
  source("../../functions/mcp-analysis-repository.R")
}

restore_binding <- function(name, old_value) {
  if (is.null(old_value)) {
    if (exists(name, envir = .GlobalEnv, inherits = FALSE)) {
      rm(list = name, envir = .GlobalEnv)
    }
  } else {
    assign(name, old_value, envir = .GlobalEnv)
  }
}

test_that("MCP LLM summary repository is cache-only and validated by default", {
  source_mcp_analysis_repository()

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
  withr::defer(restore_binding("db_execute_query", old_query))

  result <- mcp_analysis_repo_get_cached_llm_summaries("functional", cluster_hashes = "abc")

  expect_equal(nrow(result), 1L)
  expect_true(any(grepl("llm_cluster_summary_cache", sql_seen, fixed = TRUE)))
  expect_true(any(grepl("validation_status = 'validated'", sql_seen, fixed = TRUE)))
  expect_false(any(grepl("get_or_generate_summary|chat_google_gemini|llm-service", sql_seen)))
})

test_that("MCP NDDScore repository delegates to active current-view helpers", {
  source_mcp_analysis_repository()

  old_detail <- get0("nddscore_repo_gene_detail", envir = .GlobalEnv, ifnotfound = NULL)
  assign("nddscore_repo_gene_detail", function(hgnc_id_or_symbol) {
    list(
      gene = tibble::tibble(hgnc_id = "HGNC:61", gene_symbol = "ABCD1", ndd_score = 0.7),
      hpo_predictions = tibble::tibble(phenotype_id = "HP:0001250", probability = 0.4)
    )
  }, envir = .GlobalEnv)
  withr::defer(restore_binding("nddscore_repo_gene_detail", old_detail))

  result <- mcp_analysis_repo_get_nddscore_gene("HGNC:61")

  expect_equal(result$gene$gene_symbol[[1]], "ABCD1")
})

test_that("MCP analysis repository exposes only snapshot-backed derived analysis entrypoints", {
  source_mcp_analysis_repository()

  expect_false(exists("mcp_analysis_repo_get_phenotype_correlations", mode = "function"))
  expect_false(exists("mcp_analysis_repo_get_phenotype_clusters", mode = "function"))
  expect_false(exists("mcp_analysis_repo_get_phenotype_functional_correlations", mode = "function"))
  expect_false(exists("mcp_analysis_repo_get_network_edges_local", mode = "function"))

  repo_source <- paste(readLines("../../functions/mcp-analysis-repository.R", warn = FALSE), collapse = "\n")
  expect_false(grepl("generate_phenotype_correlations", repo_source, fixed = TRUE))
  expect_false(grepl("generate_phenotype_clusters", repo_source, fixed = TRUE))
  expect_false(grepl("generate_phenotype_functional_cluster_correlation", repo_source, fixed = TRUE))
  expect_false(grepl("gen_network_edges_mem", repo_source, fixed = TRUE))
})

test_that("MCP analysis availability probes use public snapshot manifests", {
  source("../../functions/analysis-snapshot-presets.R")
  source("../../functions/analysis-snapshot-repository.R")
  source_mcp_analysis_repository()

  seen_types <- character()
  old_query <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  old_source_version <- get0("analysis_snapshot_source_data_version", envir = .GlobalEnv, ifnotfound = NULL)
  assign("db_execute_query", function(sql, params = list(), conn = NULL) {
    seen_types <<- c(seen_types, params[[1]])
    tibble::tibble(snapshot_id = 1L, source_data_version = "source-v1", stale_after = Sys.time() + 3600)
  }, envir = .GlobalEnv)
  assign("analysis_snapshot_source_data_version", function(...) NULL, envir = .GlobalEnv)
  withr::defer({
    restore_binding("db_execute_query", old_query)
    restore_binding("analysis_snapshot_source_data_version", old_source_version)
  })

  expect_true(mcp_analysis_repo_phenotype_correlations_cache_hit())
  expect_true(mcp_analysis_repo_phenotype_cluster_cache_hit())
  expect_true(mcp_analysis_repo_functional_cluster_cache_hit())
  expect_true(mcp_analysis_repo_network_cache_hit(cluster_type = "clusters", min_confidence = 400L))
  expect_false(mcp_analysis_repo_network_cache_hit(cluster_type = "subclusters", min_confidence = 400L))
  expect_false(mcp_analysis_repo_network_cache_hit(cluster_type = "clusters", min_confidence = 700L))
  expect_equal(
    sort(unique(seen_types)),
    sort(c("phenotype_correlations", "phenotype_clusters", "functional_clusters", "gene_network_edges"))
  )
})

test_that("MCP snapshot phenotype cluster repository filters shaped snapshot rows", {
  source_mcp_analysis_repository()

  old_public <- get0("mcp_analysis_repo_get_public_snapshot", envir = .GlobalEnv, ifnotfound = NULL)
  old_shape <- get0("mcp_analysis_repo_shape_snapshot_phenotype_clusters", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_get_public_snapshot", function(...) list(snapshot = list()), envir = .GlobalEnv)
  assign("mcp_analysis_repo_shape_snapshot_phenotype_clusters", function(snapshot) {
    list(clusters = tibble::tibble(
      cluster = c("3", "4"),
      identifiers = list(
        tibble::tibble(entity_id = 1L, hgnc_id = "HGNC:1", symbol = "GENE1"),
        tibble::tibble(entity_id = 2L, hgnc_id = "HGNC:2", symbol = "GENE2")
      )
    ))
  }, envir = .GlobalEnv)
  withr::defer({
    restore_binding("mcp_analysis_repo_get_public_snapshot", old_public)
    restore_binding("mcp_analysis_repo_shape_snapshot_phenotype_clusters", old_shape)
  })

  result <- mcp_analysis_repo_get_snapshot_phenotype_clusters(gene = "GENE1", cluster_id = "3")

  expect_equal(nrow(result$records), 1L)
  expect_equal(result$records$cluster[[1]], "3")
  expect_equal(result$records$hgnc_id[[1]], "HGNC:1")
})

test_that("MCP snapshot functional cluster repository filters shaped snapshot rows", {
  source_mcp_analysis_repository()

  old_public <- get0("mcp_analysis_repo_get_public_snapshot", envir = .GlobalEnv, ifnotfound = NULL)
  old_shape <- get0("service_analysis_snapshot_shape_functional", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_get_public_snapshot", function(...) list(snapshot = list()), envir = .GlobalEnv)
  assign("service_analysis_snapshot_shape_functional", function(snapshot) {
    list(clusters = tibble::tibble(
      cluster = c("7", "8"),
      identifiers = list(
        tibble::tibble(hgnc_id = "HGNC:1", symbol = "GENE1"),
        tibble::tibble(hgnc_id = "HGNC:2", symbol = "GENE2")
      )
    ))
  }, envir = .GlobalEnv)
  withr::defer({
    restore_binding("mcp_analysis_repo_get_public_snapshot", old_public)
    restore_binding("service_analysis_snapshot_shape_functional", old_shape)
  })

  result <- mcp_analysis_repo_get_snapshot_functional_clusters(gene = "HGNC:1", cluster_id = "7")

  expect_equal(nrow(result$records), 1L)
  expect_equal(result$records$cluster[[1]], "7")
  expect_equal(result$records$symbol[[1]], "GENE1")
})

test_that("MCP snapshot phenotype correlations filter by phenotype and limit results", {
  source_mcp_analysis_repository()

  old_public <- get0("mcp_analysis_repo_get_public_snapshot", envir = .GlobalEnv, ifnotfound = NULL)
  old_shape <- get0("mcp_analysis_repo_shape_snapshot_correlations", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_get_public_snapshot", function(...) list(snapshot = list()), envir = .GlobalEnv)
  assign("mcp_analysis_repo_shape_snapshot_correlations", function(snapshot,
                                                                   min_abs_correlation = NULL,
                                                                   drop_diagonal = TRUE,
                                                                   triangle_only = FALSE) {
    expect_equal(min_abs_correlation, 0.3)
    expect_true(drop_diagonal)
    list(correlation_melted = tibble::tibble(
      x = c("HP:0001250", "HP:0001252", "HP:0001250"),
      y = c("HP:0001251", "HP:0001253", "HP:0001254"),
      value = c(0.7, 0.9, 0.5)
    ))
  }, envir = .GlobalEnv)
  withr::defer({
    restore_binding("mcp_analysis_repo_get_public_snapshot", old_public)
    restore_binding("mcp_analysis_repo_shape_snapshot_correlations", old_shape)
  })

  result <- mcp_analysis_repo_get_snapshot_phenotype_correlations(
    phenotype = "HP:0001250",
    min_abs_correlation = 0.3,
    limit = 1L
  )

  expect_equal(nrow(result), 1L)
  expect_equal(result$value[[1]], 0.7)
})

test_that("MCP snapshot phenotype functional filters use producer cluster key format", {
  source_mcp_analysis_repository()

  old_public <- get0("mcp_analysis_repo_get_public_snapshot", envir = .GlobalEnv, ifnotfound = NULL)
  old_shape <- get0("mcp_analysis_repo_shape_snapshot_correlations", envir = .GlobalEnv, ifnotfound = NULL)
  old_phenotype <- get0("mcp_analysis_repo_get_snapshot_phenotype_clusters", envir = .GlobalEnv, ifnotfound = NULL)
  old_functional <- get0("mcp_analysis_repo_get_snapshot_functional_clusters", envir = .GlobalEnv, ifnotfound = NULL)

  assign("mcp_analysis_repo_get_public_snapshot", function(...) list(snapshot = list()), envir = .GlobalEnv)
  assign("mcp_analysis_repo_shape_snapshot_correlations", function(...) {
    list(correlation_melted = tibble::tibble(
      x = c("pc_3", "phenotype_3", "fc_7", "7"),
      y = c("fc_7", "pc_3", "other", "pc_3"),
      value = c(0.8, 0.7, 0.6, 0.5)
    ))
  }, envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_snapshot_phenotype_clusters", function(...) {
    list(records = tibble::tibble(cluster = "3", hgnc_id = "HGNC:1", symbol = "GENE1"))
  }, envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_snapshot_functional_clusters", function(...) {
    list(records = tibble::tibble(cluster = "7", hgnc_id = "HGNC:1", symbol = "GENE1"))
  }, envir = .GlobalEnv)

  withr::defer({
    restore_binding("mcp_analysis_repo_get_public_snapshot", old_public)
    restore_binding("mcp_analysis_repo_shape_snapshot_correlations", old_shape)
    restore_binding("mcp_analysis_repo_get_snapshot_phenotype_clusters", old_phenotype)
    restore_binding("mcp_analysis_repo_get_snapshot_functional_clusters", old_functional)
  })

  result <- mcp_analysis_repo_get_snapshot_phenotype_functional_correlations(gene = "HGNC:1", limit = 10L)

  expect_equal(sort(unique(c(result$x, result$y))), sort(c("fc_7", "pc_3")))
  expect_false(any(result$x == "phenotype_3" | result$y == "phenotype_3"))
  expect_false(any(result$x == "7" | result$y == "7"))
  expect_false(any(result$x == "other" | result$y == "other"))
})

test_that("MCP snapshot network repository filters and limits public snapshot edges", {
  source_mcp_analysis_repository()

  old_public <- get0("mcp_analysis_repo_get_public_snapshot", envir = .GlobalEnv, ifnotfound = NULL)
  old_shape <- get0("mcp_analysis_repo_shape_snapshot_network", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_get_public_snapshot", function(...) list(snapshot = list()), envir = .GlobalEnv)
  assign("mcp_analysis_repo_shape_snapshot_network", function(snapshot, max_edges = 10000L) {
    list(
      nodes = tibble::tibble(
        hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
        symbol = c("GENE1", "GENE2", "GENE3"),
        cluster = c("1", "1", "2"),
        category = c("Definitive", "Moderate", "Limited")
      ),
      edges = tibble::tibble(
        source = c("HGNC:1", "HGNC:1", "HGNC:2"),
        target = c("HGNC:2", "HGNC:3", "HGNC:3"),
        confidence = c(0.8, 0.9, 0.7)
      ),
      metadata = list(snapshot = list(analysis_type = "gene_network_edges"))
    )
  }, envir = .GlobalEnv)
  withr::defer({
    restore_binding("mcp_analysis_repo_get_public_snapshot", old_public)
    restore_binding("mcp_analysis_repo_shape_snapshot_network", old_shape)
  })

  result <- mcp_analysis_repo_get_snapshot_network(gene = "HGNC:1", max_edges = 1L)

  expect_equal(nrow(result$edges), 1L)
  expect_equal(result$edges$target[[1]], "HGNC:3")
  expect_equal(sort(result$nodes$hgnc_id), c("HGNC:1", "HGNC:3"))
  expect_true(result$metadata$gene_filtered)
  expect_equal(result$metadata$cluster_count, 2L)
})

test_that("shared phenotype analysis helpers enforce approved and active review rows", {
  source("../../functions/analyses-functions.R")
  source("../../functions/analysis-phenotype-functions.R")

  correlation_body <- paste(deparse(body(generate_phenotype_correlations)), collapse = "\n")
  cluster_body <- paste(deparse(body(generate_phenotype_cluster_input)), collapse = "\n")

  expect_match(correlation_body, "review_approved == 1", fixed = TRUE)
  expect_match(correlation_body, "is_active == 1", fixed = TRUE)
  expect_match(cluster_body, "review_approved == 1", fixed = TRUE)
  expect_match(cluster_body, "is_active == 1", fixed = TRUE)
})

test_that("shared phenotype correlations preserve the public filter argument", {
  source("../../functions/analyses-functions.R")
  source("../../functions/analysis-phenotype-functions.R")

  correlation_body <- paste(deparse(body(generate_phenotype_correlations)), collapse = "\n")
  modifier_pos <- regexpr("modifier_phenotype_id", correlation_body, fixed = TRUE)[[1]]
  filter_pos <- regexpr("filter(!!!rlang::parse_exprs(filter_exprs))", correlation_body, fixed = TRUE)[[1]]

  expect_match(correlation_body, "generate_filter_expressions(filter)", fixed = TRUE)
  expect_match(correlation_body, "filter(!!!rlang::parse_exprs(filter_exprs))", fixed = TRUE)
  expect_gt(modifier_pos, 0L)
  expect_gt(filter_pos, modifier_pos)
  expect_false(grepl("categories <- c(\"Definitive\")", correlation_body, fixed = TRUE))
})

test_that("phenotype cluster reader threads snapshot meta with validation + db_release", {
  source_mcp_analysis_repository()

  old_get <- get0("mcp_analysis_repo_get_public_snapshot", envir = .GlobalEnv, ifnotfound = NULL)
  old_shape <- get0("mcp_analysis_repo_shape_snapshot_phenotype_clusters", envir = .GlobalEnv, ifnotfound = NULL)
  on.exit({
    restore_binding("mcp_analysis_repo_get_public_snapshot", old_get)
    restore_binding("mcp_analysis_repo_shape_snapshot_phenotype_clusters", old_shape)
  })

  assign("mcp_analysis_repo_get_public_snapshot",
    function(...) list(snapshot = list(stub = TRUE)), envir = .GlobalEnv)
  assign("mcp_analysis_repo_shape_snapshot_phenotype_clusters", function(snapshot) list(
    clusters = tibble::tibble(
      cluster = "1", hash_filter = "h1",
      identifiers = list(tibble::tibble(entity_id = 1L, hgnc_id = "HGNC:1", symbol = "A"))
    ),
    meta = list(snapshot = list(
      validation = list(partition_scope = "visible_top_level", mean_silhouette = 0.4),
      db_release = list(version = "v3.2.0", commit = "abc1234")
    ))
  ), envir = .GlobalEnv)

  res <- mcp_analysis_repo_get_snapshot_phenotype_clusters()
  expect_true(is.list(res) && !is.null(res$meta))
  expect_equal(res$meta$snapshot$validation$partition_scope, "visible_top_level")
  expect_equal(res$meta$snapshot$db_release$version, "v3.2.0")
  expect_true(tibble::is_tibble(res$records) && nrow(res$records) >= 1L)
})

test_that("functional cluster reader threads snapshot meta with validation + db_release", {
  source_mcp_analysis_repository()

  old_get <- get0("mcp_analysis_repo_get_public_snapshot", envir = .GlobalEnv, ifnotfound = NULL)
  old_shape <- get0("service_analysis_snapshot_shape_functional", envir = .GlobalEnv, ifnotfound = NULL)
  on.exit({
    restore_binding("mcp_analysis_repo_get_public_snapshot", old_get)
    restore_binding("service_analysis_snapshot_shape_functional", old_shape)
  })

  assign("mcp_analysis_repo_get_public_snapshot",
    function(...) list(snapshot = list(stub = TRUE)), envir = .GlobalEnv)
  assign("service_analysis_snapshot_shape_functional", function(snapshot) list(
    clusters = tibble::tibble(
      cluster = "1", hash_filter = "h1",
      identifiers = list(tibble::tibble(entity_id = 1L, hgnc_id = "HGNC:1", symbol = "A"))
    ),
    meta = list(snapshot = list(
      validation = list(partition_scope = "visible_top_level", modularity = 0.41,
                        modularity_scope = "full_partition"),
      db_release = list(version = "v3.2.0", commit = "abc1234")
    ))
  ), envir = .GlobalEnv)

  res <- mcp_analysis_repo_get_snapshot_functional_clusters()
  expect_true(is.list(res) && !is.null(res$meta))
  expect_equal(res$meta$snapshot$validation$partition_scope, "visible_top_level")
  expect_equal(res$meta$snapshot$validation$modularity_scope, "full_partition")
  expect_equal(res$meta$snapshot$db_release$version, "v3.2.0")
  expect_true(tibble::is_tibble(res$records) && nrow(res$records) >= 1L)
})
