# Behavioural test for GET /api/list/inheritance (tree = FALSE): runs the real
# handler against a stubbed mode_of_inheritance_list, no database needed.

library(testthat)

test_that("GET inheritance without tree paginates the raw rows", {
  for (pkg in c("dplyr", "tidyr")) skip_if_not_installed(pkg)
  suppressPackageStartupMessages({
    library(dplyr)
    library(tidyr)
  })
  for (helper in c("response-fields-helpers.R", "pagination-helpers.R")) {
    source(file.path(get_api_dir(), "functions", helper), local = TRUE)
  }

  env <- new.env(parent = environment())
  env$pool <- "STUB_POOL"
  env$tbl <- function(src, name) {
    tibble::tibble(
      hpo_mode_of_inheritance_term = c("HP:0000006", "HP:0000007", "HP:0001417"),
      hpo_mode_of_inheritance_term_name = c("Autosomal dominant", "Autosomal recessive", "X-linked"),
      is_active = c(1L, 1L, 0L),
      update_date = as.Date("2024-01-01")
    )
  }

  file_path <- file.path(get_api_dir(), "endpoints", "list_endpoints.R")
  src <- readLines(file_path, warn = FALSE)
  dec_line <- grep("^#\\*\\s+@get\\s+inheritance\\s*$", src)[[1L]]
  parsed <- parse(file_path, keep.source = TRUE)
  starts <- vapply(attr(parsed, "srcref"), function(s) s[[1L]], integer(1))
  handler <- eval(parsed[[which(starts > dec_line)[[1L]]]], envir = env)

  result <- handler(tree = FALSE)

  expect_equal(result$data$hpo_mode_of_inheritance_term, c("HP:0000006", "HP:0000007"))
  expect_equal(
    result$data$hpo_mode_of_inheritance_term_name,
    c("Autosomal dominant", "Autosomal recessive")
  )
})
