# api/functions/analysis-snapshot-release-zenodo-verify.R
#
# Fetch/download/extract-verify helpers AND the safety validator for the
# analysis-snapshot RELEASE Zenodo packager (#573 Slice C). Extracted from
# `analysis-snapshot-release-zenodo-package.R` (which guard-sources this
# file) to keep both files under the repo's 600-line soft ceiling -- mirrors
# the sibling `analysis-snapshot-release-zenodo-docs.R` split and the
# `comparisons-functions.R` / `comparisons-parsers.R` precedent.
#
# This file is the hardening surface for a script that publishes public data
# and moves an operator-supplied filesystem path: release-id validation
# (path/filename/marker-injection guard), the extracted-bundle
# coverage/traversal checks, and the staging-tree safety validator
# (case-insensitive forbidden-name matching, a file-type allowlist, and a
# symlink rejection) all live here.
#
# Depends on `%||%`, defined in the sibling `analysis-snapshot-release-
# zenodo-package.R` (which always sources this file, never the other way
# around) -- resolved lazily at CALL time via the shared sourcing
# environment, not at source time, so definition order across the two files
# does not matter (same idiom as the `-docs.R` sibling).

.analysis_release_zenodo_verify_loaded <- TRUE

# --------------------------------------------------------------------------- #
# Shared constants (forbidden files/dirs, sensitive text, expected layout,
# allowed file-type suffixes, the staging-ownership sentinel, the release-id
# shape).
# --------------------------------------------------------------------------- #

.ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES <- c(".env", ".env.local", ".envrc")
.ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS <- c(
  ".git", ".planning", ".superpowers", ".venv", "__pycache__"
)
.ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS <- c(
  "/home/", "/users/", "bernt-popp", "zenodo_token", "zenodo_access_token",
  "bearer ", "development/sysndd", "development/nddscore", ".env", "git_sha"
)
# A well-formed analysis-release staging tree only ever contains these
# suffixes (the release payload/docs). Doubles as both the file-type
# ALLOWLIST (item 3: any staged regular file whose suffix is not in this set
# fails validation, catching `.csv`/`.pem`/extensionless/binary secret files
# without needing to scan binaries) and the set of suffixes the sensitive-
# text content scan reads.
.ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES <- c(".md", ".json", ".sql", ".cff", ".sha256", ".txt")
.ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL <- c(
  "README.md", "DATA_CARD.md", "SCHEMA.md", "CHANGELOG.md", "CITATION.cff",
  "datapackage.json", "zenodo_metadata.json", "checksums.sha256"
)
.ANALYSIS_RELEASE_ZENODO_NESTED_DIR <- "analysis_snapshot_release"
.ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED <- c("manifest.json", "checksums.sha256")

# The ownership marker this tool writes at the staging root immediately
# after creating it. `analysis_release_zenodo_package()` refuses to
# recursively delete a pre-existing `--staging-dir` unless it is empty or
# carries this sentinel -- see `.analysis_release_zenodo_staging_owned_by_tool()`.
.ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL <- ".analysis-release-zenodo-staging"

# A published release id is `"asr_" + 16 lowercase hex chars`
# (`analysis_release_id()` in `analysis-snapshot-release-manifest.R`). This is
# the ONLY shape ever allowed to become a filename, path component, or a
# value written into the `latest.env` marker the Makefile `source`s.
.ANALYSIS_RELEASE_ZENODO_ID_PATTERN <- "^asr_[0-9a-f]{16}$"

# --------------------------------------------------------------------------- #
# Release-id validation -- path/filename/marker-injection guard (item 2).
# --------------------------------------------------------------------------- #

#' Stop unless `release_id` is exactly `"latest"` (only when
#' `allow_latest = TRUE`, i.e. the caller-supplied REQUEST arg) or a
#' well-formed `asr_<16 lowercase hex>` id. Called on BOTH (a) the
#' `--release-id` request argument (`allow_latest = TRUE`, in
#' `analysis_release_zenodo_fetch_head()`) and (b) the RESOLVED id the API
#' returns on the release head (`allow_latest = FALSE`, in
#' `analysis_release_zenodo_package()`) -- defense-in-depth, since the
#' resolved id is what actually becomes `<release_id>.tar.gz` and the
#' `RELEASE_ID=` marker line. Any other value (`../evil`, an id containing a
#' newline or shell metacharacters, ...) stops loudly here, before it is ever
#' used as a path/filename/marker value.
#'
#' @return `release_id` (as a length-1 character), invisibly, on success.
.analysis_release_zenodo_assert_valid_release_id <- function(release_id, allow_latest = FALSE) {
  value <- as.character(release_id)[[1]]
  if (isTRUE(allow_latest) && identical(value, "latest")) {
    return(invisible(value))
  }
  if (!grepl(.ANALYSIS_RELEASE_ZENODO_ID_PATTERN, value)) {
    stop(sprintf(
      "Invalid analysis-snapshot release id %s: expected %s'asr_<16 lowercase hex>'",
      shQuote(value), if (isTRUE(allow_latest)) "'latest' or " else ""
    ), call. = FALSE)
  }
  invisible(value)
}

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
#'   Validated via `.analysis_release_zenodo_assert_valid_release_id()`
#'   before it is ever placed into the request URL.
#' @param http_get_json Function(url) -> parsed JSON list. Injectable seam.
#' @return The parsed head list (release_id, created_at, license,
#'   source_data_version, bundle_sha256, manifest, ...).
analysis_release_zenodo_fetch_head <- function(
    api_base_url,
    release_id = "latest",
    http_get_json = .analysis_release_zenodo_http_get_json) {
  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
  release_id <- as.character(release_id)[[1]]
  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = TRUE)
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

# --------------------------------------------------------------------------- #
# Path-traversal guard, shared by both the tar-member listing and the inner
# `checksums.sha256` entries (item 4).
# --------------------------------------------------------------------------- #

#' Stop if any `paths` entry is absolute (POSIX `/...` or a Windows drive
#' letter) or contains a `..` path segment. Used on BOTH the tar member list
#' (before extraction) and every `checksums.sha256` entry (before it is
#' resolved to a file under `exdir`) -- a tampered bundle cannot escape the
#' extraction directory via either vector.
.analysis_release_zenodo_assert_no_traversal <- function(paths, context) {
  offenders <- Filter(function(p) {
    startsWith(p, "/") || grepl("^[A-Za-z]:", p) ||
      any(strsplit(p, "/", fixed = TRUE)[[1]] == "..")
  }, paths)
  if (length(offenders) > 0) {
    stop(sprintf(
      "%s path traversal rejected: %s", context, paste(offenders, collapse = ", ")
    ), call. = FALSE)
  }
  invisible(TRUE)
}

#' Verify a downloaded bundle against the release head's `bundle_sha256`,
#' extract it, then verify the bundle's OWN inner `checksums.sha256` against
#' every extracted file. Mirrors `nddscore_extract_and_verify()`'s verify
#' loop, but the outer digest is SHA-256 (not MD5), and the release bundle's
#' files sit directly at the archive root (no named top-level subdirectory
#' to search for).
#'
#' Hardening (item 4): (1) every tar member path and every `checksums.sha256`
#' entry is rejected if absolute or containing a `..` segment, BEFORE it is
#' ever joined onto `exdir`; (2) after the existing per-line checksum
#' verification, COVERAGE is asserted -- every extracted regular file except
#' `checksums.sha256` itself must appear EXACTLY ONCE in the checksums list,
#' so a tampered bundle that drops a checksum line for a present file (or
#' lists the same path twice) fails loudly instead of silently passing.
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

  tar_entries <- utils::untar(bundle_path, list = TRUE)
  .analysis_release_zenodo_assert_no_traversal(tar_entries, context = "tar member")

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

  checksummed_paths <- character(0)
  for (line in sha_lines) {
    parts <- strsplit(trimws(line), "\\s+")[[1]]
    expected_sha <- parts[[1]]
    rel_name <- parts[[length(parts)]]
    .analysis_release_zenodo_assert_no_traversal(rel_name, context = "checksums.sha256 entry")
    target <- file.path(exdir, rel_name)
    if (!file.exists(target)) {
      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name), call. = FALSE)
    }
    actual_sha <- digest::digest(file = target, algo = "sha256")
    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
      stop(sprintf("Bundled sha256 mismatch for release file '%s'", rel_name), call. = FALSE)
    }
    checksummed_paths <- c(checksummed_paths, rel_name)
  }

  duplicate_entries <- unique(checksummed_paths[duplicated(checksummed_paths)])
  if (length(duplicate_entries) > 0) {
    stop(sprintf(
      "checksums.sha256 lists duplicate entries: %s", paste(duplicate_entries, collapse = ", ")
    ), call. = FALSE)
  }

  extracted_files <- list.files(exdir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
  extracted_files <- extracted_files[extracted_files != "checksums.sha256"]
  uncovered <- base::setdiff(extracted_files, checksummed_paths)
  if (length(uncovered) > 0) {
    stop(sprintf(
      "Extracted release bundle contains file(s) not listed in checksums.sha256: %s",
      paste(sort(uncovered), collapse = ", ")
    ), call. = FALSE)
  }

  exdir
}

# --------------------------------------------------------------------------- #
# Shared public-file iterator -- filter-at-source, reused by every
# builder/checksums/validator step (belt half of belt-and-suspenders).
# Case-insensitive (item 3) and excludes the staging-ownership sentinel
# (item 1), which is an internal marker, never a shipped release file.
# --------------------------------------------------------------------------- #

#' Sorted, files-only, relative POSIX paths under `root_dir`, excluding
#' forbidden filenames, any path with a forbidden dir-part segment, and the
#' staging-ownership sentinel. Matching is case-insensitive.
#'
#' @return character vector of relative paths ("/"-separated).
.analysis_release_zenodo_iter_public_files <- function(root_dir) {
  all_files <- list.files(
    root_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
  )
  keep <- vapply(all_files, function(rel_path) {
    if (rel_path == .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL) {
      return(FALSE)
    }
    base <- tolower(basename(rel_path))
    if (base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES) {
      return(FALSE)
    }
    segments <- tolower(strsplit(rel_path, "/", fixed = TRUE)[[1]])
    !any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
  }, logical(1))
  sort(all_files[keep])
}

# --------------------------------------------------------------------------- #
# Staging-directory delete guard (item 1, BLOCKER) -- refuse to
# `unlink(recursive = TRUE)` any directory this tool did not itself create.
# --------------------------------------------------------------------------- #

#' TRUE when `staging_dir` is safe for this tool to recursively delete: it
#' does not exist yet, is empty, or carries the ownership sentinel written by
#' a prior run of this tool. A pre-existing, non-empty directory WITHOUT the
#' sentinel is presumed to be an operator typo (e.g. `--staging-dir
#' /important/dir`) and must never be silently rmtree'd.
.analysis_release_zenodo_staging_owned_by_tool <- function(staging_dir) {
  if (!dir.exists(staging_dir)) {
    return(TRUE)
  }
  contents <- list.files(staging_dir, all.files = TRUE, no.. = TRUE)
  if (length(contents) == 0L) {
    return(TRUE)
  }
  file.exists(file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL))
}

#' Stop with a clear, actionable message unless `staging_dir` is safe to
#' recursively delete (see `.analysis_release_zenodo_staging_owned_by_tool()`).
.analysis_release_zenodo_assert_staging_deletable <- function(staging_dir) {
  if (!.analysis_release_zenodo_staging_owned_by_tool(staging_dir)) {
    stop(sprintf(
      paste0(
        "refusing to delete %s: not an analysis-release staging dir; ",
        "remove it manually or choose another --staging-dir"
      ),
      staging_dir
    ), call. = FALSE)
  }
  invisible(TRUE)
}

#' Write the ownership sentinel at the staging root. Called immediately after
#' `dir.create(staging_dir)` (before any other staging content) so a later
#' re-run recognizes this directory as the tool's own even if that later run
#' is interrupted before completing.
.analysis_release_zenodo_write_staging_sentinel <- function(staging_dir) {
  writeLines(
    paste0(
      "This directory is owned by package-analysis-release-zenodo.R and is ",
      "safe for it to recursively replace on the next run. Do not remove ",
      "this file manually if you want that protection to keep applying."
    ),
    file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL)
  )
  invisible(TRUE)
}

# --------------------------------------------------------------------------- #
# THE SAFETY VALIDATOR -- defense in depth, runs LAST before tarring.
# Independent checks; each collects offending paths and stops loudly.
# --------------------------------------------------------------------------- #

.analysis_release_zenodo_validate_no_forbidden <- function(staging_dir) {
  # Deliberately re-walks the tree directly (not via the shared iterator,
  # which already excludes these) -- an independent re-check, not a
  # tautology. Case-insensitive (item 3): both the forbidden filename and
  # forbidden dir-part segments are matched lowercase, so `.ENV`,
  # `.Git/config`, etc. no longer slip through.
  all_files <- list.files(
    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
  )
  offenders <- Filter(function(rel_path) {
    base <- tolower(basename(rel_path))
    segments <- tolower(strsplit(rel_path, "/", fixed = TRUE)[[1]])
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

#' Reject symlinks / non-regular files anywhere in the staging tree (item 3)
#' -- a symlink could point outside the archive, or at a private file
#' `utils::tar()` would then follow and embed verbatim. Checks BOTH files and
#' directory entries (`include.dirs = TRUE`) so a symlinked directory is
#' caught even if `list.files()` would otherwise silently walk through it.
.analysis_release_zenodo_validate_no_symlinks <- function(staging_dir) {
  rel_paths <- list.files(
    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE,
    full.names = FALSE, include.dirs = TRUE
  )
  offenders <- Filter(function(rel_path) {
    full_path <- file.path(staging_dir, rel_path)
    target <- suppressWarnings(Sys.readlink(full_path))
    !is.na(target) && nzchar(target)
  }, rel_paths)

  if (length(offenders) > 0) {
    stop(sprintf(
      "Zenodo staging contains symlinks (not allowed): %s",
      paste(sort(offenders), collapse = ", ")
    ), call. = FALSE)
  }
  invisible(TRUE)
}

.analysis_release_zenodo_has_allowed_suffix <- function(rel_path) {
  lower <- tolower(rel_path)
  any(vapply(
    .ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES,
    function(suffix) endsWith(lower, suffix), logical(1)
  ))
}

#' File-type ALLOWLIST (item 3): any staged regular file whose (lowercased)
#' suffix is not in `.ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES` fails
#' validation. This catches `.csv`/`.pem`/extensionless/binary secret files
#' without needing to scan binary content -- a well-formed analysis-release
#' staging tree only ever contains the release payload/docs suffixes.
.analysis_release_zenodo_validate_allowed_suffix <- function(staging_dir) {
  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
  offenders <- Filter(
    function(rel_path) !.analysis_release_zenodo_has_allowed_suffix(rel_path), rel_paths
  )
  if (length(offenders) > 0) {
    stop(sprintf(
      "Zenodo staging contains file(s) with an unexpected type/suffix: %s",
      paste(offenders, collapse = ", ")
    ), call. = FALSE)
  }
  invisible(TRUE)
}

.analysis_release_zenodo_validate_no_sensitive_text <- function(staging_dir) {
  offenders <- character(0)
  for (rel_path in .analysis_release_zenodo_iter_public_files(staging_dir)) {
    if (!.analysis_release_zenodo_has_allowed_suffix(rel_path)) {
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

#' The safety validator. Independent checks, in order; stops with a clear
#' message naming the offending relative paths on the first failing check.
analysis_release_zenodo_validate_staging <- function(staging_dir) {
  .analysis_release_zenodo_validate_no_forbidden(staging_dir)
  .analysis_release_zenodo_validate_no_symlinks(staging_dir)
  .analysis_release_zenodo_validate_allowed_suffix(staging_dir)
  .analysis_release_zenodo_validate_no_sensitive_text(staging_dir)
  .analysis_release_zenodo_validate_layout(staging_dir)
  invisible(TRUE)
}
