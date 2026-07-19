# api/functions/analysis-snapshot-release-zenodo-common.R
#
# Tiny shared helpers for the analysis-snapshot RELEASE Zenodo operator
# scripts (#573 Slice C, Codex round-2 hardening item 2 -- HIGH): the `%||%`
# NULL-coalesce helper and the STRICT release-id shape validator
# (`.analysis_release_zenodo_assert_valid_release_id()`).
#
# Guard-sourced by BOTH the package/verify pair
# (`analysis-snapshot-release-zenodo-verify.R`, itself guard-sourced by
# `-package.R`) AND the upload/DOI file
# (`analysis-snapshot-release-zenodo-upload.R`) so the validator is defined
# exactly once and every operator-script path -- package AND upload/DOI --
# rejects a malformed release id identically, before it is ever placed into a
# URL or a printed shell command.
#
# Extracted here (rather than left duplicated only in `-verify.R`, where the
# round-1 guard originally lived) because Codex round 2 found the upload/DOI
# path (`record_doi()`/`manual_doi_command()`, and the CLI's `--release-id`
# flag) built an admin PATCH URL AND a printed `curl` command straight from
# an UNVALIDATED `--release-id` -- a value like `asr_x' ; rm -rf ~ ; #`
# becomes a copy/paste command-injection payload once printed inside a
# single-quoted shell command, and a `../` value alters the URL path.
#
# NOT API-runtime code: not registered in `bootstrap/load_modules.R`. Kept
# well under the repo's 600-line soft ceiling on purpose -- this file only
# grows if a THIRD operator-script path needs the same guard.

.analysis_release_zenodo_common_loaded <- TRUE

`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0) {
    b
  } else {
    a
  }
}

# A published release id is `"asr_" + 16 lowercase hex chars`
# (`analysis_release_id()` in `analysis-snapshot-release-manifest.R`). This is
# the ONLY shape ever allowed to become a filename, path component, URL
# segment, or a value interpolated into a printed shell command.
.ANALYSIS_RELEASE_ZENODO_ID_PATTERN <- "^asr_[0-9a-f]{16}$"

#' Stop unless `release_id` is exactly `"latest"` (only when
#' `allow_latest = TRUE`, i.e. a caller-supplied REQUEST arg) or a
#' well-formed `asr_<16 lowercase hex>` id.
#'
#' Shared by BOTH:
#' - the package/verify path (`analysis_release_zenodo_fetch_head()`'s
#'   REQUEST arg, and defense-in-depth on the RESOLVED id from the release
#'   head in `analysis_release_zenodo_package()`) -- this is the value that
#'   becomes `<release_id>.tar.gz` and the `RELEASE_ID=` marker line;
#' - the upload/DOI path (`analysis_release_zenodo_record_doi()`,
#'   `analysis_release_zenodo_manual_doi_command()`, called before EITHER
#'   builds the admin PATCH URL or the printed `curl` command from the
#'   CLI's `--release-id`).
#'
#' Any other value (`../evil`, an id containing a quote, `;`, a newline, or
#' other shell metacharacters, ...) stops loudly here, before it is ever used
#' as a path/filename/marker/URL segment or interpolated into a command.
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
