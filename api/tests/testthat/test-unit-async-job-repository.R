library(testthat)
library(DBI)

source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/migration-runner.R", local = FALSE)

async_job_repository_path <- function() {
  override <- Sys.getenv("ASYNC_JOB_REPOSITORY_PATH", "")
  if (nzchar(override)) {
    return(override)
  }

  file.path(get_api_dir(), "functions", "async-job-repository.R")
}

async_job_migration_path <- function() {
  override <- Sys.getenv("ASYNC_JOB_MIGRATION_PATH", "")
  if (nzchar(override)) {
    return(override)
  }

  candidates <- c(
    file.path(get_api_dir(), "..", "db", "migrations", "020_add_async_job_schema.sql"),
    file.path(get_api_dir(), "db", "migrations", "020_add_async_job_schema.sql")
  )

  for (candidate in candidates) {
    if (file.exists(candidate)) {
      return(candidate)
    }
  }

  candidates[[1]]
}

ensure_async_job_repository_loaded <- function() {
  repo_path <- async_job_repository_path()
  if (!file.exists(repo_path)) {
    stop("async-job repository file is missing: ", repo_path)
  }

  source(repo_path, local = FALSE)
  invisible(repo_path)
}

apply_async_job_migration <- function(conn) {
  migration_path <- async_job_migration_path()
  if (!file.exists(migration_path)) {
    stop("async-job migration file is missing: ", migration_path)
  }

  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")
  statements <- split_sql_statements(sql)

  for (statement in statements) {
    DBI::dbExecute(conn, statement, immediate = TRUE)
  }

  invisible(TRUE)
}

ensure_async_job_schema <- function() {
  conn <- get_test_db_connection()
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  if (DBI::dbExistsTable(conn, "async_job_events")) {
    DBI::dbExecute(conn, "DROP TABLE async_job_events", immediate = TRUE)
  }
  if (DBI::dbExistsTable(conn, "async_jobs")) {
    DBI::dbExecute(conn, "DROP TABLE async_jobs", immediate = TRUE)
  }

  apply_async_job_migration(conn)

  invisible(TRUE)
}

seed_async_job <- function(conn, ...) {
  async_job_repository_create(
    c(
      list(
        job_id = paste0("job-", substr(uuid::UUIDgenerate(), 1, 8)),
        job_type = "hgnc_update",
        queue_name = "default",
        priority = 100L,
        request_payload_json = "{\"operation\":\"hgnc_update\"}",
        request_hash = paste0("hash-", substr(uuid::UUIDgenerate(), 1, 12)),
        submitted_by = NULL,
        scheduled_at = Sys.time(),
        max_attempts = 1L
      ),
      list(...)
    ),
    conn = conn
  )
}

test_that("async job migration exposes required durable columns and audit-safe foreign key", {
  skip_if_no_test_db()
  ensure_async_job_repository_loaded()
  ensure_async_job_schema()

  conn <- get_test_db_connection()
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  async_job_columns <- DBI::dbGetQuery(conn, "SHOW COLUMNS FROM async_jobs")$Field
  event_columns <- DBI::dbGetQuery(conn, "SHOW COLUMNS FROM async_job_events")$Field
  create_sql <- DBI::dbGetQuery(conn, "SHOW CREATE TABLE async_jobs")$`Create Table`[1]

  expect_true(all(c(
    "job_id",
    "job_type",
    "queue_name",
    "priority",
    "status",
    "request_hash",
    "request_payload_json",
    "submitted_by",
    "scheduled_at",
    "claim_token",
    "worker_hostname",
    "worker_pid",
    "last_heartbeat_at",
    "claim_expires_at",
    "next_attempt_at",
    "progress_pct",
    "progress_message",
    "cancelled_by",
    "updated_at",
    "result_json"
  ) %in% async_job_columns))
  expect_true(all(c("event_id", "job_id", "event_type", "event_message", "event_payload_json", "created_at") %in% event_columns))
  expect_match(create_sql, "FOREIGN KEY \\(`submitted_by`\\) REFERENCES `user` \\(`user_id`\\)")
  expect_false(grepl("FOREIGN KEY \\(`submitted_by`\\).*ON DELETE CASCADE", create_sql))
})

test_that("async_job_repository_create and get support polling without result payloads", {
  skip_if_no_test_db()
  ensure_async_job_repository_loaded()
  ensure_async_job_schema()

  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    submitted_at <- as.POSIXct("2026-04-23 09:00:00", tz = "UTC")

    job_id <- async_job_repository_create(
      list(
        job_id = "job-create-get",
        job_type = "comparisons_update",
        queue_name = "bulk",
        priority = 10L,
        request_payload_json = "{\"operation\":\"comparisons_update\"}",
        request_hash = "hash-create-get",
        submitted_by = NULL,
        submitted_at = submitted_at,
        scheduled_at = submitted_at,
        max_attempts = 3L
      ),
      conn = conn
    )

    stored_poll <- async_job_repository_get(job_id, conn = conn)
    stored_full <- async_job_repository_get(job_id, include_result = TRUE, conn = conn)

    expect_equal(job_id, "job-create-get")
    expect_equal(stored_poll$job_id[[1]], "job-create-get")
    expect_equal(stored_poll$status[[1]], "queued")
    expect_equal(stored_poll$queue_name[[1]], "bulk")
    expect_false("result_json" %in% colnames(stored_poll))
    expect_true("result_json" %in% colnames(stored_full))
    expect_true(is.na(stored_full$result_json[[1]]))
  })
})

test_that("async_job_repository_find_active_duplicate ignores terminal jobs", {
  skip_if_no_test_db()
  ensure_async_job_repository_loaded()
  ensure_async_job_schema()

  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    seed_async_job(
      conn,
      job_id = "job-duplicate-completed",
      request_hash = "dup-hash",
      status = "completed"
    )
    seed_async_job(
      conn,
      job_id = "job-duplicate-running",
      request_hash = "dup-hash",
      status = "running",
      claimed_by_worker = "worker-a",
      worker_hostname = "host-a",
      worker_pid = 1001L,
      started_at = Sys.time(),
      last_heartbeat_at = Sys.time(),
      claim_expires_at = Sys.time() + 60
    )

    duplicate <- async_job_repository_find_active_duplicate(
      job_type = "hgnc_update",
      request_hash = "dup-hash",
      conn = conn
    )

    expect_equal(duplicate$job_id[[1]], "job-duplicate-running")
    expect_equal(duplicate$status[[1]], "running")

    async_job_repository_fail(
      job_id = "job-duplicate-running",
      error_code = "RETRY",
      error_message = "Retry later",
      claim_token = duplicate$claim_token[[1]],
      next_attempt_at = Sys.time() + 60,
      conn = conn
    )

    retry_duplicate <- async_job_repository_find_active_duplicate(
      job_type = "hgnc_update",
      request_hash = "dup-hash",
      conn = conn
    )

    expect_equal(retry_duplicate$job_id[[1]], "job-duplicate-running")
    expect_equal(retry_duplicate$status[[1]], "failed")
  })
})

test_that("async_job_repository_create raises durable duplicate error for concurrent active hash", {
  skip_if_no_test_db()
  ensure_async_job_repository_loaded()
  ensure_async_job_schema()

  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    seed_async_job(
      conn,
      job_id = "job-duplicate-existing",
      request_hash = "durable-dup-hash",
      status = "queued"
    )

    expect_error(
      async_job_repository_create(
        list(
          job_id = "job-duplicate-new",
          job_type = "hgnc_update",
          queue_name = "default",
          priority = 100L,
          request_payload_json = "{\"operation\":\"hgnc_update\"}",
          request_hash = "durable-dup-hash",
          scheduled_at = Sys.time(),
          max_attempts = 1L
        ),
        conn = conn
      ),
      class = "async_job_duplicate_error"
    )
  })
})

test_that("async_job_repository_claim_next claims one eligible job and marks it running", {
  skip_if_no_test_db()
  ensure_async_job_repository_loaded()
  ensure_async_job_schema()

  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    seed_async_job(
      conn,
      job_id = "job-claim-queued",
      queue_name = "default",
      priority = 5L,
      request_hash = "claim-hash-queued",
      scheduled_at = as.POSIXct("2026-04-23 08:59:00", tz = "UTC"),
      max_attempts = 2L
    )
    seed_async_job(
      conn,
      job_id = "job-claim-retry",
      request_hash = "claim-hash-retry",
      priority = 5L,
      status = "failed",
      attempt_count = 1L,
      max_attempts = 3L,
      next_attempt_at = as.POSIXct("2026-04-23 08:58:00", tz = "UTC"),
      scheduled_at = as.POSIXct("2026-04-23 08:50:00", tz = "UTC")
    )
    seed_async_job(
      conn,
      job_id = "job-claim-later",
      request_hash = "claim-hash-later",
      priority = 1L,
      scheduled_at = Sys.time() + 3600
    )

    claimed <- async_job_repository_claim_next(
      worker_id = "worker-a",
      worker_hostname = "host-a",
      worker_pid = 4242L,
      lease_seconds = 60L,
      queues = "default",
      conn = conn
    )

    expect_equal(claimed$job_id[[1]], "job-claim-queued")
    expect_equal(claimed$status[[1]], "running")
    expect_equal(claimed$claimed_by_worker[[1]], "worker-a")
    expect_equal(claimed$worker_hostname[[1]], "host-a")
    expect_equal(claimed$worker_pid[[1]], 4242L)
    expect_equal(claimed$attempt_count[[1]], 1L)
    expect_true(nzchar(claimed$claim_token[[1]]))
    expect_false(is.na(claimed$claim_expires_at[[1]]))

    second_claim <- async_job_repository_claim_next(
      worker_id = "worker-b",
      worker_hostname = "host-b",
      worker_pid = 4343L,
      lease_seconds = 60L,
      queues = "default",
      conn = conn
    )

    expect_equal(second_claim$job_id[[1]], "job-claim-retry")
    expect_equal(second_claim$attempt_count[[1]], 2L)

    seed_async_job(
      conn,
      job_id = "job-claim-retry-earlier",
      request_hash = "claim-hash-retry-earlier",
      priority = 5L,
      status = "failed",
      attempt_count = 1L,
      max_attempts = 3L,
      next_attempt_at = as.POSIXct("2026-04-23 08:55:00", tz = "UTC"),
      scheduled_at = as.POSIXct("2026-04-23 08:59:30", tz = "UTC")
    )
    seed_async_job(
      conn,
      job_id = "job-claim-retry-later",
      request_hash = "claim-hash-retry-later",
      priority = 5L,
      status = "failed",
      attempt_count = 1L,
      max_attempts = 3L,
      next_attempt_at = as.POSIXct("2026-04-23 08:57:00", tz = "UTC"),
      scheduled_at = as.POSIXct("2026-04-23 08:40:00", tz = "UTC")
    )

    retry_order_claim <- async_job_repository_claim_next(
      worker_id = "worker-c",
      worker_hostname = "host-c",
      worker_pid = 4444L,
      lease_seconds = 60L,
      queues = "default",
      conn = conn
    )

    expect_equal(retry_order_claim$job_id[[1]], "job-claim-retry-earlier")
  })
})

test_that("async job repository updates progress, appends events, heartbeats, and completes", {
  skip_if_no_test_db()
  ensure_async_job_repository_loaded()
  ensure_async_job_schema()

  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    seed_async_job(conn, job_id = "job-progress", request_hash = "progress-hash")
    claimed <- async_job_repository_claim_next(
      worker_id = "worker-progress",
      worker_hostname = "host-progress",
      worker_pid = 5151L,
      lease_seconds = 30L,
      queues = "default",
      conn = conn
    )

    async_job_repository_update_progress(
      job_id = "job-progress",
      progress_pct = 55.5,
      progress_message = "Halfway there",
      claim_token = claimed$claim_token[[1]],
      conn = conn
    )
    event_id <- async_job_repository_append_event(
      job_id = "job-progress",
      event_type = "progress",
      event_message = "Milestone reached",
      event_payload = "{\"pct\":55.5}",
      conn = conn
    )
    async_job_repository_heartbeat(
      job_id = "job-progress",
      lease_seconds = 90L,
      claim_token = claimed$claim_token[[1]],
      conn = conn
    )
    async_job_repository_complete(
      job_id = "job-progress",
      result_json = "{\"ok\":true}",
      claim_token = claimed$claim_token[[1]],
      conn = conn
    )

    stored <- async_job_repository_get("job-progress", include_result = TRUE, conn = conn)
    events <- DBI::dbGetQuery(
      conn,
      "SELECT event_id, event_type, event_message, event_payload_json FROM async_job_events WHERE job_id = ?",
      params = list("job-progress")
    )

    expect_equal(stored$status[[1]], "completed")
    expect_equal(stored$progress_message[[1]], "Halfway there")
    expect_equal(round(stored$progress_pct[[1]], 1), 55.5)
    expect_equal(stored$result_json[[1]], "{\"ok\":true}")
    expect_false(is.na(stored$completed_at[[1]]))
    expect_true(is.na(stored$claim_expires_at[[1]]))
    expect_true(event_id > 0)
    expect_equal(events$event_type[[1]], "progress")
    expect_equal(events$event_message[[1]], "Milestone reached")
  })
})

test_that("async job repository mutators reject stale claim tokens", {
  skip_if_no_test_db()
  ensure_async_job_repository_loaded()
  ensure_async_job_schema()

  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    seed_async_job(conn, job_id = "job-stale-token", request_hash = "stale-token-hash")
    claimed <- async_job_repository_claim_next(
      worker_id = "worker-token",
      worker_hostname = "host-token",
      worker_pid = 6060L,
      lease_seconds = 30L,
      conn = conn
    )

    progress_rows <- async_job_repository_update_progress(
      job_id = "job-stale-token",
      progress_pct = 10,
      progress_message = "stale",
      claim_token = "wrong-token",
      conn = conn
    )
    heartbeat_rows <- async_job_repository_heartbeat(
      job_id = "job-stale-token",
      lease_seconds = 60L,
      claim_token = "wrong-token",
      conn = conn
    )
    complete_rows <- async_job_repository_complete(
      job_id = "job-stale-token",
      result_json = "{\"ok\":true}",
      claim_token = "wrong-token",
      conn = conn
    )

    stored <- async_job_repository_get("job-stale-token", include_result = TRUE, conn = conn)

    expect_equal(progress_rows, 0L)
    expect_equal(heartbeat_rows, 0L)
    expect_equal(complete_rows, 0L)
    expect_equal(stored$status[[1]], "running")
    expect_true(is.na(stored$result_json[[1]]))
    expect_equal(stored$claim_token[[1]], claimed$claim_token[[1]])
  })
})

test_that("async job repository fail, cancel, and stale recovery follow durable status rules", {
  skip_if_no_test_db()
  ensure_async_job_repository_loaded()
  ensure_async_job_schema()

  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    seed_async_job(conn, job_id = "job-fail", request_hash = "fail-hash", max_attempts = 3L)
    claimed_fail <- async_job_repository_claim_next(
      worker_id = "worker-fail",
      worker_hostname = "host-fail",
      worker_pid = 6161L,
      lease_seconds = 30L,
      conn = conn
    )
    retry_at <- as.POSIXct("2026-04-23 09:05:00", tz = "UTC")
    async_job_repository_fail(
      job_id = "job-fail",
      error_code = "TRANSIENT",
      error_message = "Retry later",
      claim_token = claimed_fail$claim_token[[1]],
      next_attempt_at = retry_at,
      conn = conn
    )

    failed <- async_job_repository_get("job-fail", include_result = TRUE, conn = conn)
    expect_equal(failed$status[[1]], "failed")
    expect_equal(failed$last_error_code[[1]], "TRANSIENT")
    expect_equal(as.character(failed$next_attempt_at[[1]]), as.character(retry_at))

    expect_error(
      async_job_repository_create(
        list(
          job_id = "job-fail",
          job_type = "hgnc_update",
          queue_name = "default",
          priority = 100L,
          request_payload_json = "{\"operation\":\"hgnc_update\"}",
          request_hash = "different-hash",
          scheduled_at = Sys.time(),
          max_attempts = 1L
        ),
        conn = conn
      ),
      class = "db_statement_error"
    )

    seed_async_job(conn, job_id = "job-cancel-running", request_hash = "cancel-running-hash")
    async_job_repository_claim_next(
      worker_id = "worker-cancel",
      worker_hostname = "host-cancel",
      worker_pid = 7171L,
      lease_seconds = 30L,
      conn = conn
    )
    async_job_repository_cancel("job-cancel-running", cancelled_by = NULL, conn = conn)
    cancelled_request <- async_job_repository_get("job-cancel-running", conn = conn)
    expect_equal(cancelled_request$status[[1]], "cancel_requested")
    heartbeat_rows <- async_job_repository_heartbeat(
      job_id = "job-cancel-running",
      lease_seconds = 60L,
      claim_token = cancelled_request$claim_token[[1]],
      conn = conn
    )
    expect_equal(heartbeat_rows, 1L)

    seed_async_job(conn, job_id = "job-cancel-queued", request_hash = "cancel-queued-hash")
    async_job_repository_cancel("job-cancel-queued", cancelled_by = NULL, conn = conn)
    cancelled <- async_job_repository_get("job-cancel-queued", conn = conn)
    expect_equal(cancelled$status[[1]], "cancelled")
    expect_false(is.na(cancelled$completed_at[[1]]))

    seed_async_job(
      conn,
      job_id = "job-cancel-completed",
      request_hash = "cancel-completed-hash",
      status = "completed",
      completed_at = Sys.time()
    )
    async_job_repository_cancel("job-cancel-completed", cancelled_by = 42L, conn = conn)
    completed_after_cancel <- async_job_repository_get("job-cancel-completed", conn = conn)
    expect_equal(completed_after_cancel$status[[1]], "completed")
    expect_true(is.na(completed_after_cancel$cancelled_by[[1]]))

    seed_async_job(
      conn,
      job_id = "job-stale-retry",
      request_hash = "stale-retry-hash",
      status = "running",
      attempt_count = 1L,
      max_attempts = 3L,
      claimed_by_worker = "worker-stale",
      worker_hostname = "host-stale",
      worker_pid = 8181L,
      started_at = Sys.time() - 300,
      last_heartbeat_at = Sys.time() - 300,
      claim_expires_at = Sys.time() - 120
    )
    seed_async_job(
      conn,
      job_id = "job-stale-terminal",
      request_hash = "stale-terminal-hash",
      status = "running",
      attempt_count = 1L,
      max_attempts = 1L,
      claimed_by_worker = "worker-terminal",
      worker_hostname = "host-terminal",
      worker_pid = 9191L,
      started_at = Sys.time() - 300,
      last_heartbeat_at = Sys.time() - 300,
      claim_expires_at = Sys.time() - 120
    )

    recovered <- async_job_repository_recover_stale(now = Sys.time(), conn = conn)

    stale_retry <- async_job_repository_get("job-stale-retry", conn = conn)
    stale_terminal <- async_job_repository_get("job-stale-terminal", conn = conn)

    expect_equal(recovered$jobs_recovered[[1]], 2L)
    expect_equal(stale_retry$status[[1]], "queued")
    expect_true(is.na(stale_retry$next_attempt_at[[1]]))
    expect_false(is.na(stale_retry$scheduled_at[[1]]))
    expect_true(is.na(stale_retry$completed_at[[1]]))
    expect_true(is.na(stale_retry$claimed_by_worker[[1]]))
    expect_equal(stale_terminal$status[[1]], "failed")
    expect_true(is.na(stale_terminal$next_attempt_at[[1]]))
    expect_equal(stale_terminal$last_error_code[[1]], "LEASE_EXPIRED")
  })
})

test_that("async_job_repository_history returns newest jobs first without result payloads", {
  skip_if_no_test_db()
  ensure_async_job_repository_loaded()
  ensure_async_job_schema()

  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    seed_async_job(
      conn,
      job_id = "job-history-old",
      request_hash = "history-old",
      submitted_at = as.POSIXct("2026-04-23 08:00:00", tz = "UTC"),
      scheduled_at = as.POSIXct("2026-04-23 08:00:00", tz = "UTC")
    )
    seed_async_job(
      conn,
      job_id = "job-history-new",
      request_hash = "history-new",
      submitted_at = as.POSIXct("2026-04-23 09:00:00", tz = "UTC"),
      scheduled_at = as.POSIXct("2026-04-23 09:00:00", tz = "UTC")
    )

    history <- async_job_repository_history(limit = 1L, conn = conn)

    expect_equal(nrow(history), 1)
    expect_equal(history$job_id[[1]], "job-history-new")
    expect_false("result_json" %in% colnames(history))
  })
})
