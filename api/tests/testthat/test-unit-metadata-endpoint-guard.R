# tests/testthat/test-unit-metadata-endpoint-guard.R
#
# Static guards for the Admin metadata vocabulary endpoints (issue #32).
# Pure source-text checks (no DB), so they run on the host.
#
# Guarantees:
#   1. /api/metadata is mounted through mount_endpoint() (RFC 9457 errors).
#   2. Every plumber handler in metadata_endpoints.R calls
#      require_role(req, res, "Administrator") so no route is unauthenticated.
#   3. The repository + service files are registered in load_modules.R so the
#      functions exist at runtime.

library(testthat)

endpoint_path <- file.path(get_api_dir(), "endpoints", "metadata_endpoints.R")
endpoint_src <- readLines(endpoint_path, warn = FALSE)
endpoint_blob <- paste(endpoint_src, collapse = "\n")

mount_blob <- paste(
  readLines(file.path(get_api_dir(), "bootstrap", "mount_endpoints.R"), warn = FALSE),
  collapse = "\n"
)

modules_blob <- paste(
  readLines(file.path(get_api_dir(), "bootstrap", "load_modules.R"), warn = FALSE),
  collapse = "\n"
)

test_that("metadata endpoints are mounted via mount_endpoint()", {
  expect_match(
    mount_blob,
    'pr_mount\\("/api/metadata", mount_endpoint\\("endpoints/metadata_endpoints.R"\\)\\)'
  )
})

test_that("every metadata handler enforces Administrator role", {
  # Count plumber route annotations (@get/@post/@put/@delete).
  route_count <- length(grep("^#\\*\\s*@(get|post|put|delete)", endpoint_src))
  expect_gte(route_count, 5)

  # Count Administrator role guards.
  guard_count <- length(grep(
    'require_role\\(req, res, "Administrator"\\)',
    endpoint_src
  ))

  # Every route must be guarded.
  expect_equal(guard_count, route_count)
})

test_that("metadata writes are body-only (no query-string write transport)", {
  # Write handlers read the parsed JSON body, never a query-string write param.
  expect_match(endpoint_blob, "\\.metadata_request_body\\(req\\)")
  # The body helper tolerates plumber's two body accessors.
  expect_match(endpoint_blob, "req\\$body")
  expect_match(endpoint_blob, "req\\$argsBody")
})

test_that("repository and service modules are registered in load order", {
  expect_match(modules_blob, '"functions/metadata-vocabulary-repository.R"')
  expect_match(modules_blob, '"services/metadata-vocabulary-service.R"')
  # Repository must load before service (service prefix invariant; repo provides
  # the functions the service calls).
  repo_pos <- regexpr('"functions/metadata-vocabulary-repository.R"', modules_blob)
  svc_pos <- regexpr('"services/metadata-vocabulary-service.R"', modules_blob)
  expect_true(repo_pos > 0 && svc_pos > 0)
  expect_lt(repo_pos, svc_pos)
})
