# tests/testthat/test-endpoint-hash.R
# Endpoint tests for hash creation handler.
#
# Scope (Phase C unit C9, exit criterion #5 locked):
#   Per HTTP method per route in api/endpoints/hash_endpoints.R, at
#   minimum a happy-path `test_that()` block. This file currently exposes
#   a single route:
#     - POST create  (no leading slash; mounted at /api/hash/create)
#
# Handler extraction:
#   We parse the endpoint file and eval the top-level function literal
#   that follows each decorator into a sandbox environment carrying a
#   stub `post_db_hash()`. This mirrors the approach in
#   test-endpoint-auth.R. No real DB is touched.

library(testthat)

`%||%` <- function(a, b) if (is.null(a)) b else a

extract_plumber_handler <- function(file_path, decorator_regex, envir) {
  src_lines <- readLines(file_path, warn = FALSE)
  dec_line <- grep(decorator_regex, src_lines)
  if (length(dec_line) == 0L) {
    stop("Decorator not found: ", decorator_regex)
  }
  dec_line <- dec_line[[1L]]

  parsed <- parse(file = file_path, keep.source = TRUE)
  srcrefs <- attr(parsed, "srcref")
  if (is.null(srcrefs)) {
    stop("Unable to read source refs for ", file_path)
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

hash_file_path <- function() {
  file.path(get_api_dir(), "endpoints", "hash_endpoints.R")
}

make_hash_sandbox <- function(post_db_hash_fn = NULL) {
  env <- new.env(parent = globalenv())
  env$`%||%` <- function(a, b) if (is.null(a)) b else a
  env$post_db_hash <- post_db_hash_fn %||% function(json_data, columns, endpoint) {
    list(
      hash = "fakehash1234567890abcdef",
      endpoint = endpoint,
      href = paste0(endpoint, "/hash/", "fakehash1234567890abcdef")
    )
  }
  env
}

extract_post_create <- function(envir) {
  extract_plumber_handler(
    hash_file_path(),
    decorator_regex = "^#\\*\\s+@post\\s+create\\s*$",
    envir = envir
  )
}


# -----------------------------------------------------------------------------
# Route-surface assertions (structural)
# -----------------------------------------------------------------------------

test_that("hash_endpoints.R exposes @post create", {
  src <- readLines(hash_file_path(), warn = FALSE)
  decorators <- grep("^#\\*\\s+@post\\s+create\\s*$", src, value = TRUE)
  expect_true(
    length(decorators) >= 1L,
    info = "Expected a `#* @post create` decorator to be present."
  )
})


# -----------------------------------------------------------------------------
# POST create
# -----------------------------------------------------------------------------

test_that("POST create happy path returns hash link from post_db_hash", {
  called <- new.env()
  called$args <- NULL
  env <- make_hash_sandbox(function(json_data, columns, endpoint) {
    called$args <- list(
      json_data = json_data,
      columns = columns,
      endpoint = endpoint
    )
    list(
      hash = "abc123",
      endpoint = endpoint,
      href = paste0(endpoint, "/hash/abc123")
    )
  })
  handler <- extract_post_create(env)
  expect_true(is.function(handler))

  req <- list(
    argsBody = list(
      json_data = list(
        list(symbol = "ARID1B", hgnc_id = "HGNC:18040", entity_id = 1L),
        list(symbol = "GRIN2B", hgnc_id = "HGNC:4586", entity_id = 2L)
      )
    )
  )
  res <- make_mock_res()
  result <- handler(req = req, res = res, endpoint = "/api/gene")

  expect_equal(res$status, 200L)
  expect_equal(result$hash, "abc123")
  expect_equal(result$endpoint, "/api/gene")
  # The handler hard-codes the columns argument to this exact value.
  expect_equal(called$args$columns, "symbol,hgnc_id,entity_id")
  expect_equal(called$args$endpoint, "/api/gene")
})

test_that("POST create uses default endpoint /api/gene when not provided", {
  received_endpoint <- new.env()
  received_endpoint$value <- NULL
  env <- make_hash_sandbox(function(json_data, columns, endpoint) {
    received_endpoint$value <- endpoint
    list(hash = "xyz", endpoint = endpoint)
  })
  handler <- extract_post_create(env)

  req <- list(argsBody = list(json_data = list(list(symbol = "FOO"))))
  res <- make_mock_res()
  handler(req = req, res = res)

  expect_equal(received_endpoint$value, "/api/gene")
})

test_that("POST create returns 400 when json_data is missing", {
  env <- make_hash_sandbox(function(...) {
    stop("should not be called when json_data missing")
  })
  handler <- extract_post_create(env)

  req <- list(argsBody = list())
  res <- make_mock_res()
  result <- handler(req = req, res = res, endpoint = "/api/gene")

  expect_equal(res$status, 400L)
  # Handler sets res$body to a JSON string and returns res.
  expect_true(!is.null(res$body))
  parsed <- jsonlite::fromJSON(res$body)
  expect_equal(parsed$status, 400)
  expect_match(
    parsed$message,
    "json_data",
    info = "Error message should mention the missing json_data parameter."
  )
})

test_that("POST create passes custom endpoint through to post_db_hash", {
  received_endpoint <- new.env()
  received_endpoint$value <- NULL
  env <- make_hash_sandbox(function(json_data, columns, endpoint) {
    received_endpoint$value <- endpoint
    list(hash = "e1", endpoint = endpoint)
  })
  handler <- extract_post_create(env)

  req <- list(argsBody = list(json_data = list(list(symbol = "BAR"))))
  res <- make_mock_res()
  handler(req = req, res = res, endpoint = "/api/entity")

  expect_equal(received_endpoint$value, "/api/entity")
})
