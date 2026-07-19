# functions/analysis-snapshot-provenance-generator.R
#
# Immutable generator provenance for analysis snapshots (issue #585).
#
# Additive-only: written to the manifest `generator_json` column, OUTSIDE every
# identity hash (payload_hash / input_hash / per-cluster cluster_hash). It records
# HOW a snapshot was produced (application version+commit, snapshot-builder
# version, CLUSTER_LOGIC_VERSION for clustering axes, the applied algorithm
# params, and pinned library versions) without touching WHAT it contains, so it
# NEVER changes membership, cluster_hash, or LLM summaries. Never bump
# CLUSTER_LOGIC_VERSION for a provenance-only change.

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

ANALYSIS_SNAPSHOT_BUILDER_VERSION <- "1.0"
ANALYSIS_GENERATOR_SCHEMA_VERSION <- "1.0"

# Clustering analysis types whose provenance must record CLUSTER_LOGIC_VERSION.
.analysis_generator_clustering_types <- c("functional_clusters", "phenotype_clusters")

#' Resolve the deployed application git commit (shared with the version endpoint).
#'
#' Priority: `GIT_COMMIT` env (Docker build injection) > `git rev-parse --short
#' HEAD` (development) > "unknown". Never errors; a missing git binary or a
#' non-repo cwd degrades to "unknown".
#' @return character(1).
#' @export
resolve_app_git_commit <- function() {
  commit <- Sys.getenv("GIT_COMMIT", unset = "")
  if (nzchar(commit)) {
    return(commit)
  }
  tryCatch(
    {
      out <- system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE)
      if (length(out) == 0L || !nzchar(out[[1]])) "unknown" else out[[1]]
    },
    error = function(e) "unknown"
  )
}

#' Resolve the application semantic version robustly in API AND worker contexts.
#'
#' The worker does not necessarily hold the `version_json` global and there is no
#' production `get_api_dir()`; degrade through the global, then the `APP_VERSION`
#' env, then a cwd-relative `version_spec.json`, then "unknown" (never error).
#' `start_async_worker.R` also initializes the global so path 1 normally succeeds
#' there; the env/cwd fallbacks are defense-in-depth.
#' @return character(1).
#' @export
resolve_app_version <- function() {
  v <- tryCatch(base::get("version_json", envir = .GlobalEnv)$version, error = function(e) NULL)
  if (!is.null(v) && nzchar(v)) {
    return(v)
  }
  ev <- Sys.getenv("APP_VERSION", unset = "")
  if (nzchar(ev)) {
    return(ev)
  }
  # Container worker cwd is the api dir; read the spec relative to cwd if present.
  vj <- tryCatch(jsonlite::fromJSON("version_spec.json"), error = function(e) NULL)
  if (!is.null(vj$version) && nzchar(vj$version)) {
    return(vj$version)
  }
  "unknown"
}

#' Pinned library versions relevant to clustering reproducibility.
#'
#' A per-package fetch failure degrades to `NA` for that package rather than
#' erroring the whole block.
#' @return named list of character version strings (+ `r_version`).
#' @export
analysis_generator_library_versions <- function() {
  pkgs <- c("igraph", "leidenAlg", "FactoMineR", "factoextra", "STRINGdb", "data.table")
  vers <- lapply(pkgs, function(p) {
    tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_)
  })
  names(vers) <- pkgs
  vers$r_version <- R.version.string
  vers
}

#' Applied functional-clustering params (hash-safe; attached as an attribute).
#'
#' Frozen defaults read from the real call sites in analyses-functions.R:
#' gen_string_clust_obj (`min_size = 10`, `resolution = 1.0`, `set.seed(42)`,
#' `algorithm = "leiden"`, `score_threshold = 400`). The served membership channel
#' comes from the #514 coherence provenance.
#' @export
analysis_snapshot_functional_applied_params <- function(params, weight_channel = NA_character_) {
  list(
    algorithm = params$algorithm %||% "leiden",
    resolution = 1.0, seed = 42L, score_threshold = 400L, min_size = 10L,
    weight_channel = weight_channel %||% NA_character_
  )
}

#' Applied phenotype MCA/HCPC params (hash-safe; attached as an attribute).
#'
#' Frozen defaults from gen_mca_clust_obj: `ncp = 8`, `kk = Inf` (consolidation
#' runs), `consol = TRUE` (#509); the prevalence band is env-driven
#' (analysis-phenotype-mca-prep.R). `hcpc_nb_clust` records the served (visible)
#' cluster count -- the data-driven-k attribute is dropped by the dplyr nest
#' pipeline in generate_phenotype_clusters(), so the served k is what is available.
#' @export
analysis_snapshot_phenotype_applied_params <- function(hcpc_nb_clust) {
  list(
    ncp = 8L,
    prevalence_min = suppressWarnings(as.numeric(Sys.getenv("PHENOTYPE_MCA_PREVALENCE_MIN", "0.05"))),
    prevalence_max = suppressWarnings(as.numeric(Sys.getenv("PHENOTYPE_MCA_PREVALENCE_MAX", "0.95"))),
    kk = "Inf", consol = TRUE,
    hcpc_nb_clust = hcpc_nb_clust
  )
}

#' Assemble the immutable generator provenance block.
#'
#' @param analysis_type character analysis-type (preset) name.
#' @param params the parameters actually applied to the generating call (the
#'   builder passes `attr(payload, "applied_params")`); recorded verbatim under
#'   `algorithm$params`.
#' @param generated_at_utc a single UTC ISO-8601 timestamp captured once by the
#'   caller (so payload + generator share one wall-clock instant).
#' @return list; the generator block written to `generator_json`.
#' @export
analysis_snapshot_build_generator <- function(analysis_type, params, generated_at_utc) {
  is_clustering <- analysis_type %in% .analysis_generator_clustering_types
  cluster_logic_version <- if (is_clustering) {
    tryCatch(CLUSTER_LOGIC_VERSION, error = function(e) NULL)
  } else {
    NULL
  }
  list(
    generator_schema_version = ANALYSIS_GENERATOR_SCHEMA_VERSION,
    application_version = resolve_app_version(),
    application_commit = resolve_app_git_commit(),
    snapshot_builder_version = ANALYSIS_SNAPSHOT_BUILDER_VERSION,
    cluster_logic_version = cluster_logic_version,
    generated_at = generated_at_utc,
    algorithm = list(
      name = params$algorithm %||% params$cluster_type %||% analysis_type,
      params = params %||% list()
    ),
    library_versions = analysis_generator_library_versions()
  )
}

#' Compute derived manifest provenance for a refresh (#585 B3).
#'
#' Consolidates payload/input hashing (identity hashes exclude
#' raw/partition_validation/reproducibility, #512/#514), DB-release/source-version
#' resolution (#22/#459), and additive generator provenance (#585) + its
#' completeness gate. Lives here (not the builder) to keep both files <= 600
#' lines; every primitive it calls resolves from the loaded global env at call time.
#' @return list(payload_hash, input_hash, source_versions, db_release_version,
#'   db_release_commit, generator).
#' @export
analysis_snapshot_compute_manifest_provenance <- function(normalized, payload,
                                                          source_data_version, refresh_conn) {
  payload_hash <- analysis_snapshot_payload_hash(
    payload[setdiff(names(payload), c("raw", "partition_validation", "reproducibility"))]
  )
  input_provenance <- list(
    analysis_type = normalized$analysis_type,
    params = normalized$params,
    source_data_version = source_data_version
  )
  if (!is.null(payload$dependencies)) {
    input_provenance$dependencies <- payload$dependencies
  }
  input_hash <- analysis_snapshot_input_hash(input_provenance)
  rv <- analysis_snapshot_resolve_source_versions(
    refresh_conn, source_data_version, payload$dependencies
  )
  generator <- analysis_snapshot_prepare_generator(
    normalized$analysis_type, attr(payload, "applied_params") %||% normalized$params
  )
  list(
    payload_hash = payload_hash, input_hash = input_hash,
    source_versions = rv$source_versions,
    db_release_version = rv$db_release_version, db_release_commit = rv$db_release_commit,
    generator = generator
  )
}

#' Capture one UTC instant, build the generator block, and gate it (#585 B3).
#'
#' Convenience wrapper used by the snapshot builder so the refresh function stays
#' compact: fails the refresh (via the completeness gate) if provenance is
#' incomplete for a new snapshot.
#' @return the gated generator list.
#' @export
analysis_snapshot_prepare_generator <- function(analysis_type, applied_params) {
  generated_at_utc <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")
  generator <- analysis_snapshot_build_generator(analysis_type, applied_params, generated_at_utc)
  analysis_snapshot_assert_generator_complete(generator, analysis_type)
  generator
}

#' Fail-closed completeness gate for a NEW snapshot's generator provenance.
#'
#' Every required field must be a present, non-empty scalar; a clustering axis
#' additionally requires `cluster_logic_version`. `application_commit` must be
#' present but may legitimately be "unknown" in dev. Throws on any gap so an
#' incomplete provenance block can never be persisted.
#' @return invisibly TRUE (or `stop()`s).
#' @export
analysis_snapshot_assert_generator_complete <- function(generator, analysis_type) {
  required <- c("generator_schema_version", "application_version",
                "snapshot_builder_version", "generated_at")
  if (analysis_type %in% .analysis_generator_clustering_types) {
    required <- c(required, "cluster_logic_version")
  }
  for (k in required) {
    v <- generator[[k]]
    if (is.null(v) || length(v) == 0L || is.na(v[[1]]) || !nzchar(as.character(v[[1]]))) {
      stop(sprintf("incomplete snapshot generator provenance: missing '%s' for %s",
                   k, analysis_type), call. = FALSE)
    }
  }
  # application_commit must be present but may legitimately be "unknown" in dev.
  if (is.null(generator$application_commit)) {
    stop("incomplete snapshot generator provenance: missing 'application_commit'", call. = FALSE)
  }
  invisible(TRUE)
}
