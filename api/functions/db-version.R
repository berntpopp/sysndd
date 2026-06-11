# functions/db-version.R
#
# Issue #22: human-facing semantic version of the SysNDD database.
#
# Reads the single-row `db_version` table (migration 028) and, at startup,
# optionally refreshes the row's commit/version from deployment-injected
# DB_VERSION / DB_COMMIT environment variables. The release helper
# db/scripts/update-db-version.sh documents how DB_COMMIT is captured from
# `git log -1 --format=%h -- db/` at release time.
#
# This is intentionally separate from:
#   * schema_version  -- the migration runner's at-most-once apply ledger
#   * about_content.version -- About-page CONTENT publish versioning
#
# Read access is graceful: a missing table or unavailable DB returns a
# fallback list with version "unknown" rather than throwing, so the public
# /api/version endpoint never fails because of the DB-version surface.

#' Read the current semantic database version.
#'
#' Reads row id = 1 from the `db_version` table. Falls back gracefully to
#' an "unknown" record (never throws) when the table is missing or the DB is
#' unavailable, so the public version endpoint stays resilient.
#'
#' @param conn Optional DBI connection/pool for dependency injection in tests.
#'   When NULL, the global pool is used.
#'
#' @return A list with character `version`, character `commit`, character or
#'   NULL `description`, and character or NULL `updated_at` (ISO-ish string).
#'   `available` is TRUE when a row was read, FALSE on any fallback.
#' @export
db_version_get <- function(conn = NULL) {
  fallback <- list(
    version = "unknown",
    commit = "unknown",
    description = NULL,
    updated_at = NULL,
    available = FALSE
  )

  tryCatch(
    {
      result <- db_execute_query(
        paste0(
          "SELECT db_version, db_commit, description, updated_at ",
          "FROM db_version WHERE id = 1 LIMIT 1"
        ),
        conn = conn
      )

      if (is.null(result) || nrow(result) == 0) {
        return(fallback)
      }

      list(
        version = as.character(result$db_version[1]),
        commit = as.character(result$db_commit[1]),
        description = db_version_nullify(result$description[1]),
        updated_at = db_version_nullify(as.character(result$updated_at[1])),
        available = TRUE
      )
    },
    error = function(e) {
      log_warn("db_version_get failed, returning fallback: {e$message}")
      fallback
    }
  )
}

#' Coerce empty/NA scalar values to NULL for clean JSON output.
#'
#' @param x A length-1 vector.
#' @return The value, or NULL when it is NA or an empty string.
#' @keywords internal
db_version_nullify <- function(x) {
  if (length(x) == 0) {
    return(NULL)
  }
  if (is.na(x[1])) {
    return(NULL)
  }
  if (is.character(x[1]) && !nzchar(x[1])) {
    return(NULL)
  }
  x[1]
}

#' Sync the database version row from deployment environment variables.
#'
#' At release/deploy time the operator (or db/scripts/update-db-version.sh)
#' injects DB_VERSION (semantic version) and/or DB_COMMIT (last db/ folder git
#' short hash). When either is present this updates the existing id = 1 row so
#' the API and App report the deployed values without editing SQL by hand.
#'
#' This NEVER throws: a failure here must not block API startup. It is a no-op
#' when neither env var is set, when the row does not yet exist, or on any DB
#' error.
#'
#' @param conn Optional DBI connection/pool for dependency injection in tests.
#'
#' @return Invisibly TRUE when the row was updated, FALSE otherwise.
#' @export
db_version_sync_from_env <- function(conn = NULL) {
  env_version <- Sys.getenv("DB_VERSION", unset = "")
  env_commit <- Sys.getenv("DB_COMMIT", unset = "")

  if (!nzchar(env_version) && !nzchar(env_commit)) {
    return(invisible(FALSE))
  }

  tryCatch(
    {
      # Only refresh the canonical seeded row; never create extra rows.
      sets <- character(0)
      params <- list()

      if (nzchar(env_version)) {
        sets <- c(sets, "db_version = ?")
        params <- c(params, list(env_version))
      }
      if (nzchar(env_commit)) {
        sets <- c(sets, "db_commit = ?")
        params <- c(params, list(env_commit))
      }

      sql <- paste0(
        "UPDATE db_version SET ",
        paste(sets, collapse = ", "),
        " WHERE id = 1"
      )

      affected <- db_execute_statement(sql, params, conn = conn)

      if (isTRUE(affected > 0)) {
        log_info(
          "db_version synced from env (version={v}, commit={c})",
          v = if (nzchar(env_version)) env_version else "unchanged",
          c = if (nzchar(env_commit)) env_commit else "unchanged"
        )
        return(invisible(TRUE))
      }

      invisible(FALSE)
    },
    error = function(e) {
      log_warn("db_version_sync_from_env failed (non-fatal): {e$message}")
      invisible(FALSE)
    }
  )
}
