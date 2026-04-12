## -------------------------------------------------------------------##
# api/bootstrap/load_modules.R
#
# Part of the Phase D.D6 extract-bootstrap refactor.
#
# Loads every R source file required by the running API into the
# global environment, in the correct order:
#   1. functions/* (repositories, helpers, clients, etc.)
#   2. core/* (security, errors, responses, middleware, filters)
#   3. services/* (transactional orchestration)
#
# Source order matters. Repository functions are loaded BEFORE
# services so that any `svc_`/`service_`-prefixed function in
# services/* can still call the underlying repository helpers.
# (A service that accidentally drops its prefix will shadow the
# repository function — see CLAUDE.md.)
#
# Mirai daemon workers do NOT use this module. They re-source a
# hand-picked subset of functions/* via `everywhere({...})` in
# api/bootstrap/setup_workers.R. Changes here do not automatically
# propagate to workers — update setup_workers.R as well when a
# function file is needed inside a daemon.
## -------------------------------------------------------------------##

#' Source a file into .GlobalEnv with a helpful error if missing.
#'
#' `source(..., local = FALSE)` puts the bindings into the global
#' environment — that is what endpoint files expect at runtime.
#' Top-level `source("...", local = TRUE)` in start_sysndd_api.R
#' previously had the same effect by accident of being at the top
#' level of the script; here we make the intent explicit.
#'
#' @param path Relative path from api/ to the source file.
#' @noRd
.bootstrap_source <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("bootstrap: source file not found: %s", path))
  }
  source(path, local = FALSE)
  invisible(NULL)
}

#' Load the full API source tree into the global environment.
#'
#' This is the explicit, auditable source list that used to live
#' inline in start_sysndd_api.R between the markers
#' `# --- function source list (v11.0) ---` and
#' `# --- end source list ---`.
#'
#' @return A list describing which file groups were loaded (used
#'   for logging / diagnostics). The side effect is that every
#'   listed file is sourced into .GlobalEnv.
#' @export
bootstrap_load_modules <- function() {

  # --- function source list (v11.0) ---
  function_files <- c(
    "functions/config-functions.R",
    "functions/logging-functions.R",
    "functions/db-helpers.R",
    "functions/entity-repository.R",
    "functions/review-repository.R",
    "functions/status-repository.R",
    "functions/re-review-sync.R",
    "functions/publication-repository.R",
    "functions/phenotype-repository.R",
    "functions/ontology-repository.R",
    "functions/user-repository.R",
    "functions/hash-repository.R",
    "functions/category-normalization.R",
    "functions/endpoint-functions.R",
    "functions/publication-functions.R",
    "functions/genereviews-functions.R",
    "functions/analyses-functions.R",
    "functions/account-helpers.R",
    "functions/data-helpers.R",
    "functions/entity-helpers.R",
    "functions/response-helpers.R",
    "functions/email-templates.R",
    "functions/pagination-helpers.R",
    "functions/external-functions.R",
    "functions/external-proxy-functions.R",
    "functions/external-proxy-gnomad.R",
    "functions/external-proxy-uniprot.R",
    "functions/external-proxy-ensembl.R",
    "functions/external-proxy-alphafold.R",
    "functions/external-proxy-mgi.R",
    "functions/external-proxy-rgd.R",
    "functions/file-functions.R",
    "functions/hpo-functions.R",
    "functions/hgnc-functions.R",
    "functions/hgnc-enrichment-gnomad.R",
    "functions/llm-cache-repository.R",
    "functions/llm-validation.R",
    "functions/llm-client.R",
    "functions/llm-rate-limiter.R",
    "functions/llm-types.R",
    "functions/llm-service.R",
    "functions/llm-judge.R",
    "functions/llm-batch-generator.R",
    "functions/ontology-functions.R",
    "functions/pubtator-client.R",
    "functions/pubtator-parser.R",
    "functions/pubtator-functions.R",
    "functions/ensembl-functions.R",
    "functions/job-manager.R",
    "functions/job-progress.R",
    "functions/backup-functions.R",
    "functions/ols-functions.R",
    "functions/openapi-helpers.R",
    "functions/migration-runner.R"
  )
  # --- end source list ---

  core_files <- c(
    "core/security.R",
    "core/errors.R",
    "core/responses.R",
    "core/logging_sanitizer.R",
    "core/middleware.R",
    "core/filters.R"
  )

  service_files <- c(
    "services/auth-service.R",
    "services/user-service.R",
    "services/status-service.R",
    "services/search-service.R",
    "services/entity-service.R",
    "services/review-service.R",
    "services/approval-service.R",
    "services/re-review-service.R"
  )

  for (path in function_files) .bootstrap_source(path)
  for (path in core_files) .bootstrap_source(path)
  for (path in service_files) .bootstrap_source(path)

  list(
    functions = length(function_files),
    core = length(core_files),
    services = length(service_files)
  )
}
