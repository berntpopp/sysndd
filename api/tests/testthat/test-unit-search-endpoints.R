# Behavioural test for GET /api/search/<searchterm>: runs the real handler
# against a stubbed ndd_entity_view, no database needed.

library(testthat)

run_entity_search <- function(searchterm) {
  for (pkg in c("dplyr", "tidyr", "stringr", "stringdist")) skip_if_not_installed(pkg)
  suppressPackageStartupMessages({
    library(dplyr)
    library(tidyr)
    library(stringr)
    library(stringdist)
  })

  env <- new.env(parent = globalenv())
  env$pool <- "STUB_POOL"
  env$tbl <- function(src, name) {
    tibble::tibble(
      entity_id = c(1848L, 184L, 1849L),
      hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
      symbol = c("AAA1", "BBB2", "CCC3"),
      disease_ontology_id_version = c("OMIM:1", "OMIM:2", "OMIM:3"),
      disease_ontology_name = c("Disease one", "Disease two", "Disease three")
    )
  }

  file_path <- file.path(get_api_dir(), "endpoints", "search_endpoints.R")
  src <- readLines(file_path, warn = FALSE)
  dec_line <- grep("^#\\*\\s+@get\\s+<searchterm>\\s*$", src)[[1L]]
  parsed <- parse(file_path, keep.source = TRUE)
  starts <- vapply(attr(parsed, "srcref"), function(s) s[[1L]], integer(1))
  handler <- eval(parsed[[which(starts > dec_line)[[1L]]]], envir = env)

  handler(searchterm, helper = FALSE)
}

test_that("an exact numeric entity id returns only that entity", {
  result <- run_entity_search("1848")

  expect_equal(nrow(result), 1L)
  expect_equal(result$search, "entity_id")
  expect_equal(result$link, "/Entities/1848")
})

test_that("an exact symbol hit still returns a single row", {
  result <- run_entity_search("BBB2")

  expect_equal(nrow(result), 1L)
  expect_equal(result$link, "/Genes/BBB2")
})
