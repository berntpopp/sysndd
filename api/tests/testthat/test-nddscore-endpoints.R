library(testthat)
library(DBI)

source_api_file("functions/db-helpers.R", local = FALSE, envir = .GlobalEnv)
source_api_file("functions/async-job-repository.R", local = FALSE, envir = .GlobalEnv)
source_api_file("functions/nddscore-import.R", local = FALSE, envir = .GlobalEnv)
source_api_file("functions/nddscore-repository.R", local = FALSE, envir = .GlobalEnv)
source_api_file("endpoints/nddscore_endpoints.R", local = FALSE, envir = .GlobalEnv)

with_nddscore_endpoint_fixture <- function(code) {
  skip_if_no_test_db()
  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn), envir = parent.frame())
  nddscore_clean_tables(conn)
  withr::defer(nddscore_clean_tables(conn), envir = parent.frame())

  old_daemon_conn_exists <- exists("daemon_db_conn", envir = .GlobalEnv)
  old_daemon_conn <- if (old_daemon_conn_exists) {
    get("daemon_db_conn", envir = .GlobalEnv)
  } else {
    NULL
  }
  assign("daemon_db_conn", conn, envir = .GlobalEnv)
  withr::defer({
    if (old_daemon_conn_exists) {
      assign("daemon_db_conn", old_daemon_conn, envir = .GlobalEnv)
    } else if (exists("daemon_db_conn", envir = .GlobalEnv)) {
      rm("daemon_db_conn", envir = .GlobalEnv)
    }
  }, envir = parent.frame())

  force(code)
}

test_that("NDDScore endpoint helpers map no active release to 404", {
  with_nddscore_endpoint_fixture({
    expect_null(nddscore_repo_download_info())

    res <- new.env(parent = emptyenv())
    result <- nddscore_endpoint_not_found(res)

    expect_equal(res$status, 404L)
    expect_equal(result$error, "not_found")
    expect_match(result$message, "No active NDDScore release")
  })
})

test_that("NDDScore active fixture backs paginated gene endpoint data", {
  with_nddscore_endpoint_fixture({
    nddscore_run_import(
      conn = get("daemon_db_conn", envir = .GlobalEnv),
      record_id = "20258027",
      validate_only = FALSE,
      imported_by = NULL,
      job_id = "job-endpoint-fixture",
      deps = nddscore_stub_deps(),
      progress = function(...) NULL
    )

    genes <- nddscore_repo_genes(page = 1L, page_size = 2L)

    expect_equal(genes$total, 3L)
    expect_lte(nrow(genes$data), 2L)
  })
})

describe("NDDScore admin import submission", {
  it("submits a durable nddscore_import job and returns its job id", {
    skip_if_no_test_db()
    conn <- get_test_db_connection()
    withr::defer(DBI::dbDisconnect(conn), envir = parent.frame())
    ensure_test_async_job_schema(conn)
    DBI::dbBegin(conn)
    withr::defer(DBI::dbRollback(conn), envir = parent.frame())

    old_daemon_conn_exists <- exists("daemon_db_conn", envir = .GlobalEnv)
    old_daemon_conn <- if (old_daemon_conn_exists) {
      get("daemon_db_conn", envir = .GlobalEnv)
    } else {
      NULL
    }
    assign("daemon_db_conn", conn, envir = .GlobalEnv)
    withr::defer({
      if (old_daemon_conn_exists) {
        assign("daemon_db_conn", old_daemon_conn, envir = .GlobalEnv)
      } else if (exists("daemon_db_conn", envir = .GlobalEnv)) {
        rm("daemon_db_conn", envir = .GlobalEnv)
      }
    }, envir = parent.frame())

    source_api_file("functions/async-job-service.R", local = FALSE)
    submitted <- async_job_service_submit(
      job_type = "nddscore_import",
      request_payload = list(record_id = "20258027", validate_only = TRUE),
      submitted_by = NULL)
    expect_true(submitted$created || submitted$duplicate)
    expect_equal(submitted$job$job_type[[1]], "nddscore_import")
  })
})
