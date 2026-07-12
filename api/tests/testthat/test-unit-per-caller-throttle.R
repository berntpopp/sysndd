# Tests for the reusable, bounded per-caller admission limiter (#550).

staged_api_dir <- Sys.getenv("SYSNDD_API_DIR", "")
if (nzchar(staged_api_dir)) {
  api_dir <- staged_api_dir
} else if (exists("get_api_dir")) {
  api_dir <- get_api_dir()
} else {
  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
  if (!file.exists(file.path(api_dir, "functions", "per-caller-throttle.R"))) {
    api_dir <- normalizePath(getwd(), mustWork = FALSE)
  }
}
source(file.path(api_dir, "functions", "per-caller-throttle.R"), local = FALSE)

test_that("generic limiter allows N then returns a retry time for N plus one", {
  store <- new.env(parent = emptyenv())
  for (i in 1:2) {
    decision <- per_caller_rate_limit(
      fingerprint = "203.0.113.8",
      now = 1000,
      max_n = 2L,
      window_s = 60L,
      store = store,
      max_tracked = 10L
    )
    expect_true(decision$allowed)
  }

  denied <- per_caller_rate_limit(
    fingerprint = "203.0.113.8",
    now = 1000,
    max_n = 2L,
    window_s = 60L,
    store = store,
    max_tracked = 10L
  )

  expect_false(denied$allowed)
  expect_equal(denied$retry_after, 60L)
})

test_that("generic fingerprint takes the rightmost untrusted XFF hop", {
  trusted <- "10.9.0.0/24"
  legit <- list(HTTP_X_FORWARDED_FOR = "203.0.113.8, 10.9.0.5")
  expect_equal(
    per_caller_throttle_fingerprint(legit, trusted_cidrs = trusted),
    "203.0.113.8"
  )

  # The attacker can forge the left side, but never Traefik's appended right side.
  spoofed <- list(HTTP_X_FORWARDED_FOR = "203.0.113.8, 10.9.0.5, 198.51.100.44")
  expect_equal(
    per_caller_throttle_fingerprint(spoofed, trusted_cidrs = trusted),
    "198.51.100.44"
  )
})

test_that("oversized or excessive-hop XFF falls back before expensive parsing", {
  remote <- "198.51.100.44"
  oversized <- list(
    HTTP_X_FORWARDED_FOR = paste(rep("203.0.113.8", 400L), collapse = ","),
    REMOTE_ADDR = remote
  )
  excessive_hops <- list(
    HTTP_X_FORWARDED_FOR = paste(rep("203.0.113.8", 33L), collapse = ","),
    REMOTE_ADDR = remote
  )

  expect_equal(per_caller_throttle_fingerprint(oversized), remote)
  expect_equal(per_caller_throttle_fingerprint(excessive_hops), remote)
})

test_that("trusted proxy configuration is bounded before parsing", {
  too_many <- paste(rep("10.9.0.0/24", 33L), collapse = ",")
  too_large <- paste0("10.9.0.0/24,", strrep(" ", 4096L))

  expect_identical(
    per_caller_throttle_parse_trusted_cidrs(too_many, "TEST_TRUSTED_CIDRS"),
    character(0)
  )
  expect_identical(
    per_caller_throttle_parse_trusted_cidrs(too_large, "TEST_TRUSTED_CIDRS"),
    character(0)
  )
})

test_that("generic limiter isolates callers and bounds a rotation flood", {
  store <- new.env(parent = emptyenv())
  for (i in 1:2) {
    per_caller_rate_limit("203.0.113.8", now = 1000, max_n = 2L,
                          window_s = 60L, store = store, max_tracked = 2L)
  }
  expect_false(per_caller_rate_limit("203.0.113.8", now = 1000, max_n = 2L,
                                      window_s = 60L, store = store, max_tracked = 2L)$allowed)
  expect_true(per_caller_rate_limit("203.0.113.9", now = 1000, max_n = 2L,
                                     window_s = 60L, store = store, max_tracked = 2L)$allowed)

  for (i in 1:50) {
    per_caller_rate_limit(
      paste0("198.51.100.", i),
      now = 1000,
      max_n = 2L,
      window_s = 60L,
      store = store,
      max_tracked = 2L
    )
  }

  expect_lte(per_caller_rate_limit_size(store), 2L)
  expect_false(per_caller_rate_limit("203.0.113.8", now = 1000, max_n = 2L,
                                      window_s = 60L, store = store, max_tracked = 2L)$allowed)
})

test_that("generic guard fails closed without leaking request fields", {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res$headers <- list()
  res$setHeader <- function(name, value) res$headers[[name]] <- value
  secret <- "never-return-this-password"

  denied <- per_caller_admission_guard(
    req = list(HTTP_X_FORWARDED_FOR = "203.0.113.8", postBody = secret),
    res = res,
    rate_limit = function(...) stop("limiter unavailable"),
    rate_limit_message = "Too many requests. Please retry shortly."
  )

  expect_false(denied$admitted)
  expect_equal(res$status, 503L)
  expect_equal(res$headers[["Retry-After"]], "5")
  expect_false(grepl(secret, paste(unlist(denied$response), collapse = " "), fixed = TRUE))
})

test_that("generic guard invokes a safe error observer before failing closed", {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res$headers <- list()
  res$setHeader <- function(name, value) res$headers[[name]] <- value
  observed <- 0L

  denied <- per_caller_admission_guard(
    req = list(REMOTE_ADDR = "203.0.113.8"),
    res = res,
    rate_limit = function(...) stop("internal sentinel"),
    rate_limit_message = "Too many requests.",
    on_error = function(error) {
      expect_s3_class(error, "error")
      observed <<- observed + 1L
    }
  )

  expect_equal(observed, 1L)
  expect_false(denied$admitted)
  expect_equal(res$status, 503L)
})

test_that("generic guard fails closed on malformed denied decisions", {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res$headers <- list()
  res$setHeader <- function(name, value) res$headers[[name]] <- value

  denied <- per_caller_admission_guard(
    req = list(REMOTE_ADDR = "203.0.113.8"),
    res = res,
    rate_limit = function(...) list(
      allowed = FALSE,
      retry_after = list(list())
    ),
    rate_limit_message = "Too many requests."
  )

  expect_false(denied$admitted)
  expect_equal(res$status, 503L)
  expect_equal(denied$response$error, "THROTTLE_UNAVAILABLE")
})
