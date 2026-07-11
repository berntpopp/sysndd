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
# CRITICAL (mirai): database connections cannot cross process boundaries.
# `hgnc_update` and `comparisons_update` build a `db_config` list from the
# global `dw` config object so their anonymous `executor_fn` closures can open
# their own connection inside the daemon. `db_config` contains a database
# password, so it is deliberately NEVER passed into `check_duplicate_job()` —
# only the stable operation name is hashed/stored there. Keep every
# `executor_fn` closure anonymous/inline (do not extract to a named helper);
# `create_job()` serializes it into the mirai daemon call.
#
# This is an ENDPOINT service: it is sourced by the shared bootstrap loader
# (api/bootstrap/load_modules.R) like any other services/* file, but it is
# never registered as an async job handler and the worker never calls it
# directly — the worker only ever invokes the `executor_fn` closures below via
# `async_job_service_submit()`.

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
  # CRITICAL: Extract database config BEFORE mirai
  # Database connections cannot cross process boundaries, so the daemon
  # must create its own connection using the config values.
  db_config <- list(
    dbname   = dw$dbname,
    host     = dw$host,
    user     = dw$user,
    password = dw$password,
    port     = dw$port
  )

  # Check for duplicate running job
  # Use a stable identifier (operation name only) — db_config contains credentials
  # and should NOT be included in the hash or stored longer than necessary.
  dup_check <- check_duplicate_job("hgnc_update", list(operation = "hgnc_update"))
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
    params = list(db_config = db_config),
    timeout_ms = 1800000, # 30 minutes (bulk TSV approach makes gnomAD fast)
    executor_fn = function(params) {
      # This runs in mirai daemon
      # Create file-based progress reporter so main process can read progress
      progress <- create_progress_reporter(params$.__job_id__)
      job_id <- params$.__job_id__

      # --- Phase 1: Download and process HGNC data ---
      message(sprintf(
        "[%s] [job:%s] HGNC update: starting data download and processing...",
        Sys.time(), job_id
      ))

      hgnc_data <- tryCatch(
        {
          update_process_hgnc_data(progress_fn = progress)
        },
        error = function(e) {
          msg <- sprintf("HGNC pipeline failed during data processing: %s", conditionMessage(e))
          message(sprintf("[%s] [job:%s] %s", Sys.time(), job_id, msg))
          stop(msg)
        }
      )

      message(sprintf(
        "[%s] [job:%s] HGNC update: processed %d rows (%d columns), writing to database...",
        Sys.time(), job_id, nrow(hgnc_data), ncol(hgnc_data)
      ))

      # --- Phase 2: Write to database ---
      progress("db_write", "Writing to database...", current = 9, total = 9)

      conn <- tryCatch(
        {
          DBI::dbConnect(
            RMariaDB::MariaDB(),
            dbname   = params$db_config$dbname,
            host     = params$db_config$host,
            user     = params$db_config$user,
            password = params$db_config$password,
            port     = params$db_config$port
          )
        },
        error = function(e) {
          msg <- sprintf("Failed to connect to database: %s", conditionMessage(e))
          message(sprintf("[%s] [job:%s] %s", Sys.time(), job_id, msg))
          stop(msg)
        }
      )
      on.exit(DBI::dbDisconnect(conn), add = TRUE)

      # Reconcile tibble columns against DB schema to prevent mismatches
      # (e.g. HGNC upstream renames like rna_central_ids -> rna_central_id)
      db_cols <- DBI::dbListFields(conn, "non_alt_loci_set")
      tibble_cols <- colnames(hgnc_data)

      # Drop tibble columns that don't exist in the DB table
      extra_cols <- setdiff(tibble_cols, db_cols)
      if (length(extra_cols) > 0) {
        message(sprintf(
          "[%s] [job:%s] Dropping %d tibble columns not in DB: %s",
          Sys.time(), job_id, length(extra_cols),
          paste(extra_cols, collapse = ", ")
        ))
        hgnc_data <- hgnc_data[, setdiff(tibble_cols, extra_cols), drop = FALSE]
      }

      # Warn about DB columns missing from the tibble (will be NULL in DB)
      missing_cols <- setdiff(db_cols, colnames(hgnc_data))
      if (length(missing_cols) > 0) {
        message(sprintf(
          "[%s] [job:%s] DB columns not in tibble (will be NULL): %s",
          Sys.time(), job_id, paste(missing_cols, collapse = ", ")
        ))
      }

      # Atomic table replacement: DELETE + INSERT in a real transaction
      # NOTE: TRUNCATE is DDL and auto-commits in MySQL — it cannot be rolled back.
      # DELETE FROM is DML and participates in the transaction, so on failure the
      # entire operation rolls back and the table retains its previous data.
      tryCatch(
        {
          # Disable FK checks for this session; ensure they are re-enabled even on error
          DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")
          on.exit(tryCatch(DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 1"),
            error = function(e) NULL
          ), add = TRUE)

          DBI::dbWithTransaction(conn, {
            DBI::dbExecute(conn, "DELETE FROM non_alt_loci_set")

            if (nrow(hgnc_data) > 0) {
              DBI::dbAppendTable(conn, "non_alt_loci_set", hgnc_data)
            }
          })

          DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 1")
        },
        error = function(e) {
          msg <- sprintf(
            "Database write failed: %s. Tibble cols: [%s]. DB cols: [%s].",
            conditionMessage(e),
            paste(colnames(hgnc_data), collapse = ", "),
            paste(db_cols, collapse = ", ")
          )
          message(sprintf("[%s] [job:%s] %s", Sys.time(), job_id, msg))
          stop(msg)
        }
      )

      message(sprintf(
        "[%s] [job:%s] HGNC update: database write complete (%d rows)",
        Sys.time(), job_id, nrow(hgnc_data)
      ))

      # Return summary (not the full tibble — avoid memory overhead in job state)
      list(
        status = "completed",
        rows_processed = nrow(hgnc_data),
        columns_written = ncol(hgnc_data),
        columns_dropped = length(extra_cols),
        gnomad_fallback_recovered = as.integer(
          attr(hgnc_data, "fallback_recovered", exact = TRUE) %||% 0L
        ),
        gnomad_fallback_unresolved = as.integer(
          attr(hgnc_data, "fallback_unresolved", exact = TRUE) %||% 0L
        ),
        message = "HGNC data updated and written to database successfully"
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
  # CRITICAL: Extract database config BEFORE mirai
  # Database connections cannot cross process boundaries, so the daemon
  # must create its own connection using the config values.
  db_config <- list(
    dbname   = dw$dbname,
    host     = dw$host,
    user     = dw$user,
    password = dw$password,
    port     = dw$port
  )

  # Check for duplicate running job
  # Use a stable identifier (operation name only) — db_config contains credentials
  # and should NOT be included in the hash or stored longer than necessary.
  dup_check <- check_duplicate_job("comparisons_update", list(operation = "comparisons_update"))
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
    params = list(db_config = db_config),
    timeout_ms = 1800000, # 30 minutes
    executor_fn = function(params) {
      # This runs in mirai daemon
      comparisons_update_async(params)
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
  res$setHeader("Retry-After", "30") # Long-running job: poll every 30 seconds

  list(
    job_id = result$job_id,
    status = result$status,
    estimated_seconds = 300, # ~5 min typical
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}
