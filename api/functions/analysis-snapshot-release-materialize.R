# functions/analysis-snapshot-release-materialize.R
#
# Pure, DB-light helpers for the immutable analysis-snapshot RELEASE build
# orchestrator (#573 Slice A / Task A4). Split out of
# `analysis-snapshot-release.R` to keep both files under the 600-line ceiling.
#
# Contains: the classed-condition constructor, the manifest/loader extraction
# helpers, the best-effort HARD coherence-re-check default (`coherence_assert`
# seam default), the cross-layer lineage gates, and the per-layer file
# materialization (payload / reproducibility / README). No DB access, no network.
#
# Sourced together with `analysis-snapshot-release.R` (both registered in
# `bootstrap/load_modules.R` -- Task A8 -- and both sourced by the direct-source
# integration test).

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# --------------------------------------------------------------------------- #
# Classed conditions
# --------------------------------------------------------------------------- #

#' Construct a classed release-gate condition (`c(<class>,"error","condition")`).
#'
#' The five `release_*` gate classes are surfaced to the A5 service, which maps
#' them to HTTP 400 (`stop_for_bad_request`; the contract has no 409 class).
#' @noRd
.analysis_release_condition <- function(class, message, ...) {
  structure(
    list(message = message, call = NULL, ...),
    class = c(class, "error", "condition")
  )
}

# --------------------------------------------------------------------------- #
# Extraction helpers
# --------------------------------------------------------------------------- #

#' Scalar read of a manifest field (manifest is a 1-row data.frame / tibble).
#' @noRd
.analysis_release_manifest_scalar <- function(manifest, field, default = NA) {
  if (is.null(manifest)) {
    return(default)
  }
  if (!(field %in% names(manifest))) {
    return(default)
  }
  column <- manifest[[field]]
  if (length(column) == 0L) {
    return(default)
  }
  value <- column[[1]]
  if (is.null(value)) default else value
}

#' Take a consistent scalar of `field` across the loaded layer manifests.
#'
#' Returns the single distinct non-empty value when the layers agree, else the
#' FIRST non-NA/non-empty value (a benign provenance disagreement never blocks a
#' build). NA when no layer carries it. Used for `db_release_version`/`_commit`.
#' @noRd
.analysis_release_consistent_manifest_value <- function(loaded, field) {
  values <- vapply(
    loaded,
    function(e) as.character(.analysis_release_manifest_scalar(e$manifest, field, NA_character_)),
    character(1)
  )
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0L) {
    return(NA_character_)
  }
  values[[1]]
}

#' Coerce a possibly-NULL child tibble to a plain data.frame for serialization.
#' @noRd
.analysis_release_rows <- function(x) {
  if (is.null(x)) {
    return(data.frame())
  }
  as.data.frame(x, stringsAsFactors = FALSE)
}

#' Map a cluster analysis_type to its cluster_kind label.
#' @noRd
.analysis_release_layer_kind <- function(analysis_type) {
  switch(as.character(analysis_type[[1]]),
    functional_clusters = "functional",
    phenotype_clusters = "phenotype",
    NA_character_
  )
}

#' Extract the reproducibility_hash from a loader row (df or list), or NA.
#' @noRd
.analysis_release_repro_hash <- function(repro) {
  if (is.null(repro)) {
    return(NA_character_)
  }
  if (is.data.frame(repro) && nrow(repro) == 0L) {
    return(NA_character_)
  }
  hash <- repro$reproducibility_hash
  if (is.null(hash) || length(hash) == 0L) {
    return(NA_character_)
  }
  as.character(hash[[1]])
}

# --------------------------------------------------------------------------- #
# Default coherence seam (best-effort HARD re-check over the STORED snapshot).
#
# Two of the three #514 coherence components ARE reconstructable from the stored
# public snapshot and are re-checked here (HARD, require_coherence = TRUE,
# ignoring the ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE downgrade):
#   1. Cluster-set integrity: every visible cluster (by cluster_kind) must appear
#      in the membership AND carry a non-NA stability score (jaccard_mean) in its
#      metadata_json — directly catching the #514 symptom ("real clusters with n/a
#      stability") in stored form.
#   2. Channel match (functional axis): the served membership channel
#      (`membership_weight_channel`) and the validation channel (`weight_channel`)
#      are both persisted in the manifest `validation_json`; when both are present
#      they must agree, else the served membership was clustered on a different
#      STRING channel than the validation scored (the #514 text-mining-vs-exp+db
#      case that slips through when cluster-id labels coincide).
# The THIRD component — full member-set equality — is genuinely NOT
# reconstructable: the validator's `reference_members` is a sibling of `partition`
# and is never persisted. That check is left to the build-time gate; the dev-stack
# e2e exercises the true membership-vs-validation recompute path.
# --------------------------------------------------------------------------- #

#' Parse the manifest `validation_json` column to a plain list (or empty list).
#' @noRd
.analysis_release_parse_validation_json <- function(manifest) {
  raw <- suppressWarnings(as.character(.analysis_release_manifest_scalar(manifest, "validation_json", NA_character_)))
  if (length(raw) == 0L || is.na(raw[[1]]) || !nzchar(raw[[1]])) {
    return(list())
  }
  parsed <- tryCatch(jsonlite::fromJSON(raw[[1]], simplifyVector = TRUE), error = function(e) NULL)
  if (is.null(parsed) || !is.list(parsed)) {
    return(list())
  }
  parsed
}

#' @noRd
.analysis_release_cluster_has_stability <- function(metadata_json) {
  txt <- suppressWarnings(as.character(metadata_json))
  if (length(txt) == 0L || is.na(txt[[1]]) || !nzchar(txt[[1]])) {
    return(FALSE)
  }
  parsed <- tryCatch(jsonlite::fromJSON(txt[[1]], simplifyVector = TRUE), error = function(e) NULL)
  if (is.null(parsed)) {
    return(FALSE)
  }
  score <- parsed$jaccard_mean %||% parsed$stability %||% parsed$stability_score
  !is.null(score) && length(score) >= 1L && !is.na(suppressWarnings(as.numeric(score[[1]])))
}

#' Hard coherence re-check over a loaded cluster snapshot. Default `coherence_assert`.
#' @export
analysis_snapshot_release_assert_coherent <- function(snapshot, kind) {
  clusters <- .analysis_release_rows(snapshot$clusters)
  members <- .analysis_release_rows(snapshot$cluster_members)
  if ("cluster_kind" %in% names(clusters)) {
    clusters <- clusters[as.character(clusters$cluster_kind) == kind, , drop = FALSE]
  }
  if ("cluster_kind" %in% names(members)) {
    members <- members[as.character(members$cluster_kind) == kind, , drop = FALSE]
  }

  membership_ids <- if ("cluster_id" %in% names(members)) unique(as.character(members$cluster_id)) else character(0)
  membership <- tibble::tibble(cluster = membership_ids)

  valid_ids <- character(0)
  if (nrow(clusters) > 0L && "cluster_id" %in% names(clusters)) {
    metadata <- if ("metadata_json" %in% names(clusters)) clusters$metadata_json else rep(NA_character_, nrow(clusters))
    has_stability <- vapply(
      seq_len(nrow(clusters)),
      function(i) .analysis_release_cluster_has_stability(metadata[[i]]),
      logical(1)
    )
    valid_ids <- as.character(clusters$cluster_id[has_stability])
  }
  per_cluster <- tibble::tibble(cluster_id = valid_ids)

  # Channel match (functional axis only): both channels live in validation_json;
  # when both are present they must agree. Absent/older snapshots skip this
  # comparison (assert_partition_coherent only fires channel_mismatch when BOTH
  # membership_channel and validation_channel are non-NULL).
  membership_channel <- NULL
  validation_channel <- NULL
  if (identical(kind, "functional")) {
    validation <- .analysis_release_parse_validation_json(snapshot$manifest)
    membership_channel <- validation$membership_weight_channel
    validation_channel <- validation$weight_channel
  }

  tryCatch(
    analysis_snapshot_assert_partition_coherent(
      membership, per_cluster, kind,
      membership_channel = membership_channel,
      validation_channel = validation_channel,
      require_coherence = TRUE
    ),
    error = function(e) {
      stop(.analysis_release_condition(
        "release_source_incoherent",
        sprintf("%s snapshot failed hard coherence re-check: %s", kind, conditionMessage(e)),
        kind = kind
      ))
    }
  )
  invisible(TRUE)
}

# --------------------------------------------------------------------------- #
# Cross-layer lineage gates (step 2). Re-asserted immediately before insert.
# --------------------------------------------------------------------------- #

#' @noRd
.analysis_release_dep_matches <- function(dependencies, key, entry) {
  if (!is.list(dependencies)) {
    return(FALSE)
  }
  dep <- dependencies[[key]]
  if (!is.list(dep)) {
    return(FALSE)
  }
  dep_id <- suppressWarnings(as.integer(dep$snapshot_id %||% NA))
  dep_hash <- as.character(dep$payload_hash %||% "")
  entry_id <- suppressWarnings(as.integer(entry$snapshot_id))
  entry_hash <- as.character(entry$payload_hash %||% "")
  !is.na(dep_id) && !is.na(entry_id) && identical(dep_id, entry_id) &&
    nzchar(dep_hash) && nzchar(entry_hash) && identical(dep_hash, entry_hash)
}

#' Assert one shared source_data_version + correlation dependency lineage.
#' @noRd
.analysis_release_assert_lineage <- function(loaded) {
  versions <- vapply(
    loaded,
    function(e) as.character(e$source_data_version %||% NA_character_),
    character(1)
  )
  uniq <- unique(versions)
  if (length(uniq) != 1L || is.na(uniq[[1]]) || !nzchar(uniq[[1]])) {
    stop(.analysis_release_condition(
      "release_source_version_mismatch",
      sprintf(
        "release layers do not share one source_data_version (found: %s)",
        paste(ifelse(is.na(versions), "<NA>", versions), collapse = ", ")
      )
    ))
  }

  corr <- loaded[["phenotype_functional_correlations"]]
  func <- loaded[["functional_clusters"]]
  phen <- loaded[["phenotype_clusters"]]
  if (!is.null(corr) && !is.null(func) && !is.null(phen)) {
    dependencies <- analysis_snapshot_manifest_dependencies(corr$manifest)
    ok <- .analysis_release_dep_matches(dependencies, "functional_clusters", func) &&
      .analysis_release_dep_matches(dependencies, "phenotype_clusters", phen)
    if (!ok) {
      stop(.analysis_release_condition(
        "release_dependency_lineage_mismatch",
        paste(
          "correlation snapshot dependency lineage does not match the pinned",
          "functional/phenotype cluster snapshots (a cluster axis was refreshed",
          "after the correlation was computed)"
        )
      ))
    }
  }
  invisible(TRUE)
}

# --------------------------------------------------------------------------- #
# File materialization
# --------------------------------------------------------------------------- #

#' Layer-appropriate payload object (its own bytes; NOT the snapshot payload_hash).
#' @noRd
.analysis_release_layer_payload <- function(snapshot, layer) {
  if (isTRUE(layer$has_reproducibility)) {
    list(
      clusters = .analysis_release_rows(snapshot$clusters),
      cluster_members = .analysis_release_rows(snapshot$cluster_members)
    )
  } else if (grepl("correlation", layer$analysis_type, fixed = TRUE)) {
    list(correlations = .analysis_release_rows(snapshot$correlations))
  } else {
    list(
      network_nodes = .analysis_release_rows(snapshot$network_nodes),
      network_edges = .analysis_release_rows(snapshot$network_edges)
    )
  }
}

#' Assemble one materialized artifact with its own sha256 + byte_size.
#' @noRd
.analysis_release_artifact <- function(path, bytes, media_type) {
  # Every materialized file path flows through here — assert containment at this
  # single choke point (defense-in-depth alongside analysis_release_build_tar_gz).
  .analysis_release_assert_safe_path(path)
  list(
    path = path,
    bytes = bytes,
    media_type = media_type,
    sha256 = analysis_release_sha256(bytes),
    byte_size = length(bytes)
  )
}

#' README.md content bytes (scope + independent-verification recipe).
#' @noRd
.analysis_release_readme_bytes <- function(release_id, title, scope_statement, license,
                                           source_data_version, layer_entries) {
  layer_lines <- vapply(
    layer_entries,
    function(e) {
      sprintf(
        "- %s (snapshot_id %s, payload_hash %s)",
        e$analysis_type, as.character(e$snapshot_id), substr(e$payload_hash, 1, 12)
      )
    },
    character(1)
  )
  lines <- c(
    sprintf("# %s", title %||% "SysNDD analysis-snapshot release"),
    "",
    sprintf("Release: `%s`", release_id),
    sprintf("License: %s", license %||% "CC-BY-4.0"),
    sprintf("Source data version: %s", source_data_version %||% "unknown"),
    "",
    "## Scope",
    "",
    scope_statement %||% paste(
      "Immutable, content-addressed public export of the curated derived",
      "cluster-analysis snapshots served by the SysNDD analysis API."
    ),
    "",
    "## Layers",
    "",
    layer_lines,
    "",
    "## Verify",
    "",
    "1. `sha256sum -c checksums.sha256` verifies every file against its recorded digest.",
    "2. `manifest.json` records each layer's source snapshot lineage",
    "   (`snapshot_id`, `payload_hash`, `input_hash`) plus the reproducibility hash.",
    "3. Each cluster layer's `reproducibility.json` hashes exactly to its",
    "   `reproducibility_hash` and carries the inputs to independently recompute",
    "   the served separation metric (modularity / silhouette).",
    ""
  )
  charToRaw(enc2utf8(paste(lines, collapse = "\n")))
}
