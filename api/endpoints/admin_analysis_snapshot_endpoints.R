## -------------------------------------------------------------------##
# api/endpoints/admin_analysis_snapshot_endpoints.R
#
# Administrator-only HTTP triggers for the durable public analysis snapshots that
# the /api/analysis/* read endpoints serve. Mounted at /api/admin/analysis, so:
#   POST /api/admin/analysis/snapshots/refresh  (submit refresh jobs)
#   GET  /api/admin/analysis/snapshots/status   (per-preset manifest state)
#
# All three snapshot submit paths (startup hook, this endpoint, and the operator
# script scripts/refresh-analysis-snapshots.R) share one function,
# service_analysis_snapshot_submit_refresh(), so submission logic is not
# duplicated. Spec: .planning/superpowers/specs/2026-06-14-analysis-snapshot-bootstrap-design.md
#
# #573 Slice A / Task A7 appends 6 Administrator-only routes for immutable,
# content-addressed public analysis-snapshot RELEASES: build/list/detail/
# publish/record-DOI/delete-draft. The mutating routes (build, publish, set
# DOI, delete draft) thinly delegate to the A5 service layer
# (services/analysis-snapshot-release-service.R, `svc_release_*`); the two
# admin READS that must see DRAFT rows call the A3 repository
# (functions/analysis-snapshot-release-repository.R) directly with
# `include_draft = TRUE` / `status = NULL` -- the sibling
# svc_release_list()/svc_release_get() in the service layer are
# PUBLISHED-ONLY by design (the public routes in analysis_endpoints.R use
# those), so this file bypasses them for the two admin listings. The service
# file and the four release function files are wired into
# bootstrap/load_modules.R by Task A8, so these routes are live.
## -------------------------------------------------------------------##

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

#* Submit analysis snapshot refresh jobs (Administrator only)
#*
#* Idempotently submits `analysis_snapshot_refresh` jobs so the worker rebuilds +
#* activates the durable public-ready snapshots. By default only presets without a
#* current public-ready snapshot are submitted; pass `force=true` to rebuild all.
#* Re-submitting a queued/running refresh returns the existing job (dedup).
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @param analysis_type:str Optional single preset (e.g. "gene_network_edges"). Omit for all supported presets.
#* @param force:bool Optional; rebuild even when a current snapshot exists. Default false.
#*
#* @post /snapshots/refresh
function(req, res, analysis_type = NULL, force = FALSE) {
  require_role(req, res, "Administrator")

  at <- if (is.null(analysis_type) || !nzchar(as.character(analysis_type[[1]]))) {
    NULL
  } else {
    as.character(analysis_type[[1]])
  }
  force_flag <- isTRUE(force) ||
    identical(tolower(as.character(force)[[1]]), "true") ||
    identical(as.character(force)[[1]], "1")

  summary <- service_analysis_snapshot_submit_refresh(analysis_type = at, force = force_flag)

  res$status <- 202L
  summary
}

#* Per-preset analysis snapshot status (Administrator only)
#*
#* Returns the manifest state (missing / available / stale /
#* source_version_mismatch) for each supported analysis preset, with timestamps
#* and stored row counts, so an operator can watch a rebuild progress without DB
#* access.
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @get /snapshots/status
function(req, res) {
  require_role(req, res, "Administrator")
  service_analysis_snapshot_status()
}

## -------------------------------------------------------------------##
## Analysis-snapshot RELEASES: admin routes (#573 Slice A / Task A7)
## -------------------------------------------------------------------##

#' Parse a POST/PATCH JSON request body with `jsonlite::fromJSON(simplifyVector
#' = FALSE)`, NOT Plumber's default `req$argsBody` (`plumber:::safeFromJSON`,
#' which parses with `simplifyVector = TRUE`).
#'
#' This matters specifically for `POST /releases`'s optional `layers` array
#' override. Verified live: `simplifyVector = TRUE` collapses a JSON array of
#' layer-override objects into a *data.frame* -- and a nested object field
#' (e.g. `params`) collapses into its OWN nested data.frame column when every
#' layer shares the same param keys. `analysis_snapshot_release_build()`
#' iterates its `layers` argument with `lapply(layers, function(layer)
#' layer$analysis_type[[1]])`; iterating a data.frame with `lapply()` walks
#' the data.frame's COLUMNS (atomic vectors), the same "$ operator is invalid
#' for atomic vectors" trap AGENTS.md documents for the force-apply payload
#' helpers (`functions/async-job-force-apply-payload.R`). Re-parsing the raw
#' body text with `simplifyVector = FALSE` instead -- the same call
#' `core/logging_sanitizer.R`'s `sanitize_post_body_for_log()` already makes
#' on `req$postBody` -- yields the EXACT list-of-named-lists shape
#' `analysis_snapshot_release_layers()` itself returns (each layer's `params`
#' comes back as a genuine named list too), so a caller-supplied `layers`
#' override needs no further normalization before being forwarded to
#' `svc_release_build()`. `req$postBody` is populated by Plumber's default
#' `bodyFilter` for every request with a body, independent of any `@parser`
#' annotation on this route.
#'
#' @noRd
.admin_release_parse_json_body <- function(req) {
  raw <- tryCatch(req$postBody, error = function(e) NULL)
  if (is.null(raw) || !nzchar(raw)) {
    return(list())
  }
  tryCatch(
    jsonlite::fromJSON(raw, simplifyVector = FALSE),
    error = function(e) stop_for_bad_request("Malformed JSON request body")
  )
}

#' Defensively parse a query-string integer with a default.
#'
#' A file-local duplicate of the identically-named helper in
#' `endpoints/analysis_endpoints.R`: each endpoints file is mounted as its
#' OWN Plumber sub-router / environment (`plumber::pr(file)`), so a top-level
#' helper defined in a sibling endpoints file is not visible here.
#'
#' @noRd
.admin_release_query_int <- function(value, default) {
  scalar <- if (is.null(value)) default else value[[1]]
  parsed <- suppressWarnings(as.integer(scalar))
  if (is.na(parsed)) default else parsed
}

#* Build (and, by default, publish) a new analysis-snapshot release (Administrator only)
#*
#* Loads the currently active public-ready snapshots for the fixed layer
#* registry (or a caller-supplied `layers` override -- see the JSON body
#* shape below), gates them (available + hard coherence + reproducibility
#* presence + shared source-data version + dependency lineage), materializes
#* the release files, and persists an immutable, content-addressed release.
#* A rebuild whose content is IDENTICAL to an existing release is idempotent
#* (200, same release_id, no duplicate row); a genuinely new content set is
#* 201. A gate failure (a layer not available / incoherent / missing its
#* reproducibility bundle / mismatched source version or dependency lineage)
#* is 400, naming the failing layer.
#*
#* JSON body (all fields optional): `{ layers?: [...], title?,
#* scope_statement?, license?, publish? }`. `publish` defaults to `true`;
#* `false` stages a draft for review before a Zenodo run. `license` defaults
#* to `"CC-BY-4.0"`. Omitting `layers` uses the fixed default registry
#* (`analysis_snapshot_release_layers()`).
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @post /releases
function(req, res) {
  require_role(req, res, "Administrator")

  body <- .admin_release_parse_json_body(req)
  publish_flag <- if (is.null(body$publish)) TRUE else isTRUE(body$publish)

  # analysis_snapshot_release_build() ultimately calls
  # analysis_release_insert(), which wraps its writes in ONE
  # DBI::dbWithTransaction() and binds blob params via list(<raw>) -- both
  # need a real DBIConnection, never the global `pool` Pool object directly
  # (see functions/analysis-snapshot-release-repository.R's file header).
  # The other 5 admin routes below issue single non-transactional
  # dbExecute()/dbGetQuery() calls, which pool::Pool supports directly.
  conn <- pool::poolCheckout(pool)
  on.exit(pool::poolReturn(conn), add = TRUE)

  svc_release_build(
    res,
    layers = body$layers,
    title = body$title,
    scope_statement = body$scope_statement,
    license = body$license %||% "CC-BY-4.0",
    publish = publish_flag,
    created_by = req$user_id,
    conn = conn
  )
}

#* List ALL analysis-snapshot releases, including drafts (Administrator only)
#*
#* Unlike the public `GET /api/analysis/releases` (published-only, see
#* `svc_release_list()`), this admin listing includes draft rows so an
#* operator can see an in-progress/failed build before it is published or
#* deleted.
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @param limit:int Optional page size. Default 50.
#* @param offset:int Optional page offset. Default 0.
#*
#* @get /releases
function(req, res, limit = NULL, offset = NULL) {
  require_role(req, res, "Administrator")

  limit_int <- .admin_release_query_int(limit, 50L)
  offset_int <- .admin_release_query_int(offset, 0L)
  releases <- analysis_release_list(status = NULL, limit = limit_int, offset = offset_int, conn = pool)

  list(
    releases = releases,
    pagination = list(limit = limit_int, offset = offset_int, count = length(releases))
  )
}

#* Fetch one analysis-snapshot release, including a draft (Administrator only)
#*
#* Unlike the public `GET /api/analysis/releases/<id>` (published-only, see
#* `svc_release_get()`), this admin detail resolves a draft release too.
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @get /releases/<release_id>
function(req, res, release_id) {
  require_role(req, res, "Administrator")

  head <- analysis_release_get(release_id, include_draft = TRUE, conn = pool)
  if (is.null(head)) {
    stop_for_not_found("Release not found")
  }
  head
}

#* Publish a draft analysis-snapshot release (Administrator only)
#*
#* Unknown release id -> 404. Publishing an already-published release is an
#* idempotent no-op. Returns the (published) release head.
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @post /releases/<release_id>/publish
function(req, res, release_id) {
  require_role(req, res, "Administrator")
  svc_release_publish(release_id, conn = pool)
}

#* Record external Zenodo/DOI provenance on a release (Administrator only)
#*
#* Additive metadata only; NEVER touches the release's `content_digest` /
#* `manifest_sha256` (release scientific identity is immutable once minted).
#* Any subset of the four fields may be supplied -- an omitted field is left
#* unchanged, it is never cleared/nulled out.
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @param zenodo_record_id:str Optional.
#* @param zenodo_record_url:str Optional.
#* @param version_doi:str Optional.
#* @param concept_doi:str Optional.
#*
#* @patch /releases/<release_id>/doi
function(req, res, release_id, zenodo_record_id = NULL, zenodo_record_url = NULL,
         version_doi = NULL, concept_doi = NULL) {
  require_role(req, res, "Administrator")

  doi_fields <- list(
    zenodo_record_id = zenodo_record_id,
    zenodo_record_url = zenodo_record_url,
    version_doi = version_doi,
    concept_doi = concept_doi
  )
  # Only forward fields the caller actually supplied -- list(a = NULL) still
  # keeps the name "a", so an unfiltered pass-through would overwrite every
  # omitted field to NULL instead of leaving it unchanged.
  doi_fields <- doi_fields[!vapply(doi_fields, is.null, logical(1))]

  svc_release_set_doi(release_id, doi_fields = doi_fields, conn = pool)
}

#* Delete a draft analysis-snapshot release (Administrator only)
#*
#* Unknown release id -> 404. Refuses (400) once the release is published --
#* releases are retained indefinitely once published; only a draft (e.g. a
#* failed/aborted build) can be discarded.
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @delete /releases/<release_id>
function(req, res, release_id) {
  require_role(req, res, "Administrator")
  svc_release_delete_draft(release_id, conn = pool)
}
