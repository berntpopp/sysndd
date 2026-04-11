# tests/testthat/test-endpoint-auth.R
# Endpoint tests for authentication + password-change handlers.
#
# Phase A A1 (v11.0) moved login and password-change secrets out of URL
# query strings into JSON request bodies to stop them leaking into access
# logs, Traefik logs, and browser history. These tests lock in the new
# shapes and verify the dual-mode (body + legacy query) behaviour.
#
# Scope is deliberately narrow because no Phase C endpoint tests exist yet
# for auth: we assert the route surface via plumber::pr() and exercise the
# handler bodies directly with mocked dependencies (auth_signin / pool / dw /
# verify_password / user_update_password). This avoids needing a live DB or
# API server. Integration coverage comes in Phase C.

library(testthat)

`%||%` <- function(a, b) if (is.null(a)) b else a

# Helper: extract the anonymous handler function that immediately follows
# a given plumber decorator line (e.g. `#* @post authenticate`) in an
# endpoint source file, and eval it into the supplied environment.
#
# This avoids depending on plumber's internal Route / PlumberEndpoint
# layout (which shifts between 1.x minor versions). We parse the file
# with base R and pick out the top-level `function(...) { ... }` expression
# that follows the decorator. The returned closure has its enclosing
# environment set to `envir`, so any stubs assigned there (auth_signin,
# pool, dw, ...) are visible when the handler is called.
extract_plumber_handler <- function(file_path, decorator_regex, envir) {
  src_lines <- readLines(file_path, warn = FALSE)
  dec_line <- grep(decorator_regex, src_lines)
  if (length(dec_line) == 0L) {
    stop("Decorator not found: ", decorator_regex)
  }
  dec_line <- dec_line[[1L]]

  # Parse the entire file to get top-level expressions with their source refs
  parsed <- parse(file = file_path, keep.source = TRUE)
  srcrefs <- attr(parsed, "srcref")
  if (is.null(srcrefs)) {
    stop("Unable to read source refs for ", file_path)
  }

  # Find the first top-level expression whose starting line is > dec_line.
  # Plumber writes the handler as a bare `function(...)` on the line(s)
  # immediately after the decorator block, so that expression is our handler.
  handler_expr <- NULL
  for (i in seq_along(parsed)) {
    start_line <- srcrefs[[i]][1L]
    if (start_line > dec_line) {
      handler_expr <- parsed[[i]]
      break
    }
  }
  if (is.null(handler_expr)) {
    stop("No top-level expression found after decorator line ", dec_line)
  }

  # Eval the function literal into `envir` so it captures the stubs.
  eval(handler_expr, envir = envir)
}

# Build a mock plumber `res` object that behaves like the real one for the
# narrow set of properties our handlers touch (`status` / `body`).
make_mock_res <- function() {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res$body <- NULL
  res
}


# -----------------------------------------------------------------------------
# Route-surface assertions (structural)
# -----------------------------------------------------------------------------
#
# These do not require plumber — they parse the file as text and assert the
# decorators exist. Keeps the test useful on hosts that cannot install plumber
# (e.g. Conda R on Ubuntu questing). Matching plumber::pr()-based assertions
# follow below and run only when plumber is available.

test_that("authentication_endpoints.R exposes @post authenticate", {
  src <- readLines(
    file.path(get_api_dir(), "endpoints", "authentication_endpoints.R"),
    warn = FALSE
  )
  decorators <- grep("^#\\*\\s+@post\\s+authenticate\\s*$", src, value = TRUE)
  expect_true(
    length(decorators) >= 1,
    info = "Expected a `#* @post authenticate` decorator to be present."
  )
})

test_that("authentication_endpoints.R still exposes @get authenticate (transitional)", {
  src <- readLines(
    file.path(get_api_dir(), "endpoints", "authentication_endpoints.R"),
    warn = FALSE
  )
  decorators <- grep("^#\\*\\s+@get\\s+authenticate\\s*$", src, value = TRUE)
  expect_true(
    length(decorators) >= 1,
    info = paste0(
      "Expected the legacy `#* @get authenticate` decorator to remain ",
      "during the Phase A hotfix rollout (removed in Phase E)."
    )
  )
})

test_that("@post authenticate parses credentials from req$postBody", {
  src <- readLines(
    file.path(get_api_dir(), "endpoints", "authentication_endpoints.R"),
    warn = FALSE
  )
  post_idx <- grep("^#\\*\\s+@post\\s+authenticate\\s*$", src)
  expect_length(post_idx, 1L)
  # Grab the ~40 lines after the decorator to scan the handler body.
  handler_window <- src[post_idx:min(length(src), post_idx + 45L)]
  handler_blob <- paste(handler_window, collapse = "\n")
  expect_match(
    handler_blob,
    "fromJSON\\s*\\(\\s*req\\$postBody\\s*\\)",
    info = "POST authenticate handler must parse credentials from req$postBody."
  )
  expect_match(
    handler_blob,
    "user_name\\s*<-\\s*body\\$user_name",
    info = "POST authenticate handler must read user_name from the JSON body."
  )
  expect_match(
    handler_blob,
    "password\\s*<-\\s*body\\$password",
    info = "POST authenticate handler must read password from the JSON body."
  )
})

test_that("user_endpoints.R @put password/update parses req$postBody", {
  src <- readLines(
    file.path(get_api_dir(), "endpoints", "user_endpoints.R"),
    warn = FALSE
  )
  put_idx <- grep("^#\\*\\s+@put\\s+password/update\\s*$", src)
  expect_length(put_idx, 1L)
  handler_window <- src[put_idx:min(length(src), put_idx + 60L)]
  handler_blob <- paste(handler_window, collapse = "\n")
  expect_match(
    handler_blob,
    "fromJSON\\s*\\(\\s*req\\$postBody\\s*\\)",
    info = "PUT password/update handler must accept a JSON body."
  )
  for (field in c("user_id_pass_change", "old_pass", "new_pass_1", "new_pass_2")) {
    expect_match(
      handler_blob,
      paste0("body\\$", field),
      info = paste0("PUT password/update must read `", field, "` from body.")
    )
  }
})

test_that("no auth endpoint still reads credentials from URL query params only", {
  # Regression gate: once E7 lands the @get shape goes away entirely. Until
  # then we verify the POST handler does NOT take credentials via its formal
  # argument list (which would expose them as ?user_name=&password=).
  src <- readLines(
    file.path(get_api_dir(), "endpoints", "authentication_endpoints.R"),
    warn = FALSE
  )
  post_idx <- grep("^#\\*\\s+@post\\s+authenticate\\s*$", src)
  expect_length(post_idx, 1L)
  # The function signature sits on the line immediately after the decorator.
  sig_line <- src[post_idx + 1L]
  expect_match(
    sig_line,
    "^function\\s*\\(\\s*req\\s*,\\s*res\\s*\\)\\s*\\{",
    info = paste0(
      "POST authenticate must take only (req, res) — credentials must ",
      "come from req$postBody, never plumber-decoded query args."
    )
  )
})


# -----------------------------------------------------------------------------
# Handler-level invocation (behavioural)
# -----------------------------------------------------------------------------
#
# These extract the handler function literal directly from the endpoint source
# (via `extract_plumber_handler`) and eval it into a sandbox environment that
# contains stubs for the production dependencies (`auth_signin`, `pool`, `dw`,
# `%||%`). This avoids depending on plumber's internal PlumberEndpoint /
# Route layout, which varies across 1.x minor versions. The structural tests
# above already prove the decorator / signature surface; these tests exercise
# the handler body itself.

make_auth_sandbox <- function(auth_signin_fn) {
  env <- new.env(parent = globalenv())
  env$auth_signin <- auth_signin_fn
  env$pool <- "STUB_POOL"
  env$dw <- list(secret = "test-secret", refresh = 3600)
  env$`%||%` <- function(a, b) if (is.null(a)) b else a
  env
}

auth_file_path <- function() {
  file.path(get_api_dir(), "endpoints", "authentication_endpoints.R")
}

extract_post_authenticate <- function(envir) {
  extract_plumber_handler(
    auth_file_path(),
    decorator_regex = "^#\\*\\s+@post\\s+authenticate\\s*$",
    envir = envir
  )
}

test_that("POST authenticate returns access token from auth_signin on success", {
  skip_if_not_installed("jsonlite")

  env <- make_auth_sandbox(function(user_name, password, pool, config) {
    list(access_token = "fake.jwt.token", refresh_token = "fake.jwt.token")
  })
  handler <- extract_post_authenticate(env)
  expect_true(is.function(handler))

  req <- list(
    postBody = '{"user_name":"valid_user","password":"valid_pass_123"}'
  )
  res <- make_mock_res()
  result <- handler(req = req, res = res)
  expect_equal(result, "fake.jwt.token")
  expect_equal(res$status, 200L)
})

test_that("POST authenticate returns 400 on short or missing credentials", {
  skip_if_not_installed("jsonlite")

  env <- make_auth_sandbox(function(...) {
    stop("should not be called on invalid input")
  })
  handler <- extract_post_authenticate(env)
  expect_true(is.function(handler))

  # Empty body -> empty user_name/password -> 400
  req_empty <- list(postBody = "{}")
  res_empty <- make_mock_res()
  handler(req = req_empty, res = res_empty)
  expect_equal(res_empty$status, 400L)

  # Username too short -> 400
  req_short <- list(postBody = '{"user_name":"x","password":"validpass"}')
  res_short <- make_mock_res()
  handler(req = req_short, res = res_short)
  expect_equal(res_short$status, 400L)

  # Password too short -> 400
  req_shortpass <- list(postBody = '{"user_name":"valid_user","password":"x"}')
  res_shortpass <- make_mock_res()
  handler(req = req_shortpass, res = res_shortpass)
  expect_equal(res_shortpass$status, 400L)
})

test_that("POST authenticate returns 401 when auth_signin raises", {
  skip_if_not_installed("jsonlite")

  env <- make_auth_sandbox(function(user_name, password, pool, config) {
    stop("Invalid username or password")
  })
  handler <- extract_post_authenticate(env)
  expect_true(is.function(handler))

  req <- list(
    postBody = '{"user_name":"valid_user","password":"wrong_pass"}'
  )
  res <- make_mock_res()
  handler(req = req, res = res)
  expect_equal(res$status, 401L)
})

test_that("POST authenticate returns 400 on malformed JSON", {
  skip_if_not_installed("jsonlite")

  env <- make_auth_sandbox(function(...) {
    stop("should not be called on invalid JSON")
  })
  handler <- extract_post_authenticate(env)
  expect_true(is.function(handler))

  req <- list(postBody = "this is not json{{")
  res <- make_mock_res()
  handler(req = req, res = res)
  # Malformed JSON -> empty fields -> validation fails -> 400
  expect_equal(res$status, 400L)
})
