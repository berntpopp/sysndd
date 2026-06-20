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

  # Build a mounted endpoint sub-router that inherits the API's RFC 9457 error
  # and 404 handling. Plumber does NOT propagate the root router's error/404
  # handlers to mounted sub-routers (each router keeps its own), so a thrown
  # classed error (e.g. stop_for_bad_request() -> error_400) or an unknown
  # sub-path would otherwise fall back to plumber's default opaque
  # `{"error":"500 ..."}` / `{"error":"404 ..."}` instead of being mapped to the
  # correct status + problem+json by errorHandler / notFoundHandler. Attaching
  # them here keeps error and not-found responses consistent across every
  # /api/<subpath>. Static guard: tests/testthat/test-unit-endpoint-error-handler.R
  mount_endpoint <- function(file) {
    plumber::pr(file) %>%
      plumber::pr_set_error(errorHandler) %>%
      plumber::pr_set_404(notFoundHandler)
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
          "/api/seo/routes", "/api/seo/gene", "/api/seo/entity", "/api/seo/static",
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
    plumber::pr_mount("/api/health", mount_endpoint("endpoints/health_endpoints.R")) %>%
    ####################################################################
    # Mount version endpoint for API version discovery
    ####################################################################
    plumber::pr_mount("/api/version", mount_endpoint("endpoints/version_endpoints.R")) %>%
    ####################################################################
    # Mount each endpoint file at /api/<subpath>
    ####################################################################
    plumber::pr_mount("/api/entity", mount_endpoint("endpoints/entity_endpoints.R")) %>%
    plumber::pr_mount("/api/review", mount_endpoint("endpoints/review_endpoints.R")) %>%
    plumber::pr_mount("/api/re_review", mount_endpoint("endpoints/re_review_endpoints.R")) %>%
    plumber::pr_mount("/api/publication", mount_endpoint("endpoints/publication_endpoints.R")) %>%
    plumber::pr_mount("/api/gene", mount_endpoint("endpoints/gene_endpoints.R")) %>%
    plumber::pr_mount("/api/ontology", mount_endpoint("endpoints/ontology_endpoints.R")) %>%
    plumber::pr_mount("/api/phenotype", mount_endpoint("endpoints/phenotype_endpoints.R")) %>%
    plumber::pr_mount("/api/status", mount_endpoint("endpoints/status_endpoints.R")) %>%
    plumber::pr_mount("/api/panels", mount_endpoint("endpoints/panels_endpoints.R")) %>%
    plumber::pr_mount("/api/comparisons", mount_endpoint("endpoints/comparisons_endpoints.R")) %>%
    plumber::pr_mount("/api/analysis", mount_endpoint("endpoints/analysis_endpoints.R")) %>%
    plumber::pr_mount("/api/jobs/network_layout", mount_endpoint("endpoints/jobs_network_layout_endpoints.R")) %>%
    plumber::pr_mount("/api/jobs", mount_endpoint("endpoints/jobs_endpoints.R")) %>%
    plumber::pr_mount("/api/hash", mount_endpoint("endpoints/hash_endpoints.R")) %>%
    plumber::pr_mount("/api/search", mount_endpoint("endpoints/search_endpoints.R")) %>%
    plumber::pr_mount("/api/list", mount_endpoint("endpoints/list_endpoints.R")) %>%
    plumber::pr_mount("/api/metadata", mount_endpoint("endpoints/metadata_endpoints.R")) %>%
    plumber::pr_mount("/api/logs", mount_endpoint("endpoints/logging_endpoints.R")) %>%
    plumber::pr_mount("/api/user", mount_endpoint("endpoints/user_endpoints.R")) %>%
    plumber::pr_mount("/api/auth", mount_endpoint("endpoints/authentication_endpoints.R")) %>%
    plumber::pr_mount("/api/about", mount_endpoint("endpoints/about_endpoints.R")) %>%
    plumber::pr_mount("/api/seo", mount_endpoint("endpoints/seo_endpoints.R")) %>%
    plumber::pr_mount("/api/admin/analysis", mount_endpoint("endpoints/admin_analysis_snapshot_endpoints.R")) %>%
    plumber::pr_mount("/api/admin", mount_endpoint("endpoints/admin_endpoints.R")) %>%
    plumber::pr_mount("/api/llm", mount_endpoint("endpoints/llm_admin_endpoints.R")) %>%
    plumber::pr_mount("/api/backup", mount_endpoint("endpoints/backup_endpoints.R")) %>%
    plumber::pr_mount("/api/external", mount_endpoint("endpoints/external_endpoints.R")) %>%
    plumber::pr_mount("/api/statistics", mount_endpoint("endpoints/statistics_endpoints.R")) %>%
    plumber::pr_mount("/api/variant", mount_endpoint("endpoints/variant_endpoints.R")) %>%
    plumber::pr_mount("/api/nddscore", mount_endpoint("endpoints/nddscore_endpoints.R")) %>%
    plumber::pr_mount("/api/genereviews", mount_endpoint("endpoints/genereviews_endpoints.R")) %>%
    plumber::pr_mount("/api/disease", mount_endpoint("endpoints/disease_mapping_endpoints.R")) %>%
    ####################################################################
    # preroute / postroute hooks for timing & logging
    ####################################################################
    plumber::pr_hook("preroute", function() {
      external_proxy_request_reset() # #344: zero the per-request external-time accumulator
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
        "[redacted]",
        safe_post_body,
        convert_empty(res$status),
        round(end$toc - end$tic, digits = getOption("digits", 5)),
        sep = ";",
        collapse = ""
      )
      log_info(skip_formatter(log_entry))

      # #344: structured, greppable per-request timing with external-time
      # attribution. external_ms is the wall time this request spent in external
      # provider calls (0 for cheap routes); slow=true flags requests over the
      # SLO threshold (API_SLOW_REQUEST_MS, default 2000).
      duration_ms <- (end$toc - end$tic) * 1000
      external_ms <- external_proxy_request_total_ms()
      slow_threshold_ms <- suppressWarnings(as.numeric(Sys.getenv("API_SLOW_REQUEST_MS", "2000")))
      if (is.na(slow_threshold_ms) || slow_threshold_ms <= 0) slow_threshold_ms <- 2000
      structured_timing <- paste0(
        "[request-timing] ",
        "method=", convert_empty(req$REQUEST_METHOD),
        " path=", convert_empty(req$PATH_INFO),
        " status=", convert_empty(res$status),
        " duration_ms=", as.integer(round(duration_ms)),
        " external_ms=", as.integer(round(external_ms)),
        " slow=", tolower(as.character(duration_ms >= slow_threshold_ms))
      )
      log_info(skip_formatter(structured_timing))

      # Write log entry to DB with sanitized data
      log_message_to_db(
        address         = convert_empty(req$REMOTE_ADDR),
        agent           = convert_empty(req$HTTP_USER_AGENT),
        host            = convert_empty(req$HTTP_HOST),
        request_method  = convert_empty(req$REQUEST_METHOD),
        path            = convert_empty(req$PATH_INFO),
        query           = "[redacted]",
        post            = safe_post_body,
        status          = convert_empty(res$status),
        duration        = round(end$toc - end$tic, digits = getOption("digits", 5)),
        file            = logging_temp_file,
        modified        = Sys.time()
      )
    })
}
