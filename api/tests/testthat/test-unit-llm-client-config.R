source_llm_client_config <- function() {
  source(testthat::test_path("../../functions/llm-model-config.R"))
  source(testthat::test_path("../../functions/llm-client.R"))
}

test_that("Gemini placeholder API keys are treated as unconfigured", {
  source_llm_client_config()

  withr::local_envvar(GEMINI_API_KEY = "")
  expect_false(is_gemini_configured())

  withr::local_envvar(GEMINI_API_KEY = "your_gemini_api_key_here")
  expect_false(is_gemini_configured())

  withr::local_envvar(GEMINI_API_KEY = "your-api-key")
  expect_false(is_gemini_configured())
})

test_that("Gemini configuration accepts non-placeholder keys", {
  source_llm_client_config()

  withr::local_envvar(GEMINI_API_KEY = "test-valid-looking-key")
  expect_true(is_gemini_configured())
})

test_that("Gemini model choices expose current text generation models", {
  source_llm_client_config()

  models <- list_gemini_models()

  expect_equal(models[[1]], "gemini-3.5-flash")
  expect_true("gemini-3.1-flash-lite" %in% models)
  expect_true("gemini-3.1-pro-preview" %in% models)
  expect_false("gemini-3.1-flash-lite-preview" %in% models)
  expect_false("gemini-3-flash-preview" %in% models)
  expect_false(any(grepl("image|tts|live", models)))
})

test_that("Gemini model metadata describes current default model", {
  source_llm_client_config()

  info <- get_gemini_model_metadata("gemini-3.5-flash")

  expect_equal(info$display_name, "Gemini 3.5 Flash")
  expect_equal(info$recommended_for, "Default summaries")
})

test_that("Gemini client rejects invalid configured models before API calls", {
  source_llm_client_config()

  result <- generate_cluster_summary(
    cluster_data = list(),
    cluster_type = "functional",
    model = "gemini-3-pro-preview"
  )

  expect_false(result$success)
  expect_equal(result$error_code, "llm_model_invalid")
  expect_equal(result$attempts, 0L)
})
