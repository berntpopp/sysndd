# tests/testthat/test-unit-llm-summary-cache-version.R
#
# Unit tests for the version-aware LLM summary cache key + orphan retirement
# (#485). Pure tests (no DB): db_execute_query / db_execute_statement /
# db_with_transaction are stubbed in a fresh env before sourcing the repository,
# so RMariaDB never loads.
#
# Host-runnable:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-llm-summary-cache-version.R')"

library(testthat)
library(tibble)

source_cache_repo_env <- function() {
  env <- new.env(parent = globalenv())
  env$`%||%` <- function(a, b) if (is.null(a)) b else a
  # Pre-define DB helpers so the repository's `if (!exists("db_execute_query"))`
  # guard does not source db-helpers.R (which would pull in RMariaDB).
  env$db_execute_query <- function(...) tibble::tibble()
  env$db_execute_statement <- function(...) 0L
  env$db_with_transaction <- function(fn, ...) fn(NULL)
  source_api_file("functions/llm-summary-config.R", local = FALSE, envir = env)
  # tidyverse is not installed on the host CI image; the repository's top-level
  # require(tidyverse) warns (non-fatally) and we do not exercise any tidyverse
  # verb here, so silence that noise.
  suppressWarnings(source_api_file("functions/llm-cache-repository.R", local = FALSE, envir = env))
  env
}

test_that("LLM_SUMMARY_PROMPT_VERSION is a defined non-empty version string", {
  # The specific value is an implementation choice (bump only on a GENERATION
  # prompt change — see llm-summary-config.R); the invariant is that it exists,
  # is a scalar string, and is bound into every write/lookup (covered below).
  env <- source_cache_repo_env()
  expect_true(is.character(env$LLM_SUMMARY_PROMPT_VERSION))
  expect_length(env$LLM_SUMMARY_PROMPT_VERSION, 1L)
  expect_true(nzchar(env$LLM_SUMMARY_PROMPT_VERSION))
})

test_that("get_cached_summary binds the prompt version into the lookup", {
  env <- source_cache_repo_env()
  captured <- new.env()
  env$db_execute_query <- function(sql, params = list(), ...) {
    captured$sql <- sql
    captured$params <- params
    tibble::tibble() # 0 rows -> NULL
  }

  expect_null(env$get_cached_summary("abc123"))
  expect_match(captured$sql, "prompt_version = ?", fixed = TRUE)
  # cluster_hash then prompt_version constant
  expect_equal(captured$params[[1]], "abc123")
  expect_equal(captured$params[[length(captured$params)]], env$LLM_SUMMARY_PROMPT_VERSION)
})

test_that("get_cached_summary(require_validated=TRUE) still binds prompt version", {
  env <- source_cache_repo_env()
  captured <- new.env()
  env$db_execute_query <- function(sql, params = list(), ...) {
    captured$sql <- sql
    captured$params <- params
    tibble::tibble()
  }

  env$get_cached_summary("abc123", require_validated = TRUE)
  expect_match(captured$sql, "validation_status = 'validated'", fixed = TRUE)
  expect_match(captured$sql, "prompt_version = ?", fixed = TRUE)
  expect_equal(captured$params[[length(captured$params)]], env$LLM_SUMMARY_PROMPT_VERSION)
})

test_that("save_summary_to_cache defaults prompt_version to the central constant", {
  env <- source_cache_repo_env()
  default_expr <- formals(env$save_summary_to_cache)$prompt_version
  expect_equal(as.character(default_expr), "LLM_SUMMARY_PROMPT_VERSION")
  expect_equal(eval(default_expr, envir = env), env$LLM_SUMMARY_PROMPT_VERSION)
})

test_that("save_summary_to_cache writes the constant prompt_version into the INSERT", {
  env <- source_cache_repo_env()
  captured <- new.env()
  env$db_with_transaction <- function(fn, ...) fn(NULL)
  env$db_execute_statement <- function(sql, params, conn = NULL) {
    if (grepl("INSERT INTO llm_cluster_summary_cache", sql)) {
      captured$insert_params <- params
    }
    1L
  }
  env$db_execute_query <- function(sql, ...) tibble::tibble(id = 99L)

  id <- env$save_summary_to_cache(
    cluster_type = "phenotype",
    cluster_number = 2L,
    cluster_hash = "hashX",
    model_name = "gemini-test",
    summary_json = list(summary = "x")
  )
  expect_equal(id, 99L)
  # INSERT column order: type, number, hash, model, prompt_version, ...
  expect_equal(captured$insert_params[[5]], env$LLM_SUMMARY_PROMPT_VERSION)
})

test_that("retire_orphan_cluster_summaries emits a hash-scoped NOT IN update", {
  env <- source_cache_repo_env()
  captured <- new.env()
  env$db_execute_statement <- function(sql, params, conn = NULL) {
    captured$sql <- sql
    captured$params <- params
    captured$conn <- conn
    2L
  }

  n <- env$retire_orphan_cluster_summaries("phenotype", c("h1", "h2"), conn = "CONN")
  expect_equal(n, 2L)
  expect_match(captured$sql, "SET is_current = 0", fixed = TRUE)
  expect_match(captured$sql, "cluster_hash NOT IN", fixed = TRUE)
  expect_match(captured$sql, "cluster_type = ?", fixed = TRUE)
  # NOTE: no validation_status predicate — a rejected-but-live hash IN the
  # snapshot must be kept (#490), so retirement is by hash membership only.
  expect_false(grepl("validation_status", captured$sql))
  expect_equal(captured$params, list("phenotype", "h1", "h2"))
  expect_equal(captured$conn, "CONN")
})

test_that("retire_orphan_cluster_summaries is a no-op with no current hashes", {
  env <- source_cache_repo_env()
  called <- FALSE
  env$db_execute_statement <- function(...) {
    called <<- TRUE
    0L
  }
  expect_equal(env$retire_orphan_cluster_summaries("phenotype", character()), 0L)
  expect_equal(env$retire_orphan_cluster_summaries("phenotype", c(NA_character_, "")), 0L)
  expect_false(called)
})
