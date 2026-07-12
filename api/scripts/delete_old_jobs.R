#!/usr/bin/env Rscript
# scripts/delete_old_jobs.R
#
# Retention-based cleanup of terminal `async_jobs` rows (#535 S7).
#
# Thin entrypoint mirroring scripts/delete_old_logs.R: bootstraps libraries +
# config + the DB pool the same way, then delegates to the reusable, unit-tested
# helpers in functions/async-job-retention.R (which reuse the injection-safe
# validate_retention_days() from functions/log-cleanup.R).
#
# Configuration (environment variables):
#   ASYNC_JOB_RETENTION_DAYS             Retention window in days (default 90)
#   ASYNC_JOB_RETENTION_DRY_RUN          When truthy (1/true/yes/on): count only, no delete
#                                        (an unrecognized value fails safe to dry-run)
#   ASYNC_JOB_RETENTION_BATCH_SIZE       Candidate PKs read+deleted per batch, clamped <=1000 (default 1000)
#   ASYNC_JOB_RETENTION_LOCK_WAIT_SECONDS Per-batch row+metadata lock wait, clamped <=30 (default 10)
#   ENVIRONMENT                          production | development | <other> -> config block
#
# Exit codes: 0 on success, non-zero on any failure.
#
# Run inside the API image, e.g.:
#   Rscript scripts/delete_old_jobs.R

# --- Bootstrap (mirrors scripts/delete_old_logs.R) --------------------------
source("bootstrap/init_libraries.R", local = FALSE)
source("bootstrap/create_pool.R", local = FALSE)

bootstrap_init_libraries()

source("functions/db-helpers.R", local = FALSE)
source("functions/log-cleanup.R", local = FALSE) # validate_retention_days / env-is-true
source("functions/async-job-retention.R", local = FALSE)

env_mode <- Sys.getenv("ENVIRONMENT", "local")
if (tolower(env_mode) == "production") {
  Sys.setenv(API_CONFIG = "sysndd_db")
} else if (tolower(env_mode) == "development") {
  Sys.setenv(API_CONFIG = "sysndd_db_dev")
} else {
  Sys.setenv(API_CONFIG = "sysndd_db_local")
}

main <- function() {
  config <- async_job_retention_config_from_env()

  dw <- config::get(Sys.getenv("API_CONFIG"))
  if (!is.null(dw$workdir) && dir.exists(dw$workdir)) {
    setwd(dw$workdir)
  }

  pool <- bootstrap_create_pool(dw)
  on.exit(pool::poolClose(pool), add = TRUE)

  assign("pool", pool, envir = .GlobalEnv)

  # Hold ONE connection for the whole run and bound its lock waits so a single
  # batch DELETE can never stall indefinitely on a lock held by a worker (a
  # blocked statement fails fast instead of exceeding the run's wall-clock
  # ceiling). `innodb_lock_wait_timeout` bounds InnoDB ROW-lock waits;
  # `lock_wait_timeout` bounds METADATA-lock (DDL) waits — both are set because
  # they cover distinct wait classes. Reuses the one connection for every batch.
  conn <- pool::poolCheckout(pool)
  on.exit(pool::poolReturn(conn), add = TRUE)
  # Clamped to a fail-closed maximum so an oversized lock wait cannot let a
  # blocked statement stall past the run's wall-clock ceiling.
  lock_wait <- async_job_retention_bounded_int(
    Sys.getenv("ASYNC_JOB_RETENTION_LOCK_WAIT_SECONDS", ""),
    ASYNC_JOB_RETENTION_LOCK_WAIT_DEFAULT, ASYNC_JOB_RETENTION_LOCK_WAIT_MAX,
    "ASYNC_JOB_RETENTION_LOCK_WAIT_SECONDS"
  )
  DBI::dbExecute(conn, sprintf("SET SESSION innodb_lock_wait_timeout = %d", lock_wait))
  DBI::dbExecute(conn, sprintf("SET SESSION lock_wait_timeout = %d", lock_wait))

  count_fn <- function(sql, params = list()) {
    res <- db_execute_query(sql, params, conn = conn)
    if (is.data.frame(res) && nrow(res) >= 1L && "n" %in% names(res)) {
      return(as.integer(res$n[[1]]))
    }
    0L
  }
  select_ids_fn <- function(sql, params = list()) {
    res <- db_execute_query(sql, params, conn = conn)
    if (is.data.frame(res) && "job_id" %in% names(res)) {
      return(as.character(res$job_id))
    }
    character(0)
  }
  execute_fn <- function(sql, params = list()) {
    as.integer(db_execute_statement(sql, params, conn = conn))
  }

  run_async_job_retention(
    config = config,
    count_fn = count_fn,
    select_ids_fn = select_ids_fn,
    execute_fn = execute_fn,
    logger = function(msg) message(sprintf("[%s] %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), msg))
  )
}

tryCatch(
  main(),
  error = function(e) {
    message(sprintf(
      "[%s] [job-retention] FAILED: %s",
      format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), conditionMessage(e)
    ))
    quit(status = 1L, save = "no")
  }
)

quit(status = 0L, save = "no")
