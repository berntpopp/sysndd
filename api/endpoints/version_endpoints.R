# api/endpoints/version_endpoints.R
#
# Version endpoint for API version discovery and deployment tracking.
# Returns the API semantic version (version_spec.json) + git commit hash, plus
# the human-facing database semantic version (issue #22) from the db_version
# table. The database block degrades gracefully when the DB/table is missing.
# This endpoint must be lightweight and NOT require authentication.

#* Version endpoint for API + database version discovery
#*
#* Returns the API semantic version and git commit hash for deployment
#* tracking, plus the database semantic version, db-folder git commit, and
#* last-updated timestamp (issue #22). Unauthenticated. The database block
#* falls back to "unknown" rather than failing if the DB is unavailable.
#*
#* @tag version
#* @serializer json
#*
#* @get /
function(req, res) {
  # Git commit hash for the API. Shared resolver (#585) with the same priority:
  # GIT_COMMIT env (Docker build injection) > `git rev-parse --short HEAD`
  # (development) > "unknown". Single source of truth for commit resolution so the
  # version endpoint and the snapshot generator provenance never diverge.
  commit <- resolve_app_git_commit()

  # Database semantic version (issue #22). db_version_get() never throws; it
  # returns an "unknown" / available = FALSE fallback when the DB or table is
  # not reachable, so this public endpoint stays resilient.
  db_version <- db_version_get()

  list(
    version = version_json$version,
    commit = commit,
    title = version_json$title,
    description = version_json$description,
    database = list(
      version = db_version$version,
      commit = db_version$commit,
      description = db_version$description,
      updated_at = db_version$updated_at,
      available = db_version$available
    )
  )
}
