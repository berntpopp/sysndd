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
#' @param http_get Function(url) returning the parsed record JSON as a list.
#' @return Named list: record_id, record_url, version, version_doi, concept_doi,
#'   archive_name, archive_bytes, archive_md5, content_url.
nddscore_fetch_zenodo_metadata <- function(
    record_id,
    http_get = .nddscore_http_get_json) {
  record_id <- as.character(record_id)[[1]]
  url <- paste0("https://zenodo.org/api/records/", record_id)
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
