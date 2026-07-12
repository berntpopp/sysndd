# Tests for the public authentication policy adapter (#550).

auth_throttle_api_dir <- function() {
  staged <- Sys.getenv("SYSNDD_API_DIR", "")
  if (nzchar(staged)) return(staged)
  if (exists("get_api_dir")) return(get_api_dir())
  normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
}

auth_throttle_dir <- auth_throttle_api_dir()
source(file.path(auth_throttle_dir, "functions", "per-caller-throttle.R"), local = FALSE)
source(file.path(auth_throttle_dir, "functions", "auth-endpoint-throttle.R"), local = FALSE)

auth_throttle_res <- function() {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res$headers <- list()
  res$setHeader <- function(name, value) res$headers[[name]] <- value
  res
}

test_that("auth adapter blocks N plus one and leaves another caller independent", {
  store <- new.env(parent = emptyenv())
  first <- "203.0.113.8"
  for (i in 1:2) {
    expect_true(auth_endpoint_rate_limit(first, now = 1000, max_n = 2L,
                                         window_s = 60L, store = store, max_tracked = 10L)$allowed)
  }
  expect_false(auth_endpoint_rate_limit(first, now = 1000, max_n = 2L,
                                        window_s = 60L, store = store, max_tracked = 10L)$allowed)
  expect_true(auth_endpoint_rate_limit("203.0.113.9", now = 1000, max_n = 2L,
                                       window_s = 60L, store = store, max_tracked = 10L)$allowed)
})

test_that("auth guard emits only a generic 429 and Retry-After", {
  auth_endpoint_rate_limit_reset()
  on.exit(auth_endpoint_rate_limit_reset(), add = TRUE)
  request <- list(HTTP_X_FORWARDED_FOR = "203.0.113.8", postBody = '{"password":"not-returned"}')
  for (i in seq_len(AUTH_ENDPOINT_PER_CALLER_MAX)) {
    expect_true(auth_endpoint_admission_guard(request, auth_throttle_res())$admitted)
  }
  res <- auth_throttle_res()
  denied <- auth_endpoint_admission_guard(request, res)

  expect_false(denied$admitted)
  expect_equal(res$status, 429L)
  expect_true(nzchar(res$headers[["Retry-After"]]))
  expect_match(res$headers[["Retry-After"]], "^[1-9][0-9]*$")
  expect_gt(denied$response$retry_after, 0L)
  expect_equal(denied$response$error, "RATE_LIMITED")
  expect_false(grepl("not-returned", paste(unlist(denied$response), collapse = " "), fixed = TRUE))
})

test_that("real auth guard keeps independent client fingerprints isolated", {
  store <- new.env(parent = emptyenv())
  guard <- function(req, res) {
    per_caller_admission_guard(
      req,
      res,
      rate_limit = function(fingerprint) {
        auth_endpoint_rate_limit(
          fingerprint,
          now = 1000,
          max_n = 1L,
          window_s = 60L,
          store = store,
          max_tracked = 10L
        )
      },
      rate_limit_message = "Too many authentication requests."
    )
  }

  client_a <- list(HTTP_X_FORWARDED_FOR = "203.0.113.8")
  client_b <- list(HTTP_X_FORWARDED_FOR = "203.0.113.9")
  expect_true(guard(client_a, auth_throttle_res())$admitted)
  expect_false(guard(client_a, auth_throttle_res())$admitted)
  expect_true(guard(client_b, auth_throttle_res())$admitted)
})

test_that("auth policy caps the aggregate timestamp budget", {
  configured <- new.env(parent = globalenv())
  withr::with_envvar(c(
    AUTH_ENDPOINT_PER_CALLER_MAX = "1000",
    AUTH_ENDPOINT_MAX_TRACKED = "200000"
  ), {
    sys.source(file.path(auth_throttle_dir, "functions", "per-caller-throttle.R"), envir = configured)
    sys.source(file.path(auth_throttle_dir, "functions", "auth-endpoint-throttle.R"), envir = configured)
  })

  expect_lte(
    configured$AUTH_ENDPOINT_PER_CALLER_MAX *
      (configured$AUTH_ENDPOINT_MAX_TRACKED + 1L),
    configured$AUTH_ENDPOINT_MAX_ENTRIES
  )
})

test_that("malformed auth configuration falls back and never trusts invalid CIDRs", {
  configured <- new.env(parent = globalenv())
  withr::with_envvar(c(
    AUTH_ENDPOINT_PER_CALLER_MAX = "not-an-integer",
    AUTH_ENDPOINT_WINDOW_SECONDS = "0",
    AUTH_ENDPOINT_MAX_TRACKED = "-20",
    AUTH_ENDPOINT_TRUSTED_PROXY_CIDRS = "not-a-cidr, 10.9.0.0/24"
  ), {
    sys.source(file.path(auth_throttle_dir, "functions", "per-caller-throttle.R"), envir = configured)
    sys.source(file.path(auth_throttle_dir, "functions", "auth-endpoint-throttle.R"), envir = configured)
  })

  expect_equal(configured$AUTH_ENDPOINT_PER_CALLER_MAX, 5L)
  expect_equal(configured$AUTH_ENDPOINT_WINDOW_SECONDS, 60L)
  expect_equal(configured$AUTH_ENDPOINT_MAX_TRACKED, 20000L)
  expect_equal(configured$AUTH_ENDPOINT_TRUSTED_PROXY_CIDRS, "10.9.0.0/24")
  expect_equal(
    configured$per_caller_throttle_fingerprint(
      list(HTTP_X_FORWARDED_FOR = "198.51.100.44, 10.9.0.5"),
      configured$AUTH_ENDPOINT_TRUSTED_PROXY_CIDRS
    ),
    "198.51.100.44"
  )
})

test_that("corrupted auth runtime policy fails closed", {
  configured <- new.env(parent = globalenv())
  sys.source(file.path(auth_throttle_dir, "functions", "per-caller-throttle.R"), envir = configured)
  sys.source(file.path(auth_throttle_dir, "functions", "auth-endpoint-throttle.R"), envir = configured)
  configured$AUTH_ENDPOINT_PER_CALLER_MAX <- NA_integer_

  res <- auth_throttle_res()
  denied <- configured$auth_endpoint_admission_guard(
    list(HTTP_X_FORWARDED_FOR = "203.0.113.8"),
    res
  )

  expect_false(denied$admitted)
  expect_equal(res$status, 503L)
  expect_equal(res$headers[["Retry-After"]], "5")
  expect_equal(denied$response$error, "THROTTLE_UNAVAILABLE")
})
