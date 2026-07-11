# tests/testthat/test-unit-async-job-maintenance-handlers.R
#
# #535 P1-1: the durable backup handlers must resolve DB credentials from
# runtime config (async_job_worker_db_config), NOT from the job payload, and
# must preserve the pre-restore safety-backup contract (BKUP-05). Host-runnable:
# the handler is sourced into a sandbox env whose free variables (resolver,
# progress reporter, mysqldump/restore) resolve to stubs.

library(testthat)

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a)) b else a

# Source the maintenance handlers into an isolated env and stub the collaborators
# they look up (resolver, progress reporter). Per-test stubs for
# execute_mysqldump/execute_restore are assigned into the returned env.
make_handler_sandbox <- function() {
  env <- new.env(parent = globalenv())
  source_api_file("functions/async-job-maintenance-handlers.R", local = FALSE, envir = env)
  env$.async_job_progress_reporter <- function(job_id) function(...) invisible(NULL)
  env$async_job_worker_db_config <- function(...) {
    list(dbname = "d", host = "h", user = "u", password = "RUNTIME_PW", port = 3306L)
  }
  env
}

test_that("backup_create resolves creds from runtime config, not the payload", {
  env <- make_handler_sandbox()
  seen <- new.env()
  env$execute_mysqldump <- function(db_config, output_file, ...) {
    seen$pw <- db_config$password
    list(success = TRUE, file = output_file, size_bytes = 10, compressed = TRUE)
  }
  job <- list(job_id = "j1")
  payload <- list(backup_dir = "/backup", backup_filename = "m.sql")  # NO db_config

  out <- env$.async_job_run_backup_create(job, payload, state = NULL, worker_config = NULL)

  expect_equal(out$status, "completed")
  expect_equal(seen$pw, "RUNTIME_PW")  # from resolver, never the payload
})

test_that("backup_restore runs the pre-restore backup BEFORE restore, using runtime creds", {
  env <- make_handler_sandbox()
  call_log <- character(0)
  seen <- new.env()
  env$execute_mysqldump <- function(db_config, output_file, ...) {
    call_log <<- c(call_log, "mysqldump")
    seen$dump_pw <- db_config$password
    list(success = TRUE, file = output_file, size_bytes = 10, compressed = TRUE)
  }
  env$execute_restore <- function(db_config, restore_file, ...) {
    call_log <<- c(call_log, "restore")
    seen$restore_pw <- db_config$password
    list(success = TRUE)
  }
  job <- list(job_id = "j1")
  payload <- list(backup_dir = "/backup", restore_file = "/backup/x.sql.gz")  # NO db_config

  out <- env$.async_job_run_backup_restore(job, payload, state = NULL, worker_config = NULL)

  expect_equal(call_log, c("mysqldump", "restore"))  # safety backup strictly before restore
  expect_equal(out$status, "completed")
  expect_equal(seen$dump_pw, "RUNTIME_PW")
  expect_equal(seen$restore_pw, "RUNTIME_PW")
})

test_that("backup_restore aborts before restoring when the pre-restore backup fails", {
  env <- make_handler_sandbox()
  call_log <- character(0)
  env$execute_mysqldump <- function(...) {
    call_log <<- c(call_log, "mysqldump")
    list(success = FALSE, error = "disk full")
  }
  env$execute_restore <- function(...) {
    call_log <<- c(call_log, "restore")
    list(success = TRUE)
  }
  job <- list(job_id = "j1")
  payload <- list(backup_dir = "/backup", restore_file = "/backup/x.sql.gz")

  expect_error(
    env$.async_job_run_backup_restore(job, payload, NULL, NULL),
    "Pre-restore backup failed"
  )
  expect_equal(call_log, "mysqldump")  # execute_restore() must never run
})
