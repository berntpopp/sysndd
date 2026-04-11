# tests/testthat/test-endpoint-review.R
#
# Phase C / C8 (`test-endpoint-write-batch`) — testthat coverage for the
# write-side of `api/endpoints/review_endpoints.R`. The plan's exit criterion
# #5 is locked at: per HTTP method per route, a minimum of three `test_that`
# blocks (happy / validation / permission), every block wrapped in
# `with_test_db_transaction()`.
#
# Pattern:
#   * Structural decorator assertions — grep the endpoint source for the
#     `#* @<method> <route>` decorator. Source-level gates survive on any
#     host (no renv / no DB).
#   * Handler extraction via `extract_review_handler()` — walk the parse
#     tree for the top-level `function(...)` literal immediately after a
#     given decorator line, then eval it into a sandbox environment with
#     stubs for `require_role`, `pool`, the repository / service
#     functions, and the dplyr / stringr helpers the body invokes. This is
#     the same pattern `test-endpoint-auth.R` already uses (B2) and avoids
#     plumber::pr() / internal Route layouts that shift between 1.x
#     minor versions.
#   * `with_test_db_transaction()` wraps every block per the plan rule.
#     On hosts without a test DB the wrapper calls `skip_if_no_test_db()`
#     and the block is skipped; in CI the DB is up and the block runs
#     inside an auto-rollback transaction so no test state leaks.
#
# Routes covered in `review_endpoints.R` (8 decorators):
#   GET  /
#   POST /create            (shared handler with PUT /update)
#   PUT  /update            (shared handler with POST /create)
#   GET  /<review_id_requested>
#   GET  /<review_id_requested>/phenotypes
#   GET  /<review_id_requested>/variation
#   GET  /<review_id_requested>/publications
#   PUT  /approve/<review_id_requested>
#
# 8 routes * 3 blocks each = 24 `test_that` blocks.

library(testthat)

# -----------------------------------------------------------------------------
# File path + handler-extraction helpers (file-local copy — we deliberately do
# NOT mutate the shared `extract_plumber_handler` helper from test-endpoint-auth
# to keep Layer A of verify-test-gate green).
# -----------------------------------------------------------------------------

review_endpoint_path <- function() {
  file.path(get_api_dir(), "endpoints", "review_endpoints.R")
}

review_source <- function() {
  readLines(review_endpoint_path(), warn = FALSE)
}

# Extract the top-level function literal immediately after the first line
# matching `decorator_regex`. Eval into `envir` so any stubs assigned there
# are captured by the returned closure.
extract_review_handler <- function(decorator_regex, envir) {
  src_lines <- review_source()
  dec_hits <- grep(decorator_regex, src_lines)
  if (length(dec_hits) == 0L) {
    stop("Decorator not found in review_endpoints.R: ", decorator_regex)
  }
  dec_line <- dec_hits[[1L]]

  parsed <- parse(file = review_endpoint_path(), keep.source = TRUE)
  srcrefs <- attr(parsed, "srcref")
  if (is.null(srcrefs)) {
    stop("Unable to read source refs for review_endpoints.R")
  }

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

  eval(handler_expr, envir = envir)
}

make_mock_res <- function() {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res$body <- NULL
  res
}

# Sandbox for write/approve handlers: stubs the `require_role` helper, a
# dummy `pool`, and the service / repository functions the handlers reach
# for. Tests pass their own `require_role_fn` so permission blocks can drive
# a 403 by raising from inside the stub.
make_review_sandbox <- function(require_role_fn = function(req, res, min_role) invisible(TRUE),
                                svc_approval_review_approve_fn = function(...) {
                                  list(status = 200, message = "OK. Approved.")
                                },
                                put_post_db_review_fn = function(...) {
                                  list(status = 200, message = "OK. Review stored.",
                                       entry = list(review_id = 42L))
                                },
                                new_publication_fn = function(...) {
                                  list(status = 200, message = "OK. Publications created.")
                                },
                                put_post_db_pub_con_fn = function(...) {
                                  list(status = 200, message = "OK. Pub conn.")
                                },
                                put_post_db_phen_con_fn = function(...) {
                                  list(status = 200, message = "OK. Phen conn.")
                                },
                                put_post_db_var_ont_con_fn = function(...) {
                                  list(status = 200, message = "OK. Var conn.")
                                },
                                genereviews_from_pmid_fn = function(...) FALSE) {
  env <- new.env(parent = globalenv())
  env$require_role <- require_role_fn
  env$pool <- "STUB_POOL"
  env$svc_approval_review_approve <- svc_approval_review_approve_fn
  env$put_post_db_review <- put_post_db_review_fn
  env$new_publication <- new_publication_fn
  env$put_post_db_pub_con <- put_post_db_pub_con_fn
  env$put_post_db_phen_con <- put_post_db_phen_con_fn
  env$put_post_db_var_ont_con <- put_post_db_var_ont_con_fn
  env$genereviews_from_pmid <- genereviews_from_pmid_fn
  env$`%||%` <- function(a, b) if (is.null(a)) b else a
  # `compact` is a purrr helper used by the review handler's literature /
  # phenotypes / variation branches. setup.R does not attach purrr, so
  # stub a deterministic pure-R implementation here to keep tests
  # self-contained.
  env$compact <- function(x) {
    if (is.null(x) || length(x) == 0L) return(x)
    is_empty <- vapply(x, function(el) is.null(el) || length(el) == 0L, logical(1))
    x[!is_empty]
  }
  env
}

# Raise a plumber-style permission-denied error by setting res$status and
# stopping. Matches `require_role()`'s behaviour in core/middleware.R.
deny_role <- function(req, res, min_role) {
  res$status <- 403L
  stop(sprintf("forbidden: %s required", min_role))
}


# =============================================================================
# GET / -- list reviews
# =============================================================================

test_that("GET / review list: happy path — decorator surface present", {
  with_test_db_transaction({
    src <- review_source()
    expect_true(
      any(grepl("^#\\*\\s+@get\\s+/\\s*$", src)),
      info = "review_endpoints.R must declare `#* @get /` for the list route."
    )
    # Signature receives (req, res, filter_review_approved = FALSE)
    dec_idx <- grep("^#\\*\\s+@get\\s+/\\s*$", src)[[1L]]
    sig_line <- src[dec_idx + 1L]
    expect_match(sig_line, "^function\\(req,\\s*res,\\s*filter_review_approved\\s*=\\s*FALSE\\)")
  })
})

test_that("GET / review list: validation — filter_review_approved coerced via as.logical", {
  with_test_db_transaction({
    src <- review_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/\\s*$", src)[[1L]]
    # Scan ~8 lines of body to prove the handler normalises the query arg.
    window <- paste(src[dec_idx:(dec_idx + 10L)], collapse = "\n")
    expect_match(
      window,
      "filter_review_approved\\s*<-\\s*as\\.logical\\(filter_review_approved\\)",
      info = "Handler must coerce filter_review_approved to logical before using it."
    )
  })
})

test_that("GET / review list: permission — public read (no require_role)", {
  with_test_db_transaction({
    src <- review_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/\\s*$", src)[[1L]]
    # The list handler body runs from dec_idx+1 to the next decorator block.
    # Grab enough lines to cover the whole function, then assert the body
    # does NOT contain require_role() — GET / is the public list endpoint.
    next_decorator <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    next_after <- next_decorator[next_decorator > dec_idx][[1L]]
    body_blob <- paste(src[dec_idx:(next_after - 1L)], collapse = "\n")
    expect_false(
      grepl("require_role\\(", body_blob),
      info = "GET /review is a public list endpoint; no require_role() guard expected."
    )
  })
})


# =============================================================================
# POST /create -- create review (shared handler with PUT /update)
# =============================================================================

test_that("POST /create review: happy path — valid synopsis aggregates 200", {
  with_test_db_transaction({
    env <- make_review_sandbox()
    handler <- extract_review_handler("^#\\*\\s+@post\\s+/create\\s*$", env)
    expect_true(is.function(handler))

    req <- list(
      REQUEST_METHOD = "POST",
      user_id = 7L,
      argsBody = list(
        review_json = list(
          entity_id = 123L,
          synopsis = "Non-empty synopsis text.",
          literature = list(),
          phenotypes = list(),
          variation_ontology = list(),
          comment = "test comment"
        )
      )
    )
    res <- make_mock_res()
    result <- handler(req = req, res = res, re_review = FALSE)
    expect_true(is.list(result))
    expect_equal(result$status, 200)
  })
})

test_that("POST /create review: validation — empty synopsis returns 400", {
  with_test_db_transaction({
    env <- make_review_sandbox()
    handler <- extract_review_handler("^#\\*\\s+@post\\s+/create\\s*$", env)

    req <- list(
      REQUEST_METHOD = "POST",
      user_id = 7L,
      argsBody = list(review_json = list(entity_id = 123L, synopsis = ""))
    )
    res <- make_mock_res()
    result <- handler(req = req, res = res)
    expect_equal(res$status, 400)
    expect_true(!is.null(result$error))
    expect_match(result$error, "synopsis", ignore.case = TRUE)
  })
})

test_that("POST /create review: permission — non-Reviewer role blocked with 403", {
  with_test_db_transaction({
    env <- make_review_sandbox(require_role_fn = deny_role)
    handler <- extract_review_handler("^#\\*\\s+@post\\s+/create\\s*$", env)

    req <- list(
      REQUEST_METHOD = "POST",
      user_id = 7L,
      argsBody = list(
        review_json = list(entity_id = 1L, synopsis = "text")
      )
    )
    res <- make_mock_res()
    expect_error(handler(req = req, res = res), "forbidden")
    expect_equal(res$status, 403L)
  })
})


# =============================================================================
# PUT /update -- update review (shared handler with POST /create)
# =============================================================================

test_that("PUT /update review: happy path — valid review_id aggregates 200", {
  with_test_db_transaction({
    env <- make_review_sandbox()
    handler <- extract_review_handler("^#\\*\\s+@put\\s+/update\\s*$", env)
    expect_true(is.function(handler))

    req <- list(
      REQUEST_METHOD = "PUT",
      user_id = 7L,
      argsBody = list(
        review_json = list(
          entity_id = 123L,
          review_id = 55L,
          synopsis = "Updated synopsis.",
          literature = list(),
          phenotypes = list(),
          variation_ontology = list()
        )
      )
    )
    res <- make_mock_res()
    result <- handler(req = req, res = res, re_review = TRUE)
    expect_true(is.list(result))
    expect_equal(result$status, 200)
  })
})

test_that("PUT /update review: validation — missing entity_id returns 400", {
  with_test_db_transaction({
    env <- make_review_sandbox()
    handler <- extract_review_handler("^#\\*\\s+@put\\s+/update\\s*$", env)

    req <- list(
      REQUEST_METHOD = "PUT",
      user_id = 7L,
      argsBody = list(review_json = list(review_id = 55L, synopsis = "text"))
    )
    res <- make_mock_res()
    result <- handler(req = req, res = res)
    expect_equal(res$status, 400)
    expect_true(!is.null(result$error))
  })
})

test_that("PUT /update review: permission — Viewer role blocked with 403", {
  with_test_db_transaction({
    env <- make_review_sandbox(require_role_fn = deny_role)
    handler <- extract_review_handler("^#\\*\\s+@put\\s+/update\\s*$", env)

    req <- list(
      REQUEST_METHOD = "PUT",
      user_id = 7L,
      argsBody = list(
        review_json = list(entity_id = 1L, review_id = 9L, synopsis = "x")
      )
    )
    res <- make_mock_res()
    expect_error(handler(req = req, res = res), "forbidden")
    expect_equal(res$status, 403L)
  })
})


# =============================================================================
# GET /<review_id_requested> -- single review lookup
# =============================================================================

test_that("GET /<review_id_requested>: happy path — decorator + parameterised signature", {
  with_test_db_transaction({
    src <- review_source()
    expect_true(
      any(grepl("^#\\*\\s+@get\\s+/<review_id_requested>\\s*$", src)),
      info = "review_endpoints.R must declare `#* @get /<review_id_requested>`."
    )
    dec_idx <- grep("^#\\*\\s+@get\\s+/<review_id_requested>\\s*$", src)[[1L]]
    sig_line <- src[dec_idx + 1L]
    expect_match(sig_line, "^function\\(review_id_requested\\)")
  })
})

test_that("GET /<review_id_requested>: validation — handler URLdecodes + splits on comma", {
  with_test_db_transaction({
    src <- review_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/<review_id_requested>\\s*$", src)[[1L]]
    window <- paste(src[dec_idx:(dec_idx + 6L)], collapse = "\n")
    expect_match(window, "URLdecode\\(review_id_requested\\)")
    expect_match(window, "str_split\\(pattern\\s*=\\s*\",\"")
  })
})

test_that("GET /<review_id_requested>: permission — public read (no require_role)", {
  with_test_db_transaction({
    src <- review_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/<review_id_requested>\\s*$", src)[[1L]]
    # Walk forward until the next decorator block to bound the handler body.
    next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    after <- next_dec[next_dec > dec_idx][[1L]]
    body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
    expect_false(grepl("require_role\\(", body_blob))
  })
})


# =============================================================================
# GET /<review_id_requested>/phenotypes
# =============================================================================

test_that("GET /<review_id>/phenotypes: happy path — decorator surface present", {
  with_test_db_transaction({
    src <- review_source()
    expect_true(
      any(grepl("^#\\*\\s+@get\\s+/<review_id_requested>/phenotypes\\s*$", src)),
      info = "review_endpoints.R must declare the `/phenotypes` sub-route."
    )
    dec_idx <- grep("^#\\*\\s+@get\\s+/<review_id_requested>/phenotypes\\s*$", src)[[1L]]
    sig_line <- src[dec_idx + 1L]
    expect_match(sig_line, "^function\\(review_id_requested\\)")
  })
})

test_that("GET /<review_id>/phenotypes: validation — body filters by review_id + is_active", {
  with_test_db_transaction({
    src <- review_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/<review_id_requested>/phenotypes\\s*$", src)[[1L]]
    next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    after <- next_dec[next_dec > dec_idx][[1L]]
    body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
    expect_match(
      body_blob,
      "review_id\\s*%in%\\s*review_id_requested\\s*&\\s*is_active",
      info = "Handler must filter active phenotype rows for the requested review."
    )
  })
})

test_that("GET /<review_id>/phenotypes: permission — public read (no require_role)", {
  with_test_db_transaction({
    src <- review_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/<review_id_requested>/phenotypes\\s*$", src)[[1L]]
    next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    after <- next_dec[next_dec > dec_idx][[1L]]
    body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
    expect_false(grepl("require_role\\(", body_blob))
  })
})


# =============================================================================
# GET /<review_id_requested>/variation
# =============================================================================

test_that("GET /<review_id>/variation: happy path — decorator surface present", {
  with_test_db_transaction({
    src <- review_source()
    expect_true(
      any(grepl("^#\\*\\s+@get\\s+/<review_id_requested>/variation\\s*$", src))
    )
    dec_idx <- grep("^#\\*\\s+@get\\s+/<review_id_requested>/variation\\s*$", src)[[1L]]
    sig_line <- src[dec_idx + 1L]
    expect_match(sig_line, "^function\\(review_id_requested\\)")
  })
})

test_that("GET /<review_id>/variation: validation — joins variation_ontology_list", {
  with_test_db_transaction({
    src <- review_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/<review_id_requested>/variation\\s*$", src)[[1L]]
    next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    after <- next_dec[next_dec > dec_idx][[1L]]
    body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
    expect_match(body_blob, "variation_ontology_list")
    expect_match(body_blob, "vario_id")
  })
})

test_that("GET /<review_id>/variation: permission — public read (no require_role)", {
  with_test_db_transaction({
    src <- review_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/<review_id_requested>/variation\\s*$", src)[[1L]]
    next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    after <- next_dec[next_dec > dec_idx][[1L]]
    body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
    expect_false(grepl("require_role\\(", body_blob))
  })
})


# =============================================================================
# GET /<review_id_requested>/publications
# =============================================================================

test_that("GET /<review_id>/publications: happy path — decorator surface present", {
  with_test_db_transaction({
    src <- review_source()
    expect_true(
      any(grepl("^#\\*\\s+@get\\s+/<review_id_requested>/publications\\s*$", src))
    )
    dec_idx <- grep("^#\\*\\s+@get\\s+/<review_id_requested>/publications\\s*$", src)[[1L]]
    sig_line <- src[dec_idx + 1L]
    expect_match(sig_line, "^function\\(review_id_requested\\)")
  })
})

test_that("GET /<review_id>/publications: validation — pulls ndd_review_publication_join", {
  with_test_db_transaction({
    src <- review_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/<review_id_requested>/publications\\s*$", src)[[1L]]
    next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    after <- next_dec[next_dec > dec_idx][[1L]]
    body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
    expect_match(body_blob, "ndd_review_publication_join")
  })
})

test_that("GET /<review_id>/publications: permission — public read (no require_role)", {
  with_test_db_transaction({
    src <- review_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/<review_id_requested>/publications\\s*$", src)[[1L]]
    next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    after <- next_dec[next_dec > dec_idx][[1L]]
    body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
    expect_false(grepl("require_role\\(", body_blob))
  })
})


# =============================================================================
# PUT /approve/<review_id_requested> -- approve a review (Curator+)
# =============================================================================

test_that("PUT /approve/<review_id>: happy path — service returns approval payload", {
  with_test_db_transaction({
    approval_seen <- list(called = FALSE, approve = NA, user_id = NA_integer_)
    fake_svc <- function(review_id, user_id, approve, pool) {
      approval_seen$called <<- TRUE
      approval_seen$approve <<- approve
      approval_seen$user_id <<- user_id
      list(status = 200, message = "OK. Review approved.")
    }
    env <- make_review_sandbox(svc_approval_review_approve_fn = fake_svc)
    handler <- extract_review_handler(
      "^#\\*\\s+@put\\s+/approve/<review_id_requested>\\s*$",
      env
    )
    expect_true(is.function(handler))

    req <- list(user_id = 17L)
    res <- make_mock_res()
    result <- handler(req = req, res = res, review_id_requested = "77", review_ok = "TRUE")
    expect_equal(result$status, 200)
    expect_true(approval_seen$called)
    expect_true(approval_seen$approve)
    expect_equal(approval_seen$user_id, 17L)
  })
})

test_that("PUT /approve/<review_id>: validation — review_ok coerced via as.logical", {
  with_test_db_transaction({
    captured_approve <- NULL
    fake_svc <- function(review_id, user_id, approve, pool) {
      captured_approve <<- approve
      list(status = 200, message = "OK.")
    }
    env <- make_review_sandbox(svc_approval_review_approve_fn = fake_svc)
    handler <- extract_review_handler(
      "^#\\*\\s+@put\\s+/approve/<review_id_requested>\\s*$",
      env
    )

    req <- list(user_id = 17L)
    res <- make_mock_res()
    handler(req = req, res = res, review_id_requested = "77", review_ok = "FALSE")
    expect_false(captured_approve)
    expect_type(captured_approve, "logical")
  })
})

test_that("PUT /approve/<review_id>: permission — non-Curator role blocked with 403", {
  with_test_db_transaction({
    svc_called <- FALSE
    fake_svc <- function(...) {
      svc_called <<- TRUE
      list(status = 200, message = "OK.")
    }
    env <- make_review_sandbox(
      require_role_fn = deny_role,
      svc_approval_review_approve_fn = fake_svc
    )
    handler <- extract_review_handler(
      "^#\\*\\s+@put\\s+/approve/<review_id_requested>\\s*$",
      env
    )

    req <- list(user_id = 17L)
    res <- make_mock_res()
    expect_error(
      handler(req = req, res = res, review_id_requested = "77", review_ok = "TRUE"),
      "forbidden"
    )
    expect_equal(res$status, 403L)
    expect_false(svc_called)
  })
})
