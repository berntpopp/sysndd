# tests/testthat/test-unit-llm-judge-outcome-log.R
#
# Tests that generate_and_validate_with_judge() persists the JUDGE outcome to
# the operator-visible generation log on a non-accept verdict (#490), using the
# authoritative cluster_hash (matching the cache) rather than a recomputed one.
#
# CONTAINER-ONLY: llm-judge.R builds an ellmer type at source time, so these
# tests skip on a host without ellmer.
#   docker exec sysndd-api-1 Rscript -e \
#     "testthat::test_file('/app/tests/testthat/test-unit-llm-judge-outcome-log.R')"

library(testthat)
library(tibble)

source_judge_env <- function() {
  env <- new.env(parent = globalenv())
  env$`%||%` <- function(a, b) if (is.null(a)) b else a
  env$get_default_gemini_model <- function() "gemini-test"
  env$generate_cluster_hash <- function(...) "IDENTIFIER_RECOMPUTED_HASH"
  env$calculate_derived_confidence <- function(...) list(score = "low")
  source_api_file("functions/llm-judge-prompts.R", local = FALSE, envir = env)
  source_api_file("functions/llm-judge.R", local = FALSE, envir = env)
  env
}

test_that("judge rejection logs a validation_failed row with the authoritative hash", {
  skip_if_not_installed("ellmer")
  env <- source_judge_env()
  logged <- new.env()

  env$generate_cluster_summary <- function(cluster_data, cluster_type, model, cluster_hash = NULL, ...) {
    logged$gen_hash <- cluster_hash
    list(success = TRUE, summary = list(summary = "over-broad", tags = c("id")))
  }
  env$validate_with_llm_judge <- function(...) {
    list(verdict = "reject", reasoning = "over-broad, low specificity")
  }
  env$save_summary_to_cache <- function(cluster_type, cluster_number, cluster_hash, ...) {
    logged$saved_hash <- cluster_hash
    42L
  }
  env$log_generation_attempt <- function(cluster_type, cluster_number, cluster_hash,
                                          model_name, status, ...) {
    args <- list(...)
    logged$status <- status
    logged$log_hash <- cluster_hash
    logged$validation_errors <- args$validation_errors
    1L
  }

  res <- env$generate_and_validate_with_judge(
    cluster_data = list(identifiers = tibble::tibble(entity_id = 1:3), cluster_number = 2L),
    cluster_type = "phenotype",
    cluster_hash = "175f540336"
  )

  expect_equal(res$validation_status, "rejected")
  expect_equal(logged$status, "validation_failed")
  expect_equal(logged$validation_errors, "over-broad, low specificity")
  # The log, cache, and generation-call hashes all agree with the authoritative
  # snapshot hash (not the identifier-recomputed value) (#490 secondary).
  expect_equal(logged$log_hash, "175f540336")
  expect_equal(logged$saved_hash, "175f540336")
  expect_equal(logged$gen_hash, "175f540336")
})

test_that("an accept verdict does not emit an extra validation_failed judge-outcome log", {
  skip_if_not_installed("ellmer")
  env <- source_judge_env()
  logged <- new.env()
  logged$calls <- 0L

  env$generate_cluster_summary <- function(cluster_data, cluster_type, model, cluster_hash = NULL, ...) {
    list(success = TRUE, summary = list(summary = "grounded clinical summary", tags = character()))
  }
  env$validate_with_llm_judge <- function(...) list(verdict = "accept", reasoning = "grounded")
  env$save_summary_to_cache <- function(...) 7L
  env$log_generation_attempt <- function(...) {
    logged$calls <- logged$calls + 1L
    1L
  }

  res <- env$generate_and_validate_with_judge(
    cluster_data = list(identifiers = tibble::tibble(entity_id = 1:3), cluster_number = 1L),
    cluster_type = "phenotype",
    cluster_hash = "h"
  )

  expect_true(res$success)
  expect_equal(logged$calls, 0L)
})
