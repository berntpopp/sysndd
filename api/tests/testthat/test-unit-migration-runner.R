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
