# api/tests/testthat/test-unit-publication-date-backfill.R
# NOTE: publication key is `publication_id` (prefixed string, e.g. "PMID:999100"); there is
# no bare numeric PMID column. Seed publication_id + a primary-approved review join.

test_that("backfill selects unverified primary-approved rows and writes both columns", {
  skip_if_no_test_db()
  source(file.path(get_api_dir(), "functions", "publication-functions.R"), local = FALSE)
  source(file.path(get_api_dir(), "functions", "publication-date-backfill.R"), local = FALSE)

  # info_from_pmid returns one row per fetched PMID with Publication_date +
  # publication_date_source. Override the global binding (the repo convention for
  # mocking sourced-into-global free functions; mirrors
  # test-mcp-service-publication-discovery.R). testthat::local_mocked_bindings cannot
  # target these non-package bindings.
  old_info <- get("info_from_pmid", envir = .GlobalEnv)
  assign("info_from_pmid", function(pmid_value, ...) dplyr::tibble(
    Publication_date = as.Date("2019-03-01"), publication_date_source = "pubmed"
  ), envir = .GlobalEnv)
  withr::defer(assign("info_from_pmid", old_info, envir = .GlobalEnv))

  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_publication_backfill_schema(conn)
    seed_primary_approved_publication(conn, publication_id = "PMID:999100", source = NULL)
    # manage_transaction = FALSE: the harness already holds an open transaction
    # (with_test_db_transaction); MySQL forbids a nested dbBegin. The worker /
    # operator CLI use the default TRUE on a fresh AUTOCOMMIT connection.
    res <- backfill_publication_dates_run(conn, dry_run = FALSE, manage_transaction = FALSE)
    expect_gte(res$targeted, 1L)
    expect_equal(res$verified, 1L)
    got <- DBI::dbGetQuery(conn,
      "SELECT Publication_date, publication_date_source FROM publication WHERE publication_id = 'PMID:999100'")
    expect_equal(got$publication_date_source, "pubmed")
    expect_equal(as.character(got$Publication_date), "2019-03-01")
  })
})

test_that("backfill fails observably when every targeted PMID errors (systemic outage)", {
  # Codex review (#460): a systemic fetch outage (NCBI down / worker egress broken)
  # must NOT complete as "success" with unresolved == targeted. When every targeted
  # PMID errors during fetch, the run raises a classed error so the async handler
  # marks the job failed and the CLI exits non-zero.
  skip_if_no_test_db()
  source(file.path(get_api_dir(), "functions", "publication-functions.R"), local = FALSE)
  source(file.path(get_api_dir(), "functions", "publication-date-backfill.R"), local = FALSE)

  old_info <- get("info_from_pmid", envir = .GlobalEnv)
  assign("info_from_pmid", function(pmid_value, ...) stop("simulated NCBI outage"),
         envir = .GlobalEnv)
  withr::defer(assign("info_from_pmid", old_info, envir = .GlobalEnv))

  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_publication_backfill_schema(conn)
    seed_primary_approved_publication(conn, publication_id = "PMID:999102", source = NULL)
    expect_error(
      backfill_publication_dates_run(conn, dry_run = FALSE, manage_transaction = FALSE),
      class = "publication_backfill_systemic_failure"
    )
    # No partial write leaked from the failed run.
    got <- DBI::dbGetQuery(conn,
      "SELECT publication_date_source FROM publication WHERE publication_id = 'PMID:999102'")
    expect_true(is.na(got$publication_date_source))
  })
})

test_that("backfill treats parse-empty PMIDs as unresolved, not a systemic outage", {
  # #500: a genuinely unresolvable PMID (info_from_pmid raises
  # publication_fetch_error after a clean fetch) is a DATA condition -> the run
  # succeeds with unresolved counted and nothing written; it must NOT raise the
  # transport-only systemic-outage error.
  skip_if_no_test_db()
  source(file.path(get_api_dir(), "functions", "publication-functions.R"), local = FALSE)
  source(file.path(get_api_dir(), "functions", "publication-date-backfill.R"), local = FALSE)

  old_info <- get("info_from_pmid", envir = .GlobalEnv)
  assign("info_from_pmid", function(pmid_value, ...) {
    rlang::abort("PMIDs not retrievable from PubMed: PMID:999103",
                 class = "publication_fetch_error")
  }, envir = .GlobalEnv)
  withr::defer(assign("info_from_pmid", old_info, envir = .GlobalEnv))

  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_publication_backfill_schema(conn)
    seed_primary_approved_publication(conn, publication_id = "PMID:999103", source = NULL)
    res <- backfill_publication_dates_run(conn, dry_run = FALSE, manage_transaction = FALSE)
    expect_equal(res$verified, 0L)
    expect_equal(res$written, 0L)
    expect_gte(res$unresolved_skip_count, 1L)
    expect_equal(res$failed_count, 0L)
    got <- DBI::dbGetQuery(conn,
      "SELECT publication_date_source FROM publication WHERE publication_id = 'PMID:999103'")
    expect_true(is.na(got$publication_date_source))
  })
})

test_that("dry_run reports targets without writing", {
  skip_if_no_test_db()
  source(file.path(get_api_dir(), "functions", "publication-date-backfill.R"), local = FALSE)
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_publication_backfill_schema(conn)
    seed_primary_approved_publication(conn, publication_id = "PMID:999101", source = NULL)
    res <- backfill_publication_dates_run(conn, dry_run = TRUE)
    expect_gte(res$targeted, 1L)
    expect_equal(res$verified, 0L)
    got <- DBI::dbGetQuery(conn,
      "SELECT publication_date_source FROM publication WHERE publication_id = 'PMID:999101'")
    expect_true(is.na(got$publication_date_source))
  })
})

test_that("publication_date_backfill handler is registered", {
  source_api_file("functions/async-job-force-apply-payload.R", local = FALSE)
  source_api_file("functions/async-job-handlers.R", local = FALSE)
  expect_true("publication_date_backfill" %in% names(async_job_handler_registry))
})

# ---------------------------------------------------------------------------
# #489 regression: backfill_write_updates must NOT probe transaction state with a
# bare SAVEPOINT. On a fresh MySQL AUTOCOMMIT connection (the worker handler and
# operator CLI) a bare SAVEPOINT "succeeds" but is not retained, so the follow-up
# ROLLBACK TO / RELEASE SAVEPOINT throws "SAVEPOINT ... does not exist" and the
# whole backfill fails with zero dates persisted. These tests are host-runnable:
# they use a fake DBI connection (no DB, no RMariaDB) that models that behavior.
# ---------------------------------------------------------------------------

library(DBI)

methods::setClass(
  "FakeBackfillConn",
  contains = "DBIConnection",
  representation(state = "environment")
)

new_fake_backfill_conn <- function(fail_on = NULL) {
  state <- new.env(parent = emptyenv())
  state$sql_log <- character()   # every statement executed
  state$attempted <- character() # publication_ids reaching an UPDATE
  state$persisted <- character() # publication_ids durably committed
  state$pending <- character()   # writes since dbBegin, not yet committed
  state$in_txn <- FALSE
  state$begins <- 0L
  state$commits <- 0L
  state$rollbacks <- 0L
  state$fail_on <- fail_on
  methods::new("FakeBackfillConn", state = state)
}

methods::setMethod("dbExecute", methods::signature("FakeBackfillConn", "character"), function(conn, statement, ...) {
  st <- conn@state
  st$sql_log <- c(st$sql_log, statement)
  # Model MySQL autocommit: a bare SAVEPOINT "succeeds" but is not retained, so a
  # later ROLLBACK TO / RELEASE fails — the exact #489 production symptom.
  if (grepl("SAVEPOINT", statement, ignore.case = TRUE)) {
    if (grepl("ROLLBACK TO|RELEASE", statement, ignore.case = TRUE)) {
      stop("SAVEPOINT sysndd_backfill_pub_dates does not exist")
    }
    return(0L)
  }
  params <- list(...)$params
  pid <- if (length(params) >= 3L) as.character(params[[3]]) else NA_character_
  st$attempted <- c(st$attempted, pid)
  if (!is.null(st$fail_on) && isTRUE(pid == st$fail_on)) {
    stop(sprintf("simulated write failure for %s", pid))
  }
  if (isTRUE(st$in_txn)) {
    st$pending <- c(st$pending, pid)
  } else {
    st$persisted <- c(st$persisted, pid)
  }
  1L
})

methods::setMethod("dbBegin", "FakeBackfillConn", function(conn, ...) {
  st <- conn@state
  st$in_txn <- TRUE
  st$pending <- character()
  st$begins <- st$begins + 1L
  invisible(TRUE)
})

methods::setMethod("dbCommit", "FakeBackfillConn", function(conn, ...) {
  st <- conn@state
  st$persisted <- c(st$persisted, st$pending)
  st$pending <- character()
  st$in_txn <- FALSE
  st$commits <- st$commits + 1L
  invisible(TRUE)
})

methods::setMethod("dbRollback", "FakeBackfillConn", function(conn, ...) {
  st <- conn@state
  st$pending <- character()
  st$in_txn <- FALSE
  st$rollbacks <- st$rollbacks + 1L
  invisible(TRUE)
})

.fake_backfill_rows <- function(pids) {
  data.frame(
    Publication_date = rep("2020-01-01", length(pids)),
    publication_date_source = rep("pubmed", length(pids)),
    publication_id = pids,
    stringsAsFactors = FALSE
  )
}

test_that("fake autocommit connection reproduces the #489 SAVEPOINT failure", {
  conn <- new_fake_backfill_conn()
  # A bare SAVEPOINT "succeeds" under autocommit ...
  expect_silent(DBI::dbExecute(conn, "SAVEPOINT sysndd_backfill_pub_dates"))
  # ... but the follow-up ROLLBACK TO / RELEASE throws the production symptom.
  expect_error(
    DBI::dbExecute(conn, "ROLLBACK TO SAVEPOINT sysndd_backfill_pub_dates"),
    "SAVEPOINT sysndd_backfill_pub_dates does not exist"
  )
})

test_that("backfill_write_updates issues no SAVEPOINT and commits one txn per batch", {
  source(file.path(get_api_dir(), "functions", "publication-date-backfill.R"), local = FALSE)
  conn <- new_fake_backfill_conn()
  to_update <- .fake_backfill_rows(c("PMID:1", "PMID:2", "PMID:3"))

  written <- backfill_write_updates(conn, to_update, manage_transaction = TRUE,
                                    write_batch_size = 2L)

  expect_equal(written, 3L)
  expect_false(any(grepl("SAVEPOINT", conn@state$sql_log, ignore.case = TRUE)))
  # Two batches (2 + 1) => two owned transactions, both committed.
  expect_equal(conn@state$begins, 2L)
  expect_equal(conn@state$commits, 2L)
  expect_setequal(conn@state$persisted, c("PMID:1", "PMID:2", "PMID:3"))
})

test_that("backfill_write_updates persists earlier batches when a later batch throws", {
  source(file.path(get_api_dir(), "functions", "publication-date-backfill.R"), local = FALSE)
  conn <- new_fake_backfill_conn(fail_on = "PMID:2")
  to_update <- .fake_backfill_rows(c("PMID:1", "PMID:2", "PMID:3"))

  # write_batch_size = 1 => batch 1 (PMID:1) commits, batch 2 (PMID:2) throws.
  expect_error(
    backfill_write_updates(conn, to_update, manage_transaction = TRUE,
                           write_batch_size = 1L),
    "simulated write failure for PMID:2"
  )
  # No SAVEPOINT anywhere, and the already-committed batch survived the failure.
  expect_false(any(grepl("SAVEPOINT", conn@state$sql_log, ignore.case = TRUE)))
  expect_true("PMID:1" %in% conn@state$persisted)
  expect_false("PMID:2" %in% conn@state$persisted)
  expect_false("PMID:3" %in% conn@state$persisted)
  expect_equal(conn@state$rollbacks, 1L)
})

test_that("backfill_write_updates joins the caller's transaction when manage_transaction = FALSE", {
  source(file.path(get_api_dir(), "functions", "publication-date-backfill.R"), local = FALSE)
  conn <- new_fake_backfill_conn()
  to_update <- .fake_backfill_rows(c("PMID:10", "PMID:11"))

  written <- backfill_write_updates(conn, to_update, manage_transaction = FALSE,
                                    write_batch_size = 200L)

  expect_equal(written, 2L)
  # Never owns a transaction (no nested dbBegin) and never issues a SAVEPOINT.
  expect_equal(conn@state$begins, 0L)
  expect_false(any(grepl("SAVEPOINT", conn@state$sql_log, ignore.case = TRUE)))
  expect_setequal(conn@state$attempted, c("PMID:10", "PMID:11"))
})
