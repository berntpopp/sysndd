analysis_snapshot_dependency_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(analysis_snapshot_dependency_test_wd), testthat::teardown_env())

test_that("phenotype-functional payload is built from immutable cluster snapshot dependencies", {
  env <- new.env(parent = globalenv())
  source(file.path("functions", "analysis-snapshot-presets.R"), local = env)
  source(file.path("functions", "analysis-snapshot-dependencies.R"), local = env)
  source(file.path("functions", "analysis-snapshot-builder.R"), local = env)

  functional <- list(
    status_code = "available",
    manifest = tibble::tibble(
      snapshot_id = 41L,
      payload_hash = "functional-payload-hash"
    ),
    cluster_members = tibble::tibble(
      cluster_kind = "functional",
      cluster_id = c("2", "2", "6", "6"),
      hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3", "HGNC:4")
    )
  )
  phenotype <- list(
    status_code = "available",
    manifest = tibble::tibble(
      snapshot_id = 39L,
      payload_hash = "phenotype-payload-hash"
    ),
    cluster_members = tibble::tibble(
      cluster_kind = "phenotype",
      cluster_id = c("1", "1", "2", "2"),
      hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3", "HGNC:4")
    )
  )
  requested <- character()
  loader <- function(analysis_type, params, conn = NULL) {
    requested <<- c(requested, analysis_type)
    switch(analysis_type,
      functional_clusters = functional,
      phenotype_clusters = phenotype,
      stop("unexpected analysis type")
    )
  }

  result <- env$analysis_snapshot_build_dependency_bound_pc_fc_correlation(
    cluster_snapshot_loader = loader,
    conn = "test-connection"
  )

  expect_equal(requested, c("functional_clusters", "phenotype_clusters"))
  expect_equal(
    result$dependencies,
    list(
      functional_clusters = list(snapshot_id = 41L, payload_hash = "functional-payload-hash"),
      phenotype_clusters = list(snapshot_id = 39L, payload_hash = "phenotype-payload-hash")
    )
  )
  pc1_fc2 <- dplyr::filter(result$rows, x == "fc_2", y == "pc_1")
  pc2_fc2 <- dplyr::filter(result$rows, x == "fc_2", y == "pc_2")
  expect_equal(pc1_fc2$value, 1)
  expect_equal(pc2_fc2$value, -1)
})

test_that("dependency-bound phenotype-functional build rejects unavailable cluster snapshots", {
  env <- new.env(parent = globalenv())
  source(file.path("functions", "analysis-snapshot-presets.R"), local = env)
  source(file.path("functions", "analysis-snapshot-dependencies.R"), local = env)
  source(file.path("functions", "analysis-snapshot-builder.R"), local = env)

  unavailable_loader <- function(...) list(status_code = "snapshot_missing")

  expect_error(
    env$analysis_snapshot_build_dependency_bound_pc_fc_correlation(
      cluster_snapshot_loader = unavailable_loader
    ),
    "functional_clusters.*available"
  )
})

test_that("phenotype-functional correlation status fails closed when a dependency changes", {
  env <- new.env(parent = globalenv())
  source(file.path("functions", "analysis-snapshot-presets.R"), local = env)
  source(file.path("functions", "analysis-snapshot-dependencies.R"), local = env)

  manifest <- tibble::tibble(
    analysis_type = "phenotype_functional_correlations",
    source_versions_json = jsonlite::toJSON(
      list(
        dependencies = list(
          functional_clusters = list(snapshot_id = 41L, payload_hash = "functional-hash"),
          phenotype_clusters = list(snapshot_id = 39L, payload_hash = "phenotype-hash")
        )
      ),
      auto_unbox = TRUE
    )
  )
  active_manifest_loader <- function(analysis_type, params, conn = NULL) {
    switch(analysis_type,
      functional_clusters = tibble::tibble(snapshot_id = 42L, payload_hash = "new-functional-hash"),
      phenotype_clusters = tibble::tibble(snapshot_id = 39L, payload_hash = "phenotype-hash")
    )
  }

  expect_equal(
    env$analysis_snapshot_dependency_status_code(
      manifest,
      active_manifest_loader = active_manifest_loader
    ),
    "dependency_snapshot_mismatch"
  )
})

test_that("public correlation reads do not serve a dependency-mismatched manifest", {
  env <- new.env(parent = globalenv())
  env$db_execute_query <- function(...) {
    tibble::tibble(
      snapshot_id = 40L,
      analysis_type = "phenotype_functional_correlations",
      parameter_hash = "correlation-parameter-hash",
      public_ready = 1L,
      status = "public_ready",
      source_data_version = "source-v1",
      schema_version = NA_character_,
      stale_after = as.POSIXct("2099-01-01", tz = "UTC")
    )
  }
  env$analysis_snapshot_source_data_version <- function(conn = NULL) "source-v1"
  env$analysis_snapshot_dependency_status_code <- function(manifest, conn = NULL) {
    expect_equal(manifest$snapshot_id[[1]], 40L)
    "dependency_snapshot_mismatch"
  }
  source(file.path("functions", "analysis-snapshot-repository.R"), local = env)

  result <- env$analysis_snapshot_get_public(
    "phenotype_functional_correlations",
    "correlation-parameter-hash"
  )

  expect_equal(result$status_code, "dependency_snapshot_mismatch")
  expect_null(result$correlations)
})

test_that("correlation endpoint metadata exposes dependency lineage", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)

  snapshot <- list(
    manifest = tibble::tibble(
      snapshot_id = 40L,
      analysis_type = "phenotype_functional_correlations",
      parameter_hash = "correlation-parameter-hash",
      schema_version = "1.2",
      data_class = "curated_derived_analysis",
      generated_at = as.POSIXct("2026-07-16", tz = "UTC"),
      stale_after = as.POSIXct("2026-07-23", tz = "UTC"),
      source_data_version = "source-v1",
      input_hash = "input-hash",
      payload_hash = "payload-hash",
      source_versions_json = jsonlite::toJSON(
        list(
          dependencies = list(
            functional_clusters = list(snapshot_id = 41L, payload_hash = "functional-hash"),
            phenotype_clusters = list(snapshot_id = 39L, payload_hash = "phenotype-hash")
          )
        ),
        auto_unbox = TRUE
      ),
      validation_json = NA_character_,
      row_counts_json = NA_character_,
      db_release_version = "1.0.0",
      db_release_commit = "commit"
    )
  )

  meta <- service_analysis_snapshot_meta(snapshot)

  expect_equal(meta$snapshot$dependencies$functional_clusters$snapshot_id, 41L)
  expect_equal(meta$snapshot$dependencies$phenotype_clusters$payload_hash, "phenotype-hash")
})
