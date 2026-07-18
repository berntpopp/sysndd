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
    "functions/db-version.R",
    "functions/metadata-refresh.R",
    "functions/ontology-status-service.R",
    "functions/async-job-repository.R",
    "functions/async-job-db-config.R",
    "functions/async-job-payload-scrub.R",
    "functions/async-job-service.R",
    "functions/per-caller-throttle.R",
    "functions/clustering-submit-throttle.R",
    "functions/auth-endpoint-throttle.R",
    "functions/analysis-snapshot-presets.R",
    "functions/analysis-snapshot-repository.R",
    "functions/analysis-snapshot-prune-helpers.R",
    "functions/analysis-snapshot-coherence.R",
    "functions/analysis-snapshot-dependencies.R",
    "functions/analysis-snapshot-builder.R",
    "functions/analysis-reproducibility.R",
    # Immutable, content-addressed public analysis-snapshot releases (#573
    # Slice A). Synchronous admin/API-only build path (svc_release_build(),
    # called directly from the admin endpoint) -- NOT a durable async-job
    # handler and NOT a mirai daemon job, so (unlike the sibling
    # analysis-snapshot-*.R files above) these are intentionally absent from
    # bootstrap/setup_workers.R's mirai everywhere() block. Registered here
    # only, which still covers the durable worker (start_async_worker.R) and
    # the MCP sidecar (start_sysndd_mcp.R) via this shared loader. Order:
    # manifest (content digest / canonical JSON / tar.gz) -> repository (DB
    # CRUD) -> materialize (coherence assertions + file/README building) ->
    # release (orchestrator, depends on all three).
    "functions/analysis-snapshot-release-manifest.R",
    "functions/analysis-snapshot-release-repository.R",
    "functions/analysis-snapshot-release-materialize.R",
    "functions/analysis-snapshot-release.R",
    "functions/async-job-analysis-snapshot-handlers.R",
    "functions/async-job-network-layout-handlers.R",
    "functions/nddscore-import.R",
    "functions/nddscore-repository.R",
    "functions/nddscore-admin-endpoint-helpers.R",
    "functions/entity-repository.R",
    "functions/review-repository.R",
    "functions/status-repository.R",
    "functions/re-review-sync.R",
    "functions/publication-repository.R",
    "functions/phenotype-repository.R",
    "functions/ontology-repository.R",
    "functions/mcp-search-repository.R",
    "functions/mcp-repository.R",
    "functions/mcp-analysis-cache-repository.R",
    "functions/mcp-analysis-repository.R",
    "functions/user-repository.R",
    "functions/user-endpoint-helpers.R",
    "functions/hash-repository.R",
    "functions/metadata-vocabulary-repository.R",
    "functions/category-normalization.R",
    "functions/phenotype-endpoint-functions.R",
    "functions/panels-endpoint-functions.R",
    "functions/endpoint-functions.R",
    "functions/comparisons-list.R",
    # Comparisons refresh write-path (durable `comparisons_update` job). These
    # were historically only loaded into the mirai daemon pool via
    # setup_workers.R, but create_job() now submits comparisons_update as a
    # durable System B job, so the async worker (which loads via this list) must
    # define comparisons_update_async() and its helpers too. Order: sources +
    # parsers + omim before comparisons-functions.R (which uses them).
    "functions/omim-functions.R",
    "functions/comparisons-sources.R",
    "functions/comparisons-parsers.R",
    "functions/comparisons-omim.R",
    "functions/comparisons-functions.R",
    "functions/publication-endpoint-helpers.R",
    "functions/pubmed-xml-parser.R",
    "functions/publication-functions.R",
    "functions/publication-date-backfill.R",
    "functions/genereviews-functions.R",
    "functions/analysis-string-channels.R",
    "functions/analysis-cache-fingerprint.R",
    "functions/analyses-functions.R",
    "functions/analysis-phenotype-mca-prep.R",
    "functions/analysis-phenotype-functions.R",
    "functions/analysis-null-models.R",
    "functions/analysis-cluster-validation.R",
    "functions/analysis-network-layout-functions.R",
    "functions/analysis-network-functions.R",
    "functions/account-helpers.R",
    "functions/data-helpers.R",
    "functions/entity-helpers.R",
    "functions/response-helpers.R",
    "functions/response-fields-helpers.R",
    "functions/email-templates.R",
    "functions/pagination-helpers.R",
    "functions/external-proxy-functions.R",
    "functions/external-proxy-gnomad.R",
    "functions/external-proxy-gnomad-batch.R",
    "functions/external-proxy-uniprot.R",
    "functions/external-proxy-ensembl.R",
    "functions/external-proxy-alphafold.R",
    "functions/external-proxy-mgi.R",
    "functions/external-proxy-rgd.R",
    "functions/genereviews-lookup.R",
    "functions/file-functions.R",
    "functions/hpo-functions.R",
    "functions/hgnc-functions.R",
    "functions/hgnc-enrichment-gnomad.R",
    "functions/llm-summary-config.R",
    "functions/llm-cache-repository.R",
    "functions/llm-cache-admin-repository.R",
    "functions/llm-validation.R",
    "functions/llm-model-config.R",
    "functions/llm-client.R",
    "functions/llm-rate-limiter.R",
    "functions/llm-types.R",
    "functions/llm-prompt-template-repository.R",
    "functions/llm-service.R",
    "functions/llm-judge-prompts.R",
    "functions/llm-judge.R",
    "functions/llm-batch-cluster-data.R",
    "functions/llm-batch-generator.R",
    "functions/llm-regenerate-helpers.R",
    "functions/mondo-index-builder.R",
    "functions/disease-ontology-mapping-builder.R",
    "functions/disease-ontology-mapping-repository.R",
    "functions/disease-ontology-mapping-refresh.R",
    "functions/ontology-functions.R",
    "functions/ontology-object.R",
    "functions/pubtator-client.R",
    "functions/pubtator-parser.R",
    "functions/pubtator-functions.R",
    "functions/pubtator-enrichment-metrics.R",
    "functions/pubtator-enrichment-collector.R",
    "functions/pubtator-gene-summary.R",
    "functions/pubtatornidd-nightly.R",
    "functions/ensembl-functions.R",
    "functions/job-manager.R",
    "functions/job-progress.R",
    "functions/backup-functions.R",
    "functions/ols-functions.R",
    "functions/openapi-helpers.R",
    "functions/migration-manifest.R",
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
    "services/metadata-vocabulary-service.R",
    "services/search-service.R",
    "services/entity-service.R",
    "services/entity-creation-service.R",
    "services/entity-rename-service.R",
    "services/review-service.R",
    "services/genereviews-service.R",
    "services/approval-service.R",
    "services/re-review-selection-service.R",
    "services/re-review-service.R",
    "services/re-review-refusal-service.R",
    "services/seo-service.R",
    "services/analysis-snapshot-service.R",
    "services/analysis-snapshot-refresh-service.R",
    "services/analysis-snapshot-release-service.R",
    "services/disease-ontology-mapping-service.R",
    "services/mcp-service.R",
    "services/mcp-analysis-shaping.R",
    "services/mcp-query-service.R",
    "services/mcp-record-service.R",
    "services/mcp-analysis-service.R",
    "services/mcp-analysis-llm-cache-service.R",
    "services/mcp-research-context-service.R",
    "services/mcp-capabilities-service.R",
    "services/mcp-tool-core.R",
    "services/mcp-tool-resources.R",
    "services/mcp-tools.R",
    "services/mcp-tool-analysis-registry.R",
    "services/mcp-tool-registry.R",
    # --- #346 Wave 3: endpoint-delegation services (svc_-prefixed). These are
    # sourced by the API and the durable worker via this shared loader, but are
    # never registered as job handlers or called by worker execution. They only
    # depend on functions/* and the domain services above, so they are appended
    # last (definition order is irrelevant; none call each other at source time).
    "services/publication-query-endpoint-service.R",
    "services/publication-admin-endpoint-service.R",
    "services/user-read-endpoint-service.R",
    "services/user-account-endpoint-service.R",
    "services/user-password-profile-endpoint-service.R",
    "services/user-bulk-endpoint-service.R",
    "services/admin-ontology-endpoint-service.R",
    "services/admin-diagnostics-endpoint-service.R",
    "services/admin-nddscore-endpoint-service.R",
    "services/admin-publication-refresh-endpoint-service.R",
    "services/job-functional-submission-service.R",
    "services/job-phenotype-submission-service.R",
    "services/job-maintenance-submission-service.R",
    "services/job-query-endpoint-service.R",
    "services/re-review-query-endpoint-service.R",
    "services/re-review-workflow-endpoint-service.R",
    "services/entity-read-endpoint-service.R",
    "services/entity-submission-endpoint-service.R",
    "services/statistics-public-endpoint-service.R",
    "services/statistics-admin-endpoint-service.R",
    "services/llm-admin-endpoint-service.R",
    "services/backup-endpoint-service.R"
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
