# tests/testthat/test-endpoint-backup.R
# Endpoint tests for backup management handlers (admin-only).
#
# Scope (Phase C unit C9, exit criterion #5 locked):
#   Per HTTP method per route in api/endpoints/backup_endpoints.R, at
#   minimum a happy-path `test_that()` block. Where applicable, we also
#   add validation and permission blocks (destructive writes + privileged-
#   only endpoints justify both). The 5 routes covered are:
#     - GET    /list
#     - POST   /create
#     - POST   /restore
#     - GET    /download/<filename>
#     - DELETE /delete/<filename>
#
# Mock filesystem strategy:
#   backup_endpoints.R hard-codes "/backup" as the backup directory.
#   We do NOT touch that path. Instead, each test stubs the downstream
#   helpers the handler calls — `list_backup_files`, `get_backup_metadata`,
#   `check_duplicate_job`, `create_job`, and base-R `file.exists` /
#   `file.info` / `file.remove` / `file` / `readBin` — with closures that
#   read from a per-test `withr::local_tempdir()` or return canned data.
#   This keeps the tests hermetic and cross-platform without requiring a
#   real /backup mount or a dittodb cassette.
#
# Handler extraction:
#   We parse the endpoint file and eval the top-level function literal
#   that follows each decorator into a sandbox environment carrying the
#   stubs. This mirrors the approach in test-endpoint-auth.R and avoids
#   depending on plumber's internal PlumberEndpoint layout.

library(testthat)

source("backup-endpoint-fixtures.R", local = TRUE)

# -----------------------------------------------------------------------------
# Route-surface assertions (structural)
# -----------------------------------------------------------------------------

test_that("backup_endpoints.R exposes all 5 documented routes", {
  src <- readLines(backup_file_path(), warn = FALSE)

  decorators <- c(
    "^#\\*\\s+@get\\s+/list\\s*$",
    "^#\\*\\s+@post\\s+/create\\s*$",
    "^#\\*\\s+@post\\s+/restore\\s*$",
    "^#\\*\\s+@get\\s+/download/<filename>\\s*$",
    "^#\\*\\s+@delete\\s+/delete/<filename>\\s*$"
  )
  for (pat in decorators) {
    matches <- grep(pat, src, value = TRUE)
    expect_true(
      length(matches) >= 1L,
      info = paste0("Missing decorator: ", pat)
    )
  }
})


# -----------------------------------------------------------------------------
# GET /list
# -----------------------------------------------------------------------------

extract_get_list <- function(envir) {
  extract_plumber_handler(
    backup_file_path(),
    decorator_regex = "^#\\*\\s+@get\\s+/list\\s*$",
    envir = envir
  )
}

test_that("GET /list happy path returns paginated empty backup list", {
  env <- make_backup_sandbox()
  handler <- extract_get_list(env)
  expect_true(is.function(handler))

  req <- admin_req()
  res <- make_mock_res()
  result <- handler(req = req, res = res, page = 1, sort = "newest")

  expect_equal(res$status, 200L)
  expect_true(is.list(result))
  expect_true("data" %in% names(result))
  expect_equal(result$total, 0L)
  expect_equal(result$page, 1)
  expect_equal(result$page_size, 20)
})

test_that("GET /list happy path with non-empty fixture paginates correctly", {
  env <- make_backup_sandbox()
  env$list_backup_files <- function(dir) {
    data.frame(
      filename = c("b-01.sql.gz", "b-02.sql.gz", "b-03.sql.gz"),
      size_bytes = c(1024L, 2048L, 4096L),
      created_at = as.POSIXct(c("2026-04-01", "2026-04-02", "2026-04-03")),
      table_count = c(10L, 11L, 12L),
      stringsAsFactors = FALSE
    )
  }
  env$get_backup_metadata <- function(dir) {
    list(total_count = 3L, total_size_bytes = 7168L)
  }
  handler <- extract_get_list(env)

  req <- admin_req()
  res <- make_mock_res()
  result <- handler(req = req, res = res, page = 1, sort = "newest")

  expect_equal(res$status, 200L)
  expect_equal(result$total, 3L)
  expect_equal(nrow(result$data), 3L)
  expect_equal(result$meta$total_count, 3L)
})

test_that("GET /list rejects invalid sort parameter with 400", {
  env <- make_backup_sandbox()
  handler <- extract_get_list(env)

  req <- admin_req()
  res <- make_mock_res()
  result <- handler(req = req, res = res, page = 1, sort = "sideways")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "INVALID_SORT_PARAMETER")
})

test_that("GET /list rejects non-admin with 403", {
  env <- make_backup_sandbox()
  handler <- extract_get_list(env)

  req <- viewer_req()
  res <- make_mock_res()
  expect_error(handler(req = req, res = res, page = 1, sort = "newest"))
  expect_equal(res$status, 403L)
})


# -----------------------------------------------------------------------------
# POST /create
# -----------------------------------------------------------------------------

extract_post_create <- function(envir) {
  extract_plumber_handler(
    backup_file_path(),
    decorator_regex = "^#\\*\\s+@post\\s+/create\\s*$",
    envir = envir
  )
}

test_that("POST /create happy path returns 202 with job id", {
  env <- make_backup_sandbox()
  handler <- extract_post_create(env)
  expect_true(is.function(handler))

  req <- admin_req()
  res <- make_mock_res()
  result <- handler(req = req, res = res)

  expect_equal(res$status, 202L)
  expect_equal(result$job_id, "job-fixture-1234")
  expect_equal(result$status, "accepted")
  expect_true("estimated_seconds" %in% names(result))
  expect_true(!is.null(res$headers[["Location"]]))
})

test_that("POST /create returns 409 when backup already running", {
  env <- make_backup_sandbox()
  env$check_duplicate_job <- function(operation, params) {
    list(duplicate = TRUE, existing_job_id = "existing-job-xyz")
  }
  handler <- extract_post_create(env)

  req <- admin_req()
  res <- make_mock_res()
  result <- handler(req = req, res = res)

  expect_equal(res$status, 409L)
  expect_equal(result$error, "BACKUP_IN_PROGRESS")
  expect_equal(result$existing_job_id, "existing-job-xyz")
})

test_that("POST /create returns 503 when job capacity exceeded", {
  env <- make_backup_sandbox()
  env$create_job <- function(operation, params) {
    list(
      error = "CAPACITY_EXCEEDED",
      retry_after = 30L,
      message = "All workers busy"
    )
  }
  handler <- extract_post_create(env)

  req <- admin_req()
  res <- make_mock_res()
  result <- handler(req = req, res = res)

  expect_equal(res$status, 503L)
  expect_equal(result$error, "CAPACITY_EXCEEDED")
  expect_equal(res$headers[["Retry-After"]], "30")
})

test_that("POST /create rejects non-admin with 403", {
  env <- make_backup_sandbox()
  handler <- extract_post_create(env)

  req <- viewer_req()
  res <- make_mock_res()
  expect_error(handler(req = req, res = res))
  expect_equal(res$status, 403L)
})


# -----------------------------------------------------------------------------
# POST /restore
# -----------------------------------------------------------------------------

extract_post_restore <- function(envir) {
  extract_plumber_handler(
    backup_file_path(),
    decorator_regex = "^#\\*\\s+@post\\s+/restore\\s*$",
    envir = envir
  )
}

test_that("POST /restore happy path returns 202 with job id", {
  env <- make_backup_sandbox()
  # Stub file.exists to report restore file as present (in mock /backup path).
  env$file.exists <- function(path) TRUE

  handler <- extract_post_restore(env)
  expect_true(is.function(handler))

  req <- admin_req(body = list(filename = "backup-2026-04-01.sql.gz"))
  res <- make_mock_res()
  result <- handler(req = req, res = res)

  expect_equal(res$status, 202L)
  expect_equal(result$job_id, "job-fixture-1234")
  expect_equal(result$status, "accepted")
})

test_that("POST /restore returns 400 when filename missing", {
  env <- make_backup_sandbox()
  handler <- extract_post_restore(env)

  req <- admin_req(body = list())
  res <- make_mock_res()
  result <- handler(req = req, res = res)

  expect_equal(res$status, 400L)
  expect_equal(result$error, "MISSING_FILENAME")
})

test_that("POST /restore returns 404 when backup file does not exist", {
  env <- make_backup_sandbox()
  env$file.exists <- function(path) FALSE

  handler <- extract_post_restore(env)

  req <- admin_req(body = list(filename = "nope.sql.gz"))
  res <- make_mock_res()
  result <- handler(req = req, res = res)

  expect_equal(res$status, 404L)
  expect_equal(result$error, "BACKUP_NOT_FOUND")
})

test_that("POST /restore returns 409 when restore already running", {
  env <- make_backup_sandbox()
  env$file.exists <- function(path) TRUE
  env$check_duplicate_job <- function(operation, params) {
    list(duplicate = TRUE, existing_job_id = "active-restore")
  }
  handler <- extract_post_restore(env)

  req <- admin_req(body = list(filename = "backup-2026-04-01.sql.gz"))
  res <- make_mock_res()
  result <- handler(req = req, res = res)

  expect_equal(res$status, 409L)
  expect_equal(result$error, "RESTORE_IN_PROGRESS")
})

test_that("POST /restore rejects non-admin with 403", {
  env <- make_backup_sandbox()
  handler <- extract_post_restore(env)

  req <- viewer_req(body = list(filename = "backup.sql.gz"))
  res <- make_mock_res()
  expect_error(handler(req = req, res = res))
  expect_equal(res$status, 403L)
})


# -----------------------------------------------------------------------------
# GET /download/<filename>
# -----------------------------------------------------------------------------

extract_get_download <- function(envir) {
  extract_plumber_handler(
    backup_file_path(),
    decorator_regex = "^#\\*\\s+@get\\s+/download/<filename>\\s*$",
    envir = envir
  )
}

test_that("GET /download/<filename> happy path returns raw bytes", {
  skip_if_not_installed("withr")
  tmpdir <- withr::local_tempdir()
  content_bytes <- charToRaw("-- MOCK SQL DUMP --\nSELECT 1;\n")

  env <- make_backup_sandbox()
  install_download_fixture(env, tmpdir, "backup-2026-04-01.sql", content_bytes)

  handler <- extract_get_download(env)
  expect_true(is.function(handler))

  req <- admin_req()
  res <- make_mock_res()
  result <- handler(req = req, res = res, filename = "backup-2026-04-01.sql")

  expect_equal(res$status, 200L)
  expect_true(is.raw(result))
  expect_equal(length(result), length(content_bytes))
  expect_equal(res$headers[["Content-Type"]], "application/sql")
})

test_that("GET /download/<filename> rejects path traversal with 400", {
  env <- make_backup_sandbox()
  handler <- extract_get_download(env)

  req <- admin_req()
  res <- make_mock_res()
  result <- handler(req = req, res = res, filename = "../etc/passwd")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "INVALID_FILENAME")
})

test_that("GET /download/<filename> rejects invalid extension with 400", {
  env <- make_backup_sandbox()
  handler <- extract_get_download(env)

  req <- admin_req()
  res <- make_mock_res()
  result <- handler(req = req, res = res, filename = "backup.txt")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "INVALID_FILENAME")
})

test_that("GET /download/<filename> returns 404 when file missing", {
  env <- make_backup_sandbox()
  env$file.exists <- function(path) FALSE

  handler <- extract_get_download(env)

  req <- admin_req()
  res <- make_mock_res()
  result <- handler(req = req, res = res, filename = "ghost.sql.gz")

  expect_equal(res$status, 404L)
  expect_equal(result$error, "BACKUP_NOT_FOUND")
})

test_that("GET /download/<filename> rejects non-admin with 403", {
  env <- make_backup_sandbox()
  handler <- extract_get_download(env)

  req <- viewer_req()
  res <- make_mock_res()
  expect_error(handler(req = req, res = res, filename = "backup.sql.gz"))
  expect_equal(res$status, 403L)
})


# -----------------------------------------------------------------------------
# DELETE /delete/<filename>
# -----------------------------------------------------------------------------

extract_delete_delete <- function(envir) {
  extract_plumber_handler(
    backup_file_path(),
    decorator_regex = "^#\\*\\s+@delete\\s+/delete/<filename>\\s*$",
    envir = envir
  )
}

test_that("DELETE /delete/<filename> happy path removes file via mock", {
  skip_if_not_installed("withr")
  tmpdir <- withr::local_tempdir()
  filename <- "backup-2026-04-01.sql.gz"
  fake_path <- file.path(tmpdir, filename)
  writeBin(charToRaw("fake"), fake_path)

  env <- make_backup_sandbox()
  deleted_flag <- new.env()
  deleted_flag$called <- FALSE
  env$file.exists <- function(path) endsWith(path, paste0("/", filename))
  env$file.info <- function(path) data.frame(size = 4L)
  env$file.remove <- function(path) {
    deleted_flag$called <- TRUE
    TRUE
  }

  handler <- extract_delete_delete(env)
  expect_true(is.function(handler))

  req <- admin_req(body = list(confirm = "DELETE"))
  res <- make_mock_res()
  result <- handler(req = req, res = res, filename = filename)

  expect_true(deleted_flag$called)
  expect_equal(res$status, 200L)
  expect_true(isTRUE(result$success))
  expect_equal(result$deleted_file, filename)
})

test_that("DELETE /delete/<filename> rejects path traversal with 400", {
  env <- make_backup_sandbox()
  handler <- extract_delete_delete(env)

  req <- admin_req(body = list(confirm = "DELETE"))
  res <- make_mock_res()
  result <- handler(req = req, res = res, filename = "../etc/shadow")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "INVALID_FILENAME")
})

test_that("DELETE /delete/<filename> rejects invalid extension with 400", {
  env <- make_backup_sandbox()
  handler <- extract_delete_delete(env)

  req <- admin_req(body = list(confirm = "DELETE"))
  res <- make_mock_res()
  result <- handler(req = req, res = res, filename = "backup.txt")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "INVALID_FILENAME")
})

test_that("DELETE /delete/<filename> refuses to delete latest.* symlinks", {
  env <- make_backup_sandbox()
  handler <- extract_delete_delete(env)

  req <- admin_req(body = list(confirm = "DELETE"))
  res <- make_mock_res()
  result <- handler(req = req, res = res, filename = "latest.sql.gz")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "CANNOT_DELETE_SYMLINK")
})

test_that("DELETE /delete/<filename> requires DELETE confirmation with 400", {
  env <- make_backup_sandbox()
  env$file.exists <- function(path) TRUE
  handler <- extract_delete_delete(env)

  req <- admin_req(body = list(confirm = "yes"))
  res <- make_mock_res()
  result <- handler(req = req, res = res, filename = "backup.sql.gz")

  expect_equal(res$status, 400L)
  expect_equal(result$error, "CONFIRMATION_REQUIRED")
})

test_that("DELETE /delete/<filename> returns 404 when file missing", {
  env <- make_backup_sandbox()
  env$file.exists <- function(path) FALSE
  handler <- extract_delete_delete(env)

  req <- admin_req(body = list(confirm = "DELETE"))
  res <- make_mock_res()
  result <- handler(req = req, res = res, filename = "ghost.sql.gz")

  expect_equal(res$status, 404L)
  expect_equal(result$error, "BACKUP_NOT_FOUND")
})

test_that("DELETE /delete/<filename> rejects non-admin with 403", {
  env <- make_backup_sandbox()
  handler <- extract_delete_delete(env)

  req <- viewer_req(body = list(confirm = "DELETE"))
  res <- make_mock_res()
  expect_error(handler(req = req, res = res, filename = "backup.sql.gz"))
  expect_equal(res$status, 403L)
})
