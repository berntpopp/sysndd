test_that("external proxy budgets are short and source-specific", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)
  withr::local_envvar(c(
    EXTERNAL_PROXY_TIMEOUT_SECONDS = NA,
    EXTERNAL_PROXY_MAX_SECONDS = NA,
    EXTERNAL_PROXY_MAX_TRIES = NA,
    EXTERNAL_PROXY_MGI_TIMEOUT_SECONDS = NA,
    EXTERNAL_PROXY_MGI_MAX_SECONDS = NA,
    EXTERNAL_PROXY_MGI_MAX_TRIES = NA,
    EXTERNAL_PROXY_GNOMAD_TIMEOUT_SECONDS = NA
  ))

  mgi <- external_proxy_budget("mgi")
  gnomad <- external_proxy_budget("gnomad")

  expect_lte(mgi$timeout_seconds, 8)
  expect_lte(mgi$max_seconds, 12)
  expect_lte(gnomad$timeout_seconds, 8)
  expect_true(mgi$max_tries >= 1L)
})

test_that("external proxy timing wrapper preserves result and records elapsed metadata", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)

  result <- external_proxy_with_timing("mgi", function() list(source = "mgi", found = FALSE))

  expect_false(isTRUE(result$error))
  expect_equal(result$source, "mgi")
  expect_true(is.numeric(result$elapsed_ms))
})

test_that("external proxy aggregate budget is bounded and configurable", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)
  withr::local_envvar(c(EXTERNAL_PROXY_AGGREGATE_MAX_SECONDS = NA))

  expect_equal(external_proxy_aggregate_budget(), 12)

  withr::local_envvar(c(EXTERNAL_PROXY_AGGREGATE_MAX_SECONDS = "5"))
  expect_equal(external_proxy_aggregate_budget(), 5)
})

test_that("external proxy aggregate helper reports skipped sources after budget", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)
  withr::local_envvar(c(EXTERNAL_PROXY_AGGREGATE_MAX_SECONDS = "0.001"))

  result <- external_proxy_aggregate_sources(
    "GENE1",
    list(
      first = function() {
        Sys.sleep(0.01)
        list(source = "first")
      },
      second = function() stop("second should be skipped")
    ),
    instance = "/api/external/gene/GENE1"
  )

  expect_true(result$partial)
  expect_equal(result$skipped_sources, list("second"))
  expect_true(is.null(result$errors$second))
})

test_that("external proxy aggregate helper keeps error-then-skip partial", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)
  withr::local_envvar(c(EXTERNAL_PROXY_AGGREGATE_MAX_SECONDS = "0.001"))

  result <- external_proxy_aggregate_sources(
    "GENE1",
    list(
      first = function() {
        Sys.sleep(0.01)
        stop("first failed")
      },
      second = function() list(source = "second")
    ),
    instance = "/api/external/gene/GENE1"
  )
  successful_sources <- Filter(function(s) !isTRUE(s$found == FALSE), result$sources)
  would_return_503 <- !isTRUE(result$partial) && length(successful_sources) == 0 && length(result$errors) > 0

  expect_true(result$partial)
  expect_equal(result$skipped_sources, list("second"))
  expect_false(would_return_503)
})
