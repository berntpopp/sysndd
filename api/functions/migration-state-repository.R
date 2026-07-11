# functions/migration-state-repository.R
#
# Migration state persistence for the SysNDD API migration runner.
# Split out of functions/migration-runner.R (#346 Wave 4) to keep each file
# under the repository's 600-line ceiling.
#
# This module owns everything that reads or writes the `schema_version`
# tracking table and the on-disk migration manifest:
# - schema_version table creation (idempotent)
# - listing migration files on disk
# - reading applied migration rows
# - reconciling historical migration renames
# - recording a newly-applied migration
#
# It does NOT own: advisory locking, SQL statement splitting/execution, the
# pending-migration diff, or the run_migrations() entry point — those stay in
# functions/migration-runner.R, which sources this file (guard-sourced, see
# below) before defining them.
#
# Usage:
#   source("functions/migration-state-repository.R")
#   ensure_schema_version_table()
#   list_migration_files("db/migrations")

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

#' Historical migration renames tracked by the runner
#'
#' Map of `old_filename = new_filename` for files that were renamed in master
#' after they had already been applied in long-lived deployments. The
#' reconciliation step below rewrites `schema_version.filename` before the
#' pending-migration diff so a rename does not re-execute the migration.
#'
#' Add a new entry whenever a historical migration is renamed. Keep the map
#' small; prefer not renaming migrations once deployed.
#'
#' @keywords internal
MIGRATION_RENAMES <- list(
  # Phase A.A4 (v11.0): duplicate 008_ prefix resolved by renaming to 018_
  # See .planning/reviews/2026-04-11-codebase-review.md §2 and .planning/_archive/legacy-plans/v11.0/phase-a.md §3 A4.
  "008_hgnc_symbol_lookup.sql" = "018_hgnc_symbol_lookup.sql"
)

#' Reconcile schema_version for historical migration renames
#'
#' Before computing the pending-migration diff, rewrite any rows in
#' `schema_version` whose filename is listed in [MIGRATION_RENAMES] as an
#' old name and whose new name (a) exists on disk and (b) is not already
#' recorded. This prevents a renamed migration from being re-executed on
#' long-lived deployments after the rename PR merges.
#'
#' The operation is idempotent: re-running it on an already-reconciled
#' database is a no-op.
#'
#' @param conn Optional database connection or pool object. If NULL, uses global pool.
#' @param migrations_dir Directory containing migration `.sql` files.
#'
#' @return Character vector of (old → new) pairs that were rewritten.
#' @keywords internal
reconcile_schema_version_renames <- function(conn = NULL, migrations_dir = "db/migrations") {
  if (length(MIGRATION_RENAMES) == 0) {
    return(character(0))
  }

  use_pool <- if (is.null(conn)) pool else conn
  is_pool_obj <- inherits(use_pool, "Pool")

  if (is_pool_obj) {
    use_conn <- pool::poolCheckout(use_pool)
    on.exit(pool::poolReturn(use_conn), add = TRUE)
  } else {
    use_conn <- use_pool
  }

  # Read the on-disk file set once. If this fails, let the error propagate:
  # the outer run_migrations() will hit the same failure on its own call to
  # list_migration_files() right after, so swallowing it here only obscures the
  # diagnostic.
  on_disk <- list_migration_files(migrations_dir)

  rewritten <- character(0)

  # For each rename, SELECT + UPDATE/DELETE run without tryCatch. Errors
  # propagate because the schema_version table is guaranteed to exist at this
  # point (ensure_schema_version_table() ran above in run_migrations(), which
  # is the only caller). A genuine DB error here means the connection is
  # broken — that must crash startup rather than silently skip reconciliation,
  # otherwise the renamed migration would re-run in the main loop and
  # duplicate non-idempotent rows (exactly the hazard this function exists
  # to prevent).
  for (old_name in names(MIGRATION_RENAMES)) {
    new_name <- MIGRATION_RENAMES[[old_name]]

    # Only rewrite if the new file exists on disk (otherwise the rename PR has
    # not landed yet in this tree and the reconciliation is premature).
    if (!(new_name %in% on_disk)) {
      next
    }

    # Check current schema_version state for both rows.
    old_row <- DBI::dbGetQuery(
      use_conn,
      "SELECT filename FROM schema_version WHERE filename = ? LIMIT 1",
      params = list(old_name)
    )
    new_row <- DBI::dbGetQuery(
      use_conn,
      "SELECT filename FROM schema_version WHERE filename = ? LIMIT 1",
      params = list(new_name)
    )

    old_present <- !is.null(old_row) && nrow(old_row) > 0
    new_present <- !is.null(new_row) && nrow(new_row) > 0

    if (old_present && !new_present) {
      # Rewrite the row. UPDATE failures propagate (no tryCatch) so that the
      # API startup aborts before run_migrations() reaches its setdiff() loop
      # with an unreconciled schema_version state. Proceeding in that state
      # would re-execute the renamed migration and duplicate rows.
      log_info(paste0(
        "reconcile_schema_version_renames: rewriting schema_version.filename ",
        "'", old_name, "' -> '", new_name, "'"
      ))
      DBI::dbExecute(
        use_conn,
        "UPDATE schema_version SET filename = ? WHERE filename = ?",
        params = list(new_name, old_name)
      )
      rewritten <- c(rewritten, paste0(old_name, " -> ", new_name))
    } else if (old_present && new_present) {
      # Both present — this is a soft anomaly (A4's 018 re-ran before this
      # reconciliation was deployed, OR the rename ran twice). Keep the new
      # row and drop the old row so future checks are clean. Do not touch
      # any other table; the duplicate-row cleanup (if any) is a manual
      # follow-up.
      #
      # DELETE failures propagate for the same reason as UPDATE above: we
      # must not leave schema_version in an inconsistent state and then fall
      # through into the main migration loop.
      log_info(paste0(
        "reconcile_schema_version_renames: both '", old_name, "' and '", new_name,
        "' present in schema_version; dropping stale old row"
      ))
      DBI::dbExecute(
        use_conn,
        "DELETE FROM schema_version WHERE filename = ?",
        params = list(old_name)
      )
      rewritten <- c(rewritten, paste0(old_name, " -> ", new_name, " (dedup)"))
    }
    # Else: nothing to do (old_name not recorded; new_name already recorded, or
    # neither present — the rename PR has not been applied to this deployment
    # yet).
  }

  return(rewritten)
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
