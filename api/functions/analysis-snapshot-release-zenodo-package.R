# api/functions/analysis-snapshot-release-zenodo-package.R
#
# Pure, host-runnable operator-script helper for packaging a PUBLISHED
# analysis-snapshot release (#573) into a Zenodo-shaped dataset staging
# directory + deterministic tar.gz archive. This is NOT API-runtime code: it
# is not registered in `bootstrap/load_modules.R`. The C2 CLI wrapper
# (`api/scripts/package-analysis-release-zenodo.R`) sources this file
# directly; tests use `source_api_file(..., local = FALSE)`.
#
# Read path: the PUBLIC HTTP API only (no DB, no docker exec) --
#   GET {api_base_url}/api/analysis/releases/{latest|<release_id>}
#   GET {api_base_url}/api/analysis/releases/<release_id>/bundle
# A release is already a complete, self-verifying, content-addressed export
# (see AGENTS.md "Analysis-snapshot releases (#573)"), so the packager's job
# is narrow: download + verify the bundle, re-stage its files UNMODIFIED
# under `analysis_snapshot_release/`, add Zenodo-facing docs/metadata, write
# a staging-wide checksums.sha256, run the safety validator, then tar.
#
# Mirrors the sibling `../nddscore/src/models/sysndd_export.py` builders
# (translated Python -> R) and reuses the fetch/extract/verify idioms from
# `functions/nddscore-release-source.R` -- except the release bundle's own
# checksum is SHA-256 (`bundle_sha256` on the release head), not the MD5
# Zenodo's OWN file listing uses for the (unrelated) inbound nddscore fetch.
#
# Every HTTP/file-IO boundary is an injectable parameter with a real default
# (the `.analysis_release_zenodo_http_*` seams below), so unit tests inject
# plain stub closures -- no mocking library, no real network. Per AGENTS.md
# ("External-budget guard: Slice C scripts ARE EXEMPT" in the scout, and the
# documented `publication-functions.R`/`nddscore-release-source.R`
# precedent), one-shot operator scripts are outside
# `external_proxy_budget()` -- plain `httr2::req_timeout()`/`req_retry()`
# literals are used directly.
#
# Doc-string builders live in the sibling
# `analysis-snapshot-release-zenodo-docs.R` (guard-sourced below) to keep
# this file under the repo's 600-line soft ceiling.

`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0) {
    b
  } else {
    a
  }
}

if (!exists(".analysis_release_zenodo_docs_loaded", mode = "logical")) {
  # Resolve this file's own directory from the active source() frame (the
  # proven `helper-functions.R` / `async-job-repository.R` idiom) so the
  # sibling docs file loads regardless of cwd or how this file was sourced.
  .analysis_release_zenodo_self_dir <- local({
    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
  })
  .analysis_release_zenodo_docs_candidates <- c(
    if (!is.null(.analysis_release_zenodo_self_dir)) {
      file.path(.analysis_release_zenodo_self_dir, "analysis-snapshot-release-zenodo-docs.R")
    },
    "functions/analysis-snapshot-release-zenodo-docs.R",
    "/app/functions/analysis-snapshot-release-zenodo-docs.R"
  )
  for (.analysis_release_zenodo_docs_path in .analysis_release_zenodo_docs_candidates) {
    if (file.exists(.analysis_release_zenodo_docs_path)) {
      # local = TRUE (not FALSE): evaluate into THIS call's parent frame, i.e.
      # the same environment this main file is itself being sourced into
      # (mirrors the working `async-job-repository.R` guard-source precedent).
      # `local = FALSE` would instead always target globalenv() regardless of
      # caller, splitting the two files' symbols across different
      # environments whenever `source_api_file(local = FALSE)` sources this
      # file into a non-global test environment.
      source(.analysis_release_zenodo_docs_path, local = TRUE)
      break
    }
  }
  rm(.analysis_release_zenodo_self_dir, .analysis_release_zenodo_docs_candidates, .analysis_release_zenodo_docs_path)
}

# --------------------------------------------------------------------------- #
# Shared constants (forbidden files/dirs, sensitive text, expected layout)
# --------------------------------------------------------------------------- #

.ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES <- c(".env", ".env.local", ".envrc")
.ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS <- c(
  ".git", ".planning", ".superpowers", ".venv", "__pycache__"
)
.ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS <- c(
  "/home/", "/users/", "bernt-popp", "zenodo_token", "zenodo_access_token",
  "bearer ", "development/sysndd", "development/nddscore", ".env", "git_sha"
)
.ANALYSIS_RELEASE_ZENODO_TEXT_SUFFIXES <- c(".md", ".json", ".sql", ".cff", ".sha256", ".txt")
.ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL <- c(
  "README.md", "DATA_CARD.md", "SCHEMA.md", "CHANGELOG.md", "CITATION.cff",
  "datapackage.json", "zenodo_metadata.json", "checksums.sha256"
)
.ANALYSIS_RELEASE_ZENODO_NESTED_DIR <- "analysis_snapshot_release"
.ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED <- c("manifest.json", "checksums.sha256")

# --------------------------------------------------------------------------- #
# Fetch (DI seams: http_get_json / http_download)
# --------------------------------------------------------------------------- #

#' Default JSON GET; tests inject a stub. Mirrors `.nddscore_http_get_json`.
.analysis_release_zenodo_http_get_json <- function(url) {
  resp <- httr2::request(url) |>
    httr2::req_retry(
      max_tries = 4,
      is_transient = ~ httr2::resp_status(.x) %in% c(429, 503, 504)
    ) |>
    httr2::req_timeout(30) |>
    httr2::req_perform()
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}

#' Default streamed binary GET; tests inject a stub. Mirrors `.nddscore_http_download`.
.analysis_release_zenodo_http_download <- function(url, destfile) {
  httr2::request(url) |>
    httr2::req_retry(max_tries = 4) |>
    httr2::req_timeout(300) |>
    httr2::req_perform(path = destfile)
  invisible(destfile)
}

#' Fetch a published release's head + parsed manifest over the public API.
#'
#' @param api_base_url Base URL of the SysNDD API (e.g. "http://localhost:7778").
#' @param release_id "latest" (default) or an explicit `asr_<16 hex>` id.
#' @param http_get_json Function(url) -> parsed JSON list. Injectable seam.
#' @return The parsed head list (release_id, created_at, license,
#'   source_data_version, bundle_sha256, manifest, ...).
analysis_release_zenodo_fetch_head <- function(
    api_base_url,
    release_id = "latest",
    http_get_json = .analysis_release_zenodo_http_get_json) {
  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
  release_id <- as.character(release_id)[[1]]
  url <- paste0(base_url, "/api/analysis/releases/", release_id)
  http_get_json(url)
}

#' Download a published release's whole `bundle.tar.gz`, verbatim, to `destfile`.
#'
#' @param release_id An EXPLICIT `asr_<16 hex>` id (there is no
#'   `/releases/latest/bundle` route -- callers must resolve the concrete id
#'   via `analysis_release_zenodo_fetch_head()` first).
#' @param http_download Function(url, destfile). Injectable seam.
#' @return `destfile`, invisibly-compatible (returned for chaining).
analysis_release_zenodo_download_bundle <- function(
    api_base_url,
    release_id,
    destfile,
    http_download = .analysis_release_zenodo_http_download) {
  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
  release_id <- as.character(release_id)[[1]]
  url <- paste0(base_url, "/api/analysis/releases/", release_id, "/bundle")
  http_download(url, destfile)
  if (!file.exists(destfile) || file.size(destfile) == 0) {
    stop("Analysis-snapshot release bundle download produced an empty file", call. = FALSE)
  }
  destfile
}

#' Verify a downloaded bundle against the release head's `bundle_sha256`,
#' extract it, then verify the bundle's OWN inner `checksums.sha256` against
#' every extracted file. Mirrors `nddscore_extract_and_verify()`'s verify
#' loop, but the outer digest is SHA-256 (not MD5), and the release bundle's
#' files sit directly at the archive root (no named top-level subdirectory
#' to search for).
#'
#' @param bundle_path Path to the downloaded `bundle.tar.gz`.
#' @param expected_bundle_sha256 The release head's `bundle_sha256`.
#' @param exdir Optional extraction directory (defaults to a fresh temp dir).
#' @return Path to the extraction directory (== `exdir`).
analysis_release_zenodo_extract_and_verify <- function(
    bundle_path, expected_bundle_sha256, exdir = NULL) {
  if (!file.exists(bundle_path)) {
    stop("Analysis-snapshot release bundle not found for verification", call. = FALSE)
  }
  actual_bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
  expected <- tolower(as.character(expected_bundle_sha256 %||% "")[[1]])
  if (!identical(tolower(actual_bundle_sha256), expected)) {
    stop(sprintf(
      "Analysis-snapshot release bundle checksum mismatch (expected %s, got %s)",
      expected, actual_bundle_sha256
    ), call. = FALSE)
  }

  if (is.null(exdir)) {
    exdir <- file.path(
      tempdir(), paste0("analysis_release_zenodo_extract_", as.integer(stats::runif(1, 1, 1e9)))
    )
  }
  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
  utils::untar(bundle_path, exdir = exdir)

  sha_file <- file.path(exdir, "checksums.sha256")
  if (!file.exists(sha_file)) {
    stop("Extracted release bundle has no checksums.sha256", call. = FALSE)
  }
  sha_lines <- readLines(sha_file, warn = FALSE)
  sha_lines <- sha_lines[nzchar(trimws(sha_lines))]
  for (line in sha_lines) {
    parts <- strsplit(trimws(line), "\\s+")[[1]]
    expected_sha <- parts[[1]]
    rel_name <- parts[[length(parts)]]
    target <- file.path(exdir, rel_name)
    if (!file.exists(target)) {
      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name), call. = FALSE)
    }
    actual_sha <- digest::digest(file = target, algo = "sha256")
    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
      stop(sprintf("Bundled sha256 mismatch for release file '%s'", rel_name), call. = FALSE)
    }
  }
  exdir
}

# --------------------------------------------------------------------------- #
# Shared public-file iterator -- filter-at-source, reused by every
# builder/checksums/validator step (belt half of belt-and-suspenders).
# --------------------------------------------------------------------------- #

#' Sorted, files-only, relative POSIX paths under `root_dir`, excluding
#' forbidden filenames and any path with a forbidden dir-part segment.
#'
#' @return character vector of relative paths ("/"-separated).
.analysis_release_zenodo_iter_public_files <- function(root_dir) {
  all_files <- list.files(
    root_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
  )
  keep <- vapply(all_files, function(rel_path) {
    base <- basename(rel_path)
    if (base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES) {
      return(FALSE)
    }
    segments <- strsplit(rel_path, "/", fixed = TRUE)[[1]]
    !any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
  }, logical(1))
  sort(all_files[keep])
}

# --------------------------------------------------------------------------- #
# Builders (pure)
# --------------------------------------------------------------------------- #

.analysis_release_zenodo_created_at_date <- function(created_at) {
  value <- as.character(created_at %||% "")[[1]]
  if (!nzchar(value)) {
    return("")
  }
  candidate <- substr(value, 1, 10)
  if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", candidate)) candidate else value
}

#' Build the Zenodo metadata list -- becomes `zenodo_metadata.json` AND the
#' body `set_metadata()` PUTs (C2). Never includes a `doi` key: Zenodo mints
#' the DOI on deposition creation.
#'
#' @param head The release head (from `analysis_release_zenodo_fetch_head()`).
#' @param version Optional override; default `head$source_data_version` or
#'   `head$release_id`.
#' @param license_id Optional override; default `head$license` or `"cc-by-4.0"`.
analysis_release_zenodo_build_metadata <- function(head, version = NULL, license_id = NULL) {
  release_id <- as.character(head$release_id %||% "")[[1]]
  release_date <- .analysis_release_zenodo_created_at_date(head$created_at)
  title <- if (nzchar(release_date)) {
    sprintf("SysNDD analysis-snapshot release %s, %s", release_id, release_date)
  } else {
    sprintf("SysNDD analysis-snapshot release %s", release_id)
  }

  resolved_license <- license_id %||% head$license %||% "cc-by-4.0"
  resolved_version <- as.character((version %||% head$source_data_version %||% release_id))[[1]]

  description <- paste0(
    "<p>Immutable, content-addressed public export of a SysNDD analysis-snapshot ",
    "release: the functional (STRING/Leiden) clusters, the phenotype (MCA/HCPC) ",
    "clusters, and the phenotype-functional correlation layer, each derived from ",
    "approved public SysNDD curation data.</p>",
    "<p>Every layer and file is independently verifiable via the bundled ",
    "manifest.json and checksums.sha256. This is a derived analysis product, not a ",
    "copy of the primary curated evidence.</p>"
  )

  list(
    title = title,
    upload_type = "dataset",
    description = description,
    creators = list(list(name = "Popp, Bernt", orcid = "0000-0002-3679-1081")),
    keywords = list(
      "SysNDD", "neurodevelopmental disorders", "gene-disease", "clustering",
      "analysis snapshot"
    ),
    access_right = "open",
    license = as.character(resolved_license)[[1]],
    version = resolved_version,
    language = "eng"
  )
}

#' Build a Frictionless Data Package describing the WHOLE staging tree.
#'
#' @param staging_dir Root of the staging directory (already populated).
#' @param name Dataset machine name.
#' @param version Dataset version string.
#' @param release_id The release id (becomes the datapackage `id`).
analysis_release_zenodo_build_datapackage <- function(staging_dir, name, version, release_id) {
  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
  rel_paths <- base::setdiff(rel_paths, c("checksums.sha256", "datapackage.json"))

  resources <- lapply(rel_paths, function(rel_path) {
    full_path <- file.path(staging_dir, rel_path)
    list(
      name = gsub("\\.", "-", gsub("/", "-", rel_path)),
      path = rel_path,
      bytes = as.numeric(file.info(full_path)$size),
      hash = digest::digest(file = full_path, algo = "sha256"),
      mediatype = "application/octet-stream"
    )
  })

  list(
    profile = "data-package",
    name = as.character(name)[[1]],
    title = "SysNDD analysis-snapshot release",
    version = as.character(version)[[1]],
    id = as.character(release_id)[[1]],
    licenses = list(list(name = "CC-BY-4.0", path = "https://creativecommons.org/licenses/by/4.0/")),
    resources = resources
  )
}

# --------------------------------------------------------------------------- #
# Staging + checksums + tarball
# --------------------------------------------------------------------------- #

.analysis_release_zenodo_write_text <- function(path, content) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  cat(content, file = path)
  invisible(path)
}

#' Write `checksums.sha256` at the staging root, covering every iterated file
#' (excluding itself). Byte-identical format to
#' `analysis_release_checksums_text()`: `"<sha256>  <path>\n"` lines.
#'
#' @return The written path.
analysis_release_zenodo_write_checksums <- function(staging_dir) {
  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
  rel_paths <- rel_paths[rel_paths != "checksums.sha256"]

  content <- if (length(rel_paths) == 0L) {
    ""
  } else {
    lines <- vapply(rel_paths, function(rel_path) {
      full_path <- file.path(staging_dir, rel_path)
      paste0(digest::digest(file = full_path, algo = "sha256"), "  ", rel_path)
    }, character(1))
    paste0(paste(lines, collapse = "\n"), "\n")
  }

  out_path <- file.path(staging_dir, "checksums.sha256")
  .analysis_release_zenodo_write_text(out_path, content)
  out_path
}

#' Deterministic gzip tarball with ONE top-level dir (`basename(staging_dir)`).
#' Also writes `<archive_path>.sha256` (`"<sha256>  <basename>\n"`).
#'
#' @return list(archive_path, archive_sha256_path).
analysis_release_zenodo_make_tarball <- function(staging_dir, archive_path) {
  archive_dir <- dirname(archive_path)
  dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
  archive_path <- normalizePath(file.path(archive_dir, basename(archive_path)), mustWork = FALSE)

  staging_dir <- normalizePath(staging_dir, mustWork = TRUE)
  parent_dir <- dirname(staging_dir)
  base_name <- basename(staging_dir)

  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
  entries <- sort(file.path(base_name, rel_paths))

  previous_wd <- setwd(parent_dir)
  on.exit(setwd(previous_wd), add = TRUE)
  # tar = "internal" forces R's built-in (pure-R) tar writer so the archive
  # never depends on a system `tar` binary being present/compatible.
  utils::tar(tarfile = archive_path, files = entries, compression = "gzip", tar = "internal")

  sha256 <- digest::digest(file = archive_path, algo = "sha256")
  sha_path <- paste0(archive_path, ".sha256")
  cat(paste0(sha256, "  ", basename(archive_path), "\n"), file = sha_path)

  list(archive_path = archive_path, archive_sha256_path = sha_path)
}

# --------------------------------------------------------------------------- #
# THE SAFETY VALIDATOR -- defense in depth, runs LAST before tarring.
# Three independent checks; each collects offending paths and stops loudly.
# --------------------------------------------------------------------------- #

.analysis_release_zenodo_validate_no_forbidden <- function(staging_dir) {
  # Deliberately re-walks the tree directly (not via the shared iterator,
  # which already excludes these) -- an independent re-check, not a
  # tautology.
  all_files <- list.files(
    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
  )
  offenders <- Filter(function(rel_path) {
    base <- basename(rel_path)
    segments <- strsplit(rel_path, "/", fixed = TRUE)[[1]]
    base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES ||
      any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
  }, all_files)

  if (length(offenders) > 0) {
    stop(sprintf(
      "Zenodo staging contains private files: %s",
      paste(sort(offenders), collapse = ", ")
    ), call. = FALSE)
  }
  invisible(TRUE)
}

.analysis_release_zenodo_has_text_suffix <- function(rel_path) {
  lower <- tolower(rel_path)
  any(vapply(
    .ANALYSIS_RELEASE_ZENODO_TEXT_SUFFIXES,
    function(suffix) endsWith(lower, suffix), logical(1)
  ))
}

.analysis_release_zenodo_validate_no_sensitive_text <- function(staging_dir) {
  offenders <- character(0)
  for (rel_path in .analysis_release_zenodo_iter_public_files(staging_dir)) {
    if (!.analysis_release_zenodo_has_text_suffix(rel_path)) {
      next
    }
    full_path <- file.path(staging_dir, rel_path)
    text <- tolower(paste(readLines(full_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
    hit <- Find(function(pattern) grepl(pattern, text, fixed = TRUE),
                .ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS)
    if (!is.null(hit)) {
      offenders <- c(offenders, sprintf("%s (matched '%s')", rel_path, hit))
    }
  }
  if (length(offenders) > 0) {
    stop(sprintf(
      "Zenodo staging contains sensitive public text: %s",
      paste(offenders, collapse = "; ")
    ), call. = FALSE)
  }
  invisible(TRUE)
}

.analysis_release_zenodo_validate_layout <- function(staging_dir) {
  expected_top <- .ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL
  expected_nested <- file.path(
    .ANALYSIS_RELEASE_ZENODO_NESTED_DIR, .ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED
  )
  expected <- c(expected_top, expected_nested)

  missing <- Filter(function(rel_path) !file.exists(file.path(staging_dir, rel_path)), expected)
  if (length(missing) > 0) {
    stop(sprintf(
      "Zenodo staging is missing expected members: %s",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }
  invisible(TRUE)
}

#' The safety validator. Three independent checks; stops with a clear message
#' naming the offending relative paths on the first failing check.
analysis_release_zenodo_validate_staging <- function(staging_dir) {
  .analysis_release_zenodo_validate_no_forbidden(staging_dir)
  .analysis_release_zenodo_validate_no_sensitive_text(staging_dir)
  .analysis_release_zenodo_validate_layout(staging_dir)
  invisible(TRUE)
}

# --------------------------------------------------------------------------- #
# Orchestrator
# --------------------------------------------------------------------------- #

#' Recursively sort a named list's keys alphabetically (objects only --
#' unnamed lists/arrays are recursed into without reordering). Used for
#' `zenodo_metadata.json`'s "pretty JSON, sorted keys" contract, mirroring
#' Python's `json.dumps(..., sort_keys=True)`.
.analysis_release_zenodo_sort_keys <- function(x) {
  if (is.list(x)) {
    nms <- names(x)
    if (!is.null(nms) && all(nzchar(nms))) {
      x <- x[order(nms)]
    }
    x <- lapply(x, .analysis_release_zenodo_sort_keys)
  }
  x
}

.analysis_release_zenodo_copy_tree <- function(src_dir, dest_dir) {
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  rel_paths <- list.files(src_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
  for (rel_path in rel_paths) {
    dest_path <- file.path(dest_dir, rel_path)
    dir.create(dirname(dest_path), recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(src_dir, rel_path), dest_path, overwrite = TRUE, copy.date = TRUE)
  }
  invisible(dest_dir)
}

#' Fetch a published release over the public HTTP API and assemble a Zenodo
#' staging directory + deterministic tarball. Mirrors nddscore's
#' `build_zenodo_dataset_package()` top-to-bottom.
#'
#' @return list(staging_dir, archive_path, archive_sha256_path,
#'   zenodo_metadata_path, release_id).
analysis_release_zenodo_package <- function(
    api_base_url,
    release_id = "latest",
    staging_dir,
    archive_dir,
    version = NULL,
    doi = NULL,
    http_get_json = .analysis_release_zenodo_http_get_json,
    http_download = .analysis_release_zenodo_http_download) {
  head <- analysis_release_zenodo_fetch_head(api_base_url, release_id, http_get_json = http_get_json)
  resolved_release_id <- as.character(head$release_id)[[1]]

  bundle_path <- tempfile(fileext = ".tar.gz")
  on.exit(unlink(bundle_path, force = TRUE), add = TRUE)
  analysis_release_zenodo_download_bundle(
    api_base_url, resolved_release_id, bundle_path, http_download = http_download
  )
  extracted_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, head$bundle_sha256)
  on.exit(unlink(extracted_dir, recursive = TRUE, force = TRUE), add = TRUE)

  if (dir.exists(staging_dir)) {
    unlink(staging_dir, recursive = TRUE, force = TRUE)
  }
  dir.create(staging_dir, recursive = TRUE)

  nested_dir <- file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_NESTED_DIR)
  .analysis_release_zenodo_copy_tree(extracted_dir, nested_dir)

  resolved_version <- as.character(
    (version %||% head$source_data_version %||% resolved_release_id)
  )[[1]]

  .analysis_release_zenodo_write_text(
    file.path(staging_dir, "README.md"), analysis_release_zenodo_build_readme(head, doi)
  )
  .analysis_release_zenodo_write_text(
    file.path(staging_dir, "DATA_CARD.md"), analysis_release_zenodo_build_data_card(head)
  )
  .analysis_release_zenodo_write_text(
    file.path(staging_dir, "SCHEMA.md"), analysis_release_zenodo_build_schema_doc(head)
  )
  .analysis_release_zenodo_write_text(
    file.path(staging_dir, "CHANGELOG.md"),
    analysis_release_zenodo_build_changelog(head, resolved_version)
  )
  .analysis_release_zenodo_write_text(
    file.path(staging_dir, "CITATION.cff"),
    analysis_release_zenodo_build_citation_cff(head, resolved_version, doi)
  )

  metadata <- analysis_release_zenodo_build_metadata(head, version = resolved_version)
  metadata_json <- jsonlite::toJSON(
    .analysis_release_zenodo_sort_keys(metadata), auto_unbox = TRUE, pretty = TRUE, null = "null"
  )
  zenodo_metadata_path <- file.path(staging_dir, "zenodo_metadata.json")
  .analysis_release_zenodo_write_text(zenodo_metadata_path, paste0(as.character(metadata_json), "\n"))

  datapackage <- analysis_release_zenodo_build_datapackage(
    staging_dir,
    name = "sysndd-analysis-snapshot-release",
    version = resolved_version,
    release_id = resolved_release_id
  )
  datapackage_json <- jsonlite::toJSON(datapackage, auto_unbox = TRUE, pretty = TRUE, null = "null")
  .analysis_release_zenodo_write_text(
    file.path(staging_dir, "datapackage.json"), paste0(as.character(datapackage_json), "\n")
  )

  analysis_release_zenodo_write_checksums(staging_dir)

  analysis_release_zenodo_validate_staging(staging_dir)

  archive_path <- file.path(archive_dir, paste0(resolved_release_id, ".tar.gz"))
  tar_result <- analysis_release_zenodo_make_tarball(staging_dir, archive_path)

  list(
    staging_dir = staging_dir,
    archive_path = tar_result$archive_path,
    archive_sha256_path = tar_result$archive_sha256_path,
    zenodo_metadata_path = zenodo_metadata_path,
    release_id = resolved_release_id
  )
}
