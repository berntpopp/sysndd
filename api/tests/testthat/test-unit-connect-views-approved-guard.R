# tests/testthat/test-unit-connect-views-approved-guard.R
#
# Guard (#3 views): ndd_review_phenotype_connect_view and
# ndd_review_variant_connect_view feed the public phenotype/variant browse,
# count and correlation endpoints (endpoint-functions.R) and the entity-list
# vario filter. They must gate is_active = 1 AND is_primary = 1 AND
# review_approved = 1, or unapproved in-place review edits leak publicly.
# Migration 042 and the C_Rcommands mirror must stay in sync (Codex PR-1 review).
#
# Pure (no database) — source scan; runs on host.

connect_views_migration_path <- function() {
  file.path(get_api_dir(), "..", "db", "migrations",
            "042_gate_connect_views_review_approved.sql")
}

c_rcommands_path <- function() {
  file.path(get_api_dir(), "..", "db", "C_Rcommands_set-table-connections.R")
}

test_that("migration 042 gates both connect views on review_approved", {
  path <- connect_views_migration_path()
  expect_true(file.exists(path))
  sql <- paste(readLines(path, warn = FALSE), collapse = "\n")

  expect_match(sql, "VIEW `ndd_review_phenotype_connect_view`", fixed = TRUE)
  expect_match(sql, "VIEW `ndd_review_variant_connect_view`", fixed = TRUE)

  # Both views must carry all three predicates.
  n_approved <- length(gregexpr("`review_approved` = 1", sql, fixed = TRUE)[[1]])
  expect_gte(n_approved, 2)
  expect_match(sql, "`is_primary` = 1", fixed = TRUE)
  expect_match(sql, "`is_active` = 1", fixed = TRUE)
})

test_that("C_Rcommands mirror also gates both connect views on review_approved", {
  path <- c_rcommands_path()
  skip_if_not(file.exists(path))
  src <- paste(readLines(path, warn = FALSE), collapse = "\n")

  # The two connect views in the out-of-band script must stay in sync with the
  # migration: each adds review_approved to its WHERE clause.
  n_approved <- length(gregexpr("`review_approved` = 1", src, fixed = TRUE)[[1]])
  expect_gte(n_approved, 2)
})
