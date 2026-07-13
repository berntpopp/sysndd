test_that("MCP repository queries use only least-privilege public projections", {
  source("../../functions/mcp-repository.R")
  captured <- list()

  old_query <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  assign("db_execute_query", function(sql, params = list(), conn = NULL) {
    captured[[length(captured) + 1L]] <<- list(sql = sql, params = params)
    tibble::tibble(total = integer())
  }, envir = .GlobalEnv)
  withr::defer(
    if (is.null(old_query)) rm("db_execute_query", envir = .GlobalEnv) else assign("db_execute_query", old_query, envir = .GlobalEnv)
  )

  mcp_repo_get_entity_context(123L)
  mcp_repo_get_gene_entities("1", limit = 10L, offset = 0L)
  mcp_repo_get_publication_context("PMID:123456")

  sql <- paste(vapply(captured, `[[`, character(1), "sql"), collapse = "\n")

  expect_match(sql, "mcp_public_entity")
  expect_match(sql, "mcp_public_review")
  expect_match(sql, "mcp_public_review_publication")
  expect_false(grepl("\\bndd_entity_view\\b|\\bndd_entity_review\\b|\\bpublication\\b", sql, ignore.case = TRUE))
  expect_false(grepl("INSERT|UPDATE|DELETE|DROP|ALTER", sql, ignore.case = TRUE))
  expect_true(all(vapply(captured, function(x) is.list(x$params), logical(1))))
})

test_that("MCP repository search and lookup helpers use bounded projection SELECTs", {
  source("../../functions/mcp-search-repository.R")
  source("../../functions/mcp-repository.R")
  captured <- list()

  old_query <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  assign("db_execute_query", function(sql, params = list(), conn = NULL) {
    captured[[length(captured) + 1L]] <<- list(sql = sql, params = params)
    tibble::tibble(metric = character(), value = integer())
  }, envir = .GlobalEnv)
  withr::defer(
    if (is.null(old_query)) rm("db_execute_query", envir = .GlobalEnv) else assign("db_execute_query", old_query, envir = .GlobalEnv)
  )

  mcp_repo_search("MEC", c("gene", "disease"), 5L)
  mcp_repo_find_entities_by_phenotype("HP:0001250", "present", "Definitive", 5L, 0L)
  mcp_repo_count_entities_by_phenotype("HP:0001250", "present", "Definitive")
  mcp_repo_find_entities_by_disease("Rett", 5L, 0L)
  mcp_repo_count_entities_by_disease("Rett")
  mcp_repo_get_stats()

  sql <- paste(vapply(captured, `[[`, character(1), "sql"), collapse = "\n")

  expect_match(sql, "LIMIT")
  expect_match(sql, "COUNT\\(\\*\\) AS total")
  expect_match(sql, "mcp_public_entity")
  expect_match(sql, "mcp_public_review_phenotype")
  expect_false(grepl("SELECT \\*", sql, ignore.case = TRUE))
})

test_that("all MCP repository relations are approved mcp_public projections", {
  repository_paths <- file.path(
    "../../functions",
    c("mcp-repository.R", "mcp-search-repository.R", "mcp-analysis-repository.R")
  )
  source_text <- paste(unlist(lapply(repository_paths, readLines, warn = FALSE)), collapse = "\n")
  relations <- unlist(regmatches(
    source_text,
    gregexpr("(?i)\\b(?:FROM|JOIN)\\s+`?([a-z][a-z0-9_]*)`?", source_text, perl = TRUE)
  ))
  relations <- sub("(?i)^(?:FROM|JOIN)\\s+`?", "", relations, perl = TRUE)
  relations <- sub("`.*$", "", relations)

  expect_gt(length(relations), 0L)
  expect_true(all(grepl("^mcp_public_[a-z0-9_]+$", relations)))
  expect_false(grepl("INFORMATION_SCHEMA", source_text, fixed = TRUE))
  expect_false(grepl("analysis_snapshot_get_public", source_text, fixed = TRUE))
  expect_false(grepl("nddscore_repo_", source_text, fixed = TRUE))
})
