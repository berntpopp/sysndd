# api/functions/async-job-provider-handlers.R
#
# Durable async job handlers for external-provider-backed refresh families:
# HGNC, PubTator/PubTatorNDD, NDDScore import, disease-ontology mapping
# refresh, OMIM ontology update, and the OMIM force-apply write path.
#
# Worker-executed code (#346 Wave 4 split of async-job-handlers.R). The
# `async_job_handler_registry` list in functions/async-job-handlers.R
# references these handler functions by bare symbol, and R evaluates a
# list() literal's elements eagerly at construction time — so this file
# MUST be sourced BEFORE functions/async-job-handlers.R at every worker
# entrypoint (API bootstrap does not need it; the API never dispatches
# handlers, only submits jobs). It also depends on
# functions/async-job-omim-apply.R (.async_job_omim_db_write,
# apply_additive_terms_on_block) and
# functions/async-job-force-apply-payload.R
# (.async_job_force_apply_auto_fixes / _critical_versions), which are
# resolved lazily at call time, not source time, so their relative order to
# this file does not matter functionally — but keep them sourced nearby for
# readability.

.async_job_hgnc_write_db <- function(hgnc_data, db_config, job_id) {
  conn <- DBI::dbConnect(
    RMariaDB::MariaDB(),
    dbname = db_config$dbname,
    host = db_config$host,
    user = db_config$user,
    password = db_config$password,
    port = db_config$port
  )
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  db_cols <- DBI::dbListFields(conn, "non_alt_loci_set")
  tibble_cols <- colnames(hgnc_data)
  extra_cols <- setdiff(tibble_cols, db_cols)

  if (length(extra_cols) > 0) {
    message(sprintf(
      "[%s] [job:%s] Dropping %d tibble columns not in DB: %s",
      Sys.time(), job_id, length(extra_cols), paste(extra_cols, collapse = ", ")
    ))
    hgnc_data <- hgnc_data[, setdiff(tibble_cols, extra_cols), drop = FALSE]
  }

  missing_cols <- setdiff(db_cols, colnames(hgnc_data))
  if (length(missing_cols) > 0) {
    message(sprintf(
      "[%s] [job:%s] DB columns not in tibble (will be NULL): %s",
      Sys.time(), job_id, paste(missing_cols, collapse = ", ")
    ))
  }

  tryCatch(
    {
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")
      on.exit(tryCatch(DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 1"), error = function(e) NULL), add = TRUE)

      DBI::dbWithTransaction(conn, {
        DBI::dbExecute(conn, "DELETE FROM non_alt_loci_set")
        if (nrow(hgnc_data) > 0) {
          DBI::dbAppendTable(conn, "non_alt_loci_set", hgnc_data)
        }
      })

      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 1")
    },
    error = function(e) {
      stop(sprintf(
        "Database write failed: %s. Tibble cols: [%s]. DB cols: [%s].",
        conditionMessage(e),
        paste(colnames(hgnc_data), collapse = ", "),
        paste(db_cols, collapse = ", ")
      ), call. = FALSE)
    }
  )

  list(
    rows_processed = nrow(hgnc_data),
    columns_written = ncol(hgnc_data),
    columns_dropped = length(extra_cols),
    gnomad_fallback_recovered = as.integer(
      attr(hgnc_data, "fallback_recovered", exact = TRUE) %||% 0L
    ),
    gnomad_fallback_unresolved = as.integer(
      attr(hgnc_data, "fallback_unresolved", exact = TRUE) %||% 0L
    )
  )
}

.async_job_run_hgnc_update <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]])
  hgnc_data <- update_process_hgnc_data(progress_fn = progress)
  progress("db_write", "Writing to database...", current = 9, total = 9)

  write_result <- .async_job_hgnc_write_db(
    hgnc_data = hgnc_data,
    db_config = payload$db_config,
    job_id = job$job_id[[1]]
  )

  list(
    status = "completed",
    rows_processed = write_result$rows_processed,
    columns_written = write_result$columns_written,
    columns_dropped = write_result$columns_dropped,
    gnomad_fallback_recovered = write_result$gnomad_fallback_recovered,
    gnomad_fallback_unresolved = write_result$gnomad_fallback_unresolved,
    message = "HGNC data updated and written to database successfully"
  )
}

.async_job_run_pubtator <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]])
  progress("init", "Initializing PubTator fetch...", current = 0, total = payload$max_pages)

  result <- pubtator_db_update_async(
    db_config = payload$db_config,
    query = payload$query,
    max_pages = payload$max_pages,
    do_full_update = payload$clear_old,
    progress_fn = progress
  )

  progress("complete", "PubTator fetch complete", current = payload$max_pages, total = payload$max_pages)

  list(
    status = "completed",
    success = result$success,
    query_id = result$query_id,
    query = payload$query,
    pages_cached = result$pages_cached,
    pages_total = result$pages_total,
    publications_count = result$publications_count,
    message = result$message
  )
}

.async_job_ensure_nddscore_import_loaded <- function() {
  if (exists("nddscore_run_import", mode = "function")) {
    return(invisible(TRUE))
  }

  candidates <- c(
    "functions/nddscore-import.R",
    "/app/functions/nddscore-import.R"
  )

  for (path in candidates) {
    if (file.exists(path)) {
      source(path, local = FALSE)
      return(invisible(TRUE))
    }
  }

  stop("NDDScore import functions are not loaded", call. = FALSE)
}

.async_job_run_nddscore_import <- function(job, payload, state, worker_config) {
  .async_job_ensure_nddscore_import_loaded()

  record_id <- .async_job_payload_scalar(payload, "record_id")
  validate_only <- isTRUE(.async_job_payload_scalar(
    payload,
    "validate_only",
    required = FALSE,
    default = FALSE
  ))
  imported_by <- .async_job_payload_scalar(
    payload,
    "imported_by",
    required = FALSE,
    default = NULL
  )
  if (is.null(imported_by) && !is.null(job$submitted_by) && !is.na(job$submitted_by[[1]])) {
    imported_by <- job$submitted_by[[1]]
  }
  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)

  if (!base::exists("pool", envir = .GlobalEnv, inherits = FALSE)) {
    stop("NDDScore import requires the global database pool", call. = FALSE)
  }

  db_pool <- base::get("pool", envir = .GlobalEnv, inherits = FALSE)
  conn <- pool::poolCheckout(db_pool)
  conn_checked_out <- TRUE
  lock_acquired <- FALSE
  on.exit({
    if (isTRUE(lock_acquired)) {
      tryCatch(nddscore_release_import_lock(conn), error = function(e) NULL)
    }
    if (isTRUE(conn_checked_out)) {
      pool::poolReturn(conn)
    }
  }, add = TRUE)

  nddscore_acquire_import_lock(conn)
  lock_acquired <- TRUE

  tryCatch(
    {
      nddscore_run_import(
        conn = conn,
        record_id = record_id,
        validate_only = validate_only,
        imported_by = imported_by,
        job_id = job$job_id[[1]],
        deps = list(
          fetch_metadata = nddscore_fetch_zenodo_metadata,
          download = nddscore_download_archive
        ),
        progress = progress
      )
    },
    error = function(e) {
      stop(e)
    }
  )
}

.async_job_run_pubtator_enrichment <- function(job, payload, state, worker_config) {
  pubtator_enrichment_job_run(job, .async_job_progress_reporter)
}

.async_job_run_pubtatornidd_nightly <- function(job, payload, state, worker_config) {
  pubtatornidd_nightly_job_run(job, payload, .async_job_progress_reporter)
}

.async_job_run_disease_ontology_mapping_refresh <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]])
  disease_ontology_mapping_refresh_run(job, payload, progress)
}

#' Re-trigger a forced disease-ontology mapping refresh after a successful
#' ontology-set refresh (correction #2).
#'
#' `refresh_disease_ontology_set()` rewrites `disease_ontology_set` (DELETE +
#' re-append) and does not rebuild the cross-ontology projection columns or the
#' normalized `disease_ontology_mapping` rows, so a successful ontology refresh
#' leaves the new mapping columns blank and the normalized rows pointing at base
#' ids that may have changed. Enqueueing a forced mapping refresh heals it.
#'
#' Best-effort: a submission hiccup must NOT fail the ontology refresh, so this
#' is wrapped in tryCatch and only logs on error.
#' @keywords internal
.async_job_chain_ontology_mapping_refresh <- function() {
  if (!exists("service_disease_ontology_mapping_submit_refresh", mode = "function")) {
    return(invisible(NULL))
  }
  tryCatch(
    {
      outcome <- service_disease_ontology_mapping_submit_refresh(force = TRUE)
      message(sprintf(
        "[ontology-mapping-chain] forced mapping refresh after ontology-set refresh (job_id=%s)",
        tryCatch(outcome$job_id, error = function(e) NA_character_)
      ))
    },
    error = function(e) {
      message(sprintf(
        "[ontology-mapping-chain] could not enqueue mapping refresh (non-fatal): %s",
        conditionMessage(e)
      ))
    }
  )
  invisible(NULL)
}

.async_job_run_omim_update <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
  progress("prepare", "Processing OMIM ontology update...", 0, 5)

  disease_ontology_set_update <- process_combine_ontology(
    hgnc_list = payload$non_alt_loci_set,
    mode_of_inheritance_list = payload$mode_of_inheritance_list,
    max_file_age = 0,
    output_path = "data/",
    progress_callback = progress
  )

  progress("validate", "Validating ontology update...", 4, 5)
  validation <- validate_omim_data(disease_ontology_set_update)
  if (!isTRUE(validation$valid)) {
    stop(paste("Validation failed:", paste(validation$errors, collapse = "; ")), call. = FALSE)
  }

  ndd_entity_view_ontology_set <- payload$ndd_entity_view |>
    dplyr::select(entity_id, disease_ontology_id_version, disease_ontology_name)
  safeguard <- identify_critical_ontology_changes(
    disease_ontology_set_update,
    payload$disease_ontology_set_current,
    ndd_entity_view_ontology_set
  )

  if (safeguard$summary$truly_critical > 0) {
    pending_dir <- "data/pending_ontology/"
    if (!dir.exists(pending_dir)) {
      dir.create(pending_dir, recursive = TRUE)
    }
    csv_path <- paste0(
      pending_dir,
      "pending_ontology_update.",
      format(Sys.Date(), "%Y-%m-%d"),
      ".csv"
    )
    readr::write_csv(disease_ontology_set_update, file = csv_path, na = "NULL")

    additive <- apply_additive_terms_on_block(payload, disease_ontology_set_update)

    progress("blocked", "Critical ontology changes require manual review", 5, 5)

    return(list(
      status = "blocked",
      message = paste0(
        "Ontology update blocked: ", safeguard$summary$truly_critical,
        " critical entity-referenced changes detected. Review and use Force Apply to proceed."
      ),
      pending_csv_path = csv_path,
      critical_count = safeguard$summary$truly_critical,
      auto_fixable_count = safeguard$summary$auto_fixable,
      total_affected = safeguard$summary$total_affected,
      additive_applied = additive$applied,
      additive_error = additive$error,
      critical_entities = safeguard$critical |>
        dplyr::select(
          disease_ontology_id_version,
          disease_ontology_name,
          hgnc_id,
          hpo_mode_of_inheritance_term
        ) |>
        as.list() |>
        purrr::transpose(),
      auto_fixes = if (nrow(safeguard$auto_fixes) > 0) {
        safeguard$auto_fixes |>
          as.list() |>
          purrr::transpose()
      } else {
        list()
      }
    ))
  }

  progress("write", "Writing ontology update to the database...", 5, 5)
  auto_fixes_applied <- .async_job_omim_db_write(
    disease_ontology_set_update = disease_ontology_set_update,
    safeguard = safeguard
  )

  list(
    status = "success",
    rows_written = nrow(disease_ontology_set_update),
    auto_fixes_applied = auto_fixes_applied,
    total_affected = safeguard$summary$total_affected
  )
}

# Force-apply payload-shape helpers (.async_job_force_apply_table /
# _auto_fixes / _critical_versions) live in
# functions/async-job-force-apply-payload.R, sourced before this file at every
# worker entrypoint. Keeping them out of this file avoids growing it past the
# AGENTS.md soft ceiling.

.async_job_run_force_apply_ontology <- function(job, payload, state, worker_config) {
  disease_ontology_set_update <- readr::read_csv(
    payload$csv_path,
    na = "NULL",
    show_col_types = FALSE
  )

  auto_fixes <- .async_job_force_apply_auto_fixes(payload$auto_fixes_raw)
  critical_versions <- .async_job_force_apply_critical_versions(payload$critical_entities_raw)

  critical_entity_ids <- if (length(critical_versions) > 0) {
    payload$ndd_entity_view |>
      dplyr::filter(disease_ontology_id_version %in% critical_versions) |>
      dplyr::pull(entity_id) |>
      unique()
  } else {
    integer(0)
  }

  compatibility_rows <- if (length(critical_versions) > 0) {
    payload$disease_ontology_set_current |>
      dplyr::filter(disease_ontology_id_version %in% critical_versions) |>
      dplyr::mutate(is_active = FALSE)
  } else {
    tibble::tibble()
  }

  # Resolve DB creds from the worker runtime config at run time (#535 S2b).
  sysndd_db <- async_job_db_connect()
  on.exit(DBI::dbDisconnect(sysndd_db), add = TRUE)

  result <- tryCatch(
    {
      refresh_result <- refresh_disease_ontology_set(
        conn = sysndd_db,
        disease_ontology_set_update = disease_ontology_set_update,
        auto_fixes = auto_fixes,
        compatibility_rows = compatibility_rows
      )

      auto_fixes_applied <- refresh_result$auto_fixes_applied
      compat_count <- refresh_result$compatibility_rows

      # Correction #2: the disease set changed, so rebuild the cross-ontology
      # mappings (best-effort; never fails the force-apply).
      .async_job_chain_ontology_mapping_refresh()

      re_review_batch_id <- NULL
      if (length(critical_entity_ids) > 0 && exists("batch_create", mode = "function")) {
        tryCatch(
          {
            batch_result <- batch_create(
              criteria = list(entity_ids = critical_entity_ids),
              assigned_user_id = payload$requesting_user_id,
              batch_name = paste0("Ontology Update Review - ", format(Sys.Date(), "%Y-%m-%d")),
              pool = sysndd_db
            )
            if (identical(batch_result$status, 200)) {
              re_review_batch_id <- batch_result$entry$batch_id
            }
          },
          error = function(e) {
            warning(
              paste("Re-review batch creation failed (non-fatal):", conditionMessage(e)),
              call. = FALSE
            )
          }
        )
      }

      tryCatch(file.remove(payload$csv_path), error = function(e) NULL)

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
      stop(paste("Force-apply failed:", conditionMessage(e)), call. = FALSE)
    }
  )

  result
}
