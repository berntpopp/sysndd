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
# `analysis-snapshot-release-zenodo-docs.R` (guard-sourced below); the
# fetch/download/extract-verify helpers and the safety validator live in the
# sibling `analysis-snapshot-release-zenodo-verify.R` (also guard-sourced
# below) -- both splits keep every file under the repo's 600-line soft
# ceiling.

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

if (!exists(".analysis_release_zenodo_verify_loaded", mode = "logical")) {
  # Same guard-source idiom as the docs block above, targeting the sibling
  # fetch/extract-verify + safety-validator file instead.
  .analysis_release_zenodo_self_dir <- local({
    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
  })
  .analysis_release_zenodo_verify_candidates <- c(
    if (!is.null(.analysis_release_zenodo_self_dir)) {
      file.path(.analysis_release_zenodo_self_dir, "analysis-snapshot-release-zenodo-verify.R")
    },
    "functions/analysis-snapshot-release-zenodo-verify.R",
    "/app/functions/analysis-snapshot-release-zenodo-verify.R"
  )
  for (.analysis_release_zenodo_verify_path in .analysis_release_zenodo_verify_candidates) {
    if (file.exists(.analysis_release_zenodo_verify_path)) {
      # local = TRUE for the same reason as the docs block above.
      source(.analysis_release_zenodo_verify_path, local = TRUE)
      break
    }
  }
  rm(
    .analysis_release_zenodo_self_dir, .analysis_release_zenodo_verify_candidates,
    .analysis_release_zenodo_verify_path
  )
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

# A fixed, arbitrary epoch every staged file/dir's mtime is normalized to
# before tarring (item 5). R's internal tar writer already zeroes the gzip
# container's own embedded timestamp, so per-file mtimes are the ONLY
# remaining source of non-determinism between two builds of the same staged
# content; normalizing them makes the resulting `.tar.gz` byte-identical
# across runs (proved by
# `test-unit-analysis-release-zenodo-package.R`'s "packaging the SAME staged
# content twice" determinism test).
.ANALYSIS_RELEASE_ZENODO_TAR_FIXED_TIME <- as.POSIXct("2020-01-01", tz = "UTC")

#' Set every file's and directory's mtime under `staging_dir` (INCLUDING
#' `staging_dir` itself) to a fixed epoch, deepest-first, so a rebuild of the
#' identical content never differs by mtime alone.
.analysis_release_zenodo_normalize_mtimes <- function(staging_dir) {
  entries <- list.files(
    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE,
    full.names = TRUE, include.dirs = TRUE
  )
  # Deepest-first: a directory's own mtime is set only after every entry
  # nested inside it, so nothing touched later in this loop bumps it again.
  depth <- lengths(strsplit(entries, "/", fixed = TRUE))
  entries <- entries[order(-depth)]
  for (path in entries) {
    Sys.setFileTime(path, .ANALYSIS_RELEASE_ZENODO_TAR_FIXED_TIME)
  }
  Sys.setFileTime(staging_dir, .ANALYSIS_RELEASE_ZENODO_TAR_FIXED_TIME)
  invisible(TRUE)
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

  .analysis_release_zenodo_normalize_mtimes(staging_dir)

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
  # Defense-in-depth (item 2): re-validate the RESOLVED id even though the
  # REQUEST arg was already validated inside fetch_head() -- this is the
  # value that actually becomes `<release_id>.tar.gz` and the `RELEASE_ID=`
  # marker line, so a compromised/misbehaving API response can never smuggle
  # a path/marker-injection payload through.
  .analysis_release_zenodo_assert_valid_release_id(resolved_release_id, allow_latest = FALSE)

  bundle_path <- tempfile(fileext = ".tar.gz")
  on.exit(unlink(bundle_path, force = TRUE), add = TRUE)
  analysis_release_zenodo_download_bundle(
    api_base_url, resolved_release_id, bundle_path, http_download = http_download
  )
  extracted_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, head$bundle_sha256)
  on.exit(unlink(extracted_dir, recursive = TRUE, force = TRUE), add = TRUE)

  # BLOCKER guard (item 1): refuse to recursively delete a pre-existing
  # `--staging-dir` unless this tool itself created it (empty, absent, or
  # carrying the ownership sentinel) -- an operator typo must never
  # irreversibly rmtree an unrelated directory.
  .analysis_release_zenodo_assert_staging_deletable(staging_dir)
  if (dir.exists(staging_dir)) {
    unlink(staging_dir, recursive = TRUE, force = TRUE)
  }
  dir.create(staging_dir, recursive = TRUE)
  .analysis_release_zenodo_write_staging_sentinel(staging_dir)

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
