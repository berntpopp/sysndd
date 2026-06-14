source_api_file("functions/pubtatornidd-nightly.R", local = FALSE)

test_that("resolve_query prefers requested, then env, then cached", {
  cached <- function() "CACHED_QUERY"

  # requested wins
  expect_equal(
    pubtatornidd_nightly_resolve_query(
      requested_query = "REQ", env_query = "ENV", cached_query_fn = cached
    ),
    "REQ"
  )
  # env wins when no requested
  expect_equal(
    pubtatornidd_nightly_resolve_query(
      requested_query = NULL, env_query = "ENV", cached_query_fn = cached
    ),
    "ENV"
  )
  expect_equal(
    pubtatornidd_nightly_resolve_query(
      requested_query = "", env_query = "ENV", cached_query_fn = cached
    ),
    "ENV"
  )
  # cached wins when neither requested nor env
  expect_equal(
    pubtatornidd_nightly_resolve_query(
      requested_query = NULL, env_query = "", cached_query_fn = cached
    ),
    "CACHED_QUERY"
  )
})

test_that("resolve_query returns NA when nothing is available", {
  expect_true(is.na(pubtatornidd_nightly_resolve_query(
    requested_query = NULL, env_query = "",
    cached_query_fn = function() NA_character_
  )))
})

test_that("cached_query reads the most-recent cached query or NA", {
  ok_fn <- function(sql) {
    expect_match(sql, "pubtator_query_cache", fixed = TRUE)
    expect_match(sql, "ORDER BY query_date DESC", fixed = TRUE)
    data.frame(query_text = "GRIN2B", stringsAsFactors = FALSE)
  }
  expect_equal(pubtatornidd_nightly_cached_query(query_fn = ok_fn), "GRIN2B")

  empty_fn <- function(sql) data.frame()
  expect_true(is.na(pubtatornidd_nightly_cached_query(query_fn = empty_fn)))

  err_fn <- function(sql) stop("db down")
  expect_true(is.na(pubtatornidd_nightly_cached_query(query_fn = err_fn)))
})

test_that("payload scalar helper is NULL-safe", {
  expect_null(.pubtatornidd_payload_scalar(NULL, "query"))
  expect_null(.pubtatornidd_payload_scalar(list(), "query"))
  expect_equal(.pubtatornidd_payload_scalar(list(query = "X"), "query"), "X")
  expect_equal(.pubtatornidd_payload_scalar(list(max_pages = 7L), "max_pages"), 7L)
  expect_equal(.pubtatornidd_payload_scalar(list(), "max_pages", default = 50L), 50L)
})

test_that("nightly lock helpers map GET_LOCK / RELEASE_LOCK results", {
  testthat::local_mocked_bindings(
    dbGetQuery = function(conn, statement, ...) {
      if (grepl("GET_LOCK", statement)) return(data.frame(acquired = 1L))
      if (grepl("RELEASE_LOCK", statement)) return(data.frame(released = 1L))
      stop("unexpected statement")
    },
    .package = "DBI"
  )
  expect_true(pubtatornidd_nightly_try_lock(conn = NULL))
  expect_true(pubtatornidd_nightly_release_lock(conn = NULL))
})

test_that("nightly try_lock returns FALSE when the lock is held elsewhere", {
  testthat::local_mocked_bindings(
    dbGetQuery = function(conn, statement, ...) data.frame(acquired = 0L),
    .package = "DBI"
  )
  expect_false(pubtatornidd_nightly_try_lock(conn = NULL))
})

test_that("pubtatornidd_nightly job type is registered in the handler registry", {
  source_api_file("functions/async-job-handlers.R", local = FALSE)
  entry <- async_job_handler_registry[["pubtatornidd_nightly"]]
  expect_false(is.null(entry))
  expect_true(is.function(entry$run))
  expect_equal(entry$cancel_mode, "non_interruptible")
})
