# api/services/admin-ontology-endpoint-service.R
#
# Service layer for the Administrator ontology/HGNC/deprecated-entity family
# extracted from api/endpoints/admin_endpoints.R (issue #346, Wave 3).
#
# Endpoint shells keep their `require_role(req, res, "Administrator")` gate,
# route decorators, and formals byte-identical; the route bodies below are
# unchanged logic, only relocated. `force_apply_ontology`'s cheap
# `blocked_job_id` presence guard and the final `create_job()` submission stay
# inline in the endpoint (test-endpoint-admin.R asserts those substrings
# directly against admin_endpoints.R's source); this service supplies the
# heavier blocked-job lookup/validation between them.
#
# All DB-facing calls accept their collaborator as an injectable parameter
# (default = the real global function) so unit tests can supply fakes without
# a live database; see test-unit-admin-endpoint-services.R.

#' PUT /admin/update_ontology_async body.
#'
#' Pre-fetches the tables the daemon worker cannot reach directly, then
#' submits (or returns the existing) `omim_update` durable job.
#'
#' @export
svc_admin_ontology_update_async <- function(req, res, pool,
                                             duplicate_check_fn = check_active_job_by_type,
                                             create_job_fn = create_job) {
  mode_of_inheritance_list <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    dplyr::select(-is_active, -sort) %>%
    collect()

  non_alt_loci_set <- pool %>%
    tbl("non_alt_loci_set") %>%
    dplyr::select(hgnc_id, symbol) %>%
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

  dup_check <- duplicate_check_fn("omim_update", list())
  if (dup_check$duplicate) {
    return(list(
      job_id = dup_check$existing_job_id,
      status = "already_running",
      message = "An OMIM update job is already running"
    ))
  }

  result <- create_job_fn(
    operation = "omim_update",
    params = list(
      mode_of_inheritance_list = mode_of_inheritance_list,
      non_alt_loci_set = non_alt_loci_set,
      ndd_entity_view = ndd_entity_view,
      disease_ontology_set_current = disease_ontology_set_current,
      ndd_entity = ndd_entity
    )
  )

  res$status <- 202
  result
}

#' Validate + prepare a blocked ontology update for force-apply.
#'
#' Looks up the blocked job (full result mode is REQUIRED: summary mode omits
#' the parsed result_json, which would make every "was it blocked?" check
#' below fail with a false 409), checks the pending CSV exists and is not
#' stale (>48h), and assembles the `force_apply_ontology` job params.
#'
#' @return List with either `early_return` (a body the caller must return
#'   as-is, with `res$status` already set) or `params` (ready for
#'   `create_job(operation = "force_apply_ontology", params = ...)`).
#' @export
svc_admin_force_apply_ontology_prepare <- function(req, res, blocked_job_id, assigned_user_id,
                                                     pool, job_status_fn = get_job_status) {
  assigned_user_id <- if (!is.null(assigned_user_id) && assigned_user_id != "") {
    as.integer(assigned_user_id)
  } else {
    NULL
  }

  blocked_job <- job_status_fn(blocked_job_id, result_mode = "full")

  if (!is.null(blocked_job$error) && blocked_job$error == "JOB_NOT_FOUND") {
    res$status <- 404L
    return(list(early_return = list(error = "Blocked job not found", job_id = blocked_job_id)))
  }

  if (blocked_job$status != "completed") {
    res$status <- 409L
    return(list(early_return = list(
      error = "Job is not in completed state",
      job_status = blocked_job$status
    )))
  }

  job_result <- blocked_job$result
  result_status <- if (is.list(job_result$status)) {
    job_result$status[[1]]
  } else {
    job_result$status
  }
  if (is.null(result_status) || result_status != "blocked") {
    res$status <- 409L
    return(list(early_return = list(
      error = "Referenced job was not blocked",
      result_status = result_status
    )))
  }

  csv_path <- if (is.list(job_result$pending_csv_path)) {
    job_result$pending_csv_path[[1]]
  } else {
    job_result$pending_csv_path
  }
  if (is.null(csv_path) || !file.exists(csv_path)) {
    res$status <- 410L
    return(list(early_return = list(
      error = "Pending ontology CSV not found (may have expired)",
      path = csv_path
    )))
  }

  csv_age_hours <- as.numeric(
    difftime(Sys.time(), file.info(csv_path)$mtime, units = "hours")
  )
  if (csv_age_hours > 48) {
    res$status <- 410L
    return(list(early_return = list(
      error = "Pending ontology update is stale (>48 hours). Re-run the update.",
      age_hours = round(csv_age_hours, 1)
    )))
  }

  requesting_user_id <- if (!is.null(assigned_user_id)) assigned_user_id else req$user_id

  ndd_entity_view <- pool %>%
    tbl("ndd_entity_view") %>%
    collect()

  disease_ontology_set_current <- pool %>%
    tbl("disease_ontology_set") %>%
    collect()

  list(
    early_return = NULL,
    params = list(
      csv_path = csv_path,
      auto_fixes_raw = job_result$auto_fixes,
      critical_entities_raw = job_result$critical_entities,
      disease_ontology_set_current = disease_ontology_set_current,
      ndd_entity_view = ndd_entity_view,
      requesting_user_id = requesting_user_id
    )
  )
}

#' PUT /admin/update_hgnc_data body.
#'
#' Downloads + processes HGNC data, then atomically replaces
#' `non_alt_loci_set` inside a transaction with FK checks disabled for the
#' bulk delete+reinsert.
#'
#' @export
svc_admin_hgnc_update <- function(req, res,
                                   fetch_hgnc_fn = update_process_hgnc_data,
                                   transaction_fn = db_with_transaction,
                                   fk_guard_fn = metadata_with_foreign_key_checks_disabled,
                                   execute_fn = db_execute_statement) {
  hgnc_data <- fetch_hgnc_fn()

  tryCatch(
    {
      transaction_fn(function(txn_conn) {
        fk_guard_fn(txn_conn, function() {
          execute_fn("DELETE FROM non_alt_loci_set", conn = txn_conn)

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
              row_values <- unname(as.list(hgnc_data[i, ]))
              execute_fn(sql, row_values, conn = txn_conn)
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

#' GET /admin/deprecated_entities body.
#'
#' Cross-references the latest mim2gene.txt "moved/removed" MIM numbers
#' against curated entities, enriching hits with MONDO deprecation info from
#' EBI OLS4.
#'
#' @export
svc_admin_deprecated_entities <- function(req, res, pool, data_dir = "data/",
                                           mim2gene_fn = parse_mim2gene,
                                           deprecated_mims_fn = get_deprecated_mim_numbers,
                                           check_entities_fn = check_entities_for_deprecation,
                                           mondo_info_fn = ols_get_deprecated_omim_info_batch) {
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

  file_info <- file.info(mim2gene_files)
  latest_file <- mim2gene_files[which.max(file_info$mtime)]

  mim2gene_date <- regmatches(
    basename(latest_file), regexpr("\\d{4}-\\d{2}-\\d{2}", basename(latest_file))
  )
  if (length(mim2gene_date) == 0) mim2gene_date <- NA

  tryCatch(
    {
      mim2gene_data <- mim2gene_fn(latest_file, include_moved_removed = TRUE)
      deprecated_mims <- deprecated_mims_fn(mim2gene_data)

      if (length(deprecated_mims) == 0) {
        return(list(
          deprecated_count = 0,
          affected_entity_count = 0,
          affected_entities = list(),
          mim2gene_date = mim2gene_date,
          message = "No deprecated MIM numbers found."
        ))
      }

      affected <- check_entities_fn(pool, deprecated_mims)

      if (nrow(affected) == 0) {
        return(list(
          deprecated_count = length(deprecated_mims),
          affected_entity_count = 0,
          affected_entities = list(),
          mim2gene_date = mim2gene_date,
          message = "No entities affected by deprecated OMIM IDs."
        ))
      }

      unique_omim_ids <- unique(affected$disease_ontology_id)
      mondo_info_map <- mondo_info_fn(unique_omim_ids)

      affected_enriched <- svc_admin_enrich_deprecated_entities(affected, mondo_info_map)

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

#' Enrich affected-entity rows with per-OMIM-ID MONDO deprecation info.
#' @keywords internal
svc_admin_enrich_deprecated_entities <- function(affected, mondo_info_map) {
  affected %>%
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
}
