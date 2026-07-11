#!/usr/bin/env Rscript
# Operator entrypoint (#535 P1-1): redact the DB password from historical
# async_jobs BACKUP payloads and recompute their request_hash. Idempotent.
# Run inside the API/worker container after deploy AND after rotating the DB
# credential:
#   docker exec sysndd-api-1 Rscript /app/scripts/scrub-job-payload-credentials.R
# (The same scrub also runs best-effort at API startup and after each restore.)

setwd("/app")
source("bootstrap/init_libraries.R", local = FALSE)
bootstrap_init_libraries()
source("bootstrap/load_modules.R", local = FALSE)
bootstrap_load_modules()
source("bootstrap/create_pool.R", local = FALSE)

dw <- config::get(Sys.getenv("API_CONFIG"))
pool <- bootstrap_create_pool(dw)

n <- async_job_scrub_payload_credentials()
cat(sprintf("Redacted credentials from %d terminal backup payload row(s).\n", n))
