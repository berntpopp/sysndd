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
