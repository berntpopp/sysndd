# api/endpoints/admin_endpoints.R
#
# This file contains all Administrator-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Be sure to source any required helper files at the top (e.g.,
# source("functions/database-functions.R", local = TRUE)) if needed.

# Note: All required modules (db-helpers.R, middleware.R)
# are sourced by start_sysndd_api.R before endpoints are loaded.
# Functions are available in the global environment.

## -------------------------------------------------------------------##
## Administration section
## -------------------------------------------------------------------##

#* Get OpenAPI specification
#*
#* Returns the enhanced OpenAPI JSON specification for this API.
#* This endpoint is used by the frontend Swagger UI.
#*
#* The spec is enhanced with:
#* - Component schemas from config/openapi/schemas/*.json
#* - RFC 9457 ProblemDetails error responses
#* - Standard error response references on all endpoints
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @get /openapi.json
function(req, res) {

  # Get the full spec from root router (stored globally in start_sysndd_api.R)
  # Note: req$pr refers to sub-router which only has admin endpoints;
  # root$getApiSpec() returns full spec with all mounted endpoints
  spec <- root$getApiSpec()

  # Apply OpenAPI enhancements (schemas, error responses)
  # The root router's pr_set_api_spec callback is already applied by getApiSpec(),
  # which includes enhance_openapi_spec(). The spec should already be enhanced.

  spec
}

#* Updates ontology sets (DEPRECATED — removed)
#*
#* **REMOVED:** This synchronous endpoint has been removed.
#* Use PUT /admin/update_ontology_async instead, which provides progress
#* tracking, auto-fix of version shuffles, and safeguards against
#* critical ontology changes.
#*
#* @tag admin
#* @serializer unboxedJSON
#* @put update_ontology
function(req, res) {
  res$status <- 410L
  list(
    error = "Gone",
    message = "This endpoint is deprecated. Use PUT /api/admin/update_ontology_async"
  )
}


#* Updates OMIM ontology annotations asynchronously
#*
#* Returns immediately with a job_id. Poll GET /api/jobs/{job_id} for status.
#* Uses the new mim2gene.txt + JAX API workflow for OMIM data.
#*
#* Progress steps:
#* 1) Download mim2gene.txt
#* 2) Fetch disease names from JAX API
#* 3) Build and validate ontology set
#* 4) Apply MONDO SSSOM mappings and write to database
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* On success: Returns 202 with job_id and status="accepted".
#* If duplicate job running: Returns existing job_id with status="already_running".
#*
#* @tag admin
#* @serializer json list(na="string")
#* @put update_ontology_async
function(req, res) {
  # Require Administrator role
  require_role(req, res, "Administrator")

  # Pre-fetch database data (cannot be accessed in daemon workers)
  mode_of_inheritance_list <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    select(-is_active, -sort) %>%
    collect()

  non_alt_loci_set <- pool %>%
    tbl("non_alt_loci_set") %>%
    select(hgnc_id, symbol) %>%
    collect()

  ndd_entity_view <- pool %>%
    tbl("ndd_entity_view") %>%
    collect()

  disease_ontology_set_current <- pool %>%
    tbl("disease_ontology_set") %>%
    collect()

  ndd_entity <- pool %>%
    tbl("ndd_entity") %>%
    collect()

  # Check for duplicate job
  dup_check <- check_duplicate_job("omim_update", list())
  if (dup_check$duplicate) {
    return(list(
      job_id = dup_check$existing_job_id,
      status = "already_running",
      message = "An OMIM update job is already running"
    ))
  }

  # Create async job
  result <- create_job(
    operation = "omim_update",
    params = list(
      mode_of_inheritance_list = mode_of_inheritance_list,
      non_alt_loci_set = non_alt_loci_set,
      ndd_entity_view = ndd_entity_view,
      disease_ontology_set_current = disease_ontology_set_current,
      ndd_entity = ndd_entity,
      db_config = list(
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
      )
    )
  )

  res$status <- 202
  return(result)
}


#* Force-apply a blocked ontology update
#*
#* When an ontology update is blocked due to critical entity-referenced changes,
#* this endpoint force-applies the update by:
#* 1. Applying auto-fix remappings to ndd_entity
#* 2. Writing the new ontology set
#* 3. Inserting compatibility rows (is_active=FALSE) for critical old versions
#* 4. Creating a re-review batch for critical entities
#*
#* Returns immediately with a job_id. Poll GET /api/jobs/{job_id} for status.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Parameters`
#* @param blocked_job_id:character The job_id of the blocked ontology update
#*
#* # `Return`
#* On success: Returns 202 with job_id for the force-apply job.
#*
#* @tag admin
#* @serializer json list(na="string")
#* @put force_apply_ontology
function(req, res, blocked_job_id = NULL, assigned_user_id = NULL) {
  require_role(req, res, "Administrator")

  if (is.null(blocked_job_id) || blocked_job_id == "") {
    res$status <- 400L
    return(list(error = "blocked_job_id query parameter is required"))
  }

  # Parse optional assigned_user_id (defaults to requesting user)
  assigned_user_id <- if (!is.null(assigned_user_id) && assigned_user_id != "") {
    as.integer(assigned_user_id)
  } else {
    NULL
  }

  # Look up the blocked job result
  blocked_job <- get_job_status(blocked_job_id)

  if (!is.null(blocked_job$error) && blocked_job$error == "JOB_NOT_FOUND") {
    res$status <- 404L
    return(list(error = "Blocked job not found", job_id = blocked_job_id))
  }

  if (blocked_job$status != "completed") {
    res$status <- 409L
    return(list(
      error = "Job is not in completed state",
      job_status = blocked_job$status
    ))
  }

  # Check the job result contains blocked status
  job_result <- blocked_job$result
  result_status <- if (is.list(job_result$status)) {
    job_result$status[[1]]
  } else {
    job_result$status
  }
  if (is.null(result_status) || result_status != "blocked") {
    res$status <- 409L
    return(list(
      error = "Referenced job was not blocked",
      result_status = result_status
    ))
  }

  # Get the pending CSV path
  csv_path <- if (is.list(job_result$pending_csv_path)) {
    job_result$pending_csv_path[[1]]
  } else {
    job_result$pending_csv_path
  }
  if (is.null(csv_path) || !file.exists(csv_path)) {
    res$status <- 410L
    return(list(
      error = "Pending ontology CSV not found (may have expired)",
      path = csv_path
    ))
  }

  # Staleness check: reject if CSV is older than 48 hours
  csv_age_hours <- as.numeric(
    difftime(Sys.time(), file.info(csv_path)$mtime, units = "hours")
  )
  if (csv_age_hours > 48) {
    res$status <- 410L
    return(list(
      error = "Pending ontology update is stale (>48 hours). Re-run the update.",
      age_hours = round(csv_age_hours, 1)
    ))
  }

  # Use assigned_user_id if provided, otherwise fall back to requesting user
  requesting_user_id <- if (!is.null(assigned_user_id)) {
    assigned_user_id
  } else {
    req$user_id
  }

  # Pre-fetch data needed for the async job
  ndd_entity_view <- pool %>%
    tbl("ndd_entity_view") %>%
    collect()

  disease_ontology_set_current <- pool %>%
    tbl("disease_ontology_set") %>%
    collect()

  # Extract critical versions and auto_fixes from blocked job result
  critical_entities_raw <- job_result$critical_entities
  auto_fixes_raw <- job_result$auto_fixes

  # Check for duplicate job
  dup_check <- check_duplicate_job("force_apply_ontology", list())
  if (dup_check$duplicate) {
    return(list(
      job_id = dup_check$existing_job_id,
      status = "already_running",
      message = "A force-apply job is already running"
    ))
  }

  result <- create_job(
    operation = "force_apply_ontology",
    params = list(
      csv_path = csv_path,
      auto_fixes_raw = auto_fixes_raw,
      critical_entities_raw = critical_entities_raw,
      disease_ontology_set_current = disease_ontology_set_current,
      ndd_entity_view = ndd_entity_view,
      requesting_user_id = requesting_user_id,
      db_config = list(
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
      )
    )
  )

  res$status <- 202
  return(result)
}


#* Updates HGNC data and refreshes the non_alt_loci_set table
#*
#* This endpoint performs an update process by downloading the latest HGNC data,
#* processing it, and updating the non_alt_loci_set table. It is restricted to
#* Administrator users.
#*
#* # `Details`
#* The function downloads the latest HGNC file, processes the gene information,
#* updates STRINGdb identifiers, computes gene coordinates, and then updates
#* the non_alt_loci_set table in the MySQL database with these new values.
#*
#* # `Authorization`
#* Access to this endpoint is restricted to users with the 'Administrator' role.
#*
#* # `Return`
#* If successful, returns a success message. Otherwise, returns an error message.
#*
#* @tag admin
#* @serializer json list(na="string")
#* @put update_hgnc_data
function(req, res) {
  # Require Administrator role
  require_role(req, res, "Administrator")

  # Call the function to update the HGNC data
  hgnc_data <- update_process_hgnc_data()

  # Use transaction for atomic HGNC update
  tryCatch(
    {
      db_with_transaction(function(txn_conn) {
        metadata_with_foreign_key_checks_disabled(txn_conn, function() {
          db_execute_statement("DELETE FROM non_alt_loci_set", conn = txn_conn)

          # Insert hgnc_data rows using dynamic column names
          if (nrow(hgnc_data) > 0) {
            cols <- names(hgnc_data)
            # Quote column names with backticks for MySQL (handles special chars like hyphens)
            quoted_cols <- paste0("`", cols, "`")
            placeholders <- paste(rep("?", length(cols)), collapse = ", ")
            sql <- sprintf(
              "INSERT INTO non_alt_loci_set (%s) VALUES (%s)",
              paste(quoted_cols, collapse = ", "), placeholders
            )
            for (i in seq_len(nrow(hgnc_data))) {
              # Convert row to unnamed list for anonymous placeholders
              row_values <- unname(as.list(hgnc_data[i, ]))
              db_execute_statement(sql, row_values, conn = txn_conn)
            }
          }
        })
      })

      list(status = "Success", message = "HGNC data update process completed.")
    },
    error = function(e) {
      res$status <- 500
      list(
        error = "An error occurred during the HGNC update process. Transaction rolled back.",
        details = e$message
      )
    }
  )
}


#* Retrieves the current API version
#*
#* This endpoint provides the current version of the API. It's a simple utility
#* function that can be useful for clients to check the API version they are
#* interacting with. This can help in ensuring compatibility when multiple
#* versions exist.
#*
#* # `Details`
#* The function no longer calls `apiV()`, but instead references a global
#* variable `sysndd_api_version`. It's primarily for informational purposes.
#*
#* # `Authorization`
#* This endpoint does not require any specific role. It's open for any client
#* or user who needs to know the API version.
#*
#* # `Return`
#* Returns a JSON object with the API version, e.g. {"api_version": "x.y.z"}.
#*
#* @tag admin
#* @serializer unboxedJSON list(na="string")
#* @get api_version
function() {
  list(api_version = sysndd_api_version)
}


#* Get annotation update dates
#*
#* Returns the last update dates for various annotation sources.
#* Prefers job completion timestamps from job history over file metadata,
#* falling back to file dates for fresh installs with no job runs.
#*
#* # `Return`
#* Returns dates for OMIM (mim2gene), MONDO mappings, and HGNC updates.
#*
#* @tag admin
#* @serializer json list(na="string")
#* @get annotation_dates
function() {
  data_dir <- "data/"

  # Fetch job history once for all lookups
  history <- tryCatch(get_job_history(100), error = function(e) {
    data.frame(
      operation = character(0),
      status = character(0),
      completed_at = character(0),
      stringsAsFactors = FALSE
    )
  })

  # Helper: get most recent completed_at for matching operations
  get_last_successful_run <- function(operations, hist) {
    if (nrow(hist) == 0) return(NA)
    matches <- hist[
      hist$operation %in% operations & hist$status == "completed",
    ]
    if (nrow(matches) == 0) return(NA)
    # Sort by completed_at descending to get most recently finished job
    valid <- matches[!is.na(matches$completed_at), ]
    if (nrow(valid) == 0) return(NA)
    sorted <- valid[order(valid$completed_at, decreasing = TRUE), ]
    sorted$completed_at[1]
  }

  # Helper to get most recent file date matching a pattern
  get_latest_file_date <- function(pattern) {
    files <- list.files(data_dir, pattern = pattern, full.names = TRUE)
    if (length(files) == 0) return(NA)
    file_info <- file.info(files)
    if (nrow(file_info) == 0) return(NA)
    latest <- files[which.max(file_info$mtime)]
    format(file_info[latest, "mtime"], "%Y-%m-%d %H:%M:%S")
  }

  # Extract date from filename pattern like mim2gene.YYYY-MM-DD.txt
  get_date_from_filename <- function(pattern) {
    files <- list.files(data_dir, pattern = pattern, full.names = FALSE)
    if (length(files) == 0) return(NA)
    dates <- regmatches(files, regexpr("\\d{4}-\\d{2}-\\d{2}", files))
    if (length(dates) == 0) return(NA)
    max(dates)
  }

  # Prefer job history timestamps; fall back to file metadata
  omim_job <- get_last_successful_run("omim_update", history)
  ontology_job <- get_last_successful_run(
    c("ontology_update", "force_apply_ontology"), history
  )
  hgnc_job <- get_last_successful_run("hgnc_update", history)

  null_coalesce <- function(a, b) if (!is.na(a)) a else b

  list(
    omim_update = null_coalesce(
      omim_job, get_date_from_filename("^mim2gene\\..*\\.txt$")
    ),
    mondo_update = null_coalesce(
      ontology_job, get_latest_file_date("^mondo")
    ),
    hgnc_update = null_coalesce(
      hgnc_job, get_latest_file_date("^hgnc|^non_alt_loci")
    ),
    disease_ontology_update = null_coalesce(
      ontology_job,
      get_date_from_filename("^disease_ontology_set\\..*\\.csv$")
    )
  )
}


#* Get entities using deprecated OMIM IDs
#*
#* Returns entities that reference OMIM IDs marked as "moved/removed" in the
#* latest mim2gene.txt file. Each entity is enriched with MONDO mapping info
#* and replacement suggestions from the EBI OLS4 API.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* Returns a list with:
#* - deprecated_count: Number of deprecated MIM numbers found
#* - affected_entity_count: Number of entities using deprecated OMIM IDs
#* - affected_entities: Array of entities with MONDO deprecation info
#* - mim2gene_date: Date of the mim2gene.txt file used
#*
#* Each affected entity includes:
#* - entity_id, symbol, hgnc_id, disease_ontology_id, disease_ontology_name, category
#* - mondo_id: MONDO term referencing this OMIM (if found)
#* - mondo_label: Label of the MONDO term
#* - deprecation_reason: Reason for deprecation from MONDO
#* - replacement_mondo_id: Suggested replacement MONDO term
#* - replacement_omim_id: Suggested replacement OMIM ID
#*
#* @tag admin
#* @serializer json list(na="string")
#* @get deprecated_entities
function(req, res) {
  # Require Administrator role
  require_role(req, res, "Administrator")

  data_dir <- "data/"

  # Find the latest mim2gene file
  mim2gene_files <- list.files(data_dir, pattern = "^mim2gene\\..*\\.txt$", full.names = TRUE)

  if (length(mim2gene_files) == 0) {
    return(list(
      deprecated_count = 0,
      affected_entity_count = 0,
      affected_entities = list(),
      mim2gene_date = NA,
      message = "No mim2gene.txt file found. Run ontology update first."
    ))
  }

  # Get the newest file
  file_info <- file.info(mim2gene_files)
  latest_file <- mim2gene_files[which.max(file_info$mtime)]

  # Extract date from filename
  mim2gene_date <- regmatches(basename(latest_file), regexpr("\\d{4}-\\d{2}-\\d{2}", basename(latest_file)))
  if (length(mim2gene_date) == 0) mim2gene_date <- NA

  # Parse mim2gene with moved/removed entries
  tryCatch(
    {
      mim2gene_data <- parse_mim2gene(latest_file, include_moved_removed = TRUE)

      # Get deprecated MIM numbers
      deprecated_mims <- get_deprecated_mim_numbers(mim2gene_data)

      if (length(deprecated_mims) == 0) {
        return(list(
          deprecated_count = 0,
          affected_entity_count = 0,
          affected_entities = list(),
          mim2gene_date = mim2gene_date,
          message = "No deprecated MIM numbers found."
        ))
      }

      # Check entities for deprecation
      affected <- check_entities_for_deprecation(pool, deprecated_mims)

      if (nrow(affected) == 0) {
        return(list(
          deprecated_count = length(deprecated_mims),
          affected_entity_count = 0,
          affected_entities = list(),
          mim2gene_date = mim2gene_date,
          message = "No entities affected by deprecated OMIM IDs."
        ))
      }

      # Get unique OMIM IDs to look up (avoid duplicate API calls)
      unique_omim_ids <- unique(affected$disease_ontology_id)

      # Look up MONDO deprecation info for each unique OMIM ID
      # Use batch function with rate limiting
      mondo_info_map <- ols_get_deprecated_omim_info_batch(unique_omim_ids)

      # Enrich affected entities with MONDO info
      affected_enriched <- affected %>%
        {
          # Guard rowwise operations against empty tibble
          if (nrow(.) > 0) {
            dplyr::rowwise(.) %>%
              dplyr::mutate(
                mondo_info = list(mondo_info_map[[disease_ontology_id]]),
                mondo_id = if (!is.null(mondo_info)) mondo_info$mondo_id else NA_character_,
                mondo_label = if (!is.null(mondo_info)) mondo_info$mondo_label else NA_character_,
                deprecation_reason = if (!is.null(mondo_info)) mondo_info$deprecation_reason else NA_character_,
                replacement_mondo_id = if (!is.null(mondo_info)) mondo_info$replacement_mondo_id else NA_character_,
                replacement_mondo_label = if (!is.null(mondo_info)) {
                  mondo_info$replacement_mondo_label
                } else {
                  NA_character_
                },
                replacement_omim_id = if (!is.null(mondo_info)) mondo_info$replacement_omim_id else NA_character_
              ) %>%
              dplyr::ungroup()
          } else {
            dplyr::mutate(.,
              mondo_id = NA_character_,
              mondo_label = NA_character_,
              deprecation_reason = NA_character_,
              replacement_mondo_id = NA_character_,
              replacement_mondo_label = NA_character_,
              replacement_omim_id = NA_character_
            )
          }
        } %>%
        dplyr::select(
          entity_id,
          symbol,
          hgnc_id,
          disease_ontology_id,
          disease_ontology_id_version,
          disease_ontology_name,
          category,
          ndd_phenotype,
          mondo_id,
          mondo_label,
          deprecation_reason,
          replacement_mondo_id,
          replacement_mondo_label,
          replacement_omim_id
        )

      # Convert to list for JSON serialization
      affected_list <- affected_enriched %>%
        as.list() %>%
        purrr::transpose()

      list(
        deprecated_count = length(deprecated_mims),
        affected_entity_count = nrow(affected),
        affected_entities = affected_list,
        mim2gene_date = mim2gene_date
      )
    },
    error = function(e) {
      logger::log_error("Failed to check deprecated entities: {e$message}")
      res$status <- 500
      list(
        error = "Failed to check deprecated entities",
        details = e$message
      )
    }
  )
}


#* Test SMTP connection status
#*
#* Attempts to connect to the configured SMTP server and returns
#* connection status. Does not send any email.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* - success: Boolean indicating if connection succeeded
#* - host: SMTP host that was tested
#* - port: SMTP port that was tested
#* - error: Error message if connection failed (null on success)
#*
#* @tag admin
#* @serializer unboxedJSON
#* @get /smtp/test
function(req, res) {
  require_role(req, res, "Administrator")

  smtp_host <- dw$mail_noreply_host
  smtp_port <- as.integer(dw$mail_noreply_port)

  result <- tryCatch(
    {
      # Attempt socket connection to SMTP server
      con <- socketConnection(
        host = smtp_host,
        port = smtp_port,
        open = "r+",
        blocking = TRUE,
        timeout = 5
      )
      close(con)

      list(
        success = TRUE,
        host = smtp_host,
        port = smtp_port,
        error = NULL
      )
    },
    error = function(e) {
      list(
        success = FALSE,
        host = smtp_host,
        port = smtp_port,
        error = e$message
      )
    }
  )

  result
}


## -------------------------------------------------------------------##
## NDDScore Administration Endpoints
## -------------------------------------------------------------------##

#* Get NDDScore import status
#*
#* Returns the active NDDScore release and recent durable import jobs.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* @tag admin
#* @serializer json list(na="null")
#* @get /nddscore/status
function(req, res, limit = 10L) {
  require_role(req, res, "Administrator")

  limit <- suppressWarnings(as.integer(limit))
  if (is.na(limit) || limit < 1L) {
    limit <- 10L
  }
  limit <- min(limit, 100L)

  release <- nddscore_repo_current_release()
  jobs <- async_job_service_history(limit = 100L, include_result = TRUE)
  if (.nddscore_admin_has_rows(jobs)) {
    jobs <- jobs[jobs$job_type == "nddscore_import", , drop = FALSE]
    jobs <- utils::head(jobs, limit)
  }

  list(
    active_release = if (.nddscore_admin_has_rows(release)) {
      as.list(release[1L, , drop = FALSE])
    } else {
      NULL
    },
    active_release_available = .nddscore_admin_has_rows(release),
    recent_jobs = .nddscore_admin_tibble_rows(jobs),
    meta = list(
      job_type = "nddscore_import",
      default_record_id = nddscore_default_zenodo_record_id(),
      count = if (.nddscore_admin_has_rows(jobs)) nrow(jobs) else 0L,
      limit = limit
    )
  )
}


#* Check NDDScore Zenodo metadata
#*
#* Fetches Zenodo record metadata and compares it with the active release.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* @tag admin
#* @serializer json list(na="null")
#* @get /nddscore/zenodo
function(req, res, record_id = NULL) {
  require_role(req, res, "Administrator")

  record_id <- as.character(
    .nddscore_admin_scalar(record_id, nddscore_default_zenodo_record_id())
  )
  zenodo <- nddscore_fetch_zenodo_metadata(record_id)
  release <- nddscore_repo_current_release()
  active_release <- if (.nddscore_admin_has_rows(release)) {
    as.list(release[1L, , drop = FALSE])
  } else {
    NULL
  }

  comparison <- if (.nddscore_admin_has_rows(release)) {
    list(
      active_release_available = TRUE,
      record_id_matches = identical(
        as.character(release$source_record_id[[1]]),
        as.character(zenodo$record_id)
      ),
      version_matches = identical(
        as.character(release$version[[1]]),
        as.character(zenodo$version)
      ),
      archive_name_matches = identical(
        as.character(release$source_archive_name[[1]]),
        as.character(zenodo$archive_name)
      ),
      archive_checksum_matches = identical(
        as.character(release$source_archive_checksum[[1]]),
        as.character(zenodo$archive_md5)
      )
    )
  } else {
    list(active_release_available = FALSE)
  }

  list(
    record_id = record_id,
    zenodo = zenodo,
    active_release = active_release,
    comparison = comparison,
    matches_active = isTRUE(comparison$record_id_matches) &&
      isTRUE(comparison$version_matches) &&
      isTRUE(comparison$archive_name_matches) &&
      isTRUE(comparison$archive_checksum_matches)
  )
}


#* Submit NDDScore import job
#*
#* Submits a durable nddscore_import job. Poll the returned status_url.
#*
#* # `Request Body`
#* {
#*   "record_id": "20258027",
#*   "validate_only": false
#* }
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* @tag admin
#* @serializer json list(na="null")
#* @post /nddscore/import
function(req, res) {
  require_role(req, res, "Administrator")

  body <- .nddscore_admin_request_body(req)
  record_id <- as.character(
    .nddscore_admin_scalar(body$record_id, nddscore_default_zenodo_record_id())
  )
  validate_only <- .nddscore_admin_bool(body$validate_only, FALSE)

  submitted <- async_job_service_submit(
    job_type = "nddscore_import",
    request_payload = list(
      record_id = record_id,
      validate_only = validate_only
    ),
    submitted_by = req$user_id %||% NULL
  )

  job <- submitted$job
  job_id <- job$job_id[[1]]
  status_url <- .nddscore_admin_job_status_url(job_id)

  res$status <- if (isTRUE(submitted$duplicate)) 409L else 202L
  res$setHeader("Location", status_url)
  res$setHeader("Retry-After", "5")

  list(
    job_id = job_id,
    status = if (isTRUE(submitted$duplicate)) "already_running" else "accepted",
    job_status = job$status[[1]],
    status_url = status_url
  )
}


#* Refresh publication metadata from PubMed
#*
#* Returns immediately with job_id. Poll GET /api/jobs/{job_id} for status.
#* Rate limited to 3 requests/second (NCBI limit without API key).
#*
#* Supports three modes:
#* 1. Explicit PMIDs: Provide a `pmids` list to refresh
#* 2. Date filter: Provide `not_updated_since` (YYYY-MM-DD) to refresh publications older than that
#* 3. Refresh all: Provide `all=true` to refresh the whole corpus (enumerated server-side)
#*
#* Request body: { pmids?: [...], not_updated_since?: "YYYY-MM-DD", all?: true }.
#* With both a date and pmids, the list is filtered to publications older than the date.
#*
#* Returns 202 Accepted with { job_id, status, estimated_seconds }.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* @tag admin
#* @serializer json list(na="string")
#* @post /publications/refresh
function(req, res) {
  require_role(req, res, "Administrator")

  # CRITICAL: Extract request body BEFORE mirai call
  # Request object cannot cross process boundaries
  body <- req$body
  pmids <- body$pmids
  not_updated_since <- body$not_updated_since
  refresh_all <- isTRUE(body$all)

  # Handle date-based filtering
  if (!is.null(not_updated_since) && nzchar(not_updated_since)) {
    # Validate date format
    filter_date <- tryCatch(
      as.Date(not_updated_since),
      error = function(e) NULL
    )

    if (is.null(filter_date) || is.na(filter_date)) {
      res$status <- 400
      return(list(error = "Invalid date format for not_updated_since. Use YYYY-MM-DD."))
    }

    # Fetch PMIDs of publications not updated since the filter date
    filtered_pubs <- db_execute_query(
      "SELECT publication_id FROM publication WHERE update_date < ?",
      list(as.character(filter_date))
    )

    if (nrow(filtered_pubs) == 0) {
      res$status <- 200
      return(list(
        message = "No publications need refreshing",
        filter_date = as.character(filter_date),
        count = 0
      ))
    }

    filtered_pmids <- filtered_pubs$publication_id

    if (is.null(pmids) || length(pmids) == 0) {
      # No PMIDs provided - use all filtered publications
      pmids <- filtered_pmids
    } else {
      # Intersect provided PMIDs with filtered publications
      pmids <- intersect(pmids, filtered_pmids)
      if (length(pmids) == 0) {
        res$status <- 200
        return(list(
          message = "No matching publications need refreshing",
          filter_date = as.character(filter_date),
          count = 0
        ))
      }
    }
  }

  # Opt-in full-corpus refresh: enumerate server-side (client need not fetch all PMIDs).
  if (refresh_all && (is.null(pmids) || length(pmids) == 0)) {
    pmids <- db_execute_query("SELECT publication_id FROM publication")$publication_id
  }

  # Validate input - at least one PMID required. An empty request still 400s
  # (safety guard); full-corpus refresh requires the explicit all=true flag.
  if (is.null(pmids) || length(pmids) == 0) {
    res$status <- 400
    return(list(error = "No PMIDs provided and no date filter specified"))
  }

  # Check for duplicate job
  dup_check <- check_duplicate_job("publication_refresh", list(pmids = pmids))
  if (dup_check$duplicate) {
    return(list(
      job_id = dup_check$existing_job_id,
      status = "already_running",
      message = "A publication refresh job is already running with these PMIDs"
    ))
  }

  # Calculate estimated time: 350ms per PMID + overhead
  estimated_seconds <- ceiling(length(pmids) * 0.4)

  # Create async job
  result <- create_job(
    operation = "publication_refresh",
    params = list(
      pmids = pmids,
      db_config = list(
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
      )
    ),
    executor_fn = function(params) {
      # Source required functions in mirai daemon
      source("functions/publication-functions.R")
      source("functions/job-progress.R")
      source("functions/db-helpers.R")

      # Create progress reporter
      reporter <- create_progress_reporter(params$.__job_id__)

      pmids <- params$pmids
      total <- length(pmids)
      results <- list()

      # Connect to database (daemon needs its own connection)
      sysndd_db <- DBI::dbConnect(
        RMariaDB::MariaDB(),
        dbname = params$db_config$dbname,
        user = params$db_config$user,
        password = params$db_config$password,
        host = params$db_config$host,
        port = params$db_config$port
      )
      on.exit(DBI::dbDisconnect(sysndd_db), add = TRUE)

      # Process each PMID with rate limiting
      for (i in seq_along(pmids)) {
        pmid <- pmids[i]
        reporter(
          "fetch",
          sprintf("Fetching %s (%d/%d)", pmid, i, total),
          current = i,
          total = total
        )

        result_item <- tryCatch({
          # Fetch metadata from PubMed
          info <- info_from_pmid(pmid)

          # Update database - note info is a tibble so we access columns
          rows_affected <- db_execute_statement(
            "UPDATE publication SET
              Title = ?,
              Abstract = ?,
              Publication_date = ?,
              Journal = ?,
              Keywords = ?,
              Lastname = ?,
              Firstname = ?,
              update_date = NOW()
            WHERE publication_id = ?",
            list(
              info$Title[1],
              info$Abstract[1],
              info$Publication_date[1],
              info$Journal[1],
              info$Keywords[1],
              info$Lastname[1],
              info$Firstname[1],
              pmid
            ),
            conn = sysndd_db
          )

          list(
            pmid = pmid,
            status = if (rows_affected > 0) "updated" else "not_found",
            title = info$Title[1]
          )
        }, error = function(e) {
          list(
            pmid = pmid,
            status = "error",
            error = e$message
          )
        })

        results[[i]] <- result_item

        # Rate limit: 350ms delay = 2.86 req/sec (safe for NCBI 3 req/sec limit)
        if (i < total) Sys.sleep(0.35)
      }

      # Return summary
      list(
        total = total,
        success = sum(vapply(results, function(r) r$status == "updated", logical(1))),
        failed = sum(vapply(results, function(r) r$status == "error", logical(1))),
        not_found = sum(vapply(results, function(r) r$status == "not_found", logical(1))),
        results = results
      )
    },
    timeout_ms = 7200000  # 2 hours timeout for large batches (4547 pubs ~27 min)
  )

  # Check for capacity error
  if (!is.null(result$error)) {
    res$status <- 503
    return(result)
  }

  # Add estimated time to response
  result$estimated_seconds <- estimated_seconds

  res$status <- 202
  return(result)
}


## Administration section
## -------------------------------------------------------------------##
