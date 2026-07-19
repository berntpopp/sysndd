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
# and lives OUTSIDE this pure orchestrator (it is invoked by the CLI script,
# Deliverable 3), so this file stays free of SysNDD-admin coupling and easy to
# test in isolation.

`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0) {
    b
  } else {
    a
  }
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
#' @param patch Function(method, url, token, body = NULL) -> parsed JSON list.
#'   Injectable seam; defaults to the real httr2 call.
analysis_release_zenodo_record_doi <- function(
    sysndd_api_base_url, admin_token, release_id, doi_fields,
    patch = .analysis_release_zenodo_http_json) {
  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
  release_id <- as.character(release_id)[[1]]
  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
  patch("PATCH", url, admin_token, body = fields)
}

#' Build the exact `curl -X PATCH ...` command an operator can run by hand to
#' record DOI/record provenance when `--record-doi` was not opted into (the
#' default). Never executed automatically.
analysis_release_zenodo_manual_doi_command <- function(sysndd_api_base_url, release_id, doi_fields) {
  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
  release_id <- as.character(release_id)[[1]]
  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
  body_json <- as.character(jsonlite::toJSON(fields, auto_unbox = TRUE))

  paste0(
    "curl -X PATCH '", url, "' ",
    "-H 'Authorization: Bearer <SYSNDD_ADMIN_TOKEN>' ",
    "-H 'Content-Type: application/json' ",
    "-d '", body_json, "'"
  )
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
    stop("ZENODO_TOKEN not set and --token not provided", call. = FALSE)
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
