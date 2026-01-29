# api/endpoints/backup_endpoints.R
#
# Backup management API endpoints.
# Provides listing, creation, and restore of database backups.
#
# Note: All required modules (db-helpers.R, middleware.R, backup-functions.R)
# are sourced by start_sysndd_api.R before endpoints are loaded.
# Functions are available in the global environment.

## -------------------------------------------------------------------##
## Backup List Endpoint
## -------------------------------------------------------------------##

#* List available backups
#*
#* Returns paginated list of backup files with metadata including
#* filename, size, creation date, and table count (if available).
#* Results are sorted newest-first by default, or oldest-first if
#* ?sort=oldest parameter is provided.
#*
#* # `Authorization`
#* Requires Administrator role.
#*
#* # `Parameters`
#* - page: Integer - Page number (default: 1)
#* - sort: String - Sort order: "newest" (default) or "oldest"
#*
#* # `Response`
#* Paginated response with:
#* - data: Array of backup objects (filename, size_bytes, created_at, table_count)
#* - total: Total number of backups
#* - page: Current page number
#* - page_size: Number of items per page (20)
#* - meta: Directory metadata (total_count, total_size_bytes)
#*
#* @tag backup
#* @serializer json list(na="string")
#*
#* @get /list
function(req, res, page = 1, sort = "newest") {
  # Require Administrator role
  require_role(req, res, "Administrator")

  # Validate and coerce page parameter
  page <- suppressWarnings(as.integer(page))
  if (is.na(page) || page < 1) {
    page <- 1
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

  # Page size per CONTEXT.md
  page_size <- 20

  # Get backup list from business logic
  tryCatch(
    {
      backups <- list_backup_files("/backup")

      # Apply sort order
      if (sort == "oldest") {
        backups <- dplyr::arrange(backups, created_at)
      }
      # else keep default: newest first (already sorted by list_backup_files)

      # Calculate pagination
      total <- nrow(backups)
      offset <- (page - 1) * page_size

      # Slice data for current page
      if (total == 0) {
        data <- backups # Empty tibble with correct structure
      } else {
        start_idx <- offset + 1
        end_idx <- min(offset + page_size, total)

        if (start_idx > total) {
          # Page beyond available data - return empty
          data <- backups[0, ]
        } else {
          data <- dplyr::slice(backups, start_idx:end_idx)
        }
      }

      # Get directory metadata
      meta <- get_backup_metadata("/backup")

      # Return paginated response
      list(
        data = data,
        total = total,
        page = page,
        page_size = page_size,
        meta = meta
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


## -------------------------------------------------------------------##
## Backup Creation Endpoint
## -------------------------------------------------------------------##

#* Trigger manual backup creation
#*
#* Creates a new database backup asynchronously using the job manager.
#* Returns job ID for status polling. Only one backup operation can run
#* at a time; concurrent requests return 409 Conflict.
#*
#* # `Authorization`
#* Requires Administrator role.
#*
#* # `Response`
#* - 202 Accepted: Job created successfully
#*   - job_id: UUID for status polling
#*   - status: "accepted"
#*   - estimated_seconds: Estimated completion time
#*   - status_url: URL to poll job status
#* - 409 Conflict: Backup already in progress
#* - 503 Service Unavailable: Job capacity exceeded
#*
#* @tag backup
#* @serializer json list(na="string")
#*
#* @post /create
function(req, res) {
  # Require Administrator role
  require_role(req, res, "Administrator")

  # Check for duplicate job
  dup_check <- check_duplicate_job("backup_create", list())
  if (dup_check$duplicate) {
    res$status <- 409
    return(list(
      error = "BACKUP_IN_PROGRESS",
      message = "A backup operation is already running",
      existing_job_id = dup_check$existing_job_id
    ))
  }

  # Database config for daemon
  db_config <- list(
    dbname = dw$dbname,
    host = dw$host,
    user = dw$user,
    password = dw$password,
    port = dw$port
  )

  # Generate backup filename with manual prefix and timestamp
  backup_filename <- sprintf("manual_%s.sql", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"))

  result <- create_job(
    operation = "backup_create",
    params = list(
      db_config = db_config,
      backup_dir = "/backup",
      backup_filename = backup_filename
    ),
    timeout_ms = 600000,  # 10 minutes per CONTEXT.md
    executor_fn = function(params) {
      # Source backup functions in daemon
      source("/app/functions/backup-functions.R", local = FALSE)

      output_path <- file.path(params$backup_dir, params$backup_filename)
      result <- execute_mysqldump(params$db_config, output_path)

      if (!result$success) {
        stop(paste("Backup failed:", result$error))
      }

      list(
        status = "completed",
        filename = params$backup_filename,
        size_bytes = file.info(output_path)$size
      )
    }
  )

  # Handle capacity exceeded
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


## -------------------------------------------------------------------##
## Backup Restore Endpoint
## -------------------------------------------------------------------##

#* Restore database from backup
#*
#* Triggers async restore operation. Automatically creates a pre-restore
#* safety backup before restoring. If pre-restore backup fails, the
#* restore operation is aborted. Returns job ID for status polling.
#*
#* # `Authorization`
#* Requires Administrator role.
#*
#* # `Request Body`
#* JSON with:
#* - filename: String - Name of backup file to restore (e.g., "backup-2024-01-15.sql.gz")
#*
#* # `Response`
#* - 202 Accepted: Job created successfully
#*   - job_id: UUID for status polling
#*   - status: "accepted"
#*   - estimated_seconds: Estimated completion time
#*   - status_url: URL to poll job status
#* - 400 Bad Request: Missing or invalid filename
#* - 404 Not Found: Backup file does not exist
#* - 409 Conflict: Backup/restore already in progress
#* - 503 Service Unavailable: Job capacity exceeded or pre-restore backup failed
#*
#* @tag backup
#* @serializer json list(na="string")
#*
#* @post /restore
function(req, res) {
  # Require Administrator role
  require_role(req, res, "Administrator")

  # Extract and validate filename from request body
  filename <- req$argsBody$filename
  if (is.null(filename) || filename == "") {
    res$status <- 400
    return(list(
      error = "MISSING_FILENAME",
      message = "Backup filename is required in request body"
    ))
  }

  # Validate file exists
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

  # Database config for daemon
  db_config <- list(
    dbname = dw$dbname,
    host = dw$host,
    user = dw$user,
    password = dw$password,
    port = dw$port
  )

  result <- create_job(
    operation = "backup_restore",
    params = list(
      db_config = db_config,
      restore_file = backup_path,
      backup_dir = "/backup"
    ),
    timeout_ms = 600000,  # 10 minutes per CONTEXT.md
    executor_fn = function(params) {
      # Source backup functions in daemon
      source("/app/functions/backup-functions.R", local = FALSE)

      # Step 1: Create pre-restore safety backup (BKUP-05)
      pre_restore_filename <- sprintf(
        "pre-restore_%s.sql",
        format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
      )
      pre_restore_path <- file.path(params$backup_dir, pre_restore_filename)

      pre_result <- execute_mysqldump(params$db_config, pre_restore_path)

      if (!pre_result$success) {
        stop(paste(
          "Pre-restore backup failed - cannot proceed with restore:",
          pre_result$error
        ))
      }

      # Step 2: Execute restore from specified file
      restore_result <- execute_restore(params$db_config, params$restore_file)

      if (!restore_result$success) {
        stop(paste(
          "Restore failed:",
          restore_result$error,
          "- pre-restore backup available at:",
          pre_restore_filename
        ))
      }

      list(
        status = "completed",
        pre_restore_backup = pre_restore_filename,
        restored_from = basename(params$restore_file)
      )
    }
  )

  # Handle capacity exceeded
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
