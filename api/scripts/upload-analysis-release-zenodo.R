#!/usr/bin/env Rscript
# api/scripts/upload-analysis-release-zenodo.R
#
# Thin operator CLI: upload a packaged analysis-snapshot release archive
# (#573; output of `package-analysis-release-zenodo.R`) to a Zenodo
# deposition -- get-or-create -> set metadata -> stream archive to bucket ->
# (optional, double-gated) publish -- then, opt-in, PATCH the resulting
# DOI/record provenance back onto the SysNDD release head.
#
# All upload/record-back logic lives in
# `api/functions/analysis-snapshot-release-zenodo-upload.R`; this script
# only parses flags, sources that file, calls the orchestrator, and prints
# results -- mirroring the sibling
# `../nddscore/scripts/upload_sysndd_zenodo_dataset.py`.
#
# Usage (from the repo root, or from api/ -- CWD-independent, see below):
#   Rscript api/scripts/upload-analysis-release-zenodo.R \
#     --archive <path/to/archive.tar.gz> --metadata <path/to/zenodo_metadata.json> \
#     [--sandbox] [--deposition-id <id>] [--publish --confirm-publish] \
#     [--record-doi --release-id <asr_...>] [--api-base-url <SysNDD API base>]
#
# ZENODO_TOKEN is READ FROM THE ENVIRONMENT ONLY -- there is deliberately no
# `--token` flag. A CLI flag would leak the token into shell history and
# `ps`/`/proc/<pid>/cmdline` argv on any multi-user host; the underlying
# `analysis_release_zenodo_upload()` function still accepts a `token`
# parameter for tests/programmatic callers, but this CLI wrapper only ever
# reads `Sys.getenv("ZENODO_TOKEN")`.
#
# Publish safety interlock: `--publish` alone is REFUSED -- both `--publish`
# AND `--confirm-publish` must be passed, or the run stops before any HTTP
# call is made (`analysis_release_zenodo_require_publish_confirmation()`).
# Without `--publish`, the archive is uploaded to a Zenodo DRAFT only, for
# manual review before publishing.
#
# DOI record-back is OPT-IN and requires BOTH `--record-doi` AND the
# `SYSNDD_ADMIN_TOKEN` env var (a pre-minted SysNDD Administrator bearer
# token) to be set, plus `--release-id` and a successfully PUBLISHED Zenodo
# DOI. Absent any of those, this script NEVER calls the SysNDD admin PATCH
# endpoint automatically -- it prints the exact manual `curl` command instead
# so the operator can record it by hand. A DRAFT upload (no `--publish`, or
# `--publish` without `--confirm-publish`) never gets a populated PATCH
# command either way -- only post-publication instructions are printed,
# because a draft DOI is not final and the record-back rule is
# published-only (see `analysis_release_zenodo_print_doi_record_back()`).
# `--release-id` is validated (`^asr_[0-9a-f]{16}$`) before it is ever placed
# into the admin URL or the printed command.
#
# Requires: httr2, jsonlite (api/renv.lock). No DB, no bootstrap, no
# `external_proxy_budget()` -- see AGENTS.md "Analysis-snapshot releases
# (#573)" and `.superpowers/sdd/slice-c-scout.md`.
#
# CWD note: resolves `api/functions/analysis-snapshot-release-zenodo-
# upload.R` relative to ITS OWN file location (same idiom as
# `package-analysis-release-zenodo.R` / `capture-external-fixtures.R`), so it
# may be invoked from any working directory.

# --------------------------------------------------------------------------- #
# Resolve this script's own directory, then source the upload/record-back
# functions (function definitions only -- no top-level network calls in that
# file, so this is safe to do unconditionally, even when this CLI script is
# itself only `source()`d).
# --------------------------------------------------------------------------- #

.upload_analysis_release_zenodo_script_dir <- function() {
  script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (is.null(script_file) || !nzchar(script_file)) {
    full_args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", full_args, value = TRUE)
    script_file <- if (length(file_arg) >= 1) sub("^--file=", "", file_arg[1]) else "."
  }
  dirname(normalizePath(script_file, mustWork = FALSE))
}

.upload_analysis_release_zenodo_script_dir_value <- .upload_analysis_release_zenodo_script_dir()
source(
  file.path(
    .upload_analysis_release_zenodo_script_dir_value, "..", "functions",
    "analysis-snapshot-release-zenodo-upload.R"
  ),
  local = FALSE
)

# --------------------------------------------------------------------------- #
# CLI arg parsing -- manual commandArgs() flag loop (repo convention; no
# optparse dependency, see `verify-endpoints.R`).
# --------------------------------------------------------------------------- #

#' Parse + run the upload CLI. Wrapped in a function (rather than bare
#' top-level code) so the file can be `source()`d for its function
#' definitions alone -- see the `sys.nframe() == 0L` main-guard at the
#' bottom of this file, which only calls this when the script is run
#' directly (`Rscript upload-analysis-release-zenodo.R`), never when
#' `source()`d (e.g. by a test).
run_upload_analysis_release_zenodo_cli <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  archive <- NULL
  metadata <- NULL
  # ZENODO_TOKEN is env-only -- see the "no --token flag" note in the file
  # header. There is no CLI flag to set/override it.
  token <- Sys.getenv("ZENODO_TOKEN", "")
  sandbox <- FALSE
  deposition_id <- NULL
  publish <- FALSE
  confirm_publish <- FALSE
  record_doi <- FALSE
  release_id <- NULL
  api_base_url <- Sys.getenv("SYSNDD_API_BASE_URL", "http://localhost:7778")

  if (length(args) > 0) {
    for (i in seq_along(args)) {
      if (args[i] == "--archive" && i < length(args)) {
        archive <- args[i + 1]
      } else if (args[i] == "--metadata" && i < length(args)) {
        metadata <- args[i + 1]
      } else if (args[i] == "--sandbox") {
        sandbox <- TRUE
      } else if (args[i] == "--deposition-id" && i < length(args)) {
        deposition_id <- args[i + 1]
      } else if (args[i] == "--publish") {
        publish <- TRUE
      } else if (args[i] == "--confirm-publish") {
        confirm_publish <- TRUE
      } else if (args[i] == "--record-doi") {
        record_doi <- TRUE
      } else if (args[i] == "--release-id" && i < length(args)) {
        release_id <- args[i + 1]
      } else if (args[i] == "--api-base-url" && i < length(args)) {
        api_base_url <- args[i + 1]
      }
    }
  }

  if (is.null(archive) || !nzchar(archive)) {
    stop("--archive is required", call. = FALSE)
  }
  if (is.null(metadata) || !nzchar(metadata)) {
    stop("--metadata is required", call. = FALSE)
  }

  result <- analysis_release_zenodo_upload(
    archive_path = archive,
    metadata_path = metadata,
    token = token,
    sandbox = sandbox,
    deposition_id = deposition_id,
    publish = publish,
    confirm_publish = confirm_publish
  )

  cat(sprintf("Zenodo deposition id: %s\n", result$deposition_id))
  cat(sprintf(
    "Zenodo reserved DOI:  %s\n",
    if (is.na(result$reserved_doi)) "not returned" else result$reserved_doi
  ))
  cat(sprintf(
    "Zenodo draft URL:     %s\n",
    if (is.na(result$draft_url)) "not returned" else result$draft_url
  ))

  if (isTRUE(result$published)) {
    cat(sprintf("Published Zenodo DOI: %s\n", result$version_doi))
    cat(sprintf("Published Zenodo URL: %s\n", result$record_url))
  } else {
    cat("Draft uploaded only. Review in Zenodo before publishing.\n")
  }

  # Item 3 (MEDIUM, Codex round 2): `analysis_release_zenodo_print_doi_record_back()`
  # (in the functions file, not duplicated here) prints ONLY post-publication
  # instructions for a draft upload -- never a populated PATCH command.
  analysis_release_zenodo_print_doi_record_back(result, release_id, api_base_url, record_doi)

  invisible(result)
}

# Main guard: `sys.nframe()` is 0 only at the true top level of a directly
# `Rscript`-invoked file; a `source()`d file (e.g. from a test) always adds
# at least one frame, so this line never fires under `source()`. This check
# MUST stay at top level (not inside a function).
if (sys.nframe() == 0L) run_upload_analysis_release_zenodo_cli()
