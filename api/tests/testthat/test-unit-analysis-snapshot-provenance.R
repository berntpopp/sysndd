# Regression guard for issue #347: public analysis snapshot responses must
# surface the W3C-PROV / FAIR provenance fields named in the issue output
# contract (snapshot_id, schema_version, generated_at, source_versions,
# input_hash, record_counts, parameters) directly from the public-ready
# manifest row, without any heavy compute or extra DB round trip.

analysis_snapshot_provenance_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(analysis_snapshot_provenance_test_wd), testthat::teardown_env())

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
