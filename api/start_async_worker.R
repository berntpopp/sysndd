source("bootstrap/init_libraries.R", local = FALSE)
source("bootstrap/create_pool.R", local = FALSE)
source("bootstrap/load_modules.R", local = FALSE)

bootstrap_init_libraries()
bootstrap_load_modules()
source("bootstrap/init_cache.R", local = FALSE)
bootstrap_init_cache_version()
bootstrap_bind_memoised(envir = .GlobalEnv)
source("functions/async-job-progress.R", local = FALSE)
source("functions/async-job-omim-apply.R", local = FALSE)
source("functions/async-job-force-apply-payload.R", local = FALSE)
source("functions/async-job-provider-handlers.R", local = FALSE)
source("functions/async-job-maintenance-handlers.R", local = FALSE)
source("functions/async-job-handlers.R", local = FALSE)
source("functions/async-job-worker.R", local = FALSE)

env_mode <- Sys.getenv("ENVIRONMENT", "local")

if (tolower(env_mode) == "production") {
  Sys.setenv(API_CONFIG = "sysndd_db")
} else if (tolower(env_mode) == "development") {
  Sys.setenv(API_CONFIG = "sysndd_db_dev")
} else {
  Sys.setenv(API_CONFIG = "sysndd_db_local")
}

dw <- config::get(Sys.getenv("API_CONFIG"))

if (!is.null(dw$workdir)) {
  setwd(dw$workdir)
}

pool <- bootstrap_create_pool(dw)
on.exit(pool::poolClose(pool), add = TRUE)

worker_config <- async_job_worker_config_from_env()
if (!is.null(worker_config$drain_file) && nzchar(worker_config$drain_file)) {
  unlink(worker_config$drain_file, force = TRUE)
}

# Remove any mode-0600 MySQL option files a previously-crashed worker left
# behind (#535 P1-1 L1). Best-effort.
if (exists("async_job_backup_cleanup_stale_option_files")) {
  async_job_backup_cleanup_stale_option_files()
}
message(sprintf(
  "[async-worker] starting worker_id=%s queues=%s",
  worker_config$worker_id,
  paste(worker_config$queues, collapse = ",")
))

async_job_worker_main(worker_config = worker_config)
