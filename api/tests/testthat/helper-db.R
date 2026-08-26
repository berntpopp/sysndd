# tests/testthat/helper-db.R
# Database connection helpers for tests
#
# These functions provide isolated test database access with proper cleanup.
# Uses config::get() to load sysndd_db_test configuration.

#' Get test database connection
#'
#' Creates a DBI connection to the test database.
#' Caller is responsible for disconnecting.
#'
#' @return DBI connection to test database
#' @examples
#' con <- get_test_db_connection()
#' # ... use connection ...
#' DBI::dbDisconnect(con)
get_test_db_connection <- function() {
  # Use get_test_config to find config.yml robustly
  test_config <- get_test_config()

  if (is.null(test_config)) {
    stop("sysndd_db_test configuration not found in config.yml")
  }

  DBI::dbConnect(
    RMariaDB::MariaDB(),
    dbname = test_config$dbname,
    host = test_config$host,
    user = test_config$user,
    password = test_config$password,
    port = as.integer(test_config$port)
  )
}


#' Check if test database is available
#'
#' Attempts to connect to test database and returns TRUE/FALSE.
#' Used internally by skip_if_no_test_db().
#'
#' @return Logical indicating if test DB is available
test_db_available <- function() {
  tryCatch({
    con <- get_test_db_connection()
    DBI::dbDisconnect(con)
    TRUE
  }, error = function(e) {
    FALSE
  })
}


#' Skip test if test database unavailable
#'
#' Call at the start of integration tests that require database.
#' Provides informative skip message.
#'
#' @examples
#' test_that("database query works", {
#'   skip_if_no_test_db()
#'   # ... test code ...
#' })
skip_if_no_test_db <- function() {
  if (!test_db_available()) {
    testthat::skip("Test database (sysndd_db_test) not available")
  }
}


#' Ensure the minimal user table required by schema-level test fixtures exists
#'
#' CI starts with an empty test database. Some integration fixtures only need the
#' user primary key as a foreign-key target, so they create this minimal table
#' instead of loading the full application schema.
#'
#' @param conn DBI connection to the test database
#' @return Invisibly TRUE
ensure_test_user_table <- function(conn) {
  if (DBI::dbExistsTable(conn, "user")) {
    return(invisible(TRUE))
  }

  DBI::dbExecute(
    conn,
    paste(
      "CREATE TABLE user (",
      "user_id INT NOT NULL PRIMARY KEY,",
      "user_name VARCHAR(255) NULL",
      ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
      sep = " "
    ),
    immediate = TRUE
  )

  invisible(TRUE)
}


test_async_job_migration_path <- function() {
  candidates <- c(
    file.path(get_api_dir(), "..", "db", "migrations", "020_add_async_job_schema.sql"),
    file.path(get_api_dir(), "db", "migrations", "020_add_async_job_schema.sql")
  )

  for (candidate in candidates) {
    if (file.exists(candidate)) {
      return(candidate)
    }
  }

  candidates[[1]]
}


apply_test_async_job_migration <- function(conn) {
  if (!exists("split_sql_statements", mode = "function")) {
    source_api_file("functions/migration-runner.R", local = FALSE, envir = .GlobalEnv)
  }

  migration_path <- test_async_job_migration_path()
  if (!file.exists(migration_path)) {
    stop("async-job migration file is missing: ", migration_path)
  }

  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")
  for (statement in split_sql_statements(sql)) {
    DBI::dbExecute(conn, statement, immediate = TRUE)
  }

  invisible(TRUE)
}


#' Ensure the durable async job schema required by async job tests exists
#'
#' @param conn DBI connection to the test database
#' @param reset Drop and recreate existing async-job tables
#' `reset = TRUE` DROPs both tables and re-applies their migration. That is a
#' complete DDL restore, not the destructive-teardown class fixed elsewhere in
#' #612: migration `020_add_async_job_schema.sql` is the ONLY migration that
#' touches `async_jobs` / `async_job_events` (verified by grepping the whole
#' `db/migrations` directory), so re-applying it reproduces their current shape
#' exactly. If a later migration ever alters either table, this must replay that
#' one too -- exactly the gap that made restoring migration 047 alone leave
#' `variation_ontology_evidence` without 049's `origin_review_id`.
#'
#' Queued and historical job ROWS are lost, which is fine on a test database
#' where they are test artifacts.
#'
#' @return Invisibly TRUE
ensure_test_async_job_schema <- function(conn, reset = FALSE) {
  ensure_test_user_table(conn)

  has_jobs <- DBI::dbExistsTable(conn, "async_jobs")
  has_events <- DBI::dbExistsTable(conn, "async_job_events")
  if (!reset && has_jobs && has_events) {
    return(invisible(TRUE))
  }

  if (has_events) {
    DBI::dbExecute(conn, "DROP TABLE async_job_events", immediate = TRUE)
  }
  if (has_jobs) {
    DBI::dbExecute(conn, "DROP TABLE async_jobs", immediate = TRUE)
  }

  apply_test_async_job_migration(conn)

  invisible(TRUE)
}


test_analysis_snapshot_release_migration_path <- function() {
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


apply_test_analysis_snapshot_release_migration <- function(conn) {
  if (!exists("split_sql_statements", mode = "function")) {
    source_api_file("functions/migration-runner.R", local = FALSE, envir = .GlobalEnv)
  }

  migration_path <- test_analysis_snapshot_release_migration_path()
  if (!file.exists(migration_path)) {
    stop("analysis-snapshot-release migration file is missing: ", migration_path)
  }

  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")
  for (statement in split_sql_statements(sql)) {
    DBI::dbExecute(conn, statement, immediate = TRUE)
  }

  invisible(TRUE)
}


#' Ensure the analysis-snapshot RELEASE schema (migration 045) exists
#'
#' Idempotent: migration 045's `CREATE TABLE IF NOT EXISTS` statements are a
#' no-op when the three release tables already exist. `analysis_snapshot_release`
#' has an FK to `user(user_id)`, so the minimal user fixture table is ensured
#' first. Call this on its OWN plain connection, separate from (and before)
#' any `with_test_db_transaction()` block — DDL auto-commits and cannot be
#' rolled back, so mixing it into a transactional test connection would break
#' isolation (see the `with_test_db_transaction()` docs above).
#'
#' @param conn DBI connection to the test database
#' @return Invisibly TRUE
ensure_test_release_schema <- function(conn) {
  ensure_test_user_table(conn)
  apply_test_analysis_snapshot_release_migration(conn)
  invisible(TRUE)
}


test_analysis_snapshot_manifest_migration_path <- function() {
  candidates <- c(
    file.path(get_api_dir(), "..", "db", "migrations", "024_add_public_analysis_snapshots.sql"),
    file.path(get_api_dir(), "db", "migrations", "024_add_public_analysis_snapshots.sql")
  )

  for (candidate in candidates) {
    if (file.exists(candidate)) {
      return(candidate)
    }
  }

  candidates[[1]]
}


apply_test_analysis_snapshot_manifest_migration <- function(conn) {
  if (!exists("split_sql_statements", mode = "function")) {
    source_api_file("functions/migration-runner.R", local = FALSE, envir = .GlobalEnv)
  }

  migration_path <- test_analysis_snapshot_manifest_migration_path()
  if (!file.exists(migration_path)) {
    stop("public-analysis-snapshot migration file is missing: ", migration_path)
  }

  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")
  for (statement in split_sql_statements(sql)) {
    DBI::dbExecute(conn, statement, immediate = TRUE)
  }

  invisible(TRUE)
}


#' Ensure the public analysis-snapshot manifest schema (migration 024) exists
#'
#' Idempotent (`CREATE TABLE IF NOT EXISTS`); `analysis_snapshot_manifest` has
#' no external FK dependencies (its child tables reference it, not the other
#' way around), so no fixture table is required first. Call this on its OWN
#' plain connection, separate from (and before) any `with_test_db_transaction()`
#' block -- DDL auto-commits, mirroring `ensure_test_release_schema()` above.
#'
#' @param conn DBI connection to the test database
#' @return Invisibly TRUE
ensure_test_analysis_snapshot_manifest_schema <- function(conn) {
  apply_test_analysis_snapshot_manifest_migration(conn)
  invisible(TRUE)
}


#' Run code with test database transaction (auto-rollback)
#'
#' Wraps code in a transaction that is always rolled back,
#' ensuring tests don't leave data in the database.
#'
#' @param code Code block to execute within transaction
#' @return Result of code block
#'
#' @examples
#' test_that("entity creation works", {
#'   with_test_db_transaction({
#'     con <- getOption(".test_db_con")
#'     # ... insert data ...
#'     # Transaction will be rolled back after test
#'   })
#' })
with_test_db_transaction <- function(code) {
  skip_if_no_test_db()

  con <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(con))

  DBI::dbBegin(con)
  withr::defer(DBI::dbRollback(con))

  # Make connection available to code block
  withr::local_options(list(.test_db_con = con))

  force(code)
}


#' Get test configuration value
#'
#' Helper to access test config values (secret, etc.)
#' Falls back to environment variables in CI when config.yml is unavailable.
#'
#' @param key Configuration key to retrieve
#' @return Configuration value or full config list
get_test_config <- function(key = NULL) {

  # First check if running in CI with environment variables set
  # This is the preferred method in GitHub Actions
  if (Sys.getenv("MYSQL_HOST", "") != "") {
    # Build config from environment variables (CI mode)
    config <- list(
      dbtype = "mysql",
      dbname = Sys.getenv("MYSQL_DATABASE", "sysndd_test"),
      user = Sys.getenv("MYSQL_USER", "test"),
      password = Sys.getenv("MYSQL_PASSWORD", "test"),
      host = Sys.getenv("MYSQL_HOST", "127.0.0.1"),
      port = Sys.getenv("MYSQL_PORT", "3306"),
      # Defaults for other values needed by tests
      secret = Sys.getenv("TEST_SECRET", "test-secret-for-ci"),
      salt = Sys.getenv("TEST_SALT", "test-salt")
    )

    if (is.null(key)) {
      return(config)
    }
    return(config[[key]])
  }

  # Try multiple paths to find config.yml
  # testthat changes working directory during tests, so we need robust path handling
  possible_paths <- c(
    "config.yml",                          # Current directory
    "../config.yml",                       # Parent directory
    "../../config.yml",                    # Two levels up (from tests/testthat/)
    file.path(getwd(), "config.yml"),     # Explicit current dir
    file.path(dirname(getwd()), "config.yml"),  # Explicit parent
    # Use test_path to get path relative to tests/testthat/
    if (exists("test_path", mode = "function")) {
      tryCatch(test_path("..", "..", "config.yml"), error = function(e) NULL)
    } else NULL
  )

  # Filter out NULL values
  possible_paths <- possible_paths[!vapply(possible_paths, is.null, logical(1))]

  config_path <- NULL
  for (path in possible_paths) {
    if (!is.null(path) && file.exists(path)) {
      config_path <- path
      break
    }
  }

  if (is.null(config_path)) {
    stop("config.yml not found and MYSQL_HOST env not set. ",
         "Tried paths: ", paste(possible_paths, collapse = ", "))
  }

  config <- config::get("sysndd_db_test", file = config_path)

  if (is.null(key)) {
    return(config)
  }

  config[[key]]
}


#' Fetch LAST_INSERT_ID() as a plain R integer
#'
#' `LAST_INSERT_ID()` is a MySQL BIGINT, and RMariaDB returns a BIGINT as a
#' `bit64::integer64` -- a double whose storage carries an int64 BIT PATTERN,
#' not the numeric value. Interpolating that into a fixture statement with
#' `sprintf("%d", id)` therefore aborts with
#'
#'   invalid format '%d'; use format %f, %e, %g or %a for numeric objects
#'
#' because the double is a denormal, not a whole number. The value 0 happens to
#' work (bit pattern 0 IS the double 0), which is why a fresh connection looks
#' fine and only a real inserted row fails.
#'
#' This was invisible until #612 gave the test database a real schema: with no
#' tables the seeding tests skipped, so the id was never fetched. Coerce once,
#' at the source, so every `%d` call site in a fixture stays correct.
#'
#' Only valid for a signed-`INT` key, which is every id this suite inserts.
#' `as.integer()` would return `NA_integer_` (with a warning) for a value above
#' `2^31 - 1`, so fail loudly instead: a fixture that silently binds NA as a
#' foreign key is the kind of defect this helper exists to stop.
#'
#' @param conn DBI connection that just performed the INSERT.
#' @param id_column Name to alias the id to (kept for call-site readability).
#' @return Length-1 plain `integer`.
test_db_last_insert_id <- function(conn, id_column = "id") {
  raw_id <- DBI::dbGetQuery(
    conn,
    sprintf("SELECT LAST_INSERT_ID() AS %s", id_column)
  )[[id_column]][[1]]

  id <- suppressWarnings(as.integer(as.character(raw_id)))
  if (length(id) != 1L || is.na(id)) {
    stop(
      "test_db_last_insert_id(): LAST_INSERT_ID() did not yield a plain integer ",
      "(got '", as.character(raw_id), "'). A value beyond a signed INT cannot be ",
      "used as a fixture id.",
      call. = FALSE
    )
  }
  id
}
