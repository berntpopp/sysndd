analysis_snapshot_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(analysis_snapshot_test_wd), testthat::teardown_env())

test_that("snapshot repository exposes expected public API", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)

  expect_true(exists("analysis_snapshot_lock_name", mode = "function"))
  expect_true(exists("analysis_snapshot_get_public", mode = "function"))
  expect_true(exists("analysis_snapshot_create_manifest", mode = "function"))
  expect_true(exists("analysis_snapshot_activate", mode = "function"))
  expect_true(exists("analysis_snapshot_prune", mode = "function"))
})

test_that("snapshot lock names are scoped by analysis type and parameter hash", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)

  preset <- analysis_snapshot_normalize_params(
    "gene_network_edges",
    list(cluster_type = "clusters", min_confidence = 400, max_edges = 10000)
  )
  expect_equal(
    analysis_snapshot_lock_name(preset$analysis_type, preset$parameter_hash),
    paste0("analysis_snapshot_refresh:gene_network_edges:", preset$parameter_hash)
  )
})

test_that("snapshot status helpers classify missing and stale rows", {
  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)

  expect_equal(analysis_snapshot_status_code(NULL), "snapshot_missing")
  stale <- list(stale_after = Sys.time() - 60)
  expect_equal(analysis_snapshot_status_code(stale), "snapshot_stale")
  fresh <- list(stale_after = Sys.time() + 60)
  expect_equal(analysis_snapshot_status_code(fresh), "available")
})

test_that("manifest creation uses one checked-out pool connection for insert id lookup", {
  env <- new.env(parent = globalenv())
  source(file.path("functions", "analysis-snapshot-repository.R"), local = env)

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

  env$db_execute_statement <- function(sql, params = list(), conn = NULL) {
    expect_identical(conn, checked_out)
    events <<- c(events, "insert")
    1L
  }
  env$db_execute_query <- function(sql, params = list(), conn = NULL) {
    expect_identical(conn, checked_out)
    events <<- c(events, "last_id")
    tibble::tibble(snapshot_id = 77)
  }

  snapshot_id <- env$analysis_snapshot_create_manifest(
    list(
      analysis_type = "gene_network_edges",
      parameter_hash = "abc",
      schema_version = "1.0",
      data_class = "curated_derived_analysis",
      status = "pending",
      parameters_json = "{}",
      input_hash = "input",
      payload_hash = "payload"
    ),
    conn = fake_pool
  )

  expect_equal(snapshot_id, 77)
  expect_equal(events, c("checkout", "insert", "last_id", "return"))
})
