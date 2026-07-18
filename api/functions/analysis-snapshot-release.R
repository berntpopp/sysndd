# functions/analysis-snapshot-release.R
#
# Build orchestrator for immutable, content-addressed public analysis-snapshot
# RELEASES (#573 Slice A / Task A4). This is the correctness-critical layer: it
# LOADS the active public snapshots, GATES them (available + hard coherence +
# reproducibility presence + shared source-data version + dependency lineage +
# TOCTOU), MATERIALIZES the release files, computes the content-addressed
# identity, and PERSISTS via the A3 repository.
#
# Reuses (sourced by callers before this file / registered in load_modules):
#   - analysis-snapshot-presets.R          : canonical JSON + parameter hashing
#   - analysis-snapshot-coherence.R        : analysis_snapshot_assert_partition_coherent
#   - analysis-snapshot-dependencies.R     : analysis_snapshot_manifest_dependencies
#   - analysis-reproducibility.R           : analysis_reproducibility_decode_raw
#   - analysis-snapshot-release-manifest.R : identity + manifest/checksums/tar helpers (A2)
#   - analysis-snapshot-release-repository.R: analysis_release_insert/get/exists/... (A3)
#
# DEPENDENCY-INJECTION SEAMS. The three collaborators below are injectable so the
# gates are deterministically unit-testable WITHOUT seeding the complex snapshot
# tables. Their call-time defaults are the real functions; the body always calls
# the seam, never the real function directly:
#   - loader(analysis_type, parameter_hash, conn)  -> loaded snapshot
#   - reproducibility_loader(snapshot_id, conn)    -> reproducibility row (or NULL)
#   - coherence_assert(snapshot, kind)             -> invisibly / throws
#
# ERROR CONTRACT. The five classed conditions below are `c(<name>,"error",
# "condition")`; the A5 service maps them to HTTP 400 (the contract has no 409):
#   release_snapshot_not_available, release_source_incoherent,
#   release_reproducibility_missing, release_source_version_mismatch,
#   release_dependency_lineage_mismatch.
# A DUPLICATE build is NOT an error: it returns the existing head with
# created = FALSE (service -> 200).

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Materialization / gate / coherence helpers live in the sibling file (kept
# separate so both stay under the 600-line ceiling). Registered together in
# bootstrap/load_modules.R -- Task A8 -- and sourced together by the integration test.

# --------------------------------------------------------------------------- #
# Advisory locks (TOCTOU): serialize a build against a concurrent axis refresh.
#
# The build acquires the SAME per-preset advisory lock the axis refresh holds —
# `analysis_snapshot_lock_name(analysis_type, parameter_hash)` — so a mid-flight
# refresh of a source preset blocks the read (MySQL 8 lets one session hold many
# named GET_LOCKs). Best-effort: engaged only on a real DBIConnection (a
# pooled/NULL conn cannot hold a session-scoped GET_LOCK meaningfully), and a
# lock-acquire timeout does NOT abort — the fresh pre-insert re-read below is the
# invariant that always catches a snapshot that changed under us.
# --------------------------------------------------------------------------- #

#' Per-preset lock name — identical to the axis-refresh lock so they collide.
#' @noRd
.analysis_release_preset_lock_name <- function(analysis_type, parameter_hash) {
  if (exists("analysis_snapshot_lock_name", mode = "function")) {
    return(analysis_snapshot_lock_name(analysis_type, parameter_hash))
  }
  # Byte-identical fallback for minimal/test envs where the repository file that
  # defines analysis_snapshot_lock_name() is not sourced.
  paste0("asr:", substr(as.character(parameter_hash[[1]]), 1, 56))
}

#' @noRd
.analysis_release_get_lock <- function(conn, name, timeout_seconds = 5L) {
  if (!inherits(conn, "DBIConnection")) {
    return(FALSE)
  }
  tryCatch(
    {
      rows <- DBI::dbGetQuery(
        conn, "SELECT GET_LOCK(?, ?) AS acquired",
        params = unname(list(name, as.integer(timeout_seconds)))
      )
      isTRUE(as.integer(rows$acquired[[1]]) == 1L)
    },
    error = function(e) FALSE
  )
}

#' @noRd
.analysis_release_release_named_lock <- function(conn, name) {
  if (!inherits(conn, "DBIConnection")) {
    return(invisible(FALSE))
  }
  tryCatch(
    DBI::dbGetQuery(
      conn, "SELECT RELEASE_LOCK(?) AS released",
      params = unname(list(name))
    ),
    error = function(e) NULL
  )
  invisible(TRUE)
}

#' Fresh pre-insert re-read: re-load each layer via the loader seam (NOT the
#' cached step-1 `loaded`) and confirm each layer's {snapshot_id, payload_hash}
#' and the correlation dependencies still equal the pinned lineage. Throws a
#' classed gate error if a source snapshot changed between the first read and the
#' insert (the real TOCTOU catch).
#' @noRd
.analysis_release_verify_lineage_unchanged <- function(layer_specs, loaded, loader, conn) {
  for (spec in layer_specs) {
    at <- spec$analysis_type
    entry <- loaded[[at]]
    fresh <- loader(at, spec$parameter_hash, conn = conn)
    status_code <- if (is.null(fresh)) "snapshot_missing" else (fresh$status_code %||% "snapshot_missing")
    if (!identical(status_code, "available")) {
      stop(.analysis_release_condition(
        "release_snapshot_not_available",
        sprintf("layer %s became unavailable before insert: %s", at, status_code),
        analysis_type = at, status_code = status_code
      ))
    }
    fresh_id <- suppressWarnings(as.integer(.analysis_release_manifest_scalar(fresh$manifest, "snapshot_id")))
    fresh_hash <- as.character(.analysis_release_manifest_scalar(fresh$manifest, "payload_hash", NA_character_))
    if (!identical(fresh_id, suppressWarnings(as.integer(entry$snapshot_id))) ||
      !identical(fresh_hash, entry$payload_hash)) {
      stop(.analysis_release_condition(
        "release_dependency_lineage_mismatch",
        sprintf(
          "layer %s snapshot changed between read and insert (was snapshot_id %s, now %s)",
          at, as.character(entry$snapshot_id), as.character(fresh_id)
        ),
        analysis_type = at
      ))
    }
    if (identical(at, "phenotype_functional_correlations") &&
      !is.null(loaded[["functional_clusters"]]) && !is.null(loaded[["phenotype_clusters"]])) {
      fresh_deps <- analysis_snapshot_manifest_dependencies(fresh$manifest)
      ok <- .analysis_release_dep_matches(fresh_deps, "functional_clusters", loaded[["functional_clusters"]]) &&
        .analysis_release_dep_matches(fresh_deps, "phenotype_clusters", loaded[["phenotype_clusters"]])
      if (!ok) {
        stop(.analysis_release_condition(
          "release_dependency_lineage_mismatch",
          "correlation dependency lineage changed between read and insert",
          analysis_type = at
        ))
      }
    }
  }
  invisible(TRUE)
}

# --------------------------------------------------------------------------- #
# Orchestrator
# --------------------------------------------------------------------------- #

#' Build (and optionally publish) an immutable analysis-snapshot release.
#'
#' @param layers Layer registry (default `analysis_snapshot_release_layers()`).
#' @param title,scope_statement,license Presentation metadata (excluded from the
#'   content digest / release identity).
#' @param publish If TRUE the inserted draft is flipped to `published`.
#' @param created_by Optional user id recorded on the head row.
#' @param conn A real DBIConnection (required for persistence; A5 checks one out).
#' @param loader,reproducibility_loader,coherence_assert Injectable seams (see file
#'   header); call-time defaults are the real functions.
#' @return `list(release = <head>, created = TRUE|FALSE)`.
#' @export
analysis_snapshot_release_build <- function(layers = analysis_snapshot_release_layers(),
                                            title = NULL,
                                            scope_statement = NULL,
                                            license = "CC-BY-4.0",
                                            publish = TRUE,
                                            created_by = NULL,
                                            conn = NULL,
                                            loader = analysis_snapshot_get_public,
                                            reproducibility_loader = analysis_snapshot_get_reproducibility,
                                            coherence_assert = analysis_snapshot_release_assert_coherent) {
  # Resolve (analysis_type, parameter_hash) per layer once (pure; validates params).
  layer_specs <- lapply(layers, function(layer) {
    at <- as.character(layer$analysis_type[[1]])
    list(
      analysis_type = at,
      layer = layer,
      parameter_hash = analysis_snapshot_normalize_params(at, layer$params %||% list())$parameter_hash
    )
  })

  # --- Step 0: per-preset TOCTOU advisory locks (best-effort) --------------
  # Acquire the SAME per-preset lock the axis refresh holds, so a mid-flight
  # refresh of a source preset serializes against this read. Released on exit.
  if (inherits(conn, "DBIConnection")) {
    acquired_locks <- character(0)
    for (spec in layer_specs) {
      lock_name <- .analysis_release_preset_lock_name(spec$analysis_type, spec$parameter_hash)
      if (.analysis_release_get_lock(conn, lock_name, 5L)) {
        acquired_locks <- c(acquired_locks, lock_name)
      }
    }
    if (length(acquired_locks) > 0L) {
      on.exit(
        for (lock_name in acquired_locks) .analysis_release_release_named_lock(conn, lock_name),
        add = TRUE
      )
    }
  }

  # --- Step 1/1b/1c: load + gate each layer --------------------------------
  loaded <- list()
  for (spec in layer_specs) {
    layer <- spec$layer
    at <- spec$analysis_type
    parameter_hash <- spec$parameter_hash

    snapshot <- loader(at, parameter_hash, conn = conn)
    status_code <- if (is.null(snapshot)) "snapshot_missing" else (snapshot$status_code %||% "snapshot_missing")
    if (!identical(status_code, "available")) {
      stop(.analysis_release_condition(
        "release_snapshot_not_available",
        sprintf("layer %s is not available for release: %s", at, status_code),
        analysis_type = at, status_code = status_code
      ))
    }

    manifest <- snapshot$manifest
    entry <- list(
      analysis_type = at,
      kind = .analysis_release_layer_kind(at),
      layer = layer,
      snapshot = snapshot,
      manifest = manifest,
      snapshot_id = .analysis_release_manifest_scalar(manifest, "snapshot_id"),
      payload_hash = as.character(.analysis_release_manifest_scalar(manifest, "payload_hash", NA_character_)),
      input_hash = as.character(.analysis_release_manifest_scalar(manifest, "input_hash", NA_character_)),
      schema_version = as.character(.analysis_release_manifest_scalar(manifest, "schema_version", NA_character_)),
      source_data_version = as.character(
        .analysis_release_manifest_scalar(manifest, "source_data_version", NA_character_)
      ),
      parameter_hash = parameter_hash,
      reproducibility_hash = NULL,
      dependencies = NULL,
      reproducibility_bundle = NULL
    )

    if (isTRUE(layer$has_reproducibility)) {
      # 1b: HARD coherence re-check (any failure -> release_source_incoherent).
      tryCatch(
        coherence_assert(snapshot, entry$kind),
        release_source_incoherent = function(e) stop(e),
        error = function(e) {
          stop(.analysis_release_condition(
            "release_source_incoherent",
            sprintf("layer %s failed the hard coherence re-check: %s", at, conditionMessage(e)),
            analysis_type = at
          ))
        }
      )

      # 1c: reproducibility bundle presence.
      repro <- reproducibility_loader(entry$snapshot_id, conn = conn)
      repro_hash <- .analysis_release_repro_hash(repro)
      if (is.na(repro_hash) || !nzchar(repro_hash)) {
        stop(.analysis_release_condition(
          "release_reproducibility_missing",
          sprintf("layer %s has no reproducibility bundle; the release requires one", at),
          analysis_type = at
        ))
      }
      entry$reproducibility_hash <- repro_hash
      entry$reproducibility_bundle <- repro$bundle_gzip_json
    }

    loaded[[at]] <- entry
  }

  # --- Step 2: shared source version + correlation dependency lineage ------
  .analysis_release_assert_lineage(loaded)
  shared_source_version <- unique(vapply(
    loaded, function(e) as.character(e$source_data_version), character(1)
  ))[[1]]

  # For the correlation layer, pin the actual dependency lineage into its entry.
  corr <- loaded[["phenotype_functional_correlations"]]
  if (!is.null(corr)) {
    loaded[["phenotype_functional_correlations"]]$dependencies <-
      analysis_snapshot_manifest_dependencies(corr$manifest)
  }

  # --- Step 3/4/5: materialize per-layer files + README, build layer_entries
  artifacts <- list()
  layer_entries <- list()

  for (layer in layers) {
    at <- as.character(layer$analysis_type[[1]])
    entry <- loaded[[at]]
    prefix <- layer$files_prefix %||% at

    payload_bytes <- analysis_release_canonical_bytes(.analysis_release_layer_payload(entry$snapshot, layer))
    artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
      paste0(prefix, "/payload.json"), payload_bytes, "application/json"
    )

    if (isTRUE(layer$has_reproducibility)) {
      repro_bytes <- charToRaw(analysis_reproducibility_decode_raw(entry$reproducibility_bundle))
      artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
        paste0(prefix, "/reproducibility.json"), repro_bytes, "application/json"
      )
    }

    layer_entries[[length(layer_entries) + 1L]] <- list(
      analysis_type = at,
      parameter_hash = entry$parameter_hash,
      snapshot_id = entry$snapshot_id,
      input_hash = entry$input_hash,
      payload_hash = entry$payload_hash,
      schema_version = entry$schema_version,
      reproducibility_hash = entry$reproducibility_hash,
      dependencies = entry$dependencies
    )
  }

  # --- Step 6: content_digest -> release_id + idempotency ------------------
  content_digest <- analysis_release_content_digest(
    layer_entries, shared_source_version, ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION
  )
  release_id <- analysis_release_id(content_digest)

  if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
    existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
    if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
      return(list(release = existing, created = FALSE))
    }
    stop(sprintf(
      "release id %s already exists with a different content_digest (identity anomaly)",
      release_id
    ), call. = FALSE)
  }

  # README carries the resolved release_id now that it is known.
  readme_bytes <- .analysis_release_readme_bytes(
    release_id, title, scope_statement, license, shared_source_version, layer_entries
  )
  artifacts <- c(
    list(.analysis_release_artifact("README.md", readme_bytes, "text/markdown")),
    artifacts
  )

  created_at <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  # --- Step 7: manifest.json (files[] excludes manifest + checksums) -------
  content_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256, bytes = a$byte_size))
  manifest_obj <- analysis_release_build_manifest(list(
    release_id = release_id,
    release_version = NULL,
    title = title,
    created_at = created_at,
    license = license %||% "CC-BY-4.0",
    scope_statement = scope_statement,
    generator = list(
      name = "sysndd-analysis-snapshot-release-build",
      manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
      reproducibility_schema_version = if (exists("ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION")) {
        ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION
      } else {
        NULL
      }
    ),
    source = list(
      source_data_version = shared_source_version,
      snapshots = lapply(layer_entries, function(e) {
        list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
      })
    ),
    layers = layer_entries,
    files = content_files,
    content_digest = content_digest
  ))
  manifest_bytes <- analysis_release_canonical_bytes(manifest_obj)
  manifest_artifact <- .analysis_release_artifact("manifest.json", manifest_bytes, "application/json")
  manifest_sha256 <- manifest_artifact$sha256
  artifacts[[length(artifacts) + 1L]] <- manifest_artifact

  # --- Step 8: checksums.sha256 (all files incl. manifest, excl. checksums)-
  checksum_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256))
  checksums_bytes <- charToRaw(enc2utf8(analysis_release_checksums_text(checksum_files)))
  artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
    "checksums.sha256", checksums_bytes, "text/plain"
  )

  # --- Step 9: bundle.tar.gz (all files) -----------------------------------
  named_raw <- stats::setNames(
    lapply(artifacts, function(a) a$bytes),
    vapply(artifacts, function(a) a$path, character(1))
  )
  bundle_gzip <- analysis_release_build_tar_gz(named_raw)
  bundle_sha256 <- analysis_release_sha256(bundle_gzip)

  # --- Step 2 (re-assert immediately before insert) ------------------------
  # A FRESH DB re-read via the loader seam (not the cached `loaded`) so a source
  # snapshot that was refreshed between the first read and now is caught. Combined
  # with the per-preset locks above, this closes the TOCTOU window.
  .analysis_release_assert_lineage(loaded)
  .analysis_release_verify_lineage_unchanged(layer_specs, loaded, loader, conn)

  # --- Step 10: persist ----------------------------------------------------
  release_head <- list(
    release_id = release_id,
    release_version = NULL,
    title = title,
    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
    content_digest = content_digest,
    manifest_sha256 = manifest_sha256,
    bundle_sha256 = bundle_sha256,
    bundle_gzip = bundle_gzip,
    source_data_version = shared_source_version,
    scope_statement = scope_statement,
    license = license %||% "CC-BY-4.0",
    created_by_user_id = created_by
  )

  members <- lapply(layer_entries, function(e) {
    list(
      analysis_type = e$analysis_type,
      parameter_hash = e$parameter_hash,
      snapshot_id = e$snapshot_id,
      input_hash = e$input_hash,
      payload_hash = e$payload_hash,
      schema_version = e$schema_version,
      reproducibility_hash = e$reproducibility_hash,
      role = "layer"
    )
  })

  insert_files <- lapply(artifacts, function(a) {
    list(
      file_path = a$path,
      content_sha256 = a$sha256,
      byte_size = a$byte_size,
      media_type = a$media_type,
      content_gzip = memCompress(a$bytes, type = "gzip")
    )
  })

  analysis_release_insert(release_head, members, insert_files, conn)
  if (isTRUE(publish)) {
    analysis_release_publish(release_id, conn = conn)
  }

  list(
    release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
    created = TRUE
  )
}
