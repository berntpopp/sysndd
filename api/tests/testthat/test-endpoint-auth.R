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

# Helper: extract the handler function for a given verb + path out of a
# plumber::pr() object. Works across plumber versions by walking the
# internal `routes` list when the public accessors (`plumber::routes`,
# `plumber::endpoints`) are not present.
get_plumber_handler <- function(pr_obj, verb, path) {
  verb <- toupper(verb)
  routes <- NULL
  if (!is.null(pr_obj$routes)) {
    routes <- pr_obj$routes
  } else if (!is.null(pr_obj$endpoints)) {
    # Newer plumber versions store per-verb endpoint lists instead of a flat
    # `routes` list; flatten them into a route-like structure.
    for (verb_key in names(pr_obj$endpoints)) {
      for (endpoint in pr_obj$endpoints[[verb_key]]) {
        routes[[length(routes) + 1L]] <- list(
          verbs = verb_key,
          path = endpoint$path,
          exec = endpoint$exec
        )
      }
    }
  }

  for (route in routes) {
    # plumber 1.x: `verbs` is a character vector or scalar; path starts with "/"
    verbs <- route$verbs %||% route$endpoint$verbs
    rpath <- route$path %||% route$endpoint$path
    if (is.null(verbs) || is.null(rpath)) next
    if (verb %in% toupper(verbs) && sub("^/", "", rpath) == sub("^/", "", path)) {
      return(route$exec %||% route$endpoint$func)
    }
  }
  NULL
}

`%||%` <- function(a, b) if (is.null(a)) b else a

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
# These load the endpoint file via plumber::pr() with dependencies stubbed in
# the global environment (plumber 1.x closures resolve free variables via the
# standard R scoping chain, which eventually hits globalenv()). Stubs are
# installed per-test via `with_global_stubs()` and torn down on exit so the
# suite leaves globalenv() unchanged.

with_global_stubs <- function(stubs, code) {
  ge <- globalenv()
  saved <- list()
  was_bound <- character(0)
  for (nm in names(stubs)) {
    if (exists(nm, envir = ge, inherits = FALSE)) {
      saved[[nm]] <- get(nm, envir = ge, inherits = FALSE)
      was_bound <- c(was_bound, nm)
    }
    assign(nm, stubs[[nm]], envir = ge)
  }
  on.exit({
    for (nm in names(stubs)) {
      if (nm %in% was_bound) {
        assign(nm, saved[[nm]], envir = ge)
      } else {
        if (exists(nm, envir = ge, inherits = FALSE)) {
          rm(list = nm, envir = ge)
        }
      }
    }
  }, add = TRUE)
  force(code)
}

make_auth_stubs <- function(auth_signin_fn) {
  list(
    auth_signin = auth_signin_fn,
    pool = "STUB_POOL",
    dw = list(secret = "test-secret", refresh = 3600),
    `%||%` = function(a, b) if (is.null(a)) b else a
  )
}

test_that("POST authenticate returns access token from auth_signin on success", {
  skip_if_not_installed("plumber")
  skip_if_not_installed("jsonlite")

  stubs <- make_auth_stubs(function(user_name, password, pool, config) {
    list(access_token = "fake.jwt.token", refresh_token = "fake.jwt.token")
  })

  with_global_stubs(stubs, {
    pr_obj <- plumber::pr(
      file.path(get_api_dir(), "endpoints", "authentication_endpoints.R")
    )
    handler <- get_plumber_handler(pr_obj, "POST", "authenticate")
    expect_false(is.null(handler))

    req <- list(
      postBody = '{"user_name":"valid_user","password":"valid_pass_123"}'
    )
    res <- make_mock_res()
    result <- handler(req = req, res = res)
    expect_equal(result, "fake.jwt.token")
    expect_equal(res$status, 200L)
  })
})

test_that("POST authenticate returns 400 on short or missing credentials", {
  skip_if_not_installed("plumber")
  skip_if_not_installed("jsonlite")

  stubs <- make_auth_stubs(function(...) {
    stop("should not be called on invalid input")
  })

  with_global_stubs(stubs, {
    pr_obj <- plumber::pr(
      file.path(get_api_dir(), "endpoints", "authentication_endpoints.R")
    )
    handler <- get_plumber_handler(pr_obj, "POST", "authenticate")
    expect_false(is.null(handler))

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
})

test_that("POST authenticate returns 401 when auth_signin raises", {
  skip_if_not_installed("plumber")
  skip_if_not_installed("jsonlite")

  stubs <- make_auth_stubs(function(user_name, password, pool, config) {
    stop("Invalid username or password")
  })

  with_global_stubs(stubs, {
    pr_obj <- plumber::pr(
      file.path(get_api_dir(), "endpoints", "authentication_endpoints.R")
    )
    handler <- get_plumber_handler(pr_obj, "POST", "authenticate")
    expect_false(is.null(handler))

    req <- list(
      postBody = '{"user_name":"valid_user","password":"wrong_pass"}'
    )
    res <- make_mock_res()
    handler(req = req, res = res)
    expect_equal(res$status, 401L)
  })
})

test_that("POST authenticate returns 400 on malformed JSON", {
  skip_if_not_installed("plumber")
  skip_if_not_installed("jsonlite")

  stubs <- make_auth_stubs(function(...) {
    stop("should not be called on invalid JSON")
  })

  with_global_stubs(stubs, {
    pr_obj <- plumber::pr(
      file.path(get_api_dir(), "endpoints", "authentication_endpoints.R")
    )
    handler <- get_plumber_handler(pr_obj, "POST", "authenticate")
    expect_false(is.null(handler))

    req <- list(postBody = "this is not json{{")
    res <- make_mock_res()
    handler(req = req, res = res)
    # Malformed JSON -> empty fields -> validation fails -> 400
    expect_equal(res$status, 400L)
  })
})
