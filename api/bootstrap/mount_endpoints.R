## -------------------------------------------------------------------##
# api/bootstrap/mount_endpoints.R
#
# Part of the Phase D.D6 extract-bootstrap refactor.
#
# Builds the root Plumber router:
#   - attaches the RFC 9457 error handler + 404 handler
#   - wires the OpenAPI spec callback (reads version_spec.json)
#   - attaches the `cors` and `require_auth` filters
#   - installs the exit hook that closes the DB pool and the
#     mirai daemon pool
#   - mounts every endpoint file under /api/<subpath>
#   - installs the preroute/postroute timing + logging hook
#
# The composer in start_sysndd_api.R passes the pool and the
# temporary log-file path; they are captured by closure so the
# exit hook and the postroute hook can reach them without needing
# top-level globals.
## -------------------------------------------------------------------##

#' Build the fully-mounted root Plumber router.
#'
#' @param api_spec The parsed `config/api_spec.json` list, used by
#'   `update_api_spec_examples()` inside the OpenAPI spec callback.
#' @param pool The shared DBI pool; closed by the exit hook.
#' @param logging_temp_file Path to the Plumber access log file; the
#'   postroute hook passes this to `log_message_to_db()` so entries
#'   can be correlated with the on-disk logs.
#' @return A Plumber router ready to be started with `pr_run()`.
#' @export
bootstrap_mount_endpoints <- function(api_spec, pool, logging_temp_file) {

  # Named closure for the exit hook so the pool reference travels
  # via closure instead of via a global lookup.
  cleanupHook <- function(pr) {
    pr %>%
      plumber::pr_hook("exit", function() {
        pool::poolClose(pool)
        message("Disconnected from DB")
        mirai::daemons(0) # Shutdown mirai daemon pool
        message("Shutdown mirai daemon pool")
      })
  }

  plumber::pr() %>%
    # Install error handler middleware
    plumber::pr_set_error(errorHandler) %>%
    # Install 404 handler for non-existent routes (RFC 9457 compliant)
    plumber::pr_set_404(notFoundHandler) %>%
    # Insert doc info in pr_set_api_spec
    plumber::pr_set_api_spec(function(spec) {
      # Read version info from version_spec.json
      version_info <- jsonlite::fromJSON("version_spec.json")
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

      # Enhance with modular schemas and standard error responses
      spec <- enhance_openapi_spec(
        spec,
        config_dir = "config/openapi",
        add_error_responses = TRUE,
        public_paths = c(
          "/api/health", "/api/version", "/api/about",
          "/__docs__", "/__swagger__"
        )
      )

      spec
    }) %>%
    ####################################################################
    # Attach filters
    ####################################################################
    plumber::pr_filter("cors", corsFilter) %>%
    plumber::pr_filter("require_auth", require_auth) %>%
    ####################################################################
    # Attach exit hook
    ####################################################################
    cleanupHook() %>%
    ####################################################################
    # Mount health endpoint for Docker HEALTHCHECK
    ####################################################################
    plumber::pr_mount("/api/health", plumber::pr("endpoints/health_endpoints.R")) %>%
    ####################################################################
    # Mount version endpoint for API version discovery
    ####################################################################
    plumber::pr_mount("/api/version", plumber::pr("endpoints/version_endpoints.R")) %>%
    ####################################################################
    # Mount each endpoint file at /api/<subpath>
    ####################################################################
    plumber::pr_mount("/api/entity", plumber::pr("endpoints/entity_endpoints.R")) %>%
    plumber::pr_mount("/api/review", plumber::pr("endpoints/review_endpoints.R")) %>%
    plumber::pr_mount("/api/re_review", plumber::pr("endpoints/re_review_endpoints.R")) %>%
    plumber::pr_mount("/api/publication", plumber::pr("endpoints/publication_endpoints.R")) %>%
    plumber::pr_mount("/api/gene", plumber::pr("endpoints/gene_endpoints.R")) %>%
    plumber::pr_mount("/api/ontology", plumber::pr("endpoints/ontology_endpoints.R")) %>%
    plumber::pr_mount("/api/phenotype", plumber::pr("endpoints/phenotype_endpoints.R")) %>%
    plumber::pr_mount("/api/status", plumber::pr("endpoints/status_endpoints.R")) %>%
    plumber::pr_mount("/api/panels", plumber::pr("endpoints/panels_endpoints.R")) %>%
    plumber::pr_mount("/api/comparisons", plumber::pr("endpoints/comparisons_endpoints.R")) %>%
    plumber::pr_mount("/api/analysis", plumber::pr("endpoints/analysis_endpoints.R")) %>%
    plumber::pr_mount("/api/jobs", plumber::pr("endpoints/jobs_endpoints.R")) %>%
    plumber::pr_mount("/api/hash", plumber::pr("endpoints/hash_endpoints.R")) %>%
    plumber::pr_mount("/api/search", plumber::pr("endpoints/search_endpoints.R")) %>%
    plumber::pr_mount("/api/list", plumber::pr("endpoints/list_endpoints.R")) %>%
    plumber::pr_mount("/api/logs", plumber::pr("endpoints/logging_endpoints.R")) %>%
    plumber::pr_mount("/api/user", plumber::pr("endpoints/user_endpoints.R")) %>%
    plumber::pr_mount("/api/auth", plumber::pr("endpoints/authentication_endpoints.R")) %>%
    plumber::pr_mount("/api/about", plumber::pr("endpoints/about_endpoints.R")) %>%
    plumber::pr_mount("/api/admin", plumber::pr("endpoints/admin_endpoints.R")) %>%
    plumber::pr_mount("/api/llm", plumber::pr("endpoints/llm_admin_endpoints.R")) %>%
    plumber::pr_mount("/api/backup", plumber::pr("endpoints/backup_endpoints.R")) %>%
    plumber::pr_mount("/api/external", plumber::pr("endpoints/external_endpoints.R")) %>%
    plumber::pr_mount("/api/statistics", plumber::pr("endpoints/statistics_endpoints.R")) %>%
    plumber::pr_mount("/api/variant", plumber::pr("endpoints/variant_endpoints.R")) %>%
    ####################################################################
    # preroute / postroute hooks for timing & logging
    ####################################################################
    plumber::pr_hook("preroute", function() {
      tictoc::tic()
    }) %>%
    plumber::pr_hook("postroute", function(req, res) {
      end <- tictoc::toc(quiet = TRUE)

      # Sanitize the request before logging
      safe_req <- sanitize_request(req)

      # For postBody, extract and sanitize if present
      safe_post_body <- if (!is.null(req$postBody) && nchar(req$postBody) > 0) {
        tryCatch(
          {
            body_parsed <- jsonlite::fromJSON(
              req$postBody, simplifyVector = FALSE
            )
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
}
