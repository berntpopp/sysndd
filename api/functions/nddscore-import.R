# NDDScore importer - pure, unit-testable functions.
# Fetch / download / verify / extract / parse / load / validate a Zenodo release.
# No DB writes here; no secrets are logged. See db/migrations/023 for the target schema.

`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0) {
    b
  } else {
    a
  }
}

.NDDSCORE_DEFAULT_ZENODO_API_BASE_URL <- "https://zenodo.org/api/records"
.NDDSCORE_DEFAULT_ZENODO_RECORD_ID <- "20258027"

.nddscore_config <- function(config = NULL) {
  if (!is.null(config)) {
    return(config)
  }

  tryCatch(
    {
      config_name <- Sys.getenv("API_CONFIG", "")
      if (nzchar(config_name)) {
        return(config::get(config_name))
      }
      config::get()
    },
    error = function(e) {
      list()
    }
  )
}

.nddscore_config_scalar <- function(config, name, default) {
  value <- config[[name]]
  if (is.null(value) || length(value) == 0L) {
    return(default)
  }

  value <- trimws(as.character(value[[1]]))
  if (!nzchar(value)) {
    return(default)
  }
  value
}

nddscore_zenodo_api_base_url <- function(config = NULL) {
  env_value <- trimws(Sys.getenv("NDDSCORE_ZENODO_API_BASE_URL", ""))
  if (nzchar(env_value)) {
    return(sub("/+$", "", env_value))
  }

  config_value <- .nddscore_config_scalar(
    .nddscore_config(config),
    "nddscore_zenodo_api_base_url",
    .NDDSCORE_DEFAULT_ZENODO_API_BASE_URL
  )
  sub("/+$", "", config_value)
}

nddscore_default_zenodo_record_id <- function(config = NULL) {
  env_value <- trimws(Sys.getenv("NDDSCORE_ZENODO_RECORD_ID", ""))
  if (nzchar(env_value)) {
    return(env_value)
  }

  .nddscore_config_scalar(
    .nddscore_config(config),
    "nddscore_zenodo_record_id",
    .NDDSCORE_DEFAULT_ZENODO_RECORD_ID
  )
}

#' Default HTTP JSON GET used by nddscore_fetch_zenodo_metadata.
#' Separated out so tests inject a stub instead.
.nddscore_http_get_json <- function(url) {
  resp <- httr2::request(url) |>
    httr2::req_retry(
      max_tries = 4,
      is_transient = ~ httr2::resp_status(.x) %in% c(429, 503, 504)
    ) |>
    httr2::req_timeout(30) |>
    httr2::req_perform()
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}

#' Fetch Zenodo record metadata and locate the release archive file entry.
#'
#' @param record_id Zenodo numeric record id (string or numeric).
#' @param api_base_url Base URL for Zenodo record API requests.
#' @param http_get Function(url) returning the parsed record JSON as a list.
#' @return Named list: record_id, record_url, version, version_doi, concept_doi,
#'   archive_name, archive_bytes, archive_md5, content_url.
nddscore_fetch_zenodo_metadata <- function(
    record_id = nddscore_default_zenodo_record_id(),
    api_base_url = nddscore_zenodo_api_base_url(),
    http_get = .nddscore_http_get_json) {
  record_id <- as.character(record_id)[[1]]
  api_base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
  url <- paste0(api_base_url, "/", record_id)
  record <- http_get(url)

  files <- record$files
  if (is.null(files) || length(files) == 0) {
    stop(
      "Zenodo record has no files; cannot locate NDDScore archive",
      call. = FALSE
    )
  }

  is_archive <- vapply(files, function(f) {
    grepl("\\.tar\\.gz$", f$key %||% "", ignore.case = TRUE)
  }, logical(1))
  if (!any(is_archive)) {
    stop("Zenodo record contains no .tar.gz archive file entry", call. = FALSE)
  }
  entry <- files[is_archive][[1]]

  checksum <- entry$checksum %||% ""
  archive_md5 <- sub("^md5:", "", checksum)

  list(
    record_id = record_id,
    record_url = record$links$self_html %||%
      paste0("https://zenodo.org/records/", record_id),
    version = record$metadata$version %||% NA_character_,
    version_doi = record$doi %||% NA_character_,
    concept_doi = record$conceptdoi %||% NA_character_,
    archive_name = entry$key,
    archive_bytes = as.numeric(entry$size %||% NA),
    archive_md5 = archive_md5,
    content_url = entry$links$self
  )
}

#' Verify a downloaded archive against the Zenodo-published MD5.
#' @return TRUE on match; stops with a clear error on mismatch.
nddscore_verify_archive_checksum <- function(path, expected_md5) {
  if (!file.exists(path)) {
    stop("NDDScore archive not found for checksum verification", call. = FALSE)
  }
  actual <- digest::digest(file = path, algo = "md5")
  expected <- tolower(sub("^md5:", "", expected_md5 %||% ""))
  if (!identical(tolower(actual), expected)) {
    stop(sprintf(
      "NDDScore archive checksum mismatch (expected %s, got %s)",
      expected, actual
    ), call. = FALSE)
  }
  TRUE
}

#' Default binary downloader; tests inject a stub.
.nddscore_http_download <- function(url, destfile) {
  resp <- httr2::request(url) |>
    httr2::req_retry(max_tries = 4) |>
    httr2::req_timeout(300) |>
    httr2::req_perform(path = destfile)
  invisible(destfile)
}

#' Download the release archive to a destination path.
#' @return The destination path.
nddscore_download_archive <- function(
    url,
    dest,
    http_download = .nddscore_http_download) {
  if (is.null(url) || !nzchar(url)) {
    stop("NDDScore archive download URL is missing", call. = FALSE)
  }
  http_download(url, dest)
  if (!file.exists(dest) || file.size(dest) == 0) {
    stop("NDDScore archive download produced an empty file", call. = FALSE)
  }
  dest
}

#' Extract the release archive and verify the bundled inner checksums.sha256.
#'
#' @param archive_path Path to the .tar.gz.
#' @param exdir Optional extraction directory (defaults to a fresh temp dir).
#' @return Path to the `sysndd_prediction_release` directory inside the extraction.
nddscore_extract_and_verify <- function(archive_path, exdir = NULL) {
  if (is.null(exdir)) {
    exdir <- file.path(tempdir(), paste0("ndd_extract_", as.integer(runif(1, 1, 1e9))))
  }
  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
  utils::untar(archive_path, exdir = exdir)

  rel_candidates <- list.files(exdir, pattern = "^sysndd_prediction_release$",
                               recursive = TRUE, include.dirs = TRUE,
                               full.names = TRUE)
  if (length(rel_candidates) == 0) {
    stop("Archive does not contain a sysndd_prediction_release directory", call. = FALSE)
  }
  rel_dir <- rel_candidates[[1]]

  sha_file <- file.path(rel_dir, "checksums.sha256")
  if (!file.exists(sha_file)) {
    stop("Archive release directory has no bundled checksums.sha256", call. = FALSE)
  }
  sha_lines <- readLines(sha_file, warn = FALSE)
  sha_lines <- sha_lines[nzchar(trimws(sha_lines))]
  for (line in sha_lines) {
    parts <- strsplit(trimws(line), "\\s+")[[1]]
    expected_sha <- parts[[1]]
    rel_name <- parts[[length(parts)]]
    target <- file.path(rel_dir, rel_name)
    if (!file.exists(target)) {
      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name),
           call. = FALSE)
    }
    actual_sha <- digest::digest(file = target, algo = "sha256")
    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
      stop(sprintf("Bundled sha256 mismatch for release file '%s'", rel_name),
           call. = FALSE)
    }
  }
  rel_dir
}

#' Parse NDDScore release metadata from nddscore_release.json.
#'
#' @param dir Path to the extracted sysndd_prediction_release directory.
#' @return One-row metadata list with nested metric/version objects serialized
#'   as compact JSON strings.
nddscore_parse_release_json <- function(dir) {
  path <- file.path(dir, "nddscore_release.json")
  if (!file.exists(path)) {
    stop("NDDScore release metadata file not found", call. = FALSE)
  }

  release <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  json_fields <- grep("_json$", names(release), value = TRUE)
  for (field in json_fields) {
    release[[field]] <- jsonlite::toJSON(
      release[[field]],
      auto_unbox = TRUE,
      null = "null",
      digits = NA
    )
  }

  integer_fields <- c("n_genes", "n_hpo_predictions", "n_hpo_terms", "n_features")
  for (field in intersect(integer_fields, names(release))) {
    release[[field]] <- as.integer(release[[field]])
  }

  release
}

#' Load NDDScore release TSV files.
#'
#' @param dir Path to the extracted sysndd_prediction_release directory.
#' @return Named list of tibbles: gene, hpo, and term.
nddscore_load_tsvs <- function(dir) {
  list(
    gene = readr::read_tsv(
      file.path(dir, "nddscore_gene_predictions.tsv"),
      show_col_types = FALSE,
      progress = FALSE
    ),
    hpo = readr::read_tsv(
      file.path(dir, "nddscore_hpo_predictions.tsv"),
      show_col_types = FALSE,
      progress = FALSE
    ),
    term = readr::read_tsv(
      file.path(dir, "nddscore_hpo_terms.tsv"),
      show_col_types = FALSE,
      progress = FALSE
    )
  )
}

.nddscore_required_columns <- list(
  gene = c(
    "release_id", "hgnc_id", "gene_symbol", "ensembl_gene_id", "ndd_score",
    "ndd_score_std", "ndd_score_iqr", "bag_agreement", "rank", "percentile",
    "risk_tier", "confidence_tier", "known_sysndd_gene", "model_split",
    "inheritance_ad_probability", "inheritance_ar_probability",
    "inheritance_xld_probability", "inheritance_xlr_probability",
    "top_inheritance_mode", "called_inheritance_modes", "n_predicted_hpo",
    "top_hpo_predictions_json", "shap_clinical", "shap_constraint",
    "shap_expression", "shap_network", "shap_conservation", "shap_other",
    "dominant_shap_group", "top_features_json", "prediction_note"
  ),
  hpo = c(
    "release_id", "hgnc_id", "gene_symbol", "phenotype_id",
    "phenotype_name", "probability", "rank_for_gene",
    "passes_default_threshold", "term_auc_roc", "term_auc_pr",
    "term_training_support"
  ),
  term = c(
    "release_id", "phenotype_id", "phenotype_name", "term_auc_roc",
    "term_auc_pr", "term_training_support"
  )
)

.nddscore_frame_json_columns <- list(
  gene = c(
    "called_inheritance_modes", "top_hpo_predictions_json",
    "top_features_json"
  )
)

.nddscore_release_json_columns <- c(
  "ndd_performance_json", "phenotype_performance_json",
  "inheritance_performance_json", "data_versions_json",
  "artifact_hashes_json"
)

#' Validate NDDScore release metadata and loaded TSV frames.
#'
#' @return list(ok = TRUE/FALSE, messages = character()) without stopping.
nddscore_validate <- function(release, frames) {
  messages <- character(0)

  add_message <- function(message) {
    messages <<- c(messages, message)
  }

  frame_names <- names(.nddscore_required_columns)
  for (frame_name in frame_names) {
    frame <- frames[[frame_name]]
    if (is.null(frame) || !is.data.frame(frame)) {
      add_message(sprintf("Missing %s frame", frame_name))
      next
    }

    missing_columns <- setdiff(
      .nddscore_required_columns[[frame_name]],
      names(frame)
    )
    if (length(missing_columns) > 0) {
      add_message(sprintf(
        "%s frame is missing required columns: %s",
        frame_name,
        paste(missing_columns, collapse = ", ")
      ))
    }
  }

  row_count_checks <- list(
    gene = "n_genes",
    hpo = "n_hpo_predictions",
    term = "n_hpo_terms"
  )
  for (frame_name in names(row_count_checks)) {
    count_field <- row_count_checks[[frame_name]]
    frame <- frames[[frame_name]]
    expected <- release[[count_field]]
    if (is.null(frame) || !is.data.frame(frame)) {
      next
    }
    if (is.null(expected)) {
      add_message(sprintf("Release metadata is missing %s", count_field))
      next
    }

    expected <- suppressWarnings(as.integer(expected[[1]]))
    actual <- nrow(frame)
    if (is.na(expected) || !identical(actual, expected)) {
      add_message(sprintf(
        "%s row count %s does not match %s %s",
        frame_name,
        actual,
        count_field,
        as.character(release[[count_field]][[1]])
      ))
    }
  }

  for (column in .nddscore_release_json_columns) {
    if (is.null(release[[column]])) {
      next
    }

    values <- as.character(release[[column]])
    invalid <- !vapply(values, jsonlite::validate, logical(1))
    if (any(invalid)) {
      add_message(sprintf("Release JSON column %s contains invalid JSON", column))
    }
  }

  for (frame_name in names(.nddscore_frame_json_columns)) {
    frame <- frames[[frame_name]]
    if (is.null(frame) || !is.data.frame(frame)) {
      next
    }

    for (column in .nddscore_frame_json_columns[[frame_name]]) {
      if (!column %in% names(frame)) {
        next
      }

      values <- as.character(frame[[column]])
      invalid <- !vapply(values, jsonlite::validate, logical(1))
      if (any(invalid)) {
        add_message(sprintf(
          "%s JSON column %s contains invalid JSON",
          frame_name,
          column
        ))
      }
    }
  }

  gene <- frames$gene
  hpo <- frames$hpo
  term <- frames$term
  if (is.data.frame(gene) && is.data.frame(hpo) &&
      all(c("hgnc_id") %in% names(gene)) &&
      all(c("hgnc_id") %in% names(hpo))) {
    orphan_hgnc <- unique(hpo$hgnc_id[!hpo$hgnc_id %in% gene$hgnc_id])
    orphan_hgnc <- orphan_hgnc[!is.na(orphan_hgnc)]
    if (length(orphan_hgnc) > 0) {
      add_message(sprintf(
        "HPO prediction orphan hgnc_id values not present in gene frame: %s",
        paste(orphan_hgnc, collapse = ", ")
      ))
    }
  }

  if (is.data.frame(term) && is.data.frame(hpo) &&
      all(c("phenotype_id") %in% names(term)) &&
      all(c("phenotype_id") %in% names(hpo))) {
    orphan_terms <- unique(
      hpo$phenotype_id[!hpo$phenotype_id %in% term$phenotype_id]
    )
    orphan_terms <- orphan_terms[!is.na(orphan_terms)]
    if (length(orphan_terms) > 0) {
      add_message(sprintf(
        "HPO prediction orphan phenotype_id values not present in term frame: %s",
        paste(orphan_terms, collapse = ", ")
      ))
    }
  }

  list(ok = length(messages) == 0, messages = messages)
}

# NDDScore DB-write helpers -------------------------------------------------

.NDDSCORE_IMPORT_LOCK <- "nddscore_import"

.nddscore_scalar <- function(x, default = NA) {
  if (is.null(x) || length(x) == 0) {
    return(default)
  }
  x[[1]]
}

.nddscore_datetime <- function(x) {
  x <- .nddscore_scalar(x)
  if (is.null(x) || is.na(x) || !nzchar(as.character(x))) {
    return(NA)
  }
  sub("T", " ", as.character(x), fixed = TRUE)
}

.nddscore_bind_execute <- function(conn, sql, params = list()) {
  DBI::dbExecute(conn, sql, params = unname(params))
}

nddscore_try_acquire_import_lock <- function(conn) {
  result <- DBI::dbGetQuery(
    conn,
    "SELECT GET_LOCK(?, 0) AS acquired",
    params = unname(list(.NDDSCORE_IMPORT_LOCK))
  )
  identical(as.integer(result$acquired[[1]]), 1L)
}

nddscore_acquire_import_lock <- function(conn) {
  result <- DBI::dbGetQuery(
    conn,
    "SELECT GET_LOCK(?, 30) AS acquired",
    params = unname(list(.NDDSCORE_IMPORT_LOCK))
  )
  if (!identical(as.integer(result$acquired[[1]]), 1L)) {
    stop("Could not acquire NDDScore import lock", call. = FALSE)
  }
  TRUE
}

nddscore_release_import_lock <- function(conn) {
  result <- DBI::dbGetQuery(
    conn,
    "SELECT RELEASE_LOCK(?) AS released",
    params = unname(list(.NDDSCORE_IMPORT_LOCK))
  )
  identical(as.integer(result$released[[1]]), 1L)
}

nddscore_release_exists <- function(conn, release_id) {
  row <- DBI::dbGetQuery(
    conn,
    paste(
      "SELECT release_id, is_active, import_status",
      "FROM nddscore_release",
      "WHERE release_id = ?",
      sep = " "
    ),
    params = unname(list(release_id))
  )
  if (nrow(row) == 0) {
    return(list(exists = FALSE, is_active = FALSE, import_status = NULL))
  }
  list(
    exists = TRUE,
    is_active = identical(as.integer(row$is_active[[1]]), 1L),
    import_status = as.character(row$import_status[[1]])
  )
}

nddscore_upsert_release_row <- function(
    conn,
    release,
    import_job_id,
    imported_by = NULL,
    source = list(),
    import_status = "importing") {
  sql <- paste(
    "INSERT INTO nddscore_release (",
    "release_id, score_schema_version, version, release_created_at,",
    "n_genes, n_hpo_predictions, n_hpo_terms, n_features, hpo_threshold,",
    "calibration_method, ndd_model_created_at, phenotype_model_created_at,",
    "inheritance_model_created_at, ndd_performance_json,",
    "phenotype_performance_json, inheritance_performance_json,",
    "data_versions_json, artifact_hashes_json, zenodo_record_url,",
    "version_doi, concept_doi, source_record_id, source_archive_name,",
    "source_archive_checksum, source_archive_bytes, is_active, import_status,",
    "imported_by, import_job_id, import_started_at, last_error_message",
    ") VALUES (",
    paste(rep("?", 31), collapse = ", "),
    ") ON DUPLICATE KEY UPDATE",
    "score_schema_version = VALUES(score_schema_version),",
    "version = VALUES(version),",
    "release_created_at = VALUES(release_created_at),",
    "n_genes = VALUES(n_genes),",
    "n_hpo_predictions = VALUES(n_hpo_predictions),",
    "n_hpo_terms = VALUES(n_hpo_terms),",
    "n_features = VALUES(n_features),",
    "hpo_threshold = VALUES(hpo_threshold),",
    "calibration_method = VALUES(calibration_method),",
    "ndd_model_created_at = VALUES(ndd_model_created_at),",
    "phenotype_model_created_at = VALUES(phenotype_model_created_at),",
    "inheritance_model_created_at = VALUES(inheritance_model_created_at),",
    "ndd_performance_json = VALUES(ndd_performance_json),",
    "phenotype_performance_json = VALUES(phenotype_performance_json),",
    "inheritance_performance_json = VALUES(inheritance_performance_json),",
    "data_versions_json = VALUES(data_versions_json),",
    "artifact_hashes_json = VALUES(artifact_hashes_json),",
    "zenodo_record_url = VALUES(zenodo_record_url),",
    "version_doi = VALUES(version_doi),",
    "concept_doi = VALUES(concept_doi),",
    "source_record_id = VALUES(source_record_id),",
    "source_archive_name = VALUES(source_archive_name),",
    "source_archive_checksum = VALUES(source_archive_checksum),",
    "source_archive_bytes = VALUES(source_archive_bytes),",
    "is_active = 0,",
    "import_status = VALUES(import_status),",
    "imported_by = VALUES(imported_by),",
    "import_job_id = VALUES(import_job_id),",
    "import_started_at = VALUES(import_started_at),",
    "import_completed_at = NULL,",
    "activated_at = NULL,",
    "last_error_message = NULL",
    sep = " "
  )

  params <- list(
    .nddscore_scalar(release$release_id),
    .nddscore_scalar(release$score_schema_version),
    .nddscore_scalar(release$version),
    .nddscore_datetime(release$release_created_at %||% release$created_at),
    as.integer(.nddscore_scalar(release$n_genes)),
    as.integer(.nddscore_scalar(release$n_hpo_predictions)),
    as.integer(.nddscore_scalar(release$n_hpo_terms)),
    as.integer(.nddscore_scalar(release$n_features)),
    as.numeric(.nddscore_scalar(release$hpo_threshold)),
    .nddscore_scalar(release$calibration_method),
    .nddscore_scalar(release$ndd_model_created_at),
    .nddscore_scalar(release$phenotype_model_created_at),
    .nddscore_scalar(release$inheritance_model_created_at),
    .nddscore_scalar(release$ndd_performance_json),
    .nddscore_scalar(release$phenotype_performance_json),
    .nddscore_scalar(release$inheritance_performance_json),
    .nddscore_scalar(release$data_versions_json),
    .nddscore_scalar(release$artifact_hashes_json),
    .nddscore_scalar(source$record_url),
    .nddscore_scalar(source$version_doi),
    .nddscore_scalar(source$concept_doi),
    .nddscore_scalar(source$record_id),
    .nddscore_scalar(source$archive_name),
    .nddscore_scalar(source$archive_md5),
    as.numeric(.nddscore_scalar(source$archive_bytes)),
    0L,
    import_status,
    imported_by %||% NA,
    import_job_id,
    format(Sys.time(), "%Y-%m-%d %H:%M:%OS6"),
    NA
  )
  .nddscore_bind_execute(conn, sql, params)
  invisible(TRUE)
}

nddscore_insert_predictions <- function(conn, release_id, frames) {
  .nddscore_bind_execute(
    conn,
    "DELETE FROM nddscore_hpo_prediction WHERE release_id = ?",
    list(release_id)
  )
  .nddscore_bind_execute(
    conn,
    "DELETE FROM nddscore_gene_prediction WHERE release_id = ?",
    list(release_id)
  )
  .nddscore_bind_execute(
    conn,
    "DELETE FROM nddscore_hpo_term WHERE release_id = ?",
    list(release_id)
  )

  DBI::dbAppendTable(
    conn,
    "nddscore_gene_prediction",
    as.data.frame(frames$gene[.nddscore_required_columns$gene])
  )
  DBI::dbAppendTable(
    conn,
    "nddscore_hpo_term",
    as.data.frame(frames$term[.nddscore_required_columns$term])
  )
  DBI::dbAppendTable(
    conn,
    "nddscore_hpo_prediction",
    as.data.frame(frames$hpo[.nddscore_required_columns$hpo])
  )
  invisible(TRUE)
}

nddscore_count_release_rows <- function(conn, release_id) {
  count_one <- function(table) {
    sql <- sprintf("SELECT COUNT(*) AS n FROM %s WHERE release_id = ?", table)
    result <- DBI::dbGetQuery(conn, sql, params = unname(list(release_id)))
    as.integer(result$n[[1]])
  }
  list(
    gene = count_one("nddscore_gene_prediction"),
    hpo = count_one("nddscore_hpo_prediction"),
    term = count_one("nddscore_hpo_term")
  )
}

nddscore_mark_release_validated <- function(conn, release_id) {
  .nddscore_bind_execute(
    conn,
    paste(
      "UPDATE nddscore_release",
      "SET import_status = 'validated',",
      "import_completed_at = CURRENT_TIMESTAMP(6),",
      "last_error_message = NULL",
      "WHERE release_id = ?"
    ),
    list(release_id)
  )
  invisible(TRUE)
}

nddscore_activate_release <- function(conn, release_id) {
  DBI::dbWithTransaction(conn, {
    .nddscore_bind_execute(
      conn,
      paste(
        "UPDATE nddscore_release",
        "SET is_active = 0, import_status = 'superseded'",
        "WHERE is_active = 1 AND release_id <> ?"
      ),
      list(release_id)
    )
    .nddscore_bind_execute(
      conn,
      paste(
        "UPDATE nddscore_release",
        "SET is_active = 1, import_status = 'active',",
        "activated_at = CURRENT_TIMESTAMP(6),",
        "import_completed_at = COALESCE(import_completed_at, CURRENT_TIMESTAMP(6)),",
        "last_error_message = NULL",
        "WHERE release_id = ?"
      ),
      list(release_id)
    )
  })
  invisible(TRUE)
}

nddscore_mark_release_failed <- function(conn, release_id, message) {
  .nddscore_bind_execute(
    conn,
    paste(
      "UPDATE nddscore_release",
      "SET is_active = 0, import_status = 'failed',",
      "import_completed_at = CURRENT_TIMESTAMP(6),",
      "last_error_message = ?",
      "WHERE release_id = ?"
    ),
    list(message, release_id)
  )
  invisible(TRUE)
}

nddscore_delete_inactive_release <- function(conn, release_id) {
  .nddscore_bind_execute(
    conn,
    "DELETE FROM nddscore_release WHERE release_id = ? AND is_active = 0",
    list(release_id)
  )
  invisible(TRUE)
}

nddscore_run_import <- function(
    conn,
    record_id,
    validate_only = FALSE,
    imported_by = NULL,
    job_id = NULL,
    deps = list(),
    progress = NULL) {
  deps <- utils::modifyList(
    list(
      fetch_metadata = nddscore_fetch_zenodo_metadata,
      download = nddscore_download_archive,
      verify_checksum = nddscore_verify_archive_checksum,
      extract = nddscore_extract_and_verify,
      parse_release = nddscore_parse_release_json,
      load_tsvs = nddscore_load_tsvs,
      validate = nddscore_validate
    ),
    deps
  )

  report <- function(step, message, current, total = 12L) {
    if (is.function(progress)) {
      progress(step, message, current = current, total = total)
    }
  }

  validate_only <- isTRUE(validate_only)
  job_id <- job_id %||% NA_character_

  report("metadata", "Fetching NDDScore Zenodo metadata", 1L)
  source <- deps$fetch_metadata(record_id)

  archive_path <- tempfile(pattern = "nddscore_", fileext = ".tar.gz")
  extract_dir <- tempfile(pattern = "nddscore_extract_")
  on.exit(unlink(c(archive_path, extract_dir), recursive = TRUE, force = TRUE), add = TRUE)

  report("download", "Downloading NDDScore archive", 2L)
  deps$download(source$content_url, archive_path)

  report("checksum", "Verifying NDDScore archive checksum", 3L)
  deps$verify_checksum(archive_path, source$archive_md5)

  report("extract", "Extracting NDDScore release archive", 4L)
  release_dir <- deps$extract(archive_path, exdir = extract_dir)

  report("parse_release", "Parsing NDDScore release metadata", 5L)
  release <- deps$parse_release(release_dir)
  release_id <- .nddscore_scalar(release$release_id)

  report("load_predictions", "Loading NDDScore prediction tables", 6L)
  frames <- deps$load_tsvs(release_dir)

  report("validate", "Validating NDDScore release content", 7L)
  validation <- deps$validate(release, frames)
  if (!isTRUE(validation$ok)) {
    stop(
      sprintf(
        "NDDScore release validation failed: %s",
        paste(validation$messages, collapse = "; ")
      ),
      call. = FALSE
    )
  }

  if (validate_only) {
    report("complete", "NDDScore release validation complete", 12L)
    return(list(
      status = "validated",
      validate_only = TRUE,
      release_id = release_id,
      validation = validation,
      counts = list(
        gene = nrow(frames$gene),
        hpo = nrow(frames$hpo),
        term = nrow(frames$term)
      ),
      source = source
    ))
  }

  existing <- nddscore_release_exists(conn, release_id)
  if (isTRUE(existing$is_active)) {
    stop(
      sprintf(
        "NDDScore release_id '%s' is currently active and cannot be re-imported",
        release_id
      ),
      call. = FALSE
    )
  }

  tryCatch(
    {
      report("release_row", "Recording NDDScore release import", 8L)
      nddscore_upsert_release_row(
        conn,
        release,
        import_job_id = job_id,
        imported_by = imported_by,
        source = source
      )

      report("prediction_rows", "Writing NDDScore prediction rows", 9L)
      nddscore_insert_predictions(conn, release_id, frames)

      report("validated", "Marking NDDScore release validated", 10L)
      nddscore_mark_release_validated(conn, release_id)

      report("activate", "Activating NDDScore release", 11L)
      nddscore_activate_release(conn, release_id)

      counts <- nddscore_count_release_rows(conn, release_id)
      report("complete", "NDDScore release import complete", 12L)

      list(
        status = "active",
        validate_only = FALSE,
        release_id = release_id,
        validation = validation,
        counts = counts,
        source = source
      )
    },
    error = function(e) {
      nddscore_mark_release_failed(conn, release$release_id, conditionMessage(e))
      stop(e)
    }
  )
}
