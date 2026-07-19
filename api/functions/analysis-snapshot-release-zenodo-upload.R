# api/functions/analysis-snapshot-release-zenodo-upload.R
#
# Pure, host-runnable operator-script helper (#573 Slice C / Task C2) for
# uploading a Zenodo-staged analysis-snapshot release archive
# (`api/functions/analysis-snapshot-release-zenodo-package.R`'s output) to a
# Zenodo deposition, and (opt-in) recording the resulting DOI/record back
# onto the SysNDD release head. NOT API-runtime code: it is not registered in
# `bootstrap/load_modules.R`. The C2 CLI wrapper
# (`api/scripts/upload-analysis-release-zenodo.R`) sources this file
# directly; tests use `source_api_file(..., local = FALSE)`.
#
# Mirrors the sibling `../nddscore/scripts/upload_sysndd_zenodo_dataset.py`
# flow (deposition get-or-create -> set metadata -> PUT archive to bucket ->
# optional publish), translated Python -> R.
#
# Every HTTP boundary is an injectable seam parameter with a real `httr2`
# default (the `.analysis_release_zenodo_http_*` functions below), so unit
# tests inject plain stub closures -- no mocking library, no real network.
# Per AGENTS.md ("External-budget guard: Slice C scripts ARE EXEMPT" in the
# planning scout, and the documented `publication-functions.R`/
# `nddscore-release-source.R` precedent), one-shot operator scripts are
# outside `external_proxy_budget()` -- plain `httr2::req_timeout()` literals
# are used directly.
#
# Publish is DOUBLE-gated: `analysis_release_zenodo_require_publish_confirmation()`
# stops unless BOTH `publish` and `confirm_publish` are set -- the orchestrator
# is draft-only by default. DOI record-back to the SysNDD admin API is OPT-IN
# (`analysis_release_zenodo_record_doi()`/`analysis_release_zenodo_manual_doi_command()`/
# `analysis_release_zenodo_print_doi_record_back()` below); the CLI script
# only wires flags/env into the latter, so this file stays the single place
# that decides WHEN a DOI is recorded/printed and is easy to test in
# isolation.
#
# Codex round-2 hardening (item 2, HIGH): the DOI/record-back path takes an
# operator-supplied `--release-id` and both builds an admin PATCH URL from it
# AND interpolates it into a printed single-quoted `curl` command -- so an
# unvalidated value is a path/URL-injection AND a copy/paste
# command-injection vector. Every DOI URL/command builder below calls the
# shared `.analysis_release_zenodo_assert_valid_release_id()` (guard-sourced
# from the sibling `analysis-snapshot-release-zenodo-common.R`, same
# validator the package/verify path already used) FIRST, and
# `manual_doi_command()` additionally `shQuote()`s every interpolated value
# as defense in depth.

if (!exists(".analysis_release_zenodo_common_loaded", mode = "logical")) {
  # Same self-locating guard-source idiom as `-package.R`'s docs/verify
  # blocks and `-verify.R`'s own common guard block: resolves this file's
  # own directory from the active source() frame so the sibling common file
  # loads regardless of cwd or how this file was sourced (directly by the
  # CLI script, or by `source_api_file()` in tests).
  .analysis_release_zenodo_common_self_dir <- local({
    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
  })
  .analysis_release_zenodo_common_candidates <- c(
    if (!is.null(.analysis_release_zenodo_common_self_dir)) {
      file.path(.analysis_release_zenodo_common_self_dir, "analysis-snapshot-release-zenodo-common.R")
    },
    "functions/analysis-snapshot-release-zenodo-common.R",
    "/app/functions/analysis-snapshot-release-zenodo-common.R"
  )
  for (.analysis_release_zenodo_common_path in .analysis_release_zenodo_common_candidates) {
    if (file.exists(.analysis_release_zenodo_common_path)) {
      # local = TRUE: evaluate into THIS call's parent frame (same reasoning
      # as `-package.R`'s guard blocks).
      source(.analysis_release_zenodo_common_path, local = TRUE)
      break
    }
  }
  rm(
    .analysis_release_zenodo_common_self_dir, .analysis_release_zenodo_common_candidates,
    .analysis_release_zenodo_common_path
  )
}

# --------------------------------------------------------------------------- #
# Zenodo API base URLs + publish safety interlock
# --------------------------------------------------------------------------- #

.ANALYSIS_RELEASE_ZENODO_API_PROD <- "https://zenodo.org/api"
.ANALYSIS_RELEASE_ZENODO_API_SANDBOX <- "https://sandbox.zenodo.org/api"

#' Resolve the Zenodo API base URL for the requested environment.
analysis_release_zenodo_resolve_api <- function(sandbox = FALSE) {
  if (isTRUE(sandbox)) {
    .ANALYSIS_RELEASE_ZENODO_API_SANDBOX
  } else {
    .ANALYSIS_RELEASE_ZENODO_API_PROD
  }
}

#' Stop unless BOTH `publish` and `confirm_publish` are set. A `publish`
#' request without explicit confirmation is refused -- draft-only is the
#' default, safe outcome. Mirrors the Python sibling's
#' `require_publish_confirmation()` (there a `SystemExit`; here a `stop()`).
analysis_release_zenodo_require_publish_confirmation <- function(publish, confirm_publish) {
  if (isTRUE(publish) && !isTRUE(confirm_publish)) {
    stop("--publish requires --confirm-publish", call. = FALSE)
  }
  invisible(NULL)
}

# --------------------------------------------------------------------------- #
# DI seams: default httr2 implementations. Tests inject plain stub closures
# with the SAME formal signature instead of mocking httr2/network calls.
# --------------------------------------------------------------------------- #

#' Default JSON request against the Zenodo deposit API. `token` is turned
#' into a `Authorization: Bearer <token>` header; a non-NULL `body` is sent
#' as a JSON object (Content-Type set by `httr2::req_body_json()`). The
#' create-deposition call passes `body = list()`, which `jsonlite::toJSON()`
#' would otherwise serialize as `[]` (an empty *array*) rather than the `{}`
#' Zenodo's API expects for "create an empty deposition" -- special-cased via
#' `req_body_raw()` so the wire format is the literal JSON object Zenodo
#' documents.
.analysis_release_zenodo_http_json <- function(method, url, token, body = NULL) {
  req <- httr2::request(url) |>
    httr2::req_method(method) |>
    httr2::req_headers(Authorization = paste("Bearer", as.character(token)[[1]])) |>
    httr2::req_timeout(60)

  if (!is.null(body)) {
    req <- if (is.list(body) && length(body) == 0) {
      httr2::req_body_raw(req, "{}", type = "application/json")
    } else {
      httr2::req_body_json(req, body, auto_unbox = TRUE)
    }
  }

  resp <- httr2::req_perform(req)
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}

#' Default streaming file PUT to a Zenodo bucket URL. Streams `archive_path`
#' from disk as the raw request body (`httr2::req_body_file()`), Bearer auth,
#' a long timeout (large archives, slow upload links).
.analysis_release_zenodo_http_put_file <- function(url, token, archive_path) {
  httr2::request(url) |>
    httr2::req_method("PUT") |>
    httr2::req_headers(Authorization = paste("Bearer", as.character(token)[[1]])) |>
    httr2::req_timeout(3600) |>
    httr2::req_body_file(archive_path) |>
    httr2::req_perform()
}

# --------------------------------------------------------------------------- #
# Deposition lifecycle
# --------------------------------------------------------------------------- #

#' Get-or-create a Zenodo deposition. `deposition_id = NULL` creates a fresh
#' draft (`POST {api}/deposit/depositions` with an empty JSON object body);
#' an explicit id reuses an existing draft (`GET
#' {api}/deposit/depositions/{id}`). Returns the parsed deposition list.
#'
#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
#'   Injectable seam; defaults to the real httr2 call.
analysis_release_zenodo_get_or_create_deposition <- function(
    api, token, deposition_id = NULL, http = .analysis_release_zenodo_http_json) {
  api <- sub("/+$", "", as.character(api)[[1]])
  if (is.null(deposition_id)) {
    http("POST", paste0(api, "/deposit/depositions"), token, body = list())
  } else {
    deposition_id <- as.character(deposition_id)[[1]]
    http("GET", paste0(api, "/deposit/depositions/", deposition_id), token)
  }
}

#' Overwrite a deposition's metadata. `PUT {api}/deposit/depositions/{id}`
#' with body `{"metadata": <metadata>}`.
#'
#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
analysis_release_zenodo_set_metadata <- function(
    api, token, deposition_id, metadata, http = .analysis_release_zenodo_http_json) {
  api <- sub("/+$", "", as.character(api)[[1]])
  deposition_id <- as.character(deposition_id)[[1]]
  url <- paste0(api, "/deposit/depositions/", deposition_id)
  http("PUT", url, token, body = list(metadata = metadata))
}

#' Stream the archive to the deposition's Zenodo bucket.
#' `PUT {bucket_url}/{basename(archive_path)}`.
#'
#' @param put Function(url, token, archive_path). Injectable seam; defaults
#'   to the real httr2 streaming PUT.
#' @return The upload URL, invisibly.
analysis_release_zenodo_upload_bucket <- function(
    bucket_url, token, archive_path, put = .analysis_release_zenodo_http_put_file) {
  bucket_url <- sub("/+$", "", as.character(bucket_url)[[1]])
  url <- paste0(bucket_url, "/", basename(archive_path))
  put(url, token, archive_path)
  invisible(url)
}

#' Publish a draft deposition. `POST
#' {api}/deposit/depositions/{id}/actions/publish`. Returns the published
#' deposition (`{doi, conceptdoi, id, links: {html, ...}}`).
#'
#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
analysis_release_zenodo_publish_deposition <- function(
    api, token, deposition_id, http = .analysis_release_zenodo_http_json) {
  api <- sub("/+$", "", as.character(api)[[1]])
  deposition_id <- as.character(deposition_id)[[1]]
  url <- paste0(api, "/deposit/depositions/", deposition_id, "/actions/publish")
  http("POST", url, token)
}

# --------------------------------------------------------------------------- #
# DOI record-back (OPT-IN, SysNDD-admin side) -- additive metadata, outside
# any release content hash. Never called automatically; the CLI script only
# invokes `analysis_release_zenodo_record_doi()` when the operator passes
# `--record-doi` AND `SYSNDD_ADMIN_TOKEN` is set. Otherwise it prints
# `analysis_release_zenodo_manual_doi_command()` so the operator can record
# it by hand.
# --------------------------------------------------------------------------- #

.ANALYSIS_RELEASE_ZENODO_DOI_FIELD_NAMES <- c(
  "zenodo_record_id", "zenodo_record_url", "version_doi", "concept_doi"
)

#' Keep only the four recognized DOI fields with a non-empty value. An
#' omitted/NULL/NA/empty-string field is dropped, never forwarded as "",
#' NULL, or NA -- the admin endpoint treats an omitted field as "leave
#' unchanged", so a forwarded empty value would incorrectly clear it.
#' `is.na()` is checked BEFORE `nzchar()` because `nzchar(NA_character_)` is
#' TRUE in R -- without the guard an NA field survives the filter and is
#' emitted as an explicit `null` instead of being omitted.
.analysis_release_zenodo_doi_non_empty_fields <- function(doi_fields) {
  doi_fields <- doi_fields[names(doi_fields) %in% .ANALYSIS_RELEASE_ZENODO_DOI_FIELD_NAMES]
  Filter(function(value) {
    if (is.null(value) || length(value) == 0) {
      return(FALSE)
    }
    scalar <- value[[1]]
    if (is.na(scalar)) {
      return(FALSE)
    }
    nzchar(trimws(as.character(scalar)))
  }, doi_fields)
}

#' PATCH the four Zenodo/DOI provenance fields onto a published release head.
#' Additive-only: forwards ONLY the supplied non-empty fields, matching the
#' admin endpoint's "an omitted field is left unchanged, never nulled out"
#' contract (see AGENTS.md "Analysis-snapshot releases (#573)").
#'
#' @param sysndd_api_base_url Base URL of the SysNDD API.
#' @param admin_token A pre-minted SysNDD Administrator bearer token
#'   (`SYSNDD_ADMIN_TOKEN`). Distinct from the Zenodo `token` used elsewhere
#'   in this file.
#' @param release_id Validated via
#'   `.analysis_release_zenodo_assert_valid_release_id()` BEFORE the admin
#'   PATCH URL is built (Codex round-2 item 2, HIGH) -- an invalid id
#'   (`../evil`, a quote/`;`/newline-shaped value, ...) stops here, before it
#'   is ever placed into the URL.
#' @param patch Function(method, url, token, body = NULL) -> parsed JSON list.
#'   Injectable seam; defaults to the real httr2 call.
analysis_release_zenodo_record_doi <- function(
    sysndd_api_base_url, admin_token, release_id, doi_fields,
    patch = .analysis_release_zenodo_http_json) {
  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
  release_id <- as.character(release_id)[[1]]
  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
  patch("PATCH", url, admin_token, body = fields)
}

#' Build the exact `curl -X PATCH ...` command an operator can run by hand to
#' record DOI/record provenance when `--record-doi` was not opted into (the
#' default). Never executed automatically.
#'
#' Codex round-2 item 2 (HIGH): `release_id` is validated via
#' `.analysis_release_zenodo_assert_valid_release_id()` BEFORE the URL or
#' command string is built -- an invalid id stops here rather than becoming a
#' path-altering URL segment or a copy/paste command-injection payload once
#' printed. Defense in depth: the resolved URL and the JSON body are each
#' `shQuote()`d (POSIX `sh` quoting -- wraps in single quotes and escapes any
#' embedded single quote), so even a doi_fields VALUE containing a quote,
#' `;`, or a newline cannot break out of the single-quoted `curl` arguments.
analysis_release_zenodo_manual_doi_command <- function(sysndd_api_base_url, release_id, doi_fields) {
  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
  release_id <- as.character(release_id)[[1]]
  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
  body_json <- as.character(jsonlite::toJSON(fields, auto_unbox = TRUE))

  paste0(
    "curl -X PATCH ", shQuote(url), " ",
    "-H 'Authorization: Bearer <SYSNDD_ADMIN_TOKEN>' ",
    "-H 'Content-Type: application/json' ",
    "-d ", shQuote(body_json)
  )
}

# --------------------------------------------------------------------------- #
# DOI record-back print step -- the CLI-facing decision of WHEN to
# auto-record vs. print a manual command vs. print instructions-only.
# Lives here (not in the CLI script) so it is directly unit-testable via
# `source_api_file()`, the same convention as the rest of this file.
# --------------------------------------------------------------------------- #

#' Print the (opt-in) DOI record-back step after `analysis_release_zenodo_upload()`
#' completes. Never calls the SysNDD admin endpoint unless the operator
#' explicitly asked for it (`--record-doi`) AND supplied credentials
#' (`SYSNDD_ADMIN_TOKEN`) AND the run reached a real, published DOI.
#'
#' Codex round-2 hardening:
#' - item 2 (HIGH): `release_id` is validated via
#'   `.analysis_release_zenodo_assert_valid_release_id()` immediately after
#'   the "no id supplied" short-circuit and BEFORE any URL or command is
#'   built from it (`record_doi()`/`manual_doi_command()` also validate
#'   internally -- this is defense in depth, not the only gate).
#' - item 3 (MEDIUM): when the upload was a DRAFT (`result$published` is
#'   FALSE), this prints ONLY post-publication instructions -- never a
#'   ready-to-run PATCH command populated with draft values, which would let
#'   an operator record a draft DOI and violate the locked published-only
#'   rule (the automatic `--record-doi` path already gated on `published`;
#'   the PRINTED fallback command previously did not).
#'
#' @param result The list returned by `analysis_release_zenodo_upload()`.
#' @param release_id Operator-supplied `--release-id` (or `NULL`).
#' @param api_base_url Base URL of the SysNDD API.
#' @param record_doi Whether `--record-doi` was passed.
#' @param printer Function(...) used for output; defaults to `cat`.
#'   Injectable seam so tests can capture output without `capture.output()`.
#' @param record_doi_fn Function with `analysis_release_zenodo_record_doi()`'s
#'   signature. Injectable seam (mirrors every other HTTP boundary in this
#'   file) so tests can exercise the automatic-record branch without a real
#'   network call.
analysis_release_zenodo_print_doi_record_back <- function(
    result, release_id, api_base_url, record_doi, printer = cat,
    record_doi_fn = analysis_release_zenodo_record_doi) {
  have_release_id <- !is.null(release_id) && nzchar(as.character(release_id)[[1]])
  if (!have_release_id) {
    printer("\nNo --release-id supplied -- pass one to record or print a DOI record-back command.\n")
    return(invisible(NULL))
  }

  release_id <- as.character(release_id)[[1]]
  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)

  if (!isTRUE(result$published)) {
    printer(
      "\nDraft uploaded (not published) -- a draft DOI is never recorded (published-only ",
      "rule). Publish first with --publish --confirm-publish, then re-run with ",
      "--record-doi (and SYSNDD_ADMIN_TOKEN set), or record the DOI by hand once ",
      "the deposition is published.\n",
      sep = ""
    )
    return(invisible(NULL))
  }

  doi_fields <- list(
    zenodo_record_id = as.character(result$deposition_id),
    zenodo_record_url = result$record_url,
    version_doi = result$version_doi,
    concept_doi = result$concept_doi
  )
  have_published_doi <- !is.na(result$version_doi) && nzchar(as.character(result$version_doi))
  admin_token <- Sys.getenv("SYSNDD_ADMIN_TOKEN", "")

  if (isTRUE(record_doi) && nzchar(admin_token) && have_published_doi) {
    updated <- record_doi_fn(
      sysndd_api_base_url = api_base_url,
      admin_token = admin_token,
      release_id = release_id,
      doi_fields = doi_fields
    )
    printer("\nDOI recorded on the SysNDD release head:\n")
    printer(sprintf("  release_id:        %s\n", updated$release_id %||% release_id))
    printer(sprintf("  version_doi:       %s\n", updated$version_doi %||% doi_fields$version_doi))
    printer(sprintf("  zenodo_record_url: %s\n", updated$zenodo_record_url %||% doi_fields$zenodo_record_url))
  } else {
    printer(
      "\nDOI not recorded automatically",
      if (!have_published_doi) " (no published DOI)" else "",
      ". Run with --record-doi and SYSNDD_ADMIN_TOKEN set, ",
      "or record it by hand:\n",
      sep = ""
    )
    printer(analysis_release_zenodo_manual_doi_command(api_base_url, release_id, doi_fields), "\n")
  }
  invisible(NULL)
}

# --------------------------------------------------------------------------- #
# Orchestrator -- mirrors the Python sibling's `main()` flow. Pure w.r.t.
# SysNDD: it never calls `analysis_release_zenodo_record_doi()` itself (the
# CLI script does that, after this returns).
# --------------------------------------------------------------------------- #

#' Upload a packaged Zenodo archive: get-or-create deposition -> set metadata
#' -> stream archive to bucket -> (if `publish`) publish. Draft-only unless
#' BOTH `publish` and `confirm_publish` are set (enforced first, via
#' `analysis_release_zenodo_require_publish_confirmation()`).
#'
#' @return list(deposition_id, reserved_doi, draft_url, published (bool),
#'   version_doi, concept_doi, record_url). `version_doi`/`concept_doi`/
#'   `record_url` are `NA_character_` unless `published` is TRUE.
analysis_release_zenodo_upload <- function(
    archive_path,
    metadata_path,
    token,
    sandbox = FALSE,
    deposition_id = NULL,
    publish = FALSE,
    confirm_publish = FALSE,
    get_or_create_deposition = analysis_release_zenodo_get_or_create_deposition,
    set_metadata = analysis_release_zenodo_set_metadata,
    upload_bucket = analysis_release_zenodo_upload_bucket,
    publish_deposition = analysis_release_zenodo_publish_deposition) {
  analysis_release_zenodo_require_publish_confirmation(publish, confirm_publish)

  if (is.null(token) || !nzchar(as.character(token)[[1]])) {
    # No `--token` CLI flag exists (item 6, #573 Slice C hardening) -- a
    # flag would leak the token into shell history/argv. The `token`
    # parameter here is for programmatic/test callers only; the CLI wrapper
    # always resolves it from `Sys.getenv("ZENODO_TOKEN")`.
    stop("ZENODO_TOKEN not set (export it in your shell before running this script)", call. = FALSE)
  }
  if (!file.exists(archive_path)) {
    stop(sprintf("Archive does not exist: %s", archive_path), call. = FALSE)
  }
  if (!file.exists(metadata_path)) {
    stop(sprintf("Metadata does not exist: %s", metadata_path), call. = FALSE)
  }

  api <- analysis_release_zenodo_resolve_api(sandbox)
  metadata <- jsonlite::fromJSON(metadata_path, simplifyVector = FALSE)

  deposition <- get_or_create_deposition(api, token, deposition_id = deposition_id)
  resolved_deposition_id <- deposition$id
  bucket_url <- deposition$links$bucket
  reserved_doi <- deposition$metadata$prereserve_doi$doi

  set_metadata(api, token, resolved_deposition_id, metadata)
  upload_bucket(bucket_url, token, archive_path)

  result <- list(
    deposition_id = resolved_deposition_id,
    reserved_doi = reserved_doi %||% NA_character_,
    draft_url = deposition$links$html %||% NA_character_,
    published = FALSE,
    version_doi = NA_character_,
    concept_doi = NA_character_,
    record_url = NA_character_
  )

  if (isTRUE(publish)) {
    published_deposition <- publish_deposition(api, token, resolved_deposition_id)
    result$published <- TRUE
    result$version_doi <- published_deposition$doi %||% NA_character_
    result$concept_doi <- published_deposition$conceptdoi %||% NA_character_
    result$record_url <- published_deposition$links$html %||% NA_character_
  }

  result
}
