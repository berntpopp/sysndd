analysis_snapshot_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(analysis_snapshot_test_wd), testthat::teardown_env())

test_that("migration manifest tracks the latest migration", {
  source(file.path("functions", "migration-manifest.R"), local = TRUE)

  expect_equal(EXPECTED_LATEST_MIGRATION, "027_add_pubtator_gene_enrichment.sql")
  expect_equal(EXPECTED_MIGRATION_COUNT, 28L)
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
