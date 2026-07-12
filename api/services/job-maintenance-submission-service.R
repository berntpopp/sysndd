# api/services/job-maintenance-submission-service.R
#
# Bodies of the three Administrator-only maintenance job submission handlers,
# extracted from endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5):
#   POST /api/jobs/ontology_update/submit
#   POST /api/jobs/hgnc_update/submit
#   POST /api/jobs/comparisons_update/submit
#
# The `require_role(req, res, "Administrator")` gate stays in the endpoint
# shell (byte-identical); these svc_ functions receive `res` (mutated in
# place: status + headers) and return the JSON payload.
#
# DB credentials (#535 S2b): `hgnc_update` and `comparisons_update` no longer
# marshal a `db_config` into the job payload. Their durable handlers
# (.async_job_run_hgnc_update / comparisons_update_async) resolve DB creds at
# run time from the worker's runtime config via `async_job_db_connect()`, so no
# password is ever persisted in `async_jobs.request_payload_json`. They also
# dedupe via job-type single-flight (`async_job_service_duplicate_by_type()`),
# not a payload hash, so a full-table-replace maintenance job never runs
# concurrently — including across a deploy that changes its payload schema.
# `create_job()`'s `executor_fn` is dead (ignored); these submits pass `NULL`.
#
# This is an ENDPOINT service: it is sourced by the shared bootstrap loader
# (api/bootstrap/load_modules.R) like any other services/* file, and only ever
# submits durable jobs (`async_job_service_submit()`); the worker executes the
# registered handlers, never these svc_ functions.

#' Submit a disease ontology update job (MONDO + OMIM).
#'
#' @param res Plumber response, mutated in place (status + headers).
#' @return List payload for the `json` serializer.
#' @export
svc_job_submit_ontology_update <- function(res) {
  # CRITICAL: Extract all database data BEFORE mirai
  # Database connections cannot cross process boundaries

  # Get HGNC list
  hgnc_list <- pool %>%
    dplyr::tbl("non_alt_loci_set") %>%
    dplyr::select(symbol, hgnc_id) %>%
    dplyr::collect()

  # Get mode of inheritance list
  mode_of_inheritance_list <- pool %>%
    dplyr::tbl("mode_of_inheritance_list") %>%
    dplyr::filter(is_active == 1) %>%
    dplyr::select(hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name) %>%
    dplyr::collect()

  # Check for duplicate job (ontology update has no params variation)
  dup_check <- check_duplicate_job("ontology_update", list(operation = "ontology_update"))
  if (dup_check$duplicate) {
    res$status <- 409
    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
    return(list(
      error = "DUPLICATE_JOB",
      message = "Ontology update job already running",
      existing_job_id = dup_check$existing_job_id,
      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
    ))
  }

  # Create async job
  result <- create_job(
    operation = "ontology_update",
    params = list(
      hgnc_list = hgnc_list,
      mode_of_inheritance_list = mode_of_inheritance_list
    ),
    executor_fn = function(params) {
      # This runs in mirai daemon
      # The process_combine_ontology function handles:
      # - Downloading MONDO ontology
      # - Downloading OMIM genemap2
      # - Processing and combining data
      # - Saving results to CSV

      # Call the ontology processing function
      disease_ontology_set <- process_combine_ontology(
        hgnc_list = params$hgnc_list,
        mode_of_inheritance_list = params$mode_of_inheritance_list,
        max_file_age = 0, # Force regeneration
        output_path = "data/"
      )

      # Return summary
      list(
        status = "completed",
        rows_processed = nrow(disease_ontology_set),
        sources = c("MONDO", "OMIM"),
        output_file = paste0("data/disease_ontology_set.", format(Sys.Date(), "%Y-%m-%d"), ".csv")
      )
    }
  )

  # Check capacity
  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", as.character(result$retry_after))
    return(result)
  }

  # Success - return HTTP 202 Accepted
  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "30") # Longer polling interval for ontology update

  list(
    job_id = result$job_id,
    status = result$status,
    estimated_seconds = 300, # Ontology update is slow (5+ minutes)
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}

#' Submit an HGNC gene data update job.
#'
#' @param res Plumber response, mutated in place (status + headers).
#' @return List payload for the `json` serializer.
#' @export
svc_job_submit_hgnc_update <- function(res) {
  # Job-type single-flight (#535 S2b HIGH-4): hgnc_update fully replaces
  # non_alt_loci_set, so only one may run at a time. Dedupe on job_type alone
  # (not a payload hash) so removing db_config from the payload cannot open a
  # deploy-window where a pre-deploy job and a post-deploy submission coexist.
  dup_check <- async_job_service_duplicate_by_type("hgnc_update")
  if (dup_check$duplicate) {
    res$status <- 409
    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
    return(list(
      error = "DUPLICATE_JOB",
      message = "HGNC update job already running",
      existing_job_id = dup_check$existing_job_id,
      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
    ))
  }

  # Create async job for HGNC update pipeline
  # gnomAD enrichment now uses bulk TSV download (~10s), Ensembl/STRINGdb are the bottleneck
  result <- create_job(
    operation = "hgnc_update",
    params = list(),
    timeout_ms = 1800000, # 30 minutes (bulk TSV approach makes gnomAD fast)
    executor_fn = NULL
  )

  # Check capacity
  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", as.character(result$retry_after))
    return(result)
  }

  # Success - return HTTP 202 Accepted
  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "60") # Long-running job: poll every minute

  list(
    job_id = result$job_id,
    status = result$status,
    estimated_seconds = 300, # ~5 min typical (Ensembl BioMart is the bottleneck)
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}

#' Submit a comparisons data update job (7+ external NDD databases).
#'
#' @param res Plumber response, mutated in place (status + headers).
#' @return List payload for the `json` serializer.
#' @export
svc_job_submit_comparisons_update <- function(res) {
  # Job-type single-flight (#535 S2b HIGH-4): comparisons_update replaces
  # ndd_database_comparison per-list, so only one may run at a time. Dedupe on
  # job_type alone (not a payload hash) so removing db_config from the payload
  # cannot open a deploy-window with two concurrent refreshes.
  dup_check <- async_job_service_duplicate_by_type("comparisons_update")
  if (dup_check$duplicate) {
    res$status <- 409
    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
    return(list(
      error = "DUPLICATE_JOB",
      message = "Comparisons update job already running",
      existing_job_id = dup_check$existing_job_id,
      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
    ))
  }

  # Create async job for comparisons update
  # Downloads from 7+ sources can take 5-30 minutes depending on network
  result <- create_job(
    operation = "comparisons_update",
    params = list(),
    timeout_ms = 1800000, # 30 minutes
    executor_fn = NULL
  )

  # Check capacity
  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", as.character(result$retry_after))
    return(result)
  }

  # Success - return HTTP 202 Accepted
  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "30") # Long-running job: poll every 30 seconds

  list(
    job_id = result$job_id,
    status = result$status,
    estimated_seconds = 300, # ~5 min typical
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}
