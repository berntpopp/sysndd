# test-unit-migration-runner.R
#
# Unit tests for migration runner functions.
# Tests SQL splitting, file listing, and core logic.
# Integration tests with real database are separate.

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/migration-runner.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Load required packages
library(testthat)
library(withr)
library(fs)

# Source the migration runner (suppress logger messages during tests)
suppressMessages({
  source(file.path(api_dir, "functions/migration-runner.R"), local = TRUE)
})

# ============================================================================
# split_sql_statements() Tests
# ============================================================================

describe("split_sql_statements", {
  it("splits simple SQL on semicolon-newline", {
    sql <- "SELECT 1;\nSELECT 2;\n"
    result <- split_sql_statements(sql)
    expect_length(result, 2)
    expect_equal(trimws(result[1]), "SELECT 1")
    expect_equal(trimws(result[2]), "SELECT 2")
  })

  it("handles single statement without trailing newline", {
    sql <- "SELECT 1"
    result <- split_sql_statements(sql)
    expect_length(result, 1)
    expect_equal(trimws(result[1]), "SELECT 1")
  })

  it("filters out empty statements", {
    sql <- "SELECT 1;\n\nSELECT 2;\n"
    result <- split_sql_statements(sql)
    # Should only have 2 non-empty statements
    expect_true(all(nchar(trimws(result)) > 0))
    expect_length(result, 2)
  })

  it("handles DELIMITER for stored procedures", {
    sql <- "DELIMITER //\nCREATE PROCEDURE test() BEGIN SELECT 1; END //\nDELIMITER ;\nCALL test();\n"
    result <- split_sql_statements(sql)
    # Should split on // not ;
    expect_true(any(grepl("CREATE PROCEDURE", result)))
    expect_true(any(grepl("CALL test", result)))
  })

  it("preserves comments in SQL", {
    sql <- "-- Comment\nSELECT 1;\n"
    result <- split_sql_statements(sql)
    expect_true(grepl("-- Comment", result[1]))
  })

  it("handles multi-line CREATE TABLE statement", {
    sql <- "CREATE TABLE test (\n  id INT PRIMARY KEY,\n  name VARCHAR(255)\n);\n"
    result <- split_sql_statements(sql)
    expect_length(result, 1)
    expect_true(grepl("CREATE TABLE", result[1]))
    expect_true(grepl("id INT PRIMARY KEY", result[1]))
  })

  it("handles statement with inline comment after semicolon-newline", {
    # Note: inline comment AFTER semicolon on same line prevents splitting
    # Split happens on semicolon-newline pattern, so comments must follow that pattern
    sql <- "SELECT * FROM users;\n-- get all users\nDELETE FROM logs;\n"
    result <- split_sql_statements(sql)
    expect_length(result, 2)
    expect_true(grepl("SELECT", result[1]))
    expect_true(grepl("DELETE", result[2]))
  })

  it("documents known limitation: inline comment after semicolon", {
    # Known limitation: semicolon followed by text on same line is not split
    # This is by design for the migration use case where statements end with ;\n
    sql <- "SELECT * FROM users; -- get all users\nDELETE FROM logs;\n"
    result <- split_sql_statements(sql)
    # Expected: single statement (entire content) because first ; not followed by \n
    expect_true(grepl("SELECT", result[1]))
    expect_true(grepl("DELETE", result[1]))  # Both in same element
  })

  it("handles complex DELIMITER with double slash", {
    sql <- "DELIMITER //\n\nDROP PROCEDURE IF EXISTS test_proc//\n\nCREATE PROCEDURE test_proc()\nBEGIN\n  SELECT 1;\n  SELECT 2;\nEND//\n\nDELIMITER ;\n"
    result <- split_sql_statements(sql)
    # Should have DROP and CREATE as separate statements
    expect_true(any(grepl("DROP PROCEDURE", result)))
    expect_true(any(grepl("CREATE PROCEDURE", result)))
  })
})

# ============================================================================
# list_migration_files() Tests
# ============================================================================

describe("list_migration_files", {
  it("returns sorted list of SQL files", {
    withr::with_tempdir({
      migrations_dir <- file.path(getwd(), "test_migrations")
      dir.create(migrations_dir, showWarnings = FALSE)

      # Create test files (out of order to test sorting)
      writeLines("SELECT 1;", file.path(migrations_dir, "002_second.sql"))
      writeLines("SELECT 1;", file.path(migrations_dir, "001_first.sql"))
      writeLines("SELECT 1;", file.path(migrations_dir, "003_third.sql"))

      result <- list_migration_files(migrations_dir)

      expect_length(result, 3)
      expect_equal(result[1], "001_first.sql")
      expect_equal(result[2], "002_second.sql")
      expect_equal(result[3], "003_third.sql")
    })
  })

  it("returns empty vector for empty directory", {
    withr::with_tempdir({
      empty_dir <- file.path(getwd(), "empty_migrations")
      dir.create(empty_dir, showWarnings = FALSE)

      result <- list_migration_files(empty_dir)
      expect_length(result, 0)
      expect_true(is.character(result))
    })
  })

  it("ignores non-SQL files", {
    withr::with_tempdir({
      migrations_dir <- file.path(getwd(), "mixed_migrations")
      dir.create(migrations_dir, showWarnings = FALSE)

      writeLines("SELECT 1;", file.path(migrations_dir, "001_valid.sql"))
      writeLines("# README", file.path(migrations_dir, "README.md"))
      writeLines("test", file.path(migrations_dir, "test.txt"))

      result <- list_migration_files(migrations_dir)

      expect_length(result, 1)
      expect_equal(result[1], "001_valid.sql")
    })
  })

  it("returns empty vector for non-existent directory", {
    result <- list_migration_files("/nonexistent/path/that/does/not/exist")
    expect_length(result, 0)
    expect_true(is.character(result))
  })

  it("handles files with similar prefixes correctly", {
    withr::with_tempdir({
      migrations_dir <- file.path(getwd(), "prefix_migrations")
      dir.create(migrations_dir, showWarnings = FALSE)

      writeLines("SELECT 1;", file.path(migrations_dir, "001_init.sql"))
      writeLines("SELECT 1;", file.path(migrations_dir, "010_later.sql"))
      writeLines("SELECT 1;", file.path(migrations_dir, "002_middle.sql"))

      result <- list_migration_files(migrations_dir)

      expect_length(result, 3)
      expect_equal(result[1], "001_init.sql")
      expect_equal(result[2], "002_middle.sql")
      expect_equal(result[3], "010_later.sql")
    })
  })
})

# ============================================================================
# Migration idempotency logic Tests
# ============================================================================

describe("migration idempotency logic", {
  it("setdiff correctly identifies pending migrations", {
    all_files <- c("001_first.sql", "002_second.sql", "003_third.sql")
    applied <- c("001_first.sql")

    pending <- setdiff(all_files, applied)

    expect_length(pending, 2)
    expect_equal(pending, c("002_second.sql", "003_third.sql"))
  })

  it("returns empty when all migrations applied", {
    all_files <- c("001_first.sql", "002_second.sql")
    applied <- c("001_first.sql", "002_second.sql")

    pending <- setdiff(all_files, applied)

    expect_length(pending, 0)
  })

  it("returns all files when none applied", {
    all_files <- c("001_first.sql", "002_second.sql", "003_third.sql")
    applied <- character(0)

    pending <- setdiff(all_files, applied)

    expect_length(pending, 3)
    expect_equal(pending, all_files)
  })

  it("handles out-of-order application correctly", {
    # If somehow migrations were applied out of order
    all_files <- c("001_first.sql", "002_second.sql", "003_third.sql")
    applied <- c("002_second.sql")  # Only middle one applied

    pending <- setdiff(all_files, applied)

    expect_length(pending, 2)
    expect_true("001_first.sql" %in% pending)
    expect_true("003_third.sql" %in% pending)
  })

  it("preserves order of pending migrations", {
    all_files <- c("001_a.sql", "002_b.sql", "003_c.sql", "004_d.sql")
    applied <- c("001_a.sql", "003_c.sql")

    pending <- setdiff(all_files, applied)

    # setdiff preserves order from first argument
    expect_equal(pending[1], "002_b.sql")
    expect_equal(pending[2], "004_d.sql")
  })
})

# ============================================================================
# split_sql_with_custom_delimiter() Tests (internal helper)
# ============================================================================

describe("DELIMITER extraction", {
  it("extracts double-slash delimiter correctly", {
    sql <- "DELIMITER //\nSELECT 1//\nDELIMITER ;\n"
    result <- split_sql_statements(sql)
    # Should parse without error and extract statement
    expect_true(any(grepl("SELECT 1", result)))
  })

  it("handles DELIMITER $$ commonly used in MySQL", {
    sql <- "DELIMITER $$\nCREATE TRIGGER test BEFORE INSERT ON t FOR EACH ROW BEGIN SET NEW.x = 1; END$$\nDELIMITER ;\n"
    result <- split_sql_statements(sql)
    expect_true(any(grepl("CREATE TRIGGER", result)))
  })

  it("handles nested semicolons in stored procedure body", {
    sql <- "DELIMITER //\nCREATE PROCEDURE multi_stmt()\nBEGIN\n  DECLARE x INT;\n  SET x = 1;\n  SELECT x;\nEND//\nDELIMITER ;\n"
    result <- split_sql_statements(sql)
    # The procedure body should remain intact with all semicolons
    proc_stmt <- result[grepl("CREATE PROCEDURE", result)]
    expect_true(grepl("DECLARE x INT", proc_stmt))
    expect_true(grepl("SET x = 1", proc_stmt))
    expect_true(grepl("SELECT x", proc_stmt))
  })
})

# ============================================================================
# Edge cases and error handling Tests
# ============================================================================

describe("edge cases", {
  it("handles empty SQL string", {
    result <- split_sql_statements("")
    expect_length(result, 0)
  })

  it("handles whitespace-only SQL string", {
    result <- split_sql_statements("   \n\n   \t\t\n  ")
    expect_length(result, 0)
  })

  it("handles SQL with only comments", {
    sql <- "-- This is a comment\n-- Another comment\n"
    result <- split_sql_statements(sql)
    # Comments should be preserved but may result in empty after split
    # Behavior depends on implementation - just verify no error
    expect_true(is.character(result))
  })

  it("handles multiple consecutive semicolons", {
    sql <- "SELECT 1;;;\nSELECT 2;\n"
    result <- split_sql_statements(sql)
    # Should filter empty statements
    non_empty <- result[nchar(trimws(result)) > 0]
    expect_true(length(non_empty) >= 1)
  })
})

# ============================================================================
# reconcile_schema_version_renames() Tests
# ============================================================================
# Phase A.A4 rename of 008_hgnc_symbol_lookup.sql -> 018_hgnc_symbol_lookup.sql
# introduced a hazard: on long-lived deployments, schema_version still records
# the file under its old name, so the runner would re-execute the renamed file
# and duplicate rows. `reconcile_schema_version_renames` handles that before
# the pending-migration diff runs. These tests mock DBI to verify behavior in
# each of the four possible states without needing a live database.

describe("MIGRATION_RENAMES", {
  it("is a named list mapping old -> new filenames", {
    expect_true(is.list(MIGRATION_RENAMES))
    expect_true(!is.null(names(MIGRATION_RENAMES)))
    expect_true(all(nzchar(names(MIGRATION_RENAMES))))
    for (nm in names(MIGRATION_RENAMES)) {
      expect_true(is.character(MIGRATION_RENAMES[[nm]]))
      expect_true(nzchar(MIGRATION_RENAMES[[nm]]))
      expect_match(nm, "\\.sql$")
      expect_match(MIGRATION_RENAMES[[nm]], "\\.sql$")
    }
  })

  it("records the A4 rename: 008_hgnc_symbol_lookup -> 018_hgnc_symbol_lookup", {
    expect_equal(
      MIGRATION_RENAMES[["008_hgnc_symbol_lookup.sql"]],
      "018_hgnc_symbol_lookup.sql"
    )
  })
})

describe("reconcile_schema_version_renames", {
  # Helper: build a fake connection that records SELECTs and UPDATEs against
  # a stub schema_version "table" represented as a character vector.
  make_fake_conn <- function(initial_rows) {
    rows_env <- new.env(parent = emptyenv())
    rows_env$rows <- initial_rows
    rows_env$executes <- list()
    structure(
      list(rows_env = rows_env),
      class = c("FakeConn", "DBIConnection")
    )
  }

  fake_dbGetQuery <- function(conn, sql, params = list()) {
    filename <- params[[1]]
    if (filename %in% conn$rows_env$rows) {
      data.frame(filename = filename, stringsAsFactors = FALSE)
    } else {
      data.frame(filename = character(0), stringsAsFactors = FALSE)
    }
  }

  fake_dbExecute <- function(conn, sql, params = list()) {
    conn$rows_env$executes <- c(
      conn$rows_env$executes,
      list(list(sql = sql, params = params))
    )
    if (grepl("UPDATE schema_version SET filename", sql)) {
      new_name <- params[[1]]
      old_name <- params[[2]]
      conn$rows_env$rows <- c(
        setdiff(conn$rows_env$rows, old_name),
        new_name
      )
    } else if (grepl("DELETE FROM schema_version", sql)) {
      old_name <- params[[1]]
      conn$rows_env$rows <- setdiff(conn$rows_env$rows, old_name)
    }
    1L
  }

  fake_list_migration_files <- function(migrations_dir) {
    c(
      "001_initial.sql",
      "002_seed.sql",
      "018_hgnc_symbol_lookup.sql"
    )
  }

  it("rewrites schema_version when old name is present and new name is not", {
    skip_if_not_installed("mockery")
    conn <- make_fake_conn(c("001_initial.sql", "002_seed.sql", "008_hgnc_symbol_lookup.sql"))

    mockery::stub(reconcile_schema_version_renames, "list_migration_files", fake_list_migration_files)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbGetQuery", fake_dbGetQuery)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbExecute", fake_dbExecute)

    result <- reconcile_schema_version_renames(conn = conn, migrations_dir = "db/migrations")

    expect_length(result, 1)
    expect_match(result[1], "008_hgnc_symbol_lookup.sql -> 018_hgnc_symbol_lookup.sql")
    expect_true("018_hgnc_symbol_lookup.sql" %in% conn$rows_env$rows)
    expect_false("008_hgnc_symbol_lookup.sql" %in% conn$rows_env$rows)
    expect_length(conn$rows_env$executes, 1)
    expect_match(conn$rows_env$executes[[1]]$sql, "UPDATE schema_version")
  })

  it("is a no-op when the new name is already recorded (idempotent)", {
    skip_if_not_installed("mockery")
    conn <- make_fake_conn(c("001_initial.sql", "018_hgnc_symbol_lookup.sql"))

    mockery::stub(reconcile_schema_version_renames, "list_migration_files", fake_list_migration_files)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbGetQuery", fake_dbGetQuery)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbExecute", fake_dbExecute)

    result <- reconcile_schema_version_renames(conn = conn, migrations_dir = "db/migrations")

    expect_length(result, 0)
    expect_length(conn$rows_env$executes, 0)
    expect_true("018_hgnc_symbol_lookup.sql" %in% conn$rows_env$rows)
  })

  it("drops stale old row when both old and new are recorded (dedup)", {
    skip_if_not_installed("mockery")
    conn <- make_fake_conn(c(
      "001_initial.sql",
      "008_hgnc_symbol_lookup.sql",
      "018_hgnc_symbol_lookup.sql"
    ))

    mockery::stub(reconcile_schema_version_renames, "list_migration_files", fake_list_migration_files)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbGetQuery", fake_dbGetQuery)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbExecute", fake_dbExecute)

    result <- reconcile_schema_version_renames(conn = conn, migrations_dir = "db/migrations")

    expect_length(result, 1)
    expect_match(result[1], "dedup")
    expect_false("008_hgnc_symbol_lookup.sql" %in% conn$rows_env$rows)
    expect_true("018_hgnc_symbol_lookup.sql" %in% conn$rows_env$rows)
    expect_length(conn$rows_env$executes, 1)
    expect_match(conn$rows_env$executes[[1]]$sql, "DELETE FROM schema_version")
  })

  it("is a no-op when neither name is recorded (fresh DB)", {
    skip_if_not_installed("mockery")
    conn <- make_fake_conn(c("001_initial.sql"))

    mockery::stub(reconcile_schema_version_renames, "list_migration_files", fake_list_migration_files)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbGetQuery", fake_dbGetQuery)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbExecute", fake_dbExecute)

    result <- reconcile_schema_version_renames(conn = conn, migrations_dir = "db/migrations")

    expect_length(result, 0)
    expect_length(conn$rows_env$executes, 0)
  })

  it("skips the rename when the new file is not yet on disk", {
    skip_if_not_installed("mockery")
    conn <- make_fake_conn(c("008_hgnc_symbol_lookup.sql"))

    fake_files_without_new <- function(migrations_dir) {
      c("001_initial.sql", "008_hgnc_symbol_lookup.sql")
    }

    mockery::stub(reconcile_schema_version_renames, "list_migration_files", fake_files_without_new)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbGetQuery", fake_dbGetQuery)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbExecute", fake_dbExecute)

    result <- reconcile_schema_version_renames(conn = conn, migrations_dir = "db/migrations")

    expect_length(result, 0)
    expect_length(conn$rows_env$executes, 0)
    expect_true("008_hgnc_symbol_lookup.sql" %in% conn$rows_env$rows)
  })

  # Fail-fast tests — Risk 5 mitigation. The reconciliation must crash
  # startup on DB errors rather than silently skipping, otherwise the
  # renamed migration would re-run in run_migrations()' main loop and
  # duplicate non-idempotent rows. Copilot flagged the original swallowing
  # tryCatch wrappers on PR #228; these tests lock in the corrected behavior.

  it("fail-fast: propagates dbGetQuery errors (does not silently skip)", {
    skip_if_not_installed("mockery")
    conn <- make_fake_conn(c("008_hgnc_symbol_lookup.sql"))

    raising_dbGetQuery <- function(conn, sql, params = list()) {
      stop("simulated: connection broken during schema_version SELECT")
    }

    mockery::stub(reconcile_schema_version_renames, "list_migration_files", fake_list_migration_files)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbGetQuery", raising_dbGetQuery)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbExecute", fake_dbExecute)

    expect_error(
      reconcile_schema_version_renames(conn = conn, migrations_dir = "db/migrations"),
      "simulated: connection broken during schema_version SELECT"
    )
    # No UPDATE/DELETE should have been attempted before the SELECT crash.
    expect_length(conn$rows_env$executes, 0)
  })

  it("fail-fast: propagates dbExecute errors from UPDATE (does not silently skip)", {
    skip_if_not_installed("mockery")
    conn <- make_fake_conn(c("001_initial.sql", "008_hgnc_symbol_lookup.sql"))

    raising_dbExecute <- function(conn, sql, params = list()) {
      stop("simulated: UPDATE rejected by constraint")
    }

    mockery::stub(reconcile_schema_version_renames, "list_migration_files", fake_list_migration_files)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbGetQuery", fake_dbGetQuery)
    mockery::stub(reconcile_schema_version_renames, "DBI::dbExecute", raising_dbExecute)

    expect_error(
      reconcile_schema_version_renames(conn = conn, migrations_dir = "db/migrations"),
      "simulated: UPDATE rejected by constraint"
    )
    # The fake row was not rewritten (the raising stub doesn't mutate rows).
    expect_true("008_hgnc_symbol_lookup.sql" %in% conn$rows_env$rows)
    expect_false("018_hgnc_symbol_lookup.sql" %in% conn$rows_env$rows)
  })
})
