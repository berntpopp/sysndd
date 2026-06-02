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

test_that("mount_endpoint helper attaches the RFC 9457 errorHandler", {
  expect_match(mount_blob, "mount_endpoint\\s*<-\\s*function\\(file\\)")
  # The helper body must wire pr_set_error(errorHandler).
  expect_match(mount_blob, "plumber::pr\\(file\\)\\s*%>%\\s*\\n\\s*plumber::pr_set_error\\(errorHandler\\)")
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
