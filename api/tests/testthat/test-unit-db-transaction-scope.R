# api/tests/testthat/test-unit-db-transaction-scope.R
#
# db_with_savepoint_or_transaction() (#612).
#
# A write unit that must be atomic can be handed either a pool (production) or a
# caller-owned DBIConnection. `with_test_db_transaction()` is the second case and
# has ALREADY issued `DBI::dbBegin()` (helper-db.R), while
# `db_with_transaction()` calls `DBI::dbWithTransaction()` for BOTH
# (db-helpers.R) -- and RMariaDB does not support a nested transaction. So the
# caller-owned case needs a SAVEPOINT instead.
#
# review_write_run_mutation() has encoded that decision since #608; this helper
# is that logic lifted out so the approval path and the curation queue share one
# implementation instead of each re-deriving it.

source_api_file("functions/db-transaction-scope.R", local = FALSE)

fake_pool <- function() structure(list(), class = c("Pool", "list"))
fake_conn <- function() structure(list(), class = c("MariaDBConnection", "DBIConnection"))

test_that("a pool goes through the injected transaction runner", {
  seen <- NULL
  result <- db_with_savepoint_or_transaction(
    fake_pool(), "unit_test",
    fn = function(conn) "ran",
    transaction_runner = function(code, pool_obj = NULL) {
      seen <<- pool_obj
      code(pool_obj)
    }
  )
  expect_equal(result, "ran")
  expect_s3_class(seen, "Pool")
})

test_that("a direct connection uses a savepoint and releases it on success", {
  statements <- character()
  testthat::local_mocked_bindings(
    dbExecute = function(conn, statement, ...) {
      statements <<- c(statements, statement)
      1L
    },
    .package = "DBI"
  )

  expect_equal(
    db_with_savepoint_or_transaction(fake_conn(), "unit_test", fn = function(conn) "ok"),
    "ok"
  )
  expect_equal(statements, c("SAVEPOINT unit_test", "RELEASE SAVEPOINT unit_test"))
})

test_that("a direct connection rolls back to the savepoint and rethrows", {
  statements <- character()
  testthat::local_mocked_bindings(
    dbExecute = function(conn, statement, ...) {
      statements <<- c(statements, statement)
      1L
    },
    .package = "DBI"
  )

  expect_error(
    db_with_savepoint_or_transaction(fake_conn(), "unit_test",
                                     fn = function(conn) stop("boom")),
    "boom"
  )
  # The savepoint is rolled back and NOT released -- the caller's outer
  # transaction is still open and still theirs to finish.
  expect_equal(statements, c("SAVEPOINT unit_test", "ROLLBACK TO SAVEPOINT unit_test"))
})

test_that("a direct connection receives itself as the working connection", {
  testthat::local_mocked_bindings(dbExecute = function(conn, statement, ...) 1L, .package = "DBI")
  conn <- fake_conn()
  expect_identical(
    db_with_savepoint_or_transaction(conn, "unit_test", fn = function(cn) cn),
    conn
  )
})

test_that("the savepoint name must be a bare identifier", {
  # It is interpolated (savepoint names cannot be bound), so a caller passing a
  # non-literal must fail loudly rather than build SQL from it.
  expect_error(
    db_with_savepoint_or_transaction(fake_conn(), "bad name; DROP", fn = function(conn) NULL),
    "bare SQL identifier"
  )
  expect_error(
    db_with_savepoint_or_transaction(fake_conn(), "", fn = function(conn) NULL),
    "bare SQL identifier"
  )
})

test_that("review_write_run_mutation still delegates here", {
  # The #608 savepoint name is part of the review write path's behaviour; the
  # extraction must not rename it.
  service <- paste(
    readLines(file.path(get_api_dir(), "services", "review-write-service.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(service, "db_with_savepoint_or_transaction", fixed = TRUE)
  expect_match(service, "review_write_mutation", fixed = TRUE)
})
