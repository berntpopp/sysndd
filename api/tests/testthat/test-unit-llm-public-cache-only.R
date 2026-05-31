# test-unit-llm-public-cache-only.R
#
# Security gate: public path for LLM cluster summaries must be cache-hit-only.
# Generation (Gemini API calls) must only happen for authenticated Curator+.
#
# Tests use stubs in .GlobalEnv so no database or Gemini key is needed.
# Run from api/ directory:
#   Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-llm-public-cache-only.R')"

library(testthat)

# Source into .GlobalEnv explicitly so get_cluster_summary resolves its
# internal helpers (get_cached_summary, format_summary_response, etc.) from
# .GlobalEnv, where the per-test local_mocks stubs are installed.
source_api_file("functions/llm-endpoint-helpers.R", local = FALSE, envir = .GlobalEnv)

# Stub the cache + generation seams in the global env.
local_mocks <- function(cached_value, gen_called_env) {
  assign("get_cached_summary", function(...) cached_value, envir = .GlobalEnv)
  assign("is_gemini_configured", function() TRUE, envir = .GlobalEnv)
  assign("fetch_cluster_data_for_generation", function(...) list(genes = "X"), envir = .GlobalEnv)
  assign("get_or_generate_summary", function(...) {
    gen_called_env$called <- TRUE
    list(success = TRUE, cache_id = 1, summary = list(model_name = "m"))
  }, envir = .GlobalEnv)
  assign("format_summary_response", function(cached, n) list(ok = TRUE), envir = .GlobalEnv)
  assign("extract_raw_hash", function(h) h, envir = .GlobalEnv)
}

test_that("anonymous cache MISS does NOT call Gemini and returns 404", {
  env <- new.env(); env$called <- FALSE
  local_mocks(cached_value = NULL, gen_called_env = env)
  res <- new.env(); res$status <- 200L
  out <- get_cluster_summary("abc", "1", "functional", res, allow_generation = FALSE)
  expect_false(env$called)
  expect_equal(res$status, 404L)
})

test_that("cache HIT returns the summary without generation", {
  env <- new.env(); env$called <- FALSE
  local_mocks(cached_value = data.frame(validation_status = "validated"), gen_called_env = env)
  res <- new.env(); res$status <- 200L
  out <- get_cluster_summary("abc", "1", "functional", res, allow_generation = FALSE)
  expect_false(env$called)
  expect_true(isTRUE(out$ok))
})
