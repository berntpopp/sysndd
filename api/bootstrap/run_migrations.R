## -------------------------------------------------------------------##
# api/bootstrap/run_migrations.R
#
# Part of the Phase D.D6 extract-bootstrap refactor.
#
# Runs the double-checked-locking migration startup dance using
# functions defined in functions/migration-runner.R (which must be
# sourced earlier by bootstrap_load_modules()).
#
# Returns the migration status list that is exposed via
# /api/health/ready.
## -------------------------------------------------------------------##

#' Execute startup migrations with advisory-lock coordination.
#'
#' Flow:
#'   1. Fast-path check — if no pending migrations, skip the lock.
#'   2. Otherwise, acquire the MySQL advisory lock (30s timeout).
#'   3. Re-check pending migrations (another container may have
#'      raced ahead and applied them).
#'   4. Apply migrations if still needed.
#'
#' A migration failure throws — the caller (start_sysndd_api.R) lets
#' the process crash deliberately so operators notice and fix the
#' underlying issue before traffic lands on a half-migrated schema.
#'
#' @param pool The shared DBI pool created by bootstrap_create_pool().
#' @param migrations_dir Path to the directory with numbered .sql files.
#' @return A status list with fields pending_migrations, total_migrations,
#'   last_run, newly_applied, filenames, fast_path, lock_acquired, and
#'   optionally `error`. Always returned (never NULL), so health checks
#'   can report the state on failure.
#' @export
bootstrap_run_migrations <- function(pool, migrations_dir = "db/migrations") {
  status <- tryCatch(
    {
      # Step 1: Fast path check (no lock needed if schema current)
      pending_before_lock <- get_pending_migrations(
        migrations_dir = migrations_dir, conn = pool
      )

      if (length(pending_before_lock) == 0) {
        message(sprintf(
          "[%s] Fast path: schema up to date, no lock needed",
          Sys.time()
        ))

        applied_count <- length(get_applied_migrations(pool))

        list(
          pending_migrations = 0,
          total_migrations = applied_count,
          last_run = Sys.time(),
          newly_applied = 0,
          filenames = character(0),
          fast_path = TRUE,
          lock_acquired = FALSE
        )
      } else {
        # Step 2: Migrations needed - acquire lock
        message(sprintf(
          "[%s] Pending migrations detected (%d): %s - acquiring lock",
          Sys.time(), length(pending_before_lock),
          paste(pending_before_lock, collapse = ", ")
        ))

        # Checkout connection for lock duration
        migration_conn <- pool::poolCheckout(pool)
        on.exit(pool::poolReturn(migration_conn), add = TRUE)

        # Acquire advisory lock (blocks until available or 30s timeout)
        acquire_migration_lock(migration_conn, timeout = 30)
        on.exit(release_migration_lock(migration_conn), add = TRUE)

        # Step 3: Re-check after lock
        pending_after_lock <- get_pending_migrations(
          migrations_dir = migrations_dir, conn = pool
        )

        if (length(pending_after_lock) == 0) {
          message(sprintf(
            "[%s] Another container completed migrations while we waited",
            Sys.time()
          ))

          applied_count <- length(get_applied_migrations(pool))

          list(
            pending_migrations = 0,
            total_migrations = applied_count,
            last_run = Sys.time(),
            newly_applied = 0,
            filenames = character(0),
            fast_path = FALSE,
            lock_acquired = TRUE
          )
        } else {
          # Step 4: Apply migrations (we hold lock, migrations still needed)
          start_time <- Sys.time()
          result <- run_migrations(
            migrations_dir = migrations_dir, conn = pool
          )
          duration <- as.numeric(
            difftime(Sys.time(), start_time, units = "secs")
          )

          if (result$newly_applied > 0) {
            message(sprintf(
              "[%s] Migrations complete (%d applied in %.2fs): %s",
              Sys.time(), result$newly_applied, duration,
              paste(result$filenames, collapse = ", ")
            ))
          } else {
            message(sprintf(
              "[%s] Schema up to date (%d migrations applied)",
              Sys.time(), result$total_applied
            ))
          }

          list(
            pending_migrations = 0,
            total_migrations = result$total_applied,
            last_run = Sys.time(),
            newly_applied = result$newly_applied,
            filenames = result$filenames,
            fast_path = FALSE,
            lock_acquired = TRUE
          )
        }
      }
    },
    error = function(e) {
      message(sprintf(
        "[%s] FATAL: Migration failed - %s",
        Sys.time(), e$message
      ))

      failure_status <- list(
        pending_migrations = NA,
        total_migrations = NA,
        last_run = Sys.time(),
        newly_applied = 0,
        filenames = character(0),
        fast_path = FALSE,
        lock_acquired = FALSE,
        error = e$message
      )

      # Record failure on the global so /health/ready can still report
      # it, then crash — operators must fix the migration before deploy.
      assign("migration_status", failure_status, envir = .GlobalEnv)
      stop(paste(
        "API startup aborted: migration failure -", e$message
      ))
    }
  )

  status
}
