library(testthat)

source_llm_batch_for_progress_tests <- function() {
  env <- new.env(parent = globalenv())
  env$generate_cluster_summary <- function(...) NULL
  env$get_cached_summary <- function(...) NULL
  env$create_progress_reporter <- function(...) function(...) invisible(NULL)
  env$generate_and_validate_with_judge <- function(...) NULL
  source_api_file("functions/llm-batch-generator.R", local = FALSE, envir = env)
  env
}

test_that("LLM cluster progress message accepts character phenotype cluster IDs", {
  env <- source_llm_batch_for_progress_tests()

  expect_equal(
    env$llm_cluster_progress_message("8", 1L, 5L),
    "Cluster 8 (1/5)"
  )
  expect_equal(
    env$llm_cluster_progress_message("functional cluster 8", 1L, 5L),
    "Cluster functional cluster 8 (1/5)"
  )
})
