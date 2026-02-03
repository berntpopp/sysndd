# api/endpoints/health_endpoints.R
#
# Health check endpoint for Docker HEALTHCHECK.
# This endpoint must be lightweight and NOT require authentication.

#' Check current migration lock status
#'
#' Queries MySQL to check if the migration advisory lock is currently held.
#' Used by health endpoint to report coordination state.
#'
#' @return List with locked (boolean) and holder (connection_id or NULL)
#'
#' @keywords internal
check_migration_lock_status <- function() {
  tryCatch(
    {
      result <- db_execute_query("SELECT IS_USED_LOCK('sysndd_migration') AS holder")

      if (is.null(result$holder) || is.na(result$holder)) {
        list(locked = FALSE, holder = NULL)
      } else {
        list(locked = TRUE, holder = as.integer(result$holder))
      }
    },
    error = function(e) {
      list(locked = NA, error = e$message)
    }
  )
}

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
#* Checks database connectivity and migration status for comprehensive readiness.
#*
#* # `Response Codes`
#* - 200: API ready to serve traffic (database connected, migrations current)
#* - 503: API not ready (database unavailable or migrations pending)
#*
#* # `Details`
#* This endpoint performs three checks:
#* 1. Database connectivity: Executes SELECT 1 to verify connection
#* 2. Migration status: Verifies no pending migrations
#* 3. Pool statistics: Reports active/idle connections
#*
#* Use this endpoint for Kubernetes readiness probes and load balancer health checks.
#*
#* @tag health
#* @serializer json
#*
#* @response 200 OK. API ready to serve traffic with database connected.
#* @response 503 Service Unavailable. Database unavailable or migrations pending.
#*
#* @get /ready
function(req, res) {
  timestamp <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  # Check database connectivity with simple ping query
  db_ok <- tryCatch(
    {
      result <- db_execute_query("SELECT 1 AS ok")
      !is.null(result) && nrow(result) == 1 && result$ok[1] == 1
    },
    error = function(e) {
      log_warn("Health check database ping failed: {e$message}")
      FALSE
    }
  )

  # Check migration status (variable set during API startup)
  migrations_ok <- FALSE
  migration_info <- list(pending = NA, applied = NA, fast_path = NA, lock_acquired = NA)

  if (exists("migration_status", where = .GlobalEnv) &&
    !is.null(.GlobalEnv$migration_status)) {
    status <- .GlobalEnv$migration_status
    pending <- status$pending_migrations

    # Check if startup had an error
    if (!is.null(status$error)) {
      migrations_ok <- FALSE
    } else {
      migrations_ok <- !is.null(pending) && !is.na(pending) && pending == 0
    }

    migration_info <- list(
      pending = if (is.null(pending) || is.na(pending)) NA else pending,
      applied = if (is.null(status$total_migrations)) NA else status$total_migrations,
      fast_path = if (is.null(status$fast_path)) NA else status$fast_path,
      lock_acquired = if (is.null(status$lock_acquired)) NA else status$lock_acquired
    )
  }

  # Get pool statistics
  pool_stats <- tryCatch(
    {
      # pool package stores counters internally
      # Use pool's internal state to get connection counts
      checkout_count <- pool$counters$free + pool$counters$taken
      list(
        max_size = as.integer(Sys.getenv("DB_POOL_SIZE", "5")),
        active = pool$counters$taken,
        idle = pool$counters$free,
        total = checkout_count
      )
    },
    error = function(e) {
      list(
        max_size = as.integer(Sys.getenv("DB_POOL_SIZE", "5")),
        error = "Unable to read pool statistics"
      )
    }
  )

  # Determine overall health
  if (db_ok && migrations_ok) {
    # Check current lock status (for debugging parallel startup issues)
    lock_status <- check_migration_lock_status()

    list(
      status = "healthy",
      database = "connected",
      migrations = list(
        pending = migration_info$pending,
        applied = migration_info$applied,
        startup = list(
          fast_path = migration_info$fast_path,
          lock_acquired = migration_info$lock_acquired
        ),
        lock = lock_status
      ),
      pool = pool_stats,
      timestamp = timestamp
    )
  } else {
    res$status <- 503L

    # Determine reason for unhealthy status
    reason <- if (!db_ok) {
      "database_unavailable"
    } else if (exists("migration_status", where = .GlobalEnv) &&
               !is.null(.GlobalEnv$migration_status$error)) {
      "migration_error"
    } else {
      "migrations_pending"
    }

    lock_status <- tryCatch(check_migration_lock_status(), error = function(e) list(locked = NA))

    list(
      status = "unhealthy",
      reason = reason,
      database = if (db_ok) "connected" else "disconnected",
      migrations = list(
        pending = migration_info$pending,
        applied = migration_info$applied,
        startup = list(
          fast_path = migration_info$fast_path,
          lock_acquired = migration_info$lock_acquired
        ),
        lock = lock_status,
        error = if (exists("migration_status", where = .GlobalEnv)) .GlobalEnv$migration_status$error else NULL
      ),
      pool = pool_stats,
      timestamp = timestamp
    )
  }
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
#* @get /performance
function() {
  # Read configured worker count from environment (same logic as start_sysndd_api.R)
  configured_workers <- as.integer(Sys.getenv("MIRAI_WORKERS", "2"))
  if (is.na(configured_workers)) configured_workers <- 2L
  configured_workers <- max(1L, min(configured_workers, 8L))

  # Check worker pool status via mirai
  worker_status <- tryCatch(
    {
      status <- mirai::status()
      list(
        configured = configured_workers,
        connections = status$connections,
        # Dispatcher handles task distribution
        dispatcher_active = TRUE
      )
    },
    error = function(e) {
      list(
        configured = configured_workers,
        connections = 0,
        dispatcher_active = FALSE,
        error = e$message
      )
    }
  )

  # Check cache statistics
  cache_stats <- tryCatch(
    {
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
    },
    error = function(e) {
      list(
        file_count = 0,
        total_size_mb = 0,
        error = e$message
      )
    }
  )

  # Check for versioned cache files (from Plan 01)
  versioned_cache <- tryCatch(
    {
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
    },
    error = function(e) {
      list(error = e$message)
    }
  )

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
