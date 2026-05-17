test_that("MCP repository queries use approved public views and primary approved review gates", {
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

  expect_match(sql, "ndd_entity_view")
  expect_match(sql, "is_primary\\s*=\\s*1")
  expect_match(sql, "review_approved\\s*=\\s*1")
  expect_false(grepl("LEFT\\s+JOIN\\s+ndd_review_publication_join|LEFT\\s+JOIN\\s+ndd_entity_review|LEFT\\s+JOIN\\s+ndd_entity_view", sql, ignore.case = TRUE))
  expect_false(grepl("INSERT|UPDATE|DELETE|DROP|ALTER", sql, ignore.case = TRUE))
  expect_true(all(vapply(captured, function(x) is.list(x$params), logical(1))))
})

test_that("MCP repository search and lookup helpers use bounded SELECT queries", {
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
  expect_match(sql, "ndd_entity_view")
  expect_false(grepl("SELECT \\*", sql, ignore.case = TRUE))
})
