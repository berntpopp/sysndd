library(testthat)
library(DBI)

source_api_file("functions/nddscore-import.R", local = FALSE, envir = .GlobalEnv)

nddscore_test_fixture <- function() {
  rel_dir <- nddscore_extract_and_verify(nddscore_fixture_path())
  release <- nddscore_parse_release_json(rel_dir)
  frames <- nddscore_load_tsvs(rel_dir)
  list(release = release, frames = frames)
}

nddscore_test_conn <- function() {
  skip_if_no_test_db()
  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn), envir = parent.frame())
  nddscore_clean_tables(conn)
  withr::defer(nddscore_clean_tables(conn), envir = parent.frame())
  conn
}

test_that("nddscore_release_exists reports existence and active state", {
  conn <- nddscore_test_conn()
  fx <- nddscore_test_fixture()

  expect_false(nddscore_release_exists(conn, fx$release$release_id)$exists)

  nddscore_upsert_release_row(
    conn,
    fx$release,
    import_job_id = "job-release-exists",
    source = nddscore_stub_deps()$fetch_metadata("20258027")
  )

  stored <- nddscore_release_exists(conn, fx$release$release_id)
  expect_true(stored$exists)
  expect_false(stored$is_active)
  expect_equal(stored$import_status, "importing")

  nddscore_mark_release_validated(conn, fx$release$release_id)
  nddscore_activate_release(conn, fx$release$release_id)

  active <- nddscore_release_exists(conn, fx$release$release_id)
  expect_true(active$exists)
  expect_true(active$is_active)
  expect_equal(active$import_status, "active")
})

test_that("nddscore_insert_predictions and count_release_rows persist fixture rows", {
  conn <- nddscore_test_conn()
  fx <- nddscore_test_fixture()

  nddscore_upsert_release_row(
    conn,
    fx$release,
    import_job_id = "job-insert-predictions",
    source = nddscore_stub_deps()$fetch_metadata("20258027")
  )
  nddscore_insert_predictions(conn, fx$release$release_id, fx$frames)

  counts <- nddscore_count_release_rows(conn, fx$release$release_id)
  expect_equal(counts$gene, 3L)
  expect_equal(counts$hpo, 4L)
  expect_equal(counts$term, 2L)
})

test_that("nddscore_activate_release atomically switches active release", {
  conn <- nddscore_test_conn()
  fx <- nddscore_test_fixture()
  old_release <- fx$release
  old_release$release_id <- "ndd_fixture_release_old"

  nddscore_upsert_release_row(conn, old_release, import_job_id = "job-old")
  nddscore_mark_release_validated(conn, old_release$release_id)
  nddscore_activate_release(conn, old_release$release_id)

  nddscore_upsert_release_row(conn, fx$release, import_job_id = "job-new")
  nddscore_mark_release_validated(conn, fx$release$release_id)
  nddscore_activate_release(conn, fx$release$release_id)

  old_state <- nddscore_release_exists(conn, old_release$release_id)
  new_state <- nddscore_release_exists(conn, fx$release$release_id)
  expect_true(new_state$is_active)
  expect_equal(new_state$import_status, "active")
  expect_false(old_state$is_active)
  expect_equal(old_state$import_status, "superseded")
})

test_that("active_release_slot unique key rejects two active releases", {
  conn <- nddscore_test_conn()
  fx <- nddscore_test_fixture()
  release_two <- fx$release
  release_two$release_id <- "ndd_fixture_release_two"

  nddscore_upsert_release_row(conn, fx$release, import_job_id = "job-one")
  nddscore_upsert_release_row(conn, release_two, import_job_id = "job-two")

  DBI::dbExecute(
    conn,
    "UPDATE nddscore_release SET is_active = 1 WHERE release_id = ?",
    params = unname(list(fx$release$release_id))
  )
  expect_error(
    DBI::dbExecute(
      conn,
      "UPDATE nddscore_release SET is_active = 1 WHERE release_id = ?",
      params = unname(list(release_two$release_id))
    ),
    "Duplicate|unique|idx_nddscore_release_active_slot"
  )
})

test_that("advisory lock excludes a second connection until release", {
  skip_if_no_test_db()
  conn_one <- get_test_db_connection()
  conn_two <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn_one))
  withr::defer(DBI::dbDisconnect(conn_two))
  withr::defer(nddscore_release_import_lock(conn_one))

  expect_true(nddscore_try_acquire_import_lock(conn_one))
  expect_false(nddscore_try_acquire_import_lock(conn_two))
  expect_true(nddscore_release_import_lock(conn_one))
  expect_true(nddscore_try_acquire_import_lock(conn_two))
  expect_true(nddscore_release_import_lock(conn_two))
})
