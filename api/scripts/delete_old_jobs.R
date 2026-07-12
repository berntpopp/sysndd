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
#   ASYNC_JOB_RETENTION_DAYS      Retention window in days (default 90)
#   ASYNC_JOB_RETENTION_DRY_RUN   When truthy (1/true/yes/on): count only, no delete
#   ENVIRONMENT                   production | development | <other> -> config block
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

  count_fn <- function(sql, params = list()) {
    res <- db_execute_query(sql, params)
    if (is.data.frame(res) && nrow(res) >= 1L && "n" %in% names(res)) {
      return(as.integer(res$n[[1]]))
    }
    0L
  }
  execute_fn <- function(sql, params = list()) {
    as.integer(db_execute_statement(sql, params))
  }

  run_async_job_retention(
    config = config,
    count_fn = count_fn,
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
