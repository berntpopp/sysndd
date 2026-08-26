# functions/db-transaction-scope.R
#
# One decision, in one place: how to make a write unit atomic when the caller
# may hand you EITHER a pool OR a connection they already own.
#
# A pool gets a real transaction. A direct DBIConnection is caller-owned --
# `with_test_db_transaction()` has already issued `DBI::dbBegin()` -- and
# RMariaDB does not support a nested transaction, so it gets a SAVEPOINT.
# Handing such a connection to `db_with_transaction()` calls
# `DBI::dbWithTransaction()` on it and fails.
#
# This lives in its own file, ahead of functions/db-helpers.R in the loader,
# because db-helpers.R opens with `library(RMariaDB)` and this logic needs
# nothing but DBI -- so it stays testable on a host without the MySQL client
# runtime. The `transaction_runner` default references `db_with_transaction()`
# from that file; R evaluates default arguments lazily, so it only has to exist
# by the time a POOL is passed, which is always true in the loaded API.

#' Run a write unit atomically on either a pool or a caller-owned connection
#'
#' A pool gets a real transaction. A direct DBIConnection is CALLER-OWNED --
#' notably `with_test_db_transaction()`, which has already issued
#' `DBI::dbBegin()` -- and RMariaDB does not support a nested transaction, so it
#' gets a SAVEPOINT instead. Handing such a connection to `db_with_transaction()`
#' would still call `DBI::dbWithTransaction()` on it and fail.
#'
#' On failure the savepoint is rolled back but NOT released: the caller's outer
#' transaction is still open and still theirs to commit or roll back.
#'
#' Extracted from `review_write_run_mutation()` (#608), which now delegates here,
#' so the review write path, the approval path (#612) and the curation queue
#' share one implementation of this decision rather than each re-deriving it.
#'
#' @param db Pool or DBIConnection.
#' @param savepoint Savepoint name. A savepoint name cannot be bound, so this is
#'   interpolated -- callers pass a literal, and a value that is not a bare SQL
#'   identifier is rejected rather than built into a statement.
#' @param fn Function taking the working connection.
#' @param transaction_runner Injectable for tests; defaults to db_with_transaction.
#' @return Whatever `fn` returns.
#' @export
db_with_savepoint_or_transaction <- function(db, savepoint, fn,
                                             transaction_runner = db_with_transaction) {
  if (length(savepoint) != 1L || is.na(savepoint) ||
        !grepl("^[A-Za-z_][A-Za-z0-9_]*$", savepoint)) {
    stop("savepoint must be a bare SQL identifier")
  }

  if (inherits(db, "DBIConnection")) {
    DBI::dbExecute(db, paste("SAVEPOINT", savepoint))
    return(tryCatch(
      {
        result <- fn(db)
        DBI::dbExecute(db, paste("RELEASE SAVEPOINT", savepoint))
        result
      },
      error = function(error) {
        DBI::dbExecute(db, paste("ROLLBACK TO SAVEPOINT", savepoint))
        stop(error)
      }
    ))
  }

  transaction_runner(fn, pool_obj = db)
}
