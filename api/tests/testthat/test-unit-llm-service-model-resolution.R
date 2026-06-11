# test-unit-llm-service-model-resolution.R
#
# Issue #348: get_or_generate_summary() must not hardcode a Gemini model. When
# called without an explicit `model`, it must resolve the default through
# get_default_gemini_model() so the centralized config / GEMINI_MODEL override
# is honored and the shut-down `gemini-3-pro-preview` is never the default.
#
# This is a pure-logic unit test. Database- and network-backed dependencies of
# llm-service.R are stubbed in the global environment before sourcing so that
# RMariaDB / tidyverse / live Gemini are never required.

library(testthat)

api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/llm-service.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Captures the model argument that get_or_generate_summary() forwards to
# generate_cluster_summary(), so each test can assert the resolved value.
.captured_model_env <- new.env(parent = emptyenv())

original_wd <- getwd()
setwd(api_dir)
tryCatch(
  {
    register_test_stub <- function(name, fn) {
      base::assign(name, fn, envir = .GlobalEnv)
    }

    if (!exists("%||%", mode = "function")) {
      base::assign("%||%", function(a, b) if (is.null(a)) b else a, envir = .GlobalEnv)
    }

    # Real centralized model config must load first so llm-service.R does not
    # re-source its split modules (and so get_default_gemini_model is genuine).
    suppressMessages(source("functions/llm-model-config.R", local = FALSE))

    # Stub DB/validation/generation dependencies so llm-service.R's guarded
    # source() calls are skipped and no real DB or Gemini call happens.
    register_test_stub("generate_cluster_hash", function(identifiers, cluster_type = "functional") {
      "deadbeefcafef00d"
    })
    register_test_stub("validate_summary_entities", function(...) list(is_valid = TRUE, errors = character(0)))
    register_test_stub("get_cached_summary", function(...) NULL)
    register_test_stub("save_summary_to_cache", function(...) 1L)
    register_test_stub("log_generation_attempt", function(...) invisible(NULL))
    register_test_stub("calculate_derived_confidence", function(...) 0.9)
    register_test_stub("get_db_connection", function() stop("Database not available"))

    # Capture the model forwarded by get_or_generate_summary().
    capture_generate_cluster_summary <- function(
      cluster_data,
      cluster_type = "functional",
      model = NULL,
      ...
    ) {
      .captured_model_env$model <- model
      list(
        success = TRUE,
        summary = list(model_name = model),
        validation = list(is_valid = TRUE)
      )
    }
    register_test_stub("generate_cluster_summary", capture_generate_cluster_summary)

    suppressMessages(source("functions/llm-service.R", local = FALSE))
  },
  error = function(e) {
    message("Note: llm-service.R not fully loaded - ", e$message)
  },
  finally = setwd(original_wd)
)

sample_cluster_data <- function() {
  list(
    identifiers = data.frame(
      hgnc_id = 1:3,
      symbol = c("GENE1", "GENE2", "GENE3"),
      stringsAsFactors = FALSE
    ),
    cluster_number = 1L
  )
}

test_that("get_or_generate_summary resolves a supported model when none is given", {
  skip_if_not(exists("get_or_generate_summary", mode = "function"))

  withr::local_envvar(GEMINI_MODEL = NA, GEMINI_ALLOWED_MODELS_EXTRA = NA)
  .captured_model_env$model <- NULL

  result <- get_or_generate_summary(
    cluster_data = sample_cluster_data(),
    cluster_type = "functional"
  )

  expect_true(result$success)
  resolved <- .captured_model_env$model
  expect_false(is.null(resolved))
  expect_true(resolved %in% list_gemini_models())
  expect_false(identical(resolved, "gemini-3-pro-preview"))
  expect_equal(resolved, LLM_DEFAULT_GEMINI_MODEL)
})

test_that("get_or_generate_summary honors the GEMINI_MODEL override", {
  skip_if_not(exists("get_or_generate_summary", mode = "function"))

  withr::local_envvar(GEMINI_MODEL = "gemini-2.5-pro", GEMINI_ALLOWED_MODELS_EXTRA = NA)
  .captured_model_env$model <- NULL

  result <- get_or_generate_summary(
    cluster_data = sample_cluster_data(),
    cluster_type = "functional"
  )

  expect_true(result$success)
  expect_equal(.captured_model_env$model, "gemini-2.5-pro")
})

test_that("get_or_generate_summary forwards an explicit model unchanged", {
  skip_if_not(exists("get_or_generate_summary", mode = "function"))

  withr::local_envvar(GEMINI_MODEL = NA, GEMINI_ALLOWED_MODELS_EXTRA = NA)
  .captured_model_env$model <- NULL

  result <- get_or_generate_summary(
    cluster_data = sample_cluster_data(),
    cluster_type = "functional",
    model = "gemini-3.1-flash-lite"
  )

  expect_true(result$success)
  expect_equal(.captured_model_env$model, "gemini-3.1-flash-lite")
})
