#' Backup Functions Module
#'
#' Provides backup file listing and metadata functions.
#' Uses fs package for file system operations.
#'
#' @name backup-functions
#' @author SysNDD Team

## -------------------------------------------------------------------##
# Core Functions
## -------------------------------------------------------------------##

#' List backup files with metadata
#'
#' Returns a tibble of backup files (.sql, .sql.gz) from the backup directory
#' with filename, size, creation date, and placeholder for table count.
#'
#' @param backup_dir Character path to backup directory (default: "/backup")
#'
#' @return Tibble with columns:
#'   - filename: Character - base filename only (not full path)
#'   - size_bytes: Numeric - file size in bytes
#'   - created_at: Character - ISO 8601 UTC timestamp
#'   - table_count: Integer - NA_integer_ (computed separately if needed)
#'
#' @details
#' Uses fs::dir_info() to read file metadata efficiently.
#' Returns empty tibble (same structure) if no backup files found.
#' Results are sorted by created_at descending (newest first).
#'
#' @examples
#' \dontrun{
#' backups <- list_backup_files("/backup")
#' }
#'
#' @export
list_backup_files <- function(backup_dir = "/backup") {
  # Check if directory exists
  if (!fs::dir_exists(backup_dir)) {
    return(tibble::tibble(
      filename = character(0),
      size_bytes = numeric(0),
      created_at = character(0),
      table_count = integer(0)
    ))
  }

  # Get file info for SQL backups (both .sql and .sql.gz)
  files_info <- fs::dir_info(
    backup_dir,
    regexp = "\\.sql(\\.gz)?$"
  )

  # Filter out symlinks (e.g., latest.*.sql.gz convenience links)
  files_info <- files_info[files_info$type != "symlink", ]

  # Handle empty directory
  if (nrow(files_info) == 0) {
    return(tibble::tibble(
      filename = character(0),
      size_bytes = numeric(0),
      created_at = character(0),
      table_count = integer(0)
    ))
  }

  # Transform to API response format
  result <- files_info %>%
    dplyr::select(
      path,
      size,
      modification_time
    ) %>%
    dplyr::mutate(
      filename = basename(path),
      size_bytes = as.numeric(size),
      created_at = format(modification_time, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      table_count = NA_integer_
    ) %>%
    dplyr::select(filename, size_bytes, created_at, table_count) %>%
    dplyr::arrange(dplyr::desc(created_at))

  return(result)
}


#' Get backup directory metadata
#'
#' Returns summary statistics for the backup directory including total
#' backup count and cumulative size in bytes.
#'
#' @param backup_dir Character path to backup directory (default: "/backup")
#'
#' @return List with:
#'   - total_count: Integer - number of backup files
#'   - total_size_bytes: Numeric - cumulative size of all backups
#'
#' @details
#' Used for meta field in paginated API responses.
#' Returns count=0, size=0 if directory doesn't exist or is empty.
#'
#' @examples
#' \dontrun{
#' meta <- get_backup_metadata("/backup")
#' # Returns: list(total_count = 42, total_size_bytes = 1048576000)
#' }
#'
#' @export
get_backup_metadata <- function(backup_dir = "/backup") {
  # Check if directory exists
  if (!fs::dir_exists(backup_dir)) {
    return(list(
      total_count = 0L,
      total_size_bytes = 0
    ))
  }

  # Get file info
  files_info <- fs::dir_info(
    backup_dir,
    regexp = "\\.sql(\\.gz)?$"
  )

  # Filter out symlinks (e.g., latest.*.sql.gz convenience links)
  files_info <- files_info[files_info$type != "symlink", ]

  # Handle empty directory
  if (nrow(files_info) == 0) {
    return(list(
      total_count = 0L,
      total_size_bytes = 0
    ))
  }

  # Compute totals
  list(
    total_count = as.integer(nrow(files_info)),
    total_size_bytes = sum(as.numeric(files_info$size))
  )
}


#' Execute mysqldump to create database backup
#'
#' Runs mysqldump binary via system2() to create a SQL dump file.
#' Uses --single-transaction for consistent backup without table locks.
#' Optionally compresses output with gzip and creates a "latest" symlink.
#'
#' @param db_config List with dbname, host, user, password, port
#' @param output_file Character path where backup will be written
#' @param progress_fn Optional progress reporter function created by create_progress_reporter()
#' @param compress Logical - whether to gzip the output file (default: TRUE)
#' @param create_latest_link Logical - whether to create/update latest symlink (default: TRUE)
#'
#' @return List with:
#'   - success: Logical - TRUE if backup succeeded
#'   - file: Character path to backup file (if success=TRUE)
#'   - size_bytes: Numeric file size (if success=TRUE)
#'   - compressed: Logical - whether file was compressed
#'   - error: Character error message (if success=FALSE)
#'
#' @details
#' Uses mysqldump flags:
#' - --single-transaction: Consistent backup for InnoDB
#' - --routines: Include stored procedures and functions
#' - --triggers: Include triggers
#' - --quick: Retrieve rows one at a time (memory efficient)
#'
#' Progress steps reported (if progress_fn provided):
#' - "connecting": Validating database connection
#' - "dumping": Running mysqldump
#' - "compressing": Compressing with gzip (if enabled)
#' - "verifying": Verifying backup file integrity
#' - "linking": Creating latest symlink (if enabled)
#'
#' @examples
#' \dontrun{
#' db_config <- list(
#'   dbname = "sysndd",
#'   host = "mysql",
#'   user = "root",
#'   password = "secret",
#'   port = 3306
#' )
#' result <- execute_mysqldump(db_config, "/backup/manual.sql")
#' }
#'
#' @export
execute_mysqldump <- function(db_config, output_file, progress_fn = NULL,
                               compress = TRUE, create_latest_link = TRUE) {
  # Helper to report progress (no-op if progress_fn is NULL)
  report <- function(step, message, current = NULL, total = NULL) {
    if (!is.null(progress_fn)) {
      progress_fn(step, message, current, total)
    }
  }

  total_steps <- 3 + as.integer(compress) + as.integer(create_latest_link)
  current_step <- 0

  # Step 1: Report connection/preparation

  current_step <- current_step + 1
  report("connecting", "Preparing database connection...", current_step, total_steps)

  # Build arguments safely (no shell interpolation)
  args <- c(
    "-h", db_config$host,
    "-P", as.character(db_config$port),
    "-u", db_config$user,
    paste0("-p", db_config$password),
    "--single-transaction",
    "--routines",
    "--triggers",
    "--quick",
    db_config$dbname
  )

  # Step 2: Execute mysqldump
  current_step <- current_step + 1

  report("dumping", sprintf("Running mysqldump for database '%s'...", db_config$dbname),
         current_step, total_steps)


  # Note: On Unix, system2 with stderr=TRUE forces stdout=TRUE internally,
  # ignoring stdout file paths. We must capture output as character vector
  # and write to file manually.
  # See: https://stat.ethz.ch/R-manual/R-devel/library/base/html/system2.html
  stderr_file <- tempfile(pattern = "mysqldump_stderr_", fileext = ".txt")
  on.exit(unlink(stderr_file), add = TRUE)

  result <- system2(
    "mysqldump",
    args = args,
    stdout = TRUE,  # Capture stdout as character vector
    stderr = stderr_file  # Redirect stderr to temp file
  )

  # system2 returns character vector when stdout=TRUE, status as attribute
  status <- attr(result, "status") %||% 0

  # Check for errors via exit status
  if (status != 0) {
    stderr_content <- if (file.exists(stderr_file)) {
      paste(readLines(stderr_file, warn = FALSE), collapse = "\n")
    } else {
      "Unknown error"
    }
    return(list(
      success = FALSE,
      error = sprintf("mysqldump failed (exit %d): %s", status, stderr_content)
    ))
  }

  # Write captured output to file
  # result is a character vector with one element per line
  if (length(result) == 0) {
    return(list(
      success = FALSE,
      error = "mysqldump completed but produced no output"
    ))
  }

  tryCatch({
    writeLines(result, output_file)
  }, error = function(e) {
    return(list(
      success = FALSE,
      error = sprintf("Failed to write backup file: %s", e$message)
    ))
  })

  # Check if dump file was created and has content
  if (!file.exists(output_file)) {
    return(list(
      success = FALSE,
      error = "mysqldump completed but output file was not created"
    ))
  }

  dump_size <- file.info(output_file)$size
  if (is.na(dump_size) || dump_size == 0) {
    return(list(
      success = FALSE,
      error = "mysqldump completed but output file is empty"
    ))
  }

  final_file <- output_file
  compressed <- FALSE

  # Step 3 (optional): Compress with gzip
  if (compress) {
    current_step <- current_step + 1
    report("compressing", sprintf("Compressing backup (%.1f MB)...", dump_size / 1024 / 1024),
           current_step, total_steps)

    gzip_result <- system2("gzip", args = c("-f", output_file), stderr = TRUE)
    gzip_status <- attr(gzip_result, "status") %||% 0

    if (gzip_status != 0) {
      # Compression failed but dump succeeded - continue with uncompressed
      message(sprintf("[backup] gzip failed: %s - continuing with uncompressed file",
                      paste(gzip_result, collapse = "\n")))
    } else {
      final_file <- paste0(output_file, ".gz")
      compressed <- TRUE
    }
  }

  # Step 4: Verify backup file
  current_step <- current_step + 1
  report("verifying", "Verifying backup file integrity...", current_step, total_steps)

  if (!file.exists(final_file)) {
    return(list(
      success = FALSE,
      error = sprintf("Backup file not found after processing: %s", final_file)
    ))
  }

  final_size <- file.info(final_file)$size
  if (is.na(final_size) || final_size == 0) {
    return(list(
      success = FALSE,
      error = "Backup file is empty after processing"
    ))
  }

  # Step 5 (optional): Create/update latest symlink
  if (create_latest_link) {
    current_step <- current_step + 1
    report("linking", "Updating 'latest' symlink...", current_step, total_steps)

    backup_dir <- dirname(final_file)
    latest_ext <- if (compressed) ".sql.gz" else ".sql"
    latest_link <- file.path(backup_dir, paste0("latest.", db_config$dbname, latest_ext))

    # Remove existing symlink if present
    if (file.exists(latest_link)) {
      tryCatch(file.remove(latest_link), error = function(e) NULL)
    }

    # Create symlink (use relative path for portability)
    tryCatch({
      file.symlink(basename(final_file), latest_link)
    }, error = function(e) {
      # Symlink failure is non-fatal
      message(sprintf("[backup] Failed to create latest symlink: %s", e$message))
    })
  }

  list(
    success = TRUE,
    file = final_file,
    size_bytes = final_size,
    compressed = compressed
  )
}


#' Execute database restore from backup file
#'
#' Restores a MySQL database from a .sql or .sql.gz backup file.
#' Automatically handles decompression for gzipped files.
#'
#' @param db_config List with dbname, host, user, password, port
#' @param restore_file Character path to backup file to restore
#' @param progress_fn Optional progress reporter function created by create_progress_reporter()
#'
#' @return List with:
#'   - success: Logical - TRUE if restore succeeded
#'   - error: Character error message (if success=FALSE)
#'
#' @details
#' For .sql.gz files: Uses system() with gunzip piped to mysql
#' For .sql files: Uses system() with mysql redirect
#'
#' @examples
#' \dontrun{
#' db_config <- list(
#'   dbname = "sysndd",
#'   host = "mysql",
#'   user = "root",
#'   password = "secret",
#'   port = 3306
#' )
#' result <- execute_restore(db_config, "/backup/backup-2024-01-15.sql.gz")
#' }
#'
#' @export
execute_restore <- function(db_config, restore_file, progress_fn = NULL) {
  # Helper to report progress (no-op if progress_fn is NULL)
  report <- function(step, message, current = NULL, total = NULL) {
    if (!is.null(progress_fn)) {
      progress_fn(step, message, current, total)
    }
  }

  # Validate file exists
  report("validating", "Validating backup file...", 1, 3)

  if (!file.exists(restore_file)) {
    return(list(
      success = FALSE,
      error = sprintf("Backup file not found: %s", restore_file)
    ))
  }

  file_size <- file.info(restore_file)$size
  is_gzipped <- grepl("\\.gz$", restore_file)

  report("restoring",
         sprintf("Restoring from %s (%.1f MB)...",
                 basename(restore_file), file_size / 1024 / 1024),
         2, 3)

  # Build mysql command based on file extension
  if (is_gzipped) {
    # Gzipped backup: decompress on the fly
    restore_cmd <- sprintf(
      "gunzip -c '%s' | mysql -h %s -P %s -u %s -p'%s' %s",
      restore_file,
      db_config$host,
      as.character(db_config$port),
      db_config$user,
      db_config$password,
      db_config$dbname
    )
  } else {
    # Plain SQL file: direct mysql redirect
    restore_cmd <- sprintf(
      "mysql -h %s -P %s -u %s -p'%s' %s < '%s'",
      db_config$host,
      as.character(db_config$port),
      db_config$user,
      db_config$password,
      db_config$dbname,
      restore_file
    )
  }

  # Execute restore command
  result <- system(restore_cmd, intern = FALSE, ignore.stderr = FALSE)

  if (result != 0) {
    return(list(
      success = FALSE,
      error = sprintf("Restore failed with exit code %d", result)
    ))
  }

  report("complete", "Restore completed successfully", 3, 3)

  list(success = TRUE)
}


#' Check if a backup operation is currently running
#'
#' Scans the jobs environment for any active backup_create or
#' backup_restore operations. Used to enforce single-concurrent-backup rule.
#'
#' @return Logical - TRUE if any backup job is running, FALSE otherwise
#'
#' @details
#' Checks jobs_env (from job-manager.R) for jobs with:
#' - operation in c("backup_create", "backup_restore")
#' - status in c("pending", "running")
#'
#' @examples
#' \dontrun{
#' if (check_backup_in_progress()) {
#'   return_409_conflict()
#' }
#' }
#'
#' @export
check_backup_in_progress <- function() {
  job_ids <- ls(jobs_env)

  if (length(job_ids) == 0) {
    return(FALSE)
  }

  for (job_id in job_ids) {
    job <- jobs_env[[job_id]]

    if (!is.null(job) &&
          job$operation %in% c("backup_create", "backup_restore") &&
          job$status %in% c("pending", "running")) {
      return(TRUE)
    }
  }

  return(FALSE)
}
