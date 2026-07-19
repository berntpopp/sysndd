#!/usr/bin/env Rscript
# api/scripts/package-analysis-release-zenodo.R
#
# Thin operator CLI: fetch a PUBLISHED analysis-snapshot release (#573) over
# the public SysNDD HTTP API and assemble a Zenodo-shaped dataset staging
# directory + deterministic tar.gz archive, ready for
# `upload-analysis-release-zenodo.R`.
#
# All packaging logic lives in
# `api/functions/analysis-snapshot-release-zenodo-package.R`
# (`analysis_release_zenodo_package()`, which itself guard-sources the
# sibling `-docs.R` file); this script only parses flags, resolves + sources
# that ONE file, calls the orchestrator, and prints the resulting paths --
# mirroring the sibling
# `../nddscore/scripts/package_sysndd_zenodo_dataset.py`.
#
# Usage (from the repo root, or from api/ -- CWD-independent, see below):
#   Rscript api/scripts/package-analysis-release-zenodo.R \
#     [--api-base-url http://localhost:7778] [--release-id latest] \
#     [--staging-dir outputs/analysis-release-zenodo/staging] \
#     [--archive-dir outputs/analysis-release-zenodo/archive] \
#     [--version <override>]
#
# Requires: httr2, jsonlite, digest (all in api/renv.lock). No DB, no
# bootstrap, no `external_proxy_budget()` -- a pure HTTP client, runnable on
# any host with R (see AGENTS.md "Analysis-snapshot releases (#573)" and
# `.superpowers/sdd/slice-c-scout.md` S3 for why the public API is the read
# path, not the DB).
#
# CWD note: this script resolves
# `api/functions/analysis-snapshot-release-zenodo-package.R` relative to ITS
# OWN file location (via `sys.frame(1)$ofile`, falling back to Rscript's own
# `--file=` argument -- the same idiom `capture-external-fixtures.R` uses),
# so it may be invoked from any working directory; it does NOT assume CWD is
# the repo root or `api/`.

# --------------------------------------------------------------------------- #
# Resolve this script's own directory, then source the packager (functions
# only -- no top-level network calls in that file, so this is safe to do
# unconditionally, even when this CLI script is itself only `source()`d).
# --------------------------------------------------------------------------- #

.package_analysis_release_zenodo_script_dir <- function() {
  script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (is.null(script_file) || !nzchar(script_file)) {
    full_args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", full_args, value = TRUE)
    script_file <- if (length(file_arg) >= 1) sub("^--file=", "", file_arg[1]) else "."
  }
  dirname(normalizePath(script_file, mustWork = FALSE))
}

.package_analysis_release_zenodo_script_dir_value <- .package_analysis_release_zenodo_script_dir()
source(
  file.path(
    .package_analysis_release_zenodo_script_dir_value, "..", "functions",
    "analysis-snapshot-release-zenodo-package.R"
  ),
  local = FALSE
)

# --------------------------------------------------------------------------- #
# CLI arg parsing -- manual commandArgs() flag loop (repo convention; no
# optparse dependency, see `verify-endpoints.R`).
# --------------------------------------------------------------------------- #

#' Parse + run the packaging CLI. Wrapped in a function (rather than bare
#' top-level code) so the file can be `source()`d for its function
#' definitions alone -- see the `sys.nframe() == 0L` main-guard at the
#' bottom of this file, which only calls this when the script is run
#' directly (`Rscript package-analysis-release-zenodo.R`), never when
#' `source()`d (e.g. by a test).
run_package_analysis_release_zenodo_cli <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  api_base_url <- Sys.getenv("SYSNDD_API_BASE_URL", "http://localhost:7778")
  release_id <- "latest"
  staging_dir <- "outputs/analysis-release-zenodo/staging"
  archive_dir <- "outputs/analysis-release-zenodo/archive"
  version <- NULL

  if (length(args) > 0) {
    for (i in seq_along(args)) {
      if (args[i] == "--api-base-url" && i < length(args)) {
        api_base_url <- args[i + 1]
      } else if (args[i] == "--release-id" && i < length(args)) {
        release_id <- args[i + 1]
      } else if (args[i] == "--staging-dir" && i < length(args)) {
        staging_dir <- args[i + 1]
      } else if (args[i] == "--archive-dir" && i < length(args)) {
        archive_dir <- args[i + 1]
      } else if (args[i] == "--version" && i < length(args)) {
        version <- args[i + 1]
      }
    }
  }

  message(sprintf(
    "[package-analysis-release-zenodo] api_base_url=%s release_id=%s staging_dir=%s archive_dir=%s",
    api_base_url, release_id, staging_dir, archive_dir
  ))

  result <- analysis_release_zenodo_package(
    api_base_url = api_base_url,
    release_id = release_id,
    staging_dir = staging_dir,
    archive_dir = archive_dir,
    version = version
  )

  cat(sprintf("Release ID:           %s\n", result$release_id))
  cat(sprintf("Staging dir:          %s\n", result$staging_dir))
  cat(sprintf("Archive path:         %s\n", result$archive_path))
  cat(sprintf("Archive sha256 path:  %s\n", result$archive_sha256_path))
  cat(sprintf("Zenodo metadata path: %s\n", result$zenodo_metadata_path))
  cat(sprintf(
    "\nNext: Rscript api/scripts/upload-analysis-release-zenodo.R --archive %s --metadata %s\n",
    result$archive_path, result$zenodo_metadata_path
  ))

  invisible(result)
}

# Main guard: `sys.nframe()` is 0 only at the true top level of a directly
# `Rscript`-invoked file; a `source()`d file (e.g. from a test) always adds
# at least one frame, so this line never fires under `source()`. This check
# MUST stay at top level (not inside a function) -- see AGENTS.md-adjacent
# `.superpowers/sdd/task-c2-report.md` for the empirical verification.
if (sys.nframe() == 0L) run_package_analysis_release_zenodo_cli()
