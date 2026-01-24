# api/endpoints/version_endpoints.R
#
# Version endpoint for API version discovery and deployment tracking.
# Returns semantic version from version_spec.json and git commit hash.
# This endpoint must be lightweight and NOT require authentication.

#* Version endpoint for API version discovery
#*
#* Returns semantic version and git commit hash for deployment tracking.
#* This endpoint is unauthenticated and does not query the database.
#*
#* @tag version
#* @serializer json
#*
#* @get /
function(req, res) {
  # Get git commit hash
  # Priority: GIT_COMMIT env var (Docker build injection) > git command (development) > "unknown"
  commit <- Sys.getenv("GIT_COMMIT", unset = "")

  if (commit == "") {
    # Try to get commit from git command (development environment)
    tryCatch({
      commit <- system2("git", c("rev-parse", "--short", "HEAD"),
                       stdout = TRUE, stderr = FALSE)
      # system2 returns character(0) if git not available
      if (length(commit) == 0 || commit == "") {
        commit <- "unknown"
      }
    }, error = function(e) {
      commit <<- "unknown"
    })
  }

  list(
    version = version_json$version,
    commit = commit,
    title = version_json$title,
    description = version_json$description
  )
}
