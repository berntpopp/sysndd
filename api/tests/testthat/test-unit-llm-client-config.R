test_that("Gemini placeholder API keys are treated as unconfigured", {
  source(testthat::test_path("../../functions/llm-client.R"))

  withr::local_envvar(GEMINI_API_KEY = "")
  expect_false(is_gemini_configured())

  withr::local_envvar(GEMINI_API_KEY = "your_gemini_api_key_here")
  expect_false(is_gemini_configured())

  withr::local_envvar(GEMINI_API_KEY = "your-api-key")
  expect_false(is_gemini_configured())
})

test_that("Gemini configuration accepts non-placeholder keys", {
  source(testthat::test_path("../../functions/llm-client.R"))

  withr::local_envvar(GEMINI_API_KEY = "test-valid-looking-key")
  expect_true(is_gemini_configured())
})

test_that("Gemini model choices expose current text generation models", {
  source(testthat::test_path("../../functions/llm-client.R"))

  models <- list_gemini_models()

  expect_equal(models[[1]], "gemini-3.5-flash")
  expect_true("gemini-3.1-flash-lite" %in% models)
  expect_true("gemini-3.1-pro-preview" %in% models)
  expect_true("gemini-3.1-flash-lite-preview" %in% models)
  expect_false(any(grepl("image|tts|live", models)))
})

test_that("Gemini model metadata describes current default model", {
  source(testthat::test_path("../../functions/llm-client.R"))

  info <- get_gemini_model_metadata("gemini-3.5-flash")

  expect_equal(info$display_name, "Gemini 3.5 Flash")
  expect_equal(info$recommended_for, "Default summaries")
})
