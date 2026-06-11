# tests/testthat/test-unit-db-version.R
#
# Unit tests for the database-version surface (issue #22).
#
# These are pure-logic tests: db-version.R is sourced into a local environment
# and its DB + logging dependencies are stubbed in that same scope, so the
# tests run without RMariaDB or a live database. The integration behaviour of
# the /api/version `database` block is covered by the HTTP probes in
# test-integration-version.R (which require a running API in CI).

# Stub logging helpers used by db-version.R (no-ops in tests).
log_warn <- function(...) invisible(NULL)
log_info <- function(...) invisible(NULL)
log_debug <- function(...) invisible(NULL)

# Mutable holders so individual tests can swap the DB helper behaviour.
.dbv_query_fn <- NULL
.dbv_statement_fn <- NULL

db_execute_query <- function(sql, params = list(), conn = NULL) {
  .dbv_query_fn(sql, params, conn)
}
db_execute_statement <- function(sql, params = list(), conn = NULL) {
  .dbv_statement_fn(sql, params, conn)
}

# Source the unit under test into the global environment. Its name lookups for
# db_execute_query / db_execute_statement / log_* resolve to the stubs we assign
# into the global environment below.
source_api_file("functions/db-version.R", local = FALSE, envir = globalenv())

# Promote the stubs into the global environment so the sourced functions (whose
# enclosing environment is globalenv) resolve them.
assign("log_warn", log_warn, envir = globalenv())
assign("log_info", log_info, envir = globalenv())
assign("log_debug", log_debug, envir = globalenv())
assign("db_execute_query", db_execute_query, envir = globalenv())
assign("db_execute_statement", db_execute_statement, envir = globalenv())
assign(".dbv_query_fn", NULL, envir = globalenv())
assign(".dbv_statement_fn", NULL, envir = globalenv())

# ---------------------------------------------------------------------------
# db_version_nullify
# ---------------------------------------------------------------------------

test_that("db_version_nullify maps empty/NA scalars to NULL", {
  expect_null(db_version_nullify(NA_character_))
  expect_null(db_version_nullify(""))
  expect_null(db_version_nullify(character(0)))
  expect_identical(db_version_nullify("1.0.0"), "1.0.0")
  expect_identical(db_version_nullify(c("a", "b")), "a")
})

# ---------------------------------------------------------------------------
# db_version_get
# ---------------------------------------------------------------------------

test_that("db_version_get returns a normalized record when a row exists", {
  .dbv_query_fn <<- function(sql, params, conn) {
    tibble::tibble(
      db_version = "1.2.3",
      db_commit = "abc1234",
      description = "release note",
      updated_at = "2026-06-11 10:00:00"
    )
  }

  res <- db_version_get()

  expect_identical(res$version, "1.2.3")
  expect_identical(res$commit, "abc1234")
  expect_identical(res$description, "release note")
  expect_identical(res$updated_at, "2026-06-11 10:00:00")
  expect_true(res$available)
})

test_that("db_version_get falls back when no row is present", {
  .dbv_query_fn <<- function(sql, params, conn) tibble::tibble()

  res <- db_version_get()

  expect_identical(res$version, "unknown")
  expect_identical(res$commit, "unknown")
  expect_null(res$description)
  expect_null(res$updated_at)
  expect_false(res$available)
})

test_that("db_version_get never throws on DB error and reports unavailable", {
  .dbv_query_fn <<- function(sql, params, conn) stop("connection refused")

  res <- expect_no_error(db_version_get())

  expect_identical(res$version, "unknown")
  expect_false(res$available)
})

test_that("db_version_get nullifies empty description/updated_at", {
  .dbv_query_fn <<- function(sql, params, conn) {
    tibble::tibble(
      db_version = "1.0.0",
      db_commit = "unknown",
      description = NA_character_,
      updated_at = NA_character_
    )
  }

  res <- db_version_get()

  expect_identical(res$version, "1.0.0")
  expect_null(res$description)
  expect_null(res$updated_at)
  expect_true(res$available)
})

# ---------------------------------------------------------------------------
# db_version_sync_from_env
# ---------------------------------------------------------------------------

test_that("db_version_sync_from_env is a no-op when no env vars are set", {
  withr::with_envvar(c(DB_VERSION = "", DB_COMMIT = ""), {
    called <- FALSE
    .dbv_statement_fn <<- function(sql, params, conn) {
      called <<- TRUE
      1L
    }
    result <- db_version_sync_from_env()
    expect_false(result)
    expect_false(called)
  })
})

test_that("db_version_sync_from_env updates only commit when only DB_COMMIT set", {
  withr::with_envvar(c(DB_VERSION = "", DB_COMMIT = "deadbee"), {
    captured <- list()
    .dbv_statement_fn <<- function(sql, params, conn) {
      captured$sql <<- sql
      captured$params <<- params
      1L
    }
    result <- db_version_sync_from_env()
    expect_true(result)
    expect_match(captured$sql, "db_commit = ?", fixed = TRUE)
    expect_false(grepl("db_version = ?", captured$sql, fixed = TRUE))
    expect_match(captured$sql, "WHERE id = 1", fixed = TRUE)
    expect_identical(captured$params, list("deadbee"))
  })
})

test_that("db_version_sync_from_env updates both version and commit when set", {
  withr::with_envvar(c(DB_VERSION = "2.0.0", DB_COMMIT = "cafe123"), {
    captured <- list()
    .dbv_statement_fn <<- function(sql, params, conn) {
      captured$sql <<- sql
      captured$params <<- params
      1L
    }
    result <- db_version_sync_from_env()
    expect_true(result)
    expect_match(captured$sql, "db_version = ?", fixed = TRUE)
    expect_match(captured$sql, "db_commit = ?", fixed = TRUE)
    expect_identical(captured$params, list("2.0.0", "cafe123"))
  })
})

test_that("db_version_sync_from_env returns FALSE when no row was updated", {
  withr::with_envvar(c(DB_VERSION = "2.0.0", DB_COMMIT = ""), {
    .dbv_statement_fn <<- function(sql, params, conn) 0L
    expect_false(db_version_sync_from_env())
  })
})

test_that("db_version_sync_from_env never throws on DB error", {
  withr::with_envvar(c(DB_VERSION = "2.0.0", DB_COMMIT = ""), {
    .dbv_statement_fn <<- function(sql, params, conn) stop("db down")
    expect_false(expect_no_error(db_version_sync_from_env()))
  })
})

# ---------------------------------------------------------------------------
# Migration contract
# ---------------------------------------------------------------------------

test_that("migration 028 creates the db_version table and seeds a semver row", {
  migration_path <- file.path(
    get_api_dir(), "..", "db", "migrations", "028_add_db_version.sql"
  )
  expect_true(file.exists(migration_path))
  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")

  expect_match(sql, "CREATE TABLE IF NOT EXISTS `db_version`", fixed = TRUE)
  expect_match(sql, "`db_version`", fixed = TRUE)
  expect_match(sql, "`db_commit`", fixed = TRUE)
  expect_match(sql, "INSERT IGNORE INTO `db_version`", fixed = TRUE)
  # Seeded value must be a semantic version.
  expect_match(sql, "'[0-9]+\\.[0-9]+\\.[0-9]+'")
})
