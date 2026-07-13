test_that("MCP search token scoring ranks aliases and phrase token matches", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "services", "mcp-service.R"), local = TRUE)
  source(file.path(api_dir, "functions", "mcp-search-repository.R"), local = TRUE)
  source(file.path(api_dir, "services", "mcp-query-service.R"), local = TRUE)

  expect_equal(mcp_search_tokens("NMDA receptor"), c("NMDA", "RECEPTOR"))

  candidates <- tibble::tibble(
    type = c("gene", "gene"),
    id = c("GRIN2A", "GENE2"),
    label = c("GRIN2A", "GENE2"),
    description = c("glutamate ionotropic receptor NMDA type subunit 2A", "unrelated"),
    matched_field = c("name", "symbol"),
    match_tier = c("token_overlap", "contains"),
    token_matches = c(2L, 0L)
  )

  ranked <- mcp_rank_search_candidates(candidates)
  expect_equal(ranked$id[[1]], "GRIN2A")
})

test_that("MCP search fallback scores use the same 100-1000 scale as repository scores", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "services", "mcp-service.R"), local = TRUE)

  expect_equal(mcp_score_for_tier("exact_identifier"), 1000)
  expect_equal(mcp_score_for_tier("exact_label"), 950)
  expect_equal(mcp_score_for_tier("prefix"), 800)
  expect_equal(mcp_score_for_tier("contains"), 600)
})

test_that("MCP capabilities expose only projection-safe snapshot diagnostics", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "services", "mcp-service.R"), local = TRUE)
  source(file.path(api_dir, "services", "mcp-capabilities-service.R"), local = TRUE)

  caps <- mcp_get_sysndd_capabilities()

  expect_true("snapshot_missing" %in% caps$error_codes)
  expect_false("snapshot_stale" %in% caps$error_codes)
  expect_false("source_version_mismatch" %in% caps$error_codes)
  expect_null(caps$error_examples$snapshot_stale)
  expect_null(caps$error_examples$source_version_mismatch)
  expect_false("result_cache" %in% names(caps))
  expect_false(grepl("cache_ttl_seconds|in-process result cache", paste(capture.output(str(caps)), collapse = "\n"), fixed = FALSE))
})

test_that("MCP search zero-result response includes diagnostics", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "services", "mcp-service.R"), local = TRUE)
  source(file.path(api_dir, "services", "mcp-query-service.R"), local = TRUE)

  old_repo <- get0("mcp_repo_search", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_repo_search", function(query, types, limit) tibble::tibble(), envir = .GlobalEnv)
  on.exit(
    {
      if (is.null(old_repo)) rm("mcp_repo_search", envir = .GlobalEnv) else assign("mcp_repo_search", old_repo, envir = .GlobalEnv)
    },
    add = TRUE
  )

  result <- mcp_search_sysndd("epilepsy aphasia", types = c("gene", "disease"), limit = 10)
  expect_equal(result$meta$returned, 0L)
  expect_equal(result$meta$query_tokens, c("EPILEPSY", "APHASIA"))
  expect_true(length(result$meta$searched_types) > 0)
})

test_that("MCP search expands phrase tokens across non-gene result types", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "functions", "mcp-search-repository.R"), local = TRUE)
  source(file.path(api_dir, "functions", "mcp-repository.R"), local = TRUE)

  old_db <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  calls <- list()
  assign("db_execute_query", function(query, params = list(), conn = NULL) {
    calls[[length(calls) + 1L]] <<- list(query = query, params = params)
    tibble::tibble()
  }, envir = .GlobalEnv)
  on.exit(
    {
      if (is.null(old_db)) rm("db_execute_query", envir = .GlobalEnv) else assign("db_execute_query", old_db, envir = .GlobalEnv)
    },
    add = TRUE
  )

  mcp_repo_search(
    "epilepsy aphasia",
    types = c("entity", "disease", "phenotype", "variant"),
    limit = 10L
  )

  all_params <- as.character(unlist(lapply(calls, `[[`, "params"), use.names = FALSE))
  all_sql <- paste(vapply(calls, `[[`, "query", FUN.VALUE = character(1)), collapse = "\n")

  expect_gte(sum(all_params == "%EPILEPSY%"), 4L)
  expect_gte(sum(all_params == "%APHASIA%"), 4L)
  expect_true(grepl("disease_ontology_name", all_sql, fixed = TRUE))
  expect_true(grepl("HPO_term", all_sql, fixed = TRUE))
  expect_true(grepl("definition", all_sql, fixed = TRUE))
})
