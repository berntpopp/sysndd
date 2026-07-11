# tests/testthat/test-unit-async-job-payload-scrub.R
# #535 P1-1: the historical-payload scrub is backup + terminal scoped, single
# path, idempotent, and recomputes request_hash so it no longer encodes the
# password. The statement-shape test is host-runnable; the idempotency test
# needs the test DB.

library(testthat)

source_api_file("functions/async-job-payload-scrub.R", local = FALSE)

test_that("scrub statement is backup+terminal-scoped, single-path, idempotent, recomputes hash", {
  s <- async_job_payload_scrub_statement()
  expect_true(grepl("$.db_config.password", s, fixed = TRUE))
  expect_true(grepl("job_type IN ('backup_create','backup_restore')", s, fixed = TRUE))
  expect_true(grepl("status IN ('completed','failed','cancelled')", s, fixed = TRUE))
  expect_true(grepl("SHA2(CONCAT(job_type", s, fixed = TRUE))   # request_hash recompute (H6)
  expect_true(grepl("<> '***REDACTED***'", s, fixed = TRUE))    # idempotency guard (M3)
  # Single path only (backup family): must NOT touch other families' variants.
  expect_false(grepl("db_password", s, fixed = TRUE))
})

test_that("scrub redacts a seeded terminal backup row once and is idempotent (DB)", {
  skip_if_no_test_db()
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    db_execute_statement(
      paste0(
        "INSERT INTO async_jobs (job_id, job_type, status, request_hash, request_payload_json) ",
        "VALUES ('scrub-test-1','backup_create','completed', REPEAT('a',64), ",
        "JSON_OBJECT('db_config', JSON_OBJECT('password','leaky','host','h','user','u','port',3306,'dbname','d'), ",
        "'backup_dir','/backup'))"
      ),
      list(), conn = con
    )

    n1 <- async_job_scrub_payload_credentials(conn = con)
    n2 <- async_job_scrub_payload_credentials(conn = con)
    expect_equal(n1, 1L)   # redacts the seeded row
    expect_equal(n2, 0L)   # idempotent: nothing left to do

    row <- DBI::dbGetQuery(
      con,
      paste0("SELECT JSON_UNQUOTE(JSON_EXTRACT(request_payload_json,'$.db_config.password')) AS pw, ",
             "request_hash FROM async_jobs WHERE job_id='scrub-test-1'")
    )
    expect_equal(row$pw, "***REDACTED***")
    expect_equal(nchar(row$request_hash), 64L)          # still a valid sha256
    expect_false(identical(row$request_hash, paste(rep("a", 64), collapse = "")))  # recomputed
  })
})

test_that("scrub leaves a QUEUED backup row (non-terminal) untouched (DB)", {
  skip_if_no_test_db()
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    db_execute_statement(
      paste0(
        "INSERT INTO async_jobs (job_id, job_type, status, request_hash, request_payload_json) ",
        "VALUES ('scrub-queued-1','backup_create','queued', REPEAT('b',64), ",
        "JSON_OBJECT('db_config', JSON_OBJECT('password','leaky'), 'backup_dir','/backup'))"
      ),
      list(), conn = con
    )
    n <- async_job_scrub_payload_credentials(conn = con)
    row <- DBI::dbGetQuery(
      con,
      "SELECT JSON_UNQUOTE(JSON_EXTRACT(request_payload_json,'$.db_config.password')) AS pw FROM async_jobs WHERE job_id='scrub-queued-1'"
    )
    expect_equal(row$pw, "leaky")  # queued row must NOT be scrubbed (its handler may still run)
    expect_equal(n, 0L)
  })
})
