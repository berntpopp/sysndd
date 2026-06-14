#!/usr/bin/env Rscript
# scripts/pubtatornidd_nightly_enqueue.R
#
# Enqueue ONE durable `pubtatornidd_nightly` job. This is the entire job of the
# `pubtatornidd-cron` sidecar: it submits a job and exits. The durable worker
# (which has the PubTator/PubMed egress) claims and runs the orchestrator in
# functions/pubtatornidd-nightly.R.
#
# Reuses async_job_service_submit() so the durable request_hash dedup applies:
# if a nightly job is already queued/running, this is a no-op (no overlap), but
# once the previous run is terminal a fresh submit succeeds the next night.
#
# Mirrors scripts/delete_old_logs.R for bootstrap/config/pool so it stays
# aligned with the rest of the API runtime (renv deps + RMariaDB, no hand-rolled
# dbConnect).
#
# Configuration (environment variables):
#   PUBTATORNDD_NIGHTLY_QUERY      Optional standing query override (else the
#                                  worker uses the most-recent cached query).
#   PUBTATORNDD_NIGHTLY_MAX_PAGES  Optional page cap for the incremental fetch.
#   ENVIRONMENT                    production | development | <other>
#
# Exit codes: 0 on success (including a benign duplicate), non-zero on failure
# so the scheduler can surface problems.

# --- Bootstrap (mirrors scripts/delete_old_logs.R) --------------------------
source("bootstrap/init_libraries.R", local = FALSE)
source("bootstrap/create_pool.R", local = FALSE)

bootstrap_init_libraries()

source("functions/db-helpers.R", local = FALSE)
source("functions/async-job-repository.R", local = FALSE)
source("functions/async-job-service.R", local = FALSE)

env_mode <- Sys.getenv("ENVIRONMENT", "local")
if (tolower(env_mode) == "production") {
  Sys.setenv(API_CONFIG = "sysndd_db")
} else if (tolower(env_mode) == "development") {
  Sys.setenv(API_CONFIG = "sysndd_db_dev")
} else {
  Sys.setenv(API_CONFIG = "sysndd_db_local")
}

log_line <- function(msg) {
  message(sprintf("[%s] [pubtatornidd-cron] %s",
                  format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), msg))
}

main <- function() {
  dw <- config::get(Sys.getenv("API_CONFIG"))
  if (!is.null(dw$workdir) && dir.exists(dw$workdir)) {
    setwd(dw$workdir)
  }

  pool <- bootstrap_create_pool(dw)
  on.exit(pool::poolClose(pool), add = TRUE)

  # async-job repository/service resolve the global `pool` via db-helpers.
  assign("pool", pool, envir = .GlobalEnv)

  payload <- list(trigger = "cron")
  query <- Sys.getenv("PUBTATORNDD_NIGHTLY_QUERY", "")
  if (nzchar(query)) {
    payload$query <- query
  }
  max_pages <- Sys.getenv("PUBTATORNDD_NIGHTLY_MAX_PAGES", "")
  if (nzchar(max_pages)) {
    payload$max_pages <- as.integer(max_pages)
  }

  submitted <- async_job_service_submit(
    job_type = "pubtatornidd_nightly",
    request_payload = payload
  )

  job_id <- submitted$job$job_id[[1]]
  if (isTRUE(submitted$duplicate)) {
    log_line(sprintf("nightly job already active (job_id=%s); skipped enqueue", job_id))
  } else {
    log_line(sprintf("enqueued nightly job_id=%s", job_id))
  }
  invisible(submitted)
}

tryCatch(
  main(),
  error = function(e) {
    log_line(sprintf("FAILED to enqueue nightly job: %s", conditionMessage(e)))
    quit(status = 1L, save = "no")
  }
)

quit(status = 0L, save = "no")
