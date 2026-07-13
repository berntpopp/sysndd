test_that("bootstrap helper binds memoised analysis wrappers into the target environment", {
  test_env <- new.env(parent = globalenv())
  test_env$generate_stat_tibble <- function() "stats"
  test_env$generate_gene_news_tibble <- function() "news"
  test_env$nest_gene_tibble <- function() "genes"
  test_env$generate_tibble_fspec <- function() "fspec"
  test_env$gen_string_clust_obj <- function(genes, algorithm = "leiden") {
    list(genes = genes, algorithm = algorithm)
  }
  test_env$gen_mca_clust_obj <- function(matrix) list(rows = nrow(matrix))
  test_env$gen_network_edges <- function(cluster_type = "clusters", min_confidence = 400L) {
    list(cluster_type = cluster_type, min_confidence = min_confidence)
  }
  test_env$generate_phenotype_correlations <- function(filter = "", min_abs_correlation = NULL) {
    tibble::tibble(x = "Seizure", x_id = "HP:0001250", y = "Ataxia", y_id = "HP:0001251", value = 0.42)
  }
  test_env$read_log_files <- function() "logs"
  test_env$nest_pubtator_gene_tibble <- function() "pubtator"

  source_api_file("bootstrap/init_cache.R", local = FALSE, envir = test_env)

  cache_dir <- file.path(tempdir(), paste0("mcp-cache-", Sys.getpid()))
  test_env$bootstrap_bind_memoised(cache_dir = cache_dir, envir = test_env)

  expect_true(memoise::is.memoised(test_env$gen_network_edges_mem))
  expect_true(memoise::is.memoised(test_env$gen_mca_clust_obj_mem))
  expect_true(memoise::is.memoised(test_env$gen_string_clust_obj_mem))
  expect_true(memoise::is.memoised(test_env$generate_phenotype_correlations_mem))
  expect_equal(
    test_env$gen_network_edges_mem(cluster_type = "clusters", min_confidence = 400L)$cluster_type,
    "clusters"
  )
})

test_that("MCP startup does not wire shared memoise result caches", {
  script <- readLines(file.path(get_api_dir(), "start_sysndd_mcp.R"), warn = FALSE)

  expect_false(any(grepl('source\\("bootstrap/init_cache.R"', script, fixed = FALSE)))
  expect_false(any(grepl("bootstrap_bind_memoised", script, fixed = TRUE)))
  expect_false(any(grepl("bootstrap_init_cache_version", script, fixed = TRUE)))
})

test_that("API startup exposes phenotype correlation memoise wrapper for cache warming", {
  script <- paste(readLines(file.path(get_api_dir(), "start_sysndd_api.R"), warn = FALSE), collapse = "\n")

  expect_match(script, "generate_phenotype_correlations_mem\\s*<-\\s*memoised\\$generate_phenotype_correlations_mem")
})

test_that("MCP compose service does not mount the shared API cache", {
  compose <- readLines(file.path(dirname(get_api_dir()), "docker-compose.yml"), warn = FALSE)
  mcp_start <- grep("^  mcp:", compose)
  next_service <- grep("^  [a-zA-Z0-9_-]+:", compose)
  mcp_end <- min(next_service[next_service > mcp_start], length(compose) + 1L) - 1L
  mcp_block <- compose[mcp_start:mcp_end]

  expect_false(any(grepl("api_cache:/app/cache", mcp_block, fixed = TRUE)))
})
