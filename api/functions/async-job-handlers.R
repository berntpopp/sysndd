.async_job_after_success_noop <- function(result, job, payload, state, worker_config) {
  invisible(result)
}
.async_job_or <- function(value, fallback) {
  if (is.null(value) || length(value) == 0) {
    return(fallback)
  }

  value
}
.async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
  if (!exists("create_async_job_progress_reporter", mode = "function")) {
    stop("create_async_job_progress_reporter() is required for durable async job handlers", call. = FALSE)
  }

  create_async_job_progress_reporter(job_id, throttle_seconds = throttle_seconds)
}
.async_job_payload_field <- function(payload, field, required = TRUE, default = NULL) {
  value <- payload[[field]]

  if (is.null(value)) {
    if (isTRUE(required)) {
      stop(sprintf("Async job payload is missing required field '%s'", field), call. = FALSE)
    }

    return(default)
  }

  value
}
.async_job_payload_scalar <- function(payload, field, required = TRUE, default = NULL) {
  value <- .async_job_payload_field(payload, field, required = required, default = default)

  if (is.null(value)) {
    return(value)
  }

  if (is.list(value)) {
    value <- value[[1]]
  }

  value[[1]]
}

.async_job_add_job_id <- function(payload, job) {
  payload$.__job_id__ <- job$job_id[[1]]
  payload
}

.async_job_functional_categories <- function(clusters, category_links) {
  categories <- clusters |>
    dplyr::select(term_enrichment) |>
    tidyr::unnest(cols = c(term_enrichment)) |>
    dplyr::select(category) |>
    unique() |>
    dplyr::arrange(category) |>
    dplyr::mutate(
      text = dplyr::case_when(
        nchar(category) <= 5 ~ category,
        nchar(category) > 5 ~ stringr::str_to_sentence(category)
      )
    ) |>
    dplyr::select(value = category, text)

  if (!is.null(category_links)) {
    categories <- dplyr::left_join(categories, category_links, by = c("value"))
  }

  categories
}

.async_job_run_clustering <- function(job, payload, state, worker_config) {
  genes <- .async_job_payload_field(payload, "genes")
  algorithm <- .async_job_payload_scalar(payload, "algorithm")
  string_id_table <- .async_job_payload_field(payload, "string_id_table", required = FALSE)
  category_links <- .async_job_payload_field(payload, "category_links", required = FALSE)
  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)

  progress("cluster", "Running functional clustering...", current = 0, total = 1)

  clusters <- gen_string_clust_obj(
    genes,
    algorithm = algorithm,
    string_id_table = string_id_table
  )

  progress("complete", "Functional clustering complete", current = 1, total = 1)

  list(
    clusters = clusters,
    categories = .async_job_functional_categories(clusters, category_links),
    meta = list(
      algorithm = algorithm,
      gene_count = length(genes),
      cluster_count = nrow(clusters)
    )
  )
}

.async_job_chain_llm <- function(result, job, cluster_type) {
  if (!exists("trigger_llm_batch_generation", mode = "function")) {
    return(invisible(result))
  }

  llm_clusters <- result

  if (is.list(result) && "clusters" %in% names(result) && !is.null(result[["clusters"]])) {
    llm_clusters <- result[["clusters"]]
  }

  trigger_llm_batch_generation(
    clusters = llm_clusters,
    cluster_type = cluster_type,
    parent_job_id = job$job_id[[1]]
  )

  invisible(result)
}

.async_job_phenotype_matrix <- function(payload) {
  sysndd_db_phenotypes <- payload$ndd_entity_view_tbl |>
    dplyr::left_join(payload$ndd_review_phenotype_connect_tbl, by = "entity_id") |>
    dplyr::left_join(payload$modifier_list_tbl, by = "modifier_id") |>
    dplyr::left_join(payload$phenotype_list_tbl, by = "phenotype_id") |>
    dplyr::mutate(ndd_phenotype = dplyr::case_when(
      ndd_phenotype == 1 ~ "Yes",
      ndd_phenotype == 0 ~ "No",
      TRUE ~ ndd_phenotype
    )) |>
    dplyr::filter(ndd_phenotype == "Yes") |>
    dplyr::filter(category %in% payload$categories) |>
    dplyr::filter(modifier_name == "present") |>
    dplyr::filter(review_id %in% payload$ndd_entity_review_tbl$review_id) |>
    dplyr::select(
      entity_id, hpo_mode_of_inheritance_term_name, phenotype_id,
      HPO_term, hgnc_id
    ) |>
    dplyr::group_by(entity_id) |>
    dplyr::mutate(
      phenotype_non_id_count = sum(!(phenotype_id %in% payload$id_phenotype_ids)),
      phenotype_id_count = sum(phenotype_id %in% payload$id_phenotype_ids)
    ) |>
    dplyr::ungroup() |>
    unique()

  sysndd_db_phenotypes_wider <- sysndd_db_phenotypes |>
    dplyr::mutate(present = "yes") |>
    dplyr::select(-phenotype_id) |>
    tidyr::pivot_wider(names_from = HPO_term, values_from = present) |>
    dplyr::group_by(hgnc_id) |>
    dplyr::mutate(gene_entity_count = dplyr::n()) |>
    dplyr::ungroup() |>
    dplyr::relocate(gene_entity_count, .after = phenotype_id_count) |>
    dplyr::select(-hgnc_id)

  phenotype_df <- sysndd_db_phenotypes_wider |>
    dplyr::select(-entity_id) |>
    as.data.frame()
  row.names(phenotype_df) <- sysndd_db_phenotypes_wider$entity_id

  phenotype_df
}

.async_job_run_phenotype_clustering <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)

  progress("prepare_matrix", "Preparing phenotype matrix...", current = 0, total = 2)
  phenotype_matrix <- .async_job_phenotype_matrix(payload)
  progress("cluster", "Running phenotype clustering...", current = 1, total = 2)
  phenotype_clusters <- gen_mca_clust_obj(phenotype_matrix)
  progress("complete", "Phenotype clustering complete", current = 2, total = 2)

  identifiers <- payload$ndd_entity_view_tbl |>
    dplyr::select(entity_id, hgnc_id, symbol)

  phenotype_clusters |>
    tidyr::unnest(identifiers) |>
    dplyr::mutate(entity_id = as.integer(entity_id)) |>
    dplyr::left_join(identifiers, by = "entity_id") |>
    tidyr::nest(identifiers = c(entity_id, hgnc_id, symbol))
}

.async_job_run_ontology_update <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]])

  progress("init", "Preparing ontology update", current = 0, total = 4)
  disease_ontology_set <- process_combine_ontology(
    hgnc_list = payload$hgnc_list,
    mode_of_inheritance_list = payload$mode_of_inheritance_list,
    max_file_age = 0,
    output_path = "data/",
    progress_callback = progress
  )
  progress("complete", "Ontology update complete", current = 4, total = 4)

  list(
    status = "completed",
    rows_processed = nrow(disease_ontology_set),
    sources = c("MONDO", "OMIM"),
    output_file = paste0("data/disease_ontology_set.", format(Sys.Date(), "%Y-%m-%d"), ".csv")
  )
}

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

.async_job_run_passthrough <- function(fn_name) {
  force(fn_name)

  function(job, payload, state, worker_config) {
    fn <- base::get(fn_name, mode = "function")
    fn(.async_job_add_job_id(payload, job))
  }
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

.async_job_run_backup_create <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]])

  output_path <- file.path(payload$backup_dir, payload$backup_filename)
  result <- execute_mysqldump(
    payload$db_config,
    output_path,
    progress_fn = progress,
    compress = TRUE,
    create_latest_link = TRUE
  )

  if (!isTRUE(result$success)) {
    stop(paste("Backup failed:", result$error), call. = FALSE)
  }

  list(
    status = "completed",
    filename = basename(result$file),
    size_bytes = result$size_bytes,
    compressed = result$compressed
  )
}

.async_job_run_backup_restore <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]])

  progress("pre_backup", "Creating pre-restore safety backup...", 1, 4)
  pre_restore_filename <- sprintf("pre-restore_%s.sql", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"))
  pre_restore_path <- file.path(payload$backup_dir, pre_restore_filename)

  pre_result <- execute_mysqldump(
    payload$db_config,
    pre_restore_path,
    progress_fn = NULL,
    compress = TRUE,
    create_latest_link = FALSE
  )

  if (!isTRUE(pre_result$success)) {
    stop(
      paste("Pre-restore backup failed - cannot proceed with restore:", pre_result$error),
      call. = FALSE
    )
  }

  progress(
    "pre_backup_done",
    sprintf("Pre-restore backup created (%.1f MB)", pre_result$size_bytes / 1024 / 1024),
    2, 4
  )
  progress("restoring", sprintf("Restoring from %s...", basename(payload$restore_file)), 3, 4)

  restore_result <- execute_restore(
    payload$db_config,
    payload$restore_file,
    progress_fn = NULL
  )

  if (!isTRUE(restore_result$success)) {
    stop(
      paste(
        "Restore failed:",
        restore_result$error,
        "- pre-restore backup available at:",
        basename(pre_result$file)
      ),
      call. = FALSE
    )
  }

  progress("complete", "Restore completed successfully", 4, 4)

  list(
    status = "completed",
    pre_restore_backup = basename(pre_result$file),
    restored_from = basename(payload$restore_file)
  )
}

.async_job_omim_db_write <- function(disease_ontology_set_update, safeguard, db_config) {
  sysndd_db <- DBI::dbConnect(
    RMariaDB::MariaDB(),
    dbname = db_config$dbname,
    user = db_config$user,
    password = db_config$password,
    server = db_config$server,
    host = db_config$host,
    port = db_config$port
  )
  on.exit(DBI::dbDisconnect(sysndd_db), add = TRUE)

  refresh_result <- refresh_disease_ontology_set(
    conn = sysndd_db,
    disease_ontology_set_update = disease_ontology_set_update,
    auto_fixes = safeguard$auto_fixes
  )

  refresh_result$auto_fixes_applied
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
    safeguard = safeguard,
    db_config = payload$db_config
  )

  list(
    status = "success",
    rows_written = nrow(disease_ontology_set_update),
    auto_fixes_applied = auto_fixes_applied,
    total_affected = safeguard$summary$total_affected
  )
}

.async_job_force_apply_auto_fixes <- function(auto_fixes_raw) {
  if (length(auto_fixes_raw) == 0) {
    return(tibble::tibble(old_version = character(0), new_version = character(0)))
  }

  tibble::tibble(
    old_version = vapply(
      auto_fixes_raw,
      function(x) as.character(.async_job_or(x$old_version, x$old_version[[1]])),
      character(1)
    ),
    new_version = vapply(
      auto_fixes_raw,
      function(x) as.character(.async_job_or(x$new_version, x$new_version[[1]])),
      character(1)
    )
  )
}

.async_job_force_apply_critical_versions <- function(critical_entities_raw) {
  if (length(critical_entities_raw) == 0) {
    return(character(0))
  }

  vapply(
    critical_entities_raw,
    function(x) {
      value <- x$disease_ontology_id_version
      if (is.list(value)) value[[1]] else value
    },
    character(1)
  )
}

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

  sysndd_db <- DBI::dbConnect(
    RMariaDB::MariaDB(),
    dbname = payload$db_config$dbname,
    user = payload$db_config$user,
    password = payload$db_config$password,
    server = payload$db_config$server,
    host = payload$db_config$host,
    port = payload$db_config$port
  )
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

.async_job_run_publication_refresh <- function(job, payload, state, worker_config) {
  reporter <- .async_job_progress_reporter(job$job_id[[1]])
  pmids <- payload$pmids
  total <- length(pmids)
  results <- vector("list", total)

  sysndd_db <- DBI::dbConnect(
    RMariaDB::MariaDB(),
    dbname = payload$db_config$dbname,
    user = payload$db_config$user,
    password = payload$db_config$password,
    host = payload$db_config$host,
    port = payload$db_config$port
  )
  on.exit(DBI::dbDisconnect(sysndd_db), add = TRUE)

  for (i in seq_along(pmids)) {
    pmid <- pmids[i]
    reporter("fetch", sprintf("Fetching %s (%d/%d)", pmid, i, total), current = i, total = total)

    results[[i]] <- tryCatch(
      {
        info <- info_from_pmid(pmid)
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
      },
      error = function(e) {
        list(
          pmid = pmid,
          status = "error",
          error = conditionMessage(e)
        )
      }
    )

    if (i < total) {
      Sys.sleep(0.35)
    }
  }

  list(
    total = total,
    success = sum(vapply(results, function(r) identical(r$status, "updated"), logical(1))),
    failed = sum(vapply(results, function(r) identical(r$status, "error"), logical(1))),
    not_found = sum(vapply(results, function(r) identical(r$status, "not_found"), logical(1))),
    results = results
  )
}

async_job_handler_registry <- list(
  clustering = list(
    cancel_mode = "best_effort",
    run = .async_job_run_clustering,
    after_success = function(result, job, payload, state, worker_config) {
      .async_job_chain_llm(result, job, cluster_type = "functional")
    }
  ),
  phenotype_clustering = list(
    cancel_mode = "best_effort",
    run = .async_job_run_phenotype_clustering,
    after_success = function(result, job, payload, state, worker_config) {
      .async_job_chain_llm(result, job, cluster_type = "phenotype")
    }
  ),
  ontology_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_ontology_update,
    after_success = .async_job_after_success_noop
  ),
  hgnc_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_hgnc_update,
    after_success = .async_job_after_success_noop
  ),
  comparisons_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_passthrough("comparisons_update_async"),
    after_success = .async_job_after_success_noop
  ),
  pubtator_update = list(
    cancel_mode = "best_effort",
    run = .async_job_run_pubtator,
    after_success = .async_job_after_success_noop
  ),
  nddscore_import = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_nddscore_import,
    after_success = .async_job_after_success_noop
  ),
  llm_generation = list(
    cancel_mode = "best_effort",
    run = .async_job_run_passthrough("llm_batch_executor"),
    after_success = .async_job_after_success_noop
  ),
  network_layout_prewarm = list(
    cancel_mode = "best_effort",
    run = function(...) .async_job_run_network_layout_prewarm(...),
    after_success = .async_job_after_success_noop
  ),
  backup_create = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_backup_create,
    after_success = .async_job_after_success_noop
  ),
  backup_restore = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_backup_restore,
    after_success = .async_job_after_success_noop
  ),
  omim_update = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_omim_update,
    after_success = .async_job_after_success_noop
  ),
  force_apply_ontology = list(
    cancel_mode = "non_interruptible",
    run = .async_job_run_force_apply_ontology,
    after_success = .async_job_after_success_noop
  ),
  publication_refresh = list(
    cancel_mode = "best_effort",
    run = .async_job_run_publication_refresh,
    after_success = .async_job_after_success_noop
  )
)

#' Resolve a durable async job handler definition
#' @param job_type Character async job type.
#' @param registry Named handler registry.
#'
#' @return Registry entry with run/cancel metadata.
#' @export
async_job_get_handler <- function(job_type, registry = async_job_handler_registry) {
  entry <- registry[[job_type]]

  if (is.null(entry)) {
    stop(sprintf("No durable async job handler registered for '%s'", job_type), call. = FALSE)
  }

  if (!is.function(entry$run)) {
    stop(sprintf("Handler registry entry for '%s' is missing a callable run function", job_type), call. = FALSE)
  }

  if (is.null(entry$after_success)) {
    entry$after_success <- .async_job_after_success_noop
  }

  entry
}
