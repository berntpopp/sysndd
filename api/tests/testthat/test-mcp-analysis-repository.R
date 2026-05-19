source_mcp_analysis_repository <- function() {
  source("../../functions/mcp-analysis-cache-repository.R")
  source("../../functions/mcp-analysis-repository.R")
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
  source_mcp_analysis_repository()

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

test_that("MCP phenotype repository degrades to unavailable when shared endpoint dependencies fail", {
  source_mcp_analysis_repository()

  old_corr <- get0("generate_phenotype_correlations", envir = .GlobalEnv, ifnotfound = NULL)
  assign("generate_phenotype_correlations", function(...) stop("missing endpoint dependency"), envir = .GlobalEnv)
  withr::defer(
    if (is.null(old_corr)) rm("generate_phenotype_correlations", envir = .GlobalEnv) else assign("generate_phenotype_correlations", old_corr, envir = .GlobalEnv)
  )

  expect_null(mcp_analysis_repo_get_phenotype_correlations())
})

test_that("MCP phenotype cluster repositories degrade to unavailable when shared helpers fail", {
  source_mcp_analysis_repository()

  old_clusters <- get0("generate_phenotype_clusters", envir = .GlobalEnv, ifnotfound = NULL)
  old_functional_hit <- mcp_analysis_repo_functional_cluster_cache_hit
  old_functional <- get0("generate_phenotype_functional_cluster_correlation", envir = .GlobalEnv, ifnotfound = NULL)

  assign("generate_phenotype_clusters", function(...) stop("cluster helper unavailable"), envir = .GlobalEnv)
  assign("mcp_analysis_repo_functional_cluster_cache_hit", function(...) TRUE, envir = .GlobalEnv)
  assign("generate_phenotype_functional_cluster_correlation", function(...) stop("functional helper unavailable"), envir = .GlobalEnv)

  withr::defer({
    if (is.null(old_clusters)) rm("generate_phenotype_clusters", envir = .GlobalEnv) else assign("generate_phenotype_clusters", old_clusters, envir = .GlobalEnv)
    assign("mcp_analysis_repo_functional_cluster_cache_hit", old_functional_hit, envir = .GlobalEnv)
    if (is.null(old_functional)) rm("generate_phenotype_functional_cluster_correlation", envir = .GlobalEnv) else assign("generate_phenotype_functional_cluster_correlation", old_functional, envir = .GlobalEnv)
  })

  expect_null(mcp_analysis_repo_get_phenotype_clusters())
  expect_null(mcp_analysis_repo_get_phenotype_functional_correlations())
})

test_that("MCP functional cluster cache probes degrade when gene lookup fails", {
  source_mcp_analysis_repository()

  old_genes <- get0("generate_ndd_hgnc_ids", envir = .GlobalEnv, ifnotfound = NULL)
  old_cluster <- get0("gen_string_clust_obj_mem", envir = .GlobalEnv, ifnotfound = NULL)

  assign("generate_ndd_hgnc_ids", function(...) stop("gene lookup unavailable"), envir = .GlobalEnv)
  assign("gen_string_clust_obj_mem", memoise::memoise(function(...) tibble::tibble()), envir = .GlobalEnv)
  withr::defer({
    if (is.null(old_genes)) rm("generate_ndd_hgnc_ids", envir = .GlobalEnv) else assign("generate_ndd_hgnc_ids", old_genes, envir = .GlobalEnv)
    if (is.null(old_cluster)) rm("gen_string_clust_obj_mem", envir = .GlobalEnv) else assign("gen_string_clust_obj_mem", old_cluster, envir = .GlobalEnv)
  })

  expect_false(mcp_analysis_repo_functional_cluster_cache_hit())
  expect_null(mcp_analysis_repo_get_phenotype_functional_correlations())
})

test_that("MCP phenotype functional correlations exclude non-SysNDD pseudoclusters", {
  source_mcp_analysis_repository()

  old_functional_hit <- mcp_analysis_repo_functional_memoise_cache_hit
  old_phenotype_hit <- mcp_analysis_repo_phenotype_memoise_cache_hit
  old_functional <- get0("generate_phenotype_functional_cluster_correlation", envir = .GlobalEnv, ifnotfound = NULL)

  include_sfari_seen <- NULL
  assign("mcp_analysis_repo_functional_memoise_cache_hit", function(...) TRUE, envir = .GlobalEnv)
  assign("mcp_analysis_repo_phenotype_memoise_cache_hit", function(...) TRUE, envir = .GlobalEnv)
  assign("generate_phenotype_functional_cluster_correlation", function(include_membership = FALSE,
                                                                       include_sfari = TRUE,
                                                                       ...) {
    include_sfari_seen <<- include_sfari
    list(
      correlation_melted = tibble::tibble(x = "fc_1", y = "pc_1", value = 0.6),
      cluster_membership = tibble::tibble(cluster = c("fc_1", "pc_1"), hgnc_id = c("HGNC:1", "HGNC:1"))
    )
  }, envir = .GlobalEnv)

  withr::defer({
    assign("mcp_analysis_repo_functional_memoise_cache_hit", old_functional_hit, envir = .GlobalEnv)
    assign("mcp_analysis_repo_phenotype_memoise_cache_hit", old_phenotype_hit, envir = .GlobalEnv)
    if (is.null(old_functional)) rm("generate_phenotype_functional_cluster_correlation", envir = .GlobalEnv) else assign("generate_phenotype_functional_cluster_correlation", old_functional, envir = .GlobalEnv)
  })

  result <- mcp_analysis_repo_get_phenotype_functional_correlations()

  expect_false(include_sfari_seen)
  expect_equal(result$x[[1]], "fc_1")
})

test_that("MCP phenotype cluster repositories do not cold-run memoised analysis helpers", {
  source_mcp_analysis_repository()

  old_cluster_helper <- get0("generate_phenotype_clusters", envir = .GlobalEnv, ifnotfound = NULL)
  old_functional_hit <- mcp_analysis_repo_functional_cluster_cache_hit
  old_functional <- get0("generate_phenotype_functional_cluster_correlation", envir = .GlobalEnv, ifnotfound = NULL)
  old_mca <- get0("gen_mca_clust_obj_mem", envir = .GlobalEnv, ifnotfound = NULL)

  cluster_called <- FALSE
  functional_called <- FALSE
  assign("generate_phenotype_clusters", function(...) {
    cluster_called <<- TRUE
    tibble::tibble(cluster = integer(), identifiers = list())
  }, envir = .GlobalEnv)
  assign("mcp_analysis_repo_functional_cluster_cache_hit", function(...) TRUE, envir = .GlobalEnv)
  assign("generate_phenotype_functional_cluster_correlation", function(...) {
    functional_called <<- TRUE
    list(correlation_melted = tibble::tibble(), cluster_membership = tibble::tibble())
  }, envir = .GlobalEnv)
  assign("gen_mca_clust_obj_mem", function(...) tibble::tibble(), envir = .GlobalEnv)
  withr::defer({
    if (is.null(old_cluster_helper)) rm("generate_phenotype_clusters", envir = .GlobalEnv) else assign("generate_phenotype_clusters", old_cluster_helper, envir = .GlobalEnv)
    assign("mcp_analysis_repo_functional_cluster_cache_hit", old_functional_hit, envir = .GlobalEnv)
    if (is.null(old_functional)) rm("generate_phenotype_functional_cluster_correlation", envir = .GlobalEnv) else assign("generate_phenotype_functional_cluster_correlation", old_functional, envir = .GlobalEnv)
    if (is.null(old_mca)) rm("gen_mca_clust_obj_mem", envir = .GlobalEnv) else assign("gen_mca_clust_obj_mem", old_mca, envir = .GlobalEnv)
  })

  expect_null(mcp_analysis_repo_get_phenotype_clusters())
  expect_false(cluster_called)
  expect_null(mcp_analysis_repo_get_phenotype_functional_correlations())
  expect_false(functional_called)
})

test_that("MCP phenotype cluster repository detects shared disk cache payloads when memoise key lookup misses", {
  source_mcp_analysis_repository()

  cache_dir <- withr::local_tempdir()
  withr::local_envvar(c(MCP_CACHE_DIR = cache_dir))
  saveRDS(
    list(
      value = tibble::tibble(
        cluster = "3",
        identifiers = list(tibble::tibble(entity_id = 1L, hgnc_id = "HGNC:1", symbol = "GENE1")),
        hash_filter = "equals(hash,abc)",
        cluster_size = 1L,
        quali_inp_var = list(tibble::tibble(variable = "Seizures"))
      )
    ),
    file.path(cache_dir, "phenotype-clusters.rds")
  )

  old_mca <- get0("gen_mca_clust_obj_mem", envir = .GlobalEnv, ifnotfound = NULL)
  if (exists("gen_mca_clust_obj_mem", envir = .GlobalEnv, inherits = FALSE)) {
    rm("gen_mca_clust_obj_mem", envir = .GlobalEnv)
  }
  withr::defer(
    if (is.null(old_mca)) {
      if (exists("gen_mca_clust_obj_mem", envir = .GlobalEnv, inherits = FALSE)) rm("gen_mca_clust_obj_mem", envir = .GlobalEnv)
    } else {
      assign("gen_mca_clust_obj_mem", old_mca, envir = .GlobalEnv)
    }
  )

  expect_true(mcp_analysis_repo_phenotype_cluster_cache_hit())
})

test_that("MCP phenotype cluster repository reads shared disk payloads without cold-running MCA", {
  source_mcp_analysis_repository()

  cache_dir <- withr::local_tempdir()
  withr::local_envvar(c(MCP_CACHE_DIR = cache_dir))
  saveRDS(
    list(
      value = tibble::tibble(
        cluster = c("3", "4"),
        identifiers = list(
          tibble::tibble(entity_id = 1L, hgnc_id = "HGNC:1", symbol = "GENE1"),
          tibble::tibble(entity_id = 2L, hgnc_id = "HGNC:2", symbol = "GENE2")
        ),
        hash_filter = c("equals(hash,abc)", "equals(hash,def)"),
        cluster_size = c(1L, 1L),
        quali_inp_var = list(tibble::tibble(variable = "Seizures"), tibble::tibble(variable = "Hypotonia"))
      )
    ),
    file.path(cache_dir, "phenotype-clusters.rds")
  )

  old_mca_hit <- mcp_analysis_repo_phenotype_memoise_cache_hit
  old_clusters <- get0("generate_phenotype_clusters", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_phenotype_memoise_cache_hit", function(...) FALSE, envir = .GlobalEnv)
  assign("generate_phenotype_clusters", function(...) stop("cold MCA should not run"), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_phenotype_memoise_cache_hit", old_mca_hit, envir = .GlobalEnv)
    if (is.null(old_clusters)) rm("generate_phenotype_clusters", envir = .GlobalEnv) else assign("generate_phenotype_clusters", old_clusters, envir = .GlobalEnv)
  })

  result <- mcp_analysis_repo_get_phenotype_clusters(gene = "HGNC:1")

  expect_equal(nrow(result), 1L)
  expect_equal(result$cluster[[1]], "3")
  expect_equal(result$hgnc_id[[1]], "HGNC:1")
})

test_that("MCP phenotype cluster disk payloads are enriched with gene identifiers for filtering", {
  source_mcp_analysis_repository()

  cache_dir <- withr::local_tempdir()
  withr::local_envvar(c(MCP_CACHE_DIR = cache_dir))
  saveRDS(
    list(
      value = tibble::tibble(
        cluster = "3",
        identifiers = list(tibble::tibble(entity_id = 1L)),
        hash_filter = "equals(hash,abc)",
        cluster_size = 1L,
        quali_inp_var = list(tibble::tibble(variable = "Seizures"))
      )
    ),
    file.path(cache_dir, "phenotype-clusters.rds")
  )

  old_input <- get0("generate_phenotype_cluster_input", envir = .GlobalEnv, ifnotfound = NULL)
  old_mca_hit <- mcp_analysis_repo_phenotype_memoise_cache_hit
  old_clusters <- get0("generate_phenotype_clusters", envir = .GlobalEnv, ifnotfound = NULL)
  assign("generate_phenotype_cluster_input", function(...) {
    list(
      matrix = data.frame(),
      entity_gene_map = tibble::tibble(entity_id = 1L, hgnc_id = "HGNC:1", symbol = "GENE1")
    )
  }, envir = .GlobalEnv)
  assign("mcp_analysis_repo_phenotype_memoise_cache_hit", function(...) FALSE, envir = .GlobalEnv)
  assign("generate_phenotype_clusters", function(...) stop("cold MCA should not run"), envir = .GlobalEnv)
  withr::defer({
    if (is.null(old_input)) rm("generate_phenotype_cluster_input", envir = .GlobalEnv) else assign("generate_phenotype_cluster_input", old_input, envir = .GlobalEnv)
    assign("mcp_analysis_repo_phenotype_memoise_cache_hit", old_mca_hit, envir = .GlobalEnv)
    if (is.null(old_clusters)) rm("generate_phenotype_clusters", envir = .GlobalEnv) else assign("generate_phenotype_clusters", old_clusters, envir = .GlobalEnv)
  })

  result <- mcp_analysis_repo_get_phenotype_clusters(gene = "GENE1")

  expect_equal(nrow(result), 1L)
  expect_equal(result$hgnc_id[[1]], "HGNC:1")
  expect_equal(result$symbol[[1]], "GENE1")
})

test_that("MCP phenotype functional correlations can be computed from shared disk cluster payloads", {
  source_mcp_analysis_repository()

  cache_dir <- withr::local_tempdir()
  withr::local_envvar(c(MCP_CACHE_DIR = cache_dir))
  saveRDS(
    list(value = tibble::tibble(
      cluster = "3",
      identifiers = list(tibble::tibble(entity_id = 1L, hgnc_id = "HGNC:1", symbol = "GENE1")),
      hash_filter = "equals(hash,abc)",
      cluster_size = 1L,
      quali_inp_var = list(tibble::tibble(variable = "Seizures"))
    )),
    file.path(cache_dir, "phenotype-clusters.rds")
  )
  saveRDS(
    list(value = tibble::tibble(
      cluster = 7L,
      cluster_size = 1L,
      identifiers = list(tibble::tibble(hgnc_id = "HGNC:1")),
      hash_filter = "equals(hash,ghi)",
      term_enrichment = list(tibble::tibble(term = "GO:1")),
      subclusters = list(tibble::tibble())
    )),
    file.path(cache_dir, "functional-clusters.rds")
  )

  old_functional_hit <- mcp_analysis_repo_functional_memoise_cache_hit
  old_phenotype_hit <- mcp_analysis_repo_phenotype_memoise_cache_hit
  old_correlation <- get0("generate_phenotype_functional_cluster_correlation", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_functional_memoise_cache_hit", function(...) FALSE, envir = .GlobalEnv)
  assign("mcp_analysis_repo_phenotype_memoise_cache_hit", function(...) FALSE, envir = .GlobalEnv)
  assign("generate_phenotype_functional_cluster_correlation", function(...) stop("cold correlation should not run"), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_functional_memoise_cache_hit", old_functional_hit, envir = .GlobalEnv)
    assign("mcp_analysis_repo_phenotype_memoise_cache_hit", old_phenotype_hit, envir = .GlobalEnv)
    if (is.null(old_correlation)) rm("generate_phenotype_functional_cluster_correlation", envir = .GlobalEnv) else assign("generate_phenotype_functional_cluster_correlation", old_correlation, envir = .GlobalEnv)
  })

  result <- mcp_analysis_repo_get_phenotype_functional_correlations(gene = "HGNC:1")

  expect_true(nrow(result) > 0L)
  expect_true(any(result$x == "fc_7" | result$y == "fc_7"))
  expect_true(any(result$x == "pc_3" | result$y == "pc_3"))
})


test_that("MCP network repository filters cached edges to the requested gene neighborhood", {
  source_mcp_analysis_repository()

  old_hit <- mcp_analysis_repo_network_memoise_cache_hit
  old_network <- get0("gen_network_edges_mem", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_network_memoise_cache_hit", function(...) TRUE, envir = .GlobalEnv)
  assign("gen_network_edges_mem", function(...) {
    list(
      nodes = tibble::tibble(
        hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
        symbol = c("GENE1", "GENE2", "GENE3"),
        cluster = c(1L, 1L, 2L),
        category = c("Definitive", "Moderate", "Limited")
      ),
      edges = tibble::tibble(
        source = c("HGNC:1", "HGNC:2"),
        target = c("HGNC:2", "HGNC:3"),
        confidence = c(0.9, 0.8)
      ),
      metadata = list(
        edge_count = 2L,
        node_count = 3L,
        cluster_count = 2L,
        category_counts = list(Definitive = 1L, Moderate = 1L, Limited = 1L)
      )
    )
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_network_memoise_cache_hit", old_hit, envir = .GlobalEnv)
    if (is.null(old_network)) rm("gen_network_edges_mem", envir = .GlobalEnv) else assign("gen_network_edges_mem", old_network, envir = .GlobalEnv)
  })

  result <- mcp_analysis_repo_get_network_edges_local(gene = "HGNC:1", max_edges = 10L)
  expect_equal(nrow(result$edges), 1L)
  expect_equal(result$edges$source[[1]], "HGNC:1")
  expect_equal(sort(result$nodes$hgnc_id), c("HGNC:1", "HGNC:2"))
  expect_true(result$metadata$gene_filtered)
  expect_equal(result$metadata$cluster_count, 1L)
  expect_false("Limited" %in% names(result$metadata$category_counts))
})

test_that("MCP network repository detects shared disk cache payloads when memoise key lookup misses", {
  source_mcp_analysis_repository()

  cache_dir <- withr::local_tempdir()
  withr::local_envvar(c(MCP_CACHE_DIR = cache_dir))
  saveRDS(
    list(
      value = list(
        nodes = tibble::tibble(hgnc_id = "HGNC:1", symbol = "GENE1", cluster = 1L),
        edges = tibble::tibble(source = character(), target = character(), confidence = numeric()),
        metadata = list(min_confidence = 400L, cluster_type = "clusters")
      )
    ),
    file.path(cache_dir, "network.rds")
  )

  old_network <- get0("gen_network_edges_mem", envir = .GlobalEnv, ifnotfound = NULL)
  if (exists("gen_network_edges_mem", envir = .GlobalEnv, inherits = FALSE)) {
    rm("gen_network_edges_mem", envir = .GlobalEnv)
  }
  withr::defer(
    if (is.null(old_network)) {
      if (exists("gen_network_edges_mem", envir = .GlobalEnv, inherits = FALSE)) rm("gen_network_edges_mem", envir = .GlobalEnv)
    } else {
      assign("gen_network_edges_mem", old_network, envir = .GlobalEnv)
    }
  )

  expect_true(mcp_analysis_repo_network_cache_hit(cluster_type = "clusters", min_confidence = 400L))
  expect_false(mcp_analysis_repo_network_cache_hit(cluster_type = "subclusters", min_confidence = 400L))
  expect_false(mcp_analysis_repo_network_cache_hit(cluster_type = "clusters", min_confidence = 700L))
})

test_that("MCP network repository reads and filters shared disk cache payloads without cold-running STRING", {
  source_mcp_analysis_repository()

  cache_dir <- withr::local_tempdir()
  withr::local_envvar(c(MCP_CACHE_DIR = cache_dir))
  saveRDS(
    list(
      value = list(
        nodes = tibble::tibble(
          hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
          symbol = c("GENE1", "GENE2", "GENE3"),
          cluster = c(1L, 1L, 2L),
          category = c("Definitive", "Moderate", "Limited")
        ),
        edges = tibble::tibble(
          source = c("HGNC:1", "HGNC:2"),
          target = c("HGNC:2", "HGNC:3"),
          confidence = c(0.9, 0.8)
        ),
        metadata = list(min_confidence = 400L, cluster_type = "clusters")
      )
    ),
    file.path(cache_dir, "network.rds")
  )

  old_network <- get0("gen_network_edges_mem", envir = .GlobalEnv, ifnotfound = NULL)
  if (exists("gen_network_edges_mem", envir = .GlobalEnv, inherits = FALSE)) {
    rm("gen_network_edges_mem", envir = .GlobalEnv)
  }
  withr::defer(
    if (is.null(old_network)) {
      if (exists("gen_network_edges_mem", envir = .GlobalEnv, inherits = FALSE)) rm("gen_network_edges_mem", envir = .GlobalEnv)
    } else {
      assign("gen_network_edges_mem", old_network, envir = .GlobalEnv)
    }
  )

  result <- mcp_analysis_repo_get_network_edges_local(gene = "HGNC:1", max_edges = 10L)

  expect_equal(nrow(result$edges), 1L)
  expect_equal(result$edges$source[[1]], "HGNC:1")
  expect_equal(sort(result$nodes$hgnc_id), c("HGNC:1", "HGNC:2"))
  expect_true(result$metadata$gene_filtered)
  expect_equal(result$metadata$cache_source, "disk_payload_scan")
})

test_that("MCP network repository degrades to unavailable on cached-read errors", {
  source_mcp_analysis_repository()

  old_hit <- mcp_analysis_repo_network_memoise_cache_hit
  old_network <- get0("gen_network_edges_mem", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_analysis_repo_network_memoise_cache_hit", function(...) TRUE, envir = .GlobalEnv)
  assign("gen_network_edges_mem", function(...) stop("cached read failed"), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_network_memoise_cache_hit", old_hit, envir = .GlobalEnv)
    if (is.null(old_network)) rm("gen_network_edges_mem", envir = .GlobalEnv) else assign("gen_network_edges_mem", old_network, envir = .GlobalEnv)
  })

  expect_null(mcp_analysis_repo_get_network_edges_local(gene = "HGNC:1"))
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
