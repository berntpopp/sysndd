# api/endpoints/health_endpoints.R
#
# Health check endpoint for Docker HEALTHCHECK.
# This endpoint must be lightweight and NOT require authentication.

#* Health check endpoint for Docker HEALTHCHECK
#*
#* Returns API health status for container orchestration.
#* This endpoint is unauthenticated and does not query the database.
#*
#* @tag health
#* @serializer json
#*
#* @get /
function(req, res) {
  list(
    status = "healthy",
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    version = sysndd_api_version
  )
}
