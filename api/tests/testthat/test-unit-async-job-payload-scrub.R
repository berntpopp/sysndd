# tests/testthat/test-unit-async-job-payload-scrub.R
# #535 P1-1 + S2b: the historical-payload scrub is TERMINAL + non-retryable
# scoped, job-type AGNOSTIC, DUAL-PATH ($.db_config.password AND
# $.db_config.db_password via JSON_REPLACE), idempotent, and recomputes
# request_hash so it no longer encodes the password. The statement-shape test is
# host-runnable; the redaction/idempotency tests need the test DB.

library(testthat)

source_api_file("functions/async-job-payload-scrub.R", local = FALSE)

test_that("scrub statement is family-agnostic, terminal-scoped, both paths, idempotent, recomputes hash", {
  s <- async_job_payload_scrub_statement()
  # Both credential JSON paths: canonical families store $.db_config.password;
  # pubtator/llm store $.db_config.db_password (#535 S2b).
  expect_true(grepl("$.db_config.password", s, fixed = TRUE))
  expect_true(grepl("$.db_config.db_password", s, fixed = TRUE))
  # Job-type agnostic: no longer backup-only (all families were migrated, so it
  # is now safe to scrub every terminal row).
  expect_false(grepl("job_type IN ('backup_create'", s, fixed = TRUE))
  expect_true(grepl("status IN ('completed','failed','cancelled')", s, fixed = TRUE))
  expect_true(grepl("active_request_hash IS NULL", s, fixed = TRUE))  # avoid unique-index collision (M1)
  expect_true(grepl("SHA2(CONCAT(job_type", s, fixed = TRUE))   # request_hash recompute (H6)
  # JSON_REPLACE (not JSON_SET): never CREATE an absent key, only redact existing.
  expect_true(grepl("JSON_REPLACE", s, fixed = TRUE))
  expect_false(grepl("JSON_SET", s, fixed = TRUE))
  expect_true(grepl("<> '***REDACTED***'", s, fixed = TRUE))    # idempotency guard (M3)
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

test_that("scrub leaves a RETRYABLE-failed backup row (active_request_hash non-NULL) untouched (DB)", {
  skip_if_no_test_db()
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    # attempt_count < max_attempts AND next_attempt_at set -> active_request_hash
    # is the generated request_hash (non-NULL). Scrubbing two such rows that
    # differ only by password could collide on UNIQUE(job_type, active_request_hash).
    db_execute_statement(
      paste0(
        "INSERT INTO async_jobs (job_id, job_type, status, request_hash, ",
        "attempt_count, max_attempts, next_attempt_at, request_payload_json) ",
        "VALUES ('scrub-retry-1','backup_create','failed', REPEAT('c',64), ",
        "0, 3, NOW(6), JSON_OBJECT('db_config', JSON_OBJECT('password','leaky')))"
      ),
      list(), conn = con
    )
    n <- async_job_scrub_payload_credentials(conn = con)
    row <- DBI::dbGetQuery(
      con,
      "SELECT JSON_UNQUOTE(JSON_EXTRACT(request_payload_json,'$.db_config.password')) AS pw, active_request_hash FROM async_jobs WHERE job_id='scrub-retry-1'"
    )
    expect_false(is.na(row$active_request_hash))  # retryable -> active hash present
    expect_equal(row$pw, "leaky")                 # retryable row must NOT be scrubbed
    expect_equal(n, 0L)
  })
})

test_that("scrub redacts a NON-backup terminal row on the db_password path and recomputes hash (DB)", {
  # #535 S2b MEDIUM-2: pubtator/llm families persisted the credential under
  # $.db_config.db_password, and are now scrubbable (job-type agnostic).
  skip_if_no_test_db()
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    db_execute_statement(
      paste0(
        "INSERT INTO async_jobs (job_id, job_type, status, request_hash, request_payload_json) ",
        "VALUES ('scrub-llm-1','llm_generation','completed', REPEAT('d',64), ",
        "JSON_OBJECT('db_config', JSON_OBJECT('db_password','leaky','db_host','h','db_user','u',",
        "'db_port',3306,'db_name','d'), 'cluster_type','functional'))"
      ),
      list(), conn = con
    )

    n1 <- async_job_scrub_payload_credentials(conn = con)
    n2 <- async_job_scrub_payload_credentials(conn = con)
    expect_equal(n1, 1L)   # db_password-path row is redacted
    expect_equal(n2, 0L)   # idempotent

    row <- DBI::dbGetQuery(
      con,
      paste0("SELECT JSON_UNQUOTE(JSON_EXTRACT(request_payload_json,'$.db_config.db_password')) AS pw, ",
             "JSON_UNQUOTE(JSON_EXTRACT(request_payload_json,'$.cluster_type')) AS ct, ",
             "request_hash FROM async_jobs WHERE job_id='scrub-llm-1'")
    )
    expect_equal(row$pw, "***REDACTED***")
    expect_equal(row$ct, "functional")                   # non-credential fields preserved
    expect_equal(nchar(row$request_hash), 64L)
    expect_false(identical(row$request_hash, paste(rep("d", 64), collapse = "")))  # recomputed
  })
})

test_that("scrub does not CREATE a credential key on a payload that lacks db_config (DB)", {
  # JSON_REPLACE (not JSON_SET) must be a no-op on an absent path.
  skip_if_no_test_db()
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    db_execute_statement(
      paste0(
        "INSERT INTO async_jobs (job_id, job_type, status, request_hash, request_payload_json) ",
        "VALUES ('scrub-nodbcfg-1','llm_generation','completed', REPEAT('e',64), ",
        "JSON_OBJECT('cluster_type','functional'))"
      ),
      list(), conn = con
    )
    n <- async_job_scrub_payload_credentials(conn = con)
    row <- DBI::dbGetQuery(
      con,
      paste0("SELECT JSON_CONTAINS_PATH(request_payload_json,'one','$.db_config') AS has_cfg, ",
             "request_hash FROM async_jobs WHERE job_id='scrub-nodbcfg-1'")
    )
    expect_equal(as.integer(row$has_cfg), 0L)  # no db_config key was created
    expect_equal(row$request_hash, paste(rep("e", 64), collapse = ""))  # untouched
  })
})
