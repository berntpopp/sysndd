######################################################################
# start_sysndd_api.R
#
# Thin top-level composer for the SysNDD Plumber API.
#
# After the Phase D.D6 extract-bootstrap refactor the heavy lifting
# lives in api/bootstrap/*.R. This script:
#   1. attaches libraries + resolves the environment-specific config
#   2. sources every application module (repositories, core, services,
#      filters) via api/bootstrap/load_modules.R
#   3. builds the DB pool, runs migrations, configures the memoise cache
#   4. spawns the mirai daemon pool and pre-sources worker deps
#   5. mounts every endpoint onto the root router
#   6. starts Plumber
#
# Every bootstrap module returns its result. The composer binds the
# returned value at script top level (which IS .GlobalEnv), so
# endpoints / filters / services that still look up `pool`,
# `serializers`, `migration_status`, `root`, etc. as globals keep
# working unchanged — no super-assignments required anywhere.
#
# Run with: Rscript start_sysndd_api.R
# Override env with: ENVIRONMENT=production Rscript start_sysndd_api.R
######################################################################

## -------------------------------------------------------------------##
# 1) Bring the bootstrap modules + libraries onto the search path.
## -------------------------------------------------------------------##
source("bootstrap/init_libraries.R", local = FALSE)
source("bootstrap/load_modules.R",    local = FALSE)
source("bootstrap/create_pool.R",     local = FALSE)
source("bootstrap/run_migrations.R",  local = FALSE)
source("bootstrap/init_globals.R",    local = FALSE)
source("bootstrap/init_cache.R",      local = FALSE)
source("bootstrap/setup_workers.R",   local = FALSE)
source("bootstrap/mount_endpoints.R", local = FALSE)

bootstrap_init_libraries()

## -------------------------------------------------------------------##
# 2) Environment + config resolution.
## -------------------------------------------------------------------##
env_mode <- Sys.getenv("ENVIRONMENT", "local")
message(paste("ENVIRONMENT set to:", env_mode))

if (tolower(env_mode) == "production") {
  Sys.setenv(API_CONFIG = "sysndd_db")
} else if (tolower(env_mode) == "development") {
  Sys.setenv(API_CONFIG = "sysndd_db_dev")
} else {
  Sys.setenv(API_CONFIG = "sysndd_db_local")
}

dw <- config::get(Sys.getenv("API_CONFIG"))

# config::get() may parse unquoted YAML values as lists; coerce + validate.
if (is.list(dw$secret)) {
  dw$secret <- as.character(dw$secret[[1]])
  message("WARNING: dw$secret was list, coerced to character. Check config.yml quoting.")
}
stopifnot(
  "dw$secret must be a non-empty string" =
    is.character(dw$secret) && nchar(dw$secret) > 0
)

if (!is.null(dw$workdir)) {
  message(paste("Setting working directory to:", dw$workdir))
  setwd(dw$workdir)
} else {
  message("No 'workdir' specified in config. Using current working directory.")
}

## -------------------------------------------------------------------##
# 3) Load repositories/core/services/filters into .GlobalEnv.
## -------------------------------------------------------------------##
bootstrap_load_modules()

## -------------------------------------------------------------------##
# 4) Static OpenAPI spec + structured logging file.
## -------------------------------------------------------------------##
api_spec <- fromJSON("config/api_spec.json", flatten = TRUE)

log_dir <- "logs"
if (!dir_exists(log_dir)) fs::dir_create(log_dir)
logging_temp_file <- tempfile("plumber_", log_dir, ".log")
log_appender(appender_file(logging_temp_file))

## -------------------------------------------------------------------##
# 5) Database pool + migrations.
## -------------------------------------------------------------------##
pool <- bootstrap_create_pool(dw)
migration_status <- bootstrap_run_migrations(pool)

# Issue #22: refresh the human-facing db_version row (id = 1) from
# deployment-injected DB_VERSION / DB_COMMIT env vars when present. No-op and
# non-fatal otherwise; the migration seeds the baseline row.
db_version_sync_from_env(conn = pool)

## -------------------------------------------------------------------##
# 6) Top-level constants (serializers, allow-lists, version).
## -------------------------------------------------------------------##
globals <- bootstrap_init_globals()
serializers                <- globals$serializers
inheritance_input_allowed  <- globals$inheritance_input_allowed
output_columns_allowed     <- globals$output_columns_allowed
user_status_allowed        <- globals$user_status_allowed
version_json               <- globals$version_json
sysndd_api_version         <- globals$sysndd_api_version

## -------------------------------------------------------------------##
# 7) Disk-backed memoise cache (see documentation/09-deployment.qmd for CACHE_VERSION).
## -------------------------------------------------------------------##
bootstrap_init_cache_version()

memoised <- bootstrap_init_memoised()
generate_stat_tibble_mem       <- memoised$generate_stat_tibble_mem
generate_gene_news_tibble_mem  <- memoised$generate_gene_news_tibble_mem
nest_gene_tibble_mem           <- memoised$nest_gene_tibble_mem
generate_tibble_fspec_mem      <- memoised$generate_tibble_fspec_mem
gen_string_clust_obj_mem       <- memoised$gen_string_clust_obj_mem
gen_mca_clust_obj_mem          <- memoised$gen_mca_clust_obj_mem
gen_network_edges_mem          <- memoised$gen_network_edges_mem
generate_phenotype_correlations_mem <-
  memoised$generate_phenotype_correlations_mem
read_log_files_mem             <- memoised$read_log_files_mem
nest_pubtator_gene_tibble_mem  <- memoised$nest_pubtator_gene_tibble_mem

## -------------------------------------------------------------------##
# 8) Mirai daemon pool + worker-side source files.
## -------------------------------------------------------------------##
worker_context <- bootstrap_setup_workers()

# Hourly job cleanup (schedule_cleanup defined in functions/job-manager.R).
schedule_cleanup(3600)

## -------------------------------------------------------------------##
# 9) Mount endpoints + filters onto the root router.
## -------------------------------------------------------------------##
root <- bootstrap_mount_endpoints(api_spec, pool, logging_temp_file)

## -------------------------------------------------------------------##
# 9b') Scrub any DB credential older code persisted into terminal backup job
#      payloads (#535 P1-1). Idempotent, backup+terminal scoped, env-gated
#      (ASYNC_JOB_PAYLOAD_SCRUB_ON_STARTUP), never crashes boot. Operator
#      credential rotation remains the primary mitigation. Safe on both lanes
#      (cheap + idempotent), so it runs OUTSIDE the enrichment-lane gate below.
## -------------------------------------------------------------------##
async_job_scrub_payload_credentials_on_startup()

## -------------------------------------------------------------------##
# 9b-9d) Startup bootstraps (pubtatornidd enrichment #421, analysis snapshots
#        #420, disease ontology mapping WP-C). These enqueue durable jobs and
#        are the CORE lane's responsibility only: the enrichment lane (#344)
#        depends_on the core API being healthy (migrations + these bootstraps
#        already done), so it must NOT re-run them. Each is idempotent +
#        dedup-safe and never crashes boot.
## -------------------------------------------------------------------##
if (!api_lane_is_enrichment()) {
  tryCatch(
    pubtatornidd_bootstrap_enrichment(),
    error = function(e) {
      message(sprintf("[pubtatornidd-bootstrap] skipped: %s", conditionMessage(e)))
    }
  )

  tryCatch(
    analysis_snapshot_bootstrap_on_startup(),
    error = function(e) {
      message(sprintf("[snapshot-bootstrap] skipped: %s", conditionMessage(e)))
    }
  )

  tryCatch(
    disease_ontology_mapping_bootstrap_on_startup(),
    error = function(e) {
      message(sprintf("[ontology-mapping-bootstrap] skipped: %s", conditionMessage(e)))
    }
  )
} else {
  message("[api-lane] enrichment lane: skipping startup bootstraps (core lane owns them)")
}

## -------------------------------------------------------------------##
# 10) Run the API.
## -------------------------------------------------------------------##
root %>% pr_run(host = "0.0.0.0", port = as.numeric(dw$port_self))
