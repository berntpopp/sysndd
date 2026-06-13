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
# snapshots exist (by design — see AGENTS.md "Background jobs"). There is no
# public route that triggers a refresh (correct: it is admin/operator-only and
# heavy), so this script is the operator entry point.
#
# Usage (inside the running API or worker container, which already has STRINGdb
# and the full runtime available):
#   docker exec sysndd-api-1 Rscript /app/scripts/refresh-analysis-snapshots.R
#
# Or via the Make target:  make refresh-analysis-snapshots
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
  "[refresh-snapshots] submitting analysis_snapshot_refresh for %d presets on '%s'",
  length(presets), api_config
))

submitted <- 0L
for (preset in presets) {
  outcome <- tryCatch(
    async_job_service_submit(
      job_type = "analysis_snapshot_refresh",
      request_payload = list(
        analysis_type = preset$analysis_type,
        params = preset$params
      ),
      queue_name = "default",
      priority = 50L
    ),
    error = function(e) list(.error = conditionMessage(e))
  )

  if (!is.null(outcome$.error)) {
    message(sprintf("  %-34s ERROR: %s", preset$analysis_type, outcome$.error))
    next
  }

  job_id <- tryCatch(as.character(outcome$job$job_id[[1]]), error = function(e) NA_character_)
  tag <- if (isTRUE(outcome$duplicate)) " (existing job reused)" else ""
  message(sprintf("  %-34s job_id=%s%s", preset$analysis_type, job_id, tag))
  submitted <- submitted + 1L
}

message(sprintf(
  "[refresh-snapshots] %d/%d jobs queued. Worker (queue 'default') will build + activate each snapshot.",
  submitted, length(presets)
))
