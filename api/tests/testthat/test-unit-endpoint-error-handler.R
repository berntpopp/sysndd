# tests/testthat/test-unit-endpoint-error-handler.R
#
# Static guard for RFC 9457 error consistency across mounted endpoints.
#
# Plumber does NOT propagate the root router's error handler to mounted
# sub-routers — each `plumber::pr()` keeps its own. So a thrown classed error
# (e.g. stop_for_bad_request() -> error_400) inside an endpoint mounted with a
# bare `plumber::pr("endpoints/x.R")` falls back to plumber's default opaque
# `{"error":"500 ..."}` instead of being mapped to the correct status +
# application/problem+json by core/filters.R::errorHandler.
#
# bootstrap/mount_endpoints.R must therefore route EVERY endpoint sub-router
# through the `mount_endpoint()` helper, which attaches errorHandler. This is a
# pure source-text check (no DB), so it runs on the host.

library(testthat)

mount_path <- file.path(get_api_dir(), "bootstrap", "mount_endpoints.R")
mount_src <- readLines(mount_path, warn = FALSE)
mount_blob <- paste(mount_src, collapse = "\n")

test_that("mount_endpoint helper attaches the RFC 9457 error + 404 handlers", {
  expect_match(mount_blob, "mount_endpoint\\s*<-\\s*function\\(file\\)")
  # The helper body must wire pr_set_error(errorHandler) ...
  expect_match(mount_blob, "plumber::pr\\(file\\)\\s*%>%\\s*\\n\\s*plumber::pr_set_error\\(errorHandler\\)")
  # ... and pr_set_404(notFoundHandler) so sub-path 404s are RFC 9457 too.
  expect_match(mount_blob, "plumber::pr_set_404\\(notFoundHandler\\)")
})

test_that("every endpoint sub-router is mounted through mount_endpoint()", {
  mount_lines <- grep("pr_mount\\(", mount_src, value = TRUE)
  # Sanity: the API mounts many endpoint files.
  expect_gt(length(mount_lines), 20)

  # No endpoint sub-router may be mounted with a bare plumber::pr("endpoints/...")
  # — that bypasses errorHandler. All must go through mount_endpoint().
  bare <- grep('plumber::pr\\("endpoints/', mount_lines, value = TRUE)
  expect_identical(
    bare,
    character(0),
    info = paste(
      "These mounts bypass the RFC 9457 errorHandler (use mount_endpoint()):\n",
      paste(bare, collapse = "\n")
    )
  )

  # Every endpoint mount routes through the helper.
  endpoint_mounts <- grep('mount_endpoint\\("endpoints/', mount_lines, value = TRUE)
  expect_gt(length(endpoint_mounts), 20)
})

# -----------------------------------------------------------------------------
# Malformed JSON bodies: plumber parses the body before any handler runs, so a
# client sending invalid JSON reached errorHandler as a bare parse error and
# got a 500. It must be a 400 problem+json.
# -----------------------------------------------------------------------------

source_api_file("core/errors.R", local = FALSE)
source_api_file("core/filters.R", local = FALSE)

call_error_handler <- function(body, content_type = "application/json") {
  req <- list(
    REQUEST_METHOD = "POST", PATH_INFO = "/deactivate",
    HTTP_CONTENT_TYPE = content_type, bodyRaw = charToRaw(body)
  )
  res <- new.env(parent = emptyenv())
  err <- tryCatch(jsonlite::parse_json(body), error = function(e) e)
  if (!inherits(err, "error")) err <- simpleError("boom")
  out <- suppressMessages(errorHandler(req, res, err))
  list(status = res$status, body = out)
}

test_that("errorHandler maps an invalid JSON request body to 400 problem+json", {
  for (body in c("{bad", "{\"deactivate_json\":", "[1,")) {
    r <- call_error_handler(body)
    expect_equal(r$status, 400, info = body)
    expect_equal(r$body$detail, "Malformed JSON request body")
  }
})

test_that("errorHandler maps invalid JSON sent without a content type to 400", {
  # plumber picks its JSON parser for a body starting with { or [ when no type is set.
  expect_equal(call_error_handler("{bad", content_type = NULL)$status, 400)
})

test_that("errorHandler keeps 500 for an unexpected error with a valid, empty or non-JSON body", {
  expect_equal(call_error_handler("{\"a\":1}")$status, 500)
  expect_equal(call_error_handler("")$status, 500)
  expect_equal(call_error_handler("{bad", content_type = "text/plain")$status, 500)
  expect_equal(call_error_handler("a=1", content_type = NULL)$status, 500)
})
