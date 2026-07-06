# tests/testthat/test-unit-core-views-manifest.R
#
# Verifies that the latest migration is reflected in the manifest constants and
# that the on-disk migration directory agrees with the manifest expectations.
#
# Uses get_api_dir() (from helper-paths.R) to locate the migrations directory
# portably across cwd contexts (api/, tests/testthat/, Docker /app).

source_api_file("functions/migration-manifest.R", local = FALSE)
source_api_file("functions/migration-runner.R", local = FALSE)

test_that("manifest expects migration 042 as latest", {
  expect_equal(EXPECTED_LATEST_MIGRATION, "042_gate_connect_views_review_approved.sql")
  expect_equal(EXPECTED_MIGRATION_COUNT, 39L)
})

test_that("migration manifest validates against db/migrations", {
  migrations_dir <- file.path(get_api_dir(), "..", "db", "migrations")
  res <- validate_migration_manifest(migrations_dir = migrations_dir)
  expect_true(res$ok)
  expect_identical(res$latest, "042_gate_connect_views_review_approved.sql")
})

test_that("migration 036 file exists and contains disease_ontology_mapping table", {
  migration_path <- file.path(
    get_api_dir(), "..", "db", "migrations",
    "036_add_disease_ontology_mappings.sql"
  )
  expect_true(file.exists(migration_path))
  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")

  # Must create the disease_ontology_mapping table.
  expect_match(sql, "CREATE TABLE IF NOT EXISTS `disease_ontology_mapping`", fixed = TRUE)

  # Cross-charset join key must be pinned to utf8mb3.
  expect_match(sql, "CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci", fixed = TRUE)

  # Must also create the other new tables.
  expect_match(sql, "CREATE TABLE IF NOT EXISTS `mondo_term`", fixed = TRUE)
  expect_match(sql, "CREATE TABLE IF NOT EXISTS `mondo_xref`", fixed = TRUE)
  expect_match(sql, "CREATE TABLE IF NOT EXISTS `disease_ontology_mapping_meta`", fixed = TRUE)

  # Must add new columns to disease_ontology_set.
  expect_match(sql, "ALTER TABLE `disease_ontology_set`", fixed = TRUE)
  expect_match(sql, "`UMLS`", fixed = TRUE)
  expect_match(sql, "`MedGen`", fixed = TRUE)
  expect_match(sql, "`NCIT`", fixed = TRUE)
  expect_match(sql, "`GARD`", fixed = TRUE)
  expect_match(sql, "`ontology_mapping_release`", fixed = TRUE)
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
