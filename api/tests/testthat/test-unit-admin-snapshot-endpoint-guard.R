# Static guard: the admin snapshot AND admin release endpoints must gate
# every route on the Administrator role and must be mounted via
# mount_endpoint() (#420 / #573 Slice A Task A7).

# Resolve files relative to the API directory via the shared get_api_dir()
# helper (helper-paths.R, auto-loaded by testthat), mirroring how
# test-unit-endpoint-error-handler.R locates bootstrap/mount_endpoints.R.
read_api_lines <- function(rel) {
  path <- file.path(get_api_dir(), rel)
  if (!file.exists(path)) stop(sprintf("cannot locate %s", path))
  readLines(path, warn = FALSE)
}

test_that("both admin snapshot routes require the Administrator role", {
  src <- read_api_lines("endpoints/admin_analysis_snapshot_endpoints.R")
  joined <- paste(src, collapse = "\n")
  expect_true(grepl("@post /snapshots/refresh", joined, fixed = TRUE))
  expect_true(grepl("@get /snapshots/status", joined, fixed = TRUE))
  role_gate <- grepl('require_role(req, res, "Administrator")', src, fixed = TRUE)
  expect_gte(sum(role_gate), 2L)
})

test_that("all 6 admin analysis-release routes are declared and Administrator-gated", {
  src <- read_api_lines("endpoints/admin_analysis_snapshot_endpoints.R")
  joined <- paste(src, collapse = "\n")

  expect_true(grepl("@post /releases", joined, fixed = TRUE))
  expect_true(grepl("@get /releases", joined, fixed = TRUE))
  expect_true(grepl("@get /releases/<release_id>", joined, fixed = TRUE))
  expect_true(grepl("@post /releases/<release_id>/publish", joined, fixed = TRUE))
  expect_true(grepl("@patch /releases/<release_id>/doi", joined, fixed = TRUE))
  expect_true(grepl("@delete /releases/<release_id>", joined, fixed = TRUE))

  # 2 pre-existing snapshot routes + 6 new release routes = at least 8 gates.
  role_gate <- grepl('require_role(req, res, "Administrator")', src, fixed = TRUE)
  expect_gte(sum(role_gate), 8L)
})

test_that("admin snapshot endpoint is mounted via mount_endpoint", {
  src <- read_api_lines("bootstrap/mount_endpoints.R")
  joined <- paste(src, collapse = "\n")
  expect_true(grepl(
    'pr_mount("/api/admin/analysis", mount_endpoint("endpoints/admin_analysis_snapshot_endpoints.R"))',
    joined, fixed = TRUE
  ))
})
