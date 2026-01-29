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
