analysis_snapshot_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(analysis_snapshot_test_wd), testthat::teardown_env())

test_that("network snapshot builder normalizes nodes and edges", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("functions", "analysis-snapshot-builder.R"), local = TRUE)

  network <- list(
    nodes = tibble::tibble(
      hgnc_id = c("HGNC:1", "HGNC:2"),
      symbol = c("A", "B"),
      cluster = c(1, 1),
      category = c("Definitive", "Moderate"),
      degree = c(5L, 4L),
      x = c(10, 20),
      y = c(30, 40)
    ),
    edges = tibble::tibble(source = "HGNC:1", target = "HGNC:2", confidence = 0.9),
    metadata = list(node_count = 2L, edge_count = 1L)
  )

  built <- analysis_snapshot_build_network_rows(network)

  expect_equal(nrow(built$nodes), 2L)
  expect_equal(nrow(built$edges), 1L)
  expect_equal(built$edges$edge_rank, 1L)
  expect_equal(built$row_counts$nodes, 2L)
  expect_equal(built$row_counts$edges, 1L)
})

test_that("correlation snapshot builder supports triangle and diagonal shaping later", {
  source(file.path("functions", "analysis-snapshot-builder.R"), local = TRUE)

  rows <- tibble::tibble(x = c("A", "A", "B"), y = c("A", "B", "B"), value = c(1, 0.5, 1))
  built <- analysis_snapshot_build_correlation_rows(rows, correlation_kind = "phenotype")

  expect_equal(nrow(built$correlations), 3L)
  expect_equal(built$correlations$row_rank, 1:3)
  expect_equal(built$correlations$abs_value, c(1, 0.5, 1))
})

test_that("approved gene query limits functional snapshots to NDD phenotype genes", {
  env <- new.env(parent = globalenv())
  captured_sql <- NULL
  env$db_execute_query <- function(sql, params = list(), conn = NULL) {
    captured_sql <<- sql
    expect_identical(conn, "snapshot-conn")
    tibble::tibble(hgnc_id = "HGNC:1")
  }
  source(file.path("functions", "analysis-snapshot-builder.R"), local = env)

  result <- env$analysis_snapshot_approved_gene_ids(conn = "snapshot-conn")

  expect_equal(result, "HGNC:1")
  expect_match(captured_sql, "ndd_phenotype\\s*=\\s*1")
})

test_that("snapshot refresh uses one connection and one write transaction", {
  env <- new.env(parent = globalenv())
  source(file.path("functions", "analysis-snapshot-presets.R"), local = env)
  source(file.path("functions", "analysis-snapshot-builder.R"), local = env)

  refresh_conn <- structure(list(label = "refresh"), class = "DBIConnection")
  events <- character()
  record_conn <- function(name, conn) {
    events <<- c(events, name)
    expect_identical(conn, refresh_conn)
  }

  env$get_db_connection <- function() {
    events <<- c(events, "checkout")
    refresh_conn
  }
  env$db_with_transaction <- function(code, pool_obj = NULL) {
    expect_identical(pool_obj, refresh_conn)
    events <<- c(events, "tx_start")
    result <- code(pool_obj)
    events <<- c(events, "tx_end")
    result
  }
  env$analysis_snapshot_acquire_lock <- function(analysis_type, parameter_hash, timeout_seconds = 30L, conn = NULL) {
    record_conn("acquire", conn)
    TRUE
  }
  env$analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
    record_conn("release", conn)
    TRUE
  }
  env$analysis_snapshot_source_data_version <- function(conn = NULL) {
    record_conn("source_version", conn)
    "source-v1"
  }
  env$analysis_snapshot_build_payload <- function(analysis_type, params, conn = NULL) {
    expect_identical(conn, refresh_conn)
    events <<- c(events, "build_payload")
    list(
      kind = "network",
      nodes = tibble::tibble(),
      edges = tibble::tibble(),
      row_counts = list(nodes = 0L, edges = 0L)
    )
  }
  env$analysis_snapshot_create_manifest <- function(manifest, conn = NULL) {
    record_conn("create_manifest", conn)
    expect_equal(manifest$source_data_version, "source-v1")
    42
  }
  env$analysis_snapshot_insert_network_rows <- function(snapshot_id, rows, conn = NULL) {
    record_conn("insert_network", conn)
    expect_equal(snapshot_id, 42)
  }
  env$analysis_snapshot_activate <- function(snapshot_id, analysis_type, parameter_hash, conn = NULL, ...) {
    record_conn("activate", conn)
    expect_equal(snapshot_id, 42)
  }
  env$analysis_snapshot_prune <- function(analysis_type, parameter_hash, keep_public_ready = 3L, keep_superseded_days = 14L, conn = NULL) {
    record_conn("prune", conn)
    0L
  }

  result <- env$analysis_snapshot_refresh(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = 400, max_edges = 10000)
  )

  expect_equal(result$snapshot_id, 42)
  expect_equal(
    events,
    c(
      "checkout",
      "acquire",
      "source_version",
      "build_payload",
      "tx_start",
      "create_manifest",
      "insert_network",
      "activate",
      "prune",
      "tx_end",
      "release"
    )
  )
})

test_that("snapshot refresh checks out an explicit pool once before locking", {
  env <- new.env(parent = globalenv())
  source(file.path("functions", "analysis-snapshot-presets.R"), local = env)
  source(file.path("functions", "analysis-snapshot-builder.R"), local = env)

  events <- character()
  fake_pool <- NULL
  checked_out <- structure(
    list(label = "checked-out"),
    class = "DBIConnection",
    pool_metadata = list(valid = TRUE)
  )
  fake_pool <- structure(
    list(
      fetch = function() {
        events <<- c(events, "checkout")
        checked_out <<- structure(
          list(label = "checked-out"),
          class = "DBIConnection",
          pool_metadata = list(pool = fake_pool, valid = TRUE)
        )
        checked_out
      },
      release = function(object) {
        expect_identical(object, checked_out)
        events <<- c(events, "return")
      }
    ),
    class = "Pool"
  )
  record_conn <- function(name, conn) {
    events <<- c(events, name)
    expect_identical(conn, checked_out)
  }

  env$db_with_transaction <- function(code, pool_obj = NULL) {
    expect_identical(pool_obj, checked_out)
    events <<- c(events, "tx_start")
    result <- code(pool_obj)
    events <<- c(events, "tx_end")
    result
  }
  env$analysis_snapshot_acquire_lock <- function(analysis_type, parameter_hash, timeout_seconds = 30L, conn = NULL) {
    record_conn("acquire", conn)
    TRUE
  }
  env$analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
    record_conn("release", conn)
    TRUE
  }
  env$analysis_snapshot_source_data_version <- function(conn = NULL) {
    record_conn("source_version", conn)
    "source-v1"
  }
  env$analysis_snapshot_build_payload <- function(analysis_type, params, conn = NULL) {
    record_conn("build_payload", conn)
    list(
      kind = "network",
      nodes = tibble::tibble(),
      edges = tibble::tibble(),
      row_counts = list(nodes = 0L, edges = 0L)
    )
  }
  env$analysis_snapshot_create_manifest <- function(manifest, conn = NULL) {
    record_conn("create_manifest", conn)
    42
  }
  env$analysis_snapshot_insert_network_rows <- function(snapshot_id, rows, conn = NULL) {
    record_conn("insert_network", conn)
  }
  env$analysis_snapshot_activate <- function(snapshot_id, analysis_type, parameter_hash, conn = NULL, ...) {
    record_conn("activate", conn)
  }
  env$analysis_snapshot_prune <- function(analysis_type, parameter_hash, keep_public_ready = 3L, keep_superseded_days = 14L, conn = NULL) {
    record_conn("prune", conn)
    0L
  }

  result <- env$analysis_snapshot_refresh(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = 400, max_edges = 10000),
    conn = fake_pool
  )

  expect_equal(result$snapshot_id, 42)
  expect_equal(
    events,
    c(
      "checkout",
      "acquire",
      "source_version",
      "build_payload",
      "tx_start",
      "create_manifest",
      "insert_network",
      "activate",
      "prune",
      "tx_end",
      "release",
      "return"
    )
  )
})
