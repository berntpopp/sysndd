# tests/testthat/test-endpoint-status.R
#
# Phase C / C8 (`test-endpoint-write-batch`) — testthat coverage for
# `api/endpoints/status_endpoints.R`. Sibling of test-endpoint-review.R;
# see that file's header for the full rationale, including the
# handler-extraction sandbox pattern and the `with_test_db_transaction()`
# gating rule locked by the plan's exit criterion #5.
#
# Routes covered in `status_endpoints.R` (6 decorators):
#   GET  /
#   GET  /<status_id_requested>
#   GET  _list
#   POST /create            (shared handler with PUT /update)
#   PUT  /update            (shared handler with POST /create)
#   PUT  /approve/<status_id_requested>
#
# 6 routes * 3 blocks each = 18 `test_that` blocks.

library(testthat)

# -----------------------------------------------------------------------------
# Helpers (file-local; keeps Layer A of verify-test-gate green because we
# don't mutate the shared test-endpoint-auth extractor).
# -----------------------------------------------------------------------------

status_endpoint_path <- function() {
  file.path(get_api_dir(), "endpoints", "status_endpoints.R")
}

status_source <- function() {
  readLines(status_endpoint_path(), warn = FALSE)
}

extract_status_handler <- function(decorator_regex, envir) {
  src_lines <- status_source()
  dec_hits <- grep(decorator_regex, src_lines)
  if (length(dec_hits) == 0L) {
    stop("Decorator not found in status_endpoints.R: ", decorator_regex)
  }
  dec_line <- dec_hits[[1L]]

  parsed <- parse(file = status_endpoint_path(), keep.source = TRUE)
  srcrefs <- attr(parsed, "srcref")
  if (is.null(srcrefs)) {
    stop("Unable to read source refs for status_endpoints.R")
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

make_status_sandbox <- function(require_role_fn = function(req, res, min_role) invisible(TRUE),
                                put_post_db_status_fn = function(method, status_data, re_review) {
                                  list(status = 200, message = "OK. Status stored.")
                                },
                                svc_approval_status_approve_fn = function(status_id,
                                                                          user_id,
                                                                          approve,
                                                                          pool) {
                                  list(status = 200, message = "OK. Status approved.")
                                },
                                generate_cursor_pag_inf_safe_fn = function(data,
                                                                            page_size,
                                                                            page_after,
                                                                            identifier) {
                                  list(
                                    links = list(self = "stub"),
                                    meta = list(perPage = 10, currentPage = 1, totalPages = 1),
                                    data = data
                                  )
                                }) {
  env <- new.env(parent = globalenv())
  env$require_role <- require_role_fn
  env$pool <- "STUB_POOL"
  env$put_post_db_status <- put_post_db_status_fn
  env$svc_approval_status_approve <- svc_approval_status_approve_fn
  env$generate_cursor_pag_inf_safe <- generate_cursor_pag_inf_safe_fn
  env$`%||%` <- function(a, b) if (is.null(a)) b else a
  # Direct-approval helper (issues #36/#37). Faithful copy of
  # approval-service.R::svc_status_apply_direct_approval that delegates to the
  # sandbox's status-approve stub. Calls `svc_approval_status_approve_fn`
  # directly (closed over here) rather than by name, so it always hits the
  # injected stub regardless of lexical scope. Keeps the handler test
  # self-contained without sourcing the service layer.
  env$svc_status_apply_direct_approval <- function(write_response, user_id,
                                                   direct_approval, pool) {
    if (!isTRUE(direct_approval)) return(write_response)
    if (is.null(write_response$status) || write_response$status != 200) return(write_response)
    status_id <- write_response$entry
    if (is.null(status_id) || length(status_id) == 0 || is.na(status_id[[1]])) {
      return(write_response)
    }
    approval <- svc_approval_status_approve_fn(status_id, user_id, TRUE, pool)
    if (is.null(approval$status) || approval$status != 200) {
      write_response$status <- approval$status %||% 500
    }
    write_response
  }
  env
}

deny_role <- function(req, res, min_role) {
  res$status <- 403L
  stop(sprintf("forbidden: %s required", min_role))
}


# =============================================================================
# GET / -- list statuses
# =============================================================================

test_that("GET / status list: happy path — decorator surface present", {
  with_test_db_transaction({
    src <- status_source()
    expect_true(
      any(grepl("^#\\*\\s+@get\\s+/\\s*$", src)),
      info = "status_endpoints.R must declare `#* @get /` for the list route."
    )
    dec_idx <- grep("^#\\*\\s+@get\\s+/\\s*$", src)[[1L]]
    sig_line <- src[dec_idx + 1L]
    expect_match(sig_line, "^function\\(req,\\s*res,\\s*filter_status_approved\\s*=\\s*FALSE\\)")
  })
})

test_that("GET / status list: validation — filter_status_approved coerced via as.logical", {
  with_test_db_transaction({
    src <- status_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/\\s*$", src)[[1L]]
    window <- paste(src[dec_idx:(dec_idx + 10L)], collapse = "\n")
    expect_match(
      window,
      "filter_status_approved\\s*<-\\s*as\\.logical\\(filter_status_approved\\)",
      info = "Handler must coerce filter_status_approved to logical before use."
    )
  })
})

test_that("GET / status list: permission — requires Reviewer+", {
  with_test_db_transaction({
    src <- status_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/\\s*$", src)[[1L]]
    next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    after <- next_dec[next_dec > dec_idx][[1L]]
    body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
    expect_true(
      grepl("require_role\\(\\s*req\\s*,\\s*res\\s*,\\s*\"Reviewer\"", body_blob),
      info = "This GET route must gate at Reviewer+ (draft/curator-identity exposure)."
    )
  })
})


# =============================================================================
# GET /<status_id_requested>
# =============================================================================

test_that("GET /<status_id_requested>: happy path — parameterised signature", {
  with_test_db_transaction({
    src <- status_source()
    expect_true(
      any(grepl("^#\\*\\s+@get\\s+/<status_id_requested>\\s*$", src))
    )
    dec_idx <- grep("^#\\*\\s+@get\\s+/<status_id_requested>\\s*$", src)[[1L]]
    sig_line <- src[dec_idx + 1L]
    expect_match(sig_line, "^function\\(req, res, status_id_requested\\)")
  })
})

test_that("GET /<status_id_requested>: validation — URLdecodes + splits on comma", {
  with_test_db_transaction({
    src <- status_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/<status_id_requested>\\s*$", src)[[1L]]
    window <- paste(src[dec_idx:(dec_idx + 6L)], collapse = "\n")
    expect_match(window, "URLdecode\\(status_id_requested\\)")
    expect_match(window, "str_split\\(pattern\\s*=\\s*\",\"")
  })
})

test_that("GET /<status_id_requested>: permission — requires Reviewer+", {
  with_test_db_transaction({
    src <- status_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/<status_id_requested>\\s*$", src)[[1L]]
    next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    after <- next_dec[next_dec > dec_idx][[1L]]
    body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
    expect_true(
      grepl("require_role\\(\\s*req\\s*,\\s*res\\s*,\\s*\"Reviewer\"", body_blob),
      info = "This GET route must gate at Reviewer+ (draft/curator-identity exposure)."
    )
  })
})


# =============================================================================
# GET _list -- status categories list
# =============================================================================

test_that("GET _list status: happy path — pagination params in signature", {
  with_test_db_transaction({
    src <- status_source()
    expect_true(
      any(grepl("^#\\*\\s+@get\\s+_list\\s*$", src)),
      info = "status_endpoints.R must declare `#* @get _list`."
    )
    dec_idx <- grep("^#\\*\\s+@get\\s+_list\\s*$", src)[[1L]]
    sig_line <- src[dec_idx + 1L]
    expect_match(sig_line, "^function\\(page_after\\s*=\\s*0,\\s*page_size\\s*=\\s*\"all\"\\)")
  })
})

test_that("GET _list status: validation — returns list with links/meta/data shape", {
  with_test_db_transaction({
    src <- status_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+_list\\s*$", src)[[1L]]
    next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    after_idx <- next_dec[next_dec > dec_idx]
    if (length(after_idx) == 0L) {
      after <- length(src) + 1L
    } else {
      after <- after_idx[[1L]]
    }
    body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
    expect_match(body_blob, "generate_cursor_pag_inf_safe")
    expect_match(body_blob, "links\\s*=\\s*pagination_info\\$links")
    expect_match(body_blob, "meta\\s*=\\s*pagination_info\\$meta")
    expect_match(body_blob, "data\\s*=\\s*pagination_info\\$data")
  })
})

test_that("GET _list status: permission — public read (no require_role)", {
  with_test_db_transaction({
    src <- status_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+_list\\s*$", src)[[1L]]
    next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    after_idx <- next_dec[next_dec > dec_idx]
    if (length(after_idx) == 0L) {
      after <- length(src) + 1L
    } else {
      after <- after_idx[[1L]]
    }
    body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
    expect_false(grepl("require_role\\(", body_blob))
  })
})


# =============================================================================
# POST /create -- create status (shared handler with PUT /update)
# =============================================================================

test_that("POST /create status: happy path — service returns 200 payload", {
  with_test_db_transaction({
    captured <- list(method = NA_character_, status_data = NULL)
    fake_put_post <- function(method, status_data, re_review) {
      captured$method <<- method
      captured$status_data <<- status_data
      list(status = 200, message = "OK. Status created.")
    }
    env <- make_status_sandbox(put_post_db_status_fn = fake_put_post)
    handler <- extract_status_handler("^#\\*\\s+@post\\s+/create\\s*$", env)
    expect_true(is.function(handler))

    req <- list(
      REQUEST_METHOD = "POST",
      user_id = 11L,
      argsBody = list(
        status_json = list(entity_id = 101L, category_id = 2L, comment = "ok")
      )
    )
    res <- make_mock_res()
    result <- handler(req = req, res = res, re_review = FALSE)
    expect_equal(result$status, 200)
    expect_equal(captured$method, "POST")
    # Handler should stamp status_user_id from req$user_id before delegating.
    expect_equal(captured$status_data$status_user_id, 11L)
  })
})

test_that("POST /create status: validation — service error propagates via res$status", {
  with_test_db_transaction({
    fake_put_post <- function(method, status_data, re_review) {
      list(status = 400, message = "Invalid status data.")
    }
    env <- make_status_sandbox(put_post_db_status_fn = fake_put_post)
    handler <- extract_status_handler("^#\\*\\s+@post\\s+/create\\s*$", env)

    req <- list(
      REQUEST_METHOD = "POST",
      user_id = 11L,
      argsBody = list(status_json = list(entity_id = NULL, category_id = NULL))
    )
    res <- make_mock_res()
    result <- handler(req = req, res = res)
    expect_equal(result$status, 400)
    # Handler sets res$status from response$status (see endpoint lines ~276).
    expect_equal(res$status, 400)
  })
})

test_that("POST /create status: permission — non-Reviewer role blocked with 403", {
  with_test_db_transaction({
    svc_called <- FALSE
    fake_put_post <- function(...) {
      svc_called <<- TRUE
      list(status = 200, message = "OK.")
    }
    env <- make_status_sandbox(
      require_role_fn = deny_role,
      put_post_db_status_fn = fake_put_post
    )
    handler <- extract_status_handler("^#\\*\\s+@post\\s+/create\\s*$", env)

    req <- list(
      REQUEST_METHOD = "POST",
      user_id = 11L,
      argsBody = list(status_json = list(entity_id = 1L, category_id = 2L))
    )
    res <- make_mock_res()
    expect_error(handler(req = req, res = res), "forbidden")
    expect_equal(res$status, 403L)
    expect_false(svc_called)
  })
})


# =============================================================================
# POST /create direct_approval -- Curator-gated approval (issues #36 / #37)
# =============================================================================

# require_role that allows Reviewer (the write gate) but denies Curator (the
# direct-approval escalation). Mirrors the real role hierarchy where a
# Reviewer can write but not approve.
deny_curator_allow_reviewer <- function(req, res, min_role) {
  if (identical(min_role, "Curator")) {
    res$status <- 403L
    stop("forbidden: Curator required")
  }
  invisible(TRUE)
}

test_that("POST /create direct_approval=TRUE: Curator approves the new status", {
  with_test_db_transaction({
    approve_args <- list()
    fake_put_post <- function(method, status_data, re_review) {
      list(status = 200, message = "OK. Status created.", entry = 77L)
    }
    fake_approve <- function(status_id, user_id, approve, pool) {
      approve_args <<- list(status_id = status_id, user_id = user_id, approve = approve)
      list(status = 200, message = "OK. Status approved.", entry = status_id)
    }
    env <- make_status_sandbox(
      put_post_db_status_fn = fake_put_post,
      svc_approval_status_approve_fn = fake_approve
    )
    handler <- extract_status_handler("^#\\*\\s+@post\\s+/create\\s*$", env)

    req <- list(
      REQUEST_METHOD = "POST",
      user_id = 11L,
      argsBody = list(status_json = list(entity_id = 101L, category_id = 2L))
    )
    res <- make_mock_res()
    result <- handler(req = req, res = res, re_review = FALSE, direct_approval = TRUE)

    expect_equal(result$status, 200)
    # The freshly created status (entry=77) is approved by the calling user.
    expect_equal(approve_args$status_id, 77L)
    expect_equal(approve_args$user_id, 11L)
    expect_true(isTRUE(approve_args$approve))
  })
})

test_that("POST /create direct_approval=FALSE: approval service is NOT called", {
  with_test_db_transaction({
    approve_called <- FALSE
    fake_put_post <- function(method, status_data, re_review) {
      list(status = 200, message = "OK. Status created.", entry = 77L)
    }
    fake_approve <- function(...) {
      approve_called <<- TRUE
      list(status = 200, message = "OK.")
    }
    env <- make_status_sandbox(
      put_post_db_status_fn = fake_put_post,
      svc_approval_status_approve_fn = fake_approve
    )
    handler <- extract_status_handler("^#\\*\\s+@post\\s+/create\\s*$", env)

    req <- list(
      REQUEST_METHOD = "POST",
      user_id = 11L,
      argsBody = list(status_json = list(entity_id = 101L, category_id = 2L))
    )
    res <- make_mock_res()
    result <- handler(req = req, res = res, re_review = FALSE, direct_approval = FALSE)

    expect_equal(result$status, 200)
    expect_false(approve_called)
  })
})

test_that("POST /create direct_approval=TRUE: Reviewer (non-Curator) blocked with 403", {
  with_test_db_transaction({
    write_called <- FALSE
    approve_called <- FALSE
    fake_put_post <- function(...) {
      write_called <<- TRUE
      list(status = 200, message = "OK.", entry = 77L)
    }
    fake_approve <- function(...) {
      approve_called <<- TRUE
      list(status = 200, message = "OK.")
    }
    env <- make_status_sandbox(
      require_role_fn = deny_curator_allow_reviewer,
      put_post_db_status_fn = fake_put_post,
      svc_approval_status_approve_fn = fake_approve
    )
    handler <- extract_status_handler("^#\\*\\s+@post\\s+/create\\s*$", env)

    req <- list(
      REQUEST_METHOD = "POST",
      user_id = 11L,
      argsBody = list(status_json = list(entity_id = 101L, category_id = 2L))
    )
    res <- make_mock_res()
    # The Curator escalation fires BEFORE any write, so a Reviewer requesting
    # direct approval is rejected and nothing is written or approved.
    expect_error(
      handler(req = req, res = res, re_review = FALSE, direct_approval = TRUE),
      "forbidden"
    )
    expect_equal(res$status, 403L)
    expect_false(write_called)
    expect_false(approve_called)
  })
})


# =============================================================================
# PUT /update -- update status (shared handler with POST /create)
# =============================================================================

test_that("PUT /update status: happy path — service returns 200 payload", {
  with_test_db_transaction({
    captured <- list(method = NA_character_)
    fake_put_post <- function(method, status_data, re_review) {
      captured$method <<- method
      list(status = 200, message = "OK. Status updated.")
    }
    env <- make_status_sandbox(put_post_db_status_fn = fake_put_post)
    handler <- extract_status_handler("^#\\*\\s+@put\\s+/update\\s*$", env)
    expect_true(is.function(handler))

    req <- list(
      REQUEST_METHOD = "PUT",
      user_id = 11L,
      argsBody = list(
        status_json = list(status_id = 41L, entity_id = 101L, category_id = 3L)
      )
    )
    res <- make_mock_res()
    result <- handler(req = req, res = res, re_review = TRUE)
    expect_equal(result$status, 200)
    expect_equal(captured$method, "PUT")
  })
})

test_that("PUT /update status: validation — service error propagates to res$status", {
  with_test_db_transaction({
    fake_put_post <- function(method, status_data, re_review) {
      list(status = 422, message = "Invalid status_id.")
    }
    env <- make_status_sandbox(put_post_db_status_fn = fake_put_post)
    handler <- extract_status_handler("^#\\*\\s+@put\\s+/update\\s*$", env)

    req <- list(
      REQUEST_METHOD = "PUT",
      user_id = 11L,
      argsBody = list(status_json = list(status_id = NA, entity_id = 1L))
    )
    res <- make_mock_res()
    result <- handler(req = req, res = res)
    expect_equal(result$status, 422)
    expect_equal(res$status, 422)
  })
})

test_that("PUT /update status: permission — non-Reviewer role blocked with 403", {
  with_test_db_transaction({
    svc_called <- FALSE
    fake_put_post <- function(...) {
      svc_called <<- TRUE
      list(status = 200, message = "OK.")
    }
    env <- make_status_sandbox(
      require_role_fn = deny_role,
      put_post_db_status_fn = fake_put_post
    )
    handler <- extract_status_handler("^#\\*\\s+@put\\s+/update\\s*$", env)

    req <- list(
      REQUEST_METHOD = "PUT",
      user_id = 11L,
      argsBody = list(status_json = list(status_id = 41L, entity_id = 101L))
    )
    res <- make_mock_res()
    expect_error(handler(req = req, res = res), "forbidden")
    expect_equal(res$status, 403L)
    expect_false(svc_called)
  })
})


# =============================================================================
# PUT /approve/<status_id_requested>
# =============================================================================

test_that("PUT /approve/<status_id>: happy path — service returns approval payload", {
  with_test_db_transaction({
    captured <- list(called = FALSE, approve = NA, user_id = NA_integer_)
    fake_svc <- function(status_id, user_id, approve, pool) {
      captured$called <<- TRUE
      captured$approve <<- approve
      captured$user_id <<- user_id
      list(status = 200, message = "OK. Status approved.")
    }
    env <- make_status_sandbox(svc_approval_status_approve_fn = fake_svc)
    handler <- extract_status_handler(
      "^#\\*\\s+@put\\s+/approve/<status_id_requested>\\s*$",
      env
    )
    expect_true(is.function(handler))

    req <- list(user_id = 21L)
    res <- make_mock_res()
    result <- handler(req = req, res = res, status_id_requested = "88", status_ok = "TRUE")
    expect_equal(result$status, 200)
    expect_true(captured$called)
    expect_true(captured$approve)
    expect_equal(captured$user_id, 21L)
  })
})

test_that("PUT /approve/<status_id>: validation — status_ok coerced via as.logical", {
  with_test_db_transaction({
    captured_approve <- NULL
    fake_svc <- function(status_id, user_id, approve, pool) {
      captured_approve <<- approve
      list(status = 200, message = "OK.")
    }
    env <- make_status_sandbox(svc_approval_status_approve_fn = fake_svc)
    handler <- extract_status_handler(
      "^#\\*\\s+@put\\s+/approve/<status_id_requested>\\s*$",
      env
    )

    req <- list(user_id = 21L)
    res <- make_mock_res()
    handler(req = req, res = res, status_id_requested = "88", status_ok = "FALSE")
    expect_false(captured_approve)
    expect_type(captured_approve, "logical")
  })
})

test_that("PUT /approve/<status_id>: permission — non-Curator role blocked with 403", {
  with_test_db_transaction({
    svc_called <- FALSE
    fake_svc <- function(...) {
      svc_called <<- TRUE
      list(status = 200, message = "OK.")
    }
    env <- make_status_sandbox(
      require_role_fn = deny_role,
      svc_approval_status_approve_fn = fake_svc
    )
    handler <- extract_status_handler(
      "^#\\*\\s+@put\\s+/approve/<status_id_requested>\\s*$",
      env
    )

    req <- list(user_id = 21L)
    res <- make_mock_res()
    expect_error(
      handler(req = req, res = res, status_id_requested = "88", status_ok = "TRUE"),
      "forbidden"
    )
    expect_equal(res$status, 403L)
    expect_false(svc_called)
  })
})
