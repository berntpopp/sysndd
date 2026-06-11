# tests/testthat/test-unit-core-views-manifest.R
#
# Verifies that the latest migration is reflected in the manifest constants and
# that the on-disk migration directory agrees with the manifest expectations.
#
# Uses get_api_dir() (from helper-paths.R) to locate the migrations directory
# portably across cwd contexts (api/, tests/testthat/, Docker /app).

source_api_file("functions/migration-manifest.R", local = FALSE)
source_api_file("functions/migration-runner.R", local = FALSE)

test_that("manifest expects migration 027 as latest", {
  expect_equal(EXPECTED_LATEST_MIGRATION, "027_add_pubtator_gene_enrichment.sql")
  expect_gte(EXPECTED_MIGRATION_COUNT, 28L)
})

test_that("migration manifest validates against db/migrations", {
  migrations_dir <- file.path(get_api_dir(), "..", "db", "migrations")
  res <- validate_migration_manifest(migrations_dir = migrations_dir)
  expect_true(res$ok)
  expect_identical(res$latest, "027_add_pubtator_gene_enrichment.sql")
})

test_that("migration 026 adds a last_update column derived from curation dates", {
  migration_path <- file.path(
    get_api_dir(), "..", "db", "migrations",
    "026_add_entity_last_update.sql"
  )
  expect_true(file.exists(migration_path))
  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")

  # Rebuilds ndd_entity_view with a derived freshness column.
  expect_match(sql, "CREATE OR REPLACE", fixed = TRUE)
  expect_match(sql, "ndd_entity_view", fixed = TRUE)
  expect_match(sql, "AS `last_update`", fixed = TRUE)
  expect_match(sql, "GREATEST", fixed = TRUE)

  # last_update must fold in the approved status date and the primary-approved
  # review date, not just entry_date.
  expect_match(sql, "status_date", fixed = TRUE)
  expect_match(sql, "review_date", fixed = TRUE)
  expect_match(sql, "is_primary", fixed = TRUE)
  expect_match(sql, "review_approved", fixed = TRUE)
})
