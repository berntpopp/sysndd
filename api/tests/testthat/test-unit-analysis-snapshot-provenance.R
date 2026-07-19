# Regression guard for issue #347: public analysis snapshot responses must
# surface the W3C-PROV / FAIR provenance fields named in the issue output
# contract (snapshot_id, schema_version, generated_at, source_versions,
# input_hash, record_counts, parameters) directly from the public-ready
# manifest row, without any heavy compute or extra DB round trip.

analysis_snapshot_provenance_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(analysis_snapshot_provenance_test_wd), testthat::teardown_env())

# Generator-provenance helpers under test + their dependencies (#585). The
# provenance-generator file defines its own guarded `%||%`; CLUSTER_LOGIC_VERSION
# comes from the cache-fingerprint module. Guarded so a missing file is a no-op.
analysis_snapshot_provenance_api_dir <- getwd()
for (f in c("functions/analysis-cache-fingerprint.R",
            "functions/analysis-snapshot-provenance-generator.R",
            "functions/analysis-snapshot-builder.R",
            "functions/analysis-snapshot-release-manifest.R",
            "functions/analysis-snapshot-release-materialize.R",
            "functions/analysis-snapshot-presets.R",
            "functions/analysis-snapshot-release.R")) {
  fp <- file.path(analysis_snapshot_provenance_api_dir, f)
  if (file.exists(fp)) source(fp, local = FALSE)
}
if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a)) b else a

analysis_snapshot_provenance_fake_snapshot <- function(row_counts_json) {
  list(
    manifest = tibble::tibble(
      snapshot_id = 42,
      analysis_type = "gene_network_edges",
      parameter_hash = "param-hash",
      schema_version = "1.0",
      data_class = "curated_derived_analysis",
      generated_at = as.POSIXct("2026-05-30 12:00:00", tz = "UTC"),
      stale_after = as.POSIXct("2026-06-06 12:00:00", tz = "UTC"),
      source_data_version = "source-v1",
      parameters_json = "{\"cluster_type\":\"clusters\",\"min_confidence\":400,\"max_edges\":10000}",
      algorithm_name = "clusters",
      input_hash = "input-hash",
      payload_hash = "payload-hash",
      row_counts_json = row_counts_json
    ),
    network_nodes = tibble::tibble(),
    network_edges = tibble::tibble(),
    clusters = tibble::tibble(),
    cluster_members = tibble::tibble(),
    correlations = tibble::tibble()
  )
}

test_that("snapshot meta surfaces lineage hashes and record counts from the manifest", {
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  snapshot <- analysis_snapshot_provenance_fake_snapshot(
    row_counts_json = "{\"nodes\":2,\"edges\":1,\"network_metadata\":{\"min_confidence\":400}}"
  )

  meta <- service_analysis_snapshot_meta(snapshot)$snapshot

  # Issue #347 output-contract fields are all present and load-bearing.
  expect_equal(as.character(meta$snapshot_id), "42")
  expect_equal(as.character(meta$schema_version), "1.0")
  expect_equal(as.character(meta$data_class), "curated_derived_analysis")
  expect_equal(as.character(meta$source_data_version), "source-v1")
  expect_equal(as.character(meta$input_hash), "input-hash")
  expect_equal(as.character(meta$payload_hash), "payload-hash")
  expect_false(is.null(meta$generated_at))

  # record_counts reflects the materialized payload tables only; the generated
  # network_metadata block is excluded so the block stays a true row-count map.
  expect_equal(meta$record_counts$nodes, 2L)
  expect_equal(meta$record_counts$edges, 1L)
  expect_null(meta$record_counts$network_metadata)

  # No validation_json on this row -> validation_hash is NULL (Codex #457-459 P2:
  # payload_hash excludes the partition-validation block).
  expect_null(meta$validation_hash)
})

test_that("snapshot meta exposes validation_hash bound to the persisted validation_json", {
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  validation_json <- "{\"algorithm\":\"leiden\",\"modularity\":0.42}"
  snapshot <- analysis_snapshot_provenance_fake_snapshot(
    row_counts_json = "{\"nodes\":2,\"edges\":1}"
  )
  snapshot$manifest$validation_json <- validation_json

  meta <- service_analysis_snapshot_meta(snapshot)$snapshot

  # validation_hash binds the served `validation` metadata (excluded from
  # payload_hash) so clients can detect a validation-only change.
  expect_equal(
    as.character(meta$validation_hash),
    digest::digest(validation_json, algo = "sha256", serialize = FALSE)
  )
  expect_false(identical(as.character(meta$validation_hash),
                         as.character(meta$payload_hash)))
})

test_that("snapshot meta record_counts is null when no row counts were stored", {
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  snapshot <- analysis_snapshot_provenance_fake_snapshot(row_counts_json = NA_character_)
  meta <- service_analysis_snapshot_meta(snapshot)$snapshot

  expect_null(meta$record_counts)
})

test_that("snapshot meta record_counts is null when only generated metadata is stored", {
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  snapshot <- analysis_snapshot_provenance_fake_snapshot(
    row_counts_json = "{\"network_metadata\":{\"min_confidence\":400}}"
  )
  meta <- service_analysis_snapshot_meta(snapshot)$snapshot

  expect_null(meta$record_counts)
})

test_that("snapshot meta tolerates manifests missing the optional lineage columns", {
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  snapshot <- list(
    manifest = tibble::tibble(
      snapshot_id = 7,
      analysis_type = "phenotype_clusters",
      parameter_hash = "p",
      schema_version = "1.0",
      data_class = "curated_derived_analysis",
      generated_at = as.POSIXct("2026-05-30 12:00:00", tz = "UTC"),
      stale_after = as.POSIXct(NA),
      source_data_version = "source-v1"
    )
  )

  meta <- service_analysis_snapshot_meta(snapshot)$snapshot
  expect_null(meta$input_hash)
  expect_null(meta$payload_hash)
  expect_null(meta$record_counts)
  expect_equal(as.character(meta$snapshot_id), "7")
})

# ---------------------------------------------------------------------------#
# #585: additive snapshot generator provenance helpers (B2).
# ---------------------------------------------------------------------------#

test_that("resolve_app_version degrades to 'unknown' without a global/env/file (no error)", {
  had_version <- exists("version_json", envir = .GlobalEnv)
  saved <- if (had_version) base::get("version_json", envir = .GlobalEnv) else NULL
  withr::defer(if (had_version) assign("version_json", saved, envir = .GlobalEnv))
  withr::with_envvar(c(APP_VERSION = ""), {
    if (had_version) rm("version_json", envir = .GlobalEnv)
    withr::with_dir(tempdir(), {
      expect_silent(v <- resolve_app_version())
      expect_true(is.character(v) && nzchar(v)) # "unknown" when nothing resolves
    })
  })
})

test_that("generator block is complete and reproducible for clustering types", {
  g <- analysis_snapshot_build_generator(
    "functional_clusters",
    params = list(algorithm = "leiden", resolution = 1.0, score_threshold = 400),
    generated_at_utc = "2026-07-19T00:00:00Z"
  )
  expect_identical(g$generator_schema_version, ANALYSIS_GENERATOR_SCHEMA_VERSION)
  expect_true(nzchar(g$application_version))
  expect_true(nzchar(g$snapshot_builder_version))
  expect_identical(g$cluster_logic_version, CLUSTER_LOGIC_VERSION)
  expect_identical(g$generated_at, "2026-07-19T00:00:00Z")
  expect_true("leiden" == g$algorithm$name || "functional_clusters" == g$algorithm$name)
  expect_true(is.list(g$library_versions))
  expect_silent(analysis_snapshot_assert_generator_complete(g, "functional_clusters"))
})

test_that("completeness gate rejects a missing required field", {
  g <- analysis_snapshot_build_generator("functional_clusters",
        list(algorithm = "leiden"), "2026-07-19T00:00:00Z")
  g$cluster_logic_version <- NULL
  expect_error(analysis_snapshot_assert_generator_complete(g, "functional_clusters"))
})

test_that("non-clustering types do not require cluster_logic_version", {
  # real non-clustering preset name is "gene_network_edges" (analysis-snapshot-presets.R:42)
  g <- analysis_snapshot_build_generator("gene_network_edges", list(), "2026-07-19T00:00:00Z")
  expect_null(g$cluster_logic_version)
  expect_silent(analysis_snapshot_assert_generator_complete(g, "gene_network_edges"))
})

test_that("resolve_app_git_commit never errors and returns a scalar string", {
  expect_silent(commit <- resolve_app_git_commit())
  expect_true(is.character(commit) && length(commit) == 1L && nzchar(commit))
})

test_that("applied_params attribute and generator never enter payload_hash", {
  payload <- list(kind = "clusters", clusters = list(a = 1), members = list(),
                  raw = list(x = 1), partition_validation = list(v = 1))
  hashed <- function(p) analysis_snapshot_payload_hash(
    p[setdiff(names(p), c("raw", "partition_validation", "reproducibility"))])
  h1 <- hashed(payload)
  attr(payload, "applied_params") <- list(resolution = 1.0, seed = 42L)  # attribute, not a name
  h2 <- hashed(payload)
  expect_identical(h1, h2)                              # attribute changed nothing
  expect_false("applied_params" %in% names(payload))   # it's an attr, never a list element
  expect_false("generator" %in% names(payload))        # generator lives on the manifest, not payload
})

# ---------------------------------------------------------------------------#
# #585: meta.snapshot.generator + generator_hash (B4), pre-046 tolerant.
# ---------------------------------------------------------------------------#

test_that("meta exposes generator + generator_hash when generator_json present", {
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)
  row <- tibble::tibble(snapshot_id = 1, analysis_type = "functional_clusters",
    parameter_hash = "p", schema_version = "1.2", data_class = "curated_derived_analysis",
    generated_at = "2026-07-19 00:00:00", stale_after = NA, source_data_version = "v1",
    source_versions_json = "{}", input_hash = "i", payload_hash = "h",
    generator_json = '{"application_version":"0.30.6","cluster_logic_version":"x"}')
  meta <- service_analysis_snapshot_meta(list(manifest = row))$snapshot
  expect_equal(meta$generator$application_version, "0.30.6")
  expect_true(nzchar(meta$generator_hash))
  # generator_hash is bound to the exact stored JSON bytes.
  expect_equal(
    as.character(meta$generator_hash),
    digest::digest(row$generator_json[[1]], algo = "sha256", serialize = FALSE)
  )
})

test_that("pre-046 snapshot (no/empty generator_json) omits generator + null hash", {
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)
  row <- tibble::tibble(snapshot_id = 1, analysis_type = "functional_clusters",
    parameter_hash = "p", schema_version = "1.2", data_class = "x",
    generated_at = "2026-07-19 00:00:00", stale_after = NA, source_data_version = "v1",
    source_versions_json = "{}", input_hash = "i", payload_hash = "h")
  meta <- service_analysis_snapshot_meta(list(manifest = row))$snapshot
  expect_null(meta$generator)
  expect_null(meta$generator_hash)
})

# ---------------------------------------------------------------------------#
# #585 (B5): per-layer generator provenance in the release manifest. The full
# release-build integration test is DB-gated (SKIPs host-side without RMariaDB),
# so this locks the pure source.snapshots[] assembly + the content-digest
# exclusion directly (release helpers sourced in the file header).
# ---------------------------------------------------------------------------#

test_that(".analysis_release_manifest_generator parses a pinned snapshot's generator_json", {
  m <- tibble::tibble(snapshot_id = 5,
    generator_json = '{"application_version":"0.30.6","snapshot_builder_version":"1.0"}')
  g <- .analysis_release_manifest_generator(m)
  expect_equal(g$application_version, "0.30.6")
  expect_equal(g$snapshot_builder_version, "1.0")
  # pre-046 (no column / empty) -> NULL, so the release omits the key.
  expect_null(.analysis_release_manifest_generator(tibble::tibble(snapshot_id = 5)))
  expect_null(.analysis_release_manifest_generator(
    tibble::tibble(snapshot_id = 5, generator_json = NA_character_)))
})

test_that("source.snapshots[] carries each layer's generator; content_digest ignores it", {
  layer_entries <- list(
    list(analysis_type = "functional_clusters", parameter_hash = "pf",
         snapshot_id = 101L, input_hash = "if", payload_hash = "pyf",
         reproducibility_hash = "rf", dependencies = NULL),
    list(analysis_type = "phenotype_clusters", parameter_hash = "pp",
         snapshot_id = 202L, input_hash = "ip", payload_hash = "pyp",
         reproducibility_hash = "rp", dependencies = NULL)
  )
  loaded <- list(
    functional_clusters = list(generator = list(application_version = "0.30.6",
                                                cluster_logic_version = "cf")),
    phenotype_clusters  = list(generator = list(application_version = "0.30.6",
                                                cluster_logic_version = "cp"))
  )

  snaps <- .analysis_release_source_snapshots(layer_entries, loaded)
  expect_length(snaps, 2L)
  expect_equal(snaps[[1]]$generator$cluster_logic_version, "cf")
  expect_equal(snaps[[2]]$generator$cluster_logic_version, "cp")
  expect_equal(snaps[[1]]$snapshot_id, 101L)

  # A layer whose loaded entry has no generator (pre-046) omits the key entirely.
  snaps_missing <- .analysis_release_source_snapshots(
    layer_entries, list(functional_clusters = list(), phenotype_clusters = list()))
  expect_false("generator" %in% names(snaps_missing[[1]]))

  # content_digest is computed from layer_entries only and NEVER sees generator:
  # adding a generator key to every layer entry leaves the digest byte-identical.
  d_plain <- analysis_release_content_digest(layer_entries, "srcv-1",
                                             ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION)
  layer_entries_gen <- lapply(layer_entries, function(e) {
    e$generator <- list(application_version = "0.30.6"); e
  })
  d_gen <- analysis_release_content_digest(layer_entries_gen, "srcv-1",
                                           ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION)
  expect_identical(d_plain, d_gen)
})
