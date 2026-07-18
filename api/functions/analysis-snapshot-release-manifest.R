# Pure, DB-free helpers for immutable public analysis-snapshot RELEASES
# (#573 Slice A / Task A2): the layer registry, content-address identity
# (content_digest / release_id), the manifest.json / checksums.sha256
# builders, and the deterministic tar.gz archive writer.
#
# These functions define release IDENTITY and file contracts consumed by
# later tasks (repository persistence, build orchestrator). They must stay
# pure: no DB access, no network, no side effects beyond a scratch tempdir
# used internally by `analysis_release_build_tar_gz()`.
#
# Reuses the EXISTING canonical JSON serializer from
# `analysis-snapshot-presets.R` (`analysis_snapshot_canonical_json()`, sourced
# by callers before this file) so release file bytes hash identically to the
# bytes the public snapshot API already serves. Do not reimplement it here.

ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION <- "1.0"

#' Default analysis layers bundled into a release.
#'
#' Registry-driven (a list, single source of truth): which analysis types are
#' included, the locked snapshot params used to select their source snapshot,
#' the archive path prefix for that layer's files, and whether a
#' reproducibility bundle is expected for it.
#'
#' @return list of `list(analysis_type, params, files_prefix,
#'   has_reproducibility)`.
analysis_snapshot_release_layers <- function() {
  list(
    list(
      analysis_type = "functional_clusters",
      params = list(algorithm = "leiden"),
      files_prefix = "functional_clusters",
      has_reproducibility = TRUE
    ),
    list(
      analysis_type = "phenotype_clusters",
      params = list(),
      files_prefix = "phenotype_clusters",
      has_reproducibility = TRUE
    ),
    list(
      analysis_type = "phenotype_functional_correlations",
      params = list(algorithm = "leiden"),
      files_prefix = "phenotype_functional_correlations",
      has_reproducibility = FALSE
    )
  )
}

#' Resolve a caller-supplied `layers` request to authoritative REGISTRY entries.
#'
#' `layers` in a build request is a SELECTION, never a policy redefinition: each
#' requested entry is read ONLY for its `analysis_type` (accepting either a bare
#' string or a `{analysis_type, ...}` object), matched against the authoritative
#' `analysis_snapshot_release_layers()` registry, and the REGISTRY entry is
#' returned — so the caller can never override `params`, `files_prefix`, or the
#' gate-controlling `has_reproducibility` (which would let an Admin skip the hard
#' coherence / reproducibility gates, or path-traverse via `files_prefix`).
#'
#' NULL/absent `requested` -> the full registry unchanged. An unknown or
#' duplicated `analysis_type` -> 400 (`stop_for_bad_request`).
#'
#' @param requested NULL, or a list of selectors (strings or `{analysis_type}`).
#' @return list of registry layer entries (a subset of the registry, in request
#'   order).
analysis_snapshot_release_resolve_layers <- function(requested = NULL) {
  registry <- analysis_snapshot_release_layers()
  if (is.null(requested) || length(requested) == 0L) {
    return(registry)
  }

  registry_types <- vapply(registry, function(layer) layer$analysis_type, character(1))
  registry_by_type <- stats::setNames(registry, registry_types)

  seen <- character(0)
  lapply(requested, function(entry) {
    analysis_type <- if (is.list(entry)) entry$analysis_type else entry
    analysis_type <- as.character(analysis_type %||% "")[[1]]
    if (!nzchar(analysis_type)) {
      stop_for_bad_request("release layer selector is missing analysis_type")
    }
    if (analysis_type %in% seen) {
      stop_for_bad_request(sprintf("duplicate release layer: %s", analysis_type))
    }
    seen <<- c(seen, analysis_type)
    match <- registry_by_type[[analysis_type]]
    if (is.null(match)) {
      stop_for_bad_request(sprintf("unknown release layer: %s", analysis_type))
    }
    match
  })
}

#' Reject an archive-relative file path that could escape the archive root.
#'
#' Defense-in-depth against path traversal: rejects any path that is empty,
#' absolute (leading `/` or a Windows drive), contains a backslash separator, or
#' contains a `..` segment. Called for every materialized file path AND every
#' path written into the tar archive (`analysis_release_build_tar_gz`).
#'
#' @param path chr, an archive-relative file path.
#' @return invisibly TRUE; throws on an unsafe path.
.analysis_release_assert_safe_path <- function(path) {
  p <- as.character(path)[[1]]
  segments <- strsplit(p, "/", fixed = TRUE)[[1]]
  if (!nzchar(p) ||
    startsWith(p, "/") ||
    grepl("^[A-Za-z]:[\\\\/]", p) ||
    grepl("\\\\", p) ||
    any(segments == "..")) {
    stop(sprintf("unsafe release file path: %s", p), call. = FALSE)
  }
  invisible(TRUE)
}

#' UTF-8 raw bytes of the canonical JSON serialization of `obj`.
#'
#' Uses the SAME serializer as the public snapshot API
#' (`analysis_snapshot_canonical_json()`), so release file bytes hash
#' identically to the corresponding public API response bytes.
#'
#' @param obj Any value accepted by `analysis_snapshot_canonical_json()`.
#' @return raw vector.
analysis_release_canonical_bytes <- function(obj) {
  charToRaw(enc2utf8(analysis_snapshot_canonical_json(obj)))
}

#' SHA-256 hex digest of raw bytes or a character string.
#'
#' Repo-wide convention: `digest::digest(x, algo = "sha256", serialize =
#' FALSE)`. With `serialize = FALSE`, a raw vector is hashed as its bytes
#' directly and a character string is hashed as its string content, so this
#' accepts either without branching.
#'
#' @param raw_or_chr raw vector or a length-1 character string.
#' @return chr, a 64-character lowercase hex sha256 digest.
analysis_release_sha256 <- function(raw_or_chr) {
  digest::digest(raw_or_chr, algo = "sha256", serialize = FALSE)
}

#' Order-independent content digest: the identity basis for a release.
#'
#' Deliberately excludes `created_at`, `title`, and any DOI — release
#' identity is pure scientific content (each layer's input/payload/
#' reproducibility hashes and dependencies, plus the source data version and
#' manifest schema version), never presentation metadata. `layer_entries` is
#' sorted by `analysis_type` before hashing so caller-supplied ordering never
#' changes the digest.
#'
#' @param layer_entries list of list(analysis_type, input_hash, payload_hash,
#'   reproducibility_hash, dependencies).
#' @param source_data_version chr.
#' @param manifest_schema_version chr.
#' @return chr, a 64-character lowercase hex sha256 digest.
analysis_release_content_digest <- function(layer_entries, source_data_version, manifest_schema_version) {
  analysis_types <- vapply(layer_entries, function(entry) entry$analysis_type, character(1))
  # method = "radix" is locale-invariant: the content identity must not depend on
  # the builder's LC_COLLATE (de-risks cross-host #574 reproducibility).
  sorted_entries <- layer_entries[order(analysis_types, method = "radix")]

  identity_layers <- lapply(sorted_entries, function(entry) {
    entry[c("analysis_type", "input_hash", "payload_hash", "reproducibility_hash", "dependencies")]
  })

  identity_obj <- list(
    manifest_schema_version = manifest_schema_version,
    source_data_version = source_data_version,
    layers = identity_layers
  )

  analysis_release_sha256(analysis_release_canonical_bytes(identity_obj))
}

#' Short, readable release handle derived from the content digest.
#'
#' The first 16 hex characters (64 bits) of the content digest, prefixed
#' `asr_`. This is a human/URL-facing handle only; the full content digest is
#' the authoritative identity value and is stored separately by later tasks.
#'
#' @param content_digest chr, as returned by `analysis_release_content_digest()`.
#' @return chr, matching `^asr_[0-9a-f]{16}$` for a well-formed digest.
analysis_release_id <- function(content_digest) {
  paste0("asr_", substr(content_digest, 1, 16))
}

#' Build the release `manifest.json` R list.
#'
#' `fields$files` is the caller-computed flat file list (one
#' `list(path, sha256, bytes)` entry per archive member). Neither
#' `manifest.json` nor `checksums.sha256` can describe their own checksum, so
#' both are excluded from the `files[]` array in the built manifest.
#'
#' @param fields list with elements `release_id`, `release_version`, `title`,
#'   `created_at`, `license`, `scope_statement`, `generator`, `source`,
#'   `layers`, `files`, `content_digest`.
#' @return list, the manifest ready for `analysis_snapshot_canonical_json()`.
analysis_release_build_manifest <- function(fields) {
  self_describing_paths <- c("manifest.json", "checksums.sha256")
  files <- Filter(function(f) !(f$path %in% self_describing_paths), fields$files)

  list(
    release_id = fields$release_id,
    release_version = fields$release_version,
    title = fields$title,
    created_at = fields$created_at,
    license = fields$license,
    scope_statement = fields$scope_statement,
    generator = fields$generator,
    source = fields$source,
    layers = fields$layers,
    files = files,
    content_digest = fields$content_digest
  )
}

#' Build the `checksums.sha256` file content.
#'
#' One `"<sha256>  <path>\n"` line per file (the classic `sha256sum` format),
#' excluding `checksums.sha256` itself since a file cannot list its own
#' checksum.
#'
#' @param files list of `list(path, sha256, bytes)`.
#' @return chr, the full checksums file text (empty string if `files` yields
#'   no lines after exclusion).
analysis_release_checksums_text <- function(files) {
  files <- Filter(function(f) f$path != "checksums.sha256", files)
  if (length(files) == 0) {
    return("")
  }
  lines <- vapply(files, function(f) paste0(f$sha256, "  ", f$path), character(1))
  paste0(paste(lines, collapse = "\n"), "\n")
}

#' Build a gzip-compressed tar archive from named raw vectors.
#'
#' `named_raw_list` is a named list of `path = raw_bytes`; each name becomes
#' a (possibly nested, e.g. `"functional_clusters/reproducibility.json.gz"`)
#' relative file path inside the archive. Built ONCE at release-build time
#' and stored/served verbatim thereafter, so byte-level rebuild determinism
#' is NOT required here — per-file `checksums.sha256` entries plus the
#' manifest are the verification anchors for individual file contents. Paths
#' are sorted purely for a stable, readable archive listing order.
#'
#' @param named_raw_list named list of raw vectors, keyed by archive-relative
#'   path.
#' @return raw vector, the gzip-compressed tar archive bytes.
analysis_release_build_tar_gz <- function(named_raw_list) {
  paths <- names(named_raw_list)
  stopifnot(
    "named_raw_list must be a non-empty named list" = length(paths) > 0 && all(nzchar(paths))
  )
  # Containment: refuse any path that could escape the archive root before it is
  # written under the scratch dir with file.path(src_dir, path).
  for (path in paths) {
    .analysis_release_assert_safe_path(path)
  }
  paths <- sort(paths)

  src_dir <- tempfile("analysis-release-src-")
  dir.create(src_dir, recursive = TRUE)
  on.exit(unlink(src_dir, recursive = TRUE, force = TRUE), add = TRUE)

  for (path in paths) {
    full_path <- file.path(src_dir, path)
    dir.create(dirname(full_path), recursive = TRUE, showWarnings = FALSE)
    writeBin(named_raw_list[[path]], full_path)
  }

  tar_file <- tempfile("analysis-release-", fileext = ".tar")
  on.exit(unlink(tar_file, force = TRUE), add = TRUE)

  previous_wd <- setwd(src_dir)
  on.exit(setwd(previous_wd), add = TRUE)
  # tar = "internal" forces R's built-in (pure-R) tar writer so the archive
  # never depends on a system `tar` binary being present/compatible.
  utils::tar(tarfile = tar_file, files = paths, compression = "none", tar = "internal")

  memCompress(readBin(tar_file, "raw", n = file.info(tar_file)$size), type = "gzip")
}
