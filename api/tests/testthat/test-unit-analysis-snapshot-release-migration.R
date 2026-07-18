# tests/testthat/test-unit-analysis-snapshot-release-migration.R
#
# Migration smoke test for 045_add_analysis_snapshot_release.sql (#573).
#
# Applies migration 045 directly to the test database (mirroring the
# apply_test_async_job_migration() idiom in helper-db.R) and asserts the
# three release tables exist with their key columns. Migration 045 has an
# FK to `user(user_id)`, so the minimal user fixture table is created first
# via ensure_test_user_table(). Because the migration's CREATE TABLE
# statements are guarded with IF NOT EXISTS (DDL auto-commits and cannot be
# rolled back), the test drops the three release tables itself at the end
# so reruns stay idempotent.

analysis_snapshot_release_migration_path <- function() {
  candidates <- c(
    file.path(get_api_dir(), "..", "db", "migrations", "045_add_analysis_snapshot_release.sql"),
    file.path(get_api_dir(), "db", "migrations", "045_add_analysis_snapshot_release.sql")
  )

  for (candidate in candidates) {
    if (file.exists(candidate)) {
      return(candidate)
    }
  }

  candidates[[1]]
}

apply_analysis_snapshot_release_migration <- function(conn) {
  if (!exists("split_sql_statements", mode = "function")) {
    source_api_file("functions/migration-runner.R", local = FALSE, envir = .GlobalEnv)
  }

  migration_path <- analysis_snapshot_release_migration_path()
  if (!file.exists(migration_path)) {
    stop("analysis-snapshot-release migration file is missing: ", migration_path)
  }

  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")
  for (statement in split_sql_statements(sql)) {
    DBI::dbExecute(conn, statement, immediate = TRUE)
  }

  invisible(TRUE)
}

drop_analysis_snapshot_release_tables <- function(conn) {
  # Children first, then the head table (FK ON DELETE CASCADE dependency order).
  for (tbl in c(
    "analysis_snapshot_release_file",
    "analysis_snapshot_release_member",
    "analysis_snapshot_release"
  )) {
    if (DBI::dbExistsTable(conn, tbl)) {
      DBI::dbExecute(conn, paste0("DROP TABLE `", tbl, "`"), immediate = TRUE)
    }
  }
  invisible(TRUE)
}

test_that("migration 045 creates the three analysis-snapshot release tables", {
  skip_if_no_test_db()

  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn))

  ensure_test_user_table(conn)

  # Clean slate: drop any leftovers from a prior interrupted run so the
  # CREATE TABLE IF NOT EXISTS statements actually create fresh tables here.
  drop_analysis_snapshot_release_tables(conn)
  withr::defer(drop_analysis_snapshot_release_tables(conn))

  apply_analysis_snapshot_release_migration(conn)

  expect_true(DBI::dbExistsTable(conn, "analysis_snapshot_release"))
  expect_true(DBI::dbExistsTable(conn, "analysis_snapshot_release_member"))
  expect_true(DBI::dbExistsTable(conn, "analysis_snapshot_release_file"))

  head_cols <- DBI::dbListFields(conn, "analysis_snapshot_release")
  expect_true("content_digest" %in% head_cols)
  expect_true("bundle_gzip" %in% head_cols)
  expect_true("manifest_sha256" %in% head_cols)
  expect_true("bundle_sha256" %in% head_cols)
  expect_true("status" %in% head_cols)
  expect_true("created_by_user_id" %in% head_cols)

  # status is a MySQL ENUM('draft','published').
  status_type <- DBI::dbGetQuery(
    conn,
    "SELECT COLUMN_TYPE FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'analysis_snapshot_release'
       AND COLUMN_NAME = 'status'"
  )$COLUMN_TYPE
  expect_match(status_type, "^enum\\('draft','published'\\)$")

  member_cols <- DBI::dbListFields(conn, "analysis_snapshot_release_member")
  expect_true("release_id" %in% member_cols)
  expect_true("analysis_type" %in% member_cols)
  expect_true("parameter_hash" %in% member_cols)
  expect_true("snapshot_id" %in% member_cols)
  expect_true("payload_hash" %in% member_cols)
  expect_true("role" %in% member_cols)

  file_cols <- DBI::dbListFields(conn, "analysis_snapshot_release_file")
  expect_true("release_id" %in% file_cols)
  expect_true("file_path" %in% file_cols)
  expect_true("content_sha256" %in% file_cols)
  expect_true("content_gzip" %in% file_cols)
})
