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
    ),
    executor_fn = function(params) {
      # Source required functions in worker
      source("functions/omim-functions.R")
      source("functions/mondo-functions.R")
      source("functions/ontology-functions.R")
      source("functions/file-functions.R")

      # Process new ontology data using mim2gene + JAX API
      disease_ontology_set_update <- process_combine_ontology(
        params$non_alt_loci_set,
        params$mode_of_inheritance_list,
        3,
        "data/"
      )

      # Validate before write (CONTEXT.md: abort if any entry fails)
      validation <- validate_omim_data(disease_ontology_set_update)
      if (!validation$valid) {
        stop(paste("Validation failed:", paste(validation$errors, collapse = "; ")))
      }

      # Identify critical changes with safeguard
      ndd_entity_view_ontology_set <- params$ndd_entity_view %>%
        dplyr::select(entity_id, disease_ontology_id_version, disease_ontology_name)

      safeguard <- identify_critical_ontology_changes(
        disease_ontology_set_update,
        params$disease_ontology_set_current,
        ndd_entity_view_ontology_set
      )

      # If truly critical changes exist, BLOCK the write
      if (safeguard$summary$truly_critical > 0) {
        # Save pending update to CSV for later force-apply
        pending_dir <- "data/pending_ontology/"
        if (!dir.exists(pending_dir)) dir.create(pending_dir, recursive = TRUE)
        csv_path <- paste0(
          pending_dir,
          "pending_ontology_update.",
          format(Sys.Date(), "%Y-%m-%d"),
          ".csv"
        )
        readr::write_csv(disease_ontology_set_update, file = csv_path, na = "NULL")

        # Return blocked result (job completes, but signals blocked)
        return(list(
          status = "blocked",
          message = paste0(
            "Ontology update blocked: ", safeguard$summary$truly_critical,
            " critical entity-referenced changes detected. ",
            "Review and use Force Apply to proceed."
          ),
          pending_csv_path = csv_path,
          critical_count = safeguard$summary$truly_critical,
          auto_fixable_count = safeguard$summary$auto_fixable,
          total_affected = safeguard$summary$total_affected,
          critical_entities = safeguard$critical %>%
            dplyr::select(
              disease_ontology_id_version,
              disease_ontology_name,
              hgnc_id,
              hpo_mode_of_inheritance_term
            ) %>%
            as.list() %>%
            purrr::transpose(),
          auto_fixes = if (nrow(safeguard$auto_fixes) > 0) {
            safeguard$auto_fixes %>%
              as.list() %>%
              purrr::transpose()
          } else {
            list()
          }
        ))
      }

      # No truly critical changes — proceed with write
      # Connect to database
      sysndd_db <- DBI::dbConnect(
        RMariaDB::MariaDB(),
        dbname = params$db_config$dbname,
        user = params$db_config$user,
        password = params$db_config$password,
        server = params$db_config$server,
        host = params$db_config$host,
        port = params$db_config$port
      )
      on.exit(DBI::dbDisconnect(sysndd_db), add = TRUE)

      auto_fixes_applied <- 0
      DBI::dbBegin(sysndd_db)
      tryCatch(
        {
          # Truncate and write new ontology set first (new versions must
          # exist before auto-fix UPDATEs can reference them)
          DBI::dbExecute(sysndd_db, "SET FOREIGN_KEY_CHECKS = 0;")
          DBI::dbExecute(sysndd_db, "TRUNCATE TABLE disease_ontology_set;")
          DBI::dbAppendTable(sysndd_db, "disease_ontology_set", disease_ontology_set_update)
          DBI::dbExecute(sysndd_db, "SET FOREIGN_KEY_CHECKS = 1;")

          # Apply auto-fix UPDATEs to ndd_entity (new versions now exist)
          if (nrow(safeguard$auto_fixes) > 0) {
            for (i in seq_len(nrow(safeguard$auto_fixes))) {
              fix <- safeguard$auto_fixes[i, ]
              DBI::dbExecute(
                sysndd_db,
                "UPDATE ndd_entity SET disease_ontology_id_version = ? WHERE disease_ontology_id_version = ?", # nolint: line_length_linter
                params = unname(list(fix$new_version, fix$old_version))
              )
              auto_fixes_applied <- auto_fixes_applied + 1
            }
          }

          DBI::dbCommit(sysndd_db)
          list(
            status = "success",
            rows_written = nrow(disease_ontology_set_update),
            auto_fixes_applied = auto_fixes_applied,
            total_affected = safeguard$summary$total_affected
          )
        },
        error = function(e) {
          DBI::dbRollback(sysndd_db)
          stop(paste("Database write failed:", e$message))
        }
      )
    }
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
    ),
    executor_fn = function(params) {
      source("functions/file-functions.R")

      # Load the pending ontology data
      disease_ontology_set_update <- readr::read_csv(
        params$csv_path, na = "NULL", show_col_types = FALSE
      )

      # Reconstruct auto_fixes tibble from raw list
      auto_fixes <- if (length(params$auto_fixes_raw) > 0) {
        tibble::tibble(
          old_version = vapply(
            params$auto_fixes_raw,
            function(x) as.character(x$old_version %||% x$old_version[[1]]),
            character(1)
          ),
          new_version = vapply(
            params$auto_fixes_raw,
            function(x) as.character(x$new_version %||% x$new_version[[1]]),
            character(1)
          )
        )
      } else {
        tibble::tibble(old_version = character(0), new_version = character(0))
      }

      # Reconstruct critical entities tibble to extract old versions
      critical_versions <- if (length(params$critical_entities_raw) > 0) {
        vapply(
          params$critical_entities_raw,
          function(x) {
            v <- x$disease_ontology_id_version
            if (is.list(v)) v[[1]] else v
          },
          character(1)
        )
      } else {
        character(0)
      }

      # Get entity_ids referencing critical versions
      critical_entity_ids <- if (length(critical_versions) > 0) {
        params$ndd_entity_view %>%
          dplyr::filter(
            disease_ontology_id_version %in% critical_versions
          ) %>%
          dplyr::pull(entity_id) %>%
          unique()
      } else {
        integer(0)
      }

      # Build compatibility rows from current ontology for critical versions
      compatibility_rows <- if (length(critical_versions) > 0) {
        params$disease_ontology_set_current %>%
          dplyr::filter(
            disease_ontology_id_version %in% critical_versions
          ) %>%
          dplyr::mutate(is_active = FALSE)
      } else {
        tibble::tibble()
      }

      # Connect to database
      sysndd_db <- DBI::dbConnect(
        RMariaDB::MariaDB(),
        dbname = params$db_config$dbname,
        user = params$db_config$user,
        password = params$db_config$password,
        server = params$db_config$server,
        host = params$db_config$host,
        port = params$db_config$port
      )
      on.exit(DBI::dbDisconnect(sysndd_db), add = TRUE)

      auto_fixes_applied <- 0
      DBI::dbBegin(sysndd_db)
      tryCatch(
        {
          # Truncate and write new ontology set first (new versions must
          # exist before auto-fix UPDATEs can reference them)
          DBI::dbExecute(sysndd_db, "SET FOREIGN_KEY_CHECKS = 0;")
          DBI::dbExecute(sysndd_db, "TRUNCATE TABLE disease_ontology_set;")
          DBI::dbAppendTable(
            sysndd_db, "disease_ontology_set", disease_ontology_set_update
          )

          # Append compatibility rows so critical entity FKs remain valid
          compat_count <- 0
          if (nrow(compatibility_rows) > 0) {
            DBI::dbAppendTable(
              sysndd_db, "disease_ontology_set", compatibility_rows
            )
            compat_count <- nrow(compatibility_rows)
          }

          DBI::dbExecute(sysndd_db, "SET FOREIGN_KEY_CHECKS = 1;")

          # Apply auto-fix UPDATEs to ndd_entity (new versions now exist)
          if (nrow(auto_fixes) > 0) {
            for (i in seq_len(nrow(auto_fixes))) {
              fix <- auto_fixes[i, ]
              DBI::dbExecute(
                sysndd_db,
                "UPDATE ndd_entity SET disease_ontology_id_version = ? WHERE disease_ontology_id_version = ?", # nolint: line_length_linter
                params = unname(list(fix$new_version, fix$old_version))
              )
              auto_fixes_applied <- auto_fixes_applied + 1
            }
          }
          DBI::dbCommit(sysndd_db)

          # Create re-review batch for critical entities (outside transaction)
          re_review_batch_id <- NULL
          if (length(critical_entity_ids) > 0) {
            tryCatch({
              source("services/re-review-service.R")
              source("functions/db-helpers.R")
              batch_name <- paste0(
                "Ontology Update Review - ",
                format(Sys.Date(), "%Y-%m-%d")
              )
              batch_result <- batch_create(
                criteria = list(entity_ids = critical_entity_ids),
                assigned_user_id = params$requesting_user_id,
                batch_name = batch_name,
                pool = sysndd_db
              )
              if (batch_result$status == 200) {
                re_review_batch_id <- batch_result$entry$batch_id
              }
            }, error = function(e) {
              warning(paste(
                "Re-review batch creation failed (non-fatal):",
                e$message
              ))
            })
          }

          # Clean up pending CSV
          tryCatch(file.remove(params$csv_path), error = function(e) NULL)

          list(
            status = "success",
            rows_written = nrow(disease_ontology_set_update),
            auto_fixes_applied = auto_fixes_applied,
            compatibility_rows = compat_count,
            re_review_batch_id = re_review_batch_id,
            critical_entity_count = length(critical_entity_ids)
          )
        },
        error = function(e) {
          DBI::dbRollback(sysndd_db)
          stop(paste("Force-apply failed:", e$message))
        }
      )
    }
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
        db_execute_statement("SET FOREIGN_KEY_CHECKS = 0", conn = txn_conn)
        db_execute_statement("TRUNCATE TABLE non_alt_loci_set", conn = txn_conn)

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

        db_execute_statement("SET FOREIGN_KEY_CHECKS = 1", conn = txn_conn)
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
#* Returns the last update dates for various annotation sources based on
#* file modification times in the data directory.
#*
#* # `Return`
#* Returns dates for OMIM (mim2gene), MONDO mappings, and HGNC updates.
#*
#* @tag admin
#* @serializer json list(na="string")
#* @get annotation_dates
function() {
  data_dir <- "data/"

  # Helper to get most recent file date matching a pattern
  get_latest_file_date <- function(pattern) {
    files <- list.files(data_dir, pattern = pattern, full.names = TRUE)
    if (length(files) == 0) {
      return(NA)
    }
    # Get file info and find most recent
    file_info <- file.info(files)
    if (nrow(file_info) == 0) {
      return(NA)
    }
    latest <- files[which.max(file_info$mtime)]
    format(file_info[latest, "mtime"], "%Y-%m-%d %H:%M:%S")
  }

  # Extract date from filename pattern like mim2gene.YYYY-MM-DD.txt
  get_date_from_filename <- function(pattern) {
    files <- list.files(data_dir, pattern = pattern, full.names = FALSE)
    if (length(files) == 0) {
      return(NA)
    }
    # Extract date from filename
    dates <- regmatches(files, regexpr("\\d{4}-\\d{2}-\\d{2}", files))
    if (length(dates) == 0) {
      return(NA)
    }
    max(dates)
  }

  list(
    omim_update = get_date_from_filename("^mim2gene\\..*\\.txt$"),
    mondo_update = get_latest_file_date("^mondo"),
    hgnc_update = get_latest_file_date("^hgnc|^non_alt_loci"),
    disease_ontology_update = get_date_from_filename("^disease_ontology_set\\..*\\.csv$")
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


#* Refresh publication metadata from PubMed
#*
#* Returns immediately with job_id. Poll GET /api/jobs/{job_id} for status.
#* Rate limited to 3 requests/second (NCBI limit without API key).
#*
#* Supports two modes:
#* 1. Explicit PMIDs: Provide a list of PMIDs to refresh
#* 2. Date filter: Provide not_updated_since to refresh all publications not updated since that date
#*
#* # `Request Body`
#* {
#*   "pmids": ["PMID:12345678", "PMID:87654321"],
#*   "not_updated_since": "2024-01-01"
#* }
#*
#* If not_updated_since is provided without pmids, fetches all publications not updated since that date.
#* If both are provided, filters the pmids list to only those not updated since that date.
#*
#* # `Response (202 Accepted)`
#* {
#*   "job_id": "550e8400-e29b-41d4-a716-446655440000",
#*   "status": "accepted",
#*   "estimated_seconds": 30
#* }
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

  # Validate input - at least one PMID required
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
