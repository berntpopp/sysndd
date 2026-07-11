# api/services/backup-endpoint-service.R
#
# Service layer for the backup management endpoints (#346 Wave 3 Task 9).
# api/endpoints/backup_endpoints.R stays a thin authorization/delegation
# shell; every svc_backup_* function here is the exact handler body, moved
# verbatim except for `require_role()`, which stays in the shell next to
# its route decorator. Callers MUST run that gate before calling any
# function below.
#
# Sourced by api/bootstrap/load_modules.R after functions/db-helpers.R (dw),
# functions/job-manager.R (create_job, check_duplicate_job),
# functions/job-progress.R (create_progress_reporter), and
# functions/backup-functions.R (list_backup_files, get_backup_metadata,
# is_valid_backup_filename, execute_mysqldump, execute_restore). Not used
# by the async worker: none of these are registered job handlers; the
# `executor_fn` closures below run inside the legacy mirai create_job()
# daemon and source() their own dependencies, unchanged from before.

#' Shared 202/503 response shaping for the /create and /restore job
#' submissions, which differ only in the create_job() operation/params.
.svc_backup_job_response <- function(res, result) {
  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", as.character(result$retry_after))
    return(result)
  }

  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "5")

  list(
    job_id = result$job_id,
    status = "accepted",
    estimated_seconds = 120,
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}

# ---- Backup List: GET /list (paginated listing) ----
# Legacy page-based pagination (`page` + fixed page_size=20) and
# offset-based (`limit`+`offset`, takes precedence when `limit` is given).
# Sorts newest-first by default, oldest-first when sort="oldest".
svc_backup_list <- function(req, res, page = 1, sort = "newest", limit = NULL, offset = NULL) {
  # Coerce via suppressWarnings so non-numeric inputs degrade to NA, then
  # fall back to defaults. Clamp to reasonable bounds to prevent invalid slicing.
  page_size <- 20L
  limit_raw  <- suppressWarnings(as.integer(limit))
  offset_raw <- suppressWarnings(as.integer(offset))

  if (!is.null(limit) && !is.na(limit_raw) && limit_raw >= 1L) {
    limit     <- min(limit_raw, 500L)
    offset    <- if (!is.null(offset) && !is.na(offset_raw) && offset_raw >= 0L) offset_raw else 0L
    page_size <- limit
  } else {
    page <- suppressWarnings(as.integer(page))
    if (is.na(page) || page < 1L) page <- 1L
    limit  <- page_size
    offset <- (page - 1L) * page_size
  }

  # Validate sort parameter
  if (!sort %in% c("newest", "oldest")) {
    res$status <- 400
    return(list(
      error = "INVALID_SORT_PARAMETER",
      message = "Sort parameter must be 'newest' or 'oldest'",
      valid_values = c("newest", "oldest")
    ))
  }

  tryCatch(
    {
      backups <- list_backup_files("/backup")

      if (sort == "oldest") {
        backups <- dplyr::arrange(backups, created_at)
      }

      # Inline pagination (no external helper dependency)
      total <- nrow(backups)
      if (total == 0) {
        data <- backups
      } else {
        start_idx <- offset + 1L
        end_idx   <- min(offset + limit, total)
        data <- if (start_idx > total) backups[0, ] else dplyr::slice(backups, start_idx:end_idx)
      }
      # Preserve active query params (sort) when building links.next so that
      # following the link keeps the caller on the same sort order.
      next_offset <- offset + limit
      next_link   <- if (next_offset < total) {
        paste0("?limit=", limit, "&offset=", next_offset, "&sort=", sort)
      } else {
        NULL
      }

      dir_meta <- get_backup_metadata("/backup")

      # Top-level legacy fields (total/page/page_size) stay for backward
      # compatibility; `links`/`limit`/`offset` are the new pagination contract.
      list(
        data      = data,
        total     = total,
        page      = floor(offset / page_size) + 1L,
        page_size = page_size,
        limit     = limit,
        offset    = offset,
        links     = list("next" = next_link),
        meta      = dir_meta
      )
    },
    error = function(e) {
      logger::log_error("Failed to list backups: {e$message}")
      res$status <- 500
      list(
        error = "BACKUP_LIST_FAILED",
        message = "Failed to retrieve backup list",
        details = e$message
      )
    }
  )
}

# ---- Backup Creation: POST /create ----
# Submits a mirai `backup_create` job via create_job(); 409 when a backup is
# already in progress, 503 when job capacity is exceeded.
svc_backup_create <- function(req, res) {
  dup_check <- check_duplicate_job("backup_create", list())
  if (dup_check$duplicate) {
    res$status <- 409
    return(list(
      error = "BACKUP_IN_PROGRESS",
      message = "A backup operation is already running",
      existing_job_id = dup_check$existing_job_id
    ))
  }

  backup_filename <- sprintf("manual_%s.sql", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"))

  # No DB credential in the job payload (#535 P1-1): the durable handler
  # .async_job_run_backup_create resolves it from runtime config. create_job()
  # ignores executor_fn/timeout_ms; execution is the registered durable handler.
  result <- create_job(
    operation = "backup_create",
    params = list(
      backup_dir = "/backup",
      backup_filename = backup_filename
    ),
    executor_fn = NULL
  )

  .svc_backup_job_response(res, result)
}

# ---- Backup Restore: POST /restore ----
# Validates the filename (path-traversal + extension guard, existence),
# guards against a concurrent restore for the same file, then submits a
# backup_restore job whose executor always takes a pre-restore safety
# backup before running the actual restore (BKUP-05).
svc_backup_restore <- function(req, res) {
  filename <- req$argsBody$filename
  if (is.null(filename) || filename == "") {
    res$status <- 400
    return(list(
      error = "MISSING_FILENAME",
      message = "Backup filename is required in request body"
    ))
  }

  # Path-traversal + extension guard (parity with /download and /delete)
  if (!is_valid_backup_filename(filename)) {
    res$status <- 400
    return(list(
      error = "INVALID_FILENAME",
      message = "Filename contains invalid characters or has an unsupported extension"
    ))
  }

  backup_path <- file.path("/backup", filename)
  if (!file.exists(backup_path)) {
    res$status <- 404
    return(list(
      error = "BACKUP_NOT_FOUND",
      message = sprintf("Backup file '%s' not found", filename)
    ))
  }

  # Check for duplicate restore job
  dup_check <- check_duplicate_job("backup_restore", list(filename = filename))
  if (dup_check$duplicate) {
    res$status <- 409
    return(list(
      error = "RESTORE_IN_PROGRESS",
      message = "A restore operation is already running for this backup",
      existing_job_id = dup_check$existing_job_id
    ))
  }

  # No DB credential in the job payload (#535 P1-1): the durable handler
  # .async_job_run_backup_restore resolves it from runtime config and performs
  # the pre-restore safety backup (BKUP-05). create_job() ignores
  # executor_fn/timeout_ms; execution is the registered durable handler.
  result <- create_job(
    operation = "backup_restore",
    params = list(
      restore_file = backup_path,
      backup_dir = "/backup"
    ),
    executor_fn = NULL
  )

  .svc_backup_job_response(res, result)
}

# ---- Backup Download: GET /download/<filename> ----
# Serves raw bytes with the `octet` serializer on success; error branches
# switch res$serializer to JSON so failures return a structured problem
# body instead of an empty octet stream.
svc_backup_download <- function(req, res, filename) {
  if (!is_valid_backup_filename(filename)) {
    res$status <- 400
    res$serializer <- serializer_json()
    return(list(
      error = "INVALID_FILENAME",
      message = "Filename contains invalid characters or has an unsupported extension"
    ))
  }

  backup_path <- file.path("/backup", filename)
  if (!file.exists(backup_path)) {
    res$status <- 404
    res$serializer <- serializer_json()
    return(list(
      error = "BACKUP_NOT_FOUND",
      message = sprintf("Backup file '%s' not found", filename)
    ))
  }

  file_info <- file.info(backup_path)
  file_size <- file_info$size

  if (grepl("\\.gz$", filename)) {
    content_type <- "application/gzip"
  } else {
    content_type <- "application/sql"
  }

  res$setHeader("Content-Type", content_type)
  res$setHeader("Content-Disposition", sprintf('attachment; filename="%s"', filename))
  res$setHeader("Content-Length", as.character(file_size))

  tryCatch(
    {
      con <- file(backup_path, "rb")
      on.exit(close(con))
      readBin(con, "raw", n = file_size)
    },
    error = function(e) {
      logger::log_error("Failed to read backup file: {e$message}")
      res$status <- 500
      res$serializer <- serializer_json()
      list(
        error = "FILE_READ_FAILED",
        message = "Failed to read backup file",
        details = e$message
      )
    }
  )
}

# ---- Backup Delete: DELETE /delete/<filename> ----
# Requires a typed confirm: "DELETE" body field, refuses to delete
# `latest.*` convenience symlinks, and validates the filename with the same
# path-traversal + extension guard as /download and /restore.
svc_backup_delete <- function(req, res, filename) {
  if (!is_valid_backup_filename(filename)) {
    res$status <- 400
    res$serializer <- serializer_json()
    return(list(
      error = "INVALID_FILENAME",
      message = "Filename contains invalid characters or has an unsupported extension"
    ))
  }

  # Prevent deletion of symlinks (like latest.*.sql.gz)
  if (grepl("^latest\\.", filename)) {
    res$status <- 400
    return(list(
      error = "CANNOT_DELETE_SYMLINK",
      message = "Cannot delete 'latest' symlink files"
    ))
  }

  # Extract and validate confirmation from request body
  confirm <- req$argsBody$confirm
  if (is.null(confirm) || confirm != "DELETE") {
    res$status <- 400
    return(list(
      error = "CONFIRMATION_REQUIRED",
      message = "Must provide confirm: 'DELETE' in request body to delete backup"
    ))
  }

  backup_path <- file.path("/backup", filename)
  if (!file.exists(backup_path)) {
    res$status <- 404
    return(list(
      error = "BACKUP_NOT_FOUND",
      message = sprintf("Backup file '%s' not found", filename)
    ))
  }

  # Get file info before deletion for response
  file_info <- file.info(backup_path)
  file_size <- file_info$size

  tryCatch(
    {
      success <- file.remove(backup_path)
      if (!success) {
        res$status <- 500
        return(list(
          error = "DELETE_FAILED",
          message = "Failed to delete backup file"
        ))
      }

      logger::log_info("Backup file deleted: {filename} ({file_size} bytes)")

      list(
        success = TRUE,
        message = sprintf("Backup file '%s' deleted successfully", filename),
        deleted_file = filename,
        deleted_size_bytes = file_size
      )
    },
    error = function(e) {
      logger::log_error("Failed to delete backup file: {e$message}")
      res$status <- 500
      list(
        error = "DELETE_FAILED",
        message = "Failed to delete backup file",
        details = e$message
      )
    }
  )
}
