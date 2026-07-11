# api/endpoints/backup_endpoints.R
#
# Backup management API endpoints.
# Provides listing, creation, and restore of database backups.
#
# Note: All required modules (db-helpers.R, middleware.R, backup-functions.R,
# services/backup-endpoint-service.R) are sourced by start_sysndd_api.R
# before endpoints are loaded. Functions are available in the global
# environment.
#
# This file is intentionally a thin authorization/delegation shell (#346
# Wave 3 Task 9): every route keeps its decorators, formals, and the
# Administrator role gate, then delegates the full handler body to the
# matching `svc_backup_*` function in
# api/services/backup-endpoint-service.R.

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
#* Two mutually-exclusive pagination modes:
#*   1. Legacy page-based (default): `page` (default: 1) with fixed
#*      `page_size=20`. Used when `limit` is not provided.
#*   2. New offset-based: `limit` (default: 50 when used, max: 500) +
#*      `offset` (default: 0). Takes precedence when `limit` is provided.
#* - sort: String - Sort order: "newest" (default) or "oldest"
#*
#* # `Response`
#* Paginated response with:
#* - data: Array of backup objects (filename, size_bytes, created_at, table_count)
#* - total: Integer total count of backups
#* - page: Current page number (legacy)
#* - page_size: Number of items per page (legacy)
#* - limit: Integer effective page size
#* - offset: Integer rows skipped
#* - links: Object with `next` URL string (or null when no more pages)
#* - meta: Directory metadata (total_count, total_size_bytes)
#*
#* @tag backup
#* @serializer json list(na="string")
#*
#* @param limit:int Maximum number of items per page (default: 50, max: 500)
#* @param offset:int Number of items to skip (default: 0)
#*
#* @get /list
function(req, res, page = 1, sort = "newest", limit = NULL, offset = NULL) {
  # Require Administrator role
  require_role(req, res, "Administrator")

  svc_backup_list(req, res, page = page, sort = sort, limit = limit, offset = offset)
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

  svc_backup_create(req, res)
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

  svc_backup_restore(req, res)
}


## -------------------------------------------------------------------##
## Backup Download Endpoint
## -------------------------------------------------------------------##

#* Download a backup file
#*
#* Returns the raw backup file content for download. Supports both
#* .sql and .sql.gz files with appropriate Content-Type headers.
#*
#* # `Authorization`
#* Requires Administrator role.
#*
#* # `Path Parameters`
#* - filename: String - Name of the backup file to download
#*
#* # `Response`
#* - 200 OK: Raw file bytes with appropriate headers
#* - 400 Bad Request: Invalid filename (path traversal attempt, invalid extension)
#* - 404 Not Found: Backup file does not exist
#*
#* @tag backup
#* @serializer octet
#*
#* @get /download/<filename>
function(req, res, filename) {
  # Require Administrator role
  require_role(req, res, "Administrator")

  svc_backup_download(req, res, filename)
}


## -------------------------------------------------------------------##
## Backup Delete Endpoint
## -------------------------------------------------------------------##

#* Delete a backup file
#*
#* Permanently removes a backup file from the backup directory.
#* Requires typed confirmation ("DELETE") in request body to prevent accidents.
#*
#* # `Authorization`
#* Requires Administrator role.
#*
#* # `Path Parameters`
#* - filename: String - Name of the backup file to delete
#*
#* # `Request Body`
#* JSON with:
#* - confirm: String - Must be exactly "DELETE" to proceed
#*
#* # `Response`
#* - 200 OK: File deleted successfully
#* - 400 Bad Request: Invalid filename, missing confirmation, or wrong confirmation
#* - 404 Not Found: Backup file does not exist
#*
#* @tag backup
#* @serializer json list(na="string")
#*
#* @delete /delete/<filename>
function(req, res, filename) {
  # Require Administrator role
  require_role(req, res, "Administrator")

  svc_backup_delete(req, res, filename)
}
