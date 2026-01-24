# Authentication and Authorization Middleware for SysNDD API
# Provides centralized JWT validation and role-based access control via Plumber filters
#
# Usage:
#   source("core/middleware.R")
#   pr_filter("require_auth", require_auth)
#
# Exports:
#   - require_auth: Filter for JWT validation and user context attachment
#   - require_role: Helper function for endpoint-level role enforcement
#   - AUTH_ALLOWLIST: Public endpoints that bypass authentication

library(jose)
library(stringr)
library(logger)

# Public endpoints that bypass authentication
# These endpoints are accessible without Bearer tokens
AUTH_ALLOWLIST <- c(
  "/api/gene/hash",
  "/api/entity/hash",
  "/api/jobs/clustering/submit",
  "/api/jobs/clustering/submit/",
  "/api/jobs/phenotype_clustering/submit",
  "/api/jobs/phenotype_clustering/submit/",
  "/api/user/password/reset/request",
  "/api/auth/signin",
  "/api/auth/signup",
  "/api/auth/verify",
  "/api/auth/refresh",
  "/health",
  "/health/",
  "/__docs__/",
  "/openapi.json"
)

#' Authentication Filter
#'
#' Validates JWT tokens for protected endpoints. Implements allowlist pattern
#' for public endpoints and provides public read access for GET requests.
#'
#' Authentication flow:
#' 1. OPTIONS requests (CORS preflight) -> forward
#' 2. Paths in AUTH_ALLOWLIST -> forward
#' 3. GET requests without auth -> forward (public read access)
#' 4. All other requests -> require valid Bearer token
#'
#' On successful authentication, attaches to req object:
#' - req$user_id: Numeric user ID
#' - req$user_role: String user role (Viewer, Reviewer, Curator, Administrator)
#' - req$user_name: String user name
#'
#' @param req Plumber request object
#' @param res Plumber response object
#' @return Forwards to next filter/endpoint on success, returns 401 error on failure
#'
#' @examples
#' \dontrun{
#' pr_filter("require_auth", require_auth)
#' }
require_auth <- function(req, res) {
  # OPTIONS requests (CORS preflight) always forward
  if (req$REQUEST_METHOD == "OPTIONS") {
    log_debug("require_auth: OPTIONS request, forwarding")
    return(plumber::forward())
  }

  # Check if path is in allowlist (public endpoints)
  if (req$PATH_INFO %in% AUTH_ALLOWLIST) {
    log_debug("require_auth: Path in allowlist, forwarding", path = req$PATH_INFO)
    return(plumber::forward())
  }

  # GET requests without auth get public read access
  if (req$REQUEST_METHOD == "GET" && is.null(req$HTTP_AUTHORIZATION)) {
    log_debug("require_auth: GET without auth, forwarding (public read)")
    return(plumber::forward())
  }

  # All other cases require authentication
  if (is.null(req$HTTP_AUTHORIZATION)) {
    log_warn("require_auth: Missing authorization header",
             method = req$REQUEST_METHOD,
             path = req$PATH_INFO)
    res$status <- 401
    stop(error_unauthorized("Authorization header missing. Please provide a Bearer token."))
  }

  # Extract and validate Bearer token
  token <- stringr::str_remove(req$HTTP_AUTHORIZATION, "^Bearer\\s+")

  # Decode JWT using global secret (dw$secret is approved global)
  key <- charToRaw(dw$secret)

  tryCatch({
    user <- jose::jwt_decode_hmac(token, secret = key)

    # Check token expiration
    if (!is.null(user$exp) && user$exp < as.numeric(Sys.time())) {
      log_warn("require_auth: Token expired", user_id = user$user_id)
      res$status <- 401
      stop(error_unauthorized("Token expired. Please refresh your authentication."))
    }

    # Attach user context to request for downstream use
    req$user_id <- as.integer(user$user_id)
    req$user_role <- user$user_role
    req$user_name <- user$user_name %||% "Unknown"

    log_debug("require_auth: Authentication successful",
              user_id = req$user_id,
              user_role = req$user_role,
              path = req$PATH_INFO)

    return(plumber::forward())

  }, error = function(e) {
    # JWT decode failed (invalid signature, malformed token, etc.)
    log_warn("require_auth: JWT decode failed",
             error = conditionMessage(e),
             path = req$PATH_INFO)
    res$status <- 401
    stop(error_unauthorized("Invalid or malformed authentication token."))
  })
}

#' Role-Based Authorization Helper
#'
#' Enforces minimum role requirement for endpoint actions. Call this from
#' endpoint handlers to ensure user has sufficient privileges.
#'
#' Role hierarchy (from lowest to highest):
#' - Viewer (1): Read-only access
#' - Reviewer (2): Can review submissions
#' - Curator (3): Can create/modify data
#' - Administrator (4): Full system access
#'
#' @param req Plumber request object (must have req$user_role attached by require_auth)
#' @param res Plumber response object
#' @param min_role String minimum role required ("Viewer", "Reviewer", "Curator", "Administrator")
#' @return Invisible TRUE on success, stops with 403 error on insufficient privileges
#'
#' @examples
#' \dontrun{
#' # In endpoint handler:
#' function(req, res) {
#'   require_role(req, res, "Curator")  # Only Curator+ can proceed
#'   # ... endpoint logic
#' }
#' }
require_role <- function(req, res, min_role) {
  role_levels <- c(
    "Viewer" = 1,
    "Reviewer" = 2,
    "Curator" = 3,
    "Administrator" = 4
  )

  # Get user's role level (default to 0 if missing or invalid)
  user_level <- role_levels[[req$user_role]] %||% 0
  required_level <- role_levels[[min_role]] %||% 1

  if (user_level < required_level) {
    log_warn("require_role: Insufficient privileges",
             user_id = req$user_id %||% "unknown",
             user_role = req$user_role %||% "none",
             required_role = min_role,
             path = req$PATH_INFO)

    res$status <- 403
    stop(error_forbidden(sprintf(
      "This action requires %s privileges. You have %s role.",
      min_role,
      req$user_role %||% "no"
    )))
  }

  log_debug("require_role: Authorization successful",
            user_id = req$user_id,
            user_role = req$user_role,
            required_role = min_role)

  invisible(TRUE)
}
