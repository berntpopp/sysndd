# test-unit-admin-ontology-mapping-endpoints.R
#
# Static guard (WP-C, C4): the admin ontology-mapping endpoints must gate both
# routes on the Administrator role, be mounted via mount_endpoint() (RFC 9457),
# and be mounted at /api/admin/ontology BEFORE /api/admin so the more-specific
# prefix wins. Pure source-text checks (no DB) — runs on host.

library(testthat)

read_api_lines <- function(rel) {
  path <- file.path(get_api_dir(), rel)
  if (!file.exists(path)) stop(sprintf("cannot locate %s", path))
  readLines(path, warn = FALSE)
}

test_that("both admin ontology-mapping routes require the Administrator role", {
  src <- read_api_lines("endpoints/admin_ontology_mapping_endpoints.R")
  joined <- paste(src, collapse = "\n")
  expect_true(grepl("@post /mappings/refresh", joined, fixed = TRUE))
  expect_true(grepl("@get /mappings/status", joined, fixed = TRUE))
  role_gate <- grepl('require_role(req, res, "Administrator")', src, fixed = TRUE)
  expect_gte(sum(role_gate), 2L)
})

test_that("the refresh route returns 202 and delegates to the shared submit", {
  joined <- paste(read_api_lines("endpoints/admin_ontology_mapping_endpoints.R"), collapse = "\n")
  expect_true(grepl("res$status <- 202L", joined, fixed = TRUE))
  expect_true(grepl("service_disease_ontology_mapping_submit_refresh", joined, fixed = TRUE))
  expect_true(grepl("service_disease_ontology_mapping_status()", joined, fixed = TRUE))
})

test_that("admin ontology endpoint is mounted via mount_endpoint before /api/admin", {
  src <- read_api_lines("bootstrap/mount_endpoints.R")
  joined <- paste(src, collapse = "\n")
  expect_true(grepl(
    'pr_mount("/api/admin/ontology", mount_endpoint("endpoints/admin_ontology_mapping_endpoints.R"))',
    joined, fixed = TRUE
  ))

  ontology_line <- grep('pr_mount("/api/admin/ontology"', src, fixed = TRUE)
  admin_line <- grep('pr_mount("/api/admin"', src, fixed = TRUE)
  expect_length(ontology_line, 1L)
  expect_length(admin_line, 1L)
  # The more-specific /api/admin/ontology prefix must be mounted first.
  expect_lt(ontology_line, admin_line)
})

test_that("dictionary-status route exists, is Administrator-gated, and calls the status service", {
  src <- read_api_lines("endpoints/admin_ontology_mapping_endpoints.R")
  body <- paste(src, collapse = "\n")
  expect_match(body, "@get /dictionary-status")
  expect_match(body, "ontology_dictionary_status")
  expect_match(body, "require_role\\(req, res, \"Administrator\"\\)")
})
