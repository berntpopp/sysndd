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
#'
#' @param db_config List with dbname, host, user, password, port
#' @param output_file Character path where backup will be written
#'
#' @return List with:
#'   - success: Logical - TRUE if backup succeeded
#'   - file: Character path to backup file (if success=TRUE)
#'   - error: Character error message (if success=FALSE)
#'
#' @details
#' Uses mysqldump flags:
#' - --single-transaction: Consistent backup for InnoDB
#' - --routines: Include stored procedures and functions
#' - --triggers: Include triggers
#' - --quick: Retrieve rows one at a time (memory efficient)
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
execute_mysqldump <- function(db_config, output_file) {
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

  # Execute with stderr capture for error handling
  result <- system2(
    "mysqldump",
    args = args,
    stdout = output_file,
    stderr = TRUE
  )

  # system2 returns status code as attribute when stderr=TRUE
  status <- attr(result, "status") %||% 0

  if (status != 0) {
    return(list(
      success = FALSE,
      error = paste(result, collapse = "\n")
    ))
  }

  list(success = TRUE, file = output_file)
}


#' Execute database restore from backup file
#'
#' Restores a MySQL database from a .sql or .sql.gz backup file.
#' Automatically handles decompression for gzipped files.
#'
#' @param db_config List with dbname, host, user, password, port
#' @param restore_file Character path to backup file to restore
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
execute_restore <- function(db_config, restore_file) {
  # Validate file exists
  if (!file.exists(restore_file)) {
    return(list(
      success = FALSE,
      error = sprintf("Backup file not found: %s", restore_file)
    ))
  }

  # Build mysql command based on file extension
  if (grepl("\\.gz$", restore_file)) {
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
