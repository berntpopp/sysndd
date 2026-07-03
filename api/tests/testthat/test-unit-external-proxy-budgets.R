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

test_that("gnomAD proxy fetchers use central external request budgets", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "functions", "external-proxy-functions.R"), local = TRUE)
  withr::local_envvar(c(
    EXTERNAL_PROXY_MAX_SECONDS = NA,
    EXTERNAL_PROXY_GNOMAD_MAX_SECONDS = NA
  ))

  gnomad <- external_proxy_budget("gnomad")
  source_text <- paste(readLines(file.path(api_dir, "functions", "external-proxy-gnomad.R"), warn = FALSE), collapse = "\n")

  expect_lte(gnomad$max_seconds, 12)
  expect_match(source_text, 'external_proxy_budget\\("gnomad"\\)')
  expect_false(grepl("max_seconds = 120", source_text, fixed = TRUE))
  expect_false(grepl("req_timeout(30)", source_text, fixed = TRUE))
})

test_that("external proxy timing wrapper preserves result and records elapsed metadata", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)

  messages <- character()
  result <- withCallingHandlers(
    external_proxy_with_timing("mgi", function() list(source = "mgi", found = FALSE)),
    message = function(m) {
      messages <<- c(messages, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )

  expect_false(isTRUE(result$error))
  expect_equal(result$source, "mgi")
  expect_true(is.numeric(result$elapsed_ms))
  expect_true(any(grepl("status=404", messages, fixed = TRUE)))
  expect_false(any(grepl("cache=unknown", messages, fixed = TRUE)))
})

test_that("external proxy timing wrapper logs result cache status when supplied", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)

  messages <- character()
  result <- withCallingHandlers(
    external_proxy_with_timing("mgi", function() list(source = "mgi", cache_status = "hit")),
    message = function(m) {
      messages <<- c(messages, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )

  expect_equal(result$cache_status, "hit")
  expect_true(any(grepl("cache=hit", messages, fixed = TRUE)))
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
  # Budget must sit safely above OS scheduling jitter (a 1ms budget occasionally
  # tripped the check at source #1 under CI load, wrongly skipping `first`) yet
  # well below `first`'s runtime so `second` is deterministically skipped once
  # `first` has run.
  withr::local_envvar(c(EXTERNAL_PROXY_AGGREGATE_MAX_SECONDS = "0.05"))

  result <- external_proxy_aggregate_sources(
    "GENE1",
    list(
      first = function() {
        Sys.sleep(0.2)
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
  # Budget safely above OS scheduling jitter but well below `first`'s runtime, so
  # `second` is deterministically skipped once `first` runs (see the note above; a
  # 1ms budget flaked at source #1 under CI load).
  withr::local_envvar(c(EXTERNAL_PROXY_AGGREGATE_MAX_SECONDS = "0.05"))

  result <- external_proxy_aggregate_sources(
    "GENE1",
    list(
      first = function() {
        Sys.sleep(0.2)
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

# ---------------------------------------------------------------------------
# #344: tunable per-provider budget defaults
# ---------------------------------------------------------------------------

test_that("external_proxy_budget honors default overrides when no env is set", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)
  withr::local_envvar(c(
    EXTERNAL_PROXY_GNOMAD_BATCH_TIMEOUT_SECONDS = NA,
    EXTERNAL_PROXY_TIMEOUT_SECONDS = NA,
    EXTERNAL_PROXY_GNOMAD_BATCH_MAX_SECONDS = NA,
    EXTERNAL_PROXY_MAX_SECONDS = NA,
    EXTERNAL_PROXY_GNOMAD_BATCH_MAX_TRIES = NA,
    EXTERNAL_PROXY_MAX_TRIES = NA
  ))
  b <- external_proxy_budget("gnomad_batch", default_timeout = 20, default_max = 30, default_tries = 3)
  expect_equal(b$timeout_seconds, 20)
  expect_equal(b$max_seconds, 30)
  expect_equal(b$max_tries, 3L)
})

test_that("external_proxy_budget env override beats the supplied default", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)
  withr::local_envvar(c(EXTERNAL_PROXY_GNOMAD_BATCH_TIMEOUT_SECONDS = "8"))
  b <- external_proxy_budget("gnomad_batch", default_timeout = 20)
  expect_equal(b$timeout_seconds, 8)
})

test_that("external_proxy_budget defaults stay 6/10/2 for existing callers", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)
  withr::local_envvar(c(
    EXTERNAL_PROXY_MGI_TIMEOUT_SECONDS = NA, EXTERNAL_PROXY_TIMEOUT_SECONDS = NA,
    EXTERNAL_PROXY_MGI_MAX_SECONDS = NA, EXTERNAL_PROXY_MAX_SECONDS = NA,
    EXTERNAL_PROXY_MGI_MAX_TRIES = NA, EXTERNAL_PROXY_MAX_TRIES = NA
  ))
  b <- external_proxy_budget("mgi")
  expect_equal(b$timeout_seconds, 6)
  expect_equal(b$max_seconds, 10)
  expect_equal(b$max_tries, 2L)
})

# ---------------------------------------------------------------------------
# #344: request-scoped external-time accumulator + per-request ceiling
# ---------------------------------------------------------------------------

test_that("request-time accumulator sums and resets", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)
  external_proxy_request_reset()
  expect_equal(external_proxy_request_total_ms(), 0)
  external_proxy_request_add(1200)
  external_proxy_request_add(800)
  expect_equal(external_proxy_request_total_ms(), 2000)
  external_proxy_request_reset()
  expect_equal(external_proxy_request_total_ms(), 0)
})

test_that("request ceiling trips at the env-configured limit", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)
  withr::local_envvar(c(EXTERNAL_PROXY_REQUEST_MAX_SECONDS = "15"))
  external_proxy_request_reset()
  external_proxy_request_add(2000)
  expect_false(external_proxy_request_ceiling_exceeded())
  external_proxy_request_add(14000) # total 16000ms > 15000ms
  expect_true(external_proxy_request_ceiling_exceeded())
})

test_that("timing wrapper accumulates external time into the request total", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)
  external_proxy_request_reset()
  suppressMessages(
    external_proxy_with_timing("mgi", function() {
      Sys.sleep(0.05)
      list(source = "mgi", found = FALSE)
    })
  )
  expect_gt(external_proxy_request_total_ms(), 40)
})

test_that("once the ceiling trips, the timing wrapper short-circuits upstream", {
  source(file.path(get_api_dir(), "functions", "external-proxy-functions.R"), local = TRUE)
  withr::local_envvar(c(EXTERNAL_PROXY_REQUEST_MAX_SECONDS = "0.001"))
  external_proxy_request_reset()
  external_proxy_request_add(50) # already over the 1ms ceiling
  called <- FALSE
  result <- suppressMessages(
    external_proxy_with_timing("mgi", function() {
      called <<- TRUE
      list(source = "mgi")
    })
  )
  expect_false(called)
  expect_true(isTRUE(result$error))
  expect_equal(result$status, 503L)
  expect_true(isTRUE(result$request_budget_exceeded))
})
