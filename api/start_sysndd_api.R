######################################################################
# start_sysndd_api.R
#
# A single script that:
#  - Loads all required libraries and config
#  - Loads environment variables from .env via dotenv
#  - Decides environment (local/production) via ENVIRONMENT variable
#  - Uses config.yml to get 'workdir' (and everything else)
#  - Creates & memoizes global objects (pool, serializers, etc.)
#  - Defines Plumber filters & hooks
#  - Mounts endpoint scripts at /api/<something>
#  - Runs the API
#
# Run it with: Rscript start_sysndd_api.R
# Or set ENVIRONMENT=production to run with production config.
######################################################################

## -------------------------------------------------------------------##
# 1) Load Required Libraries
## -------------------------------------------------------------------##
library(dotenv)
# Load .env file if present (local development); skip in Docker where env vars come from compose
if (file.exists(".env")) {
  dotenv::load_dot_env(file = ".env")
}

library(plumber)
library(logger)
library(tictoc)
library(fs)
library(jsonlite)
library(DBI)
library(RMariaDB)
library(config)
library(pool)

# Additional libraries from your old sysndd_plumber.R
library(biomaRt)
library(tidyverse)
library(stringr)
library(jose)
library(RCurl)
library(stringdist)
library(xlsx)
library(easyPubMed)
library(xml2)
library(rvest)
library(lubridate)
library(memoise)
library(coop)
library(reshape2)
library(blastula)
library(keyring)
library(future)
library(knitr)
library(rlang)
library(timetk)
library(STRINGdb)
library(factoextra)
library(FactoMineR)
library(vctrs)
library(httr)
library(httr2)
library(ellipsis)
library(ontologyIndex)
library(httpproblems)
library(mirai)
library(promises)
library(uuid)

## -------------------------------------------------------------------##
# set redirect to trailing slash
options_plumber(trailingSlash = TRUE)
## -------------------------------------------------------------------##

## -------------------------------------------------------------------##
# 2) Decide which environment (local vs production)
## -------------------------------------------------------------------##
env_mode <- Sys.getenv("ENVIRONMENT", "local")
# If ENVIRONMENT is not set (or missing in .env), default to "local"

message(paste("ENVIRONMENT set to:", env_mode))

# Map that environment to the config key:
if (tolower(env_mode) == "production") {
  Sys.setenv(API_CONFIG = "sysndd_db") # Production entry in config.yml
} else if (tolower(env_mode) == "development") {
  Sys.setenv(API_CONFIG = "sysndd_db_dev") # Docker development entry (Mailpit SMTP)
} else {
  Sys.setenv(API_CONFIG = "sysndd_db_local") # Local entry in config.yml (Windows)
}

## -------------------------------------------------------------------##
# 3) Read config and set working directory from config
## -------------------------------------------------------------------##
dw <- config::get(Sys.getenv("API_CONFIG"))
# Above line reads from config.yml the environment block
# e.g. sysndd_db_local or sysndd_db

# If you have a field 'workdir' in the config, do:
if (!is.null(dw$workdir)) {
  message(paste("Setting working directory to:", dw$workdir))
  setwd(dw$workdir)
} else {
  message("No 'workdir' specified in config. Using current working directory.")
}

## -------------------------------------------------------------------##
# 4) Load Additional Scripts (Helper Functions)
## -------------------------------------------------------------------##
source("functions/config-functions.R", local = TRUE)
source("functions/logging-functions.R", local = TRUE)
source("functions/db-helpers.R", local = TRUE)
source("functions/entity-repository.R", local = TRUE)
source("functions/review-repository.R", local = TRUE)
source("functions/status-repository.R", local = TRUE)
source("functions/publication-repository.R", local = TRUE)
source("functions/phenotype-repository.R", local = TRUE)
source("functions/ontology-repository.R", local = TRUE)
source("functions/user-repository.R", local = TRUE)
source("functions/hash-repository.R", local = TRUE)
source("functions/legacy-wrappers.R", local = TRUE)
source("functions/endpoint-functions.R", local = TRUE)
source("functions/publication-functions.R", local = TRUE)
source("functions/genereviews-functions.R", local = TRUE)
source("functions/analyses-functions.R", local = TRUE)
source("functions/helper-functions.R", local = TRUE)
source("functions/email-templates.R", local = TRUE)
source("functions/pagination-helpers.R", local = TRUE)
source("functions/external-functions.R", local = TRUE)
source("functions/external-proxy-functions.R", local = TRUE)
source("functions/external-proxy-gnomad.R", local = TRUE)
source("functions/external-proxy-uniprot.R", local = TRUE)
source("functions/external-proxy-ensembl.R", local = TRUE)
source("functions/external-proxy-alphafold.R", local = TRUE)
source("functions/external-proxy-mgi.R", local = TRUE)
source("functions/external-proxy-rgd.R", local = TRUE)
source("functions/file-functions.R", local = TRUE)
source("functions/hpo-functions.R", local = TRUE)
source("functions/hgnc-functions.R", local = TRUE)
source("functions/hgnc-enrichment-gnomad.R", local = TRUE)
source("functions/ontology-functions.R", local = TRUE)
source("functions/pubtator-functions.R", local = TRUE)
source("functions/ensembl-functions.R", local = TRUE)
source("functions/job-manager.R", local = TRUE)
source("functions/job-progress.R", local = TRUE)
source("functions/backup-functions.R", local = TRUE)
source("functions/ols-functions.R", local = TRUE)

# Core security and error handling modules
source("core/security.R", local = TRUE)
source("core/errors.R", local = TRUE)
source("core/responses.R", local = TRUE)
source("core/logging_sanitizer.R", local = TRUE)
source("core/middleware.R", local = TRUE)

# Service layer
source("services/auth-service.R", local = TRUE)
source("services/user-service.R", local = TRUE)
source("services/status-service.R", local = TRUE)
source("services/search-service.R", local = TRUE)
source("services/entity-service.R", local = TRUE)
source("services/review-service.R", local = TRUE)
source("services/approval-service.R", local = TRUE)
source("services/re-review-service.R", local = TRUE)

## -------------------------------------------------------------------##
# 5) Load the API spec for OpenAPI (optional)
## -------------------------------------------------------------------##
api_spec <- fromJSON("config/api_spec.json", flatten = TRUE)

## -------------------------------------------------------------------##
# 6) Setup logging
## -------------------------------------------------------------------##
log_dir <- "logs"
if (!dir_exists(log_dir)) fs::dir_create(log_dir)
logging_temp_file <- tempfile("plumber_", log_dir, ".log")
log_appender(appender_file(logging_temp_file))

## -------------------------------------------------------------------##
# 7) Create a global DB pool in the global environment
## -------------------------------------------------------------------##
# Read pool size from environment variable with default
# Why 5: Single-threaded R rarely needs >1-2 concurrent connections,
# but 5 allows burst for mirai workers. Explicit sizing prevents
# unbounded connection growth that could exhaust MySQL max_connections.
pool_size <- as.integer(Sys.getenv("DB_POOL_SIZE", "5"))

pool <<- dbPool(
  drv = RMariaDB::MariaDB(),
  dbname = dw$dbname,
  host = dw$host,
  user = dw$user,
  password = dw$password,
  server = dw$server,
  port = dw$port,
  minSize = 1,
  maxSize = pool_size,
  idleTimeout = 60,
  validationInterval = 60
)

message(sprintf("[%s] Database pool created (minSize=1, maxSize=%d)", Sys.time(), pool_size))

## -------------------------------------------------------------------##
# 7.5) Run database migrations with double-checked locking
## -------------------------------------------------------------------##
source("functions/migration-runner.R", local = TRUE)

tryCatch(
  {
    # Step 1: Fast path check (no lock needed if schema current)
    pending_before_lock <- get_pending_migrations(migrations_dir = "db/migrations", conn = pool)

    if (length(pending_before_lock) == 0) {
      # Fast path: schema up to date, skip lock entirely
      message(sprintf("[%s] Fast path: schema up to date, no lock needed", Sys.time()))

      # Get total applied count for status
      applied_count <- length(get_applied_migrations(pool))

      migration_status <<- list(
        pending_migrations = 0,
        total_migrations = applied_count,
        last_run = Sys.time(),
        newly_applied = 0,
        filenames = character(0),
        fast_path = TRUE,
        lock_acquired = FALSE
      )
    } else {
      # Step 2: Migrations needed - acquire lock
      message(sprintf(
        "[%s] Pending migrations detected (%d): %s - acquiring lock",
        Sys.time(), length(pending_before_lock), paste(pending_before_lock, collapse = ", ")
      ))

      # Checkout connection for lock duration
      migration_conn <- pool::poolCheckout(pool)
      on.exit(pool::poolReturn(migration_conn), add = TRUE)

      # Acquire advisory lock (blocks until available or 30s timeout)
      acquire_migration_lock(migration_conn, timeout = 30)
      on.exit(release_migration_lock(migration_conn), add = TRUE)

      # Step 3: Re-check after lock (another container may have migrated)
      pending_after_lock <- get_pending_migrations(migrations_dir = "db/migrations", conn = pool)

      if (length(pending_after_lock) == 0) {
        # Race condition: another container applied migrations while we waited
        message(sprintf("[%s] Another container completed migrations while we waited", Sys.time()))

        applied_count <- length(get_applied_migrations(pool))

        migration_status <<- list(
          pending_migrations = 0,
          total_migrations = applied_count,
          last_run = Sys.time(),
          newly_applied = 0,
          filenames = character(0),
          fast_path = FALSE,
          lock_acquired = TRUE
        )
      } else {
        # Step 4: Apply migrations (we hold lock, migrations still needed)
        start_time <- Sys.time()
        result <- run_migrations(migrations_dir = "db/migrations", conn = pool)
        duration <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

        if (result$newly_applied > 0) {
          message(sprintf(
            "[%s] Migrations complete (%d applied in %.2fs): %s",
            Sys.time(), result$newly_applied, duration,
            paste(result$filenames, collapse = ", ")
          ))
        } else {
          message(sprintf(
            "[%s] Schema up to date (%d migrations applied)",
            Sys.time(), result$total_applied
          ))
        }

        migration_status <<- list(
          pending_migrations = 0,
          total_migrations = result$total_applied,
          last_run = Sys.time(),
          newly_applied = result$newly_applied,
          filenames = result$filenames,
          fast_path = FALSE,
          lock_acquired = TRUE
        )
      }
    }
  },
  error = function(e) {
    message(sprintf("[%s] FATAL: Migration failed - %s", Sys.time(), e$message))

    # Record failure state for health endpoint
    migration_status <<- list(
      pending_migrations = NA,
      total_migrations = NA,
      last_run = Sys.time(),
      newly_applied = 0,
      filenames = character(0),
      fast_path = FALSE,
      lock_acquired = FALSE,
      error = e$message
    )

    # Crash API - forces fix before deploy
    stop(paste("API startup aborted: migration failure -", e$message))
  }
)

## -------------------------------------------------------------------##
# 8) Define global objects (serializers, allowed arrays, etc.)
## -------------------------------------------------------------------##
serializers <<- list(
  "json" = serializer_json(),
  "xlsx" = serializer_content_type(
    type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  )
)

inheritance_input_allowed <<- c(
  "X-linked",
  "Autosomal dominant",
  "Autosomal recessive",
  "Other",
  "All"
)

output_columns_allowed <<- c(
  "category",
  "inheritance",
  "symbol",
  "hgnc_id",
  "entrez_id",
  "ensembl_gene_id",
  "ucsc_id",
  "bed_hg19",
  "bed_hg38",
  "gnomad_constraints",
  "alphafold_id"
)

user_status_allowed <<- c("Administrator", "Curator", "Reviewer", "Viewer")

# Load version info from version_spec.json
version_json <<- fromJSON("version_spec.json")
sysndd_api_version <<- version_json$version

## -------------------------------------------------------------------##
# 9) Memoize certain functions
## -------------------------------------------------------------------##
cm <- cachem::cache_disk(
  dir      = "/app/cache",
  max_age  = Inf, # Never expires (clear volume to invalidate)
  max_size = 500 * 1024^2 # 500 MB persistent on disk
)

generate_stat_tibble_mem <<- memoise(generate_stat_tibble, cache = cm)
generate_gene_news_tibble_mem <<- memoise(generate_gene_news_tibble, cache = cm)
nest_gene_tibble_mem <<- memoise(nest_gene_tibble, cache = cm)
generate_tibble_fspec_mem <<- memoise(generate_tibble_fspec, cache = cm)
gen_string_clust_obj_mem <<- memoise(gen_string_clust_obj, cache = cm)
gen_mca_clust_obj_mem <<- memoise(gen_mca_clust_obj, cache = cm)
gen_network_edges_mem <<- memoise(gen_network_edges, cache = cm)
read_log_files_mem <<- memoise(read_log_files, cache = cm)
nest_pubtator_gene_tibble_mem <<- memoise(nest_pubtator_gene_tibble, cache = cm)

## -------------------------------------------------------------------##
# 9.5) Initialize mirai daemon pool for async jobs
## -------------------------------------------------------------------##
daemons(
  n = 2, # 2 workers (right-sized for 4-core VPS with 8GB RAM)
  dispatcher = TRUE, # Enable for variable-length jobs
  autoexit = tools::SIGINT
)
message(sprintf("[%s] Started mirai daemon pool with 2 workers", Sys.time()))

# Export required packages and functions to all daemons
# NOTE: Load packages that mask dplyr::select FIRST (STRINGdb, biomaRt load
# AnnotationDbi), then load dplyr/tidyverse LAST so their functions win.
everywhere({
  library(DBI)
  library(RMariaDB)
  library(STRINGdb)
  library(biomaRt)
  library(FactoMineR)
  library(factoextra)
  library(cluster)
  library(igraph)
  library(digest)
  library(jsonlite)
  library(openssl)
  library(httr2)
  library(memoise)
  library(cachem)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(stringr)
  library(purrr)
  library(readr)
  library(logger)
  # Load ellmer for LLM functionality (optional - graceful degradation if not available)
  if (requireNamespace("ellmer", quietly = TRUE)) {
    library(ellmer)
  }
  # Load pdftools for PDF parsing in comparisons update (optional)
  if (requireNamespace("pdftools", quietly = TRUE)) {
    library(pdftools)
  }
  # Source helper functions first (generate_panel_hash, generate_function_hash)
  source("/app/functions/helper-functions.R", local = FALSE)
  # Source file functions (check_file_age, get_newest_file)
  source("/app/functions/file-functions.R", local = FALSE)
  # Source the analysis functions (gen_string_clust_obj, gen_mca_clust_obj)
  source("/app/functions/analyses-functions.R", local = FALSE)
  # Source shared external proxy infrastructure (validate_gene_symbol, cache backends, throttle)
  source("/app/functions/external-proxy-functions.R", local = FALSE)
  # Source gnomAD proxy functions (fetch_gnomad_constraints + memoised wrapper)
  source("/app/functions/external-proxy-gnomad.R", local = FALSE)
  # Source gnomAD/AlphaFold enrichment functions for HGNC update pipeline
  source("/app/functions/hgnc-enrichment-gnomad.R", local = FALSE)
  # Source HGNC functions (update_process_hgnc_data)
  source("/app/functions/hgnc-functions.R", local = FALSE)
  # Source Ensembl functions (gene_coordinates_from_ensembl, gene_coordinates_from_symbol)
  source("/app/functions/ensembl-functions.R", local = FALSE)
  # Source file-based job progress reporting
  source("/app/functions/job-progress.R", local = FALSE)
  # Source db-helpers for parameterized queries
  source("/app/functions/db-helpers.R", local = FALSE)
  # Source PubTator functions for async update jobs
  source("/app/functions/pubtator-functions.R", local = FALSE)
  # Source comparisons functions for async comparisons update jobs
  source("/app/functions/comparisons-sources.R", local = FALSE)
  source("/app/functions/comparisons-functions.R", local = FALSE)
  # Source LLM-related functions for async LLM batch generation jobs
  source("/app/functions/llm-cache-repository.R", local = FALSE)
  source("/app/functions/llm-validation.R", local = FALSE)
  source("/app/functions/llm-service.R", local = FALSE)
  source("/app/functions/llm-judge.R", local = FALSE)
  source("/app/functions/llm-batch-generator.R", local = FALSE)
})
message(sprintf("[%s] Exported packages and functions to mirai daemons", Sys.time()))

# Schedule hourly job cleanup (uses schedule_cleanup from job-manager.R)
schedule_cleanup(3600) # 3600 seconds = 1 hour

## -------------------------------------------------------------------##
# 10) Define filters as named functions with roxygen tags
## -------------------------------------------------------------------##
#* @filter cors
corsFilter <- function(req, res) {
  # CORS configuration for credentialed requests (sticky session cookies)
  #
  # IMPORTANT: When using withCredentials:true on the frontend, browsers require:
  # 1. Access-Control-Allow-Origin to be the SPECIFIC origin (not "*")
  # 2. Access-Control-Allow-Credentials: true
  #
  # Without this, sticky session cookies are silently dropped by the browser,

  # causing job status polling to hit random containers and return 404 errors.

  # Get the request origin
  origin <- req$HTTP_ORIGIN

  # Define allowed origins based on environment
  # In production, you may want to restrict this to specific domains
  allowed_origins <- c(
    "http://localhost",
    "http://localhost:80",
    "http://localhost:5173",  # Vite dev server
    "http://127.0.0.1",
    "http://127.0.0.1:80",
    "http://127.0.0.1:5173"
  )

  # Check if origin is allowed (or allow all in development)
  # For production, add your domain to allowed_origins

  if (!is.null(origin) && (origin %in% allowed_origins || Sys.getenv("ENVIRONMENT") == "development")) {
    res$setHeader("Access-Control-Allow-Origin", origin)
    res$setHeader("Access-Control-Allow-Credentials", "true")
  } else if (is.null(origin)) {
    # No origin header (same-origin request or non-browser client like curl)
    # Use a safe default that still allows cookies
    res$setHeader("Access-Control-Allow-Origin", "http://localhost")
    res$setHeader("Access-Control-Allow-Credentials", "true")
  } else {
    # Unknown origin - still set CORS but log warning
    log_warn("CORS: Unknown origin", origin = origin)
    res$setHeader("Access-Control-Allow-Origin", origin)
    res$setHeader("Access-Control-Allow-Credentials", "true")
  }

  if (req$REQUEST_METHOD == "OPTIONS") {
    res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS")
    res$setHeader(
      "Access-Control-Allow-Headers",
      req$HTTP_ACCESS_CONTROL_REQUEST_HEADERS
    )
    res$status <- 200
    return(list())
  } else {
    plumber::forward()
  }
}

#* @filter check_signin
# DEPRECATED: Use require_auth filter instead.
# This will be removed after Phase 22 endpoint migration.
checkSignInFilter <- function(req, res) {
  key <- charToRaw(dw$secret)

  # GET without auth => forward
  if (req$REQUEST_METHOD == "GET" && is.null(req$HTTP_AUTHORIZATION)) {
    plumber::forward()
  } else if (req$REQUEST_METHOD == "GET" && !is.null(req$HTTP_AUTHORIZATION)) {
    # GET with Bearer token => decode
    jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")
    tryCatch(
      {
        user <- jwt_decode_hmac(jwt, secret = key)
      },
      error = function(e) {
        res$status <- 401
        return(list(error = "Token expired or invalid."))
      }
    )
    req$user_id <- as.integer(user$user_id)
    req$user_role <- user$user_role
    plumber::forward()
  } else if (req$REQUEST_METHOD == "POST" &&
    (req$PATH_INFO == "/api/gene/hash" || req$PATH_INFO == "/api/entity/hash")) {
    # POST to /api/entity/hash or /api/gene/hash => forward
    plumber::forward()
  } else if (req$REQUEST_METHOD == "POST" &&
    (req$PATH_INFO %in% c(
      "/api/jobs/clustering/submit",
      "/api/jobs/clustering/submit/",
      "/api/jobs/phenotype_clustering/submit",
      "/api/jobs/phenotype_clustering/submit/"
    ))) {
    # POST to public async job endpoints => forward
    # (clustering and phenotype_clustering are public, ontology_update requires auth handled internally)
    plumber::forward()
  } else if (req$REQUEST_METHOD == "PUT" &&
    (req$PATH_INFO == "/api/user/password/reset/request")) {
    # PUT to /api/user/password/reset/request
    plumber::forward()
  } else {
    # Otherwise require Bearer token
    if (is.null(req$HTTP_AUTHORIZATION)) {
      res$status <- 401
      return(list(error = "Authorization http header missing."))
    } else {
      decoded_jwt <- jwt_decode_hmac(
        str_remove(req$HTTP_AUTHORIZATION, "Bearer "),
        secret = key
      )
      if (decoded_jwt$exp < as.numeric(Sys.time())) {
        res$status <- 401
        return(list(error = "Token expired."))
      } else {
        req$user_id <- as.integer(decoded_jwt$user_id)
        req$user_role <- decoded_jwt$user_role
        plumber::forward()
      }
    }
  }
}

## -------------------------------------------------------------------##
# 11) We define a named function for the final 'exit' hook
## -------------------------------------------------------------------##
#* @plumber
cleanupHook <- function(pr) {
  pr %>%
    pr_hook("exit", function() {
      pool::poolClose(pool)
      message("Disconnected from DB")
      daemons(0) # Shutdown mirai daemon pool
      message("Shutdown mirai daemon pool")
    })
}

## -------------------------------------------------------------------##
# 12) Define error handler middleware for RFC 9457 compliance
## -------------------------------------------------------------------##
#* @plumber
errorHandler <- function(req, res, err) {
  # Get error message safely
  err_msg <- tryCatch(
    conditionMessage(err),
    error = function(e) "An error occurred"
  )

  # Log all errors with sanitized request info (internal - full details)
  tryCatch({
    log_error(
      "API error",
      error_class = class(err)[1],
      error_message = err_msg,
      endpoint = req$PATH_INFO,
      request = sanitize_request(req)
    )
  }, error = function(e) {
    # Fallback logging if structured logging fails
    cat(sprintf("[ERROR] %s: %s\n", class(err)[1], err_msg), file = stderr())
  })

  # Set content type for all error responses
  res$setHeader("Content-Type", "application/problem+json")

  # Get request path for 'instance' field (RFC 9457)
  instance <- tryCatch(req$PATH_INFO, error = function(e) NULL)

  # Helper to create RFC 9457 problem response
  # Uses unbox() wrapper for proper scalar serialization
  make_problem_response <- function(type_suffix, title, status_code, detail_msg) {
    res$status <- status_code
    # Use serializer_unboxed_json for proper scalar values
    res$serializer <- plumber::serializer_unboxed_json()
    list(
      type = paste0("https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/", status_code),
      title = title,
      status = status_code,
      detail = detail_msg,
      instance = instance
    )
  }

  # Handle custom classed errors from core/errors.R
  # Create RFC 9457 problem details directly based on error class
  if (inherits(err, "error_400")) {
    return(make_problem_response(400, "Bad Request", 400, err_msg))
  }

  if (inherits(err, "error_401")) {
    return(make_problem_response(401, "Unauthorized", 401, err_msg))
  }

  if (inherits(err, "error_403")) {
    return(make_problem_response(403, "Forbidden", 403, err_msg))
  }

  if (inherits(err, "error_404")) {
    return(make_problem_response(404, "Not Found", 404, err_msg))
  }

  # Unhandled exception = 500 Internal Server Error
  # Don't expose internal details to client
  return(make_problem_response(500, "Internal Server Error", 500, "An unexpected error occurred"))
}

#' Route-level 404 Not Found Handler (RFC 9457 compliant)
#'
#' Handles requests to non-existent routes/endpoints.
#' This is separate from resource-level 404s handled by error_404.
#'
#' @param req Plumber request object
#' @param res Plumber response object
#' @return RFC 9457 problem details response
notFoundHandler <- function(req, res) {
  res$status <- 404
  res$setHeader("Content-Type", "application/problem+json")
  res$serializer <- plumber::serializer_unboxed_json()
  list(
    type = "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/404",
    title = "Not Found",
    status = 404,
    detail = sprintf("The requested endpoint '%s' does not exist", req$PATH_INFO),
    instance = req$PATH_INFO
  )
}

## -------------------------------------------------------------------##
# 13) Create root plumber router with doc lines for the entire API
## -------------------------------------------------------------------##
root <- pr() %>%
  # Install error handler middleware
  pr_set_error(errorHandler) %>%
  # Install 404 handler for non-existent routes (RFC 9457 compliant)
  pr_set_404(notFoundHandler) %>%
  # Insert doc info in pr_set_api_spec
  pr_set_api_spec(function(spec) {
    # -----------------------------------------------------------------
    #  We read from version_spec.json for the version info:
    # -----------------------------------------------------------------
    version_info <- fromJSON("version_spec.json") # Load your JSON file
    # Set the spec fields from version_info:
    spec$info$title <- version_info$title
    spec$info$description <- version_info$description
    spec$info$version <- version_info$version

    if (!is.null(version_info$contact)) {
      spec$info$contact <- version_info$contact
    }
    if (!is.null(version_info$license)) {
      spec$info$license <- version_info$license
    }

    spec$components$securitySchemes$bearerAuth$type <- "http"
    spec$components$securitySchemes$bearerAuth$scheme <- "bearer"
    spec$components$securitySchemes$bearerAuth$bearerFormat <- "JWT"
    spec$security[[1]]$bearerAuth <- ""

    # Insert example requests from your api_spec.json (optional)
    spec <- update_api_spec_examples(spec, api_spec)
    spec
  }) %>%
  ####################################################################
  # Attach filters
  ####################################################################
  pr_filter("cors", corsFilter) %>%
  pr_filter("require_auth", require_auth) %>%
  ####################################################################
  # Attach exit hook
  ####################################################################
  cleanupHook() %>%
  ####################################################################
  # Mount health endpoint for Docker HEALTHCHECK
  ####################################################################
  pr_mount("/api/health", pr("endpoints/health_endpoints.R")) %>%
  ####################################################################
  # Mount version endpoint for API version discovery
  ####################################################################
  pr_mount("/api/version", pr("endpoints/version_endpoints.R")) %>%
  ####################################################################
  # Mount each endpoint file at /api/<subpath>
  ####################################################################
  pr_mount("/api/entity", pr("endpoints/entity_endpoints.R")) %>%
  pr_mount("/api/review", pr("endpoints/review_endpoints.R")) %>%
  pr_mount("/api/re_review", pr("endpoints/re_review_endpoints.R")) %>%
  pr_mount("/api/publication", pr("endpoints/publication_endpoints.R")) %>%
  pr_mount("/api/gene", pr("endpoints/gene_endpoints.R")) %>%
  pr_mount("/api/ontology", pr("endpoints/ontology_endpoints.R")) %>%
  pr_mount("/api/phenotype", pr("endpoints/phenotype_endpoints.R")) %>%
  pr_mount("/api/status", pr("endpoints/status_endpoints.R")) %>%
  pr_mount("/api/panels", pr("endpoints/panels_endpoints.R")) %>%
  pr_mount("/api/comparisons", pr("endpoints/comparisons_endpoints.R")) %>%
  pr_mount("/api/analysis", pr("endpoints/analysis_endpoints.R")) %>%
  pr_mount("/api/jobs", pr("endpoints/jobs_endpoints.R")) %>%
  pr_mount("/api/hash", pr("endpoints/hash_endpoints.R")) %>%
  pr_mount("/api/search", pr("endpoints/search_endpoints.R")) %>%
  pr_mount("/api/list", pr("endpoints/list_endpoints.R")) %>%
  pr_mount("/api/logs", pr("endpoints/logging_endpoints.R")) %>%
  pr_mount("/api/user", pr("endpoints/user_endpoints.R")) %>%
  pr_mount("/api/auth", pr("endpoints/authentication_endpoints.R")) %>%
  pr_mount("/api/about", pr("endpoints/about_endpoints.R")) %>%
  pr_mount("/api/admin", pr("endpoints/admin_endpoints.R")) %>%
  pr_mount("/api/llm", pr("endpoints/llm_admin_endpoints.R")) %>%
  pr_mount("/api/backup", pr("endpoints/backup_endpoints.R")) %>%
  pr_mount("/api/external", pr("endpoints/external_endpoints.R")) %>%
  pr_mount("/api/statistics", pr("endpoints/statistics_endpoints.R")) %>%
  pr_mount("/api/variant", pr("endpoints/variant_endpoints.R")) %>%
  # -------------------------------------------------------------------

  ####################################################################
  # preroute / postroute hooks for timing & logging
  ####################################################################
  pr_hook("preroute", function() {
    tictoc::tic()
  }) %>%
  pr_hook("postroute", function(req, res) {
    end <- tictoc::toc(quiet = TRUE)

    # Sanitize the request before logging
    safe_req <- sanitize_request(req)

    # For postBody, extract and sanitize if present
    safe_post_body <- if (!is.null(req$postBody) && nchar(req$postBody) > 0) {
      tryCatch(
        {
          body_parsed <- jsonlite::fromJSON(req$postBody, simplifyVector = FALSE)
          body_sanitized <- sanitize_object(body_parsed)
          jsonlite::toJSON(body_sanitized, auto_unbox = TRUE)
        },
        error = function(e) {
          "[PARSE_ERROR]"
        }
      )
    } else {
      convert_empty(req$postBody)
    }

    log_entry <- paste(
      convert_empty(req$REMOTE_ADDR),
      convert_empty(req$HTTP_USER_AGENT),
      convert_empty(req$HTTP_HOST),
      convert_empty(req$REQUEST_METHOD),
      convert_empty(req$PATH_INFO),
      convert_empty(req$QUERY_STRING),
      safe_post_body,
      convert_empty(res$status),
      round(end$toc - end$tic, digits = getOption("digits", 5)),
      sep = ";",
      collapse = ""
    )
    log_info(skip_formatter(log_entry))

    # Write log entry to DB with sanitized data
    log_message_to_db(
      address         = convert_empty(req$REMOTE_ADDR),
      agent           = convert_empty(req$HTTP_USER_AGENT),
      host            = convert_empty(req$HTTP_HOST),
      request_method  = convert_empty(req$REQUEST_METHOD),
      path            = convert_empty(req$PATH_INFO),
      query           = convert_empty(req$QUERY_STRING),
      post            = safe_post_body,
      status          = convert_empty(res$status),
      duration        = round(end$toc - end$tic, digits = getOption("digits", 5)),
      file            = logging_temp_file,
      modified        = Sys.time()
    )
  })

## -------------------------------------------------------------------##
# 14) Finally, run the API
## -------------------------------------------------------------------##
# For example, you could do port = as.numeric(dw$port_self) if that’s in your config
root %>% pr_run(host = "0.0.0.0", port = as.numeric(dw$port_self))
