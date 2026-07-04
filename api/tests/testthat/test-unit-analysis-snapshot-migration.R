analysis_snapshot_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(analysis_snapshot_test_wd), testthat::teardown_env())

test_that("migration manifest tracks the latest migration", {
  source(file.path("functions", "migration-manifest.R"), local = TRUE)

  expect_equal(EXPECTED_LATEST_MIGRATION, "040_rename_geisinger_to_ndd_genehub.sql")
  expect_equal(EXPECTED_MIGRATION_COUNT, 35L)
})

test_that("migration 037 adds validation + db release columns", {
  sql <- paste(readLines(file.path(
    get_api_dir(), "..", "db", "migrations",
    "037_add_analysis_snapshot_validation.sql"
  )), collapse = "\n")
  expect_match(sql, "validation_json")
  expect_match(sql, "db_release_version")
  expect_match(sql, "db_release_commit")
  expect_match(sql, "ALTER TABLE\\s+analysis_snapshot_manifest")
})

test_that("public analysis snapshot migration enforces scoped public-ready uniqueness", {
  migration_path <- file.path("..", "db", "migrations", "024_add_public_analysis_snapshots.sql")
  if (!file.exists(migration_path)) {
    migration_path <- file.path("db", "migrations", "024_add_public_analysis_snapshots.sql")
  }
  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")

  expect_match(sql, "analysis_snapshot_manifest", fixed = TRUE)
  expect_match(sql, "public_ready_slot", fixed = TRUE)
  expect_match(sql, "analysis_type", fixed = TRUE)
  expect_match(sql, "parameter_hash", fixed = TRUE)
  expect_match(sql, "UNIQUE KEY `idx_analysis_snapshot_public_ready`", fixed = TRUE)
  expect_match(sql, "`analysis_type`, `parameter_hash`, `public_ready_slot`", fixed = TRUE)
  expect_match(sql, "fk_analysis_snapshot_cluster_member_cluster", fixed = TRUE)
  expect_match(sql, "FOREIGN KEY (`snapshot_id`, `cluster_kind`, `cluster_id`)", fixed = TRUE)
  expect_match(sql, "ON DELETE CASCADE", fixed = TRUE)
})
