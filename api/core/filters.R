## -------------------------------------------------------------------##
# api/core/filters.R
#
# Part of the Phase D.D6 extract-bootstrap refactor.
#
# Hosts the named Plumber filter functions that used to live inline
# in start_sysndd_api.R. `corsFilter` and `checkSignInFilter` are
# attached to the root router in api/bootstrap/mount_endpoints.R via
# pr_filter().
#
# NOTE: `checkSignInFilter` is the legacy pre-require_auth filter.
# It is kept here for the transitional migration path but is not
# wired to the router by default — the live filter is `require_auth`
# from core/security.R. See the `# DEPRECATED` note on the function.
#
# Both filters read the JWT secret from the top-level `dw` list in
# .GlobalEnv (populated by start_sysndd_api.R from config::get()).
## -------------------------------------------------------------------##

#* @filter cors
corsFilter <- function(req, res) {
  # CORS configuration for credentialed requests (sticky session cookies)
  #
  # IMPORTANT: When using withCredentials:true on the frontend, browsers require:
  # 1. Access-Control-Allow-Origin to be the SPECIFIC origin (not "*")
  # 2. Access-Control-Allow-Credentials: true
  # 3. Vary: Origin header for proper caching
  #
  # Without this, sticky session cookies are silently dropped by the browser,
  # causing job status polling to hit random containers and return 404 errors.
  #
  # Firefox is stricter about CORS than Chrome/Edge - missing or incorrect

  # CORS headers on preflight can cause 502 errors in Firefox specifically.
  # See: https://github.com/berntpopp/sysndd/issues/143

  # Get the request origin
  origin <- req$HTTP_ORIGIN


  # Build allowed origins list from environment variable + development defaults
  # CORS_ALLOWED_ORIGINS: comma-separated list of allowed origins
  # e.g., "https://example.com,https://staging.example.com"
  env_origins <- Sys.getenv("CORS_ALLOWED_ORIGINS", "")

  # Parse environment variable into vector (handle empty string case)
  custom_origins <- if (nzchar(env_origins)) {
    trimws(strsplit(env_origins, ",")[[1]])
  } else {
    character(0)
  }

  # Development defaults (always included for local development)
  dev_origins <- c(
    "http://localhost",
    "http://localhost:80",
    "http://localhost:5173", # Vite dev server
    "http://127.0.0.1",
    "http://127.0.0.1:80",
    "http://127.0.0.1:5173"
  )

  # Combine custom origins (first, higher priority) with dev defaults
  allowed_origins <- unique(c(custom_origins, dev_origins))

  # Log configured origins at startup (only once per session via memoization pattern)
  if (!exists(".cors_origins_logged", envir = .GlobalEnv)) {
    if (length(custom_origins) > 0) {
      message(sprintf("[%s] CORS: Configured allowed origins: %s", Sys.time(), paste(custom_origins, collapse = ", ")))
    } else {
      message(sprintf(
        "[%s] CORS: No custom origins configured, using development defaults only",
        Sys.time()
      ))
    }
    assign(".cors_origins_logged", TRUE, envir = .GlobalEnv)
  }

  # Determine if origin is allowed
  is_development <- Sys.getenv("ENVIRONMENT") == "development"
  origin_allowed <- !is.null(origin) && origin %in% allowed_origins

  # Set CORS headers based on origin validation
  if (origin_allowed) {
    # Origin is in allowlist - allow with credentials
    res$setHeader("Access-Control-Allow-Origin", origin)
    res$setHeader("Access-Control-Allow-Credentials", "true")
    res$setHeader("Vary", "Origin") # Critical for proper caching
  } else if (is.null(origin)) {
    # No origin header (same-origin request or non-browser client like curl)
    # Use first allowed origin as default
    default_origin <- if (length(custom_origins) > 0) custom_origins[1] else "http://localhost"
    res$setHeader("Access-Control-Allow-Origin", default_origin)
    res$setHeader("Access-Control-Allow-Credentials", "true")
    res$setHeader("Vary", "Origin")
  } else if (is_development) {
    # Development mode: allow any origin but log for debugging
    log_debug("CORS: Development mode allowing unlisted origin", origin = origin)
    res$setHeader("Access-Control-Allow-Origin", origin)
    res$setHeader("Access-Control-Allow-Credentials", "true")
    res$setHeader("Vary", "Origin")
  } else {
    # Production mode: reject unknown origins
    # Return proper CORS error instead of allowing (security best practice)
    log_warn("CORS: Blocked request from unknown origin in production",
             origin = origin,
             allowed = paste(allowed_origins, collapse = ", "))
    res$status <- 403
    res$setHeader("Content-Type", "application/problem+json")
    return(list(
      type = "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/403",
      title = "Forbidden",
      status = 403,
      detail = "Origin not allowed by CORS policy"
    ))
  }

  # Handle preflight OPTIONS requests
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS")
    res$setHeader(
      "Access-Control-Allow-Headers",
      req$HTTP_ACCESS_CONTROL_REQUEST_HEADERS %||% "Content-Type, Authorization"
    )
    # Cache preflight response for 24 hours (reduces preflight requests)
    res$setHeader("Access-Control-Max-Age", "86400")
    # 204 No Content is more appropriate for preflight than 200
    res$status <- 204
    return(list())
  }

  plumber::forward()
}

#* @filter check_signin
# DEPRECATED: Use require_auth filter instead.
# This will be removed after Phase 22 endpoint migration.
checkSignInFilter <- function(req, res) {
  key <- charToRaw(if (is.list(dw$secret)) as.character(dw$secret[[1]]) else as.character(dw$secret))

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

#' Error handler middleware for RFC 9457 compliance.
#'
#' Wraps every unhandled exception in a problem+json response.
#' Classed errors from core/errors.R (error_400, error_401, ...)
#' map to the corresponding HTTP status; everything else becomes
#' a 500 with a redacted detail message.
#'
#' @param req Plumber request object
#' @param res Plumber response object
#' @param err Condition raised by the endpoint
#' @return RFC 9457 problem details response
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
