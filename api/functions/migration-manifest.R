# functions/migration-manifest.R
#
# Strict migration manifest validation for startup/readiness.

EXPECTED_LATEST_MIGRATION <- "033_add_metadata_lookup_admin_columns.sql"
EXPECTED_MIGRATION_COUNT <- 31L

#' Validate the migration manifest for strict startup/readiness checks
#'
#' Low-level migration helpers remain tolerant of missing or empty directories
#' for tests and fixtures. API startup/readiness uses this validator so bad
#' migration mounts fail explicitly instead of looking up to date.
#'
#' @param migrations_dir Path to migrations directory. Default: "db/migrations"
#' @param expected_latest Expected latest migration filename for this repo state.
#' @param expected_min_count Minimum SQL migration count for this repo state.
#' @param allow_empty Logical. If TRUE, missing/empty dirs return an allowed
#'   non-ok result for fixture callers instead of throwing.
#'
#' @return List describing manifest health.
#' @export
validate_migration_manifest <- function(migrations_dir = "db/migrations",
                                        expected_latest = EXPECTED_LATEST_MIGRATION,
                                        expected_min_count = EXPECTED_MIGRATION_COUNT,
                                        allow_empty = FALSE) {
  if (!fs::dir_exists(migrations_dir)) {
    if (isTRUE(allow_empty)) {
      return(list(ok = FALSE, allowed_empty = TRUE, reason = "missing_directory", count = 0L))
    }
    stop(sprintf("Migrations directory does not exist: %s", migrations_dir))
  }

  files <- list_migration_files(migrations_dir)
  count <- length(files)

  if (count == 0L) {
    if (isTRUE(allow_empty)) {
      return(list(ok = FALSE, allowed_empty = TRUE, reason = "empty_directory", count = 0L))
    }
    stop(sprintf("No migration files found in: %s", migrations_dir))
  }

  latest <- utils::tail(files, 1L)[[1L]]

  if (!identical(latest, expected_latest)) {
    stop(sprintf(
      "Expected latest migration mismatch: expected %s, found %s",
      expected_latest,
      latest
    ))
  }

  if (count < expected_min_count) {
    stop(sprintf("Migration file count too low: found %d, expected at least %d", count, expected_min_count))
  }

  list(
    ok = TRUE,
    allowed_empty = FALSE,
    count = count,
    expected_latest = expected_latest,
    latest = latest
  )
}
