# functions/migration-runner.R
#
# Database migration runner for SysNDD API.
# Executes SQL migrations sequentially with state tracking.
#
# Key features:
# - Tracks applied migrations in schema_version table
# - Idempotent: safe to run multiple times
# - Handles DELIMITER commands for stored procedures
# - Stops on first error (fail-fast)
# - Uses pool connection management like db-helpers.R
#
# Usage:
#   source("functions/migration-runner.R")
#   run_migrations()  # Uses global pool
#   run_migrations(conn = my_conn)  # Uses provided connection

library(DBI)
library(pool)
library(logger)
library(fs)

#' Ensure schema_version table exists
#'
#' Creates the tracking table if it does not exist. The table stores
#' filenames and timestamps of applied migrations.
#'
#' @param conn Optional database connection or pool object. If NULL, uses global pool.
#'
#' @return Invisible NULL (side effect: table created if needed)
#'
#' @details
#' - Uses CREATE TABLE IF NOT EXISTS for idempotency
#' - Table schema: filename (PK), applied_at (timestamp), success (boolean)
#' - Uses DBI::dbExecute with immediate = TRUE for DDL execution
#'
#' @export
ensure_schema_version_table <- function(conn = NULL) {
  log_debug("Ensuring schema_version table exists")

  # Determine connection: use provided conn or checkout from global pool

use_pool <- if (is.null(conn)) pool else conn
  is_pool_obj <- inherits(use_pool, "Pool")

  if (is_pool_obj) {
    use_conn <- pool::poolCheckout(use_pool)
    on.exit(pool::poolReturn(use_conn), add = TRUE)
  } else {
    use_conn <- use_pool
  }

  sql <- "
    CREATE TABLE IF NOT EXISTS schema_version (
      filename VARCHAR(255) PRIMARY KEY,
      applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      success BOOLEAN DEFAULT TRUE
    )
  "

  tryCatch({
    DBI::dbExecute(use_conn, sql, immediate = TRUE)
    log_debug("schema_version table ready")
  }, error = function(e) {
    log_error("Failed to create schema_version table: {e$message}")
    stop(e)
  })

  invisible(NULL)
}

#' List migration files sorted by numeric prefix
#'
#' Scans the migrations directory for SQL files and returns them
#' sorted by filename (001, 002, etc. naturally sort correctly).
#'
#' @param migrations_dir Path to migrations directory. Default: "db/migrations"
#'
#' @return Character vector of filenames (not full paths), sorted alphabetically
#'
#' @details
#' - Uses fs::dir_ls() to list files with .sql extension
#' - Returns just filenames (basename), not full paths
#' - Sort order relies on consistent numeric prefix convention (NNN_name.sql)
#'
#' @export
list_migration_files <- function(migrations_dir = "db/migrations") {
  log_debug("Listing migration files from: {migrations_dir}")

  if (!fs::dir_exists(migrations_dir)) {
    log_warn("Migrations directory does not exist: {migrations_dir}")
    return(character(0))
  }

  files <- fs::dir_ls(migrations_dir, glob = "*.sql", type = "file")

  if (length(files) == 0) {
    log_debug("No migration files found")
    return(character(0))
  }

  # Extract basenames and sort (NNN_ prefix ensures correct order)
  basenames <- basename(files)
  sorted_files <- sort(basenames)

  log_debug("Found {length(sorted_files)} migration files")
  return(sorted_files)
}

#' Get list of already-applied migrations
#'
#' Queries the schema_version table to retrieve filenames of
#' successfully applied migrations.
#'
#' @param conn Optional database connection or pool object. If NULL, uses global pool.
#'
#' @return Character vector of filenames (empty vector if none applied)
#'
#' @details
#' - Queries schema_version WHERE success = TRUE
#' - Returns ordered by filename for consistent comparison
#' - Returns empty character vector if table is empty
#'
#' @export
get_applied_migrations <- function(conn = NULL) {
  log_debug("Getting list of applied migrations")

  # Determine connection: use provided conn or checkout from global pool
  use_pool <- if (is.null(conn)) pool else conn
  is_pool_obj <- inherits(use_pool, "Pool")

  if (is_pool_obj) {
    use_conn <- pool::poolCheckout(use_pool)
    on.exit(pool::poolReturn(use_conn), add = TRUE)
  } else {
    use_conn <- use_pool
  }

  sql <- "SELECT filename FROM schema_version WHERE success = TRUE ORDER BY filename"

  tryCatch({
    result <- DBI::dbGetQuery(use_conn, sql)
    filenames <- result$filename
    if (is.null(filenames)) {
      filenames <- character(0)
    }
    log_debug("Found {length(filenames)} applied migrations")
    return(filenames)
  }, error = function(e) {
    # Table might not exist yet (first run)
    log_debug("Could not query schema_version: {e$message}")
    return(character(0))
  })
}

#' Record a successful migration
#'
#' Inserts a record into schema_version to track that a migration
#' was successfully applied.
#'
#' @param filename The migration filename (basename only)
#' @param conn Optional database connection or pool object. If NULL, uses global pool.
#'
#' @return Invisible NULL (side effect: row inserted)
#'
#' @details
#' - Uses parameterized INSERT to prevent SQL injection
#' - Sets success = TRUE (only successful migrations are recorded)
#' - applied_at defaults to CURRENT_TIMESTAMP
#'
#' @export
record_migration <- function(filename, conn = NULL) {
  log_debug("Recording migration: {filename}")

  # Determine connection: use provided conn or checkout from global pool
  use_pool <- if (is.null(conn)) pool else conn
  is_pool_obj <- inherits(use_pool, "Pool")

  if (is_pool_obj) {
    use_conn <- pool::poolCheckout(use_pool)
    on.exit(pool::poolReturn(use_conn), add = TRUE)
  } else {
    use_conn <- use_pool
  }

  sql <- "INSERT INTO schema_version (filename, success) VALUES (?, TRUE)"

  tryCatch({
    DBI::dbExecute(use_conn, sql, params = list(filename))
    log_debug("Migration recorded: {filename}")
  }, error = function(e) {
    log_error("Failed to record migration {filename}: {e$message}")
    stop(e)
  })

  invisible(NULL)
}

#' Acquire MySQL advisory lock for migration coordination
#'
#' Uses MySQL GET_LOCK() to coordinate migrations across multiple API workers.
#' Only one worker can hold the lock at a time; others wait until timeout.
#'
#' @param conn Database connection or pool object
#' @param lock_name Name of the advisory lock. Default: "sysndd_migration"
#' @param timeout Timeout in seconds to wait for lock. Default: 30
#'
#' @return TRUE on success, otherwise stops with error
#'
#' @details
#' - MySQL GET_LOCK returns: 1 = acquired, 0 = timeout, NULL = error
#' - Lock is automatically released when connection closes
#' - Locks are per-connection, not per-thread
#' - Safe for multi-worker coordination (first worker applies, others wait)
#'
#' @export
acquire_migration_lock <- function(conn, lock_name = "sysndd_migration", timeout = 30) {
  log_debug("Attempting to acquire migration lock: {lock_name} (timeout: {timeout}s)")

  # Determine connection: use provided conn or checkout from global pool
  use_pool <- if (is.null(conn)) pool else conn
  is_pool_obj <- inherits(use_pool, "Pool")

  if (is_pool_obj) {
    use_conn <- pool::poolCheckout(use_pool)
    on.exit(pool::poolReturn(use_conn), add = TRUE)
  } else {
    use_conn <- use_pool
  }

  sql <- sprintf("SELECT GET_LOCK('%s', %d) AS acquired", lock_name, timeout)

  tryCatch({
    result <- DBI::dbGetQuery(use_conn, sql)

    if (is.na(result$acquired) || is.null(result$acquired)) {
      log_error("Migration lock acquisition failed: database error")
      stop(sprintf("Migration lock acquisition failed: database error"))
    } else if (result$acquired == 0) {
      log_error("Migration lock acquisition timed out after {timeout} seconds")
      stop(sprintf("Migration lock acquisition timed out after %d seconds", timeout))
    } else if (result$acquired == 1) {
      log_info("Acquired migration lock '{lock_name}'")
      return(TRUE)
    } else {
      log_error("Migration lock acquisition returned unexpected value: {result$acquired}")
      stop(sprintf("Migration lock acquisition returned unexpected value: %s", result$acquired))
    }
  }, error = function(e) {
    log_error("Failed to acquire migration lock: {e$message}")
    stop(e)
  })
}

#' Release MySQL advisory lock
#'
#' Releases the migration advisory lock acquired by acquire_migration_lock().
#' Safe to call even if lock is not held (returns FALSE but doesn't error).
#'
#' @param conn Database connection or pool object
#' @param lock_name Name of the advisory lock. Default: "sysndd_migration"
#'
#' @return TRUE if lock was held and released, FALSE if not held
#'
#' @details
#' - MySQL RELEASE_LOCK returns: 1 = released, 0 = not held, NULL = error
#' - Logs release but doesn't error on "not held" case
#' - Lock is automatically released when connection closes anyway
#'
#' @export
release_migration_lock <- function(conn, lock_name = "sysndd_migration") {
  log_debug("Releasing migration lock: {lock_name}")

  # Determine connection: use provided conn or checkout from global pool
  use_pool <- if (is.null(conn)) pool else conn
  is_pool_obj <- inherits(use_pool, "Pool")

  if (is_pool_obj) {
    use_conn <- pool::poolCheckout(use_pool)
    on.exit(pool::poolReturn(use_conn), add = TRUE)
  } else {
    use_conn <- use_pool
  }

  sql <- sprintf("SELECT RELEASE_LOCK('%s') AS released", lock_name)

  tryCatch({
    result <- DBI::dbGetQuery(use_conn, sql)

    if (result$released == 1) {
      log_info("Released migration lock '{lock_name}'")
      return(TRUE)
    } else {
      log_debug("Migration lock '{lock_name}' was not held")
      return(FALSE)
    }
  }, error = function(e) {
    log_warn("Failed to release migration lock: {e$message}")
    return(FALSE)
  })
}

#' Split SQL content into executable statements
#'
#' Parses SQL file content and splits it into individual statements.
#' Handles DELIMITER commands used for stored procedure definitions.
#'
#' @param sql_content Character string containing SQL file content
#'
#' @return Character vector of individual SQL statements (empty statements filtered)
#'
#' @details
#' - Detects DELIMITER commands (e.g., "DELIMITER //")
#' - If DELIMITER found: extracts custom delimiter, strips DELIMITER lines,
#'   splits on custom delimiter
#' - Otherwise: splits on semicolon followed by newline or end of string
#' - Filters out empty statements
#'
#' @export
split_sql_statements <- function(sql_content) {
  log_debug("Splitting SQL content into statements")

  # Check for DELIMITER command (used for stored procedures)
  if (grepl("DELIMITER\\s+", sql_content, ignore.case = TRUE)) {
    log_debug("DELIMITER command detected, using custom delimiter parsing")
    return(split_sql_with_custom_delimiter(sql_content))
  }

  # Standard split: semicolon followed by newline or end
  # This handles multi-statement files with standard SQL
  statements <- strsplit(sql_content, ";\\s*(\n|$)")[[1]]

  # Clean up: trim whitespace and filter empty
  statements <- trimws(statements)
  statements <- statements[nchar(statements) > 0]

  log_debug("Split into {length(statements)} statements")
  return(statements)
}

#' Split SQL with custom delimiter (internal helper)
#'
#' Handles SQL files that use DELIMITER command for stored procedures.
#'
#' @param sql_content Character string containing SQL with DELIMITER commands
#'
#' @return Character vector of SQL statements
#'
#' @keywords internal
split_sql_with_custom_delimiter <- function(sql_content) {
  # Extract the custom delimiter (e.g., "DELIMITER //" -> "//")
  delimiter_match <- regmatches(
    sql_content,
    regexpr("DELIMITER\\s+(\\S+)", sql_content)
  )

  if (length(delimiter_match) == 0) {
    log_warn("DELIMITER keyword found but no delimiter value")
    return(split_sql_statements(gsub("DELIMITER", "", sql_content)))
  }

  custom_delim <- gsub("DELIMITER\\s+", "", delimiter_match[1])
  log_debug("Custom delimiter detected: '{custom_delim}'")

  # Remove all DELIMITER lines (both setting and resetting)
  sql_clean <- gsub("DELIMITER\\s+\\S+\\s*\n?", "", sql_content)

  # Escape special regex characters in delimiter
  delim_escaped <- gsub("([.|()\\^{}+$*?\\[\\]])", "\\\\\\1", custom_delim)

  # Split on custom delimiter
  statements <- strsplit(sql_clean, paste0(delim_escaped, "\\s*(\n|$)"))[[1]]

  # Clean up: trim whitespace and filter empty
  statements <- trimws(statements)
  statements <- statements[nchar(statements) > 0]

  log_debug("Split into {length(statements)} statements using custom delimiter")
  return(statements)
}

#' Execute a single migration file
#'
#' Reads and executes all SQL statements from a migration file.
#' Records success in schema_version table.
#'
#' @param filepath Filename (basename) of the migration file
#' @param migrations_dir Path to migrations directory. Default: "db/migrations"
#' @param conn Optional database connection or pool object. If NULL, uses global pool.
#'
#' @return Invisible NULL (side effect: migration executed and recorded)
#'
#' @details
#' - Reads file content and splits into statements
#' - Executes each statement with DBI::dbExecute(immediate = TRUE)
#' - On success: records migration in schema_version
#' - On error: logs error and stops (fail-fast)
#' - Note: MySQL DDL causes implicit commits, not transactional
#'
#' @export
execute_migration <- function(filepath, migrations_dir = "db/migrations", conn = NULL) {
  full_path <- file.path(migrations_dir, filepath)
  log_info("Executing migration: {filepath}")

  if (!file.exists(full_path)) {
    log_error("Migration file not found: {full_path}")
    stop(paste("Migration file not found:", full_path))
  }

  # Determine connection: use provided conn or checkout from global pool
  use_pool <- if (is.null(conn)) pool else conn
  is_pool_obj <- inherits(use_pool, "Pool")

  if (is_pool_obj) {
    use_conn <- pool::poolCheckout(use_pool)
    on.exit(pool::poolReturn(use_conn), add = TRUE)
  } else {
    use_conn <- use_pool
  }

  # Read file content
  sql_content <- paste(readLines(full_path, warn = FALSE), collapse = "\n")

  # Split into statements
  statements <- split_sql_statements(sql_content)

  if (length(statements) == 0) {
    log_warn("Migration file is empty: {filepath}")
    # Still record it to avoid re-running
    record_migration(filepath, use_conn)
    return(invisible(NULL))
  }

  log_debug("Migration {filepath} contains {length(statements)} statements")

  # Execute each statement
  tryCatch({
    for (i in seq_along(statements)) {
      stmt <- statements[[i]]
      if (nchar(trimws(stmt)) > 0) {
        log_debug("Executing statement {i}/{length(statements)}")
        # immediate = TRUE for DDL and multi-statement support
        DBI::dbExecute(use_conn, stmt, immediate = TRUE)
      }
    }

    # Record successful migration
    record_migration(filepath, use_conn)
    log_info("Migration completed: {filepath}")

  }, error = function(e) {
    log_error("Migration failed: {filepath} - {e$message}")
    # Re-throw to stop further migrations
    stop(paste("Migration failed:", filepath, "-", e$message))
  })

  invisible(NULL)
}

#' Get list of pending migrations
#'
#' Compares available migration files against applied migrations
#' to determine what needs to be run.
#'
#' @param migrations_dir Path to migrations directory. Default: "db/migrations"
#' @param conn Optional database connection or pool object. If NULL, uses global pool.
#'
#' @return Character vector of pending migration filenames (empty if up-to-date)
#'
#' @export
get_pending_migrations <- function(migrations_dir = "db/migrations", conn = NULL) {
  # Ensure tracking table exists (creates if needed, idempotent)
  ensure_schema_version_table(conn)

  # Get all migration files
  all_files <- list_migration_files(migrations_dir)
  if (length(all_files) == 0) {
    return(character(0))
  }

  # Get applied migrations
  applied <- get_applied_migrations(conn)

  # Return pending (those not yet applied)
  setdiff(all_files, applied)
}

#' Run all pending database migrations
#'
#' Main entry point for the migration system. Checks for pending migrations
#' and executes them in order.
#'
#' @param migrations_dir Path to migrations directory. Default: "db/migrations"
#' @param conn Optional database connection or pool object. If NULL, uses global pool.
#' @param verbose Logical. If TRUE, logs additional detail. Default: FALSE
#'
#' @return List with: total_applied (count before run), newly_applied (count this run),
#'   filenames (vector of newly applied filenames)
#'
#' @details
#' - Creates schema_version table if not exists
#' - Lists all migration files, compares to applied list
#' - Executes pending migrations in filename order (NNN_ prefix)
#' - Stops on first error (fail-fast)
#' - Safe to run multiple times (idempotent)
#'
#' @examples
#' \dontrun{
#' # Run with global pool
#' result <- run_migrations()
#' cat(sprintf("Applied %d new migrations\n", result$newly_applied))
#'
#' # Run with explicit connection
#' result <- run_migrations(conn = my_conn, verbose = TRUE)
#' }
#'
#' @export
run_migrations <- function(migrations_dir = "db/migrations", conn = NULL, verbose = FALSE) {
  log_info("Starting migration runner")

  if (verbose) {
    log_debug("Verbose mode enabled")
  }

  # Ensure tracking table exists
  ensure_schema_version_table(conn)

  # Get list of all migration files
  migration_files <- list_migration_files(migrations_dir)

  if (length(migration_files) == 0) {
    log_info("No migration files found in {migrations_dir}")
    return(list(
      total_applied = 0,
      newly_applied = 0,
      filenames = character(0)
    ))
  }

  # Get already-applied migrations
  applied <- get_applied_migrations(conn)

  # Calculate pending migrations
  pending <- setdiff(migration_files, applied)

  if (length(pending) == 0) {
    log_info("No pending migrations - database is up to date")
    return(list(
      total_applied = length(applied),
      newly_applied = 0,
      filenames = character(0)
    ))
  }

  log_info("Found {length(pending)} pending migrations: {paste(pending, collapse = ', ')}")

  # Execute each pending migration in order
  newly_applied <- character(0)
  for (migration_file in pending) {
    execute_migration(migration_file, migrations_dir, conn)
    newly_applied <- c(newly_applied, migration_file)
  }

  # Summary log
  log_info("Applied {length(newly_applied)} migrations ({paste(newly_applied, collapse = ', ')})")

  return(list(
    total_applied = length(applied) + length(newly_applied),
    newly_applied = length(newly_applied),
    filenames = newly_applied
  ))
}
