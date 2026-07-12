# tests/testthat/test-unit-backup-endpoint-service.R
# Unit tests for api/services/backup-endpoint-service.R (#346 Wave 3 Task 9).
#
# These exercise the svc_backup_* handler-body functions directly (no
# decorator/plumber extraction, no `require_role()` gate — that stays in
# api/endpoints/backup_endpoints.R and is covered by
# tests/testthat/test-endpoint-backup.R). Everything here is host-runnable:
# no real /backup mount and no real database. All downstream helpers
# (list_backup_files, get_backup_metadata, check_duplicate_job, create_job,
# execute_mysqldump, execute_restore, filesystem primitives) are stubbed
# per test via closures in an isolated sandbox environment, mirroring the
# approach in test-endpoint-backup.R. There is no DB-state case in this
# service layer (all DB-touching work is mocked at the check_duplicate_job/
# create_job boundary), so no skip_if_no_test_db() guard is needed here.

library(testthat)

`%||%` <- function(a, b) if (is.null(a)) b else a

# -----------------------------------------------------------------------------
# Sandbox helpers
# -----------------------------------------------------------------------------

make_mock_res <- function() {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res$body <- NULL
  res$headers <- list()
  res$setHeader <- function(name, value) {
    res$headers[[name]] <- value
    invisible(NULL)
  }
  res$serializer <- NULL
  res
}

admin_req <- function(body = NULL) {
  list(
    user_id = 42L,
    user_role = "Administrator",
    user_name = "admin_test",
    argsBody = body %||% list()
  )
}

# Real shared filename validator (path-traversal / extension policy), loaded
# once into an isolated env so we exercise the actual guard, not a stand-in.
.backup_functions_env <- new.env()
source_api_file("functions/backup-functions.R", local = FALSE, envir = .backup_functions_env)

#' Build a sandbox env with the stubs svc_backup_* reaches for, then source
#' the real service file into it so its functions' free variables (dw,
#' check_duplicate_job, create_job, list_backup_files, get_backup_metadata,
#' is_valid_backup_filename, serializer_json, logger) resolve to the stubs.
make_service_sandbox <- function() {
  env <- new.env(parent = globalenv())
  env$`%||%` <- function(a, b) if (is.null(a)) b else a

  env$log_error <- function(...) invisible(NULL)
  env$log_info <- function(...) invisible(NULL)
  # Note: `logger::log_*` (`::`-qualified) bypasses this stub and hits the
  # real installed package — acceptable, it just logs to stderr in tests.
  env$logger <- list(
    log_error = function(...) invisible(NULL),
    log_info = function(...) invisible(NULL)
  )

  # Plumber is not loaded in this sandbox (no router), so serializer_json()
  # is undefined; stub it to a no-op like test-endpoint-backup.R does.
  env$serializer_json <- function(...) identity

  env$dw <- list(
    dbname = "sysndd_test",
    host = "127.0.0.1",
    user = "test",
    password = "test",
    port = 3306L
  )

  env$check_duplicate_job <- function(operation, params) {
    list(duplicate = FALSE, existing_job_id = NULL)
  }
  env$create_job <- function(operation, params, timeout_ms, executor_fn) {
    list(job_id = "job-fixture-1234", error = NULL)
  }
  env$list_backup_files <- function(dir) {
    data.frame(
      filename = character(0),
      size_bytes = integer(0),
      created_at = as.POSIXct(character(0)),
      table_count = integer(0),
      stringsAsFactors = FALSE
    )
  }
  env$get_backup_metadata <- function(dir) {
    list(total_count = 0L, total_size_bytes = 0L)
  }
  env$is_valid_backup_filename <- .backup_functions_env$is_valid_backup_filename

  source_api_file("services/backup-endpoint-service.R", local = FALSE, envir = env)
  env
}

# -----------------------------------------------------------------------------
# svc_backup_list: sort/pagination
# -----------------------------------------------------------------------------

test_that("svc_backup_list defaults to legacy page-based pagination", {
  env <- make_service_sandbox()
  res <- make_mock_res()
  result <- env$svc_backup_list(admin_req(), res)

  expect_equal(res$status, 200L)
  expect_equal(result$total, 0L)
  expect_equal(result$page, 1)
  expect_equal(result$page_size, 20)
  expect_equal(result$limit, 20)
  expect_equal(result$offset, 0)
})

test_that("svc_backup_list offset/limit mode takes precedence over page and clamps limit to 500", {
  env <- make_service_sandbox()
  env$list_backup_files <- function(dir) {
    data.frame(
      filename = sprintf("b-%02d.sql.gz", 1:10),
      size_bytes = rep(1024L, 10),
      created_at = as.POSIXct(sprintf("2026-04-%02d", 1:10)),
      table_count = rep(1L, 10),
      stringsAsFactors = FALSE
    )
  }
  env$get_backup_metadata <- function(dir) list(total_count = 10L, total_size_bytes = 10240L)

  res <- make_mock_res()
  result <- env$svc_backup_list(admin_req(), res, page = 1, sort = "newest", limit = 5000, offset = 3)

  expect_equal(res$status, 200L)
  expect_equal(result$limit, 500L) # clamped
  expect_equal(result$offset, 3)
  expect_equal(nrow(result$data), 7L) # 10 rows, offset 3 -> 7 remain
  expect_null(result$links[["next"]]) # nothing left after this page
})

test_that("svc_backup_list paginates and reports a next link when more rows remain", {
  env <- make_service_sandbox()
  env$list_backup_files <- function(dir) {
    data.frame(
      filename = sprintf("b-%02d.sql.gz", 1:10),
      size_bytes = rep(1024L, 10),
      created_at = as.POSIXct(sprintf("2026-04-%02d", 1:10)),
      table_count = rep(1L, 10),
      stringsAsFactors = FALSE
    )
  }
  env$get_backup_metadata <- function(dir) list(total_count = 10L, total_size_bytes = 10240L)

  res <- make_mock_res()
  result <- env$svc_backup_list(admin_req(), res, limit = 4, offset = 0, sort = "oldest")

  expect_equal(nrow(result$data), 4L)
  expect_equal(result$links[["next"]], "?limit=4&offset=4&sort=oldest")
})

test_that("svc_backup_list rejects an invalid sort value with 400", {
  env <- make_service_sandbox()
  res <- make_mock_res()
  result <- env$svc_backup_list(admin_req(), res, sort = "sideways")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "INVALID_SORT_PARAMETER")
})

test_that("svc_backup_list surfaces list_backup_files() failures as 500", {
  env <- make_service_sandbox()
  env$list_backup_files <- function(dir) stop("disk unreadable")

  res <- make_mock_res()
  result <- env$svc_backup_list(admin_req(), res)

  expect_equal(res$status, 500L)
  expect_equal(result$error, "BACKUP_LIST_FAILED")
  expect_match(result$details, "disk unreadable")
})

# -----------------------------------------------------------------------------
# svc_backup_create: duplicate / capacity / happy path
# -----------------------------------------------------------------------------

test_that("svc_backup_create returns 202 with job id and headers on success", {
  env <- make_service_sandbox()
  res <- make_mock_res()
  result <- env$svc_backup_create(admin_req(), res)

  expect_equal(res$status, 202L)
  expect_equal(result$job_id, "job-fixture-1234")
  expect_equal(result$status, "accepted")
  expect_equal(res$headers[["Location"]], "/api/jobs/job-fixture-1234/status")
  expect_equal(res$headers[["Retry-After"]], "5")
})

test_that("svc_backup_create returns 409 when a backup is already running", {
  env <- make_service_sandbox()
  env$check_duplicate_job <- function(operation, params) {
    list(duplicate = TRUE, existing_job_id = "existing-job-xyz")
  }
  res <- make_mock_res()
  result <- env$svc_backup_create(admin_req(), res)

  expect_equal(res$status, 409L)
  expect_equal(result$error, "BACKUP_IN_PROGRESS")
  expect_equal(result$existing_job_id, "existing-job-xyz")
})

test_that("svc_backup_create returns 503 + Retry-After when job capacity is exceeded", {
  env <- make_service_sandbox()
  env$create_job <- function(operation, params, timeout_ms, executor_fn) {
    list(error = "CAPACITY_EXCEEDED", retry_after = 30L, message = "All workers busy")
  }
  res <- make_mock_res()
  result <- env$svc_backup_create(admin_req(), res)

  expect_equal(res$status, 503L)
  expect_equal(result$error, "CAPACITY_EXCEEDED")
  expect_equal(res$headers[["Retry-After"]], "30")
})

# -----------------------------------------------------------------------------
# svc_backup_restore: filename validation / duplicate / capacity / happy path
# -----------------------------------------------------------------------------

test_that("svc_backup_restore returns 400 when filename is missing", {
  env <- make_service_sandbox()
  res <- make_mock_res()
  result <- env$svc_backup_restore(admin_req(body = list()), res)

  expect_equal(res$status, 400L)
  expect_equal(result$error, "MISSING_FILENAME")
})

test_that("svc_backup_restore rejects a path-traversal filename with 400", {
  env <- make_service_sandbox()
  res <- make_mock_res()
  result <- env$svc_backup_restore(admin_req(body = list(filename = "../etc/passwd")), res)

  expect_equal(res$status, 400L)
  expect_equal(result$error, "INVALID_FILENAME")
})

test_that("svc_backup_restore rejects a disallowed extension with 400", {
  env <- make_service_sandbox()
  res <- make_mock_res()
  result <- env$svc_backup_restore(admin_req(body = list(filename = "backup.txt")), res)

  expect_equal(res$status, 400L)
  expect_equal(result$error, "INVALID_FILENAME")
})

test_that("svc_backup_restore returns 404 when the backup file does not exist", {
  env <- make_service_sandbox()
  env$file.exists <- function(path) FALSE
  res <- make_mock_res()
  result <- env$svc_backup_restore(admin_req(body = list(filename = "nope.sql.gz")), res)

  expect_equal(res$status, 404L)
  expect_equal(result$error, "BACKUP_NOT_FOUND")
})

test_that("svc_backup_restore returns 409 when a restore is already running for this file", {
  env <- make_service_sandbox()
  env$file.exists <- function(path) TRUE
  env$check_duplicate_job <- function(operation, params) {
    list(duplicate = TRUE, existing_job_id = "active-restore")
  }
  res <- make_mock_res()
  result <- env$svc_backup_restore(admin_req(body = list(filename = "backup-2026-04-01.sql.gz")), res)

  expect_equal(res$status, 409L)
  expect_equal(result$error, "RESTORE_IN_PROGRESS")
})

test_that("svc_backup_restore returns 503 + Retry-After when job capacity is exceeded", {
  env <- make_service_sandbox()
  env$file.exists <- function(path) TRUE
  env$create_job <- function(operation, params, timeout_ms, executor_fn) {
    list(error = "CAPACITY_EXCEEDED", retry_after = 15L)
  }
  res <- make_mock_res()
  result <- env$svc_backup_restore(admin_req(body = list(filename = "backup-2026-04-01.sql.gz")), res)

  expect_equal(res$status, 503L)
  expect_equal(res$headers[["Retry-After"]], "15")
})

test_that("svc_backup_restore returns 202 with job id on success", {
  env <- make_service_sandbox()
  env$file.exists <- function(path) TRUE
  res <- make_mock_res()
  result <- env$svc_backup_restore(admin_req(body = list(filename = "backup-2026-04-01.sql.gz")), res)

  expect_equal(res$status, 202L)
  expect_equal(result$job_id, "job-fixture-1234")
  expect_equal(result$status, "accepted")
})

# -----------------------------------------------------------------------------
# Credential-free job submission (#535 P1-1)
#
# Backup jobs execute in the durable handlers .async_job_run_backup_create /
# .async_job_run_backup_restore (registered in async_job_handler_registry);
# create_job() IGNORES executor_fn. The submit params must therefore carry NO
# database credential — the worker resolves it from runtime config via
# async_job_worker_db_config(). The restore-ordering / pre-backup-abort safety
# contract is now verified against the real durable handler in
# test-unit-async-job-maintenance-handlers.R.
# -----------------------------------------------------------------------------

test_that("svc_backup_create submits NO DB credential in job params (#535 P1-1)", {
  env <- make_service_sandbox()
  captured <- new.env()
  env$create_job <- function(operation, params, executor_fn = NULL, timeout_ms = NULL) {
    captured$params <- params
    list(job_id = "job-fixture-1234", error = NULL)
  }
  res <- make_mock_res()
  env$svc_backup_create(admin_req(), res)

  expect_false("db_config" %in% names(captured$params))
  expect_false(any(grepl("password", unlist(captured$params), fixed = TRUE)))
  expect_true(all(c("backup_dir", "backup_filename") %in% names(captured$params)))
})

test_that("svc_backup_restore submits NO DB credential in job params (#535 P1-1)", {
  env <- make_service_sandbox()
  env$file.exists <- function(path) TRUE
  captured <- new.env()
  env$create_job <- function(operation, params, executor_fn = NULL, timeout_ms = NULL) {
    captured$params <- params
    list(job_id = "job-fixture-1234", error = NULL)
  }
  res <- make_mock_res()
  env$svc_backup_restore(admin_req(body = list(filename = "backup-2026-04-01.sql.gz")), res)

  expect_false("db_config" %in% names(captured$params))
  expect_false(any(grepl("password", unlist(captured$params), fixed = TRUE)))
  expect_true(all(c("restore_file", "backup_dir") %in% names(captured$params)))
})

# -----------------------------------------------------------------------------
# svc_backup_download: guards, happy path, serializer switching, read failure
# -----------------------------------------------------------------------------

install_download_fixture <- function(env, tmpdir, filename, content_bytes) {
  fake_path <- file.path(tmpdir, filename)
  writeBin(content_bytes, fake_path)
  fake_size <- file.info(fake_path)$size

  env$file.exists <- function(path) endsWith(path, paste0("/", filename))
  env$file.info <- function(path) {
    if (endsWith(path, paste0("/", filename))) data.frame(size = fake_size) else data.frame(size = NA_real_)
  }
  env$file <- function(description, open = "") base::file(fake_path, open = open)
  env$readBin <- function(con, what, n, ...) base::readBin(con, what = what, n = n, ...)
  invisible(fake_path)
}

test_that("svc_backup_download returns raw bytes with a matching Content-Type", {
  skip_if_not_installed("withr")
  tmpdir <- withr::local_tempdir()
  content_bytes <- charToRaw("-- MOCK SQL DUMP --\nSELECT 1;\n")

  env <- make_service_sandbox()
  install_download_fixture(env, tmpdir, "backup-2026-04-01.sql.gz", content_bytes)

  res <- make_mock_res()
  result <- env$svc_backup_download(admin_req(), res, "backup-2026-04-01.sql.gz")

  expect_equal(res$status, 200L)
  expect_true(is.raw(result))
  expect_equal(length(result), length(content_bytes))
  expect_equal(res$headers[["Content-Type"]], "application/gzip")
  expect_equal(res$headers[["Content-Disposition"]], 'attachment; filename="backup-2026-04-01.sql.gz"')
})

test_that("svc_backup_download rejects path traversal and switches the serializer to JSON", {
  env <- make_service_sandbox()
  serializer_switched <- FALSE
  env$serializer_json <- function(...) {
    serializer_switched <<- TRUE
    identity
  }
  res <- make_mock_res()
  result <- env$svc_backup_download(admin_req(), res, "../etc/passwd")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "INVALID_FILENAME")
  expect_true(serializer_switched)
})

test_that("svc_backup_download rejects a disallowed extension with 400", {
  env <- make_service_sandbox()
  res <- make_mock_res()
  result <- env$svc_backup_download(admin_req(), res, "backup.txt")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "INVALID_FILENAME")
})

test_that("svc_backup_download returns 404 and switches the serializer when the file is missing", {
  env <- make_service_sandbox()
  env$file.exists <- function(path) FALSE
  res <- make_mock_res()
  result <- env$svc_backup_download(admin_req(), res, "ghost.sql.gz")

  expect_equal(res$status, 404L)
  expect_equal(result$error, "BACKUP_NOT_FOUND")
})

test_that("svc_backup_download returns 500 FILE_READ_FAILED when reading the file throws", {
  env <- make_service_sandbox()
  env$file.exists <- function(path) TRUE
  env$file.info <- function(path) data.frame(size = 10)
  env$file <- function(description, open = "") stop("permission denied")

  res <- make_mock_res()
  result <- env$svc_backup_download(admin_req(), res, "backup.sql.gz")

  expect_equal(res$status, 500L)
  expect_equal(result$error, "FILE_READ_FAILED")
  expect_match(result$details, "permission denied")
})

# -----------------------------------------------------------------------------
# svc_backup_delete: guards, latest-link refusal, confirmation, happy path,
# filesystem failures
# -----------------------------------------------------------------------------

test_that("svc_backup_delete removes the file and reports its size on success", {
  skip_if_not_installed("withr")
  tmpdir <- withr::local_tempdir()
  filename <- "backup-2026-04-01.sql.gz"
  fake_path <- file.path(tmpdir, filename)
  writeBin(charToRaw("fake"), fake_path)

  env <- make_service_sandbox()
  removed <- FALSE
  env$file.exists <- function(path) endsWith(path, paste0("/", filename))
  env$file.info <- function(path) data.frame(size = 4L)
  env$file.remove <- function(path) {
    removed <<- TRUE
    TRUE
  }

  res <- make_mock_res()
  result <- env$svc_backup_delete(admin_req(body = list(confirm = "DELETE")), res, filename)

  expect_true(removed)
  expect_equal(res$status, 200L)
  expect_true(isTRUE(result$success))
  expect_equal(result$deleted_file, filename)
  expect_equal(result$deleted_size_bytes, 4L)
})

test_that("svc_backup_delete rejects path traversal with 400", {
  env <- make_service_sandbox()
  res <- make_mock_res()
  result <- env$svc_backup_delete(admin_req(body = list(confirm = "DELETE")), res, "../etc/shadow")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "INVALID_FILENAME")
})

test_that("svc_backup_delete rejects a disallowed extension with 400", {
  env <- make_service_sandbox()
  res <- make_mock_res()
  result <- env$svc_backup_delete(admin_req(body = list(confirm = "DELETE")), res, "backup.txt")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "INVALID_FILENAME")
})

test_that("svc_backup_delete refuses to delete latest.* symlinks", {
  env <- make_service_sandbox()
  res <- make_mock_res()
  result <- env$svc_backup_delete(admin_req(body = list(confirm = "DELETE")), res, "latest.sysndd_test.sql.gz")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "CANNOT_DELETE_SYMLINK")
})

test_that("svc_backup_delete requires a typed 'DELETE' confirmation", {
  env <- make_service_sandbox()
  env$file.exists <- function(path) TRUE
  res <- make_mock_res()
  result <- env$svc_backup_delete(admin_req(body = list(confirm = "yes")), res, "backup.sql.gz")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "CONFIRMATION_REQUIRED")
})

test_that("svc_backup_delete rejects a missing confirm field the same as a wrong one", {
  env <- make_service_sandbox()
  env$file.exists <- function(path) TRUE
  res <- make_mock_res()
  result <- env$svc_backup_delete(admin_req(body = list()), res, "backup.sql.gz")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "CONFIRMATION_REQUIRED")
})

test_that("svc_backup_delete returns 404 when the backup file does not exist", {
  env <- make_service_sandbox()
  env$file.exists <- function(path) FALSE
  res <- make_mock_res()
  result <- env$svc_backup_delete(admin_req(body = list(confirm = "DELETE")), res, "ghost.sql.gz")

  expect_equal(res$status, 404L)
  expect_equal(result$error, "BACKUP_NOT_FOUND")
})

test_that("svc_backup_delete returns 500 DELETE_FAILED when file.remove() returns FALSE", {
  env <- make_service_sandbox()
  env$file.exists <- function(path) TRUE
  env$file.info <- function(path) data.frame(size = 4L)
  env$file.remove <- function(path) FALSE

  res <- make_mock_res()
  result <- env$svc_backup_delete(admin_req(body = list(confirm = "DELETE")), res, "backup.sql.gz")

  expect_equal(res$status, 500L)
  expect_equal(result$error, "DELETE_FAILED")
})

test_that("svc_backup_delete returns 500 DELETE_FAILED when file.remove() throws", {
  env <- make_service_sandbox()
  env$file.exists <- function(path) TRUE
  env$file.info <- function(path) data.frame(size = 4L)
  env$file.remove <- function(path) stop("EBUSY: resource busy")

  res <- make_mock_res()
  result <- env$svc_backup_delete(admin_req(body = list(confirm = "DELETE")), res, "backup.sql.gz")

  expect_equal(res$status, 500L)
  expect_equal(result$error, "DELETE_FAILED")
  expect_match(result$details, "EBUSY")
})
