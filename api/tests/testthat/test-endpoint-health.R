test_that("readiness depends on migration manifest health", {
  health_src <- paste(readLines(file.path(get_api_dir(), "endpoints", "health_endpoints.R"), warn = FALSE), collapse = "\n")
  expect_match(health_src, "manifest_ok")
  expect_match(health_src, "migrations_ok <- .*manifest_ok")
})
