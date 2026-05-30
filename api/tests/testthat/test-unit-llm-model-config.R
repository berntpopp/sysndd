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
