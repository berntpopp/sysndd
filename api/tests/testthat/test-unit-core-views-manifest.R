# tests/testthat/test-unit-core-views-manifest.R
#
# Verifies that migration 025 is reflected in the manifest constants and that
# the on-disk migration directory agrees with the manifest expectations.
#
# Uses get_api_dir() (from helper-paths.R) to locate the migrations directory
# portably across cwd contexts (api/, tests/testthat/, Docker /app).

source_api_file("functions/migration-manifest.R", local = FALSE)
source_api_file("functions/migration-runner.R", local = FALSE)

test_that("manifest expects migration 025 as latest", {
  expect_equal(EXPECTED_LATEST_MIGRATION, "025_create_core_views.sql")
  expect_gte(EXPECTED_MIGRATION_COUNT, 26L)
})

test_that("migration manifest validates against db/migrations", {
  migrations_dir <- file.path(get_api_dir(), "..", "db", "migrations")
  res <- validate_migration_manifest(migrations_dir = migrations_dir)
  expect_true(res$ok)
  expect_identical(res$latest, "025_create_core_views.sql")
})
