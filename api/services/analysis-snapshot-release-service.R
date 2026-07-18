# services/analysis-snapshot-release-service.R
#
# Service layer for immutable, content-addressed public analysis-snapshot
# RELEASES (#573 Slice A / Task A5). Shapes the A4 build orchestrator
# (`functions/analysis-snapshot-release.R`) and the A3 repository
# (`functions/analysis-snapshot-release-repository.R`) into problem+json HTTP
# semantics for the endpoint layer (wired into `bootstrap/load_modules.R` by
# Task A8).
#
# ERROR CONTRACT. Only the FOUR existing error classes exist in this repo:
# 400 (`stop_for_bad_request`), 401, 403 (`stop_for_forbidden`, enforced by
# the endpoint's `require_role()`, not here), and 404 (`stop_for_not_found`).
# There is deliberately NO 409 class — a "sources not ready" build rejection
# is a 400, not a conflict. The mounted errorHandler (`core/filters.R`)
# serializes `conditionMessage(err)` (the classed condition's `message`) into
# the problem+json body, NOT `detail` — so every user-facing reason is passed
# as the `message` argument to `stop_for_*()`, never `detail`.
#
# BUILD MAPPING. `svc_release_build()` calls the A4 orchestrator inside a
# `tryCatch()` that maps its five classed `release_*` conditions
# (`release_snapshot_not_available`, `release_source_incoherent`,
# `release_reproducibility_missing`, `release_source_version_mismatch`,
# `release_dependency_lineage_mismatch`) to `stop_for_bad_request()`, passing
# the ORIGINAL `conditionMessage()` through verbatim (it already names the
# failing layer/analysis_type and the concrete reason). Any OTHER error is
# left to propagate unmapped (falls through to the generic 500 path). A
# DUPLICATE/idempotent build (`created = FALSE`) is NOT an error: the caller
# gets 200 + the existing head instead of 201 + the new head.
#
# PUBLIC SURFACE. `svc_release_list/get/manifest/file/bundle()` are the
# published-only public read surface: every repository call is pinned to
# `status = "published"` / `include_draft = FALSE`, so a draft release (or an
# unknown release id, or an unknown archive file path) is indistinguishable
# from the caller's point of view — both resolve to a plain 404. Drafts are
# NEVER returned publicly.
#
# ADMIN SURFACE. `svc_release_build/publish/set_doi/delete_draft()` are
# admin-only from the caller's perspective (the endpoint layer is expected to
# gate with `require_role(req, res, "Administrator")` before calling in, the
# same pattern as the other `svc_*` admin services in this directory); this
# file does not itself check roles.
#
# `svc_` prefix avoids shadowing the `analysis_release_*`/
# `analysis_snapshot_release_build` repository/orchestrator functions in the
# global search path (AGENTS.md service-prefix invariant).

# --------------------------------------------------------------------------- #
# Admin
# --------------------------------------------------------------------------- #

#' Build (and, by default, publish) a new analysis-snapshot release.
#'
#' Thin problem+json shim over `analysis_snapshot_release_build()`. On
#' success mutates `res$status` (201 for a newly-created release, 200 for an
#' idempotent duplicate) and returns the release head. On a gate failure
#' (any of the five classed `release_*` conditions), raises a 400 whose
#' message is the original `conditionMessage()` verbatim. Any other error
#' propagates unmapped.
#'
#' @param res Plumber response, mutated in place (`$status`).
#' @param layers Optional layer registry override; when `NULL` the
#'   orchestrator's own default (`analysis_snapshot_release_layers()`) is
#'   used — `layers` is only forwarded when the caller supplies one.
#' @param title,scope_statement,license Presentation metadata.
#' @param publish Whether to flip the inserted draft to `published`.
#' @param created_by Optional user id recorded on the head row.
#' @param conn A real DBIConnection (the orchestrator persists via A3).
#' @return The release head (a named list).
#' @export
svc_release_build <- function(res,
                               layers = NULL,
                               title = NULL,
                               scope_statement = NULL,
                               license = "CC-BY-4.0",
                               publish = TRUE,
                               created_by = NULL,
                               conn = NULL) {
  build_args <- list(
    title = title,
    scope_statement = scope_statement,
    license = license,
    publish = publish,
    created_by = created_by,
    conn = conn
  )
  if (!is.null(layers)) {
    build_args$layers <- layers
  }

  result <- tryCatch(
    do.call(analysis_snapshot_release_build, build_args),
    release_snapshot_not_available = function(e) stop_for_bad_request(conditionMessage(e)),
    release_source_incoherent = function(e) stop_for_bad_request(conditionMessage(e)),
    release_reproducibility_missing = function(e) stop_for_bad_request(conditionMessage(e)),
    release_source_version_mismatch = function(e) stop_for_bad_request(conditionMessage(e)),
    release_dependency_lineage_mismatch = function(e) stop_for_bad_request(conditionMessage(e))
  )

  res$status <- if (isTRUE(result$created)) 201L else 200L
  result$release
}

#' Publish a draft release.
#'
#' Publishing an unknown release id is the only failure mode (404).
#' Publishing an already-published release is an idempotent no-op (the
#' repository's `analysis_release_publish()` already no-ops when the row is
#' not currently a draft) — either way the caller gets the current head back.
#'
#' @param release_id Release id (`asr_<16 hex>`).
#' @param conn A real DBIConnection.
#' @return The (published) release head.
#' @export
svc_release_publish <- function(release_id, conn = NULL) {
  analysis_release_publish(release_id, conn = conn)
  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
  if (is.null(head)) {
    stop_for_not_found(sprintf("Release '%s' not found", release_id))
  }
  head
}

#' Record external Zenodo/DOI provenance on an existing release.
#'
#' Additive metadata only (forwarded verbatim to the repository, which never
#' touches `content_digest`/`manifest_sha256` — release scientific identity
#' is immutable once minted). Unknown release id -> 404.
#'
#' @param release_id Release id.
#' @param doi_fields Named list, any subset of `zenodo_record_id`,
#'   `zenodo_record_url`, `version_doi`, `concept_doi`.
#' @param conn A real DBIConnection.
#' @return The updated release head.
#' @export
svc_release_set_doi <- function(release_id, doi_fields, conn = NULL) {
  analysis_release_set_doi(release_id, doi_fields = doi_fields, conn = conn)
  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
  if (is.null(head)) {
    stop_for_not_found(sprintf("Release '%s' not found", release_id))
  }
  head
}

#' Delete a draft release (e.g. a failed/aborted build).
#'
#' Unknown release id -> 404. A published release is immutable/retained
#' indefinitely -> 400 (only drafts are deletable). A draft is deleted and
#' `list(deleted = TRUE, release_id = release_id)` is returned.
#'
#' @param release_id Release id.
#' @param conn A real DBIConnection.
#' @return `list(deleted = TRUE, release_id = release_id)`.
#' @export
svc_release_delete_draft <- function(release_id, conn = NULL) {
  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
  if (is.null(head)) {
    stop_for_not_found(sprintf("Release '%s' not found", release_id))
  }
  if (!identical(as.character(head$status), "draft")) {
    stop_for_bad_request("Cannot delete a published release; only drafts are deletable")
  }
  analysis_release_delete_draft(release_id, conn = conn)
  list(deleted = TRUE, release_id = release_id)
}

# --------------------------------------------------------------------------- #
# Public (published-only)
# --------------------------------------------------------------------------- #

#' List published releases (newest first).
#'
#' @param limit,offset Pagination.
#' @param conn A real DBIConnection.
#' @return Whatever shape `analysis_release_list()` returns (a list of
#'   release-head-plus-layers entries); never includes drafts.
#' @export
svc_release_list <- function(limit = 50, offset = 0, conn = NULL) {
  analysis_release_list(status = "published", limit = limit, offset = offset, conn = conn)
}

#' Fetch one published release's head + parsed manifest.
#'
#' Unknown id OR a draft release -> 404 (indistinguishable to the caller;
#' `include_draft = FALSE` makes the repository's own SQL filter the only
#' source of truth for visibility).
#'
#' @param release_id Release id.
#' @param conn A real DBIConnection.
#' @return The release head (+ `$manifest`).
#' @export
svc_release_get <- function(release_id, conn = NULL) {
  head <- analysis_release_get(release_id, include_draft = FALSE, conn = conn)
  if (is.null(head)) {
    stop_for_not_found("Release not found")
  }
  head
}

#' Fetch a published release's stored `manifest.json` file.
#'
#' @param release_id Release id.
#' @param conn A real DBIConnection.
#' @return `list(bytes, media_type = "application/json", content_sha256)`.
#' @export
svc_release_manifest <- function(release_id, conn = NULL) {
  file <- analysis_release_get_file(release_id, "manifest.json", include_draft = FALSE, conn = conn)
  if (is.null(file)) {
    stop_for_not_found("Release not found")
  }
  list(bytes = file$bytes, media_type = "application/json", content_sha256 = file$content_sha256)
}

#' Fetch one archive file's bytes from a published release by exact path.
#'
#' Unknown release, a draft release, or an unknown `file_path` all resolve to
#' the same 404 (never distinguished for the caller).
#'
#' @param release_id Release id.
#' @param file_path Exact archive-relative path (e.g. `"README.md"`,
#'   `"functional_clusters/payload.json"`).
#' @param conn A real DBIConnection.
#' @return `list(bytes, media_type, content_sha256)`.
#' @export
svc_release_file <- function(release_id, file_path, conn = NULL) {
  file <- analysis_release_get_file(release_id, file_path, include_draft = FALSE, conn = conn)
  if (is.null(file)) {
    stop_for_not_found(sprintf("Release file not found: %s", file_path))
  }
  list(bytes = file$bytes, media_type = file$media_type, content_sha256 = file$content_sha256)
}

#' Fetch a published release's whole archive (`bundle.tar.gz`) verbatim.
#'
#' @param release_id Release id.
#' @param conn A real DBIConnection.
#' @return `list(bytes, sha256, filename)`.
#' @export
svc_release_bundle <- function(release_id, conn = NULL) {
  bundle <- analysis_release_get_bundle(release_id, include_draft = FALSE, conn = conn)
  if (is.null(bundle)) {
    stop_for_not_found("Release not found")
  }
  list(bytes = bundle$bytes, sha256 = bundle$sha256, filename = bundle$filename)
}
