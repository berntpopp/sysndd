#!/usr/bin/env Rscript
# Operator entrypoint (#535 P1-1): redact the DB password from historical
# async_jobs BACKUP payloads and recompute their request_hash. Idempotent.
#
# The same scrub runs best-effort at API startup and after each restore, so a
# normal deploy/restart (`docker compose up -d --force-recreate api`) already
# applies it. Use this script to scrub WITHOUT a restart. Run it in the API
# container (after rotating the DB credential):
#   docker exec sysndd-api-1 Rscript /app/scripts/scrub-job-payload-credentials.R

setwd("/app")
source("bootstrap/init_libraries.R", local = FALSE)
bootstrap_init_libraries()
source("bootstrap/load_modules.R", local = FALSE)
bootstrap_load_modules()
source("bootstrap/create_pool.R", local = FALSE)

# Resolve the config section exactly like start_sysndd_api.R: Compose passes
# ENVIRONMENT (production/development/...), NOT API_CONFIG.
env_mode <- Sys.getenv("ENVIRONMENT", "local")
api_config <- if (tolower(env_mode) == "production") {
  "sysndd_db"
} else if (tolower(env_mode) == "development") {
  "sysndd_db_dev"
} else {
  "sysndd_db_local"
}
dw <- config::get(api_config)
pool <- bootstrap_create_pool(dw)

n <- async_job_scrub_payload_credentials()
cat(sprintf("Redacted credentials from %d terminal backup payload row(s).\n", n))
