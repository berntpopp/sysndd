# api/tests/testthat/test-endpoint-curate-variation.R
#
# Route-level contracts for /api/curate/variation (#612 Phase 6).
#
# The service tests in test-unit-curate-variation-*.R call the service functions
# directly, so they prove nothing about the things a Curator-gated write surface
# most needs proven: that `require_role` actually runs, that the batch is read
# from the JSON BODY rather than the query string, that the acting user comes
# from the authenticated request rather than the payload, and that each route
# carries the null-preserving serializer.
#
# Harness mirrors test-endpoint-review.R: parse the endpoint file, take the
# function literal after a decorator, and evaluate it in a sandbox holding the
# stubs.

curate_endpoint_path <- function() {
  file.path(get_api_dir(), "endpoints", "curate_variation_endpoints.R")
}

curate_source <- function() readLines(curate_endpoint_path(), warn = FALSE)

extract_curate_handler <- function(decorator_regex, envir) {
  src_lines <- curate_source()
  dec_hits <- grep(decorator_regex, src_lines)
  if (length(dec_hits) == 0L) {
    stop("Decorator not found in curate_variation_endpoints.R: ", decorator_regex)
  }
  dec_line <- dec_hits[[1L]]

  parsed <- parse(file = curate_endpoint_path(), keep.source = TRUE)
  srcrefs <- attr(parsed, "srcref")
  handler_expr <- NULL
  for (i in seq_along(parsed)) {
    if (srcrefs[[i]][1L] > dec_line) {
      handler_expr <- parsed[[i]]
      break
    }
  }
  if (is.null(handler_expr)) {
    stop("No top-level expression found after decorator line ", dec_line)
  }
  eval(handler_expr, envir = envir)
}

make_mock_res <- function() {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res
}

deny_role <- function(req, res, min_role) {
  res$status <- 403L
  stop(sprintf("forbidden: %s required", min_role))
}

make_curate_sandbox <- function(require_role_fn = function(req, res, min_role) invisible(TRUE),
                                apply_fn = function(...) {
                                  list(requested = 1L, applied = 1L, skipped = list())
                                },
                                params_fn = function(...) list(marker = "params"),
                                list_fn = function(params, pool) {
                                  list(meta = list(page = 1L, page_size = 25L, total = 0L),
                                       data = list())
                                }) {
  env <- new.env(parent = globalenv())
  env$require_role <- require_role_fn
  env$pool <- "STUB_POOL"
  env$svc_curate_variation_apply <- apply_fn
  env$svc_curate_variation_suggestion_params <- params_fn
  env$svc_curate_variation_suggestions <- list_fn
  env
}

sample_items <- list(list(entity_id = 42L, vario_id = "VariO:0015", modifier_id = 1L))


# ---------------------------------------------------------------------------
# Authorization
# ---------------------------------------------------------------------------

test_that("every route gates at Curator", {
  # Anonymous requests are forwarded by require_auth, so each handler must
  # self-gate. A missing gate here exposes curation workflow state -- including
  # `suggested` and `rejected`, which the public surface never reveals.
  decorators <- c("@get /suggestions$", "@post /suggestions/confirm",
                  "@post /suggestions/dismiss")
  for (decorator in decorators) {
    seen <- NULL
    env <- make_curate_sandbox(
      require_role_fn = function(req, res, min_role) {
        seen <<- min_role
        deny_role(req, res, min_role)
      }
    )
    handler <- extract_curate_handler(decorator, env)
    res <- make_mock_res()
    req <- list(argsBody = list(items = sample_items), user_id = 7L)

    expect_error(handler(req = req, res = res), "forbidden")
    expect_equal(res$status, 403L)
    expect_equal(seen, "Curator")
  }
})

test_that("the role gate runs BEFORE any service call", {
  called <- FALSE
  env <- make_curate_sandbox(
    require_role_fn = deny_role,
    apply_fn = function(...) {
      called <<- TRUE
      list(requested = 0L, applied = 0L, skipped = list())
    }
  )
  handler <- extract_curate_handler("@post /suggestions/confirm", env)
  expect_error(handler(req = list(argsBody = list(items = sample_items), user_id = 7L),
                       res = make_mock_res()))
  expect_false(called)
})


# ---------------------------------------------------------------------------
# Body and identity plumbing
# ---------------------------------------------------------------------------

test_that("confirm reads items from the BODY and the user from the request", {
  # Never from the payload: an acting user a client can name is an acting user a
  # client can forge.
  captured <- NULL
  env <- make_curate_sandbox(apply_fn = function(items, action, review_user_id, db) {
    captured <<- list(items = items, action = action,
                      review_user_id = review_user_id, db = db)
    list(requested = 1L, applied = 1L, skipped = list())
  })
  handler <- extract_curate_handler("@post /suggestions/confirm", env)

  result <- handler(
    req = list(argsBody = list(items = sample_items), user_id = 7L),
    res = make_mock_res()
  )

  expect_identical(captured$items, sample_items)
  expect_equal(captured$action, "confirm")
  expect_equal(captured$review_user_id, 7L)
  expect_equal(captured$db, "STUB_POOL")
  expect_equal(result$applied, 1L)
})

test_that("dismiss forwards the dismiss action", {
  captured <- NULL
  env <- make_curate_sandbox(apply_fn = function(items, action, review_user_id, db) {
    captured <<- action
    list(requested = 1L, applied = 0L, skipped = list())
  })
  handler <- extract_curate_handler("@post /suggestions/dismiss", env)
  handler(req = list(argsBody = list(items = sample_items), user_id = 7L),
          res = make_mock_res())
  expect_equal(captured, "dismiss")
})

test_that("an absent body reaches the service as NULL, which it rejects with a 400", {
  # The 400 belongs to the service (it owns the item contract); the endpoint's
  # job is to forward faithfully rather than to invent an empty batch.
  captured <- "unset"
  env <- make_curate_sandbox(apply_fn = function(items, action, review_user_id, db) {
    captured <<- items
    list(requested = 0L, applied = 0L, skipped = list())
  })
  handler <- extract_curate_handler("@post /suggestions/confirm", env)
  handler(req = list(argsBody = NULL, user_id = 7L), res = make_mock_res())
  expect_null(captured)
})

test_that("the listing forwards every query parameter to validation", {
  captured <- NULL
  env <- make_curate_sandbox(
    params_fn = function(state, source_key, max_strength, moved, q, sort, page, page_size) {
      captured <<- list(state = state, source_key = source_key,
                        max_strength = max_strength, moved = moved, q = q,
                        sort = sort, page = page, page_size = page_size)
      list(marker = "params")
    }
  )
  handler <- extract_curate_handler("@get /suggestions$", env)

  handler(req = list(user_id = 7L), res = make_mock_res(),
          state = "suggested", source_key = "clinvar", max_strength = "1",
          moved = "true", q = "CHD8", sort = "strength_asc", page = "2",
          page_size = "10")

  expect_equal(captured$state, "suggested")
  expect_equal(captured$source_key, "clinvar")
  expect_equal(captured$max_strength, "1")
  expect_equal(captured$moved, "true")
  expect_equal(captured$q, "CHD8")
  expect_equal(captured$sort, "strength_asc")
  expect_equal(captured$page, "2")
  expect_equal(captured$page_size, "10")
})

test_that("the listing passes the validated params, not the raw ones, to the query", {
  captured <- NULL
  env <- make_curate_sandbox(
    params_fn = function(...) list(marker = "validated"),
    list_fn = function(params, pool) {
      captured <<- params
      list(meta = list(page = 1L, page_size = 25L, total = 0L), data = list())
    }
  )
  handler <- extract_curate_handler("@get /suggestions$", env)
  result <- handler(req = list(user_id = 7L), res = make_mock_res())
  expect_equal(captured$marker, "validated")
  expect_equal(result$meta$total, 0L)
})


# ---------------------------------------------------------------------------
# Static contracts
# ---------------------------------------------------------------------------

test_that("every route declares the null-preserving serializer", {
  # Without null="null", jsonlite renders a NULL nested value as {} rather than
  # null -- which is how `provenance: null` would stop meaning
  # "curator-authored" on the sibling entity routes. Queue rows carry nullable
  # nested scalars (symbol, vario_name, strength, summary) for the same reason.
  src <- curate_source()
  serializers <- grep('@serializer json list(na="string", null="null")', src, fixed = TRUE)
  routes <- grep("#\\* @(get|post) ", src)
  expect_length(routes, 3L)
  for (route in routes) {
    expect_true(
      any(serializers < route & serializers > route - 40L),
      info = paste("no serializer declared above", src[[route]])
    )
  }
})

test_that("the literal action routes are declared BEFORE the bare /suggestions route", {
  # Plumber matches in declaration order. A dynamic single-segment sibling
  # declared first would capture "confirm"/"dismiss" as its parameter -- the
  # /api/status/_list trap.
  src <- curate_source()
  confirm <- grep("@post /suggestions/confirm", src, fixed = TRUE)
  dismiss <- grep("@post /suggestions/dismiss", src, fixed = TRUE)
  listing <- grep("@get /suggestions", src, fixed = TRUE)
  expect_length(confirm, 1L)
  expect_length(dismiss, 1L)
  expect_length(listing, 1L)
  expect_lt(confirm, listing)
  expect_lt(dismiss, listing)
})

test_that("the endpoint file is mounted through mount_endpoint()", {
  # mount_endpoint() attaches the RFC 9457 error handler; a bare pr_mount turns
  # every stop_for_bad_request() into an opaque 500.
  mount <- paste(
    readLines(file.path(get_api_dir(), "bootstrap", "mount_endpoints.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(
    mount,
    'pr_mount("/api/curate/variation", mount_endpoint("endpoints/curate_variation_endpoints.R"))',
    fixed = TRUE
  )
})

test_that("the endpoint stays thin -- no SQL, no direct table access", {
  src <- paste(curate_source(), collapse = "\n")
  for (fragment in c("SELECT ", "UPDATE ", "INSERT ", "DELETE ",
                     "db_execute_query", "db_execute_statement")) {
    expect_false(grepl(fragment, src, fixed = TRUE), info = fragment)
  }
})
