# Static guard: the admin verified-date backfill endpoints must gate both routes on
# the Administrator role and be mounted via mount_endpoint() before /api/admin so
# the more-specific prefix wins (#460). Mirrors
# test-unit-admin-snapshot-endpoint-guard.R.
test_that("verify-dates endpoints require Administrator and are mounted via mount_endpoint", {
  src <- readLines(file.path(get_api_dir(), "endpoints", "admin_publications_endpoints.R"))
  body <- paste(src, collapse = "\n")
  expect_match(body, 'require_role\\([^)]*"Administrator"')
  mnt <- paste(readLines(file.path(get_api_dir(), "bootstrap", "mount_endpoints.R")), collapse = "\n")
  expect_match(mnt, "/api/admin/publications")
  # more-specific prefix mounted before /api/admin
  expect_lt(regexpr("/api/admin/publications", mnt)[1], regexpr('"/api/admin"', mnt)[1])
})
