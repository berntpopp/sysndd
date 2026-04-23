source("bootstrap/init_libraries.R", local = FALSE)
source("bootstrap/create_pool.R", local = FALSE)

source("functions/db-helpers.R", local = FALSE)
source("functions/async-job-repository.R", local = FALSE)
source("functions/async-job-progress.R", local = FALSE)
source("functions/async-job-handlers.R", local = FALSE)
source("functions/async-job-worker.R", local = FALSE)

bootstrap_init_libraries()

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
message(sprintf(
  "[async-worker] starting worker_id=%s queues=%s",
  worker_config$worker_id,
  paste(worker_config$queues, collapse = ",")
))

async_job_worker_main(worker_config = worker_config)
