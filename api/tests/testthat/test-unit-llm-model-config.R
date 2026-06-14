test_that("Gemini model config resolves stable default", {
  source(testthat::test_path("../../functions/llm-model-config.R"), local = TRUE)

  withr::local_envvar(GEMINI_MODEL = NA, GEMINI_ALLOWED_MODELS_EXTRA = NA)
  resolved <- llm_model_config_resolve(config = list())

  expect_equal(resolved$model, "gemini-3.5-flash")
  expect_equal(resolved$source, "default")
  expect_true(resolved$valid)
})

test_that("Gemini model config rejects unknown models unless operator allowlisted", {
  source(testthat::test_path("../../functions/llm-model-config.R"), local = TRUE)

  withr::local_envvar(GEMINI_MODEL = "gemini-new-release", GEMINI_ALLOWED_MODELS_EXTRA = NA)
  rejected <- llm_model_config_resolve(config = list())
  expect_false(rejected$valid)
  expect_equal(rejected$error_code, "llm_model_invalid")

  withr::local_envvar(GEMINI_MODEL = "gemini-new-release", GEMINI_ALLOWED_MODELS_EXTRA = "gemini-new-release")
  allowed <- llm_model_config_resolve(config = list())
  expect_true(allowed$valid)
  expect_true(allowed$operator_allowed)
  expect_match(allowed$warning, "operator", ignore.case = TRUE)
})

test_that("Gemini model catalog marks shut-down preview model invalid", {
  source(testthat::test_path("../../functions/llm-model-config.R"), local = TRUE)

  meta <- llm_model_metadata("gemini-3-pro-preview")
  expect_false(meta$allowed)
  expect_equal(meta$status, "shutdown")
})

test_that("every catalog model carries positive cost-estimate pricing", {
  source(testthat::test_path("../../functions/llm-model-config.R"), local = TRUE)

  catalog <- llm_model_catalog()
  expect_true(all(c("price_input_per_million", "price_output_per_million") %in% names(catalog)))
  expect_true(all(catalog$price_input_per_million > 0))
  expect_true(all(catalog$price_output_per_million > 0))
})

test_that("llm_model_pricing keys off the model and falls back for unknown models", {
  source(testthat::test_path("../../functions/llm-model-config.R"), local = TRUE)

  flash <- llm_model_pricing("gemini-3.5-flash")
  pro <- llm_model_pricing("gemini-2.5-pro")
  expect_true(flash$input_per_million > 0 && flash$output_per_million > 0)
  # Pro-tier costs more than flash-tier (per-token).
  expect_gt(pro$input_per_million, flash$input_per_million)
  expect_gt(pro$output_per_million, flash$output_per_million)

  # Unknown models fall back to flash-tier rates, not NA.
  unknown <- llm_model_pricing("gemini-does-not-exist")
  expect_equal(unknown$input_per_million, flash$input_per_million)
  expect_equal(unknown$output_per_million, flash$output_per_million)
})
