# Static guard: the admin verified-date backfill endpoints must gate both routes on
# the Administrator role and be mounted via mount_endpoint() before /api/admin so
# the more-specific prefix wins (#460). Mirrors
# test-unit-admin-snapshot-endpoint-guard.R.
test_that("verify-dates endpoints require Administrator and are mounted via mount_endpoint", {
  src <- readLines(file.path(get_api_dir(), "endpoints", "admin_publications_endpoints.R"))

  # Per-route guard check (Codex review #460): a single file-wide match would not
  # catch ONE route losing its Administrator guard. Slice each route handler from
  # its @post/@get marker to the next marker (or EOF) and assert each individually
  # gates on require_role(..., "Administrator").
  route_markers <- grep("^#\\*\\s*@(post|get)\\b", src)
  expect_gte(length(route_markers), 2L)
  route_paths <- trimws(sub("^#\\*\\s*@(post|get)\\s*", "", src[route_markers]))
  expect_true(any(grepl("/verify-dates$", route_paths)))         # POST enqueue
  expect_true(any(grepl("/verify-dates/status$", route_paths)))  # GET status

  bounds <- c(route_markers, length(src) + 1L)
  for (i in seq_along(route_markers)) {
    block <- paste(src[route_markers[i]:(bounds[i + 1L] - 1L)], collapse = "\n")
    expect_match(block, 'require_role\\([^)]*"Administrator"',
                 info = paste("route missing Administrator guard:", route_paths[i]))
  }

  mnt <- paste(readLines(file.path(get_api_dir(), "bootstrap", "mount_endpoints.R")), collapse = "\n")
  expect_match(mnt, "/api/admin/publications")
  # more-specific prefix mounted before /api/admin
  expect_lt(regexpr("/api/admin/publications", mnt)[1], regexpr('"/api/admin"', mnt)[1])
})
