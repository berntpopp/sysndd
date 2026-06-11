#!/usr/bin/env Rscript
# scripts/delete_old_logs.R
#
# Retention-based cleanup of the operational request log table (`logging`).
#
# This is a thin entrypoint: it bootstraps libraries + config + the DB pool the
# same way start_async_worker.R does, then delegates all logic to the reusable,
# unit-tested helpers in functions/log-cleanup.R. The connection helpers and
# config loading are reused (no hand-rolled dbConnect / RMySQL) so the script
# stays aligned with the rest of the API runtime (renv deps + RMariaDB).
#
# Configuration (environment variables):
#   LOG_RETENTION_DAYS            Retention window in days (default 30)
#   LOG_CLEANUP_DRY_RUN           When truthy (1/true/yes/on): count only, no delete
#   LOG_CLEANUP_TABLE             Override table name (default "logging")
#   LOG_CLEANUP_TIMESTAMP_COLUMN  Override timestamp column (default "timestamp")
#   ENVIRONMENT                   production | development | <other> -> config block
#
# Exit codes: 0 on success, non-zero on any failure (so a scheduler/cron can
# surface failures).
#
# Run inside the API image, e.g.:
#   Rscript scripts/delete_old_logs.R

# --- Bootstrap (mirrors start_async_worker.R) -------------------------------
source("bootstrap/init_libraries.R", local = FALSE)
source("bootstrap/create_pool.R", local = FALSE)

bootstrap_init_libraries()

# Reusable cleanup logic + the DB execution helpers it needs.
source("functions/db-helpers.R", local = FALSE)
source("functions/log-cleanup.R", local = FALSE)

env_mode <- Sys.getenv("ENVIRONMENT", "local")
if (tolower(env_mode) == "production") {
  Sys.setenv(API_CONFIG = "sysndd_db")
} else if (tolower(env_mode) == "development") {
  Sys.setenv(API_CONFIG = "sysndd_db_dev")
} else {
  Sys.setenv(API_CONFIG = "sysndd_db_local")
}

main <- function() {
  config <- log_cleanup_config_from_env()

  dw <- config::get(Sys.getenv("API_CONFIG"))
  if (!is.null(dw$workdir) && dir.exists(dw$workdir)) {
    setwd(dw$workdir)
  }

  pool <- bootstrap_create_pool(dw)
  on.exit(pool::poolClose(pool), add = TRUE)

  # The shared db-helpers execute/query against a global `pool` by default; bind
  # it so db_execute_statement()/db_get_query() resolve it via get_db_connection().
  assign("pool", pool, envir = .GlobalEnv)

  count_fn <- function(sql) {
    res <- db_execute_query(sql)
    if (is.data.frame(res) && nrow(res) >= 1L && "n" %in% names(res)) {
      return(as.integer(res$n[[1]]))
    }
    0L
  }
  execute_fn <- function(sql) {
    as.integer(db_execute_statement(sql))
  }

  summary <- run_log_cleanup(
    config = config,
    count_fn = count_fn,
    execute_fn = execute_fn,
    logger = function(msg) message(sprintf("[%s] %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), msg))
  )

  invisible(summary)
}

result <- tryCatch(
  main(),
  error = function(e) {
    message(sprintf(
      "[%s] [log-cleanup] FAILED: %s",
      format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), conditionMessage(e)
    ))
    quit(status = 1L, save = "no")
  }
)

quit(status = 0L, save = "no")
