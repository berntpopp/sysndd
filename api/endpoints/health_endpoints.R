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

#* Readiness check for Kubernetes probes
#*
#* Returns HTTP 200 when ready to serve traffic, HTTP 503 when not ready.
#* Reports pending migration count for monitoring and diagnostics.
#*
#* # `Response Codes`
#* - 200: API ready to serve traffic (migrations current)
#* - 503: API not ready (migrations pending or not yet run)
#*
#* # `Details`
#* This endpoint checks if database migrations have been applied. The
#* migration_status global variable is set during API startup by the
#* migration runner. If migrations haven't run yet (startup in progress)
#* or if migrations are pending, returns HTTP 503 to signal not ready.
#*
#* Use this endpoint for Kubernetes readiness probes to ensure traffic
#* is only routed to containers with current database schema.
#*
#* @tag health
#* @serializer json
#*
#* @response 200 OK. API ready to serve traffic.
#* @response 503 Service Unavailable. Migrations pending or not yet run.
#*
#* @get /ready
function(req, res) {
  # Check if migrations have run (variable set during API startup)
  if (!exists("migration_status", envir = .GlobalEnv) ||
      is.null(get("migration_status", envir = .GlobalEnv))) {
    res$status <- 503L
    return(list(
      status = "not_ready",
      reason = "migrations_not_run",
      pending_migrations = NA,
      timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    ))
  }

  # Get migration status from global
  status <- get("migration_status", envir = .GlobalEnv)
  pending <- status$pending_migrations

  # If there are pending migrations, not ready
  if (!is.null(pending) && pending > 0) {
    res$status <- 503L
    return(list(
      status = "not_ready",
      reason = "migrations_pending",
      pending_migrations = pending,
      timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    ))
  }

  # Ready to serve
  list(
    status = "ready",
    pending_migrations = 0,
    total_migrations = status$total_migrations,
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}

#* Performance Metrics
#*
#* Returns performance metrics including worker pool status and cache statistics.
#* Use this endpoint to monitor optimization impact and diagnose performance issues.
#*
#* # `Details`
#* - Worker pool: Shows mirai daemon pool utilization
#* - Cache: Shows file-based cache statistics in results/ directory
#* - Timestamp: Current server time for correlation with logs
#*
#* @tag health
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns performance metrics object.
#*
#* @get /health/performance
function() {
  # Check worker pool status via mirai
  worker_status <- tryCatch({
    status <- mirai::status()
    list(
      total_workers = 8,
      connections = length(status$connections),
      # Dispatcher handles task distribution
      dispatcher_active = TRUE
    )
  }, error = function(e) {
    list(
      total_workers = 8,
      connections = 0,
      dispatcher_active = FALSE,
      error = e$message
    )
  })

  # Check cache statistics
  cache_stats <- tryCatch({
    cache_files <- list.files("results/", pattern = "\\.json$", full.names = TRUE)
    if (length(cache_files) > 0) {
      file_info <- file.info(cache_files)
      total_size_mb <- sum(file_info$size, na.rm = TRUE) / (1024^2)
      oldest_file <- min(file_info$mtime, na.rm = TRUE)
      newest_file <- max(file_info$mtime, na.rm = TRUE)
    } else {
      total_size_mb <- 0
      oldest_file <- NA
      newest_file <- NA
    }

    list(
      file_count = length(cache_files),
      total_size_mb = round(total_size_mb, 2),
      oldest_cache = as.character(oldest_file),
      newest_cache = as.character(newest_file)
    )
  }, error = function(e) {
    list(
      file_count = 0,
      total_size_mb = 0,
      error = e$message
    )
  })

  # Check for versioned cache files (from Plan 01)
  versioned_cache <- tryCatch({
    all_files <- list.files("results/", pattern = "\\.json$")
    leiden_files <- grep("leiden", all_files, value = TRUE)
    walktrap_files <- grep("walktrap", all_files, value = TRUE)
    mca_files <- grep("mca\\.cache_v", all_files, value = TRUE)

    list(
      leiden_cache_files = length(leiden_files),
      walktrap_cache_files = length(walktrap_files),
      mca_versioned_files = length(mca_files),
      # If walktrap files exist but no leiden, may indicate old cache
      cache_migration_needed = length(walktrap_files) > 0 && length(leiden_files) == 0
    )
  }, error = function(e) {
    list(error = e$message)
  })

  # Build response
  list(
    workers = worker_status,
    cache = cache_stats,
    cache_versions = versioned_cache,
    environment = list(
      cache_version = Sys.getenv("CACHE_VERSION", "1"),
      r_version = paste(R.version$major, R.version$minor, sep = ".")
    ),
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
  )
}
