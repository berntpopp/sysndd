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
