#!/usr/bin/env Rscript
# scripts/ontology_mapping_refresh_enqueue.R
#
# Enqueue ONE durable `disease_ontology_mapping_refresh` job. This is the entire
# job of the `ontology-mapping-cron` sidecar: it submits a job and exits. The
# durable worker (which has the MONDO/SSSOM egress) claims and runs the
# orchestrator in functions/disease-ontology-mapping-refresh.R.
#
# Reuses the shared submit path (service_disease_ontology_mapping_submit_refresh)
# so the durable request_hash dedup applies: if a refresh is already
# queued/running, this is a no-op (no overlap), but once the previous run is
# terminal a fresh submit succeeds the next cycle. The cron uses force = FALSE so
# an unchanged MONDO release is a cheap conditional-GET no-op in the worker; the
# worker still rebuilds when the release changed.
#
# Mirrors scripts/pubtatornidd_nightly_enqueue.R for bootstrap/config/pool so it
# stays aligned with the rest of the API runtime (renv deps + RMariaDB).
#
# Exit codes: 0 on success (including a benign duplicate / skipped), non-zero on
# failure so the scheduler can surface problems.

# --- Bootstrap (mirrors scripts/pubtatornidd_nightly_enqueue.R) -------------
source("bootstrap/init_libraries.R", local = FALSE)
source("bootstrap/create_pool.R", local = FALSE)

bootstrap_init_libraries()

source("functions/db-helpers.R", local = FALSE)
source("functions/async-job-repository.R", local = FALSE)
source("functions/async-job-service.R", local = FALSE)
source("services/disease-ontology-mapping-service.R", local = FALSE)

env_mode <- Sys.getenv("ENVIRONMENT", "local")
if (tolower(env_mode) == "production") {
  Sys.setenv(API_CONFIG = "sysndd_db")
} else if (tolower(env_mode) == "development") {
  Sys.setenv(API_CONFIG = "sysndd_db_dev")
} else {
  Sys.setenv(API_CONFIG = "sysndd_db_local")
}

log_line <- function(msg) {
  message(sprintf("[%s] [ontology-mapping-cron] %s",
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

  outcome <- service_disease_ontology_mapping_submit_refresh(force = FALSE)

  if (isTRUE(outcome$skipped)) {
    log_line("successful mapping build present; skipped enqueue")
  } else if (isTRUE(outcome$duplicate)) {
    log_line(sprintf("refresh already active (job_id=%s); skipped enqueue", outcome$job_id))
  } else {
    log_line(sprintf("enqueued refresh job_id=%s", outcome$job_id))
  }
  invisible(outcome)
}

tryCatch(
  main(),
  error = function(e) {
    log_line(sprintf("FAILED to enqueue refresh job: %s", conditionMessage(e)))
    quit(status = 1L, save = "no")
  }
)

quit(status = 0L, save = "no")
