test_that("fast CI test selection excludes slow and live API suites", {
  env <- new.env(parent = globalenv())
  source_api_file("scripts/test-selection.R", local = FALSE, envir = env)

  fast_files <- basename(env$list_ci_test_files("fast"))

  expect_false("test-e2e-user-lifecycle.R" %in% fast_files)
  expect_false("test-integration-email.R" %in% fast_files)
  expect_false("test-external-pubmed.R" %in% fast_files)
  expect_false("test-external-pubtator.R" %in% fast_files)
  expect_false("test-integration-health.R" %in% fast_files)
  expect_false("test-integration-version.R" %in% fast_files)
  expect_false("test-integration-async.R" %in% fast_files)
  expect_false("test-integration-auth.R" %in% fast_files)
  expect_false("test-integration-llm-endpoints.R" %in% fast_files)

  expect_true("test-endpoint-auth.R" %in% fast_files)
  expect_true("test-unit-auth-service.R" %in% fast_files)
})

test_that("full CI test selection includes all test files", {
  env <- new.env(parent = globalenv())
  source_api_file("scripts/test-selection.R", local = FALSE, envir = env)

  full_files <- env$list_ci_test_files("full")
  expected_files <- normalizePath(list.files(
    test_path(),
    pattern = "^test-.*\\.R$",
    full.names = TRUE
  ))

  expect_setequal(full_files, expected_files)
})

test_that("CI test selection rejects unknown modes", {
  env <- new.env(parent = globalenv())
  source_api_file("scripts/test-selection.R", local = FALSE, envir = env)

  expect_error(
    env$list_ci_test_files("bogus"),
    "Unknown CI test selection mode"
  )
})
