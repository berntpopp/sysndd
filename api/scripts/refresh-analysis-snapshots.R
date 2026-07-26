# api/scripts/refresh-analysis-snapshots.R
#
# Submit an `analysis_snapshot_refresh` async job for every supported analysis
# preset, so the worker BUILDS and ACTIVATES the durable public-ready snapshots
# that the public analysis endpoints read:
#   - GeneNetworks            -> gene_network_edges
#   - Functional clustering   -> functional_clusters
#   - Phenotype clustering    -> phenotype_clusters
#   - Phenotype correlations  -> phenotype_correlations
#   - Phenotype x functional  -> phenotype_functional_correlations
#
# Public analysis endpoints return HTTP 503 `snapshot_missing` until these
# snapshots exist (by design — see AGENTS.md "Background jobs"). A public GET no
# longer triggers a heavy build synchronously, but the serving path DOES enqueue
# a best-effort, throttled, dedup-safe self-heal refresh when it observes a
# missing / stale / version-mismatched snapshot
# (`service_analysis_snapshot_selfheal_on_serve()`), so a post-startup data
# change recovers on its own instead of serving a permanent 503. This script
# remains the operator entry point to FORCE an immediate all-preset rebuild.
#
# Usage: this file is NOT baked into the API image (`api/.dockerignore` excludes
# `scripts/`), and the container runs as a non-root user (so `docker cp` into
# `/app` is denied). Pipe it into the running container's R over stdin — the
# container already has STRINGdb and the full runtime available:
#
#   make refresh-analysis-snapshots
#     (which runs: docker exec -i sysndd-api-1 Rscript - < api/scripts/refresh-analysis-snapshots.R)
#
# Do NOT use `docker exec sysndd-api-1 Rscript /app/scripts/refresh-analysis-snapshots.R`
# — that path does not exist in the image (#484).
#
# The worker (queue "default") picks up the jobs and runs them; clustering-backed
# snapshots can take 30-80s each. Re-running while jobs are queued/running returns
# the existing job (dedup); re-running after completion rebuilds them.

setwd("/app")

source("bootstrap/init_libraries.R", local = FALSE)
source("bootstrap/create_pool.R", local = FALSE)
source("bootstrap/load_modules.R", local = FALSE)
bootstrap_init_libraries()
bootstrap_load_modules()

env_mode <- Sys.getenv("ENVIRONMENT", "local")
api_config <- if (tolower(env_mode) == "production") {
  "sysndd_db"
} else if (tolower(env_mode) == "development") {
  "sysndd_db_dev"
} else {
  "sysndd_db_local"
}
Sys.setenv(API_CONFIG = api_config)
dw <- config::get(api_config)
if (!is.null(dw$workdir)) {
  setwd(dw$workdir)
}

pool <- bootstrap_create_pool(dw)
on.exit(pool::poolClose(pool), add = TRUE)

presets <- analysis_snapshot_supported_presets()
message(sprintf(
  "[refresh-snapshots] forcing analysis_snapshot_refresh for %d presets on '%s'",
  length(presets), api_config
))

# Shared submit path (#420): the same function backs the startup bootstrap and
# the admin endpoint. The operator script's contract is "rebuild them", so it
# forces a refresh regardless of whether a current snapshot already exists.
summary <- service_analysis_snapshot_submit_refresh(force = TRUE)

for (r in summary$results) {
  tag <- switch(r$action,
    submitted = "",
    reused = " (existing job reused)",
    error = sprintf(" ERROR: %s", r$message),
    skipped_existing = " (already present)",
    ""
  )
  message(sprintf("  %-34s job_id=%s%s", r$analysis_type, r$job_id, tag))
}

message(sprintf(
  paste(
    "[refresh-snapshots] %d submitted, %d reused, %d failed of %d presets.",
    "Worker (queue 'default') will build + activate each snapshot."
  ),
  summary$submitted, summary$reused, summary$failed, summary$requested
))
